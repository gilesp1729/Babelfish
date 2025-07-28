# Babelfish

## Translate Bafang CAN Bus to BLE: a Bafang Go+ replacement

Bafang’s Bluetooth phone app, **Bafang Go+**, allows real-time speed, map, power, etc. to be displayed, and also for certain motor settings to be changed. However, its BLE protocol is proprietary, and it requires **privileges** on the phone that are unreasonable, as well as requiring logging on to anonymous servers somewhere and “phoning home” with who knows what personal data.

**Babelfish** translates between CAN bus packets and standard BLE characteristics for cycle power, speed and cadence. These can be read with many cycling apps, such as **SuperCycle**, which requires no login, personal data or off-device storage.

Babelfish also exposes custom characteristics for the companion phone app, to display assist level, trip and odometer, battery current and temperatures, and to allow viewing and changing motor settings, such as speed limit and wheel size.

While plugged into USB, Babelfish has different levels of logging CAN bus packets. 

## Versions

Version 1 is current. It sits on the CAN bus between motor controller and display and simply eavesdrops on the CAN bus. The Babelfish phone app is upcoming.

Version 2 is upcoming. It acts as a replacement display, simplifying wiring and allowing more control. Supported hardware, display type and phone app support is TBD (the current 32u4 is very tight on memory...)

## Hardware and libraries required

Babelfish V1 runs on an Adafruit Bluefruit LE 32u4 with its companion CAN bus transceiver (MCP2515). To run on the bike it also needs a switching regulator to step the 48V battery voltage down to 5V. The two boards can be stacked or run on a doubler.

Libraries used are Adafruit_BluefruitLE_nRF51 and Adafruit_MCP2515. Follow Adafruit's directions to load their additional boards manager URL.

The Babelfish Android app is being developed using B4A.
