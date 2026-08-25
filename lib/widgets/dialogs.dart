import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';

/// Asks the parent to confirm a delete.
///
/// A photo card is a photo the parent took of their own child's things. Deleting
/// it used to take one mis-tap on a 24px target, with no way back.
Future<bool> confirmDeleteCard(BuildContext context, String label) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this card?'),
      content: Text(
        '"$label" and its photo are removed for good. '
        'To keep the photo but take the card off the grid, hide it instead.',
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

/// Asks where the photo comes from.
///
/// Camera only was a real limit: a parent's photos of family and of favourite
/// things are already on the device.
Future<ImageSource?> pickPhotoSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from the gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Collects a card label. Returns null when the parent cancels.
///
/// Save stays disabled until the text has a non-space character, because the old
/// `label.isEmpty` check let a label of spaces through and made an unreadable
/// card.
Future<String?> askForLabel(
  BuildContext context, {
  String initialValue = '',
  String title = 'Card label',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _LabelDialog(initialValue: initialValue, title: title),
  );
}

class _LabelDialog extends StatefulWidget {
  const _LabelDialog({required this.initialValue, required this.title});

  final String initialValue;
  final String title;

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _value => _controller.text.trim();

  void _submit() {
    if (_value.isEmpty) return;
    Navigator.pop(context, _value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 24,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          hintText: 'For example: Teddy',
          helperText: 'This is the word the app speaks.',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _value.isEmpty ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
