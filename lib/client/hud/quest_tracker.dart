import 'package:flutter/material.dart';

import '../../game/session.dart';
import '../theme.dart';

/// Compact list of active quests and objective counters.
class QuestTracker extends StatelessWidget {
  const QuestTracker({super.key, required this.session, this.maxQuests = 3, this.onTap});

  final GameSession session;
  final int maxQuests;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<QuestTrackerEntry>>(
      valueListenable: session.tracker,
      builder: (_, quests, _) {
        if (quests.isEmpty) return const SizedBox.shrink();
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 250,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xaa0b0f18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DR.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final q in quests.take(maxQuests)) ...[
                  Text(
                    q.name,
                    style: DR.body(13, color: q.ready ? DR.gold : DR.text, weight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  if (q.ready)
                    Text('✓ Return to ${q.giverName}', style: DR.body(12, color: DR.gold))
                  else
                    for (final o in q.objectives)
                      Text(
                        o.need > 1 ? '• ${o.text}  ${o.have}/${o.need}' : '${o.done ? '✓' : '•'} ${o.text}',
                        style: DR.body(12, color: o.done ? DR.green : DR.muted),
                      ),
                  const SizedBox(height: 7),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
