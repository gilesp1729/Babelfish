#include <Arduino.h>
#include "Babelfish.h"

// Definitions of motor+controller, and display.
MotorController motor;
Display display;
Settings settings;

// Data structure to retain packet ID's to suppress printing of unchanged data

// The maximum size of a packet as read from the CAN bus
#define DATA_SIZE   16

// Number of distinct packet ID's to be checked on
#define PACKETS     48

// Size of data to be checked.
// May be smaller than DATA_SIZE, to save memory on the 32u4 (only 2.5k bytes!)
#define CHECK_SIZE  8

typedef struct Packet
{
  uint32_t  id;                   // ID of packets in this entry
  uint16_t  repeats;              // How many times this packet ID has been seen
  uint8_t   length;               // Actual length
  uint8_t   check[CHECK_SIZE];    // The first <= CHECK_SIZE bytes of the payload
} Packet;

static Packet packets[PACKETS];
static int num_packets = 0;       // Number of slots in the packet ID array

// Helper to extract two data bytes from a packet.
uint16_t raw_2bytes(uint8_t b0, uint8_t b1)
{
   return ((uint16_t)b1 << 8) | b0;
}

// Format without sprintf's. Format and print.
void format_dec_and_print(uint16_t raw, int places)
{
  uint16_t frac;

   switch (places)
   {
   case 0:
      Serial.print(raw);
      break;
   case 1:
      Serial.print(raw / 10);   // integer part
      Serial.print(F("."));
      Serial.print(raw % 10);   // fractional part is always 1 digit
      break;
   case 2:
      Serial.print(raw / 100);
      Serial.print(F("."));
      frac = raw % 100;
      if (frac < 10)
        Serial.print(F("0"));      // insert the leading zero if frac is 1 digit
      Serial.print(frac);
      break;
   }
}

// Helper to print a wheel size. THe lower nibble is a decimal fraction (not hex)
// e.g. B5 01 = 01B5 = 1Bhex . 5 = 27.5
// Always print to 1 decimal place
void format_wheelsize_and_print(uint16_t raw)
{
   int whole = raw >> 4;
   int frac = raw & 0xF;
   format_dec_and_print(whole * 10 + frac, 1);
}

// Echo the packet length and data, for those packets we wish to 
// respond to.
void echo(uint32_t id, int indx, int packetSize, uint8_t data[])
{
  int i;
  char buf[16];

  Serial.print(millis());
  Serial.print(F(": "));
  Serial.print(id, HEX);
  if (indx >= 0)      // print index in the packet ID array
  {
    Serial.print(F("["));
    Serial.print(indx);
    Serial.print(F("]"));
  }
  Serial.print(F(" "));
  Serial.print(packetSize);

  for (i = 0; i < packetSize; i++)
  {
    Serial.print(F(" "));
    if (data[i] < 16)
      Serial.print(F("0"));
    Serial.print(data[i], HEX);
  }

  // pad out to 8 bytes formatted width
  for ( ; i < 8; i++)
      Serial.print(F("   "));
}

// Echo the tail end of the packet, printing the repeat count if we are
// suppressing repeats, and a new line in any case.
void echo_tail(int verbosity, uint16_t repeats)
{
  if (verbosity == 1)
  {
    Serial.print(F(" ["));
    Serial.print(repeats);
    Serial.print(F("]"));
  }
  Serial.println();
}

// Scan the CAN bus for a packet and interpret it to various
// globals, and (optionally) print it to serial.
//
// mcp        MCP2515 instance
//
// connected      if true, we are connected to a BLE central  
//
// verbosity      0 = don't print any packets
//                1 = print all packets with changed data (suppress repeats)
//                2 = print known packets
//                3 = print all packets.
//
// only_this_id   0 = print all packets according to verbosity
//                !=0 print only packets with this ID
//
// Returns:       1 if a speed packet was received so we can
//                update the BLE characteristics, else 0
//

