import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../content/game_data.dart';
import '../../rules/hero_profile.dart';
import '../../rules/stats.dart';
import '../combat/powers.dart';
import '../fx/fx.dart';
import '../input.dart';
import '../render/character_sprite.dart';
import '../session.dart';
import 'actor.dart';
import 'entity.dart';
import 'interactables.dart';

class HeroAbilitySlot {
  HeroAbilitySlot(this.slot, this.ability, this.unlockLevel);
  final AbilitySlotId slot;
  final AbilityDef ability;
  final int unlockLevel;
}

/// Outcome of trying to start an ability from input.
enum _Attempt { started, blocked, rejected }

/// The player's hero. Reads [InputState] each frame.
class HeroEntity extends Actor {
  HeroEntity({required this.def, required this.profile, required CharacterSheet sheet, required Vector2 ground})
    : super(ground: ground, radius: 0.3, faction: Faction.hero) {
    animator = SpriteAnimator(sheet);
    boundsHalfWidth = 70;
    boundsHeight = 130;
  }

  final HeroDef def;
  final HeroProfile profile;
  late HeroStats stats;
  final powers = PowerSet();
  AbilityDef? basicAbility;
  AbilityDef? dodgeAbility;
  final slots = <HeroAbilitySlot>[];

  double ultimate = 0;
  double potionCooldown = 0;
  double flairCooldown = 0;
  final moveIntent = Vector2.zero();
  Actor? currentTarget;

  // Portrait mood timers.
  double _attackMood = 0;
  double _ultimateMood = 0;

  // Gathering channel.
  ResourceNodeEntity? gatherTarget;
  double gatherTime = 0;
  double gatherDuration = 1;

  double _promptTimer = 0;
  Interactable? nearestInteractable;
  double _stepDust = 0;

  @override
  Future<void> onLoad() async {
    final data = game.data;
    basicAbility = data.abilities[def.basicAbility];
    dodgeAbility = data.abilities[def.dodgeAbility];
    const ids = [AbilitySlotId.skill1, AbilitySlotId.skill2, AbilitySlotId.skill3, AbilitySlotId.ultimate];
    for (var i = 0; i < def.abilities.length && i < ids.length; i++) {
      final s = def.abilities[i];
      slots.add(HeroAbilitySlot(s.ultimate ? AbilitySlotId.ultimate : ids[i], data.abilities[s.abilityId]!, s.unlockLevel));
    }
    level = profile.level;
    recomputeStats(fullHeal: true);
  }

  /// Recalculates stats from level + equipped gear (+ legendary powers).
  void recomputeStats({bool fullHeal = false}) {
    final data = game.data;
    final frac = maxHp > 1 ? hp / maxHp : 1.0;
    stats = HeroStats.compute(def, profile.level, profile.inventory.equipped.values);
    level = profile.level;
    maxHp = stats.maxHp;
    hp = fullHeal ? maxHp : math.max(1, maxHp * frac);
    attack = stats.attack;
    armor = stats.armor;
    critChance = stats.critChance;
    critDamage = stats.critDamage;
    damageBonus = stats.damageBonus;
    moveSpeed = stats.moveSpeed;
    powers.setFrom([
      for (final item in profile.inventory.equipped.values)
        if (item.legendaryId != null) data.legendaries[item.legendaryId]!.power,
    ]);
  }

  double get ultimateMax => game.data.progression.ultimateMax;
  bool get ultimateReady => ultimate >= ultimateMax;

  void gainCharge(double amount) {
    if (amount <= 0) return;
    final before = ultimate;
    ultimate = math.min(ultimateMax, ultimate + amount * (1 + stats.ultimateCharge));
    if (before < ultimateMax && ultimate >= ultimateMax && unlocked(AbilitySlotId.ultimate)) {
      game.session.toast('Ultimate ready!', icon: 'ability_arrow_storm', color: 0xffffc94f);
    }
  }

  void spendUltimate() => ultimate = 0;

