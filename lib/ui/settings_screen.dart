import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/joomla_client.dart';
import '../api/models.dart';
import '../l10n/app_localizations.dart';
import '../services/settings_store.dart';
import 'error_text.dart';
import 'status_message.dart';

/// Creates an API client. Injectable so tests can use a mocked HTTP client.
typedef JoomlaClientFactory = JoomlaClient Function(
  String apiBaseUrl,
  String token,
);

JoomlaClient defaultClientFactory(String apiBaseUrl, String token) =>
    JoomlaClient(apiBaseUrl: apiBaseUrl, token: token);

/// Edits language, site URL, token, category and publish state. The
/// language applies immediately; the connection settings are only saved
/// after a successful connection test, which also stores the media adapter
/// needed for uploads.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    this.clientFactory = defaultClientFactory,
  });

  final SettingsStore store;
  final JoomlaClientFactory clientFactory;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _siteUrl;
  late final TextEditingController _categoryId;
  final _token = TextEditingController();
  late bool _publishImmediately;

  bool _busy = false;

  // Built on demand, so they follow a language switch.
  String Function(AppLocalizations l10n)? _successMessage;
  String Function(AppLocalizations l10n)? _errorMessage;

  @override
  void initState() {
    super.initState();
    final settings = widget.store.settings;
    _siteUrl = TextEditingController(text: settings?.siteUrl ?? '');
    _categoryId = TextEditingController(
      text: settings == null ? '' : '${settings.categoryId}',
    );
    _publishImmediately = settings?.articleState == ArticleState.published;
  }

  @override
  void dispose() {
    _siteUrl.dispose();
    _categoryId.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    setState(() {
      _successMessage = null;
      _errorMessage = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    final enteredToken = _token.text.trim();
    final settings = JoomlaSettings(
      siteUrl: SettingsStore.normalizeSiteUrl(_siteUrl.text),
      categoryId: int.parse(_categoryId.text.trim()),
      articleState: _publishImmediately
          ? ArticleState.published
          : ArticleState.unpublished,
    );

    JoomlaClient? client;
    try {
      final token = enteredToken.isNotEmpty
          ? enteredToken
          : await widget.store.readToken() ?? '';
      client = widget.clientFactory(settings.apiBaseUrl, token);
      final categoryTitle = await client.verifyCategory(settings.categoryId);
      final adapter = await client.fetchMediaAdapter();
      await widget.store.save(
        settings.copyWith(mediaAdapter: adapter),
        token: enteredToken.isEmpty ? null : enteredToken,
      );
      _token.clear();
      _successMessage = (l10n) => categoryTitle.isEmpty
          ? l10n.connectionOk
          : l10n.connectionOkCategory(categoryTitle);
    } on JoomlaApiException catch (e) {
      _errorMessage = (l10n) => errorText(l10n, e);
    } on TokenStoreException catch (e) {
      _errorMessage = (l10n) => errorText(l10n, e);
    } finally {
      client?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasToken = widget.store.hasToken;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              // A Column (not a lazy ListView) keeps every field built, so
              // Form.validate() always checks all of them.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LanguageSelector(store: widget.store),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _siteUrl,
                    decoration: InputDecoration(
                      labelText: l10n.siteUrlLabel,
                      hintText: 'https://example.org',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (value) =>
                        switch (SettingsStore.validateSiteUrl(value ?? '')) {
                          final error? => siteUrlErrorText(l10n, error),
                          null => null,
                        },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _token,
                    decoration: InputDecoration(
                      labelText: l10n.tokenLabel,
                      helperText: hasToken ? l10n.tokenSavedHelper : null,
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    validator: (value) =>
                        !hasToken && (value ?? '').trim().isEmpty
                        ? l10n.tokenRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _categoryId,
                    decoration: InputDecoration(
                      labelText: l10n.categoryIdLabel,
                      helperText: l10n.categoryIdHelper,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final id = int.tryParse((value ?? '').trim());
                      return id == null || id < 1
                          ? l10n.categoryIdRequired
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.publishImmediately),
                    subtitle: Text(l10n.publishImmediatelyHint),
                    value: _publishImmediately,
                    onChanged: _busy
                        ? null
                        : (value) =>
                              setState(() => _publishImmediately = value),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _testAndSave,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: Text(l10n.testAndSave),
                  ),
                  if (_successMessage case final message?)
                    StatusMessage.success(message(l10n)),
                  if (_errorMessage case final message?)
                    StatusMessage.error(message(l10n)),
                  const SizedBox(height: 24),
                  const _HelpCard(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.info_outline),
                      label: Text(l10n.aboutTitle),
                      // Includes "View licenses" for the bundled packages,
                      // which their BSD/MIT licenses require us to show.
                      onPressed: () => showAboutDialog(
                        context: context,
                        applicationName: l10n.appTitle,
                        applicationLegalese: l10n.aboutLegalese,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Language choice; applies immediately, independent of the connection test.
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.store});

  final SettingsStore store;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<String?>(
      initialValue: store.languageCode,
      decoration: InputDecoration(
        labelText: l10n.languageLabel,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.languageSystem)),
        // Language names are shown in their own language on purpose.
        const DropdownMenuItem(value: 'en', child: Text('English')),
        const DropdownMenuItem(value: 'de', child: Text('Deutsch')),
      ],
      onChanged: store.setLanguage,
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.helpTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(l10n.helpText),
          ],
        ),
      ),
    );
  }
}
