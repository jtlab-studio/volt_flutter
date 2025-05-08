import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Add this import for StreamSubscription
import 'dart:convert';

// Define connection states for better UI feedback
enum DeviceConnectionState {
  disconnected,
  connecting,
  authenticating, // New state for MTU negotiation phase
  connected,
  failed
}

class SensorsScreen extends ConsumerStatefulWidget {
  const SensorsScreen({super.key});

  @override
  ConsumerState<SensorsScreen> createState() => _SensorsScreenState();
}

// Extended device info class to store additional data
class ExtendedDeviceInfo {
  final BluetoothDevice device;
  final String cachedName;
  final int lastConnected;

  ExtendedDeviceInfo(
      {required this.device,
      required this.cachedName,
      required this.lastConnected});
}

class _SensorsScreenState extends ConsumerState<SensorsScreen> {
  // Bluetooth state
  bool _isScanning = false;
  bool _permissionGranted = false;
  List<BluetoothDevice> _connectedDevices = [];
  List<ScanResult> _scanResults = [];
  List<BluetoothDevice> _savedDevices = [];

  // Track connection states for each device
  final Map<String, DeviceConnectionState> _deviceConnectionStates = {};

  // Store subscriptions to properly cancel them
  final Map<String, StreamSubscription> _connectionStateSubscriptions = {};
  final Map<String, Completer<void>> _connectionCompleters = {};

  // Flag to prevent multiple simultaneous connections
  bool _isConnecting = false;

  // Map to hold extended device info for better name display
  final Map<String, String> _deviceCachedNames = {};

