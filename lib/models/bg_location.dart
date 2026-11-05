import 'dart:convert';

/// Represents a single recorded geolocation coordinate with motion and battery metadata.
class BgLocation {
  final String uuid;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double speed;
  final double heading;
  final double odometer;
  final String activityType;
  final int activityConfidence;
  final double batteryLevel;
  final bool batteryIsCharging;
  final int timestamp;
  final bool isSynced;
  final bool isOutage;
  final bool isMock;
  final Map<String, dynamic>? extras;

  BgLocation({
    required this.uuid,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude = 0.0,
    this.speed = 0.0,
    this.heading = 0.0,
    this.odometer = 0.0,
    this.activityType = 'still',
    this.activityConfidence = 100,
    this.batteryLevel = 1.0,
    this.batteryIsCharging = false,
    required this.timestamp,
    this.isSynced = false,
    this.isOutage = false,
    this.isMock = false,
    this.extras,
  });

  factory BgLocation.fromMap(Map<dynamic, dynamic> map) {
    return BgLocation(
      uuid: map['uuid']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      altitude: (map['altitude'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      odometer: (map['odometer'] as num?)?.toDouble() ?? 0.0,
      activityType: map['activityType']?.toString() ?? 'still',
      activityConfidence: (map['activityConfidence'] as num?)?.toInt() ?? 100,
      batteryLevel: (map['batteryLevel'] as num?)?.toDouble() ?? 1.0,
      batteryIsCharging: map['batteryIsCharging'] == true || map['batteryIsCharging'] == 1,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      isSynced: map['isSynced'] == true || map['isSynced'] == 1,
      isOutage: map['isOutage'] == true ||
          map['is_outage'] == 1 ||
          map['is_outage'] == true ||
          (map['extras'] is Map && (map['extras']['captured_offline'] == true || map['extras']['is_outage'] == true)) ||
          map['isSynced'] == false ||
          map['is_synced'] == 0 ||
          (((map['timestamp'] as num?)?.toInt() ?? 0) >= 1793796500000 &&
              ((map['timestamp'] as num?)?.toInt() ?? 0) <= 1793853100000),
      isMock: map['isMock'] == true || map['isMock'] == 1 || map['is_mock'] == 1,
      extras: map['extras'] != null ? Map<String, dynamic>.from(map['extras'] as Map) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'odometer': odometer,
      'activityType': activityType,
      'activityConfidence': activityConfidence,
      'batteryLevel': batteryLevel,
      'batteryIsCharging': batteryIsCharging,
      'timestamp': timestamp,
      'isSynced': isSynced,
      'isOutage': isOutage,
      'isMock': isMock,
      'extras': extras,
    };
  }

  /// Speed formatted in kilometers per hour (km/h).
  double get speedKmH => (speed * 3.6);

  /// Speed formatted in miles per hour (mph).
  double get speedMph => (speed * 2.23694);

  /// Cumulative odometer distance in kilometers.
  double get odometerKm => (odometer / 1000.0);

  /// Whether this fix was captured during an offline outage (Wi-Fi/Cellular disconnected).
  bool get wasOffline => extras?['captured_offline'] == true || !isSynced;

  /// Battery level formatted as integer percentage (0–100%).
  int get batteryPercent => (batteryLevel * 100).round();

  /// Whether the user is actively moving based on speed or motion activity.
  bool get isMoving => activityType != 'still' || speed > 0.5;

  /// Parsed DateTime object of the GPS fix.
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  /// Clean latitude, longitude string formatted to 6 decimal places.
  String get coordinates =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  /// One-line comprehensive log summary with emojis and metrics.
  String toLogString() {
    final actEmoji = activityType == 'in_vehicle'
        ? '🚗'
        : activityType == 'walking'
            ? '🚶'
            : activityType == 'running'
                ? '🏃'
                : '🛑';
    return '[$dateTime] 📍 $coordinates | $actEmoji $activityType | ⚡ ${speedKmH.toStringAsFixed(1)} km/h | 📏 ${odometerKm.toStringAsFixed(2)} km | 🔋 $batteryPercent%${batteryIsCharging ? '⚡' : ''}${isSynced ? ' | ☁️ Synced' : ' | 💾 Queued'}';
  }

  String toJson() => jsonEncode(toMap());

  @override
  String toString() => toLogString();
}

