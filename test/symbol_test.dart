import 'dart:convert';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_builder_aac/widgets/mini_card.dart';
import 'package:talk_builder_aac/widgets/symbol_picker.dart';
import 'package:talk_builder_aac/widgets/talk_card_tile.dart';

import 'test_harness.dart';

void main() {
  const String apple = 'assets/symbols/apple.svg';

  Finder svgIn(Finder parent) =>
      find.descendant(of: parent, matching: find.byType(SvgPicture));

  Future<void> openSymbolLibrary(WidgetTester tester) async {
    await enterAdminMode(tester);
    await tester.tap(find.byTooltip('Add a card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Symbol library'));
    await tester.pumpAndSettle();
  }

  testWidgets('A symbol card draws its symbol on the grid and in the strip', (
    tester,
  ) async {
    installMocks(
      storedCards: [storedCard(id: 's', label: 'Apple', symbol: apple)],
    );
    await pumpApp(tester);

    final Finder tile = find.widgetWithText(TalkCardTile, 'Apple');
    expect(svgIn(tile), findsOneWidget);
    // The bundled asset loads, so no placeholder shows.
    await settleImages(tester);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(svgIn(find.widgetWithText(MiniCard, 'Apple')), findsOneWidget);
  });

  testWidgets('A symbol that does not load shows a placeholder', (
    tester,
  ) async {
    installMocks(
      storedCards: [
        storedCard(id: 's', label: 'Gone', symbol: 'assets/symbols/gone.svg'),
      ],
    );
    await pumpApp(tester);
    await settleImages(tester);

    expect(
      find.descendant(
        of: find.widgetWithText(TalkCardTile, 'Gone'),
        matching: find.byIcon(Icons.image_not_supported_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('The symbol library is searchable, and names symbols readably', (
    tester,
  ) async {
    installMocks();
    await pumpApp(tester);
    await openSymbolLibrary(tester);

    // Hundreds of symbols in a plain grid are not browsable.
    expect(find.textContaining('Search'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bathe');
    await tester.pumpAndSettle();
    expect(find.text('Bathe'), findsOneWidget);
  });

  test('A file name becomes a label that a parent would write', () {
    // The bundled set qualifies an entry after a comma or a dash.
    expect(prettifySymbolName('assets/symbols/bathe_,_to.svg'), 'Bathe');
    expect(prettifySymbolName('assets/symbols/shoe_-_mans.svg'), 'Shoe');
    expect(
      prettifySymbolName('assets/symbols/chest_of_drawers.svg'),
      'Chest of drawers',
    );
    expect(prettifySymbolName('assets/symbols/settee_1.svg'), 'Settee 1');
    // A dash inside a word is part of the word, not a qualifier.
    expect(prettifySymbolName('assets/symbols/t-shirt.svg'), 'T-shirt');
  });

  testWidgets('A parent adds a card from the symbol library', (tester) async {
    installMocks();
    await pumpApp(tester);
    await openSymbolLibrary(tester);

    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();

    // The label dialog starts from the symbol's name.
    expect(find.widgetWithText(TextField, 'Apple'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<dynamic> stored =
        json.decode(prefs.getString('toddler_cards')!) as List<dynamic>;
    expect(stored.single, containsPair('symbol', apple));
    expect(stored.single, containsPair('isCustom', true));
    expect(stored.single, containsPair('label', 'Apple'));
  });
}
