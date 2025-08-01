import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/model.dart';

class DetailDistressLog extends StatefulWidget {
  final RAMSDataPost projectdata;

  const DetailDistressLog({super.key, required this.projectdata});

  @override
  State<DetailDistressLog> createState() => _DetailDistressLogState();
}

class _DetailDistressLogState extends State<DetailDistressLog> {
  final MapController _mapController = MapController();
  bool _mapInitialized = false;
  late LatLng _currentPosition;
  String? _error;

  @override
  void initState() {
    super.initState();

    debugPrint(
      'DetailDistressLog.initState(): '
      'latitude = ${widget.projectdata.latitude}, '
      'longitude = ${widget.projectdata.longitude}, '
      'dimensions = ${widget.projectdata.dimensions}',
    );
    _extractPosition();
  }

  void _extractPosition() {
    try {
      final lat = double.tryParse(widget.projectdata.latitude ?? '');
      final lon = double.tryParse(widget.projectdata.longitude ?? '');

      if (_isValidLatLng(lat, lon)) {
        _currentPosition = LatLng(lat!, lon!);
        return;
      }

      final dimensions = widget.projectdata.dimensions;
      if (dimensions != null && dimensions.isNotEmpty) {
        final dimList =
            dimensions
                .split(',')
                .map((e) => double.tryParse(e.trim()))
                .toList();

        if (dimList.length >= 2 && _isValidLatLng(dimList[0], dimList[1])) {
          _currentPosition = LatLng(dimList[0]!, dimList[1]!);
          return;
        }
      }

      _error = 'No valid coordinates found';
      _currentPosition = const LatLng(0, 0);
    } catch (e) {
      _error = 'Error extracting coordinates: $e';
      _currentPosition = const LatLng(0, 0);
    }
  }

  bool _isValidLatLng(double? lat, double? lon) {
    return lat != null &&
        lon != null &&
        lat.isFinite &&
        lon.isFinite &&
        lat.abs() <= 90 &&
        lon.abs() <= 180;
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = 'N/A';
    try {
      final timestampStr = widget.projectdata.timestamp;
      final parsed = DateTime.tryParse(timestampStr);
      if (parsed != null) {
        formattedDate =
            '${parsed.toLocal().toIso8601String().replaceFirst('T', ' ').substring(0, 19)}';
      }
    } catch (_) {
      formattedDate = 'Invalid date';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Distress Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Type: ${widget.projectdata.distressType}",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              "Location (raw): ${widget.projectdata.latitude}, ${widget.projectdata.longitude}",
            ),
            const SizedBox(height: 8),
            Text("Status: ${widget.projectdata.note ?? 'N/A'}"),
            const SizedBox(height: 8),
            Text("Date: $formattedDate"),
            const SizedBox(height: 16),

            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            const SizedBox(height: 16),
            const Text("Map Location:", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),

            Expanded(
              child:
                  (_currentPosition.latitude == 0 &&
                          _currentPosition.longitude == 0)
                      ? const Center(child: Text("Invalid location"))
                      : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          onMapReady: () {
                            _mapInitialized = true;
                            _mapController.move(_currentPosition, 14.0);
                          },
                          initialCenter: _currentPosition,
                          initialZoom: 14.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                "http://mt0.google.com/vt/lyrs=y&hl=en&x={x}&y={y}&z={z}&s=Ga",
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _currentPosition,
                                width: 48,
                                height: 48,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
