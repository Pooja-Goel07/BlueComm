// lib/services/rfcomm_channel.dart
// Platform channel bridge for native RFCOMM operations.
// Bypasses flutter_bluetooth_serial's connection logic to use the native
// 3-tier fallback (standard SPP → reflection channel 1 → insecure SPP)
// and server socket for accepting incoming connections.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RfcommChannel {
  // Method channel for connect/disconnect/send/server control.
  static const _methodChannel = MethodChannel('com.example.bluecomm/rfcomm');

  // Event channel for receiving data bytes from the native read thread.
  static const _dataChannel = EventChannel('com.example.bluecomm/rfcomm_data');

  // Event channel for incoming connection notifications from the server socket.
  static const _serverChannel = EventChannel('com.example.bluecomm/rfcomm_server');

  // Stream subscription for incoming data bytes.
  StreamSubscription? _dataSubscription;

  // Stream controller that re-broadcasts received bytes to the Dart layer.
  final _dataController = StreamController<Uint8List>.broadcast();

  // Public stream of received bytes for the MessagingModule to consume.
  Stream<Uint8List> get dataStream => _dataController.stream;

  // Stream subscription for incoming connection events.
  StreamSubscription? _serverSubscription;

  // Callback when an incoming connection is accepted by the server.
  Function(String address, String name)? onIncomingConnection;

  // Whether we are currently connected via the native channel.
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Initializes the data event channel listener and server listener.
  void initialize() {
    // Listen for incoming data bytes from the native read thread.
    _dataSubscription = _dataChannel
        .receiveBroadcastStream()
        .listen(
      (data) {
        if (data is List<int>) {
          _dataController.add(Uint8List.fromList(data));
        } else if (data is Uint8List) {
          _dataController.add(data);
        }
      },
      onError: (error) {
        debugPrint('BlueComm: Data stream error: $error');
        _isConnected = false;
        _dataController.addError(error);
      },
      onDone: () {
        debugPrint('BlueComm: Data stream closed (peer disconnected)');
        _isConnected = false;
      },
      cancelOnError: false,
    );

    // Listen for incoming connection events from the server socket.
    _serverSubscription = _serverChannel
        .receiveBroadcastStream()
        .listen(
      (event) {
        if (event is Map) {
          final address = event['address'] as String? ?? '';
          final name = event['name'] as String? ?? 'Unknown';
          debugPrint('BlueComm: Incoming connection from $name ($address)');
          _isConnected = true;

          // Re-initialize data listener for the new connection.
          _restartDataListener();

          onIncomingConnection?.call(address, name);
        }
      },
      onError: (error) {
        debugPrint('BlueComm: Server stream error: $error');
      },
      cancelOnError: false,
    );
  }

  // Re-subscribes to the data event channel after a new connection.
  void _restartDataListener() {
    _dataSubscription?.cancel();
    _dataSubscription = _dataChannel
        .receiveBroadcastStream()
        .listen(
      (data) {
        if (data is List<int>) {
          _dataController.add(Uint8List.fromList(data));
        } else if (data is Uint8List) {
          _dataController.add(data);
        }
      },
      onError: (error) {
        _isConnected = false;
        _dataController.addError(error);
      },
      onDone: () {
        _isConnected = false;
      },
      cancelOnError: false,
    );
  }

  // Connects to a device via the native 3-tier RFCOMM fallback.
  // Returns a map with 'connected', 'address', 'name' on success.
  Future<Map<String, dynamic>?> connect(String address) async {
    try {
      final result = await _methodChannel.invokeMethod('connect', {
        'address': address,
      });

      if (result != null && result is Map) {
        _isConnected = true;
        // Re-initialize data listener for the new connection.
        _restartDataListener();
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('BlueComm: Native connect failed: ${e.message}');
      _isConnected = false;
      return null;
    }
  }

  // Disconnects the active RFCOMM socket via the native layer.
  Future<void> disconnect() async {
    try {
      await _methodChannel.invokeMethod('disconnect');
    } catch (_) {}
    _isConnected = false;
  }

  // Sends raw bytes to the connected device via the native layer.
  Future<bool> send(Uint8List data) async {
    try {
      await _methodChannel.invokeMethod('send', {'data': data});
      return true;
    } on PlatformException catch (e) {
      debugPrint('BlueComm: Send failed: ${e.message}');
      return false;
    }
  }

  // Starts the native server socket to accept incoming RFCOMM connections.
  Future<bool> startServer() async {
    try {
      await _methodChannel.invokeMethod('startServer');
      return true;
    } on PlatformException catch (e) {
      debugPrint('BlueComm: Start server failed: ${e.message}');
      return false;
    }
  }

  // Stops the native server socket.
  Future<void> stopServer() async {
    try {
      await _methodChannel.invokeMethod('stopServer');
    } catch (_) {}
  }

  // Checks if the native socket is currently connected.
  Future<bool> checkConnected() async {
    try {
      final result = await _methodChannel.invokeMethod('isConnected');
      _isConnected = result == true;
      return _isConnected;
    } catch (_) {
      return false;
    }
  }

  // Releases all resources.
  void dispose() {
    _dataSubscription?.cancel();
    _serverSubscription?.cancel();
    _dataController.close();
  }
}
