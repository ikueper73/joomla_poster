import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:joomla_poster/api/joomla_client.dart';
import 'package:joomla_poster/api/models.dart';

const baseUrl = 'https://example.org/api/index.php/v1';
const token = 'secret-token-123';

JoomlaClient clientFor(MockClientHandler handler) => JoomlaClient(
  apiBaseUrl: baseUrl,
  token: token,
  httpClient: MockClient(handler),
);

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

/// Matches a [JoomlaApiException] of [kind]. The detail must never contain
/// the token; [detail] / [excludes] check it further.
TypeMatcher<JoomlaApiException> apiError(
  ApiErrorKind kind, {
  int? status,
  String? detail,
  String? excludes,
}) => isA<JoomlaApiException>()
    .having((e) => e.kind, 'kind', kind)
    .having((e) => e.statusCode, 'statusCode', status)
    .having(
      (e) => e.detail ?? '',
      'detail',
      allOf([
        isNot(contains(token)),
        detail == null ? anything : contains(detail),
        excludes == null ? anything : isNot(contains(excludes)),
      ]),
    );

void main() {
  group('verifyCategory', () {
    test('sends GET with auth headers and returns the title', () async {
      late http.Request sent;
      final client = clientFor((request) async {
        sent = request;
        return jsonResponse({
          'data': {
            'type': 'categories',
            'id': '12',
            'attributes': {'title': 'News'},
          },
        });
      });

      expect(await client.verifyCategory(12), 'News');
      expect(sent.method, 'GET');
      expect(sent.url.toString(), '$baseUrl/content/categories/12');
      expect(sent.headers['X-Joomla-Token'], token);
      expect(sent.headers['Accept'], 'application/vnd.api+json');
      expect(sent.headers.containsKey('Authorization'), isFalse);
    });

    test('returns empty title when attributes are missing', () async {
      final client = clientFor((_) async => jsonResponse({'data': {}}));
      expect(await client.verifyCategory(12), '');
    });

    test('401 explains the token problem', () async {
      final client = clientFor(
        (_) async => jsonResponse({
          'errors': [
            {'title': 'Forbidden', 'code': 401},
          ],
        }, 401),
      );
      await expectLater(
        client.verifyCategory(12),
        throwsA(
          apiError(ApiErrorKind.unauthorized, status: 401, detail: 'Forbidden'),
        ),
      );
    });

    test('404 mentions URL and category, includes API detail', () async {
      final client = clientFor(
        (_) async => jsonResponse({
          'errors': [
            {'title': 'Resource not found', 'code': 404},
          ],
        }, 404),
      );
      await expectLater(
        client.verifyCategory(99),
        throwsA(
          apiError(
            ApiErrorKind.notFound,
            status: 404,
            detail: 'Resource not found',
          ),
        ),
      );
    });

    test('error details are stripped of HTML and the token', () async {
      final client = clientFor(
        (_) async => jsonResponse({
          'errors': [
            {'title': '<b>Bad</b> token $token\n  given', 'code': 400},
          ],
        }, 400),
      );
      await expectLater(
        client.verifyCategory(12),
        throwsA(
          apiError(
            ApiErrorKind.requestFailed,
            status: 400,
            detail: 'Bad token *** given',
            excludes: '<b>',
          ),
        ),
      );
    });

    test('long error details are truncated', () async {
      final client = clientFor(
        (_) async => jsonResponse({
          'errors': [
            {'title': 'x' * 1000},
          ],
        }, 400),
      );
      await expectLater(
        client.verifyCategory(12),
        throwsA(
          isA<JoomlaApiException>().having(
            (e) => e.detail!.length,
            'detail length',
            lessThan(400),
          ),
        ),
      );
    });

    test('HTML error page gives server error without detail', () async {
      final client = clientFor(
        (_) async =>
            http.Response('<html><body>Fatal error</body></html>', 500),
      );
      await expectLater(
        client.verifyCategory(12),
        throwsA(
          apiError(
            ApiErrorKind.serverError,
            status: 500,
          ).having((e) => e.detail, 'detail', isNull),
        ),
      );
    });

    test('200 with non-JSON body is reported', () async {
      final client = clientFor(
        (_) async => http.Response('<html>Welcome</html>', 200),
      );
      await expectLater(
        client.verifyCategory(12),
        throwsA(apiError(ApiErrorKind.unexpectedResponse, status: 200)),
      );
    });

    test('network failure becomes a JoomlaApiException', () async {
      final client = clientFor(
        (_) async => throw http.ClientException('Connection refused'),
      );
      await expectLater(
        client.verifyCategory(12),
        throwsA(apiError(ApiErrorKind.network, detail: 'Connection refused')),
      );
    });

    test('timeout becomes a JoomlaApiException', () async {
      final client = JoomlaClient(
        apiBaseUrl: baseUrl,
        token: token,
        timeout: const Duration(milliseconds: 10),
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          return jsonResponse({});
        }),
      );
      await expectLater(
        client.verifyCategory(12),
        throwsA(apiError(ApiErrorKind.timeout)),
      );
    });
  });

  group('fetchMediaAdapter', () {
    Map<String, dynamic> adapter(String id, String name) => {
      'type': 'adapters',
      'id': id,
      'attributes': {'provider_id': 'local', 'name': name, 'path': '$id:/'},
    };

    test('sends GET with auth headers and returns the adapter id', () async {
      late http.Request sent;
      final client = clientFor((request) async {
        sent = request;
        return jsonResponse({
          'data': [adapter('local-images', 'images')],
        });
      });

      expect(await client.fetchMediaAdapter(), 'local-images');
      expect(sent.method, 'GET');
      expect(sent.url.toString(), '$baseUrl/media/adapters');
      expect(sent.headers['X-Joomla-Token'], token);
    });

    test('prefers the adapter for the images folder', () async {
      final client = clientFor(
        (_) async => jsonResponse({
          'data': [
            adapter('local-files', 'files'),
            adapter('local-0', 'images'),
          ],
        }),
      );
      expect(await client.fetchMediaAdapter(), 'local-0');
    });

    test('falls back to the first adapter', () async {
      final client = clientFor(
        (_) async => jsonResponse({
          'data': [adapter('local-files', 'files')],
        }),
      );
      expect(await client.fetchMediaAdapter(), 'local-files');
    });

    test('empty adapter list is an error', () async {
      final client = clientFor((_) async => jsonResponse({'data': []}));
      await expectLater(
        client.fetchMediaAdapter(),
        throwsA(apiError(ApiErrorKind.noMediaAdapters)),
      );
    });

    test('403 explains missing rights', () async {
      final client = clientFor((_) async => jsonResponse({}, 403));
      await expectLater(
        client.fetchMediaAdapter(),
        throwsA(apiError(ApiErrorKind.forbidden, status: 403)),
      );
    });
  });

  group('uploadImage', () {
    final image = PendingImage(
      relativePath: 'articles/2026/my-title-1.jpg',
      bytes: Uint8List.fromList([1, 2, 3, 255]),
      alt: 'A cat',
    );

    test('POSTs base64 content with adapter path', () async {
      late http.Request sent;
      final client = clientFor((request) async {
        sent = request;
        return jsonResponse({'data': {}});
      });

      final uploaded = await client.uploadImage('local-images', image);

      expect(uploaded.path, 'images/articles/2026/my-title-1.jpg');
      expect(uploaded.alt, 'A cat');
      expect(sent.method, 'POST');
      expect(sent.url.toString(), '$baseUrl/media/files');
      expect(sent.headers['X-Joomla-Token'], token);
      expect(sent.headers['Accept'], 'application/vnd.api+json');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['path'], 'local-images:/articles/2026/my-title-1.jpg');
      expect(base64Decode(body['content'] as String), [1, 2, 3, 255]);
    });

    test('413 says the file is too large', () async {
      final client = clientFor((_) async => http.Response('', 413));
      await expectLater(
        client.uploadImage('local-images', image),
        throwsA(apiError(ApiErrorKind.tooLarge, status: 413)),
      );
    });

    test('409 says the file already exists', () async {
      final client = clientFor((_) async => jsonResponse({}, 409));
      await expectLater(
        client.uploadImage('local-images', image),
        throwsA(apiError(ApiErrorKind.conflict, status: 409)),
      );
    });
  });

  group('createArticle', () {
    test('POSTs the article fields and returns the id', () async {
      late http.Request sent;
      final client = clientFor((request) async {
        sent = request;
        return jsonResponse({
          'data': {'type': 'articles', 'id': '42', 'attributes': {}},
        });
      });

      final id = await client.createArticle(
        title: 'Hello',
        articleHtml: '<p>World</p>',
        categoryId: 12,
        state: ArticleState.unpublished,
        introImage: const UploadedImage(
          path: 'images/articles/2026/a.jpg',
          alt: 'Intro',
        ),
      );

      expect(id, 42);
      expect(sent.method, 'POST');
      expect(sent.url.toString(), '$baseUrl/content/articles');
      expect(sent.headers['X-Joomla-Token'], token);
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {
        'title': 'Hello',
        'catid': 12,
        'articletext': '<p>World</p>',
        'state': 0,
        'language': '*',
        'images': {
          'image_intro': 'images/articles/2026/a.jpg',
          'image_intro_alt': 'Intro',
          'image_fulltext': 'images/articles/2026/a.jpg',
          'image_fulltext_alt': 'Intro',
        },
      });
    });

    test('sends no images and no alias without intro image', () async {
      late Map<String, dynamic> body;
      final client = clientFor((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse({
          'data': {'id': 7},
        });
      });

      final id = await client.createArticle(
        title: 'Hello',
        articleHtml: '<p>World</p>',
        categoryId: 12,
        state: ArticleState.published,
      );

      expect(id, 7);
      expect(body['state'], 1);
      expect(body.containsKey('images'), isFalse);
      expect(body.containsKey('alias'), isFalse);
    });

    test('returns null when the response has no id', () async {
      final client = clientFor((_) async => jsonResponse({'data': {}}));
      final id = await client.createArticle(
        title: 'Hello',
        articleHtml: '',
        categoryId: 12,
        state: ArticleState.unpublished,
      );
      expect(id, isNull);
    });

    test('surfaces API validation errors', () async {
      final client = clientFor(
        (_) async => jsonResponse({
          'errors': [
            {'title': 'Save failed: Please enter a title'},
          ],
        }, 400),
      );
      await expectLater(
        client.createArticle(
          title: '',
          articleHtml: '',
          categoryId: 12,
          state: ArticleState.unpublished,
        ),
        throwsA(
          apiError(
            ApiErrorKind.requestFailed,
            status: 400,
            detail: 'Please enter a title',
          ),
        ),
      );
    });
  });

  group('postArticle', () {
    PendingImage pending(String name, [String alt = '']) => PendingImage(
      relativePath: 'articles/2026/$name',
      bytes: Uint8List.fromList([1]),
      alt: alt,
    );

    String fakeHtml(String body, List<UploadedImage> images) =>
        '$body|${images.map((i) => '${i.path}:${i.alt}').join(',')}';

    test('uploads all images in order, then creates the article', () async {
      final requests = <http.Request>[];
      final client = clientFor((request) async {
        requests.add(request);
        return request.url.path.endsWith('/content/articles')
            ? jsonResponse({
                'data': {'id': '5'},
              })
            : jsonResponse({'data': {}});
      });
      final progress = <String>[];

      final id = await client.postArticle(
        ArticleDraft(
          title: 'Title',
          body: 'Text',
          introImage: pending('intro.jpg', 'Intro'),
          inlineImages: [pending('a.jpg', 'A'), pending('b.jpg', 'B')],
        ),
        adapter: 'local-images',
        categoryId: 12,
        state: ArticleState.unpublished,
        buildArticleHtml: fakeHtml,
        onProgress: (done, total) => progress.add('$done/$total'),
      );

      expect(id, 5);
      expect(requests.map((r) => r.url.path.split('/v1').last), [
        '/media/files',
        '/media/files',
        '/media/files',
        '/content/articles',
      ]);
      expect(
        requests
            .take(3)
            .map((r) => (jsonDecode(r.body) as Map<String, dynamic>)['path']),
        [
          'local-images:/articles/2026/intro.jpg',
          'local-images:/articles/2026/a.jpg',
          'local-images:/articles/2026/b.jpg',
        ],
      );
      final article = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(
        article['articletext'],
        'Text|images/articles/2026/a.jpg:A,images/articles/2026/b.jpg:B',
      );
      expect(
        (article['images'] as Map)['image_intro'],
        'images/articles/2026/intro.jpg',
      );
      expect(progress, ['0/3', '1/3', '2/3', '3/3']);
    });

    test('works without any images', () async {
      final requests = <http.Request>[];
      final client = clientFor((request) async {
        requests.add(request);
        return jsonResponse({
          'data': {'id': '1'},
        });
      });

      await client.postArticle(
        const ArticleDraft(title: 'Title', body: 'Text'),
        adapter: 'local-images',
        categoryId: 12,
        state: ArticleState.unpublished,
        buildArticleHtml: fakeHtml,
      );

      expect(requests, hasLength(1));
      final article = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(article['articletext'], 'Text|');
      expect(article.containsKey('images'), isFalse);
    });

    test('inline images only: none is used as intro image', () async {
      late Map<String, dynamic> article;
      final client = clientFor((request) async {
        if (request.url.path.endsWith('/content/articles')) {
          article = jsonDecode(request.body) as Map<String, dynamic>;
        }
        return jsonResponse({
          'data': {'id': '1'},
        });
      });

      await client.postArticle(
        ArticleDraft(title: 'T', body: 'B', inlineImages: [pending('a.jpg')]),
        adapter: 'local-images',
        categoryId: 12,
        state: ArticleState.unpublished,
        buildArticleHtml: fakeHtml,
      );

      expect(article['articletext'], 'B|images/articles/2026/a.jpg:');
      expect(article.containsKey('images'), isFalse);
    });

    test('a failed upload stops before creating the article', () async {
      final requests = <http.Request>[];
      final client = clientFor((request) async {
        requests.add(request);
        if (requests.length == 2) {
          return jsonResponse({
            'errors': [
              {'title': 'File type not allowed'},
            ],
          }, 400);
        }
        return jsonResponse({
          'data': {'id': '1'},
        });
      });

      await expectLater(
        client.postArticle(
          ArticleDraft(
            title: 'T',
            body: 'B',
            inlineImages: [
              pending('a.jpg'),
              pending('b.jpg'),
              pending('c.jpg'),
            ],
          ),
          adapter: 'local-images',
          categoryId: 12,
          state: ArticleState.unpublished,
          buildArticleHtml: fakeHtml,
        ),
        throwsA(
          isA<ImageUploadException>()
              .having((e) => e.number, 'number', 2)
              .having((e) => e.total, 'total', 3)
              .having(
                (e) => e.cause,
                'cause',
                apiError(
                  ApiErrorKind.requestFailed,
                  status: 400,
                  detail: 'File type not allowed',
                ),
              ),
        ),
      );
      expect(requests, hasLength(2));
      expect(
        requests.any((r) => r.url.path.endsWith('/content/articles')),
        isFalse,
      );
    });
  });
}
