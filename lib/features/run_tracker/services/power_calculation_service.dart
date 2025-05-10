// lib/features/run_tracker/services/power_calculation_service.dart
import 'package:flutter/foundation.dart';
import '../../profile/models/user_profile.dart';

/// Class to calculate running power based on speed, elevation changes, and runner weight
class PowerCalculationService {
  /// Default energy cost of running on flat ground (J/kg/m)
  static const double defaultEcor = 0.98;

  /// Gravity constant (m/s²)
  static const double gravity = 9.81;

  /// User profile for weight and other characteristics
  final UserProfile userProfile;

  /// Create an instance with user profile
  PowerCalculationService({required this.userProfile});

  /// Calculate running power (watts) based on speed, elevation change, and time
  ///
  /// - [speedMps]: Speed in meters per second
  /// - [elevationChangeM]: Elevation change in meters (positive for uphill, negative for downhill)
  /// - [timeSeconds]: Time period in seconds over which the elevation change occurred
  /// - [useCustomEcor]: Whether to use the user's custom ECOR value if available
  ///
  /// Returns: Power in watts
  double calculatePower({
    required double speedMps,
    required double elevationChangeM,
    required double timeSeconds,
    bool useCustomEcor = true,
  }) {
    try {
      // Validate inputs
      if (speedMps < 0) {
        debugPrint(
            'Warning: Negative speed provided to power calculation, using absolute value');
        speedMps = speedMps.abs();
      }

      if (timeSeconds <= 0) {
        debugPrint('Error: Invalid time period for power calculation');
        return 0.0;
      }

      // Get runner's mass (kg)
      final double mass = userProfile.weightKg;

      // Get ECOR value (J/kg/m)
      final double ecor = useCustomEcor ? userProfile.getEcor() : defaultEcor;

      // Calculate horizontal power component (flat ground running)
      final double horizontalPower = mass * ecor * speedMps;

      // Calculate vertical power component (elevation change)
      final double verticalPower = elevationChangeM > 0
          ? mass * gravity * elevationChangeM / timeSeconds
          : 0.0; // No power credit for downhill

      // For downhill running, increase ECOR to account for braking forces
      double downhillFactor = 0.0;
      if (elevationChangeM < 0) {
        // Apply increasing penalty as the grade gets steeper (maxing at 30% extra)
        final double grade = elevationChangeM.abs() / (speedMps * timeSeconds);
        downhillFactor = horizontalPower * _getDownhillPenaltyFactor(grade);
      }

      // Total power is the sum of horizontal and vertical components
      final double totalPower =
          horizontalPower + verticalPower + downhillFactor;

      // Round to nearest integer for display
      return totalPower;
    } catch (e) {
      debugPrint('Error calculating power: $e');
      return 0.0;
    }
  }

  /// Calculate power based on vertical speed (elevation change rate)
  double calculateVerticalPower({
    required double verticalSpeedMps,
  }) {
    try {
      // Get runner's mass (kg)
      final double mass = userProfile.weightKg;

      // Vertical power = mass * gravity * vertical_speed
      double verticalPower = 0.0;

      // Only positive vertical speed (uphill) contributes to power
      if (verticalSpeedMps > 0) {
        verticalPower = mass * gravity * verticalSpeedMps;
      }

      return verticalPower;
    } catch (e) {
      debugPrint('Error calculating vertical power: $e');
      return 0.0;
    }
  }

  /// Calculate power based on acceleration
  double calculateAccelerationPower({
    required double speedMps,
    required double accelerationMps2,
    required double timeSeconds,
  }) {
    try {
      // Get runner's mass (kg)
      final double mass = userProfile.weightKg;

      // Only positive acceleration contributes to power
      if (accelerationMps2 <= 0) {
        return 0.0;
      }

      // Force = mass * acceleration
      final double force = mass * accelerationMps2;

      // Power = force * velocity
      final double power = force * speedMps;

      return power;
    } catch (e) {
      debugPrint('Error calculating acceleration power: $e');
      return 0.0;
    }
  }

  /// Calculate the caloric cost of running
  ///
  /// Returns: Calories burned per hour at the given power output
  double calculateCalories(double powerWatts) {
    try {
      // Convert from watts to kcal/hour
      // 1 watt = 3.6 kJ/hour
      // 1 kcal = 4.184 kJ
      final double kjPerHour = powerWatts * 3.6;
      final double kcalPerHour = kjPerHour / 4.184;

      return kcalPerHour;
    } catch (e) {
      debugPrint('Error calculating calories: $e');
      return 0.0;
    }
  }

  /// Get the downhill penalty factor based on grade
  /// Returns a multiplier for the additional power cost of running downhill
  double _getDownhillPenaltyFactor(double grade) {
    if (grade <= 0.01) return 0.0; // Less than 1% grade has minimal impact

    // Higher grades have increasing penalties
    if (grade < 0.05) return 0.05; // 0-5% grade: 5% penalty
    if (grade < 0.10) return 0.10; // 5-10% grade: 10% penalty
    if (grade < 0.15) return 0.20; // 10-15% grade: 20% penalty
    return 0.30; // >15% grade: 30% penalty
  }

