import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

/// Ability slots exposed to controls. `basic` auto-fires while held.
enum AbilitySlotId { basic, skill1, skill2, skill3, ultimate, dodge }

/// A request to use an ability, optionally aimed at a world point.
class AbilityRequest {
  AbilityRequest(this.slot, {this.aimWorld, this.aimDir});

  final AbilitySlotId slot;

  /// Explicit target point in world tiles (mouse cursor, drag-aim).
  final Vector2? aimWorld;

  /// Explicit world direction (drag-aim for directional skills).
  final Vector2? aimDir;
}

/// Live control state written by the Flutter shell (keyboard, mouse,
/// joystick, skill buttons) and read by the hero controller each frame.
class InputState {
  /// Screen-space movement direction, length 0..1.
  final Vector2 move = Vector2.zero();

  /// Last known mouse position in world tiles (desktop aiming).
  Vector2? mouseWorld;

  /// Basic attack is held down.
  bool attackHeld = false;

  /// Touch drag-aim currently in progress.
  AbilitySlotId? aiming;

  /// Drag vector in screen pixels (relative to the button) while aiming.
  final Vector2 aimDrag = Vector2.zero();

  /// True when the last input came from touch (shows on-screen controls).
  final touch = ValueNotifier<bool>(false);
  bool get touchMode => touch.value;
  set touchMode(bool v) {
    if (touch.value != v) touch.value = v;
  }

  /// How long a press waits for the hero to be free (input buffering: a skill
  /// pressed during another action still fires when that action ends).
  static const bufferWindow = 0.4;

  final List<(AbilityRequest, double)> _queue = [];
  bool _interact = false;
  bool _potion = false;

  void requestAbility(AbilityRequest r) {
    // Keep only the newest request per slot so mashing doesn't queue up.
    _queue
      ..removeWhere((q) => q.$1.slot == r.slot)
      ..add((r, 0));
  }

  /// Offers each buffered request (oldest first) to [tryRun], which returns
  /// true when the request is finished with (started or impossible). The
  /// rest wait until they outlive [bufferWindow].
  void runRequests(double dt, bool Function(AbilityRequest r) tryRun) {
    final pending = List.of(_queue);
    _queue.clear();
    for (final (r, age) in pending) {
      if (tryRun(r)) continue;
      if (age + dt <= bufferWindow) _queue.add((r, age + dt));
    }
  }

  void requestInteract() => _interact = true;
  void requestPotion() => _potion = true;

  bool takeInteract() {
    final v = _interact;
    _interact = false;
    return v;
  }

  bool takePotion() {
    final v = _potion;
    _potion = false;
    return v;
  }

  void clear() {
    move.setZero();
    attackHeld = false;
    aiming = null;
    aimDrag.setZero();
    _queue.clear();
    _interact = false;
    _potion = false;
  }
}
