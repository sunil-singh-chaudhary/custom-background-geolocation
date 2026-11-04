/// Production-grade native background geolocation and geofencing engine for Flutter.
library custom_background_geolocation;

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

import 'models/bg_config.dart';
import 'models/bg_location.dart';
import 'models/bg_motion_activity.dart';
import 'models/device_settings.dart';

export 'models/bg_config.dart';
export 'models/bg_geofence.dart';
export 'models/bg_location.dart';
export 'models/bg_motion_activity.dart';
export 'models/device_settings.dart';

/// The primary public entry point for the custom background geolocation engine.
class CustomBackgroundGeolocation {
  static const MethodChannel _methodChannel =
      MethodChannel('com.custom.bglocation/methods');
  static const EventChannel _locationEventChannel =
      EventChannel('com.custom.bglocation/events/location');
  static const EventChannel _motionEventChannel =
      EventChannel('com.custom.bglocation/events/motion');
  static const EventChannel _geofenceEventChannel =
      EventChannel('com.custom.bglocation/events/geofence');
  static const EventChannel _heartbeatEventChannel =
      EventChannel('com.custom.bglocation/events/heartbeat');

  static Stream<BgLocation>? _locationStream;
  static Stream<BgMotionActivity>? _motionStream;
  static Stream<Map<String, dynamic>>? _geofenceStream;
  static Stream<Map<String, dynamic>>? _heartbeatStream;

  static StreamSubscription<BgLocation>? _quickStartLocationSub;
  static StreamSubscription<BgMotionActivity>? _quickStartMotionSub;
  static StreamSubscription<Map<String, dynamic>>? _quickStartGeofenceSub;
  static StreamSubscription<Map<String, dynamic>>? _quickStartHeartbeatSub;

  /// Configure the plugin with desired accuracy, distanceFilter, and sync options.
  static Future<bool> ready(BgConfig config) async {
    final result =
        await _methodChannel.invokeMethod<bool>('ready', config.toMap());
    return result ?? false;
  }

  /// ONE-LINE QUICK START:
  /// Initializes, requests permissions, enables battery optimization bypass,
  /// starts the foreground tracking engine, and provides a continuous stream callback!
  ///
  /// Example:
  /// ```dart
  /// final sub = await CustomBackgroundGeolocation.quickStart(
  ///   onLocation: (loc) => print(loc.toLogString()),
  /// );
  /// ```
  static Future<StreamSubscription<BgLocation>> quickStart({
    required void Function(BgLocation location) onLocation,
    void Function(BgMotionActivity activity)? onMotionChange,
    void Function(Map<String, dynamic> geofence)? onGeofence,
    void Function(Map<String, dynamic> heartbeat)? onHeartbeat,
    String? syncUrl,
    Map<String, dynamic>? extras,
    double distanceFilter = 15.0,
    double stationaryRadius = 25.0,
    String notificationTitle = 'Location Tracker',
    String notificationText = 'Live background tracking active',
    bool autoSyncOnConnectivity = true,
  }) async {
    // Cancel any prior quickStart subscriptions to avoid duplicate listeners on clean restart
    await _quickStartLocationSub?.cancel();
    _quickStartLocationSub = null;
    await _quickStartMotionSub?.cancel();
    _quickStartMotionSub = null;
    await _quickStartGeofenceSub?.cancel();
    _quickStartGeofenceSub = null;
    await _quickStartHeartbeatSub?.cancel();
    _quickStartHeartbeatSub = null;

    final config = BgConfig(
      distanceFilter: distanceFilter,
      stationaryRadius: stationaryRadius,
      desiredHighAccuracy: true,
      notificationTitle: notificationTitle,
      notificationText: notificationText,
      syncUrl: syncUrl,
      extras: extras,
      autoSyncOnConnectivity: autoSyncOnConnectivity,
    );

    await ready(config);
    await start();

    if (onMotionChange != null) {
      _quickStartMotionSub =
          CustomBackgroundGeolocation.onMotionChange.listen(onMotionChange);
    }
    if (onGeofence != null) {
      _quickStartGeofenceSub =
          CustomBackgroundGeolocation.onGeofence.listen(onGeofence);
    }
    if (onHeartbeat != null) {
      _quickStartHeartbeatSub =
          CustomBackgroundGeolocation.onHeartbeat.listen(onHeartbeat);
    }

    _quickStartLocationSub =
        CustomBackgroundGeolocation.onLocation.listen(onLocation);
    return _quickStartLocationSub!;
  }

  /// ONE-LINE LISTENER:
  /// Listens to location stream with automatic console logging formatted in one line.
  static StreamSubscription<BgLocation> listen(
    void Function(BgLocation location) onLocation, {
    bool logToConsole = true,
  }) {
    return CustomBackgroundGeolocation.onLocation.listen((loc) {
      if (logToConsole) {
        // ignore: avoid_print
        print(loc.toLogString());
      }
      onLocation(loc);
    });
  }

