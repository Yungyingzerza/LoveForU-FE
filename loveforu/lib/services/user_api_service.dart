import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Handles communication with the backend user API.
class UserApiService {
  UserApiService({String? baseUrl, http.Client? client})
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

  Future<UserResponse> exchangeLineToken(String accessToken) async {
    final uri = Uri.parse('$_baseUrl/api/User');
    developer.log('POST $uri', name: 'UserApiService');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'accessToken': accessToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      developer.log(
        'User API failed with status ${response.statusCode}: ${response.body}',
        name: 'UserApiService',
        level: 1000,
      );
      throw UserApiException(
        'User API request failed with status ${response.statusCode}',
      );
    }

    developer.log('User API success ${response.statusCode}', name: 'UserApiService');
    final Map<String, dynamic> body = jsonDecode(response.body);
    return UserResponse.fromJson(body);
  }
}

class UserResponse {
  const UserResponse({required this.id, required this.displayName, this.pictureUrl});

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      pictureUrl: json['pictureUrl'] as String?,
    );
  }

  final String id;
  final String displayName;
  final String? pictureUrl;
}

class UserApiException implements Exception {
  UserApiException(this.message);

  final String message;

  @override
  String toString() => 'UserApiException: $message';
}
