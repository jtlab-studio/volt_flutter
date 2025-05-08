// lib/features/run_tracker/screens/run_tracker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../providers/tracker_providers.dart';
import '../services/tracker_service.dart';
import '../widgets/metrics_grid.dart';
import '../widgets/sensor_status_bar.dart';
import '../widgets/activity_controls.dart';
import 'activity_summary_screen.dart';
import 'activity_history_screen.dart';

class RunTrackerScreen extends ConsumerStatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  ConsumerState<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends ConsumerState<RunTrackerScreen>
    with WidgetsBindingObserver {
  // Flag to show modal when initializing
  bool _isInitializing = true;
  bool _buttonPressed = false;

  // Map controller to control zoom and centering
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Automatically connect to sensors as soon as the screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    super.dispose();
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

  // View activity history
  void _viewActivityHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ActivityHistoryScreen(),
      ),
    );
  }

  // Build the map section
  Widget _buildMapSection() {
    final currentActivity = ref.watch(currentActivityProvider);
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

  @override
  Widget build(BuildContext context) {
    final trackerState = ref.watch(trackerStateProvider);
    final metrics = ref.watch(currentMetricsProvider);

    // FIXED: Properly detect if the timer has started
    final bool timerStarted =
        metrics['duration'] > 0 && trackerState == TrackerState.active;

    // Calculate available height between app bar and bottom
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = kToolbarHeight;
    final bottomNavHeight = 70.0; // Activity controls height
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final sensorBarHeight = 40.0;

    // Calculate space available for content
    final availableHeight = screenHeight -
        appBarHeight -
        bottomNavHeight -
        bottomPadding -
        sensorBarHeight;

    // Allocate ~60% to metrics grid, rest to map
    final metricsGridHeight = availableHeight * 0.6;
    final mapHeight = availableHeight * 0.4;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Run Tracker'),
        backgroundColor: Colors.black,
        actions: [
          // History button
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _viewActivityHistory,
            tooltip: 'Activity History',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content - IMPROVED LAYOUT WITH MAP
          Column(
            children: [
              // Sensor status bar
              const SizedBox(
                height: 40,
                child: SensorStatusBar(),
              ),

              // Metrics grid - ~60% of available space
              SizedBox(
                height: metricsGridHeight,
                child: MetricsGrid(metrics: metrics),
              ),

              // Small spacer
              const SizedBox(height: 8),

              // Map section - ~40% of available space
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: SizedBox(
                  height: mapHeight,
                  child: _buildMapSection(),
                ),
              ),

              // Small spacer
              const SizedBox(height: 8),

              // Activity controls at the bottom
              SizedBox(
                height: 70,
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

              // Space for bottom system UI
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
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
