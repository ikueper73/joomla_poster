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

/// What went wrong in an API call. The UI turns this into a translated
/// message; the client itself produces no user-facing sentences.
enum ApiErrorKind {
  /// The site could not be reached (DNS, TLS, connection refused, …).
  network,
  timeout,

  /// A 2xx response that is not the expected JSON (e.g. an HTML page).
  unexpectedResponse,

  /// `GET /media/adapters` returned no adapters.
  noMediaAdapters,

  unauthorized, // 401
  forbidden, // 403
  notFound, // 404
  conflict, // 409, e.g. file already exists
  tooLarge, // 413
  serverError, // 5xx
  requestFailed, // any other non-2xx status
}

/// An error from the Joomla API or the network. Never contains the token.
class JoomlaApiException implements Exception {
  const JoomlaApiException(this.kind, {this.statusCode, this.detail});

  final ApiErrorKind kind;

  /// HTTP status code, or null for network errors and timeouts.
  final int? statusCode;

  /// Sanitized extra information: the JSON:API `errors` from the server
  /// (in the site's language) or the network error text. May be null.
  final String? detail;

  @override
  String toString() =>
      'JoomlaApiException(${kind.name}, status: $statusCode, detail: $detail)';
}

/// An image upload failed, so no article was created.
class ImageUploadException implements Exception {
  const ImageUploadException({
    required this.number,
    required this.total,
    required this.cause,
  });

  /// 1-based number of the failed image and the number of images.
  final int number;
  final int total;
  final JoomlaApiException cause;

  @override
  String toString() => 'ImageUploadException($number of $total): $cause';
}
