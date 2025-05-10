// lib/features/run_tracker/screens/activity_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/tracker_providers.dart';
import '../models/activity.dart';
import '../widgets/custom_metric_display.dart';

/// Screen 2 of the activity tracker showing a map with route and customizable metrics
class ActivityMapScreen extends ConsumerStatefulWidget {
  const ActivityMapScreen({super.key});

  @override
  ConsumerState<ActivityMapScreen> createState() => _ActivityMapScreenState();
}

class _ActivityMapScreenState extends ConsumerState<ActivityMapScreen> {
  // Map controller to control zoom and centering
  final MapController _mapController = MapController();

  // Selected metrics for the top display (user can customize these)
  String _leftMetric = 'pace';
  String _rightMetric = 'heartRate';

  // Available metrics to choose from
  final List<String> _availableMetrics = [
    'pace',
    'heartRate',
    'power',
    'cadence',
    'distance',
    'duration',
    'elevationGain',
    'elevationLoss',
  ];

  @override
  Widget build(BuildContext context) {
    // Get current activity and metrics from providers
    final currentActivity = ref.watch(currentActivityProvider);
    final metrics = ref.watch(currentMetricsProvider);

    // Get route points from the current activity
    final routePoints = currentActivity?.routePoints ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Activity Map'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Top metrics display (customizable)
          SizedBox(
            height: 80,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  // Left metric (customizable)
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () => _showMetricPicker(isLeftMetric: true),
                      child: CustomMetricDisplay(
                        metricKey: _leftMetric,
                        metrics: metrics,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Right metric (customizable)
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () => _showMetricPicker(isLeftMetric: false),
                      child: CustomMetricDisplay(
                        metricKey: _rightMetric,
                        metrics: metrics,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Map view (takes remaining space)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildMapView(routePoints),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the map view with the current route
  Widget _buildMapView(List<LatLng> routePoints) {
    // Default center point if no GPS data
    LatLng center =
        const LatLng(37.7749, -122.4194); // Default to San Francisco

    // If we have route points, center on the latest one
    if (routePoints.isNotEmpty) {
      center = routePoints.last;

      // Update map view if needed - This ensures map stays centered on current location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(center, 16);
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 16.0, // Good zoom level for running
          minZoom: 3.0,
          maxZoom: 18.0,
        ),
        children: [
          // Base map tiles
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.volt_running_tracker',
          ),

          // Route polyline
          if (routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  color: Colors.blue,
                  strokeWidth: 4.0,
                ),
              ],
            ),

          // Current position marker
          if (routePoints.isNotEmpty)
            MarkerLayer(
              markers: [
                Marker(
                  point: routePoints.last,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Show a dialog to pick a metric for display
  void _showMetricPicker({required bool isLeftMetric}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select ${isLeftMetric ? 'Left' : 'Right'} Metric'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableMetrics.length,
            itemBuilder: (context, index) {
              final metric = _availableMetrics[index];
              return ListTile(
                title: Text(_getMetricDisplayName(metric)),
                onTap: () {
                  setState(() {
                    if (isLeftMetric) {
                      _leftMetric = metric;
                    } else {
                      _rightMetric = metric;
                    }
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Get a human-readable display name for a metric key
  String _getMetricDisplayName(String metricKey) {
    switch (metricKey) {
      case 'pace':
        return 'Pace';
      case 'heartRate':
        return 'Heart Rate';
      case 'power':
        return 'Power';
      case 'cadence':
        return 'Cadence';
      case 'distance':
        return 'Distance';
      case 'duration':
        return 'Duration';
      case 'elevationGain':
        return 'Elevation Gain';
      case 'elevationLoss':
        return 'Elevation Loss';
      default:
        return metricKey;
    }
  }
}
