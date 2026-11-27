import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../models/talk_card.dart';
import '../theme.dart';
import 'card_image.dart';

/// Draws the picture of a card: its photo, else its symbol, else its emoji.
class CardMedia extends StatelessWidget {
  const CardMedia({super.key, required this.card, required this.decodeWidth});

  final TalkCard card;

  /// Passed to [CardImage] for a photo.
  final int decodeWidth;

  /// Keeps a symbol drawing clear of the card edge.
  static const EdgeInsets _symbolInset = EdgeInsets.all(4);

  @override
  Widget build(BuildContext context) {
    final String? photo = card.imagePath;
    if (photo != null) return CardImage(path: photo, decodeWidth: decodeWidth);

    final String? symbol = card.symbol;
    if (symbol != null) {
      // An asset that does not load shows an icon, so the parent sees a fault
      // and not an empty card.
      return Padding(
        padding: _symbolInset,
        child: SvgPicture.asset(
          symbol,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const _MissingSymbol(),
        ),
      );
    }

    // FittedBox, not a fixed font size: the emoji shrinks with the card when
    // the card is small or the system text scale is large.
    return Center(
      child: FittedBox(
        child: Text(card.icon ?? '', style: const TextStyle(fontSize: 40)),
      ),
    );
  }
}

class _MissingSymbol extends StatelessWidget {
  const _MissingSymbol();

  @override
  Widget build(BuildContext context) => const Center(
    child: FittedBox(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 48,
        color: AppTokens.inkMuted,
      ),
    ),
  );
}
