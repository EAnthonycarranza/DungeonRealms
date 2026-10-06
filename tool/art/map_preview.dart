// Renders a downscaled preview of a Tiled map (ground + decor + props) so the
// layout can be reviewed without launching the game.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'common.dart';

Future<void> renderMapPreview(String tmxPath, String outPath, {double scale = 0.25}) async {
  final xml = File(tmxPath).readAsStringSync();
  final w = int.parse(RegExp(r'<map [^>]*? width="(\d+)"').firstMatch(xml)!.group(1)!);
  final h = int.parse(RegExp(r'<map [^>]*? height="(\d+)"').firstMatch(xml)!.group(1)!);
  final tilesets = [for (final m in RegExp(r'<tileset firstgid="(\d+)" source="([^"]+)"/>').allMatches(xml)) (int.parse(m.group(1)!), m.group(2)!)];
  final dir = File(tmxPath).parent.path;

  // Atlas tilesets (terrain/decor) and image collection (props).
  final atlases = <(int first, Image img, int cols, int count)>[];
  final collection = <int, (Image, int, int)>{};
  for (final (first, src) in tilesets) {
    final tsx = File('$dir/$src').readAsStringSync();
    final single = RegExp(r'<tileset [^>]*columns="(\d+)"[^>]*>\s*<grid[^>]*/>\s*<image source="([^"]+)"').firstMatch(tsx);
    final count = int.parse(RegExp(r'tilecount="(\d+)"').firstMatch(tsx)!.group(1)!);
    if (single != null && int.parse(single.group(1)!) > 0) {
      atlases.add((first, await loadImage('$dir/${single.group(2)}'), int.parse(single.group(1)!), count));
    } else {
      for (final m in RegExp(r'<tile id="(\d+)"[^>]*>.*?<image source="([^"]+)" width="(\d+)" height="(\d+)"/>', dotAll: true).allMatches(tsx)) {
        collection[first + int.parse(m.group(1)!)] = (await loadImage('$dir/${m.group(2)}'), int.parse(m.group(3)!), int.parse(m.group(4)!));
      }
    }
  }

  List<List<int>> layer(String name) {
    final m = RegExp('<layer [^>]*name="$name"[^>]*>\\s*<data encoding="csv">(.*?)</data>', dotAll: true).firstMatch(xml)!;
    final values = m.group(1)!.split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty).map(int.parse).toList();
    return List.generate(h, (j) => values.sublist(j * w, (j + 1) * w));
  }

  final ground = layer('ground');
  final decor = layer('decor');
  final objects = [
    for (final m in RegExp(r'<object [^>]*gid="(\d+)" x="([\d.]+)" y="([\d.]+)"').allMatches(xml))
      (int.parse(m.group(1)!), double.parse(m.group(2)!), double.parse(m.group(3)!)),
  ];
  final markers = [
    for (final m in RegExp(r'<object id="\d+" name="([^"]*)" type="(npc|player_start|spawn|boss_spawn)" x="([\d.]+)" y="([\d.]+)"').allMatches(xml))
      (m.group(2)!, double.parse(m.group(3)!), double.parse(m.group(4)!)),
  ];

  final pw = ((w + h) * 64 * scale).ceil(), ph = ((w + h) * 32 * scale + 400 * scale).ceil();
  Offset project(double wx, double wy) => Offset((wx - wy) * 64 + h * 64, (wx + wy) * 32 + 300);

  void drawGid(Canvas c, int gid, Offset center) {
    for (final (first, img, cols, count) in atlases) {
      if (gid >= first && gid < first + count) {
        final id = gid - first;
        final src = Rect.fromLTWH((id % cols) * 128.0, (id ~/ cols) * 64.0, 128, 64);
        c.drawImageRect(img, src, Rect.fromCenter(center: center, width: 128, height: 64), Paint()..filterQuality = FilterQuality.medium);
        return;
      }
    }
  }

  final image = await renderImage(pw, ph, (c) {
    c.drawRect(Rect.fromLTWH(0, 0, pw.toDouble(), ph.toDouble()), Paint()..color = hex(0x0b0f16));
    c.scale(scale);
    for (var j = 0; j < h; j++) {
      for (var i = 0; i < w; i++) {
        final center = project(i + 0.5, j + 0.5);
        drawGid(c, ground[j][i], center);
        if (decor[j][i] != 0) drawGid(c, decor[j][i], center);
      }
    }
    final sorted = [...objects]..sort((a, b) => (a.$2 + a.$3).compareTo(b.$2 + b.$3));
    for (final (gid, x, y) in sorted) {
      final entry = collection[gid];
      if (entry == null) continue;
      final (img, iw, ih) = entry;
      final bottom = project(x / 64, y / 64);
      c.drawImage(img, bottom - Offset(iw / 2, ih.toDouble()), Paint());
    }
    for (final (type, x, y) in markers) {
      final p = project(x / 64, y / 64);
      final color = switch (type) {
        'npc' => hex(0x4fd4ff),
        'player_start' => hex(0xffffff),
        'boss_spawn' => hex(0xff2d2d),
        _ => hex(0xff8a2b),
      };
      c.drawCircle(p, 40, Paint()..color = color);
      c.drawCircle(
        p,
        40,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = hex(0x000000),
      );
    }
  });
  await savePng(image, outPath);
  // ignore: avoid_print
  print('map preview ${math.max(pw, ph)}px -> $outPath');
}
