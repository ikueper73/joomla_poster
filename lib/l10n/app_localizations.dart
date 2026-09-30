import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Joomla Poster'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get languageSystem;

  /// No description provided for @siteUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Site URL'**
  String get siteUrlLabel;

  /// No description provided for @tokenLabel.
  ///
  /// In en, this message translates to:
  /// **'API token'**
  String get tokenLabel;

  /// No description provided for @tokenSavedHelper.
  ///
  /// In en, this message translates to:
  /// **'A token is saved. Leave empty to keep it.'**
  String get tokenSavedHelper;

  /// No description provided for @tokenRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the API token.'**
  String get tokenRequired;

  /// No description provided for @categoryIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Category ID'**
  String get categoryIdLabel;

  /// No description provided for @categoryIdHelper.
  ///
  /// In en, this message translates to:
  /// **'Shown in the ID column of the category list'**
  String get categoryIdHelper;

  /// No description provided for @categoryIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the numeric category ID.'**
  String get categoryIdRequired;

  /// No description provided for @publishImmediately.
  ///
  /// In en, this message translates to:
  /// **'Publish immediately'**
  String get publishImmediately;

  /// No description provided for @publishImmediatelyHint.
  ///
  /// In en, this message translates to:
  /// **'When off, articles are saved unpublished so an editor can review them on the site.'**
  String get publishImmediatelyHint;

  /// No description provided for @testAndSave.
  ///
  /// In en, this message translates to:
  /// **'Test connection and save'**
  String get testAndSave;

  /// No description provided for @connectionOk.
  ///
  /// In en, this message translates to:
  /// **'Connection OK. Settings saved.'**
  String get connectionOk;

  /// No description provided for @connectionOkCategory.
  ///
  /// In en, this message translates to:
  /// **'Connection OK: category \"{category}\". Settings saved.'**
  String connectionOkCategory(String category);

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Setting up Joomla'**
  String get helpTitle;

  /// No description provided for @helpText.
  ///
  /// In en, this message translates to:
  /// **'• Create a dedicated Joomla user for this app with only the rights to create articles in this category and upload media. Never use a Super User token: anyone who gets the token can do everything that user can.\n• Get the token in that user\'s profile, tab \"Joomla API Token\".\n• These plugins must be enabled: \"API Authentication - Web Services Joomla Token\", \"User - Joomla API Token\", \"Web Services - Content\" and \"Web Services - Media\".'**
  String get helpText;

  /// No description provided for @urlEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter the site URL.'**
  String get urlEmpty;

  /// No description provided for @urlNotAbsolute.
  ///
  /// In en, this message translates to:
  /// **'Please enter a full URL, e.g. https://example.org'**
  String get urlNotAbsolute;

  /// No description provided for @urlHasExtras.
  ///
  /// In en, this message translates to:
  /// **'Please enter only the site address, without login data, \"?\" or \"#\".'**
  String get urlHasExtras;

  /// No description provided for @urlNotHttps.
  ///
  /// In en, this message translates to:
  /// **'Only https:// URLs are allowed (http://localhost is allowed for development).'**
  String get urlNotHttps;

  /// No description provided for @composeTitle.
  ///
  /// In en, this message translates to:
  /// **'New article'**
  String get composeTitle;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title.'**
  String get titleRequired;

  /// No description provided for @bodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get bodyLabel;

  /// No description provided for @bodyHelper.
  ///
  /// In en, this message translates to:
  /// **'Markdown: ### Heading, **bold**, *italic*, - list, [link](https://…). A line with --- ends the intro text (Read more). Place images with markers like [img1].'**
  String get bodyHelper;

  /// No description provided for @introImageHeading.
  ///
  /// In en, this message translates to:
  /// **'Intro image'**
  String get introImageHeading;

  /// No description provided for @chooseIntroImage.
  ///
  /// In en, this message translates to:
  /// **'Choose intro image'**
  String get chooseIntroImage;

  /// No description provided for @inlineImagesHeading.
  ///
  /// In en, this message translates to:
  /// **'Inline images'**
  String get inlineImagesHeading;

  /// No description provided for @addInlineImages.
  ///
  /// In en, this message translates to:
  /// **'Add inline images'**
  String get addInlineImages;

  /// No description provided for @chooseImagesDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose images'**
  String get chooseImagesDialogTitle;

  /// No description provided for @altTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Alt text (describes the image)'**
  String get altTextLabel;

  /// No description provided for @insertMarkerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Insert {marker} into text'**
  String insertMarkerTooltip(String marker);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @postArticle.
  ///
  /// In en, this message translates to:
  /// **'Post article'**
  String get postArticle;

  /// No description provided for @preparingImage.
  ///
  /// In en, this message translates to:
  /// **'Preparing image {current} of {total}…'**
  String preparingImage(int current, int total);

  /// No description provided for @uploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Uploading image {current} of {total}…'**
  String uploadingImage(int current, int total);

  /// No description provided for @creatingArticle.
  ///
  /// In en, this message translates to:
  /// **'Creating article…'**
  String get creatingArticle;

  /// No description provided for @articleIdSuffix.
  ///
  /// In en, this message translates to:
  /// **' (ID {id})'**
  String articleIdSuffix(int id);

  /// No description provided for @articlePublished.
  ///
  /// In en, this message translates to:
  /// **'Article \"{title}\"{idSuffix} was published.'**
  String articlePublished(String title, String idSuffix);

  /// No description provided for @articleCreatedUnpublished.
  ///
  /// In en, this message translates to:
  /// **'Article \"{title}\"{idSuffix} was created unpublished and is waiting for review.'**
  String articleCreatedUnpublished(String title, String idSuffix);

  /// No description provided for @unknownMarkers.
  ///
  /// In en, this message translates to:
  /// **'Your text contains markers without a matching image: {markers}. You have {count, plural, =0{no inline images} =1{1 inline image} other{{count} inline images}}.'**
  String unknownMarkers(String markers, int count);

  /// No description provided for @unusedImagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Images without marker'**
  String get unusedImagesTitle;

  /// No description provided for @unusedImagesMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Image {numbers} is not placed in the text. It will be added at the end of the article.} other{Images {numbers} are not placed in the text. They will be added at the end of the article.}}'**
  String unusedImagesMessage(int count, String numbers);

  /// No description provided for @postAnyway.
  ///
  /// In en, this message translates to:
  /// **'Post anyway'**
  String get postAnyway;

  /// No description provided for @removeImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove image {number}?'**
  String removeImageTitle(int number);

  /// No description provided for @removeImageMessage.
  ///
  /// In en, this message translates to:
  /// **'Your text contains markers for image {number} or later. After removing it, later images move up one number, so markers like {nextMarker} will point to a different image. Check your markers afterwards.'**
  String removeImageMessage(int number, String nextMarker);

  /// No description provided for @setupPrompt.
  ///
  /// In en, this message translates to:
  /// **'Connect to your Joomla site first: enter URL, API token and category, then test the connection.'**
  String get setupPrompt;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The site did not respond in time. Please try again.'**
  String get errorTimeout;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the site.'**
  String get errorNetwork;

  /// No description provided for @errorUnexpectedResponse.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response from the site. Is the site URL correct?'**
  String get errorUnexpectedResponse;

  /// No description provided for @errorNoMediaAdapters.
  ///
  /// In en, this message translates to:
  /// **'The site reported no media adapters. Is the \"Web Services - Media\" plugin enabled?'**
  String get errorNoMediaAdapters;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Check the API token.'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'Permission denied. The token user lacks the required rights.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found. Check the site URL and category ID.'**
  String get errorNotFound;

  /// No description provided for @errorConflict.
  ///
  /// In en, this message translates to:
  /// **'A file with this name already exists on the server.'**
  String get errorConflict;

  /// No description provided for @errorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is too large for the server.'**
  String get errorTooLarge;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'The site reported a server error ({status}).'**
  String errorServer(int status);

  /// No description provided for @errorRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed ({status}).'**
  String errorRequestFailed(int status);

  /// No description provided for @errorWithDetail.
  ///
  /// In en, this message translates to:
  /// **'{message} Server said: {detail}'**
  String errorWithDetail(String message, String detail);

  /// No description provided for @errorImageUpload.
  ///
  /// In en, this message translates to:
  /// **'Image {number} of {total} could not be uploaded, so no article was created. {message}'**
  String errorImageUpload(int number, int total, String message);

  /// No description provided for @errorImageUnsupported.
  ///
  /// In en, this message translates to:
  /// **'\"{fileName}\" is not supported. Please use JPG, PNG or WebP images.'**
  String errorImageUnsupported(String fileName);

  /// No description provided for @errorImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'\"{fileName}\" is too large (over 40 MB).'**
  String errorImageTooLarge(String fileName);

  /// No description provided for @errorImageUnreadable.
  ///
  /// In en, this message translates to:
  /// **'\"{fileName}\" could not be read. Is it a valid image?'**
  String errorImageUnreadable(String fileName);

  /// No description provided for @errorKeyring.
  ///
  /// In en, this message translates to:
  /// **'Could not access the system keyring to store the API token. On Linux, make sure a keyring service (e.g. GNOME Keyring or KWallet) is running and unlocked.'**
  String get errorKeyring;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
