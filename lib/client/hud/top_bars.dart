import 'package:flutter/material.dart';

import '../../game/session.dart';
import '../theme.dart';
import '../widgets/art.dart';

/// Boss / elite health bar with phase markers ("Readable Bosses").
class BossBar extends StatelessWidget {
  const BossBar({super.key, required this.session, required this.width});

  final GameSession session;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BossHud?>(
      valueListenable: session.boss,
      builder: (_, boss, _) {
        if (boss == null) return const SizedBox.shrink();
        final color = boss.elite ? DR.orange : DR.red;
        return Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          decoration: DR.panelBox(radius: 16, border: color.withValues(alpha: 0.5)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (!boss.elite) const IconImage('boss_skull', size: 26),
                  if (!boss.elite) const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: boss.name.toUpperCase(), style: DR.title(boss.elite ? 17 : 21)),
                          if (boss.title != null)
                            TextSpan(
                              text: '   ${boss.title}',
                              style: DR.body(12, color: DR.muted),
                            ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (boss.vulnerable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: DR.gold, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        'BREAK! +50%',
                        style: DR.body(11, color: DR.ink, weight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 16,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(color: const Color(0xcc12161f), borderRadius: BorderRadius.circular(8)),
                    ),
                    FractionallySizedBox(
                      widthFactor: boss.hpFraction,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: boss.vulnerable ? const [Color(0xffffe066), Color(0xffffb020)] : [color.withValues(alpha: 0.85), color],
                          ),
                        ),
                      ),
                    ),
                    if (!boss.elite)
                      for (final mark in const [0.6, 0.3])
                        Positioned(
                          left: (width - 28) * mark - 1,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 2, color: const Color(0xccffffff)),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Public event banner: timer, objective health, wave counter.
class EventBar extends StatelessWidget {
  const EventBar({super.key, required this.session, required this.width});

  final GameSession session;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EventHud?>(
      valueListenable: session.event,
      builder: (_, ev, _) {
        if (ev == null) return const SizedBox.shrink();
        final secs = ev.timeLeft.ceil();
        return Container(
          width: width,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          decoration: DR.panelBox(radius: 16, border: DR.green.withValues(alpha: 0.5)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'PUBLIC EVENT',
                    style: DR.body(10, color: DR.green, weight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(ev.name, style: DR.title(17), overflow: TextOverflow.ellipsis),
                  ),
                  Text('${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}', style: DR.title(17, color: secs < 15 ? DR.red : DR.gold)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Wave ${ev.wave}/${ev.waves} • ${ev.description}', style: DR.body(12, color: DR.muted)),
              if (ev.targetName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(ev.targetName!, style: DR.body(11, weight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(value: ev.targetHp, minHeight: 8, color: DR.green, backgroundColor: const Color(0xcc12161f)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
