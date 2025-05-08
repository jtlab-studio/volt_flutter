// lib/features/run_tracker/widgets/activity_controls.dart
import 'package:flutter/material.dart';
import '../services/tracker_service.dart';

class ActivityControls extends StatelessWidget {
  final TrackerState state;
  final bool timerStarted; // Add this to track if timer has started
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onDiscard;

  const ActivityControls({
    super.key,
    required this.state,
    this.timerStarted = false, // Default to false
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(128),
            blurRadius: 10.0,
            spreadRadius: 2.0,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: _buildControlsForState(context),
    );
  }

  // Build different controls based on tracker state
  Widget _buildControlsForState(BuildContext context) {
    // Override the visual state if timer hasn't started but it should be active
    TrackerState visualState = state;
    if (state == TrackerState.active && !timerStarted) {
      visualState = TrackerState.idle; // Show start button instead
    }

    switch (visualState) {
      case TrackerState.idle:
      case TrackerState.preparing:
        return _buildStartControls();
      case TrackerState.active:
        return _buildActiveControls();
      case TrackerState.paused:
        return _buildPausedControls();
      case TrackerState.stopped:
      case TrackerState.error:
        return _buildErrorControls();
    }
  }

  // Controls for idle/preparing state
  Widget _buildStartControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Start button - Now always enabled
        _buildControlButton(
          onPressed: onStart,
          icon: Icons.play_arrow,
          label: 'START',
          color: Colors.green,
          size: 64.0,
          isLoading: state == TrackerState.preparing,
        ),
      ],
    );
  }

  // Controls for active state
  Widget _buildActiveControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Discard button (small)
        _buildControlButton(
          onPressed: onDiscard,
          icon: Icons.delete,
          color: Colors.red,
          size: 48.0,
          showBackground: false,
        ),

        // Pause button (large)
        _buildControlButton(
          onPressed: onPause,
          icon: Icons.pause,
          label: 'PAUSE',
          color: Colors.orange,
          size: 64.0,
        ),

        // End button (small)
        _buildControlButton(
          onPressed: onStop,
          icon: Icons.stop,
          color: Colors.red,
          size: 48.0,
          showBackground: false,
        ),
      ],
    );
  }

  // Controls for paused state
  Widget _buildPausedControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Discard button
        _buildControlButton(
          onPressed: onDiscard,
          icon: Icons.delete,
          label: 'DISCARD',
          color: Colors.red,
          size: 48.0,
        ),

        // Resume button
        _buildControlButton(
          onPressed: onResume,
          icon: Icons.play_arrow,
          label: 'RESUME',
          color: Colors.green,
          size: 64.0,
        ),

        // End button
        _buildControlButton(
          onPressed: onStop,
          icon: Icons.stop,
          label: 'END',
          color: Colors.red,
          size: 48.0,
        ),
      ],
    );
  }

  // Controls for error state
  Widget _buildErrorControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Retry button
        _buildControlButton(
          onPressed: onStart,
          icon: Icons.refresh,
          label: 'RETRY',
          color: Colors.orange,
          size: 64.0,
        ),
      ],
    );
  }

  // Helper to build control buttons
  Widget _buildControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
    String? label,
    required Color color,
    required double size,
    bool showBackground = true,
    bool isLoading = false,
  }) {
    // Disabled color
    final disabledColor = Colors.grey;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(size / 2),
            child: Ink(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: showBackground
                    ? (onPressed != null
                        ? color.withAlpha(51)
                        : disabledColor.withAlpha(25))
                    : Colors.transparent,
                border: Border.all(
                  color: onPressed != null ? color : disabledColor,
                  width: 2.0,
                ),
              ),
              child: isLoading
                  ? Center(
                      child: SizedBox(
                        width: size / 2,
                        height: size / 2,
                        child: CircularProgressIndicator(
                          color: color,
                          strokeWidth: 3.0,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        icon,
                        color: onPressed != null ? color : disabledColor,
                        size: size / 2,
                      ),
                    ),
            ),
          ),
        ),

        // Label
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              label,
              style: TextStyle(
                color: onPressed != null ? Colors.white : disabledColor,
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
      ],
    );
  }
}
