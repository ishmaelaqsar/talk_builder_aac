import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_builder_aac/widgets/mini_card.dart';
import 'package:talk_builder_aac/widgets/sentence_strip.dart';
import 'package:talk_builder_aac/widgets/talk_card_tile.dart';
import 'package:talk_builder_aac/widgets/vocab_grid.dart';

import 'test_harness.dart';

void main() {
  setUp(() => installMocks());

  Future<void> tapCard(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(TalkCardTile, label));
    await tester.pumpAndSettle();
  }

  Future<void> speakSentence(WidgetTester tester, List<String> labels) async {
    for (final String label in labels) {
      await tapCard(tester, label);
    }
    await tester.tap(find.text('SPEAK'));
    await tester.pumpAndSettle();
  }

  List<String> stripWords(WidgetTester tester) => tester
      .widgetList<MiniCard>(find.byType(MiniCard))
      .map((m) => m.card.label)
      .toList();

  bool isSpeaking(WidgetTester tester, String label) =>
      tester.widget<MiniCard>(find.widgetWithText(MiniCard, label)).isSpeaking;

  /// Whether the strip shows all of the word [label].
  bool inView(WidgetTester tester, String label) {
    final Finder card = find.widgetWithText(MiniCard, label);
    if (card.evaluate().isEmpty) return false;
    final Rect strip = tester.getRect(
      find.descendant(
        of: find.byType(SentenceStrip),
        matching: find.byType(ListView),
      ),
    );
    return strip.expandToInclude(tester.getRect(card)) == strip;
  }

  testWidgets('The voice is British English', (tester) async {
    await pumpApp(tester);

    expect(
      ttsCalls.firstWhere((c) => c.method == 'setLanguage').arguments,
      'en-GB',
    );
  });

  testWidgets('A late cancel of the cut word keeps STOP on screen', (
    tester,
  ) async {
    await pumpApp(tester);
    await speakSentence(tester, ['I', 'Want']);
    expect(find.text('STOP'), findsOneWidget);

    // The Android plugin answers stop at once, and sends the cancel of the
    // word that it cut after that.
    await deliverTts(tester, 'speak.onCancel');

    expect(find.text('STOP'), findsOneWidget);
    expect(isSpeaking(tester, 'I'), isTrue);
  });

  testWidgets('A sentence that plays to the end brings SPEAK back', (
    tester,
  ) async {
    await pumpApp(tester);
    await speakSentence(tester, ['I', 'Want']);

    await deliverTts(tester, 'speak.onComplete');

    expect(find.text('SPEAK'), findsOneWidget);
    expect(find.text('STOP'), findsNothing);
  });

  testWidgets('The highlight follows the word that the engine reports', (
    tester,
  ) async {
    await pumpApp(tester);
    await speakSentence(tester, ['I', 'Want']);
    expect(isSpeaking(tester, 'I'), isTrue);

    await deliverTts(tester, 'speak.onProgress', {
      'text': 'I Want',
      'start': '2',
      'end': '6',
      'word': 'Want',
    });

    expect(isSpeaking(tester, 'I'), isFalse);
    expect(isSpeaking(tester, 'Want'), isTrue);
  });

  testWidgets('After a sentence plays to the end, a card starts a new one', (
    tester,
  ) async {
    await pumpApp(tester);
    await speakSentence(tester, ['I', 'Want']);
    await deliverTts(tester, 'speak.onComplete');

    await tapCard(tester, 'See');

    expect(stripWords(tester), ['See']);
  });

  testWidgets('A backspace after the sentence ends keeps the sentence', (
    tester,
  ) async {
    await pumpApp(tester);
    await speakSentence(tester, ['I', 'Want']);
    await deliverTts(tester, 'speak.onComplete');

    await tester.tap(find.byTooltip('Remove the last word'));
    await tester.pumpAndSettle();
    await tapCard(tester, 'See');

    expect(stripWords(tester), ['I', 'See']);
  });

  testWidgets('A stopped sentence keeps the sentence', (tester) async {
    await pumpApp(tester);
    await speakSentence(tester, ['I', 'Want']);

    await tester.tap(find.text('STOP'));
    await tester.pumpAndSettle();
    await deliverTts(tester, 'speak.onCancel');
    await tapCard(tester, 'See');

    expect(stripWords(tester), ['I', 'Want', 'See']);
  });

  testWidgets('Card taps do not rebuild the grid', (tester) async {
    await pumpApp(tester);
    final Widget grid = tester.widget(find.byType(VocabGrid));

    for (final String label in ['I', 'Want', 'See']) {
      await tapCard(tester, label);
    }

    expect(identical(tester.widget(find.byType(VocabGrid)), grid), isTrue);
  });

  testWidgets('Clear stops a sentence that plays', (tester) async {
    await pumpApp(tester);
    await speakSentence(tester, ['I', 'Want']);
    ttsCalls.clear();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(ttsCalls.map((c) => c.method), contains('stop'));
  });

  testWidgets('The strip follows the spoken word', (tester) async {
    const List<String> words = [
      'I',
      'Want',
      'See',
      'Go',
      'Like',
      'More',
      'No',
      'Yes',
    ];
    await pumpApp(tester, size: const Size(320, 568));
    await speakSentence(tester, words);

    expect(
      inView(tester, 'I'),
      isTrue,
      reason: 'SPEAK starts at the first word',
    );

    final String text = words.join(' ');
    await deliverTts(tester, 'speak.onProgress', {
      'text': text,
      'start': '${text.lastIndexOf('Yes')}',
      'end': '${text.length}',
      'word': 'Yes',
    });

    expect(inView(tester, 'Yes'), isTrue);
  });

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
