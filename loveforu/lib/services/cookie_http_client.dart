import 'dart:io';

import 'package:http/http.dart' as http;

/// Simple cookie-aware HTTP client that stores Set-Cookie headers
/// and replays them on subsequent requests.
class CookieHttpClient extends http.BaseClient {
  CookieHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Map<String, String> _cookies = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_cookies.isNotEmpty) {
      final cookieHeader = _cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
      request.headers[HttpHeaders.cookieHeader] = cookieHeader;
    }

    final response = await _inner.send(request);
    _storeCookies(response);
    return response;
  }

  void clearCookies() => _cookies.clear();

  @override
  void close() {
    _inner.close();
    super.close();
  }

  void _storeCookies(http.StreamedResponse response) {
    final setCookie = response.headers[HttpHeaders.setCookieHeader];
    if (setCookie == null || setCookie.isEmpty) {
      return;
    }

    // Only use the first part before the attributes (path, httpOnly, etc.).
    final cookieParts = setCookie.split(';');
    if (cookieParts.isEmpty) {
      return;
    }

    final first = cookieParts.first;
    final separatorIndex = first.indexOf('=');
    if (separatorIndex == -1) {
      return;
    }
    final key = first.substring(0, separatorIndex).trim();
    final value = first.substring(separatorIndex + 1).trim();
    if (key.isEmpty) {
      return;
    }

    _cookies[key] = value;
  }
}
