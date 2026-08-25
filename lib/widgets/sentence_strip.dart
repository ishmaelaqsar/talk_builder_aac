import 'package:flutter/material.dart';

import '../models/talk_card.dart';
import '../theme.dart';
import 'mini_card.dart';

/// The sentence under construction, plus the clear, speak, and backspace row.
///
/// The height comes from the viewport instead of a constant, and the action row
/// wraps. The old fixed 140px box left each mini card about 22px of image, and
/// overflowed outright once the system text scale rose.
class SentenceStrip extends StatelessWidget {
  const SentenceStrip({
    super.key,
    required this.wellHeight,
    required this.cards,
    required this.speakingIndex,
    required this.isSpeaking,
    required this.scrollController,
    required this.onSpeak,
    required this.onStop,
    required this.onClear,
    required this.onBackspace,
    required this.onTapWord,
    required this.onRemoveWord,
  });

  /// Height of the well the words sit in, set by the caller from the height the
  /// screen actually has.
  final double wellHeight;

  final List<TalkCard> cards;
  final int? speakingIndex;
  final bool isSpeaking;
  final ScrollController scrollController;
  final VoidCallback onSpeak;
  final VoidCallback onStop;
  final VoidCallback onClear;
  final VoidCallback onBackspace;
  final void Function(int index) onTapWord;
  final void Function(int index) onRemoveWord;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: wellHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTokens.well,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTokens.outline),
                ),
                child: cards.isEmpty ? _buildHint(context) : _buildWords(),
              ),
            ),
            const SizedBox(height: 8),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHint(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        'Tap words to build a sentence',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTokens.inkMuted),
      ),
    ),
  );

  Widget _buildWords() => ListView.separated(
    controller: scrollController,
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.all(8),
    itemCount: cards.length,
    separatorBuilder: (context, index) => const SizedBox(width: 8),
    itemBuilder: (context, index) => MiniCard(
      card: cards[index],
      isSpeaking: speakingIndex == index,
      onTap: () => onTapWord(index),
      onRemove: () => onRemoveWord(index),
    ),
  );

  Widget _buildActions(BuildContext context) {
    final bool hasWords = cards.isNotEmpty;

    // Wrap, not Row: at a large text scale the three controls no longer fit on
    // one line, and a Row would overflow instead of reflowing.
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton.icon(
          onPressed: hasWords ? onClear : null,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Clear'),
          style: TextButton.styleFrom(
            foregroundColor: AppTokens.danger,
            minimumSize: const Size(0, AppTokens.minTouchTarget),
          ),
        ),
        _buildSpeakButton(context, hasWords),
        IconButton(
          onPressed: hasWords ? onBackspace : null,
          icon: const Icon(Icons.backspace_outlined),
          iconSize: 28,
          tooltip: 'Remove the last word',
          color: AppTokens.inkMuted,
          constraints: const BoxConstraints(
            minWidth: AppTokens.minTouchTarget,
            minHeight: AppTokens.minTouchTarget,
          ),
        ),
      ],
    );
  }

  /// The speak control doubles as a stop control while an utterance is running,
  /// so there is always a way to interrupt a long sentence.
  Widget _buildSpeakButton(BuildContext context, bool hasWords) {
    return ElevatedButton.icon(
      onPressed: isSpeaking ? onStop : (hasWords ? onSpeak : null),
      icon: Icon(isSpeaking ? Icons.stop : Icons.play_arrow, size: 28),
      label: Text(
        isSpeaking ? 'STOP' : 'SPEAK',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTokens.speak,
        foregroundColor: AppTokens.onSpeak,
        disabledBackgroundColor: AppTokens.outline,
        disabledForegroundColor: AppTokens.inkMuted,
        textStyle: Theme.of(context).textTheme.titleMedium,
        minimumSize: const Size(140, AppTokens.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    );
  }
}
