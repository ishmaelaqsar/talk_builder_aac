import 'package:material_ui/material_ui.dart';

import '../models/talk_card.dart';
import '../theme.dart';

/// Asks the parent to confirm a delete.
///
/// A photo card is a photo the parent took of their own child's things. Deleting
/// it used to take one mis-tap on a 24px target, with no way back.
Future<bool> confirmDeleteCard(BuildContext context, TalkCard card) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this card?'),
      content: Text(
        card.imagePath == null
            ? '"${card.label}" is removed for good. '
                  'To keep it but take it off the grid, hide it instead.'
            : '"${card.label}" and its photo are removed for good. '
                  'To keep the photo but take the card off the grid, hide it '
                  'instead.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppTokens.danger),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Where the picture of a new card comes from.
enum CardSource { camera, gallery, symbols }

/// Asks where the picture comes from.
///
/// Camera only was a real limit: a parent's photos of family and of favourite
/// things are already on the device.
Future<CardSource?> pickCardSource(BuildContext context) {
  return showModalBottomSheet<CardSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, CardSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from the gallery'),
            onTap: () => Navigator.pop(context, CardSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_symbols_outlined),
            title: const Text('Symbol library'),
            onTap: () => Navigator.pop(context, CardSource.symbols),
          ),
        ],
      ),
    ),
  );
}
