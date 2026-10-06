import 'package:flutter/material.dart';

import '../../game/dungeon_realms_game.dart';
import '../../game/input.dart';
import '../../game/session.dart';
import '../theme.dart';
import 'skill_button.dart';

/// Desktop/web action bar with key hints. Buttons are clickable too.
class DesktopSkillBar extends StatelessWidget {
  const DesktopSkillBar({super.key, required this.game});

  final DungeonRealmsGame game;

  @override
  Widget build(BuildContext context) {
    final s = game.session;
    const size = 58.0;
    final basic = game.data.abilities[game.data.heroes[game.profile.heroClass]!.basicAbility];
    Widget slot(AbilitySlotId id, String key) => ListenableBuilder(
      listenable: Listenable.merge([s.abilities, s.dodge, s.ultimateCharge]),
      builder: (_, _) {
        final hud = id == AbilitySlotId.dodge ? s.dodge.value : s.abilities.value.where((a) => a.slot == id).firstOrNull;
        return Tooltip(
          message: hud == null ? '' : '${hud.name}\n${hud.description}',
          waitDuration: const Duration(milliseconds: 400),
          child: GestureDetector(
            onTap: () => game.input.requestAbility(AbilityRequest(id, aimWorld: game.input.mouseWorld)),
            child: SkillButtonFace(hud: hud, size: size, keyLabel: key, charge: hud?.isUltimate == true ? s.ultimateCharge.value : null),
          ),
        );
      },
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: DR.panelBox(radius: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: '${basic?.name ?? 'Attack'}\nHold left mouse (or J) to fire at the cursor.',
            child: SkillButtonFace(hud: null, size: size, keyLabel: 'LMB', iconOverride: basic?.icon),
          ),
          const SizedBox(width: 10),
          slot(AbilitySlotId.skill1, 'Q'),
          const SizedBox(width: 10),
          slot(AbilitySlotId.skill2, 'E'),
          const SizedBox(width: 10),
          slot(AbilitySlotId.skill3, 'R'),
          const SizedBox(width: 10),
          slot(AbilitySlotId.ultimate, 'F'),
          Container(width: 1, height: 44, margin: const EdgeInsets.symmetric(horizontal: 12), color: DR.line),
          slot(AbilitySlotId.dodge, 'SPC'),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => game.input.requestPotion(),
            child: ValueListenableBuilder<(int, int, double)>(
              valueListenable: s.potion,
              builder: (_, p, _) =>
                  SkillButtonFace(hud: null, size: size, keyLabel: 'H', iconOverride: game.data.potion.icon, badge: '${p.$1}', pressed: p.$3 > 0),
            ),
          ),
        ],
      ),
    );
  }
}

/// "[G] Talk" prompt for keyboard players.
class DesktopPrompt extends StatelessWidget {
  const DesktopPrompt({super.key, required this.game});

  final DungeonRealmsGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InteractPrompt?>(
      valueListenable: game.session.prompt,
      builder: (_, p, _) => AnimatedOpacity(
        opacity: p == null ? 0 : 1,
        duration: const Duration(milliseconds: 150),
        child: p == null
            ? const SizedBox(height: 36)
            : GestureDetector(
                onTap: () => game.input.requestInteract(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: DR.panelBox(radius: 12, border: DR.gold.withValues(alpha: 0.5)),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '[G]  ',
                          style: DR.body(15, color: DR.gold, weight: FontWeight.w900),
                        ),
                        TextSpan(
                          text: p.label,
                          style: DR.body(15, weight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
