import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// A card's photo, with a placeholder for the case where the file has gone.
///
/// A photo can vanish under the app: a restore from a partial zip, cleared app
/// data, or a manual file delete. A bare `Image.file` then renders an exception
/// box with no text, which leaves a card the parent cannot identify or remove.
class CardImage extends StatelessWidget {
  const CardImage({
    super.key,
    required this.path,
    required this.decodeWidth,
    this.fit = BoxFit.cover,
  });

  final String path;

  /// Target width in pixels. The source photo is up to 800px square, so
  /// decoding at tile size keeps a large grid off the memory ceiling.
  final int decodeWidth;

  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: fit,
      width: double.infinity,
      cacheWidth: decodeWidth,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: AppTokens.well,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppTokens.inkMuted,
          ),
        ),
      ),
    );
  }
}
