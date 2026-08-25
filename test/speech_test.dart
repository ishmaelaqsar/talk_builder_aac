import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  setUp(() => installMocks());

  testWidgets('The engine is configured before the first word is spoken', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('I'));
    await tester.pumpAndSettle();

    final List<String> methods = ttsCalls.map((c) => c.method).toList();
    expect(methods, contains('setLanguage'));
    expect(methods, contains('setSpeechRate'));
    expect(
      methods.indexOf('setSpeechRate'),
      lessThan(methods.indexOf('speak')),
      reason: 'A fast first tap must not speak at the default rate',
    );
  });

  testWidgets('A fast second tap stops the first word first', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('I'));
    await tester.pump();
    await tester.tap(find.text('Want').first);
    await tester.pumpAndSettle();

    final List<String> methods = ttsCalls.map((c) => c.method).toList();
    final int firstSpeak = methods.indexOf('speak');
    final int lastSpeak = methods.lastIndexOf('speak');

    expect(lastSpeak, greaterThan(firstSpeak), reason: 'both words spoke');
    expect(
      methods.sublist(firstSpeak, lastSpeak),
      contains('stop'),
      reason: 'the second tap must cancel the first, or the two garble',
    );
  });

  testWidgets('SPEAK reads the whole sentence, joined by spaces', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Want').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SPEAK'));
    await tester.pumpAndSettle();

    expect(ttsCalls.last.method, 'speak');
    expect(ttsCalls.last.arguments, 'I Want');
  });

  testWidgets('SPEAK is disabled while the sentence is empty', (tester) async {
    await pumpApp(tester);

    final ElevatedButton button = tester.widget(
      find.widgetWithText(ElevatedButton, 'SPEAK'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Tapping a word in the sentence speaks that word again', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('I'));
    await tester.pumpAndSettle();
    ttsCalls.clear();

    await tester.tap(inStrip('I'));
    await tester.pumpAndSettle();

    expect(ttsCalls.map((c) => c.method), contains('speak'));
  });

  testWidgets('Long-pressing a word in the sentence removes it', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('I'));
    await tester.pumpAndSettle();
    expect(find.text('I'), findsNWidgets(2));

    await tester.longPress(inStrip('I'));
    await tester.pumpAndSettle();

    expect(find.text('I'), findsOneWidget);
  });
}
