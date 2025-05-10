// lib/features/run_tracker/screens/activity_tracker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../sensors/screens/bluetooth_service.dart'; // Added for BLE connection

import '../providers/tracker_providers.dart';
import '../services/tracker_service.dart';
import '../widgets/metrics_grid.dart';
import '../widgets/sensor_status_bar.dart';
import '../widgets/activity_controls.dart';
import 'activity_summary_screen.dart';

class ActivityTrackerScreen extends ConsumerStatefulWidget {
  const ActivityTrackerScreen({super.key});

  @override
  ConsumerState<ActivityTrackerScreen> createState() =>
      _ActivityTrackerScreenState();
}

class _ActivityTrackerScreenState extends ConsumerState<ActivityTrackerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Flag to show modal when initializing
  bool _isInitializing = true;
  bool _buttonPressed = false;

  // Map controller to control zoom and centering
  final MapController _mapController = MapController();

  // Tab controller for switching between metrics and map
  late TabController _tabController;

  // Custom metrics for the map view
  String _leftMetric = 'pace';
  String _rightMetric = 'distance';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize tab controller for the two screens
    _tabController = TabController(length: 2, vsync: this);

    // Automatically connect to sensors as soon as the screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Connect to saved BLE devices first
      _connectToSavedDevices();

      // Then prepare the activity (which will also set up GPS etc.)
      _prepareActivity();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final trackerService = ref.read(trackerServiceProvider);

    if (state == AppLifecycleState.resumed) {
      // App is in the foreground
      // Auto-reconnect to sensors when returning to the app
      if (trackerService.isTracking || _isInitializing) {
        _prepareActivity();
      }
    } else if (state == AppLifecycleState.paused) {
      // App is in the background
      // Automatically pause the activity if it's active
      if (trackerService.state == TrackerState.active) {
        trackerService.pauseActivity();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activity automatically paused')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  /// Connect to saved BLE sensor devices
  Future<void> _connectToSavedDevices() async {
    // Show a connecting indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting to saved sensors...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      // Create Bluetooth service instance
      final bluetoothService = CustomBluetoothService();

      // Load saved devices
      final savedDevices = await bluetoothService.loadSavedDevices();

      if (savedDevices.isNotEmpty) {
        // Connect to saved devices
        final connectedCount =
            await bluetoothService.autoConnectToSavedDevices(savedDevices);

        // Show connection status
        if (mounted) {
          if (connectedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Connected to $connectedCount ${connectedCount == 1 ? 'sensor' : 'sensors'}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No sensors connected'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 1),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error connecting to saved devices: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error connecting to sensors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Prepare the activity
  Future<void> _prepareActivity() async {
    setState(() {
      _isInitializing = true;
    });

    final trackerService = ref.read(trackerServiceProvider);

    // Prepare activity will connect to sensors and set up
    await trackerService.prepareActivity();

    if (mounted) {
      setState(() {
        _isInitializing = false;

        // If start button was pressed while initializing, start the activity now
        if (_buttonPressed) {
          _buttonPressed = false;
          _startActivity(); // Auto-start after initialization completes
        }
      });
    }
  }

  // Start activity
  Future<void> _startActivity() async {
    final trackerService = ref.read(trackerServiceProvider);

    // If still initializing, set the flag and return
    if (_isInitializing) {
      setState(() {
        _buttonPressed = true;
      });
      return;
    }

    // Vibrate to indicate start
    Vibration.vibrate(duration: 200);

    await trackerService.startActivity();

    // Explicitly notify UI that we've started
    if (mounted) {
      setState(() {});
    }
  }

  // Pause activity
  Future<void> _pauseActivity() async {
    final trackerService = ref.read(trackerServiceProvider);

    // Vibrate to indicate pause
    Vibration.vibrate(duration: 100);
    await Future.delayed(const Duration(milliseconds: 150));
    Vibration.vibrate(duration: 100);

    await trackerService.pauseActivity();

    // Explicitly update UI
    if (mounted) {
      setState(() {});
    }
  }

  // Resume activity
  Future<void> _resumeActivity() async {
    final trackerService = ref.read(trackerServiceProvider);

    // Vibrate to indicate resume
    Vibration.vibrate(duration: 100);

    await trackerService.resumeActivity();

    // Explicitly update UI
    if (mounted) {
      setState(() {});
    }
  }

  // End activity
  Future<void> _endActivity() async {
    final trackerService = ref.read(trackerServiceProvider);

    // Vibrate to indicate end
    Vibration.vibrate(duration: 300);

    // End the activity
    final completedActivity = await trackerService.endActivity();

    if (completedActivity != null && mounted) {
      // Navigate to summary screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              ActivitySummaryScreen(activity: completedActivity),
        ),
      );
    } else {
      // If there was an error or the user is no longer on this screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // Discard activity
  Future<void> _discardActivity() async {
    final trackerService = ref.read(trackerServiceProvider);

    // Show confirmation dialog
    if (!mounted) return;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Activity'),
        content: const Text(
            'Are you sure you want to discard this activity? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (shouldDiscard == true) {
      await trackerService.discardActivity();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // Build the map view tab
  Widget _buildMapView() {
    final currentActivity = ref.watch(currentActivityProvider);
    final metrics = ref.watch(currentMetricsProvider);
    final routePoints = currentActivity?.routePoints ?? [];

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

    return Column(
      children: [
        // Sensor status bar
        const SensorStatusBar(),

        // Top metrics display (customizable)
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Left metric
              Expanded(
                child: _buildMapMetricCard(_leftMetric, metrics, true),
              ),
              const SizedBox(width: 12),
              // Right metric
              Expanded(
                child: _buildMapMetricCard(_rightMetric, metrics, false),
              ),
            ],
          ),
        ),

        // Map view (takes remaining space)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              margin: EdgeInsets.zero,
              child: ClipRRect(
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
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
              ),
            ),
          ),
        ),

        // Space for the controls
        const SizedBox(height: 70),
      ],
    );
  }

  // Build a metric card for the map view
  Widget _buildMapMetricCard(
      String metricKey, Map<String, dynamic> metrics, bool isLeft) {
    return InkWell(
      onTap: () => _showMetricPicker(isLeft),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: EdgeInsets.zero,
        color: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Metric label
              Text(
                _getMetricLabel(metricKey),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              // Metric value
              Text(
                _formatMetricValue(metricKey, metrics),
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Hint
              Text(
                'Tap to change',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show a dialog to pick a metric for display
  void _showMetricPicker(bool isLeft) {
    final availableMetrics = [
      'pace',
      'heartRate',
      'power',
      'cadence',
      'distance',
      'duration',
      'elevationGain',
      'elevationLoss',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select ${isLeft ? 'Left' : 'Right'} Metric'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableMetrics.length,
            itemBuilder: (context, index) {
              final metric = availableMetrics[index];
              return ListTile(
                title: Text(_getMetricLabel(metric)),
                onTap: () {
                  setState(() {
                    if (isLeft) {
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

  // Get the display label for a metric key
  String _getMetricLabel(String metricKey) {
    switch (metricKey) {
      case 'pace':
        return 'PACE';
      case 'heartRate':
        return 'HEART RATE';
      case 'power':
        return 'POWER';
      case 'cadence':
        return 'CADENCE';
      case 'distance':
        return 'DISTANCE';
      case 'duration':
        return 'TIME';
      case 'elevationGain':
        return 'ELEV. GAIN';
      case 'elevationLoss':
        return 'ELEV. LOSS';
      default:
        return metricKey.toUpperCase();
    }
  }

  // Format the metric value based on its type
  String _formatMetricValue(String metricKey, Map<String, dynamic> metrics) {
    switch (metricKey) {
      case 'pace':
        final pace = metrics['pace'] as int?;
        return pace != null
            ? '${pace ~/ 60}:${(pace % 60).toString().padLeft(2, '0')}'
            : '--:--';

      case 'heartRate':
        final heartRate = metrics['heartRate'] as int?;
        return heartRate != null ? '$heartRate bpm' : '--';

      case 'power':
        final power = metrics['power'] as int?;
        return power != null ? '$power W' : '--';

      case 'cadence':
        final cadence = metrics['cadence'] as int?;
        return cadence != null ? '$cadence spm' : '--';

      case 'distance':
        final distance = metrics['distance'] as double;
        return '${TrackerService.formatDistance(distance)} km';

      case 'duration':
        final duration = metrics['duration'] as int;
        return TrackerService.formatDuration(duration);

      case 'elevationGain':
        final elevationGain = metrics['elevationGain'] as double;
        return '${elevationGain.toStringAsFixed(0)} m';

      case 'elevationLoss':
        final elevationLoss = metrics['elevationLoss'] as double;
        return '${elevationLoss.toStringAsFixed(0)} m';

      default:
        return '--';
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackerState = ref.watch(trackerStateProvider);
    final metrics = ref.watch(currentMetricsProvider);

    final bool timerStarted =
        metrics['duration'] > 0 && trackerState == TrackerState.active;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Activity Tracker'),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.data_usage),
              text: 'Metrics',
            ),
            Tab(
              icon: Icon(Icons.map),
              text: 'Map',
            ),
          ],
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: Stack(
        children: [
          // Main content - TabBarView for switching between metrics and map
          TabBarView(
            controller: _tabController,
            children: [
              // First tab - Metrics Grid
              Column(
                children: [
                  // Sensor status bar
                  const SensorStatusBar(),

                  // Metrics grid
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: MetricsGrid(metrics: metrics),
                    ),
                  ),

                  // Space for controls
                  const SizedBox(height: 70),
                ],
              ),

              // Second tab - Map View
              _buildMapView(),
            ],
          ),

          // Activity controls fixed at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ActivityControls(
              state: trackerState,
              timerStarted: timerStarted,
              onStart: _startActivity,
              onPause: _pauseActivity,
              onResume: _resumeActivity,
              onStop: _endActivity,
              onDiscard: _discardActivity,
            ),
          ),

          // Loading overlay
          if (_isInitializing)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withAlpha(179),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Connecting to sensors...',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
