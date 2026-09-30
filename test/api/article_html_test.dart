import 'package:flutter_test/flutter_test.dart';
import 'package:joomla_poster/api/article_html.dart';
import 'package:joomla_poster/api/models.dart';

const cat = UploadedImage(path: 'images/articles/2026/cat.jpg', alt: 'Cat');
const dog = UploadedImage(path: 'images/articles/2026/dog.jpg', alt: 'Dog');

const catTag = '<img src="images/articles/2026/cat.jpg" alt="Cat">';
const dogTag = '<img src="images/articles/2026/dog.jpg" alt="Dog">';

void main() {
  group('buildArticleHtml', () {
    test('empty body without images gives empty HTML', () {
      expect(buildArticleHtml('', []), '');
      expect(buildArticleHtml('  \n\n  ', []), '');
    });

    test('splits paragraphs on blank lines', () {
      expect(
        buildArticleHtml('First.\n\nSecond.\n  \n\nThird.', []),
        '<p>First.</p>\n<p>Second.</p>\n<p>Third.</p>',
      );
    });

    test('single line breaks become <br>', () {
      expect(
        buildArticleHtml('Line 1\nLine 2', []),
        '<p>Line 1<br>\nLine 2</p>',
      );
    });

    test('handles Windows line endings', () {
      expect(buildArticleHtml('A\r\n\r\nB', []), '<p>A</p>\n<p>B</p>');
    });

    test('escapes HTML in user text', () {
      expect(
        buildArticleHtml('<script>alert("x")</script> & \'y\'', []),
        '<p>&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt; &amp; '
        '&#39;y&#39;</p>',
      );
    });

    test('keeps slashes readable', () {
      expect(buildArticleHtml('either/or', []), '<p>either/or</p>');
    });

    test('marker on its own paragraph becomes an image paragraph', () {
      expect(
        buildArticleHtml('Intro text.\n\n[img1]\n\nMore text.', [cat]),
        '<p>Intro text.</p>\n<p>$catTag</p>\n<p>More text.</p>',
      );
    });

    test('marker inside a sentence stays inline', () {
      expect(
        buildArticleHtml('Look [img1] here.', [cat]),
        '<p>Look $catTag here.</p>',
      );
    });

    test('markers map to images by position and can repeat', () {
      expect(
        buildArticleHtml('[img2] [img1] [img2]', [cat, dog]),
        '<p>$dogTag $catTag $dogTag</p>',
      );
    });

    test('unknown markers stay as literal text', () {
      expect(
        buildArticleHtml('[img1] [img9] [img0]', [cat]),
        '<p>$catTag [img9] [img0]</p>',
      );
    });

    test('unreferenced images are appended at the end', () {
      expect(
        buildArticleHtml('Text [img2]', [cat, dog]),
        '<p>Text $dogTag</p>\n<p>$catTag</p>',
      );
      expect(buildArticleHtml('', [cat]), '<p>$catTag</p>');
    });

    test('escapes alt text and path in the img tag', () {
      const tricky = UploadedImage(path: 'images/a"b.jpg', alt: 'Say "hi" <b>');
      expect(
        buildArticleHtml('[img1]', [tricky]),
        '<p><img src="images/a&quot;b.jpg" '
        'alt="Say &quot;hi&quot; &lt;b&gt;"></p>',
      );
    });

    test('marker text typed by the user cannot smuggle HTML', () {
      expect(
        buildArticleHtml('[img1]"><script>', [cat]),
        '<p>$catTag&quot;&gt;&lt;script&gt;</p>',
      );
    });
  });

  group('checkImageMarkers', () {
    test('all fine when every image is referenced once', () {
      final check = checkImageMarkers('[img1] and [img2]', 2);
      expect(check.hasUnknownMarkers, isFalse);
      expect(check.hasUnusedImages, isFalse);
    });

    test('reports unknown markers sorted and without duplicates', () {
      final check = checkImageMarkers('[img9] [img0] [img3] [img9]', 2);
      expect(check.unknownMarkers, [0, 3, 9]);
    });

    test('reports unused images', () {
      final check = checkImageMarkers('[img2]', 3);
      expect(check.unusedImages, [1, 3]);
    });

    test('no images and no markers is fine', () {
      final check = checkImageMarkers('Just text', 0);
      expect(check.unknownMarkers, isEmpty);
      expect(check.unusedImages, isEmpty);
    });
  });
}
