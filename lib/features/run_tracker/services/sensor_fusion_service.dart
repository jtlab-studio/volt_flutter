// lib/features/run_tracker/services/sensor_fusion_service.dart
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

/// A service that fuses data from multiple sensors to provide improved activity metrics
class SensorFusionService {
  // Constants for filtering
  static const double _alphaLowPass = 0.1; // Lower means more smoothing

  // State variables for storing previous measurements
  LatLng? _lastPosition;
  DateTime? _lastPositionTime;
  double? _lastElevation;
  int? _lastStepCount;

  // Low-pass filtered values
  double? _filteredSpeed;
  double? _filteredElevation;
  double? _filteredVerticalSpeed;

  // Cumulative distance and elevation
  double _totalDistanceMeters = 0.0;
  double _elevationGainMeters = 0.0;
  double _elevationLossMeters = 0.0;

  // Error tracking
  int _gpsErrorCount = 0;
  bool _useFallbackMode = false;

  /// Creates a new instance of the sensor fusion service
  SensorFusionService();

  /// Reset the service state
  void reset() {
    _lastPosition = null;
    _lastPositionTime = null;
    _lastElevation = null;
    _lastStepCount = null;
    _filteredSpeed = null;
    _filteredElevation = null;
    _filteredVerticalSpeed = null;
    _totalDistanceMeters = 0.0;
    _elevationGainMeters = 0.0;
    _elevationLossMeters = 0.0;
    _gpsErrorCount = 0;
    _useFallbackMode = false;
  }

  /// Update metrics with a new GPS position
  ///
  /// Returns a map containing the updated metrics
  Map<String, dynamic> updateWithGpsPosition(Position position) {
    try {
      final results = <String, dynamic>{
        'positionUpdated': false,
        'distanceChanged': false,
        'elevationChanged': false,
        'speedUpdated': false,
      };

      // Create LatLng from position
      final currentPosition = LatLng(position.latitude, position.longitude);
      final currentTime = position.timestamp;

      // Calculate distance if we have a previous position
      if (_lastPosition != null && _lastPositionTime != null) {
        final distanceChange =
            _calculateDistance(_lastPosition!, currentPosition);

        // Check if the distance change is reasonable (basic sanity check)
        if (distanceChange < 50) {
          // Max 50m per update as a sanity check
          _totalDistanceMeters += distanceChange;
          results['distanceChanged'] = true;
          results['distanceMeters'] = _totalDistanceMeters;
        } else {
          // GPS jump detected, increment error count
          _gpsErrorCount++;
          debugPrint('GPS jump detected: $distanceChange meters');

          // Switch to fallback mode if we get too many errors
          if (_gpsErrorCount > 5) {
            _useFallbackMode = true;
            debugPrint('Too many GPS errors, switching to fallback mode');
          }
        }
      }

      // Process elevation data
      if (position.altitude != 0) {
        final double currentElevation = position.altitude;

        // Apply low-pass filter to smooth elevation data
        if (_filteredElevation != null) {
          _filteredElevation = _lowPassFilter(
              _filteredElevation!, currentElevation, _alphaLowPass);
        } else {
          _filteredElevation = currentElevation;
        }

        // Calculate elevation change if we have a previous filtered elevation
        if (_lastElevation != null) {
          final elevationChange = _filteredElevation! - _lastElevation!;

          // Only count significant changes (>0.5m) to avoid noise
          if (elevationChange.abs() > 0.5) {
            results['elevationChanged'] = true;

            // Track cumulative gain and loss
            if (elevationChange > 0) {
              _elevationGainMeters += elevationChange;
              results['elevationGainMeters'] = _elevationGainMeters;
            } else {
              _elevationLossMeters += elevationChange.abs();
              results['elevationLossMeters'] = _elevationLossMeters;
            }

            // Calculate vertical speed (m/s)
            if (_lastPositionTime != null) {
              final timeElapsed =
                  currentTime.difference(_lastPositionTime!).inMilliseconds /
                      1000;
              if (timeElapsed > 0) {
                final verticalSpeed = elevationChange / timeElapsed;

                // Apply low-pass filter to vertical speed
                if (_filteredVerticalSpeed != null) {
                  _filteredVerticalSpeed = _lowPassFilter(
                      _filteredVerticalSpeed!, verticalSpeed, _alphaLowPass);
                } else {
                  _filteredVerticalSpeed = verticalSpeed;
                }

                results['verticalSpeedMps'] = _filteredVerticalSpeed;
              }
            }
          }
        }

        // Update last elevation
        _lastElevation = _filteredElevation;
      }

      // Process speed data
      if (position.speed >= 0) {
        // Apply low-pass filter to smooth speed data
        if (_filteredSpeed != null) {
          _filteredSpeed =
              _lowPassFilter(_filteredSpeed!, position.speed, _alphaLowPass);
        } else {
          _filteredSpeed = position.speed;
        }

        results['speedUpdated'] = true;
        results['speedMps'] = _filteredSpeed;

        // Calculate pace (seconds per kilometer)
        if (_filteredSpeed! > 0) {
          final paceSecondsPerKm = (1000 / _filteredSpeed!).round();
          results['paceSecondsPerKm'] = paceSecondsPerKm;
        }
      }

      // Update last position
      _lastPosition = currentPosition;
      _lastPositionTime = currentTime;

      results['positionUpdated'] = true;
      results['position'] = currentPosition;

      return results;
    } catch (e) {
      debugPrint('Error updating with GPS position: $e');
      return {'error': e.toString()};
    }
  }

