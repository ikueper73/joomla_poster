import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/article_html.dart';
import '../api/joomla_client.dart';
import '../api/models.dart';
import '../l10n/app_localizations.dart';
import '../services/image_service.dart';
import '../services/settings_store.dart';
import 'error_text.dart';
import 'settings_screen.dart';
import 'status_message.dart';

/// A local file chosen by the user.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Lets the user choose image files. Injectable for tests.
typedef ImagePicker = Future<List<PickedFile>> Function({
  required bool multiple,
  required String dialogTitle,
});

Future<List<PickedFile>> pickImagesFromDisk({
  required bool multiple,
  required String dialogTitle,
}) async {
  final files = multiple
      ? await FilePicker.pickFiles(
          dialogTitle: dialogTitle,
          type: FileType.custom,
          allowedExtensions: ImageService.allowedExtensions,
        )
      : [
          ?await FilePicker.pickFile(
            dialogTitle: dialogTitle,
            type: FileType.custom,
            allowedExtensions: ImageService.allowedExtensions,
          ),
        ];
  return [
    for (final file in files)
      PickedFile(name: file.name, bytes: await file.readAsBytes()),
  ];
}

/// An image in the form, with its editable alt text.
class _ImageEntry {
  _ImageEntry(this.file);

  final PickedFile file;
  final alt = TextEditingController();
}

final _markerPattern = RegExp(r'\[img(\d+)\]');

