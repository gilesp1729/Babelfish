// Babelfish is several things: 
// - a transponder between the Bafang M510 CAN bus and BLE cycle power
// characteristics to suit popular cycling apps (e.g. SuperCycle). 
// Exports speed, cadence, and power to a CP service, and battery level 
// to a battery service.
// Also exports extra information (motor power, amps, range, PAS level, etc)
// to custom BLE services for the companion custom phone app, designed to 
// replace Bafang Go+.

// - a CAN bus sniffer and logger
// - a means of proramming the motor, like Bafang's BESST tool.

// Runs on Adafruit Bluefruit LE feather and CAN bus wing.

#include <Adafruit_BLEGatt.h>
#include "Adafruit_BluefruitLE_SPI.h"
#include "BluefruitConfig.h"
#include "Babelfish.h"

// CAN bus select pin and baud rate
#define CS_PIN    5
#define CAN_BAUDRATE (250000)

Adafruit_MCP2515 mcp(CS_PIN);

Adafruit_BluefruitLE_SPI ble(BLUEFRUIT_SPI_CS, BLUEFRUIT_SPI_IRQ, BLUEFRUIT_SPI_RST);
Adafruit_BLEGatt gatt(ble);

// Logging packets on CAN bus.
// verbosity      0 = don't print any packets
//                1 = print all packets with changed data (suppress repeats)
//                2 = print known packets
//                3 = print all packets.
// only_this_id   0 = print all packets according to verbosity
//                !=0 print only packets with this ID
int verbosity = 3;
uint32_t only_this_id = 0;

int sensor_pos = 11;      // sensor position magic number.
// No idea what they mean (shitty specs) but it's mandatory to supply one.

unsigned char bleBuffer[14];
unsigned char slBuffer[1];
unsigned char fBuffer[4];
int connected = 0;

// Feature bits: bit 2 - wheel pair present, bit 3 - crank pair present
unsigned short feature_bits = 0x0C;

// Flags bits: bit 4 - wheel pair present, bit 5 - crank pair present
unsigned short flags = 0x30;

  // Services and characteristics
  uint8_t cyclePowerService;
  uint8_t cyclePowerFeature;
  uint8_t cyclePowerMeasurement;
  uint8_t cyclePowerSensorLocation;

  uint8_t batteryService;
  uint8_t batteryLevelChar;

  uint8_t motorService;
  uint8_t motorMeasurement;
  uint8_t motorSettings;
  uint8_t motorResettableTrip;

// Timing and counters
// Counters for wheel and crank 
unsigned long time_now;
unsigned long time_prev_wheel = 0;
unsigned long time_prev_crank = 0;
unsigned long wheel_interval, crank_interval;

// Counters for updating power and speed services
unsigned long wheelRev = 0;
unsigned long lastWheeltime = 0;   // last time measurement taken
// Note: the wheel time is in half-ms (1/2048 sec), unlike CSC where it is in ms
unsigned int crankRev = 0;
unsigned long lastCranktime = 0;

// Motor controller readings, derived values, and display values
extern MotorController motor;
extern Display display;

// Fill the CP measurement array and send it
void fillCP()
{
  int n = 0;  // to facilitate adding and removing stuff
  bleBuffer[n++] = flags & 0xff;
  bleBuffer[n++] = (flags >> 8) & 0xff;
  bleBuffer[n++] = motor.power & 0xff;
  bleBuffer[n++] = (motor.power >> 8) & 0xff;
  bleBuffer[n++] = wheelRev & 0xff;
  bleBuffer[n++] = (wheelRev >> 8) & 0xff;  // UInt32
  bleBuffer[n++] = (wheelRev >> 16) & 0xff;
  bleBuffer[n++] = (wheelRev >> 24) & 0xff;
  bleBuffer[n++] = lastWheeltime & 0xff;
  bleBuffer[n++] = (lastWheeltime >> 8) & 0xff;
  bleBuffer[n++] = crankRev & 0xff;
  bleBuffer[n++] = (crankRev >> 8) & 0xff;
  bleBuffer[n++] = lastCranktime & 0xff;
  bleBuffer[n++] = (lastCranktime >> 8) & 0xff;
  gatt.setChar(cyclePowerMeasurement, bleBuffer, n);
}

