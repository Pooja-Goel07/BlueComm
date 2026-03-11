// lib/models/chat_message.dart
// Core data transfer object for the messaging subsystem.
// Represents a single text message exchanged over the RFCOMM socket.

class ChatMessage {
  // The UTF-8 text content of the message.
  final String messageText;

  // True if this message was sent by the local user, false if received from the peer.
  final bool isSentByUser;

  // Timestamp of when the message was created (runtime only, not persisted).
  final DateTime timestamp;

  ChatMessage({
    required this.messageText,
    required this.isSentByUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // Returns the text content of this message.
  String getMessage() => messageText;

  // Returns true if this message originated from the local user.
  bool isFromUser() => isSentByUser;
}
