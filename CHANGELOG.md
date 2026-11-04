# Changelog

All notable changes to this project will be documented in this file.

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
