import 'package:material_ui/material_ui.dart';

import '../models/talk_card.dart';
import '../theme.dart';
import 'card_media.dart';

/// One word inside the sentence strip.
///
/// Tapping re-speaks the word; a long press removes it. Before, the strip was
/// inert and backspace could only reach the last word.
class MiniCard extends StatelessWidget {
  const MiniCard({
    super.key,
    required this.card,
    required this.isSpeaking,
    required this.onTap,
    required this.onRemove,
  });

  /// Fixed, so the strip can compute where each word sits.
  static const double width = 88;

  final TalkCard card;
  final bool isSpeaking;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // The label lives on this node, and the actions come from the InkWell below.
    // `excludeSemantics` here would have taken the actions with it, leaving a
    // screen reader a button it could announce but not activate.
    return Semantics(
      button: true,
      label: '${card.label}. In the sentence.',
      hint: 'Double tap to hear it. Long press to remove it.',
      child: Material(
        color: card.imagePath != null ? AppTokens.surface : card.fillColor,
        borderRadius: BorderRadius.circular(AppTokens.miniCardRadius),
        child: InkWell(
          onTap: onTap,
          onLongPress: onRemove,
          borderRadius: BorderRadius.circular(AppTokens.miniCardRadius),
          child: ExcludeSemantics(child: _buildContent(context)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.miniCardRadius),
        border: Border.all(
          color: isSpeaking ? AppTokens.speaking : AppTokens.outline,
          width: isSpeaking ? 3 : 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double band = (constraints.maxHeight * 0.34).clamp(0.0, 26.0);

          return Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTokens.miniCardRadius),
                  ),
                  child: CardMedia(card: card, decodeWidth: 176),
                ),
              ),
              SizedBox(
                height: band,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        card.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTokens.ink,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
