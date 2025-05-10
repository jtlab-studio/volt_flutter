// lib/features/run_tracker/screens/run_tracker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'activity_tracker_screen.dart';
import 'activity_map_screen.dart';
import 'activity_history_screen.dart';
import '../providers/tracker_providers.dart';

/// Main entry point for the Run Tracker functionality
/// This screen serves as a dashboard that provides access to:
/// - Starting a new activity
/// - Viewing activity history
/// - Checking activity map
class RunTrackerScreen extends ConsumerWidget {
  const RunTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current metrics from provider (if there's an active activity)
    final metricsAsyncValue = ref.watch(currentMetricsProvider);
    final connectionStatus = ref.watch(sensorStatusProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Run Tracker'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _navigateToHistory(context),
            tooltip: 'Activity History',
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () => _navigateToMap(context),
            tooltip: 'Map View',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sensor status indicators
          _buildSensorStatus(connectionStatus),

          // Current activity stats (if any)
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Activity Hub',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 8),

          // Quick stats overview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildContentArea(context, metricsAsyncValue),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewActivity(context),
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.directions_run),
        label: const Text('START ACTIVITY'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // Build sensor status indicators
  Widget _buildSensorStatus(Map<String, bool> sensorStatus) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSensorIndicator(
              "GPS", Icons.gps_fixed, sensorStatus['gps'] ?? false),
          _buildSensorIndicator(
              "Heart Rate", Icons.favorite, sensorStatus['hrm'] ?? false),
          _buildSensorIndicator(
              "Stryd", Icons.directions_walk, sensorStatus['stryd'] ?? false),
        ],
      ),
    );
  }

  // Build a single sensor indicator
  Widget _buildSensorIndicator(String label, IconData icon, bool isConnected) {
    return Row(
      children: [
        Icon(
          icon,
          color: isConnected ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isConnected ? Colors.green : Colors.red,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Build the main content area based on current state
  Widget _buildContentArea(BuildContext context, dynamic metricsAsyncValue) {
    // If there's an active activity, show metrics
    // Otherwise show activity options
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity Cards
          _buildActivityCard(
            context,
            'Start New Activity',
            'Track your run with real-time metrics',
            Icons.directions_run,
            Colors.blue,
            () => _startNewActivity(context),
          ),

          const SizedBox(height: 16),

          _buildActivityCard(
            context,
            'Activity History',
            'View your past activities and stats',
            Icons.history,
            Colors.orange,
            () => _navigateToHistory(context),
          ),

          const SizedBox(height: 16),

          _buildActivityCard(
            context,
            'Map View',
            'See your routes on a map',
            Icons.map,
            Colors.green,
            () => _navigateToMap(context),
          ),

          const SizedBox(height: 24),

          // Quick Stats Section
          Text(
            'QUICK STATS',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQuickStat(
                      'This Week',
                      '0 km',
                      Icons.straighten,
                      Colors.blue,
                    ),
                    _buildQuickStat(
                      'Activities',
                      '0',
                      Icons.directions_run,
                      Colors.green,
                    ),
                    _buildQuickStat(
                      'Time',
                      '0:00',
                      Icons.timer,
                      Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build an activity option card
  Widget _buildActivityCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build a quick stat display
  Widget _buildQuickStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),
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
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Navigation methods
  void _startNewActivity(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ActivityTrackerScreen()),
    );
  }

  void _navigateToHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ActivityHistoryScreen()),
    );
  }

  void _navigateToMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ActivityMapScreen()),
    );
  }
}
