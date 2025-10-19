import 'package:flutter/material.dart';

import 'package:loveforu/services/chat_api_service.dart';
import 'package:loveforu/services/friend_api_service.dart';

class ChatThreadsController extends ChangeNotifier {
  ChatThreadsController({
    required this.chatApiService,
    required this.friendApiService,
    required this.currentUserId,
  });

  final ChatApiService chatApiService;
  final FriendApiService friendApiService;
  final String currentUserId;

  final List<ChatThreadSummary> _threads = <ChatThreadSummary>[];
  final List<FriendListItem> _friends = <FriendListItem>[];
  ChatEventStream? _eventStream;

  bool _disposed = false;
  bool _initialized = false;
  bool _isLoadingThreads = true;
  bool _isFetchingThreads = false;
  String? _threadsError;
  bool _isLoadingFriends = true;
  String? _friendsError;
  String? _startingFriendshipId;

  List<ChatThreadSummary> get threads => List.unmodifiable(_threads);
  List<FriendListItem> get friends => List.unmodifiable(_friends);
  bool get isLoadingThreads => _isLoadingThreads;
  String? get threadsError => _threadsError;
  bool get isLoadingFriends => _isLoadingFriends;
  String? get friendsError => _friendsError;
  String? get startingFriendshipId => _startingFriendshipId;

  List<FriendListItem> get friendsWithoutExistingThread {
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
        .toList(growable: false);
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await Future.wait([
      _loadThreads(),
      _loadFriends(),
    ]);
    _subscribeToEvents();
  }

  Future<void> refresh() async {
    await Future.wait([
      _loadThreads(force: true),
      _loadFriends(),
    ]);
  }

  Future<StartConversationResult> startConversation({
    required FriendListItem friend,
    required String message,
  }) async {
    _startingFriendshipId = friend.friendshipId;
    _notify();

    try {
      final sent = await chatApiService.sendMessage(
        friendshipId: friend.friendshipId,
        content: message,
      );
      await _loadThreads(force: true, silent: true);
      if (_disposed) {
        return const StartConversationResult(
          success: false,
          message: 'Conversation started but screen left.',
        );
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
      return StartConversationResult(
        success: true,
        message:
            'Message sent to ${friend.displayName.isNotEmpty ? friend.displayName : friend.friendUserId}.',
        thread: thread,
      );
    } on ChatApiException catch (error) {
      return StartConversationResult(success: false, message: error.message);
    } catch (_) {
      return const StartConversationResult(
        success: false,
        message: 'Unable to start conversation.',
      );
    } finally {
      _startingFriendshipId = null;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _eventStream?.close();
    super.dispose();
  }

  Future<void> _loadThreads({bool silent = false, bool force = false}) async {
    if (_isFetchingThreads) {
      if (!force) {
        return;
      }
      while (_isFetchingThreads) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    _isFetchingThreads = true;
    if (!silent) {
      _isLoadingThreads = true;
      _threadsError = null;
      _notify();
    }

    try {
      final threads = await chatApiService.getThreads();
      threads.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      _threads
        ..clear()
        ..addAll(threads);
      _isLoadingThreads = false;
      _notify();
    } on ChatApiException catch (error) {
      _isLoadingThreads = false;
      _threadsError = error.message;
      _notify();
    } catch (_) {
      _isLoadingThreads = false;
      _threadsError = 'Unable to load conversations.';
      _notify();
    } finally {
      _isFetchingThreads = false;
    }
  }

  Future<void> _loadFriends({bool silent = false}) async {
    if (!silent) {
      _isLoadingFriends = true;
      _friendsError = null;
      _notify();
    }
    try {
      final friends = await friendApiService.getFriendships();
      _friends
        ..clear()
        ..addAll(
          friends.where((friend) => friend.friendUserId != currentUserId),
        );
      _isLoadingFriends = false;
      _notify();
    } on FriendApiException catch (error) {
      _friendsError = error.message;
      _isLoadingFriends = false;
      _notify();
    } catch (_) {
      _friendsError = 'Unable to load friends.';
      _isLoadingFriends = false;
      _notify();
    }
  }

  Future<void> _subscribeToEvents() async {
    try {
      final stream = await chatApiService.openEventStream();
      if (_disposed) {
        await stream.close();
        return;
      }
      _eventStream = stream;
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

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }
}

class StartConversationResult {
  const StartConversationResult({
    required this.success,
    required this.message,
    this.thread,
  });

  final bool success;
  final String message;
  final ChatThreadSummary? thread;
}
