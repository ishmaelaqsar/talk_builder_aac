import 'package:material_ui/material_ui.dart';

import '../models/board_settings.dart';
import '../theme.dart';
import 'choices.dart';

/// Opens the settings.
///
/// Each change goes to [onChanged] at once, so there is no Save button for a
/// parent to miss. [onHear] gets a sample to speak with the current settings.
Future<void> showSettingsSheet(
  BuildContext context, {
  required BoardSettings settings,
  required ValueChanged<BoardSettings> onChanged,
  required ValueChanged<String> onHear,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      _SettingsSheet(settings: settings, onChanged: onChanged, onHear: onHear),
);

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.settings,
    required this.onChanged,
    required this.onHear,
  });

  final BoardSettings settings;
  final ValueChanged<BoardSettings> onChanged;
  final ValueChanged<String> onHear;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late BoardSettings _settings = widget.settings;

  void _change(BoardSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    // Scrolls, so the sheet holds up on a short screen and at a large text
    // scale.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Choices<SpeechVoice>(
              title: 'Voice',
              names: const {
                SpeechVoice.british: 'British',
                SpeechVoice.american: 'American',
              },
              selected: _settings.voice,
              onSelected: (voice) => _change(_settings.copyWith(voice: voice)),
            ),
            Choices<bool>(
              title: 'Speed',
              names: const {false: 'Normal', true: 'Slow'},
              selected: _settings.slow,
              onSelected: (slow) => _change(_settings.copyWith(slow: slow)),
            ),
            Choices<CardSize>(
              title: 'Card size',
              names: const {
                CardSize.small: 'Small',
                CardSize.medium: 'Medium',
                CardSize.large: 'Large',
              },
              selected: _settings.cardSize,
              onSelected: (size) => _change(_settings.copyWith(cardSize: size)),
            ),
            ElevatedButton.icon(
              onPressed: () => widget.onHear('I want more.'),
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Hear it'),
            ),
          ],
        ),
      ),
    );
  }
}
