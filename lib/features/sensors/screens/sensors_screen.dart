import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadSavedDevices().then((_) {
      _initBluetooth();
      // Add a slight delay before auto-connecting
      Future.delayed(const Duration(seconds: 1), () {
        if (_permissionGranted) {
          _autoConnectToSavedDevices();
        }
      });
    });
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

    setState(() {
      _permissionGranted = bluetoothStatus.isGranted &&
          locationStatus.isGranted &&
          bluetoothConnectStatus.isGranted &&
          bluetoothScanStatus.isGranted;
    });
  }

  // Initialize Bluetooth
  Future<void> _initBluetooth() async {
    // Get connected devices
    try {
      if (_permissionGranted) {
        List<BluetoothDevice> connectedDevices =
            FlutterBluePlus.connectedDevices;
        setState(() {
          _connectedDevices = connectedDevices;
        });
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

      setState(() {
        _savedDevices = devices;
      });
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

  // Method to auto-connect to saved devices
  Future<void> _autoConnectToSavedDevices() async {
    if (_savedDevices.isEmpty) return;

    // Show a loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting to saved devices...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Try to connect to each saved device
    for (final device in _savedDevices) {
      // Skip if already connected
      if (_connectedDevices.any((d) => d.remoteId == device.remoteId)) {
        continue;
      }

      try {
        await device
            .connect(
          autoConnect: true,
        )
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('Connection timeout for device: ${device.platformName}');
            return;
          },
        );

        // Add to connected devices list
        setState(() {
          if (!_connectedDevices.contains(device)) {
            _connectedDevices.add(device);
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${device.platformName}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        debugPrint('Failed to auto-connect to ${device.platformName}: $e');
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

    setState(() {
      _scanResults = [];
      _isScanning = true;
    });

    try {
      // Stop any existing scan
      await FlutterBluePlus.stopScan();

      // Listen for scan results
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results;
        });
      });

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      _logError('Error scanning: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  // Connect to a device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();

      // Add to connected devices list
      setState(() {
        if (!_connectedDevices.contains(device)) {
          _connectedDevices.add(device);
        }
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.platformName}'),
          backgroundColor: Colors.green,
        ),
      );

      // Ask to save the device
      _showSaveDeviceDialog(device);
    } catch (e) {
      _logError('Error connecting to device: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Disconnect from a device
  Future<void> _disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();

      setState(() {
        _connectedDevices.removeWhere((d) => d.remoteId == device.remoteId);
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disconnected from ${device.platformName}'),
        ),
      );
    } catch (e) {
      _logError('Error disconnecting: $e');
    }
  }

  // Save device to persistent storage
  Future<void> _saveDevice(BluetoothDevice device) async {
    try {
      // Add to the local list first for immediate UI update
      setState(() {
        if (!_savedDevices.any((d) => d.remoteId == device.remoteId)) {
          _savedDevices.add(device);
        }
      });

      // Then save to persistent storage
      await _saveSavedDevicesListToPrefs();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${device.platformName} saved for auto-connect'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error saving device: $e');
    }
  }

  // Forget a device
  Future<void> _forgetDevice(BluetoothDevice device) async {
    try {
      // Remove from the local list
      setState(() {
        _savedDevices.removeWhere((d) => d.remoteId == device.remoteId);
      });

      // Update persistent storage
      await _saveSavedDevicesListToPrefs();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Forgot ${device.platformName}'),
        ),
      );
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
                onPressed: _autoConnectToSavedDevices,
                backgroundColor: Colors.green,
                icon: const Icon(Icons.bluetooth_connected),
                label: const Text('Connect All Saved'),
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
            _savedDevices.any((d) => !_connectedDevices.contains(d))) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Saved Devices (${_savedDevices.where((d) => !_connectedDevices.contains(d)).length})',
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

                // Skip if already connected (shown above)
                if (isConnected) return const SizedBox.shrink();

                return _buildDeviceItem(
                  device: device,
                  isConnected: false,
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

  Widget _buildDeviceItem({
    required BluetoothDevice device,
    required bool isConnected,
    required bool isSaved,
    required VoidCallback onTap,
    required VoidCallback onSaveTap,
    int? rssi,
  }) {
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isConnected ? Colors.green : Colors.teal,
          child: Icon(
            _getDeviceIcon(deviceName),
            color: Colors.white,
          ),
        ),
        title: Text(
          deviceName,
          style: TextStyle(
            fontWeight:
                isConnected || isSaved ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Row(
          children: [
            Text(isConnected ? 'Connected' : 'Tap to connect'),
            if (rssi != null) ...[
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConnected)
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
        onTap: isConnected ? null : onTap,
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
