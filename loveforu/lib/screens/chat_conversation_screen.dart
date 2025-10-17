import 'dart:async';

import 'package:flutter/material.dart';

import 'package:loveforu/services/chat_api_service.dart';
import 'package:loveforu/theme/app_gradients.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  List<ChatMessageDto> _messages = <ChatMessageDto>[];
  ChatEventStream? _eventStream;
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  bool _hasSentMessage = false;
  DateTime? _latestCreatedAt;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _subscribeToEvents();
  }

  @override
  void dispose() {
    _eventStream?.close();
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final messages = await widget.chatApiService.getMessages(
        threadId: widget.thread.threadId,
        limit: 200,
      );
      if (!mounted) {
        return;
      }
      final normalized = _normalizeMessages(messages);
      setState(() {
        _messages = normalized;
        _latestCreatedAt =
            normalized.isNotEmpty ? normalized.last.createdAt : null;
        _isLoading = false;
      });
      _scrollToBottom(force: true);
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
        _errorMessage = 'Unable to load messages.';
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
          if (event.threadId != widget.thread.threadId) {
            return;
          }
          _loadNewMessages();
        },
        onError: (_) {},
      );
    } on ChatApiException {
      // Ignore; user can still refresh manually.
    }
  }

  Future<void> _loadNewMessages() async {
    final lastTimestamp = _latestCreatedAt;
    try {
      final fresh = await widget.chatApiService.getMessages(
        threadId: widget.thread.threadId,
        after: lastTimestamp,
        limit: 200,
      );
      if (!mounted || fresh.isEmpty) {
        return;
      }

      final merged = _mergeWithExisting(fresh);
      if (merged == null) {
        return;
      }

      setState(() {
        _messages = merged;
        _latestCreatedAt =
            merged.isNotEmpty ? merged.last.createdAt : lastTimestamp;
        _hasSentMessage = true;
      });
      _scrollToBottomIfNearEnd();
    } catch (_) {
      // Ignore transient failures when fetching incremental updates.
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) {
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final message = await widget.chatApiService.sendMessage(
        friendshipId: widget.thread.friendshipId,
        content: text,
      );
      if (!mounted) {
        return;
      }
      final merged = _mergeWithExisting([message]);
      setState(() {
        if (merged != null) {
          _messages = merged;
          _latestCreatedAt =
              merged.isNotEmpty ? merged.last.createdAt : message.createdAt;
          _hasSentMessage = true;
        }
        _messageController.clear();
        _isSending = false;
      });
      _scrollToBottom(force: true);
    } on ChatApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = 'Failed to send message.';
      });
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    final shouldAnimate = force ||
        (_scrollController.position.pixels >
            maxScroll - 200); // near the bottom already
    if (shouldAnimate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _scrollToBottomIfNearEnd() {
    _scrollToBottom();
  }

  Future<void> _handleRefresh() async {
    await _loadInitialMessages();
  }

  List<ChatMessageDto>? _mergeWithExisting(Iterable<ChatMessageDto> incoming) {
    return _mergeMessages(_messages, incoming);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final friendName = widget.thread.friendDisplayName.isNotEmpty
        ? widget.thread.friendDisplayName
        : widget.thread.friendUserId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_hasSentMessage);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                backgroundImage: widget.thread.friendPictureUrl.isNotEmpty
                    ? NetworkImage(widget.thread.friendPictureUrl)
                    : null,
                child: widget.thread.friendPictureUrl.isEmpty
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
        body: Container(
          decoration: const BoxDecoration(gradient: appBackgroundGradient),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: Colors.white,
                    backgroundColor: const Color(0xFF0F1F39),
                    child: _buildMessagesList(),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                _buildComposer(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_messages.isEmpty) {
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
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isSelf = message.senderId == widget.currentUserId;
        final showAvatar = !isSelf &&
            (index == 0 ||
                _messages[index - 1].senderId != message.senderId);
        final showTimestamp = index == _messages.length - 1 ||
            _messages[index + 1].senderId != message.senderId;
        return _MessageBubble(
          message: message,
          isSelf: isSelf,
          showAvatar: showAvatar,
          showTimestamp: showTimestamp,
          friendAvatarUrl: widget.thread.friendPictureUrl,
          photoResolver: widget.chatApiService.resolvePhotoUrl,
        );
      },
    );
  }

  Widget _buildComposer(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1F39).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocusNode,
                enabled: !_isSending,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              width: 40,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendMessage,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color(0xFF5B7CF7),
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 0,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isSelf,
    required this.showAvatar,
    required this.showTimestamp,
    required this.friendAvatarUrl,
    required this.photoResolver,
  });

  final ChatMessageDto message;
  final bool isSelf;
  final bool showAvatar;
  final bool showTimestamp;
  final String friendAvatarUrl;
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
        left: isSelf ? 48 : (showAvatar ? 0 : 48),
        right: isSelf ? (showAvatar ? 0 : 48) : 48,
      ),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment:
                isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isSelf && showAvatar)
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white24,
                  backgroundImage: friendAvatarUrl.isNotEmpty
                      ? NetworkImage(friendAvatarUrl)
                      : null,
                  child: friendAvatarUrl.isEmpty
                      ? const Icon(Icons.person_outline,
                          size: 16, color: Colors.white)
                      : null,
                ),
              if (!isSelf) const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                          Radius.circular(isSelf ? 18 : (showAvatar ? 6 : 18)),
                      bottomRight:
                          Radius.circular(isSelf ? (showAvatar ? 6 : 18) : 18),
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
                left: isSelf ? 0 : (showAvatar ? 40 : 0),
                right: isSelf ? (showAvatar ? 40 : 0) : 0,
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
    final timeOfDay =
        TimeOfDay(hour: local.hour, minute: local.minute);
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

List<ChatMessageDto> _normalizeMessages(Iterable<ChatMessageDto> messages) {
  final map = <String, ChatMessageDto>{};
  for (final message in messages) {
    map[message.id] = message;
  }
  final list = map.values.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return list;
}

bool _messageEquals(ChatMessageDto a, ChatMessageDto b) {
  return a.id == b.id &&
      a.threadId == b.threadId &&
      a.senderId == b.senderId &&
      a.senderDisplayName == b.senderDisplayName &&
      a.senderPictureUrl == b.senderPictureUrl &&
      a.content == b.content &&
      a.photoShareId == b.photoShareId &&
      _photoEquals(a.photo, b.photo) &&
      a.createdAt == b.createdAt;
}

bool _photoEquals(ChatMessagePhoto? a, ChatMessagePhoto? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null) {
    return a == b;
  }
  return a.photoShareId == b.photoShareId &&
      a.photoId == b.photoId &&
      a.imageUrl == b.imageUrl &&
      a.caption == b.caption;
}

List<ChatMessageDto>? _mergeMessages(
  List<ChatMessageDto> existing,
  Iterable<ChatMessageDto> incoming,
) {
  if (incoming.isEmpty) {
    return null;
  }
  final map = <String, ChatMessageDto>{
    for (final message in existing) message.id: message,
  };
  var changed = false;
  for (final message in incoming) {
    final current = map[message.id];
    if (current == null || !_messageEquals(current, message)) {
      map[message.id] = message;
      changed = true;
    }
  }
  if (!changed) {
    return null;
  }
  final merged = map.values.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return merged;
}
