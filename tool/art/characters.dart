// Character sprite sheets: looks + animation sets + sheet packing.
//
// Output per character (assets/images/sprites/):
//   <id>.png   - frames packed left-to-right, top-to-bottom
//   <id>.json  - frame size, anchor (feet), pixel ratio and animation table
// Each animation has a "front" and "back" frame range; the engine mirrors
// frames horizontally for left-facing directions.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'common.dart';
import 'rig_bear.dart';
import 'rig_humanoid.dart';

double _wave(double t, [double phase = 0]) => math.sin((t + phase) * math.pi * 2);
double _ease(double t) => t * t * (3 - 2 * t);

// ---------------------------------------------------------------------------
// Shared animation builders
// ---------------------------------------------------------------------------

Pose _idle(double t, {double sway = 0.3}) {
  final p = Pose()
    ..planted = true
    ..bodyY = _wave(t) * 0.9
    ..armF = 0.12 + _wave(t) * 0.04
    ..armB = -0.12 - _wave(t) * 0.04
    ..cloakSway = _wave(t) * sway;
  return p;
}

Pose _walk(double t, {double stride = 0.55, double lean = 0.08}) {
  final s = _wave(t);
  final c = math.cos(t * math.pi * 2);
  return Pose()
    ..legF = s * stride
    ..legB = -s * stride
    ..kneeF = math.max(0, -c) * 0.9 + 0.08
    ..kneeB = math.max(0, c) * 0.9 + 0.08
    ..armF = -s * 0.45
    ..armB = s * 0.5
    ..elbowF = 0.35
    ..elbowB = 0.35
    ..lean = lean
    ..cloakSway = 0.6 + s * 0.25;
}

Pose _hit(double t) {
  final k = 1 - t;
  return Pose()
    ..planted = true
    ..crouch = 2 * k
    ..lean = -0.28 * k
    ..headTilt = -0.2 * k
    ..armF = 0.7 * k + 0.1
    ..armB = 0.9 * k
    ..face = 'hurt'
    ..cloakSway = -0.4 * k;
}

Pose _death(double t, HumanoidLook look) {
  final e = _ease(math.min(1, t * 1.25));
  // Drop the body until the (big, chibi) head rests on the ground.
  final lying = (look.legLen + look.torsoH * 0.4) - math.max(look.headR * 0.9, look.torsoW * 0.5 * look.bulk);
  return Pose()
    ..planted = true
    ..crouch = 4 * e
    ..rotation = -1.5 * e
    ..lift = lying * e
    ..armF = 0.8 + 1.2 * e
    ..armB = 1.4 * e
    ..lean = -0.1 * e
    ..face = t > 0.45 ? 'dead' : 'hurt'
    ..cloakSway = -0.5;
}

class CharacterSpec {
  CharacterSpec({
    required this.id,
    required this.look,
    required this.anims,
    required this.frameSize,
    required this.anchor,
    this.pixelRatio = 1.5,
    this.facings = const ['front', 'back'],
  });

  final String id;
  final HumanoidLook? look;
  final Map<String, AnimSpec<Object>> anims;
  final double frameSize;
  final Offset anchor;
  final double pixelRatio;
  final List<String> facings;

  /// Custom painter for non-humanoids (Grizzlefang).
  void Function(Canvas c, Offset feet, Object pose, bool back)? customDraw;
}

// ---------------------------------------------------------------------------
// Ranger
// ---------------------------------------------------------------------------

