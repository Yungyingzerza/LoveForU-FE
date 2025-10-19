import 'package:flutter/material.dart';

import 'package:loveforu/controllers/chat_conversation_controller.dart';
import 'package:loveforu/services/chat_api_service.dart';

class ConversationMessagesList extends StatelessWidget {
  const ConversationMessagesList({
    super.key,
    required this.controller,
    required this.currentUserId,
    required this.friendPictureUrl,
    required this.photoResolver,
  });

  final ChatConversationController controller;
  final String currentUserId;
  final String friendPictureUrl;
  final String Function(String) photoResolver;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (controller.messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        children: const [
          SizedBox(height: 160),
          Center(
            child: Text(
              'No messages yet. Say hi!',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: controller.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      itemCount: controller.messages.length,
      itemBuilder: (context, index) {
        final message = controller.messages[index];
        final isSelf = message.senderId == currentUserId;
        final showTimestamp = index == controller.messages.length - 1 ||
            controller.messages[index + 1].senderId != message.senderId;
        final avatarUrl = message.senderPictureUrl.isNotEmpty
            ? message.senderPictureUrl
            : friendPictureUrl;
        return ConversationMessageBubble(
          message: message,
          isSelf: isSelf,
          showTimestamp: showTimestamp,
          senderAvatarUrl: avatarUrl,
          photoResolver: photoResolver,
        );
      },
    );
  }
}

class ConversationMessageBubble extends StatelessWidget {
  const ConversationMessageBubble({
    super.key,
    required this.message,
    required this.isSelf,
    required this.showTimestamp,
    required this.senderAvatarUrl,
    required this.photoResolver,
  });

  final ChatMessageDto message;
  final bool isSelf;
  final bool showTimestamp;
  final String senderAvatarUrl;
  final String Function(String) photoResolver;

  @override
  Widget build(BuildContext context) {
    final alignment =
        isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isSelf
        ? const LinearGradient(
            colors: [Color(0xFF5B7CF7), Color(0xFF8A66F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF152241), Color(0xFF0F1B33)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    return Padding(
      padding: EdgeInsets.only(
        top: 8,
        bottom: showTimestamp ? 12 : 4,
        left: isSelf ? 60 : 16,
        right: isSelf ? 16 : 60,
      ),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment:
                isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isSelf ? 18 : 18),
                      bottomRight: Radius.circular(isSelf ? 18 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _BubbleContent(
                    message: message,
                    isSelf: isSelf,
                    photoResolver: photoResolver,
                  ),
                ),
              ),
            ],
          ),
          if (showTimestamp)
            Padding(
              padding: EdgeInsets.only(
                top: 6,
                left: isSelf ? 0 : 0,
                right: isSelf ? 0 : 0,
              ),
              child: Text(
                _formatTimestamp(context, message.createdAt),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatTimestamp(BuildContext context, DateTime timestamp) {
    final local = timestamp.toLocal();
    final materialLocalizations = MaterialLocalizations.of(context);
    final timeOfDay = TimeOfDay(hour: local.hour, minute: local.minute);
    final formattedTime = materialLocalizations.formatTimeOfDay(
      timeOfDay,
      alwaysUse24HourFormat: true,
    );
    final now = DateTime.now();
    final isSameDay =
        local.year == now.year && local.month == now.month && local.day == now.day;
    if (isSameDay) {
      return formattedTime;
    }
    return '${local.month}/${local.day} $formattedTime';
  }
}

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({
    required this.message,
    required this.isSelf,
    required this.photoResolver,
  });

  final ChatMessageDto message;
  final bool isSelf;
  final String Function(String) photoResolver;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    final String? text = message.content?.trim();
    if (text != null && text.isNotEmpty) {
      children.add(
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.25,
          ),
        ),
      );
    }

    final photo = message.photo;
    if (photo != null && photo.imageUrl.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 8));
      }
      final resolvedUrl = photoResolver(photo.imageUrl);
      children.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 280,
              minWidth: 120,
              maxHeight: 320,
            ),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
      );

      final caption = photo.caption?.trim();
      if (caption != null && caption.isNotEmpty) {
        children.add(const SizedBox(height: 6));
        children.add(
          Text(
            caption,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        );
      }
    }

    if (children.isEmpty) {
      final fallback = _fallbackText(message);
      children.add(
        Text(
          fallback,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.25,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  static String _fallbackText(ChatMessageDto message) {
    final content = message.content?.trim();
    if (content != null && content.isNotEmpty) {
      return content;
    }
    final caption = message.photo?.caption?.trim();
    if (caption != null && caption.isNotEmpty) {
      return caption;
    }
    if (message.photo != null || message.photoShareId != null) {
      return 'Shared a photo';
    }
    return '(no content)';
  }
}