  /// Update metrics with accelerometer data
  ///
  /// This method uses accelerometer data to estimate steps and distance
  /// when GPS data is unavailable or unreliable
  ///
  /// [accelerationX], [accelerationY], [accelerationZ]: Acceleration values in m/s²
  /// [timeStamp]: Timestamp of the reading
  Map<String, dynamic> updateWithAccelerometer(
    double accelerationX,
    double accelerationY,
    double accelerationZ,
    DateTime timeStamp,
  ) {
    try {
      // Only use accelerometer in fallback mode (when GPS is unreliable)
      if (!_useFallbackMode) {
        return {};
      }

      final results = <String, dynamic>{};

      // Calculate magnitude of acceleration
      final accelMagnitude = math.sqrt(accelerationX * accelerationX +
          accelerationY * accelerationY +
          accelerationZ * accelerationZ);

      // Simple step detection with thresholding
      // This is a very basic approach - a real implementation would use
      // more sophisticated algorithms like peak detection
      const stepThreshold = 12.0; // Threshold for step detection

      // Detect steps based on acceleration magnitude crossing the threshold
      bool isStep = accelMagnitude > stepThreshold;

      if (isStep) {
        // Estimate distance based on steps
        // Use a simple model: 1 step ≈ 0.7 meters (average stride length)
        const strideLength = 0.7;
        _totalDistanceMeters += strideLength;

        results['distanceChanged'] = true;
        results['distanceMeters'] = _totalDistanceMeters;

        // Estimate speed as moving average
        // A more sophisticated approach would account for cadence and stride length

        // For now, we'll use a fixed speed estimate
        const estimatedSpeed = 1.5; // m/s (moderate walking pace)

        if (_filteredSpeed != null) {
          _filteredSpeed =
              _lowPassFilter(_filteredSpeed!, estimatedSpeed, _alphaLowPass);
        } else {
          _filteredSpeed = estimatedSpeed;
        }

        results['speedUpdated'] = true;
        results['speedMps'] = _filteredSpeed;
      }

      return results;
    } catch (e) {
      debugPrint('Error updating with accelerometer data: $e');
      return {'error': e.toString()};
    }
  }

  /// Update metrics with barometer data
  ///
  /// This method uses barometer data to estimate elevation changes,
  /// particularly in situations where GPS-based elevation is unreliable
  ///
  /// [pressurePa]: Atmospheric pressure in Pascals
  /// [timeStamp]: Timestamp of the reading
  Map<String, dynamic> updateWithBarometer(
      double pressurePa, DateTime timeStamp) {
    try {
      final results = <String, dynamic>{};

      // Convert pressure to elevation using the barometric formula
      // This is an approximation and should be calibrated for local conditions
      const standardPressure = 101325.0; // Standard sea-level pressure in Pa
      const temperatureK = 288.15; // Standard temperature in Kelvin (15°C)
      const gasConstant = 8.31432; // Universal gas constant
      const gravitationalAcceleration = 9.80665; // g in m/s²
      const molarMass = 0.0289644; // Molar mass of Earth's air in kg/mol

      // Barometric formula: h = -(RT/Mg) * ln(P/P₀)
      final elevation = -(temperatureK * gasConstant) /
          (molarMass * gravitationalAcceleration) *
          math.log(pressurePa / standardPressure);

      // Apply low-pass filter to smooth elevation data
      if (_filteredElevation != null) {
        // Weight barometer data for elevation
        const weightBarometer = 0.85;
        _filteredElevation = _lowPassFilter(
            _filteredElevation!, elevation, _alphaLowPass * weightBarometer);
      } else {
        _filteredElevation = elevation;
      }

      // Calculate elevation change if we have a previous filtered elevation
      if (_lastElevation != null) {
        final elevationChange = _filteredElevation! - _lastElevation!;

        // Only count significant changes to avoid noise
        if (elevationChange.abs() > 0.5) {
          results['elevationChanged'] = true;

          // Track cumulative gain and loss
          if (elevationChange > 0) {
            _elevationGainMeters += elevationChange;
            results['elevationGainMeters'] = _elevationGainMeters;
          } else {
            _elevationLossMeters += elevationChange.abs();
            results['elevationLossMeters'] = _elevationLossMeters;
          }
        }
      }

      // Update last elevation
      _lastElevation = _filteredElevation;

      return results;
    } catch (e) {
      debugPrint('Error updating with barometer data: $e');
      return {'error': e.toString()};
    }
  }