Map<String, AnimSpec<Pose>> rangerAnims(HumanoidLook look) => {
  'idle': AnimSpec(6, 6, true, (t, f) {
    return _idle(t)
      ..handF = Offset(12 + _wave(t) * 0.5, 21)
      ..aim = 1.05;
  }),
  'walk': AnimSpec(8, 12, true, (t, f) {
    return _walk(t)
      ..handF = Offset(12 + _wave(t) * 2, 19)
      ..aim = 1.0;
  }),
  'shoot': AnimSpec(5, 16, false, (t, f) {
    const draws = [0.35, 0.75, 1.0, 0.0, 0.0];
    return Pose()
      ..planted = true
      ..footFx = -5
      ..footBx = 9
      ..crouch = 1.5
      ..lean = f == 3 ? -0.06 : 0.02
      ..handF = const Offset(19, -3)
      ..aim = f == 4 ? 0.12 : 0.0
      ..draw = draws[f]
      ..arrowNocked = f < 3
      ..farHandOnString = true
      ..face = 'focus'
      ..cloakSway = f == 3 ? 0.5 : 0.2;
  }, events: {'release': 3}),
  'charge': AnimSpec(4, 10, true, (t, f) {
    // Precision Shot: holding a full draw, trembling slightly.
    return Pose()
      ..planted = true
      ..footFx = -6
      ..footBx = 10
      ..crouch = 3
      ..lean = 0.04
      ..handF = Offset(19, -3 + (f.isEven ? 0.4 : -0.4))
      ..aim = 0
      ..draw = 1
      ..arrowNocked = true
      ..farHandOnString = true
      ..face = 'focus'
      ..glow = 0.6
      ..glowColor = hex(0xfff3a0)
      ..cloakSway = 0.3 + _wave(t) * 0.1;
  }),
  'volley': AnimSpec(6, 14, false, (t, f) {
    const draws = [0.3, 0.6, 0.9, 1.0, 0.0, 0.0];
    return Pose()
      ..planted = true
      ..footFx = -6
      ..footBx = 9
      ..crouch = 2
      ..lean = -0.14
      ..handF = Offset.fromDirection(-1.05, 21)
      ..aim = -1.05
      ..draw = draws[f]
      ..arrowNocked = f < 4
      ..farHandOnString = true
      ..face = 'angry'
      ..cloakSway = 0.4;
  }, events: {'release': 4}),
  'cast': AnimSpec(6, 12, false, (t, f) {
    // Vine Trap: lob a glowing seed with the far hand.
    const arm = [-0.9, -1.6, -1.2, 0.6, 1.3, 0.8];
    return Pose()
      ..planted = true
      ..footFx = -6
      ..footBx = 8
      ..crouch = f >= 3 ? 3 : 1
      ..lean = f >= 3 ? 0.18 : -0.08
      ..handF = const Offset(6, 20)
      ..aim = 0.6
      ..armB = arm[f]
      ..elbowB = f < 3 ? 1.2 : 0.3
      ..glow = f < 4 ? 0.8 : 0.2
      ..glowColor = hex(0x8bff5a)
      ..face = 'angry'
      ..cloakSway = 0.3;
  }, events: {'release': 3}),
  'dodge': AnimSpec(6, 16, false, (t, f) {
    final tt = (f + 0.5) / 6;
    return Pose()
      ..groundFeet = false
      ..legF = 1.25
      ..legB = 1.0
      ..kneeF = 2.1
      ..kneeB = 1.9
      ..handF = const Offset(8, 8)
      ..aim = 1.2
      ..armB = 0.8
      ..rotation = -math.pi * 2 * tt
      ..lift = -math.sin(math.pi * tt) * 26 + 6
      ..face = 'focus'
      ..cloakSway = 0.6;
  }),
  'hit': AnimSpec(
    3,
    12,
    false,
    (t, f) => _hit(f / 2)
      ..handF = const Offset(10, 14)
      ..aim = 0.6,
  ),
  'death': AnimSpec(7, 10, false, (t, f) => _death(f / 6, look)..handF = null),
};

HumanoidLook leafwardenLook() => HumanoidLook(
  skin: hex(0xf2c9a0),
  hair: hex(0x8a4b22),
  tunic: hex(0x5b8f3a),
  tunicTrim: hex(0xd9b45a),
  pants: hex(0x6b4a2e),
  boots: hex(0x4a3020),
  belt: hex(0x7a4e2b),
  gloves: hex(0x7a4e2b),
  cloak: hex(0x3f8a3a),
  cloakTrim: hex(0x6fcf4a),
  eyeColor: hex(0x2f8a4f),
  hairStyle: 'long_wavy',
  ears: 'elf',
  headgear: 'hood_down',
  headgearColor: hex(0x3f8a3a),
  weapon: 'bow',
  back: 'quiver',
);

HumanoidLook wildheartLook() => HumanoidLook(
  skin: hex(0xe8b48a),
  hair: hex(0xa8562a),
  tunic: hex(0x4f7a33),
  tunicTrim: hex(0xe7d6b0),
  pants: hex(0x5e4630),
  boots: hex(0x4a3020),
  belt: hex(0x7a4e2b),
  gloves: hex(0x6b4426),
  cloak: hex(0xd8c6a0),
  cloakTrim: hex(0xb06a3a),
  eyeColor: hex(0x3a8f5a),
  hairStyle: 'wild',
  ears: 'human',
  headgear: 'feathers',
  weapon: 'bow',
  back: 'quiver',
);

