import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_builder_aac/data/card_repository.dart';
import 'package:talk_builder_aac/main.dart';
import 'package:talk_builder_aac/theme.dart';
import 'package:talk_builder_aac/widgets/talk_card_tile.dart';

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

  Finder tile(String label) => find.widgetWithText(TalkCardTile, label);

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// [text] inside the delete question, which sits on top of the editor.
  Finder inDeleteQuestion(String text) => find.descendant(
    of: find.widgetWithText(AlertDialog, 'Delete this card?'),
    matching: find.text(text),
  );

  testWidgets('Deleting a card asks first, and Cancel keeps it', (
    tester,
  ) async {
    installMocks(
      storedCards: [storedCard(id: 'a', label: 'Teddy')],
    );
    await pumpApp(tester);
    await enterAdminMode(tester);

    await tapAndSettle(tester, tile('Teddy'));
    await tapAndSettle(tester, find.text('Delete card'));

    expect(find.text('Delete this card?'), findsOneWidget);

    await tapAndSettle(tester, inDeleteQuestion('Cancel'));

    expect(find.text('Delete this card?'), findsNothing);
    expect(find.text('Card details'), findsOneWidget);
    expect(tile('Teddy'), findsOneWidget);
    expect(await savedOrder(), ['Teddy']);
  });

  testWidgets('Confirming the delete removes the card and its photo', (
    tester,
  ) async {
    installMocks();
    final File photo = File(p.join(appDocuments.path, 'teddy.jpg'))
      ..writeAsBytesSync(const [1, 2, 3]);
    installMocks(
      storedCards: [storedCard(id: 'a', label: 'Teddy', imagePath: photo.path)],
    );
    await pumpApp(tester);
    await enterAdminMode(tester);

    await tapAndSettle(tester, tile('Teddy'));
    await tapAndSettle(tester, find.text('Delete card'));
    await tapAndSettle(tester, inDeleteQuestion('Delete'));
    await settleFileWork(tester);

    expect(find.text('Card details'), findsNothing);
    expect(tile('Teddy'), findsNothing);
    expect(await savedOrder(), isEmpty);
    expect(photo.existsSync(), isFalse);
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
    await tapAndSettle(tester, tile('Teddy'));
    await tapAndSettle(tester, find.text('Delete card'));
    await tapAndSettle(tester, inDeleteQuestion('Delete'));

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

    void expectTarget(String name, Finder control) => expect(
      tester.getSize(control).shortestSide,
      greaterThanOrEqualTo(AppTokens.minTouchTarget),
      reason: '$name is below the 48dp minimum',
    );

    // The button, not its tooltip: the tooltip wraps only the visible circle,
    // and the button pads it to the target.
    expectTarget(
      'Add a card',
      find.ancestor(
        of: find.byTooltip('Add a card'),
        matching: find.byType(IconButton),
      ),
    );
    await tapAndSettle(tester, tile('Teddy'));
    expectTarget(
      'Delete card',
      find.ancestor(
        of: find.text('Delete card'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expectTarget('The show switch', find.byType(SwitchListTile));
  });

  testWidgets('Hiding a card takes it off the child-facing grid', (
    tester,
  ) async {
    installMocks(
      storedCards: [storedCard(id: 'a', label: 'Teddy')],
    );
    await pumpApp(tester);
    await enterAdminMode(tester);

    await tapAndSettle(tester, tile('Teddy'));
    await tapAndSettle(tester, find.byType(Switch));
    await tapAndSettle(tester, find.text('Save'));

    // Still shown to the parent while editing...
    expect(find.text('Teddy'), findsOneWidget);

    // ...but gone once locked.
    await tester.tap(find.byIcon(Icons.lock_open));
    await tester.pumpAndSettle();
    expect(find.text('Teddy'), findsNothing);
  });

  bool isLocked() => find.text('Admin mode').evaluate().isEmpty;
  bool gateOpen() => find.text('Grown-ups only').evaluate().isNotEmpty;

  /// The system UI modes the app asked for, in order.
  List<Object?> uiModes() => [
    for (final MethodCall call in platformCalls)
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') call.arguments,
  ];

  bool leftTheApp() =>
      platformCalls.any((call) => call.method == 'SystemNavigator.pop');

  final String hiddenBars = SystemUiMode.immersiveSticky.toString();
  final String shownBars = SystemUiMode.edgeToEdge.toString();

  group('The lock', () {
    testWidgets('A tap does not unlock it', (tester) async {
      installMocks();
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Press and hold to edit cards'));
      await tester.pumpAndSettle();

      expect(gateOpen(), isFalse);
      expect(isLocked(), isTrue);
    });

    testWidgets('A hold opens the gate, and the hold alone does not unlock', (
      tester,
    ) async {
      installMocks();
      await pumpApp(tester);

      await holdLock(tester);

      expect(gateOpen(), isTrue);
      expect(isLocked(), isTrue);
    });

    testWidgets('A wrong key closes the gate and leaves it locked', (
      tester,
    ) async {
      installMocks();
      await pumpApp(tester);
      await holdLock(tester);

      await tapGateKey(tester, gateCode(tester).first % 9 + 1);

      expect(gateOpen(), isFalse);
      expect(isLocked(), isTrue);
    });

    testWidgets('The right keys unlock it', (tester) async {
      installMocks();
      await pumpApp(tester);
      await holdLock(tester);

      await solveParentGate(tester);

      expect(gateOpen(), isFalse);
      expect(isLocked(), isFalse);
    });

    testWidgets('The gate closes itself when no key comes', (tester) async {
      installMocks();
      await pumpApp(tester);
      await holdLock(tester);

      await tester.pump(AppTokens.gateTimeout);
      await tester.pumpAndSettle();

      expect(gateOpen(), isFalse);
      expect(isLocked(), isTrue);
    });

    testWidgets('A tap on the open lock locks it', (tester) async {
      installMocks();
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tester.tap(find.byIcon(Icons.lock_open));
      await tester.pumpAndSettle();

      expect(isLocked(), isTrue);
    });
  });

  group('Auto-lock', () {
    testWidgets('A trip to the background locks', (tester) async {
      installMocks();
      await pumpApp(tester);
      await enterAdminMode(tester);

      backgroundAndReturn(tester);
      await tester.pumpAndSettle();

      expect(isLocked(), isTrue);
    });

    testWidgets('A trip to the background during an open flow does not lock', (
      tester,
    ) async {
      installMocks();
      await pumpApp(tester);
      await enterAdminMode(tester);

      // The source sheet stands in for the camera or a picker, which send the
      // app to the background.
      await tester.tap(find.byTooltip('Add a card'));
      await tester.pumpAndSettle();
      backgroundAndReturn(tester);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(isLocked(), isFalse);
    });

    testWidgets('Two minutes with no touch lock', (tester) async {
      installMocks();
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tester.pump(AppTokens.adminTimeout);
      await tester.pumpAndSettle();

      expect(isLocked(), isTrue);
    });

    testWidgets('A touch restarts the two minutes', (tester) async {
      installMocks();
      await pumpApp(tester);
      await enterAdminMode(tester);
      const Duration nearly = Duration(seconds: 90);

      await tester.pump(nearly);
      // The title does nothing on a tap, so only the touch itself counts.
      await tester.tap(find.text('Admin mode'));
      await tester.pump(nearly);
      expect(isLocked(), isFalse);

      await tester.pump(AppTokens.adminTimeout - nearly);
      await tester.pumpAndSettle();
      expect(isLocked(), isTrue);
    });
  });

  group('The screen in child mode', () {
    testWidgets('Back does not leave the app', (tester) async {
      installMocks();
      await pumpApp(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(leftTheApp(), isFalse);
    });

    // The control for the case above: the same Back must leave here, or that
    // case proves nothing.
    testWidgets('Back leaves the app in admin mode', (tester) async {
      installMocks();
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(leftTheApp(), isTrue);
    });

    testWidgets(
      'The system bars hide, show for a parent, and hide at the lock',
      (tester) async {
        installMocks();
        await pumpApp(tester);
        expect(uiModes(), [hiddenBars]);

        await enterAdminMode(tester);
        expect(uiModes().last, shownBars);

        await tester.tap(find.byIcon(Icons.lock_open));
        await tester.pumpAndSettle();
        expect(uiModes().last, hiddenBars);
      },
    );

    // Android can show the bars again after a resume.
    testWidgets('The system bars hide again when the app comes back', (
      tester,
    ) async {
      installMocks();
      await pumpApp(tester);
      platformCalls.clear();

      backgroundAndReturn(tester);
      await tester.pumpAndSettle();

      expect(uiModes(), isNotEmpty);
      expect(uiModes(), everyElement(hiddenBars));
    });
  });

  group('The load', () {
    const String emptyText = 'No photo or symbol cards yet.';
    const String unreadable = 'not json';

    Future<String?> stored(String key) async =>
        (await SharedPreferences.getInstance()).getString(key);

    testWidgets('The empty-state text waits for the cards', (tester) async {
      installMocks();
      await tester.pumpWidget(const TalkBuilderApp());

      expect(find.textContaining(emptyText), findsNothing);
      expect(find.widgetWithText(TalkCardTile, 'I'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.textContaining(emptyText), findsOneWidget);
    });

    testWidgets('Unreadable cards show the error and Try again to a child', (
      tester,
    ) async {
      installMocks(rawStoredCards: unreadable);
      await pumpApp(tester);

      expect(find.text('The cards could not be loaded'), findsOneWidget);
      expect(find.text('Ask a grown-up to help.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Start again'), findsNothing);
    });

    testWidgets('Try again loads the cards once they can be read', (
      tester,
    ) async {
      installMocks(rawStoredCards: unreadable);
      await pumpApp(tester);

      await (await SharedPreferences.getInstance()).setString(
        CardRepository.storageKey,
        json.encode([storedCard(id: 'a', label: 'Teddy')]),
      );
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Teddy'), findsOneWidget);
    });

    testWidgets('The core words still speak while the error shows', (
      tester,
    ) async {
      installMocks(rawStoredCards: unreadable);
      await pumpApp(tester);

      await tester.tap(find.widgetWithText(TalkCardTile, 'I'));
      await tester.pumpAndSettle();

      expect(ttsCalls.last.method, 'speak');
      expect(ttsCalls.last.arguments, 'I');
    });

    // A save would put an empty list over the text that a retry can read.
    testWidgets('No control that saves the cards shows', (tester) async {
      installMocks(rawStoredCards: unreadable);
      await pumpApp(tester);
      await enterAdminMode(tester);

      expect(find.byTooltip('Add a card'), findsNothing);
      expect(find.byTooltip('Settings and backup'), findsNothing);

      await tester.tap(find.byIcon(Icons.lock_open));
      await tester.pumpAndSettle();
      expect(await stored(CardRepository.storageKey), unreadable);
    });

    testWidgets('Start again keeps a copy, then shows an empty grid', (
      tester,
    ) async {
      installMocks(rawStoredCards: unreadable);
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tester.tap(find.text('Start again'));
      await tester.pumpAndSettle();

      expect(await stored(CardRepository.rescueKey), unreadable);
      expect(await stored(CardRepository.storageKey), '[]');
      expect(find.text('The cards could not be loaded'), findsNothing);
      expect(find.byTooltip('Add a card'), findsOneWidget);
    });
  });
}
