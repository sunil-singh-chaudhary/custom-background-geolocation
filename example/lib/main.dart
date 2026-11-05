import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:custom_background_geolocation/custom_background_geolocation.dart';
import 'map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: LocationTrackerExampleApp(),
    debugShowCheckedModeBanner: false,
  ));
}

enum LogFilter { all, outage, online }

class LocationTrackerExampleApp extends StatefulWidget {
  const LocationTrackerExampleApp({super.key});

  @override
  State<LocationTrackerExampleApp> createState() => _LocationTrackerExampleAppState();
}

class _LocationTrackerExampleAppState extends State<LocationTrackerExampleApp> {
  bool _isTracking = false;
  BgLocation? _currentLocation;
  String _currentActivity = 'still';
  List<BgLocation> _storedLocations = [];
  int _unsyncedCount = 0;
  LogFilter _selectedFilter = LogFilter.all;
  String? _lastExportedFilePath;
  bool _isDeskMode = false; // Default to Battery-Saving Field Mode (Auto-sleeps at night, auto-wakes on movement)

  @override
  void initState() {
    super.initState();
    _refreshFromDatabase();
    _startTracking();
  }

  /// Refreshes historical and outage locations stored in SQLite (even when app was killed).
  Future<void> _refreshFromDatabase() async {
    final list = await CustomBackgroundGeolocation.getLocations(limit: 300);
    final unsynced = await CustomBackgroundGeolocation.getUnsyncedCount();
    setState(() {
      _storedLocations = list;
      _unsyncedCount = unsynced;
      if (list.isNotEmpty && _currentLocation == null) {
        _currentLocation = list.first;
      }
    });
  }

  /// Initializes and begins background tracking with callbacks.
  Future<void> _startTracking() async {
    await CustomBackgroundGeolocation.quickStart(
      distanceFilter: _isDeskMode ? 0.0 : 15.0,
      stationaryRadius: _isDeskMode ? 0.0 : 25.0,
      onLocation: (location) {
        setState(() {
          _currentLocation = location;
          final alreadyExists = _storedLocations.any((l) =>
              (l.uuid.isNotEmpty && l.uuid == location.uuid) ||
              (l.timestamp > 0 && l.timestamp == location.timestamp));
          if (!alreadyExists) {
            _storedLocations.insert(0, location);
            if (!location.isSynced) {
              _unsyncedCount++;
            }
          }
        });
      },
      onMotionChange: (motion) {
        setState(() {
          _currentActivity = motion.type;
        });
      },
      notificationTitle: _isDeskMode ? '🧪 Desk Test Mode Active (0m)' : 'Live Geolocation & Odometer',
      notificationText: _isDeskMode
          ? 'Fast updates active (every 10s without moving)'
          : 'Tracking active across background and outages (15m filter)',
    );

    setState(() => _isTracking = true);
    await _refreshFromDatabase();
  }

