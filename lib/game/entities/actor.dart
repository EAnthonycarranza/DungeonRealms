import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../content/ability_defs.dart';
import '../combat/ability_cast.dart';
import '../combat/status_effects.dart';
import '../fx/fx.dart';
import '../render/character_sprite.dart';
import 'entity.dart';

enum Faction { hero, enemy }

/// Base class for everything that fights: the hero, enemies, event targets.
abstract class Actor extends GameEntity {
  Actor({super.ground, super.radius, required this.faction});

  final Faction faction;
  int level = 1;
  double hp = 1;
  double maxHp = 1;
  double attack = 1;
  double armor = 0;
  double critChance = 0;
  double critDamage = 0.5;
  double damageBonus = 0;
  double moveSpeed = 3;

  /// Multiplies animation/cast speed (rage buffs, attack speed gear).
  double actionSpeed = 1;

  /// Multiplies cooldown recovery.
  double cooldownRate = 1;

  /// Incoming damage multiplier (break windows set this above 1).
  double vulnerability = 1;
  bool knockbackImmune = false;

  final statuses = StatusEffects();
  SpriteAnimator? animator;

  /// World-space facing direction (unit).
  final facing = Vector2(0.7071, 0.7071);
  final knockback = Vector2.zero();

  AbilityCast? cast;
  final cooldowns = <String, double>{};

  /// Dash (dodge / charge) motion.
  final dashVelocity = Vector2.zero();
  double dashTime = 0;
  bool dashInvulnerable = false;

  double flash = 0;
  double invulnerable = 0;
  bool dead = false;
  double deadTime = 0;
  double sinceHurt = 99;
  double sinceCombat = 99;
  double renderScale = 1;
  Color? tint;

  String? _bark;
  double _barkTime = 0;

  bool get alive => !dead;
  bool get isDashing => dashTime > 0;
  bool get canAct => alive && !statuses.stunned && cast == null && !isDashing;
  bool get canMove => alive && statuses.moveMultiplier > 0 && cast == null && !isDashing;
  bool get isInvulnerable => invulnerable > 0 || (isDashing && dashInvulnerable);
  double get hpFraction => maxHp <= 0 ? 0 : (hp / maxHp).clamp(0, 1);
  double get visualHeight => animator?.sheet.visualHeight ?? 60;

  double cooldownOf(String abilityId) => cooldowns[abilityId] ?? 0;
  bool ready(AbilityDef a) => cooldownOf(a.id) <= 0;

  void startCooldown(AbilityDef a, {double reduction = 0}) => cooldowns[a.id] = a.cooldown * (1 - reduction);

  void say(String text, {double duration = 2.6}) {
    _bark = text;
    _barkTime = duration;
  }

  /// Turns toward a world direction and updates sprite facing.
  void faceDirection(Vector2 worldDir) {
    if (worldDir.length2 < 1e-6) return;
    facing.setFrom(worldDir.normalized());
    final s = game.iso.worldDirToScreen(facing.x, facing.y);
    final a = animator;
    if (a != null) {
      if (s.x.abs() > 1) a.flip = s.x < 0;
      a.back = s.y < -0.35 * game.iso.halfH;
    }
  }

  void faceToward(Vector2 worldPoint) => faceDirection(worldPoint - ground);

  /// Moves with static collision. Returns the fraction of the distance made.
  double moveBy(Vector2 delta) => game.collision.move(ground, delta, radius);

  void playAnim(String name, {bool restart = false, double speed = 1}) => animator?.play(name, restart: restart, speed: speed);

  @override
  void update(double dt) {
    final burn = statuses.update(dt);
    if (burn > 0 && alive) game.combat.applyBurn(this, burn);
    for (final k in cooldowns.keys.toList()) {
      cooldowns[k] = math.max(0, cooldowns[k]! - dt * cooldownRate);
    }
    flash = math.max(0, flash - dt);
    invulnerable = math.max(0, invulnerable - dt);
    sinceHurt += dt;
    sinceCombat += dt;
    if (_barkTime > 0) _barkTime -= dt;

    if (dead) {
      deadTime += dt;
    } else {
      if (dashTime > 0) {
        final step = math.min(dt, dashTime);
        final made = moveBy(dashVelocity * step);
        onDashStep(made);
        dashTime -= step;
        if (dashTime <= 0) onDashEnd();
      }
      if (knockback.length2 > 1e-4) {
        moveBy(knockback * dt);
        knockback.scale(math.max(0, 1 - dt * 7));
      }
      final c = cast;
      if (c != null) {
        if (statuses.stunned) {
          interruptCast();
        } else {
          c.update(dt * actionSpeed);
          if (c.done) cast = null;
        }
      }
    }
    animator?.update(dt);
    super.update(dt);
  }

