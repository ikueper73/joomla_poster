import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';

/// Where the API token lives. Abstracted so tests can use a fake.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
}

/// Thrown when the system keyring cannot be used.
class TokenStoreException implements Exception {
  const TokenStoreException();

  @override
  String toString() => 'TokenStoreException: system keyring unavailable';
}

/// Why a site URL was rejected by [SettingsStore.validateSiteUrl].
enum SiteUrlError {
  empty,

  /// Not a full URL with scheme and host.
  notAbsolute,

  /// Contains login data, a query or a fragment.
  hasExtras,

  /// Neither https nor http://localhost.
  notHttps,
}

/// Keeps the token in the OS keyring (Windows Credential Manager,
/// libsecret on Linux). Never in shared preferences.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _key = 'joomla_api_token';

  @override
  Future<String?> read() => _guard(() => _storage.read(key: _key));

  @override
  Future<void> write(String token) =>
      _guard(() => _storage.write(key: _key, value: token));

  // PlatformException details come from the OS; the UI shows a fixed,
  // translated message instead.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException {
      throw const TokenStoreException();
    }
  }
}

/// Loads and saves the connection settings. Non-secret values go to
/// shared preferences, the token goes to the [TokenStore].
class SettingsStore extends ChangeNotifier {
  SettingsStore({required this._prefs, required this._tokens});

  final SharedPreferences _prefs;
  final TokenStore _tokens;

  static const _siteUrlKey = 'site_url';
  static const _categoryIdKey = 'category_id';
  static const _articleStateKey = 'article_state';
  static const _mediaAdapterKey = 'media_adapter';
  static const _languageKey = 'language';

  /// Language codes the UI is translated to.
  static const supportedLanguages = ['en', 'de'];

  JoomlaSettings? _settings;
  bool _hasToken = false;
  String? _languageCode;

  /// Null until a site URL and category ID have been saved.
  JoomlaSettings? get settings => _settings;
  bool get hasToken => _hasToken;

  /// UI language chosen by the user, or null to follow the system.
  String? get languageCode => _languageCode;

  /// True when everything needed for posting is present, including the
  /// media adapter that a successful connection test stores.
  bool get isComplete =>
      _settings != null && _hasToken && _settings!.mediaAdapter != null;

  Future<void> load() async {
    final language = _prefs.getString(_languageKey);
    _languageCode = supportedLanguages.contains(language) ? language : null;
    final siteUrl = _prefs.getString(_siteUrlKey);
    final categoryId = _prefs.getInt(_categoryIdKey);
    _settings = siteUrl == null || categoryId == null
        ? null
        : JoomlaSettings(
            siteUrl: siteUrl,
            categoryId: categoryId,
            articleState: ArticleState.fromValue(
              _prefs.getInt(_articleStateKey) ?? 0,
            ),
            mediaAdapter: _prefs.getString(_mediaAdapterKey),
          );
    try {
      final token = await _tokens.read();
      _hasToken = token != null && token.isNotEmpty;
    } on TokenStoreException {
      // Keyring unavailable: start anyway. Saving a token in the settings
      // screen will then show the readable error.
      _hasToken = false;
    }
    notifyListeners();
  }

  /// Saves [settings]. The site URL must pass [validateSiteUrl]; it is
  /// stored normalized. Pass [token] only when it changed.
  Future<void> save(JoomlaSettings settings, {String? token}) async {
    final error = validateSiteUrl(settings.siteUrl);
    if (error != null) throw ArgumentError('Invalid site URL: ${error.name}');
    final normalized = settings.copyWith(
      siteUrl: normalizeSiteUrl(settings.siteUrl),
    );

    if (token != null) {
      await _tokens.write(token.trim());
      _hasToken = token.trim().isNotEmpty;
    }
    await _prefs.setString(_siteUrlKey, normalized.siteUrl);
    await _prefs.setInt(_categoryIdKey, normalized.categoryId);
    await _prefs.setInt(_articleStateKey, normalized.articleState.value);
    final adapter = normalized.mediaAdapter;
    if (adapter == null) {
      await _prefs.remove(_mediaAdapterKey);
    } else {
      await _prefs.setString(_mediaAdapterKey, adapter);
    }
    _settings = normalized;
    notifyListeners();
  }

  /// Sets the UI language; null follows the system. Saved immediately,
  /// independent of the connection settings.
  Future<void> setLanguage(String? languageCode) async {
    if (languageCode != null && !supportedLanguages.contains(languageCode)) {
      throw ArgumentError.value(languageCode, 'languageCode');
    }
    if (languageCode == null) {
      await _prefs.remove(_languageKey);
    } else {
      await _prefs.setString(_languageKey, languageCode);
    }
    _languageCode = languageCode;
    notifyListeners();
  }

  /// Reads the token for an API call. Keep it only as long as needed.
  Future<String?> readToken() => _tokens.read();

  /// Trims whitespace and trailing slashes.
  static String normalizeSiteUrl(String input) =>
      input.trim().replaceFirst(RegExp(r'/+$'), '');

  /// Returns why [input] is rejected, or null if it is an allowed site URL:
  /// `https://…`, or `http://localhost` / `http://127.0.0.1` for development.
  static SiteUrlError? validateSiteUrl(String input) {
    final text = normalizeSiteUrl(input);
    if (text.isEmpty) return SiteUrlError.empty;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return SiteUrlError.notAbsolute;
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      return SiteUrlError.hasExtras;
    }
    final isLocalhost = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (uri.scheme == 'https' || (uri.scheme == 'http' && isLocalhost)) {
      return null;
    }
    return SiteUrlError.notHttps;
  }
}
