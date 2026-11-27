import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_builder_aac/data/card_repository.dart';
import 'package:talk_builder_aac/models/talk_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory documents;
  late Directory temporary;
  late CardRepository repository;

  setUp(() {
    // Two levels down, so an entry that climbs out with `../../` would land
    // in [root], where a test can look for it.
    root = Directory.systemTemp.createTempSync('tb_repo');
    documents = Directory(p.join(root.path, 'app', 'documents'))
      ..createSync(recursive: true);
    temporary = Directory(p.join(root.path, 'tmp'))..createSync();
    repository = CardRepository();
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => call.method == 'getTemporaryDirectory'
              ? temporary.path
              : documents.path,
        );
  });

  tearDown(() => root.deleteSync(recursive: true));

  File writeZip(Map<String, List<int>> entries) {
    final Archive archive = Archive();
    entries.forEach(
      (name, bytes) => archive.add(ArchiveFile.bytes(name, bytes)),
    );
    final File zip = File(p.join(root.path, 'fixture.zip'));
    zip.writeAsBytesSync(ZipEncoder().encode(archive));
    return zip;
  }

  List<int> asJson(Object value) => utf8.encode(json.encode(value));

  List<String> documentNames() =>
      documents.listSync().map((e) => p.basename(e.path)).toList()..sort();

  /// A card record in the shape that Toddler Talk's `TalkCard.toJson` writes.
  /// A photo's `content` is a path on the device that wrote the backup.
  Map<String, dynamic> toddlerTalkCard({
    required String id,
    required String label,
    required String type,
    required String content,
    String? audioPath,
    String? speech,
    String? page,
    int color = 0xFFFFE0B2,
    bool isVisible = true,
  }) => {
    'id': id,
    'label': label,
    'type': type,
    'content': content,
    'audioPath': audioPath,
    'speech': speech,
    'page': page,
    'color': color,
    'isVisible': isVisible,
  };

  group('load', () {
    test('skips a record that it cannot read, and keeps the others', () async {
      SharedPreferences.setMockInitialValues({
        CardRepository.storageKey: json.encode([
          {'id': 'a', 'label': 'Cup', 'imagePath': 'cup.jpg'},
          {'id': 7, 'label': 'Bad id'},
          'not a record',
          {
            'id': 'b',
            'label': 'Ball',
            'symbol': 'assets/symbols/ball.svg',
            'isCustom': true,
          },
        ]),
      });

      expect((await repository.load()).map((c) => c.id), ['a', 'b']);
    });

    test('throws on text that is not JSON', () async {
      SharedPreferences.setMockInitialValues({
        CardRepository.storageKey: 'not json',
      });

      await expectLater(repository.load(), throwsFormatException);
    });
  });

  test('startAgain keeps the unreadable text, then stores no cards', () async {
    SharedPreferences.setMockInitialValues({
      CardRepository.storageKey: 'not json',
    });

    await repository.startAgain();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(CardRepository.rescueKey), 'not json');
    expect(await repository.load(), isEmpty);
  });

  group('backup', () {
    test('a Talk Builder backup round-trips', () async {
      final File photo = File(p.join(documents.path, 'face.jpg'))
        ..writeAsBytesSync(const [1, 2, 3]);
      final List<TalkCard> cards = [
        TalkCard(
          id: 'p',
          label: 'Mummy',
          imagePath: photo.path,
          isCustom: true,
        ),
        const TalkCard(
          id: 's',
          label: 'Apple',
          symbol: 'assets/symbols/apple.svg',
          isCustom: true,
        ),
        const TalkCard(
          id: 'h',
          label: 'Crème brûlée 🍰',
          symbol: 'assets/symbols/cake.svg',
          isCustom: true,
          isVisible: false,
        ),
      ];

      final File zip = await repository.writeBackup(cards);

      expect(p.isWithin(temporary.path, zip.path), isTrue);
      expect(
        p.basename(zip.path),
        matches(RegExp(r'^talk_builder_backup_\d{4}-\d{2}-\d{2}\.zip$')),
      );

      // A restore onto another device: the photo is not there yet.
      photo.deleteSync();
      final (List<TalkCard> restored, _) = await repository.readBackup(
        zip,
        const [],
      );

      expect(restored.map((c) => c.id), ['p', 's', 'h']);
      expect(restored[0].imagePath, photo.path);
      expect(File(restored[0].imagePath!).readAsBytesSync(), const [1, 2, 3]);
      expect(restored[1].symbol, 'assets/symbols/apple.svg');
      expect(restored[1].imagePath, isNull);
      expect(restored[2].label, 'Crème brûlée 🍰');
      expect(restored[2].isVisible, isFalse);
      expect(restored.every((c) => c.isCustom), isTrue);
    });

    test('a photo card whose file is gone stays in the manifest', () async {
      final File zip = await repository.writeBackup([
        TalkCard(
          id: 'g',
          label: 'Gone',
          imagePath: p.join(documents.path, 'gone.jpg'),
          isCustom: true,
        ),
      ]);

      final Archive archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
      final List<dynamic> manifest = json.decode(
        utf8.decode(archive.findFile('data.json')!.content),
      ) as List<dynamic>;
      expect(manifest.single, containsPair('imagePath', 'gone.jpg'));
      expect(archive.findFile('gone.jpg'), isNull);
    });
  });

  group('restore', () {
    test('a second import adds nothing, and counts what it skips', () async {
      final File zip = writeZip({
        'data.json': asJson([
          {'id': 'a', 'label': 'Cup', 'symbol': 'assets/symbols/cup.svg'},
          {'id': 'b', 'label': 'Ball', 'symbol': 'assets/symbols/ball.svg'},
        ]),
      });

      final (List<TalkCard> first, _) = await repository.readBackup(
        zip,
        const [],
      );
      final (List<TalkCard> second, RestoreOutcome outcome) = await repository
          .readBackup(zip, first);

      expect(second.map((c) => c.id), ['a', 'b']);
      expect(outcome.added, 0);
      expect(outcome.skipped, 2);
    });

    test(
      'a Toddler Talk backup brings its photo, symbol, and emoji cards',
      () async {
        const String device =
            '/data/user/0/dev.aqsar.toddler_talk_aac/app_flutter';
        final File zip = writeZip({
          'cards.json': asJson([
            toddlerTalkCard(
              id: 'photo',
              label: 'Mummy',
              type: 'image',
              content: '$device/face.jpg',
              audioPath: '$device/mummy.m4a',
              speech: 'Hello, Mummy',
              page: 'family',
              color: 0xFFF8BBD0,
              isVisible: false,
            ),
            toddlerTalkCard(
              id: 'gif',
              label: 'Dance',
              type: 'image',
              content: '$device/dance.gif',
            ),
            toddlerTalkCard(
              id: 'symbol',
              label: 'Apple',
              type: 'asset',
              content: 'assets/symbols/apple.svg',
              audioPath: '$device/apple.m4a',
            ),
            toddlerTalkCard(
              id: 'emoji',
              label: 'Dog',
              type: 'emoji',
              content: '🐶',
            ),
          ]),
          'pages.json': asJson([
            {'id': 'family', 'name': 'Family', 'symbol': null},
          ]),
          'settings.json': asJson({'voice': 'british', 'slow': true}),
          'face.jpg': const [1, 2, 3],
          'dance.gif': const [4, 5],
          'mummy.m4a': const [6],
          'apple.m4a': const [7],
        });

        final (List<TalkCard> cards, RestoreOutcome outcome) = await repository
            .readBackup(zip, const []);

        expect(cards.map((c) => c.id), ['photo', 'gif', 'symbol', 'emoji']);
        expect(outcome.added, 4);
        expect(outcome.recordingsDropped, 2);

        final TalkCard photo = cards[0];
        expect(photo.label, 'Mummy');
        expect(photo.imagePath, p.join(documents.path, 'face.jpg'));
        expect(File(photo.imagePath!).readAsBytesSync(), const [1, 2, 3]);
        expect(photo.symbol, isNull);
        expect(photo.icon, isNull);
        expect(photo.color, 0xFFF8BBD0);
        expect(photo.isVisible, isFalse);

        expect(cards[1].imagePath, p.join(documents.path, 'dance.gif'));
        expect(File(cards[1].imagePath!).existsSync(), isTrue);
        expect(cards[2].symbol, 'assets/symbols/apple.svg');
        expect(cards[2].imagePath, isNull);
        expect(cards[3].icon, '🐶');
        expect(cards.every((c) => c.isCustom), isTrue);

        // No recording and no manifest reaches the device.
        expect(documentNames(), ['dance.gif', 'face.jpg']);
      },
    );

    test('a zip with no manifest throws, and writes no file', () async {
      final File zip = writeZip({
        'holiday.png': const [1, 2],
      });

      await expectLater(
        repository.readBackup(zip, const []),
        throwsA(isA<BackupException>()),
      );
      expect(documentNames(), isEmpty);
    });

    test('an entry that climbs out lands inside the documents', () async {
      final File zip = writeZip({
        'data.json': asJson([
          {'id': 'o', 'label': 'Out', 'imagePath': 'outside.jpg'},
        ]),
        '../../outside.jpg': const [1],
      });

      await repository.readBackup(zip, const []);

      expect(File(p.join(root.path, 'outside.jpg')).existsSync(), isFalse);
      expect(documentNames(), ['outside.jpg']);
    });

    test('the files of a skipped card are not written', () async {
      final File zip = writeZip({
        'data.json': asJson([
          {'id': 'a', 'label': 'Teddy', 'imagePath': 'teddy.jpg'},
        ]),
        'teddy.jpg': const [1],
      });

      final (_, RestoreOutcome outcome) = await repository.readBackup(zip, [
        const TalkCard(id: 'a', label: 'Teddy', isCustom: true),
      ]);

      expect(outcome.skipped, 1);
      expect(documentNames(), isEmpty);
    });
  });
}
