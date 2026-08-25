import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../data/card_repository.dart';
import '../models/talk_card.dart';
import '../services/speech_service.dart';
import '../theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/sentence_strip.dart';
import '../widgets/vocab_grid.dart';

class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key, this.repository, this.speech});

  /// Injectable so a test can drive the screen without the real plugins.
  final CardRepository? repository;
  final SpeechService? speech;

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  /// Admin mode drops back to the locked state after this long without a tap, so
  /// a parent who walks away does not leave live delete buttons on screen.
  static const Duration _adminTimeout = Duration(minutes: 2);

  late final CardRepository _repository = widget.repository ?? CardRepository();
  late final SpeechService _speech = widget.speech ?? SpeechService();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _stripController = ScrollController();

  List<TalkCard> _photoCards = [];
  List<TalkCard> _sentence = [];

  bool _isAdminMode = false;
  bool _isBusy = false;
  Timer? _adminTimer;

  @override
  void initState() {
    super.initState();
    _speech.addListener(_onSpeechChanged);
    _speech.init();
    _loadCards();
  }

  @override
  void dispose() {
    _adminTimer?.cancel();
    _stripController.dispose();
    _speech.removeListener(_onSpeechChanged);
    // Only dispose what this screen created. An injected service is the
    // caller's to close.
    if (widget.speech == null) _speech.dispose();
    super.dispose();
  }

  void _onSpeechChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCards() async {
    final List<TalkCard> cards = await _repository.load();
    if (!mounted) return;
    setState(() => _photoCards = cards);
  }

  Future<void> _persist() => _repository.save(_photoCards);

  // --- Parent-facing messages -------------------------------------------------

  /// Reports to the parent on screen.
  ///
  /// These used to be spoken by the text-to-speech engine, which read "Backup
  /// failed" aloud to the child and left the parent with nothing to look at.
  void _notify(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), action: action));
  }

  // --- Sentence strip ---------------------------------------------------------

  void _addToSentence(TalkCard card) {
    setState(() => _sentence = [..._sentence, card]);
    _speech.speakWord(card.label);
    _scrollStripToEnd();
  }

  void _scrollStripToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_stripController.hasClients) return;
      _stripController.animateTo(
        _stripController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _speakSentence() =>
      _speech.speakSentence(_sentence.map((c) => c.label).toList());

  void _backspace() {
    if (_sentence.isEmpty) return;
    setState(() => _sentence = _sentence.sublist(0, _sentence.length - 1));
  }

  /// Clears the strip, and offers the sentence back.
  ///
  /// Clear used to be irreversible, which punished the mis-tap it was there to
  /// recover from.
  void _clearSentence() {
    if (_sentence.isEmpty) return;
    final List<TalkCard> previous = _sentence;
    setState(() => _sentence = []);
    _notify(
      'Sentence cleared',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          if (mounted) setState(() => _sentence = previous);
        },
      ),
    );
  }

  void _removeWord(int index) {
    setState(() => _sentence = [..._sentence]..removeAt(index));
  }

  // --- Admin mode -------------------------------------------------------------

  void _toggleAdminMode() {
    HapticFeedback.mediumImpact();
    setState(() => _isAdminMode = !_isAdminMode);
    _notify(_isAdminMode ? 'Editing unlocked' : 'Locked');
    _restartAdminTimer();
  }

  void _restartAdminTimer() {
    _adminTimer?.cancel();
    if (!_isAdminMode) return;
    _adminTimer = Timer(_adminTimeout, () {
      if (!mounted || !_isAdminMode) return;
      setState(() => _isAdminMode = false);
      _notify('Locked again after a pause');
    });
  }

  // --- Card editing -----------------------------------------------------------

  Future<void> _addCard() async {
    _restartAdminTimer();

    final ImageSource? source = await pickPhotoSource(context);
    if (source == null || !mounted) return;

    final XFile? photo = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;

    // Ask for the label before writing anything. The old order saved the photo
    // first, so cancelling here left an orphan file on disk for good.
    final String? label = await askForLabel(context);
    if (label == null || !mounted) return;

    final String path = await _repository.newPhotoPath();
    await photo.saveTo(path);

    setState(() {
      _photoCards = [
        ..._photoCards,
        TalkCard(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          label: label,
          imagePath: path,
          isCustom: true,
        ),
      ];
    });
    await _persist();
  }

  Future<void> _deleteCard(TalkCard card) async {
    _restartAdminTimer();
    if (!await confirmDeleteCard(context, card.label)) return;

    if (!mounted) return;

    setState(() {
      _photoCards = _photoCards.where((c) => c.id != card.id).toList();
      // Drop it from the strip too. The strip held the same objects, so a
      // deleted card stayed on screen as a word pointing at nothing.
      _sentence = _sentence.where((c) => c.id != card.id).toList();
    });
    _notify('Deleted "${card.label}"');

    await _persist();
    await _repository.deletePhoto(card.imagePath);
  }

  Future<void> _toggleVisibility(TalkCard card) async {
    _restartAdminTimer();
    setState(() {
      _photoCards = _photoCards
          .map((c) => c.id == card.id ? c.copyWith(isVisible: !c.isVisible) : c)
          .toList();
    });
    await _persist();
  }

  Future<void> _renameCard(TalkCard card) async {
    _restartAdminTimer();
    final String? label = await askForLabel(
      context,
      initialValue: card.label,
      title: 'Rename card',
    );
    if (label == null || !mounted) return;

    setState(() {
      _photoCards = _photoCards
          .map((c) => c.id == card.id ? c.copyWith(label: label) : c)
          .toList();
      _sentence = _sentence
          .map((c) => c.id == card.id ? c.copyWith(label: label) : c)
          .toList();
    });
    await _persist();
  }

  Future<void> _moveCard(TalkCard card, int delta) async {
    _restartAdminTimer();
    final int from = _photoCards.indexWhere((c) => c.id == card.id);
    final int to = from + delta;
    if (from < 0 || to < 0 || to >= _photoCards.length) return;

    setState(() {
      final List<TalkCard> next = List.of(_photoCards);
      next.insert(to, next.removeAt(from));
      _photoCards = next;
    });
    await _persist();
  }

  // --- Backup and restore -----------------------------------------------------

  /// Runs [action] with a blocking progress overlay, and reports the result.
  ///
  /// Both operations read and write every photo. They used to run with no
  /// indicator at all, so a large library looked like a frozen app.
  Future<void> _withProgress(Future<String> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final String message = await action();
      _notify(message);
    } catch (error, stackTrace) {
      debugPrint('Card operation failed: $error\n$stackTrace');
      _notify('That did not work. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _backup() => _withProgress(() async {
    if (_photoCards.isEmpty) return 'There are no photo cards to back up yet.';

    final File zip = await _repository.writeBackup(_photoCards);
    await SharePlus.instance.share(
      ShareParams(text: 'Talk Builder backup', files: [XFile(zip.path)]),
    );
    return 'Backup ready to share.';
  });

  Future<void> _restore() => _withProgress(() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final String? path = picked?.files.single.path;
    if (path == null) return 'Import cancelled.';

    final (List<TalkCard> merged, RestoreOutcome outcome) = await _repository
        .readBackup(File(path), _photoCards);

    if (mounted) setState(() => _photoCards = merged);
    await _persist();

    if (outcome.added == 0) {
      return outcome.skipped == 0
          ? 'That file held no cards.'
          : 'Every card in that file was already here.';
    }
    final String skipped = outcome.skipped == 0
        ? ''
        : ', ${outcome.skipped} already here';
    return 'Added ${outcome.added} card${outcome.added == 1 ? '' : 's'}$skipped.';
  });

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      // LayoutBuilder, so the strip is sized from the height it actually has.
      // A constant left a short landscape viewport with nothing for the grid.
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Column(
              children: [
                SentenceStrip(
                  wellHeight: (constraints.maxHeight * 0.14).clamp(44.0, 150.0),
                  cards: _sentence,
                  speakingIndex: _speech.speakingIndex,
                  isSpeaking: _speech.isSpeakingSentence,
                  scrollController: _stripController,
                  onSpeak: _speakSentence,
                  onStop: _speech.stop,
                  onClear: _clearSentence,
                  onBackspace: _backspace,
                  onTapWord: (i) => _speech.speakWord(_sentence[i].label),
                  onRemoveWord: _removeWord,
                ),
                const Divider(),
                Expanded(
                  child: VocabGrid(
                    photoCards: _photoCards,
                    isAdminMode: _isAdminMode,
                    onTapCard: _addToSentence,
                    onAddCard: _addCard,
                    onDeleteCard: _deleteCard,
                    onToggleVisibility: _toggleVisibility,
                    onRenameCard: _renameCard,
                    onMoveCard: _moveCard,
                  ),
                ),
              ],
            ),
            if (_isBusy)
              const ModalBarrier(dismissible: false, color: AppTokens.scrim),
            if (_isBusy) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        _isAdminMode ? 'Admin mode' : 'Talk Builder',
        style: _isAdminMode
            ? const TextStyle(
                color: AppTokens.admin,
                fontWeight: FontWeight.bold,
              )
            : null,
      ),
      actions: [
        if (_isAdminMode)
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            tooltip: 'Backup and import',
            onSelected: (value) {
              if (value == 'backup') _backup();
              if (value == 'restore') _restore();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'backup', child: Text('Back up cards')),
              PopupMenuItem(
                value: 'restore',
                child: Text('Import or restore cards'),
              ),
            ],
          ),
        // Long press, not tap: a curious child finds a tap immediately.
        Semantics(
          button: true,
          label: _isAdminMode ? 'Lock editing' : 'Unlock editing',
          hint: 'Press and hold',
          child: Tooltip(
            message: _isAdminMode
                ? 'Press and hold to lock'
                : 'Press and hold to edit cards',
            child: InkWell(
              onLongPress: _toggleAdminMode,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _isAdminMode ? Icons.lock_open : Icons.lock_outline,
                  color: _isAdminMode ? AppTokens.admin : AppTokens.inkMuted,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
