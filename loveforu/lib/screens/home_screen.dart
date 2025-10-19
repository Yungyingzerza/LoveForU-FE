import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:loveforu/controllers/home_controller.dart';
import 'package:loveforu/services/friend_api_service.dart';
import 'package:loveforu/services/photo_api_service.dart';
import 'package:loveforu/utils/display_utils.dart';
import 'package:loveforu/widgets/common/app_gradient_scaffold.dart';
import 'package:loveforu/widgets/home/camera_capture_view.dart';
import 'package:loveforu/widgets/home/friendship_center_sheet.dart';
import 'package:loveforu/widgets/home/login_call_to_action.dart';
import 'package:loveforu/widgets/home/login_placeholder.dart';
import 'package:loveforu/widgets/home/photo_feed_preview.dart';
import 'package:loveforu/widgets/home/photo_list_tile.dart';

import 'chat_threads_screen.dart';
import 'upload_screen.dart';

class _FriendFilterOption {
  const _FriendFilterOption({required this.id, required this.label});

  final String? id;
  final String label;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final bool isLoggedIn = _controller.userId.isNotEmpty;

        return AppGradientScaffold(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          body: isLoggedIn
              ? _buildLoggedInLayout(context)
              : _buildLoggedOutLayout(context),
        );
      },
    );
  }

  Widget _buildLoggedInLayout(BuildContext context) {
    final List<PhotoResponse> visiblePhotos = _controller.visiblePhotos;
    final PhotoResponse? latestPhoto = visiblePhotos.isNotEmpty
        ? visiblePhotos.first
        : null;
    final String friendFilterLabel = _controller.currentFriendFilterLabel();
    final String placeholderMessage =
        _controller.selectedFriendUserId == null ||
            _controller.selectedFriendUserId!.isEmpty
        ? 'Share a moment with friends.'
        : _controller.selectedFriendUserId == _controller.userId
        ? 'You have not shared a photo yet.'
        : 'No photos from $friendFilterLabel yet.';
    final Widget previewWidget = visiblePhotos.isNotEmpty
        ? PhotoFeedPreview(
            photos: visiblePhotos,
            resolvePhotoUrl: resolvePhotoUrl,
            onActivePhotoChanged: _controller.updateActivePhoto,
            onRefresh: _controller.refreshHome,
          )
        : _buildPreviewPlaceholder(message: placeholderMessage);
    final ImageProvider? historyImage = latestPhoto != null
        ? NetworkImage(resolvePhotoUrl(latestPhoto.imageUrl))
        : null;
    final ImageProvider? avatarImage = _controller.pictureUrl.isNotEmpty
        ? NetworkImage(_controller.pictureUrl)
        : null;
    final String friendsLabel = 'Viewing: $friendFilterLabel';
    final PhotoResponse? activePhoto = _controller.activePreviewPhoto;
    FriendListItem? friendForReply;
    if (activePhoto != null &&
        activePhoto.uploaderId.isNotEmpty &&
        activePhoto.uploaderId != _controller.userId) {
      for (final friend in _controller.friends) {
        if (friend.friendUserId == activePhoto.uploaderId) {
          friendForReply = friend;
          break;
        }
      }
    }
    FutureOr<void> Function()? replyAction;
    if (!_controller.isReplyingWithPhoto &&
        _controller.userId.isNotEmpty &&
        activePhoto != null &&
        friendForReply != null) {
      replyAction = () => _replyWithPhoto(activePhoto, friendForReply!);
    }

    return Column(
      children: [
        Expanded(
          child: CameraCaptureView(
            avatarImage: avatarImage,
            friendsLabel: friendsLabel,
            preview: previewWidget,
            onProfileTap: _showUserMenu,
            onMessagesTap: _openChatThreads,
            historyImage: historyImage,
            onGalleryTap: _pickImageFromGallery,
            onShutterTap: _controller.isLoadingPhotos
                ? null
                : () => _openUploadScreen(),
            onReplyWithPhoto: replyAction,
            onHistoryTap: () => _showGallery(context),
            onFriendFilterTap: _showFriendFilter,
          ),
        ),
        if (_controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              _controller.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
      ],
    );
  }

  Widget _buildLoggedOutLayout(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LoginCallToAction(
          onLogin: _controller.login,
          isLoading:
              _controller.isAuthenticating || _controller.isRestoringSession,
        ),
        const SizedBox(height: 32),
        const LoginPlaceholder(),
        if (_controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _controller.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewPlaceholder({
    String message = 'Capture your first moment',
  }) {
    return Container(
      color: Colors.white10,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            color: Colors.white38,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    final result = await _controller.pickImageFromGallery();
    if (!mounted) return;
    if (result.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.errorMessage!)));
      return;
    }
    final file = result.file;
    if (file == null) {
      return;
    }
    await _openUploadScreen(initialFile: file);
  }

  Future<void> _openUploadScreen({XFile? initialFile}) async {
    final photo = await Navigator.of(context).push<PhotoResponse>(
      MaterialPageRoute(
        builder: (_) => UploadScreen(
          photoApiService: _controller.photoApiService,
          initialFile: initialFile,
          friends: _controller.friends,
        ),
      ),
    );

    if (photo == null || !mounted) {
      return;
    }

    await _controller.addUploadedPhoto(photo);
  }

  Future<void> _showGallery(BuildContext parentContext) async {
    final List<PhotoResponse> visiblePhotos = _controller.visiblePhotos;
    if (visiblePhotos.isEmpty) {
      ScaffoldMessenger.of(
        parentContext,
      ).showSnackBar(const SnackBar(content: Text('No photos to show yet.')));
      return;
    }

    await showModalBottomSheet<void>(
      context: parentContext,
      backgroundColor: const Color(0xFF0F1F39),
      isScrollControlled: true,
      builder: (modalContext) {
        final titleText = _controller.selectedFriendUserId == null
            ? 'Latest photos'
            : _controller.selectedFriendUserId == _controller.userId
            ? 'Your photos'
            : 'Photos from ${_controller.currentFriendFilterLabel()}';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  titleText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: MediaQuery.of(modalContext).size.height * 0.45,
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: visiblePhotos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final photo = visiblePhotos[index];
                      final bool canDelete =
                          _controller.userId.isNotEmpty &&
                          photo.uploaderId == _controller.userId;
                      return PhotoListTile(
                        photo: photo,
                        canDelete: canDelete,
                        isDeleting: _controller.deletingPhotoId == photo.id,
                        onDelete: canDelete
                            ? () => _deletePhoto(photo, modalContext)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFriendFilter() async {
    if (_controller.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to choose whose photos to view.')),
      );
      return;
    }

    await _controller.refreshHome();
    if (!mounted) {
      return;
    }

    final List<_FriendFilterOption> options = <_FriendFilterOption>[
      const _FriendFilterOption(id: null, label: 'Everyone'),
      if (_controller.userId.isNotEmpty)
        _FriendFilterOption(
          id: _controller.userId,
          label: _controller.displayName.isNotEmpty
              ? _controller.displayName
              : 'Just me',
        ),
      ..._controller.friends.map(
        (friend) => _FriendFilterOption(
          id: friend.friendUserId,
          label: friend.displayName.isNotEmpty
              ? friend.displayName
              : friend.friendUserId,
        ),
      ),
    ];

    final String? initialSelection = _controller.selectedFriendUserId;

    final String? selectedId = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: const Color(0xFF0F1F39),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'View photos from',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final option = options[index];
                      final bool isSelected =
                          option.id == initialSelection ||
                          (option.id == null && initialSelection == null);
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: isSelected
                            ? Colors.white12
                            : Colors.transparent,
                        leading: Icon(
                          option.id == null
                              ? Icons.public
                              : option.id == _controller.userId
                              ? Icons.person_outline
                              : Icons.person,
                          color: Colors.white,
                        ),
                        title: Text(
                          option.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                        onTap: () => Navigator.of(modalContext).pop(option.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    if (selectedId == initialSelection) {
      return;
    }

    _controller.selectFriend(selectedId);
  }

  Future<void> _promptAddFriend() async {
    String pendingFriendUserId = '';
    final String? friendUserId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add friend'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'LINE user ID',
              hintText: 'Uxxxxxxxxxxxxxxxxxxxx',
            ),
            onChanged: (value) {
              pendingFriendUserId = value.trim();
            },
            onSubmitted: (value) {
              pendingFriendUserId = value.trim();
              Navigator.of(dialogContext).pop(pendingFriendUserId);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();
                Navigator.of(dialogContext).pop(pendingFriendUserId);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (friendUserId == null || friendUserId.isEmpty || !mounted) {
      return;
    }

    final result = await _controller.addFriend(friendUserId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _replyWithPhoto(
    PhotoResponse photo,
    FriendListItem friend,
  ) async {
    final String? messageContent = await _promptPhotoReplyMessage(friend);
    if (messageContent == null) {
      return;
    }

    final result = await _controller.replyWithPhoto(
      photo: photo,
      friend: friend,
      messageContent: messageContent,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<String?> _promptPhotoReplyMessage(FriendListItem friend) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1F39),
          title: Text(
            'Reply to ${friend.displayName.isNotEmpty ? friend.displayName : friend.friendUserId}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add a message (optional)',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                autofocus: true,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Say something about the photo…',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    return result;
  }

  Future<void> _deletePhoto(
    PhotoResponse photo,
    BuildContext modalContext,
  ) async {
    final navigator = Navigator.of(modalContext);
    final messenger = ScaffoldMessenger.of(context);

    final bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F1F39),
              title: const Text(
                'Delete photo?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: const Text(
                'This removes the photo for everyone and detaches it from chats.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirm) {
      return;
    }

    final result = await _controller.deletePhoto(photo);
    if (!mounted) return;
    if (navigator.mounted && navigator.canPop()) {
      navigator.pop();
    }
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  void _showFriendRequests() {
    if (_controller.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to manage friend requests.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1F39),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SizedBox(
              height: MediaQuery.of(modalContext).size.height * 0.65,
              child: FriendshipCenterSheet(
                friendApiService: _controller.friendApiService,
                currentUserId: _controller.userId,
                onFriendshipUpdated: () => _controller.refreshHome(),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showUserMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1F39),
      builder: (modalContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white24,
                  backgroundImage: _controller.pictureUrl.isNotEmpty
                      ? NetworkImage(_controller.pictureUrl)
                      : null,
                  child: _controller.pictureUrl.isEmpty
                      ? const Icon(Icons.person_outline, color: Colors.white)
                      : null,
                ),
                title: Text(
                  _controller.displayName.isNotEmpty
                      ? _controller.displayName
                      : 'Anonymous',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _controller.userId,
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _controller.userId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User ID copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Copy User ID',
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                ),
                title: const Text(
                  'Chats',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  _openChatThreads();
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.white),
                title: const Text(
                  'Refresh profile',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  _controller.refreshProfile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt, color: Colors.white),
                title: const Text(
                  'Add friend',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  _promptAddFriend();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.group_add_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'Friend requests',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  _showFriendRequests();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  _controller.logout();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openChatThreads() async {
    if (_controller.userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login to open chats.')));
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadsScreen(
          chatApiService: _controller.chatApiService,
          currentUserId: _controller.userId,
          friendApiService: _controller.friendApiService,
        ),
      ),
    );
  }
}
