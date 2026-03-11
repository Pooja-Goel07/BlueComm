// lib/widgets/message_bubble.dart
// Reusable chat bubble widget for displaying messages in the chat screen.
// Sent messages are right-aligned (blue), received messages are left-aligned (grey).

import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  // The ChatMessage to render.
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // Determine alignment and colors based on message origin.
    final isSent = message.isSentByUser;
    final alignment = isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isSent
        ? Theme.of(context).colorScheme.primary
        : Colors.grey[800];
    final textColor = Colors.white;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      // Sent messages have a sharp bottom-right corner; received have sharp bottom-left.
      bottomLeft: isSent ? const Radius.circular(16) : Radius.zero,
      bottomRight: isSent ? Radius.zero : const Radius.circular(16),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              // Limit bubble width to 75% of screen width for readability.
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message text content.
                Text(
                  message.messageText,
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
                const SizedBox(height: 4),
                // Timestamp displayed below the message text.
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Formats a DateTime to HH:MM string for display.
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