// ---------------------------------------------------------------------------
// Goblins
// ---------------------------------------------------------------------------

HumanoidLook goblinLook({
  required Color tunic,
  String headgear = 'none',
  Color? headgearColor,
  String weapon = 'club',
  double bulk = 1,
  double scale = 1,
  bool robe = false,
}) => HumanoidLook(
  headR: 16 * scale,
  torsoH: 17 * scale,
  torsoW: 19 * scale,
  hipW: 17 * scale,
  legLen: 17 * scale,
  armLen: 19 * scale,
  limbW: 6.5 * scale,
  skin: hex(0x7dbb3f),
  hair: hex(0x2f2a22),
  tunic: tunic,
  tunicTrim: shade(tunic, -0.25),
  pants: hex(0x6b4a2e),
  boots: hex(0x4a3a28),
  belt: hex(0x5a3a1e),
  eyeColor: hex(0xffd23f),
  hairStyle: 'none',
  ears: 'goblin',
  headgear: headgear,
  headgearColor: headgearColor,
  weapon: weapon,
  nose: 'goblin',
  fangs: true,
  hunch: 0.12,
  bulk: bulk,
  robe: robe,
);

Map<String, AnimSpec<Pose>> goblinMeleeAnims(HumanoidLook look, {bool heavy = false}) => {
  'idle': AnimSpec(
    6,
    6,
    true,
    (t, f) => _idle(t)
      ..footFx = -4
      ..footBx = 6
      ..handF = Offset(6, 3 + _wave(t))
      ..swing = -1.45 + _wave(t) * 0.05
      ..face = f == 3 ? 'happy' : 'normal',
  ),
  'walk': AnimSpec(
    8,
    12,
    true,
    (t, f) => _walk(t, stride: 0.6, lean: 0.12)
      ..handF = Offset(6, 3 + _wave(t) * 2)
      ..swing = -1.35 + _wave(t) * 0.1,
  ),
  'attack': AnimSpec(6, heavy ? 11 : 14, false, (t, f) {
    const swing = [-0.8, -1.7, -1.2, 1.9, 2.0, 0.8];
    const hand = [Offset(2, -6), Offset(-4, -12), Offset(4, -10), Offset(18, 6), Offset(16, 10), Offset(10, 10)];
    return Pose()
      ..planted = true
      ..footFx = -5
      ..footBx = 8
      ..crouch = f >= 3 && f <= 4 ? 3 : 0
      ..lean = f < 3 ? -0.15 : (f < 5 ? 0.3 : 0.1)
      ..handF = hand[f]
      ..swing = swing[f]
      ..armB = f < 3 ? 0.5 : -0.4
      ..face = 'angry';
  }, events: {'hit': 3}),
  if (heavy)
    'slam': AnimSpec(8, 11, false, (t, f) {
      const up = [0.0, 0.4, 0.8, 1.0, 0.2, 0.0, 0.0, 0.0];
      final u = up[f];
      return Pose()
        ..planted = true
        ..footFx = -7
        ..footBx = 9
        ..crouch = f >= 4 && f <= 5 ? 6 : 0
        ..bodyY = -u * 3
        ..lean = f >= 4 && f <= 5 ? 0.35 : -0.2 * u
        ..handF = f >= 4 && f <= 5 ? const Offset(20, 14) : Offset(2, -18 * u - 2)
        ..handB = f >= 4 && f <= 5 ? const Offset(14, 16) : Offset(-2, -18 * u)
        ..swing = f >= 4 && f <= 5 ? 2.2 : -1.6 * u
        ..face = 'angry';
    }, events: {'hit': 4}),
  'hit': AnimSpec(3, 12, false, (t, f) => _hit(f / 2)..handF = const Offset(8, 10)),
  'death': AnimSpec(7, 10, false, (t, f) => _death(f / 6, look)),
};

