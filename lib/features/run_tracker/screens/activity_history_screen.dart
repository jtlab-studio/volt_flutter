// lib/features/run_tracker/screens/activity_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/tracker_providers.dart';
import '../models/activity.dart';
import '../models/sensor_reading.dart';
import '../services/tracker_service.dart';
import '../services/database_service.dart';
import 'activity_summary_screen.dart';

class ActivityHistoryScreen extends ConsumerStatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  ConsumerState<ActivityHistoryScreen> createState() =>
      _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends ConsumerState<ActivityHistoryScreen> {
  // Mode for list view (show all activities or filtered)
  String _filterMode = 'all';

  @override
  Widget build(BuildContext context) {
    // Watch activity history
    final activitiesAsyncValue = ref.watch(activityHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Activity History'),
        backgroundColor: Colors.black,
        actions: [
          // Filter button
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Activities',
            onSelected: (value) {
              setState(() {
                _filterMode = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Activities'),
              ),
              const PopupMenuItem(
                value: 'this_week',
                child: Text('This Week'),
              ),
              const PopupMenuItem(
                value: 'this_month',
                child: Text('This Month'),
              ),
            ],
          ),
        ],
      ),
      body: activitiesAsyncValue.when(
        data: (activities) {
          // Apply filtering
          final filteredActivities = _filterActivities(activities);

          if (filteredActivities.isEmpty) {
            return _buildEmptyState();
          }

          return _buildActivityList(filteredActivities);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Text(
            'Error loading activities: $error',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pop(); // Go back to home/run tracker
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  // Filter activities based on selected mode
  List<Activity> _filterActivities(List<Activity> activities) {
    if (_filterMode == 'all') {
      return activities;
    }

    final now = DateTime.now();

    if (_filterMode == 'this_week') {
      // Start of week (Sunday)
      final startOfWeek = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday % 7));

      return activities.where((activity) {
        return activity.startTime.isAfter(startOfWeek);
      }).toList();
    }

    if (_filterMode == 'this_month') {
      // Start of month
      final startOfMonth = DateTime(now.year, now.month, 1);

      return activities.where((activity) {
        return activity.startTime.isAfter(startOfMonth);
      }).toList();
    }

    return activities;
  }

  // Build empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_run,
            size: 80,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 16.0),
          Text(
            'No Activities Found',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            _filterMode == 'all'
                ? 'Start tracking your runs to see them here'
                : 'Try changing the filter to see more activities',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24.0),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(); // Go back to home/run tracker
            },
            icon: const Icon(Icons.add),
            label: const Text('NEW ACTIVITY'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build activity list
  Widget _buildActivityList(List<Activity> activities) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildActivityCard(activity);
      },
    );
  }

  // Build card for a single activity
  Widget _buildActivityCard(Activity activity) {
    final formattedDate = DateFormat('EEE, MMM d').format(activity.startTime);
    final formattedTime = DateFormat('h:mm a').format(activity.startTime);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        onTap: () => _viewActivityDetails(activity),
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Activity name and date/time
              Row(
                children: [
                  Icon(
                    Icons.directions_run,
                    color: Colors.blue,
                    size: 24.0,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$formattedDate at $formattedTime',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.grey,
                    ),
                    onPressed: () => _showActivityOptions(activity),
                  ),
                ],
              ),

              const SizedBox(height: 16.0),

              // Key metrics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Distance
                  _buildMetricColumn(
                    label: 'DISTANCE',
                    value:
                        '${TrackerService.formatDistance(activity.distanceMeters)} km',
                    icon: Icons.straighten,
                    iconColor: Colors.blue,
                  ),

                  // Duration
                  _buildMetricColumn(
                    label: 'TIME',
                    value:
                        TrackerService.formatDuration(activity.durationSeconds),
                    icon: Icons.timer,
                    iconColor: Colors.orange,
                  ),

                  // Pace
                  _buildMetricColumn(
                    label: 'PACE',
                    value: SensorReading.formatPace(
                        activity.averagePaceSecondsPerKm),
                    icon: Icons.speed,
                    iconColor: Colors.green,
                  ),

                  // Heart Rate (if available)
                  _buildMetricColumn(
                    label: 'HEART RATE',
                    value: activity.averageHeartRate != null
                        ? '${activity.averageHeartRate} bpm'
                        : '--',
                    icon: Icons.favorite,
                    iconColor: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build a single metric column
  Widget _buildMetricColumn({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 16.0,
        ),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14.0,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // View activity details
  void _viewActivityDetails(Activity activity) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActivitySummaryScreen(
          activity: activity,
        ),
      ),
    );
  }

  // Show options for an activity
  void _showActivityOptions(Activity activity) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Activity name as header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[800]!,
                      width: 1.0,
                    ),
                  ),
                ),
                child: Text(
                  activity.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // View details option
              ListTile(
                leading: const Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                ),
                title: const Text(
                  'View Details',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _viewActivityDetails(activity);
                },
              ),

              // Rename option
              ListTile(
                leading: const Icon(
                  Icons.edit,
                  color: Colors.green,
                ),
                title: const Text(
                  'Rename Activity',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showRenameDialog(activity);
                },
              ),

              // Delete option
              ListTile(
                leading: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                title: const Text(
                  'Delete Activity',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteConfirmation(activity);
                },
              ),

              // Cancel option
              ListTile(
                leading: const Icon(
                  Icons.close,
                  color: Colors.grey,
                ),
                title: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Show dialog to rename activity
  void _showRenameDialog(Activity activity) {
    final nameController = TextEditingController(text: activity.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text(
            'Rename Activity',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter a new name',
              hintStyle: TextStyle(color: Colors.grey[400]),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  _renameActivity(activity, newName);
                }
                Navigator.of(context).pop();
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  // Rename activity
  Future<void> _renameActivity(Activity activity, String newName) async {
    try {
      final dbService = DatabaseService.instance;

      // Update activity in memory
      activity.name = newName;

      // Save to database
      await dbService.updateActivity(activity);

      // Refresh the list - store result to address warning
      final _ = ref.refresh(activityHistoryProvider);
    } catch (e) {
      debugPrint('Error renaming activity: $e');

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error renaming activity: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show confirmation before deleting activity
  void _showDeleteConfirmation(Activity activity) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text(
            'Delete Activity',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "${activity.name}"? This cannot be undone.',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteActivity(activity);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );
  }

  // Delete activity
  Future<void> _deleteActivity(Activity activity) async {
    try {
      final dbService = DatabaseService.instance;

      // Delete from database
      await dbService.deleteActivity(activity.id);

      // Refresh the list - store result to address warning
      final _ = ref.refresh(activityHistoryProvider);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity deleted'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting activity: $e');

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting activity: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
