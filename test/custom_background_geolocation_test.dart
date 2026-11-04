import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:custom_background_geolocation/custom_background_geolocation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel('com.custom.bglocation/methods');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
      log.add(call);
      switch (call.method) {
        case 'ready':
          return true;
        case 'start':
          return true;
        case 'stop':
          return true;
        case 'isRunning':
          return true;
        case 'requestPermission':
          return true;
        case 'requestBatteryExemption':
          return true;
        case 'isIgnoringBatteryOptimizations':
          return true;
        case 'openAppSettings':
          return true;
        case 'checkPermissionStatus':
          return <String, dynamic>{
            'fineLocation': true,
            'coarseLocation': true,
            'backgroundLocation': true,
            'activityRecognition': true,
            'postNotifications': true,
            'batteryOptimizationIgnored': true,
            'allGranted': true,
          };
        case 'getCurrentPosition':
          return <String, dynamic>{
            'uuid': 'test-uuid-1234',
            'latitude': 28.6139,
            'longitude': 77.2090,
            'accuracy': 5.0,
            'altitude': 210.0,
            'speed': 1.4,
            'heading': 90.0,
            'odometer': 1500.0,
            'activityType': 'walking',
            'activityConfidence': 85,
            'batteryLevel': 0.85,
            'isCharging': false,
            'timestamp': 1700000000000,
          };
        case 'getLocations':
          return <Map<String, dynamic>>[
            <String, dynamic>{
              'uuid': 'loc-1',
              'latitude': 28.6139,
              'longitude': 77.2090,
              'accuracy': 6.0,
              'altitude': 210.0,
              'speed': 0.0,
              'heading': 0.0,
              'odometer': 0.0,
              'activityType': 'still',
              'activityConfidence': 95,
              'batteryLevel': 0.90,
              'isCharging': true,
              'timestamp': 1700000001000,
            },
            <String, dynamic>{
              'uuid': 'loc-2',
              'latitude': 28.6145,
              'longitude': 77.2098,
              'accuracy': 4.0,
              'altitude': 211.0,
              'speed': 1.2,
              'heading': 45.0,
              'odometer': 120.0,
              'activityType': 'walking',
              'activityConfidence': 90,
              'batteryLevel': 0.89,
              'isCharging': false,
              'timestamp': 1700000010000,
            },
          ];
        case 'getUnsyncedCount':
          return 42;
        case 'sync':
          return true;
        case 'destroyLocations':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('BgConfig Model Tests', () {
    test('default configuration creates valid map', () {
      const config = BgConfig();
      final map = config.toMap();
      expect(map['distanceFilter'], 20.0);
      expect(map['stationaryRadius'], 25.0);
      expect(map['desiredHighAccuracy'], true);
      expect(map['startOnBoot'], true);
      expect(map['stopOnTerminate'], false);
      expect(map['autoSyncOnConnectivity'], true);
      expect(map['syncBatchSize'], 25);
    });

    test('custom values serialize correctly', () {
      const config = BgConfig(
        distanceFilter: 15.0,
        stationaryRadius: 30.0,
        notificationTitle: 'Track Test',
        notificationText: 'Testing GPS',
        syncUrl: 'https://example.com/api/locations',
        syncBatchSize: 50,
        extras: {'userId': 'user-123'},
      );
      final map = config.toMap();
      expect(map['distanceFilter'], 15.0);
      expect(map['stationaryRadius'], 30.0);
      expect(map['notificationTitle'], 'Track Test');
      expect(map['syncUrl'], 'https://example.com/api/locations');
      expect(map['syncBatchSize'], 50);
      expect(map['extras']['userId'], 'user-123');
    });
  });

  group('BgLocation Model Tests', () {
    test('parses accurately from native entity map', () {
      final loc = BgLocation.fromMap({
        'uuid': 'uuid-abc',
        'latitude': 37.7749,
        'longitude': -122.4194,
        'accuracy': 8.5,
        'altitude': 15.2,
        'speed': 4.5,
        'heading': 180.0,
        'odometer': 5230.0,
        'activityType': 'in_vehicle',
        'activityConfidence': 92,
        'batteryLevel': 0.75,
        'isCharging': false,
        'timestamp': 1700000050000,
      });

      expect(loc.uuid, 'uuid-abc');
      expect(loc.latitude, 37.7749);
      expect(loc.longitude, -122.4194);
      expect(loc.accuracy, 8.5);
      expect(loc.speed, 4.5);
      expect(loc.activityType, 'in_vehicle');
      expect(loc.activityConfidence, 92);
      expect(loc.odometer, 5230.0);
    });

    test('toMap converts back to compliant JSON structure', () {
      final loc = BgLocation(
        uuid: 'uuid-1',
        latitude: 10.0,
        longitude: 20.0,
        accuracy: 3.0,
        altitude: 100.0,
        speed: 0.0,
        heading: 0.0,
        odometer: 0.0,
        activityType: 'still',
        activityConfidence: 100,
        batteryLevel: 1.0,
        batteryIsCharging: true,
        timestamp: 1700000000000,
      );
      final map = loc.toMap();
      expect(map['uuid'], 'uuid-1');
      expect(map['latitude'], 10.0);
      expect(map['longitude'], 20.0);
      expect(map['batteryIsCharging'], true);
    });
  });

  group('BgMotionActivity Model Tests', () {
    test('isStationary accurately detects still states', () {
      final still = BgMotionActivity(activity: 'still', confidence: 95, timestamp: 100);
      expect(still.isStationary, true);
      expect(still.isMoving, false);
    });

    test('isMoving accurately detects walking and vehicle states', () {
      final walking = BgMotionActivity(activity: 'walking', confidence: 80, timestamp: 100);
      expect(walking.isStationary, false);
      expect(walking.isMoving, true);

      final driving = BgMotionActivity(activity: 'in_vehicle', confidence: 90, timestamp: 100);
      expect(driving.isStationary, false);
      expect(driving.isMoving, true);
    });
  });

  group('CustomBackgroundGeolocation Plugin Bridge Tests', () {
    test('ready invokes native method', () async {
      final ok = await CustomBackgroundGeolocation.ready(const BgConfig(distanceFilter: 10.0));
      expect(ok, true);
      expect(log.last.method, 'ready');
      expect(log.last.arguments['distanceFilter'], 10.0);
    });

    test('start invokes native method', () async {
      final ok = await CustomBackgroundGeolocation.start();
      expect(ok, true);
      expect(log.last.method, 'start');
    });

    test('stop invokes native method', () async {
      final ok = await CustomBackgroundGeolocation.stop();
      expect(ok, true);
      expect(log.last.method, 'stop');
    });

    test('isRunning queries service status', () async {
      final running = await CustomBackgroundGeolocation.isRunning();
      expect(running, true);
      expect(log.last.method, 'isRunning');
    });

    test('getCurrentPosition returns parsed location fix', () async {
      final loc = await CustomBackgroundGeolocation.getCurrentPosition(timeoutSec: 5);
      expect(loc, isNotNull);
      expect(loc!.latitude, 28.6139);
      expect(loc.longitude, 77.2090);
      expect(loc.activityType, 'walking');
      expect(log.last.method, 'getCurrentPosition');
      expect(log.last.arguments['timeout'], 5);
    });

    test('getLocations returns buffered SQLite locations', () async {
      final list = await CustomBackgroundGeolocation.getLocations();
      expect(list.length, 2);
      expect(list[0].uuid, 'loc-1');
      expect(list[1].uuid, 'loc-2');
      expect(log.last.method, 'getLocations');
    });

    test('getUnsyncedCount returns integer count of offline locations', () async {
      final count = await CustomBackgroundGeolocation.getUnsyncedCount();
      expect(count, 42);
      expect(log.last.method, 'getUnsyncedCount');
    });

    test('sync triggers batch upload', () async {
      final ok = await CustomBackgroundGeolocation.sync();
      expect(ok, true);
      expect(log.last.method, 'sync');
    });

    test('destroyLocations clears local SQLite buffer', () async {
      final ok = await CustomBackgroundGeolocation.destroyLocations();
      expect(ok, true);
      expect(log.last.method, 'destroyLocations');
    });

    test('checkPermissionStatus returns complete capability map', () async {
      final status = await CustomBackgroundGeolocation.checkPermissionStatus();
      expect(status['fineLocation'], true);
      expect(status['backgroundLocation'], true);
      expect(status['postNotifications'], true);
      expect(status['batteryOptimizationIgnored'], true);
      expect(status['allGranted'], true);
      expect(log.last.method, 'checkPermissionStatus');
    });

    test('requestBatteryExemption invokes native intent', () async {
      final ok = await CustomBackgroundGeolocation.requestBatteryExemption();
      expect(ok, true);
      expect(log.last.method, 'requestBatteryExemption');
    });

    test('isIgnoringBatteryOptimizations queries OS power manager', () async {
      final ignored = await CustomBackgroundGeolocation.isIgnoringBatteryOptimizations();
      expect(ignored, true);
      expect(log.last.method, 'isIgnoringBatteryOptimizations');
    });

    test('openAppSettings opens details intent', () async {
      final ok = await CustomBackgroundGeolocation.openAppSettings();
      expect(ok, true);
      expect(log.last.method, 'openAppSettings');
    });
  });
}
