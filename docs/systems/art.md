# Art pipeline

Every tile, prop, character sprite and icon is drawn by code in `tool/art/`
(dart:ui canvas, run through `flutter test`). The game only consumes PNGs and
metadata, so any file can later be swapped for hand-made art with no code
changes, as long as the format below is kept.

The exceptions are the hero **concept-art sheets** in
`assets/images/heroes/*.webp` (hand-made, from the vision document). They feed
the hero select screen and the HUD portrait through face crops in
`heroes.json`.

## Running it

```bash
flutter test tool/art/generate_art_test.dart                       # everything
ART=props flutter test tool/art/generate_art_test.dart             # one group
ART=sprites SPRITES=goblin_grunt,grizzlefang flutter test tool/art/generate_art_test.dart
ART=mappreview flutter test tool/art/generate_art_test.dart        # whole-map render
```

| Group | Source | Writes |
| --- | --- | --- |
| `terrain` | `terrain.dart` | `assets/tiles/terrain.png` + `terrain.tsx` (88 Wang tiles) |
| `decor` | `decor.dart` | `assets/tiles/decor.png` + `decor.tsx` |
| `props` | `props.dart` | `assets/tiles/props/<name>.png` + `assets/tiles/props.tsx` |
| `sprites` | `characters.dart`, `rig_humanoid.dart`, `rig_bear.dart` | `assets/images/sprites/<id>.png` + `<id>.json` |
| `icons` | `icons.dart` | `assets/images/icons/<id>.png` |
| `mappreview` | `map_preview.dart` | `build/art_preview/goblinwood_map.png` (not part of the default run) |

Contact sheets for checking the results by eye go to `build/art_preview/`
(git-ignored). Shared drawing helpers (inked outlines, shading, palette) are
in `common.dart` and `iso.dart`.

## Style

Bright cartoon fantasy, matching the concept art: thick dark ink outlines,
two-tone cel shading with a highlight, saturated greens, golds and
oranges, and readable silhouettes at phone size. Characters are about
90 px tall in the world; enemies get distinct silhouettes (club, sling, staff,
cleaver; Grizzlefang's spiked armor).

## Sprite sheets

A sheet is a grid of equal frames plus a JSON file:

```json
{
  "image": "ranger_leafwarden.png",
  "frameWidth": 264, "frameHeight": 264, "columns": 15,
  "pixelRatio": 1.5,
  "anchor": [132.0, 222.0],
  "visualHeight": 90.0,
  "facings": ["front", "back"],
  "animations": {
    "idle":  { "fps": 6,  "loop": true,  "front": [0, 6],  "back": [6, 6] },
    "shoot": { "fps": 16, "loop": false, "events": { "release": 3 }, "front": [28, 5], "back": [33, 5] }
  }
}
```

- Frames are numbered left to right, top to bottom; each animation and facing
  is `[first frame, frame count]`.
- `pixelRatio`: sheet pixels per world pixel (sprites are drawn at higher
  resolution and scaled down).
- `anchor`: the feet inside a frame, in sheet pixels.
- `visualHeight`: standing height in world pixels (health bars, speech
  bubbles, hit sparks).
- Facings: `front` (facing the camera) and `back`; left-facing is the mirror
  image. NPCs only have `front`.
- `events`: frame numbers of moments in an animation. Enemy wind-ups are
  stretched so the `release` frame lands on the hit.

Animations the game uses: `idle`, `walk`, `hit`, `death`, plus whatever the
character's abilities name (`shoot`, `volley`, `cast`, `dodge`, `attack`,
`swipe`, `charge`, `roar`, `slam`...) and `talk` for NPCs.
`GameData.validate()` fails if an ability names an animation its sprite
doesn't have.

## Characters

`characters.dart` lists every sheet in `allCharacters()`. Humanoids use the
rig in `rig_humanoid.dart`:

- `HumanoidLook`: proportions (head, torso, limbs, bulk, scale), colors,
  hair, headgear, cloak, weapon.
- `Pose`: joint angles and offsets for one frame.
- `AnimSpec`: a function from time to pose, sampled into frames, with
  events.

Grizzlefang has his own rig (`rig_bear.dart`). To add an enemy: create a look
(or reuse one with new colors and gear), choose animations, add a
`CharacterSpec`, run `ART=sprites SPRITES=<id>`, and reference the id from
`enemies.json`.

## Props

`props.dart` defines each prop as a `PropDef`: name, image size, `anchorY`,
a draw function and collision metadata (`collision`, `footprint`, `layer`,
`wall`, `walkable`, `emitter`), which becomes the tile properties in
`props.tsx` (see [maps.md](maps.md#props)). Props are drawn at their final
isometric angle with the ground point at `anchorY` above the image bottom.

## Icons

`icons.dart` draws 31 icons (abilities, items, materials, currencies,
interactions and Day Jobs) at 128×128. Content refers to them by file name
(`"icon": "ability_vine_trap"`).

## Tips

- Generated PNGs use premultiplied alpha. When writing raw pixels, multiply
  color by alpha, or edges get white seams.
- Keep each frame's content inside its cell; poses that reach outside (death
  falls, big swings) get clipped. Enlarge `frameSize` instead.
- After regenerating sprites or props, run `flutter test`: the content test
  checks animations, and the game tests load every prop the map uses.
