// lib/widgets/device_list_tile.dart
// Reusable list item widget for displaying a Bluetooth device in the discovery list.
// Shows device name (or "Unknown Device"), address, and an optional paired indicator.

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class DeviceListTile extends StatelessWidget {
  // The Bluetooth device to display.
  final BluetoothDevice device;

  // Callback invoked when the user taps this tile to initiate connection.
  final VoidCallback onTap;

  // Whether this device is from the paired (bonded) devices list.
  final bool isPaired;

  const DeviceListTile({
    super.key,
    required this.device,
    required this.onTap,
    this.isPaired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        // Bluetooth icon with color indicating paired status.
        leading: Icon(
          isPaired ? Icons.bluetooth_connected : Icons.bluetooth,
          color: isPaired
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[400],
          size: 28,
        ),
        // Device name, defaulting to "Unknown Device" if null or empty.
        title: Text(
          device.name ?? 'Unknown Device',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        // Device MAC address shown as subtitle.
        subtitle: Text(
          device.address,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        // Paired badge shown on the trailing side.
        trailing: isPaired
            ? Chip(
                label: const Text(
                  'Paired',
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
