import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import '../models/model.dart';
import '../services/storage_service.dart';
import '../utility/tflite_service.dart';

class ImagePickerScreen extends StatefulWidget {
  const ImagePickerScreen({super.key});

  @override
  State<ImagePickerScreen> createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  final ImagePicker _picker = ImagePicker();
  final TFLiteService _tfliteService = TFLiteService();

  File? _file;
  File? _annotatedImage;
  List<Map<String, dynamic>>? _recognitions;
  bool _isLoading = false;
  bool _isInitialized = false;
  PavementType _selectedPavementType = PavementType.flexible;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    // Clean up the service when screen is disposed
    _tfliteService.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      setState(() => _isLoading = true);

      // Preload both models during initialization for better performance
      await _tfliteService.preloadModels();

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _initError = e.toString();
        _isLoading = false;
      });
      debugPrint('Error initializing TFLite service: $e');
    }
  }

  Future<void> _loadSelectedModel() async {
    if (!_isInitialized) return;

    try {
      setState(() => _isLoading = true);
      await _tfliteService.loadModel(_selectedPavementType);
    } catch (e) {
      debugPrint('Error loading model: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading model: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [Permission.camera, Permission.photos].request();

    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      if (mounted) {
        await showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Permissions Required'),
                content: const Text(
                  'Camera and gallery access are required.\nPlease enable them in Settings.',
                ),
                actions: [
                  TextButton(
                    onPressed: openAppSettings,
                    child: const Text('Open Settings'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
        );
      }
      return false;
    }

    return statuses.values.every((s) => s.isGranted);
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isLoading || !_isInitialized) return;

    if (!await _ensurePermissions()) return;

    setState(() {
      _isLoading = true;
      _recognitions = null;
      _file = null;
      _annotatedImage = null;
    });

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024, // Limit image size for better performance
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked == null) return;

      final file = File(picked.path);
      final bytes = await file.readAsBytes();

      // Process image in compute to avoid blocking UI
      final result = await compute(_processImage, {
        'bytes': bytes,
        'pavementType': _selectedPavementType,
      });

      if (result['error'] != null) {
        throw Exception(result['error']);
      }

      // Run detection
      final detections = await _tfliteService.detectImage(
        result['bytes'],
        width: result['width'],
        height: result['height'],
        pavementType: _selectedPavementType,
      );

      // Create annotated image
      final annotatedFile = await _createAnnotatedImage(
        result['decodedImage'],
        detections,
        file.path,
      );

      setState(() {
        _file = file;
        _annotatedImage = annotatedFile;
        _recognitions = detections;
      });

      // Show detection summary
      if (detections.isNotEmpty) {
        _showDetectionSummary(detections);
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static Map<String, dynamic> _processImage(Map<String, dynamic> params) {
    try {
      final bytes = params['bytes'] as Uint8List;
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        return {'error': 'Failed to decode image'};
      }

      return {
        'bytes': bytes,
        'width': decoded.width,
        'height': decoded.height,
        'decodedImage': decoded,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<File> _createAnnotatedImage(
    img.Image originalImage,
    List<Map<String, dynamic>> detections,
    String originalPath,
  ) async {
    final annotated = img.Image.from(originalImage);
    final color = img.ColorRgb8(255, 0, 0); // Red color for bounding boxes
    const thickness = 3;

    for (final detection in detections) {
      final box = detection['box'] as List;
      if (box.length < 4) continue;

      double x1 = box[0].toDouble();
      double y1 = box[1].toDouble();
      double x2 = box[2].toDouble();
      double y2 = box[3].toDouble();

      // Convert normalized coordinates to pixel coordinates if needed
      if (x1 <= 1 && x2 <= 1) {
        x1 *= originalImage.width;
        x2 *= originalImage.width;
      }
      if (y1 <= 1 && y2 <= 1) {
        y1 *= originalImage.height;
        y2 *= originalImage.height;
      }

      // Ensure coordinates are within image bounds
      x1 = x1.clamp(0, originalImage.width - 1);
      y1 = y1.clamp(0, originalImage.height - 1);
      x2 = x2.clamp(0, originalImage.width - 1);
      y2 = y2.clamp(0, originalImage.height - 1);

      // Draw bounding box
      img.drawRect(
        annotated,
        x1: x1.toInt(),
        y1: y1.toInt(),
        x2: x2.toInt(),
        y2: y2.toInt(),
        color: color,
        thickness: thickness,
      );

      // Add label text (optional - might be small on mobile)
      final label = detection['label']?.toString() ?? 'Unknown';
      final confidence = detection['confidence'] ?? 0.0;
      final labelText = '$label (${(confidence * 100).toInt()}%)';
      final font = img.arial14; // Use a suitable font
      // You can add text drawing here if needed
      img.drawString(
        annotated,
        labelText,
        font: font,
        x: x1.toInt(),
        y: y1.toInt() - 20,
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final annotatedPath = '${dir.path}/annotated_$timestamp.png';

    final annotatedFile = File(annotatedPath);
    await annotatedFile.writeAsBytes(img.encodePng(annotated));

    return annotatedFile;
  }

  void _showDetectionSummary(List<Map<String, dynamic>> detections) {
    final uniqueLabels = <String>{};
    for (final detection in detections) {
      uniqueLabels.add(detection['label']?.toString() ?? 'Unknown');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Detected ${detections.length} issue(s): ${uniqueLabels.join(', ')}',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission permanently denied. Please enable in settings.',
              ),
            ),
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  Future<void> _saveDetectionData() async {
    if (_recognitions == null || _recognitions!.isEmpty || _file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No detection data to save')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final position = await _getCurrentLocation();
      final location =
          position != null
              ? 'Lat: ${position.latitude.toStringAsFixed(6)}, Lon: ${position.longitude.toStringAsFixed(6)}'
              : 'Location unavailable';

      // Create measurements for each detection
      final measurements = <RAMSDataPost>[];
      for (int i = 0; i < _recognitions!.length; i++) {
        final detection = _recognitions![i];
        final label = detection['label']?.toString() ?? 'Unknown';
        final confidence = detection['confidence'] ?? 0.0;

        // Extract box dimensions from detection data (assuming `box` contains [left, top, right, bottom])
        final dimensions =
            (detection['box'] as List)
                .map((e) => (e as num).toDouble())
                .toList();

        // Determine the distressId and distressImageId based on your use case
        final distressId =
            'some_distress_id_$i'; // Adjust this based on how you generate distressId
        final distressImageId =
            'some_image_id_$i'; // Adjust this based on how you generate distressImageId

        // Construct the RAMSDataPost
        final measurement = RAMSDataPost(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          projectId:
              'some_project_id', // Adjust based on your actual project ID logic
          chainageEnd:
              'some_chainage_id', // Adjust based on your actual chainage ID logic
          distressType: label,
          rmt:
              label.toLowerCase() == 'crack'
                  ? detection['rmt']
                  : null, // For 'crack' distress, include rmt
          volumeInMt3:
              label.toLowerCase() == 'pothole'
                  ? detection['volumeInMt3']
                  : null, // For 'pothole' distress, include volumeInMt3
          distressId: distressId,
          distressImageId: distressImageId,
          unit: 'cm^2', // Assuming unit is cm^2, adjust if necessary
          area: detection['area'] ?? [],
          volume:
              detection['volume'], // Assuming volume comes from your detection logic
          timestamp: DateTime.now(),
          lat: position?.latitude ?? 0.0,
          long: position?.longitude ?? 0.0,
          dimensions: dimensions,
          note:
              'Auto-detected with confidence: ${(confidence * 100).toStringAsFixed(1)}%',
        );

        measurements.add(measurement);
      }

      // Save all measurements
      for (final measurement in measurements) {
        await StorageService.saveRAMSDataPost(measurement);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully saved ${measurements.length} detection(s)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving detection data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPavementTypeSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Select Pavement Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<PavementType>(
                    title: const Text('Flexible'),
                    subtitle: const Text('Asphalt pavement'),
                    value: PavementType.flexible,
                    groupValue: _selectedPavementType,
                    onChanged:
                        _isLoading
                            ? null
                            : (value) async {
                              if (value != null &&
                                  value != _selectedPavementType) {
                                setState(() {
                                  _selectedPavementType = value;
                                  _recognitions = null;
                                });
                                await _loadSelectedModel();
                              }
                            },
                  ),
                ),
                Expanded(
                  child: RadioListTile<PavementType>(
                    title: const Text('Rigid'),
                    subtitle: const Text('Concrete pavement'),
                    value: PavementType.rigid,
                    groupValue: _selectedPavementType,
                    onChanged:
                        _isLoading
                            ? null
                            : (value) async {
                              if (value != null &&
                                  value != _selectedPavementType) {
                                setState(() {
                                  _selectedPavementType = value;
                                  _recognitions = null;
                                });
                                await _loadSelectedModel();
                              }
                            },
                  ),
                ),
              ],
            ),
            if (!_isInitialized && _initError == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading models...'),
                  ],
                ),
              ),
            if (_initError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Model loading failed: $_initError',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_recognitions != null && _recognitions!.isNotEmpty) {
      return Column(
        children: [
          Text(
            'Detection Results',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Detected Issues',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                ..._recognitions!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final r = entry.value;
                  final label = r['label']?.toString() ?? 'Unknown';
                  final conf = ((r['confidence'] ?? 0.0) as double) * 100;
                  final pavementType =
                      r['pavementType']?.toString() ?? 'Unknown';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: conf > 70 ? Colors.green : Colors.orange,
                      child: Text(
                        '${conf.toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${pavementType.toUpperCase()} model • Detection #${index + 1}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            conf > 70
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${conf.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color:
                              conf > 70
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveDetectionData,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Detection Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_file != null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No pavement distresses detected in this image.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    final imageToShow = _annotatedImage ?? _file;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pavement Distress Detection'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing image...'),
                  ],
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildPavementTypeSelector(),
                    if (imageToShow != null)
                      Container(
                        margin: const EdgeInsets.all(16),
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            imageToShow,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.all(16),
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 80,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Select an image to analyze',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                              onPressed:
                                  (!_isInitialized || _isLoading)
                                      ? null
                                      : () => _pickImage(ImageSource.gallery),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                              onPressed:
                                  (!_isInitialized || _isLoading)
                                      ? null
                                      : () => _pickImage(ImageSource.camera),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildResults(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
    );
  }
}
