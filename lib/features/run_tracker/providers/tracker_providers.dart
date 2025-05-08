// lib/features/run_tracker/providers/tracker_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity.dart';
import '../models/sensor_reading.dart';
import '../services/tracker_service.dart';
import '../services/database_service.dart';

// Provider for tracker service
final trackerServiceProvider = ChangeNotifierProvider<TrackerService>((ref) {
  return TrackerService();
});

// Provider for current tracker state
final trackerStateProvider = Provider<TrackerState>((ref) {
  return ref.watch(trackerServiceProvider).state;
});

// Provider for current activity
final currentActivityProvider = Provider<Activity?>((ref) {
  return ref.watch(trackerServiceProvider).currentActivity;
});

// Provider for sensor connection status
final sensorStatusProvider = Provider<Map<String, bool>>((ref) {
  final service = ref.watch(trackerServiceProvider);
  return {
    'gps': service.isGpsConnected,
    'hrm': service.isHrmConnected,
    'stryd': service.isStrydConnected,
  };
});

// Provider for current metrics
final currentMetricsProvider = Provider<Map<String, dynamic>>((ref) {
  final service = ref.watch(trackerServiceProvider);

  return {
    'duration': service.currentActivity?.durationSeconds ?? 0,
    'distance': service.totalDistanceMeters,
    'pace': service.lastPace,
    'heartRate': service.lastHeartRate,
    'power': service.lastPower,
    'cadence': service.lastCadence,
    'elevationGain': service.elevationGainMeters,
    'elevationLoss': service.elevationLossMeters,
  };
});

// Provider for activity history list
final activityHistoryProvider = FutureProvider<List<Activity>>((ref) async {
  final service = ref.watch(trackerServiceProvider);
  return await service.getActivityHistory();
});

// Provider for activity details by ID
final activityDetailsProvider =
    FutureProvider.family<Activity?, String>((ref, id) async {
  final dbService = DatabaseService.instance;
  return await dbService.getActivity(id);
});

// Provider for activity sensor readings
final activityReadingsProvider =
    FutureProvider.family<List<SensorReading>, String>((ref, id) async {
  final service = ref.watch(trackerServiceProvider);
  return await service.getActivityReadings(id);
});

// Provider for activity route
final activityRouteProvider =
    FutureProvider.family<List<SensorReading>, String>((ref, id) async {
  final service = ref.watch(trackerServiceProvider);
  return await service.getActivityRoute(id);
});
