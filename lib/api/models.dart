import 'dart:typed_data';

/// Publish state of a newly created article, as Joomla's `state` field.
enum ArticleState {
  unpublished(0),
  published(1);

  const ArticleState(this.value);

  final int value;

  static ArticleState fromValue(int value) => ArticleState.values.firstWhere(
    (state) => state.value == value,
    orElse: () => ArticleState.unpublished,
  );
}

/// Non-secret connection settings. The API token is deliberately not part
/// of this class so it can never leak through logging or `toString`.
class JoomlaSettings {
  const JoomlaSettings({
    required this.siteUrl,
    required this.categoryId,
    this.articleState = ArticleState.unpublished,
    this.mediaAdapter,
  });

  /// Site root without trailing slash, e.g. `https://example.org`.
  final String siteUrl;
  final int categoryId;
  final ArticleState articleState;

  /// Media adapter prefix (e.g. `local-images`), discovered by the
  /// connection test. Null until the test has succeeded once.
  final String? mediaAdapter;

  String get apiBaseUrl => '$siteUrl/api/index.php/v1';

  JoomlaSettings copyWith({
    String? siteUrl,
    int? categoryId,
    ArticleState? articleState,
    String? mediaAdapter,
  }) {
    return JoomlaSettings(
      siteUrl: siteUrl ?? this.siteUrl,
      categoryId: categoryId ?? this.categoryId,
      articleState: articleState ?? this.articleState,
      mediaAdapter: mediaAdapter ?? this.mediaAdapter,
    );
  }

  @override
  String toString() =>
      'JoomlaSettings(siteUrl: $siteUrl, categoryId: $categoryId, '
      'articleState: ${articleState.name}, mediaAdapter: $mediaAdapter)';
}

/// A processed image that is ready to upload, but not uploaded yet.
class PendingImage {
  const PendingImage({
    required this.relativePath,
    required this.bytes,
    this.alt = '',
  });

  /// Path inside the images folder, e.g. `articles/2026/my-title-1.jpg`.
  final String relativePath;

  /// Final JPEG bytes (resized, EXIF stripped).
  final Uint8List bytes;
  final String alt;

  @override
  String toString() => 'PendingImage($relativePath, ${bytes.length} bytes)';
}

/// An image that is already on the server.
class UploadedImage {
  const UploadedImage({required this.path, this.alt = ''});

  /// Public path relative to the site root, e.g.
  /// `images/articles/2026/my-title-1.jpg`.
  final String path;
  final String alt;

  @override
  String toString() => 'UploadedImage($path)';
}

/// What the user wants to post: text plus images that still need uploading.
class ArticleDraft {
  const ArticleDraft({
    required this.title,
    required this.body,
    this.introImage,
    this.inlineImages = const [],
  });

  final String title;

  /// Plain text as typed by the user, may contain `[imgN]` markers.
  final String body;
  final PendingImage? introImage;

  /// Inline images; `[img1]` refers to the first entry.
  final List<PendingImage> inlineImages;
}

/// An error from the Joomla API or the network. [message] is already
/// sanitized and safe to show to the user; it never contains the token.
class JoomlaApiException implements Exception {
  const JoomlaApiException(this.message, {this.statusCode});

  final String message;

  /// HTTP status code, or null for network errors.
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'JoomlaApiException: $message'
      : 'JoomlaApiException ($statusCode): $message';
}
