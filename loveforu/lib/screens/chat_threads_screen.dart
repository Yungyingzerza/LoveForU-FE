import 'package:flutter/material.dart';

import 'package:loveforu/controllers/chat_threads_controller.dart';
import 'package:loveforu/services/chat_api_service.dart';
import 'package:loveforu/services/friend_api_service.dart';
import 'package:loveforu/widgets/chat/friend_start_chat_tile.dart';
import 'package:loveforu/widgets/chat/thread_tile.dart';
import 'package:loveforu/widgets/common/app_gradient_scaffold.dart';

import 'chat_conversation_screen.dart';

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
  late final ChatThreadsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChatThreadsController(
      chatApiService: widget.chatApiService,
      friendApiService: widget.friendApiService,
      currentUserId: widget.currentUserId,
    );
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
        return AppGradientScaffold(
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
          body: RefreshIndicator(
            onRefresh: _controller.refresh,
            color: Colors.white,
            backgroundColor: const Color(0xFF0F1F39),
            child: _buildThreadList(),
          ),
        );
      },
    );
  }

  Widget _buildThreadList() {
    if (_controller.isLoadingThreads) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_controller.threadsError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        children: [
          Text(
            _controller.threadsError!,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _controller.refresh(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            child: const Text('Try again'),
          ),
        ],
      );
    }

    if (_controller.threads.isEmpty) {
      return _buildEmptyState();
    }

    final List<Widget> children = <Widget>[];
    for (var index = 0; index < _controller.threads.length; index++) {
      final thread = _controller.threads[index];
      children.add(
        ThreadTile(
          thread: thread,
          onTap: () => _openThread(thread),
        ),
      );
      if (index != _controller.threads.length - 1) {
        children.add(const SizedBox(height: 12));
      }
    }

    final newChatFriends = _controller.friendsWithoutExistingThread;
    final bool showNewChatSection =
        _controller.isLoadingFriends || _controller.friendsError != null || newChatFriends.isNotEmpty;
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
          friends: (!_controller.isLoadingFriends && _controller.friendsError == null)
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
    if (_controller.isLoadingFriends) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_controller.friendsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _controller.friendsError!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _controller.refresh(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            child: const Text('Retry'),
          ),
        ],
      );
    }
    final resolvedFriends = friends ?? _controller.friends;
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
              child: FriendStartChatTile(
                friend: friend,
                isLoading: _controller.startingFriendshipId == friend.friendshipId,
                onStart: () => _startConversationWithFriend(friend),
              ),
            ),
          )
          .toList(),
    );
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
      await _controller.refresh();
    }
  }

  Future<void> _startConversationWithFriend(FriendListItem friend) async {
    final message = await _promptFirstMessage(friend);
    if (message == null || !mounted) {
      return;
    }

    final result = await _controller.startConversation(friend: friend, message: message);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success && result.thread != null) {
      await _openThread(result.thread!);
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
}
