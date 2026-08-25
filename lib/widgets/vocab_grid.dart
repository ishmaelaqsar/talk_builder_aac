import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/core_words.dart';
import '../models/talk_card.dart';
import '../theme.dart';
import 'talk_card_tile.dart';

/// The core words, pinned, above a scrolling grid of the parent's photos.
///
/// The two were one flat grid before, so the core words scrolled out of reach as
/// the photo library grew. Pinning them fixes that without adding a navigation
/// step, which a child of this age does not need to learn.
class VocabGrid extends StatelessWidget {
  const VocabGrid({
    super.key,
    required this.photoCards,
    required this.isAdminMode,
    required this.onTapCard,
    required this.onAddCard,
    required this.onDeleteCard,
    required this.onToggleVisibility,
    required this.onRenameCard,
    required this.onMoveCard,
  });

  final List<TalkCard> photoCards;
  final bool isAdminMode;
  final void Function(TalkCard card) onTapCard;
  final VoidCallback onAddCard;
  final void Function(TalkCard card) onDeleteCard;
  final void Function(TalkCard card) onToggleVisibility;
  final void Function(TalkCard card) onRenameCard;
  final void Function(TalkCard card, int delta) onMoveCard;

  @override
  Widget build(BuildContext context) {
    final List<TalkCard> visible = photoCards
        .where((c) => isAdminMode || c.isVisible)
        .toList();

    // Every child is flexible, so a short viewport shrinks the core row instead
    // of overflowing it. The cap keeps the row from ballooning on a tablet.
    return Column(
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 132),
            child: _CoreWordRow(onTapCard: onTapCard),
          ),
        ),
        const Divider(),
        Flexible(
          flex: 4,
          child: visible.isEmpty && !isAdminMode
              ? _buildEmptyState(context)
              : _buildPhotoGrid(visible),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'No photo cards yet.\n'
        'Press and hold the lock to add some.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppTokens.inkMuted),
      ),
    ),
  );

  Widget _buildPhotoGrid(List<TalkCard> visible) {
    final int count = visible.length + (isAdminMode ? 1 : 0);

    // GridView.builder, and a max-extent delegate: tiles stay about the same
    // physical size on a phone and a tablet, and only what is on screen is built.
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: AppTokens.tileExtent,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        if (index == visible.length) return _AddCardTile(onTap: onAddCard);

        final TalkCard card = visible[index];
        return TalkCardTile(
          card: card,
          isAdminMode: isAdminMode,
          onTap: () => onTapCard(card),
          onDelete: () => onDeleteCard(card),
          onToggleVisibility: () => onToggleVisibility(card),
          onRename: () => onRenameCard(card),
          onMoveLeft: index == 0 ? null : () => onMoveCard(card, -1),
          onMoveRight: index == visible.length - 1
              ? null
              : () => onMoveCard(card, 1),
        );
      },
    );
  }
}

/// The eight core words, always on screen, scrolling horizontally only if the
/// viewport is too narrow to hold them all.
class _CoreWordRow extends StatelessWidget {
  const _CoreWordRow({required this.onTapCard});

  final void Function(TalkCard card) onTapCard;

  @override
  Widget build(BuildContext context) {
    // AspectRatio, not a fixed size: each tile takes its width from the height
    // the row was given, so the row cannot outgrow its space.
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: coreWords.length,
      separatorBuilder: (context, index) => const SizedBox(width: 12),
      itemBuilder: (context, index) => AspectRatio(
        aspectRatio: 1,
        child: TalkCardTile(
          card: coreWords[index],
          onTap: () => onTapCard(coreWords[index]),
        ),
      ),
    );
  }
}

class _AddCardTile extends StatelessWidget {
  const _AddCardTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add a photo card',
      child: Material(
        color: AppTokens.well,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.cardRadius),
              border: Border.all(color: AppTokens.outline, width: 2),
            ),
            child: const Center(
              child: Icon(
                Icons.add_a_photo,
                size: 40,
                color: AppTokens.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
