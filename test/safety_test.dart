import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_builder_aac/theme.dart';

import 'test_harness.dart';

/// The destructive paths. Every one of these could previously lose data.
void main() {
  testWidgets('Clear offers Undo, and Undo restores the sentence', (
    tester,
  ) async {
    installMocks();
    await pumpApp(tester);

    await tester.tap(find.text('I'));
    await tester.pumpAndSettle();
    expect(find.text('I'), findsNWidgets(2));

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('I'), findsOneWidget);

    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('I'), findsNWidgets(2));
  });

  testWidgets('Deleting a card asks first, and Cancel keeps it', (
    tester,
  ) async {
    installMocks(
      storedCards: [storedCard(id: 'a', label: 'Teddy')],
    );
    await pumpApp(tester);
    await enterAdminMode(tester);

    await tester.tap(find.byTooltip('Delete "Teddy"'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this card?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Teddy'), findsOneWidget);
  });

  testWidgets('Confirming the delete removes the card', (tester) async {
    installMocks(
      storedCards: [storedCard(id: 'a', label: 'Teddy')],
    );
    await pumpApp(tester);
    await enterAdminMode(tester);

    await tester.tap(find.byTooltip('Delete "Teddy"'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Teddy'), findsNothing);
  });

  testWidgets('Deleting a card also takes it out of the sentence', (
    tester,
  ) async {
    installMocks(
      storedCards: [storedCard(id: 'a', label: 'Teddy')],
    );
    await pumpApp(tester);

    await tester.tap(find.text('Teddy'));
    await tester.pumpAndSettle();
    expect(find.text('Teddy'), findsNWidgets(2));

    await enterAdminMode(tester);
    await tester.tap(find.byTooltip('Delete "Teddy"'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Teddy'), findsNothing);
  });

  testWidgets('A card whose photo is gone shows a placeholder, not a crash', (
    tester,
  ) async {
    installMocks(
      storedCards: [
        storedCard(id: 'a', label: 'Teddy', imagePath: '/does/not/exist.jpg'),
      ],
    );
    await pumpApp(tester);
    await settleImages(tester);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    // The label survives, so the parent can still identify and remove the card.
    expect(find.text('Teddy'), findsOneWidget);
  });

  testWidgets('A legacy card with no isCustom flag loads and is tappable', (
    tester,
  ) async {
    installMocks(
      storedCards: [
        {'id': 'legacy', 'label': 'Apple', 'imagePath': 'apple.jpg'},
      ],
    );
    await pumpApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Apple'), findsOneWidget);

    // The old build threw here, reading a null colour for the strip's mini card.
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Apple'), findsNWidgets(2));
  });

  testWidgets('Admin controls meet the minimum touch target', (tester) async {
    installMocks(
      storedCards: [storedCard(id: 'a', label: 'Teddy')],
    );
    await pumpApp(tester);
    await enterAdminMode(tester);

    for (final String tooltip in ['Delete "Teddy"', 'Hide "Teddy"']) {
      final Size size = tester.getSize(find.byTooltip(tooltip));
      expect(
        size.shortestSide,
        greaterThanOrEqualTo(AppTokens.minTouchTarget),
        reason: '$tooltip is below the 48dp minimum',
      );
    }
  });

  testWidgets('Hiding a card takes it off the child-facing grid', (
    tester,
  ) async {
    installMocks(
      storedCards: [storedCard(id: 'a', label: 'Teddy')],
    );
    await pumpApp(tester);
    await enterAdminMode(tester);

    await tester.tap(find.byTooltip('Hide "Teddy"'));
    await tester.pumpAndSettle();

    // Still shown to the parent while editing...
    expect(find.text('Teddy'), findsOneWidget);

    // ...but gone once locked.
    await tester.longPress(find.byIcon(Icons.lock_open));
    await tester.pumpAndSettle();
    expect(find.text('Teddy'), findsNothing);
  });
}
