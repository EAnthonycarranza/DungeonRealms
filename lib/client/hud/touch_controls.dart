import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../game/dungeon_realms_game.dart';
import '../../game/input.dart';
import '../../game/session.dart';
import '../../game/world/aim_indicator.dart';
import '../theme.dart';
import '../widgets/art.dart';
import 'skill_button.dart';

/// Floating joystick on the left part of the screen.
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({super.key, required this.input});

  final InputState input;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  static const radius = 58.0;
  Offset? _base;
  Offset _knob = Offset.zero;
  int? _pointer;

  void _update(Offset local) {
    var d = local - _base!;
    if (d.distance > radius) d = d / d.distance * radius;
    setState(() => _knob = d);
    final v = Vector2(d.dx / radius, d.dy / radius);
    // Small dead zone, then full speed quickly (feels snappy on phones).
    final len = v.length;
    if (len < 0.15) {
      widget.input.move.setZero();
    } else {
      widget.input.move.setFrom(v.normalized()..scale(((len - 0.15) / 0.6).clamp(0.0, 1.0)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        widget.input.touchMode = true;
        setState(() => _base = e.localPosition);
        _update(e.localPosition);
      },
      onPointerMove: (e) {
        if (e.pointer == _pointer) _update(e.localPosition);
      },
      onPointerUp: (e) => _release(e.pointer),
      onPointerCancel: (e) => _release(e.pointer),
      child: CustomPaint(painter: _JoystickPainter(_base, _knob), child: const SizedBox.expand()),
    );
  }

  void _release(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    widget.input.move.setZero();
    setState(() {
      _base = null;
      _knob = Offset.zero;
    });
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter(this.base, this.knob);
  final Offset? base;
  final Offset knob;

  @override
  void paint(Canvas canvas, Size size) {
    final b = base ?? Offset(110, size.height - 120);
    final alpha = base == null ? 0.35 : 0.85;
    canvas.drawCircle(b, 62, Paint()..color = Color.fromRGBO(10, 14, 22, 0.45 * alpha));
    canvas.drawCircle(
      b,
      62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Color.fromRGBO(255, 201, 79, 0.5 * alpha),
    );
    canvas.drawCircle(b + knob, 28, Paint()..color = Color.fromRGBO(255, 201, 79, 0.75 * alpha));
    canvas.drawCircle(
      b + knob,
      28,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Color.fromRGBO(58, 36, 0, alpha),
    );
  }

  @override
  bool shouldRepaint(_JoystickPainter old) => old.base != base || old.knob != knob;
}

/// A touch skill button: tap to auto-cast, hold and drag to aim.
class TouchSkillButton extends StatefulWidget {
  const TouchSkillButton({super.key, required this.game, required this.slot, required this.size});

  final DungeonRealmsGame game;
  final AbilitySlotId slot;
  final double size;

  @override
  State<TouchSkillButton> createState() => _TouchSkillButtonState();
}

class _TouchSkillButtonState extends State<TouchSkillButton> {
  int? _pointer;
  bool _pressed = false;

  InputState get input => widget.game.input;

  @override
  Widget build(BuildContext context) {
    final s = widget.game.session;
    final center = Offset(widget.size / 2, widget.size / 2);
    return Listener(
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        input.touchMode = true;
        setState(() => _pressed = true);
        if (widget.slot == AbilitySlotId.basic) {
          input.attackHeld = true;
        } else {
          input.aiming = widget.slot;
          input.aimDrag.setZero();
        }
      },
      onPointerMove: (e) {
        if (e.pointer != _pointer || widget.slot == AbilitySlotId.basic) return;
        final d = e.localPosition - center;
        input.aimDrag.setValues(d.dx, d.dy);
      },
      onPointerUp: (e) => _release(e.pointer, cancel: false),
      onPointerCancel: (e) => _release(e.pointer, cancel: true),
      child: ListenableBuilder(
        listenable: Listenable.merge([s.abilities, s.dodge, s.ultimateCharge]),
        builder: (_, _) {
          final hud = _hud(s);
          return SkillButtonFace(hud: hud, size: widget.size, pressed: _pressed, charge: hud?.isUltimate == true ? s.ultimateCharge.value : null);
        },
      ),
    );
  }

  AbilityHud? _hud(GameSession s) {
    if (widget.slot == AbilitySlotId.dodge) return s.dodge.value;
    if (widget.slot == AbilitySlotId.basic) return null;
    return s.abilities.value.where((a) => a.slot == widget.slot).firstOrNull;
  }

  void _release(int pointer, {required bool cancel}) {
    if (pointer != _pointer) return;
    _pointer = null;
    setState(() => _pressed = false);
    if (widget.slot == AbilitySlotId.basic) {
      input.attackHeld = false;
      return;
    }
    final drag = input.aimDrag.clone();
    input.aiming = null;
    input.aimDrag.setZero();
    if (cancel) return;
    if (drag.length > 14 && widget.game.isLoaded) {
      input.requestAbility(AbilityRequest(widget.slot, aimDir: dragToWorldAim(widget.game, drag)));
    } else {
      input.requestAbility(AbilityRequest(widget.slot));
    }
  }
}

