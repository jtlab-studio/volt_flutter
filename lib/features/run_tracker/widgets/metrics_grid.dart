// lib/features/run_tracker/widgets/metrics_grid.dart - Optimized for space
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

    // Get available height to adjust layout
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700; // Adjust this threshold as needed

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12.0, vertical: 8.0), // Reduced padding
      child: Column(
        children: [
          // Primary metrics (Time and Distance)
          Row(
            children: [
              // Duration
              Expanded(
                child: _buildPrimaryMetric(
                  context: context,
                  value: TrackerService.formatDuration(duration),
                  label: 'TIME',
                  icon: Icons.timer,
                  isSmallScreen: isSmallScreen,
                ),
              ),

              // Distance
              Expanded(
                child: _buildPrimaryMetric(
                  context: context,
                  value: '${TrackerService.formatDistance(distance)} km',
                  label: 'DISTANCE',
                  icon: Icons.straighten,
                  isSmallScreen: isSmallScreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12.0), // Reduced vertical spacing

          // Secondary metrics grid - takes most of the space
          Expanded(
            child: isSmallScreen
                ? _buildCompactMetricsGrid(context, pace, heartRate, power,
                    cadence, elevationGain, elevationLoss)
                : _buildStandardMetricsGrid(context, pace, heartRate, power,
                    cadence, elevationGain, elevationLoss),
          ),
        ],
      ),
    );
  }

  // Standard layout for normal size screens
  Widget _buildStandardMetricsGrid(
    BuildContext context,
    int? pace,
    int? heartRate,
    int? power,
    int? cadence,
    double elevationGain,
    double elevationLoss,
  ) {
    return Column(
      children: [
        // First row: Pace and Heart Rate
        Expanded(
          child: Row(
            children: [
              // Pace (left column, top)
              Expanded(
                child: _buildMetricCard(
                  context: context,
                  value: SensorReading.formatPace(pace),
                  label: 'PACE',
                  units: 'min/km',
                  icon: Icons.speed,
                  iconColor: Colors.orange,
                  showTrend: false,
                ),
              ),
              const SizedBox(width: 12.0), // Reduced spacing
              // Heart Rate (right column, top)
              Expanded(
                child: _buildMetricCard(
                  context: context,
                  value: heartRate?.toString() ?? '--',
                  label: 'HEART RATE',
                  units: 'bpm',
                  icon: Icons.favorite,
                  iconColor: Colors.red,
                  showTrend: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12.0), // Reduced spacing
        // Second row: Power and Cadence
        Expanded(
          child: Row(
            children: [
              // Power (left column, bottom)
              Expanded(
                child: _buildMetricCard(
                  context: context,
                  value: power?.toString() ?? '--',
                  label: 'POWER',
                  units: 'W',
                  icon: Icons.bolt,
                  iconColor: Colors.yellow,
                  showTrend: false,
                ),
              ),
              const SizedBox(width: 12.0), // Reduced spacing
              // Cadence (right column, bottom)
              Expanded(
                child: _buildMetricCard(
                  context: context,
                  value: cadence?.toString() ?? '--',
                  label: 'CADENCE',
                  units: 'spm',
                  icon: Icons.directions_walk,
                  iconColor: Colors.green,
                  showTrend: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12.0), // Reduced spacing
        // Elevation widget at bottom
        _buildElevationWidget(
          context: context,
          gain: elevationGain,
          loss: elevationLoss,
        ),
      ],
    );
  }

  // Compact layout for smaller screens
  Widget _buildCompactMetricsGrid(
    BuildContext context,
    int? pace,
    int? heartRate,
    int? power,
    int? cadence,
    double elevationGain,
    double elevationLoss,
  ) {
    return Column(
      children: [
        // 2x2 grid of smaller metric cards
        Expanded(
          flex: 3,
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
            childAspectRatio: 1.6, // Wider than tall
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Pace
              _buildCompactMetricCard(
                context: context,
                value: SensorReading.formatPace(pace),
                label: 'PACE',
                units: 'min/km',
                icon: Icons.speed,
                iconColor: Colors.orange,
              ),
              // Heart Rate
              _buildCompactMetricCard(
                context: context,
                value: heartRate?.toString() ?? '--',
                label: 'HR',
                units: 'bpm',
                icon: Icons.favorite,
                iconColor: Colors.red,
              ),
              // Power
              _buildCompactMetricCard(
                context: context,
                value: power?.toString() ?? '--',
                label: 'POWER',
                units: 'W',
                icon: Icons.bolt,
                iconColor: Colors.yellow,
              ),
              // Cadence
              _buildCompactMetricCard(
                context: context,
                value: cadence?.toString() ?? '--',
                label: 'CADENCE',
                units: 'spm',
                icon: Icons.directions_walk,
                iconColor: Colors.green,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8.0), // Minimum spacing
        // Compact elevation widget
        _buildCompactElevationWidget(
          context: context,
          gain: elevationGain,
          loss: elevationLoss,
        ),
      ],
    );
  }

  // Smaller primary metrics for time and distance
  Widget _buildPrimaryMetric({
    required BuildContext context,
    required String value,
    required String label,
    required IconData icon,
    required bool isSmallScreen,
  }) {
    return Card(
      elevation: 4.0,
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(
            isSmallScreen ? 8.0 : 12.0), // Reduced padding on small screens
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.blue,
              size:
                  isSmallScreen ? 20.0 : 24.0, // Smaller icon on small screens
            ),
            const SizedBox(height: 4.0), // Minimum spacing
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen
                        ? 22.0
                        : null, // Smaller text on small screens
                  ),
            ),
            const SizedBox(height: 2.0), // Minimum spacing
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: isSmallScreen
                        ? 10.0
                        : null, // Smaller text on small screens
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // Standard metric card
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
        padding: const EdgeInsets.all(12.0),
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

            const Spacer(),

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

  // Compact metric card for smaller screens
  Widget _buildCompactMetricCard({
    required BuildContext context,
    required String value,
    required String label,
    required String units,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.all(0), // No margin to save space
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0), // Smaller radius
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0), // Minimum padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Combined label and icon in one row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 14.0, // Very small icon
                ),
                const SizedBox(width: 4.0),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.0, // Smaller text
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            // Value and units
            Text(
              value,
              style: const TextStyle(
                fontSize: 18.0, // Smaller value text
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              units,
              style: TextStyle(
                fontSize: 10.0, // Smaller unit text
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Standard elevation widget
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
        padding: const EdgeInsets.all(12.0),
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

  // Compact elevation widget for smaller screens
  Widget _buildCompactElevationWidget({
    required BuildContext context,
    required double gain,
    required double loss,
  }) {
    return Card(
      elevation: 4.0,
      color: const Color(0xFF2C2C2C),
      margin: const EdgeInsets.all(0), // No margin to save space
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0), // Smaller radius
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: 6.0, horizontal: 12.0), // Reduced padding
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Title
            const Text(
              'ELEVATION',
              style: TextStyle(
                fontSize: 10.0,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Gain
            Row(
              children: [
                const Icon(
                  Icons.arrow_upward,
                  color: Colors.green,
                  size: 14.0,
                ),
                const SizedBox(width: 2.0),
                Text(
                  '${gain.toStringAsFixed(0)}m',
                  style: const TextStyle(
                    fontSize: 14.0,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // Loss
            Row(
              children: [
                const Icon(
                  Icons.arrow_downward,
                  color: Colors.red,
                  size: 14.0,
                ),
                const SizedBox(width: 2.0),
                Text(
                  '${loss.toStringAsFixed(0)}m',
                  style: const TextStyle(
                    fontSize: 14.0,
                    color: Colors.white,
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
}
