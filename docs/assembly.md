# Assembly Guide

This is a simple assembly guide for the Pink Selfie Camera ESP32 prototype.

The exact fit may change depending on the 3D print version, but this shows the general order of assembly.

## 1. Prepare the 3D Printed Parts

Print the main enclosure parts:

* Front shell
* Back cover
* Any separate decorative or support parts

Before adding electronics, check that:

* The round display fits into the front opening
* The camera/lens opening is clear
* The back cover can close
* Screw bosses are clean
* The power switch opening is not blocked

## 2. Install the Round Display

Place the Seeed round display into the front opening of the enclosure.

Make sure:

* The display is centered
* The screen is visible through the round opening
* The display is not pressed too tightly
* The wiring has space behind it

The round display is one of the main visual parts of the camera, so this fit is important.

## 3. Place the Camera Module

Position the OV3660 camera module behind the lens opening.

Check that:

* The camera is aligned with the front opening
* The lens is not blocked by the case
* The camera cable is not bent too sharply
* The preview is not rotated or angled incorrectly

## 4. Place the XIAO ESP32S3 Sense

Place the XIAO ESP32S3 Sense inside the enclosure.

Make sure there is enough space for:

* Camera connection
* Round display connection
* microSD card access
* Battery wiring
* Power switch wiring

## 5. Add the Battery

Place the LiPo battery inside the battery area.

Make sure:

* The battery is not squeezed too tightly
* Wires are not pulled
* Nothing sharp is pressing into the battery
* The back cover can still close

## 6. Wire the Power Switch

Connect the slide switch to the battery positive wire.

Basic wiring:

```txt
Battery red wire   → switch pin 1
Switch pin 2       → board power input
Battery black wire → board ground
```

Only the positive wire is switched. The ground wire stays connected.

After soldering, cover the exposed joints with heat tape or insulation tape.

## 7. Check Internal Fit

Before closing the case, check that:

* The display is still centered
* The camera module is aligned
* Wires are not blocking the display or lens
* The battery is not being crushed
* The power switch moves freely
* The back cover can close without force

## 8. Close the Back Cover

Carefully close the back cover and secure it with screws.

Do not overtighten the screws, especially if the screw bosses are 3D printed.

## 9. Power On Test

Turn on the camera and check:

* The round display turns on
* Live preview appears
* The camera can capture a photo
* Files are saved to microSD
* The Wi-Fi network appears
* The iPhone app can connect and sync photos

## Notes

This is still a prototype assembly. Some parts may need small tolerance adjustments depending on the printer, filament, screw size, and final enclosure version.

A future version could use a custom PCB to make the inside cleaner and easier to assemble.