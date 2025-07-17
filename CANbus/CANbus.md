# CANbus traffic

## Summary

Everything (mostly!) we currently know about the Bafang CANBUS protocol. This builds on the good work of CiDi and casainho (OpenSourceEBike) and also from tomblarom on EndlessSphere. [GIVE SOME LINKS HERE]

I have not copied everything of theirs but only include stuff I have actually seen. Some differences may be due to software versions changing along the way.

## Pinout

There is some confusion of colours and also of signal names. My after-market cables used different colours to the standard Bafang ones. The signal names here are those of  OpenSourceEBike. [CHECK THIS TO BE SURE]

```
HIGO-S5-F (This is a female: the male is HIGO-B5-F)
    ────────┐
 /    1   5 │
│ 2         │
 \    3   4 │
    ────────┘
1 Orange   : Ctrl (ground this thru 470R resistor to power on)
2 White    : CanL
3 Brown    : P+/VBAT (rises to full battery voltage when on)
4 Green    : CanH
5 Black    : GND
```

[INCLUDE A SCHEMATIC HERE]

##### Level matching

The motors can have 3, 5 or 9 PAS levels. The mapping between the level number and the byte sent to the controller is given here. This byte is sent from the display in a Level/Light Setup packet.

| L9   | L5   | L3   | Byte |
| ---- | ---- | ---- | ---- |
| Walk | Walk | Walk | 06   |
| 0    | 0    | 0    | 00   |
| 1    |      |      | 01   |
| 2    | 1    |      | 0B   |
| 3    |      | 1    | 0C   |
| 4    | 2    |      | 0D   |
| 5    |      | 2    | 02   |
| 6    | 3    |      | 15   |
| 7    |      |      | 16   |
| 8    | 4    |      | 17   |
| 9    | 5    | 3    | 03   |

## Messages from Controller to Display

##### % Battery/Level Information

```
Decoding example: 02F83200 8 32 00 00 00 EE 02 2C 27
ID: 0x02F83200
Numbers Byte: 8
% Battery Byte 0        : 50%(0x32) = 32
Byte 1/2/3              : 00 00 00
Byte 4                  : EE = these have something to do with torque sensor.
Byte 5                  : 02
Range Byte 6/7          : 2C 27 -> 0x272C = 10028 = 100.28km
```

##### Speed/Current/Voltage/Temperature Information

```
Decoding example: 02F83201 8 C4 09 E8 03 E2 14 32 3C
ID: 02F83201
Numbers Byte: 8
Speed Byte   1/0    : C4 09 -> 0x09C4 = 2500 => 25.00km/h
Current Byte 3/2    : E8 03 -> 0x03E8 = 1000 => 10.00A
Voltage Byte 5/4    : E2 14 -> 0x14E2 = 5346 => 53.46V
Temp. Control. Byte 6 : 32    -> 0x32   = 50   -> 50 - 40 = 10 => 10°C
Temp. Motor Byte 7    : 3C    -> 0x3C   = 60   -> 60 - 40 = 20 => 20°C

Little-Endian byte order!
```

##### Speed limit/Wheel size/Circumference Information

```
Decoding example: 02F83203 6 70 17 B5 01 C0 08
ID: 02F83203
Speed Limit Byte   1/0 : 70 17 -> 0x1770              = 6000   => 60.00km/h
Wheel Size Byte    3/2 : B5 01 -> 0x01B5 -> 0x01B . 5 = 27 . 5 => 27.5"
Circumference Byte 5/4 : C0 08 -> 0x08C0              = 2240   => 2240mm

Decoding example: 02F83203 6 C4 09 D0 01 C0 08
ID: 02F83203
Speed Limit Byte   1/0 : C4 09 -> 0x09C4              = 2500   => 25.00km/h
Wheel Size Byte    3/2 : D0 01 -> 0x01D0 -> 0x01D . 0 = 29 . 0 => 29.0"
Circumference Byte 5/4 : E8 08 -> 0x08E8              = 2280   => 2280mm


```

##### State Information

```
ID: 02FF1200
Numbers Byte: 1
Bit0 Brake state          : 1=Brake
Bit1 Motor stopped        : 1=Stopped
Bit2 Battery undervoltage : 1=Undervoltage
```

### Messages from Display to Controller

Apart from the Level/Light Setup, these appear to have no purpose since the odometer, trip, average and max speeds are maintained purely in the display. But an eavesdropper on the bus can still access them when used with a Bafang display.

##### HMI Level/Light Setup

This packet must be sent from the display every 100-150ms. Most motors are programmed with 5 levels.

```
Decoding example: 03106300 4 05 0B 00 00
ID: 03106300
Numbers Byte: 4
Levels number Byte 0    : 03 / 05 / 09
Set Level Byte 1        : As per the level matching table above.
Button "+" Byte 2          : Off = 00 / On = 02 / Off with light = 01 / On with light = 03
Boost mode Byte 3        : Off = 01 / On = 00 (after two seconds of pressing the power button)
```

##### Odometer/Trip/Max Speed

The odometer and trip may be 3-byte quantities (we won't know until we get a high mileage bike!). Resetting the trip zeroes out the trip and max speed fields.

```
Decoding example: 03106301 8 46 01 00 A2 01 00 60 01
ID: 03106301
Numbers Byte: 8
Odometer Byte 1/0 (or 2/1/0)  : 46 01 00 -> 0x0146 => 326 km
Trip Byte 4/3 (or 5/4/3)      : A2 01 00 -> 0x01A2 = 419 => 41.9 km
Max speed Byte 7/6            : 60 01 -> 0x0160 = 352 = > 35.2 km/h
```

##### Average Speed

Resetting the trip zeroes out the average speed field. I'm not sure why the odometer value is copied in here.

```
Decoding example: 03106302
ID: 03106302
Numbers Byte: 5

```

## CAN messages during operations

##### HMI

```
03106300 every 100ms
03106301, 02, 03 approximately every 100ms too
```



##### Controller (Only with the presence of the HMI or BESST)

```
02F83200 every 1500ms
02F83201 every 280ms
02F83202 every 100ms
02F83203 every 450ms
02FF1200 every 490ms
```

## Known working CANBUS commands

These may be sent from a display, BESST, or an eavesdropper to change the motor parameters. The sender ID must be BESST (05xxxx)

##### BESST Speed/Wheel/Circumference Setup

```
Decoding example: 05103203 6 70 17 B5 01 C0 08
ID: 05103203
Speed Limit Byte   1/0    : 70 17 -> 0x1770              = 6000   => 60.00km/h
Wheel Size Byte    3/2    : B5 01 -> 0x01B5 -> 0x01B . 5 = 27 . 5 => 27.5"
Circumference Byte 5/4    : C0 08 -> 0x08C0              = 2240   => 2240mm

Decoding example: 05103203 6 C4 09 D0 01 E8 08
ID: 05103203
Speed Limit Byte   1/0    : C4 09 -> 0x09C4              = 2500   => 25.00km/h
Wheel Size Byte    3/2    : D0 01 -> 0x01D0 -> 0x01D . 0 = 29 . 0 => 29.0"
Circumference Byte 5/4    : E8 08 -> 0x08E8              = 2280   => 2280mm
```
