import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_builder_aac/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 1. Reset SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // 2. Mock Path Provider (Needed for Image Loading checks)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => ".",
        );

    // 3. Mock Text-to-Speech (So we don't actually try to speak)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (MethodCall methodCall) async => 1,
        );
  });

  testWidgets('App loads and Core Words are visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TalkBuilderApp());

    // Check for App Title
    expect(find.text('Talk Builder'), findsOneWidget);

    // Check for a few Core Words (from the grid)
    expect(find.text('I'), findsOneWidget);
    expect(find.text('Want'), findsOneWidget);

    // Check for the "SPEAK" button
    expect(find.text('SPEAK'), findsOneWidget);
  });

  testWidgets('Sentence Strip works: Click words -> Appear in strip -> Clear', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TalkBuilderApp());

    // 1. Initially, "I" should appear EXACTLY once (in the Grid only)
    expect(find.text('I'), findsOneWidget);

    // 2. Tap "I" in the Grid
    await tester.tap(find.text('I'));
    await tester.pumpAndSettle(); // Allow animation

    // 3. Now "I" should appear TWICE (Once in Grid, Once in Sentence Strip)
    expect(find.text('I'), findsNWidgets(2));

    // 4. Tap "Want"
    await tester.tap(find.text('Want'));
    await tester.pumpAndSettle();

    // 5. Verify "Want" is also there twice now
    expect(find.text('Want'), findsNWidgets(2));

    // 6. Tap "Clear"
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    // 7. Verify we are back to start (Words only exist in Grid)
    expect(find.text('I'), findsOneWidget);
    expect(find.text('Want'), findsOneWidget);
  });

  testWidgets('Admin Mode toggles correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const TalkBuilderApp());

    // 1. Check initial state (No Add Button)
    expect(find.byIcon(Icons.add_a_photo), findsNothing);
    expect(find.byIcon(Icons.lock), findsOneWidget);

    // 2. Long Press Lock to enter Admin Mode
    await tester.longPress(find.byIcon(Icons.lock));
    await tester.pumpAndSettle();

    // 3. Check Admin State
    expect(find.text('Admin Mode'), findsOneWidget);
    // The "Add Photo" button should now be visible at the bottom of the grid
    // We scroll to it just in case
    await tester.scrollUntilVisible(
      find.byIcon(Icons.add_a_photo),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
  });
}
