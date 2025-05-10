// lib/features/run_tracker/screens/activity_map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // Add Geolocator import
import '../providers/tracker_providers.dart';
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

  // Default location (will be replaced with user's location)
  LatLng _userLocation = const LatLng(0, 0); // Default initialization
  bool _isLoadingLocation = true;

  // Available metrics to choose from
  final List<String> _availableMetrics = [
    'pace',
    'avgPace',
    'heartRate',
    'avgHeartRate',
    'power',
    'avgPower',
    'cadence',
    'avgCadence',
    'distance',
    'duration',
    'elevationGain',
    'elevationLoss',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Get user's current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location permission denied");
          _handleLocationError("Location permissions are denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permissions are permanently denied");
        _handleLocationError("Location permissions are permanently denied");
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Update map view to current location
      _mapController.move(_userLocation, 16.0);
    } catch (e) {
      debugPrint("Error getting location: $e");
      _handleLocationError("Error getting your location: $e");
    }
  }

  void _handleLocationError(String message) {
    setState(() {
      _isLoadingLocation = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
        actions: [
          // Add a button to recenter the map to current location
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'My Location',
          ),
        ],
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
              child: _isLoadingLocation
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Getting your location...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  : _buildMapView(routePoints),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the map view with the current route
  Widget _buildMapView(List<LatLng> routePoints) {
    // Determine center point: use route points if available, else use current location
    LatLng center = routePoints.isNotEmpty ? routePoints.last : _userLocation;

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

          // Current location marker if no route points
          if (routePoints.isEmpty)
            MarkerLayer(
              markers: [
                Marker(
                  point: _userLocation,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
              ],
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

          // Current position marker from route
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
    // Dialog implementation remains the same...
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text(
          'Select ${isLeftMetric ? 'Left' : 'Right'} Metric',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableMetrics.length,
            itemBuilder: (context, index) {
              final metric = _availableMetrics[index];
              return ListTile(
                title: Text(
                  _getMetricDisplayName(metric),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Icon(
                  _getMetricIcon(metric),
                  color: _getMetricColor(metric),
                ),
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
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  /// Get a human-readable display name for a metric key
  String _getMetricDisplayName(String metricKey) {
    switch (metricKey) {
      case 'pace':
        return 'Pace (Current)';
      case 'avgPace':
        return 'Pace (Average)';
      case 'heartRate':
        return 'Heart Rate (Current)';
      case 'avgHeartRate':
        return 'Heart Rate (Average)';
      case 'power':
        return 'Power (Current)';
      case 'avgPower':
        return 'Power (Average)';
      case 'cadence':
        return 'Cadence (Current)';
      case 'avgCadence':
        return 'Cadence (Average)';
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

  /// Get an icon for a metric
  IconData _getMetricIcon(String metricKey) {
    if (metricKey.contains('pace')) {
      return Icons.speed;
    } else if (metricKey.contains('heart')) {
      return Icons.favorite;
    } else if (metricKey.contains('power')) {
      return Icons.bolt;
    } else if (metricKey.contains('cadence')) {
      return Icons.directions_walk;
    } else if (metricKey.contains('distance')) {
      return Icons.straighten;
    } else if (metricKey.contains('duration')) {
      return Icons.timer;
    } else if (metricKey.contains('elevation')) {
      return metricKey.contains('Gain')
          ? Icons.arrow_upward
          : Icons.arrow_downward;
    } else {
      return Icons.data_usage;
    }
  }

  /// Get a color for a metric
  Color _getMetricColor(String metricKey) {
    if (metricKey.contains('pace')) {
      return Colors.orange;
    } else if (metricKey.contains('heart')) {
      return Colors.red;
    } else if (metricKey.contains('power')) {
      return Colors.yellow;
    } else if (metricKey.contains('cadence')) {
      return Colors.green;
    } else if (metricKey.contains('distance')) {
      return Colors.blue;
    } else if (metricKey.contains('duration')) {
      return Colors.blue;
    } else if (metricKey.contains('elevationGain')) {
      return Colors.purple;
    } else if (metricKey.contains('elevationLoss')) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }
}