Map<String, AnimSpec<Pose>> goblinSlingerAnims(HumanoidLook look) => {
  'idle': AnimSpec(
    6,
    6,
    true,
    (t, f) => _idle(t)
      ..handF = Offset(8, 12 + _wave(t))
      ..swing = _wave(t) * 0.4,
  ),
  'walk': AnimSpec(
    8,
    12,
    true,
    (t, f) => _walk(t, stride: 0.6, lean: 0.12)
      ..handF = Offset(8, 10 + _wave(t) * 2)
      ..swing = _wave(t) * 0.5,
  ),
  'attack': AnimSpec(6, 14, false, (t, f) {
    // Whirl overhead twice, release on frame 4.
    final whirl = f < 4 ? f * math.pi * 0.95 : math.pi * 0.3;
    return Pose()
      ..planted = true
      ..footFx = -4
      ..footBx = 8
      ..lean = f == 4 ? 0.25 : -0.05
      ..handF = f < 4 ? const Offset(4, -16) : const Offset(18, -4)
      ..swing = whirl
      ..draw = f < 4 ? 1 : 0
      ..armB = 0.4
      ..face = 'angry';
  }, events: {'release': 4}),
  'hit': AnimSpec(3, 12, false, (t, f) => _hit(f / 2)),
  'death': AnimSpec(7, 10, false, (t, f) => _death(f / 6, look)),
};

Map<String, AnimSpec<Pose>> goblinShamanAnims(HumanoidLook look) => {
  'idle': AnimSpec(
    6,
    6,
    true,
    (t, f) => _idle(t)
      ..handF = Offset(21, 11 + _wave(t))
      ..swing = 0.22
      ..glow = 0.2 + _wave(t) * 0.1,
  ),
  'walk': AnimSpec(
    8,
    10,
    true,
    (t, f) => _walk(t, stride: 0.5, lean: 0.1)
      ..handF = Offset(21, 10 + _wave(t) * 2)
      ..swing = 0.22 + _wave(t) * 0.08
      ..glow = 0.2,
  ),
  'cast': AnimSpec(6, 10, false, (t, f) {
    const raise = [0.2, 0.6, 1.0, 1.0, 0.4, 0.1];
    final r = raise[f];
    return Pose()
      ..planted = true
      ..footFx = -5
      ..footBx = 7
      ..lean = -0.12 * r + (f == 4 ? 0.2 : 0)
      ..handF = Offset(20 + (f == 4 ? 6 : 0), 8 - 22 * r)
      ..handB = Offset(-2, -8 - 10 * r)
      ..swing = 0.22
      ..glow = 0.3 + r * 0.9
      ..face = 'angry';
  }, events: {'release': 4}),
  'hit': AnimSpec(3, 12, false, (t, f) => _hit(f / 2)),
  'death': AnimSpec(7, 10, false, (t, f) => _death(f / 6, look)),
};

// ---------------------------------------------------------------------------
// NPCs
// ---------------------------------------------------------------------------

Map<String, AnimSpec<Pose>> npcAnims(HumanoidLook look, {Offset hand = const Offset(9, 12)}) => {
  'idle': AnimSpec(
    6,
    5,
    true,
    (t, f) => _idle(t, sway: 0.2)
      ..handF = hand + Offset(0, _wave(t) * 0.6)
      ..face = 'normal',
  ),
  'talk': AnimSpec(
    6,
    8,
    true,
    (t, f) => _idle(t, sway: 0.2)
      ..handF = hand + Offset(0, _wave(t) * 0.6)
      ..armB = 0.6 + _wave(t * 2) * 0.5
      ..elbowB = 0.8
      ..headTilt = _wave(t) * 0.06
      ..face = f.isEven ? 'happy' : 'normal',
  ),
};

HumanoidLook brambleLook() => HumanoidLook(
  skin: hex(0xe8b48a),
  hair: hex(0x8a6a4a),
  tunic: hex(0x2e6fb5),
  tunicTrim: hex(0xffd36b),
  pants: hex(0x5d6670),
  boots: hex(0x3a2a1a),
  belt: hex(0x5a3a1e),
  eyeColor: hex(0x3a5a8a),
  hairStyle: 'short',
  headgear: 'helmet',
  headgearColor: hex(0xb8c2cc),
  weapon: 'spear',
  beard: 'mustache',
  nose: 'round',
  bulk: 1.12,
);

HumanoidLook hildaLook() => HumanoidLook(
  headR: 17,
  torsoH: 22,
  torsoW: 28,
  hipW: 24,
  legLen: 20,
  armLen: 21,
  limbW: 9,
  skin: hex(0xf0bf98),
  hair: hex(0xd9622b),
  tunic: hex(0x8a5a3a),
  tunicTrim: hex(0x5a3a1e),
  pants: hex(0x4a4f57),
  boots: hex(0x2a2018),
  belt: hex(0x3a2a1a),
  eyeColor: hex(0x6a4a2a),
  hairStyle: 'braids',
  headgear: 'none',
  weapon: 'hammer',
  beard: 'braided',
  nose: 'round',
  bulk: 1.1,
);