  Future<void> _toggleDeskMode() async {
    setState(() {
      _isDeskMode = !_isDeskMode;
    });
    if (_isTracking) {
      await CustomBackgroundGeolocation.stop();
      await _startTracking();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isDeskMode
              ? '🧪 Desk Mode ON: GPS updates every 10s (No movement required!)'
              : '🔋 Field Mode ON: GPS sleeps when still (15m movement required).'),
          backgroundColor: _isDeskMode ? const Color(0xFF10B981) : const Color(0xFF0284C7),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await CustomBackgroundGeolocation.stop();
      setState(() => _isTracking = false);
    } else {
      await _startTracking();
    }
  }

  /// Completely wipes all historical location details, deletes all diagnostic logs,
  /// resets odometer to 0.00 km, and restarts fresh for testing.
  Future<void> _cleanAllAndRestart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Clean All & Restart?', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          'This will wipe all historical GPS fixes, clear offline buffers & logs, reset the odometer to 0.00 km, and restart tracking fresh.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
            ),
            child: const Text('Wipe & Restart Fresh', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 1. Stop tracking service
    await CustomBackgroundGeolocation.stop();

    // 2. Clear all local databases
    await CustomBackgroundGeolocation.destroyLocations();
    await CustomBackgroundGeolocation.destroyLog();

    // 3. Reset in-memory state
    setState(() {
      _storedLocations = [];
      _currentLocation = null;
      _unsyncedCount = 0;
      _lastExportedFilePath = null;
      _currentActivity = 'still';
      _isTracking = false;
    });

    // 4. Start fresh tracking
    await _startTracking();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🧹 Cleaned all old data & restarted tracking fresh from 0.00 km!'),
          backgroundColor: Color(0xFF0284C7),
        ),
      );
    }
  }

  Future<void> _exportAndShowAuditLog() async {
    try {
      final filePath = await CustomBackgroundGeolocation.exportAuditLogToFile();
      final report = await CustomBackgroundGeolocation.generateAuditReport();
      setState(() => _lastExportedFilePath = filePath);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF0F172A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          final outagePoints = _storedLocations.where((l) => l.wasOffline).length;
          final onlinePoints = _storedLocations.where((l) => !l.wasOffline).length;

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📋 Tracking Audit File',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // File info box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saved Device File Path:',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            filePath,
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy Path'),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: filePath));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('File path copied to clipboard!')),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Color(0xFF475569)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.assignment, size: 16),
                                label: const Text('Copy Full Report'),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: report));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Full audit text copied to clipboard!')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mini Stats summary
                    Row(
                      children: [
                        Expanded(
                          child: _statBadge('🔴 Outage Fixes', '$outagePoints', Colors.redAccent),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statBadge('🟢 Live Fixes', '$onlinePoints', Colors.greenAccent),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statBadge(
                            '📏 Odometer',
                            '${_currentLocation?.odometerKm.toStringAsFixed(2) ?? '0.00'} km',
                            const Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Report Preview (.txt content):',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),

                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF020617),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: SelectableText(
                            report,
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating audit file: $e')),
      );
    }
  }

  Widget _statBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLocations = _storedLocations.where((loc) {
      if (_selectedFilter == LogFilter.outage) return loc.wasOffline;
      if (_selectedFilter == LogFilter.online) return !loc.wasOffline;
      return true;
    }).toList();

    final outageCount = _storedLocations.where((l) => l.wasOffline).length;
    final onlineCount = _storedLocations.where((l) => !l.wasOffline).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Geolocation'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'View Route on Map',
            icon: const Icon(Icons.map_outlined),
            color: const Color(0xFF10B981),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LocationMapScreen(locations: _storedLocations),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Audit & Export .txt File',
            icon: const Icon(Icons.description_outlined),
            color: const Color(0xFF38BDF8),
            onPressed: _exportAndShowAuditLog,
          ),
          IconButton(
            tooltip: 'Clean All Logs & Restart Fresh',
            icon: const Icon(Icons.refresh),
            color: const Color(0xFFF59E0B),
            onPressed: _cleanAllAndRestart,
          ),
          IconButton(
            tooltip: _isTracking ? 'Stop Tracking' : 'Start Tracking',
            icon: Icon(_isTracking ? Icons.stop_circle : Icons.play_circle),
            color: _isTracking ? Colors.redAccent : Colors.greenAccent,
            onPressed: _toggleTracking,
          ),
        ],
      ),
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: Column(
          children: [
            // Status Card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isTracking ? Colors.greenAccent : Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isTracking ? 'Tracking Active' : 'Tracking Paused',
                            style: TextStyle(
                              color: _isTracking ? Colors.greenAccent : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF475569)),
                        ),
                        child: Text(
                          '🏃 $_currentActivity',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155), height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metric(
                        'Coordinates',
                        _currentLocation?.coordinates ?? 'Waiting...',
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
                        '${_currentLocation?.batteryPercent ?? 100}%${_currentLocation?.batteryIsCharging == true ? '⚡' : ''}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Desk Mode Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _toggleDeskMode,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _isDeskMode
                            ? const Color(0xFF10B981).withValues(alpha: 0.18)
                            : const Color(0xFF475569).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isDeskMode ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isDeskMode ? Icons.bolt : Icons.nature_people,
                            size: 16,
                            color: _isDeskMode ? const Color(0xFF10B981) : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isDeskMode ? '🧪 Desk Mode: 0m (Fast Updates)' : '🔋 Field Mode: 15m (Battery Saver)',
                            style: TextStyle(
                              color: _isDeskMode ? const Color(0xFF10B981) : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    _isDeskMode ? '⚡ Updates every 10s' : '🚶 Needs 15m walk',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Live Outage Testing Banner / Instructions
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isDeskMode
                          ? 'Desk Mode Active: Turn off Wi-Fi or turn on Airplane Mode for 10s right now to see new fixes in RED.'
                          : 'Field Mode Active: Turn off Wi-Fi or turn on Airplane Mode and walk 20m to record outage fixes in RED.',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.map, size: 18),
                      label: Text(
                        'Map (${_storedLocations.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocationMapScreen(locations: _storedLocations),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Export .txt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _exportAndShowAuditLog,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.cloud_sync, size: 16),
                      label: Text('Sync ($_unsyncedCount)', style: const TextStyle(fontSize: 11)),
                      onPressed: () async {
                        final ok = await CustomBackgroundGeolocation.sync();
                        await _refreshFromDatabase();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'Sync completed successfully!' : 'No internet or sync failed.')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            if (_lastExportedFilePath != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF38BDF8), size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Last exported: ${_lastExportedFilePath!}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),

            // Filter Tabs (All / Outage / Online)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  _filterChip(LogFilter.all, 'All (${_storedLocations.length})'),
                  const SizedBox(width: 8),
                  _filterChip(LogFilter.outage, '🟠 Outage Positions ($outageCount)'),
                  const SizedBox(width: 8),
                  _filterChip(LogFilter.online, '🟢 Live Online ($onlineCount)'),
                ],
              ),
            ),

            // Color-Coded Log Feed
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: filteredLocations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_searching, color: Colors.white24, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFilter == LogFilter.outage
                                  ? 'No outage points detected yet.\nTurn on Airplane Mode or kill the app to test.'
                                  : 'Waiting for GPS location fixes...',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredLocations.length,
                        itemBuilder: (context, index) {
                          final loc = filteredLocations[index];
                          final isOutage = loc.isOutage;

                          // High-contrast color styling:
                          // Amber-Orange for OUTAGE POSITION (Saved by Odometer while Wi-Fi/Internet was off)
                          // Emerald-Green for LIVE ONLINE POSITION
                          final borderColor = isOutage
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981).withValues(alpha: 0.4);
                          final bgColor = isOutage
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                              : const Color(0xFF10B981).withValues(alpha: 0.05);
                          final tagColor = isOutage ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
                          final tagText = isOutage
                              ? '⚠️ OUTAGE POSITION • ODOMETER (${loc.odometerKm.toStringAsFixed(2)} km)'
                              : '🟢 LIVE ONLINE POSITION';

                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LocationMapScreen(
                                    locations: _storedLocations,
                                    initialFocusIndex: _storedLocations.indexOf(loc),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor, width: isOutage ? 1.6 : 1.0),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: tagColor.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: tagColor),
                                            ),
                                            child: Text(
                                              index == 0 ? '#1 (Latest)' : '#${index + 1}',
                                              style: TextStyle(
                                                color: tagColor,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 10,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              tagText,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: tagColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.map, size: 14, color: Color(0xFF38BDF8)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${loc.dateTime.hour.toString().padLeft(2, '0')}:${loc.dateTime.minute.toString().padLeft(2, '0')}:${loc.dateTime.second.toString().padLeft(2, '0')}',
                                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.place, size: 14, color: isOutage ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          loc.coordinates,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${loc.speedKmH.toStringAsFixed(1)} km/h',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '📏 Odometer: ${loc.odometerKm.toStringAsFixed(2)} km',
                                        style: TextStyle(
                                          color: isOutage ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '🎯 ±${loc.accuracy.toStringAsFixed(0)}m',
                                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                                      ),
                                      Text(
                                        '🔋 ${loc.batteryPercent}%${loc.batteryIsCharging ? "⚡" : ""}',
                                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                                      ),
                                      Text(
                                        '🏃 ${loc.activityType}',
                                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
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

  Widget _filterChip(LogFilter filter, String label) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
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
