import 'package:flutter/material.dart';

import 'package:loveforu/services/chat_api_service.dart';
import 'package:loveforu/utils/display_utils.dart';

class ThreadTile extends StatelessWidget {
  const ThreadTile({
    super.key,
    required this.thread,
    required this.onTap,
  });

  final ChatThreadSummary thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String subtitle = thread.lastMessagePreview?.trim().isNotEmpty == true
        ? thread.lastMessagePreview!.trim()
        : thread.lastMessageId != null
            ? 'Photo shared'
            : 'Say hello';
    final DateTime lastActivity = thread.lastMessageAt ?? thread.createdAt;
    final String timeLabel = formatRelativeTime(lastActivity);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1F39).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  backgroundImage: thread.friendPictureUrl.isNotEmpty
                      ? NetworkImage(thread.friendPictureUrl)
                      : null,
                  child: thread.friendPictureUrl.isEmpty
                      ? const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 22,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.friendDisplayName.isNotEmpty
                            ? thread.friendDisplayName
                            : thread.friendUserId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
