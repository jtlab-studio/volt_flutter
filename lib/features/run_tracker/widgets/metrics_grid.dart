// lib/features/run_tracker/widgets/metrics_grid.dart
import 'package:flutter/material.dart';
import '../services/tracker_service.dart';
import '../models/sensor_reading.dart';

class MetricsGrid extends StatelessWidget {
  final Map<String, dynamic> metrics;

  const MetricsGrid({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    // Extract metrics from the map
    final duration = metrics['duration'] as int;
    final distance = metrics['distance'] as double;
    final pace = metrics['pace'] as int?;
    final heartRate = metrics['heartRate'] as int?;
    final power = metrics['power'] as int?;
    final cadence = metrics['cadence'] as int?;
    final elevationGain = metrics['elevationGain'] as double;
    final elevationLoss = metrics['elevationLoss'] as double;

    // Check if current activity has values to display
    final currentActivity = metrics['currentActivity'];
    final averageHR = currentActivity?.averageHeartRate;
    final averagePower = currentActivity?.averagePower;
    final averageCadence = currentActivity?.averageCadence;
    final averagePace = currentActivity?.averagePaceSecondsPerKm;

    // MUCH SIMPLER AND MORE COMPACT LAYOUT
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Column(
        children: [
          // Primary metrics row (time and distance) - FIXED HEIGHT
          SizedBox(
            height: 60, // SIGNIFICANTLY REDUCED from 80
            child: Row(
              children: [
                // Duration
                Expanded(
                  child: _buildCompactMetric(
                    label: 'TIME',
                    value: TrackerService.formatDuration(duration),
                    icon: Icons.timer,
                    iconColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                // Distance
                Expanded(
                  child: _buildCompactMetric(
                    label: 'DISTANCE',
                    value: '${TrackerService.formatDistance(distance)} km',
                    icon: Icons.straighten,
                    iconColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4), // Minimal spacing

          // Secondary metrics - FIXED HEIGHT
          SizedBox(
            height: 120, // SIGNIFICANTLY REDUCED
            child: Row(
              children: [
                // Left column - Pace and Power
                Expanded(
                  child: Column(
                    children: [
                      // Pace
                      Expanded(
                        child: _buildCompactMetricWithAvg(
                          label: 'PACE',
                          value: SensorReading.formatPace(pace),
                          avgValue: averagePace != null
                              ? SensorReading.formatPace(averagePace)
                              : null,
                          unit: 'min/km',
                          icon: Icons.speed,
                          iconColor: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Power
                      Expanded(
                        child: _buildCompactMetricWithAvg(
                          label: 'POWER',
                          value: power?.toString() ?? '--',
                          avgValue: averagePower?.toString(),
                          unit: 'W',
                          icon: Icons.bolt,
                          iconColor: Colors.yellow,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Right column - Heart Rate and Cadence
                Expanded(
                  child: Column(
                    children: [
                      // Heart Rate
                      Expanded(
                        child: _buildCompactMetricWithAvg(
                          label: 'HEART RATE',
                          value: heartRate?.toString() ?? '--',
                          avgValue: averageHR?.toString(),
                          unit: 'bpm',
                          icon: Icons.favorite,
                          iconColor: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Cadence
                      Expanded(
                        child: _buildCompactMetricWithAvg(
                          label: 'CADENCE',
                          value: cadence?.toString() ?? '--',
                          avgValue: averageCadence?.toString(),
                          unit: 'spm',
                          icon: Icons.directions_walk,
                          iconColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4), // Minimal spacing

          // Elevation - VERY COMPACT
          SizedBox(
            height: 40, // MINIMAL HEIGHT
            child: Card(
              margin: EdgeInsets.zero,
              color: const Color(0xFF2C2C2C),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    const Text(
                      'ELEVATION',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // Gain and Loss
                    Row(
                      children: [
                        // Gain
                        Row(
                          children: [
                            const Icon(
                              Icons.arrow_upward,
                              color: Colors.green,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${elevationGain.toStringAsFixed(0)}m',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 16),

                        // Loss
                        Row(
                          children: [
                            const Icon(
                              Icons.arrow_downward,
                              color: Colors.red,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${elevationLoss.toStringAsFixed(0)}m',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Spacer to push everything up
          const Spacer(),
        ],
      ),
    );
  }

  // Ultra compact time/distance metric
  Widget _buildCompactMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF2C2C2C),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Ultra compact metric with average value
  Widget _buildCompactMetricWithAvg({
    required String label,
    required String value,
    String? avgValue,
    required String unit,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF2C2C2C),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label and icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  icon,
                  color: iconColor,
                  size: 12,
                ),
              ],
            ),

            // Value takes most space
            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' $unit',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Average if available
            if (avgValue != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'AVG: $avgValue',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
