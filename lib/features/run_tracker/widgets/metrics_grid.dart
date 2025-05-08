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

    // ENHANCED LAYOUT WITH DEDICATED AVERAGE SPACES
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Column(
        children: [
          // Primary metrics row (time and distance) - INCREASED HEIGHT
          SizedBox(
            height: 70, // INCREASED from 60
            child: Row(
              children: [
                // Duration
                Expanded(
                  child: _buildPrimaryMetric(
                    label: 'TIME',
                    value: TrackerService.formatDuration(duration),
                    icon: Icons.timer,
                    iconColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                // Distance
                Expanded(
                  child: _buildPrimaryMetric(
                    label: 'DISTANCE',
                    value: '${TrackerService.formatDistance(distance)} km',
                    icon: Icons.straighten,
                    iconColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8), // Slightly increased spacing

          // Secondary metrics - INCREASED HEIGHT with dedicated avg section
          SizedBox(
            height: 144, // INCREASED from 120 (20% increase)
            child: Row(
              children: [
                // Left column - Pace and Power
                Expanded(
                  child: Column(
                    children: [
                      // Pace
                      Expanded(
                        child: _buildMetricWithDedicatedAvg(
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
                      const SizedBox(height: 8),
                      // Power
                      Expanded(
                        child: _buildMetricWithDedicatedAvg(
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
                        child: _buildMetricWithDedicatedAvg(
                          label: 'HEART RATE',
                          value: heartRate?.toString() ?? '--',
                          avgValue: averageHR?.toString(),
                          unit: 'bpm',
                          icon: Icons.favorite,
                          iconColor: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Cadence
                      Expanded(
                        child: _buildMetricWithDedicatedAvg(
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

          const SizedBox(height: 8), // Increased spacing

          // Elevation - SLIGHTLY INCREASED HEIGHT
          SizedBox(
            height: 48, // INCREASED from 40 (20% increase)
            child: Card(
              margin: EdgeInsets.zero,
              color: const Color(0xFF2C2C2C),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    const Text(
                      'ELEVATION',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // Gain and Loss
                    Row(
                      children: [
                        // Gain
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.arrow_upward,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${elevationGain.toStringAsFixed(0)}m',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'GAIN',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 24),

                        // Loss
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.arrow_downward,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${elevationLoss.toStringAsFixed(0)}m',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'LOSS',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[400],
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
        ],
      ),
    );
  }

  // Enhanced primary metric
  Widget _buildPrimaryMetric({
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
              size: 20, // Increased from 16
            ),
            const SizedBox(width: 12), // Increased from 8
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22, // Increased from 18
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12, // Increased from 10
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

  // Enhanced metric with dedicated average value section
  Widget _buildMetricWithDedicatedAvg({
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
            // Label and icon row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11, // Increased from 9
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  icon,
                  color: iconColor,
                  size: 16, // Increased from 12
                ),
              ],
            ),

            // Current value takes most space
            Expanded(
              flex: 3,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24, // Increased from 18
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' $unit',
                      style: TextStyle(
                        fontSize: 12, // Increased from 10
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // DEDICATED AVERAGE SECTION
            if (avgValue != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[800]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'AVERAGE',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '$avgValue $unit',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[300],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
