# custom_background_geolocation

A production-grade, zero-battery-drain background geolocation, odometer, and geofencing plugin for Flutter. Built natively from the ground up to match and exceed the commercial features of Transistor Software's SDK.

[![pub package](https://img.shields.io/pub/v/custom_background_geolocation.svg)](https://pub.dev/packages/custom_background_geolocation)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/sunil-singh-chaudhary/custom-background-geolocation/blob/main/LICENSE)

---

## 🚀 Key Highlights

* **1-Line Quick Start**: Begin native background tracking and receive continuous callbacks in **literally one line of code**.
* **Zero-Drain Motion State Machine**: Automatically shuts down GPS hardware when the user sits still (0% GPS battery drain) and re-engages when motion resumes.
* **Offline & Unreachable Guarantee**: When the phone enters an elevator, basement, or airplane mode, coordinates are atomically saved to an on-device SQLite database.
* **True Native Execution**: Operates inside native Kotlin (Android) and Swift (iOS) OS services consuming `< 5 MB RAM` without keeping the heavy 50 MB+ Flutter engine alive.
* **Speed-Adaptive Displacement Pacing**: Captures points based on distance traveled (e.g. every 15 meters) instead of wasteful timers, preventing red-light duplicate coordinates.
* **Pre-Calculated Metrics**: Get instant access to `speedKmH`, `speedMph`, `odometerKm`, `batteryPercent`, and `coordinates` without writing custom math.

---

## 📱 Visualizing Behavior Across 6 Real-World Conditions

Here is how the plugin behaves on-screen and behind the scenes under different device states:

### 1. App in Foreground (Live Dashboard)
When the user is viewing your app, updates stream directly to your UI at high frequency.

```text
┌────────────────────────────────────────────────────────┐
│  📡 Background Geolocation                      [ 🛑 ]│
├────────────────────────────────────────────────────────┤
│  🟢 Tracking Active           Activity: 🚗 in_vehicle │
│ ────────────────────────────────────────────────────── │
│   Coordinates       Speed        Odometer     Battery  │
│  28.6262, 77.3787  42.5 km/h     3.84 km        73%    │
├────────────────────────────────────────────────────────┤
│  Live Telemetry Logs:                                  │
│  [13:25:32] 📍 28.626212, 77.378734 | 🚗 | 42.5 km/h  │
│  [13:25:27] 🏃 Motion changed: in_vehicle (100%)       │
│  [13:25:12] 📍 28.625890, 77.377920 | 🚶 | 4.8 km/h   │
└────────────────────────────────────────────────────────┘
```

---

### 2. App Swiped Away / In Background
When the user closes the app or swipes it away from the Android Recents screen:

```text
┌────────────────────────────────────────────────────────┐
│  📍 Location Tracker Active                   13:25    │
│  Live GPS location & odometer tracking                 │
│  RAM: 4.8 MB  •  GPS: Adaptive  •  Status: Running     │
└────────────────────────────────────────────────────────┘
```
* **Android**: The Native Foreground Service stays alive with its persistent notification. Memory footprint remains `< 5 MB RAM`.
* **iOS**: Continues tracking via native background location indicators and significant-change monitoring.

---

### 3. Stationary Condition (Sitting at Desk / Resting)
To save battery, the phone should **never** run GPS continuously while sitting still.

```text
User Sitting Still ──► Hardware Accelerometer: 'still'
                             │
                             ▼
                GPS Hardware POWERS OFF (0% Drain)
                             │
                             ▼
              Stationary Geofence (25m) Armed
```
* GPS radio is completely shut down.
* Battery consumption drops to **0.0% / hour**.
* The instant the user steps outside the 25-meter radius, the geofence triggers and wakes GPS back up.

---

### 4. Moving Condition (Walking or Driving)
When physical motion is detected:

```text
User Starts Moving ──► Accelerometer: 'in_vehicle' or 'walking'
                             │
                             ▼
                     GPS Wakes Up Instantly
                             │
                             ▼
            Displacement Filter: Fix recorded every 15m
                             │
                             ▼
            Odometer accumulates: +0.015 km / fix
```
* Fixed-distance displacement pacing prevents redundant duplicate points when waiting at traffic signals.

---

### 5. Offline Condition (Tunnel, Subway, Airplane Mode)
No cellular connection or Wi-Fi? Zero data loss.

```text
No Internet Connection ──► GPS Satellites Still Track Coordinates
                                      │
                                      ▼
                        Saved into Native Local SQLite DB
                               (is_synced = 0)
                                      │
                                      ▼
               Data safely stored on disk; zero data loss!
```

---

### 6. Cold Boot / Phone Reboot
When the user turns off their phone or runs out of battery and reboots:

```text
Device Powers On ──► Android fires BOOT_COMPLETED
                            │
                            ▼
               Native BootReceiver intercepts event
                            │
                            ▼
          Background tracking auto-resumes immediately!
```
* Tracking resumes automatically without requiring the user to unlock or re-open the app.

---

## 🛠️ Step-by-Step Implementation

### Step 1: Add Dependency

In your Flutter project's `pubspec.yaml`:

```yaml
dependencies:
  custom_background_geolocation: ^1.0.0
```

---

### Step 2: Platform Configuration

#### Android Setup
All core permissions are automatically merged by the plugin's manifest. For Android 14+ (API 34), make sure your `android/app/build.gradle` has `compileSdkVersion 34` or higher.

If you target Android 10+ (API 29+), ensure `android.permission.ACCESS_BACKGROUND_LOCATION` is included in your `android/app/src/main/AndroidManifest.xml` if you request background location:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
```

#### iOS Setup
In your `ios/Runner/Info.plist`, add:

```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app requires background location to track travel distance and provide live updates.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app requires location access while in use.</string>
<key>NSMotionUsageDescription</key>
<string>This app detects motion activity to save battery when stationary.</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
</array>
```

---

### Step 3: One-Line Quick Start (Minimum Code, Maximum Output!)

Initialize permissions, start background tracking, and receive continuous updates in **one line**:

```dart
import 'package:flutter/material.dart';
import 'package:custom_background_geolocation/custom_background_geolocation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚡ ONE-LINE QUICK START:
  await CustomBackgroundGeolocation.quickStart(
    onLocation: (loc) => print(loc.toLogString()),
  );

  runApp(const MyApp());
}
```

#### What `loc.toLogString()` Outputs in Your Console:
```text
[2026-11-04 13:25:32] 📍 28.626212, 77.378734 | 🚗 in_vehicle | ⚡ 42.5 km/h | 📏 3.84 km | 🔋 73%
```

---

### Step 4: Access Rich Pre-Calculated Metrics

No need to write custom distance formulas, speed conversions, or coordinate formatters. Everything is accessible directly on `BgLocation`:

```dart
CustomBackgroundGeolocation.listen((loc) {
  print('Formatted Coords: ${loc.coordinates}');      // "28.626212, 77.378734"
  print('Speed (km/h):      ${loc.speedKmH} km/h');    // "42.5 km/h"
  print('Speed (mph):       ${loc.speedMph} mph');     // "26.4 mph"
  print('Total Odometer:    ${loc.odometerKm} km');    // "3.84 km"
  print('Battery Level:     ${loc.batteryPercent}%');  // 73%
  print('Is Moving:         ${loc.isMoving}');         // true
  print('Activity:          ${loc.activityType}');     // "in_vehicle"
});
```

To stop tracking anytime:
```dart
await CustomBackgroundGeolocation.stop();
```

---

### Step 5: Listen to Physical Motion Activity

Listen to physical activity transitions detected by hardware accelerometers:

```dart
CustomBackgroundGeolocation.onMotionChange.listen((BgMotionActivity motion) {
  print('Motion: ${motion.type} (${motion.confidence}%)');

  if (motion.type == 'in_vehicle') {
    print('User started driving! Speed-adaptive tracking activated.');
  } else if (motion.type == 'still') {
    print('User stationary. GPS powered down.');
  }
});
```

---

### Step 6: Full Custom Configuration (Optional)

When you need custom intervals, custom notifications, or automatic server synchronization:

```dart
await CustomBackgroundGeolocation.ready(
  BgConfig(
    // Minimum meters traveled before recording a new GPS coordinate (Default: 15m)
    distanceFilter: 15.0,

    // Radius of stationary geofence in meters (Default: 25m)
    stationaryRadius: 25.0,

    // Android persistent notification details
    notificationTitle: 'Location Tracker Active',
    notificationText: 'Live GPS & odometer tracking in background',

    // Auto-restart tracking when device is rebooted
    startOnBoot: true,

    // Keep service running even if user swipes app away from recents
    stopOnTerminate: false,

    // (Optional) Remote HTTP endpoint to auto-sync locations in batches
    syncUrl: 'https://api.yourserver.com/api/locations/sync',
    syncBatchSize: 30,
    syncHeaders: {
      'Authorization': 'Bearer YOUR_JWT_TOKEN',
    },
    extras: {
      'driverId': 'DRV_4401',
    },
    autoSyncOnConnectivity: true,
  ),
);

// Start tracking after configuring
await CustomBackgroundGeolocation.start();
```

---

### Step 7: Inspect Offline Buffered Points

Query local SQLite database storage anytime:

```dart
// Check count of pending points in local SQLite
int pending = await CustomBackgroundGeolocation.getUnsyncedCount();
print('Pending points on disk: $pending');

// Retrieve all offline points
List<BgLocation> offlineFixes = await CustomBackgroundGeolocation.getLocations(unsyncedOnly: true);

// Trigger a manual sync if syncUrl is configured
bool success = await CustomBackgroundGeolocation.sync();
```

---

### Step 8: Export Audit Log File & Outage Diagnostics

Generate human-readable audit reports and export complete `.txt` log files directly onto the device:

```dart
// 1. Generate formatted markdown summary with color tags and fix history
final report = await CustomBackgroundGeolocation.generateAuditReport(limit: 250);
print(report);

// 2. Export audit log directly to an on-device text file (e.g. cache/gps_tracking_audit_log.txt)
final filePath = await CustomBackgroundGeolocation.exportAuditLogToFile();
print('Saved audit file at: $filePath');

// 3. Wipe all historical records, clear SQLite buffers, and restart fresh from 0.00 km
await CustomBackgroundGeolocation.resetAndRestart();
```

---

## 🧪 Desk Testing Mode & Offline Outage Verification System

Testing background geolocation often presents a real challenge for QA and engineering teams: **how do you test offline outages, tunnels, airplane mode, and app kills without walking outside?**

In standard production mode ("Field Mode"), the plugin uses smart battery-saving (`distanceFilter: 15.0m`, `stationaryRadius: 25.0m`). When the device sits still on a desk, **GPS hardware powers down completely** to preserve 0% battery drain. While ideal for end users, this makes desk QA testing difficult because turning off Wi-Fi or killing the app while motionless produces zero new GPS fixes.

To solve this, the library includes a built-in **Desk Testing Mode**, **Color-Coded Outage Buffer Feed**, and **On-Device `.txt` Audit File Exporter**.

---

### 1. Purpose: Why These Features Were Added

| Feature | Problem It Solves | How It Helps Developers & QA |
| :--- | :--- | :--- |
| **🧪 Desk Testing Mode (`0m Filter`)** | GPS powers off when still; testers had to walk 20+ meters outside for every single test fix. | Forces high-accuracy updates every **10 seconds** without requiring physical motion. You can test offline buffering right at your desk. |
| **🟢 Live vs 🔴 Outage Color Coding** | Testers could not easily tell which coordinates were sent live vs which were held in the offline outage buffer. | Visually labels every card: 🟢 `[LIVE / SYNCED]` (online) vs 🔴 `[OUTAGE / KILLED BUFFER]` (airplane mode, offline, app killed). |
| **🏷️ Card Index (`#1 (Latest)`, `#2`...)** | In a list of 50+ fixes, it was hard to track the newest point and sequence order. | Displays a reverse-chronological sequence badge (`#1 (Latest)` at the top down to `#N`) on every card and audit log line. |
| **📋 On-Device `.txt` Audit Exporter** | QA engineers needed a concrete, shareable file of coordinates, battery, and odometer to attach to bug reports. | Writes `gps_tracking_audit_log.txt` to device storage with summary metrics, chronological fixes, and native logcat events. |
| **🧹 Clean All & Restart** | Historical test data accumulated between test runs, skewing odometer and counts. | Top amber wipe button empties SQLite tables, clears diagnostic logs, resets odometer to `0.00 km`, and restarts fresh. |

---

### 2. How They Work Under the Hood

#### A. Continuous Desk Tracking Architecture
When `distanceFilter` is set to `0.0m` (or `_isDeskMode == true`):
1. **Pacing Override**: The native Android service configures `LocationRequest` with `intervalMs = 10000ms` (10 seconds) and `minUpdateIntervalMillis = 5000ms`.
2. **Stationary Bypass**: Setting `stationaryRadius = 0.0m` bypasses `handleEnterStationary()`, ensuring GPS stays active even though hardware accelerometers report `still`.
3. **High Accuracy**: Retains `Priority.PRIORITY_HIGH_ACCURACY` so satellite fixes continue arriving at your desk.

#### B. Offline Outage & App-Killed Detection
1. **Native Network Check**: Android's `ConnectivityManager` continuously monitors active network capabilities.
2. **Dynamic Sync Tagging**:
   - When a backend `syncUrl` is configured, points are marked `is_synced = 1` only upon receiving HTTP `200 OK`.
   - In local demo mode (no backend URL), points captured while connected and active are marked `is_synced = 1` (🟢 Live). If captured during airplane mode, Wi-Fi outage, or after the app process was terminated, they are stored with `is_synced = 0` (🔴 Outage).
3. **Auto-Reconnection Flushing**: As soon as internet connectivity returns, native `NetworkCallback.onAvailable()` automatically detects network restoration, and marks or uploads buffered fixes in batches.
4. **Engine Detachment Safety**: Native event sinks are dispatched through the Android Main Looper (`Looper.getMainLooper()`) guarded by `@Volatile var isEngineAttached` checks, preventing `FlutterJNI detached` crashes when the app is swiped away.

---

### 3. Step-by-Step QA / Desk Testing Guide

#### Scenario 1: Test Offline Outage at Your Desk
1. Open the example app and verify **`🧪 Desk Mode: 0m (Fast Updates)`** is active (default).
2. Tap **"Start Tracking"** — observe fixes arriving every 10 seconds marked **🟢 `[LIVE / SYNCED]`**.
3. Swipe down your Android notification shade and turn on **Airplane Mode** (or turn off Wi-Fi/Mobile Data) for 15–30 seconds.
4. Look at the live feed — new fixes arriving during the outage are automatically tagged **🔴 `[OUTAGE / KILLED BUFFER]`**.
5. Turn Airplane Mode off (or reconnect Wi-Fi) — tap **"Sync Queue"** or wait for auto-sync. The offline buffer flushes and pending fixes are updated.

#### Scenario 2: Test App Swiped Away / App Killed Resilience
1. Start tracking in Desk Mode or Field Mode.
2. Swipe the app away from Android Recents (or run `adb shell am kill <package>`).
3. Notice the persistent Android notification **"Live Geolocation & Odometer"** stays running in the system status bar.
4. Re-open the app after 30 seconds — all location fixes, accumulated odometer, and timestamps recorded while the app was dead are loaded from SQLite and displayed.

#### Scenario 3: Export & View the `.txt` Audit File
1. Tap **"Export Audit .txt"** in the action bar.
2. An interactive bottom sheet opens showing:
   - Total Recorded Fixes
   - Live vs Outage breakdown
   - Exact device storage path (e.g. `/data/user/0/.../cache/gps_tracking_audit_log.txt`)
3. Tap **"Copy Path"** to share the path or copy via ADB:
   ```bash
   adb pull /data/user/0/com.example.custom_background_geolocation_example/cache/gps_tracking_audit_log.txt ./
   ```
4. Scroll through the in-app preview or tap **"Copy Report Text"** to paste directly into Slack or Jira.

#### Scenario 4: Clean All & Restart Fresh
1. Tap the amber **Refresh Button (🔄)** in the top right of the AppBar.
2. Confirm the prompt: "Clean All & Restart?".
3. All historical SQLite locations and diagnostic logs are wiped, the odometer resets to `0.00 km`, and tracking restarts fresh from fix `#1`.

---

### 4. Sample Exported Audit File (`gps_tracking_audit_log.txt`)

```text
====================================================
  CUSTOM BACKGROUND GEOLOCATION AUDIT REPORT
  Generated: 2026-11-04 15:26:45.120
====================================================

SUMMARY:
  • Total Recorded Fixes:    5
  • Normal / Synced Fixes:   3 (🟢 LIVE)
  • Outage / Offline Fixes:  2 (🔴 OUTAGE / KILLED)
  • Current Odometer:        0.00 km

----------------------------------------------------
RECORDED GPS FIXES (Most recent first)
----------------------------------------------------
#1    [🟢 NORMAL/LIVE] 2026-11-04 15:26:45 | Coords: 28.626188, 77.378760 | Speed: 0.0 km/h | Odo: 0.00 km | Batt: 78% (Charging) | Motion: still
#2    [🔴 OUTAGE/KILLED] 2026-11-04 15:26:35 | Coords: 28.626196, 77.378764 | Speed: 0.0 km/h | Odo: 0.00 km | Batt: 78% (Charging) | Motion: still
#3    [🔴 OUTAGE/KILLED] 2026-11-04 15:26:25 | Coords: 28.626190, 77.378761 | Speed: 0.0 km/h | Odo: 0.00 km | Batt: 78% (Charging) | Motion: still
#4    [🟢 NORMAL/LIVE] 2026-11-04 15:26:15 | Coords: 28.626195, 77.378763 | Speed: 0.0 km/h | Odo: 0.00 km | Batt: 78% (Charging) | Motion: still
#5    [🟢 NORMAL/LIVE] 2026-11-04 15:26:05 | Coords: 28.626192, 77.378762 | Speed: 0.0 km/h | Odo: 0.00 km | Batt: 78% (Charging) | Motion: still

----------------------------------------------------
PERSISTENT SYSTEM & SERVICE DIAGNOSTIC LOGS
----------------------------------------------------
[15:26:40] [INFO] LocationTrackingService: Started native background tracking service (START_STICKY).
[15:26:40] [INFO] LocationTrackingService: Fused location updates active with distanceFilter = 0.0m (interval=10000ms).
[15:26:40] [INFO] HttpSyncManager: Registered active network connectivity listener.
```

---

## 🏆 Transistor Software Feature Comparison

| Feature | Why It Matters | Custom Background Geolocation | Status |
| :--- | :--- | :--- | :---: |
| **Motion detection (accelerometer)** | GPS on only when moving, off when still. Zero battery drain. | Native Google Play Activity Recognition & iOS CoreMotion state machine | 🟢 Supported |
| **SQLite buffer + auto-sync** | Offline or airplane mode stores locations safely on disk and flushes them in batches. | Atomic SQLite local buffer + OkHttp / URLSession auto-flush with exponential backoff | 🟢 Supported |
| **Foreground service + notification** | Keeps the process alive on Android without OS killing it. | Native Android Foreground Service with customizable persistent notification | 🟢 Supported |
| **stopOnTerminate: false, startOnBoot: true** | Tracking continues after app is swiped away or phone reboots. | Native `BOOT_COMPLETED` receiver, persistent service lifecycle, headless support | 🟢 Supported |
| **iOS significant-location-change** | iOS wakes or relaunches app after background termination. | Native `startMonitoringSignificantLocationChanges()` with auto-relaunch support | 🟢 Supported |
| **Heartbeat / periodic wakeup** | Periodic wake-up and working-hours tracking. | Configurable `heartbeatInterval` periodic alarms & `onHeartbeat` stream | 🟢 Supported |
| **DeviceSettings helper** | Opens OEM-specific battery/autostart screens (Xiaomi, Samsung, Oppo, Vivo). | Native `DeviceSettings.showPowerManager()` & `showIgnoreBatteryOptimizations()` | 🟢 Supported |
| **Mock-location detection** | Catches spoofed GPS apps. | Built-in `isMock` detection | 🟢 Supported |
| **Diagnostic logging** | Inspect why tracking stopped on a specific user's phone. | Persistent SQLite logs, `getLog()`, `destroyLog()`, `emailLog()` | 🟢 Supported |
| **🧪 Desk Testing Mode (0m Continuous)** | Test offline outages and airplane mode at an office desk without walking. | 10s continuous high-accuracy fixes with stationary sleep bypass (`distanceFilter: 0.0`) | 🟢 Supported |
| **🟢 Live vs 🔴 Outage Tagging** | Distinguish live online points from offline buffered points. | Dynamic engine attachment & network check with color-coded tags and `#index` ordering | 🟢 Supported |
| **📋 On-Device `.txt` File Exporter** | Export shareable test reports directly on device for QA & bug reports. | Built-in `exportAuditLogToFile()` and in-app modal preview | 🟢 Supported |

---

## 📄 License

MIT License. Free for commercial and personal use. Copyright (c) 2026 esimrights.in.
