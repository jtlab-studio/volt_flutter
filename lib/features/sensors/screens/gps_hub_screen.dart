// lib/features/sensors/screens/gps_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/gps_providers.dart';
import '../widgets/gps_validation_card.dart';

/// A screen for managing GPS settings with various presets and custom features
class GpsHubScreen extends ConsumerStatefulWidget {
  const GpsHubScreen({super.key});

  @override
  ConsumerState<GpsHubScreen> createState() => _GpsHubScreenState();
}

class _GpsHubScreenState extends ConsumerState<GpsHubScreen> {
  // Loading state
  bool _isDetectingCapabilities = true;

  @override
  void initState() {
    super.initState();
    // Initialize capabilities detection through the provider
    _initializeCapabilities();
  }

  /// Initialize capabilities detection
  Future<void> _initializeCapabilities() async {
    setState(() {
      _isDetectingCapabilities = true;
    });

    try {
      // Access the GPS service through Riverpod
      await ref.read(gpsCapabilitiesProvider.future);

      // Setting will be done once capabilities are fetched
      setState(() {
        _isDetectingCapabilities = false;
      });
    } catch (e) {
      debugPrint('Error detecting capabilities: $e');
      setState(() {
        _isDetectingCapabilities = false;
      });
    }
  }

  /// Handle preset mode change
  void _onModeChanged(String? value) async {
    if (value == null) return;

    // Use the Riverpod notifier to update mode
    await ref.read(gpsSettingsProvider.notifier).updateBasedOnPresetMode(value);

    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPS mode updated to ${_getModeDisplayName(value)}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// Get display name for a mode
  String _getModeDisplayName(String mode) {
    switch (mode) {
      case 'power_saver':
        return 'Power-Saver';
      case 'balanced':
        return 'Balanced';
      case 'high_accuracy':
        return 'High-Accuracy';
      case 'rtk':
        return 'RTK';
      default:
        return mode;
    }
  }

  /// Show info dialog with details about GPS settings
  void _showInfoDialog() async {
    // Get the capabilities from provider
    final capabilities = await ref.read(gpsCapabilitiesProvider.future);
    // Get power and accuracy estimates
    final powerEstimates = await ref.read(gpsPowerEstimatesProvider.future);
    final accuracyEstimates =
        await ref.read(gpsAccuracyEstimatesProvider.future);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GPS Hub Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Energy vs. Accuracy Trade-offs:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '• Power-Saver: ~${powerEstimates['power_saver']?.toInt() ?? 50} mW, ~${accuracyEstimates['power_saver']?.toInt() ?? 10}m accuracy',
              ),
              Text(
                '• Balanced: ~${powerEstimates['balanced']?.toInt() ?? 410} mW, ~${accuracyEstimates['balanced']?.toInt() ?? 3}m accuracy',
              ),
              Text(
                '• High-Accuracy: ~${powerEstimates['high_accuracy']?.toInt() ?? 2200} mW, ~${accuracyEstimates['high_accuracy'] ?? 1.5}m accuracy',
              ),
              Text(
                '• RTK: ~${powerEstimates['rtk']?.toInt() ?? 3000} mW, <${accuracyEstimates['rtk'] ?? 0.5}m accuracy',
              ),
              const SizedBox(height: 16),
              const Text(
                'Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                '• Multi-frequency: Uses both L1 and L5 bands for better accuracy',
              ),
              const Text(
                '• Raw GNSS: Provides carrier-phase measurements for RTK',
              ),
              const Text(
                '• Sensor Fusion: Combines GPS with IMU sensors',
              ),
              const Text(
                '• RTK Corrections: Uses NTRIP correction streams',
              ),
              const Text(
                '• External Receiver: Connects to external GNSS via Bluetooth',
              ),
              const SizedBox(height: 16),
              const Text(
                'Device Capabilities:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '• Dual-frequency GNSS: ${capabilities['dualFrequency'] == true ? "Supported" : "Not supported"}',
              ),
              Text(
                '• Raw GNSS Measurements: ${capabilities['rawMeasurements'] == true ? "Supported" : "Not supported"}',
              ),
              Text(
                '• Inertial Sensors: ${capabilities['inertialSensors'] == true ? "Supported" : "Not supported"}',
              ),
              Text(
                '• Multi-constellation: ${capabilities['multiConstellation'] == true ? "Supported" : "Not supported"}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch capabilities
    final capabilities = ref.watch(gpsCapabilitiesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('GPS Hub'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Information',
          ),
        ],
      ),
      body: _isDetectingCapabilities || capabilities.isLoading
          ? _buildLoadingView()
          : _buildSettingsView(),
    );
  }

  /// Build loading view while detecting capabilities
  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Detecting device capabilities...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Build the main settings view
  Widget _buildSettingsView() {
    // Watch capabilities from Riverpod
    final capabilitiesAsyncValue = ref.watch(gpsCapabilitiesProvider);
    // Watch settings from Riverpod
    final settings = ref.watch(gpsSettingsProvider);

    // Extract capabilities
    final capabilities = capabilitiesAsyncValue.valueOrNull ??
        {
          'dualFrequency': false,
          'rawMeasurements': false,
          'multiConstellation': true,
          'inertialSensors': true,
        };

    final supportsDualFreq = capabilities['dualFrequency'] ?? false;
    final supportsRawMeasurements = capabilities['rawMeasurements'] ?? false;
    final supportsSensors = capabilities['inertialSensors'] ?? true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Card #1: Preset Modes
        Card(
          child: Column(
            children: [
              const ListTile(
                title: Text('Preset Mode'),
                subtitle: Text('Quick select energy vs. accuracy'),
              ),
              RadioListTile<String>(
                title: const Text('Power-Saver'),
                subtitle: const Text('≈ 50 mW, ~10 m CEP'),
                value: 'power_saver',
                groupValue: settings.mode,
                onChanged: _onModeChanged,
              ),
              RadioListTile<String>(
                title: const Text('Balanced'),
                subtitle: const Text('≈ 410 mW, ~3 m CEP'),
                value: 'balanced',
                groupValue: settings.mode,
                onChanged: _onModeChanged,
              ),
              RadioListTile<String>(
                title: const Text('High-Accuracy'),
                subtitle: const Text('≈ 2.2 W, ~1-2 m CEP'),
                value: 'high_accuracy',
                groupValue: settings.mode,
                onChanged: _onModeChanged,
              ),
              RadioListTile<String>(
                title: const Text('RTK'),
                subtitle: const Text('> 3 W, < 0.5 m CEP'),
                value: 'rtk',
                groupValue: settings.mode,
                onChanged: _onModeChanged,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Card #2: Custom Feature Toggles
        Card(
          child: Column(
            children: [
              const ListTile(
                title: Text('Custom Features'),
                subtitle: Text('Enable individually'),
              ),
              SwitchListTile(
                title: const Text('Multi-frequency GNSS'),
                subtitle: Text(supportsDualFreq
                    ? 'Uses both L1 and L5 bands'
                    : '❌ Not supported on this device'),
                value: settings.multiFrequency,
                onChanged: supportsDualFreq
                    ? (value) => ref
                        .read(gpsSettingsProvider.notifier)
                        .setMultiFrequency(value)
                    : null,
              ),
              SwitchListTile(
                title: const Text('Raw GNSS Measurements'),
                subtitle: Text(supportsRawMeasurements
                    ? 'For carrier-phase and RTK'
                    : '❌ Not supported on this device'),
                value: settings.rawMeasurements,
                onChanged: supportsRawMeasurements
                    ? (value) => ref
                        .read(gpsSettingsProvider.notifier)
                        .setRawMeasurements(value)
                    : null,
              ),
              SwitchListTile(
                title: const Text('Sensor Fusion'),
                subtitle: Text(supportsSensors
                    ? 'Combines GPS with IMU sensors'
                    : '❌ Not supported on this device'),
                value: settings.sensorFusion,
                onChanged: supportsSensors
                    ? (value) => ref
                        .read(gpsSettingsProvider.notifier)
                        .setSensorFusion(value)
                    : null,
              ),
              SwitchListTile(
                title: const Text('RTK Corrections'),
                subtitle: const Text('NTRIP correction streams'),
                value: settings.rtkCorrections,
                onChanged: (value) => ref
                    .read(gpsSettingsProvider.notifier)
                    .setRtkCorrections(value),
              ),
              SwitchListTile(
                title: const Text('External GNSS Receiver'),
                subtitle: const Text('Connect via Bluetooth'),
                value: settings.externalReceiver,
                onChanged: (value) => ref
                    .read(gpsSettingsProvider.notifier)
                    .setExternalReceiver(value),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Card #3: Custom Trade-off Slider
        Card(
          child: Column(
            children: [
              const ListTile(
                title: Text('Custom Trade-off'),
                subtitle: Text('Battery vs. Accuracy'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.battery_full,
                      color: Colors.green,
                    ),
                    Expanded(
                      child: Slider(
                        value: settings.customLevel,
                        min: 0,
                        max: 1,
                        divisions: 10,
                        label:
                            settings.customLevel < 0.5 ? 'Battery' : 'Accuracy',
                        onChanged: (value) {
                          ref
                              .read(gpsSettingsProvider.notifier)
                              .setCustomLevel(value);
                        },
                      ),
                    ),
                    const Icon(
                      Icons.gps_fixed,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Energy Saving',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${(settings.customLevel * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'High Precision',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Card #4: GPS Field Test
        const GpsValidationCard(),
      ],
    );
  }
}
