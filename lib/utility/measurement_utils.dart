import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Utility class for measurement conversions and calculations
class MeasurementUtils {
  /// Convert between measurement units
  static double convertUnit(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;

    if (fromUnit == 'cm' && toUnit == 'in') {
      return value / 2.54;
    } else if (fromUnit == 'in' && toUnit == 'cm') {
      return value * 2.54;
    }
    return value;
  }

  /// Get distance between two points in pixels
  static double getPixelDistance(Offset point1, Offset point2) {
    return sqrt(pow(point2.dx - point1.dx, 2) + pow(point2.dy - point1.dy, 2));
  }

  /// Convert pixel distance to real-world units using calibration factor
  /// calibrationFactor = real world unit length per pixel (e.g., cm/px)
  static double pixelsToUnits(double pixelDistance, double calibrationFactor) {
    return pixelDistance * calibrationFactor;
  }

  /// Calculate angle between two points (in degrees)
  static double calculateAngle(Offset point1, Offset point2) {
    final dx = point2.dx - point1.dx;
    final dy = point2.dy - point1.dy;
    final radians = atan2(dy, dx);
    return radians * (180 / pi);
  }

  /// Calculate polygon area (in pixels²) using shoelace formula
  static double calculateArea(List<Offset> points) {
    if (points.length < 3) return 0;

    double area = 0;
    int j = points.length - 1;
    for (int i = 0; i < points.length; i++) {
      area += (points[j].dx + points[i].dx) * (points[j].dy - points[i].dy);
      j = i;
    }
    return area.abs() / 2;
  }

  /// Format measurement value for display based on magnitude
  static String formatMeasurement(double value, String unit) {
    if (value < 0.1) {
      return '${value.toStringAsFixed(3)} $unit';
    } else if (value < 10) {
      return '${value.toStringAsFixed(2)} $unit';
    } else {
      return '${value.toStringAsFixed(1)} $unit';
    }
  }

  /// Check if the camera supports distance measurement (stub - update if supported)
  static bool hasCameraDistanceMeasurement(CameraDescription camera) {
    return false;
  }
}
