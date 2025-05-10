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
    switch (metricKey) {
      case 'pace':
        return 'PACE';
      case 'heartRate':
        return 'HEART RATE';
      case 'power':
        return 'POWER';
      case 'cadence':
        return 'CADENCE';
      case 'distance':
        return 'DISTANCE';
      case 'duration':
        return 'TIME';
      case 'elevationGain':
        return 'ELEV. GAIN';
      case 'elevationLoss':
        return 'ELEV. LOSS';
      default:
        return metricKey.toUpperCase();
    }
  }

  /// Format the metric value based on its type
  String _formatMetricValue() {
    switch (metricKey) {
      case 'pace':
        final pace = metrics['pace'] as int?;
        return SensorReading.formatPace(pace);

      case 'heartRate':
        final heartRate = metrics['heartRate'] as int?;
        return heartRate != null ? '$heartRate bpm' : '--';

      case 'power':
        final power = metrics['power'] as int?;
        return power != null ? '$power W' : '--';

      case 'cadence':
        final cadence = metrics['cadence'] as int?;
        return cadence != null ? '$cadence spm' : '--';

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

  /// Get the icon for the metric
  IconData _getMetricIcon() {
    switch (metricKey) {
      case 'pace':
        return Icons.speed;
      case 'heartRate':
        return Icons.favorite;
      case 'power':
        return Icons.bolt;
      case 'cadence':
        return Icons.directions_walk;
      case 'distance':
        return Icons.straighten;
      case 'duration':
        return Icons.timer;
      case 'elevationGain':
        return Icons.arrow_upward;
      case 'elevationLoss':
        return Icons.arrow_downward;
      default:
        return Icons.show_chart;
    }
  }
}