  /// Update metrics with step counter data
  ///
  /// This method uses step counter data from the phone's step sensor
  /// to estimate distance when GPS is unreliable
  ///
  /// [steps]: Number of steps counted
  /// [timeStamp]: Timestamp of the reading
  Map<String, dynamic> updateWithStepCounter(int steps, DateTime timeStamp) {
    try {
      // Only use step counter in fallback mode (when GPS is unreliable)
      if (!_useFallbackMode) {
        return {};
      }

      final results = <String, dynamic>{};

      // Calculate step difference
      if (_lastStepCount != null) {
        final stepDiff = steps - _lastStepCount!;

        // Only process positive step differences
        if (stepDiff > 0) {
          // Estimate distance based on steps
          // Use a simple model: 1 step ≈ 0.7 meters (average stride length)
          const strideLength = 0.7;
          final distanceChange = stepDiff * strideLength;

          _totalDistanceMeters += distanceChange;

          results['distanceChanged'] = true;
          results['distanceMeters'] = _totalDistanceMeters;

          // Estimate speed from steps
          // If we have a timestamp from the last measurement
          if (_lastPositionTime != null) {
            final duration =
                timeStamp.difference(_lastPositionTime!).inMilliseconds / 1000;

            if (duration > 0) {
              final speed = distanceChange / duration;

              // Update filtered speed
              if (_filteredSpeed != null) {
                _filteredSpeed =
                    _lowPassFilter(_filteredSpeed!, speed, _alphaLowPass);
              } else {
                _filteredSpeed = speed;
              }

              results['speedUpdated'] = true;
              results['speedMps'] = _filteredSpeed;

              // Calculate pace (seconds per kilometer)
              if (_filteredSpeed! > 0) {
                final paceSecondsPerKm = (1000 / _filteredSpeed!).round();
                results['paceSecondsPerKm'] = paceSecondsPerKm;
              }
            }
          }
        }
      }

      // Update last step count
      _lastStepCount = steps;

      return results;
    } catch (e) {
      debugPrint('Error updating with step counter data: $e');
      return {'error': e.toString()};
    }
  }

  /// Calculate distance between two points using the Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth radius in meters

    // Convert latitude and longitude from degrees to radians
    final double lat1 = point1.latitude * math.pi / 180;
    final double lon1 = point1.longitude * math.pi / 180;
    final double lat2 = point2.latitude * math.pi / 180;
    final double lon2 = point2.longitude * math.pi / 180;

    // Haversine formula
    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadius * c;

    return distance;
  }

  /// Apply a low-pass filter to smooth out noisy data
  ///
  /// [currentValue]: The previous filtered value
  /// [newValue]: The new raw value
  /// [alpha]: Filter coefficient (0-1), lower values mean more smoothing
  double _lowPassFilter(double currentValue, double newValue, double alpha) {
    return currentValue * (1 - alpha) + newValue * alpha;
  }

  /// Get the current total distance in meters
  double getTotalDistanceMeters() {
    return _totalDistanceMeters;
  }

  /// Get the current elevation gain in meters
  double getElevationGainMeters() {
    return _elevationGainMeters;
  }

  /// Get the current elevation loss in meters
  double getElevationLossMeters() {
    return _elevationLossMeters;
  }

  /// Get the current filtered speed in m/s
  double? getFilteredSpeedMps() {
    return _filteredSpeed;
  }

  /// Get the current pace in seconds per kilometer
  int? getPaceSecondsPerKm() {
    if (_filteredSpeed != null && _filteredSpeed! > 0) {
      return (1000 / _filteredSpeed!).round();
    }
    return null;
  }
}
