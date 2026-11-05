# custom_background_geolocation

[![pub package](https://img.shields.io/pub/v/custom_background_geolocation.svg?color=blue)](https://pub.dev/packages/custom_background_geolocation)
[![likes](https://img.shields.io/pub/likes/custom_background_geolocation)](https://pub.dev/packages/custom_background_geolocation)
[![popularity](https://img.shields.io/pub/popularity/custom_background_geolocation)](https://pub.dev/packages/custom_background_geolocation)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/sunil-singh-chaudhary/custom-background-geolocation/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-orange.svg)](https://pub.dev/packages/custom_background_geolocation)

A production-grade, zero-battery-drain background geolocation, odometer, and geofencing engine for Flutter. Built from the ground up natively in **Kotlin (Android)** and **Swift (iOS)** with hardware motion sensing, offline SQLite persistence, and locked-screen bike/vehicle tracking guarantees.

---

```text
┌───────────────────────────────────────────────────────────────────────────┐
│  🗺️ Live Route, Odometer & Outage Visualizer                              │
├───────────────────────────────────────────────────────────────────────────┤
│  Legend: 🟠 Outage Path (Saved by Odometer)   🔵 Online Path (Live GPS)   │
│ ───────────────────────────────────────────────────────────────────────── │
│                                                                           │
│    [🟢 Start: 0.00 km]                                                    │
│          \                                                                │
│           \══════🔵 Live Online Fixes (Wi-Fi Connected)══════╗            │
│                                                              ║            │
│       [Elevator / Basement / Wi-Fi Outage Starts]            ║            │
│       ════════════════🟠 Tracked by Odometer═════════════════╝            │
│             \                                                             │
│              \══════🔵 Internet Restored & Auto-Synced══════► [🔴 Destination]
│                                                                           │
├───────────────────────────────────────────────────────────────────────────┤
│  Fix #74 • ⚠️ OUTAGE POSITION • SAVED BY ODOMETER                         │
│  📏 Odometer: 9.05 km  •  ⚡ Speed: 34.2 km/h  •  🎯 ±12m  •  🔋 85%       │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Why Use This Plugin?

* **⚡ 1-Line Quick Start**: Launch native background tracking and listen to live updates in **one line of code**.
* **🔋 Ultra-Low Overnight Battery Drain**: Uses hardware **Significant Motion Sensors (`Sensor.TYPE_SIGNIFICANT_MOTION`)** and 25m stationary geofences. When stationary at home or office, high-power GPS shuts down completely (CPU deep sleeps with **< 1–2% battery consumption overnight**).
* **🛣️ Pocket & Bike Tracking Guarantee**: Dedicated background worker thread (`HandlerThread`) and moving `WakeLock` ensure 100% road curve fidelity when riding a bike or driving with the phone locked in your pocket.
* **🔴 Offline & Outage Persistence**: Traveling through tunnels, subways, basements, or flight mode with Wi-Fi/Cellular OFF? All coordinates and odometer distances are atomically recorded into native SQLite with permanent outage tags (`isOutage = true`), auto-syncing as soon as connectivity returns.
* **📏 Pre-Computed Metrics**: Built-in `odometerKm`, `speedKmH`, `speedMph`, `batteryPercent`, and `coordinates` formatted to 6 decimals — zero boilerplate math required.
* **🗺️ Interactive Map Support**: Includes plug-and-play visual route mapping with OpenStreetMap (`flutter_map`) to inspect points, outages, and speeds.

---

## ⚡ 1-Line Quick Start

Add to your `pubspec.yaml`:

```yaml
dependencies:
  custom_background_geolocation: ^1.1.0
```

Start tracking in your `main()` or state:

```dart
import 'package:flutter/material.dart';
import 'package:custom_background_geolocation/custom_background_geolocation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚡ START TRACKING IN ONE LINE:
  await CustomBackgroundGeolocation.quickStart(
    onLocation: (BgLocation loc) {
      print('📍 Location: ${loc.coordinates}');
      print('📏 Odometer: ${loc.odometerKm.toStringAsFixed(2)} km');
      print('⚡ Speed:    ${loc.speedKmH.toStringAsFixed(1)} km/h');
      print('⚠️ Outage:   ${loc.isOutage}');
    },
    onMotionChange: (BgMotionActivity motion) {
      print('🏃 Motion Activity: ${motion.type} (${motion.confidence}%)');
    },
  );

  runApp(const MyApp());
}
```

---

## 🔋 How It Protects Your Battery (Zero Drain Architecture)

Unlike naive geolocation packages that drain 50–80% battery overnight by querying GPS 24/7 on the main looper, `custom_background_geolocation` employs a dual-state machine:

```text
 ┌────────────────────────────────────────────────────────┐
 │                   USER SITTING STILL                   │
 │           (Sleeping at night / Desk at work)           │
 └──────────────────────────┬─────────────────────────────┘
                            │
                            ▼
      ┌───────────────────────────────────────────┐
      │  1. High-Accuracy GPS POWERS OFF (0% mAh) │
      │  2. Moving WakeLock RELEASED              │
      │  3. Stationary Geofence Anchor Armed      │
      │  4. Hardware Motion Sensor Hub Activated  │
      │     (Zero CPU usage • Deep Sleep Mode)    │
      └─────────────────────┬─────────────────────┘
                            │
               Motion Detected by Hardware
              (User picks up phone / starts bike)
                            │
                            ▼
 ┌────────────────────────────────────────────────────────┐
 │                    USER IN MOTION                      │
 │               (Walking / Bike / Vehicle)               │
 ├────────────────────────────────────────────────────────┤
 │  1. High-Accuracy GPS POWERS ON (5s / 15m cadence)     │
 │  2. Background Worker Looper Processes Updates         │
 │  3. Moving WakeLock prevents pocket sleep throttles    │
 │  4. Road-Adaptive Quality Gate accepts up to 80m fixes │
 └────────────────────────────────────────────────────────┘
```

---

## 📊 Access Pre-Calculated Metrics Instantly

Every `BgLocation` object gives you clean, pre-calculated properties out of the box:

```dart
CustomBackgroundGeolocation.listen((BgLocation loc) {
  // Pre-formatted strings & metric numbers
  print(loc.coordinates);       // "28.626218, 77.378754"
  print(loc.odometerKm);        // 9.05 (in kilometers)
  print(loc.speedKmH);          // 42.5 (in km/h)
  print(loc.speedMph);          // 26.4 (in mph)
  print(loc.batteryPercent);    // 85 (0 to 100%)
  print(loc.batteryIsCharging); // true / false
  print(loc.isMoving);          // true / false
  print(loc.activityType);      // "in_vehicle", "on_bicycle", "walking", "still"

  // Outage and persistence inspection
  print(loc.isOutage);          // true if saved while Wi-Fi / cellular was disconnected
  print(loc.isSynced);          // true if synced with remote backend
  print(loc.isMock);            // true if GPS spoofing detected
});
```

---

## 🔴 Outage & Offline Tracking (Wi-Fi / Internet Off)

When mobile data or Wi-Fi is disconnected, tracking **never stops**:

1. Coordinates and odometer increments are written immediately to native on-device SQLite (`custom_bg_locations.db`).
2. Fixes are permanently stamped with `isOutage = true`.
3. When connectivity returns (exiting elevator, parking garage, or turning Wi-Fi on), the native OS `ConnectivityManager` detects internet and automatically flushes the queue to your backend.
4. **Outage Audit**: Points retain their `isOutage` status permanently so your dashboard and audit reports know which coordinates were captured during an outage.

```dart
// Manually query offline SQLite backlog anytime:
List<BgLocation> offlineFixes = await CustomBackgroundGeolocation.getLocations(limit: 500);
int unsyncedCount = await CustomBackgroundGeolocation.getUnsyncedCount();

// Filter points captured during offline outages:
final outageFixes = offlineFixes.where((l) => l.isOutage).toList();
print('Total points captured during outage: ${outageFixes.length}');
```

---

## 🗺️ Interactive Map Integration

You can easily visualize the recorded path with color-coded outage vs live online segments using OpenStreetMap (`flutter_map`):

```dart
// In your Map Screen:
PolylineLayer(
  polylines: [
    for (int i = 0; i < locations.length - 1; i++)
      Polyline(
        points: [
          LatLng(locations[i].latitude, locations[i].longitude),
          LatLng(locations[i + 1].latitude, locations[i + 1].longitude),
        ],
        // Orange for Outage path (saved by odometer), Blue for Live online
        color: (locations[i].isOutage || locations[i + 1].isOutage)
            ? const Color(0xFFF59E0B)
            : const Color(0xFF0284C7),
        strokeWidth: 4.5,
      ),
  ],
)
```

Check the included [**`example/`**](https://github.com/sunil-singh-chaudhary/custom-background-geolocation/tree/main/example) app for a complete, production-ready implementation of `LocationMapScreen` with interactive point inspectors and summary telemetry.

---

## ⚙️ Platform Configuration

### Android Setup

1. In your `android/app/build.gradle`, verify `compileSdkVersion 34` (or higher).
2. The plugin's AndroidManifest automatically merges all required foreground and location permissions. If your app targets Android 10+ (API 29+), add the background permission in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
</manifest>
```

### iOS Setup

In your `ios/Runner/Info.plist`, declare background location usage:

```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app requires background location to record travel distance and provide live telemetry.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app requires location access while in use.</string>
<key>NSMotionUsageDescription</key>
<string>This app uses motion activity to power off GPS when stationary and save battery.</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
</array>
```

---

## 🛠️ Full Custom Configuration (`ready()`)

For enterprise apps requiring custom HTTP endpoints, batch sync sizes, or custom distance intervals:

```dart
await CustomBackgroundGeolocation.ready(
  BgConfig(
    distanceFilter: 15.0,        // Capture fix every 15 meters traveled
    stationaryRadius: 25.0,      // Shut down GPS when within 25m stationary anchor
    heartbeatInterval: 60,       // Periodic heartbeat in seconds
    syncUrl: 'https://api.yourdomain.com/v1/telemetry/locations',
    syncBatchSize: 50,
    notificationTitle: 'Fleet Tracker Active',
    notificationText: 'Monitoring background trip & odometer',
  ),
);

// Start tracking after ready
await CustomBackgroundGeolocation.start();
```

---

## 📄 License & Author

* **License**: MIT
* **Author**: Sunil Singh Chaudhary ([GitHub](https://github.com/sunil-singh-chaudhary/custom-background-geolocation))
* **Issues & Contributions**: [Issue Tracker](https://github.com/sunil-singh-chaudhary/custom-background-geolocation/issues)
