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

  group('buildArticleHtml Markdown', () {
    test('### makes an h3 lead, like a Joomla intro heading', () {
      expect(
        buildArticleHtml('### The lead\n\nBody text.', []),
        '<h3>The lead</h3>\n<p>Body text.</p>',
      );
    });

    test('all heading levels are available', () {
      expect(buildArticleHtml('# A\n\n## B', []), '<h1>A</h1>\n<h2>B</h2>');
    });

    test('bold, italic and inline code', () {
      expect(
        buildArticleHtml('**bold** *it* _it_ `a<b`', []),
        '<p><strong>bold</strong> <em>it</em> <em>it</em> '
        '<code>a&lt;b</code></p>',
      );
    });

    test('lists and quotes', () {
      expect(
        buildArticleHtml('- a\n- b\n\n1. one\n\n> quoted', []),
        '<ul><li>a</li><li>b</li></ul>\n<ol><li>one</li></ol>\n'
        '<blockquote><p>quoted</p></blockquote>',
      );
    });

    test('fenced code keeps line breaks and escapes', () {
      expect(
        buildArticleHtml('```\n<a>\nline 2\n```', []),
        '<pre><code>&lt;a&gt;\nline 2\n</code></pre>',
      );
    });

    test('indented lines are not turned into code blocks', () {
      final html = buildArticleHtml('    indented', []);
      expect(html, startsWith('<p>'));
      expect(html, isNot(contains('<pre>')));
    });

    group('Read more', () {
      test('--- becomes the Joomla read-more separator', () {
        expect(
          buildArticleHtml('### Lead\n\nIntro.\n\n---\n\nFull text.', []),
          '<h3>Lead</h3>\n<p>Intro.</p>\n$readMoreTag\n<p>Full text.</p>',
        );
      });

      test('only the first separator is read more', () {
        expect(
          buildArticleHtml('a\n\n---\n\nb\n\n***\n\nc', []),
          '<p>a</p>\n$readMoreTag\n<p>b</p>\n<hr>\n<p>c</p>',
        );
      });

      test('--- directly under text is still a separator, not a heading', () {
        expect(
          buildArticleHtml('text\n---\nmore', []),
          '<p>text</p>\n$readMoreTag\n<p>more</p>',
        );
      });
    });

    group('links', () {
      test('http, https, mailto and relative links are kept', () {
        expect(
          buildArticleHtml(
            '[a](https://x.org/?a=1&b=2) [b](http://x.org) '
            '[c](mailto:me@x.org) [d](index.php?id=3) <https://auto.org>',
            [],
          ),
          '<p><a href="https://x.org/?a=1&amp;b=2">a</a> '
          '<a href="http://x.org">b</a> '
          '<a href="mailto:me@x.org">c</a> '
          '<a href="index.php?id=3">d</a> '
          '<a href="https://auto.org">https://auto.org</a></p>',
        );
      });

      test('dangerous schemes are reduced to their text', () {
        for (final href in [
          'javascript:alert(1)',
          'JaVaScRiPt:alert(1)',
          'data:text/html,<b>x</b>',
          'vbscript:x',
        ]) {
          expect(
            buildArticleHtml('[click]($href)', []),
            '<p>click</p>',
            reason: href,
          );
        }
      });

      test('link titles are dropped', () {
        expect(
          buildArticleHtml('[a](https://x.org "title")', []),
          '<p><a href="https://x.org">a</a></p>',
        );
      });
    });

    group('raw HTML is never passed through', () {
      test('HTML blocks are shown as text', () {
        expect(
          buildArticleHtml('<script>alert(1)</script>\n\ntext', []),
          '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>\n<p>text</p>',
        );
      });

      test('inline HTML is shown as text', () {
        expect(
          buildArticleHtml('a <img src=x onerror=alert(1)> b', []),
          '<p>a &lt;img src=x onerror=alert(1)&gt; b</p>',
        );
      });

      test('Markdown images are reduced to their alt text', () {
        expect(
          buildArticleHtml('![A "cat"](https://evil.example/x.png)', []),
          '<p>A &quot;cat&quot;</p>',
        );
      });
    });

    group('image markers with Markdown', () {
      test('markers work in headings, lists and links', () {
        expect(
          buildArticleHtml('### [img1]\n\n- [img2]', [cat, dog]),
          '<h3>$catTag</h3>\n<ul><li>$dogTag</li></ul>',
        );
      });

      test('markers inside code stay literal and count as unused', () {
        expect(
          buildArticleHtml('Write `[img1]` to place it.', [cat]),
          '<p>Write <code>[img1]</code> to place it.</p>\n<p>$catTag</p>',
        );
      });

      test('markers inside bold are found', () {
        expect(
          buildArticleHtml('**[img1]** and *see [img1]*', [cat]),
          '<p><strong>$catTag</strong> and <em>see $catTag</em></p>',
        );
      });

      test('marker next to formatting', () {
        expect(
          buildArticleHtml('**Look:** [img1]', [cat]),
          '<p><strong>Look:</strong> $catTag</p>',
        );
      });
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

    test('ignores markers inside code', () {
      final check = checkImageMarkers('See `[img1]`\n\n```\n[img3]\n```', 1);
      expect(check.unknownMarkers, isEmpty);
      expect(check.unusedImages, [1]);
    });

    test('finds markers inside formatting', () {
      final check = checkImageMarkers('### [img1]\n\n**[img2]**', 2);
      expect(check.unusedImages, isEmpty);
    });

    test('no images and no markers is fine', () {
      final check = checkImageMarkers('Just text', 0);
      expect(check.unknownMarkers, isEmpty);
      expect(check.unusedImages, isEmpty);
    });
  });
}
