import '../theme.dart';

/// The voice that the app speaks in.
enum SpeechVoice {
  british('en-GB'),
  american('en-US');

  const SpeechVoice(this.language);

  /// The language tag that text-to-speech takes.
  final String language;
}

/// The choices that a parent makes for the whole app.
class BoardSettings {
  const BoardSettings({
    this.voice = SpeechVoice.british,
    this.slow = false,
    this.cardSize = CardSize.medium,
  });

  final SpeechVoice voice;

  /// Speaks more slowly, for a child who is learning a word.
  final bool slow;

  final CardSize cardSize;

  /// Reads a stored record. A missing or unknown field takes its default, so
  /// a record from another version of the app loads too.
  factory BoardSettings.fromJson(Map<String, dynamic> json) {
    const BoardSettings defaults = BoardSettings();
    final Object? slow = json['slow'];
    return BoardSettings(
      voice: SpeechVoice.values.firstWhere(
        (v) => v.language == json['voice'],
        orElse: () => defaults.voice,
      ),
      slow: slow is bool ? slow : defaults.slow,
      cardSize:
          CardSize.values.asNameMap()[json['cardSize']] ?? defaults.cardSize,
    );
  }

  Map<String, dynamic> toJson() => {
    'voice': voice.language,
    'slow': slow,
    'cardSize': cardSize.name,
  };

  BoardSettings copyWith({
    SpeechVoice? voice,
    bool? slow,
    CardSize? cardSize,
  }) => BoardSettings(
    voice: voice ?? this.voice,
    slow: slow ?? this.slow,
    cardSize: cardSize ?? this.cardSize,
  );
}
