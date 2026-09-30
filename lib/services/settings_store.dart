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
  const TokenStoreException(this.message);

  final String message;

  @override
  String toString() => 'TokenStoreException: $message';
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

  // PlatformException messages come from the OS and never contain the
  // token, but we still replace them with a fixed, readable message.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException {
      throw const TokenStoreException(
        'Could not access the system keyring to store the API token. '
        'On Linux, make sure a keyring service (e.g. GNOME Keyring or '
        'KWallet) is running and unlocked.',
      );
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

  JoomlaSettings? _settings;
  bool _hasToken = false;

  /// Null until a site URL and category ID have been saved.
  JoomlaSettings? get settings => _settings;
  bool get hasToken => _hasToken;

  /// True when everything needed for posting is present, including the
  /// media adapter that a successful connection test stores.
  bool get isComplete =>
      _settings != null && _hasToken && _settings!.mediaAdapter != null;

  Future<void> load() async {
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
    final token = await _tokens.read();
    _hasToken = token != null && token.isNotEmpty;
    notifyListeners();
  }

  /// Saves [settings]. The site URL must pass [validateSiteUrl]; it is
  /// stored normalized. Pass [token] only when it changed.
  Future<void> save(JoomlaSettings settings, {String? token}) async {
    final error = validateSiteUrl(settings.siteUrl);
    if (error != null) throw ArgumentError(error);
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

  /// Reads the token for an API call. Keep it only as long as needed.
  Future<String?> readToken() => _tokens.read();

  /// Trims whitespace and trailing slashes.
  static String normalizeSiteUrl(String input) =>
      input.trim().replaceFirst(RegExp(r'/+$'), '');

  /// Returns an error message, or null if [input] is an allowed site URL:
  /// `https://…`, or `http://localhost` / `http://127.0.0.1` for development.
  static String? validateSiteUrl(String input) {
    final text = normalizeSiteUrl(input);
    if (text.isEmpty) return 'Please enter the site URL.';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) {
      return 'Please enter a full URL, e.g. https://example.org';
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      return 'Please enter only the site address, without login data, '
          '"?" or "#".';
    }
    final isLocalhost = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (uri.scheme == 'https' || (uri.scheme == 'http' && isLocalhost)) {
      return null;
    }
    return 'Only https:// URLs are allowed '
        '(http://localhost is allowed for development).';
  }
}
