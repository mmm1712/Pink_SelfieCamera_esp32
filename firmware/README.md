# ESP32 Firmware

This folder contains the firmware for the Pink Selfie Camera ESP32 project.

The firmware runs on the Seeed XIAO ESP32S3 Sense and controls the camera, round display, microSD storage, local Wi-Fi access point, and sync endpoints.

## Main Responsibilities

The firmware handles:

* Initializing the OV3660 camera module
* Showing a live preview on the round display
* Capturing photos and videos
* Saving media files to the microSD card
* Creating a local Wi-Fi access point
* Running a small local web server
* Providing endpoints for the iPhone app to sync media

## Hardware Target

Main board:

```txt
Seeed XIAO ESP32S3 Sense
```

Main connected parts:

```txt
OV3660 camera module
Seeed round display for XIAO
microSD card
LiPo battery
Power switch
```

## Local Wi-Fi Mode

The camera runs in access point mode.

This means the ESP32 creates its own Wi-Fi network, and the iPhone connects directly to it.

Example public/demo settings:

```cpp
const char* ssid = "PocketCam-0001";
const char* password = "change_this_password";
```

Do not upload private Wi-Fi passwords or personal credentials to GitHub.

## Camera API

The firmware exposes a small local HTTP API.

Example endpoints:

```txt
GET /status.json
GET /photos.json?since=0&limit=12
GET /photo?id=123
GET /latest
GET /videos.json?since=0&limit=1
GET /video?id=5
GET /capture
```

The iPhone app uses these endpoints to check status, list media, download photos/videos, and trigger capture.

## Notes

This firmware is built for a working prototype. The current focus is making the hardware, display, storage, Wi-Fi sync, and iPhone app work together in one small camera.

Future firmware improvements could include:

* Cleaner state machine
* Better video recording stability
* Faster sync
* More reliable reconnect behavior
* Better battery/power handling
* More camera settings
* Improved UI feedback on the round display