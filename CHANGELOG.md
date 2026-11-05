# Changelog

All notable changes to this project will be documented in this file.

## 1.1.0

* **Hardware Significant Motion Sensor**: Integrated `Sensor.TYPE_SIGNIFICANT_MOTION` to wake up high-accuracy GPS on physical movement while allowing 100% deep sleep overnight (< 1–2% battery consumption).
* **Moving WakeLock & Worker Thread**: Run location updates on a dedicated background `HandlerThread` (`CustomBgLocationThread`) with safe movement `WakeLock` to guarantee complete road curve tracking during bike and vehicle trips with screens locked in pockets.
* **Road-Adaptive Accuracy Quality Gate**: Enhanced accuracy filter allowing fixes up to 80m during motion (`speed > 1.0 m/s`), preventing valid road coordinates from being dropped during cellular/satellite transitions.
* **Persistent Outage Tracking**: Added permanent `isOutage` / `wasOffline` tagging so locations saved during offline periods remain identified as outages even after reconnecting and syncing.
* **Interactive Route & Outage Map**: Integrated OpenStreetMap (`flutter_map`) visualizer in the example app with color-coded paths (Amber for Outage/Odometer, Blue for Live Online), interactive markers, and odometer inspectors.
* **Nighttime Heartbeat Throttling**: Automatically reduced stationary heartbeats to prevent excessive flash disk I/O and battery drain while at rest.
* **Defaulted to Field Mode**: Updated default example configuration to enable automated stationary sleep and movement auto-wake.
* **Documentation & Screenshots**: Overhauled `README.md` with visual architecture diagrams, real-world screenshots, and streamlined quick-start guides.

## 1.0.1

* Enhanced documentation with visual state diagrams and real-world condition mockups.
* Streamlined 1-line quickstart API examples.
* Sanitized package configuration and confirmed publisher setup.

## 1.0.0

* Initial release of `custom_background_geolocation`.
* Native Android foreground service with `START_STICKY` protection.
* Native iOS `CLLocationManager` background execution and Significant Location Changes (SLC).
* On-device SQLite persistence for offline location queuing and batch synchronization.
* Integrated motion activity transitions (still, walking, running, in-vehicle).
* Circular stationary geofence auto-management to eliminate GPS battery drain while at rest.
* One-line developer API (`CustomBackgroundGeolocation.quickStart` and `.listen`).
* Built-in diagnostic logging and email log export.
