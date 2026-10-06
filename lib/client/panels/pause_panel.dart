import 'package:flutter/material.dart';

import '../../game/dungeon_realms_game.dart';
import '../theme.dart';
import 'panel_host.dart';

class PausePanel extends StatelessWidget {
  const PausePanel({super.key, required this.game, required this.onClose, this.onQuit});

  final DungeonRealmsGame game;
  final VoidCallback onClose;
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) {
    final p = game.profile;
    final minutes = (p.playSeconds / 60).floor();
    return ModalFrame(
      title: 'Paused',
      subtitle: 'Goblinwood will wait. Probably.',
      onClose: onClose,
      maxWidth: 640,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                GoldButton(label: 'Resume', icon: Icons.play_arrow_rounded, onPressed: onClose),
                ValueListenableBuilder<bool>(
                  valueListenable: game.input.touch,
                  builder: (_, touch, _) => GhostButton(
                    label: touch ? 'Hide touch controls' : 'Show touch controls',
                    icon: Icons.touch_app_rounded,
                    onPressed: () => game.input.touchMode = !touch,
                  ),
                ),
                if (p.unlockedDifficulties(game.data).length > 1)
                  GhostButton(
                    label: 'World difficulty',
                    icon: Icons.local_fire_department_rounded,
                    color: DR.orange,
                    onPressed: () {
                      onClose();
                      game.session.shop.value = 'difficulty';
                    },
                  ),
                GhostButton(
                  label: 'Save & quit',
                  icon: Icons.logout_rounded,
                  onPressed: () async {
                    await game.saveNow();
                    onQuit?.call();
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'STATS',
              style: DR.body(11, color: DR.gold, weight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Level ${p.level} • ${p.kills} goblins (and friends) bonked • ${p.deaths} heroic naps • ${minutes}m played • World: ${game.difficulty.name}',
              style: DR.body(14, color: DR.muted),
            ),
            const SizedBox(height: 16),
            Text(
              'CONTROLS',
              style: DR.body(11, color: DR.gold, weight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const _ControlsTable(
              rows: [
                ('Move', 'WASD / Arrow keys', 'Left thumb joystick'),
                ('Quick Shot', 'Hold left mouse (or J)', 'Hold the big button'),
                ('Skills', 'Q E R, ultimate F (aim with mouse)', 'Tap to auto-aim, drag to aim'),
                ('Backflip', 'Space', 'Dodge button'),
                ('Potion', 'H', 'Potion button'),
                ('Talk / Mine / Open', 'G or Enter', 'Interact button'),
                ('Inventory / Quests', 'I  /  L', 'Top-right buttons'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlsTable extends StatelessWidget {
  const _ControlsTable({required this.rows});

  final List<(String, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(1.6), 2: FlexColumnWidth(1.5)},
      children: [
        TableRow(
          children: [
            Text('', style: DR.body(12)),
            Text('Keyboard & mouse', style: DR.body(12, color: DR.muted)),
            Text('Touch', style: DR.body(12, color: DR.muted)),
          ],
        ),
        for (final (a, b, c) in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(a, style: DR.body(13, weight: FontWeight.w900)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(b, style: DR.body(13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(c, style: DR.body(13)),
              ),
            ],
          ),
      ],
    );
  }
}

/// World difficulty picker ("How spicy are we feeling?").
class DifficultyPanel extends StatelessWidget {
  const DifficultyPanel({super.key, required this.game, required this.onClose});

  final DungeonRealmsGame game;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final unlocked = game.profile.unlockedDifficulties(game.data).map((d) => d.id).toSet();
    return ModalFrame(
      title: 'How spicy are we feeling?',
      subtitle: 'Higher difficulties add mechanics, not just health.',
      accent: DR.orange,
      onClose: onClose,
      maxWidth: 600,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        children: [
          for (final d in game.data.progression.difficulties)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: game.profile.difficulty == d.id ? const Color(0x22ff8a2b) : const Color(0x0dffffff),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: unlocked.contains(d.id)
                      ? () {
                          game.setDifficulty(d.id);
                          onClose();
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${d.icon} ${d.name}',
                                style: DR.body(16, color: unlocked.contains(d.id) ? DR.text : DR.muted, weight: FontWeight.w900),
                              ),
                              Text(
                                '${d.tagline} • enemy health x${d.hp} • damage x${d.damage} • loot +${(d.rarityBonus * 100).round()}%',
                                style: DR.body(12, color: DR.muted),
                              ),
                              for (final m in d.mechanics)
                                Text('• ${game.data.progression.mechanics.firstWhere((x) => x.id == m).description}', style: DR.body(12, color: DR.orange)),
                            ],
                          ),
                        ),
                        if (!unlocked.contains(d.id)) const Icon(Icons.lock_rounded, color: DR.muted),
                        if (game.profile.difficulty == d.id) const Icon(Icons.check_circle_rounded, color: DR.orange),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