// Fill the motor service characteristics and send them
void fillMS()
{
  int n = 0;  // to facilitate adding and removing stuff
  bleBuffer[n++] = motor.kmh & 0xff;
  bleBuffer[n++] = (motor.kmh >> 8) & 0xff;
  bleBuffer[n++] = motor.crpm;
  bleBuffer[n++] = motor.power & 0xff;
  bleBuffer[n++] = (motor.power >> 8) & 0xff;
  bleBuffer[n++] = motor.volts & 0xff;
  bleBuffer[n++] = (motor.volts >> 8) & 0xff;
  bleBuffer[n++] = motor.amps & 0xff;
  bleBuffer[n++] = (motor.amps >> 8) & 0xff;
  bleBuffer[n++] = motor.range & 0xff;
  bleBuffer[n++] = (motor.range >> 8) & 0xff;
  bleBuffer[n++] = motor.pas;
  bleBuffer[n++] = motor.motor_temp;
  bleBuffer[n++] = motor.ctrlr_temp;
  gatt.setChar(motorMeasurement, bleBuffer, n);

  n = 0;
  bleBuffer[n++] = motor.limit & 0xff;
  bleBuffer[n++] = (motor.limit >> 8) & 0xff;
  bleBuffer[n++] = motor.circ & 0xff;
  bleBuffer[n++] = (motor.circ >> 8) & 0xff;
  bleBuffer[n++] = 0;         // for later setting of wheel size
  bleBuffer[n++] = 0;
  gatt.setChar(motorSettings, bleBuffer, n);

  n = 0;
  bleBuffer[n++] = display.trip & 0xff;
  bleBuffer[n++] = (display.trip >> 8) & 0xff;
  bleBuffer[n++] = display.avg_speed & 0xff;
  bleBuffer[n++] = (display.avg_speed >> 8) & 0xff;
  bleBuffer[n++] = display.max_speed & 0xff;
  bleBuffer[n++] = (display.max_speed >> 8) & 0xff;
  gatt.setChar(motorResettableTrip, bleBuffer, n);
}


// Update old values and send CP and MS to BLE client
void update_chars()
{
  // Update old values 
  fillCP();
  fillMS();

  // Some debug output to indicate what triggered the update
  Serial.print(F("Wheel Rev.: "));
  Serial.print(wheelRev);
  Serial.print(F(" WheelTime : "));
  Serial.print(lastWheeltime);
  Serial.print(F(" Crank Rev.: "));
  Serial.print(crankRev);
  Serial.print(F(" CrankTime : "));
  Serial.println(lastCranktime);
}

// Check if wheel or crank intervals have expired; increment their
// rev counters if they have.
void updateWheelCrank()
{
  time_now = millis();

  if (wheel_interval != 0 && time_now >= time_prev_wheel + wheel_interval)
  {
    // Update the wheel counter and remember the time of last update
    wheelRev = wheelRev + 1;
    lastWheeltime = (time_prev_wheel + wheel_interval) << 1;  // in half-ms
    time_prev_wheel = time_now;
  }

  if (crank_interval != 0 && time_now >= time_prev_crank + crank_interval) 
  {
    crankRev = crankRev + 1;
    lastCranktime = time_prev_crank + crank_interval;
    time_prev_crank = time_now;
  }
}

void error(const __FlashStringHelper *str)
{
  Serial.println(str);
  while (1)
    ;   // block
}

void setup()
{
  int count = 0;

  Serial.begin(9600);  // initialize serial communication
  while (!Serial)
  {
    // Be sure to break out so we don't wait forever if no serial is connected
    if (count++ > 20)
      break;
    delay(100);
  }

  if (!mcp.begin(CAN_BAUDRATE)) 
    error(F("Error initializing MCP2515."));
  
  if ( !ble.begin(VERBOSE_MODE) )
    error(F("Couldn't find Bluefruit, make sure it's in CoMmanD mode & check wiring?"));
  Serial.println( F("OK!") );

  /* Perform a factory reset to make sure everything is in a known state */
  Serial.println(F("Performing a factory reset: "));
  if (! ble.factoryReset() )
    error(F("Couldn't factory reset"));

  // Cycle power service and characteristics. Note: Don't use BLE_DATATYPE_INTEGER here,
  // as the radio's AT parser expects decimal! while the Adafruit library writes everything in hex.
  // DATATYPE_BYTEARRAY is safe.
  cyclePowerService = gatt.addService(0x1818);
  cyclePowerFeature =
    gatt.addCharacteristic(0x2A65, GATT_CHARS_PROPERTIES_READ, 4, 4, BLE_DATATYPE_BYTEARRAY);
  cyclePowerMeasurement =
    gatt.addCharacteristic(0x2A63, GATT_CHARS_PROPERTIES_READ | GATT_CHARS_PROPERTIES_NOTIFY, 14, 14, BLE_DATATYPE_BYTEARRAY);
  cyclePowerSensorLocation =
    gatt.addCharacteristic(0x2A5D, GATT_CHARS_PROPERTIES_READ, 1, 1, BLE_DATATYPE_BYTEARRAY);

  batteryService = gatt.addService(0x180F);
  batteryLevelChar =
    gatt.addCharacteristic(0x2A19, GATT_CHARS_PROPERTIES_READ | GATT_CHARS_PROPERTIES_NOTIFY, 1, 1, BLE_DATATYPE_BYTEARRAY);

  // Advertise cycling power service
  Serial.println(F("Setting device name to 'Babelfish': "));
  if (! ble.sendCommandCheckOK(F("AT+GAPDEVNAME=Babelfish")) ) 
    error(F("Could not set device name?"));

  // Initialise some value to sensible defaults
  motor.battery_level = 100;
  motor.circ = 2300;

  // Don't advertise the battery service; it will be found when the app connects,
  // if the app is looking for it
  slBuffer[0] = motor.battery_level & 0xff;
  gatt.setChar(batteryLevelChar, slBuffer, 1);

  // Create custom motor parameters service
  motorService = gatt.addService(0xFFF0);
  motorMeasurement =
    gatt.addCharacteristic(0xFFF1, GATT_CHARS_PROPERTIES_READ | GATT_CHARS_PROPERTIES_NOTIFY, 14, 14, BLE_DATATYPE_BYTEARRAY);
  motorSettings =
    gatt.addCharacteristic(0xFFF2, GATT_CHARS_PROPERTIES_READ | GATT_CHARS_PROPERTIES_WRITE | GATT_CHARS_PROPERTIES_NOTIFY, 6, 6, BLE_DATATYPE_BYTEARRAY);
  motorResettableTrip =
    gatt.addCharacteristic(0xFFF3, GATT_CHARS_PROPERTIES_READ | GATT_CHARS_PROPERTIES_WRITE | GATT_CHARS_PROPERTIES_NOTIFY, 6, 6, BLE_DATATYPE_BYTEARRAY);

  // Initial values for wheel and crank timers
  unsigned long t = millis();
  lastWheeltime = t << 1;       // this is in half-ms
  lastCranktime = t;

  // Write the initial values of the CP (power) characteristics
  slBuffer[0] = sensor_pos & 0xff;
  fBuffer[0] = feature_bits & 0xff;   // little endian
  fBuffer[1] = 0x00;
  fBuffer[2] = 0x00;
  fBuffer[3] = 0x00;
  gatt.setChar(cyclePowerFeature, fBuffer, 4);
  gatt.setChar(cyclePowerSensorLocation, slBuffer, 1);
  fillCP();

  // Write initial values for the custom motor characteristics
  fillMS();

  // Service changes require a reset
  ble.reset();

  // Advertise that we are ready to go
  Serial.print(F("Adding Cycle Power UUID to the advertising payload: "));
  ble.sendCommandCheckOK( F("AT+GAPSETADVDATA=02-01-06-05-02-18-18-0a-18") );
  ble.sendCommandCheckOK( F("AT+GAPSTARTADV"));
  Serial.println(F("Bluetooth device active, waiting for connections..."));

  // For debugging
  //error (F("Stop here"));
  ble.verbose(false);
}

