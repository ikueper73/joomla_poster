import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joomla_poster/api/models.dart';
import 'package:joomla_poster/l10n/app_localizations.dart';
import 'package:joomla_poster/services/image_service.dart';
import 'package:joomla_poster/services/settings_store.dart';
import 'package:joomla_poster/ui/error_text.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));

  test('every API error kind has a text in both languages', () {
    for (final kind in ApiErrorKind.values) {
      final error = JoomlaApiException(kind, statusCode: 500);
      for (final l10n in [en, de]) {
        final text = errorText(l10n, error);
        expect(text, isNotEmpty, reason: '${l10n.localeName} $kind');
        expect(text, isNot(contains('JoomlaApiException')));
      }
      expect(errorText(en, error), isNot(errorText(de, error)));
    }
  });

  test('server detail is appended', () {
    const error = JoomlaApiException(
      ApiErrorKind.forbidden,
      statusCode: 403,
      detail: 'No access',
    );
    expect(
      errorText(en, error),
      'Permission denied. The token user lacks the required rights. '
      'Server said: No access',
    );
    expect(errorText(de, error), endsWith('Meldung des Servers: No access'));
  });

  test('status codes appear in server and generic errors', () {
    expect(
      errorText(
        en,
        const JoomlaApiException(ApiErrorKind.serverError, statusCode: 503),
      ),
      contains('503'),
    );
    expect(
      errorText(
        de,
        const JoomlaApiException(ApiErrorKind.requestFailed, statusCode: 418),
      ),
      'Anfrage fehlgeschlagen (418).',
    );
  });

  test('upload errors wrap the cause', () {
    const error = ImageUploadException(
      number: 2,
      total: 3,
      cause: JoomlaApiException(ApiErrorKind.tooLarge, statusCode: 413),
    );
    expect(
      errorText(en, error),
      'Image 2 of 3 could not be uploaded, so no article was created. '
      'The file is too large for the server.',
    );
  });

  test('image and keyring errors are translated', () {
    for (final kind in ImageErrorKind.values) {
      final error = ImageProcessingException(kind, 'cat.heic');
      expect(errorText(en, error), contains('cat.heic'));
      expect(errorText(de, error), contains('„cat.heic“'));
    }
    expect(
      errorText(de, const TokenStoreException()),
      contains('Schlüsselbund'),
    );
  });

  test('every site URL error has a text in both languages', () {
    for (final error in SiteUrlError.values) {
      expect(siteUrlErrorText(en, error), isNotEmpty);
      expect(siteUrlErrorText(de, error), isNot(siteUrlErrorText(en, error)));
    }
  });
}
