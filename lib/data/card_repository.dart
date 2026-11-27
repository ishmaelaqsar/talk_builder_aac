import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/board_settings.dart';
import '../models/talk_card.dart';

/// Raised when a backup cannot be read, so the caller can show a message
/// instead of a bare exception.
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What a restore did, so the caller can report it to the parent.
class RestoreOutcome {
  const RestoreOutcome({
    required this.added,
    required this.skipped,
    this.recordingsDropped = 0,
  });

  final int added;
  final int skipped;

  /// Added cards that carried a *Toddler Talk* recording. Talk Builder plays
  /// no recordings, so the recordings stay out.
  final int recordingsDropped;
}

/// Reads and writes the parent's cards, their photo files, and backup zips.
///
/// Holds no UI state and shows no messages. It throws on failure, and the
/// caller decides what the parent sees.
class CardRepository {
  /// Unchanged, so an existing install keeps its cards. *Toddler Talk* is
  /// another app with its own storage, so its cards arrive only through a
  /// backup.
  static const String storageKey = 'toddler_cards';

  /// The settings have a key of their own, so the stored cards keep their
  /// shape.
  static const String settingsKey = 'talk_builder_settings_v1';

  /// Keeps stored cards that the app could not read, so a new start does not
  /// lose them for good.
  static const String rescueKey = 'toddler_cards_unreadable';

  /// The file inside a Talk Builder backup that holds the cards.
  static const String _manifestName = 'data.json';

  /// The file inside a *Toddler Talk* backup that holds the cards.
  static const String _toddlerTalkManifestName = 'cards.json';

  /// The files that a restore writes. Anything else in a zip stays out.
  static const Set<String> _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif'};

