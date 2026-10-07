// Procedural art generator for Dungeon Realms.
//
// Run from the repository root:
//   flutter test tool/art/generate_art_test.dart
// Optionally limit what is generated (comma separated):
//   ART=terrain,props flutter test tool/art/generate_art_test.dart
//
// Groups: terrain, decor, props, sprites, icons, appicon
//
// `appicon` writes the launcher icons into android/, ios/ and web/.
//
// Everything written here is placeholder-quality but production-shaped art:
// the game only consumes PNGs + metadata, so any file can later be replaced by
// hand-made art without code changes. Previews for eyeballing go to
// build/art_preview/ (git-ignored).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'app_icon.dart';
import 'characters.dart';
import 'decor.dart';
import 'icons.dart';
import 'map_preview.dart';
import 'props.dart';
import 'terrain.dart';

void main() {
  final only = (Platform.environment['ART'] ?? '').split(',').where((s) => s.isNotEmpty).toSet();
  bool wants(String group) => only.isEmpty || only.contains(group);

  test('generate art', () async {
    if (wants('terrain')) await generateTerrain('assets/tiles');
    if (wants('decor')) await generateDecor('assets/tiles');
    if (wants('props')) await generateProps('assets/tiles');
    if (wants('sprites')) {
      final ids = (Platform.environment['SPRITES'] ?? '').split(',').where((s) => s.isNotEmpty).toSet();
      await generateCharacters('assets/images/sprites', only: ids);
    }
    if (wants('icons')) await generateIcons('assets/images/icons');
    if (wants('appicon')) await generateAppIcons('.');
    // Not part of the default run: ART=mappreview
    if (only.contains('mappreview')) {
      await renderMapPreview('assets/tiles/goblinwood.tmx', 'build/art_preview/goblinwood_map.png');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
