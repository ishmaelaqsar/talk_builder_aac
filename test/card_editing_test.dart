import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:talk_builder_aac/models/talk_card.dart';
import 'package:talk_builder_aac/widgets/talk_card_tile.dart';

import 'test_harness.dart';

void main() {
  const String apple = 'assets/symbols/apple.svg';

  Finder tile(String label) => find.widgetWithText(TalkCardTile, label);
  final Finder editor = find.text('Card details');
  final Finder addCard = find.byTooltip('Add a card');

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String labelText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  /// Writes a photo into the app's own directory, and stores a card for it.
  File storePhotoCard(String label) {
    installMocks();
    final File photo = File(p.join(appDocuments.path, 'teddy.jpg'))
      ..writeAsBytesSync(const [1, 2, 3]);
    installMocks(
      storedCards: [storedCard(id: 't', label: label, imagePath: photo.path)],
    );
    return photo;
  }

  /// Picks the symbol named [name] from the open source sheet.
  Future<void> pickSymbol(WidgetTester tester, String name) async {
    await tapAndSettle(tester, find.text('Symbol library'));
    // The picker sits above the editor, so its search field comes last.
    await tester.enterText(find.byType(TextField).last, name.toLowerCase());
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text(name));
  }

  group('The editor', () {
    testWidgets('opens on a tap in admin mode, with the card label', (
      tester,
    ) async {
      installMocks(
        storedCards: [storedCard(id: 't', label: 'Teddy')],
      );
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tapAndSettle(tester, tile('Teddy'));

      expect(editor, findsOneWidget);
      expect(labelText(tester), 'Teddy');
      expect(inStrip('Teddy'), findsNothing);
    });

    testWidgets('does not open for a child, whose tap adds the word', (
      tester,
    ) async {
      installMocks(
        storedCards: [storedCard(id: 't', label: 'Teddy')],
      );
      await pumpApp(tester);

      await tapAndSettle(tester, tile('Teddy'));

      expect(editor, findsNothing);
      expect(inStrip('Teddy'), findsOneWidget);
      expect(addCard, findsNothing);
    });

    testWidgets('keeps a new label, and the word in the strip takes it', (
      tester,
    ) async {
      installMocks(
        storedCards: [storedCard(id: 't', label: 'Teddy')],
      );
      await pumpApp(tester);
      await tapAndSettle(tester, tile('Teddy'));
      await enterAdminMode(tester);

      await tapAndSettle(tester, tile('Teddy'));
      await tester.enterText(find.byType(TextField), 'Bear');
      await tapAndSettle(tester, find.text('Save'));

      expect(await savedOrder(), ['Bear']);
      expect(inStrip('Bear'), findsOneWidget);
    });

    testWidgets('changes nothing on Cancel', (tester) async {
      installMocks(
        storedCards: [storedCard(id: 't', label: 'Teddy')],
      );
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tapAndSettle(tester, tile('Teddy'));
      await tester.enterText(find.byType(TextField), 'Bear');
      await tapAndSettle(tester, find.text('Cancel'));

      expect(editor, findsNothing);
      expect(tile('Teddy'), findsOneWidget);
      expect(await savedOrder(), ['Teddy']);
    });

    testWidgets('cannot save an empty label', (tester) async {
      installMocks(
        storedCards: [storedCard(id: 't', label: 'Teddy')],
      );
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tapAndSettle(tester, tile('Teddy'));
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save'))
            .enabled,
        isFalse,
      );
    });

    testWidgets('asks about no photo when it deletes a symbol card', (
      tester,
    ) async {
      installMocks(
        storedCards: [storedCard(id: 's', label: 'Apple', symbol: apple)],
      );
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tapAndSettle(tester, tile('Apple'));
      await tapAndSettle(tester, find.text('Delete card'));

      expect(find.text('Delete this card?'), findsOneWidget);
      expect(find.textContaining('photo'), findsNothing);
    });

    testWidgets('stores a new symbol, and deletes the old photo on Save', (
      tester,
    ) async {
      final File photo = storePhotoCard('Teddy');
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tapAndSettle(tester, tile('Teddy'));
      await tapAndSettle(tester, find.text('Change picture'));
      await pickSymbol(tester, 'Apple');
      await tapAndSettle(tester, find.text('Save'));
      await settleFileWork(tester);

      final TalkCard saved = (await savedCards()).single;
      expect(saved.symbol, apple);
      expect(saved.imagePath, isNull);
      expect(saved.label, 'Teddy');
      expect(photo.existsSync(), isFalse);
    });

    testWidgets('keeps the old photo when the parent cancels', (tester) async {
      final File photo = storePhotoCard('Teddy');
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tapAndSettle(tester, tile('Teddy'));
      await tapAndSettle(tester, find.text('Change picture'));
      await pickSymbol(tester, 'Apple');
      await tapAndSettle(tester, find.text('Cancel'));
      await settleFileWork(tester);

      expect((await savedCards()).single.imagePath, photo.path);
      expect(photo.existsSync(), isTrue);
    });
  });

  group('A new card', () {
    testWidgets('admin mode with no cards points at Add', (tester) async {
      installMocks();
      await pumpApp(tester);
      await enterAdminMode(tester);

      expect(addCard, findsOneWidget);
      expect(find.textContaining('Tap the + button'), findsOneWidget);
    });

    testWidgets('from the symbol library stores nothing on Cancel', (
      tester,
    ) async {
      installMocks();
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tapAndSettle(tester, addCard);
      await pickSymbol(tester, 'Apple');
      expect(labelText(tester), 'Apple');
      await tapAndSettle(tester, find.text('Cancel'));

      expect(await savedCards(), isEmpty);
    });

    testWidgets('from a photo copies the photo into the app on Save', (
      tester,
    ) async {
      final Directory picker = Directory.systemTemp.createTempSync('tb_pick');
      addTearDown(() => picker.deleteSync(recursive: true));
      final File picked = File(p.join(picker.path, 'picked.jpg'))
        ..writeAsBytesSync(const [7, 8, 9]);
      installMocks(pickedPhoto: picked.path);
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tapAndSettle(tester, addCard);
      await tapAndSettle(tester, find.text('Choose from the gallery'));
      await tester.enterText(find.byType(TextField), 'Teddy');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Save'));
      await settleFileWork(tester);

      final TalkCard saved = (await savedCards()).single;
      expect(saved.label, 'Teddy');
      expect(p.isWithin(appDocuments.path, saved.imagePath!), isTrue);
      expect(File(saved.imagePath!).readAsBytesSync(), const [7, 8, 9]);
    });

    testWidgets('from a photo leaves no file in the app on Cancel', (
      tester,
    ) async {
      final Directory picker = Directory.systemTemp.createTempSync('tb_pick');
      addTearDown(() => picker.deleteSync(recursive: true));
      final File picked = File(p.join(picker.path, 'picked.jpg'))
        ..writeAsBytesSync(const [7, 8, 9]);
      installMocks(pickedPhoto: picked.path);
      await pumpApp(tester);
      await enterAdminMode(tester);

      await tapAndSettle(tester, addCard);
      await tapAndSettle(tester, find.text('Choose from the gallery'));
      expect(editor, findsOneWidget);
      await tapAndSettle(tester, find.text('Cancel'));
      await settleFileWork(tester);

      expect(await savedCards(), isEmpty);
      expect(appDocuments.listSync(), isEmpty);
    });
  });

  group('A drag', () {
    List<Map<String, dynamic>> threeCards() => [
      storedCard(id: 'a', label: 'Apple', symbol: apple),
      storedCard(id: 'b', label: 'Ball', symbol: 'assets/symbols/ball.svg'),
      storedCard(
        id: 'c',
        label: 'Cake',
        symbol: 'assets/symbols/cake_slice.svg',
      ),
    ];

    testWidgets('in admin mode changes the stored order', (tester) async {
      installMocks(storedCards: threeCards());
      await pumpApp(tester);
      await enterAdminMode(tester);

      await dragCard(tester, 'Apple', 'Ball');

      expect(await savedOrder(), ['Ball', 'Apple', 'Cake']);
    });

    // The control for the case above: the same gesture must move a card
    // there, or this case proves nothing.
    testWidgets('in child mode does not', (tester) async {
      installMocks(storedCards: threeCards());
      await pumpApp(tester);

      await dragCard(tester, 'Apple', 'Ball');

      expect(await savedOrder(), ['Apple', 'Ball', 'Cake']);
    });
  });
}
