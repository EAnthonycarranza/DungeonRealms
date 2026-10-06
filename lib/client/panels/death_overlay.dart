import 'package:flutter/material.dart';

import '../../game/dungeon_realms_game.dart';
import '../theme.dart';

class DeathOverlay extends StatelessWidget {
  const DeathOverlay({super.key, required this.game});

  final DungeonRealmsGame game;

  @override
  Widget build(BuildContext context) {
    final death = game.session.death.value;
    return Container(
      decoration: const BoxDecoration(gradient: RadialGradient(colors: [Color(0x66300808), Color(0xdd070308)], radius: 1.1)),
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.scale(scale: 0.9 + v * 0.1, child: child),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('YOU DIED', style: DR.title(64, color: DR.red)),
            const SizedBox(height: 10),
            if (death != null) ...[
              Text('Defeated by ${death.killer}', style: DR.body(18, weight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(death.quip, style: DR.body(15, color: DR.muted)),
            ],
            const SizedBox(height: 26),
            GoldButton(label: 'Respawn at waypoint', icon: Icons.replay_rounded, onPressed: game.respawn),
          ],
        ),
      ),
    );
  }
}
