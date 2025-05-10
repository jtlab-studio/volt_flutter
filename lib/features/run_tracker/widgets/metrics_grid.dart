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

    return Column(
      children: [
        // Primary metrics row (time and distance)
        SizedBox(
          height: 80,
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

        const SizedBox(height: 8),

        // Secondary metrics
        Expanded(
          child: Row(
            children: [
              // Left column - Pace and Power
              Expanded(
                child: Column(
                  children: [
                    // Pace
                    Expanded(
                      child: _buildMetricWithAvg(
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
                      child: _buildMetricWithAvg(
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
                      child: _buildMetricWithAvg(
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
                      child: _buildMetricWithAvg(
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

        const SizedBox(height: 8),

        // Elevation
        SizedBox(
          height: 50,
          child: Card(
            margin: EdgeInsets.zero,
            color: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        ),
      ],
    );
  }

  // Primary metric for time and distance
  Widget _buildPrimaryMetric({
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
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

  // Metric with dedicated average value section
  Widget _buildMetricWithAvg({
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
                    fontSize: 11,
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
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' $unit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Average section
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
