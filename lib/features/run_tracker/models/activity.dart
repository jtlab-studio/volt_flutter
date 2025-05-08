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

  /// Calculate average values from sensor readings - Enhanced Version
  void calculateAverages() {
    if (sensorReadings.isEmpty) {
      debugPrint('Activity.calculateAverages: No sensor readings available');
      return;
    }

    debugPrint(
        'Activity.calculateAverages: Processing ${sensorReadings.length} readings');

    int totalHeartRate = 0;
    int maxHr = 0;
    int validHrReadings = 0;

    int totalPower = 0;
    int maxPwr = 0;
    int validPowerReadings = 0;

    int totalCadence = 0;
    int maxCad = 0;
    int validCadenceReadings = 0;

    // Sample a few readings to see what data we have
    debugPrint('Activity.calculateAverages: First 3 readings sample:');
    for (int i = 0; i < sensorReadings.length && i < 3; i++) {
      final r = sensorReadings[i];
      debugPrint(
          '  Reading $i: HR=${r.heartRate}, Power=${r.power}, Cadence=${r.cadence}, Source=${r.source}');
    }

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

    // Debug logs for troubleshooting - Fixed string concatenation
    debugPrint('Activity.calculateAverages: Valid readings counts - '
        'HR: $validHrReadings/$totalHeartRate, '
        'Power: $validPowerReadings/$totalPower, '
        'Cadence: $validCadenceReadings/$totalCadence');

    // Calculate heart rate averages
    if (validHrReadings > 0) {
      averageHeartRate = (totalHeartRate / validHrReadings).round();
      maxHeartRate = maxHr;
      debugPrint(
          'Activity.calculateAverages: Set Avg HR=$averageHeartRate, Max HR=$maxHeartRate');
    } else {
      debugPrint('Activity.calculateAverages: No valid heart rate readings');
    }

    // Calculate power averages
    if (validPowerReadings > 0) {
      averagePower = (totalPower / validPowerReadings).round();
      maxPower = maxPwr;
      debugPrint(
          'Activity.calculateAverages: Set Avg Power=$averagePower, Max Power=$maxPower');
    } else {
      debugPrint('Activity.calculateAverages: No valid power readings');
    }

    // Calculate cadence averages
    if (validCadenceReadings > 0) {
      averageCadence = (totalCadence / validCadenceReadings).round();
      maxCadence = maxCad;
      debugPrint(
          'Activity.calculateAverages: Set Avg Cadence=$averageCadence, Max Cadence=$maxCadence');
    } else {
      debugPrint('Activity.calculateAverages: No valid cadence readings');
    }

    // Calculate average pace
    if (distanceMeters > 0 && durationSeconds > 0) {
      final distanceKm = distanceMeters / 1000;
      final paceSecondsPerKm = (durationSeconds / distanceKm).round();

      // Only set if the calculated pace is reasonable
      if (paceSecondsPerKm > 0 && paceSecondsPerKm < 1200) {
        // Between 0:00 and 20:00 min/km
        averagePaceSecondsPerKm = paceSecondsPerKm;
        debugPrint(
            'Activity.calculateAverages: Set Avg Pace=$averagePaceSecondsPerKm sec/km');
      } else {
        debugPrint(
            'Activity.calculateAverages: Calculated pace $paceSecondsPerKm sec/km is not reasonable');
      }
    } else {
      debugPrint(
          'Activity.calculateAverages: Cannot calculate pace - distance=$distanceMeters, duration=$durationSeconds');
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
