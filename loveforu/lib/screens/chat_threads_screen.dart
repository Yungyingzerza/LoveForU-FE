import 'dart:async';

import 'package:flutter/material.dart';

import 'package:loveforu/services/chat_api_service.dart';
import 'package:loveforu/services/friend_api_service.dart';
import 'package:loveforu/theme/app_gradients.dart';
import 'package:loveforu/screens/chat_conversation_screen.dart';

class ChatThreadsScreen extends StatefulWidget {
  const ChatThreadsScreen({
    super.key,
    required this.chatApiService,
    required this.currentUserId,
    required this.friendApiService,
  });

  final ChatApiService chatApiService;
  final String currentUserId;
  final FriendApiService friendApiService;

  @override
  State<ChatThreadsScreen> createState() => _ChatThreadsScreenState();
}

class _ChatThreadsScreenState extends State<ChatThreadsScreen> {
  List<ChatThreadSummary> _threads = <ChatThreadSummary>[];
  ChatEventStream? _eventStream;
  bool _isLoading = true;
  bool _isFetching = false;
  String? _errorMessage;
  List<FriendListItem> _friends = <FriendListItem>[];
  bool _isLoadingFriends = true;
  String? _friendsError;
  String? _startingFriendshipId;

  @override
  void initState() {
    super.initState();
    _loadThreads();
    _loadFriends();
    _subscribeToEvents();
  }

  @override
  void dispose() {
    _eventStream?.close();
    super.dispose();
  }

