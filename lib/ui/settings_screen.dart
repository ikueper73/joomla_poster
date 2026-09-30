import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/joomla_client.dart';
import '../api/models.dart';
import '../services/settings_store.dart';

/// Creates an API client. Injectable so tests can use a mocked HTTP client.
typedef JoomlaClientFactory = JoomlaClient Function(
  String apiBaseUrl,
  String token,
);

JoomlaClient defaultClientFactory(String apiBaseUrl, String token) =>
    JoomlaClient(apiBaseUrl: apiBaseUrl, token: token);

/// Edits site URL, token, category and publish state. Settings are only
/// saved after a successful connection test, which also stores the media
/// adapter needed for uploads.
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
  String? _successMessage;
  String? _errorMessage;

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
      _successMessage = categoryTitle.isEmpty
          ? 'Connection OK. Settings saved.'
          : 'Connection OK: category "$categoryTitle". Settings saved.';
    } on JoomlaApiException catch (e) {
      _errorMessage = e.message;
    } on TokenStoreException catch (e) {
      _errorMessage = e.message;
    } finally {
      client?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasToken = widget.store.hasToken;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
                  TextFormField(
                    controller: _siteUrl,
                    decoration: const InputDecoration(
                      labelText: 'Site URL',
                      hintText: 'https://example.org',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (value) =>
                        SettingsStore.validateSiteUrl(value ?? ''),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _token,
                    decoration: InputDecoration(
                      labelText: 'API token',
                      helperText: hasToken
                          ? 'A token is saved. Leave empty to keep it.'
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    validator: (value) =>
                        !hasToken && (value ?? '').trim().isEmpty
                        ? 'Please enter the API token.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category ID',
                      helperText: 'Shown in the ID column of the category list',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final id = int.tryParse((value ?? '').trim());
                      return id == null || id < 1
                          ? 'Please enter the numeric category ID.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publish immediately'),
                    subtitle: const Text(
                      'When off, articles are saved unpublished so an editor '
                      'can review them on the site.',
                    ),
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
                    label: const Text('Test connection and save'),
                  ),
                  if (_successMessage != null)
                    _StatusMessage(
                      icon: Icons.check_circle,
                      color: theme.colorScheme.primary,
                      text: _successMessage!,
                    ),
                  if (_errorMessage != null)
                    _StatusMessage(
                      icon: Icons.error,
                      color: theme.colorScheme.error,
                      text: _errorMessage!,
                    ),
                  const SizedBox(height: 24),
                  const _HelpCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(text)),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Setting up Joomla', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              '• Create a dedicated Joomla user for this app with only the '
              'rights to create articles in this category and upload media. '
              'Never use a Super User token: anyone who gets the token can '
              'do everything that user can.\n'
              '• Get the token in that user\'s profile, tab "Joomla API '
              'Token".\n'
              '• These plugins must be enabled: "API Authentication - Web '
              'Services Joomla Token", "User - Joomla API Token", '
              '"Web Services - Content" and "Web Services - Media".',
            ),
          ],
        ),
      ),
    );
  }
}
