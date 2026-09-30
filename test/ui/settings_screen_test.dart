import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:joomla_poster/api/joomla_client.dart';
import 'package:joomla_poster/api/models.dart';
import 'package:joomla_poster/services/settings_store.dart';
import 'package:joomla_poster/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

class FakeTokenStore implements TokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}

void main() {
  late FakeTokenStore tokens;
  late SettingsStore store;
  late List<http.Request> requests;
  late String? usedToken;

  /// Responds like a healthy Joomla site unless [status] says otherwise.
  JoomlaClientFactory fakeSite({int status = 200}) {
    return (apiBaseUrl, token) {
      usedToken = token;
      return JoomlaClient(
        apiBaseUrl: apiBaseUrl,
        token: token,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (status != 200) {
            return http.Response(
              jsonEncode({
                'errors': [
                  {'title': 'Forbidden'},
                ],
              }),
              status,
            );
          }
          if (request.url.path.endsWith('/media/adapters')) {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'local-images',
                    'attributes': {'name': 'images'},
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': {
                'attributes': {'title': 'News'},
              },
            }),
            200,
          );
        }),
      );
    };
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    JoomlaClientFactory? factory,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      localizedApp(
        SettingsScreen(store: store, clientFactory: factory ?? fakeSite()),
        locale: locale,
      ),
    );
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String url = 'https://example.org',
    String token = 'abc',
    String category = '12',
  }) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Site URL'), url);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'API token'),
      token,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Category ID'),
      category,
    );
  }

  Future<void> tapTestAndSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Test connection and save'));
    await tester.tap(find.text('Test connection and save'));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    tokens = FakeTokenStore();
    requests = [];
    usedToken = null;
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(
      prefs: await SharedPreferences.getInstance(),
      tokens: tokens,
    );
    await store.load();
  });

  testWidgets('successful test saves settings and adapter', (tester) async {
    await pumpScreen(tester);
    await fillForm(tester, url: 'https://example.org/');
    await tester.ensureVisible(find.text('Publish immediately'));
    await tester.tap(find.text('Publish immediately'));
    await tapTestAndSave(tester);

    expect(find.textContaining('category "News"'), findsOneWidget);
    expect(requests.map((r) => r.url.path), [
      '/api/index.php/v1/content/categories/12',
      '/api/index.php/v1/media/adapters',
    ]);
    expect(tokens.token, 'abc');
    final settings = store.settings!;
    expect(settings.siteUrl, 'https://example.org');
    expect(settings.categoryId, 12);
    expect(settings.articleState, ArticleState.published);
    expect(settings.mediaAdapter, 'local-images');
    expect(store.isComplete, isTrue);
  });

  testWidgets('failed test shows the error and saves nothing', (tester) async {
    await pumpScreen(tester, factory: fakeSite(status: 401));
    await fillForm(tester);
    await tapTestAndSave(tester);

    expect(find.textContaining('Check the API token'), findsOneWidget);
    expect(store.settings, isNull);
    expect(tokens.token, isNull);
  });

  testWidgets('invalid input is rejected before any request', (tester) async {
    await pumpScreen(tester);
    await fillForm(tester, url: 'http://example.org', token: '', category: '');
    await tapTestAndSave(tester);

    expect(find.textContaining('Only https:// URLs'), findsOneWidget);
    expect(find.text('Please enter the API token.'), findsOneWidget);
    expect(find.text('Please enter the numeric category ID.'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('empty token field reuses the saved token', (tester) async {
    tokens.token = 'saved-token';
    await store.save(
      const JoomlaSettings(siteUrl: 'https://example.org', categoryId: 12),
    );
    await store.load();
    await pumpScreen(tester);

    final urlField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Site URL'),
    );
    expect(urlField.controller!.text, 'https://example.org');
    expect(find.text('A token is saved. Leave empty to keep it.'), findsOne);

    await tapTestAndSave(tester);

    expect(usedToken, 'saved-token');
    expect(tokens.token, 'saved-token');
    expect(store.isComplete, isTrue);
  });

  testWidgets('help text warns against Super User tokens', (tester) async {
    await pumpScreen(tester);
    await tester.ensureVisible(find.textContaining('Super User'));
    expect(find.textContaining('Never use a Super User token'), findsOne);
  });

  testWidgets('language selector saves the choice immediately', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('System language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();

    expect(store.languageCode, 'de');
    expect(requests, isEmpty);
    expect(store.settings, isNull);
  });

  testWidgets('German UI shows German labels and errors', (tester) async {
    await pumpScreen(
      tester,
      factory: fakeSite(status: 401),
      locale: const Locale('de'),
    );
    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Website-URL'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Website-URL'),
      'http://example.org',
    );
    await tester.ensureVisible(find.text('Verbindung testen und speichern'));
    await tester.tap(find.text('Verbindung testen und speichern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nur https://-URLs'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Website-URL'),
      'https://example.org',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'API-Token'),
      'abc',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kategorie-ID'),
      '12',
    );
    await tester.ensureVisible(find.text('Verbindung testen und speichern'));
    await tester.tap(find.text('Verbindung testen und speichern'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Anmeldung fehlgeschlagen. Bitte den API-Token'),
      findsOneWidget,
    );
    expect(find.textContaining('Meldung des Servers: Forbidden'), findsOne);
  });

  testWidgets('about dialog shows author and license', (tester) async {
    await pumpScreen(tester);
    await tester.ensureVisible(find.text('About Joomla Poster'));
    await tester.tap(find.text('About Joomla Poster'));
    await tester.pumpAndSettle();

    expect(find.textContaining('© 2026 Ingo Kueper'), findsOneWidget);
    expect(find.textContaining('version 3 or later'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);
  });
}
