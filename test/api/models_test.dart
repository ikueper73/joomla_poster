import 'package:flutter_test/flutter_test.dart';
import 'package:joomla_poster/api/models.dart';

void main() {
  group('ArticleState', () {
    test('maps to Joomla state values', () {
      expect(ArticleState.unpublished.value, 0);
      expect(ArticleState.published.value, 1);
    });

    test('fromValue falls back to unpublished', () {
      expect(ArticleState.fromValue(1), ArticleState.published);
      expect(ArticleState.fromValue(0), ArticleState.unpublished);
      expect(ArticleState.fromValue(42), ArticleState.unpublished);
    });
  });

  group('JoomlaSettings', () {
    const settings = JoomlaSettings(
      siteUrl: 'https://example.org',
      categoryId: 12,
    );

    test('defaults to unpublished and no adapter', () {
      expect(settings.articleState, ArticleState.unpublished);
      expect(settings.mediaAdapter, isNull);
    });

    test('builds the API base URL', () {
      expect(settings.apiBaseUrl, 'https://example.org/api/index.php/v1');
    });

    test('copyWith replaces only given fields', () {
      final copy = settings.copyWith(mediaAdapter: 'local-images');
      expect(copy.siteUrl, 'https://example.org');
      expect(copy.categoryId, 12);
      expect(copy.mediaAdapter, 'local-images');
    });
  });

  group('JoomlaApiException', () {
    test('toString names kind, status and detail', () {
      expect(
        const JoomlaApiException(
          ApiErrorKind.notFound,
          statusCode: 404,
          detail: 'Missing',
        ).toString(),
        'JoomlaApiException(notFound, status: 404, detail: Missing)',
      );
    });
  });
}
