// lib/features/run_tracker/models/activity.dart
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'sensor_reading.dart';

/// Represents a single running activity
class Activity {
  /// Unique identifier for the activity
  final String id;

  /// Name of the activity (auto-generated or user-defined)
  String name;

  /// When the activity started
  final DateTime startTime;

  /// When the activity ended (null if still in progress)
  DateTime? endTime;

  /// Total duration in seconds
  int durationSeconds;

  /// Total distance in meters
  double distanceMeters;

  /// Total elevation gain in meters
  double elevationGainMeters;

  /// Total elevation loss in meters
  double elevationLossMeters;

  /// Average heart rate in BPM
  int? averageHeartRate;

  /// Maximum heart rate in BPM
  int? maxHeartRate;

  /// Average power in watts
  int? averagePower;

  /// Maximum power in watts
  int? maxPower;

  /// Average pace in seconds per kilometer
  int? averagePaceSecondsPerKm;

  /// Average cadence in steps per minute
  int? averageCadence;

  /// Maximum cadence in steps per minute
  int? maxCadence;

  /// List of GPS points throughout the activity
  List<LatLng> routePoints;

  /// List of detailed sensor readings throughout the activity
  List<SensorReading> sensorReadings;

  /// Status of the activity (in_progress, paused, completed)
  String status;

  /// Optional notes added by the user
  String? notes;

  /// Creates a new activity with a generated UUID
  Activity({
    String? id,
    String? name,
    DateTime? startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.distanceMeters = 0,
    this.elevationGainMeters = 0,
    this.elevationLossMeters = 0,
    this.averageHeartRate,
    this.maxHeartRate,
    this.averagePower,
    this.maxPower,
    this.averagePaceSecondsPerKm,
    this.averageCadence,
    this.maxCadence,
    List<LatLng>? routePoints,
    List<SensorReading>? sensorReadings,
    this.status = 'in_progress',
    this.notes,
  })  : id = id ?? const Uuid().v4(),
        name = name ?? 'Activity ${DateTime.now().toString().substring(0, 16)}',
        startTime = startTime ?? DateTime.now(),
        routePoints = routePoints ?? [],
        sensorReadings = sensorReadings ?? [];

  /// Converts activity to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'elevationGainMeters': elevationGainMeters,
      'elevationLossMeters': elevationLossMeters,
      'averageHeartRate': averageHeartRate,
      'maxHeartRate': maxHeartRate,
      'averagePower': averagePower,
      'maxPower': maxPower,
      'averagePaceSecondsPerKm': averagePaceSecondsPerKm,
      'averageCadence': averageCadence,
      'maxCadence': maxCadence,
      'routePointsJson': _encodeRoutePoints(),
      'status': status,
      'notes': notes,
    };
  }

  /// Creates an activity from a database map
  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'],
      name: map['name'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      endTime: map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'])
          : null,
      durationSeconds: map['durationSeconds'],
      distanceMeters: map['distanceMeters'],
      elevationGainMeters: map['elevationGainMeters'],
      elevationLossMeters: map['elevationLossMeters'],
      averageHeartRate: map['averageHeartRate'],
      maxHeartRate: map['maxHeartRate'],
      averagePower: map['averagePower'],
      maxPower: map['maxPower'],
      averagePaceSecondsPerKm: map['averagePaceSecondsPerKm'],
      averageCadence: map['averageCadence'],
      maxCadence: map['maxCadence'],
      routePoints: _decodeRoutePoints(map['routePointsJson']),
      status: map['status'],
      notes: map['notes'],
    );
  }

  /// Calculate average values from sensor readings
  void calculateAverages() {
    if (sensorReadings.isEmpty) return;

    int totalHeartRate = 0;
    int maxHr = 0;
    int validHrReadings = 0;

    int totalPower = 0;
    int maxPwr = 0;
    int validPowerReadings = 0;

    int totalCadence = 0;
    int maxCad = 0;
    int validCadenceReadings = 0;

    // Calculate sums for averages
    for (final reading in sensorReadings) {
      // Heart rate
      if (reading.heartRate != null && reading.heartRate! > 0) {
        totalHeartRate += reading.heartRate!;
        validHrReadings++;
        if (reading.heartRate! > maxHr) {
          maxHr = reading.heartRate!;
        }
      }

      // Power
      if (reading.power != null && reading.power! > 0) {
        totalPower += reading.power!;
        validPowerReadings++;
        if (reading.power! > maxPwr) {
          maxPwr = reading.power!;
        }
      }

      // Cadence
      if (reading.cadence != null && reading.cadence! > 0) {
        totalCadence += reading.cadence!;
        validCadenceReadings++;
        if (reading.cadence! > maxCad) {
          maxCad = reading.cadence!;
        }
      }
    }

    // Calculate averages
    if (validHrReadings > 0) {
      averageHeartRate = (totalHeartRate / validHrReadings).round();
      maxHeartRate = maxHr;
    }

    if (validPowerReadings > 0) {
      averagePower = (totalPower / validPowerReadings).round();
      maxPower = maxPwr;
    }

    if (validCadenceReadings > 0) {
      averageCadence = (totalCadence / validCadenceReadings).round();
      maxCadence = maxCad;
    }

    // Calculate average pace if we have distance and duration
    if (distanceMeters > 0 && durationSeconds > 0) {
      // Convert to seconds per km
      final distanceKm = distanceMeters / 1000;
      final paceSecondsPerKm = (durationSeconds / distanceKm).round();
      averagePaceSecondsPerKm = paceSecondsPerKm;
    }
  }

  /// Encode route points to JSON string for storage
  String _encodeRoutePoints() {
    if (routePoints.isEmpty) return '[]';

    final List<Map<String, double>> points = routePoints
        .map((point) => {
              'lat': point.latitude,
              'lng': point.longitude,
            })
        .toList();

    return points.toString();
  }

  /// Decode route points from JSON string
  static List<LatLng> _decodeRoutePoints(String? json) {
    if (json == null || json == '[]') return [];

    // This is a simple implementation - in a real app you would use a JSON decoder
    // For now, we'll parse the simple format: [{lat: 12.34, lng: 56.78}, {...}]
    final List<LatLng> points = [];

    try {
      // Remove the outer brackets
      final String content = json.substring(1, json.length - 1);

      // Split by "}, {"
      final List<String> pointStrings = content.split('}, {');

      for (var pointStr in pointStrings) {
        // Clean up the string
        pointStr = pointStr.replaceAll('{', '').replaceAll('}', '');

        // Split by comma to get lat and lng
        final parts = pointStr.split(',');

        if (parts.length == 2) {
          // Extract lat and lng values
          final latPart = parts[0].trim();
          final lngPart = parts[1].trim();

          final lat = double.parse(latPart.split(':')[1].trim());
          final lng = double.parse(lngPart.split(':')[1].trim());

          points.add(LatLng(lat, lng));
        }
      }
    } catch (e) {
      debugPrint('Error decoding route points: $e');
    }

    return points;
  }

  /// Format pace from seconds per km to MM:SS format
  static String formatPace(int? secondsPerKm) {
    if (secondsPerKm == null || secondsPerKm <= 0) return '--:--';

    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
