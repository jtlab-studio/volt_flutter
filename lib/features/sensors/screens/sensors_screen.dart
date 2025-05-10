// lib/features/sensors/screens/sensors_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import 'bluetooth_models.dart';
import 'bluetooth_service.dart';

class SensorsScreen extends ConsumerStatefulWidget {
  const SensorsScreen({super.key});

  @override
  ConsumerState<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends ConsumerState<SensorsScreen>
    with WidgetsBindingObserver {
  // Bluetooth state
  bool _isScanning = false;
  bool _permissionGranted = false;
  List<BluetoothDevice> _connectedDevices = [];
  List<ScanResult> _scanResults = [];
  List<BluetoothDevice> _savedDevices = [];
  final Map<String, List<BluetoothService>> _deviceServices = {};
  StreamSubscription? _scanSubscription;

  // Track connection states for each device
  final Map<String, DeviceConnectionState> _deviceConnectionStates = {};

  // Flag to prevent multiple simultaneous connections
  bool _isConnecting = false;

  // Bluetooth service instance
  late CustomBluetoothService _bluetoothService;

  // Categories for grouping devices
  final Map<String, List<ScanResult>> _categorizedDevices = {
    'Heart Rate Monitors': [],
    'Stryd Pods': [],
    'Headphones': [],
    'Other Devices': [],
  };

  // Map of known service UUIDs to human-readable names
  final Map<String, String> _knownServices = {
    // Base Services
    '1800': 'Generic Access',
    '1801': 'Generic Attribute',

    // Standard Health & Fitness Services
    '180d': 'Heart Rate',
    '1816': 'Cycling Speed and Cadence',
    '1814': 'Running Speed and Cadence',
    '181c': 'User Data',
    '1826': 'Fitness Machine',
    '181e': 'Power Service',
    '181b': 'Body Composition',
    '181d': 'Weight Scale',
    '1818': 'Cycling Power',
    '1819': 'Location and Navigation',
    '181a': 'Environmental Sensing',

    // Specialized Health Services
    '181f': 'Continuous Glucose Monitoring',

    // Device Status Services
    '180f': 'Battery Service',

    // Audio Services
    '1100': 'Audio Service',
    '110a': 'Audio Streaming',
    '1131': 'Microphone Control',

    // Proprietary Services
    'fc00': 'Stryd Service',
    '6a4e': 'Running Form Metrics',
    '1c68': 'Muscle Oxygen',
    '2af3': 'Stride Sensor',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  // Initialize services and data
  void _initializeServices() {
    // Create and configure Bluetooth service
    _bluetoothService = CustomBluetoothService();

    // Set up callbacks
    _bluetoothService.onDeviceStateChanged = (device, state) {
      if (mounted) {
        setState(() {
          _deviceConnectionStates[device.remoteId.str] = state;
        });
      }
    };

    _bluetoothService.onConnectedDevicesChanged = (devices) {
      if (mounted) {
        setState(() {
          _connectedDevices = devices;
        });
      }
    };

    _bluetoothService.onDeviceConnected = (deviceName) {
      _checkAndNotifyAllConnected(deviceName);
    };

    // Check permissions and load saved devices
    _checkPermissions();
    _loadSavedDevices().then((_) {
      // Initialize connection states for saved devices
      for (final device in _savedDevices) {
        _deviceConnectionStates[device.remoteId.str] =
            DeviceConnectionState.disconnected;
      }

      // Add a slight delay before auto-connecting
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_permissionGranted) {
          _autoConnectToSavedDevices();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // App is in the foreground
      _checkPermissions();
      if (_permissionGranted &&
          _connectedDevices.isEmpty &&
          _savedDevices.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _autoConnectToSavedDevices();
        });
      }
    } else if (state == AppLifecycleState.paused) {
      // App is partially visible
      _bluetoothService.fastDisconnectAllDevices();
    }
  }

  @override
  void deactivate() {
    // This is called when the screen is about to be removed from the widget tree
    debugPrint('SensorsScreen is being deactivated, disconnecting all devices');
    _bluetoothService.fastDisconnectAllDevices();
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we're mounted and just became active
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      // Small delay to avoid race conditions
      Future.delayed(const Duration(milliseconds: 300), () {
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
    WidgetsBinding.instance.removeObserver(this);
    _scanSubscription?.cancel();
    _bluetoothService.dispose();
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

  // Load saved devices from SharedPreferences via bluetooth service
  Future<void> _loadSavedDevices() async {
    final devices = await _bluetoothService.loadSavedDevices();
    if (mounted) {
      setState(() {
        _savedDevices = devices;
      });

      // For each connected device, try to discover services
      for (final device in devices) {
        if (_connectedDevices.any((d) => d.remoteId == device.remoteId)) {
          _discoverServices(device);
        }
      }
    }
  }

  // Get a human-readable name for a service UUID
  String _getServiceName(String uuid) {
    // Clean up the UUID string to match our known services map
    final shortUuid = uuid.replaceAll('-', '').toLowerCase();

    // Check if it's in our known services (try different portions)
    for (var knownUuid in _knownServices.keys) {
      if (shortUuid.contains(knownUuid.toLowerCase())) {
        return _knownServices[knownUuid]!;
      }
    }

    // Return a default for unknown services
    return 'Unknown Service';
  }

  // Discover services for a device
  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      if (_deviceConnectionStates[device.remoteId.str] ==
          DeviceConnectionState.connected) {
        final services = await device.discoverServices();

        if (mounted) {
          setState(() {
            _deviceServices[device.remoteId.str] = services;
          });
        }

        debugPrint(
            'Discovered ${services.length} services for ${device.platformName}');

        for (var service in services) {
          String knownServiceName = _getServiceName(service.uuid.toString());
          debugPrint('Service: ${service.uuid} ($knownServiceName)');
        }
      }
    } catch (e) {
      debugPrint('Error discovering services: $e');
    }
  }

  // Categorize scan results into device types
  void _categorizeScanResults(List<ScanResult> results) {
    // Clear previous categorization
    _categorizedDevices.forEach((key, value) => value.clear());

    for (final result in results) {
      final device = result.device;
      final deviceName = _bluetoothService.getDeviceDisplayName(device);
      final lowerDeviceName = deviceName.toLowerCase();

      // Skip devices that are already saved
      if (_savedDevices.any((d) => d.remoteId == device.remoteId)) {
        continue;
      }

      // Categorize by device name and advertisementData
      if (lowerDeviceName.contains('hr') ||
          lowerDeviceName.contains('heart') ||
          lowerDeviceName.contains('hrm') ||
          device.remoteId.str.contains('22:D8')) {
        _categorizedDevices['Heart Rate Monitors']!.add(result);
      } else if (lowerDeviceName.contains('stryd') ||
          lowerDeviceName.contains('pod') ||
          lowerDeviceName.contains('foot') ||
          device.remoteId.str.contains('30:02')) {
        _categorizedDevices['Stryd Pods']!.add(result);
      } else if (lowerDeviceName.contains('headphone') ||
          lowerDeviceName.contains('earphone') ||
          lowerDeviceName.contains('earbud') ||
          lowerDeviceName.contains('bose') ||
          lowerDeviceName.contains('sony') ||
          lowerDeviceName.contains('jabra') ||
          lowerDeviceName.contains('audio')) {
        _categorizedDevices['Headphones']!.add(result);
      } else {
        _categorizedDevices['Other Devices']!.add(result);
      }
    }
  }

  // Save a device to persistent storage
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

      // Save to persistent storage
      await _bluetoothService.saveDevicesToPrefs(_savedDevices);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_bluetoothService.getDeviceDisplayName(device)} saved for auto-connect'),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 800),
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
          _deviceServices.remove(device.remoteId.str);
        });
      }

      // Update persistent storage
      await _bluetoothService.saveDevicesToPrefs(_savedDevices);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Forgot ${_bluetoothService.getDeviceDisplayName(device)}'),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error forgetting device: $e');
    }
  }

  // Check if all devices are connected and show appropriate notification
  void _checkAndNotifyAllConnected(String justConnectedDeviceName) {
    // Only show individual connection messages if we don't have all devices connected
    if (_connectedDevices.length < _savedDevices.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to $justConnectedDeviceName'),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 800),
        ),
      );

      // Try to discover services for the newly connected device
      for (final device in _connectedDevices) {
        if (_bluetoothService.getDeviceDisplayName(device) ==
            justConnectedDeviceName) {
          _discoverServices(device);
          break;
        }
      }

      return;
    }

    // If this was the last device to connect, show the "all connected" message
    if (_connectedDevices.length == _savedDevices.length) {
      // Clear any existing snackbars to show the "all connected" message immediately
      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All ${_savedDevices.length} devices connected!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );

      // Discover services for all connected devices
      for (final device in _connectedDevices) {
        if (!_deviceServices.containsKey(device.remoteId.str)) {
          _discoverServices(device);
        }
      }

      // Force UI update to show "All Connected" status
      setState(() {
        _isConnecting = false;
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
        _categorizedDevices.forEach((key, value) => value.clear());
      });
    }

    // Cancel existing subscription if any
    _scanSubscription?.cancel();

    // Start scan with callback
    await _bluetoothService.startScan(onResultsUpdated: (results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
          _categorizeScanResults(results);
        });
      }
    });

    // Set up a timer to stop the scanning display after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isScanning) {
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  // Auto-connect to all saved devices
  Future<void> _autoConnectToSavedDevices() async {
    if (_savedDevices.isEmpty) return;

    // Prevent multiple concurrent auto-connect calls
    if (_isConnecting) {
      debugPrint('Connection already in progress, skipping');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection already in progress'),
            duration: Duration(milliseconds: 800),
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
          content: Text('Connecting to devices...'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }

    // Check Bluetooth state first
    if (!await _bluetoothService.isBluetoothOn()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth is turned off'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
        setState(() {
          _isConnecting = false;
        });
      }
      return;
    }

    // Connect to all saved devices
    final successCount =
        await _bluetoothService.autoConnectToSavedDevices(_savedDevices);

    // Final status update only if we're not displaying the all-connected message already
    if (mounted && successCount != _savedDevices.length) {
      setState(() {
        _isConnecting = false;
      });

      if (successCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to any devices'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      } else if (successCount < _savedDevices.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Connected to $successCount of ${_savedDevices.length} devices'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  // Connect to a specific device
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
    final displayName = _bluetoothService.getDeviceDisplayName(device);

    // Show connecting indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecting to $displayName...'),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    // Use the right connection method based on device type
    final policy = _bluetoothService.getDevicePolicy(device);
    final success = policy['fastMode'] == true
        ? await _bluetoothService.fastConnectProblematicDevice(device)
        : await _bluetoothService.connectToDeviceWithRetry(device);

    if (success && mounted) {
      // Discover services for the connected device
      _discoverServices(device);

      // Ask to save the device
      _showSaveDeviceDialog(device);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to $displayName'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted && _isConnecting) {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  // Disconnect from a device
  Future<void> _disconnectDevice(BluetoothDevice device) async {
    try {
      await _bluetoothService.fastDisconnectDevice(device);

      // Remove services when disconnected
      if (mounted) {
        setState(() {
          _deviceServices.remove(device.remoteId.str);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Disconnected from ${_bluetoothService.getDeviceDisplayName(device)}'),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error disconnecting: $e');
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
            'Do you want to save ${_bluetoothService.getDeviceDisplayName(device)} for auto-connect?'),
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
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (_connectedDevices.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Connected Devices (${_connectedDevices.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ..._connectedDevices.map((device) {
                  final isSaved =
                      _savedDevices.any((d) => d.remoteId == device.remoteId);
                  return _buildConnectedDeviceItem(
                    device: device,
                    isSaved: isSaved,
                    services: _deviceServices[device.remoteId.str] ?? [],
                    onTap: () => _disconnectDevice(device),
                    onSaveTap: isSaved
                        ? () => _forgetDevice(device)
                        : () => _saveDevice(device),
                  );
                }),
              ],

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
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark,
                          size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Saved Devices (${_savedDevices.where((d) => !_connectedDevices.contains(d) || _deviceConnectionStates[d.remoteId.str] == DeviceConnectionState.connecting || _deviceConnectionStates[d.remoteId.str] == DeviceConnectionState.authenticating || _deviceConnectionStates[d.remoteId.str] == DeviceConnectionState.failed).length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ..._savedDevices.where((device) {
                  final isConnected = _connectedDevices.contains(device);
                  final connectionState =
                      _deviceConnectionStates[device.remoteId.str] ??
                          (isConnected
                              ? DeviceConnectionState.connected
                              : DeviceConnectionState.disconnected);

                  // Skip if already connected (shown above) - unless it's in connecting, authenticating or failed state
                  return !isConnected ||
                      connectionState == DeviceConnectionState.connecting ||
                      connectionState == DeviceConnectionState.authenticating ||
                      connectionState == DeviceConnectionState.failed;
                }).map((device) {
                  final isConnected = _connectedDevices.contains(device);
                  return _buildDeviceItem(
                    device: device,
                    isConnected: isConnected,
                    isSaved: true,
                    onTap: () => _connectToDevice(device),
                    onSaveTap: () => _forgetDevice(device),
                  );
                }),
              ],

              // Discovered devices sections by category
              if (_isScanning || _scanResults.isNotEmpty) ...[
                // Heart Rate Monitors section
                if (_categorizedDevices['Heart Rate Monitors']!.isNotEmpty) ...[
                  _buildCategoryHeader(
                    'Heart Rate Monitors',
                    Icons.favorite,
                    Colors.red,
                    _categorizedDevices['Heart Rate Monitors']!.length,
                  ),
                  ..._categorizedDevices['Heart Rate Monitors']!.map((result) {
                    return _buildDeviceItem(
                      device: result.device,
                      isConnected: false,
                      isSaved: false,
                      rssi: result.rssi,
                      onTap: () => _connectToDevice(result.device),
                      onSaveTap: () => _saveDevice(result.device),
                    );
                  }),
                ],

                // Stryd Pods section
                if (_categorizedDevices['Stryd Pods']!.isNotEmpty) ...[
                  _buildCategoryHeader(
                    'Stryd Pods',
                    Icons.directions_run,
                    Colors.green,
                    _categorizedDevices['Stryd Pods']!.length,
                  ),
                  ..._categorizedDevices['Stryd Pods']!.map((result) {
                    return _buildDeviceItem(
                      device: result.device,
                      isConnected: false,
                      isSaved: false,
                      rssi: result.rssi,
                      onTap: () => _connectToDevice(result.device),
                      onSaveTap: () => _saveDevice(result.device),
                    );
                  }),
                ],

                // Headphones section
                if (_categorizedDevices['Headphones']!.isNotEmpty) ...[
                  _buildCategoryHeader(
                    'Headphones',
                    Icons.headphones,
                    Colors.blueGrey,
                    _categorizedDevices['Headphones']!.length,
                  ),
                  ..._categorizedDevices['Headphones']!.map((result) {
                    return _buildDeviceItem(
                      device: result.device,
                      isConnected: false,
                      isSaved: false,
                      rssi: result.rssi,
                      onTap: () => _connectToDevice(result.device),
                      onSaveTap: () => _saveDevice(result.device),
                    );
                  }),
                ],

                // Other devices section
                if (_categorizedDevices['Other Devices']!.isNotEmpty) ...[
                  _buildCategoryHeader(
                    'Other Devices',
                    Icons.bluetooth,
                    Colors.blue,
                    _categorizedDevices['Other Devices']!.length,
                  ),
                  ..._categorizedDevices['Other Devices']!.map((result) {
                    return _buildDeviceItem(
                      device: result.device,
                      isConnected: false,
                      isSaved: false,
                      rssi: result.rssi,
                      onTap: () => _connectToDevice(result.device),
                      onSaveTap: () => _saveDevice(result.device),
                    );
                  }),
                ],
              ],

              // If no devices found
              if (_connectedDevices.isEmpty &&
                  _scanResults.isEmpty &&
                  _savedDevices.isEmpty)
                _buildEmptyState(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      alignment: Alignment.center,
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
    );
  }

  Widget _buildCategoryHeader(
      String title, IconData icon, Color color, int count) {
    // Fixed version using List<Widget> approach to avoid if statement issues
    final List<Widget> children = [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Text(
        '$title ($count)',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ];

    // Add spinner if scanning
    if (_isScanning) {
      children.add(const Spacer());
      children.add(
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: color,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: children,
      ),
    );
  }

  // Enhanced device item for connected devices with services display
  Widget _buildConnectedDeviceItem({
    required BluetoothDevice device,
    required bool isSaved,
    required List<BluetoothService> services,
    required VoidCallback onTap,
    required VoidCallback onSaveTap,
  }) {
    // Get device name
    final deviceName = _bluetoothService.getDeviceDisplayName(device);

    // Process services for display
    final Map<String, bool> serviceTypes = {
      // Basic Services
      'Heart Rate': false,
      'Power': false,
      'Cadence': false,
      'Speed': false,
      'Audio': false,
      'Battery': false,

      // Additional Health & Fitness Services
      'Body Composition': false,
      'Weight Scale': false,
      'Cycling Power': false,
      'Location': false,
      'Environmental': false,

      // Specialized Services
      'Glucose': false,
      'Running Form': false,
      'Muscle Oxygen': false,
      'Stride': false,
    };

    // Check for known services
    for (final service in services) {
      final uuid = service.uuid.toString().toLowerCase();

      // Basic Services
      if (uuid.contains('180d')) serviceTypes['Heart Rate'] = true;
      if (uuid.contains('181e') || uuid.contains('fc00'))
        serviceTypes['Power'] = true;
      if (uuid.contains('1814') || uuid.contains('1816')) {
        serviceTypes['Cadence'] = true;
        serviceTypes['Speed'] = true;
      }
      if (uuid.contains('1100') || uuid.contains('110a'))
        serviceTypes['Audio'] = true;
      if (uuid.contains('180f')) serviceTypes['Battery'] = true;

      // Additional Health & Fitness Services
      if (uuid.contains('181b')) serviceTypes['Body Composition'] = true;
      if (uuid.contains('181d')) serviceTypes['Weight Scale'] = true;
      if (uuid.contains('1818')) serviceTypes['Cycling Power'] = true;
      if (uuid.contains('1819')) serviceTypes['Location'] = true;
      if (uuid.contains('181a')) serviceTypes['Environmental'] = true;

      // Specialized Services
      if (uuid.contains('181f')) serviceTypes['Glucose'] = true;
      if (uuid.contains('6a4e')) serviceTypes['Running Form'] = true;
      if (uuid.contains('1c68')) serviceTypes['Muscle Oxygen'] = true;
      if (uuid.contains('2af3')) serviceTypes['Stride'] = true;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(
                _getDeviceIcon(deviceName),
                color: Colors.white,
              ),
            ),
            title: Text(
              deviceName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Connected${isSaved ? ' • Saved for auto-connect' : ''}',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Row(
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
            ),
          ),

          // Services section
          if (services.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const Text(
                    'Services:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Basic Services
                      if (serviceTypes['Heart Rate']!)
                        _buildServiceChip(
                            'Heart Rate', Icons.favorite, Colors.red),
                      if (serviceTypes['Power']!)
                        _buildServiceChip('Power', Icons.bolt, Colors.orange),
                      if (serviceTypes['Cadence']!)
                        _buildServiceChip(
                            'Cadence', Icons.directions_walk, Colors.green),
                      if (serviceTypes['Speed']!)
                        _buildServiceChip('Speed', Icons.speed, Colors.blue),
                      if (serviceTypes['Audio']!)
                        _buildServiceChip(
                            'Audio', Icons.headphones, Colors.purple),
                      if (serviceTypes['Battery']!)
                        _buildServiceChip(
                            'Battery', Icons.battery_full, Colors.teal),

                      // Additional Health & Fitness Services
                      if (serviceTypes['Body Composition']!)
                        _buildServiceChip('Body Composition',
                            Icons.monitor_weight, Colors.indigo),
                      if (serviceTypes['Weight Scale']!)
                        _buildServiceChip(
                            'Weight Scale', Icons.scale, Colors.brown),
                      if (serviceTypes['Cycling Power']!)
                        _buildServiceChip(
                            'Cycling Power', Icons.pedal_bike, Colors.pink),
                      if (serviceTypes['Location']!)
                        _buildServiceChip(
                            'Location', Icons.location_on, Colors.deepOrange),
                      if (serviceTypes['Environmental']!)
                        _buildServiceChip(
                            'Environment', Icons.thermostat, Colors.lightGreen),

                      // Specialized Services
                      if (serviceTypes['Glucose']!)
                        _buildServiceChip(
                            'Glucose', Icons.timeline, Colors.deepPurple),
                      if (serviceTypes['Running Form']!)
                        _buildServiceChip(
                            'Running Form', Icons.run_circle, Colors.amber),
                      if (serviceTypes['Muscle Oxygen']!)
                        _buildServiceChip(
                            'Muscle O₂', Icons.bloodtype, Colors.redAccent),
                      if (serviceTypes['Stride']!)
                        _buildServiceChip(
                            'Stride', Icons.straighten, Colors.cyan),

                      // Show "Other" if we have services but none of the known types
                      if (services.isNotEmpty &&
                          !serviceTypes.values.any((value) => value))
                        _buildServiceChip('Bluetooth Services', Icons.bluetooth,
                            Colors.blueGrey),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Build a service chip for display
  Widget _buildServiceChip(String label, IconData icon, Color color) {
    return Chip(
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: color.withAlpha(30),
      avatar: Icon(icon, color: color, size: 16),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
        ),
      ),
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
    final deviceName = _bluetoothService.getDeviceDisplayName(device);

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
        stateText = isSaved ? 'Tap to connect' : 'Available';
        trailingWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.link),
              onPressed: onTap,
              tooltip: 'Connect',
            ),
            IconButton(
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_outline),
              onPressed: onSaveTap,
              tooltip: isSaved ? 'Forget device' : 'Save for auto-connect',
            ),
          ],
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
              backgroundColor: isSaved ? Colors.orange : Colors.teal,
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
            if (isSaved && !isConnected)
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
    if (name.contains('heart') || name.contains('hr') || name.contains('hrm')) {
      return Icons.favorite;
    } else if (name.contains('watch') || name.contains('band')) {
      return Icons.watch;
    } else if (name.contains('foot') ||
        name.contains('pod') ||
        name.contains('stryd')) {
      return Icons.directions_walk;
    } else if (name.contains('headphone') || name.contains('earbud')) {
      return Icons.headphones;
    } else {
      return Icons.bluetooth;
    }
  }
}
