import 'dart:convert';

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

TypeMatcher<JoomlaApiException> apiError({
  int? status,
  String? mentions,
  String? excludes,
}) => isA<JoomlaApiException>()
    .having((e) => e.statusCode, 'statusCode', status)
    .having(
      (e) => e.message,
      'message',
      allOf([
        isNot(contains(token)),
        mentions == null ? anything : contains(mentions),
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
        throwsA(apiError(status: 401, mentions: 'Check the API token')),
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
            status: 404,
            mentions: 'category ID',
          ).having((e) => e.message, 'message', contains('Resource not found')),
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
            status: 400,
            mentions: 'Bad token *** given',
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
            (e) => e.message.length,
            'message length',
            lessThan(400),
          ),
        ),
      );
    });

    test('HTML error page gives a generic message', () async {
      final client = clientFor(
        (_) async =>
            http.Response('<html><body>Fatal error</body></html>', 500),
      );
      await expectLater(
        client.verifyCategory(12),
        throwsA(
          apiError(status: 500, mentions: 'server error', excludes: '<html>'),
        ),
      );
    });

    test('200 with non-JSON body is reported', () async {
      final client = clientFor(
        (_) async => http.Response('<html>Welcome</html>', 200),
      );
      await expectLater(
        client.verifyCategory(12),
        throwsA(apiError(status: 200, mentions: 'site URL')),
      );
    });

    test('network failure becomes a JoomlaApiException', () async {
      final client = clientFor(
        (_) async => throw http.ClientException('Connection refused'),
      );
      await expectLater(
        client.verifyCategory(12),
        throwsA(apiError(mentions: 'Could not reach the site')),
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
        throwsA(apiError(mentions: 'did not respond')),
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
        throwsA(apiError(mentions: 'Web Services - Media')),
      );
    });

    test('403 explains missing rights', () async {
      final client = clientFor((_) async => jsonResponse({}, 403));
      await expectLater(
        client.fetchMediaAdapter(),
        throwsA(apiError(status: 403, mentions: 'Permission denied')),
      );
    });
  });
}
