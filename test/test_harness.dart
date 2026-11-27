import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_builder_aac/data/card_repository.dart';
import 'package:talk_builder_aac/main.dart';
import 'package:talk_builder_aac/models/talk_card.dart';
import 'package:talk_builder_aac/theme.dart';
import 'package:talk_builder_aac/widgets/mini_card.dart';
import 'package:talk_builder_aac/widgets/talk_card_tile.dart';

/// Every text-to-speech call the app made during a test, in order.
final List<MethodCall> ttsCalls = [];

/// Every system call the app made during a test, in order: the system bars,
/// and a Back press that leaves the app.
final List<MethodCall> platformCalls = [];

Directory? _appDocuments;

/// Where the app keeps its own files, for the current test.
///
/// The same for the whole test, so a test can call [installMocks] once to
/// learn the path, and again with the cards that it built from it.
Directory get appDocuments => _appDocuments!;

/// Installs the plugin mocks the app needs to boot in a test.
///
/// Pass [rawStoredCards] in place of [storedCards] to store text that is not a
/// list of cards. [storedSettings] is the stored settings text. [pickedPhoto]
/// is the path that the image picker returns. Null is a parent who backs out
/// of the picker.
void installMocks({
  List<Map<String, dynamic>> storedCards = const [],
  String? rawStoredCards,
  String? storedSettings,
  String? pickedPhoto,
}) {
  ttsCalls.clear();
  platformCalls.clear();

  final String? stored =
      rawStoredCards ?? (storedCards.isEmpty ? null : json.encode(storedCards));
  SharedPreferences.setMockInitialValues({
    'flutter.toddler_cards': ?stored,
    'flutter.talk_builder_settings_v1': ?storedSettings,
  });

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // A directory of its own per test, so a file that the app writes does not
  // land in the repository.
  final Directory documents = _appDocuments ??= Directory.systemTemp
      .createTempSync('tb_app');
  addTearDown(() {
    if (documents.existsSync()) documents.deleteSync(recursive: true);
    _appDocuments = null;
  });
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => documents.path,
  );

  // No platform package registers itself in a test, so the picker uses its
  // method channel.
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/image_picker'),
    (call) async => call.method == 'pickImage' ? pickedPhoto : null,
  );

  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    platformCalls.add(call);
    return null;
  });

  messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
    call,
  ) async {
    ttsCalls.add(call);
    return 1;
  });
}

/// Delivers a callback from the text-to-speech engine to the app, as the
/// plugin does on a device, and lets the app settle.
Future<void> deliverTts(
  WidgetTester tester,
  String method, [
  Object? arguments,
]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter_tts',
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
  await tester.pumpAndSettle();
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

  // Set the scale on the dispatcher, where a device puts the system setting.
  // The app then reads it through its own MediaQuery, as on a device.
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(const TalkBuilderApp());
  await tester.pumpAndSettle();
}

/// A stored card in the shape the app itself writes.
Map<String, dynamic> storedCard({
  required String id,
  required String label,
  String imagePath = 'missing.jpg',
  String? symbol,
  bool isVisible = true,
}) => {
  'id': id,
  'label': label,
  // A card shows its photo over its symbol, so a symbol card has no photo.
  if (symbol == null) 'imagePath': imagePath else 'symbol': symbol,
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

/// Enters admin mode the way a parent does: the hold, then the gate.
Future<void> enterAdminMode(WidgetTester tester) async {
  await holdLock(tester);
  await solveParentGate(tester);
}

/// Holds the lock until the parent gate opens.
///
/// [WidgetTester.longPress] is too short: the lock asks for a deliberate
/// [AppTokens.unlockHold] hold.
Future<void> holdLock(WidgetTester tester) async {
  final TestGesture hold = await tester.startGesture(
    tester.getCenter(find.byIcon(Icons.lock_outline)),
  );
  // Two frames before the clock is advanced: one to deliver the press, one for
  // the hold's ticker to record its start.
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(Duration.zero);
  await tester.pump(AppTokens.unlockHold + const Duration(milliseconds: 50));
  await hold.up();
  await tester.pumpAndSettle();
}

const List<String> _digitWords = [
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
];

/// The digits the open parent gate asks for, read from its prompt.
List<int> gateCode(WidgetTester tester) {
  // Inside the dialog only: the strip's hint also starts with "Tap".
  final String prompt = tester
      .widget<Text>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining(RegExp(r'^Tap ')),
        ),
      )
      .data!;
  return [
    for (final String word in prompt.substring('Tap '.length).split(', '))
      _digitWords.indexOf(word) + 1,
  ];
}

/// Taps [digit] on the open parent gate. A key can sit below the fold on a
/// small screen, so it is scrolled into view first.
Future<void> tapGateKey(WidgetTester tester, int digit) async {
  final Finder key = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('$digit'),
  );
  await tester.ensureVisible(key);
  await tester.pumpAndSettle();
  await tester.tap(key);
  await tester.pumpAndSettle();
}

/// Taps the digits the open parent gate asks for, in order.
Future<void> solveParentGate(WidgetTester tester) async {
  for (final int digit in gateCode(tester)) {
    await tapGateKey(tester, digit);
  }
}

/// Sends the app to the background and brings it back.
///
/// The states are walked in the order the framework requires. A paused binding
/// draws no frames, so the return leg is what lets the tree rebuild.
void backgroundAndReturn(WidgetTester tester) {
  for (final AppLifecycleState state in [
    AppLifecycleState.resumed,
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

/// Lets the app's file work finish.
///
/// A widget test runs in fake async, so a real file copy or delete never
/// completes inside [WidgetTester.pumpAndSettle]. This hands the run real
/// time, in several rounds, because each await in the app needs the event
/// loop again.
Future<void> settleFileWork(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }
}

/// The stored cards, in stored order.
Future<List<TalkCard>> savedCards() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? raw = prefs.getString(CardRepository.storageKey);
  if (raw == null) return [];
  return CardRepository().decode(raw);
}

/// The labels of the stored cards, in stored order.
Future<List<String>> savedOrder() async =>
    (await savedCards()).map((c) => c.label).toList();

/// Holds the card labelled [from] past the long press, and drags it onto the
/// card labelled [to] in small steps, as a finger does.
Future<void> dragCard(WidgetTester tester, String from, String to) async {
  final Offset start = tester.getCenter(
    find.widgetWithText(TalkCardTile, from),
  );
  final Offset end = tester.getCenter(find.widgetWithText(TalkCardTile, to));
  final TestGesture drag = await tester.startGesture(start);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  for (int step = 1; step <= 10; step++) {
    await drag.moveTo(Offset.lerp(start, end, step / 10)!);
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
  await drag.up();
  await tester.pumpAndSettle();
}