  /// Throws when the stored text is not JSON. One record that cannot be read
  /// is skipped.
  Future<List<TalkCard>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(storageKey);
    if (stored == null) return [];
    return decode(stored);
  }

  /// Copies the stored text to [rescueKey], then stores no cards in its place.
  ///
  /// The copy comes first, so the old cards are on the device at every step.
  Future<void> startAgain() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(storageKey);
    if (stored != null) await prefs.setString(rescueKey, stored);
    await save(const []);
  }

  /// Parses the stored cards. Skips a record that the app cannot read, so one
  /// bad entry does not cost the parent every card.
  List<TalkCard> decode(String source) =>
      _decodeRecords(source).map((r) => r.card).toList();

  /// Reads each record in [source] by its shape: a record with a `type` key
  /// comes from *Toddler Talk*. Skips a record that cannot be read.
  static List<({TalkCard card, bool hasRecording})> _decodeRecords(
    String source,
  ) {
    final List<({TalkCard card, bool hasRecording})> records = [];
    for (final dynamic entry in json.decode(source) as List<dynamic>) {
      try {
        final Map<String, dynamic> map = entry as Map<String, dynamic>;
        records.add((
          card: map.containsKey('type')
              ? TalkCard.fromToddlerTalk(map)
              : TalkCard.fromJson(map),
          hasRecording: map['audioPath'] != null,
        ));
      } on Object {
        continue;
      }
    }
    return records;
  }

  /// Returns the stored settings. The defaults stand in when nothing is stored
  /// or the stored text cannot be read, so bad settings never block the cards.
  Future<BoardSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(settingsKey);
      return stored == null
          ? const BoardSettings()
          : BoardSettings.fromJson(json.decode(stored) as Map<String, dynamic>);
    } on Object {
      return const BoardSettings();
    }
  }

  Future<void> saveSettings(BoardSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, json.encode(settings.toJson()));
  }

  Future<void> save(List<TalkCard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      json.encode(cards.map((c) => c.toJson()).toList()),
    );
  }

  /// Copies a picked photo into the app's documents directory, and returns the
  /// path of the copy. The card keeps working after the picker's own file goes.
  Future<String> importPhoto(String sourcePath) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String extension = p.extension(sourcePath);
    final String target = p.join(
      dir.path,
      '${const Uuid().v4()}${extension.isEmpty ? '.jpg' : extension}',
    );
    await File(sourcePath).copy(target);
    return target;
  }

  /// Removes a card's photo from disk. A missing file is not an error.
  Future<void> deletePhoto(String? path) async {
    if (path == null) return;
    final File file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Writes a zip of every card and of each photo that is still on the
  /// device, and returns it.
  ///
  /// A photo has a bare file name in the manifest, so the backup restores on
  /// another device. A card whose photo is gone keeps its place, and shows the
  /// missing-photo placeholder after a restore. The zip goes to the temporary
  /// directory, so the app's own directory holds no copy, and its name carries
  /// the date, so a parent can tell two backups apart.
  Future<File> writeBackup(List<TalkCard> cards) async {
    final String date = DateTime.now().toIso8601String().substring(0, 10);
    final String manifest = json.encode([
      for (final TalkCard card in cards)
        card.imagePath == null
            ? card.toJson()
            : card.copyWith(imagePath: p.basename(card.imagePath!)).toJson(),
    ]);
    return File(
      await _writeZip(
        p.join((await getTemporaryDirectory()).path, 'backup'),
        'talk_builder_backup_$date.zip',
        manifest,
        cards.map((c) => c.imagePath).whereType<String>().toList(),
      ),
    );
  }

  /// Packs the zip on a background isolate, so many photos do not freeze the
  /// screen.
  ///
  /// Static, and given only strings, so the isolate receives no repository.
  static Future<String> _writeZip(
    String stagingPath,
    String zipName,
    String manifest,
    List<String> photos,
  ) => Isolate.run(() async {
    // A zip from another day has another name, so nothing overwrites it, and
    // each one holds every photo.
    final Directory staging = Directory(stagingPath);
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    final String zipPath = p.join(staging.path, zipName);
    final ZipFileEncoder encoder = ZipFileEncoder();
    encoder.create(zipPath);
    encoder.addArchiveFile(ArchiveFile.string(_manifestName, manifest));
    for (final String path in photos) {
      final File file = File(path);
      // A photo is already compressed, so a second pass costs time and saves
      // nothing.
      if (await file.exists()) {
        await encoder.addFile(file, null, ZipFileEncoder.store);
      }
    }
    await encoder.close();
    return zipPath;
  });

  /// Reads a Talk Builder or a *Toddler Talk* backup, and merges its cards
  /// into [existing].
  ///
  /// Merges by id, so importing the same backup twice adds nothing. Returns the
  /// merged list together with the counts, and never mutates [existing].
  Future<(List<TalkCard>, RestoreOutcome)> readBackup(
    File zip,
    List<TalkCard> existing,
  ) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final (List<TalkCard> added, RestoreOutcome outcome) = await _unpack(
      zip.path,
      dir.path,
      existing.map((c) => c.id).toSet(),
    );
    return ([...existing, ...added], outcome);
  }

  /// Reads the zip on a background isolate, and returns the cards whose ids
  /// are not in [known], with each photo path moved to [dirPath].
  ///
  /// Writes only the photos of those cards. Nothing is written until the
  /// manifest is found, so a zip that is not a backup leaves the app's
  /// directory as it was. The paths in a backup belong to the device that
  /// wrote it, so a photo keeps only its base name.
  ///
  /// Static, and given only strings, so the isolate receives no repository.
  static Future<(List<TalkCard>, RestoreOutcome)> _unpack(
    String zipPath,
    String dirPath,
    Set<String> known,
  ) => Isolate.run(() async {
    final InputFileStream input = InputFileStream(zipPath);
    try {
      final Archive archive = ZipDecoder().decodeStream(input);

      final Map<String, ArchiveFile> manifests = {};
      final Map<String, ArchiveFile> photos = {};
      for (final ArchiveFile entry in archive) {
        if (!entry.isFile) continue;

        // A zip may name an entry `../../elsewhere`. Keep the base name only,
        // so an entry can never write outside the app's own directory.
        final String name = p.basename(entry.name);
        if (name.isEmpty || name == '.' || name == '..') continue;

        if (name == _manifestName || name == _toddlerTalkManifestName) {
          manifests[name] = entry;
        } else if (_imageExtensions.contains(p.extension(name).toLowerCase())) {
          photos[name] = entry;
        }
      }

      final ArchiveFile? manifest =
          manifests[_manifestName] ?? manifests[_toddlerTalkManifestName];
      if (manifest == null) {
        throw const BackupException(
          'That file is not a Talk Builder or Toddler Talk backup.',
        );
      }

      final Set<String> seen = {...known};
      final List<TalkCard> added = [];
      int skipped = 0;
      int recordingsDropped = 0;
      for (final ({TalkCard card, bool hasRecording}) record in _decodeRecords(
        utf8.decode(manifest.readBytes() ?? const []),
      )) {
        if (!seen.add(record.card.id)) {
          skipped++;
          continue;
        }
        if (record.hasRecording) recordingsDropped++;

        final String? path = record.card.imagePath;
        if (path == null) {
          added.add(record.card);
          continue;
        }
        final String name = p.basename(path);
        added.add(record.card.copyWith(imagePath: p.join(dirPath, name)));

        final ArchiveFile? photo = photos[name];
        if (photo == null) continue;
        final OutputFileStream output = OutputFileStream(p.join(dirPath, name));
        photo.writeContent(output);
        await output.close();
      }

      return (
        added,
        RestoreOutcome(
          added: added.length,
          skipped: skipped,
          recordingsDropped: recordingsDropped,
        ),
      );
    } finally {
      await input.close();
    }
  });
}
