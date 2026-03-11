// lib/services/permission_handler_service.dart
// Abstracts all Android Bluetooth and location permission lifecycle management.
// Handles both legacy (API < 31) and modern (API 31+) permission models.

import 'package:permission_handler/permission_handler.dart';

class PermissionHandlerService {
  // List of permissions required for Bluetooth operations.
  List<Permission> permissions = [];

  // Requests all necessary Bluetooth and location permissions.
  // On Android 12+ (API 31+), BLUETOOTH_SCAN and BLUETOOTH_CONNECT are required.
  // On Android 8–11, BLUETOOTH and ACCESS_FINE_LOCATION are required.
  // Returns true if all permissions are granted, false otherwise.
  Future<bool> checkAndRequest() async {
    permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    // Request all permissions at once; the OS will skip already-granted ones.
    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // Return true only if every permission was granted.
    return statuses.values
        .every((status) => status == PermissionStatus.granted);
  }

  // Checks current status of all previously requested permissions.
  // Returns true only if all are currently granted.
  Future<bool> checkStatus() async {
    for (var permission in permissions) {
      if (await permission.status != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }
}