  /// Apply sensor fusion to get a more accurate power estimate
  ///
  /// Combines data from multiple sensors for a better power estimate
  /// - [basicPower]: Power calculated from speed and elevation
  /// - [cadence]: Steps per minute
  /// - [heartRate]: Heart rate in BPM
  /// - [verticalOscillation]: Vertical oscillation in cm (if available)
  /// - [groundContactTime]: Ground contact time in ms (if available)
  ///
  /// Returns: Adjusted power estimate in watts
  double applyPowerSensorFusion({
    required double basicPower,
    int? cadence,
    int? heartRate,
    double? verticalOscillation,
    double? groundContactTime,
  }) {
    try {
      double adjustedPower = basicPower;

      // Running efficiency adjustments based on form metrics
      double efficiencyFactor = 1.0;

      // Cadence adjustment (optimal range typically 170-190 spm)
      if (cadence != null && cadence > 0) {
        if (cadence < 160) {
          // Low cadence is less efficient
          efficiencyFactor *= (1.0 + ((160 - cadence) * 0.003));
        } else if (cadence > 200) {
          // Very high cadence can also be less efficient
          efficiencyFactor *= (1.0 + ((cadence - 200) * 0.002));
        }
      }

      // Vertical oscillation adjustment (lower is generally better)
      if (verticalOscillation != null && verticalOscillation > 0) {
        // Optimal range ~6-10cm
        if (verticalOscillation > 12) {
          efficiencyFactor *= (1.0 + ((verticalOscillation - 12) * 0.01));
        }
      }

      // Ground contact time adjustment (lower is generally better)
      if (groundContactTime != null && groundContactTime > 0) {
        // Optimal range ~200-250ms
        if (groundContactTime > 300) {
          efficiencyFactor *= (1.0 + ((groundContactTime - 300) * 0.0005));
        }
      }

      // Apply efficiency factor
      adjustedPower *= efficiencyFactor;

      // Apply heart rate correlation adjustment if available
      // This helps correct for situations where the calculated power
      // doesn't match the physiological effort indicated by heart rate
      if (heartRate != null && heartRate > 0 && basicPower > 0) {
        // Expected heart rate for the given power
        // This is a simplified model; a real implementation would use
        // more sophisticated models based on training history
        final expectedHr = _estimateHeartRateFromPower(basicPower);

        // If actual HR is significantly different from expected, adjust power
        if (expectedHr > 0) {
          final hrRatio = heartRate.toDouble() / expectedHr;

          // Only make modest adjustments (max 15% either way)
          if (hrRatio > 1.2) {
            // HR higher than expected, increase power estimate (capped at 15%)
            adjustedPower *= Math.min(1.15, 1.0 + (hrRatio - 1.0) * 0.5);
          } else if (hrRatio < 0.8) {
            // HR lower than expected, decrease power estimate (capped at 15%)
            adjustedPower *= Math.max(0.85, 1.0 - (1.0 - hrRatio) * 0.5);
          }
        }
      }

      return adjustedPower;
    } catch (e) {
      debugPrint('Error applying sensor fusion to power: $e');
      return basicPower; // Return original power if fusion fails
    }
  }

  /// Estimate heart rate from power using a simplified model
  double _estimateHeartRateFromPower(double powerWatts) {
    try {
      // Very basic model - should be calibrated to the individual
      // In a real system, this would use the user's physiological data
      // from previous runs to build a more accurate model

      // Base heart rate
      double baseHr = 70.0;

      // Age-adjusted max HR
      double maxHr = 220.0 - userProfile.age.toDouble();

      // Reserve HR
      double reserveHr = maxHr - baseHr;

      // Typical FTP (Functional Threshold Power) for runners
      // This is highly individual and varies with fitness level
      // In a real app, this would be calculated from user's test results
      double estimatedFtp = userProfile.weightKg * 3.5;

      // Power as percentage of FTP
      double powerPctOfFtp = powerWatts / estimatedFtp;

      // Heart rate typically follows a non-linear relationship with power
      // This is a simple curve approximation
      double hrPctOfReserve;
      if (powerPctOfFtp <= 0.85) {
        // Below threshold, HR increases somewhat linearly with power
        hrPctOfReserve = powerPctOfFtp * 0.9;
      } else {
        // Above threshold, HR increases more rapidly
        hrPctOfReserve = 0.765 + (powerPctOfFtp - 0.85) * 1.5;
      }

      // Cap at 100% of reserve
      hrPctOfReserve = Math.min(1.0, hrPctOfReserve);

      // Calculate estimated heart rate
      double estimatedHr = baseHr + (reserveHr * hrPctOfReserve);

      return estimatedHr;
    } catch (e) {
      debugPrint('Error estimating heart rate from power: $e');
      return 0.0;
    }
  }
}

/// Simple Math helper class to avoid importing dart:math
class Math {
  static double min(double a, double b) => a < b ? a : b;
  static double max(double a, double b) => a > b ? a : b;
}
