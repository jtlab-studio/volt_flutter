// lib/features/run_tracker/services/tracker_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/activity.dart';
import '../models/sensor_reading.dart';
import '../../sensors/screens/bluetooth_service.dart';
import 'database_service.dart';

enum TrackerState {
  idle,
  preparing,
  active,
  paused,
  stopped,
  error,
}

class TrackerService extends ChangeNotifier {
  // Singleton instance
  static final TrackerService _instance = TrackerService._internal();
  factory TrackerService() => _instance;

  // Services
  final DatabaseService _dbService = DatabaseService.instance;
  final CustomBluetoothService _bluetoothService = CustomBluetoothService();

  // State variables
  TrackerState _state = TrackerState.idle;
  Activity? _currentActivity;

  // Sensor connection status
  bool _isGpsConnected = false;
  bool _isHrmConnected = false;
  bool _isStrydConnected = false;

  // Last known sensor values
  Position? _lastGpsPosition;
  int? _lastHeartRate;
  int? _lastPower;
  int? _lastCadence;
  double? _lastDistance;
  int? _lastPace;

  // Cumulative tracking values
  double _totalDistanceMeters = 0;
  double _elevationGainMeters = 0;
  double _elevationLossMeters = 0;
  double? _lastElevation;

  // Timer for tracking duration
  Timer? _activityTimer;
  DateTime? _lastTimerUpdate;

  // Timer for data collection
  Timer? _dataCollectionTimer;

  // Buffer for sensor readings (to batch DB operations)
  final List<SensorReading> _readingsBuffer = [];
  static const int _maxBufferSize = 10; // Flush to DB every 10 readings

  // Device references
  BluetoothDevice? _hrmDevice;
  BluetoothDevice? _strydDevice;

  // Location updates subscription
  StreamSubscription<Position>? _positionStreamSubscription;

  // Public getters
  TrackerState get state => _state;
  Activity? get currentActivity => _currentActivity;
  bool get isTracking =>
      _state == TrackerState.active || _state == TrackerState.paused;
  bool get isGpsConnected => _isGpsConnected;
  bool get isHrmConnected => _isHrmConnected;
  bool get isStrydConnected => _isStrydConnected;
  int? get lastHeartRate => _lastHeartRate;
  int? get lastPower => _lastPower;
  int? get lastCadence => _lastCadence;
  double get totalDistanceMeters => _totalDistanceMeters;
  double get elevationGainMeters => _elevationGainMeters;
  double get elevationLossMeters => _elevationLossMeters;
  int? get lastPace => _lastPace;

  // Constructor
  TrackerService._internal() {
    _initSensors();
  }

