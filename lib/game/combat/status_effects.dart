import 'dart:math' as math;

import '../../content/ability_defs.dart';

/// Crowd control and damage-over-time on one actor.
class StatusEffects {
  double root = 0;
  double stun = 0;
  double slow = 0;
  double slowAmount = 0;
  double burn = 0;
  double burnDps = 0;

  /// Bosses shrug off most crowd control (shorter durations).
  double ccResistance = 0;

  bool get rooted => root > 0;
  bool get stunned => stun > 0;
  bool get slowed => slow > 0;
  bool get burning => burn > 0;

  /// Movement multiplier from statuses.
  double get moveMultiplier {
    if (rooted || stunned) return 0;
    return slowed ? 1 - slowAmount : 1;
  }

  void apply(StatusSpec s, {double powerScale = 1}) {
    final d = s.duration * (1 - ccResistance);
    switch (s.status) {
      case 'root':
        root = math.max(root, d);
      case 'stun':
        stun = math.max(stun, d);
      case 'slow':
        slow = math.max(slow, d);
        slowAmount = math.max(slowAmount, s.amount);
      case 'burn':
        burn = math.max(burn, s.duration);
        burnDps = math.max(burnDps, s.amount * powerScale);
    }
  }

  /// Advances timers. Returns burn damage dealt this tick.
  double update(double dt) {
    root = math.max(0, root - dt);
    stun = math.max(0, stun - dt);
    slow = math.max(0, slow - dt);
    if (slow == 0) slowAmount = 0;
    var burnDamage = 0.0;
    if (burn > 0) {
      burnDamage = burnDps * math.min(dt, burn);
      burn = math.max(0, burn - dt);
      if (burn == 0) burnDps = 0;
    }
    return burnDamage;
  }

  void clear() {
    root = stun = slow = slowAmount = burn = burnDps = 0;
  }
}
