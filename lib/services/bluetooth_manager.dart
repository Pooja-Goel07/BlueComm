// lib/services/bluetooth_manager.dart
// Wraps the flutter_bluetooth_serial adapter APIs for Bluetooth Classic operations.
// Provides adapter state checks, paired device retrieval, device discovery streaming,
// and a cancel method that also cancels via the global FlutterBluetoothSerial instance.

import 'dart:async';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothManager {
  // Singleton reference to the flutter_bluetooth_serial instance.
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  // Active discovery stream subscription, tracked for cancellation.
  StreamSubscription<BluetoothDiscoveryResult>? _discoverySubscription;

  // Returns the FlutterBluetoothSerial instance for direct access if needed.
  FlutterBluetoothSerial get instance => _bluetooth;

  // Checks whether the Bluetooth adapter is currently enabled on this device.
  Future<bool?> isEnabled() async {
    return await _bluetooth.isEnabled;
  }

  // Requests the user to enable the Bluetooth adapter via system dialog.
  // Returns true if Bluetooth was enabled successfully.
  Future<bool?> requestEnable() async {
    return await _bluetooth.requestEnable();
  }

  // Retrieves the list of previously bonded (paired) Bluetooth devices.
  // These devices can be connected to without a full discovery cycle.
  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await _bluetooth.getBondedDevices();
  }

  // Starts Bluetooth Classic device discovery and streams results in real time.
  // Each BluetoothDiscoveryResult contains a BluetoothDevice and RSSI value.
  // The onDevice callback fires for each discovered device.
  // The onFinished callback fires when the discovery cycle completes.
  void startDiscovery({
    required Function(BluetoothDiscoveryResult) onDevice,
    required Function() onFinished,
  }) {
    // Cancel any existing discovery before starting a new one.
    cancelDiscovery();

    _discoverySubscription = _bluetooth.startDiscovery().listen(
      (result) {
        onDevice(result);
      },
      onDone: () {
        onFinished();
      },
      onError: (error) {
        onFinished();
      },
    );
  }

  // Cancels an in-progress device discovery scan and releases the stream.
  // CRITICAL: Also cancels via the global FlutterBluetoothSerial API to ensure
  // the Android Bluetooth adapter fully stops scanning. Discovery interferes
  // with RFCOMM socket connections — must be fully stopped before connecting.
  Future<void> cancelDiscovery() async {
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    // Cancel at the adapter level to ensure the scan is fully stopped.
    try {
      await _bluetooth.cancelDiscovery();
    } catch (_) {
      // Ignore errors if discovery wasn't running.
    }
  }

  // Cleans up resources held by this manager.
  void dispose() {
    cancelDiscovery();
  }
}
