import 'package:flutter/material.dart';

import '../../content/game_data.dart';
import '../../game/dungeon_realms_game.dart';
import '../../rules/quest_log.dart';
import '../theme.dart';
import 'panel_host.dart';

/// All quests: active first, then available, then completed.
class QuestLogPanel extends StatefulWidget {
  const QuestLogPanel({super.key, required this.game, required this.onClose});

  final DungeonRealmsGame game;
  final VoidCallback onClose;

  @override
  State<QuestLogPanel> createState() => _QuestLogPanelState();
}

class _QuestLogPanelState extends State<QuestLogPanel> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final log = game.quests;
    int order(QuestDef q) => switch (log.status(q.id)) {
      QuestStatus.ready => 0,
      QuestStatus.active => 1,
      QuestStatus.available => 2,
      QuestStatus.completed => 3,
      QuestStatus.locked => 4,
    };
    final quests = [...game.data.quests.where((q) => log.status(q.id) != QuestStatus.locked)]..sort((a, b) => order(a).compareTo(order(b)));
    final selected = quests.where((q) => q.id == _selected).firstOrNull ?? quests.firstOrNull;
    return ModalFrame(
      title: 'Quest Log',
      subtitle: '${game.data.quests.where((q) => log.status(q.id) == QuestStatus.completed).length}/${game.data.quests.length} completed in Goblinwood',
      onClose: widget.onClose,
      maxWidth: 900,
      child: LayoutBuilder(
        builder: (context, c) {
          final list = ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            children: [
              for (final q in quests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: q == selected ? const Color(0x22ffc94f) : const Color(0x0dffffff),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selected = q.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            Icon(_icon(log.status(q.id)), size: 20, color: _color(log.status(q.id))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(q.name, style: DR.body(14, weight: FontWeight.w900)),
                            ),
                            Text(game.questStatusLabel(q.id), style: DR.body(11, color: _color(log.status(q.id)))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
          final details = selected == null ? const SizedBox.shrink() : _QuestDetails(game: game, quest: selected);
          if (c.maxWidth > 680) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 330, child: list),
                Expanded(
                  child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(4, 0, 18, 18), child: details),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10), child: details),
                list,
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _icon(QuestStatus s) => switch (s) {
    QuestStatus.ready => Icons.star_rounded,
    QuestStatus.active => Icons.explore_rounded,
    QuestStatus.available => Icons.priority_high_rounded,
    QuestStatus.completed => Icons.check_circle_rounded,
    QuestStatus.locked => Icons.lock_rounded,
  };

  Color _color(QuestStatus s) => switch (s) {
    QuestStatus.ready => DR.gold,
    QuestStatus.active => DR.blue,
    QuestStatus.available => DR.orange,
    QuestStatus.completed => DR.green,
    QuestStatus.locked => DR.muted,
  };
}

class _QuestDetails extends StatelessWidget {
  const _QuestDetails({required this.game, required this.quest});

  final DungeonRealmsGame game;
  final QuestDef quest;

  @override
  Widget build(BuildContext context) {
    final log = game.quests;
    final state = log.state(quest.id);
    final status = log.status(quest.id);
    final giver = game.data.npcs[quest.giver]!;
    final r = quest.rewards;
    final rewards = <String>[
      if (r.xp > 0) '${r.xp} XP',
      if (r.gold > 0) '${r.gold} gold',
      if (r.shinyBits > 0) '${r.shinyBits} Shiny Bits',
      if (r.potionCharges > 0) '+${r.potionCharges} potion slot',
      for (final i in r.items) '${i.rarity[0].toUpperCase()}${i.rarity.substring(1)} ${i.base == null ? 'item' : game.data.bases[i.base]!.name}',
      if (r.unique != null) game.data.legendaries[r.unique]!.name,
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x0dffffff),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DR.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quest.name, style: DR.title(24, color: DR.gold)),
          const SizedBox(height: 4),
          Text('Given by ${giver.name}, ${giver.title}', style: DR.body(12, color: DR.muted)),
          const SizedBox(height: 10),
          Text(quest.summary, style: DR.body(15)),
          const SizedBox(height: 14),
          Text(
            'OBJECTIVES',
            style: DR.body(11, color: DR.gold, weight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < quest.objectives.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    state.counts[i] >= quest.objectives[i].count || status == QuestStatus.completed
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 18,
                    color: DR.green,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(quest.objectives[i].text, style: DR.body(14))),
                  if (quest.objectives[i].count > 1 && status != QuestStatus.available)
                    Text(
                      '${status == QuestStatus.completed ? quest.objectives[i].count : state.counts[i]}/${quest.objectives[i].count}',
                      style: DR.body(13, color: DR.muted),
                    ),
                ],
              ),
            ),
          if (status == QuestStatus.available) ...[
            const SizedBox(height: 8),
            Text('Talk to ${giver.name} to accept this quest.', style: DR.body(13, color: DR.orange)),
          ],
          if (status == QuestStatus.ready) ...[const SizedBox(height: 8), Text('Return to ${giver.name} for your reward!', style: DR.body(13, color: DR.gold))],
          const SizedBox(height: 14),
          Text(
            'REWARDS',
            style: DR.body(11, color: DR.gold, weight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final reward in rewards)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x14ffc94f),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x40ffc94f)),
                  ),
                  child: Text(reward, style: DR.body(12, color: const Color(0xffffe8a6))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