int scanbus(Adafruit_MCP2515 mcp, bool connected, int verbosity, uint32_t only_this_id)
{
  char buf[16];
  uint32_t id;
  int i;
  uint8_t data[DATA_SIZE];
  uint16_t rpm;
  int rc = false;
  uint16_t reps = 0;

  // weird mapping for 5-level PAS
  uint8_t pas_byte[6] = {0, 0x0B, 0x0D, 0x15, 0x17, 0x03};

  // try to parse packet
  int packetSize = mcp.parsePacket();
  if (!packetSize)
    return false;
  if (packetSize > DATA_SIZE)
    packetSize = DATA_SIZE;

  // received a packet
  if (mcp.packetRtr()) {
    // Remote transmission request, packet contains no data
    Serial.print(F("RTR "));
  }

  id = mcp.packetId();

  if (mcp.packetRtr())
  {
    Serial.print(F(" req length "));
    Serial.println(mcp.packetDlc());
  }
  else
  {
    for (i = 0; mcp.available(); i++)
    {
      if (i >= packetSize)
        break;
      data[i] = (uint8_t)mcp.read();
    }

    // Separate calculation of speed, intervals etc. here, and do the
    // printing (optionally) later on.
    switch (id)
    {
    case 0x02F83200:   // Battery% / Cadence / Torque / Range (this is different from the other docs)
        motor.battery_level = data[0];
        motor.crpm = data[3];
        motor.crank_interval = (motor.crpm == 0) ? 0 : 60000L / motor.crpm;
        motor.range = raw_2bytes(data[6], data[7]);
        break;

    case 0x02F83201:  // Speed/current/voltage/temp
        rc = true;    // Set true return upon every speed packet

        motor.kmh = raw_2bytes(data[0], data[1]);

        // Compute rpm (as integer)
        rpm = (10000L * motor.kmh) / (60L * settings.circ);

        // Compute rev interval (used for updating the CP or CSC characteristics)
        motor.wheel_interval = (rpm == 0) ? 0 : 60000L / rpm;

        motor.amps = raw_2bytes(data[2], data[3]);
        motor.volts = raw_2bytes(data[4], data[5]);

        // Compute power in watts
        motor.power = ((long)motor.volts * motor.amps) / 10000L;

        motor.ctrlr_temp = data[6];
        motor.motor_temp = data[7];
        break;

    case 0x02F83203:  // Speedlimit/wheelsize/circumference
        settings.limit = raw_2bytes(data[0], data[1]);
        settings.wheel_size = raw_2bytes(data[2], data[3]);
        settings.circ = raw_2bytes(data[4], data[5]);
        break;

    // Messages from the display.

    case 0x03106300:  // PAS Level/light setop
        for (i = 0; i < 6; i++)
        {
          if (data[1] == pas_byte[i])   // TODO What if #levels is not 5?
            break;
        }
        motor.pas = i;
        break;

    case 0x03106301:  // odo/trip/max speed
        display.odo = raw_2bytes(data[0], data[1]);   // these may be 3-byte quantities;
        display.trip = raw_2bytes(data[3], data[4]);  // we only retain 2 bytes
        display.max_speed = raw_2bytes(data[6], data[7]);
        break;

    case 0x03106302:  // average/copy of odo (not used)
        display.avg_speed = raw_2bytes(data[0], data[1]);
        break;
    }

    // If not logging anything, stop here.
    if (verbosity == 0)
      return rc;

    // Restrict logging to one specified packet.
    if (only_this_id != 0 && id != only_this_id)
      return rc;

    // Optionally, determine if the packet has been seen before.
    i = -1;
    if (verbosity == 1)
    {
        bool found = false;
        int check_count;

        // Check if packet has been seen before, and if so, whether its data has changed.
        // Some packet ID's have data changes that are not relevant to us (e.g. voltage)
        // so we set a check count for them rather than comparing the whole packet.
        switch (id)
        {
          case 0x02F83201:
            // Speed packet: only check first 4 bytes (ignore voltage and temps)
            check_count = 4;
            break;
          default:
            check_count = CHECK_SIZE;
        }

        // In any event limit to packet size for short packets
        if (packetSize < check_count)
          check_count = packetSize;

        // Check for packet found in array
        for (i = 0; i < num_packets; i++)
        {
          if (id == packets[i].id)
          {
            found = true;
            break;
          }
        }

        if (found)
        {
          bool changed = false;

          // Check the data and skip printing if unchanged
          if (packets[i].length != packetSize)
          {
            changed = true;
          }
          else
          {
            for (int j = 0; j < check_count; j++)
            {
              if (packets[i].check[j] != data[j])
              {
                changed = true;
                break;
              }
            }
          }

          // No change, just return. Always set rc on speed packet (see above)
          if (!changed)
          {
            packets[i].repeats++;
            return rc;
          }
        }

        // Store the new/changed data, and bump num_packets if we are adding
        // a new packet for the first time
        if (i == num_packets)
        {
          // Avoid overflowing the array
          if (num_packets >= PACKETS)
          {
            Serial.println(F("Packet array overflow!!"));
            return rc;
          }

          // Store a new packet type
          packets[i].id = id;
          packets[i].repeats = 1;
          num_packets++;
        }
        else
        {
          packets[i].repeats++;
        }
        packets[i].length = packetSize;
        for (int j = 0; j < check_count; j++)
          packets[i].check[j] = data[j];

        // Repeat count to be printed later
        reps = packets[i].repeats;
    }

    // If we know something about this packet ID, print it. The derived values
    // have been calculated above.
    // These are mostly ctrl -> disp
    switch (id)
    {
    case 0x02F83200:   // Battery% / Cadence / Torque / Range (this is different from the other docs)
        echo(id, i, packetSize, data);

        Serial.print(F(" Battery "));
        Serial.print(motor.battery_level, DEC);
        Serial.print(F("% "));

        Serial.print(F("Cadence "));
        Serial.print(motor.crpm, DEC);
        Serial.print(F("rpm "));
        Serial.print(F("("));
        Serial.print(motor.crank_interval);
        Serial.print(F("ms) "));

        Serial.print(F("Range "));
        format_dec_and_print(motor.range, 2);
        Serial.print(F("km"));
        echo_tail(verbosity, reps);
        break;

    case 0x02F83201:  // Speed/current/voltage/temp
        echo(id, i, packetSize, data);

        Serial.print(F(" Speed "));
        format_dec_and_print(motor.kmh, 2);
        Serial.print(F("km/h "));

        Serial.print(F("("));
        Serial.print(rpm);
        Serial.print(F("rpm "));
        Serial.print(motor.wheel_interval);
        Serial.print(F("ms) "));

        Serial.print(F("Motor "));
        format_dec_and_print(motor.amps, 2);
        Serial.print(F("amps "));
        format_dec_and_print(motor.volts, 2);
        Serial.print(F("volts "));

        Serial.print(F("("));
        Serial.print(motor.power);
        Serial.print(F("W) "));

        Serial.print(F("Temps ctrl "));
        Serial.print(motor.ctrlr_temp - 40);
        Serial.print(F(" motor "));
        Serial.print(motor.motor_temp - 40);
        echo_tail(verbosity, reps);
        break;

    case 0x02F83203:  // Speedlimit/wheelsize/circumference
        echo(id, i, packetSize, data);

        Serial.print(F(" Speed limit "));
        format_dec_and_print(settings.limit, 2);
        Serial.print(F("km/h "));

        // Wheel size is special: bottom nibble is a decimal place, not hex
        // e.g. B5 01 = 01B5 = 1Bhex . 5 = 27.5 inches
        Serial.print(F("Wheel size "));
        format_wheelsize_and_print(settings.wheel_size);
        Serial.print(F("in "));

        Serial.print(F("Circum "));
        Serial.print(settings.circ);
        Serial.print(F("mm"));
        echo_tail(verbosity, reps);
        break;

    // Messages from the display. These do not appear to be going anywhere (although
    // their destination is controller) as trip, odo, etc. seem to be managed in
    // the display, and other displays (e.g. OpenSouceEBike) do not send them

    // The PAS level/light packet is the only one that needs to be sent every 100-150ms,
    // otherwise the motor will switch off.
    case 0x03106300:  // PAS Level/light setop
        echo(id, i, packetSize, data);
        
        Serial.print(F(" #levels "));
        Serial.print(data[0], DEC);
        Serial.print(F(" level byte "));
        Serial.print(data[1], DEC);
        Serial.print(F(" (PAS "));
        Serial.print(motor.pas, DEC);
        Serial.print(F(") light? "));
        Serial.print(data[2], DEC);
        Serial.print(F(" on/off? "));
        Serial.print(data[3], DEC);
        echo_tail(verbosity, reps);
        break;

    case 0x03106301:  // odo/trip/max speed. We only retain and print 2 bytes (they might be 3 byte quantities)
        echo(id, i, packetSize, data);

        Serial.print(F(" Odometer "));
        format_dec_and_print(display.odo, 0);
        Serial.print(F("km"));
        Serial.print(F(" trip "));
        format_dec_and_print(display.trip, 1);
        Serial.print(F("km"));
        Serial.print(F(" max speed "));
        format_dec_and_print(display.max_speed, 1);
        Serial.print(F("km/h"));

        echo_tail(verbosity, reps);
        break;

    case 0x03106302:  // avg speed/copy of odo (not used)
        echo(id, i, packetSize, data);

        Serial.print(F(" Average speed "));
        format_dec_and_print(display.avg_speed, 1);
        Serial.print(F("km/h"));
        echo_tail(verbosity, reps);
        break;

    default:
        if (verbosity == 1 || verbosity == 3)   // printing all packets, not just known ID's
        {
          echo(id, i, packetSize, data);
          for (i = 0; i < packetSize; i++)
          {
            Serial.print(F(" "));
            Serial.print((char)data[i]);        // Print any ASCII characters such as version numbers
          }

          echo_tail(verbosity, reps);
        }
        break;
    }
  }

  return rc;
}

