import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

/// Provides access to the photo endpoints exposed by the backend.
class PhotoApiService {
  PhotoApiService({String? baseUrl, http.Client? client})
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

  Future<List<PhotoResponse>> getPhotos() async {
    final uri = Uri.parse('$_baseUrl/api/Photo');
    developer.log('GET $uri', name: 'PhotoApiService');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      developer.log(
        'GET /api/Photo failed ${response.statusCode}: ${response.body}',
        name: 'PhotoApiService',
        level: 1000,
      );
      throw PhotoApiException('Failed to load photos: ${response.statusCode}');
    }

    developer.log('GET /api/Photo success', name: 'PhotoApiService');
    final List<dynamic> body = jsonDecode(response.body) as List<dynamic>;
    return body
        .map((item) => PhotoResponse.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PhotoResponse> getPhoto(String id) async {
    final uri = Uri.parse('$_baseUrl/api/Photo/$id');
    developer.log('GET $uri', name: 'PhotoApiService');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      developer.log(
        'GET /api/Photo/$id failed ${response.statusCode}: ${response.body}',
        name: 'PhotoApiService',
        level: 1000,
      );
      throw PhotoApiException('Failed to load photo: ${response.statusCode}');
    }

    developer.log('GET /api/Photo/$id success', name: 'PhotoApiService');
    final Map<String, dynamic> body = jsonDecode(response.body);
    return PhotoResponse.fromJson(body);
  }

  Future<PhotoResponse> uploadPhoto({
    required File image,
    String? caption,
    List<String>? friendIds,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/Photo');
    developer.log('POST $uri', name: 'PhotoApiService');
    final contentTypeString = lookupMimeType(image.path);
    final mediaType = contentTypeString != null
        ? MediaType.parse(contentTypeString)
        : null;
    developer.log(
      'Uploading image with contentType: ${mediaType ?? 'unknown'}',
      name: 'PhotoApiService',
    );
    final file = await http.MultipartFile.fromPath(
      'Image',
      image.path,
      contentType: mediaType,
    );

    final request = http.MultipartRequest('POST', uri)..files.add(file);

    if (caption != null && caption.isNotEmpty) {
      request.fields['Caption'] = caption;
    }

    final List<String>? trimmedFriendIds = friendIds
        ?.map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (trimmedFriendIds != null && trimmedFriendIds.isNotEmpty) {
      for (var i = 0; i < trimmedFriendIds.length; i++) {
        request.fields['FriendIds[$i]'] = trimmedFriendIds[i];
      }
      developer.log(
        'Sharing photo with ${trimmedFriendIds.length} friends',
        name: 'PhotoApiService',
      );
    } else {
      developer.log(
        'No FriendIds provided; backend will share with all accepted friends',
        name: 'PhotoApiService',
      );
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 201) {
      developer.log(
        'POST /api/Photo failed ${response.statusCode}: ${response.body}',
        name: 'PhotoApiService',
        level: 1000,
      );
      throw PhotoApiException('Upload failed: ${response.statusCode}');
    }

    developer.log('POST /api/Photo success', name: 'PhotoApiService');
    final Map<String, dynamic> body = jsonDecode(response.body);
    return PhotoResponse.fromJson(body);
  }
}

class PhotoResponse {
  const PhotoResponse({
    required this.id,
    required this.uploaderId,
    required this.uploaderDisplayName,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
  });

  factory PhotoResponse.fromJson(Map<String, dynamic> json) {
    return PhotoResponse(
      id: json['id'] as String? ?? '',
      uploaderId: json['uploaderId'] as String? ?? '',
      uploaderDisplayName: json['uploaderDisplayName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      caption: json['caption'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String uploaderId;
  final String uploaderDisplayName;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;
}

class PhotoApiException implements Exception {
  PhotoApiException(this.message);

  final String message;

  @override
  String toString() => 'PhotoApiException: $message';
}
