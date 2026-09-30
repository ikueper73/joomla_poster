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

void main() {
  testWidgets('unconfigured app asks to open settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(
      prefs: await SharedPreferences.getInstance(),
      tokens: EmptyTokenStore(),
    );
    await store.load();

    await tester.pumpWidget(JoomlaPosterApp(store: store));
    expect(find.text('Open settings'), findsOneWidget);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Test connection and save'), findsOneWidget);
  });
}
