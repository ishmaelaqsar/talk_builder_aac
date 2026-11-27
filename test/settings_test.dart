import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_builder_aac/data/card_repository.dart';
import 'package:talk_builder_aac/models/board_settings.dart';
import 'package:talk_builder_aac/theme.dart';
import 'package:talk_builder_aac/widgets/talk_card_tile.dart';

import 'test_harness.dart';

/// A parent sets the voice, the speed, and the card size. Each change applies,
/// and is stored, at once.
void main() {
  List<Map<String, dynamic>> oneCard() => [storedCard(id: 't', label: 'Teddy')];

  /// The values that text-to-speech received for [method], in order.
  List<Object?> sent(String method) => ttsCalls
      .where((c) => c.method == method)
      .map((c) => c.arguments)
      .toList();

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings and backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  group('BoardSettings', () {
    test('a round trip keeps every setting', () {
      const BoardSettings settings = BoardSettings(
        voice: SpeechVoice.american,
        slow: true,
        cardSize: CardSize.large,
      );

      final BoardSettings restored = BoardSettings.fromJson(settings.toJson());

      expect(restored.voice, SpeechVoice.american);
      expect(restored.slow, isTrue);
      expect(restored.cardSize, CardSize.large);
    });

    test('a missing field takes its default', () {
      final BoardSettings settings = BoardSettings.fromJson({});

      expect(settings.voice, SpeechVoice.british);
      expect(settings.slow, isFalse);
      expect(settings.cardSize, CardSize.medium);
    });

    test('an unknown value takes its default', () {
      final BoardSettings settings = BoardSettings.fromJson({
        'voice': 'fr-FR',
        'slow': 'yes',
        'cardSize': 'huge',
      });

      expect(settings.voice, SpeechVoice.british);
      expect(settings.slow, isFalse);
      expect(settings.cardSize, CardSize.medium);
    });

    test('stored settings that cannot be read load as the defaults', () async {
      SharedPreferences.setMockInitialValues({
        CardRepository.settingsKey: 'not json',
      });

      final BoardSettings settings = await CardRepository().loadSettings();

      expect(settings.voice, SpeechVoice.british);
      expect(settings.slow, isFalse);
      expect(settings.cardSize, CardSize.medium);
    });
  });

  testWidgets('Unreadable settings give the defaults, and the cards load', (
    tester,
  ) async {
    installMocks(storedCards: oneCard(), storedSettings: 'not json');
    await pumpApp(tester);

    expect(find.text('Teddy'), findsOneWidget);
    expect(sent('setLanguage').first, 'en-GB');
    expect(sent('setSpeechRate').first, 0.45);
  });

  testWidgets('The stored voice is the first one that the engine gets', (
    tester,
  ) async {
    installMocks(
      storedCards: oneCard(),
      storedSettings: json.encode({'voice': 'en-US'}),
    );
    await pumpApp(tester);

    expect(sent('setLanguage').first, 'en-US');
  });

  testWidgets('Slow and Normal send their rates at once', (tester) async {
    installMocks(storedCards: oneCard());
    await pumpApp(tester);
    await enterAdminMode(tester);
    await openSettings(tester);

    await choose(tester, 'Slow');
    expect(sent('setSpeechRate').last, 0.35);

    await choose(tester, 'Normal');
    expect(sent('setSpeechRate').last, 0.45);
  });

  testWidgets('A change is stored at once, and holds after a restart', (
    tester,
  ) async {
    installMocks(storedCards: oneCard());
    await pumpApp(tester);
    await enterAdminMode(tester);
    await openSettings(tester);

    await choose(tester, 'American');
    await choose(tester, 'Slow');

    final String? stored = (await SharedPreferences.getInstance()).getString(
      'talk_builder_settings_v1',
    );
    expect(json.decode(stored!), containsPair('voice', 'en-US'));
    expect(json.decode(stored), containsPair('slow', true));

    // A fresh app on the same storage.
    await tester.pumpWidget(const SizedBox.shrink());
    ttsCalls.clear();
    await pumpApp(tester);

    expect(sent('setLanguage'), ['en-US']);
    expect(sent('setSpeechRate'), [0.35]);
  });

  testWidgets('Hear it speaks the sample', (tester) async {
    installMocks(storedCards: oneCard());
    await pumpApp(tester);
    await enterAdminMode(tester);
    await openSettings(tester);
    ttsCalls.clear();

    await choose(tester, 'Hear it');

    expect(sent('speak'), ['I want more.']);
  });

  testWidgets('Large makes a card wider, and Small makes it narrower', (
    tester,
  ) async {
    installMocks(storedCards: oneCard());
    await pumpApp(tester);
    await enterAdminMode(tester);
    double width() =>
        tester.getSize(find.widgetWithText(TalkCardTile, 'Teddy')).width;
    final double medium = width();
    await openSettings(tester);

    await choose(tester, 'Large');
    expect(width(), greaterThan(medium));

    await choose(tester, 'Small');
    expect(width(), lessThan(medium));
  });

  testWidgets('A child sees no Settings entry', (tester) async {
    installMocks(storedCards: oneCard());
    await pumpApp(tester);

    expect(find.byTooltip('Settings and backup'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  for (final Size size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('The sheet opens with no overflow at $size and text scale 2', (
      tester,
    ) async {
      installMocks(storedCards: oneCard());
      await pumpApp(tester, size: size, textScale: 2.0);
      await enterAdminMode(tester);

      await openSettings(tester);

      expect(find.text('Hear it'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
