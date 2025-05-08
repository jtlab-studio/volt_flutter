import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

import 'bluetooth_models.dart';

/// Service class to handle Bluetooth operations
class CustomBluetoothService {
  // Cached device names and states
  final Map<String, String> _deviceCachedNames = {};
  final Map<String, DeviceConnectionState> _deviceConnectionStates = {};

  // Maintain references to active subscriptions
  final Map<String, StreamSubscription> _connectionStateSubscriptions = {};
  final Map<String, Completer<void>> _connectionCompleters = {};

  // Device-specific connection policies with optimized values
  final Map<String, Map<String, dynamic>> _deviceConnectionPolicies = {
    'HRMPro': {
      'timeout': 6, // Reduced for speed
      'mtu': 247, // Increased for better throughput
      'mtuTimeout': 1,
      'retryDelay': 1,
      'postConnectDelay': 200,
      'connectionAttempts': 2,
      'skipSecondMtu': true,
      'specialHandling': true,
      'fastMode': true,
      'connectionPriority': BleConnectionPriority.high
    },
    'Stryd': {
      'timeout': 5, // Optimized for Stryd
      'mtu': 185, // Optimized for footpod
      'mtuTimeout': 1,
      'retryDelay': 1,
      'postConnectDelay': 200,
      'connectionAttempts': 2,
      'skipSecondMtu': true,
      'specialHandling': true,
      'fastMode': true,
      'connectionPriority': BleConnectionPriority.high
    },
    'default': {
      'timeout': 5,
      'mtu': 185,
      'mtuTimeout': 1,
      'retryDelay': 1,
      'postConnectDelay': 200,
      'connectionAttempts': 2,
      'skipSecondMtu': false,
      'specialHandling': false,
      'fastMode': false,
      'connectionPriority': BleConnectionPriority.balanced
    }
  };

  // Callbacks for UI updates
  Function(BluetoothDevice, DeviceConnectionState)? onDeviceStateChanged;
  Function(List<BluetoothDevice>)? onConnectedDevicesChanged;
  Function(String)? onDeviceConnected;

  // Current scan subscription
  StreamSubscription? _scanSubscription;

  // Constructor
  CustomBluetoothService() {
    _initBluetooth();
  }

  // Initialize Bluetooth
  Future<void> _initBluetooth() async {
    try {
      // Set debug logging for development
      try {
        await FlutterBluePlus.setLogLevel(LogLevel.debug, color: true);
      } catch (e) {
        debugPrint('Could not set log level: $e');
      }
    } catch (e) {
      debugPrint('Error initializing Bluetooth: $e');
    }
  }

