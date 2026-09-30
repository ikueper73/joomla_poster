import 'package:flutter_test/flutter_test.dart';
import 'package:joomla_poster/main.dart';

void main() {
  testWidgets('app starts', (tester) async {
    await tester.pumpWidget(const JoomlaPosterApp());
    expect(find.text('Joomla Poster'), findsOneWidget);
  });
}
