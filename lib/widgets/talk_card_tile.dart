import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/talk_card.dart';
import '../theme.dart';
import 'card_image.dart';

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
    this.onDelete,
    this.onToggleVisibility,
    this.onRename,
    this.onMoveLeft,
    this.onMoveRight,
  });

  final TalkCard card;
  final VoidCallback onTap;
  final int decodeWidth;
  final bool isAdminMode;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onRename;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;

  bool get _isHidden => !card.isVisible;

  @override
  Widget build(BuildContext context) {
    final Widget tile = Semantics(
      button: true,
      label: card.label,
      hint: _isHidden ? 'Hidden from the grid' : null,
      child: Material(
        color: card.isCustom ? AppTokens.surface : card.fillColor,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        elevation: 1,
        shadowColor: AppTokens.ink,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onLongPress: isAdminMode ? onRename : null,
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          child: ExcludeSemantics(
            child: card.isCustom
                ? _buildPhoto(context)
                : _buildCoreWord(context),
          ),
        ),
      ),
    );

    if (!isAdminMode) return tile;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Opacity(opacity: _isHidden ? 0.4 : 1, child: tile),
        ),
        ..._buildAdminControls(),
      ],
    );
  }

  Widget _buildCoreWord(BuildContext context) {
    // FittedBox, not a fixed font size: the emoji and the label have to shrink
    // together when the tile is small or the system text scale is large. The
    // label band is a share of the tile, so it can never outgrow its room.
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
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                    card.icon ?? '',
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
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
    final String? path = card.imagePath;

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
                  child: path == null
                      ? const ColoredBox(color: AppTokens.well)
                      : CardImage(path: path, decodeWidth: decodeWidth),
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

  /// Admin controls sized to the 48dp minimum.
  ///
  /// They were 24px circles sitting on the card's own tap area, so a mis-tap
  /// deleted a photo the parent could not get back.
  List<Widget> _buildAdminControls() {
    return [
      if (onToggleVisibility != null)
        Positioned(
          left: -4,
          top: -4,
          child: _AdminButton(
            icon: card.isVisible ? Icons.visibility : Icons.visibility_off,
            color: card.isVisible ? AppTokens.visible : AppTokens.hidden,
            tooltip: card.isVisible
                ? 'Hide "${card.label}"'
                : 'Show "${card.label}"',
            onPressed: onToggleVisibility!,
          ),
        ),
      if (onDelete != null)
        Positioned(
          right: -4,
          top: -4,
          child: _AdminButton(
            icon: Icons.delete_outline,
            color: AppTokens.danger,
            tooltip: 'Delete "${card.label}"',
            onPressed: onDelete!,
          ),
        ),
      if (onMoveLeft != null || onMoveRight != null)
        Positioned(
          left: 0,
          right: 0,
          bottom: -4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AdminButton(
                icon: Icons.chevron_left,
                color: AppTokens.hidden,
                tooltip: 'Move "${card.label}" earlier',
                onPressed: onMoveLeft,
              ),
              const SizedBox(width: 4),
              _AdminButton(
                icon: Icons.chevron_right,
                color: AppTokens.hidden,
                tooltip: 'Move "${card.label}" later',
                onPressed: onMoveRight,
              ),
            ],
          ),
        ),
    ];
  }
}

class _AdminButton extends StatelessWidget {
  const _AdminButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox.square(
          dimension: AppTokens.minTouchTarget,
          child: Material(
            color: onPressed == null ? AppTokens.outline : color,
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: AppTokens.ink,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Icon(icon, size: 22, color: AppTokens.onSpeak),
            ),
          ),
        ),
      ),
    );
  }
}
