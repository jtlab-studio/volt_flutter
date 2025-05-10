// lib/features/run_tracker/widgets/sensor_status_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tracker_providers.dart';

class SensorStatusBar extends ConsumerWidget {
  const SensorStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get sensor status
    final sensors = ref.watch(sensorStatusProvider);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // GPS sensor indicator
          _buildSensorIndicator(
            context: context,
            isConnected: sensors['gps'] ?? false,
            icon: Icons.gps_fixed,
            label: 'GPS',
          ),

          const SizedBox(width: 24),

          // Heart rate sensor indicator
          _buildSensorIndicator(
            context: context,
            isConnected: sensors['hrm'] ?? false,
            icon: Icons.favorite,
            label: 'HRM',
          ),

          const SizedBox(width: 24),

          // Footpod sensor indicator
          _buildSensorIndicator(
            context: context,
            isConnected: sensors['stryd'] ?? false,
            icon: Icons.directions_run,
            label: 'Stryd',
          ),
        ],
      ),
    );
  }

  Widget _buildSensorIndicator({
    required BuildContext context,
    required bool isConnected,
    required IconData icon,
    required String label,
  }) {
    return Container(
      width: 70,
      height: 32,
      decoration: BoxDecoration(
        color:
            isConnected ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
          width: 1.0,
        ),
        boxShadow: [
          if (isConnected)
            BoxShadow(
              color: Colors.green.withAlpha(80),
              blurRadius: 4.0,
              spreadRadius: 1.0,
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isConnected ? Colors.green : Colors.red,
            size: 16.0,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
              color: isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
