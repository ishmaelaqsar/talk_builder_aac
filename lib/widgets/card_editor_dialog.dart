import 'package:material_ui/material_ui.dart';

import '../models/talk_card.dart';
import '../theme.dart';
import 'card_media.dart';
import 'dialogs.dart';

/// A picture that the parent chose for a card: a photo at the path that the
/// picker returned, or a bundled symbol.
class CardPicture {
  const CardPicture.photo(String path)
    : photo = path,
      symbol = null,
      suggestedLabel = null;

  const CardPicture.symbol(String assetPath, {required String label})
    : photo = null,
      symbol = assetPath,
      suggestedLabel = label;

  final String? photo;
  final String? symbol;

  /// A label that the source already knows: a symbol's name.
  final String? suggestedLabel;
}

/// Runs the picture-picking flow. Returns null when the parent backs out.
typedef PictureChooser = Future<CardPicture?> Function();

/// What the parent chose in the editor.
sealed class CardEditResult {
  const CardEditResult();
}

/// Save, with the card as edited. A new photo is still at the picker's path.
final class CardSaved extends CardEditResult {
  const CardSaved(this.card);
  final TalkCard card;
}

/// Delete, which the parent confirmed.
final class CardDeleted extends CardEditResult {
  const CardDeleted();
}

/// Opens the card editor. Returns null when the parent cancels.
///
/// The same dialog adds a card and edits one. It writes no file, so a cancel
/// needs no clean-up. [isNew] leaves out the controls that only an existing
/// card has: the switch that hides it, and **Delete card**.
Future<CardEditResult?> showCardEditor(
  BuildContext context, {
  required TalkCard card,
  required bool isNew,
  required PictureChooser onChangePicture,
}) => showDialog<CardEditResult>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _CardEditorDialog(
    card: card,
    isNew: isNew,
    onChangePicture: onChangePicture,
  ),
);

class _CardEditorDialog extends StatefulWidget {
  const _CardEditorDialog({
    required this.card,
    required this.isNew,
    required this.onChangePicture,
  });

  final TalkCard card;
  final bool isNew;
  final PictureChooser onChangePicture;

  @override
  State<_CardEditorDialog> createState() => _CardEditorDialogState();
}

class _CardEditorDialogState extends State<_CardEditorDialog> {
  late final TextEditingController _label = TextEditingController(
    text: widget.card.label,
  );
  late TalkCard _draft = widget.card;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  bool get _canSave => _label.text.trim().isNotEmpty;

  Future<void> _changePicture() async {
    final CardPicture? picked = await widget.onChangePicture();
    if (picked == null || !mounted) return;
    setState(
      () => _draft = _draft.withPicture(
        photo: picked.photo,
        symbol: picked.symbol,
      ),
    );
  }

  Future<void> _delete() async {
    if (!await confirmDeleteCard(context, widget.card) || !mounted) return;
    Navigator.pop(context, const CardDeleted());
  }

  void _save() => Navigator.pop(
    context,
    CardSaved(_draft.copyWith(label: _label.text.trim())),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Card details'),
      // Scrolls, so the dialog holds up on a short screen and at a large text
      // scale.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _preview(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _changePicture,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Change picture'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _label,
              // The keyboard covers much of the dialog, so it rises only when
              // the card needs a word.
              autofocus: widget.card.label.isEmpty,
              maxLength: 24,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'What the card says',
                helperText: 'This is the word the app speaks.',
                border: OutlineInputBorder(),
              ),
            ),
            if (!widget.isNew) ...[
              SwitchListTile(
                value: _draft.isVisible,
                onChanged: (value) =>
                    setState(() => _draft = _draft.copyWith(isVisible: value)),
                contentPadding: EdgeInsets.zero,
                title: const Text('Show to your child'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTokens.danger,
                    minimumSize: const Size(0, AppTokens.minTouchTarget),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete card'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canSave ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  // A parent sees the picture before they save, so a wrong photo does not
  // first show up on the grid. A fixed square, because the dialog asks its
  // content for an intrinsic width, and a photo fills an unbounded width.
  Widget _preview() => Center(
    child: SizedBox.square(
      dimension: 120,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _draft.imagePath == null
              ? _draft.fillColor
              : AppTokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          border: Border.all(color: AppTokens.outline),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          child: CardMedia(card: _draft, decodeWidth: 320),
        ),
      ),
    ),
  );
}
