import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/board_settings.dart';

/// Speaks the child's words, and reports which word is being spoken.
///
/// Two things the raw plugin does not give us:
///
///  * A tap always cancels the previous utterance. Without that, a child tapping
///    fast queues a pile-up and hears a garble.
///  * [speakingIndex] tracks the word inside a spoken sentence, so the sentence
///    strip can highlight along. It is driven by the engine's own progress
///    callback, which reports character offsets into the text.
class SpeechService extends ChangeNotifier {
  SpeechService({FlutterTts? engine}) : _tts = engine ?? FlutterTts() {
    // No cancel handler. The Android plugin answers stop at once, and sends
    // the cancel of the cut utterance after that. By then the next utterance
    // has set its state, and the cancel would clear it. [stop] clears the
    // state itself.
    _tts.setCompletionHandler(_onComplete);
    _tts.setErrorHandler((_) => _onDone());
    _tts.setProgressHandler((text, start, end, word) {
      _setSpeakingIndex(_indexForOffset(start));
    });
  }

  /// Slow enough for a 2-to-5-year-old to follow, without sounding unnatural.
  static const double normalRate = 0.45;

  /// Slower than normal, for a child who is learning a word.
  static const double slowRate = 0.35;

  final FlutterTts _tts;

  /// The last call to [apply]. Every utterance waits for it, so a fast first
  /// tap does not speak at the engine's default rate and language.
  Future<void>? _applied;

  bool _isSpeakingSentence = false;
  int? _speakingIndex;

  /// Character offset at which each word of the current sentence starts.
  List<int> _wordStarts = const [];

  /// True only while a whole sentence is playing.
  ///
  /// Deliberately not set for a single word: the speak control turns into a stop
  /// control from this flag, and a child tapping cards would otherwise see the
  /// button flicker on every tap.
  bool get isSpeakingSentence => _isSpeakingSentence;

  /// Index into the sentence being spoken, or null when idle or on a single word.
  int? get speakingIndex => _speakingIndex;

  /// Called when a whole sentence plays to its end. A cancel, a stop, and an
  /// error do not call it.
  void Function()? onSentenceCompleted;

  /// Sets the voice and the speed.
  Future<void> apply(BoardSettings settings) => _applied = _configure(settings);

  Future<void> _configure(BoardSettings settings) async {
    // Logged, not thrown: a failed call here must not stop every later word.
    try {
      await _tts.setLanguage(settings.voice.language);
      await _tts.setSpeechRate(settings.slow ? slowRate : normalRate);
    } on Object catch (error) {
      debugPrint('Speech settings failed: $error');
    }
  }

  /// Speaks one word, with no highlight tracking.
  Future<void> speakWord(String label) =>
      _speak(label, const [], isSentence: false);

  /// Speaks [labels] joined by spaces, and highlights each word in turn.
  Future<void> speakSentence(List<String> labels) {
    final List<int> starts = [];
    int offset = 0;
    for (final String label in labels) {
      starts.add(offset);
      offset += label.length + 1; // The joining space.
    }
    return _speak(labels.join(' '), starts, isSentence: true);
  }

  /// Stops any utterance in progress.
  Future<void> stop() async {
    await _tts.stop();
    _onDone();
  }

  Future<void> _speak(
    String text,
    List<int> wordStarts, {
    required bool isSentence,
  }) async {
    if (text.trim().isEmpty) return;
    // The defaults stand in when the stored settings have not arrived yet.
    await (_applied ?? apply(const BoardSettings()));

    // Cancel first. Otherwise fast taps overlap and nothing is intelligible.
    await _tts.stop();

    _wordStarts = wordStarts;
    _speakingIndex = wordStarts.isEmpty ? null : 0;
    _isSpeakingSentence = isSentence;
    notifyListeners();

    await _tts.speak(text);
  }

  /// Maps a character offset from the engine back to a word index.
  int? _indexForOffset(int offset) {
    if (_wordStarts.isEmpty) return null;
    int index = 0;
    for (int i = 0; i < _wordStarts.length; i++) {
      if (_wordStarts[i] <= offset) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  void _setSpeakingIndex(int? index) {
    if (_speakingIndex == index) return;
    _speakingIndex = index;
    notifyListeners();
  }

  void _onComplete() {
    final bool wasSentence = _isSpeakingSentence;
    _onDone();
    if (wasSentence) onSentenceCompleted?.call();
  }

  void _onDone() {
    if (!_isSpeakingSentence && _speakingIndex == null) return;
    _isSpeakingSentence = false;
    _speakingIndex = null;
    _wordStarts = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
