import 'json_reader.dart';

/// kill | collect | event | discover | open | talk
class QuestObjectiveDef {
  QuestObjectiveDef.fromJson(JsonReader j)
    : type = j.str('type'),
      tag = j.strOr('tag'),
      enemy = j.strOr('enemy'),
      item = j.strOr('item'),
      event = j.strOr('event'),
      target = j.strOr('target'),
      npc = j.strOr('npc'),
      count = j.intOr('count', 1),
      text = j.str('text'),
      consume = j.boolOr('consume', false);

  final String type;
  final String? tag;
  final String? enemy;
  final String? item;
  final String? event;
  final String? target;
  final String? npc;
  final int count;
  final String text;

  /// For `collect`: remove the items from the inventory on turn-in.
  final bool consume;
}

class QuestItemReward {
  QuestItemReward.fromJson(JsonReader j) : base = j.strOr('base'), rarity = j.strOr('rarity', 'rare')!;

  final String? base;
  final String rarity;
}

class QuestRewardDef {
  QuestRewardDef.fromJson(JsonReader j)
    : xp = j.intOr('xp', 0),
      gold = j.intOr('gold', 0),
      shinyBits = j.intOr('shinyBits', 0),
      potionCharges = j.intOr('potionCharges', 0),
      items = [for (final i in j.objects('items')) QuestItemReward.fromJson(i)],
      unique = j.strOr('unique');

  final int xp, gold, shinyBits, potionCharges;
  final List<QuestItemReward> items;
  final String? unique;
}

class QuestDialogDef {
  QuestDialogDef.fromJson(JsonReader j) : offer = j.str('offer'), accept = j.str('accept'), progress = j.str('progress'), complete = j.str('complete');

  final String offer, accept, progress, complete;
}

class QuestDef {
  QuestDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      giver = j.str('giver'),
      requires = j.strings('requires'),
      summary = j.str('summary'),
      objectives = [for (final o in j.objects('objectives')) QuestObjectiveDef.fromJson(o)],
      rewards = QuestRewardDef.fromJson(j.obj('rewards')),
      dialog = QuestDialogDef.fromJson(j.obj('dialog'));

  final String id, name, giver;
  final List<String> requires;
  final String summary;
  final List<QuestObjectiveDef> objectives;
  final QuestRewardDef rewards;
  final QuestDialogDef dialog;
}

class NpcDef {
  NpcDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      title = j.str('title'),
      sprite = j.str('sprite'),
      color = j.strOr('color', '#ffffff')!,
      greeting = j.str('greeting'),
      barks = j.strings('barks'),
      services = j.strings('services');

  final String id, name, title, sprite, color, greeting;
  final List<String> barks;

  /// salvage | refill_potions | sell | respec_difficulty
  final List<String> services;
}
