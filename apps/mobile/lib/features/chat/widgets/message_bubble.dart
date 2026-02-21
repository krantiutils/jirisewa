import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/chat/models/chat_message.dart';

/// A single chat message bubble. Aligns right for the current user (blue
/// background) and left for other participants (gray background).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  final ChatMessage message;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final alignment =
        isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isCurrentUser ? AppColors.primary : AppColors.muted;
    final textColor = isCurrentUser ? Colors.white : AppColors.foreground;
    final timeColor =
        isCurrentUser ? Colors.white.withAlpha(180) : Colors.grey[500]!;

    // Rounded corners with one less-rounded corner on the sender's side.
    final borderRadius = isCurrentUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          );

    final timeFormatted = DateFormat.Hm().format(message.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: borderRadius,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _buildContent(textColor),
          ),
          const SizedBox(height: 2),
          Text(
            timeFormatted,
            style: TextStyle(fontSize: 11, color: timeColor),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color textColor) {
    switch (message.messageType) {
      case 'image':
        final uri = Uri.tryParse(message.content);
        final isValidUrl = uri != null &&
            uri.scheme == 'https' &&
            uri.host.endsWith('.supabase.co');
        if (!isValidUrl) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, color: textColor, size: 20),
              const SizedBox(width: 6),
              Text(
                'Image unavailable',
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ],
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.content,
            width: 240,
            height: 180,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const SizedBox(
                width: 240,
                height: 180,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return SizedBox(
                width: 240,
                height: 180,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: textColor, size: 32),
                      const SizedBox(height: 4),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

      case 'location':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: textColor, size: 20),
            const SizedBox(width: 6),
            Text(
              'Location shared',
              style: TextStyle(color: textColor, fontSize: 14),
            ),
          ],
        );

      default:
        return Text(
          message.content,
          style: TextStyle(color: textColor, fontSize: 14, height: 1.3),
        );
    }
  }
}
