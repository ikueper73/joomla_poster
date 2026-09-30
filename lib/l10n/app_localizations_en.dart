// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Joomla Poster';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSystem => 'System language';

  @override
  String get siteUrlLabel => 'Site URL';

  @override
  String get tokenLabel => 'API token';

  @override
  String get tokenSavedHelper => 'A token is saved. Leave empty to keep it.';

  @override
  String get tokenRequired => 'Please enter the API token.';

  @override
  String get categoryIdLabel => 'Category ID';

  @override
  String get categoryIdHelper => 'Shown in the ID column of the category list';

  @override
  String get categoryIdRequired => 'Please enter the numeric category ID.';

  @override
  String get publishImmediately => 'Publish immediately';

  @override
  String get publishImmediatelyHint =>
      'When off, articles are saved unpublished so an editor can review them on the site.';

  @override
  String get testAndSave => 'Test connection and save';

  @override
  String get connectionOk => 'Connection OK. Settings saved.';

  @override
  String connectionOkCategory(String category) {
    return 'Connection OK: category \"$category\". Settings saved.';
  }

  @override
  String get helpTitle => 'Setting up Joomla';

  @override
  String get helpText =>
      '• Create a dedicated Joomla user for this app with only the rights to create articles in this category and upload media. Never use a Super User token: anyone who gets the token can do everything that user can.\n• Get the token in that user\'s profile, tab \"Joomla API Token\".\n• These plugins must be enabled: \"API Authentication - Web Services Joomla Token\", \"User - Joomla API Token\", \"Web Services - Content\" and \"Web Services - Media\".';

  @override
  String get urlEmpty => 'Please enter the site URL.';

  @override
  String get urlNotAbsolute =>
      'Please enter a full URL, e.g. https://example.org';

  @override
  String get urlHasExtras =>
      'Please enter only the site address, without login data, \"?\" or \"#\".';

  @override
  String get urlNotHttps =>
      'Only https:// URLs are allowed (http://localhost is allowed for development).';

  @override
  String get composeTitle => 'New article';

  @override
  String get titleLabel => 'Title';

  @override
  String get titleRequired => 'Please enter a title.';

  @override
  String get bodyLabel => 'Text';

  @override
  String get bodyHelper =>
      'Markdown: ### Heading, **bold**, *italic*, - list, [link](https://…). A line with --- ends the intro text (Read more). Place images with markers like [img1].';

  @override
  String get introImageHeading => 'Intro image';

  @override
  String get chooseIntroImage => 'Choose intro image';

  @override
  String get inlineImagesHeading => 'Inline images';

  @override
  String get addInlineImages => 'Add inline images';

  @override
  String get chooseImagesDialogTitle => 'Choose images';

  @override
  String get altTextLabel => 'Alt text (describes the image)';

  @override
  String insertMarkerTooltip(String marker) {
    return 'Insert $marker into text';
  }

  @override
  String get remove => 'Remove';

  @override
  String get cancel => 'Cancel';

  @override
  String get postArticle => 'Post article';

  @override
  String preparingImage(int current, int total) {
    return 'Preparing image $current of $total…';
  }

  @override
  String uploadingImage(int current, int total) {
    return 'Uploading image $current of $total…';
  }

  @override
  String get creatingArticle => 'Creating article…';

  @override
  String articleIdSuffix(int id) {
    return ' (ID $id)';
  }

  @override
  String articlePublished(String title, String idSuffix) {
    return 'Article \"$title\"$idSuffix was published.';
  }

  @override
  String articleCreatedUnpublished(String title, String idSuffix) {
    return 'Article \"$title\"$idSuffix was created unpublished and is waiting for review.';
  }

  @override
  String unknownMarkers(String markers, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inline images',
      one: '1 inline image',
      zero: 'no inline images',
    );
    return 'Your text contains markers without a matching image: $markers. You have $_temp0.';
  }

  @override
  String get unusedImagesTitle => 'Images without marker';

  @override
  String unusedImagesMessage(int count, String numbers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Images $numbers are not placed in the text. They will be added at the end of the article.',
      one:
          'Image $numbers is not placed in the text. It will be added at the end of the article.',
    );
    return '$_temp0';
  }

  @override
  String get postAnyway => 'Post anyway';

  @override
  String removeImageTitle(int number) {
    return 'Remove image $number?';
  }

  @override
  String removeImageMessage(int number, String nextMarker) {
    return 'Your text contains markers for image $number or later. After removing it, later images move up one number, so markers like $nextMarker will point to a different image. Check your markers afterwards.';
  }

  @override
  String get setupPrompt =>
      'Connect to your Joomla site first: enter URL, API token and category, then test the connection.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get errorTimeout =>
      'The site did not respond in time. Please try again.';

  @override
  String get errorNetwork => 'Could not reach the site.';

  @override
  String get errorUnexpectedResponse =>
      'Unexpected response from the site. Is the site URL correct?';

  @override
  String get errorNoMediaAdapters =>
      'The site reported no media adapters. Is the \"Web Services - Media\" plugin enabled?';

  @override
  String get errorUnauthorized => 'Authentication failed. Check the API token.';

  @override
  String get errorForbidden =>
      'Permission denied. The token user lacks the required rights.';

  @override
  String get errorNotFound => 'Not found. Check the site URL and category ID.';

  @override
  String get errorConflict =>
      'A file with this name already exists on the server.';

  @override
  String get errorTooLarge => 'The file is too large for the server.';

  @override
  String errorServer(int status) {
    return 'The site reported a server error ($status).';
  }

  @override
  String errorRequestFailed(int status) {
    return 'Request failed ($status).';
  }

  @override
  String errorWithDetail(String message, String detail) {
    return '$message Server said: $detail';
  }

  @override
  String errorImageUpload(int number, int total, String message) {
    return 'Image $number of $total could not be uploaded, so no article was created. $message';
  }

  @override
  String errorImageUnsupported(String fileName) {
    return '\"$fileName\" is not supported. Please use JPG, PNG or WebP images.';
  }

  @override
  String errorImageTooLarge(String fileName) {
    return '\"$fileName\" is too large (over 40 MB).';
  }

  @override
  String errorImageUnreadable(String fileName) {
    return '\"$fileName\" could not be read. Is it a valid image?';
  }

  @override
  String get errorKeyring =>
      'Could not access the system keyring to store the API token. On Linux, make sure a keyring service (e.g. GNOME Keyring or KWallet) is running and unlocked.';

  @override
  String get aboutTitle => 'About Joomla Poster';

  @override
  String get aboutLegalese =>
      '© 2026 Ingo Kueper\nLicensed under the GNU General Public License, version 3 or later.\nSource code: https://github.com/ikueper73/joomla_poster';
}
