import 'package:flutter/material.dart';
import 'package:joomla_poster/l10n/app_localizations.dart';

/// Wraps [home] in a MaterialApp with the app's localizations, English by
/// default so tests can look for English text.
Widget localizedApp(Widget home, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
