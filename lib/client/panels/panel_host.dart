import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/dungeon_realms_game.dart';
import '../theme.dart';
import 'death_overlay.dart';
import 'dialog_panel.dart';
import 'inventory_panel.dart';
import 'pause_panel.dart';
import 'quest_log_panel.dart';
import 'waypoint_panel.dart';

enum PanelKind { none, inventory, quests, pause }

/// Which full-screen panel is open (inventory, quest log, pause menu).
class PanelController extends ChangeNotifier {
  PanelKind current = PanelKind.none;

  void open(PanelKind kind) {
    current = current == kind ? PanelKind.none : kind;
    notifyListeners();
  }

  void close() {
    if (current == PanelKind.none) return;
    current = PanelKind.none;
    notifyListeners();
  }

  /// Keyboard shortcuts for panels. Returns true when handled.
  bool handleKey(LogicalKeyboardKey key, DungeonRealmsGame game) {
    final s = game.session;
    if (key == LogicalKeyboardKey.escape) {
      if (s.dialog.value != null) {
        game.closeDialog();
      } else if (s.waypointPicker.value) {
        s.waypointPicker.value = false;
        game.setPaused(false);
      } else if (s.shop.value != null) {
        s.shop.value = null;
      } else if (current != PanelKind.none) {
        close();
      } else {
        open(PanelKind.pause);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.keyI || key == LogicalKeyboardKey.tab || key == LogicalKeyboardKey.keyB) {
      open(PanelKind.inventory);
      return true;
    }
    if (key == LogicalKeyboardKey.keyL) {
      open(PanelKind.quests);
      return true;
    }
    return false;
  }
}

/// Shows whichever modal UI the game state calls for.
class PanelHost extends StatelessWidget {
  const PanelHost({super.key, required this.game, required this.panels, this.onQuit});

  final DungeonRealmsGame game;
  final PanelController panels;
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) {
    final s = game.session;
    return ListenableBuilder(
      listenable: Listenable.merge([panels, s.dialog, s.waypointPicker, s.shop, s.death]),
      builder: (context, _) {
        Widget? child;
        var pauses = true;
        if (s.death.value != null) {
          child = DeathOverlay(game: game);
          pauses = false;
        } else if (s.dialog.value != null) {
          child = DialogPanel(game: game, state: s.dialog.value!);
          pauses = false; // the dialog pauses itself
        } else if (s.waypointPicker.value) {
          child = WaypointPanel(game: game);
          pauses = false;
        } else if (s.shop.value == 'difficulty') {
          child = DifficultyPanel(game: game, onClose: () => s.shop.value = null);
        } else if (s.shop.value != null) {
          child = InventoryPanel(game: game, mode: s.shop.value!, onClose: () => s.shop.value = null);
        } else {
          switch (panels.current) {
            case PanelKind.inventory:
              child = InventoryPanel(game: game, mode: 'equip', onClose: panels.close);
            case PanelKind.quests:
              child = QuestLogPanel(game: game, onClose: panels.close);
            case PanelKind.pause:
              child = PausePanel(game: game, onClose: panels.close, onQuit: onQuit);
            case PanelKind.none:
              child = null;
          }
        }
        if (pauses) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final shouldPause = child != null;
            if (game.paused != shouldPause && s.dialog.value == null && !s.waypointPicker.value) game.setPaused(shouldPause);
          });
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 160), child: child ?? const SizedBox.shrink());
      },
    );
  }
}

/// Shared chrome for full-screen panels.
class ModalFrame extends StatelessWidget {
  const ModalFrame({super.key, required this.title, required this.child, required this.onClose, this.maxWidth = 980, this.subtitle, this.accent = DR.gold});

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onClose;
  final double maxWidth;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(color: const Color(0xb3050710)),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Container(
                  decoration: DR.panelBox(radius: 22, border: accent.withValues(alpha: 0.35)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 10, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: DR.title(26, color: accent)),
                                  if (subtitle != null) Text(subtitle!, style: DR.body(13, color: DR.muted)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: onClose,
                              icon: const Icon(Icons.close_rounded, color: DR.muted),
                            ),
                          ],
                        ),
                      ),
                      Flexible(child: child),
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

/// Converts a session toast colour or rarity into UI colours.
Color statColor(String stat) => switch (stat) {
  'attack' || 'damageBonus' => DR.orange,
  'maxHp' || 'hpRegen' => DR.red,
  'armor' => DR.blue,
  'critChance' || 'critDamage' => DR.gold,
  'attackSpeed' || 'moveSpeed' || 'cooldownReduction' => DR.green,
  _ => DR.purple,
};
