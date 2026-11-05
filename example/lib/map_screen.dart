import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:custom_background_geolocation/custom_background_geolocation.dart';

class LocationMapScreen extends StatefulWidget {
  final List<BgLocation> locations;
  final int? initialFocusIndex;

  const LocationMapScreen({
    super.key,
    required this.locations,
    this.initialFocusIndex,
  });

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  late final MapController _mapController;
  int? _selectedPointIndex;
  bool _showAllMarkers = true;

  // Sorted chronologically (oldest to newest)
  late List<BgLocation> _chronoLocations;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _prepareLocations();
  }

  void _prepareLocations() {
    final list = List<BgLocation>.from(widget.locations);
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _chronoLocations = list;

    if (_chronoLocations.isNotEmpty) {
      if (widget.initialFocusIndex != null &&
          widget.initialFocusIndex! >= 0 &&
          widget.initialFocusIndex! < widget.locations.length) {
        final focusedLoc = widget.locations[widget.initialFocusIndex!];
        final matchIdx = _chronoLocations.indexWhere((l) => l.uuid == focusedLoc.uuid);
        _selectedPointIndex = matchIdx != -1 ? matchIdx : _chronoLocations.length - 1;
      } else {
        _selectedPointIndex = _chronoLocations.length - 1; // Default to latest
      }
    }
  }

  void _fitAllBounds() {
    if (_chronoLocations.isEmpty) return;
    if (_chronoLocations.length == 1) {
      _mapController.move(
        LatLng(_chronoLocations.first.latitude, _chronoLocations.first.longitude),
        16.0,
      );
      return;
    }

    final points = _chronoLocations
        .map((l) => LatLng(l.latitude, l.longitude))
        .toList();
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      ),
    );
  }

  void _selectPoint(int index) {
    if (index < 0 || index >= _chronoLocations.length) return;
    setState(() {
      _selectedPointIndex = index;
    });
    final loc = _chronoLocations[index];
    _mapController.move(LatLng(loc.latitude, loc.longitude), _mapController.camera.zoom);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  List<Polyline> _buildSegmentedPolylines() {
    if (_chronoLocations.length < 2) return [];

    final polylines = <Polyline>[];
    for (int i = 0; i < _chronoLocations.length - 1; i++) {
      final a = _chronoLocations[i];
      final b = _chronoLocations[i + 1];
      final isOutageSegment = a.isOutage || b.isOutage;

      polylines.add(
        Polyline(
          points: [
            LatLng(a.latitude, a.longitude),
            LatLng(b.latitude, b.longitude),
          ],
          strokeWidth: isOutageSegment ? 5.5 : 4.0,
          color: isOutageSegment ? const Color(0xFFF59E0B) : const Color(0xFF0284C7),
        ),
      );
    }
    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    if (_chronoLocations.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Route Map'),
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
        ),
        backgroundColor: const Color(0xFF090D16),
        body: const Center(
          child: Text(
            'No locations recorded yet to display on map.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final firstLoc = _chronoLocations.first;
    final lastLoc = _chronoLocations.last;

    final outageCount = _chronoLocations.where((l) => l.isOutage).length;
    final onlineCount = _chronoLocations.where((l) => !l.isOutage).length;

    final totalDistanceKm = lastLoc.odometerKm - firstLoc.odometerKm;
    final displayDistanceKm = totalDistanceKm > 0 ? totalDistanceKm : lastLoc.odometerKm;

    final initialCenter = (_selectedPointIndex != null &&
            _selectedPointIndex! >= 0 &&
            _selectedPointIndex! < _chronoLocations.length)
        ? LatLng(_chronoLocations[_selectedPointIndex!].latitude, _chronoLocations[_selectedPointIndex!].longitude)
        : LatLng(lastLoc.latitude, lastLoc.longitude);

    final selectedLoc = (_selectedPointIndex != null &&
            _selectedPointIndex! >= 0 &&
            _selectedPointIndex! < _chronoLocations.length)
        ? _chronoLocations[_selectedPointIndex!]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Test Track & Outage Map', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              '${_chronoLocations.length} points • ${displayDistanceKm.toStringAsFixed(2)} km • 🟠 $outageCount Outage fixes',
              style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _showAllMarkers ? 'Hide Intermediate Dots' : 'Show All Dots',
            icon: Icon(_showAllMarkers ? Icons.grain : Icons.lens_blur),
            color: _showAllMarkers ? const Color(0xFF38BDF8) : Colors.white60,
            onPressed: () => setState(() => _showAllMarkers = !_showAllMarkers),
          ),
          IconButton(
            tooltip: 'Fit All Points',
            icon: const Icon(Icons.crop_free),
            color: Colors.white,
            onPressed: _fitAllBounds,
          ),
        ],
      ),
      backgroundColor: const Color(0xFF090D16),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 15.5,
              maxZoom: 19.0,
              minZoom: 3.0,
              onMapReady: () {
                Future.delayed(const Duration(milliseconds: 300), _fitAllBounds);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.custom_background_geolocation_example',
              ),

              // Segmented Polyline Layer:
              // Amber/Orange for Outage Path (saved by odometer)
              // Blue for Live Online Path
              PolylineLayer(
                polylines: _buildSegmentedPolylines(),
              ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // Intermediate points (if enabled)
                  if (_showAllMarkers)
                    for (int i = 0; i < _chronoLocations.length; i++)
                      if (i != 0 && i != _chronoLocations.length - 1)
                        Marker(
                          point: LatLng(_chronoLocations[i].latitude, _chronoLocations[i].longitude),
                          width: 24,
                          height: 24,
                          child: GestureDetector(
                            onTap: () => _selectPoint(i),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selectedPointIndex == i
                                    ? Colors.white
                                    : (_chronoLocations[i].isOutage
                                        ? const Color(0xFFF59E0B) // Amber for Outage Position
                                        : const Color(0xFF0284C7)), // Blue for Online
                                border: Border.all(
                                  color: _selectedPointIndex == i
                                      ? (_chronoLocations[i].isOutage ? const Color(0xFFF59E0B) : const Color(0xFF0284C7))
                                      : Colors.white,
                                  width: _selectedPointIndex == i ? 3.0 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _chronoLocations[i].isOutage
                                        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                                        : Colors.black38,
                                    blurRadius: _selectedPointIndex == i ? 6 : 3,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedPointIndex == i ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                  // Start Marker (🟢 Green Flag)
                  Marker(
                    point: LatLng(firstLoc.latitude, firstLoc.longitude),
                    width: 38,
                    height: 38,
                    child: GestureDetector(
                      onTap: () => _selectPoint(0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 6, spreadRadius: 1),
                          ],
                        ),
                        child: const Icon(Icons.flag, color: Colors.white, size: 20),
                      ),
                    ),
                  ),

                  // End/Current Marker (🔴 Red/Cyan Pin)
                  if (_chronoLocations.length > 1)
                    Marker(
                      point: LatLng(lastLoc.latitude, lastLoc.longitude),
                      width: 38,
                      height: 38,
                      child: GestureDetector(
                        onTap: () => _selectPoint(_chronoLocations.length - 1),
                        child: Container(
                          decoration: BoxDecoration(
                            color: lastLoc.isOutage ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 6, spreadRadius: 1),
                            ],
                          ),
                          child: Icon(
                            lastLoc.isOutage ? Icons.wifi_off : Icons.location_on,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Top Visual Legend (Outage vs Online Color Key)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Outage Path ($outageCount)',
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0284C7),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Online Path ($onlineCount)',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Map Floating Controls (Right Side)
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                _mapActionButton(
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onTap: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _mapActionButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onTap: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _mapActionButton(
                  icon: Icons.my_location,
                  tooltip: 'Go to Latest Point',
                  color: const Color(0xFF38BDF8),
                  onTap: () => _selectPoint(_chronoLocations.length - 1),
                ),
                const SizedBox(height: 8),
                _mapActionButton(
                  icon: Icons.play_arrow,
                  tooltip: 'Go to Start Point',
                  color: const Color(0xFF10B981),
                  onTap: () => _selectPoint(0),
                ),
              ],
            ),
          ),

          // Selected Point Inspector Card (Bottom)
          if (selectedLoc != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selectedLoc.isOutage ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selectedLoc.isOutage
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                          : Colors.black87,
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with point index and navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: selectedLoc.isOutage
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                selectedLoc.isOutage
                                    ? '⚠️ OUTAGE POSITION (#${_selectedPointIndex! + 1})'
                                    : '🟢 ONLINE POSITION (#${_selectedPointIndex! + 1})',
                                style: TextStyle(
                                  color: selectedLoc.isOutage ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_formatDate(selectedLoc.dateTime)} ${_formatTime(selectedLoc.dateTime)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.chevron_left, color: Colors.white70),
                              tooltip: 'Previous Point',
                              onPressed: (_selectedPointIndex != null && _selectedPointIndex! > 0)
                                  ? () => _selectPoint(_selectedPointIndex! - 1)
                                  : null,
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.chevron_right, color: Colors.white70),
                              tooltip: 'Next Point',
                              onPressed: (_selectedPointIndex != null &&
                                      _selectedPointIndex! < _chronoLocations.length - 1)
                                  ? () => _selectPoint(_selectedPointIndex! + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155), height: 16),

                    // Metrics Grid: Odometer is highlighted!
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _cardMetric(
                          'Odometer',
                          '${selectedLoc.odometerKm.toStringAsFixed(2)} km',
                          selectedLoc.isOutage ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                        ),
                        _cardMetric('Speed', '${selectedLoc.speedKmH.toStringAsFixed(1)} km/h', Colors.white),
                        _cardMetric(
                          'Accuracy',
                          '±${selectedLoc.accuracy.toStringAsFixed(0)}m',
                          selectedLoc.accuracy <= 15 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                        _cardMetric('Battery', '${selectedLoc.batteryPercent}%', Colors.white70),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Coordinates & status note
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedLoc.latitude.toStringAsFixed(6)}, ${selectedLoc.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 11),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: selectedLoc.isOutage
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                                : const Color(0xFF10B981).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selectedLoc.isOutage ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            ),
                          ),
                          child: Text(
                            selectedLoc.isOutage
                                ? 'Saved by Odometer (Wi-Fi/Internet Off)'
                                : 'Live Online Stream Fix',
                            style: TextStyle(
                              color: selectedLoc.isOutage ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardMetric(String title, String val, Color valColor) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(color: valColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _mapActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Material(
      color: const Color(0xFF1E293B),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
