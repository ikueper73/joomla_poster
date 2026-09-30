import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:joomla_poster/services/image_service.dart';

img.Image solid(int width, int height, {int channels = 3}) {
  final image = img.Image(width: width, height: height, numChannels: channels);
  img.fill(image, color: img.ColorRgb8(200, 50, 50));
  return image;
}

img.Image decodeJpeg(Uint8List bytes) => img.decodeJpg(bytes)!;

bool containsExifMarker(Uint8List bytes) =>
    latin1.decode(bytes, allowInvalid: true).contains('Exif\u0000\u0000');

void main() {
  const service = ImageService();

  group('isSupported', () {
    test('accepts jpg, jpeg, png, webp in any case', () {
      for (final name in ['a.jpg', 'a.JPEG', 'b.png', 'c.WebP', 'x.y.jpg']) {
        expect(ImageService.isSupported(name), isTrue, reason: name);
      }
    });

    test('rejects other types', () {
      for (final name in ['a.gif', 'a.heic', 'a.svg', 'noext', 'jpg']) {
        expect(ImageService.isSupported(name), isFalse, reason: name);
      }
    });
  });

  group('processBytes', () {
    test('shrinks landscape images to 1920 px wide', () {
      final bytes = img.encodePng(solid(4000, 3000));
      final out = decodeJpeg(ImageService.processBytes(bytes)!);
      expect(out.width, 1920);
      expect(out.height, 1440);
    });

    test('shrinks portrait images to 1920 px high', () {
      final bytes = img.encodeJpg(solid(1000, 3000));
      final out = decodeJpeg(ImageService.processBytes(bytes)!);
      expect(out.width, 640);
      expect(out.height, 1920);
    });

    test('leaves small images at their size', () {
      final bytes = img.encodeJpg(solid(800, 600));
      final out = decodeJpeg(ImageService.processBytes(bytes)!);
      expect(out.width, 800);
      expect(out.height, 600);
    });

    test('strips EXIF data including GPS', () {
      final source = solid(300, 200);
      source.exif.imageIfd['Make'] = 'SpyCam';
      source.exif.gpsIfd['GPSLatitudeRef'] = 'N';
      final bytes = img.encodeJpg(source);
      expect(containsExifMarker(bytes), isTrue, reason: 'test setup');

      final out = ImageService.processBytes(bytes)!;

      expect(containsExifMarker(out), isFalse);
      expect(latin1.decode(out, allowInvalid: true), isNot(contains('SpyCam')));
      expect(decodeJpeg(out).exif.isEmpty, isTrue);
    });

    test('applies EXIF rotation before stripping it', () {
      final source = solid(200, 100);
      source.exif.imageIfd.orientation = 6; // rotate 90° clockwise
      final out = decodeJpeg(ImageService.processBytes(img.encodeJpg(source))!);
      expect(out.width, 100);
      expect(out.height, 200);
    });

    test('flattens transparent PNGs onto white', () {
      final source = img.Image(width: 10, height: 10, numChannels: 4);
      img.fill(source, color: img.ColorRgba8(0, 0, 0, 0));
      final out = decodeJpeg(ImageService.processBytes(img.encodePng(source))!);
      final pixel = out.getPixel(5, 5);
      expect(pixel.r, greaterThan(245));
      expect(pixel.g, greaterThan(245));
      expect(pixel.b, greaterThan(245));
    });

    test('returns null for data that is not an image', () {
      expect(
        ImageService.processBytes(Uint8List.fromList(utf8.encode('hello'))),
        isNull,
      );
    });
  });

  group('prepare', () {
    test('returns a JPEG pending image with path and alt', () async {
      final result = await service.prepare(
        fileName: 'photo.png',
        bytes: img.encodePng(solid(50, 40)),
        relativePath: 'articles/2026/x-1.jpg',
        alt: 'A photo',
      );
      expect(result.relativePath, 'articles/2026/x-1.jpg');
      expect(result.alt, 'A photo');
      expect(result.bytes.sublist(0, 2), [0xFF, 0xD8]); // JPEG header
    });

    test('rejects unsupported file types', () async {
      await expectLater(
        service.prepare(
          fileName: 'anim.gif',
          bytes: Uint8List(10),
          relativePath: 'x.jpg',
        ),
        throwsA(isA<ImageProcessingException>()),
      );
    });

    test('rejects broken files with a readable message', () async {
      await expectLater(
        service.prepare(
          fileName: 'broken.jpg',
          bytes: Uint8List.fromList([1, 2, 3]),
          relativePath: 'x.jpg',
        ),
        throwsA(
          isA<ImageProcessingException>().having(
            (e) => e.message,
            'message',
            contains('broken.jpg'),
          ),
        ),
      );
    });
  });

  group('slugify', () {
    test('lowercases and joins words with dashes', () {
      expect(ImageService.slugify('Hello World!'), 'hello-world');
    });

    test('transliterates umlauts and accents', () {
      expect(
        ImageService.slugify('Grüße aus Köln – Café'),
        'gruesse-aus-koeln-cafe',
      );
    });

    test('trims dashes and limits length', () {
      final slug = ImageService.slugify('  --${'word ' * 20}--  ');
      expect(slug.length, lessThanOrEqualTo(40));
      expect(slug, isNot(startsWith('-')));
      expect(slug, isNot(endsWith('-')));
    });

    test('falls back to "image"', () {
      expect(ImageService.slugify(''), 'image');
      expect(ImageService.slugify('!!!'), 'image');
    });
  });

  test('uploadPath uses year folder, slug, time stamp and number', () {
    expect(
      ImageService.uploadPath(
        title: 'Sommerfest 2026',
        number: 2,
        time: DateTime(2026, 9, 3, 7, 5),
      ),
      'articles/2026/sommerfest-2026-0903-0705-2.jpg',
    );
  });
}
