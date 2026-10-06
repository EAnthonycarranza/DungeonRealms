import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../content/game_data.dart';
import '../rules/hero_profile.dart';
import '../rules/items.dart';
import '../services/save_repository.dart';
import 'game_screen.dart';
import 'screens/hero_select_screen.dart';
import 'screens/title_screen.dart';
import 'theme.dart';

/// Root widget: loads content, then routes Title -> Hero Select -> Game.
class DungeonRealmsApp extends StatelessWidget {
  const DungeonRealmsApp({super.key, this.saves, this.quickstart = false});

  final SaveRepository? saves;
  final bool quickstart;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dungeon Realms',
      debugShowCheckedModeBanner: false,
      theme: DR.theme(),
      home: _Boot(saves: saves ?? LocalSaveRepository(), quickstart: quickstart),
    );
  }
}

class _Boot extends StatefulWidget {
  const _Boot({required this.saves, required this.quickstart});

  final SaveRepository saves;
  final bool quickstart;

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  GameData? _data;
  List<HeroProfile> _heroes = const [];
  Object? _error;
  HeroProfile? _playing;
  bool _choosing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await GameData.load();
      final problems = data.validate();
      if (problems.isNotEmpty && kDebugMode) {
        debugPrint('Content problems:\n${problems.join('\n')}');
      }
      final heroes = await widget.saves.listHeroes();
      setState(() {
        _data = data;
        _heroes = heroes;
      });
      if (widget.quickstart) _startNew('ranger', 'leafwarden');
    } catch (e, s) {
      debugPrint('Failed to load game data: $e\n$s');
      setState(() => _error = e);
    }
  }

  void _startNew(String heroClass, String look) {
    final profile = HeroProfile.create(_data!, heroClass, look, ItemFactory(_data!));
    setState(() {
      _choosing = false;
      _playing = profile;
    });
  }

  Future<void> _quit() async {
    final heroes = await widget.saves.listHeroes();
    setState(() {
      _playing = null;
      _heroes = heroes;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Text('Something went wrong loading Goblinwood:\n$_error', textAlign: TextAlign.center, style: DR.body(16)),
        ),
      );
    }
    final data = _data;
    if (data == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('DUNGEON REALMS', style: DR.title(42, color: DR.gold)),
              const SizedBox(height: 18),
              const CircularProgressIndicator(color: DR.gold),
            ],
          ),
        ),
      );
    }
    final playing = _playing;
    if (playing != null) {
      return GameScreen(key: ValueKey(playing.id), data: data, profile: playing, saves: widget.saves, onQuit: _quit);
    }
    if (_choosing) {
      return HeroSelectScreen(data: data, onBack: () => setState(() => _choosing = false), onStart: _startNew);
    }
    return TitleScreen(
      data: data,
      heroes: _heroes,
      onContinue: (h) => setState(() => _playing = h),
      onNewHero: () => setState(() => _choosing = true),
      onDelete: (h) async {
        await widget.saves.deleteHero(h.id);
        final heroes = await widget.saves.listHeroes();
        setState(() => _heroes = heroes);
      },
    );
  }
}
