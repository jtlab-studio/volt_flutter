// lib/features/run_tracker/widgets/custom_metric_display.dart
import 'package:flutter/material.dart';
import '../services/tracker_service.dart';
import '../models/sensor_reading.dart';

/// A widget that displays a customizable metric
class CustomMetricDisplay extends StatelessWidget {
  /// The key of the metric to display from the metrics map
  final String metricKey;

  /// The map of available metrics
  final Map<String, dynamic> metrics;

  const CustomMetricDisplay({
    super.key,
    required this.metricKey,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Metric label
            Text(
              _getMetricLabel(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            // Metric value
            Text(
              _formatMetricValue(),
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Check if we need to show an average value
            if (_shouldShowAverage())
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[800]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AVG',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatAverageValue(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[300],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // Long press instruction (subtle hint)
            Text(
              'Hold to change',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get the display label for the metric
  String _getMetricLabel() {
    String baseLabel = '';

    switch (metricKey) {
      case 'pace':
        baseLabel = 'PACE';
        break;
      case 'avgPace':
        baseLabel = 'AVG PACE';
        break;
      case 'heartRate':
        baseLabel = 'HEART RATE';
        break;
      case 'avgHeartRate':
        baseLabel = 'AVG HEART RATE';
        break;
      case 'power':
        baseLabel = 'POWER';
        break;
      case 'avgPower':
        baseLabel = 'AVG POWER';
        break;
      case 'cadence':
        baseLabel = 'CADENCE';
        break;
      case 'avgCadence':
        baseLabel = 'AVG CADENCE';
        break;
      case 'distance':
        baseLabel = 'DISTANCE';
        break;
      case 'duration':
        baseLabel = 'TIME';
        break;
      case 'elevationGain':
        baseLabel = 'ELEV. GAIN';
        break;
      case 'elevationLoss':
        baseLabel = 'ELEV. LOSS';
        break;
      default:
        baseLabel = metricKey.toUpperCase();
        break;
    }

    return baseLabel;
  }

  /// Format the metric value based on its type
  String _formatMetricValue() {
    final currentActivity = metrics['currentActivity'];

    switch (metricKey) {
      case 'pace':
        final pace = metrics['pace'] as int?;
        return SensorReading.formatPace(pace);

      case 'avgPace':
        final avgPace = currentActivity?.averagePaceSecondsPerKm;
        return SensorReading.formatPace(avgPace);

      case 'heartRate':
        final heartRate = metrics['heartRate'] as int?;
        return heartRate != null ? '$heartRate bpm' : '--';

      case 'avgHeartRate':
        final avgHeartRate = currentActivity?.averageHeartRate;
        return avgHeartRate != null ? '$avgHeartRate bpm' : '--';

      case 'power':
        final power = metrics['power'] as int?;
        return power != null ? '$power W' : '--';

      case 'avgPower':
        final avgPower = currentActivity?.averagePower;
        return avgPower != null ? '$avgPower W' : '--';

      case 'cadence':
        final cadence = metrics['cadence'] as int?;
        return cadence != null ? '$cadence spm' : '--';

      case 'avgCadence':
        final avgCadence = currentActivity?.averageCadence;
        return avgCadence != null ? '$avgCadence spm' : '--';

      case 'distance':
        final distance = metrics['distance'] as double;
        return '${TrackerService.formatDistance(distance)} km';

      case 'duration':
        final duration = metrics['duration'] as int;
        return TrackerService.formatDuration(duration);

      case 'elevationGain':
        final elevationGain = metrics['elevationGain'] as double;
        return '${elevationGain.toStringAsFixed(0)} m';

      case 'elevationLoss':
        final elevationLoss = metrics['elevationLoss'] as double;
        return '${elevationLoss.toStringAsFixed(0)} m';

      default:
        return '--';
    }
  }

  /// Check if we should display an average value
  bool _shouldShowAverage() {
    // Only display average values for current metrics that have corresponding average metrics
    if (metricKey == 'pace' ||
        metricKey == 'heartRate' ||
        metricKey == 'power' ||
        metricKey == 'cadence') {
      final currentActivity = metrics['currentActivity'];
      if (currentActivity == null) return false;

      // Check if the corresponding average value exists
      switch (metricKey) {
        case 'pace':
          return currentActivity.averagePaceSecondsPerKm != null;
        case 'heartRate':
          return currentActivity.averageHeartRate != null;
        case 'power':
          return currentActivity.averagePower != null;
        case 'cadence':
          return currentActivity.averageCadence != null;
        default:
          return false;
      }
    }

    // Don't show averages for already-average metrics
    return false;
  }

  /// Format the average value for the metric
  String _formatAverageValue() {
    final currentActivity = metrics['currentActivity'];
    if (currentActivity == null) return '--';

    switch (metricKey) {
      case 'pace':
        final avgPace = currentActivity.averagePaceSecondsPerKm;
        return '${SensorReading.formatPace(avgPace)} min/km';

      case 'heartRate':
        final avgHr = currentActivity.averageHeartRate;
        return avgHr != null ? '$avgHr bpm' : '--';

      case 'power':
        final avgPower = currentActivity.averagePower;
        return avgPower != null ? '$avgPower W' : '--';

      case 'cadence':
        final avgCadence = currentActivity.averageCadence;
        return avgCadence != null ? '$avgCadence spm' : '--';

      default:
        return '--';
    }
  }
}
