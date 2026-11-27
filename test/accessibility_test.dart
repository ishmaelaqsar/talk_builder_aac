import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

/// The app had no semantics at all, so a screen reader announced nothing useful.
void main() {
  testWidgets('Core words announce their label as a button', (tester) async {
    installMocks();
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpApp(tester);

    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('Want'),
    );
    expect(node.label, 'Want');
    // A button a screen reader can both announce and activate.
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    handle.dispose();
  });

  testWidgets('The lock explains that it needs a press and hold', (
    tester,
  ) async {
    installMocks();
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpApp(tester);

    expect(find.bySemanticsLabel('Unlock editing'), findsOneWidget);
    expect(find.byTooltip('Press and hold to edit cards'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('A photo card announces its label, not its file', (tester) async {
    installMocks(
      storedCards: [storedCard(id: 'a', label: 'Teddy')],
    );
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpApp(tester);

    expect(find.bySemanticsLabel('Teddy'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('A symbol card announces its label as a button', (tester) async {
    installMocks(
      storedCards: [
        storedCard(id: 's', label: 'Apple', symbol: 'assets/symbols/apple.svg'),
      ],
    );
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpApp(tester);

    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('Apple'),
    );
    expect(node.flagsCollection.isButton, isTrue);

    handle.dispose();
  });

  testWidgets('Words in the sentence say how to remove them', (tester) async {
    installMocks();
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpApp(tester);

    await tester.tap(find.text('I'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('I. In the sentence.'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('Icon-only controls carry a tooltip', (tester) async {
    installMocks();
    await pumpApp(tester);

    expect(find.byTooltip('Remove the last word'), findsOneWidget);
  });
}
