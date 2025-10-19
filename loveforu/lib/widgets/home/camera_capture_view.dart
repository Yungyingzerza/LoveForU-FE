import 'dart:async';

import 'package:flutter/material.dart';

/// Foreground camera UI inspired by Locket-style apps.
class CameraCaptureView extends StatelessWidget {
  const CameraCaptureView({
    super.key,
    required this.avatarImage,
    required this.friendsLabel,
    required this.preview,
    required this.onProfileTap,
    required this.onMessagesTap,
    required this.onGalleryTap,
    required this.onShutterTap,
    required this.onHistoryTap,
    required this.historyImage,
    required this.onFriendFilterTap,
    this.onReplyWithPhoto,
    this.historyLabel = 'History',
  });

  final ImageProvider? avatarImage;
  final String friendsLabel;
  final Widget preview;
  final VoidCallback onProfileTap;
  final VoidCallback onMessagesTap;
  final FutureOr<void> Function() onGalleryTap;
  final Future<void> Function()? onShutterTap;
  final FutureOr<void> Function()? onReplyWithPhoto;
  final VoidCallback onHistoryTap;
  final ImageProvider? historyImage;
  final String historyLabel;
  final VoidCallback onFriendFilterTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTopBar(),
        const SizedBox(height: 16),
        _buildPreview(),
        const SizedBox(height: 16),
        _buildBottomSection(),
      ],
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onProfileTap,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white24,
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(Icons.person_outline, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(40),
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: onFriendFilterTap,
              child: Container(
                constraints: const BoxConstraints(minWidth: 160, minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.group_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        friendsLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: Colors.white12,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onMessagesTap,
                child: const Center(
                  child: Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: preview,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        _buildControlsRow(),
        const SizedBox(height: 16),
        _buildHistoryPill(),
        const SizedBox(height: 8),
        const Icon(Icons.expand_more, size: 28, color: Colors.white70),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildControlsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSquareButton(
          onTap: onGalleryTap,
          icon: Icons.image_outlined,
        ),
        const SizedBox(width: 32),
        _buildShutterButton(),
        const SizedBox(width: 32),
        _buildSquareButton(
          onTap: onReplyWithPhoto ?? onHistoryTap,
          icon: onReplyWithPhoto == null
              ? Icons.history
              : Icons.reply_outlined,
        ),
      ],
    );
  }

  Widget _buildHistoryPill() {
    return GestureDetector(
      onTap: onHistoryTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white30,
              backgroundImage: historyImage,
              child: historyImage == null
                  ? const Icon(Icons.browse_gallery, color: Colors.white70)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              historyLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    final isDisabled = onShutterTap == null;
    return GestureDetector(
      onTap: isDisabled ? null : () => onShutterTap?.call(),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDisabled ? Colors.white30 : Colors.white,
            width: 6,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDisabled ? Colors.white12 : Colors.white,
          ),
          child: isDisabled
              ? const Icon(Icons.hourglass_top,
                  color: Colors.white54, size: 28)
              : null,
        ),
      ),
    );
  }

  Widget _buildSquareButton({
    required FutureOr<void> Function() onTap,
    required IconData icon,
  }) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onTap(),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
