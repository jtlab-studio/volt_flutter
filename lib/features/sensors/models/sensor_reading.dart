// lib/features/run_tracker/models/sensor_reading.dart
import 'package:latlong2/latlong.dart';

/// A single data point during an activity with all sensor measurements
class SensorReading {
  /// Associated activity ID
  final String activityId;

  /// Timestamp when this reading was recorded
  final DateTime timestamp;

  /// GPS location (latitude/longitude)
  final LatLng? location;

  /// Elevation in meters
  final double? elevationMeters;

  /// Heart rate in beats per minute (from HRM)
  final int? heartRate;

  /// Power in watts (from Stryd)
  final int? power;

  /// Cadence in steps per minute (from Stryd)
  final int? cadence;

  /// Distance in meters (from Stryd)
  final double? distanceMeters;

  /// Pace in seconds per kilometer (from GPS or Stryd)
  final int? paceSecondsPerKm;

  /// Source of the reading (GPS, HRM, Stryd, etc.)
  final String? source;

  SensorReading({
    required this.activityId,
    required this.timestamp,
    this.location,
    this.elevationMeters,
    this.heartRate,
    this.power,
    this.cadence,
    this.distanceMeters,
    this.paceSecondsPerKm,
    this.source,
  });

  /// Converts reading to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      'activityId': activityId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'elevationMeters': elevationMeters,
      'heartRate': heartRate,
      'power': power,
      'cadence': cadence,
      'distanceMeters': distanceMeters,
      'paceSecondsPerKm': paceSecondsPerKm,
      'source': source,
    };
  }

  /// Creates a reading from a database map
  factory SensorReading.fromMap(Map<String, dynamic> map) {
    LatLng? location;
    if (map['latitude'] != null && map['longitude'] != null) {
      location = LatLng(map['latitude'], map['longitude']);
    }

    return SensorReading(
      activityId: map['activityId'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      location: location,
      elevationMeters: map['elevationMeters'],
      heartRate: map['heartRate'],
      power: map['power'],
      cadence: map['cadence'],
      distanceMeters: map['distanceMeters'],
      paceSecondsPerKm: map['paceSecondsPerKm'],
      source: map['source'],
    );
  }

  /// Creates a reading with only GPS data
  factory SensorReading.fromGps({
    required String activityId,
    required DateTime timestamp,
    required LatLng location,
    double? elevationMeters,
  }) {
    return SensorReading(
      activityId: activityId,
      timestamp: timestamp,
      location: location,
      elevationMeters: elevationMeters,
      source: 'GPS',
    );
  }

  /// Creates a reading with heart rate data
  factory SensorReading.fromHrm({
    required String activityId,
    required DateTime timestamp,
    required int heartRate,
  }) {
    return SensorReading(
      activityId: activityId,
      timestamp: timestamp,
      heartRate: heartRate,
      source: 'HRM',
    );
  }

  /// Creates a reading with Stryd data
  factory SensorReading.fromStryd({
    required String activityId,
    required DateTime timestamp,
    int? power,
    int? cadence,
    double? distanceMeters,
    int? paceSecondsPerKm,
  }) {
    return SensorReading(
      activityId: activityId,
      timestamp: timestamp,
      power: power,
      cadence: cadence,
      distanceMeters: distanceMeters,
      paceSecondsPerKm: paceSecondsPerKm,
      source: 'Stryd',
    );
  }

  /// Format pace from seconds per km to MM:SS format
  static String formatPace(int? secondsPerKm) {
    if (secondsPerKm == null || secondsPerKm <= 0) return '--:--';

    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
