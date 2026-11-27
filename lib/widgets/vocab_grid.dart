import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../models/core_words.dart';
import '../models/talk_card.dart';
import '../theme.dart';
import 'talk_card_tile.dart';

/// The core words, pinned, above a scrolling grid of the parent's cards.
///
/// The two were one flat grid before, so the core words scrolled out of reach as
/// the photo library grew. Pinning them fixes that without adding a navigation
/// step, which a child of this age does not need to learn.
class VocabGrid extends StatelessWidget {
  const VocabGrid({
    super.key,
    required this.cards,
    required this.isAdminMode,
    required this.tileExtent,
    required this.onTapCard,
    required this.onEditCard,
    required this.onReorder,
    this.cardsPlaceholder,
  });

  final List<TalkCard> cards;
  final bool isAdminMode;

  /// The target width of one of the parent's cards.
  final double tileExtent;

  /// A tap on a core word, or a child's tap on a parent's card.
  final void Function(TalkCard card) onTapCard;

  /// A parent's tap on one of their cards.
  final void Function(TalkCard card) onEditCard;

  /// A parent dragged the card at [oldIndex] in [cards] to [newIndex].
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Takes the place of the parent's cards while they load, or after the load
  /// fails. The core words stay above it and keep working.
  final Widget? cardsPlaceholder;

  @override
  Widget build(BuildContext context) {
    final List<TalkCard> visible = cards
        .where((c) => isAdminMode || c.isVisible)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final _CoreLayout core = _CoreLayout(constraints.biggest);
        return Column(
          children: [
            // A border, not a Divider: a border takes no height, so the column
            // fits at any size.
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: Divider.createBorderSide(context)),
              ),
              child: SizedBox(
                height: core.height,
                child: _CoreWords(layout: core, onTapCard: onTapCard),
              ),
            ),
            Expanded(
              child:
                  cardsPlaceholder ??
                  (visible.isEmpty
                      ? _buildEmptyState(context)
                      : _buildPhotoGrid(visible)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        isAdminMode
            ? 'No cards of your own yet.\n'
                  'Tap the + button at the top to add one.'
            : 'No photo or symbol cards yet.\n'
                  'Press and hold the lock to add some.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: AppTokens.inkMuted),
      ),
    ),
  );

  Widget _buildPhotoGrid(List<TalkCard> visible) {
    // GridView.builder, and a max-extent delegate: tiles stay about the same
    // physical size on a phone and a tablet, and only what is on screen is built.
    const EdgeInsets padding = EdgeInsets.all(12);
    final SliverGridDelegate delegate =
        SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: tileExtent,
          childAspectRatio: 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        );

    // The child gets a plain grid. A reorderable grid keeps its long-press
    // drag whatever its drag widget draws, so the child could move the cards,
    // and the move would be saved.
    if (!isAdminMode) {
      return GridView.builder(
        padding: padding,
        gridDelegate: delegate,
        itemCount: visible.length,
        itemBuilder: (context, index) => _tile(visible[index]),
      );
    }

    // In admin mode [visible] holds every card, so an index into it is an
    // index into [cards].
    return ReorderableGridView.builder(
      padding: padding,
      gridDelegate: delegate,
      itemCount: visible.length,
      // The package wraps a dragged card in a Material of
      // package:flutter/material.dart, and the card's material_ui ink does not
      // count it. This is the same wrap, from material_ui.
      dragWidgetBuilderV2: DragWidgetBuilderV2(
        builder: (index, child, screenshot) =>
            Material(elevation: AppTokens.dragElevation, child: child),
      ),
      onReorder: onReorder,
      itemBuilder: (context, index) => _tile(visible[index]),
    );
  }

  Widget _tile(TalkCard card) => TalkCardTile(
    key: ValueKey(card.id),
    card: card,
    isAdminMode: isAdminMode,
    onTap: isAdminMode ? () => onEditCard(card) : () => onTapCard(card),
  );
}

/// The place of the core words in a [VocabGrid] of a given size.
///
/// No scroll, so no core word can move off screen. The spacing shrinks with
/// the space, so the rows fit at any size.
class _CoreLayout {
  factory _CoreLayout(Size size) {
    final int count = coreWords.length;
    final int columns =
        _tileWidth(size.width, count) >= AppTokens.minTouchTarget
        ? count
        : (count / 2).ceil();
    final int rows = (count / columns).ceil();

    // A tile can be wider than it is tall. Its content scales to fit.
    final double tile = _tileWidth(
      size.width,
      columns,
    ).clamp(0.0, _maxTileHeight);
    final double spaceHeight = _padding.vertical + (rows - 1) * _gap;
    final double spaceWidth = _padding.horizontal + (columns - 1) * _gap;
    final double needed = rows * tile + spaceHeight;
    final double height = math.min(needed, size.height * _maxShare);
    final double scale = math.min(height / needed, size.width / spaceWidth);

    return _CoreLayout._(columns, height, _gap * scale, _padding * scale);
  }

  const _CoreLayout._(this.columns, this.height, this.gap, this.padding);

  static const double _gap = 12;
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );

  /// Caps a tile on a wide screen, so the photos keep their room.
  static const double _maxTileHeight = 116;

  /// Caps the core area on a short screen, so the photos keep their room.
  static const double _maxShare = 0.45;

  static double _tileWidth(double width, int columns) =>
      (width - _padding.horizontal - (columns - 1) * _gap) / columns;

  final int columns;
  final double height;
  final double gap;
  final EdgeInsets padding;
}

class _CoreWords extends StatelessWidget {
  const _CoreWords({required this.layout, required this.onTapCard});

  final _CoreLayout layout;
  final void Function(TalkCard card) onTapCard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: layout.padding,
      child: Column(
        spacing: layout.gap,
        children: [
          for (int i = 0; i < coreWords.length; i += layout.columns)
            Expanded(
              child: Row(
                spacing: layout.gap,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final TalkCard card
                      in coreWords.skip(i).take(layout.columns))
                    Expanded(
                      child: TalkCardTile(
                        card: card,
                        onTap: () => onTapCard(card),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
