import 'package:flutter/material.dart';
import 'package:custom_background_geolocation/custom_background_geolocation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: LocationTrackerExampleApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class LocationTrackerExampleApp extends StatefulWidget {
  const LocationTrackerExampleApp({super.key});

  @override
  State<LocationTrackerExampleApp> createState() => _LocationTrackerExampleAppState();
}

class _LocationTrackerExampleAppState extends State<LocationTrackerExampleApp> {
  bool _isTracking = false;
  BgLocation? _currentLocation;
  String _currentActivity = 'still';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  /// ONE-LINE QUICK START: Initializes and begins background tracking with callbacks.
  Future<void> _startTracking() async {
    // ONE LINE to start everything with smart defaults & auto-permissions:
    await CustomBackgroundGeolocation.quickStart(
      onLocation: (location) {
        setState(() {
          _currentLocation = location;
          _logs.insert(0, location.toLogString());
        });
      },
      onMotionChange: (motion) {
        setState(() {
          _currentActivity = motion.type;
          _logs.insert(0, '🏃 Motion changed: ${motion.type} (${motion.confidence}%)');
        });
      },
      notificationTitle: 'Location Tracker Active',
      notificationText: 'Live GPS location & odometer tracking',
    );

    setState(() => _isTracking = true);
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await CustomBackgroundGeolocation.stop();
      setState(() => _isTracking = false);
    } else {
      await _startTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Geolocation'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.stop_circle : Icons.play_circle),
            color: _isTracking ? Colors.redAccent : Colors.greenAccent,
            onPressed: _toggleTracking,
          )
        ],
      ),
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: Column(
          children: [
            // Status Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isTracking ? '🟢 Tracking Active' : '🔴 Tracking Paused',
                        style: TextStyle(
                          color: _isTracking ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Activity: $_currentActivity',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155), height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metric(
                        'Coordinates',
                        _currentLocation?.coordinates ?? 'Waiting for fix...',
                      ),
                      _metric(
                        'Speed',
                        '${_currentLocation?.speedKmH.toStringAsFixed(1) ?? '0.0'} km/h',
                      ),
                      _metric(
                        'Odometer',
                        '${_currentLocation?.odometerKm.toStringAsFixed(2) ?? '0.00'} km',
                      ),
                      _metric(
                        'Battery',
                        '${_currentLocation?.batteryPercent ?? 100}%',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Live Log Console
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Live Telemetry Logs:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Waiting for GPS events...',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
