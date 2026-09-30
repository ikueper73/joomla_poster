import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'services/settings_store.dart';
import 'ui/compose_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SettingsStore(
    prefs: await SharedPreferences.getInstance(),
    tokens: const SecureTokenStore(),
  );
  await store.load();
  runApp(JoomlaPosterApp(store: store));
}

class JoomlaPosterApp extends StatelessWidget {
  const JoomlaPosterApp({super.key, required this.store});

  final SettingsStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        // Null follows the system language.
        locale: switch (store.languageCode) {
          final code? => Locale(code),
          null => null,
        },
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        // English first: Flutter falls back to the first entry when the
        // system language is not supported. (The generated list is sorted
        // alphabetically and would start with German.)
        supportedLocales: const [Locale('en'), Locale('de')],
        home: ComposeScreen(store: store),
      ),
    );
  }
}
