import 'package:flutter/services.dart';
import 'package:flutter_vision/flutter_vision.dart';

enum PavementType { flexible, rigid }

class TFLiteService {
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  final FlutterVision _flutterVision = FlutterVision();

  bool _flexibleModelLoaded = false;
  bool _rigidModelLoaded = false;
  List<String> _flexibleLabels = [];
  List<String> _rigidLabels = [];
  PavementType? _currentModelType;

  // Add loading states to prevent concurrent loading
  bool _isLoadingFlexible = false;
  bool _isLoadingRigid = false;

  Future<void> loadModel(PavementType pavementType) async {
    // Prevent concurrent loading of the same model
    if (pavementType == PavementType.flexible && _isLoadingFlexible) {
      print('Flexible model already loading, waiting...');
      while (_isLoadingFlexible) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    if (pavementType == PavementType.rigid && _isLoadingRigid) {
      print('Rigid model already loading, waiting...');
      while (_isLoadingRigid) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    // Check if the requested model is already loaded
    if (pavementType == PavementType.flexible &&
        _flexibleModelLoaded &&
        _currentModelType == PavementType.flexible) {
      print('Flexible model already loaded and active');
      return;
    }

    if (pavementType == PavementType.rigid &&
        _rigidModelLoaded &&
        _currentModelType == PavementType.rigid) {
      print('Rigid model already loaded and active');
      return;
    }

    try {
      // Set loading state
      if (pavementType == PavementType.flexible) {
        _isLoadingFlexible = true;
      } else {
        _isLoadingRigid = true;
      }

      String labelPath;
      String modelPath;

      if (pavementType == PavementType.flexible) {
        labelPath = 'assets/flexible_pavement_model/labelmap.txt';
        modelPath = 'assets/flexible_pavement_model/detect.tflite';
      } else {
        labelPath = 'assets/rigid_pavement_model/labelmap.txt';
        modelPath = 'assets/rigid_pavement_model/detect.tflite';
      }

      // Only load labels if not already loaded for this model type
      List<String> labels;
      if (pavementType == PavementType.flexible && _flexibleLabels.isEmpty) {
        final rawLabels = await rootBundle.loadString(labelPath);
        labels =
            rawLabels
                .split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
        _flexibleLabels = labels;
      } else if (pavementType == PavementType.rigid && _rigidLabels.isEmpty) {
        final rawLabels = await rootBundle.loadString(labelPath);
        labels =
            rawLabels
                .split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
        _rigidLabels = labels;
      } else {
        labels =
            pavementType == PavementType.flexible
                ? _flexibleLabels
                : _rigidLabels;
      }

      print('Loading ${pavementType.name} pavement model...');
      print('Labels for ${pavementType.name}: $labels');

      // Close previous model if switching types
      if (_currentModelType != null && _currentModelType != pavementType) {
        print('Closing previous model: ${_currentModelType!.name}');
        await _flutterVision.closeYoloModel();
        _currentModelType = null;
      }

      // Load YOLOv8 model
      await _flutterVision.loadYoloModel(
        labels: labelPath,
        modelPath: modelPath,
        modelVersion: "yolov8",
        quantization: false,
        numThreads: 2,
        useGpu: false,
      );

      // Update the appropriate model state
      if (pavementType == PavementType.flexible) {
        _flexibleModelLoaded = true;
      } else {
        _rigidModelLoaded = true;
      }

      _currentModelType = pavementType;

      print(
        '${pavementType.name.toUpperCase()} pavement model loaded successfully with ${labels.length} labels',
      );
    } catch (e) {
      print('Error loading ${pavementType.name} pavement model: $e');
      rethrow;
    } finally {
      // Reset loading state
      if (pavementType == PavementType.flexible) {
        _isLoadingFlexible = false;
      } else {
        _isLoadingRigid = false;
      }
    }
  }

  Future<List<Map<String, dynamic>>> detectImage(
    Uint8List bytes, {
    required int width,
    required int height,
    required PavementType pavementType,
  }) async {
    // Ensure the correct model is loaded
    await loadModel(pavementType);

    final isModelLoaded =
        (pavementType == PavementType.flexible && _flexibleModelLoaded) ||
        (pavementType == PavementType.rigid && _rigidModelLoaded);

    if (!isModelLoaded || _currentModelType != pavementType) {
      throw Exception(
        '${pavementType.name.toUpperCase()} pavement model not loaded',
      );
    }

    try {
      print('Starting detection for ${pavementType.name} pavement...');

      final results = await _flutterVision.yoloOnImage(
        bytesList: bytes,
        imageWidth: width,
        imageHeight: height,
        iouThreshold: 0.2,
        confThreshold: 0.2,
      );

      print(
        'Raw detection results for ${pavementType.name} pavement: ${results.length} detections',
      );

      if (results.isEmpty) {
        print(
          'No detections found - this might be normal if no objects are present',
        );
        return [];
      }

      final currentLabels =
          pavementType == PavementType.flexible
              ? _flexibleLabels
              : _rigidLabels;

      return results.map<Map<String, dynamic>>((r) {
        print('Processing detection result: $r');

        String label;
        // Check if result has 'tag' field (which contains the label name)
        if (r.containsKey('tag') && r['tag'] != null) {
          label = r['tag'].toString();
        }
        // Fallback to class-based mapping if no tag
        else if (r.containsKey('class')) {
          final classIndex = r['class'] ?? 0;
          if (classIndex is int &&
              classIndex >= 0 &&
              classIndex < currentLabels.length) {
            label = currentLabels[classIndex];
          } else {
            label = 'Unknown (class: $classIndex)';
          }
        }
        // Last fallback
        else {
          label = 'Unknown';
        }

        // Extract confidence from box array if it's there
        double confidence = 0.0;
        if (r.containsKey('confidence')) {
          confidence = (r['confidence'] as num?)?.toDouble() ?? 0.0;
        } else if (r['box'] is List && (r['box'] as List).length >= 5) {
          // Sometimes confidence is the 5th element in the box array
          confidence = ((r['box'] as List)[4] as num?)?.toDouble() ?? 0.0;
        }

        print('Mapped - Label: $label, Confidence: $confidence');

        return {
          'box': r['box'],
          'confidence': confidence,
          'label': label,
          'pavementType': pavementType.name,
        };
      }).toList();
    } catch (e) {
      print('Error during ${pavementType.name} pavement detection: $e');
      rethrow;
    }
  }

  // Helper method to get available labels for a specific pavement type
  List<String> getLabelsForPavementType(PavementType pavementType) {
    return pavementType == PavementType.flexible
        ? _flexibleLabels
        : _rigidLabels;
  }

  // Helper method to check if a specific model is loaded
  bool isModelLoaded(PavementType pavementType) {
    return pavementType == PavementType.flexible
        ? _flexibleModelLoaded
        : _rigidModelLoaded;
  }

  // Method to properly dispose resources
  Future<void> dispose() async {
    try {
      await _flutterVision.closeYoloModel();
      _flexibleModelLoaded = false;
      _rigidModelLoaded = false;
      _currentModelType = null;
      _flexibleLabels.clear();
      _rigidLabels.clear();
      print('TFLite service disposed');
    } catch (e) {
      print('Error disposing TFLite service: $e');
    }
  }

  // Method to preload both models (call this during app initialization)
  Future<void> preloadModels() async {
    try {
      print('Preloading models...');
      await loadModel(PavementType.flexible);
      await loadModel(PavementType.rigid);
      print('Both models preloaded successfully');
    } catch (e) {
      print('Error preloading models: $e');
    }
  }
}
