import 'dart:ui';


import 'actor.dart';

/// An immobile ally that enemies try to destroy (Pip's wagon).
/// Rendered by the map prop; this only adds hit points and a health bar.
class EventTargetEntity extends Actor {
  EventTargetEntity({required this.name, required double maxHealth, required super.ground, required super.radius, this.barHeight = 150})
    : super(faction: Faction.hero) {
    maxHp = maxHealth;
    hp = maxHealth;
    armor = 10;
    knockbackImmune = true;
    boundsHalfWidth = 120;
    boundsHeight = barHeight + 30;
  }

  final String name;
  final double barHeight;

  @override
  double get visualHeight => barHeight;

  @override
  void onDeath() => dead = true;

  @override
  void renderGround(Canvas canvas) {}

  @override
  void render(Canvas canvas) {
    if (!alive) return;
    drawHealthBar(canvas, -barHeight, 110, color: const Color(0xff82f16d));
  }
}
