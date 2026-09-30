import 'dart:convert';

import 'models.dart';

/// Matches image markers like `[img1]`; group 1 is the 1-based number.
final _marker = RegExp(r'\[img(\d+)\]');

/// Escapes `& < > " '` but, unlike the default [HtmlEscape], not `/`,
/// so ordinary text and paths stay readable. Safe in text and attributes.
const _escape = HtmlEscape(
  HtmlEscapeMode(escapeLtGt: true, escapeQuot: true, escapeApos: true),
);

/// Turns the user's plain text into article HTML.
///
/// - Paragraphs are separated by blank lines and wrapped in `<p>`;
///   single line breaks become `<br>`.
/// - All user text is HTML-escaped before markers are replaced, so the
///   text can never inject HTML.
/// - `[imgN]` is replaced with the N-th of [inlineImages]. Unknown
///   markers stay as literal text (see [checkImageMarkers]).
/// - Images that are never referenced are appended at the end.
String buildArticleHtml(String body, List<UploadedImage> inlineImages) {
  final used = <int>{};
  final paragraphs = _paragraphs(body).map((paragraph) {
    final escaped = _escape.convert(paragraph).replaceAll('\n', '<br>\n');
    final html = escaped.replaceAllMapped(_marker, (match) {
      final index = int.parse(match[1]!) - 1;
      if (index < 0 || index >= inlineImages.length) return match[0]!;
      used.add(index);
      return _imgTag(inlineImages[index]);
    });
    return '<p>$html</p>';
  }).toList();

  for (var i = 0; i < inlineImages.length; i++) {
    if (!used.contains(i)) paragraphs.add('<p>${_imgTag(inlineImages[i])}</p>');
  }
  return paragraphs.join('\n');
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
MarkerCheck checkImageMarkers(String body, int imageCount) {
  final referenced = _marker
      .allMatches(body)
      .map((match) => int.parse(match[1]!))
      .toSet();
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

Iterable<String> _paragraphs(String body) => body
    .replaceAll('\r\n', '\n')
    .split(RegExp(r'\n\s*\n'))
    .map((paragraph) => paragraph.trim())
    .where((paragraph) => paragraph.isNotEmpty);

String _imgTag(UploadedImage image) =>
    '<img src="${_escape.convert(image.path)}" '
    'alt="${_escape.convert(image.alt)}">';
