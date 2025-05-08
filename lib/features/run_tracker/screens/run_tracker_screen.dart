// lib/features/run_tracker/screens/run_tracker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      // Check if we're tracking and reconnect if needed
      if (trackerService.isTracking) {
        // This will be handled by the tracker service
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
      });
    }
  }

  // Start activity
  Future<void> _startActivity() async {
    final trackerService = ref.read(trackerServiceProvider);

    // Vibrate to indicate start
    Vibration.vibrate(duration: 200);

    await trackerService.startActivity();
  }

  // Pause activity
  Future<void> _pauseActivity() async {
    final trackerService = ref.read(trackerServiceProvider);

    // Vibrate to indicate pause
    Vibration.vibrate(duration: 100);
    await Future.delayed(const Duration(milliseconds: 150));
    Vibration.vibrate(duration: 100);

    await trackerService.pauseActivity();
  }

  // Resume activity
  Future<void> _resumeActivity() async {
    final trackerService = ref.read(trackerServiceProvider);

    // Vibrate to indicate resume
    Vibration.vibrate(duration: 100);

    await trackerService.resumeActivity();
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
            child: const Text('Discard'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    final trackerState = ref.watch(trackerStateProvider);
    final metrics = ref.watch(currentMetricsProvider);

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
          // Main content
          Column(
            children: [
              // Sensor status bar
              const SensorStatusBar(),

              // Metrics grid takes most of the space
              Expanded(
                child: MetricsGrid(metrics: metrics),
              ),

              // Activity controls at the bottom
              ActivityControls(
                state: trackerState,
                onStart: _startActivity,
                onPause: _pauseActivity,
                onResume: _resumeActivity,
                onStop: _endActivity,
                onDiscard: _discardActivity,
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