/// Right-hand thumb cluster: attack, four skills, dodge and potion.
class TouchActionCluster extends StatelessWidget {
  const TouchActionCluster({super.key, required this.game, this.scale = 1});

  final DungeonRealmsGame game;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = game.session;
    final big = 92.0 * scale, mid = 64.0 * scale, small = 56.0 * scale;
    final w = 330.0 * scale, h = 270.0 * scale;
    final cx = w - 20 * scale - big / 2, cy = h - 18 * scale - big / 2;
    Widget at(double dx, double dy, double size, Widget child) => Positioned(left: cx + dx * scale - size / 2, top: cy + dy * scale - size / 2, child: child);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          at(0, 0, big, TouchSkillButton(game: game, slot: AbilitySlotId.basic, size: big)),
          at(-116, 4, mid, TouchSkillButton(game: game, slot: AbilitySlotId.skill1, size: mid)),
          at(-96, -72, mid, TouchSkillButton(game: game, slot: AbilitySlotId.skill2, size: mid)),
          at(-36, -116, mid, TouchSkillButton(game: game, slot: AbilitySlotId.skill3, size: mid)),
          at(34, -118, mid, TouchSkillButton(game: game, slot: AbilitySlotId.ultimate, size: mid)),
          at(-196, 14, small, TouchSkillButton(game: game, slot: AbilitySlotId.dodge, size: small)),
          at(
            -182,
            -84,
            small,
            GestureDetector(
              onTap: () => game.input.requestPotion(),
              child: ValueListenableBuilder<(int, int, double)>(
                valueListenable: s.potion,
                builder: (_, p, _) => _PotionFace(size: small, charges: p.$1, cooldown: p.$3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PotionFace extends StatelessWidget {
  const _PotionFace({required this.size, required this.charges, required this.cooldown});
  final double size;
  final int charges;
  final double cooldown;

  @override
  Widget build(BuildContext context) => SkillButtonFace(hud: null, size: size, iconOverride: 'ability_potion', badge: '$charges', pressed: cooldown > 0);
}

/// Contextual interact button (Talk / Mine / Open / Travel...).
class InteractButton extends StatelessWidget {
  const InteractButton({super.key, required this.game, this.showKey = false});

  final DungeonRealmsGame game;
  final bool showKey;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InteractPrompt?>(
      valueListenable: game.session.prompt,
      builder: (_, prompt, _) {
        if (prompt == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => game.input.requestInteract(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
            decoration: BoxDecoration(
              gradient: DR.goldGradient,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xff3a2400), width: 2),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 5))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconImage(prompt.icon, size: 34),
                const SizedBox(width: 6),
                Text(showKey ? '[G]  ${prompt.label}' : prompt.label, style: DR.title(20, color: const Color(0xff271300))),
              ],
            ),
          ),
        );
      },
    );
  }
}
