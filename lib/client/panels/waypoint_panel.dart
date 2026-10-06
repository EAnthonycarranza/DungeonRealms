import 'package:flutter/material.dart';

import '../../game/dungeon_realms_game.dart';
import '../theme.dart';
import '../widgets/art.dart';
import 'panel_host.dart';

/// Fast travel between discovered waypoints.
class WaypointPanel extends StatelessWidget {
  const WaypointPanel({super.key, required this.game});

  final DungeonRealmsGame game;

  void _close() {
    game.session.waypointPicker.value = false;
    game.setPaused(false);
  }

  @override
  Widget build(BuildContext context) {
    final region = game.data.region(game.profile.region);
    return ModalFrame(
      title: 'Waypoints',
      subtitle: '${region.name} • potions refilled',
      accent: DR.blue,
      maxWidth: 520,
      onClose: _close,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        children: [
          for (final wp in region.waypoints)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WaypointRow(
                name: game.profile.waypoints.contains(wp.id) ? wp.name : '???',
                discovered: game.profile.waypoints.contains(wp.id),
                current: game.profile.lastWaypoint == wp.id,
                onTap: () => game.travelTo(wp.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _WaypointRow extends StatelessWidget {
  const _WaypointRow({required this.name, required this.discovered, required this.current, required this.onTap});

  final String name;
  final bool discovered;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x10ffffff),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: discovered && !current ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              IconImage('interact_travel', size: 36, opacity: discovered ? 1 : 0.3),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: DR.body(16, color: discovered ? DR.text : DR.muted, weight: FontWeight.w900),
                ),
              ),
              if (current) Text('You are here', style: DR.body(12, color: DR.blue)),
              if (discovered && !current) const Icon(Icons.chevron_right_rounded, color: DR.blue),
              if (!discovered) Text('Not attuned', style: DR.body(12, color: DR.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
