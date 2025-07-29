#include <Arduino.h>
#include "Babelfish.h"

// Test mode for BLE characteristics. If no packets are received,
// Babelfish (optionally) generates synthetic speed/cadence/power/etc. data.

#ifdef TEST_MODE

static uint32_t last_test_time = 0;

int testmode_poll(void)
{
  uint32_t time_now = millis();
  uint16_t rpm;

  if (time_now > last_test_time + TESTMODE_INTERVAL)
  {
    last_test_time = time_now;

    // Give reasonable numbers, and make sure we test the field's
    // expected number of digits. Watch the multipliers (*10, *100)
    motor.kmh = 50 * 100;
    motor.crpm = 100;
    motor.range = 50 * 100;
    motor.volts = 48 * 100;
    motor.amps = 6 * 100;
    motor.battery_level = 95;
    motor.pas = 3;
    motor.motor_temp = 25 + 40;  // temps are in degC + 40
    motor.ctrlr_temp = 25 + 40;

    display.odo = 100;
    display.avg_speed = 20 * 10;
    display.max_speed = 30 * 10;
    display.trip = 20 * 10;

    settings.limit = 25 * 100;
    settings.wheel_size = 29 << 4;
    settings.circ = 2312;

    // recompute the derived values
    motor.power = ((long)motor.volts * motor.amps) / 10000L;
    motor.crank_interval = (motor.crpm == 0) ? 0 : 60000L / motor.crpm;
    rpm = (10000L * motor.kmh) / (60L * settings.circ);
    motor.wheel_interval = (rpm == 0) ? 0 : 60000L / rpm;

    return 1;
  }

  return 0;  
}

#endif