  Future<void> _loadThreads({bool silent = false, bool force = false}) async {
    if (_isFetching) {
      if (!force) {
        return;
      }
      while (_isFetching) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    _isFetching = true;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final threads = await widget.chatApiService.getThreads();
      if (!mounted) {
        return;
      }
      threads.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      setState(() {
        _threads = threads;
        _isLoading = false;
      });
    } on ChatApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load conversations.';
      });
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _loadFriends({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoadingFriends = true;
        _friendsError = null;
      });
    }
    try {
      final friends = await widget.friendApiService.getFriendships();
      if (!mounted) {
        return;
      }
      setState(() {
        _friends = friends
            .where((friend) => friend.friendUserId != widget.currentUserId)
            .toList();
        _isLoadingFriends = false;
      });
    } on FriendApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _friendsError = error.message;
        _isLoadingFriends = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _friendsError = 'Unable to load friends.';
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _subscribeToEvents() async {
    try {
      final stream = await widget.chatApiService.openEventStream();
      if (!mounted) {
        await stream.close();
        return;
      }
      setState(() {
        _eventStream = stream;
      });
      stream.stream.listen(
        (event) {
          if (!event.isMessage) {
            return;
          }
          _loadThreads(silent: true, force: true);
        },
        onError: (_) {},
      );
    } on ChatApiException {
      // Ignore; user can still refresh manually.
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _loadThreads(silent: true, force: true),
      _loadFriends(silent: true),
    ]);
  }

  Future<void> _openThread(ChatThreadSummary thread) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          chatApiService: widget.chatApiService,
          thread: thread,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
    if (result == true) {
      await _loadThreads(silent: true, force: true);
    }
  }

  Future<void> _startConversationWithFriend(FriendListItem friend) async {
    final message = await _promptFirstMessage(friend);
    if (message == null) {
      return;
    }

    setState(() {
      _startingFriendshipId = friend.friendshipId;
    });

    try {
      final sent = await widget.chatApiService.sendMessage(
        friendshipId: friend.friendshipId,
        content: message,
      );

      await _loadThreads(silent: true, force: true);
      if (!mounted) {
        return;
      }
      final thread = _threads.firstWhere(
        (item) => item.threadId == sent.threadId,
        orElse: () => ChatThreadSummary(
          threadId: sent.threadId,
          friendshipId: friend.friendshipId,
          friendUserId: friend.friendUserId,
          friendDisplayName: friend.displayName,
          friendPictureUrl: friend.pictureUrl,
          lastMessageId: sent.id,
          lastMessagePreview: sent.content,
          lastMessageAt: sent.createdAt,
          createdAt: sent.createdAt,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message sent to ${friend.displayName.isNotEmpty ? friend.displayName : friend.friendUserId}.'),
        ),
      );
      await _openThread(thread);
    } on ChatApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start conversation.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _startingFriendshipId = null;
        });
      }
    }
  }

  Future<String?> _promptFirstMessage(FriendListItem friend) async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F1F39),
              title: Text(
                'Message ${friend.displayName.isNotEmpty ? friend.displayName : friend.friendUserId}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    cursorColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Say something nice...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      errorText: errorText,
                    ),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      final text = controller.text.trim();
                      if (text.isEmpty) {
                        setDialogState(() {
                          errorText = 'Enter a message.';
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop(text);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setDialogState(() {
                        errorText = 'Enter a message.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(text);
                  },
                  child: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Chats',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Colors.white,
            backgroundColor: const Color(0xFF0F1F39),
            child: _buildThreadList(),
          ),
        ),
      ),
    );
  }

  Widget _buildThreadList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        children: [
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadThreads,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            child: const Text('Try again'),
          ),
        ],
      );
    }

    if (_threads.isEmpty) {
      return _buildEmptyState();
    }

    final List<Widget> children = <Widget>[];
    for (var index = 0; index < _threads.length; index++) {
      final thread = _threads[index];
      children.add(
        _ThreadTile(
          thread: thread,
          onTap: () => _openThread(thread),
        ),
      );
      if (index != _threads.length - 1) {
        children.add(const SizedBox(height: 12));
      }
    }

    final newChatFriends = _friendsWithoutExistingThread;
    final bool showNewChatSection =
        _isLoadingFriends || _friendsError != null || newChatFriends.isNotEmpty;
    if (showNewChatSection) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 28));
      }
      children.add(const Text(
        'Start a new chat',
        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
      ));
      children.add(const SizedBox(height: 12));
      children.add(
        _buildFriendList(
          friends: (!_isLoadingFriends && _friendsError == null)
              ? newChatFriends
              : null,
          noFriendsMessage:
              'You have already started chats with all of your friends.',
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: children,
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
      children: [
        const SizedBox(height: 12),
        const Text(
          'No conversations yet',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        const Text(
          'Start chatting with a friend to keep the moments going.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 32),
        const Text(
          'Friends',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildFriendList(),
      ],
    );
  }

  Widget _buildFriendList({
    List<FriendListItem>? friends,
    String? noFriendsMessage,
  }) {
    if (_isLoadingFriends) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_friendsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _friendsError!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _loadFriends(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            child: const Text('Retry'),
          ),
        ],
      );
    }
    final resolvedFriends = friends ?? _friends;
    if (resolvedFriends.isEmpty) {
      return Text(
        noFriendsMessage ??
            'Add some friends from the home screen to start chatting.',
        style: const TextStyle(color: Colors.white60),
        textAlign: TextAlign.center,
      );
    }

    return Column(
      children: resolvedFriends
          .map(
            (friend) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FriendStartChatTile(
                friend: friend,
                isLoading: _startingFriendshipId == friend.friendshipId,
                onStart: () => _startConversationWithFriend(friend),
              ),
            ),
          )
          .toList(),
    );
  }

  List<FriendListItem> get _friendsWithoutExistingThread {
    if (_friends.isEmpty) {
      return const <FriendListItem>[];
    }
    final existingIds = _threads.map((thread) => thread.friendshipId).toSet();
    return _friends
        .where(
          (friend) =>
              friend.friendshipId.isNotEmpty &&
              !existingIds.contains(friend.friendshipId),
        )
        .toList();
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.onTap,
  });

  final ChatThreadSummary thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = thread.lastMessagePreview?.trim().isNotEmpty == true
        ? thread.lastMessagePreview!.trim()
        : thread.lastMessageId != null
            ? 'Photo shared'
            : 'Say hello';
    final timestamp = thread.lastMessageAt ?? thread.createdAt;
    final timeLabel = _formatRelativeTime(timestamp);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1F39).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  backgroundImage: thread.friendPictureUrl.isNotEmpty
                      ? NetworkImage(thread.friendPictureUrl)
                      : null,
                  child: thread.friendPictureUrl.isEmpty
                      ? const Icon(Icons.person_outline,
                          color: Colors.white, size: 22)
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

String _formatRelativeTime(DateTime timestamp) {
  final now = DateTime.now().toUtc();
  final value = timestamp.toUtc();
  final difference = now.difference(value);

  if (difference.inSeconds < 60) {
    return 'now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d';
  }
  return '${value.month}/${value.day}';
}

class _FriendStartChatTile extends StatelessWidget {
  const _FriendStartChatTile({
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
                  backgroundImage:
                      friend.pictureUrl.isNotEmpty ? NetworkImage(friend.pictureUrl) : null,
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
                      Text(
                        'Tap to start a conversation',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
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
