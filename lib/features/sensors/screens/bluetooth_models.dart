import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Connection states for better UI feedback
enum DeviceConnectionState {
  disconnected,
  connecting,
  authenticating, // State for MTU negotiation phase
  connected,
  failed
}

/// Custom Connection priority levels
enum BleConnectionPriority {
  balanced, // Default
  high, // High priority, lower latency
  lowPower // Low power mode
}

/// Extended device info class to store additional data
class ExtendedDeviceInfo {
  final BluetoothDevice device;
  final String cachedName;
  final int lastConnected;

  ExtendedDeviceInfo(
      {required this.device,
      required this.cachedName,
      required this.lastConnected});
}

/// Extension method for BluetoothDevice to add requestConnectionPriority functionality
extension BluetoothDeviceExtension on BluetoothDevice {
  /// Request a specific connection priority for better latency/throughput
  Future<void> requestCustomConnectionPriority(
      BleConnectionPriority priority) async {
    try {
      // Convert priority to appropriate integer value
      int priorityValue;
      switch (priority) {
        case BleConnectionPriority.high:
          priorityValue = 1; // HIGH
          break;
        case BleConnectionPriority.lowPower:
          priorityValue = 2; // LOW_POWER
          break;
        case BleConnectionPriority.balanced:
          priorityValue = 0; // BALANCED
          break;
      }

      // For now, just log that we requested this priority
      // In a complete implementation, this would call native code via method channels
      debugPrint(
          'Requested connection priority: $priority ($priorityValue) for device: ${remoteId.str}');

      // If your version of flutter_blue_plus supports this, you'd implement it like:
      // await _methodChannel.invokeMethod(
      //   'requestConnectionPriority',
      //   {'deviceId': remoteId.str, 'connectionPriority': priorityValue}
      // );
    } catch (e) {
      debugPrint('Error requesting connection priority: $e');
    }
  }
}
