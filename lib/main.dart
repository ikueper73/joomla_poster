import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    return MaterialApp(
      title: 'Joomla Poster',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: ComposeScreen(store: store),
    );
  }
}
