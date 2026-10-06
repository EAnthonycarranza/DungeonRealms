import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../content/game_data.dart';
import '../game/dungeon_realms_game.dart';
import '../game/input.dart';
import '../rules/hero_profile.dart';
import '../services/save_repository.dart';
import 'hud/hud.dart';
import 'panels/panel_host.dart';
import 'theme.dart';

/// Hosts the running game, keyboard/mouse input, the HUD and panels.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.data, required this.profile, required this.saves, this.onQuit});

  final GameData data;
  final HeroProfile profile;
  final SaveRepository saves;
  final VoidCallback? onQuit;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DungeonRealmsGame game = DungeonRealmsGame(data: widget.data, profile: widget.profile, saves: widget.saves);
  final _focus = FocusNode(debugLabel: 'game');

  /// Flame's GameWidget grabs focus on init and reports every key as handled
  /// unless the game mixes in KeyboardEvents. Keys belong to this screen, so
  /// the game widget gets a node that can never take focus.
  final _gameFocus = FocusNode(debugLabel: 'flame', canRequestFocus: false, skipTraversal: true);
  final panels = PanelController();
  bool _mouseDown = false;

  InputState get input => game.input;

  @override
  void initState() {
    super.initState();
    input.touchMode = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void dispose() {
    _focus.dispose();
    _gameFocus.dispose();
    super.dispose();
  }

  Vector2? _screenToWorld(Offset local) {
    if (!game.isLoaded) return null;
    final w = game.camera.globalToLocal(Vector2(local.dx, local.dy));
    return game.iso.toWorld(w.x, w.y);
  }

  // Keyboard ------------------------------------------------------------------

  static final _up = {LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp};
  static final _down = {LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown};
  static final _left = {LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft};
  static final _right = {LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight};

  void _updateMoveFromKeys() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    var x = 0.0, y = 0.0;
    if (pressed.any(_up.contains)) y -= 1;
    if (pressed.any(_down.contains)) y += 1;
    if (pressed.any(_left.contains)) x -= 1;
    if (pressed.any(_right.contains)) x += 1;
    final v = Vector2(x, y);
    if (v.length2 > 0) v.normalize();
    // Keyboard only owns movement when no joystick touch is active.
    if (!input.touchMode || v.length2 > 0) input.move.setFrom(v);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final isMove = _up.contains(key) || _down.contains(key) || _left.contains(key) || _right.contains(key);
    if (isMove) {
      input.touchMode = false;
      _updateMoveFromKeys();
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) {
      if (key == LogicalKeyboardKey.keyJ && event is KeyUpEvent) input.attackHeld = _mouseDown;
      return KeyEventResult.ignored;
    }
    if (panels.handleKey(key, game)) return KeyEventResult.handled;
    final aim = input.mouseWorld;
    AbilitySlotId? slot;
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.keyQ) slot = AbilitySlotId.skill1;
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.keyE) slot = AbilitySlotId.skill2;
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.keyR) slot = AbilitySlotId.skill3;
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.keyF) slot = AbilitySlotId.ultimate;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.shiftLeft) slot = AbilitySlotId.dodge;
    if (slot != null) {
      input.touchMode = false;
      input.requestAbility(AbilityRequest(slot, aimWorld: input.touchMode ? null : aim));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyJ) {
      input.attackHeld = true;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyG || key == LogicalKeyboardKey.enter) {
      input.requestInteract();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH) {
      input.requestPotion();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // Mouse -----------------------------------------------------------------------

  void _onPointer(PointerEvent e) {
    // A finger on the game (e.g. a touch laptop) brings up the touch controls.
    if (e.kind == PointerDeviceKind.touch && e is PointerDownEvent) input.touchMode = true;
    if (e.kind != PointerDeviceKind.mouse) return;
    input.touchMode = false;
    input.mouseWorld = _screenToWorld(e.localPosition);
    if (e is PointerDownEvent) {
      _focus.requestFocus();
      if (e.buttons & kPrimaryMouseButton != 0) {
        _mouseDown = true;
        input.attackHeld = true;
      }
      if (e.buttons & kSecondaryMouseButton != 0 && input.mouseWorld != null) {
        input.requestAbility(AbilityRequest(AbilitySlotId.skill1, aimWorld: input.mouseWorld));
      }
    } else if (e is PointerUpEvent || e is PointerCancelEvent) {
      _mouseDown = false;
      input.attackHeld = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DR.bg,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              onPointerDown: _onPointer,
              onPointerMove: _onPointer,
              onPointerHover: _onPointer,
              onPointerUp: _onPointer,
              onPointerCancel: _onPointer,
              child: MouseRegion(
                cursor: SystemMouseCursors.precise,
                child: GameWidget(game: game, focusNode: _gameFocus, autofocus: false),
              ),
            ),
            Hud(game: game, panels: panels),
            PanelHost(game: game, panels: panels, onQuit: widget.onQuit),
          ],
        ),
      ),
    );
  }
}
