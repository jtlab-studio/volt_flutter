// lib/features/run_tracker/providers/enhanced_tracker_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity.dart';
import '../services/tracker_service.dart';
import '../services/power_calculation_service.dart';
import '../services/sensor_fusion_service.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/providers/profile_providers.dart';

// Provider for the tracker service
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
    // We need to provide these values dynamically since they're not in TrackerService
    'speedMps': 0.0, // This will be calculated by the SensorFusionService
    'elevationChange':
        0.0, // This will be calculated by the SensorFusionService
    'timeInterval': 1.0, // Default 1 second interval
    // Include the current activity so we can access its average values
    'currentActivity': service.currentActivity,
  };
});

// Provider for power calculation service
final powerCalculationServiceProvider =
    Provider<PowerCalculationService>((ref) {
  // Get user profile for weight data
  final userProfile = ref.watch(userProfileProvider).valueOrNull;

  // If profile is not loaded yet, use a default profile
  final profile = userProfile ?? UserProfile();

  return PowerCalculationService(userProfile: profile);
});

// Provider for sensor fusion service
final sensorFusionServiceProvider = Provider<SensorFusionService>((ref) {
  return SensorFusionService();
});

// Provider for real-time power calculation
final currentPowerProvider = Provider<int?>((ref) {
  final trackerService = ref.watch(trackerServiceProvider);
  final metrics = ref.watch(currentMetricsProvider);

  // If we already have power from a Stryd sensor, use that
  if (trackerService.lastPower != null && trackerService.lastPower! > 0) {
    return trackerService.lastPower;
  }

  // Otherwise, calculate power using our service
  final powerService = ref.watch(powerCalculationServiceProvider);

  // Check if we have the necessary data for calculation
  final speed = metrics['speedMps'] as double?;
  final elevationChange = metrics['elevationChange'] as double?;
  final timeInterval = metrics['timeInterval'] as double?;

  if (speed != null && elevationChange != null && timeInterval != null) {
    final power = powerService.calculatePower(
      speedMps: speed,
      elevationChangeM: elevationChange,
      timeSeconds: timeInterval,
    );

    // Apply sensor fusion with heart rate if available
    final heartRate = trackerService.lastHeartRate;
    final cadence = trackerService.lastCadence;

    return powerService
        .applyPowerSensorFusion(
          basicPower: power,
          heartRate: heartRate,
          cadence: cadence,
        )
        .round();
  }

  return null;
});

// Provider for GPS accuracy estimation
final gpsAccuracyProvider = Provider<double>((ref) {
  // This would typically come from the GPS signal itself
  // For simplicity, we're using a fixed value for now
  return 3.0; // meters
});

// Provider for calculating calories burned
final caloriesBurnedProvider = Provider<double>((ref) {
  final trackerService = ref.watch(trackerServiceProvider);
  final powerService = ref.watch(powerCalculationServiceProvider);

  // Get average power either from Stryd or calculated
  final avgPower = trackerService.currentActivity?.averagePower;

  if (avgPower != null && avgPower > 0) {
    // Calculate calories per hour
    final caloriesPerHour = powerService.calculateCalories(avgPower.toDouble());

    // Pro-rate based on actual duration
    final durationHours =
        trackerService.currentActivity!.durationSeconds / 3600;
    return caloriesPerHour * durationHours;
  }

  return 0.0;
});

// Provider for step detection
final stepCountProvider = StateNotifierProvider<StepCountNotifier, int>((ref) {
  return StepCountNotifier();
});

// Step count notifier
class StepCountNotifier extends StateNotifier<int> {
  StepCountNotifier() : super(0);

  void incrementSteps(int count) {
    state += count;
  }

  void reset() {
    state = 0;
  }
}

// Provider for fetching activity summary in preferred units
final activitySummaryProvider =
    Provider.family<Map<String, dynamic>, Activity>((ref, activity) {
  final distanceFormatter = ref.watch(distanceFormatterProvider);
  final paceFormatter = ref.watch(paceFormatterProvider);

  // Format all values according to user preferences
  return {
    'name': activity.name,
    'date': activity.startTime,
    'duration': TrackerService.formatDuration(activity.durationSeconds),
    'distance': distanceFormatter(activity.distanceMeters),
    'pace': paceFormatter(activity.averagePaceSecondsPerKm ?? 0),
    'heartRate': activity.averageHeartRate != null
        ? '${activity.averageHeartRate} bpm'
        : '--',
    'power':
        activity.averagePower != null ? '${activity.averagePower} W' : '--',
    'cadence': activity.averageCadence != null
        ? '${activity.averageCadence} spm'
        : '--',
    'elevationGain': '${activity.elevationGainMeters.toStringAsFixed(0)} m',
    'elevationLoss': '${activity.elevationLossMeters.toStringAsFixed(0)} m',
    // Add calories calculation if needed
  };
});

// Provider for advanced metrics display options
final showAdvancedMetricsProvider = StateProvider<bool>((ref) => false);

// Provider for metrics screen layout
final metricsLayoutProvider = StateProvider<String>((ref) => 'standard');
