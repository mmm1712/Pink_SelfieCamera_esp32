# Wiring Notes

This project is built as a compact battery-powered prototype, so the wiring is intentionally simple.

The main wired parts are the LiPo battery, slide power switch, Seeed XIAO ESP32S3 Sense, round display, camera module, and microSD storage.

## Round Display

The camera uses a Seeed round display for XIAO as the main screen.

The round display shows the live camera preview, so the camera feels like a real small device instead of just an ESP32 saving photos in the background.

Because the display sits in the front opening of the enclosure, the internal wiring needs to stay clear of the display area. The wires should be routed so they do not press against the display, block the camera opening, or stop the back cover from closing.

## Power Switch

The camera is powered by a LiPo battery. I added a small slide switch so the camera can be turned on and off without unplugging the battery.

The basic idea:

```txt
LiPo Battery +
      ↓
Slide Switch
      ↓
XIAO ESP32S3 battery/power input
```

Only the positive power wire is switched. The ground wire stays connected.

## Simple Switch Wiring

```txt
Battery red wire   → switch pin 1
Switch pin 2       → board power input
Battery black wire → board ground
```

The switch works like a small gate:

* **ON**: power flows to the board
* **OFF**: power is disconnected

## Camera and microSD

The camera module connects to the XIAO ESP32S3 Sense and is used for live preview, photo capture, and video capture.

Photos and videos are saved to the microSD card first. The iPhone app can then connect over local Wi-Fi and sync the saved files from the camera.

## Insulation

After soldering the switch wires, I covered the exposed solder joints with heat tape / insulation tape to reduce the chance of shorts inside the case.

Because the enclosure is small, the wires can easily touch the board, battery, display module, or camera module. Covering exposed metal is important.

## Internal Wiring Notes

The final enclosure has limited space, so the wiring needs to be:

* Short enough to fit inside the case
* Flexible enough to close the back cover
* Insulated anywhere metal is exposed
* Routed away from the round display and camera opening when possible
* Placed so it does not press too hard against the battery or display

## Current Prototype Notes

This wiring is part of the prototype version. A future version could use a custom PCB to reduce loose wires and make assembly cleaner.