import 'package:flutter/material.dart';

/// Foreground camera UI inspired by Locket-style apps.
class PuppyCamScreen extends StatelessWidget {
  const PuppyCamScreen({
    super.key,
    required this.avatarImage,
    required this.friendsLabel,
    required this.preview,
    required this.onMessages,
    required this.onGallery,
    required this.onShutter,
    required this.onSwitchCamera,
    required this.onHistory,
    required this.historyImage,
    this.historyLabel = 'History',
  });

  final ImageProvider? avatarImage;
  final String friendsLabel;
  final Widget preview;
  final VoidCallback onMessages;
  final VoidCallback onGallery;
  final Future<void> Function()? onShutter;
  final VoidCallback onSwitchCamera;
  final VoidCallback onHistory;
  final ImageProvider? historyImage;
  final String historyLabel;

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
          Container(
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
          Container(
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
                Text(
                  friendsLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
                onTap: () {
                  debugPrint('Messages');
                  onMessages();
                },
                child: const Center(
                  child:
                      Icon(Icons.chat_bubble_outline, color: Colors.white, size: 22),
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
          onTap: () {
            debugPrint('Gallery');
            onGallery();
          },
          icon: Icons.image_outlined,
        ),
        const SizedBox(width: 28),
        _buildShutterButton(),
        const SizedBox(width: 28),
        _buildSquareButton(
          onTap: () {
            debugPrint('Switch Camera');
            onSwitchCamera();
          },
          icon: Icons.cameraswitch_outlined,
        ),
      ],
    );
  }

  Widget _buildSquareButton({required VoidCallback onTap, required IconData icon}) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    return SizedBox(
      width: 132,
      height: 132,
      child: Material(
        color: Colors.white10,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onShutter == null
              ? null
              : () async {
                  debugPrint('Shutter');
                  await onShutter!.call();
                },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 8),
            ),
            child: Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryPill() {
    return InkWell(
      onTap: () {
        debugPrint('History');
        onHistory();
      },
      borderRadius: BorderRadius.circular(40),
      child: Container(
        constraints: const BoxConstraints(minWidth: 190, minHeight: 46),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: historyImage != null
                  ? Image(
                      image: historyImage!,
                      width: 26,
                      height: 26,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 26,
                      height: 26,
                      color: Colors.white12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.photo_library_outlined,
                          color: Colors.white70, size: 18),
                    ),
            ),
            const SizedBox(width: 12),
            Text(
              historyLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
