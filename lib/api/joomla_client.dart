import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Talks to the Joomla Web Services API. Contains no UI code.
///
/// The token is only ever sent in the `X-Joomla-Token` header. It is never
/// logged and is scrubbed from every error message.
class JoomlaClient {
  JoomlaClient({
    required this._apiBaseUrl,
    required this._token,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client();

  final String _apiBaseUrl;
  final String _token;
  final http.Client _http;
  final Duration timeout;

  static const _maxMessageLength = 300;

  /// Checks URL, token and category in one call. Returns the category title.
  Future<String> verifyCategory(int categoryId) async {
    final json = await _get('/content/categories/$categoryId');
    final title = _attributes(json['data'])?['title'];
    return title is String ? title : '';
  }

  /// Returns the media adapter prefix to use in upload paths, e.g.
  /// `local-images`. Prefers the adapter for the `images` folder, because
  /// uploaded files must end up under `images/` to be public.
  Future<String> fetchMediaAdapter() async {
    final json = await _get('/media/adapters');
    final data = json['data'];
    final adapters = data is List ? data.whereType<Map>().toList() : <Map>[];
    if (adapters.isEmpty) {
      throw const JoomlaApiException(
        'The site reported no media adapters. '
        'Is the "Web Services - Media" plugin enabled?',
      );
    }
    final preferred = adapters.firstWhere(
      (a) => _attributes(a)?['name'] == 'images',
      orElse: () => adapters.first,
    );
    final id = preferred['id'];
    if (id is! String || id.isEmpty) {
      throw const JoomlaApiException('Unexpected media adapter response.');
    }
    return id;
  }

  void close() => _http.close();

  Map<String, String> get _headers => {
    'X-Joomla-Token': _token,
    'Accept': 'application/vnd.api+json',
  };

  Future<Map<String, dynamic>> _get(String path) {
    return _send(
      () => _http.get(Uri.parse('$_apiBaseUrl$path'), headers: _headers),
    );
  }

  /// Runs a request, turns every failure into a sanitized
  /// [JoomlaApiException] and returns the decoded JSON body.
  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const JoomlaApiException(
        'The site did not respond in time. Please try again.',
      );
    } on http.ClientException catch (e) {
      throw JoomlaApiException(
        'Could not reach the site: ${_sanitize(e.message)}',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFrom(response);
    }

    final json = _tryDecode(response.body);
    if (json == null) {
      throw JoomlaApiException(
        'Unexpected response from the site. Is the site URL correct?',
        statusCode: response.statusCode,
      );
    }
    return json;
  }

  JoomlaApiException _errorFrom(http.Response response) {
    final status = response.statusCode;
    final hint = switch (status) {
      401 => 'Authentication failed. Check the API token.',
      403 => 'Permission denied. The token user lacks the required rights.',
      404 => 'Not found. Check the site URL and category ID.',
      413 => 'The file is too large for the server.',
      >= 500 => 'The site reported a server error ($status).',
      _ => 'Request failed ($status).',
    };
    final detail = _apiErrorDetail(response.body);
    final message = detail == null ? hint : '$hint Server said: $detail';
    return JoomlaApiException(message, statusCode: status);
  }

  /// Joins the JSON:API `errors[].title/detail` entries, sanitized.
  String? _apiErrorDetail(String body) {
    final errors = _tryDecode(body)?['errors'];
    if (errors is! List) return null;
    final parts = <String>[];
    for (final error in errors.whereType<Map>()) {
      for (final key in ['title', 'detail']) {
        final value = error[key];
        if (value is String && value.trim().isNotEmpty) {
          final clean = _sanitize(value);
          if (!parts.contains(clean)) parts.add(clean);
        }
      }
    }
    if (parts.isEmpty) return null;
    return _truncate(parts.join('; '));
  }

  /// Strips HTML tags, collapses whitespace and removes the token.
  String _sanitize(String text) {
    var clean = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
    if (_token.isNotEmpty) clean = clean.replaceAll(_token, '***');
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _truncate(clean);
  }

  String _truncate(String text) => text.length <= _maxMessageLength
      ? text
      : '${text.substring(0, _maxMessageLength)}…';

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static Map? _attributes(Object? resource) {
    if (resource is! Map) return null;
    final attributes = resource['attributes'];
    return attributes is Map ? attributes : null;
  }
}
