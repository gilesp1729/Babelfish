#include <Adafruit_MCP2515.h>

// Definition of motor+controller.

typedef struct MotorController
{
  // Raw readings in uint16_t. They are raw as-received from the CAN bus,
  // and are printed to 0, 1 or 2 decimal places depending on their implicit multiplier.

  uint16_t kmh;             // speed in km/h*100
  uint8_t crpm;             // cadence in rpm
  uint16_t range;           // range in km*100
  uint16_t volts;           // battery volts*100
  uint16_t amps;            // motor current in amps*100
  int battery_level;        // in %
  uint8_t pas;              // PAS level (0-5)
  uint8_t motor_temp;       // Motor temp in degC + 40
  uint8_t ctrlr_temp;       // Controller temp in degC + 40

  // Derived values for the CP service
  uint32_t wheel_interval;  // in half-ms
  uint16_t crank_interval;  // in ms
  uint16_t power;           // in watts
};

// these fields are managed by the display. They are sent to the motor
// on the CAN bus, but do not appear to be needed by the motor.
typedef struct Display
{
  uint16_t odo;             // odometer in km/h
  uint16_t avg_speed;       // average speed in km/h*10
  uint16_t max_speed;       // maximum speed in km/h*10
  uint16_t trip;            // trip distamce in km*10
};

// These fields are writable settings for the motor.
// In practice only the speed limit is ever written (in a separate writable
// characteristic)
typedef struct Settings
{
  uint16_t limit;           // speed limit in km/h*100
  uint16_t wheel_size;      // wheel size in 12.4 (decimal fraction part in low nibble)
  uint16_t circ;            // wheel circumference in mm
  uint16_t new_limit;       // Speed limit set by central (phone app), in km/h*100
  uint16_t new_wheel;       // Wheel size set similarly, in 12.4
  uint16_t new_circ;        // Circumference set similarly, in mm
  bool     valid_read;      // True if settings have been read from the CAN bus
  bool     valid_write;     // True if settings have been written by central over BLE
};

// Motor controller readings, derived values, display values, and settings
extern MotorController motor;
extern Display display;
extern Settings settings;


// Scanning bus and logging packets.

// mcp            The MCP2515 instance.
// connected      Whether connected to a BLE central
// verbosity      0 = don't print any packets
//                1 = print all packets with changed data (suppress repeats)
//                2 = print known packets
//                3 = print all packets.
// only_this_id   0 = print all packets according to verbosity
//                !=0 print only packets with this ID
int scanbus(Adafruit_MCP2515 mcp, bool connected, int verbosity, uint32_t only_this_id);

// Print serial and model numbers of controller
void print_serial_model_nos(void);

// Set speed limit
void send_speed_limit(Adafruit_MCP2515 mcp, int speed);

// Set wheel circumference
void send_circumference(Adafruit_MCP2515 mcp, int circum);

// Set all settings
void send_settings(Adafruit_MCP2515 mcp);

// Test mode for BLE characteristics. If no packets are received,
// Babelfish (optionally) generates synthetic speed/cadence/power/etc. data.
// Define BLE_TESTMODE here to enable it.

//#define BLE_TESTMODE

// Update all values every 1 second
#define TESTMODE_INTERVAL  1000

// Check for timing on test mode data changes, and return true if anything
// has changed.
int testmode_poll(void);