HumanoidLook pipLook() => HumanoidLook(
  headR: 16,
  torsoH: 19,
  torsoW: 20,
  hipW: 19,
  legLen: 17,
  armLen: 18,
  limbW: 7,
  skin: hex(0xf2c9a0),
  hair: hex(0xc98a3a),
  tunic: hex(0xc0392b),
  tunicTrim: hex(0xffd36b),
  pants: hex(0x6b5a3a),
  boots: hex(0x5a3a1e),
  belt: hex(0x5a3a1e),
  eyeColor: hex(0x4a7a3a),
  hairStyle: 'short',
  back: 'backpack',
  nose: 'round',
);

HumanoidLook grannyLook() => HumanoidLook(
  headR: 16,
  torsoH: 22,
  torsoW: 22,
  hipW: 24,
  legLen: 22,
  armLen: 20,
  limbW: 7,
  skin: hex(0xe8c0a0),
  hair: hex(0xdedede),
  tunic: hex(0x6a4a8a),
  tunicTrim: hex(0x4fc9a2),
  pants: hex(0x4a3a5a),
  boots: hex(0x3a2a1a),
  eyeColor: hex(0x5a5a8a),
  hairStyle: 'gray_bun',
  headgear: 'kerchief',
  headgearColor: hex(0x3f8a3a),
  weapon: 'basket',
  robe: true,
  hunch: 0.1,
  nose: 'round',
);

// ---------------------------------------------------------------------------
// Catalogue
// ---------------------------------------------------------------------------

List<CharacterSpec> allCharacters() {
  final leaf = leafwardenLook();
  final wild = wildheartLook();
  final grunt = goblinLook(tunic: hex(0x8a5a3b), headgear: 'none', weapon: 'club');
  final slinger = goblinLook(tunic: hex(0x6b7f3a), headgear: 'bandana', headgearColor: hex(0xc0392b), weapon: 'sling');
  final shaman = goblinLook(tunic: hex(0x6a3f8a), headgear: 'skull_mask', weapon: 'staff', robe: true);
  final snag = goblinLook(tunic: hex(0x5d6670), headgear: 'horned_helmet', headgearColor: hex(0x7d8590), weapon: 'cleaver', bulk: 1.25, scale: 1.55);
  return [
    CharacterSpec(id: 'ranger_leafwarden', look: leaf, anims: rangerAnims(leaf), frameSize: 176, anchor: const Offset(88, 148)),
    CharacterSpec(id: 'ranger_wildheart', look: wild, anims: rangerAnims(wild), frameSize: 176, anchor: const Offset(88, 148)),
    CharacterSpec(id: 'goblin_grunt', look: grunt, anims: goblinMeleeAnims(grunt), frameSize: 144, anchor: const Offset(72, 124)),
    CharacterSpec(id: 'goblin_slinger', look: slinger, anims: goblinSlingerAnims(slinger), frameSize: 144, anchor: const Offset(72, 124)),
    CharacterSpec(id: 'goblin_shaman', look: shaman, anims: goblinShamanAnims(shaman), frameSize: 144, anchor: const Offset(72, 124)),
    CharacterSpec(id: 'warboss_snagtooth', look: snag, anims: goblinMeleeAnims(snag, heavy: true), frameSize: 224, anchor: const Offset(112, 196)),
    CharacterSpec(
      id: 'npc_bramble',
      look: brambleLook(),
      anims: npcAnims(brambleLook(), hand: const Offset(10, 6)),
      frameSize: 160,
      anchor: const Offset(80, 136),
      facings: const ['front'],
    ),
    CharacterSpec(
      id: 'npc_hilda',
      look: hildaLook(),
      anims: npcAnims(hildaLook(), hand: const Offset(15, 13)),
      frameSize: 160,
      anchor: const Offset(80, 136),
      facings: const ['front'],
    ),
    CharacterSpec(id: 'npc_pip', look: pipLook(), anims: npcAnims(pipLook()), frameSize: 160, anchor: const Offset(80, 136), facings: const ['front']),
    CharacterSpec(
      id: 'npc_granny',
      look: grannyLook(),
      anims: npcAnims(grannyLook(), hand: const Offset(8, 16)),
      frameSize: 160,
      anchor: const Offset(80, 136),
      facings: const ['front'],
    ),
    grizzlefangSpec(),
  ];
}

// ---------------------------------------------------------------------------
// Sheet packing
// ---------------------------------------------------------------------------

