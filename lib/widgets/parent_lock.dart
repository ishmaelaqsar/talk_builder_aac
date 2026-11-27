import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// The lock that guards editing.
///
/// Locked, it asks for a deliberate [AppTokens.unlockHold] hold, and fills a
/// ring while the hold runs so the parent can see it registered. A child
/// presses everything, so a plain long press is not enough of a gate.
///
/// Unlocked, the same control locks again on a tap. It stays in the tree in
/// both states, so the finger that opened admin mode still has something to
/// lift off.
class ParentLock extends StatefulWidget {
  const ParentLock({
    super.key,
    required this.unlocked,
    required this.onUnlock,
    required this.onLock,
  });

  final bool unlocked;
  final VoidCallback onUnlock;
  final VoidCallback onLock;

  @override
  State<ParentLock> createState() => _ParentLockState();
}

class _ParentLockState extends State<ParentLock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: AppTokens.unlockHold,
  )..addStatusListener(_onStatus);

  /// The pointer that is holding the lock open, if any.
  int? _holdPointer;

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _hold.value = 0;
    HapticFeedback.mediumImpact();
    widget.onUnlock();
  }

  void _onDown(PointerDownEvent event) {
    if (widget.unlocked) return;
    _holdPointer = event.pointer;
    _hold.forward();
  }

  void _onRelease(PointerEvent event) {
    // The hold that just opened admin mode ends with this release. Locking on
    // it would undo the unlock the parent had only now earned.
    if (_holdPointer == event.pointer) {
      _holdPointer = null;
      _hold.reverse();
      return;
    }
    if (widget.unlocked) widget.onLock();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool unlocked = widget.unlocked;

    return Semantics(
      button: true,
      label: unlocked ? 'Lock editing' : 'Unlock editing',
      // A hold is a pointer gesture an assistive-technology user cannot make,
      // so expose the same action as a long press.
      onLongPress: unlocked ? widget.onLock : widget.onUnlock,
      child: Tooltip(
        message: unlocked
            ? 'Tap to stop editing'
            : 'Press and hold to edit cards',
        // Raw pointer events, not a GestureDetector. The tooltip's own
        // long-press recognizer wins the gesture arena at half a second, which
        // cancelled a tap recognizer and reset the ring before the hold was
        // done. A Listener does not enter the arena, so nothing steals it.
        child: Listener(
          onPointerDown: _onDown,
          onPointerUp: _onRelease,
          onPointerCancel: _onRelease,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: AppTokens.minTouchTarget,
            height: AppTokens.minTouchTarget,
            child: Center(
              child: AnimatedBuilder(
                animation: _hold,
                builder: (context, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 36,
                      child: CircularProgressIndicator(
                        value: _hold.value,
                        strokeWidth: 3,
                        // The ring stays invisible until a hold starts, so the
                        // child-facing screen stays plain.
                        color: _hold.value == 0
                            ? Colors.transparent
                            : AppTokens.admin,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    Icon(
                      unlocked ? Icons.lock_open : Icons.lock_outline,
                      color: unlocked ? AppTokens.admin : AppTokens.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
