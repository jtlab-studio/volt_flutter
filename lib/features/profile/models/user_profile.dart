// lib/features/profile/models/user_profile.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Represents the user's profile with stored settings and physical characteristics
class UserProfile {
  /// User's display name
  String name;

  /// User's weight in kilograms (needed for power calculations)
  double weightKg;

  /// User's height in centimeters
  double heightCm;

  /// User's age in years
  int age;

  /// User's biological sex (affects some calculations)
  String biologicalSex; // 'male', 'female', 'other'

  /// User's preferred distance unit ('km' or 'mi')
  String distanceUnit;

  /// User's preferred pace unit ('min/km' or 'min/mi')
  String paceUnit;

  /// Custom ECOR value if the user wants to override the default
  double? customEcor;

  /// Date the profile was last updated
  DateTime lastUpdated;

  /// Creates a new user profile
  UserProfile({
    this.name = 'Runner',
    this.weightKg = 70.0,
    this.heightCm = 170.0,
    this.age = 30,
    this.biologicalSex = 'other',
    this.distanceUnit = 'km',
    this.paceUnit = 'min/km',
    this.customEcor,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Convert profile to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'age': age,
      'biologicalSex': biologicalSex,
      'distanceUnit': distanceUnit,
      'paceUnit': paceUnit,
      'customEcor': customEcor,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  /// Create a profile from a map
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] ?? 'Runner',
      weightKg: map['weightKg']?.toDouble() ?? 70.0,
      heightCm: map['heightCm']?.toDouble() ?? 170.0,
      age: map['age'] ?? 30,
      biologicalSex: map['biologicalSex'] ?? 'other',
      distanceUnit: map['distanceUnit'] ?? 'km',
      paceUnit: map['paceUnit'] ?? 'min/km',
      customEcor: map['customEcor']?.toDouble(),
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'])
          : DateTime.now(),
    );
  }

  /// Save profile to shared preferences
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(toMap());
      await prefs.setString('user_profile', json);
      debugPrint('User profile saved successfully');
    } catch (e) {
      debugPrint('Error saving user profile: $e');
    }
  }

  /// Load profile from shared preferences
  static Future<UserProfile> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('user_profile');

      if (json == null) {
        debugPrint('No saved user profile found, returning default');
        return UserProfile();
      }

      final map = jsonDecode(json) as Map<String, dynamic>;
      return UserProfile.fromMap(map);
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      return UserProfile();
    }
  }

  /// Get the ECOR (Energy Cost of Running) value
  /// Uses custom value if set, otherwise calculates based on user characteristics
  double getEcor() {
    // If custom ECOR is set, use that
    if (customEcor != null) {
      return customEcor!;
    }

    // Base ECOR value (J/kg/m)
    double baseEcor = 0.98;

    // Adjust for biological sex (slight differences in biomechanics)
    if (biologicalSex == 'female') {
      baseEcor *= 1.03; // ~3% higher on average
    }

    // Adjust for age (efficiency decreases with age)
    if (age > 50) {
      baseEcor *=
          (1.0 + ((age - 50) * 0.003)); // ~0.3% increase per year over 50
    }

    // Weight adjustments (heavier runners generally have higher ECOR)
    if (weightKg > 80) {
      baseEcor *=
          (1.0 + ((weightKg - 80) * 0.002)); // ~0.2% increase per kg over 80
    } else if (weightKg < 50) {
      baseEcor *=
          (1.0 - ((50 - weightKg) * 0.001)); // ~0.1% decrease per kg under 50
    }

    return baseEcor;
  }

  /// Calculate BMI (Body Mass Index)
  double calculateBmi() {
    // BMI = weight(kg) / height(m)^2
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  /// Convert distance from metric to imperial or vice versa
  double convertDistance(double distance, {bool toImperial = true}) {
    if (toImperial) {
      return distance * 0.621371; // km to miles
    } else {
      return distance * 1.60934; // miles to km
    }
  }

  /// Format pace based on user's preferred unit
  String formatPace(int secondsPerKm) {
    if (paceUnit == 'min/mi') {
      // Convert to seconds per mile
      final secondsPerMile = (secondsPerKm * 1.60934).round();
      return _formatTimeFromSeconds(secondsPerMile);
    } else {
      return _formatTimeFromSeconds(secondsPerKm);
    }
  }

  /// Helper to format seconds to MM:SS
  String _formatTimeFromSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
