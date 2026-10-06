import 'package:flutter/material.dart';

import '../../game/dungeon_realms_game.dart';
import '../../game/session.dart';
import '../theme.dart';
import '../widgets/art.dart';

/// Top-left hero frame: reactive concept-art portrait, health, XP, wallet.
class HeroFrame extends StatelessWidget {
  const HeroFrame({super.key, required this.game, this.compact = false});

  final DungeonRealmsGame game;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = game.session;
    final hero = game.data.heroes[game.profile.heroClass]!;
    final look = hero.look(game.profile.look);
    final portraitSize = compact ? 66.0 : 84.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: portraitSize + 6,
          height: portraitSize + 10,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ValueListenableBuilder<PortraitMood>(
                valueListenable: s.mood,
                builder: (_, mood, _) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: ConceptPortrait(
                    key: ValueKey(mood),
                    sheet: look.sheet,
                    crop: look.crop(mood.name),
                    size: portraitSize,
                    ring: switch (mood) {
                      PortraitMood.panic => DR.red,
                      PortraitMood.stunned => DR.purple,
                      PortraitMood.ultimate => DR.green,
                      _ => DR.gold,
                    },
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: ValueListenableBuilder<int>(
                  valueListenable: s.level,
                  builder: (_, level, _) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: DR.goldGradient,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xff3a2400), width: 2),
                    ),
                    child: Text('$level', style: DR.title(compact ? 14 : 16, color: const Color(0xff271300))),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.fromLTRB(10, 6, 12, 8),
          decoration: BoxDecoration(
            color: const Color(0xa60b0f18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DR.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${hero.name} • ${look.name}',
                style: DR.body(compact ? 12 : 13, color: DR.muted, weight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              _HealthBar(game: game, width: compact ? 150 : 210),
              const SizedBox(height: 5),
              ValueListenableBuilder<double>(
                valueListenable: s.xpFraction,
                builder: (_, xp, _) => _ThinBar(value: xp, width: compact ? 150 : 210, color: DR.purple),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const IconImage('currency_gold', size: 18),
                  const SizedBox(width: 3),
                  ValueListenableBuilder<int>(
                    valueListenable: s.gold,
                    builder: (_, g, _) => Text(
                      '$g',
                      style: DR.body(13, color: DR.gold, weight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const IconImage('currency_shiny_bits', size: 18),
                  const SizedBox(width: 3),
                  ValueListenableBuilder<int>(
                    valueListenable: s.shinyBits,
                    builder: (_, b, _) => Text(
                      '$b',
                      style: DR.body(13, color: DR.pink, weight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthBar extends StatelessWidget {
  const _HealthBar({required this.game, required this.width});

  final DungeonRealmsGame game;
  final double width;

  @override
  Widget build(BuildContext context) {
    final s = game.session;
    return ListenableBuilder(
      listenable: Listenable.merge([s.hp, s.maxHp]),
      builder: (_, _) {
        final max = s.maxHp.value <= 0 ? 1.0 : s.maxHp.value;
        final frac = (s.hp.value / max).clamp(0.0, 1.0);
        return Container(
          width: width,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xcc12161f),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0x55ffffff)),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: frac < 0.3 ? const [Color(0xffff8a7a), Color(0xffc0261e)] : const [Color(0xffff7a6a), Color(0xffd8302a)],
                    ),
                  ),
                ),
              ),
              Center(
                child: Text('${s.hp.value.ceil()} / ${max.round()}', style: DR.body(11, weight: FontWeight.w900)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThinBar extends StatelessWidget {
  const _ThinBar({required this.value, required this.width, required this.color});

  final double value;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 6,
    decoration: BoxDecoration(color: const Color(0xcc12161f), borderRadius: BorderRadius.circular(3)),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: value.clamp(0.0, 1.0),
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
    ),
  );
}
