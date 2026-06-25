# Sync Flow

PocketCam syncs photos from the ESP32 camera to the iPhone app over a local Wi-Fi connection.

The camera does not need internet, a router, or cloud storage. The ESP32 creates its own Wi-Fi network, and the iPhone connects directly to it.

## Basic Flow

```txt
PocketCam powers on
      ↓
ESP32S3 starts camera + round display
      ↓
Photos/videos are saved to microSD
      ↓
ESP32S3 creates a local Wi-Fi access point
      ↓
iPhone connects to the PocketCam Wi-Fi network
      ↓
SwiftUI app talks to the ESP32 local web server
      ↓
App downloads photos/videos into the phone gallery
```

## Local Wi-Fi

The ESP32S3 runs in access point mode.

That means the camera creates its own Wi-Fi network instead of connecting to a home router.

Example:

```txt
Wi-Fi name: PocketCam-0001
Password: change_this_password
IP address: 192.168.10.1
```

## Local Web Server

The ESP32 hosts a small local HTTP server.

The iPhone app uses simple endpoints to check camera status, list saved files, and download media.

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

## Photo Sync

Photos are saved to the microSD card first.

Then the iPhone app asks the camera which files are available, downloads the new ones, and shows them in a gallery.

```txt
Photo captured
      ↓
Saved to microSD
      ↓
Listed by ESP32 web server
      ↓
Downloaded by iPhone app
      ↓
Displayed in SwiftUI gallery
```

## Why This Design

I chose local Wi-Fi sync because it keeps the project simple and portable.

Benefits:

* No internet required
* No cloud account required
* Photos stay local unless synced
* The camera can work anywhere
* The iPhone app can communicate directly with the hardware

## Current Prototype Notes

This sync system is designed for a small DIY prototype. It works well for local photo transfer, but it is not meant to be a high-speed production camera system.

Future improvements could include faster sync, better file indexing, progress indicators, and more reliable reconnect behavior.
