import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../content/item_defs.dart';
import '../dungeon_realms_game.dart';
import '../entities/actor.dart';

/// Legendary powers: build-changing modifiers keyed by power id.
///
/// Powers are data (items.json) + a small hook here. To add one: give the
/// legendary a new `power.id`, then read it where the behaviour changes
/// (ability_runner.dart / hero.dart) via [PowerSet.get].
class PowerSet {
  final _powers = <String, PowerDef>{};

  void setFrom(Iterable<PowerDef> powers) {
    _powers
      ..clear()
      ..addEntries(powers.map((p) => MapEntry(p.id, p)));
  }

  bool has(String id) => _powers.containsKey(id);
  PowerDef? get(String id) => _powers[id];

  /// The power [id] if it is active for [abilityId]: a power names the
  /// ability it changes in items.json (no ability = always active).
  PowerDef? forAbility(String id, String abilityId) {
    final p = _powers[id];
    return p != null && (p.ability == null || p.ability == abilityId) ? p : null;
  }

  Iterable<PowerDef> get all => _powers.values;
}

/// Jagged lightning line between two screen points, fading quickly.
class LightningFx extends Component {
  LightningFx(this.from, this.to) : super(priority: 6);

  final Vector2 from, to;
  double t = 0;
  final _rng = math.Random();
  late List<Offset> _points = _build();

  List<Offset> _build() {
    final pts = <Offset>[Offset(from.x, from.y)];
    const n = 7;
    final d = to - from;
    final normal = Vector2(-d.y, d.x)..normalize();
    for (var i = 1; i < n; i++) {
      final p = from + d * (i / n) + normal * ((_rng.nextDouble() - 0.5) * 26);
      pts.add(Offset(p.x, p.y));
    }
    pts.add(Offset(to.x, to.y));
    return pts;
  }

  @override
  void update(double dt) {
    t += dt;
    if (t > 0.05 && t < 0.2) _points = _build();
    if (t >= 0.32) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final a = (1 - t / 0.32).clamp(0.0, 1.0);
    final path = Path()..addPolygon(_points, false);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeJoin = StrokeJoin.round
        ..color = Color.fromRGBO(120, 200, 255, 0.35 * a),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = Color.fromRGBO(240, 250, 255, a),
    );
  }
}

/// Stormcaller: chain lightning from [first] to nearby enemies.
void chainLightning(DungeonRealmsGame game, Actor source, Actor first, PowerDef power) {
  final chains = power.param('chains', 2).toInt();
  final range = power.param('range', 4.5);
  final mult = power.param('damage', 0.6);
  final hit = <Actor>{first};
  var from = first;
  for (var i = 0; i < chains; i++) {
    Actor? next;
    var best = range * range;
    for (final e in game.opponentsOf(source.faction)) {
      if (!e.alive || hit.contains(e)) continue;
      final d = e.ground.distanceToSquared(from.ground);
      if (d < best) {
        best = d;
        next = e;
      }
    }
    if (next == null) break;
    hit.add(next);
    final a = from.position.clone()..y -= from.visualHeight * 0.5;
    final b = next.position.clone()..y -= next.visualHeight * 0.5;
    game.overlay.add(LightningFx(a, b));
    game.combat.hit(source, next, mult, chargeGain: 1, abilityId: 'stormcaller');
    from = next;
  }
}