  // Check Bluetooth adapter state
  Future<bool> isBluetoothOn() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      debugPrint('Error checking Bluetooth state: $e');
      return false;
    }
  }

  // Get currently connected devices
  List<BluetoothDevice> getConnectedDevices() {
    return FlutterBluePlus.connectedDevices;
  }

  // Update device connection state
  void updateDeviceConnectionState(
      BluetoothDevice device, DeviceConnectionState state) {
    _deviceConnectionStates[device.remoteId.str] = state;
    if (onDeviceStateChanged != null) {
      onDeviceStateChanged!(device, state);
    }
  }

  // Get connection state for a device
  DeviceConnectionState getDeviceConnectionState(BluetoothDevice device) {
    return _deviceConnectionStates[device.remoteId.str] ??
        DeviceConnectionState.disconnected;
  }

  // Get device-specific connection policy
  Map<String, dynamic> getDevicePolicy(BluetoothDevice device) {
    final deviceId = device.remoteId.str;
    final deviceName = device.platformName.toLowerCase();

    // HRMPro device needs special handling
    if (deviceName.contains('hrm') ||
        deviceId.contains('22:D8') ||
        deviceName.contains('garmin')) {
      return _deviceConnectionPolicies['HRMPro']!;
    }

    // Stryd device needs special handling
    if (deviceName.contains('stryd') ||
        deviceId.contains('30:02') ||
        deviceName.contains('footpod') ||
        deviceName.contains('pod')) {
      return _deviceConnectionPolicies['Stryd']!;
    }

    // Check for other specific device types
    for (final key in _deviceConnectionPolicies.keys) {
      if (deviceName.contains(key.toLowerCase()) && key != 'default') {
        return _deviceConnectionPolicies[key]!;
      }
    }

    return _deviceConnectionPolicies['default']!;
  }

  // Get the best available device name for display
  String getDeviceDisplayName(BluetoothDevice device) {
    // First try to use the platform name if available
    if (device.platformName.isNotEmpty && device.platformName != 'null') {
      return device.platformName;
    }

    // Then try our cached names
    if (_deviceCachedNames.containsKey(device.remoteId.str)) {
      return _deviceCachedNames[device.remoteId.str]!;
    }

    // Try to identify common sensors by MAC address pattern
    if (device.remoteId.str.contains('22:D8')) {
      return 'HRMPro+';
    } else if (device.remoteId.str.contains('30:02')) {
      return 'StrydX';
    } else if (device.remoteId.str.toLowerCase().contains('hrm')) {
      return 'Heart Rate Monitor';
    } else if (device.remoteId.str.toLowerCase().contains('stryd') ||
        device.remoteId.str.toLowerCase().contains('pod')) {
      return 'Foot Pod';
    }

    // Fallback to a generic name with ID
    return 'Device-${device.remoteId.str.substring(device.remoteId.str.length - 8)}';
  }

  // Setup connection state listener for a device
  void setupConnectionListener(BluetoothDevice device) {
    // Cancel existing subscription if any
    _connectionStateSubscriptions[device.remoteId.str]?.cancel();

    // Create new subscription with faster state updates
    _connectionStateSubscriptions[device.remoteId.str] =
        device.connectionState.listen((BluetoothConnectionState state) {
      if (state == BluetoothConnectionState.connected) {
        updateDeviceConnectionState(device, DeviceConnectionState.connected);

        // If the device has a name, update our cached name
        if (device.platformName.isNotEmpty && device.platformName != 'null') {
          _deviceCachedNames[device.remoteId.str] = device.platformName;
        }

        // Notify connected devices changed
        if (onConnectedDevicesChanged != null) {
          onConnectedDevicesChanged!(getConnectedDevices());
        }

        // Notify connected device
        if (onDeviceConnected != null) {
          onDeviceConnected!(getDeviceDisplayName(device));
        }
      } else if (state == BluetoothConnectionState.disconnected) {
        final displayName = getDeviceDisplayName(device);
        debugPrint('Device disconnected: $displayName');

        updateDeviceConnectionState(device, DeviceConnectionState.disconnected);

        // Notify connected devices changed
        if (onConnectedDevicesChanged != null) {
          onConnectedDevicesChanged!(getConnectedDevices());
        }

        // Complete any pending connection completer for this device
        if (_connectionCompleters.containsKey(device.remoteId.str)) {
          if (!_connectionCompleters[device.remoteId.str]!.isCompleted) {
            _connectionCompleters[device.remoteId.str]!.complete();
          }
          _connectionCompleters.remove(device.remoteId.str);
        }
      }
    });
  }

  // Special method for handling MTU on problematic devices
  Future<void> handleMtuForProblematicDevice(BluetoothDevice device) async {
    try {
      // Fast MTU configuration with timeout
      await device.requestMtu(247).timeout(
        const Duration(milliseconds: 600),
        onTimeout: () {
          debugPrint(
              'MTU request timed out for ${getDeviceDisplayName(device)}, continuing anyway');
          return 23;
        },
      );

      debugPrint('Fast MTU handling for ${getDeviceDisplayName(device)}');
    } catch (e) {
      debugPrint('Error in MTU handling for problematic device: $e');
      // Continue without delay
    }
  }

  // Fast connection method for problematic devices
  Future<bool> fastConnectProblematicDevice(BluetoothDevice device) async {
    try {
      // Get display name
      final displayName = getDeviceDisplayName(device);
      debugPrint('Fast connecting to $displayName');

      // Stop all scanning first
      await FlutterBluePlus.stopScan();

      // Ensure any existing connections are terminated
      try {
        await device.disconnect().timeout(
          const Duration(milliseconds: 500),
          onTimeout: () {
            debugPrint('Pre-connection disconnect timeout, continuing anyway');
          },
        );
      } catch (e) {
        // Ignore disconnect errors
        debugPrint('Error during pre-connection disconnect: $e');
      }

      // Small delay after disconnect
      await Future.delayed(const Duration(milliseconds: 100));

      // Update state to connecting
      updateDeviceConnectionState(device, DeviceConnectionState.connecting);

      // Streamlined connection attempt with timeout
      await device
          .connect(
        timeout: const Duration(seconds: 6),
        autoConnect: false, // Direct connection is faster
      )
          .timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      // Setup connection listener
      setupConnectionListener(device);

      // Try to request high connection priority
      try {
        await device
            .requestCustomConnectionPriority(BleConnectionPriority.high)
            .timeout(
          const Duration(milliseconds: 300),
          onTimeout: () {
            debugPrint('Connection priority request timed out');
          },
        );
      } catch (e) {
        debugPrint('Error setting connection priority: $e');
      }

      // Brief delay before MTU
      await Future.delayed(const Duration(milliseconds: 100));

      // Update state
      updateDeviceConnectionState(device, DeviceConnectionState.authenticating);

      // Fast MTU handling - use higher MTU for better throughput
      try {
        await device.requestMtu(247).timeout(
          const Duration(milliseconds: 800),
          onTimeout: () {
            debugPrint('MTU request timed out, continuing');
            return 23; // Fallback to default
          },
        );
      } catch (e) {
        debugPrint('Error setting MTU: $e');
        // Continue anyway
      }

      // Mark as connected
      updateDeviceConnectionState(device, DeviceConnectionState.connected);

      return true;
    } catch (e) {
      debugPrint('Fast connection failed: $e');
      updateDeviceConnectionState(device, DeviceConnectionState.failed);
      return false;
    }
  }

  // Standard method to connect to a device with retry
  Future<bool> connectToDeviceWithRetry(BluetoothDevice device,
      {int? maxRetries}) async {
    // Stop scanning to avoid interference with connection
    await FlutterBluePlus.stopScan();

    // Get device-specific policy
    final policy = getDevicePolicy(device);

    // Use provided maxRetries or get from policy
    final attempts = maxRetries ?? policy['connectionAttempts'];
    int currentAttempt = 0;

    // Create a completer to track this connection attempt
    final completer = Completer<void>();
    _connectionCompleters[device.remoteId.str] = completer;

    // Check if this is a problematic device that needs special handling
    final bool isProblematicDevice =
        device.platformName.toLowerCase().contains('hrm') ||
            device.remoteId.str.contains('22:D8') ||
            device.platformName.toLowerCase().contains('stryd') ||
            device.remoteId.str.contains('30:02') ||
            policy['specialHandling'] == true;

    while (currentAttempt < attempts) {
      currentAttempt++;
      try {
        // Capture actual device name (may be empty at this point)
        String displayName = getDeviceDisplayName(device);

        debugPrint(
            'Connecting to $displayName (Attempt $currentAttempt/$attempts)');

        // Check if Bluetooth is on
        if (!await isBluetoothOn()) {
          debugPrint('Bluetooth is off, cannot connect');
          return false;
        }

        // Attempt to disconnect first if this is a retry
        if (currentAttempt > 1) {
          try {
            await device.disconnect().timeout(
              const Duration(seconds: 1),
              onTimeout: () {
                debugPrint('Disconnect timeout, continuing anyway');
              },
            );
            // Shorter delay after disconnection
            await Future.delayed(
                Duration(milliseconds: policy['postConnectDelay'] ~/ 2));
          } catch (e) {
            // Ignore disconnect errors
            debugPrint('Disconnect before retry error: $e');
          }
        }

        // Update state to connecting
        updateDeviceConnectionState(device, DeviceConnectionState.connecting);

        // Connect with device-specific timeout
        final timeout = Duration(seconds: policy['timeout']);

        // More reliable connection method with special handling for problematic devices
        try {
          // Special handling for HRMPro, Stryd or similar devices
          if (isProblematicDevice) {
            // Stop any scans first
            await FlutterBluePlus.stopScan();

            // Wait a brief moment after stopping scan
            await Future.delayed(const Duration(milliseconds: 50));

            // Connect with optimized parameters for problematic devices
            await device
                .connect(
              timeout: timeout,
              autoConnect: false, // Important: Use direct connection
            )
                .timeout(
              timeout,
              onTimeout: () {
                throw Exception('Connection timeout for problematic device');
              },
            );
          } else {
            // Standard connection for normal devices
            await device
                .connect(
              timeout: timeout,
              autoConnect: false,
            )
                .timeout(
              timeout,
              onTimeout: () {
                throw Exception('Connection timeout');
              },
            );
          }
        } catch (connectError) {
          debugPrint('Initial connection error: $connectError');

          if (isProblematicDevice && currentAttempt < attempts) {
            // For problematic devices, try with different strategy
            try {
              debugPrint('Retrying problematic device with special handling');

              // Force disconnect with timeout
              try {
                await device.disconnect().timeout(const Duration(seconds: 1),
                    onTimeout: () {
                  debugPrint(
                      'Disconnect timeout on special retry, continuing anyway');
                });
              } catch (_) {}

              // Brief delay
              await Future.delayed(const Duration(milliseconds: 500));

              // Retry connection with timeout
              await device
                  .connect(
                timeout: timeout,
                autoConnect: false,
              )
                  .timeout(
                timeout,
                onTimeout: () {
                  throw Exception('Connection timeout on special retry');
                },
              );
            } catch (secondTryError) {
              debugPrint('Special retry also failed: $secondTryError');
              rethrow;
            }
          } else {
            rethrow;
          }
        }

        // Setup connection state listener
        setupConnectionListener(device);

        // Try to request high connection priority for faster data exchange
        try {
          await device
              .requestCustomConnectionPriority(policy['connectionPriority'])
              .timeout(
            const Duration(milliseconds: 500),
            onTimeout: () {
              debugPrint(
                  'Connection priority request timed out, continuing anyway');
            },
          );
        } catch (e) {
          debugPrint('Error setting connection priority: $e');
          // Continue anyway
        }

        // Connection successful - add device-specific delay before continuing
        await Future.delayed(
            Duration(milliseconds: policy['postConnectDelay']));

        // Update state to authenticating during MTU negotiation
        updateDeviceConnectionState(
            device, DeviceConnectionState.authenticating);

        // Handle MTU differently for problematic devices
        if (isProblematicDevice) {
          await handleMtuForProblematicDevice(device);
        } else {
          // Set MTU with device-specific settings and shorter timeout
          try {
            final mtuTimeout = Duration(seconds: policy['mtuTimeout']);
            final mtu = await device.requestMtu(policy['mtu']).timeout(
              mtuTimeout,
              onTimeout: () {
                debugPrint(
                    'MTU request timeout, but connection is established');
                return policy['mtu']; // Use default from policy
              },
            );
            debugPrint('MTU set to $mtu for device ${device.platformName}');

            // Some devices need a second MTU request to stabilize
            if (policy['skipSecondMtu'] != true) {
              try {
                // Add small delay between MTU requests
                await Future.delayed(const Duration(milliseconds: 200));

                // Second MTU request (only for devices that can handle it)
                await device.requestMtu(policy['mtu']).timeout(
                  const Duration(seconds: 1),
                  onTimeout: () {
                    debugPrint('Second MTU request timeout, ignoring');
                    return policy['mtu'];
                  },
                );
              } catch (secondMtuError) {
                // Ignore errors from second MTU request
                debugPrint('Second MTU request error: $secondMtuError');
              }
            }
          } catch (mtuError) {
            debugPrint(
                'MTU request failed for ${device.platformName}: $mtuError');
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }

        // Update state to connected after successful MTU negotiation
        updateDeviceConnectionState(device, DeviceConnectionState.connected);

        return true; // Connection succeeded
      } catch (e) {
        debugPrint(
            'Connection attempt $currentAttempt failed for ${device.platformName}: $e');

        if (currentAttempt >= attempts) {
          debugPrint('Max retries reached for ${device.platformName}');
          updateDeviceConnectionState(device, DeviceConnectionState.failed);
          return false;
        }

        // Device-specific wait before retrying
        final baseDelay = policy['retryDelay'];
        final adjustedDelay = isProblematicDevice ? baseDelay : baseDelay;
        await Future.delayed(Duration(seconds: adjustedDelay));
      }
    }

    return false;
  }

  // Fast disconnect for a device
  Future<void> fastDisconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {
          debugPrint('Fast disconnect timeout for ${device.platformName}');
          return;
        },
      );

      updateDeviceConnectionState(device, DeviceConnectionState.disconnected);

      // Notify connected devices changed
      if (onConnectedDevicesChanged != null) {
        onConnectedDevicesChanged!(getConnectedDevices());
      }
    } catch (e) {
      debugPrint('Error in fast disconnect: $e');
      // Force update state even if disconnect fails
      updateDeviceConnectionState(device, DeviceConnectionState.disconnected);
    }
  }

  // Fast disconnect all devices
  Future<void> fastDisconnectAllDevices() async {
    final connectedDevices = getConnectedDevices();
    if (connectedDevices.isEmpty) return;

    // Disconnect all devices in parallel for speed
    List<Future<void>> disconnectFutures = [];
    for (final device in connectedDevices) {
      disconnectFutures.add(fastDisconnectDevice(device));
    }

    // Wait for all disconnections to complete with a timeout
    await Future.wait(disconnectFutures).timeout(const Duration(seconds: 1),
        onTimeout: () {
      debugPrint('Disconnect timeout, continuing anyway');
      return [];
    });
  }

  // Start scanning for devices
  Future<void> startScan(
      {required Function(List<ScanResult>) onResultsUpdated}) async {
    try {
      // Stop any existing scan
      await FlutterBluePlus.stopScan();

      // Cancel existing subscription if any
      _scanSubscription?.cancel();

      // Listen for scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen(onResultsUpdated);

      // Start scanning with optimized parameters
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      debugPrint('Error scanning: $e');
    }
  }

  // Helper method to connect a single device with optimized path
  Future<bool> connectSingleDevice(BluetoothDevice device) async {
    // Update UI state
    updateDeviceConnectionState(device, DeviceConnectionState.connecting);

    // Connect with retry mechanism - but faster for problematic devices
    final policy = getDevicePolicy(device);
    if (policy['fastMode'] == true) {
      // Use streamlined connection for problematic devices
      return await fastConnectProblematicDevice(device);
    } else {
      // Use standard connection path for normal devices
      return await connectToDeviceWithRetry(device);
    }
  }

  // Load saved devices from SharedPreferences
  Future<List<BluetoothDevice>> loadSavedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDevicesJson = prefs.getStringList('saved_devices') ?? [];

      final devices = <BluetoothDevice>[];
      _deviceCachedNames.clear();

      for (final deviceJson in savedDevicesJson) {
        try {
          final Map<String, dynamic> data = jsonDecode(deviceJson);

          // Create a BluetoothDevice from the saved data
          final deviceId = data['remoteId'];
          final cachedName = data['cachedName'] ??
              data['platformName'] ??
              'Device-${deviceId.substring(0, 8)}';

          // Store the cached name for display purposes
          _deviceCachedNames[deviceId] = cachedName;

          // Use the fromId constructor (doesn't take name or type)
          final device = BluetoothDevice.fromId(deviceId);
          devices.add(device);

          debugPrint('Loaded saved device: $cachedName ($deviceId)');
        } catch (e) {
          debugPrint('Error parsing device: $e');
        }
      }

      return devices;
    } catch (e) {
      debugPrint('Error loading saved devices: $e');
      return [];
    }
  }

  // Save devices to SharedPreferences
  Future<void> saveDevicesToPrefs(List<BluetoothDevice> devices) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedDevicesJson = devices.map((device) {
        // Generate a display name if platformName is empty
        String displayName = device.platformName;

        // If platformName is empty, try to infer a better name
        if (displayName.isEmpty || displayName == 'null') {
          if (device.remoteId.str.contains('22:D8')) {
            displayName = 'HRMPro+';
          } else if (device.remoteId.str.contains('30:02')) {
            displayName = 'StrydX';
          } else {
            // Fallback to a generic name with partial MAC
            displayName = 'Device-${device.remoteId.str.substring(0, 8)}';
          }
        }

        return jsonEncode({
          'remoteId': device.remoteId.str,
          'platformName': displayName,
          'cachedName': displayName, // Store cached name for display
          'lastConnected': DateTime.now().millisecondsSinceEpoch,
        });
      }).toList();

      await prefs.setStringList('saved_devices', savedDevicesJson);
      debugPrint('Saved ${savedDevicesJson.length} devices to preferences');
    } catch (e) {
      debugPrint('Error saving devices to preferences: $e');
    }
  }

  // Connect to all saved devices in optimal order
  Future<int> autoConnectToSavedDevices(
      List<BluetoothDevice> savedDevices) async {
    if (savedDevices.isEmpty) return 0;

    // Make sure Bluetooth is on
    if (!await isBluetoothOn()) {
      debugPrint('Bluetooth is off, cannot connect');
      return 0;
    }

    // Stop all scans
    await FlutterBluePlus.stopScan();

    // Disconnect all devices first
    await fastDisconnectAllDevices();

    // Shorter delay after disconnection
    await Future.delayed(const Duration(milliseconds: 500));

    // Track connection results
    int successCount = 0;

    // Prioritize and categorize devices for optimal connection order
    final hrmDevices = savedDevices
        .where((d) =>
            d.platformName.toLowerCase().contains('hrm') ||
            d.remoteId.str.contains('22:D8'))
        .toList();

    final footpodDevices = savedDevices
        .where((d) =>
            d.platformName.toLowerCase().contains('stryd') ||
            d.platformName.toLowerCase().contains('pod') ||
            d.remoteId.str.contains('30:02'))
        .toList();

    final standardDevices = savedDevices
        .where((d) => !hrmDevices.contains(d) && !footpodDevices.contains(d))
        .toList();

    // First connect to HRM devices (highest priority)
    for (final device in hrmDevices) {
      // Skip already connected devices
      if (getConnectedDevices().any((d) => d.remoteId == device.remoteId)) {
        successCount++;
        continue;
      }

      debugPrint(
          'Connecting to primary HRM device: ${getDeviceDisplayName(device)}');

      final success = await fastConnectProblematicDevice(device);
      if (success) {
        successCount++;
      }

      // Small delay between connections
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Then connect to footpod devices (second priority)
    for (final device in footpodDevices) {
      // Skip already connected devices
      if (getConnectedDevices().any((d) => d.remoteId == device.remoteId)) {
        successCount++;
        continue;
      }

      debugPrint(
          'Connecting to footpod device: ${getDeviceDisplayName(device)}');

      final success = await fastConnectProblematicDevice(device);
      if (success) {
        successCount++;
      }

      // Small delay between connections
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Finally connect to standard devices
    for (final device in standardDevices) {
      // Skip already connected devices
      if (getConnectedDevices().any((d) => d.remoteId == device.remoteId)) {
        successCount++;
        continue;
      }

      final success = await connectSingleDevice(device);
      if (success) {
        successCount++;
      }

      // Add delay between connections
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return successCount;
  }

  // Dispose the service (cancel subscriptions)
  void dispose() {
    _scanSubscription?.cancel();

    for (final subscription in _connectionStateSubscriptions.values) {
      subscription.cancel();
    }
    _connectionStateSubscriptions.clear();

    for (final completer in _connectionCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _connectionCompleters.clear();
  }
}
