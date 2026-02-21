import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/chat/providers/chat_provider.dart';
import 'package:jirisewa_mobile/features/chat/widgets/message_bubble.dart';

/// Chat screen with realtime messages, text/image/location sending, and
/// auto-scroll. Uses Supabase Realtime via [messagesProvider].
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  /// Marks the conversation as read and invalidates related providers so that
  /// the conversations list and unread badge update accordingly.
  Future<void> _markRead() async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    final repo = ref.read(chatRepositoryProvider);
    try {
      await repo.markConversationRead(widget.conversationId, profile.id);
      ref.invalidate(conversationsProvider);
      ref.invalidate(unreadChatCountProvider);
    } catch (_) {
      // Non-critical — silently ignore mark-read failures.
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.sendMessage(widget.conversationId, profile.id, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImageMessage() async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (picked == null) return;

    setState(() => _isSending = true);

    try {
      final Uint8List bytes = await picked.readAsBytes();

      // Determine file extension from the picked file name.
      final ext = picked.name.split('.').last.toLowerCase();
      final extension = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)
          ? ext
          : 'jpg';

      final repo = ref.read(chatRepositoryProvider);
      final imageUrl = await repo.uploadChatImage(
        profile.id,
        bytes,
        extension: extension,
      );

      await repo.sendMessage(
        widget.conversationId,
        profile.id,
        imageUrl,
        messageType: 'image',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendLocationMessage() async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    setState(() => _isSending = true);

    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.sendMessage(
        widget.conversationId,
        profile.id,
        'Location shared',
        messageType: 'location',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share location: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final profile = ref.watch(userProfileProvider);
    final currentUserId = profile?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Failed to load messages: $error'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(
                          messagesProvider(widget.conversationId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (messages) {
                // Auto-scroll when new messages arrive.
                _scrollToBottom();

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet. Start the conversation!',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return MessageBubble(
                      message: message,
                      isCurrentUser: message.senderId == currentUserId,
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          // Image button
          IconButton(
            onPressed: _isSending ? null : _sendImageMessage,
            icon: const Icon(Icons.image),
            color: AppColors.primary,
            tooltip: 'Send image',
          ),

          // Location button
          IconButton(
            onPressed: _isSending ? null : _sendLocationMessage,
            icon: const Icon(Icons.location_on),
            color: AppColors.primary,
            tooltip: 'Share location',
          ),

          // Text field
          Expanded(
            child: TextField(
              controller: _textController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTextMessage(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.muted,
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Send button
          if (_isSending)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textController,
              builder: (context, value, child) {
                final hasText = value.text.trim().isNotEmpty;
                return IconButton(
                  onPressed: hasText ? _sendTextMessage : null,
                  icon: const Icon(Icons.send),
                  color: AppColors.primary,
                  tooltip: 'Send',
                );
              },
            ),
        ],
      ),
    );
  }
}