void loop()
{
  // Accept and act on commands from the Serial monitor.
  // Anything that is not a command just gets echoed to the serial monitor.
  if (Serial.available())
  {
    char buf[16];
    int len;
    char *p;

    while (Serial.available())
    {
      len = Serial.readBytesUntil('\n', buf, 16);
      buf[len] = '\0';
      p = buf;
      Serial.println(buf);

      switch (*p++)
      {
        case 'v':
        case 'V':
          // Set logging verbosity.
          if (len <= 1)
            break;
          while (isspace(*p))
            p++;
          verbosity = atoi(p);
          break;

        case 'c':
        case 'C':
          // Set/display circumference (mm).
          if (len <= 1)
          {
            Serial.print(F("Wheel circ = "));
            Serial.println(motor.circ);
          }
          else
          {
            while (isspace(*p))
              p++;
            // Write the speed limit/circ packet to the motor here.
            send_circumference(mcp, atoi(p));
          }
          break;

#if 0  // probably won't do this.
        case 'w':
        case 'W':
          // Set/display wheel size (inches). Input is floating point.

          break;
#endif

        case 'l':
        case 'L':
          // Set/display motor speed limit. 
          if (len <= 1)
          {
            Serial.print(F("Speed limit = "));
            Serial.println(motor.limit / 100);
          }
          else
          {
            while (isspace(*p))
              p++;
            // Write the speed limit/circ packet to the motor here.
            send_speed_limit(mcp, atoi(p));
          }
          break;
      }
    }
  }

  // if a central is connected to peripheral:
  if (ble.isConnected())
  {
    Serial.println(F("Connected to central"));
    // turn on the LED to indicate the connection:
    digitalWrite(LED_BUILTIN, HIGH);

    while (ble.isConnected())
    {
      connected = 1;

      // Check if wheel or crank intervals have expired; increment their
      // rev counters if they have.
      updateWheelCrank();

      // Scan CAN bus and update characteristics.
      if (scanbus(mcp, connected, verbosity, only_this_id))
      {
        // Power, speed, cadence (CP service) and battery level service.
        // Update the characteristics.
        // Speed packets will come roughly every 280ms
        update_chars();
        slBuffer[0] = motor.battery_level & 0xff;
        gatt.setChar(batteryLevelChar, slBuffer, 1);

        // Volts, amps, motor temps, PAS level (custom motor service)
        // Speed limit, wheelsize, circumference (custom motor service)
        // TODO 



      }
    }

    // when the central disconnects, turn off the LED:
    connected = 0;
    digitalWrite(LED_BUILTIN, LOW);
    Serial.println(F("Disconnected from central"));
    ble.sendCommandCheckOK( F("AT+GAPSTARTADV"));
    Serial.println(F("Bluetooth device active, waiting for connections..."));
  }
  else  // not connected, scan the CAN bus so we can print (optionally)
        // and possibly receive commands from the serial monitor input
  {
    scanbus(mcp, connected, verbosity, only_this_id);
  }
}