  /// Incoming damage multiplier from powers (Hard Headed).
  double get incomingDamageMultiplier {
    final p = powers.get('hard_headed');
    if (p != null && hpFraction < p.param('threshold', 0.35)) return 1 - p.param('reduction', 0.3);
    return 1;
  }

  bool unlocked(AbilitySlotId id) {
    if (id == AbilitySlotId.basic || id == AbilitySlotId.dodge) return true;
    final s = slots.where((s) => s.slot == id).firstOrNull;
    return s != null && profile.level >= s.unlockLevel;
  }

  AbilityDef? abilityFor(AbilitySlotId id) => switch (id) {
    AbilitySlotId.basic => basicAbility,
    AbilitySlotId.dodge => dodgeAbility,
    _ => slots.where((s) => s.slot == id).firstOrNull?.ability,
  };

  void onHurt(double amount, Actor source) {
    if (gatherTarget != null) {
      game.session.toast('Interrupted! (Goblins hate mining.)');
      cancelGather();
    }
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  @override
  void update(double dt) {
    if (!dead) {
      _regen(dt);
      potionCooldown = math.max(0, potionCooldown - dt);
      flairCooldown = math.max(0, flairCooldown - dt);
      _attackMood = math.max(0, _attackMood - dt);
      _ultimateMood = math.max(0, _ultimateMood - dt);
      if (vulnerability != 1) vulnerability = 1;
      _handleInput(dt);
      _updateGather(dt);
      _promptTimer -= dt;
      if (_promptTimer <= 0) {
        _promptTimer = 0.1;
        _updatePrompt();
      }
    }
    super.update(dt);
  }

  void _regen(double dt) {
    var regen = stats.hpRegen;
    if (sinceHurt > game.data.progression.regenDelay && sinceCombat > game.data.progression.regenDelay) {
      regen += maxHp * game.data.progression.regenOutOfCombatPct;
    }
    hp = math.min(maxHp, hp + regen * dt);
  }

  void _handleInput(double dt) {
    final input = game.input;
    final iso = game.iso;
    iso.screenDirToWorld(input.move.x, input.move.y, moveIntent);
    moveIntent.scale(input.move.length.clamp(0.0, 1.0));

    final moving = moveIntent.length2 > 0.0025;
    if (moving && gatherTarget != null) cancelGather();

    if (canMove && moving) {
      final speed = moveSpeed * statuses.moveMultiplier;
      moveBy(moveIntent * (speed * dt));
      faceDirection(moveIntent);
      playAnim('walk', speed: (speed / 4.4).clamp(0.6, 1.6));
      _stepDust -= dt;
      if (_stepDust <= 0) {
        _stepDust = 0.28;
        game.particles.emit(x: position.x, y: position.y, color: const Color(0x99d9c9a8), count: 2, speed: 30, life: 0.35, size: 4, gravity: -30);
      }
    } else if (cast == null && !isDashing && gatherTarget == null) {
      final anim = animator!.anim;
      if (anim == 'walk' || animator!.finished) playAnim('idle');
    }

    input.runRequests(dt, (r) => _tryAbility(r) != _Attempt.blocked);
    if (input.attackHeld) _tryAbility(AbilityRequest(AbilitySlotId.basic, aimWorld: input.touchMode ? null : input.mouseWorld));
    if (input.takePotion()) drinkPotion();
    if (input.takeInteract()) {
      final target = nearestInteractable;
      if (target != null && target.canInteract) target.interact();
    }
  }

  /// Tries to start the ability for [r]. Blocked attempts (busy or cooling
  /// down) stay buffered in [InputState] for a moment; rejected ones are not
  /// retried.
  _Attempt _tryAbility(AbilityRequest r) {
    if (!unlocked(r.slot)) {
      if (r.slot != AbilitySlotId.basic) {
        final s = slots.where((s) => s.slot == r.slot).firstOrNull;
        if (s != null) game.session.toast('${s.ability.name} unlocks at level ${s.unlockLevel}');
      }
      return _Attempt.rejected;
    }
    final a = abilityFor(r.slot);
    if (a == null) return _Attempt.rejected;
    if (a.isUltimate && !ultimateReady) {
      game.session.toast('${a.name} needs a full ultimate meter');
      return _Attempt.rejected;
    }
    // Skills and dodges cut a basic attack short, and a dodge also cuts a
    // skill's follow-through: responsiveness beats one more arrow.
    final c = cast;
    if (c != null && r.slot != AbilitySlotId.basic && ready(a)) {
      if (c.ability.id == basicAbility?.id || (r.slot == AbilitySlotId.dodge && c.released)) interruptCast();
    }
    if (!canAct || !ready(a)) return _Attempt.blocked;
    if (gatherTarget != null) cancelGather();
    final aim = _resolveAim(a, r);
    final started = game.abilities.begin(this, a, aimPoint: aim);
    if (started) {
      if (r.slot == AbilitySlotId.ultimate) {
        _ultimateMood = 2.2;
        game.session.showBanner('ARROW STORM!', style: 'ultimate');
      } else if (r.slot != AbilitySlotId.dodge) {
        _attackMood = 0.7;
      }
    }
    return started ? _Attempt.started : _Attempt.blocked;
  }

  Vector2 _resolveAim(AbilityDef a, AbilityRequest r) {
    if (r.aimWorld != null) return r.aimWorld!.clone();
    if (r.aimDir != null && r.aimDir!.length2 > 1e-6) {
      final dist = a.aim == AimMode.ground ? math.min(a.range, r.aimDir!.length * a.range) : a.range;
      return ground + r.aimDir!.normalized() * math.max(0.5, dist);
    }
    if (!game.input.touchMode && game.input.mouseWorld != null && a.behavior != AbilityBehavior.dash) {
      return game.input.mouseWorld!.clone();
    }
    final target = a.autoTarget > 0 ? _autoTarget(a.autoTarget) : null;
    if (target != null) {
      currentTarget = target;
      return target.ground.clone();
    }
    return ground + facing * math.min(a.range, 4);
  }

  /// Nearest living enemy within [range], preferring the current target and
  /// enemies in front of the hero.
  Actor? _autoTarget(double range) {
    final cur = currentTarget;
    if (cur != null && cur.alive && cur.ground.distanceTo(ground) <= range) return cur;
    Actor? best;
    var bestScore = double.infinity;
    for (final e in game.opponentsOf(faction)) {
      if (!e.alive) continue;
      final d = e.ground - ground;
      final dist = d.length;
      if (dist > range) continue;
      final ahead = dist > 0.01 ? d.dot(facing) / dist : 1;
      final score = dist - ahead * 1.2;
      if (score < bestScore) {
        bestScore = score;
        best = e;
      }
    }
    return best;
  }

  void drinkPotion() {
    if (dead) return;
    if (profile.potionCharges <= 0) {
      game.session.toast('Out of potions! Visit Granny Gristle or a waypoint.');
      return;
    }
    if (potionCooldown > 0) return;
    profile.potionCharges--;
    potionCooldown = game.data.potion.cooldown;
    game.combat.heal(this, maxHp * game.data.potion.heal);
    game.particles.emit(x: position.x, y: position.y - 40, color: const Color(0xffff6b6b), count: 14, speed: 70, life: 0.7, size: 4, gravity: -90);
    say(const ['*glug glug*', 'Tastes like a dare.', 'Questionable... but effective.'][math.Random().nextInt(3)], duration: 1.6);
  }

  // ---------------------------------------------------------------------------
  // Gathering (Day Jobs)
  // ---------------------------------------------------------------------------

  void startGather(ResourceNodeEntity node) {
    if (cast != null || isDashing) return;
    final job = game.data.dayJobs[node.def.skill]!;
    final lvl = profile.dayJob(job.id).level;
    gatherTarget = node;
    gatherTime = 0;
    gatherDuration = node.def.gatherTime * (1 - job.speedPerLevel * (lvl - 1)).clamp(0.4, 1.0);
    faceToward(node.ground);
    playAnim('cast', restart: true, speed: 0.6);
  }

  void cancelGather() {
    gatherTarget = null;
    game.session.gathering.value = null;
  }

  void _updateGather(double dt) {
    final node = gatherTarget;
    if (node == null) return;
    if (!node.available || node.ground.distanceTo(ground) > node.interactRange + 0.5) {
      cancelGather();
      return;
    }
    gatherTime += dt;
    if (animator!.finished) playAnim('cast', restart: true, speed: 0.6);
    game.session.gathering.value = (node.def.verb, (gatherTime / gatherDuration).clamp(0, 1));
    if ((gatherTime * 10).floor() != ((gatherTime - dt) * 10).floor()) {
      final s = node.position;
      game.particles.emit(
        x: s.x,
        y: s.y - 30,
        color: node.def.skill == 'mining' ? const Color(0xffffb36b) : const Color(0xff8ff7d0),
        count: 2,
        speed: 90,
        life: 0.35,
        size: 3,
        shape: ParticleShape.spark,
      );
    }
    if (gatherTime >= gatherDuration) {
      cancelGather();
      game.completeGather(node);
    }
  }

  // ---------------------------------------------------------------------------
  // Interaction prompt & mood
  // ---------------------------------------------------------------------------

  void _updatePrompt() {
    Interactable? best;
    var bestD = double.infinity;
    for (final i in game.interactables) {
      if (!i.canInteract) continue;
      final d = i.ground.distanceTo(ground);
      if (d <= i.interactRange && d < bestD) {
        bestD = d;
        best = i;
      }
    }
    nearestInteractable = best;
    final s = game.session;
    final next = best == null ? null : InteractPrompt(best.promptLabel, best.promptIcon);
    final cur = s.prompt.value;
    if (cur?.label != next?.label || cur?.icon != next?.icon) s.prompt.value = next;
  }

  PortraitMood get mood {
    if (dead) return PortraitMood.panic;
    if (statuses.stunned || statuses.rooted) return PortraitMood.stunned;
    if (_ultimateMood > 0) return PortraitMood.ultimate;
    if (hpFraction < 0.3) return PortraitMood.panic;
    if (_attackMood > 0) return PortraitMood.attack;
    return PortraitMood.idle;
  }

  // ---------------------------------------------------------------------------
  // XP
  // ---------------------------------------------------------------------------

  double get xpToNext => game.combat.math_.xpToNext(profile.level);

  void gainXp(double amount) {
    if (amount <= 0) return;
    final cap = game.data.progression.levelCap;
    if (profile.level >= cap) return;
    profile.xp += amount;
    game.floatText(this, '+${amount.round()} XP', const Color(0xffb26bff), size: 16, offsetY: -24);
    var leveled = false;
    while (profile.level < cap && profile.xp >= xpToNext) {
      profile.xp -= xpToNext;
      profile.level++;
      leveled = true;
    }
    if (leveled) {
      recomputeStats(fullHeal: true);
      game.onHeroLevelUp(profile.level);
    }
  }

  @override
  void renderGround(Canvas canvas) {
    super.renderGround(canvas);
    // Hero ring so you can always find yourself in a crowd.
    final pulse = 0.5 + 0.5 * math.sin(game.time * 3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 64, height: 32),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Color.fromRGBO(255, 201, 79, 0.45 + pulse * 0.25),
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final node = gatherTarget;
    if (node != null && !dead) {
      // Small progress bar over the head while gathering.
      final k = (gatherTime / gatherDuration).clamp(0.0, 1.0);
      final y = -visualHeight - 18;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, y), width: 54, height: 8), const Radius.circular(4)),
        Paint()..color = const Color(0xcc12161f),
      );
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-27, y - 4, 54 * k, 8), const Radius.circular(4)), Paint()..color = const Color(0xffffc94f));
    }
  }
}