Future<void> generateCharacters(String outDir, {Set<String> only = const {}}) async {
  for (final spec in allCharacters()) {
    if (only.isNotEmpty && !only.contains(spec.id)) continue;
    await _generateSheet(spec, outDir);
  }
}

/// Approximate standing height in world pixels (feet to top of head/hat).
double _visualHeight(HumanoidLook k) {
  final extra = switch (k.headgear) {
    'horned_helmet' => k.headR * 0.9,
    'helmet' || 'skull_mask' => k.headR * 0.5,
    _ => k.headR * 0.15,
  };
  return (k.legLen + k.torsoH + k.headR * 1.85 + extra).roundToDouble();
}

Future<void> _generateSheet(CharacterSpec spec, String outDir) async {
  final pr = spec.pixelRatio;
  final cell = (spec.frameSize * pr).round();
  // Flat frame list.
  final frames = <(String anim, String facing, int index)>[];
  final table = <String, Map<String, Object>>{};
  for (final entry in spec.anims.entries) {
    final info = <String, Object>{'fps': entry.value.fps, 'loop': entry.value.loop};
    if (entry.value.events.isNotEmpty) info['events'] = entry.value.events;
    for (final facing in spec.facings) {
      info[facing] = [frames.length, entry.value.frames];
      for (var i = 0; i < entry.value.frames; i++) {
        frames.add((entry.key, facing, i));
      }
    }
    table[entry.key] = info;
  }
  final maxCols = (4096 / cell).floor();
  final columns = math.min(maxCols, frames.length);
  final rows = (frames.length / columns).ceil();
  if (rows * cell > 4096) {
    throw StateError('${spec.id}: sheet too tall (${rows * cell}px); reduce frames or pixel ratio');
  }
  final sheet = await renderImage(columns * cell, rows * cell, (c) {
    for (var i = 0; i < frames.length; i++) {
      final (anim, facing, index) = frames[i];
      final a = spec.anims[anim]!;
      final t = a.frames <= 1 ? 0.0 : index / a.frames;
      final pose = a.pose(t, index);
      c.save();
      c.translate((i % columns) * cell.toDouble(), (i ~/ columns) * cell.toDouble());
      c.clipRect(Rect.fromLTWH(0, 0, cell.toDouble(), cell.toDouble()));
      c.scale(pr);
      if (spec.customDraw != null) {
        spec.customDraw!(c, spec.anchor, pose, facing == 'back');
      } else {
        drawHumanoid(c, spec.anchor, spec.look!, pose as Pose, back: facing == 'back');
      }
      c.restore();
    }
  });
  await savePng(sheet, '$outDir/${spec.id}.png');
  final meta = {
    'image': '${spec.id}.png',
    'frameWidth': cell,
    'frameHeight': cell,
    'columns': columns,
    'pixelRatio': pr,
    'anchor': [spec.anchor.dx * pr, spec.anchor.dy * pr],
    'visualHeight': spec.look == null ? 236 : _visualHeight(spec.look!),
    'facings': spec.facings,
    'animations': table,
  };
  writeText('$outDir/${spec.id}.json', const JsonEncoder.withIndent('  ').convert(meta));

  // Preview strip: every animation's first facing at 1x, labelled by row.
  final previewCols = spec.anims.values.map((a) => a.frames).reduce(math.max);
  final previewRows = spec.anims.length * spec.facings.length;
  final fs = spec.frameSize;
  final preview = await renderImage((previewCols * fs).toInt(), (previewRows * fs).toInt(), (c) {
    c.drawRect(Rect.fromLTWH(0, 0, previewCols * fs, previewRows * fs), Paint()..color = hex(0x5fa845));
    var row = 0;
    for (final entry in spec.anims.entries) {
      for (final facing in spec.facings) {
        for (var i = 0; i < entry.value.frames; i++) {
          final t = entry.value.frames <= 1 ? 0.0 : i / entry.value.frames;
          final pose = entry.value.pose(t, i);
          final origin = Offset(i * fs, row * fs);
          c.drawOval(Rect.fromCenter(center: origin + spec.anchor, width: 40, height: 14), Paint()..color = withAlpha(hex(0x000000), 0.25));
          if (spec.customDraw != null) {
            spec.customDraw!(c, origin + spec.anchor, pose, facing == 'back');
          } else {
            drawHumanoid(c, origin + spec.anchor, spec.look!, pose as Pose, back: facing == 'back');
          }
        }
        row++;
      }
    }
  });
  await savePng(preview, 'build/art_preview/sprite_${spec.id}.png');
}
