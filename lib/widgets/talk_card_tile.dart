import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../models/talk_card.dart';
import '../theme.dart';
import 'card_media.dart';

/// One tile in the vocabulary grid.
///
/// Every tap gives a ripple and a haptic tick. For a child still learning that a
/// tap produces a word, that feedback is the point of the interaction, and the
/// old `GestureDetector` on a plain `Container` gave neither.
class TalkCardTile extends StatelessWidget {
  const TalkCardTile({
    super.key,
    required this.card,
    required this.onTap,
    this.decodeWidth = 320,
    this.isAdminMode = false,
  });

  final TalkCard card;
  final VoidCallback onTap;
  final int decodeWidth;

  /// True for a parent's card while a parent edits. A tap then opens the
  /// editor, so the tile says so.
  final bool isAdminMode;

  bool get _isHidden => !card.isVisible;

  bool get _isPhoto => card.imagePath != null;

  @override
  Widget build(BuildContext context) {
    final Widget tile = Semantics(
      button: true,
      label: !isAdminMode
          ? card.label
          : (_isHidden
                ? '${card.label}. Hidden from your child. Tap to edit.'
                : '${card.label}. Tap to edit.'),
      child: Material(
        color: _isPhoto ? AppTokens.surface : card.fillColor,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        elevation: 1,
        shadowColor: AppTokens.ink,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          child: ExcludeSemantics(
            child: _isPhoto ? _buildPhoto(context) : _buildOnFill(context),
          ),
        ),
      ),
    );

    if (!isAdminMode) return tile;
    // In front, because a photo and its label plate cover a border drawn
    // behind them.
    return Opacity(
      opacity: _isHidden ? 0.4 : 1,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          border: Border.all(
            color: AppTokens.admin,
            width: AppTokens.editableBorderWidth,
          ),
        ),
        child: tile,
      ),
    );
  }

  /// A symbol or an emoji on the card fill, with the label in a band below.
  Widget _buildOnFill(BuildContext context) {
    // FittedBox, not a fixed font size: the picture and the label have to
    // shrink together when the tile is small or the system text scale is large.
    // The label band is a share of the tile, so it can never outgrow its room.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double inset = (constraints.maxHeight * 0.06).clamp(0.0, 8.0);
        final double band = (constraints.maxHeight * 0.28).clamp(0.0, 44.0);

        return Padding(
          padding: EdgeInsets.all(inset),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: CardMedia(card: card, decodeWidth: decodeWidth),
              ),
              SizedBox(
                height: band,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    card.label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTokens.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhoto(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppTokens.photoBorder, width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.cardRadius - 3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double band = (constraints.maxHeight * 0.26).clamp(0.0, 34.0);

            return Column(
              children: [
                Expanded(
                  child: CardMedia(card: card, decodeWidth: decodeWidth),
                ),
                // An opaque plate, not white-over-photo. With alpha, the
                // label's contrast depended on whatever the photo was.
                SizedBox(
                  height: band,
                  width: double.infinity,
                  child: ColoredBox(
                    color: AppTokens.surface,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            card.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTokens.ink,
                                ),
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
      ),
    );
  }
}