  /// Request system location, motion, notifications, and battery saver permissions directly.
  /// Automatically cascades from foreground permissions -> background location -> battery saver exemption.
  /// (Also invoked automatically when [start()] is called if permissions are missing).
  static Future<bool> requestPermission() async {
    final result = await _methodChannel.invokeMethod<bool>('requestPermission');
    return result ?? false;
  }

  /// Request exemption from Android Battery Optimization (Doze Mode).
  /// Launches native system dialog "Let app always run in background? [Deny] [Allow]".
  static Future<bool> requestBatteryExemption() async {
    final result =
        await _methodChannel.invokeMethod<bool>('requestBatteryExemption');
    return result ?? false;
  }

  /// Check whether battery optimization is currently ignored (unrestricted) for this app.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    final result = await _methodChannel
        .invokeMethod<bool>('isIgnoringBatteryOptimizations');
    return result ?? true;
  }

  /// Comprehensive check of all required permissions and battery states.
  static Future<Map<String, dynamic>> checkPermissionStatus() async {
    final map = await _methodChannel
        .invokeMethod<Map<dynamic, dynamic>>('checkPermissionStatus');
    if (map == null) return {};
    return Map<String, dynamic>.from(map);
  }

  /// Opens the system application details / permissions settings screen.
  static Future<bool> openAppSettings() async {
    final result = await _methodChannel.invokeMethod<bool>('openAppSettings');
    return result ?? false;
  }

  /// Start continuous background location tracking.
  /// Automatically prompts for location, notification, and battery saver permissions if not already granted.
  static Future<bool> start() async {
    final result = await _methodChannel.invokeMethod<bool>('start');
    return result ?? false;
  }

  /// Stop background location tracking.
  static Future<bool> stop() async {
    await _quickStartLocationSub?.cancel();
    _quickStartLocationSub = null;
    await _quickStartMotionSub?.cancel();
    _quickStartMotionSub = null;
    await _quickStartGeofenceSub?.cancel();
    _quickStartGeofenceSub = null;
    await _quickStartHeartbeatSub?.cancel();
    _quickStartHeartbeatSub = null;

    final result = await _methodChannel.invokeMethod<bool>('stop');
    return result ?? false;
  }

  /// Check whether background tracking is currently active.
  static Future<bool> isRunning() async {
    final result = await _methodChannel.invokeMethod<bool>('isRunning');
    return result ?? false;
  }

  /// Fetch a single one-shot location immediately.
  static Future<BgLocation?> getCurrentPosition({int timeoutSec = 10}) async {
    final map = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'getCurrentPosition',
      {'timeout': timeoutSec},
    );
    if (map == null) return null;
    return BgLocation.fromMap(map);
  }

  /// Stream of location updates as the user moves.
  static Stream<BgLocation> get onLocation {
    _locationStream ??= _locationEventChannel.receiveBroadcastStream().map(
        (event) =>
            BgLocation.fromMap(Map<dynamic, dynamic>.from(event as Map)));
    return _locationStream!;
  }

  /// Stream of motion activity transitions (still, walking, driving, running).
  static Stream<BgMotionActivity> get onMotionChange {
    _motionStream ??= _motionEventChannel.receiveBroadcastStream().map(
        (event) =>
            BgMotionActivity.fromMap(Map<dynamic, dynamic>.from(event as Map)));
    return _motionStream!;
  }

  /// Stream of geofence entry/exit/dwell events.
  static Stream<Map<String, dynamic>> get onGeofence {
    _geofenceStream ??= _geofenceEventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _geofenceStream!;
  }

  /// Stream of periodic heartbeat events when device is stationary or in background.
  static Stream<Map<String, dynamic>> get onHeartbeat {
    _heartbeatStream ??= _heartbeatEventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _heartbeatStream!;
  }

  /// Retrieve locally cached SQLite locations (useful when phone was unreachable / offline).
  static Future<List<BgLocation>> getLocations({
    bool unsyncedOnly = false,
    int limit = 1250,
  }) async {
    final list = await _methodChannel.invokeListMethod<Map<dynamic, dynamic>>(
      'getLocations',
      {'unsyncedOnly': unsyncedOnly, 'limit': limit},
    );
    if (list == null) return [];
    return list.map((item) => BgLocation.fromMap(item)).toList();
  }

  /// Count of unsynced locations buffered in the native SQLite database.
  static Future<int> getUnsyncedCount() async {
    final count = await _methodChannel.invokeMethod<int>('getUnsyncedCount');
    return count ?? 0;
  }

  /// Force an immediate HTTP sync of all pending offline locations.
  static Future<bool> sync() async {
    final result = await _methodChannel.invokeMethod<bool>('sync');
    return result ?? false;
  }

  /// Clear the local offline SQLite location buffer.
  static Future<bool> destroyLocations() async {
    final result = await _methodChannel.invokeMethod<bool>('destroyLocations');
    return result ?? false;
  }

  /// Opens the OEM-specific power manager / autostart screen (Xiaomi, Samsung, Oppo, Vivo, Huawei).
  static Future<bool> showPowerManager() => DeviceSettings.showPowerManager();

  /// Retrieve persistent diagnostic logs from the native SQLite database.
  static Future<String> getLog() async {
    final logText = await _methodChannel.invokeMethod<String>('getLog');
    return logText ?? '';
  }

  /// Destroy / clear the persistent native SQLite log database.
  static Future<bool> destroyLog() async {
    final result = await _methodChannel.invokeMethod<bool>('destroyLog');
    return result ?? false;
  }

  /// Wipes all historical SQLite location fixes, clears diagnostic logs,
  /// stops tracking, and restarts fresh from 0.00 km odometer.
  static Future<bool> resetAndRestart() async {
    await stop();
    await destroyLocations();
    await destroyLog();
    return await start();
  }

  /// Append a custom entry to the persistent native SQLite logger.
  static Future<bool> log(String level, String message) async {
    final result = await _methodChannel.invokeMethod<bool>('log', {
      'level': level,
      'message': message,
    });
    return result ?? false;
  }

  /// Opens email client with device tracking diagnostic logs pre-attached.
  static Future<bool> emailLog(String email) async {
    final result =
        await _methodChannel.invokeMethod<bool>('emailLog', {'email': email});
    return result ?? false;
  }

  /// Generates a structured human-readable audit report comparing normal online tracking
  /// vs offline outage / airplane mode / app killed tracking.
  static Future<String> generateAuditReport({int limit = 250}) async {
    final locations = await getLocations(limit: limit);
    final systemLogs = await getLog();

    final buffer = StringBuffer();
    final now = DateTime.now();
    buffer.writeln('====================================================');
    buffer.writeln('  CUSTOM BACKGROUND GEOLOCATION AUDIT REPORT');
    buffer.writeln('  Generated: $now');
    buffer.writeln('====================================================\n');

    final outagePoints = locations.where((l) => !l.isSynced).toList();
    final syncedPoints = locations.where((l) => l.isSynced).toList();
    final currentOdometer =
        locations.isNotEmpty ? locations.first.odometerKm : 0.0;

    buffer.writeln('SUMMARY:');
    buffer.writeln('  • Total Recorded Fixes:    ${locations.length}');
    buffer.writeln(
        '  • Normal / Synced Fixes:   ${syncedPoints.length} (🟢 LIVE)');
    buffer.writeln(
        '  • Outage / Offline Fixes:  ${outagePoints.length} (🔴 OUTAGE / KILLED)');
    buffer.writeln(
        '  • Current Odometer:        ${currentOdometer.toStringAsFixed(2)} km\n');

    buffer.writeln('----------------------------------------------------');
    buffer.writeln('RECORDED GPS FIXES (Most recent first)');
    buffer.writeln('----------------------------------------------------');
    if (locations.isEmpty) {
      buffer.writeln('No location fixes recorded in SQLite yet.\n');
    } else {
      for (int i = 0; i < locations.length; i++) {
        final loc = locations[i];
        final indexNo = '#${i + 1}'.padRight(5);
        final tag = loc.isSynced ? '[🟢 NORMAL/LIVE]' : '[🔴 OUTAGE/KILLED]';
        buffer.writeln(
            '$indexNo $tag ${loc.dateTime} | Coords: ${loc.coordinates} | Speed: ${loc.speedKmH.toStringAsFixed(1)} km/h | Odo: ${loc.odometerKm.toStringAsFixed(2)} km | Batt: ${loc.batteryPercent}% (${loc.batteryIsCharging ? "Charging" : "Discharging"}) | Motion: ${loc.activityType}');
      }
      buffer.writeln('');
    }

    if (systemLogs.isNotEmpty) {
      buffer.writeln('----------------------------------------------------');
      buffer.writeln('SYSTEM & BACKGROUND SERVICE LOGS');
      buffer.writeln('----------------------------------------------------');
      buffer.writeln(systemLogs);
    }

    buffer.writeln('====================================================');
    buffer.writeln('  END OF AUDIT REPORT');
    buffer.writeln('====================================================');

    return buffer.toString();
  }

  /// Exports the structured audit report directly to a local .txt file on the device.
  /// If [customPath] is omitted, saves to the system temporary directory as `gps_tracking_audit_log.txt`.
  /// Returns the absolute path of the created file.
  static Future<String> exportAuditLogToFile(
      {String? customPath, int limit = 250}) async {
    final report = await generateAuditReport(limit: limit);
    final File file;
    if (customPath != null && customPath.isNotEmpty) {
      file = File(customPath);
    } else {
      final tempDir = Directory.systemTemp;
      file = File('${tempDir.path}/gps_tracking_audit_log.txt');
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(report, flush: true);
    return file.path;
  }
}