/// Writes a new article: title, text with `[imgN]` markers, intro image
/// and inline images. Uploads the images, then creates the article.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    required this.store,
    this.clientFactory = defaultClientFactory,
    this.imageService = const ImageService(),
    this.pickImages = pickImagesFromDisk,
  });

  final SettingsStore store;
  final JoomlaClientFactory clientFactory;
  final ImageService imageService;
  final ImagePicker pickImages;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  _ImageEntry? _intro;
  final _inline = <_ImageEntry>[];

  bool _busy = false;

  // Built on demand, so they follow a language switch.
  String Function(AppLocalizations l10n)? _progress;
  String Function(AppLocalizations l10n)? _successMessage;
  String Function(AppLocalizations l10n)? _errorMessage;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _intro?.alt.dispose();
    for (final entry in _inline) {
      entry.alt.dispose();
    }
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          store: widget.store,
          clientFactory: widget.clientFactory,
        ),
      ),
    );
  }

  Future<void> _pickIntro() async {
    final files = await widget.pickImages(
      multiple: false,
      dialogTitle: _l10n.chooseIntroImage,
    );
    if (files.isEmpty || !mounted) return;
    setState(() {
      _intro?.alt.dispose();
      _intro = _ImageEntry(files.first);
    });
  }

  Future<void> _pickInline() async {
    final files = await widget.pickImages(
      multiple: true,
      dialogTitle: _l10n.chooseImagesDialogTitle,
    );
    if (files.isEmpty || !mounted) return;
    setState(() => _inline.addAll(files.map(_ImageEntry.new)));
  }

  void _removeIntro() {
    setState(() {
      _intro?.alt.dispose();
      _intro = null;
    });
  }

  /// Removing image N shifts all later images down by one. If the text has
  /// markers for N or later, they would silently point elsewhere: ask first.
  Future<void> _removeInline(int index) async {
    final number = index + 1;
    final affected = _markerPattern
        .allMatches(_body.text)
        .any((match) => int.parse(match[1]!) >= number);
    if (affected) {
      final confirmed = await _confirm(
        title: _l10n.removeImageTitle(number),
        message: _l10n.removeImageMessage(number, '[img${number + 1}]'),
        confirmLabel: _l10n.remove,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _inline.removeAt(index).alt.dispose());
  }

  /// Inserts `[imgN]` at the cursor, or at the end if the body has no focus.
  void _insertMarker(int number) {
    final marker = '[img$number]';
    final text = _body.text;
    final selection = _body.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    _body.value = TextEditingValue(
      text: text.replaceRange(start, end, marker),
      selection: TextSelection.collapsed(offset: start + marker.length),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _submit() async {
    setState(() {
      _successMessage = null;
      _errorMessage = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final check = checkImageMarkers(_body.text, _inline.length);
    if (check.hasUnknownMarkers) {
      final markers = check.unknownMarkers.map((n) => '[img$n]').join(', ');
      final count = _inline.length;
      setState(() {
        _errorMessage = (l10n) => l10n.unknownMarkers(markers, count);
      });
      return;
    }
    if (check.hasUnusedImages) {
      final confirmed = await _confirm(
        title: _l10n.unusedImagesTitle,
        message: _l10n.unusedImagesMessage(
          check.unusedImages.length,
          check.unusedImages.join(', '),
        ),
        confirmLabel: _l10n.postAnyway,
      );
      if (!confirmed || !mounted) return;
    }

    final settings = widget.store.settings!;
    setState(() => _busy = true);
    JoomlaClient? client;
    try {
      final draft = await _prepareDraft();
      final token = await widget.store.readToken() ?? '';
      client = widget.clientFactory(settings.apiBaseUrl, token);
      final id = await client.postArticle(
        draft,
        adapter: settings.mediaAdapter!,
        categoryId: settings.categoryId,
        state: settings.articleState,
        buildArticleHtml: buildArticleHtml,
        onProgress: (uploaded, total) => _setProgress(
          (l10n) => uploaded < total
              ? l10n.uploadingImage(uploaded + 1, total)
              : l10n.creatingArticle,
        ),
      );
      final title = draft.title;
      final published = settings.articleState == ArticleState.published;
      _successMessage = (l10n) {
        final idSuffix = id == null ? '' : l10n.articleIdSuffix(id);
        return published
            ? l10n.articlePublished(title, idSuffix)
            : l10n.articleCreatedUnpublished(title, idSuffix);
      };
      _clearForm();
    } on ImageUploadException catch (e) {
      _errorMessage = (l10n) => errorText(l10n, e);
    } on JoomlaApiException catch (e) {
      _errorMessage = (l10n) => errorText(l10n, e);
    } on ImageProcessingException catch (e) {
      _errorMessage = (l10n) => errorText(l10n, e);
    } on TokenStoreException catch (e) {
      _errorMessage = (l10n) => errorText(l10n, e);
    } finally {
      client?.close();
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  /// Resizes and re-encodes all images. Numbering: intro first, then the
  /// inline images in order.
  Future<ArticleDraft> _prepareDraft() async {
    final title = _title.text.trim();
    final now = DateTime.now();
    final entries = [?_intro, ..._inline];
    final prepared = <PendingImage>[];
    for (final (i, entry) in entries.indexed) {
      _setProgress((l10n) => l10n.preparingImage(i + 1, entries.length));
      prepared.add(
        await widget.imageService.prepare(
          fileName: entry.file.name,
          bytes: entry.file.bytes,
          relativePath: ImageService.uploadPath(
            title: title,
            number: i + 1,
            time: now,
          ),
          alt: entry.alt.text.trim(),
        ),
      );
    }
    return ArticleDraft(
      title: title,
      body: _body.text,
      introImage: _intro == null ? null : prepared.first,
      inlineImages: _intro == null ? prepared : prepared.sublist(1),
    );
  }

  void _setProgress(String Function(AppLocalizations l10n) text) {
    if (mounted) setState(() => _progress = text);
  }

  void _clearForm() {
    _title.clear();
    _body.clear();
    _intro?.alt.dispose();
    _intro = null;
    for (final entry in _inline) {
      entry.alt.dispose();
    }
    _inline.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.composeTitle),
        actions: [
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings),
            onPressed: _busy ? null : _openSettings,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => widget.store.isComplete
            ? _buildForm(context, l10n)
            : _SetupPrompt(onOpenSettings: _openSettings),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
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
                  controller: _title,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: l10n.titleLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? l10n.titleRequired : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _body,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: l10n.bodyLabel,
                    helperText: l10n.bodyHelper,
                    helperMaxLines: 3,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.introImageHeading,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_intro case final intro?)
                  _ImageTile(
                    entry: intro,
                    label: l10n.introImageHeading,
                    enabled: !_busy,
                    onRemove: _removeIntro,
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pickIntro,
                      icon: const Icon(Icons.image),
                      label: Text(l10n.chooseIntroImage),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  l10n.inlineImagesHeading,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final (i, entry) in _inline.indexed)
                  _ImageTile(
                    entry: entry,
                    label: '[img${i + 1}]',
                    enabled: !_busy,
                    onInsertMarker: () => _insertMarker(i + 1),
                    onRemove: () => _removeInline(i),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickInline,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: Text(l10n.addInlineImages),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_progress?.call(l10n) ?? l10n.postArticle),
                ),
                if (_successMessage case final message?)
                  StatusMessage.success(message(l10n)),
                if (_errorMessage case final message?)
                  StatusMessage.error(message(l10n)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.entry,
    required this.label,
    required this.enabled,
    required this.onRemove,
    this.onInsertMarker,
  });

  final _ImageEntry entry;
  final String label;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback? onInsertMarker;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                entry.file.bytes,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                cacheWidth: 160,
                errorBuilder: (_, _, _) => const SizedBox.square(
                  dimension: 80,
                  child: Icon(Icons.broken_image),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label  ·  ${entry.file.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: entry.alt,
                    enabled: enabled,
                    decoration: InputDecoration(
                      labelText: l10n.altTextLabel,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            if (onInsertMarker != null)
              IconButton(
                tooltip: l10n.insertMarkerTooltip(label),
                icon: const Icon(Icons.input),
                onPressed: enabled ? onInsertMarker : null,
              ),
            IconButton(
              tooltip: l10n.remove,
              icon: const Icon(Icons.delete_outline),
              onPressed: enabled ? onRemove : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupPrompt extends StatelessWidget {
  const _SetupPrompt({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.settings_ethernet, size: 48),
            const SizedBox(height: 16),
            Text(l10n.setupPrompt, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onOpenSettings,
              child: Text(l10n.openSettings),
            ),
          ],
        ),
      ),
    );
  }
}
