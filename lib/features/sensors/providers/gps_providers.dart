// lib/features/sensors/providers/gps_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gps_service.dart';

// Provider for the GPS service
final gpsServiceProvider = Provider<GpsService>((ref) {
  return GpsService();
});

// Provider for GPS capabilities
final gpsCapabilitiesProvider = FutureProvider<Map<String, bool>>((ref) async {
  final gpsService = ref.watch(gpsServiceProvider);
  await gpsService.initialize();

  return {
    'dualFrequency': gpsService.supportsDualFrequency,
    'rawMeasurements': gpsService.supportsRawMeasurements,
    'multiConstellation': gpsService.supportsMultiConstellation,
    'inertialSensors': gpsService.hasInertialSensors,
  };
});

// Provider for GPS power estimates
final gpsPowerEstimatesProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final gpsService = ref.watch(gpsServiceProvider);
  return await gpsService.getCurrentPowerEstimates();
});

// Provider for GPS accuracy estimates
final gpsAccuracyEstimatesProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final gpsService = ref.watch(gpsServiceProvider);
  return await gpsService.getAccuracyEstimates();
});

// Provider for GPS settings state
final gpsSettingsProvider =
    StateNotifierProvider<GpsSettingsNotifier, GpsSettings>((ref) {
  return GpsSettingsNotifier(ref.watch(gpsServiceProvider));
});

// GPS settings state class
class GpsSettings {
  final String mode;
  final bool multiFrequency;
  final bool rawMeasurements;
  final bool sensorFusion;
  final bool rtkCorrections;
  final bool externalReceiver;
  final double customLevel;

  GpsSettings({
    required this.mode,
    required this.multiFrequency,
    required this.rawMeasurements,
    required this.sensorFusion,
    required this.rtkCorrections,
    required this.externalReceiver,
    required this.customLevel,
  });

  // Copy with method for updates
  GpsSettings copyWith({
    String? mode,
    bool? multiFrequency,
    bool? rawMeasurements,
    bool? sensorFusion,
    bool? rtkCorrections,
    bool? externalReceiver,
    double? customLevel,
  }) {
    return GpsSettings(
      mode: mode ?? this.mode,
      multiFrequency: multiFrequency ?? this.multiFrequency,
      rawMeasurements: rawMeasurements ?? this.rawMeasurements,
      sensorFusion: sensorFusion ?? this.sensorFusion,
      rtkCorrections: rtkCorrections ?? this.rtkCorrections,
      externalReceiver: externalReceiver ?? this.externalReceiver,
      customLevel: customLevel ?? this.customLevel,
    );
  }
}

// Notifier for GPS settings
class GpsSettingsNotifier extends StateNotifier<GpsSettings> {
  final GpsService _gpsService;

  GpsSettingsNotifier(this._gpsService)
      : super(GpsSettings(
          mode: 'balanced',
          multiFrequency: false,
          rawMeasurements: false,
          sensorFusion: true,
          rtkCorrections: false,
          externalReceiver: false,
          customLevel: 0.5,
        ));

  // Update mode
  Future<void> setMode(String mode) async {
    state = state.copyWith(mode: mode);
    await _applySettings();
  }

  // Update multiFrequency
  Future<void> setMultiFrequency(bool value) async {
    state = state.copyWith(multiFrequency: value);
    await _applySettings();
  }

  // Update rawMeasurements
  Future<void> setRawMeasurements(bool value) async {
    state = state.copyWith(rawMeasurements: value);
    await _applySettings();
  }

  // Update sensorFusion
  Future<void> setSensorFusion(bool value) async {
    state = state.copyWith(sensorFusion: value);
    await _applySettings();
  }

  // Update rtkCorrections
  Future<void> setRtkCorrections(bool value) async {
    state = state.copyWith(rtkCorrections: value);
    await _applySettings();
  }

  // Update externalReceiver
  Future<void> setExternalReceiver(bool value) async {
    state = state.copyWith(externalReceiver: value);
    await _applySettings();
  }

  // Update customLevel
  Future<void> setCustomLevel(double value) async {
    state = state.copyWith(customLevel: value);
    await _applySettings();
  }

  // Apply all settings
  Future<bool> _applySettings() async {
    return await _gpsService.applyGpsSettings(
      mode: state.mode,
      multiFrequency: state.multiFrequency,
      rawMeasurements: state.rawMeasurements,
      sensorFusion: state.sensorFusion,
      rtkCorrections: state.rtkCorrections,
      externalReceiver: state.externalReceiver,
      customLevel: state.customLevel,
    );
  }

  // Update based on preset mode
  Future<void> updateBasedOnPresetMode(String mode) async {
    // Set appropriate feature toggles based on mode
    switch (mode) {
      case 'power_saver':
        state = state.copyWith(
          mode: mode,
          multiFrequency: false,
          rawMeasurements: false,
          sensorFusion: false,
          rtkCorrections: false,
          customLevel: 0.0, // Full battery savings
        );
        break;
      case 'balanced':
        state = state.copyWith(
          mode: mode,
          multiFrequency: false,
          rawMeasurements: false,
          sensorFusion: true,
          rtkCorrections: false,
          customLevel: 0.5, // Balanced
        );
        break;
      case 'high_accuracy':
        state = state.copyWith(
          mode: mode,
          multiFrequency: true,
          rawMeasurements: false,
          sensorFusion: true,
          rtkCorrections: false,
          customLevel: 0.8, // Favor accuracy
        );
        break;
      case 'rtk':
        state = state.copyWith(
          mode: mode,
          multiFrequency: true,
          rawMeasurements: true,
          sensorFusion: true,
          rtkCorrections: true,
          customLevel: 1.0, // Maximum accuracy
        );
        break;
    }

    await _applySettings();
  }
}
