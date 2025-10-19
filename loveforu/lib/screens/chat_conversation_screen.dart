import 'package:flutter/material.dart';

import 'package:loveforu/controllers/chat_conversation_controller.dart';
import 'package:loveforu/services/chat_api_service.dart';
import 'package:loveforu/widgets/chat/conversation_composer.dart';
import 'package:loveforu/widgets/chat/conversation_messages_list.dart';
import 'package:loveforu/widgets/common/app_gradient_scaffold.dart';

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.chatApiService,
    required this.thread,
    required this.currentUserId,
  });

  final ChatApiService chatApiService;
  final ChatThreadSummary thread;
  final String currentUserId;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  late final ChatConversationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChatConversationController(
      chatApiService: widget.chatApiService,
      thread: widget.thread,
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_controller.hasSentMessage);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final theme = Theme.of(context);
          final friendName = widget.thread.friendDisplayName.isNotEmpty
              ? widget.thread.friendDisplayName
              : widget.thread.friendUserId;
          final resolvedFriendAvatar =
              widget.thread.friendPictureUrl.isNotEmpty
                  ? widget.chatApiService
                      .resolvePhotoUrl(widget.thread.friendPictureUrl)
                  : '';

          return AppGradientScaffold(
            safeArea: false,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    backgroundImage: resolvedFriendAvatar.isNotEmpty
                        ? NetworkImage(resolvedFriendAvatar)
                        : null,
                    child: resolvedFriendAvatar.isEmpty
                        ? const Icon(Icons.person_outline, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      friendName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _controller.refresh,
                      color: Colors.white,
                      backgroundColor: const Color(0xFF0F1F39),
                      child: ConversationMessagesList(
                        controller: _controller,
                        currentUserId: widget.currentUserId,
                        friendPictureUrl: widget.thread.friendPictureUrl,
                        photoResolver: widget.chatApiService.resolvePhotoUrl,
                      ),
                    ),
                  ),
                  if (_controller.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        _controller.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ConversationComposer(
                    controller: _controller,
                    onSend: _controller.sendMessage,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
