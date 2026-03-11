// lib/screens/chat_screen.dart
// Screen 2: Chat Screen — active for the duration of the messaging session.
// Displays messages via StreamBuilder, handles send/receive, disconnect, and reconnection banner.

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/connection_manager.dart';
import '../services/messaging_module.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  // Reference to the shared ConnectionManager holding the active RFCOMM socket.
  final ConnectionManager connectionManager;

  // Local display name set by the user on the Discovery Screen.
  final String displayName;

  const ChatScreen({
    super.key,
    required this.connectionManager,
    required this.displayName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Text controller for the message input field.
  final TextEditingController _messageController = TextEditingController();

  // Scroll controller for auto-scrolling to the latest message.
  final ScrollController _scrollController = ScrollController();

  // Messaging module initialized with the active RFCOMM socket.
  MessagingModule? _messagingModule;

  // Local copy of the message list for rendering.
  List<ChatMessage> _messages = [];

  // Current connection state, used for reconnection banner display.
  BtConnectionState _connectionState = BtConnectionState.connected;

  // Subscription to the connection manager's state stream.
  StreamSubscription<BtConnectionState>? _stateSubscription;

  // Subscription to the messaging module's message stream.
  StreamSubscription<ChatMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initMessaging();
    _listenToConnectionState();
  }

  // Initializes the MessagingModule with the native RfcommChannel from ConnectionManager.
  void _initMessaging() {
    _messagingModule = MessagingModule(
      widget.connectionManager.rfcommChannel,
      onDisconnected: _onPeerDisconnected,
    );

    // Listen for incoming messages and update the UI.
    _messageSubscription = _messagingModule!.messageStream.listen((message) {
      if (mounted) {
        setState(() {
          _messages = List.from(_messagingModule!.messageList);
        });
        _scrollToBottom();
      }
    });
  }

  // Subscribes to connection state changes for the reconnection banner.
  void _listenToConnectionState() {
    _stateSubscription = widget.connectionManager.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });

        // If fully disconnected after reconnection attempts, navigate back.
        if (state == BtConnectionState.disconnected) {
          _showSnackBar('Connection lost. Returning to device list.');
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    });
  }

  // Called when the peer's socket input stream closes unexpectedly.
  void _onPeerDisconnected() {
    if (mounted) {
      // Trigger reconnection attempts via ConnectionManager.
      widget.connectionManager.attemptReconnect();
    }
  }

  // Sends the current text in the input field as a message via the RFCOMM socket.
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _messagingModule == null) return;

    // Clear the input field immediately for responsiveness.
    _messageController.clear();

    await _messagingModule!.sendMessage(text);

    // Update the local message list for rendering.
    if (mounted) {
      setState(() {
        _messages = List.from(_messagingModule!.messageList);
      });
      _scrollToBottom();
    }
  }

  // Scrolls the message list to the bottom to show the latest message.
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Cleanly disconnects and navigates back to the Discovery Screen.
  void _disconnect() {
    _messagingModule?.dispose();
    widget.connectionManager.disconnect();
    Navigator.pop(context);
  }

  // Attempts a manual reconnection to the last connected device.
  void _manualReconnect() {
    final device = widget.connectionManager.connectedDevice;
    if (device != null) {
      widget.connectionManager.connectTo(device).then((_) {
        if (widget.connectionManager.currentState == BtConnectionState.connected) {
          // Re-initialize messaging with the new socket.
          _messagingModule?.dispose();
          _initMessaging();
        }
      });
    }
  }

  // Displays a brief message at the bottom of the screen.
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _stateSubscription?.cancel();
    _messageSubscription?.cancel();
    _messagingModule?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceName =
        widget.connectionManager.connectedDevice?.name ?? 'Unknown Device';

    return Scaffold(
      appBar: AppBar(
        // Connected device name displayed in the app bar.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deviceName, style: const TextStyle(fontSize: 16)),
            Text(
              _connectionState == BtConnectionState.connected
                  ? 'Connected'
                  : _connectionState.name,
              style: TextStyle(
                fontSize: 12,
                color: _connectionState == BtConnectionState.connected
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
              ),
            ),
          ],
        ),
        actions: [
          // Disconnect button in the app bar.
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            tooltip: 'Disconnect',
            onPressed: _disconnect,
          ),
        ],
      ),
      body: Column(
        children: [
          // Reconnection banner — shown when connectionState == reconnecting.
          if (_connectionState == BtConnectionState.reconnecting)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.amber.withOpacity(0.2),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Connection lost. Reconnecting... '
                      '(Attempt ${widget.connectionManager.reconnectAttempts}/${ConnectionManager.maxRetries})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: _manualReconnect,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),

          // Message list — main content area.
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet.\nSend a message to start chatting!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return MessageBubble(message: _messages[index]);
                    },
                  ),
          ),

          // Message input area — text field + send button.
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Text input field for composing messages.
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button — FAB style.
                  FloatingActionButton.small(
                    onPressed: _sendMessage,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
