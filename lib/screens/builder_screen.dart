import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../data/card_repository.dart';
import '../models/board_settings.dart';
import '../models/talk_card.dart';
import '../services/speech_service.dart';
import '../theme.dart';
import '../widgets/card_editor_dialog.dart';
import '../widgets/dialogs.dart';
import '../widgets/parent_gate.dart';
import '../widgets/parent_lock.dart';
import '../widgets/sentence_strip.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/symbol_picker.dart';
import '../widgets/vocab_grid.dart';

class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key, this.repository, this.speech});

  /// Injectable so a test can drive the screen without the real plugins.
  final CardRepository? repository;
  final SpeechService? speech;

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen>
    with WidgetsBindingObserver {
  late final CardRepository _repository = widget.repository ?? CardRepository();
  late final SpeechService _speech = widget.speech ?? SpeechService();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _stripController = ScrollController();

  List<TalkCard> _cards = [];
  BoardSettings _settings = const BoardSettings();
  final ValueNotifier<List<TalkCard>> _sentence = ValueNotifier(const []);

  // Only the strip listens to the sentence and the speech. A card tap and a
  // speech tick then leave the grid, with every photo in it, as it is.
  late final Listenable _stripState = Listenable.merge([_sentence, _speech]);

  /// Set when a sentence plays to its end. The next card tap starts a new
  /// sentence, so the child does not have to clear the old one first.
  bool _startNewSentence = false;

  /// The spoken word that the strip last scrolled to.
  int? _followedIndex;

  /// False until the stored cards arrive, so the empty-state text does not
  /// show before them.
  bool _loaded = false;

  /// True when the stored cards could not be read. Nothing saves the cards
  /// while this holds, so a retry reads the stored text as it was.
  bool _loadFailed = false;

  bool _isAdminMode = false;
  bool _isBusy = false;
  Timer? _adminTimer;

  /// Counts the flows that are open: the pickers, the camera, the share sheet,
  /// and the dialogs. A picker or the camera sends the app to the background,
  /// and the background otherwise locks admin mode, which would drop the
  /// parent out of the flow.
  int _openFlows = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applySystemUi();
    _speech.addListener(_onSpeechChanged);
    _speech.onSentenceCompleted = _onSentenceCompleted;
    _loadSettings();
    _loadCards();
  }

  @override
  void dispose() {
    _adminTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _stripController.dispose();
    _speech.removeListener(_onSpeechChanged);
    _speech.onSentenceCompleted = null;
    // Only dispose what this screen created. An injected service is the
    // caller's to close.
    if (widget.speech == null) _speech.dispose();
    _sentence.dispose();
    super.dispose();
  }

  void _onSpeechChanged() {
    final int? index = _speech.speakingIndex;
    if (index == _followedIndex) return;
    _followedIndex = index;
    if (index != null) _followSpokenWord(index);
  }

  void _onSentenceCompleted() => _startNewSentence = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app locks editing, so a tablet handed to the child comes
    // back safe. An open flow keeps admin mode, because a picker, the camera,
    // and the share sheet also send the app to the background.
    final bool leaving =
        state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (leaving && _isAdminMode && _openFlows == 0) _lock();
    // Android can show the system bars again after a resume.
    if (state == AppLifecycleState.resumed && !_isAdminMode) _applySystemUi();
  }

  /// Runs apart from [_loadCards], so a slow voice engine does not hold back
  /// the cards.
  Future<void> _loadSettings() async {
    final BoardSettings settings = await _repository.loadSettings();
    if (!mounted) return;
    _speech.apply(settings);
    setState(() => _settings = settings);
  }

  Future<void> _loadCards() async {
    final List<TalkCard> cards;
    try {
      cards = await _repository.load();
    } on Object catch (error) {
      debugPrint('Load failed: $error');
      if (mounted) setState(() => _loadFailed = true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _loaded = true;
    });
  }

  void _retryLoad() {
    setState(() => _loadFailed = false);
    _loadCards();
  }

  Future<void> _startAgain() async {
    await _repository.startAgain();
    if (mounted) _retryLoad();
  }

  Future<void> _persist() => _repository.save(_cards);

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
    _sentence.value = _startNewSentence ? [card] : [..._sentence.value, card];
    _startNewSentence = false;
    _speech.speakWord(card.label);
    _scrollStripToEnd();
  }

  /// Applies an edit by the child. The words under a sentence that plays
  /// change, so the sentence stops. The next card joins this sentence.
  void _editSentence(List<TalkCard> words) {
    if (_speech.isSpeakingSentence) _speech.stop();
    _startNewSentence = false;
    _sentence.value = words;
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

  /// Keeps the spoken word in view, so the child sees the word they hear.
  void _followSpokenWord(int index) {
    if (!_stripController.hasClients) return;
    final ScrollPosition position = _stripController.position;
    _stripController.animateTo(
      SentenceStrip.centreOffset(
        index,
        position.viewportDimension,
      ).clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _speakSentence() =>
      _speech.speakSentence(_sentence.value.map((c) => c.label).toList());

  void _backspace() {
    final List<TalkCard> words = _sentence.value;
    if (words.isEmpty) return;
    _editSentence(words.sublist(0, words.length - 1));
  }

  /// Clears the strip, and offers the sentence back.
  ///
  /// Clear used to be irreversible, which punished the mis-tap it was there to
  /// recover from.
  void _clearSentence() {
    final List<TalkCard> previous = _sentence.value;
    if (previous.isEmpty) return;
    _editSentence(const []);
    _notify(
      'Sentence cleared',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          if (mounted) _editSentence(previous);
        },
      ),
    );
  }

  void _removeWord(int index) =>
      _editSentence([..._sentence.value]..removeAt(index));

  // --- Admin mode -------------------------------------------------------------

  Future<void> _unlock() async {
    if (!await showParentGate(context) || !mounted) return;
    setState(() => _isAdminMode = true);
    _applySystemUi();
    _notify(
      'Editing unlocked. Tap a card to edit it. Hold and drag to move it.',
    );
    _restartAdminTimer();
  }

  /// Locks editing, and shows [message] to the parent when one is given.
  void _lock({String? message}) {
    _adminTimer?.cancel();
    _adminTimer = null;
    if (!_isAdminMode) return;
    setState(() => _isAdminMode = false);
    _applySystemUi();
    if (message != null) _notify(message);
  }

  /// Hides the system bars from the child, so a swipe from the edge does not
  /// take them out of the app. A parent gets the bars back.
  void _applySystemUi() => SystemChrome.setEnabledSystemUIMode(
    _isAdminMode ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
  );

  /// No timer runs while a flow is open, because the parent is busy in it.
  /// The outermost flow starts the timer when it ends.
  void _restartAdminTimer() {
    _adminTimer?.cancel();
    if (!_isAdminMode || _openFlows > 0) return;
    _adminTimer = Timer(AppTokens.adminTimeout, () {
      if (!mounted || !_isAdminMode) return;
      _lock(message: 'Locked again after a pause');
    });
  }

  /// Runs [action] with the auto-lock paused. The flow is a route of its own,
  /// or it sends the app to the background, so the screen sees none of the
  /// parent's touches until it ends.
  Future<T> _inFlow<T>(Future<T> Function() action) async {
    _openFlows++;
    _adminTimer?.cancel();
    try {
      return await action();
    } finally {
      _openFlows--;
      if (mounted) _restartAdminTimer();
    }
  }

  // --- Card editing -----------------------------------------------------------

  /// Asks where the picture comes from, and lets the parent pick it.
  Future<CardPicture?> _choosePicture() => _inFlow(() async {
    final CardSource? source = await pickCardSource(context);
    if (source == null || !mounted) return null;

    switch (source) {
      case CardSource.symbols:
        final SymbolChoice? symbol = await showSymbolPicker(context);
        return symbol == null
            ? null
            : CardPicture.symbol(symbol.assetPath, label: symbol.label);
      case CardSource.camera:
      case CardSource.gallery:
        final XFile? photo = await _picker.pickImage(
          source: source == CardSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        return photo == null ? null : CardPicture.photo(photo.path);
    }
  });

  Future<void> _addCard() => _inFlow(() async {
    final CardPicture? picture = await _choosePicture();
    if (picture == null || !mounted) return;

    final CardEditResult? result = await showCardEditor(
      context,
      card: TalkCard(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        label: picture.suggestedLabel ?? '',
        imagePath: picture.photo,
        symbol: picture.symbol,
        isCustom: true,
      ),
      isNew: true,
      onChangePicture: _choosePicture,
    );
    if (result is! CardSaved || !mounted) return;

    final TalkCard card = await _keepPhoto(result.card, replacing: null);
    if (!mounted) return;
    setState(() => _cards = [..._cards, card]);
    await _persist();
  });

  Future<void> _editCard(TalkCard card) => _inFlow(() async {
    final CardEditResult? result = await showCardEditor(
      context,
      card: card,
      isNew: false,
      onChangePicture: _choosePicture,
    );
    if (!mounted) return;

    switch (result) {
      case null:
        return;
      case CardDeleted():
        await _deleteCard(card);
      case CardSaved(card: final TalkCard edited):
        await _saveEdit(card, edited);
    }
  });

  /// Copies a photo that the parent picked in the editor into the app's own
  /// directory. The editor writes no file, so a cancel leaves nothing behind.
  Future<TalkCard> _keepPhoto(
    TalkCard card, {
    required TalkCard? replacing,
  }) async {
    final String? picked = card.imagePath;
    if (picked == null || picked == replacing?.imagePath) return card;
    return card.withPicture(photo: await _repository.importPhoto(picked));
  }

  Future<void> _saveEdit(TalkCard original, TalkCard edited) async {
    final TalkCard card = await _keepPhoto(edited, replacing: original);
    if (!mounted) return;

    setState(() {
      _cards = [for (final TalkCard c in _cards) c.id == card.id ? card : c];
    });
    _sentence.value = [
      for (final TalkCard c in _sentence.value) c.id == card.id ? card : c,
    ];
    await _persist();

    // After the save, so the stored card never points at a deleted file.
    final String? replaced = original.imagePath;
    if (replaced != card.imagePath) await _repository.deletePhoto(replaced);
  }

  Future<void> _deleteCard(TalkCard card) async {
    setState(() => _cards = _cards.where((c) => c.id != card.id).toList());
    // Drop it from the strip too. The strip held the same objects, so a
    // deleted card stayed on screen as a word pointing at nothing.
    _sentence.value = _sentence.value.where((c) => c.id != card.id).toList();
    _notify('Deleted "${card.label}"');

    await _persist();
    await _repository.deletePhoto(card.imagePath);
  }

  Future<void> _reorderCards(int oldIndex, int newIndex) async {
    setState(() {
      final List<TalkCard> next = List.of(_cards);
      next.insert(newIndex, next.removeAt(oldIndex));
      _cards = next;
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
    } on BackupException catch (error) {
      _notify(error.message);
    } catch (error, stackTrace) {
      debugPrint('Card operation failed: $error\n$stackTrace');
      _notify('That did not work. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _backup() => _inFlow(
    () => _withProgress(() async {
      if (_cards.isEmpty) {
        return 'There are no cards of your own to back up yet.';
      }

      final File zip = await _repository.writeBackup(_cards);
      await SharePlus.instance.share(
        ShareParams(text: 'Talk Builder backup', files: [XFile(zip.path)]),
      );
      return 'Backup ready to share.';
    }),
  );

  Future<void> _restore() => _inFlow(
    () => _withProgress(() async {
      final FilePickerResult? picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      final String? path = picked?.files.single.path;
      if (path == null) return 'Import cancelled.';

      final (List<TalkCard> merged, RestoreOutcome outcome) = await _repository
          .readBackup(File(path), _cards);

      if (mounted) setState(() => _cards = merged);
      await _persist();

      if (outcome.added == 0) {
        return outcome.skipped == 0
            ? 'That file held no cards.'
            : 'Every card in that file was already here.';
      }
      final String skipped = outcome.skipped == 0
          ? ''
          : ', ${outcome.skipped} already here';
      final String added =
          'Added ${outcome.added} card${outcome.added == 1 ? '' : 's'}$skipped.';
      final int recordings = outcome.recordingsDropped;
      if (recordings == 0) return added;
      return '$added Left out $recordings recording${recordings == 1 ? '' : 's'}. '
          'Talk Builder speaks every card with the device voice.';
    }),
  );

  // --- Settings ---------------------------------------------------------------

  Future<void> _openSettings() => _inFlow(
    () => showSettingsSheet(
      context,
      settings: _settings,
      onChanged: _changeSettings,
      onHear: _speech.speakWord,
    ),
  );

  void _changeSettings(BoardSettings settings) {
    setState(() => _settings = settings);
    _speech.apply(settings);
    _repository.saveSettings(settings);
  }

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // A child's Back press does nothing. A dialog or a sheet is a route of its
    // own, so Back closes it as usual.
    return PopScope(
      canPop: _isAdminMode,
      child: Listener(
        // Any touch counts as parent activity, so the auto-lock fires only
        // after real inactivity.
        onPointerDown: (_) {
          if (_isAdminMode) _restartAdminTimer();
        },
        child: _buildScaffold(),
      ),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      appBar: _buildAppBar(),
      // LayoutBuilder, so the strip is sized from the height it actually has.
      // A constant left a short landscape viewport with nothing for the grid.
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Column(
              children: [
                ListenableBuilder(
                  listenable: _stripState,
                  builder: (context, _) => SentenceStrip(
                    wellHeight: (constraints.maxHeight * 0.14).clamp(
                      44.0,
                      150.0,
                    ),
                    cards: _sentence.value,
                    speakingIndex: _speech.speakingIndex,
                    isSpeaking: _speech.isSpeakingSentence,
                    scrollController: _stripController,
                    onSpeak: _speakSentence,
                    onStop: _speech.stop,
                    onClear: _clearSentence,
                    onBackspace: _backspace,
                    onTapWord: (i) =>
                        _speech.speakWord(_sentence.value[i].label),
                    onRemoveWord: _removeWord,
                  ),
                ),
                const Divider(),
                Expanded(
                  child: VocabGrid(
                    cards: _cards,
                    isAdminMode: _isAdminMode,
                    tileExtent: _settings.cardSize.extent,
                    onTapCard: _addToSentence,
                    onEditCard: _editCard,
                    onReorder: _reorderCards,
                    cardsPlaceholder: _loadFailed
                        ? _buildLoadError()
                        : (_loaded ? null : const SizedBox.shrink()),
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
        if (_isAdminMode && !_loadFailed)
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add a card',
            onPressed: _addCard,
          ),
        if (_isAdminMode && !_loadFailed)
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings and backup',
            onSelected: (value) {
              if (value == 'settings') _openSettings();
              if (value == 'backup') _backup();
              if (value == 'restore') _restore();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'backup', child: Text('Back up cards')),
              PopupMenuItem(
                value: 'restore',
                child: Text('Import or restore cards'),
              ),
            ],
          ),
        ParentLock(
          unlocked: _isAdminMode,
          onUnlock: _unlock,
          onLock: () => _lock(message: 'Locked'),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// A child gets no Start again, because it puts an empty grid in place of
  /// the cards.
  Widget _buildLoadError() => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'The cards could not be loaded',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _isAdminMode
                ? 'Try again first. Start again begins with no cards of your '
                      'own, and keeps a copy of the old cards on this device.'
                : 'Ask a grown-up to help.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _retryLoad,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
          if (_isAdminMode) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _startAgain,
              child: const Text('Start again'),
            ),
          ],
        ],
      ),
    ),
  );
}
