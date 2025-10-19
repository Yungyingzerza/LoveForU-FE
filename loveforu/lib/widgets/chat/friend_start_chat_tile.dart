import 'package:flutter/material.dart';

import 'package:loveforu/services/friend_api_service.dart';

class FriendStartChatTile extends StatelessWidget {
  const FriendStartChatTile({
    super.key,
    required this.friend,
    required this.onStart,
    required this.isLoading,
  });

  final FriendListItem friend;
  final VoidCallback onStart;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final displayName =
        friend.displayName.isNotEmpty ? friend.displayName : friend.friendUserId;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isLoading ? null : onStart,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1F39).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white24,
                  backgroundImage: friend.pictureUrl.isNotEmpty
                      ? NetworkImage(friend.pictureUrl)
                      : null,
                  child: friend.pictureUrl.isEmpty
                      ? const Icon(Icons.person_outline, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to start a conversation',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
