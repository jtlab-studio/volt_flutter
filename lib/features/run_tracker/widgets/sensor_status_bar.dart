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
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            isConnected ? Colors.green.withAlpha(51) : Colors.red.withAlpha(51),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
          width: 1.0,
        ),
        boxShadow: [
          if (isConnected)
            BoxShadow(
              color: Colors.green.withAlpha(128),
              blurRadius: 8.0,
              spreadRadius: 2.0,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isConnected ? Colors.green : Colors.red,
            size: 24.0,
          ),
          const SizedBox(height: 2),
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
