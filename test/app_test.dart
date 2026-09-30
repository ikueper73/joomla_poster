import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joomla_poster/main.dart';
import 'package:joomla_poster/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmptyTokenStore implements TokenStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}
}

Future<SettingsStore> createStore([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = SettingsStore(
    prefs: await SharedPreferences.getInstance(),
    tokens: EmptyTokenStore(),
  );
  await store.load();
  return store;
}

Locale currentLocale(WidgetTester tester) =>
    Localizations.localeOf(tester.element(find.byType(Scaffold).first));

void main() {
  testWidgets('unconfigured app asks to open settings', (tester) async {
    final store = await createStore();

    await tester.pumpWidget(JoomlaPosterApp(store: store));
    expect(find.text('Open settings'), findsOneWidget);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Test connection and save'), findsOneWidget);
  });

  group('language', () {
    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .clearLocalesTestValue();
    });

    testWidgets('follows a supported system language', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('de', 'DE')];
      await tester.pumpWidget(JoomlaPosterApp(store: await createStore()));
      expect(currentLocale(tester).languageCode, 'de');
    });

    testWidgets('falls back to English for other system languages', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = [const Locale('fr')];
      await tester.pumpWidget(JoomlaPosterApp(store: await createStore()));
      expect(currentLocale(tester).languageCode, 'en');
    });

    testWidgets('the chosen language overrides the system and applies live', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      final store = await createStore({'language': 'de'});
      await tester.pumpWidget(JoomlaPosterApp(store: store));
      expect(currentLocale(tester).languageCode, 'de');

      await store.setLanguage('en');
      await tester.pumpAndSettle();
      expect(currentLocale(tester).languageCode, 'en');
    });
  });
}
