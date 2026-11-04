/// Represents detected physical user activity (still, walking, running, in_vehicle, on_bicycle).
class BgMotionActivity {
  final String activity;
  final int confidence;
  final int timestamp;

  BgMotionActivity({
    required this.activity,
    required this.confidence,
    required this.timestamp,
  });

  factory BgMotionActivity.fromMap(Map<dynamic, dynamic> map) {
    return BgMotionActivity(
      activity: map['activity']?.toString() ?? 'still',
      confidence: (map['confidence'] as num?)?.toInt() ?? 100,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() => {
    'activity': activity,
    'confidence': confidence,
    'timestamp': timestamp,
  };

  /// Alias for activity string (e.g. still, walking, in_vehicle, running).
  String get type => activity;

  bool get isStationary => activity == 'still';
  bool get isMoving => !isStationary;

  @override
  String toString() => 'BgMotionActivity($activity, confidence: $confidence%)';
}
