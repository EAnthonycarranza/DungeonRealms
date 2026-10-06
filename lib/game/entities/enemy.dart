import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../content/game_data.dart';
import '../ai/enemy_brain.dart';
import '../render/character_sprite.dart';
import '../systems/spawn_system.dart';
import 'actor.dart';

/// A hostile creature driven by an [EnemyBrain].
class EnemyEntity extends Actor {
  EnemyEntity({required this.def, required int level, required CharacterSheet sheet, required Vector2 ground, this.zone, this.eventTarget})
    : home = ground.clone(),
      super(ground: ground, radius: def.stats.radius, faction: Faction.enemy) {
    this.level = level;
    animator = SpriteAnimator(sheet);
    boundsHalfWidth = def.isBoss ? 200 : 80;
    boundsHeight = def.isBoss ? 300 : 150;
    if (def.tint != null) tint = _parseTint(def.tint!);
  }

  final EnemyDef def;
  final Vector2 home;
  final SpawnZone? zone;

  /// Public-event objective this enemy wants to wreck (e.g. Pip's wagon).
  final Actor? eventTarget;

  late final EnemyBrain brain = EnemyBrain(this);
  Actor? target;

  /// Bosses only fight once their arena is engaged.
  bool engaged = false;
  int phaseIndex = 0;
  double vulnerableTime = 0;
  bool elitePack = false;
  void Function(double made)? onDashStepHook;
  void Function()? onDashEndHook;

  static Color _parseTint(String hex) {
    final v = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0x55000000 | v);
  }

  @override
  Future<void> onLoad() async {
    final s = game.data.enemyScaling;
    final diff = game.difficulty;
    final eliteMult = elitePack ? 2.0 : 1.0;
    maxHp = s.hp(def.stats.hp, level) * diff.hp * eliteMult;
    hp = maxHp;
    attack = s.attack(def.stats.attack, level);
    armor = s.armor(def.stats.armor, level);
    moveSpeed = def.stats.speed;
    critChance = def.isBoss ? 0 : 0.05;
    critDamage = 0.5;
    if (def.isBoss) {
      knockbackImmune = true;
      statuses.ccResistance = 0.6;
      renderScale = 1;
    } else if (def.isElite) {
      knockbackImmune = true;
      statuses.ccResistance = 0.35;
    }
    if (elitePack) {
      renderScale = 1.18;
      tint ??= const Color(0x33ffd23f);
    }
    // Small random start so packs don't animate in lockstep.
    animator!.time = math.Random().nextDouble();
  }

  double get xpValue => game.data.enemyScaling.xp(def.xp, level) * game.difficulty.xp;

  void onDamaged(Actor source, double amount) => brain.onDamaged(source);

  @override
  void onDashStep(double madeFraction) => onDashStepHook?.call(madeFraction);

  @override
  void onDashEnd() {
    super.onDashEnd();
    onDashEndHook?.call();
    onDashEndHook = null;
  }

  @override
  void update(double dt) {
    if (vulnerableTime > 0) {
      vulnerableTime -= dt;
      if (vulnerableTime <= 0) vulnerability = 1;
    }
    if (!dead) brain.update(dt);
    if (dead && deadTime > 2.4) despawn();
    super.update(dt);
  }

  @override
  void renderOverhead(Canvas canvas) {
    if (def.isBoss) return; // HUD boss bar instead.
    final damaged = hp < maxHp - 0.5;
    if (!damaged && !def.isElite && !elitePack) return;
    final y = -visualHeight * renderScale - 14;
    drawHealthBar(canvas, y, def.isElite ? 96 : 52, color: def.isElite || elitePack ? const Color(0xffffa53a) : const Color(0xffff5b4d));
  }
}
