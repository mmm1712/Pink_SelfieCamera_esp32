# 3D Printed Enclosure

This folder contains the 3D printed enclosure files for the Pink Selfie Camera ESP32 project.

The enclosure was designed to make the camera feel more like a real small product instead of a loose electronics prototype.

## Design Goals

The case was designed around:

* Seeed XIAO ESP32S3 Sense
* OV3660 camera module
* Seeed round display for XIAO
* LiPo battery
* Slide power switch
* Internal wiring
* Screw bosses and back cover

The main goal was to fit all electronics inside a small pink camera-style enclosure while keeping the round display and camera opening visible from the front.

## Folder Structure

```txt
enclosure/
├── README.md
├── openscad/
│   └── .scad files
└── stl/
    └── .stl files
```

## OpenSCAD Files

The `openscad/` folder contains the editable CAD source files.

Use these files if you want to modify the case design, adjust tolerances, change screw boss length, or update the internal layout.

## STL Files

The `stl/` folder contains exported 3D printable files.

Use these files if you just want to print the enclosure without editing the OpenSCAD design.

## Enclosure Features

* Round display opening
* Camera/lens opening
* Back cover
* Screw bosses
* Battery space
* Power switch opening
* Internal room for the XIAO ESP32S3 Sense
* Space for wires and insulation
* Small product-style shape

## Print Notes

This is a compact enclosure, so small tolerance differences can matter.

Recommended checks after printing:

* Make sure the round display fits
* Make sure the camera opening is clear
* Check that the back cover closes
* Check that screw bosses are not too tight
* Make sure the switch opening is usable
* Confirm the battery is not squeezed

## Prototype Notes

The enclosure went through multiple design changes to improve fit, back cover alignment, screw bosses, display opening, lens opening, and internal hardware placement.

This version is still a prototype, so small adjustments may be needed depending on printer calibration, filament, screws, and final hardware placement.
