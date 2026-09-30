import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:joomla_poster/api/joomla_client.dart';
import 'package:joomla_poster/api/models.dart';
import 'package:joomla_poster/services/image_service.dart';
import 'package:joomla_poster/services/settings_store.dart';
import 'package:joomla_poster/ui/compose_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTokenStore implements TokenStore {
  String? token = 'abc';

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}

/// Skips real image processing, which would need a real isolate.
class FakeImageService extends ImageService {
  const FakeImageService();

  @override
  Future<PendingImage> prepare({
    required String fileName,
    required Uint8List bytes,
    required String relativePath,
    String alt = '',
  }) async {
    if (!ImageService.isSupported(fileName)) {
      throw ImageProcessingException('"$fileName" is not supported.');
    }
    return PendingImage(relativePath: relativePath, bytes: bytes, alt: alt);
  }
}

// A 1x1 transparent PNG, so Image.memory can render thumbnails.
final pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

PickedFile picked(String name) => PickedFile(name: name, bytes: pngBytes);

void main() {
  late SettingsStore store;
  late List<http.Request> requests;
  late List<List<PickedFile>> pickerResults;
  int? failUploadNumber;

  JoomlaClient fakeClient(String apiBaseUrl, String token) => JoomlaClient(
    apiBaseUrl: apiBaseUrl,
    token: token,
    httpClient: MockClient((request) async {
      requests.add(request);
      final isUpload = request.url.path.endsWith('/media/files');
      final uploads = requests
          .where((r) => r.url.path.endsWith('/media/files'))
          .length;
      if (isUpload && uploads == failUploadNumber) {
        return http.Response(
          jsonEncode({
            'errors': [
              {'title': 'File too big'},
            ],
          }),
          400,
        );
      }
      return http.Response(
        jsonEncode({
          'data': {'id': isUpload ? null : '42'},
        }),
        200,
      );
    }),
  );

  Future<List<PickedFile>> fakePicker({required bool multiple}) async =>
      pickerResults.isEmpty ? [] : pickerResults.removeAt(0);

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ComposeScreen(
          store: store,
          clientFactory: fakeClient,
          imageService: const FakeImageService(),
          pickImages: fakePicker,
        ),
      ),
    );
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  String bodyText(WidgetTester tester) =>
      tester.widget<TextFormField>(field('Text')).controller!.text;

  Future<void> tapPost(WidgetTester tester) async {
    await tester.tap(find.text('Post article'));
    await tester.pumpAndSettle();
  }

  List<String> requestPaths() =>
      requests.map((r) => r.url.path.split('/v1').last).toList();

  setUp(() async {
    requests = [];
    pickerResults = [];
    failUploadNumber = null;
    SharedPreferences.setMockInitialValues({
      'site_url': 'https://example.org',
      'category_id': 12,
      'media_adapter': 'local-images',
    });
    store = SettingsStore(
      prefs: await SharedPreferences.getInstance(),
      tokens: FakeTokenStore(),
    );
    await store.load();
  });

  testWidgets('shows setup prompt when settings are incomplete', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(
      prefs: await SharedPreferences.getInstance(),
      tokens: FakeTokenStore(),
    );
    await store.load();
    await pumpScreen(tester);

    expect(find.text('Open settings'), findsOneWidget);
    expect(field('Title'), findsNothing);
  });

  testWidgets('requires a title', (tester) async {
    await pumpScreen(tester);
    await tapPost(tester);

    expect(find.text('Please enter a title.'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('posts text-only article and clears the form', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(field('Title'), 'Hello');
    await tester.enterText(field('Text'), 'First <b>\n\nSecond');
    await tapPost(tester);

    expect(requestPaths(), ['/content/articles']);
    final article = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(article['title'], 'Hello');
    expect(article['catid'], 12);
    expect(article['state'], 0);
    expect(article['articletext'], '<p>First &lt;b&gt;</p>\n<p>Second</p>');
    expect(requests.single.headers['X-Joomla-Token'], 'abc');
    expect(find.textContaining('(ID 42) was created unpublished'), findsOne);
    expect(bodyText(tester), isEmpty);
  });

  testWidgets('uploads intro and inline images, then posts', (tester) async {
    pickerResults = [
      [picked('intro.jpg')],
      [picked('a.png'), picked('b.webp')],
    ];
    await pumpScreen(tester);
    await tester.enterText(field('Title'), 'Sommerfest');
    await tester.tap(find.text('Choose intro image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add inline images'));
    await tester.pumpAndSettle();

    expect(find.textContaining('[img1]  ·  a.png'), findsOneWidget);
    expect(find.textContaining('[img2]  ·  b.webp'), findsOneWidget);

    // Body: "Look " then insert [img2] at the end via the button.
    await tester.enterText(field('Text'), 'Look ');
    await tester.tap(find.byTooltip('Insert [img2] into text'));
    await tester.pump();
    expect(bodyText(tester), 'Look [img2]');
    await tester.enterText(
      find.widgetWithText(TextField, 'Alt text (describes the image)').at(2),
      'Beach',
    );

    await tester.tap(find.text('Post article'));
    await tester.pumpAndSettle();
    // [img1] is unused, so a confirmation appears first.
    expect(find.text('Images without marker'), findsOneWidget);
    await tester.tap(find.text('Post anyway'));
    await tester.pumpAndSettle();

    expect(requestPaths(), [
      '/media/files',
      '/media/files',
      '/media/files',
      '/content/articles',
    ]);
    final uploadPaths = requests
        .take(3)
        .map((r) => (jsonDecode(r.body) as Map<String, dynamic>)['path'])
        .toList();
    for (final (i, path) in uploadPaths.indexed) {
      expect(
        path,
        matches(
          RegExp(
            '^local-images:/articles/\\d{4}/sommerfest-'
            '\\d{4}-\\d{4}-${i + 1}\\.jpg\$',
          ),
        ),
      );
    }
    final article = jsonDecode(requests.last.body) as Map<String, dynamic>;
    final html = article['articletext'] as String;
    final image3 = (uploadPaths[2] as String).replaceFirst(
      'local-images:/',
      'images/',
    );
    final image2 = (uploadPaths[1] as String).replaceFirst(
      'local-images:/',
      'images/',
    );
    expect(
      html,
      '<p>Look <img src="$image3" alt="Beach"></p>\n'
      '<p><img src="$image2" alt=""></p>',
    );
    expect(
      (article['images'] as Map)['image_intro'],
      (uploadPaths[0] as String).replaceFirst('local-images:/', 'images/'),
    );
    expect(find.textContaining('was created unpublished'), findsOne);
    expect(find.textContaining('a.png'), findsNothing);
  });

  testWidgets('unknown marker blocks posting', (tester) async {
    pickerResults = [
      [picked('a.jpg')],
    ];
    await pumpScreen(tester);
    await tester.enterText(field('Title'), 'T');
    await tester.tap(find.text('Add inline images'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Text'), '[img1] and [img3]');
    await tapPost(tester);

    expect(find.textContaining('without a matching image: [img3]'), findsOne);
    expect(requests, isEmpty);
  });

  testWidgets('cancelling the unused-image dialog posts nothing', (
    tester,
  ) async {
    pickerResults = [
      [picked('a.jpg')],
    ];
    await pumpScreen(tester);
    await tester.enterText(field('Title'), 'T');
    await tester.tap(find.text('Add inline images'));
    await tester.pumpAndSettle();
    await tapPost(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(requests, isEmpty);
    expect(find.textContaining('a.jpg'), findsOneWidget);
  });

  testWidgets('failed upload shows error, keeps the form, no article', (
    tester,
  ) async {
    failUploadNumber = 2;
    pickerResults = [
      [picked('a.jpg'), picked('b.jpg')],
    ];
    await pumpScreen(tester);
    await tester.enterText(field('Title'), 'T');
    await tester.tap(find.text('Add inline images'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Text'), '[img1] [img2]');
    await tapPost(tester);

    expect(requestPaths(), ['/media/files', '/media/files']);
    expect(find.textContaining('Image 2 of 2 could not be uploaded'), findsOne);
    expect(find.textContaining('File too big'), findsOne);
    expect(bodyText(tester), '[img1] [img2]');
    expect(find.textContaining('b.jpg'), findsOneWidget);
  });

  testWidgets('removing an image referenced by later markers asks first', (
    tester,
  ) async {
    pickerResults = [
      [picked('a.jpg'), picked('b.jpg')],
    ];
    await pumpScreen(tester);
    await tester.tap(find.text('Add inline images'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Text'), 'See [img2]');

    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('Remove image 1?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('a.jpg'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.textContaining('a.jpg'), findsNothing);
    expect(find.textContaining('[img1]  ·  b.jpg'), findsOneWidget);
  });

  testWidgets('removing an image without affected markers needs no dialog', (
    tester,
  ) async {
    pickerResults = [
      [picked('a.jpg'), picked('b.jpg')],
    ];
    await pumpScreen(tester);
    await tester.tap(find.text('Add inline images'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Text'), 'See [img1]');

    await tester.tap(find.byTooltip('Remove').last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('b.jpg'), findsNothing);
  });

  testWidgets('published setting is reflected in the success message', (
    tester,
  ) async {
    await store.save(
      store.settings!.copyWith(articleState: ArticleState.published),
    );
    await pumpScreen(tester);
    await tester.enterText(field('Title'), 'Hello');
    await tapPost(tester);

    final article = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(article['state'], 1);
    expect(find.textContaining('was published'), findsOne);
  });
}
