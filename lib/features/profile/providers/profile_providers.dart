// lib/features/profile/providers/profile_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';

/// Provider for accessing the user profile
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  // Load the user profile from storage
  return UserProfile.load();
});

/// Provider for accessing the ECOR value
final ecorProvider = Provider<double>((ref) {
  // Get the cached user profile if available, otherwise use default
  final userProfileValue = ref.watch(userProfileProvider).valueOrNull;

  if (userProfileValue != null) {
    // Get ECOR from user profile (will use custom value if set)
    return userProfileValue.getEcor();
  } else {
    // Default ECOR value if profile not loaded yet
    return 0.98;
  }
});

/// Provider for checking if we should use imperial units
final useImperialUnitsProvider = Provider<bool>((ref) {
  final userProfileValue = ref.watch(userProfileProvider).valueOrNull;

  if (userProfileValue != null) {
    return userProfileValue.distanceUnit == 'mi';
  } else {
    // Default to metric
    return false;
  }
});

/// Provider for getting the user's weight for power calculations
final userWeightProvider = Provider<double>((ref) {
  final userProfileValue = ref.watch(userProfileProvider).valueOrNull;

  if (userProfileValue != null) {
    return userProfileValue.weightKg;
  } else {
    // Default weight if profile not loaded yet
    return 70.0;
  }
});

/// Provider that calculates the BMI
final bmiProvider = Provider<double?>((ref) {
  final userProfileValue = ref.watch(userProfileProvider).valueOrNull;

  if (userProfileValue != null) {
    // Calculate BMI
    return userProfileValue.calculateBmi();
  } else {
    // No BMI if profile not loaded
    return null;
  }
});

/// Provider that formats pace according to user preferences
final paceFormatterProvider = Provider<String Function(int)>((ref) {
  final userProfileValue = ref.watch(userProfileProvider).valueOrNull;

  if (userProfileValue != null) {
    // Use user's pace formatter
    return (int secondsPerKm) => userProfileValue.formatPace(secondsPerKm);
  } else {
    // Default formatter uses min/km
    return (int secondsPerKm) {
      final minutes = secondsPerKm ~/ 60;
      final seconds = secondsPerKm % 60;
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    };
  }
});

/// Provider that formats distance according to user preferences
final distanceFormatterProvider = Provider<String Function(double)>((ref) {
  final useImperial = ref.watch(useImperialUnitsProvider);

  return (double distanceMeters) {
    final distanceKm = distanceMeters / 1000;

    if (useImperial) {
      // Convert to miles
      final distanceMiles = distanceKm * 0.621371;
      return '${distanceMiles.toStringAsFixed(2)} mi';
    } else {
      // Use kilometers
      return '${distanceKm.toStringAsFixed(2)} km';
    }
  };
});
