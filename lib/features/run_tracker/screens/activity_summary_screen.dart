// lib/features/run_tracker/screens/activity_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../models/activity.dart';
import '../models/sensor_reading.dart';
import '../services/tracker_service.dart';
import 'activity_history_screen.dart';

class ActivitySummaryScreen extends StatelessWidget {
  final Activity activity;

  const ActivitySummaryScreen({
    super.key,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Activity Summary'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareActivity(),
            tooltip: 'Share Activity',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity map
            _buildActivityMap(),

            // Activity name and date
            _buildActivityHeader(context),

            // Key stats
            _buildKeyStats(context),

            // Detailed metrics
            _buildDetailedMetrics(context),

            // Action buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  // Build activity map with route
  Widget _buildActivityMap() {
    // Skip map if no route points
    if (activity.routePoints.isEmpty) {
      return Container(
        width: double.infinity,
        height: 200,
        color: Colors.grey[900],
        child: const Center(
          child: Text(
            'No route data available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 250,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: _calculateCenter(),
          initialZoom: 14,
          maxZoom: 18,
          minZoom: 3,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          // Base map layer
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.volt_flutter',
            subdomains: const ['a', 'b', 'c'],
          ),

          // Route polyline
          PolylineLayer(
            polylines: [
              Polyline(
                points: activity.routePoints,
                color: Colors.blue,
                strokeWidth: 4.0,
              ),
            ],
          ),

          // Start and end markers
          MarkerLayer(
            markers: _buildRouteMarkers(),
          ),
        ],
      ),
    );
  }

  // Calculate center of route for map
  LatLng _calculateCenter() {
    if (activity.routePoints.isEmpty) {
      return const LatLng(0, 0); // Default
    }

    // Use center point of route
    if (activity.routePoints.length > 1) {
      final midIndex = activity.routePoints.length ~/ 2;
      return activity.routePoints[midIndex];
    }

    // If only one point, return it
    return activity.routePoints.first;
  }

  // Build markers for start and end points
  List<Marker> _buildRouteMarkers() {
    final markers = <Marker>[];

    if (activity.routePoints.isNotEmpty) {
      // Start marker
      markers.add(
        Marker(
          point: activity.routePoints.first,
          child: const Icon(
            Icons.play_circle_fill,
            color: Colors.green,
            size: 24,
          ),
        ),
      );

      // End marker
      if (activity.routePoints.length > 1) {
        markers.add(
          Marker(
            point: activity.routePoints.last,
            child: const Icon(
              Icons.stop_circle,
              color: Colors.red,
              size: 24,
            ),
          ),
        );
      }
    }

    return markers;
  }

  // Build activity header with name and date
  Widget _buildActivityHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4.0),
          Text(
            '${_formatDate(activity.startTime)} • ${_formatTime(activity.startTime)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
        ],
      ),
    );
  }

  // Build key stats section (distance, time, pace, elevation)
  Widget _buildKeyStats(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      child: Card(
        color: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Distance
              _buildKeyStat(
                context: context,
                value: TrackerService.formatDistance(activity.distanceMeters),
                label: 'KM',
                icon: Icons.straighten,
                iconColor: Colors.blue,
              ),

              // Time
              _buildKeyStat(
                context: context,
                value: TrackerService.formatDuration(activity.durationSeconds),
                label: 'TIME',
                icon: Icons.timer,
                iconColor: Colors.orange,
              ),

              // Pace
              _buildKeyStat(
                context: context,
                value:
                    SensorReading.formatPace(activity.averagePaceSecondsPerKm),
                label: 'PACE',
                icon: Icons.speed,
                iconColor: Colors.green,
              ),

              // Elevation
              _buildKeyStat(
                context: context,
                value: activity.elevationGainMeters.toStringAsFixed(0),
                label: 'ELEV',
                icon: Icons.arrow_upward,
                iconColor: Colors.purple,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build a single key stat item
  Widget _buildKeyStat({
    required BuildContext context,
    required String value,
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 20.0,
        ),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 2.0),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  // Build detailed metrics section
  Widget _buildDetailedMetrics(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DETAILED METRICS',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 8.0),
          Card(
            color: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Heart rate metrics
                  _buildMetricRow(
                    context: context,
                    label: 'Heart Rate (avg)',
                    value: '${activity.averageHeartRate ?? '--'} bpm',
                    icon: Icons.favorite,
                    iconColor: Colors.red,
                  ),

                  const Divider(color: Colors.grey),

                  // Power metrics
                  _buildMetricRow(
                    context: context,
                    label: 'Power (avg)',
                    value: '${activity.averagePower ?? '--'} W',
                    icon: Icons.bolt,
                    iconColor: Colors.yellow,
                  ),

                  const Divider(color: Colors.grey),

                  // Cadence metrics
                  _buildMetricRow(
                    context: context,
                    label: 'Cadence (avg)',
                    value: '${activity.averageCadence ?? '--'} spm',
                    icon: Icons.directions_walk,
                    iconColor: Colors.green,
                  ),

                  const Divider(color: Colors.grey),

                  // Elevation metrics
                  _buildMetricRow(
                    context: context,
                    label: 'Elevation Gain',
                    value:
                        '${activity.elevationGainMeters.toStringAsFixed(0)} m',
                    icon: Icons.arrow_upward,
                    iconColor: Colors.purple,
                  ),

                  const Divider(color: Colors.grey),

                  // Elevation loss metrics
                  _buildMetricRow(
                    context: context,
                    label: 'Elevation Loss',
                    value:
                        '${activity.elevationLossMeters.toStringAsFixed(0)} m',
                    icon: Icons.arrow_downward,
                    iconColor: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build a single metric row
  Widget _buildMetricRow({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 20.0,
          ),
          const SizedBox(width: 16.0),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  // Build action buttons
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // View history button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const ActivityHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('VIEW HISTORY'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
            ),
          ),

          const SizedBox(width: 16.0),

          // New activity button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.add),
              label: const Text('NEW ACTIVITY'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Format date as "Jan 1, 2025"
  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Format time as "10:30 AM"
  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final hourStr = hour == 0 ? '12' : hour.toString();
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hourStr:$minute $period';
  }

  // Share activity data
  void _shareActivity() {
    // Format activity data as text
    final avgPace = SensorReading.formatPace(activity.averagePaceSecondsPerKm);

    final text = '''
Just completed a run! 🏃‍♂️

📊 Activity Stats:
- Distance: ${TrackerService.formatDistance(activity.distanceMeters)} km
- Duration: ${TrackerService.formatDuration(activity.durationSeconds)}
- Avg Pace: $avgPace min/km
${activity.averageHeartRate != null ? '- Avg HR: ${activity.averageHeartRate} bpm\n' : ''}${activity.averagePower != null ? '- Avg Power: ${activity.averagePower} W\n' : ''}${activity.averageCadence != null ? '- Avg Cadence: ${activity.averageCadence} spm\n' : ''}- Elevation Gain: ${activity.elevationGainMeters.toStringAsFixed(0)} m

Tracked with Volt Running Tracker
''';

    // Use SharePlus.instance.share() - this is the correct method for the latest share_plus package
    SharePlus.instance.share(
      ShareParams(text: text),
    );
    // Share the activity data using the share_plus package
    // Share.share(text, subject: 'My Activity Summary');
  }
}