  /// Called each dash step with the fraction of the intended distance moved.
  void onDashStep(double madeFraction) {}
  void onDashEnd() {
    dashTime = 0;
    dashInvulnerable = false;
  }

  void interruptCast() {
    cast?.cancel();
    cast = null;
  }

  /// Called by the combat system when hp reaches zero.
  void onDeath() {
    dead = true;
    deadTime = 0;
    interruptCast();
    dashTime = 0;
    statuses.clear();
    playAnim('death', restart: true);
  }

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  static final _flashPaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = const ColorFilter.mode(Color(0xddffffff), BlendMode.srcATop);

  Paint? _paintFor() {
    if (flash > 0) return _flashPaint;
    Color? c = tint;
    if (statuses.stunned) c = const Color(0x55ffe066);
    if (statuses.rooted) c = const Color(0x4482f16d);
    if (statuses.slowed && c == null) c = const Color(0x444fd4ff);
    if (statuses.burning && c == null) c = const Color(0x55ff5b2d);
    if (c == null) return null;
    return Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = ColorFilter.mode(c, BlendMode.srcATop);
  }

  double get deathFade => dead ? (1 - math.max(0, deadTime - 1.4) / 0.8).clamp(0.0, 1.0) : 1;

  @override
  void render(Canvas canvas) {
    final a = animator;
    if (a == null) return;
    final fade = deathFade;
    if (fade <= 0) return;
    canvas.save();
    canvas.translate(0, -z);
    if (fade < 1) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, fade));
    a.draw(canvas, paint: _paintFor(), scale: renderScale);
    if (fade < 1) canvas.restore();
    if (alive) renderStatusOverlays(canvas);
    canvas.restore();
    if (alive) renderOverhead(canvas);
    if (_barkTime > 0 && _bark != null && alive) {
      final alpha = math.min(1.0, _barkTime * 3);
      drawSpeechBubble(canvas, _bark!, -visualHeight * renderScale - 26 - z, alpha: alpha);
    }
  }

  void renderStatusOverlays(Canvas canvas) {
    final t = game.time;
    if (statuses.stunned) {
      final y = -visualHeight * renderScale - 6;
      for (var i = 0; i < 3; i++) {
        final ang = t * 5 + i * math.pi * 2 / 3;
        final p = Offset(math.cos(ang) * 16 * renderScale, y + math.sin(ang) * 5);
        _star(canvas, p, 5, const Color(0xffffe066));
      }
    }
    if (statuses.rooted) {
      final paint = Paint()
        ..color = const Color(0xff4faf35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final w = radius * 90;
      for (var i = 0; i < 5; i++) {
        final x = -w + i * w / 2;
        final path = Path()
          ..moveTo(x, 4)
          ..quadraticBezierTo(x + 8 * math.sin(t * 3 + i), -12, x + 4, -22 - (i.isEven ? 6 : 0));
        canvas.drawPath(path, paint);
      }
    }
  }

  static void _star(Canvas c, Offset p, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final q = p + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    path.close();
    c.drawPath(path, Paint()..color = color);
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xff5a4010),
    );
  }

  /// Health bars and markers above the head (enemies override).
  void renderOverhead(Canvas canvas) {}

  @override
  void renderGround(Canvas canvas) {
    if (dead && deathFade <= 0) return;
    final rx = radius * 92, ry = radius * 46;
    final shrink = 1 / (1 + z / 120);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2 * shrink, height: ry * 2 * shrink),
      Paint()..color = Color.fromRGBO(0, 0, 0, 0.28 * deathFade),
    );
  }

  /// Draws a compact health bar centred at (0, y).
  void drawHealthBar(Canvas canvas, double y, double width, {Color color = const Color(0xffff5b4d), bool vulnerable = false}) {
    final rect = Rect.fromCenter(center: Offset(0, y), width: width, height: 7);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(4)), Paint()..color = const Color(0xcc12161f));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rect.left, rect.top, rect.width * hpFraction, rect.height), const Radius.circular(3)),
      Paint()..color = vulnerable ? const Color(0xffffe066) : color,
    );
  }
}
