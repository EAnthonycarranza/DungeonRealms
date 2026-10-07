import 'package:flutter/material.dart';

import '../../content/game_data.dart';
import '../../game/dungeon_realms_game.dart';
import '../panels/panel_host.dart';
import '../theme.dart';
import 'announcements.dart';
import 'hero_frame.dart';
import 'quest_tracker.dart';
import 'skill_bar.dart';
import 'top_bars.dart';
import 'touch_controls.dart';

/// Everything drawn over the game while playing.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.game, required this.panels});

  final DungeonRealmsGame game;
  final PanelController panels;

  @override
  Widget build(BuildContext context) {
    final s = game.session;
    final hud = LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxHeight < 560 || c.maxWidth < 820;
        final clusterScale = compact ? (c.maxHeight / 560).clamp(0.72, 1.0) : 1.0;
        final barWidth = (c.maxWidth * 0.46).clamp(260.0, 560.0);
        return ValueListenableBuilder<bool>(
          valueListenable: game.input.touch,
          builder: (_, touch, _) => Stack(
            children: [
              if (touch)
                Positioned(
                  left: 0,
                  top: c.maxHeight * 0.32,
                  bottom: 0,
                  width: c.maxWidth * 0.45,
                  child: VirtualJoystick(input: game.input),
                ),
              Positioned(
                left: 12,
                top: 10,
                child: SafeArea(
                  child: HeroFrame(game: game, compact: compact),
                ),
              ),
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BossBar(session: s, width: barWidth),
                        EventBar(session: s, width: barWidth),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 12,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _MenuButtons(panels: panels, showKeys: !touch),
                      const SizedBox(height: 10),
                      if (!compact || !touch) QuestTracker(session: s, maxQuests: compact ? 2 : 3, onTap: () => panels.open(PanelKind.quests)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: c.maxHeight * (compact ? 0.16 : 0.2),
                child: Center(child: BannerView(session: s)),
              ),
              Positioned(
                left: 14,
                bottom: touch ? 210 * clusterScale + 40 : 120,
                child: ToastList(session: s),
              ),
              if (touch) ...[
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: TouchActionCluster(game: game, scale: clusterScale),
                ),
                Positioned(
                  right: 24,
                  bottom: 280 * clusterScale,
                  child: InteractButton(game: game),
                ),
              ] else
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DesktopPrompt(game: game),
                        const SizedBox(height: 10),
                        DesktopSkillBar(game: game),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // Controls and readouts keep clear of notches and the home indicator.
        SafeArea(child: hud),
        ValueListenableBuilder<bool>(
          valueListenable: s.loading,
          builder: (_, loading, _) => loading ? _LoadingOverlay(region: game.data.region(game.profile.region)) : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _MenuButtons extends StatelessWidget {
  const _MenuButtons({required this.panels, required this.showKeys});

  final PanelController panels;
  final bool showKeys;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, PanelKind kind) => Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tip,
        child: Material(
          color: const Color(0xcc0b0f18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: DR.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => panels.open(kind),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: DR.gold, size: 24),
            ),
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.backpack_rounded, showKeys ? 'Inventory (I)' : 'Inventory', PanelKind.inventory),
        button(Icons.menu_book_rounded, showKeys ? 'Quests (L)' : 'Quests', PanelKind.quests),
        button(Icons.pause_rounded, showKeys ? 'Menu (Esc)' : 'Menu', PanelKind.pause),
      ],
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.region});

  final RegionDef region;

  @override
  Widget build(BuildContext context) => Container(
    color: DR.bg,
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('ENTERING ${region.name.toUpperCase()}', style: DR.title(30, color: DR.gold)),
        const SizedBox(height: 16),
        const SizedBox(
          width: 220,
          child: LinearProgressIndicator(color: DR.gold, backgroundColor: DR.panel),
        ),
        const SizedBox(height: 14),
        if (region.loadingTips.isNotEmpty)
          Text('Tip: ${region.loadingTips[DateTime.now().second % region.loadingTips.length]}', style: DR.body(14, color: DR.muted)),
      ],
    ),
  );
}
