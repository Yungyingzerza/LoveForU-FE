import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Provides access to the friendship endpoints exposed by the backend.
class FriendApiService {
  FriendApiService({String? baseUrl, http.Client? client})
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

  Future<FriendshipResponse> createFriendship({
    required String friendUserId,
  }) async {
    if (friendUserId.trim().isEmpty) {
      throw ArgumentError.value(
        friendUserId,
        'friendUserId',
        'Friend LINE user id must not be empty',
      );
    }

    final uri = Uri.parse('$_baseUrl/api/friendship');
    developer.log(
      'POST $uri (friendUserId=$friendUserId)',
      name: 'FriendApiService',
    );

    final response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{'friendUserId': friendUserId}),
    );

    final String body = response.body;
    developer.log(
      'POST /api/friendship responded ${response.statusCode} $body',
      name: 'FriendApiService',
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> decoded =
          jsonDecode(body) as Map<String, dynamic>;
      return FriendshipResponse.fromJson(decoded).copyWith(
        acceptedFromIncomingRequest: response.statusCode == 200,
      );
    }

    if (response.statusCode == 409) {
      throw FriendApiException(
        'You already sent a request or you are already friends.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 404) {
      throw FriendApiException(
        'User not found. Check the LINE user ID and try again.',
        statusCode: response.statusCode,
      );
    }

    throw FriendApiException(
      'Failed to add friend: ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  Future<List<FriendshipResponse>> getPendingFriendships({
    FriendshipPendingDirection direction = FriendshipPendingDirection.incoming,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/friendship/pending').replace(
      queryParameters: direction == FriendshipPendingDirection.incoming
          ? null
          : <String, String>{'direction': direction.queryValue},
    );
    developer.log('GET $uri', name: 'FriendApiService');

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw FriendApiException(
        'Failed to load pending friendships: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((dynamic item) =>
            FriendshipResponse.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FriendshipResponse> getFriendship(String id) async {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'id must not be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/friendship/$id');
    developer.log('GET $uri', name: 'FriendApiService');
    final response = await _client.get(uri);

    if (response.statusCode == 404) {
      throw FriendApiException(
        'Friendship not found.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200) {
      throw FriendApiException(
        'Failed to load friendship: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final Map<String, dynamic> decoded =
        jsonDecode(response.body) as Map<String, dynamic>;
    return FriendshipResponse.fromJson(decoded);
  }

  Future<FriendshipResponse> acceptFriendship(String id) async {
    return _handleFriendshipDecision(id: id, action: 'accept');
  }

  Future<FriendshipResponse> denyFriendship(String id) async {
    return _handleFriendshipDecision(id: id, action: 'deny');
  }

  Future<FriendshipResponse> _handleFriendshipDecision({
    required String id,
    required String action,
  }) async {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'id must not be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/friendship/$id/$action');
    developer.log('POST $uri', name: 'FriendApiService');
    final response = await _client.post(uri);
    if (response.statusCode != 200) {
      throw FriendApiException(
        'Failed to $action friendship: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final Map<String, dynamic> decoded =
        jsonDecode(response.body) as Map<String, dynamic>;
    return FriendshipResponse.fromJson(decoded);
  }
}

class FriendshipResponse {
  const FriendshipResponse({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.acceptedFromIncomingRequest = false,
  });

  factory FriendshipResponse.fromJson(Map<String, dynamic> json) {
    return FriendshipResponse(
      id: json['id'] as String? ?? '',
      requesterId: json['requesterId'] as String? ?? '',
      addresseeId: json['addresseeId'] as String? ?? '',
      status: json['status'] is int
          ? json['status'] as int
          : int.tryParse(json['status']?.toString() ?? '') ?? -1,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      respondedAt: json['respondedAt'] != null
          ? DateTime.tryParse(json['respondedAt'].toString())
          : null,
    );
  }

  FriendshipResponse copyWith({
    bool? acceptedFromIncomingRequest,
  }) {
    return FriendshipResponse(
      id: id,
      requesterId: requesterId,
      addresseeId: addresseeId,
      status: status,
      createdAt: createdAt,
      respondedAt: respondedAt,
      acceptedFromIncomingRequest:
          acceptedFromIncomingRequest ?? this.acceptedFromIncomingRequest,
    );
  }

  final String id;
  final String requesterId;
  final String addresseeId;
  final int status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  /// Indicates a POST 200 response where the incoming pending request was accepted.
  final bool acceptedFromIncomingRequest;

  bool get isAccepted => status == 1;
  bool get isPending => status == 0;
  bool get isDeclined => status == 2;
  bool get isBlocked => status == 3;

  bool isRequester(String userId) => requesterId == userId;
  bool isAddressee(String userId) => addresseeId == userId;
}

class FriendApiException implements Exception {
  FriendApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode != null) {
      return 'FriendApiException($statusCode): $message';
    }
    return 'FriendApiException: $message';
  }
}

enum FriendshipPendingDirection { incoming, outgoing, all }

extension FriendshipPendingDirectionQuery on FriendshipPendingDirection {
  String get queryValue {
    switch (this) {
      case FriendshipPendingDirection.incoming:
        return 'incoming';
      case FriendshipPendingDirection.outgoing:
        return 'outgoing';
      case FriendshipPendingDirection.all:
        return 'all';
    }
  }

  String get label {
    switch (this) {
      case FriendshipPendingDirection.incoming:
        return 'Incoming';
      case FriendshipPendingDirection.outgoing:
        return 'Outgoing';
      case FriendshipPendingDirection.all:
        return 'All';
    }
  }
}
