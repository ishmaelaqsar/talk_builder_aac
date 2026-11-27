// The test reads what reorderable_grid_view reads, through the library that
// it imports.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_builder_aac/screens/builder_screen.dart';
import 'package:talk_builder_aac/theme.dart';

import 'test_harness.dart';

/// The app uses material_ui, but reorderable_grid_view imports
/// package:flutter/material.dart. Without a bridge, its widgets find no theme
/// and no localisations of that library.
void main() {
  testWidgets('A widget of the legacy library gets the app theme and '
      'localisations', (tester) async {
    installMocks(
      storedCards: [storedCard(id: 'a', label: 'Teddy')],
    );
    await pumpApp(tester);

    final BuildContext below = tester.element(find.byType(BuilderScreen));
    final legacy.ColorScheme colours = legacy.Theme.of(below).colorScheme;
    expect(colours.primary, AppTokens.speak);
    expect(colours.surface, AppTokens.surface);
    expect(legacy.MaterialLocalizations.of(below).cancelButtonLabel, 'Cancel');
  });
}
