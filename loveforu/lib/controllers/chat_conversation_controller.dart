import 'dart:async';

import 'package:flutter/material.dart';

import 'package:loveforu/services/chat_api_service.dart';

class ChatConversationController extends ChangeNotifier {
  ChatConversationController({
    required this.chatApiService,
    required this.thread,
    required this.currentUserId,
  });

  final ChatApiService chatApiService;
  final ChatThreadSummary thread;
  final String currentUserId;

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode inputFocusNode = FocusNode();

  List<ChatMessageDto> _messages = <ChatMessageDto>[];
  ChatEventStream? _eventStream;
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  bool _hasSentMessage = false;
  DateTime? _latestCreatedAt;
  bool _hasInitialized = false;
  bool _isDisposed = false;

  List<ChatMessageDto> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  bool get hasSentMessage => _hasSentMessage;

  Future<void> initialize() async {
    if (_hasInitialized) {
      return;
    }
    _hasInitialized = true;
    _subscribeToEvents();
    await _loadInitialMessages();
  }

  Future<void> refresh() => _loadInitialMessages();

  Future<void> sendMessage() async {
    if (_isSending) {
      return;
    }

    final text = messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _isSending = true;
    _errorMessage = null;
    _notifyListeners();

    try {
      final message = await chatApiService.sendMessage(
        friendshipId: thread.friendshipId,
        content: text,
      );
      if (_isDisposed) {
        return;
      }

      final merged = _mergeWithExisting([message]);
      if (merged != null) {
        _messages = merged;
        _latestCreatedAt =
            merged.isNotEmpty ? merged.last.createdAt : message.createdAt;
        _hasSentMessage = true;
      }
      messageController.clear();
      _isSending = false;
      _notifyListeners();
      _scrollToBottom(force: true);
    } on ChatApiException catch (error) {
      if (_isDisposed) return;
      _isSending = false;
      _errorMessage = error.message;
      _notifyListeners();
    } catch (_) {
      if (_isDisposed) return;
      _isSending = false;
      _errorMessage = 'Failed to send message.';
      _notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _eventStream?.close();
    messageController.dispose();
    scrollController.dispose();
    inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    _isLoading = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      final messages = await chatApiService.getMessages(
        threadId: thread.threadId,
        limit: 200,
      );
      if (_isDisposed) {
        return;
      }
      final normalized = _normalizeMessages(messages);
      _messages = normalized;
      _latestCreatedAt =
          normalized.isNotEmpty ? normalized.last.createdAt : null;
      _isLoading = false;
      _notifyListeners();
      _scrollToBottom(force: true);
    } on ChatApiException catch (error) {
      if (_isDisposed) return;
      _isLoading = false;
      _errorMessage = error.message;
      _notifyListeners();
    } catch (_) {
      if (_isDisposed) return;
      _isLoading = false;
      _errorMessage = 'Unable to load messages.';
      _notifyListeners();
    }
  }

  Future<void> _subscribeToEvents() async {
    try {
      final stream = await chatApiService.openEventStream();
      if (_isDisposed) {
        await stream.close();
        return;
      }
      _eventStream = stream;
      stream.stream.listen(
        (event) {
          if (!event.isMessage) {
            return;
          }
          if (event.threadId != thread.threadId) {
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
      final fresh = await chatApiService.getMessages(
        threadId: thread.threadId,
        after: lastTimestamp,
        limit: 200,
      );
      if (_isDisposed || fresh.isEmpty) {
        return;
      }

      final merged = _mergeWithExisting(fresh);
      if (merged == null) {
        return;
      }

      _messages = merged;
      _latestCreatedAt =
          merged.isNotEmpty ? merged.last.createdAt : lastTimestamp;
      _hasSentMessage = true;
      _notifyListeners();
      _scrollToBottomIfNearEnd();
    } catch (_) {
      // Ignore transient failures when fetching incremental updates.
    }
  }

  List<ChatMessageDto>? _mergeWithExisting(Iterable<ChatMessageDto> incoming) {
    return _mergeMessages(_messages, incoming);
  }

  void _scrollToBottom({bool force = false}) {
    if (!scrollController.hasClients) {
      return;
    }
    final maxScroll = scrollController.position.maxScrollExtent;
    final shouldAnimate = force ||
        (scrollController.position.pixels >
            maxScroll - 200); // near the bottom already
    if (shouldAnimate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!scrollController.hasClients) {
          return;
        }
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _scrollToBottomIfNearEnd() {
    _scrollToBottom();
  }

  void _notifyListeners() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
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
