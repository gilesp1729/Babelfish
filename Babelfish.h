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
  uint16_t limit;           // speed limit in km/h*100
  uint16_t circ;            // wheel circumference in mm
  int battery_level;        // in %
  uint8_t pas;              // PAS level (0-5)
  uint8_t motor_temp;       // Motor temp in degC + 40
  uint8_t ctrlr_temp;       // Controller temp is degC + 40

  // Derived values for the CP service
  uint32_t wheel_interval;  // in half-ms
  uint16_t crank_interval;  // in ms
  uint16_t power;           // in watts
};

// these fields are managed by the display. They are sent to the motor
// but do not appear to be needed.
typedef struct Display
{
  uint16_t odo;             // odometer in km/h
  uint16_t avg_speed;       // average speed in km/h*10
  uint16_t max_speed;       // maximum speed in km/h*10
  uint16_t trip;            // trip distamce in km*10
};

// Scanning bus and logging packets.

// mcp        The MCP2515 instance.
// connected  Whether connected to a BLE central
// verbosity  0 = don't print any packets
//            1 = print all packets with changed data (suppress repeats)
//            2 = print known packets
//            3 = print all packets.
int scanbus(Adafruit_MCP2515 mcp, bool connected, int verbosity);

// Print serial and model numbers of controller
void print_serial_model_nos(void);

// Set speed limit
void set_speed_limit(int lim);

// Set wheel size
void set_wheel_size(float wheelsize);

// Set wheel circumference
void set_wheel_circ(int circum);

// Set PAS level (0-5)
void set_PAS_level(int pas);