  // Initialize sensors
  Future<void> _initSensors() async {
    try {
      // Request location permissions
      final permissionStatus = await Geolocator.requestPermission();
      _isGpsConnected = permissionStatus == LocationPermission.always ||
          permissionStatus == LocationPermission.whileInUse;

      // Load saved devices from storage
      final savedDevices = await _bluetoothService.loadSavedDevices();

      // Identify HRM and Stryd devices
      for (final device in savedDevices) {
        final deviceName =
            _bluetoothService.getDeviceDisplayName(device).toLowerCase();

        if (deviceName.contains('hrm') || deviceName.contains('heart')) {
          _hrmDevice = device;
        } else if (deviceName.contains('stryd') ||
            deviceName.contains('footpod')) {
          _strydDevice = device;
        }
      }

      // Connect to Bluetooth devices if we're in an active state
      if (_state == TrackerState.active) {
        _connectToSensors();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing sensors: $e');
    }
  }

  // Connect to all available sensors
  Future<void> _connectToSensors() async {
    // Check GPS first
    _checkGpsConnection();

    // Then connect to Bluetooth devices
    await _connectToHrm();
    await _connectToStryd();

    notifyListeners();
  }

  // Check GPS connection status
  Future<void> _checkGpsConnection() async {
    try {
      final status = await Geolocator.checkPermission();
      _isGpsConnected = status == LocationPermission.always ||
          status == LocationPermission.whileInUse;

      if (_isGpsConnected) {
        // Try to get current position as a test
        await Geolocator.getCurrentPosition()
            .timeout(const Duration(seconds: 5), onTimeout: () {
          _isGpsConnected = false;
          return Position(
            longitude: 0,
            latitude: 0,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        });
      }
    } catch (e) {
      _isGpsConnected = false;
      debugPrint('Error checking GPS connection: $e');
    }

    notifyListeners();
  }

  // Connect to HRM device
  Future<void> _connectToHrm() async {
    if (_hrmDevice == null) {
      _isHrmConnected = false;
      return;
    }

    try {
      // Connect to device
      final connected =
          await _bluetoothService.connectSingleDevice(_hrmDevice!);
      _isHrmConnected = connected;

      if (connected) {
        // Discover services
        final services = await _hrmDevice!.discoverServices();

        // Find heart rate service
        for (final service in services) {
          // Heart rate service UUID
          if (service.uuid.toString().toLowerCase().contains('180d')) {
            // Find heart rate measurement characteristic
            for (final characteristic in service.characteristics) {
              // Heart rate measurement characteristic UUID
              if (characteristic.uuid
                  .toString()
                  .toLowerCase()
                  .contains('2a37')) {
                // Set up notifications
                await characteristic.setNotifyValue(true);
                characteristic.onValueReceived.listen(_onHeartRateReceived);

                break;
              }
            }
          }
        }
      }
    } catch (e) {
      _isHrmConnected = false;
      debugPrint('Error connecting to HRM: $e');
    }

    notifyListeners();
  }

  // Connect to Stryd device
  Future<void> _connectToStryd() async {
    if (_strydDevice == null) {
      _isStrydConnected = false;
      return;
    }

    try {
      // Connect to device
      final connected =
          await _bluetoothService.connectSingleDevice(_strydDevice!);
      _isStrydConnected = connected;

      if (connected) {
        // Discover services
        final services = await _strydDevice!.discoverServices();

        // Find running power service (there's no standard UUID, so we'll check all services)
        for (final service in services) {
          for (final characteristic in service.characteristics) {
            // Check for read/notify properties which are likely for sensor data
            if (characteristic.properties.read ||
                characteristic.properties.notify) {
              // Set up notifications for all potential data characteristics
              await characteristic.setNotifyValue(true);

              // Subscribe to updates (we'll figure out which is which based on the data)
              characteristic.onValueReceived.listen(_onStrydDataReceived);
            }
          }
        }
      }
    } catch (e) {
      _isStrydConnected = false;
      debugPrint('Error connecting to Stryd: $e');
    }

    notifyListeners();
  }

  // Heart rate data handler
  void _onHeartRateReceived(List<int> data) {
    if (data.isEmpty) return;

    try {
      // Parse heart rate data
      // Check the flag bit to see if the data format is uint8 or uint16
      bool isUint16Format = (data[0] & 0x01) == 1;

      // Extract the heart rate value (uint8 or uint16)
      int heartRate;
      if (isUint16Format && data.length >= 3) {
        // uint16 format (bytes 1-2)
        heartRate = (data[2] << 8) + data[1];
      } else if (data.length >= 2) {
        // uint8 format (byte 1)
        heartRate = data[1];
      } else {
        return; // Not enough data
      }

      // Store the value
      _lastHeartRate = heartRate;

      // Add to readings if we're tracking
      if (_state == TrackerState.active && _currentActivity != null) {
        final reading = SensorReading.fromHrm(
          activityId: _currentActivity!.id,
          timestamp: DateTime.now(),
          heartRate: heartRate,
        );

        _addSensorReading(reading);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing heart rate data: $e');
    }
  }

  // Stryd data handler
  void _onStrydDataReceived(List<int> data) {
    if (data.isEmpty) return;

    try {
      // Try to identify what type of data this is based on the pattern
      // Note: This is a simplified example - in reality you'd need to reverse engineer
      // the Stryd protocol or use their official SDK if available

      // For this example, we'll make some assumptions:
      // - If data starts with [0x10, ...] it's power data (made up for example)
      // - If data starts with [0x20, ...] it's cadence data (made up for example)
      // - If data starts with [0x30, ...] it's distance/pace data (made up for example)

      if (data[0] == 0x10 && data.length >= 3) {
        // Power data (watts)
        final power = (data[2] << 8) + data[1];
        _lastPower = power;
      } else if (data[0] == 0x20 && data.length >= 2) {
        // Cadence data (steps per minute)
        final cadence = data[1];
        _lastCadence = cadence;
      } else if (data[0] == 0x30 && data.length >= 5) {
        // Distance data (meters)
        final distance =
            ((data[4] << 24) + (data[3] << 16) + (data[2] << 8) + data[1]) /
                100.0;
        _lastDistance = distance;

        // Calculate pace if we have distance and time delta
        if (_lastTimerUpdate != null && _lastDistance != null) {
          final timeInSeconds =
              DateTime.now().difference(_lastTimerUpdate!).inSeconds;
          if (timeInSeconds > 0 && _lastDistance! > 0) {
            // Pace in seconds per kilometer = (time in seconds / distance in kilometers)
            _lastPace = (timeInSeconds / (_lastDistance! / 1000)).round();
          }
        }
      }

      // Add to readings if we're tracking
      if (_state == TrackerState.active && _currentActivity != null) {
        final reading = SensorReading.fromStryd(
          activityId: _currentActivity!.id,
          timestamp: DateTime.now(),
          power: _lastPower,
          cadence: _lastCadence,
          distanceMeters: _lastDistance,
          paceSecondsPerKm: _lastPace,
        );

        _addSensorReading(reading);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing Stryd data: $e');
    }
  }

  // Start location tracking
  void _startLocationTracking() {
    _positionStreamSubscription?.cancel();

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen(_onLocationUpdate);
  }

  // Stop location tracking
  void _stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  // Location update handler
  void _onLocationUpdate(Position position) {
    _lastGpsPosition = position;
    _isGpsConnected = true;

    if (_state != TrackerState.active || _currentActivity == null) return;

    try {
      // Calculate distance change if we have a previous position
      if (_lastGpsPosition != null) {
        final newLocation = LatLng(position.latitude, position.longitude);

        // Add the point to the route
        _currentActivity!.routePoints.add(newLocation);

        // Calculate elevation change
        if (_lastElevation != null) {
          final elevationChange = position.altitude - _lastElevation!;
          if (elevationChange > 0.5) {
            _elevationGainMeters += elevationChange;
          } else if (elevationChange < -0.5) {
            _elevationLossMeters += elevationChange.abs();
          }
        }
        _lastElevation = position.altitude;

        // If we're not getting distance from Stryd, calculate from GPS
        if (_lastDistance == null) {
          // We'll track our own distance from GPS
          final distance = Geolocator.distanceBetween(
            _lastGpsPosition!.latitude,
            _lastGpsPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          // Add to total (only if reasonable - helps avoid GPS jumps)
          if (distance < 20) {
            // Max 20m per reading as a sanity check
            _totalDistanceMeters += distance;
          }
        } else {
          // We are getting distance from Stryd, use that instead
          _totalDistanceMeters = _lastDistance!;
        }

        // If no pace from Stryd, calculate from GPS
        if (_lastPace == null && position.speed > 0) {
          // Convert m/s to sec/km
          _lastPace = (1000 / position.speed).round();
        }
      }

      // Add to readings
      final reading = SensorReading.fromGps(
        activityId: _currentActivity!.id,
        timestamp: DateTime.now(),
        location: LatLng(position.latitude, position.longitude),
        elevationMeters: position.altitude,
      );

      _addSensorReading(reading);

      // Update the activity with current values
      _updateCurrentActivity();

      notifyListeners();
    } catch (e) {
      debugPrint('Error processing location update: $e');
    }
  }

  // Start data collection timer to track metrics
  void _startDataCollection() {
    _dataCollectionTimer?.cancel();

    // Collect data every 1 second
    _dataCollectionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == TrackerState.active && _currentActivity != null) {
        // Update the current activity with latest metrics
        _updateCurrentActivity();

        // Let the UI know there's new data
        notifyListeners();
      }
    });
  }

  // Stop data collection timer
  void _stopDataCollection() {
    _dataCollectionTimer?.cancel();
    _dataCollectionTimer = null;
  }

  // Add a reading to the buffer and flush if needed
  void _addSensorReading(SensorReading reading) {
    _readingsBuffer.add(reading);

    // Flush the buffer if it's full
    if (_readingsBuffer.length >= _maxBufferSize) {
      _flushReadingsBuffer();
    }
  }

  // Flush readings buffer to the database
  Future<void> _flushReadingsBuffer() async {
    if (_readingsBuffer.isEmpty) return;

    try {
      // Copy the buffer
      final readings = List<SensorReading>.from(_readingsBuffer);
      _readingsBuffer.clear();

      // Save to database
      await _dbService.insertSensorReadingsBatch(readings);
    } catch (e) {
      debugPrint('Error flushing readings buffer: $e');
    }
  }

  // Update current activity with latest metrics
  void _updateCurrentActivity() {
    if (_currentActivity == null) return;

    // Calculate duration
    if (_lastTimerUpdate != null) {
      final timeDiff = DateTime.now().difference(_lastTimerUpdate!).inSeconds;
      if (_state == TrackerState.active) {
        _currentActivity!.durationSeconds += timeDiff;
      }
      _lastTimerUpdate = DateTime.now();
    } else {
      _lastTimerUpdate = DateTime.now();
    }

    // Update metrics
    _currentActivity!.distanceMeters = _totalDistanceMeters;
    _currentActivity!.elevationGainMeters = _elevationGainMeters;
    _currentActivity!.elevationLossMeters = _elevationLossMeters;

    // Set current heart rate, power, cadence, and pace as the activity's values
    // (we'll calculate averages at the end)
    _currentActivity!.averageHeartRate = _lastHeartRate;
    _currentActivity!.averagePower = _lastPower;
    _currentActivity!.averageCadence = _lastCadence;
    _currentActivity!.averagePaceSecondsPerKm = _lastPace;

    // Periodically save to database (every ~5 seconds)
    if (_currentActivity!.durationSeconds % 5 == 0) {
      _saveCurrentActivity();
    }
  }

  // Save current activity to database
  Future<void> _saveCurrentActivity() async {
    if (_currentActivity == null) return;

    try {
      await _dbService.updateActivity(_currentActivity!);
    } catch (e) {
      debugPrint('Error saving activity: $e');
    }
  }

  // Start timer for tracking activity duration
  void _startActivityTimer() {
    _activityTimer?.cancel();

    _lastTimerUpdate = DateTime.now();

    // Update duration every second
    _activityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == TrackerState.active && _currentActivity != null) {
        _updateCurrentActivity();
        notifyListeners();
      }
    });
  }

  // Stop activity timer
  void _stopActivityTimer() {
    _activityTimer?.cancel();
    _activityTimer = null;
    _lastTimerUpdate = null;
  }

  // PUBLIC METHODS

  // Prepare for a new activity
  Future<void> prepareActivity() async {
    _state = TrackerState.preparing;
    notifyListeners();

    try {
      // Keep the screen on
      await WakelockPlus.enable();

      // Connect to sensors
      await _connectToSensors();

      // Create a new activity
      _currentActivity = Activity(
        name: 'Run on ${DateTime.now().toString().substring(0, 16)}',
        startTime: DateTime.now(),
      );

      // Initialize tracking values
      _totalDistanceMeters = 0;
      _elevationGainMeters = 0;
      _elevationLossMeters = 0;
      _lastElevation = null;

      // Save to database
      await _dbService.insertActivity(_currentActivity!);

      _state = TrackerState.idle;
      notifyListeners();
    } catch (e) {
      _state = TrackerState.error;
      debugPrint('Error preparing activity: $e');
      notifyListeners();
    }
  }

  // Start activity tracking
  Future<void> startActivity() async {
    if (_currentActivity == null) {
      await prepareActivity();
    }

    _state = TrackerState.active;
    if (_currentActivity != null) {
      _currentActivity!.status = 'in_progress';
    } else {
      // Create a new activity if for some reason we don't have one
      _currentActivity = Activity(
        name: 'Run on ${DateTime.now().toString().substring(0, 16)}',
        startTime: DateTime.now(),
        status: 'in_progress',
      );
      await _dbService.insertActivity(_currentActivity!);
    }

    // Start timers
    _startActivityTimer();
    _startDataCollection();

    // Start location tracking
    _startLocationTracking();

    notifyListeners();

    // Save to database
    await _saveCurrentActivity();
  }

  // Pause activity tracking
  Future<void> pauseActivity() async {
    if (_state != TrackerState.active || _currentActivity == null) return;

    _state = TrackerState.paused;
    _currentActivity!.status = 'paused';

    // No need to stop timers, we'll just check state before updating

    notifyListeners();

    // Save to database
    await _saveCurrentActivity();
  }

  // Resume paused activity
  Future<void> resumeActivity() async {
    if (_state != TrackerState.paused || _currentActivity == null) return;

    _state = TrackerState.active;
    _currentActivity!.status = 'in_progress';

    // Reset timer update point
    _lastTimerUpdate = DateTime.now();

    notifyListeners();

    // Save to database
    await _saveCurrentActivity();
  }

  // End activity and save
  Future<Activity?> endActivity() async {
    if (_currentActivity == null) return null;

    // Flush any remaining readings
    await _flushReadingsBuffer();

    // Stop timers and tracking
    _stopActivityTimer();
    _stopDataCollection();
    _stopLocationTracking();

    // Update end time and status
    _currentActivity!.endTime = DateTime.now();
    _currentActivity!.status = 'completed';

    // Load all readings to calculate stats
    final readings =
        await _dbService.getActivitySensorReadings(_currentActivity!.id);
    _currentActivity!.sensorReadings = readings;

    // Calculate final averages and stats
    _currentActivity!.calculateAverages();

    // Save final activity
    await _dbService.updateActivity(_currentActivity!);

    // Allow screen to turn off again
    await WakelockPlus.disable();

    // Store a reference to completed activity before resetting
    final completedActivity = _currentActivity;

    // Reset state
    _state = TrackerState.idle;
    _currentActivity = null;
    _totalDistanceMeters = 0;
    _elevationGainMeters = 0;
    _elevationLossMeters = 0;

    notifyListeners();

    return completedActivity;
  }

  // Discard the current activity
  Future<void> discardActivity() async {
    if (_currentActivity == null) return;

    // Stop timers and tracking
    _stopActivityTimer();
    _stopDataCollection();
    _stopLocationTracking();

    final activityId = _currentActivity!.id;

    // Delete from database
    await _dbService.deleteActivity(activityId);

    // Allow screen to turn off again
    await WakelockPlus.disable();

    // Reset state
    _state = TrackerState.idle;
    _currentActivity = null;
    _totalDistanceMeters = 0;
    _elevationGainMeters = 0;
    _elevationLossMeters = 0;

    notifyListeners();
  }

  // Get a list of all activities
  Future<List<Activity>> getActivityHistory() async {
    return await _dbService.getAllActivities();
  }

  // Get sensor readings for an activity
  Future<List<SensorReading>> getActivityReadings(String activityId) async {
    return await _dbService.getActivitySensorReadings(activityId);
  }

  // Get route points for an activity
  Future<List<SensorReading>> getActivityRoute(String activityId) async {
    return await _dbService.getActivityRoutePoints(activityId);
  }

  // Format duration from seconds to HH:MM:SS
  static String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Format distance from meters to kilometers with 2 decimal places
  static String formatDistance(double meters) {
    final km = meters / 1000;
    return km.toStringAsFixed(2);
  }

  // Dispose
  @override
  void dispose() {
    _stopActivityTimer();
    _stopDataCollection();
    _stopLocationTracking();
    super.dispose();
  }
}
