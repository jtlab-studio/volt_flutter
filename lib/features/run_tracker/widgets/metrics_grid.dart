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

    return SingleChildScrollView(
      child: Column(
        children: [
          // Primary metrics row (time and distance) - these are always visible
          Row(
            children: [
              // Duration
              Expanded(
                child: _buildPrimaryMetric(
                  context: context,
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
                  context: context,
                  label: 'DISTANCE',
                  value: '${TrackerService.formatDistance(distance)} km',
                  icon: Icons.straighten,
                  iconColor: Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Secondary metrics - arranged in a 2x2 grid with current and average values
          Row(
            children: [
              // Left column - Pace and Heart Rate
              Expanded(
                child: Column(
                  children: [
                    // Pace
                    _buildMetricWithAvg(
                      label: 'PACE',
                      currentValue: SensorReading.formatPace(pace),
                      avgValue: SensorReading.formatPace(averagePace),
                      unit: 'min/km',
                      icon: Icons.speed,
                      iconColor: Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    // Heart Rate
                    _buildMetricWithAvg(
                      label: 'HEART RATE',
                      currentValue: heartRate?.toString() ?? '--',
                      avgValue: averageHR?.toString(),
                      unit: 'bpm',
                      icon: Icons.favorite,
                      iconColor: Colors.red,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right column - Power and Cadence
              Expanded(
                child: Column(
                  children: [
                    // Power
                    _buildMetricWithAvg(
                      label: 'POWER',
                      currentValue: power?.toString() ?? '--',
                      avgValue: averagePower?.toString(),
                      unit: 'W',
                      icon: Icons.bolt,
                      iconColor: Colors.yellow,
                    ),
                    const SizedBox(height: 8),
                    // Cadence
                    _buildMetricWithAvg(
                      label: 'CADENCE',
                      currentValue: cadence?.toString() ?? '--',
                      avgValue: averageCadence?.toString(),
                      unit: 'spm',
                      icon: Icons.directions_walk,
                      iconColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Elevation - at the bottom, with a different layout
          Card(
            margin: EdgeInsets.zero,
            color: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  const Text(
                    'ELEVATION',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
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
        ],
      ),
    );
  }

  // Primary metrics (Time, Distance)
  Widget _buildPrimaryMetric({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
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

  // Secondary metrics with both current and average values (Pace, HR, Power, Cadence)
  Widget _buildMetricWithAvg({
    required String label,
    required String currentValue,
    String? avgValue,
    required String unit,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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
                    fontSize: 12,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  icon,
                  color: iconColor,
                  size: 16,
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Current value row
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currentValue,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),

            // Average section
            if (avgValue != null)
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
                      '$avgValue $unit',
                      style: TextStyle(
                        fontSize: 12,
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
