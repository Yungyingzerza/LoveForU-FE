import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ChatApiService {
  ChatApiService({String? baseUrl, http.Client? client})
      : _baseUrl = baseUrl ?? _resolveBaseUrl(),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  static String _resolveBaseUrl() {
    final value = dotenv.env['API_BASE_URL'];
    if (value == null || value.isEmpty) {
      throw StateError('Missing API_BASE_URL in .env');
    }
    return value;
  }

  Future<List<ChatThreadSummary>> getThreads() async {
    final uri = Uri.parse('$_baseUrl/api/chat/threads');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw ChatApiException(
        'Failed to load threads: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((dynamic item) =>
            ChatThreadSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChatMessageDto>> getMessages({
    required String threadId,
    int? limit,
    DateTime? after,
  }) async {
    if (threadId.trim().isEmpty) {
      throw ArgumentError.value(threadId, 'threadId', 'threadId must not be empty');
    }

    final query = <String, String>{};
    if (limit != null) {
      query['limit'] = '$limit';
    }
    if (after != null) {
      query['after'] = after.toUtc().toIso8601String();
    }

    final uri = Uri.parse('$_baseUrl/api/chat/threads/$threadId/messages')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await _client.get(uri);

    if (response.statusCode == 404) {
      throw ChatApiException(
        'Thread not found.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 403) {
      throw ChatApiException(
        'You do not have access to this thread.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200) {
      throw ChatApiException(
        'Failed to load messages: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((dynamic item) =>
            ChatMessageDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessageDto> sendMessage({
    required String friendshipId,
    String? content,
    String? photoShareId,
    String? photoId,
  }) async {
    if (friendshipId.trim().isEmpty) {
      throw ArgumentError.value(
        friendshipId,
        'friendshipId',
        'friendshipId must not be empty',
      );
    }

    final body = <String, dynamic>{};
    if (content != null && content.trim().isNotEmpty) {
      body['content'] = content.trim();
    }
    if (photoShareId != null) {
      body['photoShareId'] = photoShareId;
    }
    if (photoId != null) {
      body['photoId'] = photoId;
    }

    if (body.isEmpty) {
      throw ArgumentError(
        'At least one of content, photoShareId, or photoId must be provided.',
      );
    }

    final uri =
        Uri.parse('$_baseUrl/api/chat/friendships/$friendshipId/messages');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 404) {
      throw ChatApiException(
        'Friendship not found.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 400) {
      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      throw ChatApiException(
        decoded['error'] as String? ??
            decoded['message'] as String? ??
            'Invalid chat message.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 201) {
      throw ChatApiException(
        'Failed to send message: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final Map<String, dynamic> decoded =
        jsonDecode(response.body) as Map<String, dynamic>;
    return ChatMessageDto.fromJson(decoded);
  }

  String resolvePhotoUrl(String url) {
    if (url.isEmpty) {
      return url;
    }
    final uri = Uri.parse(url);
    if (uri.hasScheme) {
      return url;
    }
    final combined = Uri.parse(_baseUrl).resolveUri(uri);
    return combined.toString();
  }

  Future<ChatEventStream> openEventStream() async {
    final uri = Uri.parse('$_baseUrl/api/chat/events');
    final request = http.Request('GET', uri);
    request.headers['Accept'] = 'text/event-stream';
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      // Drain to allow the underlying connection to close cleanly.
      unawaited(response.stream.drain<void>());
      throw ChatApiException(
        'Failed to subscribe to chat events: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final controller = StreamController<ChatEvent>();
    String? eventName;
    final StringBuffer dataBuffer = StringBuffer();

    late StreamSubscription<String> subscription;
    subscription = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (line.isEmpty) {
          if (eventName != null && dataBuffer.isNotEmpty) {
            final raw = dataBuffer.toString();
            try {
              final Map<String, dynamic> decoded =
                  jsonDecode(raw) as Map<String, dynamic>;
              controller.add(ChatEvent(
                event: eventName!,
                threadId: decoded['threadId'] as String? ?? '',
                messageId: decoded['messageId'] as String? ?? '',
                senderId: decoded['senderId'] as String? ?? '',
              ));
            } catch (error) {
              controller.addError(error);
            }
          }
          eventName = null;
          dataBuffer.clear();
          return;
        }

        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          if (dataBuffer.isNotEmpty) {
            dataBuffer.writeln();
          }
          dataBuffer.write(line.substring(5).trim());
        }
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
      },
      cancelOnError: false,
    );

    return ChatEventStream._(
      controller.stream,
      () async {
        await subscription.cancel();
        await controller.close();
      },
    );
  }
}

class ChatThreadSummary {
  ChatThreadSummary({
    required this.threadId,
    required this.friendshipId,
    required this.friendUserId,
    required this.friendDisplayName,
    required this.friendPictureUrl,
    required this.createdAt,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  factory ChatThreadSummary.fromJson(Map<String, dynamic> json) {
    return ChatThreadSummary(
      threadId: json['threadId'] as String? ?? '',
      friendshipId: json['friendshipId'] as String? ?? '',
      friendUserId: json['friendUserId'] as String? ?? '',
      friendDisplayName: json['friendDisplayName'] as String? ?? '',
      friendPictureUrl: json['friendPictureUrl'] as String? ?? '',
      lastMessageId: json['lastMessageId'] as String?,
      lastMessagePreview: json['lastMessagePreview'] as String?,
      lastMessageAt: _parseDateTime(json['lastMessageAt']),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String threadId;
  final String friendshipId;
  final String friendUserId;
  final String friendDisplayName;
  final String friendPictureUrl;
  final String? lastMessageId;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
}

class ChatMessageDto {
  ChatMessageDto({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderDisplayName,
    required this.senderPictureUrl,
    required this.createdAt,
    this.content,
    this.photoShareId,
    this.photo,
  });

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) {
    return ChatMessageDto(
      id: json['id'] as String? ?? '',
      threadId: json['threadId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderDisplayName: json['senderDisplayName'] as String? ?? '',
      senderPictureUrl: json['senderPictureUrl'] as String? ?? '',
      content: json['content'] as String?,
      photoShareId: json['photoShareId'] as String?,
      photo: json['photo'] == null
          ? null
          : ChatMessagePhoto.fromJson(json['photo'] as Map<String, dynamic>),
      createdAt:
          _parseDateTime(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String threadId;
  final String senderId;
  final String senderDisplayName;
  final String senderPictureUrl;
  final String? content;
  final String? photoShareId;
  final ChatMessagePhoto? photo;
  final DateTime createdAt;
}

class ChatMessagePhoto {
  ChatMessagePhoto({
    required this.photoShareId,
    required this.photoId,
    required this.imageUrl,
    this.caption,
  });

  factory ChatMessagePhoto.fromJson(Map<String, dynamic> json) {
    return ChatMessagePhoto(
      photoShareId: json['photoShareId'] as String? ?? '',
      photoId: json['photoId'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      caption: json['caption'] as String?,
    );
  }

  final String photoShareId;
  final String photoId;
  final String imageUrl;
  final String? caption;
}

class ChatEvent {
  const ChatEvent({
    required this.event,
    required this.threadId,
    required this.messageId,
    required this.senderId,
  });

  final String event;
  final String threadId;
  final String messageId;
  final String senderId;

  bool get isMessage => event == 'message';
}

class ChatEventStream {
  ChatEventStream._(this.stream, this._onClose);

  final Stream<ChatEvent> stream;
  final Future<void> Function() _onClose;
  bool _closed = false;

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _onClose();
  }
}

class ChatApiException implements Exception {
  const ChatApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ChatApiException($statusCode): $message';
}

DateTime? _parseDateTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}
