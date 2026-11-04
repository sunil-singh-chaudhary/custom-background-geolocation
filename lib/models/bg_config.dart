/// Configuration options for the custom background geolocation engine.
class BgConfig {
  /// Distance in meters the user must travel before a new GPS fix is recorded.
  /// (Default: 20 meters. 0 means continuous interval polling).
  final double distanceFilter;

  /// Radius in meters for the dynamic stationary geofence.
  /// (Default: 25 meters).
  final double stationaryRadius;

  /// High accuracy desired (GPS) vs low power (Cell / Wi-Fi).
  final bool desiredHighAccuracy;

  /// Persistent notification title for Android foreground service.
  final String notificationTitle;

  /// Persistent notification body text.
  final String notificationText;

  /// Remote HTTP API endpoint to automatically sync recorded locations.
  final String? syncUrl;

  /// Maximum batch size when posting locations to [syncUrl].
  final int syncBatchSize;

  /// Custom HTTP headers to include with sync requests (e.g. Authorization token).
  final Map<String, String>? syncHeaders;

  /// Custom metadata to attach to every recorded location.
  final Map<String, dynamic>? extras;

  /// Automatically restart background tracking when the device boots up.
  final bool startOnBoot;

  /// Keep tracking alive even if the user swipes the app away from recents.
  final bool stopOnTerminate;

  /// Automatically sync unsynced points to [syncUrl] when network returns.
  final bool autoSyncOnConnectivity;

  /// Periodic heartbeat interval in seconds while device is stationary or running.
  /// (Default: 60 seconds. Set to 0 to disable).
  final int heartbeatInterval;

  /// Optional working-hours tracking schedule (e.g. ['1-5 09:00-18:00']).
  final List<String>? schedule;

  const BgConfig({
    this.distanceFilter = 20.0,
    this.stationaryRadius = 25.0,
    this.desiredHighAccuracy = true,
    this.notificationTitle = 'Location Service Active',
    this.notificationText = 'Monitoring location in background',
    this.syncUrl,
    this.syncBatchSize = 25,
    this.syncHeaders,
    this.extras,
    this.startOnBoot = true,
    this.stopOnTerminate = false,
    this.autoSyncOnConnectivity = true,
    this.heartbeatInterval = 60,
    this.schedule,
  });

  Map<String, dynamic> toMap() {
    return {
      'distanceFilter': distanceFilter,
      'stationaryRadius': stationaryRadius,
      'desiredHighAccuracy': desiredHighAccuracy,
      'notificationTitle': notificationTitle,
      'notificationText': notificationText,
      'syncUrl': syncUrl,
      'syncBatchSize': syncBatchSize,
      'syncHeaders': syncHeaders,
      'extras': extras,
      'startOnBoot': startOnBoot,
      'stopOnTerminate': stopOnTerminate,
      'autoSyncOnConnectivity': autoSyncOnConnectivity,
      'heartbeatInterval': heartbeatInterval,
      'schedule': schedule,
    };
  }
}
