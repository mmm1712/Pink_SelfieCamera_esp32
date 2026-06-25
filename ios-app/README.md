# iPhone App

This folder contains the iPhone companion app for the Pink Selfie Camera ESP32 project.

The app was built with SwiftUI and is used to connect to the camera, sync photos, show them in a gallery, apply filters, and run an on-device Enhance feature.

## What the App Does

The app can:

* Connect to the PocketCam Wi-Fi network
* Check the ESP32 camera status
* List saved photos and videos
* Sync new photos from the camera
* Display synced photos in a gallery
* Apply photo filters
* Run an on-device Enhance feature using a compact Real-ESRGAN Core ML model

## How It Connects

The camera creates its own local Wi-Fi network.

The iPhone connects directly to that network, then the app communicates with the ESP32 through local HTTP endpoints.

Example camera address:

```txt
http://192.168.10.1
```

Example endpoints used by the app:

```txt
/status.json
/photos.json
/photo?id=123
/latest
/videos.json
/video?id=5
/capture
```

## On-Device Enhance

The app includes an Enhance feature using a compact Real-ESRGAN Core ML model.

This runs locally on the iPhone. It does not require internet or cloud processing.

I integrated the Core ML model into the app, but I did not train Real-ESRGAN from scratch.

## Current Prototype Notes

This app is a companion app for the hardware prototype, not a full production App Store camera app.

Future app improvements could include:

* More polished UI
* Better sync progress indicators
* Faster thumbnail loading
* More reliable reconnect behavior
* Better photo/video organization
* Settings screen for camera options
* Cleaner delete/select flow
