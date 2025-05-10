// lib/features/sensors/widgets/gps_validation_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;

import '../providers/gps_providers.dart';

/// A widget that lets users validate GPS accuracy with real measurements
class GpsValidationCard extends ConsumerStatefulWidget {
  const GpsValidationCard({super.key});

  @override
  ConsumerState<GpsValidationCard> createState() => _GpsValidationCardState();
}

class _GpsValidationCardState extends ConsumerState<GpsValidationCard> {
  // State for test running
  bool _isTestRunning = false;
  Timer? _testTimer;
  int _testDurationSeconds = 0;
  final int _testTotalDuration = 15; // 15 second test

  // Test results
  List<double> _accuracyReadings = [];
  double _batteryDrain = 0.0;
  double _averageAccuracy = 0.0;
  double _cep50 = 0.0; // Circular Error Probable (50%)
  double _cep95 = 0.0; // Circular Error Probable (95%)
  double _hdop = 0.0; // Horizontal Dilution of Precision

  @override
  void dispose() {
    _testTimer?.cancel();
    super.dispose();
  }

  /// Start a GPS validation test
  void _startTest() {
    // Reset all test values
    setState(() {
      _isTestRunning = true;
      _testDurationSeconds = 0;
      _accuracyReadings = [];
      _batteryDrain = 0.0;
      _averageAccuracy = 0.0;
      _cep50 = 0.0;
      _cep95 = 0.0;
      _hdop = 0.0;
    });

    // Create a timer to increment test progress
    _testTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        setState(() {
          _testDurationSeconds++;

          // Simulate collecting data - in a real app this would
          // come from the native platform
          _simulateDataCollection();

          // Check if test is complete
          if (_testDurationSeconds >= _testTotalDuration) {
            _completeTest();
          }
        });
      },
    );
  }

  /// Simulate collecting GPS data - in a real app, this would use
  /// the platform channel to get real measurements
  void _simulateDataCollection() {
    // Get the current GPS settings
    final settings = ref.read(gpsSettingsProvider);

    // Simulate accuracy based on the GPS mode
    double baseAccuracy;
    switch (settings.mode) {
      case 'power_saver':
        baseAccuracy = 12.0; // ~10m base accuracy
        break;
      case 'balanced':
        baseAccuracy = 3.5; // ~3m base accuracy
        break;
      case 'high_accuracy':
        baseAccuracy = 1.8; // ~1.5m base accuracy
        break;
      case 'rtk':
        baseAccuracy = 0.6; // ~0.5m base accuracy
        break;
      default:
        baseAccuracy = 5.0;
    }

    // Apply feature adjustments
    if (settings.multiFrequency) {
      baseAccuracy *= 0.7; // 30% improvement with dual frequency
    }

    if (settings.sensorFusion) {
      baseAccuracy *= 0.85; // 15% improvement with sensor fusion
    }

    if (settings.rawMeasurements && settings.rtkCorrections) {
      baseAccuracy *= 0.4; // 60% improvement with RTK
    }

    // Add some random noise
    final random = math.Random();
    final noise = (random.nextDouble() - 0.5) * baseAccuracy * 0.5;
    final accuracy = baseAccuracy + noise;

    // Add to readings list
    _accuracyReadings.add(accuracy);

    // Calculate and update running averages
    _updateMetrics();

    // Simulate battery drain based on settings
    double drainRate = 0.0;
    switch (settings.mode) {
      case 'power_saver':
        drainRate = 0.05; // 0.05% per second = ~3% per minute
        break;
      case 'balanced':
        drainRate = 0.15; // 0.15% per second = ~9% per minute
        break;
      case 'high_accuracy':
        drainRate = 0.25; // 0.25% per second = ~15% per minute
        break;
      case 'rtk':
        drainRate = 0.35; // 0.35% per second = ~21% per minute
        break;
      default:
        drainRate = 0.15;
    }

    _batteryDrain += drainRate;
  }

  /// Calculate accuracy metrics based on collected readings
  void _updateMetrics() {
    if (_accuracyReadings.isEmpty) return;

    // Calculate average accuracy
    final sum = _accuracyReadings.reduce((a, b) => a + b);
    _averageAccuracy = sum / _accuracyReadings.length;

    // Sort readings for percentile calculations
    final sortedReadings = List<double>.from(_accuracyReadings)..sort();

    // CEP50 - 50th percentile
    final median = sortedReadings.length.isOdd
        ? sortedReadings[sortedReadings.length ~/ 2]
        : (sortedReadings[(sortedReadings.length ~/ 2) - 1] +
                sortedReadings[sortedReadings.length ~/ 2]) /
            2.0;
    _cep50 = median;

    // CEP95 - 95th percentile
    final index95 = (sortedReadings.length * 0.95).ceil() - 1;
    _cep95 = index95 >= 0 && index95 < sortedReadings.length
        ? sortedReadings[index95]
        : (sortedReadings.isNotEmpty ? sortedReadings.last : 0);

    // HDOP simulation - a relative measure of geometric quality
    // Lower is better (1.0 is ideal, >20 is poor)
    if (_accuracyReadings.length > 5) {
      // Simulate HDOP that correlates with accuracy
      _hdop = math.max(1.0, _averageAccuracy / 3.0);
    }
  }

  /// Complete the test and finalize results
  void _completeTest() {
    _testTimer?.cancel();
    _testTimer = null;

    // Calculate final metrics if needed
    _updateMetrics();

    setState(() {
      _isTestRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get settings
    final settings = ref.watch(gpsSettingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GPS Field Test',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: _isTestRunning ? null : _startTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isTestRunning ? 'Testing...' : 'Run Test'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Validate actual accuracy & battery impact',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            if (_isTestRunning) ...[
              const SizedBox(height: 16),

              // Progress bar
              LinearProgressIndicator(
                value: _testDurationSeconds / _testTotalDuration,
                color: Colors.blue,
              ),

              const SizedBox(height: 8),

              Text(
                'Testing $_testDurationSeconds/${_testTotalDuration}s - Please stay still',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (!_isTestRunning && _accuracyReadings.isNotEmpty) ...[
              const SizedBox(height: 16),

              const Divider(),

              const Text(
                'Test Results:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // Results grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildResultItem(
                    label: 'Avg. Error',
                    value: '${_averageAccuracy.toStringAsFixed(1)}m',
                    icon: Icons.gps_fixed,
                    color: _getAccuracyColor(_averageAccuracy),
                  ),
                  _buildResultItem(
                    label: 'CEP50',
                    value: '${_cep50.toStringAsFixed(1)}m',
                    icon: Icons.radio_button_checked,
                    color: _getAccuracyColor(_cep50),
                  ),
                  _buildResultItem(
                    label: 'CEP95',
                    value: '${_cep95.toStringAsFixed(1)}m',
                    icon: Icons.circle_outlined,
                    color: _getAccuracyColor(_cep95),
                  ),
                  _buildResultItem(
                    label: 'HDOP',
                    value: _hdop.toStringAsFixed(1),
                    icon: Icons.stacked_line_chart,
                    color: _getHdopColor(_hdop),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Battery impact
              Row(
                children: [
                  const Icon(
                    Icons.battery_alert,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Battery Impact:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_batteryDrain.toStringAsFixed(1)}% drain',
                    style: const TextStyle(
                      color: Colors.orange,
                    ),
                  ),
                  const Text(
                    ' during test',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Recommendations
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates,
                    color: Colors.teal,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recommendation:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getRecommendation(settings),
                      style: const TextStyle(
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build a result item with label, value, and icon
  Widget _buildResultItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  /// Get a color based on accuracy (green for good, red for bad)
  Color _getAccuracyColor(double accuracy) {
    if (accuracy < 1.0) return Colors.green;
    if (accuracy < 3.0) return Colors.lightGreen;
    if (accuracy < 5.0) return Colors.amber;
    if (accuracy < 10.0) return Colors.orange;
    return Colors.red;
  }

  /// Get a color based on HDOP (green for good, red for bad)
  Color _getHdopColor(double hdop) {
    if (hdop < 1.5) return Colors.green;
    if (hdop < 3.0) return Colors.lightGreen;
    if (hdop < 5.0) return Colors.amber;
    if (hdop < 10.0) return Colors.orange;
    return Colors.red;
  }

  /// Get a recommendation based on test results and current settings
  String _getRecommendation(GpsSettings settings) {
    // If we haven't run a test yet
    if (_accuracyReadings.isEmpty) {
      return 'Run a test to get recommendations.';
    }

    // If test results show issues
    if (_hdop > 5.0) {
      return 'Poor satellite geometry detected. Consider moving to a more open area.';
    }

    // Based on settings and accuracy
    switch (settings.mode) {
      case 'power_saver':
        if (_averageAccuracy > 8.0) {
          return 'Accuracy is low. Consider switching to Balanced mode if better precision is needed.';
        } else {
          return 'Current mode is providing good battery efficiency with acceptable accuracy.';
        }

      case 'balanced':
        if (_averageAccuracy < 2.0) {
          return 'You\'re getting excellent accuracy. Could consider Power-Saver mode to extend battery life.';
        } else if (_averageAccuracy > 5.0) {
          return 'Accuracy is below expected. Try enabling Sensor Fusion or switch to High-Accuracy mode.';
        } else {
          return 'Current mode is providing a good balance of accuracy and battery life.';
        }

      case 'high_accuracy':
        if (_averageAccuracy > 3.0) {
          return 'Accuracy is below expected. Try enabling Multi-frequency if your device supports it.';
        } else if (_batteryDrain > 4.0) {
          return 'Battery drain is high. Consider using Balanced mode if lower precision is acceptable.';
        } else {
          return 'Current mode is providing good high-precision positioning.';
        }

      case 'rtk':
        if (_averageAccuracy > 1.0) {
          return 'RTK-level accuracy not achieved. Check RTK correction stream and clear sky visibility.';
        } else if (_batteryDrain > 5.0) {
          return 'Battery drain is very high. Use RTK sparingly for critical measurements only.';
        } else {
          return 'RTK positioning is working effectively with expected precision.';
        }

      default:
        return 'Consider adjusting settings based on your accuracy needs and battery constraints.';
    }
  }
}
