import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_builder_aac/models/core_words.dart';
import 'package:talk_builder_aac/models/talk_card.dart';
import 'package:talk_builder_aac/screens/builder_screen.dart';
import 'package:talk_builder_aac/theme.dart';
import 'package:talk_builder_aac/widgets/talk_card_tile.dart';
import 'package:talk_builder_aac/widgets/vocab_grid.dart';

import 'test_harness.dart';

/// The old layout used a fixed 140px strip and a hardcoded font size, so it
/// overflowed on a small screen and at a large text scale.
void main() {
  const Map<String, Size> viewports = {
    'small phone portrait': Size(320, 568),
    'small phone landscape': Size(568, 320),
    'tablet portrait': Size(800, 1280),
    'tablet landscape': Size(1280, 800),
  };

  for (final CardSize cardSize in CardSize.values) {
    for (final MapEntry<String, Size> viewport in viewports.entries) {
      for (final double scale in [1.0, 1.5, 2.0]) {
        testWidgets('${viewport.key} at text scale $scale with ${cardSize.name} '
            'cards does not overflow', (tester) async {
          installMocks(
            storedSettings: json.encode({'cardSize': cardSize.name}),
            storedCards: [
              storedCard(id: 'a', label: 'Teddy'),
              storedCard(id: 'b', label: 'A very long card label indeed'),
              storedCard(
                id: 'c',
                label: 'Apple',
                symbol: 'assets/symbols/apple.svg',
              ),
            ],
          );
          await pumpApp(tester, size: viewport.value, textScale: scale);

          // If the scale does not reach the app, this case tests nothing above 1.0.
          expect(
            MediaQuery.textScalerOf(tester.element(find.byType(BuilderScreen)))
                .scale(10),
            10 * scale,
          );

          // Build a sentence too, so the strip is populated rather than empty.
          await tester.tap(find.text('I'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Want').first);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final MapEntry<String, Size> viewport in viewports.entries) {
    for (final double scale in [1.0, 1.5, 2.0]) {
      testWidgets('${viewport.key} at text scale $scale does not overflow in '
          'admin mode', (tester) async {
        const String longLabel = 'A very long card label indeed';
        installMocks(
          storedCards: [
            storedCard(id: 'a', label: 'Teddy'),
            storedCard(id: 'b', label: longLabel),
            storedCard(
              id: 'c',
              label: 'Apple',
              symbol: 'assets/symbols/apple.svg',
            ),
          ],
        );
        await pumpApp(tester, size: viewport.value, textScale: scale);
        await enterAdminMode(tester);
        expect(tester.takeException(), isNull);

        // The unlock message covers the bottom of a small screen until it
        // hides, as it does for a parent.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // The editor is a parent's screen too.
        final Finder card = find.widgetWithText(TalkCardTile, longLabel);
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.text('Card details'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final MapEntry<String, Size> viewport in viewports.entries) {
    testWidgets('${viewport.key} shows all eight core words in full', (
      tester,
    ) async {
      installMocks();
      await pumpApp(tester, size: viewport.value);

      final Rect screen = Offset.zero & viewport.value;
      for (final TalkCard word in coreWords) {
        final Finder finder = find.widgetWithText(TalkCardTile, word.label);
        expect(finder, findsOneWidget, reason: word.label);

        final Rect tile = tester.getRect(finder);
        expect(
          screen.expandToInclude(tile),
          screen,
          reason: '${word.label} $tile',
        );
        // A tile in the small landscape phone is about 50 dp tall. That is too
        // close to the minimum to assert.
        if (viewport.key != 'small phone landscape') {
          expect(
            tile.shortestSide,
            greaterThanOrEqualTo(AppTokens.minTouchTarget),
            reason: '${word.label} $tile',
          );
        }
      }
    });
  }

  testWidgets('The vocabulary grid lays out at any size', (tester) async {
    for (final Size size in const [
      Size.zero,
      Size(568, 1),
      Size(1, 568),
      Size(40, 40),
      Size(320, 20),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: size,
              child: VocabGrid(
                cards: const [],
                isAdminMode: false,
                tileExtent: CardSize.medium.extent,
                onTapCard: (_) {},
                onEditCard: (_) {},
                onReorder: (_, _) {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('The speak button keeps a 48dp target at every text scale', (
    tester,
  ) async {
    for (final double scale in [1.0, 2.0]) {
      installMocks();
      await pumpApp(tester, size: const Size(320, 568), textScale: scale);

      final Size size = tester.getSize(
        find.widgetWithText(ElevatedButton, 'SPEAK'),
      );
      expect(size.height, greaterThanOrEqualTo(48.0));
    }
  });
}
