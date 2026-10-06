import '../content/game_data.dart';
import 'inventory.dart';

enum QuestStatus { locked, available, active, ready, completed }

class QuestState {
  QuestState(this.id, this.status, this.counts);

  final String id;
  QuestStatus status;
  final List<int> counts;

  Map<String, Object?> toJson() => {'status': status.name, 'counts': counts};

  factory QuestState.fromJson(String id, Map<String, Object?> j) =>
      QuestState(id, QuestStatus.values.byName(j['status']! as String), [for (final c in (j['counts'] as List?) ?? const []) (c as num).toInt()]);
}

/// Tracks quest availability and objective progress.
///
/// Gameplay code reports facts (a kill, a discovery, materials changed) and
/// the log decides which objectives advance. It never grants rewards itself;
/// see [QuestRewards] in the game layer.
class QuestLog {
  QuestLog(this.data, [Map<String, QuestState>? saved]) {
    for (final q in data.quests) {
      final s = saved?[q.id];
      states[q.id] = s != null && s.counts.length == q.objectives.length ? s : QuestState(q.id, QuestStatus.locked, List.filled(q.objectives.length, 0));
    }
    refreshAvailability();
  }

  final GameData data;
  final states = <String, QuestState>{};

  QuestStatus status(String id) => states[id]!.status;
  QuestState state(String id) => states[id]!;

  void refreshAvailability() {
    for (final q in data.quests) {
      final s = states[q.id]!;
      if (s.status == QuestStatus.locked || s.status == QuestStatus.available) {
        final ok = q.requires.every((r) => states[r]?.status == QuestStatus.completed);
        s.status = ok ? QuestStatus.available : QuestStatus.locked;
      }
    }
  }

  /// Active and ready-to-turn-in quests, in content order.
  List<QuestDef> get tracked => [
    for (final q in data.quests)
      if (states[q.id]!.status == QuestStatus.active || states[q.id]!.status == QuestStatus.ready) q,
  ];

  /// The quest an NPC should talk about first: ready > available > active.
  QuestDef? focusFor(String npcId) {
    for (final wanted in [QuestStatus.ready, QuestStatus.available, QuestStatus.active]) {
      for (final q in data.quests) {
        if (q.giver == npcId && states[q.id]!.status == wanted) return q;
      }
    }
    return null;
  }

  bool hasSomethingFor(String npcId) {
    final q = focusFor(npcId);
    if (q == null) return false;
    final s = states[q.id]!.status;
    return s == QuestStatus.ready || s == QuestStatus.available;
  }

  /// Accepts a quest. [inventory] seeds collect objectives with items the
  /// hero already carries (nobody likes re-gathering).
  bool accept(String id, Inventory inventory) {
    final s = states[id]!;
    if (s.status != QuestStatus.available) return false;
    s.status = QuestStatus.active;
    onMaterials(inventory);
    _checkReady(data.quest(id));
    return true;
  }

  void complete(String id) {
    states[id]!.status = QuestStatus.completed;
    refreshAvailability();
  }

  bool _objectiveDone(QuestDef q, int i) => states[q.id]!.counts[i] >= q.objectives[i].count;

  bool isComplete(QuestDef q) {
    for (var i = 0; i < q.objectives.length; i++) {
      if (!_objectiveDone(q, i)) return false;
    }
    return true;
  }

  void _checkReady(QuestDef q) {
    final s = states[q.id]!;
    if (s.status == QuestStatus.active && isComplete(q)) s.status = QuestStatus.ready;
    if (s.status == QuestStatus.ready && !isComplete(q)) s.status = QuestStatus.active;
  }

  List<String> _advance(bool Function(QuestObjectiveDef o) matches, {int by = 1, int? setTo}) {
    final changed = <String>[];
    for (final q in data.quests) {
      final s = states[q.id]!;
      if (s.status != QuestStatus.active && s.status != QuestStatus.ready) continue;
      var touched = false;
      for (var i = 0; i < q.objectives.length; i++) {
        final o = q.objectives[i];
        if (!matches(o)) continue;
        final before = s.counts[i];
        final next = (setTo ?? before + by).clamp(0, o.count);
        if (next != before) {
          s.counts[i] = next;
          touched = true;
        }
      }
      if (touched) {
        _checkReady(q);
        changed.add(q.id);
      }
    }
    return changed;
  }

  List<String> onKill(EnemyDef enemy) => _advance((o) => o.type == 'kill' && (o.enemy == enemy.id || (o.tag != null && enemy.tags.contains(o.tag))));

  List<String> onMaterials(Inventory inventory) {
    final changed = <String>[];
    for (final q in data.quests) {
      final s = states[q.id]!;
      if (s.status != QuestStatus.active && s.status != QuestStatus.ready) continue;
      var touched = false;
      for (var i = 0; i < q.objectives.length; i++) {
        final o = q.objectives[i];
        if (o.type != 'collect') continue;
        final next = inventory.materialCount(o.item!).clamp(0, o.count);
        if (next != s.counts[i]) {
          s.counts[i] = next;
          touched = true;
        }
      }
      if (touched) {
        _checkReady(q);
        changed.add(q.id);
      }
    }
    return changed;
  }

  List<String> onEvent(String eventId) => _advance((o) => o.type == 'event' && o.event == eventId);
  List<String> onDiscover(String target) => _advance((o) => o.type == 'discover' && o.target == target);
  List<String> onOpen(String target) => _advance((o) => o.type == 'open' && o.target == target);
  List<String> onTalk(String npc) => _advance((o) => o.type == 'talk' && o.npc == npc);

  Map<String, Object?> toJson() => {
    for (final e in states.entries)
      if (e.value.status != QuestStatus.locked && e.value.status != QuestStatus.available) e.key: e.value.toJson(),
  };

  static Map<String, QuestState> statesFromJson(Map<String, Object?>? j) => {
    for (final e in (j ?? const {}).entries) e.key: QuestState.fromJson(e.key, (e.value! as Map).cast<String, Object?>()),
  };
}