// Send a speed limit/wheel size/circumference packet with a
// changed speed limit. Speed should be 25, 35 or 45. The other
// fields are copied from the speed limit packet(s) read in
// so far.
void send_speed_limit(Adafruit_MCP2515 mcp, int speed)
{
  uint8_t data[8];
  int i;
Serial.println(speed);
  if (speed < 25)     // some sanity checks
    speed = 25;
  else if (speed > 45)
    speed = 45;

  speed *= 100;

  data[0] = speed & 0xFF;
  data[1] = (speed >> 8) & 0xFF;
  data[2] = settings.wheel_size & 0xFF; 
  data[3] = (settings.wheel_size >> 8) & 0xFF;
  data[4] = settings.circ & 0xFF;
  data[5] = (settings.circ >> 8) & 0xFF;

  // DEBUG: Write out the packet to serial in hex.
  for (i = 0; i < 6; i++)
  {
    if (data[i] < 0x10)
      Serial.print(F("0"));
    Serial.print(data[i], HEX);
    Serial.print(F(" "));
  }
  Serial.println();

#if 0 // Nobble this for testing
  mcp.beginExtendedPacket(0x05103203);
  for (i = 0; i < 6; i++)
    mcp.write(data[i]);
  mcp.endPacket();
#endif
}

// Send a speed limit/wheel size/circumference packet with a
// changed circumference in mm.
void send_circumference(Adafruit_MCP2515 mcp, int circum)
{
  uint8_t data[8];
  int i;

  data[0] = settings.limit & 0xFF;
  data[1] = (settings.limit >> 8) & 0xFF;
  data[2] = settings.wheel_size & 0xFF;
  data[3] = (settings.wheel_size >> 8) & 0xFF;
  data[4] = circum & 0xFF;
  data[5] = (circum >> 8) & 0xFF;

  // DEBUG: Write out the packet to serial in hex.
  for (i = 0; i < 6; i++)
  {
    if (data[i] < 0x10)
      Serial.print(F("0"));
    Serial.print(data[i], HEX);
    Serial.print(F(" "));
  }
  Serial.println();

  mcp.beginExtendedPacket(0x05103203);
  for (i = 0; i < 6; i++)
    mcp.write(data[i]);
  mcp.endPacket();
}

// Send a speed limit/wheel size/circumference packet from the
// new settings (received from connected central)
void send_settings(Adafruit_MCP2515 mcp)
{
  uint8_t data[8];
  int i;

  data[0] = settings.new_limit & 0xFF;
  data[1] = (settings.new_limit >> 8) & 0xFF;
  data[2] = settings.new_wheel & 0xFF; 
  data[3] = (settings.new_wheel >> 8) & 0xFF;
  data[4] = settings.new_circ & 0xFF;
  data[5] = (settings.new_circ >> 8) & 0xFF;

  // DEBUG: Write out the packet to serial in hex.
  for (i = 0; i < 6; i++)
  {
    if (data[i] < 0x10)
      Serial.print(F("0"));
    Serial.print(data[i], HEX);
    Serial.print(F(" "));
  }
  Serial.println();

#if 0 // Nobble this for testing
  mcp.beginExtendedPacket(0x05103203);
  for (i = 0; i < 6; i++)
    mcp.write(data[i]);
  mcp.endPacket();
#endif
}
