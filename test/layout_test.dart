import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  for (final MapEntry<String, Size> viewport in viewports.entries) {
    for (final double scale in [1.0, 1.5, 2.0]) {
      testWidgets('${viewport.key} at text scale $scale does not overflow', (
        tester,
      ) async {
        installMocks(
          storedCards: [
            storedCard(id: 'a', label: 'Teddy'),
            storedCard(id: 'b', label: 'A very long card label indeed'),
          ],
        );
        await pumpApp(tester, size: viewport.value, textScale: scale);

        // Build a sentence too, so the strip is populated rather than empty.
        await tester.tap(find.text('I'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Want').first);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }

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