  // Device-specific connection policies with even more tolerance for HRMPro
  final Map<String, Map<String, dynamic>> _deviceConnectionPolicies = {
    'HRMPro': {
      'timeout': 25, // Even longer timeout
      'mtu': 23, // Fixed at 23 based on logs
      'mtuTimeout': 1, // Very short MTU timeout to avoid blocking
      'retryDelay': 5, // Even longer delay between retries
      'postConnectDelay': 2000, // Longer delay after connection
      'connectionAttempts': 2, // Fewer attempts but longer timeouts
      'skipSecondMtu': true, // Skip second MTU request for this device
      'specialHandling': true, // Flag for special handling
    },
    'default': {
      'timeout': 10,
      'mtu': 132,
      'mtuTimeout': 4,
      'retryDelay': 2,
      'postConnectDelay': 800,
      'connectionAttempts': 2,
      'skipSecondMtu': false,
      'specialHandling': false,
    }
  };

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadSavedDevices().then((_) {
      // Initialize connection states for saved devices
      for (final device in _savedDevices) {
        _deviceConnectionStates[device.remoteId.str] =
            DeviceConnectionState.disconnected;
      }

      _initBluetooth();
      // Add a slight delay before auto-connecting
      Future.delayed(const Duration(seconds: 1), () {
        if (_permissionGranted) {
          _autoConnectToSavedDevices();
        }
      });
    });
  }

  @override
  void deactivate() {
    // This is called when the screen is about to be removed from the widget tree
    // Disconnect all devices here
    debugPrint('SensorsScreen is being deactivated, disconnecting all devices');
    _disconnectAllDevices();
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we're mounted and just became active
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      // Small delay to avoid race conditions
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted &&
            _permissionGranted &&
            _savedDevices.isNotEmpty &&
            _connectedDevices.isEmpty) {
          debugPrint('SensorsScreen became current route, auto-connecting');
          _autoConnectToSavedDevices();
        }
      });
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions when the widget is disposed
    for (final subscription in _connectionStateSubscriptions.values) {
      subscription.cancel();
    }
    _connectionStateSubscriptions.clear();

    // Complete any pending completers to avoid memory leaks
    for (final completer in _connectionCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _connectionCompleters.clear();

    super.dispose();
  }

  // Check for Bluetooth and location permissions
  Future<void> _checkPermissions() async {
    // Request necessary permissions
    var bluetoothStatus = await Permission.bluetooth.status;
    var locationStatus = await Permission.location.status;
    var bluetoothConnectStatus = await Permission.bluetoothConnect.status;
    var bluetoothScanStatus = await Permission.bluetoothScan.status;

    if (!bluetoothStatus.isGranted) {
      await Permission.bluetooth.request();
    }

    if (!locationStatus.isGranted) {
      await Permission.location.request();
    }

    if (!bluetoothConnectStatus.isGranted) {
      await Permission.bluetoothConnect.request();
    }

    if (!bluetoothScanStatus.isGranted) {
      await Permission.bluetoothScan.request();
    }

    // Check if permissions are granted
    bluetoothStatus = await Permission.bluetooth.status;
    locationStatus = await Permission.location.status;
    bluetoothConnectStatus = await Permission.bluetoothConnect.status;
    bluetoothScanStatus = await Permission.bluetoothScan.status;

    if (mounted) {
      setState(() {
        _permissionGranted = bluetoothStatus.isGranted &&
            locationStatus.isGranted &&
            bluetoothConnectStatus.isGranted &&
            bluetoothScanStatus.isGranted;
      });
    }
  }

  // Helper method to check Bluetooth adapter state
  Future<bool> _isBluetoothOn() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      debugPrint('Error checking Bluetooth state: $e');
      return false;
    }
  }

  // Initialize Bluetooth
  Future<void> _initBluetooth() async {
    // Get connected devices
    try {
      if (_permissionGranted) {
        List<BluetoothDevice> connectedDevices =
            FlutterBluePlus.connectedDevices;
        if (mounted) {
          setState(() {
            _connectedDevices = connectedDevices;
            // Update connection states for connected devices
            for (final device in connectedDevices) {
              _deviceConnectionStates[device.remoteId.str] =
                  DeviceConnectionState.connected;
              _setupConnectionListener(device);
            }
          });
        }
      }
    } catch (e) {
      _logError('Error getting connected devices: $e');
    }
  }

  // Helper method for logging errors
  void _logError(String message) {
    // In production, this would use a proper logging framework
    debugPrint(message);
  }

  // Update device connection state
  void _updateDeviceConnectionState(
      BluetoothDevice device, DeviceConnectionState state) {
    if (mounted) {
      setState(() {
        _deviceConnectionStates[device.remoteId.str] = state;
      });
    }
  }

  // Get dynamic label for Connect button based on connection state
  String _getConnectionButtonLabel() {
    if (_isConnecting) {
      return 'Connecting...';
    } else if (_connectedDevices.length == _savedDevices.length &&
        _savedDevices.isNotEmpty &&
        _connectedDevices.isNotEmpty) {
      return 'All Connected';
    } else {
      return 'Connect All Saved';
    }
  }

  // Get device-specific connection policy
  Map<String, dynamic> _getDevicePolicy(BluetoothDevice device) {
    // HRMPro device needs special handling
    if (device.platformName.toLowerCase().contains('hrm') ||
        device.remoteId.str.contains('22:D8')) {
      return _deviceConnectionPolicies['HRMPro']!;
    }

    for (final key in _deviceConnectionPolicies.keys) {
      if (device.platformName.contains(key) && key != 'default') {
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

    // Try to identify common sensors by MAC address pattern more specifically
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

  // Special method for HRMPro+ MTU handling
  Future<void> _handleMtuForProblematicDevice(BluetoothDevice device) async {
    try {
      // Only send a single MTU request at the specific value and ignore results
      await device.requestMtu(23).timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          debugPrint(
              'MTU request timed out for problematic device, continuing anyway');
          return 23;
        },
      );

      // No second request, just add a brief delay
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('Completed minimal MTU handling for ${device.platformName}');
    } catch (e) {
      debugPrint('Error in MTU handling for problematic device: $e');
      // Just continue anyway
    }
  }

  // Setup connection state listener for a device with enhanced state tracking
  void _setupConnectionListener(BluetoothDevice device) {
    // Cancel existing subscription if any
    _connectionStateSubscriptions[device.remoteId.str]?.cancel();

    // Create new subscription
    _connectionStateSubscriptions[device.remoteId.str] =
        device.connectionState.listen((BluetoothConnectionState state) {
      if (state == BluetoothConnectionState.connected) {
        // Add this block to update UI when actually connected
        if (mounted) {
          setState(() {
            if (!_connectedDevices.contains(device)) {
              _connectedDevices.add(device);
            }
            _deviceConnectionStates[device.remoteId.str] =
                DeviceConnectionState.connected;

            // If the device has a name, update our cached name
            if (device.platformName.isNotEmpty &&
                device.platformName != 'null') {
              _deviceCachedNames[device.remoteId.str] = device.platformName;
            }
          });

          // After connecting, show a brief success indicator
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${getDeviceDisplayName(device)}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (state == BluetoothConnectionState.disconnected) {
        final displayName = getDeviceDisplayName(device);
        debugPrint('Device disconnected: $displayName');

        if (mounted) {
          setState(() {
            _connectedDevices.removeWhere((d) => d.remoteId == device.remoteId);
            _deviceConnectionStates[device.remoteId.str] =
                DeviceConnectionState.disconnected;
          });

          // Quietly notify of disconnection
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$displayName disconnected'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 1),
            ),
          );
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

  // Load saved devices from SharedPreferences with improved name handling
  Future<void> _loadSavedDevices() async {
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

          // Use the fromId constructor properly (it doesn't take name or type)
          final device = BluetoothDevice.fromId(deviceId);

          devices.add(device);

          debugPrint('Loaded saved device: $cachedName ($deviceId)');
        } catch (e) {
          debugPrint('Error parsing device: $e');
        }
      }

      if (mounted) {
        setState(() {
          _savedDevices = devices;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved devices: $e');
    }
  }

  // Save the list of devices to SharedPreferences with improved name handling
  Future<void> _saveSavedDevicesListToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedDevicesJson = _savedDevices.map((device) {
        // Generate a display name if platformName is empty
        String displayName = device.platformName;

        // If platformName is empty, try to infer a better name based on device remoteId
        if (displayName.isEmpty || displayName == 'null') {
          // Check if it might be an HRM device based on MAC address
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
          'cachedName':
              displayName, // Store a cached name for display even if device name is empty
          'lastConnected': DateTime.now().millisecondsSinceEpoch,
        });
      }).toList();

      await prefs.setStringList('saved_devices', savedDevicesJson);

      debugPrint('Saved ${savedDevicesJson.length} devices to preferences');
    } catch (e) {
      debugPrint('Error saving devices to preferences: $e');
    }
  }

  // Enhanced helper method to connect to a device with improved error handling and device-specific policies
  Future<bool> _connectToDeviceWithRetry(BluetoothDevice device,
      {int? maxRetries}) async {
    // Get device-specific policy
    final policy = _getDevicePolicy(device);

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
            policy['specialHandling'] == true;

    while (currentAttempt < attempts) {
      currentAttempt++;
      try {
        // Capture actual device name (may be empty at this point)
        String displayName = getDeviceDisplayName(device);

        debugPrint(
            'Connecting to $displayName (Attempt $currentAttempt/$attempts)');

        // Check if Bluetooth is on
        if (!await _isBluetoothOn()) {
          debugPrint('Bluetooth is off, cannot connect');
          return false;
        }

        // Attempt to disconnect first if this is a retry
        if (currentAttempt > 1) {
          try {
            await device.disconnect().timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                debugPrint('Disconnect timeout, continuing anyway');
              },
            );
            // Longer delay after disconnection
            await Future.delayed(
                Duration(milliseconds: policy['postConnectDelay']));
          } catch (e) {
            // Ignore disconnect errors
            debugPrint('Disconnect before retry error: $e');
          }
        }

        // Update state to connecting
        _updateDeviceConnectionState(device, DeviceConnectionState.connecting);

        // Connect with device-specific timeout
        final timeout = Duration(seconds: policy['timeout']);

        // More reliable connection method with special handling for problematic devices
        try {
          // Special handling for HRMPro or similar devices
          if (isProblematicDevice) {
            // Use longer timeout for problematic devices
            await device
                .connect(
              timeout: Duration(seconds: policy['timeout'] + 5),
              autoConnect: false,
            )
                .timeout(
              Duration(seconds: policy['timeout'] + 5),
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
            // For problematic devices, try with much longer timeouts and different strategy
            try {
              debugPrint('Retrying problematic device with special handling');

              // Force disconnect with longer timeout
              try {
                await device.disconnect().timeout(const Duration(seconds: 3),
                    onTimeout: () {
                  debugPrint(
                      'Disconnect timeout on special retry, continuing anyway');
                });
              } catch (_) {}

              // Much longer delay
              await Future.delayed(const Duration(seconds: 3));

              // Retry connection with longer timeout
              await device
                  .connect(
                timeout: Duration(seconds: policy['timeout'] + 10),
                autoConnect: false,
              )
                  .timeout(
                Duration(seconds: policy['timeout'] + 10),
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
        _setupConnectionListener(device);

        // Connection successful - add device-specific delay before continuing
        await Future.delayed(
            Duration(milliseconds: policy['postConnectDelay']));

        // Update state to authenticating during MTU negotiation
        _updateDeviceConnectionState(
            device, DeviceConnectionState.authenticating);

        // Handle MTU differently for problematic devices
        if (isProblematicDevice) {
          await _handleMtuForProblematicDevice(device);
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
                await Future.delayed(const Duration(milliseconds: 300));

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
            // Log MTU errors but don't fail the connection
            debugPrint(
                'MTU request failed for ${device.platformName}: $mtuError');

            // Delay to let the stack stabilize even after MTU failure
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }

        // Update state to connected after successful MTU negotiation
        _updateDeviceConnectionState(device, DeviceConnectionState.connected);

        // Ensure device is in connected devices list
        if (mounted) {
          setState(() {
            if (!_connectedDevices.contains(device)) {
              _connectedDevices.add(device);
            }
          });
        }

        return true; // Connection succeeded
      } catch (e) {
        debugPrint(
            'Connection attempt $currentAttempt failed for ${device.platformName}: $e');

        if (currentAttempt >= attempts) {
          debugPrint('Max retries reached for ${device.platformName}');

          // Update state to failed
          _updateDeviceConnectionState(device, DeviceConnectionState.failed);

          return false;
        }

        // Device-specific wait before retrying, with longer delay for problematic devices
        final baseDelay = policy['retryDelay'];
        final adjustedDelay = isProblematicDevice ? baseDelay * 2 : baseDelay;

        await Future.delayed(Duration(seconds: adjustedDelay.round()));
      }
    }

    return false;
  }

  // Method to safely disconnect all devices
  Future<void> _disconnectAllDevices() async {
    if (_connectedDevices.isEmpty) return;

    // Create a copy of the list to avoid modification during iteration
    final devices = List<BluetoothDevice>.from(_connectedDevices);

    for (final device in devices) {
      try {
        await device.disconnect().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Disconnect timeout for ${device.platformName}');
            return;
          },
        );

        if (mounted) {
          setState(() {
            _connectedDevices.removeWhere((d) => d.remoteId == device.remoteId);
            _deviceConnectionStates[device.remoteId.str] =
                DeviceConnectionState.disconnected;
          });
        }

        // Brief delay between disconnections
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('Error disconnecting ${device.platformName}: $e');
        // Remove from list even if disconnection fails
        if (mounted) {
          setState(() {
            _connectedDevices.removeWhere((d) => d.remoteId == device.remoteId);
            _deviceConnectionStates[device.remoteId.str] =
                DeviceConnectionState.disconnected;
          });
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All devices disconnected'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // Even more improved auto-connect implementation that prioritizes reliable connections
  Future<void> _autoConnectToSavedDevices() async {
    if (_savedDevices.isEmpty) return;

    // Prevent multiple concurrent auto-connect calls
    if (_isConnecting) {
      debugPrint('Connection already in progress, skipping');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection already in progress'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting to saved devices...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Check Bluetooth state first
    if (!await _isBluetoothOn()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth is turned off. Please enable Bluetooth.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isConnecting = false;
        });
      }
      return;
    }

    // Disconnect all devices first to ensure clean state
    await _disconnectAllDevices();

    // Add longer delay after disconnection before attempting new connections
    await Future.delayed(const Duration(seconds: 3));

    // Track connection results
    int successCount = 0;

    // Divide devices into standard and problematic ones
    final standardDevices = _savedDevices
        .where((d) =>
            !d.platformName.toLowerCase().contains('hrm') &&
            !d.remoteId.str.contains('22:D8'))
        .toList();

    final problematicDevices = _savedDevices
        .where((d) =>
            d.platformName.toLowerCase().contains('hrm') ||
            d.remoteId.str.contains('22:D8'))
        .toList();

    // First connect to standard devices
    for (final device in standardDevices) {
      // Skip already connected devices
      if (_connectedDevices.any((d) => d.remoteId == device.remoteId)) {
        successCount++;
        continue;
      }

      await _connectSingleDevice(device);
      if (_connectedDevices.any((d) => d.remoteId == device.remoteId)) {
        successCount++;
      }

      // Add delay between connections
      await Future.delayed(const Duration(seconds: 2));
    }

    // Then connect to problematic devices with longer delays
    for (final device in problematicDevices) {
      // Skip already connected devices
      if (_connectedDevices.any((d) => d.remoteId == device.remoteId)) {
        successCount++;
        continue;
      }

      // Extra delay before problematic devices
      await Future.delayed(const Duration(seconds: 2));

      await _connectSingleDevice(device);
      if (_connectedDevices.any((d) => d.remoteId == device.remoteId)) {
        successCount++;
      }

      // Longer delay after problematic devices
      await Future.delayed(const Duration(seconds: 4));
    }

    // Final status report and UI update
    if (mounted) {
      // Important: Update isConnecting state first
      setState(() {
        _isConnecting = false;
      });

      if (successCount == _savedDevices.length && successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to all ${_savedDevices.length} devices'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Connected to $successCount of ${_savedDevices.length} devices'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to any devices'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Helper method to connect a single device with UI updates
  Future<void> _connectSingleDevice(BluetoothDevice device) async {
    final displayName = getDeviceDisplayName(device);

    // Update UI state
    if (mounted) {
      _updateDeviceConnectionState(device, DeviceConnectionState.connecting);
    }

    // Connect with retry mechanism
    final success = await _connectToDeviceWithRetry(device);

    if (success) {
      // Update UI
      if (mounted) {
        setState(() {
          if (!_connectedDevices.contains(device)) {
            _connectedDevices.add(device);
          }
          _deviceConnectionStates[device.remoteId.str] =
              DeviceConnectionState.connected;
        });

        // Already showing notification in connection listener, no need to duplicate
      }
    } else {
      // Update UI for failed connection
      if (mounted) {
        _updateDeviceConnectionState(device, DeviceConnectionState.failed);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to $displayName'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  // Start scanning for devices
  void _startScan() async {
    if (!_permissionGranted) {
      await _checkPermissions();
      if (!_permissionGranted) {
        _showPermissionDialog();
        return;
      }
    }

    if (mounted) {
      setState(() {
        _scanResults = [];
        _isScanning = true;
      });
    }

    try {
      // Stop any existing scan
      await FlutterBluePlus.stopScan();

      // Listen for scan results
      FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            _scanResults = results;
          });
        }
      });

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      _logError('Error scanning: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  // Connect to a device with better error handling
  Future<void> _connectToDevice(BluetoothDevice device) async {
    // Prevent multiple concurrent connections
    if (_isConnecting) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Another connection is in progress. Please wait.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    // Get display name
    final displayName = getDeviceDisplayName(device);

    // Mark as connecting
    if (mounted) {
      _updateDeviceConnectionState(device, DeviceConnectionState.connecting);

      // Show connecting indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecting to $displayName...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Add a timeout for the entire connection process
    bool hasTimedOut = false;
    Timer? connectionTimeout;

    // Set overall connection timeout
    connectionTimeout = Timer(const Duration(seconds: 30), () {
      hasTimedOut = true;
      if (mounted &&
          (_deviceConnectionStates[device.remoteId.str] ==
                  DeviceConnectionState.connecting ||
              _deviceConnectionStates[device.remoteId.str] ==
                  DeviceConnectionState.authenticating)) {
        debugPrint('Global connection timeout for $displayName');

        // Force update state to failed
        _updateDeviceConnectionState(device, DeviceConnectionState.failed);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection to $displayName timed out'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    final success = await _connectToDeviceWithRetry(device);

    // Cancel timeout timer
    connectionTimeout.cancel();

    if (success && mounted && !hasTimedOut) {
      // Update UI
      setState(() {
        if (!_connectedDevices.contains(device)) {
          _connectedDevices.add(device);
        }
        _deviceConnectionStates[device.remoteId.str] =
            DeviceConnectionState.connected;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to $displayName'),
          backgroundColor: Colors.green,
        ),
      );

      // Ask to save the device
      _showSaveDeviceDialog(device);
    } else if (mounted && !hasTimedOut) {
      // Update UI for failed connection only if we haven't already timed out
      _updateDeviceConnectionState(device, DeviceConnectionState.failed);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to $displayName'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  // Disconnect from a device
  Future<void> _disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();

      if (mounted) {
        setState(() {
          _connectedDevices.removeWhere((d) => d.remoteId == device.remoteId);
          _deviceConnectionStates[device.remoteId.str] =
              DeviceConnectionState.disconnected;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnected from ${getDeviceDisplayName(device)}'),
          ),
        );
      }
    } catch (e) {
      _logError('Error disconnecting: $e');
    }
  }

  // Save device to persistent storage
  Future<void> _saveDevice(BluetoothDevice device) async {
    try {
      // Add to the local list first for immediate UI update
      if (mounted) {
        setState(() {
          if (!_savedDevices.any((d) => d.remoteId == device.remoteId)) {
            _savedDevices.add(device);
          }
        });
      }

      // Then save to persistent storage
      await _saveSavedDevicesListToPrefs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${getDeviceDisplayName(device)} saved for auto-connect'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving device: $e');
    }
  }

  // Forget a device
  Future<void> _forgetDevice(BluetoothDevice device) async {
    try {
      // Remove from the local list
      if (mounted) {
        setState(() {
          _savedDevices.removeWhere((d) => d.remoteId == device.remoteId);
        });
      }

      // Update persistent storage
      await _saveSavedDevicesListToPrefs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Forgot ${getDeviceDisplayName(device)}'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error forgetting device: $e');
    }
  }

  // Dialog to ask for saving a device
  void _showSaveDeviceDialog(BluetoothDevice device) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Device'),
        content: Text(
            'Do you want to save ${getDeviceDisplayName(device)} for auto-connect?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              _saveDevice(device);
              Navigator.pop(context);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  // Dialog for permission issues
  void _showPermissionDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
            'Bluetooth and Location permissions are required to scan for and connect to devices.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkPermissions();
            },
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensors'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _permissionGranted
          ? _buildSensorContent()
          : _buildPermissionRequest(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_savedDevices.isNotEmpty && _permissionGranted)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: FloatingActionButton.extended(
                onPressed: _isConnecting ? null : _autoConnectToSavedDevices,
                backgroundColor: _isConnecting ? Colors.grey : Colors.green,
                icon: _isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(Icons.bluetooth_connected),
                label: Text(_getConnectionButtonLabel()),
                heroTag: 'autoConnect',
              ),
            ),
          FloatingActionButton(
            onPressed: _isScanning ? null : _startScan,
            backgroundColor: _isScanning ? Colors.grey : Colors.teal,
            heroTag: 'scan',
            child: _isScanning
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.bluetooth_searching),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bluetooth_disabled,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 24),
          const Text(
            'Bluetooth Permissions Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We need Bluetooth and Location permissions to scan for and connect to your sensors.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _checkPermissions,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorContent() {
    return Column(
      children: [
        // Status bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.teal.withAlpha(40),
          child: Row(
            children: [
              Icon(
                _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                color: Colors.teal,
              ),
              const SizedBox(width: 12),
              Text(
                _isScanning ? 'Scanning for devices...' : 'Sensors Module',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Connected devices section
        if (_connectedDevices.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Connected Devices (${_connectedDevices.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: _connectedDevices.length,
              itemBuilder: (context, index) {
                final device = _connectedDevices[index];
                final isSaved =
                    _savedDevices.any((d) => d.remoteId == device.remoteId);

                return _buildDeviceItem(
                  device: device,
                  isConnected: true,
                  isSaved: isSaved,
                  onTap: () => _disconnectDevice(device),
                  onSaveTap: isSaved
                      ? () => _forgetDevice(device)
                      : () => _saveDevice(device),
                );
              },
            ),
          ),
        ],

        // Saved devices section
        if (_savedDevices.isNotEmpty &&
            _savedDevices.any((d) =>
                !_connectedDevices.contains(d) ||
                _deviceConnectionStates[d.remoteId.str] ==
                    DeviceConnectionState.connecting ||
                _deviceConnectionStates[d.remoteId.str] ==
                    DeviceConnectionState.authenticating ||
                _deviceConnectionStates[d.remoteId.str] ==
                    DeviceConnectionState.failed)) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Saved Devices (${_savedDevices.where((d) => !_connectedDevices.contains(d) || _deviceConnectionStates[d.remoteId.str] == DeviceConnectionState.connecting || _deviceConnectionStates[d.remoteId.str] == DeviceConnectionState.authenticating || _deviceConnectionStates[d.remoteId.str] == DeviceConnectionState.failed).length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: _savedDevices.length,
              itemBuilder: (context, index) {
                final device = _savedDevices[index];
                final isConnected = _connectedDevices.contains(device);
                final connectionState =
                    _deviceConnectionStates[device.remoteId.str] ??
                        (isConnected
                            ? DeviceConnectionState.connected
                            : DeviceConnectionState.disconnected);

                // Skip if already connected (shown above) - unless it's in connecting, authenticating or failed state
                if (isConnected &&
                    connectionState != DeviceConnectionState.connecting &&
                    connectionState != DeviceConnectionState.authenticating &&
                    connectionState != DeviceConnectionState.failed) {
                  return const SizedBox.shrink();
                }

                return _buildDeviceItem(
                  device: device,
                  isConnected: isConnected,
                  isSaved: true,
                  onTap: () => _connectToDevice(device),
                  onSaveTap: () => _forgetDevice(device),
                );
              },
            ),
          ),
        ],

        // Scanned devices section
        if (_scanResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discovered Devices (${_scanResults.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isScanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                final device = result.device;
                final isConnected =
                    _connectedDevices.any((d) => d.remoteId == device.remoteId);
                final isSaved =
                    _savedDevices.any((d) => d.remoteId == device.remoteId);

                // Skip if device is already in connected or saved list
                if (isConnected || isSaved) return const SizedBox.shrink();

                return _buildDeviceItem(
                  device: device,
                  isConnected: isConnected,
                  isSaved: isSaved,
                  rssi: result.rssi,
                  onTap: () => _connectToDevice(device),
                  onSaveTap: isSaved
                      ? () => _forgetDevice(device)
                      : () => _saveDevice(device),
                );
              },
            ),
          ),
        ],

        // If no devices found
        if (_connectedDevices.isEmpty &&
            _scanResults.isEmpty &&
            _savedDevices.isEmpty)
          Expanded(
            child: Center(
              child: _isScanning
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(),
                        ),
                        SizedBox(height: 20),
                        Text('Scanning for nearby devices...'),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 80,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 20),
                        Text('No devices found'),
                        SizedBox(height: 10),
                        Text(
                          'Tap the button below to scan for nearby devices',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  // Enhanced device item widget with connection state indicators and better name display
  Widget _buildDeviceItem({
    required BluetoothDevice device,
    required bool isConnected,
    required bool isSaved,
    required VoidCallback onTap,
    required VoidCallback onSaveTap,
    int? rssi,
  }) {
    // Get current connection state or default to disconnected
    final connectionState = _deviceConnectionStates[device.remoteId.str] ??
        (isConnected
            ? DeviceConnectionState.connected
            : DeviceConnectionState.disconnected);

    // Get the best device name using our helper
    final deviceName = getDeviceDisplayName(device);

    // Calculate signal strength
    int signalStrength = 0;
    if (rssi != null) {
      if (rssi > -60) {
        signalStrength = 3;
      } else if (rssi > -70) {
        signalStrength = 2;
      } else if (rssi > -80) {
        signalStrength = 1;
      }
    }

    // Define indicator color and text based on connection state
    Color stateColor;
    String stateText;
    Widget trailingWidget;

    switch (connectionState) {
      case DeviceConnectionState.connecting:
        stateColor = Colors.orange;
        stateText = 'Connecting...';
        trailingWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_outline),
              onPressed: onSaveTap,
              tooltip: isSaved ? 'Forget device' : 'Save for auto-connect',
            ),
          ],
        );
        break;
      case DeviceConnectionState.authenticating:
        stateColor = Colors.blue;
        stateText = 'Setting up...';
        trailingWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_outline),
              onPressed: onSaveTap,
              tooltip: isSaved ? 'Forget device' : 'Save for auto-connect',
            ),
          ],
        );
        break;
      case DeviceConnectionState.connected:
        stateColor = Colors.green;
        stateText = 'Connected';
        trailingWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.link_off),
              onPressed: onTap,
              tooltip: 'Disconnect',
            ),
            IconButton(
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_outline),
              onPressed: onSaveTap,
              tooltip: isSaved ? 'Forget device' : 'Save for auto-connect',
            ),
          ],
        );
        break;
      case DeviceConnectionState.failed:
        stateColor = Colors.red;
        stateText = 'Connection failed';
        trailingWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onTap,
              tooltip: 'Try again',
            ),
            IconButton(
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_outline),
              onPressed: onSaveTap,
              tooltip: isSaved ? 'Forget device' : 'Save for auto-connect',
            ),
          ],
        );
        break;
      case DeviceConnectionState.disconnected:
        stateColor = Colors.grey;
        stateText = 'Tap to connect';
        trailingWidget = IconButton(
          icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_outline),
          onPressed: onSaveTap,
          tooltip: isSaved ? 'Forget device' : 'Save for auto-connect',
        );
        break;
    }

    // Show device ID in a consistent format for certain states
    final bool showDeviceId = connectionState == DeviceConnectionState.failed ||
        connectionState == DeviceConnectionState.disconnected;

    // Format device ID for display
    final deviceId =
        device.remoteId.str.substring(device.remoteId.str.length - 8);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              backgroundColor: isConnected ? Colors.green : Colors.teal,
              child: Icon(
                _getDeviceIcon(deviceName),
                color: Colors.white,
              ),
            ),
            if (connectionState == DeviceConnectionState.connecting)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            if (connectionState == DeviceConnectionState.authenticating)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            if (connectionState == DeviceConnectionState.connected)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            if (connectionState == DeviceConnectionState.failed)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                deviceName,
                style: TextStyle(
                  fontWeight: isConnected || isSaved
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            if (showDeviceId)
              Text(
                deviceId,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  stateText,
                  style: TextStyle(
                    color: stateColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (rssi != null &&
                    connectionState != DeviceConnectionState.connecting &&
                    connectionState !=
                        DeviceConnectionState.authenticating) ...[
                  const SizedBox(width: 10),
                  Row(
                    children: List.generate(
                        3,
                        (index) => Icon(
                              Icons.signal_cellular_alt,
                              size: 14,
                              color: index < signalStrength
                                  ? Colors.teal
                                  : Colors.grey.shade300,
                            )),
                  ),
                ],
              ],
            ),
            if (isSaved)
              const Text(
                'Saved for auto-connect',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: trailingWidget,
        onTap: connectionState == DeviceConnectionState.connected ||
                connectionState == DeviceConnectionState.connecting ||
                connectionState == DeviceConnectionState.authenticating
            ? null
            : onTap,
      ),
    );
  }

  IconData _getDeviceIcon(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('heart') || name.contains('hr')) {
      return Icons.favorite;
    } else if (name.contains('watch') || name.contains('band')) {
      return Icons.watch;
    } else if (name.contains('foot') || name.contains('pod')) {
      return Icons.directions_walk;
    } else if (name.contains('headphone') || name.contains('earbud')) {
      return Icons.headphones;
    } else {
      return Icons.bluetooth;
    }
  }
}
