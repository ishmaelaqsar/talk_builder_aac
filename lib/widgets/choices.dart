import 'package:material_ui/material_ui.dart';

/// One choice, as a row of chips that wraps on a narrow screen. A chip tells
/// a screen reader its name and whether it is chosen.
class Choices<T> extends StatelessWidget {
  const Choices({
    super.key,
    required this.title,
    required this.names,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final Map<T, String> names;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final MapEntry<T, String> choice in names.entries)
              ChoiceChip(
                label: Text(choice.value),
                selected: choice.key == selected,
                onSelected: (_) => onSelected(choice.key),
              ),
          ],
        ),
      ],
    ),
  );
}
