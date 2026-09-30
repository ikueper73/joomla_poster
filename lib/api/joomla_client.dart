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
    this.uploadTimeout = const Duration(minutes: 2),
  }) : _http = httpClient ?? http.Client();

  final String _apiBaseUrl;
  final String _token;
  final http.Client _http;
  final Duration timeout;
  final Duration uploadTimeout;

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

  /// Uploads one image via the media adapter [adapter] (e.g.
  /// `local-images`) and returns its public path under `images/`.
  Future<UploadedImage> uploadImage(String adapter, PendingImage image) async {
    await _post('/media/files', {
      'path': '$adapter:/${image.relativePath}',
      'content': base64Encode(image.bytes),
    }, timeout: uploadTimeout);
    return UploadedImage(path: 'images/${image.relativePath}', alt: image.alt);
  }

  /// Creates the article and returns its id (null if the response has none).
  /// Joomla generates the alias, so none is sent.
  Future<int?> createArticle({
    required String title,
    required String articleHtml,
    required int categoryId,
    required ArticleState state,
    UploadedImage? introImage,
  }) async {
    final json = await _post('/content/articles', {
      'title': title,
      'catid': categoryId,
      'articletext': articleHtml,
      'state': state.value,
      'language': '*',
      if (introImage != null)
        'images': {
          'image_intro': introImage.path,
          'image_intro_alt': introImage.alt,
          'image_fulltext': introImage.path,
          'image_fulltext_alt': introImage.alt,
        },
    });
    final data = json['data'];
    return data is Map ? int.tryParse('${data['id']}') : null;
  }

  /// Uploads all images of [draft] in order, then creates the article.
  /// If any upload fails, stops and throws; the article is not created.
  ///
  /// [buildArticleHtml] turns the plain-text body plus the uploaded inline
  /// images into the article HTML. [onProgress] is called with the number
  /// of uploaded images so far (starting at 0) and the total.
  Future<int?> postArticle(
    ArticleDraft draft, {
    required String adapter,
    required int categoryId,
    required ArticleState state,
    required String Function(String body, List<UploadedImage> inlineImages)
    buildArticleHtml,
    void Function(int uploaded, int total)? onProgress,
  }) async {
    final pending = [?draft.introImage, ...draft.inlineImages];
    final uploaded = <UploadedImage>[];
    onProgress?.call(0, pending.length);
    for (final image in pending) {
      try {
        uploaded.add(await uploadImage(adapter, image));
      } on JoomlaApiException catch (e) {
        throw JoomlaApiException(
          'Image ${uploaded.length + 1} of ${pending.length} could not be '
          'uploaded, so no article was created. ${e.message}',
          statusCode: e.statusCode,
        );
      }
      onProgress?.call(uploaded.length, pending.length);
    }

    final introImage = draft.introImage == null ? null : uploaded.first;
    final inlineImages = draft.introImage == null
        ? uploaded
        : uploaded.sublist(1);
    return createArticle(
      title: draft.title,
      articleHtml: buildArticleHtml(draft.body, inlineImages),
      categoryId: categoryId,
      state: state,
      introImage: introImage,
    );
  }

  void close() => _http.close();

  Map<String, String> get _headers => {
    'X-Joomla-Token': _token,
    'Accept': 'application/vnd.api+json',
  };

  Future<Map<String, dynamic>> _get(String path) {
    return _send(
      () => _http.get(Uri.parse('$_apiBaseUrl$path'), headers: _headers),
      timeout,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) {
    return _send(
      () => _http.post(
        Uri.parse('$_apiBaseUrl$path'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      timeout ?? this.timeout,
    );
  }

  /// Runs a request, turns every failure into a sanitized
  /// [JoomlaApiException] and returns the decoded JSON body.
  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
    Duration timeout,
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
      409 => 'A file with this name already exists on the server.',
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
