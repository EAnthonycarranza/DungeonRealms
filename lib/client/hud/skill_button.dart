import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/session.dart';
import '../theme.dart';
import '../widgets/art.dart';

/// Round ability button visual: icon, cooldown sweep, lock, ultimate ring.
class SkillButtonFace extends StatelessWidget {
  const SkillButtonFace({super.key, required this.hud, required this.size, this.keyLabel, this.pressed = false, this.charge, this.iconOverride, this.badge});

  final AbilityHud? hud;
  final double size;
  final String? keyLabel;
  final bool pressed;

  /// Ultimate meter 0..1 (drawn as a ring).
  final double? charge;
  final String? iconOverride;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final h = hud;
    final locked = h != null && !h.unlocked;
    final cooling = h != null && h.unlocked && !h.isUltimate && h.remaining > 0.05;
    final ultimateReady = h != null && h.isUltimate && h.ready;
    final ring = ultimateReady
        ? DR.gold
        : (h?.isUltimate ?? false)
        ? const Color(0xff6b5a2a)
        : const Color(0xff2c3954);
    return AnimatedScale(
      scale: pressed ? 0.92 : 1,
      duration: const Duration(milliseconds: 80),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [Color(0xff26324a), Color(0xff0e1422)]),
                border: Border.all(color: ring, width: ultimateReady ? 3.5 : 2.5),
                boxShadow: [
                  const BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 4)),
                  if (ultimateReady) const BoxShadow(color: Color(0x99ffc94f), blurRadius: 18),
                ],
              ),
            ),
            if ((iconOverride ?? h?.icon) != null)
              Opacity(
                opacity: locked ? 0.3 : 1,
                child: IconImage((iconOverride ?? h?.icon)!, size: size * 0.7),
              ),
            if (charge != null && !ultimateReady) CustomPaint(size: Size.square(size), painter: _RingPainter(charge!.clamp(0, 1), DR.gold)),
            if (cooling) ...[
              CustomPaint(size: Size.square(size), painter: _SweepPainter(h.cooldownFraction)),
              Text(h.remaining >= 1 ? h.remaining.ceil().toString() : h.remaining.toStringAsFixed(1), style: DR.title(size * 0.3)),
            ],
            if (locked) ...[
              Icon(Icons.lock_rounded, color: DR.muted, size: size * 0.32),
              Positioned(
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xee0e1422), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'Lv ${h.unlockLevel}',
                    style: DR.body(10, color: DR.muted, weight: FontWeight.w900),
                  ),
                ),
              ),
            ],
            if (keyLabel != null)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xff0e1422),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: DR.line),
                  ),
                  child: Text(
                    keyLabel!,
                    style: DR.body(10, color: DR.gold, weight: FontWeight.w900),
                  ),
                ),
              ),
            if (badge != null)
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: DR.red,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xff3a0d08), width: 1.5),
                  ),
                  child: Text(badge!, style: DR.body(11, weight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter(this.fraction);
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(rect.deflate(2), -math.pi / 2, math.pi * 2 * fraction, true, Paint()..color = const Color(0xb3070a12));
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.fraction != fraction;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      (Offset.zero & size).deflate(2),
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}
