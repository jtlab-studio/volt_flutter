import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Add this import for StreamSubscription
import 'dart:convert';

// Define connection states for better UI feedback
enum DeviceConnectionState { disconnected, connecting, connected, failed }

class SensorsScreen extends ConsumerStatefulWidget {
  const SensorsScreen({super.key});

  @override
  ConsumerState<SensorsScreen> createState() => _SensorsScreenState();
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

  // Setup connection state listener for a device
  void _setupConnectionListener(BluetoothDevice device) {
    // Cancel existing subscription if any
    _connectionStateSubscriptions[device.remoteId.str]?.cancel();

    // Create new subscription
    _connectionStateSubscriptions[device.remoteId.str] =
        device.connectionState.listen((BluetoothConnectionState state) {
      if (state == BluetoothConnectionState.disconnected) {
        debugPrint('Device disconnected: ${device.platformName}');
        if (mounted) {
          setState(() {
            _connectedDevices.removeWhere((d) => d.remoteId == device.remoteId);
            _deviceConnectionStates[device.remoteId.str] =
                DeviceConnectionState.disconnected;
          });
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

  // Load saved devices from SharedPreferences
  Future<void> _loadSavedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDevicesJson = prefs.getStringList('saved_devices') ?? [];

      final devices = <BluetoothDevice>[];

      for (final deviceJson in savedDevicesJson) {
        try {
          final Map<String, dynamic> data = jsonDecode(deviceJson);

          // Create a BluetoothDevice from the saved data
          final deviceId = data['remoteId'];

          // Use the fromId constructor properly (it doesn't take name or type)
          final device = BluetoothDevice.fromId(deviceId);

          devices.add(device);
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

  // Save the list of devices to SharedPreferences
  Future<void> _saveSavedDevicesListToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedDevicesJson = _savedDevices.map((device) {
        return jsonEncode({
          'remoteId': device.remoteId.str,
          'platformName': device.platformName,
          // Don't store type as it's not available in the API
        });
      }).toList();

      await prefs.setStringList('saved_devices', savedDevicesJson);
    } catch (e) {
      debugPrint('Error saving devices to preferences: $e');
    }
  }

  // Helper method to connect to a single device with improved error handling
  Future<bool> _connectToDeviceWithRetry(BluetoothDevice device,
      {int maxRetries = 2}) async {
    int attempts = 0;

    // Create a completer to track this connection attempt
    final completer = Completer<void>();
    _connectionCompleters[device.remoteId.str] = completer;

    while (attempts < maxRetries) {
      attempts++;
      try {
        debugPrint(
            'Connecting to ${device.platformName} (Attempt $attempts/$maxRetries)');

        // Check if Bluetooth is on
        if (!await _isBluetoothOn()) {
          debugPrint('Bluetooth is off, cannot connect');
          return false;
        }

        // Attempt to disconnect first if this is a retry
        if (attempts > 1) {
          try {
            await device.disconnect();
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            // Ignore disconnect errors
          }
        }

        // Connect with timeout
        await device.connect(timeout: const Duration(seconds: 7)).timeout(
          const Duration(seconds: 7),
          onTimeout: () {
            throw Exception('Connection timeout');
          },
        );

        // Setup connection state listener
        _setupConnectionListener(device);

        // Connection successful - add brief delay before continuing
        await Future.delayed(const Duration(milliseconds: 300));

        // Set MTU with shorter timeout
        try {
          final mtu = await device.requestMtu(512).timeout(
            const Duration(seconds: 4),
            onTimeout: () {
              debugPrint('MTU request timeout, but connection is established');
              return 23; // Default MTU
            },
          );
          debugPrint('MTU set to $mtu for device ${device.platformName}');
        } catch (mtuError) {
          // Log MTU errors but don't fail the connection
          debugPrint(
              'MTU request failed for ${device.platformName}: $mtuError');
        }

        return true; // Connection succeeded
      } catch (e) {
        debugPrint(
            'Connection attempt $attempts failed for ${device.platformName}: $e');

        if (attempts >= maxRetries) {
          debugPrint('Max retries reached for ${device.platformName}');
          return false;
        }

        // Wait before retrying
        await Future.delayed(const Duration(seconds: 1));
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
        await Future.delayed(const Duration(milliseconds: 300));
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
        ),
      );
    }
  }

  // Improved auto-connect implementation that connects one device at a time
  Future<void> _autoConnectToSavedDevices() async {
    if (_savedDevices.isEmpty) return;

    // Prevent multiple concurrent auto-connect calls
    if (_isConnecting) {
      debugPrint('Connection already in progress, skipping');
      return;
    }

    _isConnecting = true;

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
      }
      _isConnecting = false;
      return;
    }

    // Disconnect all devices first to ensure clean state
    await _disconnectAllDevices();

    // Track connection results
    int successCount = 0;
    final int totalDevices = _savedDevices.length;

    // Connect to each device - ONE AT A TIME to avoid conflicts
    for (final device in _savedDevices) {
      // Skip already connected devices
      if (_connectedDevices.any((d) => d.remoteId == device.remoteId)) {
        successCount++;
        continue;
      }

      // Update UI state
      if (mounted) {
        _updateDeviceConnectionState(device, DeviceConnectionState.connecting);
      }

      // Connect with retry mechanism - ONE AT A TIME
      final success = await _connectToDeviceWithRetry(device);

      if (success) {
        successCount++;

        // Update UI
        if (mounted) {
          setState(() {
            if (!_connectedDevices.contains(device)) {
              _connectedDevices.add(device);
            }
            _deviceConnectionStates[device.remoteId.str] =
                DeviceConnectionState.connected;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${device.platformName}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        // Update UI for failed connection
        if (mounted) {
          _updateDeviceConnectionState(device, DeviceConnectionState.failed);
        }
      }

      // Add delay between connections to prevent Bluetooth stack overload
      await Future.delayed(const Duration(seconds: 1));
    }

    // Final status report
    if (mounted) {
      if (successCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to any devices'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (successCount < totalDevices) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Connected to $successCount of $totalDevices devices'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to all $totalDevices devices'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    _isConnecting = false;
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

  // Connect to a device
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

    _isConnecting = true;

    // Mark as connecting
    if (mounted) {
      _updateDeviceConnectionState(device, DeviceConnectionState.connecting);

      // Show connecting indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecting to ${device.platformName}...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final success = await _connectToDeviceWithRetry(device);

    if (success && mounted) {
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
          content: Text('Connected to ${device.platformName}'),
          backgroundColor: Colors.green,
        ),
      );

      // Ask to save the device
      _showSaveDeviceDialog(device);
    } else if (mounted) {
      // Update UI for failed connection
      _updateDeviceConnectionState(device, DeviceConnectionState.failed);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to ${device.platformName}'),
          backgroundColor: Colors.red,
        ),
      );
    }

    _isConnecting = false;
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
            content: Text('Disconnected from ${device.platformName}'),
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
            content: Text('${device.platformName} saved for auto-connect'),
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
            content: Text('Forgot ${device.platformName}'),
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
            'Do you want to save ${device.platformName} for auto-connect?'),
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
                label:
                    Text(_isConnecting ? 'Connecting...' : 'Connect All Saved'),
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
                    DeviceConnectionState.failed)) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Saved Devices (${_savedDevices.where((d) => !_connectedDevices.contains(d) || _deviceConnectionStates[d.remoteId.str] == DeviceConnectionState.connecting || _deviceConnectionStates[d.remoteId.str] == DeviceConnectionState.failed).length})',
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

                // Skip if already connected (shown above) - unless it's in connecting or failed state
                if (isConnected &&
                    connectionState != DeviceConnectionState.connecting &&
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

  // Enhanced device item widget with connection state indicators
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

    // Handle empty or unnamed devices
    final deviceName = device.platformName.isNotEmpty
        ? device.platformName
        : 'Unknown Device (${device.remoteId.str.substring(0, 6)})';

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
        title: Text(
          deviceName,
          style: TextStyle(
            fontWeight:
                isConnected || isSaved ? FontWeight.bold : FontWeight.normal,
          ),
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
                    connectionState != DeviceConnectionState.connecting) ...[
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
                connectionState == DeviceConnectionState.connecting
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
