import 'package:flutter/material.dart';

import '../../content/game_data.dart';
import '../theme.dart';
import '../widgets/art.dart';

/// "A roster worth mastering": the vision's hero carousel, made playable.
class HeroSelectScreen extends StatefulWidget {
  const HeroSelectScreen({super.key, required this.data, required this.onBack, required this.onStart});

  final GameData data;
  final VoidCallback onBack;
  final void Function(String heroClass, String look) onStart;

  @override
  State<HeroSelectScreen> createState() => _HeroSelectScreenState();
}

class _HeroSelectScreenState extends State<HeroSelectScreen> {
  late final List<HeroDef> heroes = [...widget.data.heroes.values.where((h) => h.playable), ...widget.data.heroes.values.where((h) => !h.playable)];
  int _index = 0;
  final _looks = <String, int>{};

  HeroDef get hero => heroes[_index];
  HeroLookDef get look => hero.looks[_looks[hero.id] ?? 0];

  void _step(int d) => setState(() => _index = (_index + d) % heroes.length);

  @override
  Widget build(BuildContext context) {
    final tone = DR.tone(hero.tone);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 820;
              // Phones in landscape: compact copy, no roster strip, and the
              // start button moves into the top bar so it is always visible.
              final short = c.maxHeight < 560;
              void start() => widget.onStart(hero.id, look.id);
              final art = Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: 30,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: tone.withValues(alpha: 0.35), blurRadius: 120, spreadRadius: 20)],
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: ConceptSheet(key: ValueKey(look.sheet), sheet: look.sheet),
                  ),
                ],
              );
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hero.kicker,
                    style: DR.body(12, color: DR.gold, weight: FontWeight.w900).copyWith(letterSpacing: 2),
                  ),
                  const SizedBox(height: 6),
                  Text(hero.name, style: DR.title(short ? 36 : (wide ? 56 : 40))),
                  const SizedBox(height: 6),
                  Text(hero.role, style: DR.body(short ? 15 : 18, color: const Color(0xffdce7f7))),
                  SizedBox(height: short ? 6 : 10),
                  Text(
                    hero.description,
                    style: DR.body(short ? 13 : 15, color: DR.muted, weight: FontWeight.w600),
                  ),
                  SizedBox(height: short ? 10 : 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final s in hero.skillNames)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0x0effffff),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: DR.line),
                          ),
                          child: Text(s, style: DR.body(12, weight: FontWeight.w800)),
                        ),
                    ],
                  ),
                  if (hero.looks.length > 1) ...[
                    const SizedBox(height: 18),
                    Text(
                      'LOOK',
                      style: DR.body(11, color: DR.gold, weight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      children: [
                        for (var i = 0; i < hero.looks.length; i++)
                          GestureDetector(
                            onTap: () => setState(() => _looks[hero.id] = i),
                            child: Column(
                              children: [
                                ConceptPortrait(
                                  sheet: hero.looks[i].sheet,
                                  crop: hero.looks[i].crop('idle'),
                                  size: short ? 52 : 64,
                                  ring: (_looks[hero.id] ?? 0) == i ? DR.gold : DR.line,
                                ),
                                const SizedBox(height: 4),
                                Text(hero.looks[i].name, style: DR.body(12, color: (_looks[hero.id] ?? 0) == i ? DR.gold : DR.muted)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (hero.playable && !short) ...[
                    const SizedBox(height: 22),
                    GoldButton(label: 'Begin in ${widget.data.regions.firstWhere((r) => r.playable).name}', icon: Icons.play_arrow_rounded, onPressed: start),
                  ] else if (!hero.playable) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x10ffffff),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: DR.line),
                      ),
                      child: Text('Coming in a future update. The ${hero.name} is still practicing.', style: DR.body(14, color: DR.muted)),
                    ),
                  ],
                ],
              );
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back_rounded, color: DR.text),
                        ),
                        Text(
                          '04 — HEROES',
                          style: DR.body(12, color: DR.gold, weight: FontWeight.w900),
                        ),
                        const Spacer(),
                        Text('${_index + 1} / ${heroes.length}', style: DR.body(13, color: DR.muted)),
                        const SizedBox(width: 10),
                        _NavButton(icon: Icons.arrow_back_rounded, onTap: () => _step(-1)),
                        const SizedBox(width: 8),
                        _NavButton(icon: Icons.arrow_forward_rounded, onTap: () => _step(1)),
                        if (short && hero.playable) ...[
                          const SizedBox(width: 12),
                          GoldButton(label: 'Begin', icon: Icons.play_arrow_rounded, compact: true, onPressed: start),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(short ? 8 : 16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: DR.line),
                          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xeb1b2433), Color(0xfa090d15)]),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: wide
                            ? Row(
                                children: [
                                  Expanded(
                                    flex: 11,
                                    child: Padding(padding: EdgeInsets.all(short ? 6 : 18), child: art),
                                  ),
                                  Expanded(
                                    flex: 10,
                                    child: SingleChildScrollView(
                                      padding: EdgeInsets.fromLTRB(10, short ? 14 : 30, short ? 20 : 36, short ? 14 : 30),
                                      child: copy,
                                    ),
                                  ),
                                ],
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  children: [
                                    SizedBox(height: c.maxHeight * 0.38, child: art),
                                    copy,
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (!short)
                    SizedBox(
                      height: 86,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        children: [
                          for (var i = 0; i < heroes.length; i++)
                            GestureDetector(
                              onTap: () => setState(() => _index = i),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Opacity(
                                  opacity: heroes[i].playable || i == _index ? 1 : 0.55,
                                  child: ConceptPortrait(
                                    sheet: heroes[i].looks.first.sheet,
                                    crop: heroes[i].looks.first.crop('idle'),
                                    size: 66,
                                    ring: i == _index ? DR.gold : (heroes[i].playable ? DR.green : DR.line),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x0dffffff),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: DR.line),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: DR.text),
      ),
    ),
  );
}
