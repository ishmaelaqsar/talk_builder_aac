import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

const List<String> _digitWords = [
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
];

/// Asks for three digits named in words. Returns true only when the parent
/// taps them in order.
///
/// A young child cannot read the words, and a random tap passes once in 729
/// tries. A wrong key, **Cancel**, a tap outside, and [AppTokens.gateTimeout]
/// with no key all return false, so a child who reaches the gate gets the
/// screen back.
Future<bool> showParentGate(BuildContext context, {Random? random}) async {
  final Random source = random ?? Random();
  final List<int> code = [for (int i = 0; i < 3; i++) source.nextInt(9) + 1];
  final bool? passed = await showDialog<bool>(
    context: context,
    builder: (_) => _ParentGate(code: code),
  );
  return passed ?? false;
}

class _ParentGate extends StatefulWidget {
  const _ParentGate({required this.code});

  final List<int> code;

  @override
  State<_ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<_ParentGate> {
  int _entered = 0;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _restartTimeout();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _restartTimeout() {
    _timeout?.cancel();
    _timeout = Timer(AppTokens.gateTimeout, () => _close(false));
  }

  /// Closes the gate once. A second key in the same frame would otherwise pop
  /// the screen under the gate.
  void _close(bool passed) {
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.pop(context, passed);
    }
  }

  void _press(int digit) {
    if (digit != widget.code[_entered]) {
      _close(false);
      return;
    }
    if (_entered + 1 == widget.code.length) {
      _close(true);
      return;
    }
    setState(() => _entered++);
    _restartTimeout();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AlertDialog(
      // Scrolls, so every key stays in reach on a short screen and at a large
      // text scale.
      scrollable: true,
      title: const Text('Grown-ups only'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tap ${widget.code.map((digit) => _digitWords[digit - 1]).join(', ')}',
            style: text.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '$_entered of ${widget.code.length} entered',
            style: text.bodySmall,
          ),
          const SizedBox(height: 16),
          for (int row = 0; row < 3; row++)
            Row(
              children: [
                for (int column = 1; column <= 3; column++)
                  _key(row * 3 + column, text),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => _close(false), child: const Text('Cancel')),
      ],
    );
  }

  Widget _key(int digit, TextTheme text) => Expanded(
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: AppTokens.gateKeySize,
        child: FilledButton.tonal(
          onPressed: () => _press(digit),
          style: FilledButton.styleFrom(padding: EdgeInsets.zero),
          // Shrinks the digit at a large text scale, so it stays inside its
          // key.
          child: FittedBox(child: Text('$digit', style: text.titleMedium)),
        ),
      ),
    ),
  );
}
