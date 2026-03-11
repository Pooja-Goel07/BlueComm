// lib/main.dart
// Application entry point for BlueComm — Bluetooth Classic Messaging System.
// Sets up the MaterialApp with a dark blue/teal theme and routes to DeviceDiscoveryScreen.

import 'package:flutter/material.dart';
import 'screens/device_discovery_screen.dart';

void main() {
  // Ensure Flutter bindings are initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BlueCommApp());
}

class BlueCommApp extends StatelessWidget {
  const BlueCommApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueComm',
      debugShowCheckedModeBanner: false,

      // Dark theme with blue/teal accent for a modern messaging app look.
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1), // Deep blue seed.
          brightness: Brightness.dark,
        ),

        // Use Material 3 design system.
        useMaterial3: true,

        // App bar styling — slightly transparent with centered title.
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),

        // Card styling for device list tiles.
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        // Input field styling with rounded borders.
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),

        // Elevated button styling.
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      // Home route — Device Discovery Screen is the initial screen.
      home: const DeviceDiscoveryScreen(),
    );
  }
}
