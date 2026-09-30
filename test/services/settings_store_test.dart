import 'package:flutter_test/flutter_test.dart';
import 'package:joomla_poster/api/models.dart';
import 'package:joomla_poster/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTokenStore implements TokenStore {
  String? token;
  bool broken = false;

  @override
  Future<String?> read() async {
    if (broken) throw const TokenStoreException('No keyring');
    return token;
  }

  @override
  Future<void> write(String token) async => this.token = token;
}

void main() {
  late FakeTokenStore tokens;

  Future<SettingsStore> createStore([
    Map<String, Object> initialPrefs = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final store = SettingsStore(
      prefs: await SharedPreferences.getInstance(),
      tokens: tokens,
    );
    await store.load();
    return store;
  }

  setUp(() => tokens = FakeTokenStore());

  group('load', () {
    test('empty storage gives no settings', () async {
      final store = await createStore();
      expect(store.settings, isNull);
      expect(store.hasToken, isFalse);
      expect(store.isComplete, isFalse);
    });

    test('reads saved values and token presence', () async {
      tokens.token = 'abc';
      final store = await createStore({
        'site_url': 'https://example.org',
        'category_id': 12,
        'article_state': 1,
        'media_adapter': 'local-images',
      });

      final settings = store.settings!;
      expect(settings.siteUrl, 'https://example.org');
      expect(settings.categoryId, 12);
      expect(settings.articleState, ArticleState.published);
      expect(settings.mediaAdapter, 'local-images');
      expect(store.hasToken, isTrue);
      expect(store.isComplete, isTrue);
    });

    test('an unavailable keyring does not break loading', () async {
      tokens.broken = true;
      final store = await createStore({
        'site_url': 'https://example.org',
        'category_id': 12,
      });
      expect(store.settings!.categoryId, 12);
      expect(store.hasToken, isFalse);
    });

    test('is not complete without media adapter', () async {
      tokens.token = 'abc';
      final store = await createStore({
        'site_url': 'https://example.org',
        'category_id': 12,
      });
      expect(store.settings!.articleState, ArticleState.unpublished);
      expect(store.isComplete, isFalse);
    });
  });

  group('save', () {
    test(
      'stores settings in prefs and token only in the token store',
      () async {
        final store = await createStore();
        var notified = 0;
        store.addListener(() => notified++);

        await store.save(
          const JoomlaSettings(
            siteUrl: ' https://example.org/ ',
            categoryId: 12,
            mediaAdapter: 'local-images',
          ),
          token: ' abc ',
        );

        expect(tokens.token, 'abc');
        expect(store.hasToken, isTrue);
        expect(store.settings!.siteUrl, 'https://example.org');
        expect(notified, 1);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('site_url'), 'https://example.org');
        expect(prefs.getInt('category_id'), 12);
        expect(prefs.getInt('article_state'), 0);
        expect(prefs.getString('media_adapter'), 'local-images');
        for (final key in prefs.getKeys()) {
          expect(prefs.get(key).toString(), isNot(contains('abc')));
        }
      },
    );

    test('keeps the token when none is passed', () async {
      tokens.token = 'abc';
      final store = await createStore();
      await store.save(
        const JoomlaSettings(siteUrl: 'https://example.org', categoryId: 3),
      );
      expect(tokens.token, 'abc');
      expect(await store.readToken(), 'abc');
    });

    test('removes a stale media adapter when none is given', () async {
      final store = await createStore({'media_adapter': 'local-old'});
      await store.save(
        const JoomlaSettings(siteUrl: 'https://example.org', categoryId: 3),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('media_adapter'), isFalse);
    });

    test('rejects a disallowed URL and stores nothing', () async {
      final store = await createStore();
      await expectLater(
        store.save(
          const JoomlaSettings(siteUrl: 'http://example.org', categoryId: 3),
          token: 'abc',
        ),
        throwsArgumentError,
      );
      expect(tokens.token, isNull);
      expect(store.settings, isNull);
    });
  });

  group('validateSiteUrl', () {
    test('accepts https and local development URLs', () {
      for (final url in [
        'https://example.org',
        'https://example.org/',
        'https://example.org/joomla',
        'https://example.org:8443',
        'http://localhost',
        'http://localhost:8080/joomla',
        'http://127.0.0.1',
      ]) {
        expect(SettingsStore.validateSiteUrl(url), isNull, reason: url);
      }
    });

    test('rejects everything else', () {
      for (final url in [
        '',
        '   ',
        'example.org',
        'http://example.org',
        'ftp://example.org',
        'https://',
        'https://user:pass@example.org',
        'https://example.org/?x=1',
        'https://example.org/#top',
        'http://localhost.evil.com',
      ]) {
        expect(SettingsStore.validateSiteUrl(url), isNotNull, reason: url);
      }
    });
  });

  test('normalizeSiteUrl trims whitespace and trailing slashes', () {
    expect(
      SettingsStore.normalizeSiteUrl('  https://example.org/joomla//  '),
      'https://example.org/joomla',
    );
  });
}
