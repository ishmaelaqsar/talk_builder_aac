import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/talk_card.dart';

/// What a restore did, so the caller can report it to the parent.
class RestoreOutcome {
  const RestoreOutcome({required this.added, required this.skipped});

  final int added;
  final int skipped;
}

/// Reads and writes the parent's cards, their photo files, and backup zips.
///
/// Holds no UI state and shows no messages. It throws on failure, and the
/// caller decides what the parent sees.
class CardRepository {
  /// The key is unchanged from the *Toddler Talk* build, so an in-place upgrade
  /// keeps the cards a parent already added.
  static const String _storageKey = 'toddler_cards';
  static const String _manifestName = 'data.json';

  Future<List<TalkCard>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_storageKey);
    if (stored == null) return [];

    final List<dynamic> raw = json.decode(stored) as List<dynamic>;
    return raw
        .map((e) => TalkCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<TalkCard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      json.encode(cards.map((c) => c.toJson()).toList()),
    );
  }

  /// Returns a fresh, unused path for a photo in the app's documents directory.
  Future<String> newPhotoPath() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, '${const Uuid().v4()}.jpg');
  }

  /// Removes a card's photo from disk. A missing file is not an error.
  Future<void> deletePhoto(String? path) async {
    if (path == null) return;
    final File file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Builds a zip of every card whose photo still exists, and returns its path.
  ///
  /// Paths inside the zip are bare filenames, so the archive stays portable
  /// across devices and across installs.
  Future<File> writeBackup(List<TalkCard> cards) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final Archive archive = Archive();
    final List<Map<String, dynamic>> manifest = [];

    for (final TalkCard card in cards) {
      final String? path = card.imagePath;
      if (path == null) continue;

      final File image = File(path);
      if (!await image.exists()) continue;

      final List<int> bytes = await image.readAsBytes();
      final String filename = p.basename(path);
      archive.addFile(ArchiveFile(filename, bytes.length, bytes));
      manifest.add(card.copyWith(imagePath: filename).toJson());
    }

    // Size must be the byte count, not the character count. They differ as soon
    // as a label carries an accent or an emoji, and a wrong size truncates.
    final List<int> manifestBytes = utf8.encode(json.encode(manifest));
    archive.addFile(
      ArchiveFile(_manifestName, manifestBytes.length, manifestBytes),
    );

    final File zip = File(p.join(dir.path, 'talk_builder_backup.zip'));
    await zip.writeAsBytes(ZipEncoder().encode(archive));
    return zip;
  }

  /// Unpacks a backup zip and merges its cards into [existing].
  ///
  /// Merges by id, so importing the same backup twice adds nothing. Returns the
  /// merged list together with the counts, and never mutates [existing].
  Future<(List<TalkCard>, RestoreOutcome)> readBackup(
    File zip,
    List<TalkCard> existing,
  ) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final Archive archive = ZipDecoder().decodeBytes(await zip.readAsBytes());

    List<TalkCard> imported = [];

    for (final ArchiveFile file in archive) {
      if (!file.isFile) continue;
      final List<int> data = file.content as List<int>;

      if (p.basename(file.name) == _manifestName) {
        final List<dynamic> raw = json.decode(utf8.decode(data));
        imported = raw
            .map((e) => TalkCard.fromJson(e as Map<String, dynamic>))
            .toList();
        continue;
      }

      // Flatten the archive path, so a crafted entry cannot escape the app's
      // own directory.
      final File out = File(p.join(dir.path, p.basename(file.name)));
      if (!await out.exists()) {
        await out.create(recursive: true);
        await out.writeAsBytes(data);
      }
    }

    final Set<String> known = existing.map((c) => c.id).toSet();
    final List<TalkCard> merged = List.of(existing);
    int added = 0;
    int skipped = 0;

    for (final TalkCard card in imported) {
      if (known.contains(card.id)) {
        skipped++;
        continue;
      }
      final String? name = card.imagePath;
      merged.add(
        name == null ? card : card.copyWith(imagePath: p.join(dir.path, name)),
      );
      known.add(card.id);
      added++;
    }

    return (merged, RestoreOutcome(added: added, skipped: skipped));
  }
}
