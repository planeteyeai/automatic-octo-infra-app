import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/apis.dart'; // <-- Ensure this path matches your project structure

class GPSScreen extends StatefulWidget {
  const GPSScreen({super.key});

  @override
  _GPSScreenState createState() => _GPSScreenState();
}

class _GPSScreenState extends State<GPSScreen> {
  // Map controller and init flag
  final MapController _mapController = MapController();
  bool _mapInitialized = false;

  // Current position
  LatLng _currentPosition = LatLng(19.0760, 72.8777);

  // Loading & error
  bool _isLoading = true;
  String? _error;

  // API service
  final ApiService _apiService = ApiService();

  // Data
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _chainages = [];
  Map<String, dynamic>? _selectedProject;
  Map<String, dynamic>? _selectedChainage;

  // Polylines & stats
  final List<Polyline> _chainagePolylines = [];
  int totalDetected = 0;
  int totalReported = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkLocationServices();
    await _loadProjects();
    setState(() => _isLoading = false);
  }

  Future<void> _checkLocationServices() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _error = 'Location services are disabled.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permissions are denied.');
        return;
      }
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      });
    } catch (e) {
      setState(() => _error = 'Error retrieving location: $e');
    }
  }

  Future<void> _loadProjects() async {
    final resp = await _apiService.getProjects();
    setState(() {
      _projects = (resp ?? []).whereType<Map<String, dynamic>>().toList();
    });
  }

  /// Fetch all chainages and filter by selected project
  Future<void> _fetchChainages(int? projectId) async {
    if (projectId == null) {
      setState(() {
        _chainages = [];
        _selectedChainage = null;
      });
      return;
    }
    final resp = await _apiService.getChainages();
    if (resp != null) {
      final all = resp.whereType<Map<String, dynamic>>();
      final filtered =
          all.where((feat) {
            final props = feat['properties'] as Map<String, dynamic>?;
            return props != null && props['project'] == projectId;
          }).toList();
      setState(() {
        _chainages = filtered;
        _selectedChainage = null;
        _chainagePolylines.clear();
      });
    }
  }

  void _loadChainageGeoData(Map<String, dynamic> chainage) {
    _chainagePolylines.clear();
    final wkt = chainage['geometry'] as String? ?? '';
    final m = RegExp(
      r'LINESTRING\s*\(([^)]+)\)',
      caseSensitive: false,
    ).firstMatch(wkt);
    if (m == null) return;
    final coordsStr = m.group(1)!;
    final coords =
        coordsStr.split(',').map((p) {
          final parts = p.trim().split(RegExp(r'\s+'));
          return LatLng(double.parse(parts[1]), double.parse(parts[0]));
        }).toList();
    setState(() {
      _chainagePolylines.add(
        Polyline(points: coords, color: Colors.blue, strokeWidth: 4),
      );
      if (_mapInitialized && coords.isNotEmpty) {
        _mapController.move(coords.first, 14);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('GPS Location')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('GPS Location')),
        body: Center(child: Text(_error!)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('GPS Location')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<Map<String, dynamic>>(
              hint: const Text('Select Project'),
              value: _selectedProject,
              isExpanded: true,
              items:
                  _projects.map((pr) {
                    return DropdownMenuItem(
                      value: pr,
                      child: Text(
                        '${pr['name'] ?? 'Unnamed'} (${pr['code'] ?? 'N/A'})',
                      ),
                    );
                  }).toList(),
              onChanged: (pr) {
                setState(() {
                  _selectedProject = pr;
                  _selectedChainage = null;
                });
                _fetchChainages(pr?['id'] as int?);
              },
            ),
          ),
          if (_chainages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<Map<String, dynamic>>(
                hint: const Text('Select Chainage'),
                value: _selectedChainage,
                isExpanded: true,
                items:
                    _chainages.map((ft) {
                      final props = ft['properties'] as Map<String, dynamic>?;
                      return DropdownMenuItem(
                        value: ft,
                        child: Text(
                          '${props?['name'] ?? 'Unnamed'} (${props?['segment_id'] ?? 'N/A'})',
                        ),
                      );
                    }).toList(),
                onChanged: (ch) {
                  if (ch == null) return;
                  setState(() {
                    _selectedChainage = ch;
                    totalDetected = 0;
                    totalReported = 0;
                  });
                  _loadChainageGeoData(ch);
                },
              ),
            )
          else if (_selectedProject != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No chainages found for this project',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                onMapReady: () {
                  _mapInitialized = true;
                  _mapController.move(_currentPosition, 14);
                },
                initialCenter: _currentPosition,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'http://mt0.google.com/vt/lyrs=y&hl=en&x={x}&y={y}&z={z}&s=Ga',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
                PolylineLayer(polylines: _chainagePolylines),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
