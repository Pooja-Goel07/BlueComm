# BlueComm — Setup & Run Instructions

## 1. Add Dependencies to `pubspec.yaml`

Add the following under the `dependencies:` section in your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_bluetooth_serial: ^0.4.0
  permission_handler: ^11.0.0
```

Then run in terminal:

```bash
flutter pub get
```

---

## 2. Android Manifest — Bluetooth Permissions

Add the following permissions **inside** the `<manifest>` tag in `android/app/src/main/AndroidManifest.xml`, **before** the `<application>` tag:

```xml
<!-- Legacy Bluetooth permissions (Android 8–11) -->
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>

<!-- Modern Bluetooth permissions (Android 12+) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>

<!-- Declare Bluetooth hardware requirement -->
<uses-feature android:name="android.hardware.bluetooth" android:required="true"/>
```

---

## 3. Build Gradle — SDK Versions

In `android/app/build.gradle`, update the `defaultConfig` block:

```gradle
defaultConfig {
    applicationId = "com.example.bluecomm"
    minSdk = 26
    targetSdk = 34
    versionCode = flutter.versionCode
    versionName = flutter.versionName
}
```

> **Note:** Only change `minSdk` and `targetSdk` values. Leave other AGP/Java/Kotlin settings as you have configured.

---

## 4. Run the App

> **⚠️ CRITICAL: Bluetooth Classic does NOT work on Android emulators.**  
> You MUST use a **physical Android device** connected via USB or wireless debugging.
> The emulator does not have a real Bluetooth radio — all connections will fail.

Connect a physical Android device and run:

```bash
flutter clean
flutter pub get
flutter run
```

Or build a debug APK to install on both devices:

```bash
flutter build apk --debug
```

The APK will be at `build/app/outputs/flutter-apk/app-debug.apk`.

---

## 5. Testing on Two Devices — BOTH Must Have App Open

> **⚠️ CRITICAL: Both devices MUST have the BlueComm app open and running.**  
> The app acts as both a server (listening for connections) and a client (connecting to peers).
> If the target device doesn't have the app open, there's nothing to accept the RFCOMM connection.

### Step-by-step:

1. **Install** the APK on **two** physical Android devices
2. **Pair** the devices via Android Bluetooth settings first
3. **Open BlueComm** on **BOTH** devices
4. On Device A — tap **"Scan for Devices"** → tap Device B in the paired list
5. Device B should automatically accept the connection and navigate to Chat
6. Type a message and tap **Send** — it appears on the other device in real time

### Important device settings:

- **Bluetooth** must be ON on both devices
- **Location Services** must be ON (required for BT discovery on Android)
- **Bluetooth permissions** must be GRANTED when the app asks
- Devices should be **within 10 meters** of each other
- Make sure devices are **paired** in Android Bluetooth settings before using the app

---

## 6. How Connection Works (Technical)

The app uses a **3-tier RFCOMM connection fallback** via native platform channels:

1. **Standard SPP** — `createRfcommSocketToServiceRecord(SPP_UUID)` 
2. **Reflection fallback** — `createRfcommSocket(1)` (bypasses SDP lookup)
3. **Insecure SPP** — `createInsecureRfcommSocketToServiceRecord(SPP_UUID)`

Additionally, the app runs a **server socket** in the background that listens for incoming connections on the SPP UUID. This means:
- Device A connects → Device B's server socket accepts automatically
- The connection is bidirectional once established

---

## 7. Troubleshooting

| Issue | Solution |
|-------|---------|
| `flutter pub get` fails | Ensure you have stable internet and Flutter SDK 3.x installed |
| `Namespace not specified` build error | Already fixed in `android/build.gradle`. Run `flutter clean` first. |
| Permissions not appearing | Verify permissions in `AndroidManifest.xml` and rebuild |
| `read failed, socket might closed` | Ensure the **other device has the app open**. Also try unpairing and re-pairing |
| Connection fails on emulator | **Bluetooth Classic doesn't work on emulators.** Use physical devices |
| Connection keeps timing out | Toggle Bluetooth OFF→ON on both devices, then retry |
| App crashes on launch | Ensure `minSdk = 26` in `build.gradle` |
| Scan finds no devices | Enable **Location services** on the device |
| One device connects but the other doesn't navigate | Both devices must have the app open before connecting |

---

## 8. Project Directory Structure

```
bluecomm/
├── android/
│   └── app/
│       ├── build.gradle                         ← SDK version config
│       └── src/main/
│           ├── AndroidManifest.xml              ← Bluetooth permissions
│           └── kotlin/.../MainActivity.kt       ← Native RFCOMM handler
├── lib/
│   ├── main.dart                                ← App entry point
│   ├── models/
│   │   └── chat_message.dart                    ← ChatMessage data class
│   ├── services/
│   │   ├── permission_handler_service.dart       ← Permission management
│   │   ├── bluetooth_manager.dart                ← Bluetooth adapter control
│   │   ├── connection_manager.dart               ← RFCOMM state machine
│   │   ├── messaging_module.dart                 ← Send/receive messaging
│   │   └── rfcomm_channel.dart                   ← Native platform channel bridge
│   ├── screens/
│   │   ├── device_discovery_screen.dart           ← Screen 1: Discovery
│   │   └── chat_screen.dart                       ← Screen 2: Chat
│   └── widgets/
│       ├── device_list_tile.dart                  ← Device list item widget
│       └── message_bubble.dart                    ← Chat bubble widget
├── pubspec.yaml                                   ← Dependencies
└── instructions.md                                ← This file
```
