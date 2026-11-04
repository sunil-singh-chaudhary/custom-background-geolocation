/// Represents a monitored geographic boundary region.
class BgGeofence {
  final String identifier;
  final double latitude;
  final double longitude;
  final double radius;
  final bool notifyOnEntry;
  final bool notifyOnExit;
  final bool notifyOnDwell;
  final int loiteringDelay;
  final Map<String, dynamic>? extras;

  BgGeofence({
    required this.identifier,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.notifyOnEntry = true,
    this.notifyOnExit = true,
    this.notifyOnDwell = false,
    this.loiteringDelay = 30000,
    this.extras,
  });

  Map<String, dynamic> toMap() => {
    'identifier': identifier,
    'latitude': latitude,
    'longitude': longitude,
    'radius': radius,
    'notifyOnEntry': notifyOnEntry,
    'notifyOnExit': notifyOnExit,
    'notifyOnDwell': notifyOnDwell,
    'loiteringDelay': loiteringDelay,
    'extras': extras,
  };
}
