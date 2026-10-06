import '../../content/ability_defs.dart';

/// An ability being wound up. After [windup] seconds [onRelease] fires; the
/// caster stays busy for a short [recovery] afterwards.
class AbilityCast {
  AbilityCast({required this.ability, required this.windup, required this.onRelease, this.recovery = 0.1, this.onCancel});

  final AbilityDef ability;
  final double windup;
  final double recovery;
  final void Function() onRelease;
  final void Function()? onCancel;

  double t = 0;
  bool released = false;
  bool cancelled = false;

  bool get done => cancelled || (released && t >= windup + recovery);
  double get progress => windup <= 0 ? 1 : (t / windup).clamp(0, 1);

  void update(double dt) {
    t += dt;
    if (!released && t >= windup) {
      released = true;
      onRelease();
    }
  }

  void cancel() {
    if (released || cancelled) return;
    cancelled = true;
    onCancel?.call();
  }
}
