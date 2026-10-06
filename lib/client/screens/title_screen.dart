import 'package:flutter/material.dart';

import '../../content/game_data.dart';
import '../../rules/hero_profile.dart';
import '../theme.dart';
import '../widgets/art.dart';

/// The front door, styled after the Game Vision page.
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key, required this.data, required this.heroes, required this.onContinue, required this.onNewHero, required this.onDelete});

  final GameData data;
  final List<HeroProfile> heroes;
  final void Function(HeroProfile) onContinue;
  final VoidCallback onNewHero;
  final void Function(HeroProfile) onDelete;

  @override
  Widget build(BuildContext context) {
    final startRegion = data.regions.firstWhere((r) => r.playable);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 760;
          // Phones in landscape are short: shrink the type so the play button
          // stays above the fold.
          final short = c.maxHeight < 560;
          final titleSize = short ? (c.maxHeight * 0.15).clamp(44.0, 72.0) : (narrow ? 58.0 : 104.0);
          final bodySize = short ? 14.0 : (narrow ? 16.0 : 19.0);
          final textWidth = narrow ? c.maxWidth : (short ? c.maxWidth * 0.5 : 540.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(center: Alignment(-0.7, -1.1), radius: 1.3, colors: [Color(0x293980ff), Color(0x00000000)]),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(center: Alignment(0.9, -0.9), radius: 1.2, colors: [Color(0x24ff5e28), Color(0x00000000)]),
                ),
              ),
              // Concept art layers (Monk faint behind, Ranger in front).
              Positioned(
                right: c.maxWidth * (narrow ? -0.3 : 0.28),
                bottom: -c.maxHeight * 0.12,
                width: c.maxWidth * (narrow ? 0.9 : 0.42),
                child: const Opacity(opacity: 0.28, child: ConceptSheet(sheet: 'heroes/monk.webp')),
              ),
              Positioned(
                right: narrow ? -c.maxWidth * 0.35 : -40,
                bottom: -10,
                width: c.maxWidth * (narrow ? 1.1 : 0.6),
                child: Opacity(
                  opacity: narrow ? 0.35 : 0.9,
                  child: const ConceptSheet(sheet: 'heroes/ranger_leafwarden.webp'),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: c.maxHeight * 0.25,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00080b12), DR.bg]),
                  ),
                ),
              ),
              // Keeps the copy readable where it overlaps the art.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(stops: [0.2, 0.62], colors: [Color(0xd9080b12), Color(0x00080b12)]),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 56, vertical: short ? 14 : 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: narrow ? c.maxWidth : 680, minHeight: c.maxHeight - (short ? 28 : 56)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 34, height: 2, decoration: const BoxDecoration(gradient: DR.goldGradient)),
                            const SizedBox(width: 9),
                            Text(
                              'A COLORFUL ONLINE ACTION RPG',
                              style: DR.body(12, color: const Color(0xffffe09a), weight: FontWeight.w900).copyWith(letterSpacing: 2),
                            ),
                          ],
                        ),
                        SizedBox(height: short ? 8 : 18),
                        Text('DUNGEON', style: DR.title(titleSize)),
                        ShaderMask(
                          shaderCallback: (r) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xfffff9d9), Color(0xffffd75d), Color(0xffff8a2a)],
                          ).createShader(r),
                          child: Text('REALMS', style: DR.title(titleSize, color: Colors.white)),
                        ),
                        SizedBox(height: short ? 10 : 18),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: textWidth),
                          child: Text.rich(
                            TextSpan(
                              style: DR.body(bodySize, color: const Color(0xffd5dbea), weight: FontWeight.w600),
                              children: [
                                const TextSpan(text: 'A '),
                                TextSpan(
                                  text: '2.5D isometric, real-time fantasy RPG',
                                  style: DR.body(bodySize, weight: FontWeight.w900),
                                ),
                                const TextSpan(
                                  text: ' where heroes smash monster packs, chase ridiculous loot, learn Day Jobs, and enter challenges the game itself admits are a terrible idea.',
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!short) ...[
                          const SizedBox(height: 22),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final p in const ['Real-Time Combat', 'Build-Changing Loot', 'Cartoon Fantasy Humor', 'Mobile First']) _Pill(p),
                            ],
                          ),
                        ],
                        SizedBox(height: short ? 16 : 30),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (heroes.isNotEmpty)
                              GoldButton(
                                label: 'Continue  •  Lv ${heroes.first.level} ${data.heroes[heroes.first.heroClass]?.name ?? ''}',
                                icon: Icons.play_arrow_rounded,
                                onPressed: () => onContinue(heroes.first),
                              ),
                            heroes.isEmpty
                                ? GoldButton(label: 'Enter ${startRegion.name}', icon: Icons.play_arrow_rounded, onPressed: onNewHero)
                                : GhostButton(label: 'New Hero', icon: Icons.person_add_alt_1_rounded, onPressed: onNewHero),
                          ],
                        ),
                        if (heroes.length > 1) ...[
                          const SizedBox(height: 22),
                          Text(
                            'YOUR HEROES',
                            style: DR.body(11, color: DR.gold, weight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          for (final h in heroes.take(5)) _HeroRow(data: data, hero: h, onPlay: () => onContinue(h), onDelete: () => onDelete(h)),
                        ],
                        SizedBox(height: short ? 12 : 28),
                        Text(
                          'Phase 01–03 vertical slice • ${startRegion.name} (Lv ${startRegion.levels.$1.toInt()}–${startRegion.levels.$2.toInt()}) • Saves stay on this device',
                          style: DR.body(12, color: const Color(0xff8f99aa)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x990a0e16),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: DR.line),
    ),
    child: Text(
      text,
      style: DR.body(12, color: const Color(0xffd8dfeb), weight: FontWeight.w800),
    ),
  );
}

class _HeroRow extends StatelessWidget {
  const _HeroRow({required this.data, required this.hero, required this.onPlay, required this.onDelete});

  final GameData data;
  final HeroProfile hero;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final def = data.heroes[hero.heroClass];
    if (def == null) return const SizedBox.shrink();
    final look = def.look(hero.look);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xcc0b0f18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DR.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConceptPortrait(sheet: look.sheet, crop: look.crop('idle'), size: 44, ringWidth: 2),
          const SizedBox(width: 10),
          Text('Lv ${hero.level} ${def.name} • ${look.name}', style: DR.body(14, weight: FontWeight.w900)),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded, color: DR.gold),
          ),
          IconButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: DR.panel,
                  title: Text('Retire this hero?', style: DR.title(22)),
                  content: Text('This deletes the save on this device. There is no undo.', style: DR.body(14)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: DR.red)),
                    ),
                  ],
                ),
              );
              if (ok == true) onDelete();
            },
            icon: const Icon(Icons.delete_outline_rounded, color: DR.muted),
          ),
        ],
      ),
    );
  }
}
