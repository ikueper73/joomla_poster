import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../api/models.dart';

/// Thrown when an image cannot be used. [message] is safe to show.
class ImageProcessingException implements Exception {
  const ImageProcessingException(this.message);

  final String message;

  @override
  String toString() => 'ImageProcessingException: $message';
}

/// Prepares picked images for upload: resize, re-encode as JPEG, strip
/// EXIF (GPS data!) and choose a file name.
class ImageService {
  const ImageService();

  static const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const maxEdge = 1920;
  static const jpegQuality = 85;

  /// Refuse huge inputs before decoding to keep memory use sane.
  static const maxInputBytes = 40 * 1024 * 1024;

  static bool isSupported(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return false;
    return allowedExtensions.contains(
      fileName.substring(dot + 1).toLowerCase(),
    );
  }

  /// Processes [bytes] off the UI thread and returns a [PendingImage] that
  /// will be uploaded to [relativePath] (see [uploadPath]).
  Future<PendingImage> prepare({
    required String fileName,
    required Uint8List bytes,
    required String relativePath,
    String alt = '',
  }) async {
    if (!isSupported(fileName)) {
      throw ImageProcessingException(
        '"$fileName" is not supported. '
        'Please use JPG, PNG or WebP images.',
      );
    }
    if (bytes.length > maxInputBytes) {
      throw ImageProcessingException('"$fileName" is too large (over 40 MB).');
    }
    final jpeg = await Isolate.run(() => processBytes(bytes));
    if (jpeg == null) {
      throw ImageProcessingException(
        '"$fileName" could not be read. Is it a valid image?',
      );
    }
    return PendingImage(relativePath: relativePath, bytes: jpeg, alt: alt);
  }

  /// Decodes, applies EXIF rotation, flattens transparency onto white,
  /// shrinks to [maxEdge] and encodes as JPEG without EXIF.
  /// Returns null if [bytes] is not a decodable image.
  static Uint8List? processBytes(Uint8List bytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      // Decoders throw various errors (e.g. RangeError) on corrupt input.
      return null;
    }
    if (decoded == null) return null;

    var image = img.bakeOrientation(decoded);

    final longEdge = image.width >= image.height ? image.width : image.height;
    if (longEdge > maxEdge) {
      image = image.width >= image.height
          ? img.copyResize(
              image,
              width: maxEdge,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              image,
              height: maxEdge,
              interpolation: img.Interpolation.average,
            );
    }

    if (image.hasAlpha) {
      final background = img.Image(width: image.width, height: image.height);
      img.fill(background, color: img.ColorRgb8(255, 255, 255));
      image = img.compositeImage(background, image);
    }

    // The JPEG encoder writes whatever EXIF the image carries, so clear it.
    image.exif = img.ExifData();
    return img.encodeJpg(image, quality: jpegQuality);
  }

  /// Path inside the images folder, e.g.
  /// `articles/2026/my-title-0930-2135-1.jpg`. The month/day/time part
  /// avoids clashes with earlier articles of the same title.
  static String uploadPath({
    required String title,
    required int number,
    required DateTime time,
  }) {
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${two(time.month)}${two(time.day)}-${two(time.hour)}${two(time.minute)}';
    return 'articles/${time.year}/${slugify(title)}-$stamp-$number.jpg';
  }

  static const _transliterations = {
    'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss', //
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u',
    'ç': 'c', 'ñ': 'n',
  };

  /// ASCII file-name slug of [title], at most 40 characters.
  /// Falls back to `image` when nothing usable is left.
  static String slugify(String title) {
    final lower = title.toLowerCase();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(_transliterations[char] ?? char);
    }
    var slug = buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.length > 40) {
      slug = slug.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
    }
    return slug.isEmpty ? 'image' : slug;
  }
}
