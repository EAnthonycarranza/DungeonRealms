import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../content/sprite_meta.dart';
import '../../game/dungeon_realms_game.dart';
import '../../game/session.dart';
import '../theme.dart';
import '../widgets/art.dart';

/// NPC conversation: portrait, quest text and choices.
class DialogPanel extends StatelessWidget {
  const DialogPanel({super.key, required this.game, required this.state});

  final DungeonRealmsGame game;
  final DialogState state;

  @override
  Widget build(BuildContext context) {
    final npc = state.npc;
    final color = Color(0xff000000 | int.parse(npc.color.replaceFirst('#', ''), radix: 16));
    final meta = game.data.sprites[npc.sprite];
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: game.closeDialog,
            child: Container(color: const Color(0x66050710)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 18, 16),
                  decoration: DR.panelBox(radius: 22, border: color.withValues(alpha: 0.5)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (meta != null)
                        Container(
                          width: 104,
                          height: 120,
                          margin: const EdgeInsets.only(right: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: RadialGradient(colors: [color.withValues(alpha: 0.35), const Color(0x00000000)]),
                          ),
                          child: _SpriteFrame(meta: meta),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: npc.name,
                                    style: DR.title(22, color: color),
                                  ),
                                  TextSpan(
                                    text: '   ${npc.title}',
                                    style: DR.body(13, color: DR.muted),
                                  ),
                                ],
                              ),
                            ),
                            if (state.questName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                state.questName!.toUpperCase(),
                                style: DR.body(12, color: DR.gold, weight: FontWeight.w900),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(state.text, style: DR.body(16, weight: FontWeight.w700)),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                for (final o in state.options)
                                  o.primary
                                      ? GoldButton(label: o.label, compact: true, onPressed: () => game.chooseDialogOption(o.id))
                                      : GhostButton(label: o.label, compact: true, onPressed: () => game.chooseDialogOption(o.id)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws the first idle frame of a character sheet.
class _SpriteFrame extends StatelessWidget {
  const _SpriteFrame({required this.meta});

  final SpriteSheetMeta meta;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: ArtCache.load('assets/images/sprites/${meta.image}'),
      builder: (_, snap) => CustomPaint(painter: _FramePainter(snap.data, meta)),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.image, this.meta);

  final ui.Image? image;
  final SpriteSheetMeta meta;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;
    final idle = meta.anim('idle');
    final index = idle?.frames('front').$1 ?? 0;
    final col = index % meta.columns, row = index ~/ meta.columns;
    final src = Rect.fromLTWH(col * meta.frameWidth.toDouble(), row * meta.frameHeight.toDouble(), meta.frameWidth.toDouble(), meta.frameHeight.toDouble());
    // Fit the character's head and torso into the box.
    final scale = size.height / (meta.frameHeight * 0.62);
    final dst = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 + meta.frameHeight * scale * 0.08),
      width: meta.frameWidth * scale,
      height: meta.frameHeight * scale,
    );
    canvas.clipRect(Offset.zero & size);
    canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.image != image;
}
