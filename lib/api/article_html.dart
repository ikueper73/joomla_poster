import 'dart:convert';

import 'package:markdown/markdown.dart' as md;

import 'models.dart';

/// Matches image markers like `[img1]`; group 1 is the 1-based number.
final _marker = RegExp(r'\[img(\d+)\]');

/// Escapes `& < > " '` but, unlike the default [HtmlEscape], not `/`,
/// so ordinary text and paths stay readable. Safe in text and attributes.
const _escape = HtmlEscape(
  HtmlEscapeMode(escapeLtGt: true, escapeQuot: true, escapeApos: true),
);

/// Joomla's "Read more" separator: text before it is the intro text.
const readMoreTag = '<hr id="system-readmore">';

/// Tags copied to the output as they are (without attributes).
const _allowedTags = {
  'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', //
  'ul', 'ol', 'li', 'blockquote', 'pre', 'code', 'strong', 'em', 'br',
};

/// Turns the user's Markdown into article HTML.
///
/// Supported: headings (`### Lead` → `<h3>`), paragraphs, **bold**,
/// *italic*, lists, quotes, code, links, and `---` on its own line
/// (with a blank line before it) as Joomla's "Read more" separator.
///
/// Safety: the output is built by our own renderer, not the markdown
/// package's. All text is HTML-escaped, only [_allowedTags] and safe links
/// are emitted, raw HTML typed by the user is shown literally, and
/// Markdown images (`![](…)`) are reduced to their alt text: images must
/// be uploaded through the app.
///
/// `[imgN]` is replaced with the N-th of [inlineImages] (not inside code).
/// Unknown markers stay as literal text (see [checkImageMarkers]). Images
/// that are never referenced are appended at the end.
String buildArticleHtml(String body, List<UploadedImage> inlineImages) {
  final renderer = _Renderer(inlineImages);
  final blocks = [for (final node in _parse(body)) renderer.renderBlock(node)];
  for (var i = 0; i < inlineImages.length; i++) {
    if (!renderer.usedImages.contains(i)) {
      blocks.add('<p>${_imgTag(inlineImages[i])}</p>');
    }
  }
  return blocks.join('\n');
}

/// Result of [checkImageMarkers]. All numbers are 1-based, as the user
/// sees them in `[imgN]`.
class MarkerCheck {
  const MarkerCheck({required this.unknownMarkers, required this.unusedImages});

  /// Marker numbers without a matching image, e.g. `[img9]` with 2 images.
  final List<int> unknownMarkers;

  /// Images that no marker refers to; they will be appended at the end.
  final List<int> unusedImages;

  bool get hasUnknownMarkers => unknownMarkers.isNotEmpty;
  bool get hasUnusedImages => unusedImages.isNotEmpty;
}

/// Checks [body] against the number of inline images before submitting.
/// Markers inside code are ignored, as in [buildArticleHtml].
MarkerCheck checkImageMarkers(String body, int imageCount) {
  final referenced = <int>{};
  void visit(md.Node node) {
    if (node is md.Text) {
      referenced.addAll(
        _marker.allMatches(node.text).map((m) => int.parse(m[1]!)),
      );
    } else if (node is md.Element && node.tag != 'code') {
      _mergeText(node.children).forEach(visit);
    }
  }

  _parse(body).forEach(visit);
  return MarkerCheck(
    unknownMarkers: [
      for (final n in referenced.toList()..sort())
        if (n < 1 || n > imageCount) n,
    ],
    unusedImages: [
      for (var n = 1; n <= imageCount; n++)
        if (!referenced.contains(n)) n,
    ],
  );
}

List<md.Node> _parse(String body) {
  final document = md.Document(
    // Keep text unescaped in the tree; the renderer escapes all of it.
    encodeHtml: false,
    // No inline HTML syntax.
    extensionSet: md.ExtensionSet.none,
    // Leaves out raw HTML blocks, indented code blocks (easy to trigger by
    // accident), "text + ---" headings (we want --- as Read more) and link
    // reference definitions.
    withDefaultBlockSyntaxes: false,
    blockSyntaxes: const [
      md.EmptyBlockSyntax(),
      md.HeaderSyntax(),
      md.FencedCodeBlockSyntax(),
      md.BlockquoteSyntax(),
      md.HorizontalRuleSyntax(),
      md.UnorderedListSyntax(),
      md.OrderedListSyntax(),
      md.ParagraphSyntax(),
    ],
  );
  return document.parse(body.replaceAll('\r\n', '\n'));
}

class _Renderer {
  _Renderer(this.images);

  final List<UploadedImage> images;
  final usedImages = <int>{};
  bool _readMoreDone = false;

  String renderBlock(md.Node node) {
    // Stray top-level text (should not happen) still ends up in a paragraph.
    if (node is! md.Element) return '<p>${render(node)}</p>';
    return render(node);
  }

  String render(md.Node node, {bool inCode = false}) {
    if (node is md.Text) return _text(node.text, inCode: inCode);
    if (node is! md.Element) return _escape.convert(node.textContent);

    final tag = node.tag;
    String children({bool code = false}) => [
      for (final child in _mergeText(node.children))
        render(child, inCode: inCode || code),
    ].join();

    switch (tag) {
      case 'hr':
        // Joomla supports one Read more separator; later ones are plain.
        if (_readMoreDone) return '<hr>';
        _readMoreDone = true;
        return readMoreTag;
      case 'a':
        final href = node.attributes['href'] ?? '';
        if (!_isSafeLink(href)) return children();
        return '<a href="${_escape.convert(href)}">${children()}</a>';
      case 'img':
        return _escape.convert(node.attributes['alt'] ?? '');
      case 'code' || 'pre':
        return '<$tag>${children(code: true)}</$tag>';
      case 'br':
        return '<br>';
      case _ when _allowedTags.contains(tag):
        return '<$tag>${children()}</$tag>';
      default:
        // Unknown element: keep its content, drop the tag.
        return children();
    }
  }

  /// Escapes text, turns single line breaks into `<br>` and replaces image
  /// markers. Code keeps its line breaks and markers.
  String _text(String text, {required bool inCode}) {
    if (inCode) return _escape.convert(text);
    final escaped = _escape.convert(text).replaceAll('\n', '<br>\n');
    return escaped.replaceAllMapped(_marker, (match) {
      final index = int.parse(match[1]!) - 1;
      if (index < 0 || index >= images.length) return match[0]!;
      usedImages.add(index);
      return _imgTag(images[index]);
    });
  }
}

/// The parser may split text into several adjacent [md.Text] nodes (e.g.
/// `[`, `img2`, `]` inside `**…**`). Join them so markers are found.
List<md.Node> _mergeText(List<md.Node>? nodes) {
  final merged = <md.Node>[];
  for (final node in nodes ?? const <md.Node>[]) {
    final last = merged.isEmpty ? null : merged.last;
    if (node is md.Text && last is md.Text) {
      merged.last = md.Text(last.text + node.text);
    } else {
      merged.add(node);
    }
  }
  return merged;
}

/// Allows http(s) and mailto links, plus relative links without a scheme.
/// Anything else (javascript:, data:, obfuscated schemes) is dropped.
bool _isSafeLink(String href) {
  if (href.isEmpty || href.contains(RegExp(r'[\x00-\x20\x7f]'))) return false;
  final lower = href.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('mailto:')) {
    return true;
  }
  return !href.contains(':');
}

String _imgTag(UploadedImage image) =>
    '<img src="${_escape.convert(image.path)}" '
    'alt="${_escape.convert(image.alt)}">';
