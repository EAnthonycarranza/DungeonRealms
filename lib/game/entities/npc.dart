import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../content/game_data.dart';
import '../fx/fx.dart';
import '../render/character_sprite.dart';
import 'entity.dart';

/// A friendly townsperson: quest giver and/or service provider.
class NpcEntity extends GameEntity implements Interactable {
  NpcEntity({required this.def, required CharacterSheet sheet, required Vector2 ground})
    : animator = SpriteAnimator(sheet),
      super(ground: ground, radius: 0.35) {
    boundsHalfWidth = 70;
    boundsHeight = 150;
    animator.time = math.Random().nextDouble() * 2;
  }

  final NpcDef def;
  final SpriteAnimator animator;
  double talkTime = 0;
  String? _bark;
  double _barkTime = 0;
  double _idleBark = 6 + math.Random().nextDouble() * 10;
  final _rng = math.Random();

  /// `!` (quest available), `?` (ready to turn in) or null.
  String? marker;

  @override
  double get interactRange => 2.2;
  @override
  String get promptLabel => 'Talk';
  @override
  String get promptIcon => 'interact_talk';
  @override
  bool get canInteract => game.hero.alive;

  @override
  void interact() => game.talkTo(this);

  void say(String text, {double duration = 3}) {
    _bark = text;
    _barkTime = duration;
  }

  @override
  void update(double dt) {
    animator.update(dt);
    talkTime = math.max(0, talkTime - dt);
    animator.play(talkTime > 0 ? 'talk' : 'idle');
    if (_barkTime > 0) _barkTime -= dt;
    // Occasional ambient barks when the hero is nearby.
    _idleBark -= dt;
    if (_idleBark <= 0) {
      _idleBark = 12 + _rng.nextDouble() * 14;
      if (def.barks.isNotEmpty && game.hero.ground.distanceTo(ground) < 7) {
        say(def.barks[_rng.nextInt(def.barks.length)]);
      }
    }
    // Face the hero when close.
    final hs = game.hero.position;
    if (game.hero.ground.distanceTo(ground) < 4) animator.flip = hs.x < position.x;
    super.update(dt);
  }

  @override
  void renderGround(Canvas canvas) {
    canvas.drawOval(const Rect.fromLTWH(-30, -14, 60, 28), Paint()..color = const Color(0x40000000));
  }

  @override
  void render(Canvas canvas) {
    animator.draw(canvas);
    final top = -animator.sheet.visualHeight - 14;
    if (marker != null) {
      final bob = math.sin(game.time * 4) * 4;
      _drawMarker(canvas, marker!, Offset(0, top - 18 + bob));
    }
    if (_barkTime > 0 && _bark != null) {
      drawSpeechBubble(canvas, _bark!, top - (marker != null ? 44 : 6), alpha: math.min(1.0, _barkTime * 3));
    }
  }

  static final _markerCache = <String, (TextPainter, TextPainter)>{};

  void _drawMarker(Canvas canvas, String text, Offset at) {
    final (fill, stroke) = _markerCache.putIfAbsent(text, () {
      const style = TextStyle(fontFamily: 'LilitaOne', fontSize: 38, color: Color(0xffffd23f));
      final f = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final s = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = const Color(0xff3a2400),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return (f, s);
    });
    canvas.drawCircle(at, 24, Paint()..color = const Color(0x33ffd23f));
    final o = at - Offset(fill.width / 2, fill.height / 2);
    stroke.paint(canvas, o);
    fill.paint(canvas, o);
  }
}
