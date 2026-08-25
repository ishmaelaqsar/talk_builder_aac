import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

/// The original baseline cases, kept as a regression check on the refactor.
void main() {
  setUp(() => installMocks());

  testWidgets('App loads and core words are visible', (tester) async {
    await pumpApp(tester);

    expect(find.text('Talk Builder'), findsOneWidget);
    expect(find.text('I'), findsOneWidget);
    expect(find.text('Want'), findsOneWidget);
    expect(find.text('SPEAK'), findsOneWidget);
  });

  testWidgets('Sentence strip: tap words, then clear', (tester) async {
    await pumpApp(tester);

    expect(find.text('I'), findsOneWidget);

    await tester.tap(find.text('I'));
    await tester.pumpAndSettle();
    expect(find.text('I'), findsNWidgets(2));

    await tester.tap(find.text('Want').first);
    await tester.pumpAndSettle();
    expect(find.text('Want'), findsNWidgets(2));

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('I'), findsOneWidget);
    expect(find.text('Want'), findsOneWidget);
  });

  testWidgets('Admin mode toggles on a long press', (tester) async {
    await pumpApp(tester);

    expect(find.byIcon(Icons.add_a_photo), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    await enterAdminMode(tester);

    expect(find.text('Admin mode'), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
  });

  testWidgets('The core words stay pinned as the photo grid scrolls', (
    tester,
  ) async {
    // Enough photo cards that the grid certainly scrolls.
    installMocks(
      storedCards: List.generate(
        24,
        (i) => storedCard(id: 'c$i', label: 'Card $i'),
      ),
    );
    await pumpApp(tester, size: const Size(400, 700));

    expect(find.text('I'), findsOneWidget);

    await tester.drag(find.byType(GridView), const Offset(0, -600));
    await tester.pumpAndSettle();

    // Still reachable: the core row is not part of the scrolling grid.
    expect(find.text('I'), findsOneWidget);
    // And the grid really did move.
    expect(find.text('Card 0'), findsNothing);
  });
}
