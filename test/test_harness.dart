import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_builder_aac/main.dart';
import 'package:talk_builder_aac/widgets/mini_card.dart';

/// Every text-to-speech call the app made during a test, in order.
final List<MethodCall> ttsCalls = [];

/// Installs the plugin mocks the app needs to boot in a test.
void installMocks({List<Map<String, dynamic>> storedCards = const []}) {
  ttsCalls.clear();

  SharedPreferences.setMockInitialValues(
    storedCards.isEmpty
        ? {}
        : {'flutter.toddler_cards': json.encode(storedCards)},
  );

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => '.',
  );

  messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
    call,
  ) async {
    ttsCalls.add(call);
    return 1;
  });
}

/// Pumps the app at a chosen viewport and text scale.
Future<void> pumpApp(
  WidgetTester tester, {
  Size size = const Size(800, 1280),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: const TalkBuilderApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// A stored card in the shape the app itself writes.
Map<String, dynamic> storedCard({
  required String id,
  required String label,
  String imagePath = 'missing.jpg',
  bool isVisible = true,
}) => {
  'id': id,
  'label': label,
  'imagePath': imagePath,
  'color': 0xFFE8EDE1,
  'isCustom': true,
  'isVisible': isVisible,
};

/// Finds [text] inside the sentence strip only.
///
/// A plain `find.text` also matches the pinned core row, and the core row comes
/// second in the tree, so `.last` picks the wrong widget.
Finder inStrip(String text) =>
    find.descendant(of: find.byType(MiniCard), matching: find.text(text));

/// Waits for a failed image load to reach its error builder.
///
/// Needs [WidgetTester.runAsync]: a widget test runs in fake async, so a real
/// file read never completes and the error builder never fires.
Future<void> settleImages(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

/// Enters admin mode by holding the lock, the way a parent does.
Future<void> enterAdminMode(WidgetTester tester) async {
  await tester.longPress(find.byIcon(Icons.lock_outline));
  await tester.pumpAndSettle();
}
