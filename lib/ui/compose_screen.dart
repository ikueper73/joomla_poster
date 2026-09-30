import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/article_html.dart';
import '../api/joomla_client.dart';
import '../api/models.dart';
import '../services/image_service.dart';
import '../services/settings_store.dart';
import 'settings_screen.dart';

/// A local file chosen by the user.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Lets the user choose image files. Injectable for tests.
typedef ImagePicker = Future<List<PickedFile>> Function({
  required bool multiple,
});

Future<List<PickedFile>> pickImagesFromDisk({required bool multiple}) async {
  final files = multiple
      ? await FilePicker.pickFiles(
          dialogTitle: 'Choose images',
          type: FileType.custom,
          allowedExtensions: ImageService.allowedExtensions,
        )
      : [
          ?await FilePicker.pickFile(
            dialogTitle: 'Choose intro image',
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
  String? _progress;
  String? _successMessage;
  String? _errorMessage;

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
    final files = await widget.pickImages(multiple: false);
    if (files.isEmpty || !mounted) return;
    setState(() {
      _intro?.alt.dispose();
      _intro = _ImageEntry(files.first);
    });
  }

  Future<void> _pickInline() async {
    final files = await widget.pickImages(multiple: true);
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
        title: 'Remove image $number?',
        message:
            'Your text contains markers for image $number or later. After '
            'removing it, later images move up one number, so markers like '
            '[img${number + 1}] will point to a different image. '
            'Check your markers afterwards.',
        confirmLabel: 'Remove',
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
            child: const Text('Cancel'),
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
      setState(() {
        _errorMessage =
            'Your text contains markers without a matching image: '
            '${check.unknownMarkers.map((n) => '[img$n]').join(', ')}. '
            'You have ${_inline.length} inline image(s).';
      });
      return;
    }
    if (check.hasUnusedImages) {
      final confirmed = await _confirm(
        title: 'Images without marker',
        message:
            'Image(s) ${check.unusedImages.join(', ')} are not placed in the '
            'text. They will be added at the end of the article.',
        confirmLabel: 'Post anyway',
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
      _setProgress('Uploading images…');
      final id = await client.postArticle(
        draft,
        adapter: settings.mediaAdapter!,
        categoryId: settings.categoryId,
        state: settings.articleState,
        buildArticleHtml: buildArticleHtml,
        onProgress: (uploaded, total) => _setProgress(
          uploaded < total
              ? 'Uploading image ${uploaded + 1} of $total…'
              : 'Creating article…',
        ),
      );
      final idText = id == null ? '' : ' (ID $id)';
      _successMessage = settings.articleState == ArticleState.published
          ? 'Article "${draft.title}"$idText was published.'
          : 'Article "${draft.title}"$idText was created unpublished and '
                'is waiting for review.';
      _clearForm();
    } on JoomlaApiException catch (e) {
      _errorMessage = e.message;
    } on ImageProcessingException catch (e) {
      _errorMessage = e.message;
    } on TokenStoreException catch (e) {
      _errorMessage = e.message;
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
      _setProgress('Preparing image ${i + 1} of ${entries.length}…');
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

  void _setProgress(String text) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('New article'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: _busy ? null : _openSettings,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => widget.store.isComplete
            ? _buildForm(context)
            : _SetupPrompt(onOpenSettings: _openSettings),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
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
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Please enter a title.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _body,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Text',
                    helperText:
                        'Separate paragraphs with a blank line. Place inline '
                        'images with markers like [img1].',
                    helperMaxLines: 2,
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: 24),
                Text('Intro image', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_intro case final intro?)
                  _ImageTile(
                    entry: intro,
                    label: 'Intro image',
                    enabled: !_busy,
                    onRemove: _removeIntro,
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pickIntro,
                      icon: const Icon(Icons.image),
                      label: const Text('Choose intro image'),
                    ),
                  ),
                const SizedBox(height: 24),
                Text('Inline images', style: theme.textTheme.titleMedium),
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
                    label: const Text('Add inline images'),
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
                  label: Text(_progress ?? 'Post article'),
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
                    decoration: const InputDecoration(
                      labelText: 'Alt text (describes the image)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            if (onInsertMarker != null)
              IconButton(
                tooltip: 'Insert $label into text',
                icon: const Icon(Icons.input),
                onPressed: enabled ? onInsertMarker : null,
              ),
            IconButton(
              tooltip: 'Remove',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.settings_ethernet, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Connect to your Joomla site first: enter URL, API token and '
              'category, then test the connection.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onOpenSettings,
              child: const Text('Open settings'),
            ),
          ],
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
