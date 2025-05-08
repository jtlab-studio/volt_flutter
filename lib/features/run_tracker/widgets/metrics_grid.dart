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
    final duration = metrics['duration'] as int;
    final distance = metrics['distance'] as double;
    final pace = metrics['pace'] as int?;
    final heartRate = metrics['heartRate'] as int?;
    final power = metrics['power'] as int?;
    final cadence = metrics['cadence'] as int?;
    final elevationGain = metrics['elevationGain'] as double;
    final elevationLoss = metrics['elevationLoss'] as double;

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Primary metrics (larger)
          Row(
            children: [
              // Duration
              Expanded(
                child: _buildPrimaryMetric(
                  context: context,
                  value: TrackerService.formatDuration(duration),
                  label: 'TIME',
                  icon: Icons.timer,
                ),
              ),

              // Distance
              Expanded(
                child: _buildPrimaryMetric(
                  context: context,
                  value: '${TrackerService.formatDistance(distance)} km',
                  label: 'DISTANCE',
                  icon: Icons.straighten,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16.0),

          // Secondary metrics (smaller)
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Pace (left column, top)
                _buildMetricCard(
                  context: context,
                  value: SensorReading.formatPace(pace),
                  label: 'PACE',
                  units: 'min/km',
                  icon: Icons.speed,
                  iconColor: Colors.orange,
                  showTrend: false,
                ),

                // Heart Rate (right column, top)
                _buildMetricCard(
                  context: context,
                  value: heartRate?.toString() ?? '--',
                  label: 'HEART RATE',
                  units: 'bpm',
                  icon: Icons.favorite,
                  iconColor: Colors.red,
                  showTrend: false,
                ),

                // Power (left column, bottom)
                _buildMetricCard(
                  context: context,
                  value: power?.toString() ?? '--',
                  label: 'POWER',
                  units: 'W',
                  icon: Icons.bolt,
                  iconColor: Colors.yellow,
                  showTrend: false,
                ),

                // Cadence (right column, bottom)
                _buildMetricCard(
                  context: context,
                  value: cadence?.toString() ?? '--',
                  label: 'CADENCE',
                  units: 'spm',
                  icon: Icons.directions_walk,
                  iconColor: Colors.green,
                  showTrend: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16.0),

          // Elevation widget (horizontal bar at bottom)
          _buildElevationWidget(
            context: context,
            gain: elevationGain,
            loss: elevationLoss,
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryMetric({
    required BuildContext context,
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Card(
      elevation: 4.0,
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.blue,
              size: 24.0,
            ),
            const SizedBox(height: 8.0),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4.0),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String value,
    required String label,
    required String units,
    required IconData icon,
    required Color iconColor,
    bool showTrend = false,
    IconData? trendIcon,
    Color? trendColor,
  }) {
    return Card(
      elevation: 4.0,
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label and icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                ),
                Icon(
                  icon,
                  color: iconColor,
                  size: 20.0,
                ),
              ],
            ),

            const SizedBox(height: 8.0),

            // Value and units
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 4.0),
                Text(
                  units,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                      ),
                ),

                // Show trend if requested
                if (showTrend && trendIcon != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(
                      trendIcon,
                      color: trendColor,
                      size: 16.0,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElevationWidget({
    required BuildContext context,
    required double gain,
    required double loss,
  }) {
    return Card(
      elevation: 4.0,
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ELEVATION',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
            ),

            const SizedBox(height: 8.0),

            // Elevation gain and loss in a row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Gain
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_upward,
                          color: Colors.green,
                          size: 16.0,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          '${gain.toStringAsFixed(0)} m',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'GAIN',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[400],
                            letterSpacing: 1.0,
                          ),
                    ),
                  ],
                ),

                // Divider
                Container(
                  height: 40.0,
                  width: 1.0,
                  color: Colors.grey[700],
                ),

                // Loss
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_downward,
                          color: Colors.red,
                          size: 16.0,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          '${loss.toStringAsFixed(0)} m',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'LOSS',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[400],
                            letterSpacing: 1.0,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
