// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Joomla Poster';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get languageLabel => 'Sprache';

  @override
  String get languageSystem => 'Systemsprache';

  @override
  String get siteUrlLabel => 'Website-URL';

  @override
  String get tokenLabel => 'API-Token';

  @override
  String get tokenSavedHelper =>
      'Ein Token ist gespeichert. Leer lassen, um den gespeicherten Token zu behalten.';

  @override
  String get tokenRequired => 'Bitte den API-Token eingeben.';

  @override
  String get categoryIdLabel => 'Kategorie-ID';

  @override
  String get categoryIdHelper => 'Steht in der Spalte „ID“ der Kategorieliste';

  @override
  String get categoryIdRequired =>
      'Bitte die numerische Kategorie-ID eingeben.';

  @override
  String get publishImmediately => 'Sofort veröffentlichen';

  @override
  String get publishImmediatelyHint =>
      'Wenn aus, werden Beiträge unveröffentlicht gespeichert, damit sie auf der Website geprüft werden können.';

  @override
  String get testAndSave => 'Verbindung testen und speichern';

  @override
  String get connectionOk => 'Verbindung OK. Einstellungen gespeichert.';

  @override
  String connectionOkCategory(String category) {
    return 'Verbindung OK: Kategorie „$category“. Einstellungen gespeichert.';
  }

  @override
  String get helpTitle => 'Joomla einrichten';

  @override
  String get helpText =>
      '• Für diese App einen eigenen Joomla-Benutzer anlegen, der nur Beiträge in dieser Kategorie erstellen und Medien hochladen darf. Niemals den Token eines Super Users verwenden: Wer den Token hat, kann alles, was dieser Benutzer kann.\n• Der Token steht im Profil dieses Benutzers im Tab „Joomla-API-Token“.\n• Diese Plugins müssen aktiviert sein: „API-Authentifizierung - Webdienste Joomla-Token“, „Benutzer - Joomla-API-Token“, „Webdienste - Inhalte“ und „Webdienste - Medien“.';

  @override
  String get urlEmpty => 'Bitte die Website-URL eingeben.';

  @override
  String get urlNotAbsolute =>
      'Bitte eine vollständige URL eingeben, z. B. https://example.org';

  @override
  String get urlHasExtras =>
      'Bitte nur die Adresse der Website eingeben, ohne Zugangsdaten, „?“ oder „#“.';

  @override
  String get urlNotHttps =>
      'Nur https://-URLs sind erlaubt (http://localhost für die Entwicklung).';

  @override
  String get composeTitle => 'Neuer Beitrag';

  @override
  String get titleLabel => 'Titel';

  @override
  String get titleRequired => 'Bitte einen Titel eingeben.';

  @override
  String get bodyLabel => 'Text';

  @override
  String get bodyHelper =>
      'Absätze durch eine Leerzeile trennen. Bilder im Text mit Markern wie [img1] platzieren.';

  @override
  String get introImageHeading => 'Einleitungsbild';

  @override
  String get chooseIntroImage => 'Einleitungsbild auswählen';

  @override
  String get inlineImagesHeading => 'Bilder im Text';

  @override
  String get addInlineImages => 'Bilder hinzufügen';

  @override
  String get chooseImagesDialogTitle => 'Bilder auswählen';

  @override
  String get altTextLabel => 'Alternativtext (beschreibt das Bild)';

  @override
  String insertMarkerTooltip(String marker) {
    return '$marker in den Text einfügen';
  }

  @override
  String get remove => 'Entfernen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get postArticle => 'Beitrag senden';

  @override
  String preparingImage(int current, int total) {
    return 'Bild $current von $total wird vorbereitet…';
  }

  @override
  String uploadingImage(int current, int total) {
    return 'Bild $current von $total wird hochgeladen…';
  }

  @override
  String get creatingArticle => 'Beitrag wird erstellt…';

  @override
  String articleIdSuffix(int id) {
    return ' (ID $id)';
  }

  @override
  String articlePublished(String title, String idSuffix) {
    return 'Beitrag „$title“$idSuffix wurde veröffentlicht.';
  }

  @override
  String articleCreatedUnpublished(String title, String idSuffix) {
    return 'Beitrag „$title“$idSuffix wurde unveröffentlicht angelegt und wartet auf Prüfung.';
  }

  @override
  String unknownMarkers(String markers, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Es gibt $count Bilder im Text',
      one: 'Es gibt 1 Bild im Text',
      zero: 'Es gibt keine Bilder im Text',
    );
    return 'Der Text enthält Marker ohne passendes Bild: $markers. $_temp0.';
  }

  @override
  String get unusedImagesTitle => 'Bilder ohne Marker';

  @override
  String unusedImagesMessage(int count, String numbers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Die Bilder $numbers sind nicht im Text platziert. Sie werden am Ende des Beitrags angehängt.',
      one:
          'Bild $numbers ist nicht im Text platziert. Es wird am Ende des Beitrags angehängt.',
    );
    return '$_temp0';
  }

  @override
  String get postAnyway => 'Trotzdem senden';

  @override
  String removeImageTitle(int number) {
    return 'Bild $number entfernen?';
  }

  @override
  String removeImageMessage(int number, String nextMarker) {
    return 'Der Text enthält Marker für Bild $number oder spätere Bilder. Nach dem Entfernen rücken die folgenden Bilder eine Nummer nach vorne, sodass Marker wie $nextMarker auf ein anderes Bild zeigen. Bitte die Marker danach prüfen.';
  }

  @override
  String get setupPrompt =>
      'Zuerst die Verbindung zur Joomla-Website einrichten: URL, API-Token und Kategorie eingeben und die Verbindung testen.';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get errorTimeout =>
      'Die Website hat nicht rechtzeitig geantwortet. Bitte erneut versuchen.';

  @override
  String get errorNetwork => 'Die Website ist nicht erreichbar.';

  @override
  String get errorUnexpectedResponse =>
      'Unerwartete Antwort der Website. Ist die Website-URL richtig?';

  @override
  String get errorNoMediaAdapters =>
      'Die Website meldet keine Medien-Adapter. Ist das Plugin „Webdienste - Medien“ aktiviert?';

  @override
  String get errorUnauthorized =>
      'Anmeldung fehlgeschlagen. Bitte den API-Token prüfen.';

  @override
  String get errorForbidden =>
      'Zugriff verweigert. Dem Benutzer des Tokens fehlen die nötigen Rechte.';

  @override
  String get errorNotFound =>
      'Nicht gefunden. Bitte Website-URL und Kategorie-ID prüfen.';

  @override
  String get errorConflict =>
      'Eine Datei mit diesem Namen existiert bereits auf dem Server.';

  @override
  String get errorTooLarge => 'Die Datei ist zu groß für den Server.';

  @override
  String errorServer(int status) {
    return 'Die Website meldet einen Serverfehler ($status).';
  }

  @override
  String errorRequestFailed(int status) {
    return 'Anfrage fehlgeschlagen ($status).';
  }

  @override
  String errorWithDetail(String message, String detail) {
    return '$message Meldung des Servers: $detail';
  }

  @override
  String errorImageUpload(int number, int total, String message) {
    return 'Bild $number von $total konnte nicht hochgeladen werden, daher wurde kein Beitrag erstellt. $message';
  }

  @override
  String errorImageUnsupported(String fileName) {
    return '„$fileName“ wird nicht unterstützt. Bitte JPG-, PNG- oder WebP-Bilder verwenden.';
  }

  @override
  String errorImageTooLarge(String fileName) {
    return '„$fileName“ ist zu groß (über 40 MB).';
  }

  @override
  String errorImageUnreadable(String fileName) {
    return '„$fileName“ konnte nicht gelesen werden. Ist es ein gültiges Bild?';
  }

  @override
  String get errorKeyring =>
      'Kein Zugriff auf den Schlüsselbund des Systems, um den API-Token zu speichern. Unter Linux muss ein Schlüsselbund-Dienst (z. B. GNOME Keyring oder KWallet) laufen und entsperrt sein.';
}
