import '../../content/game_data.dart';
import '../../rules/quest_log.dart';
import '../dungeon_realms_game.dart';
import '../entities/npc.dart';
import '../session.dart';

/// Turns quest state into NPC conversations and hands out rewards.
class QuestDirector {
  QuestDirector(this.game);

  final DungeonRealmsGame game;
  NpcEntity? _npc;
  QuestDef? _quest;

  QuestLog get log => game.quests;

  /// Opens a conversation with [npc].
  void talk(NpcEntity npc) {
    _npc = npc;
    npc.talkTime = 4;
    final changed = log.onTalk(npc.def.id);
    if (changed.isNotEmpty) game.onQuestsChanged(changed);
    final q = log.focusFor(npc.def.id);
    _quest = q;
    final options = <DialogOption>[];
    String text;
    String? questName;
    if (q != null) {
      questName = q.name;
      switch (log.status(q.id)) {
        case QuestStatus.ready:
          text = q.dialog.complete;
          options.add(const DialogOption('turn_in', 'Complete quest', primary: true));
        case QuestStatus.available:
          text = q.dialog.offer;
          options.add(DialogOption('accept', q.dialog.accept, primary: true));
          options.add(const DialogOption('close', 'Not now'));
        default:
          text = q.dialog.progress;
          final event = game.data.events[q.objectives.where((o) => o.type == 'event').firstOrNull?.event];
          if (event != null && game.events.canStart(event.id)) {
            options.add(DialogOption('start_event', event.startPrompt ?? 'Start ${event.name}', primary: true));
          } else if (event != null && game.events.running) {
            text = event.runningText ?? text;
          }
          options.add(const DialogOption('close', 'On it.'));
      }
    } else {
      text = npc.def.greeting;
      options.add(const DialogOption('close', 'Bye!'));
    }
    _addServices(npc.def, options);
    game.session.dialog.value = DialogState(npc: npc.def, text: text, options: options, questName: questName);
    game.setPaused(true);
  }

  void _addServices(NpcDef npc, List<DialogOption> options) {
    for (final s in npc.services) {
      switch (s) {
        case 'refill_potions':
          options.insert(options.length - 1, const DialogOption('refill', 'Refill potions (free!)'));
        case 'salvage':
          options.insert(options.length - 1, const DialogOption('salvage', 'Salvage gear for Shiny Bits'));
        case 'sell':
          options.insert(options.length - 1, const DialogOption('sell', 'Sell gear'));
        case 'respec_difficulty':
          if (game.profile.unlockedDifficulties(game.data).length > 1) {
            options.insert(options.length - 1, const DialogOption('difficulty', 'Change world difficulty'));
          }
      }
    }
  }

  void choose(String id) {
    final npc = _npc;
    final q = _quest;
    switch (id) {
      case 'accept':
        if (q != null && log.accept(q.id, game.profile.inventory)) {
          game.session.toast('Quest accepted: ${q.name}', icon: 'interact_talk', color: 0xffffc94f);
          game.onQuestsChanged([q.id]);
          final event = q.objectives.where((o) => o.type == 'event').firstOrNull?.event;
          if (event != null && game.events.canStart(event)) {
            close();
            game.events.start(event);
            return;
          }
        }
        close();
      case 'turn_in':
        if (q != null && log.status(q.id) == QuestStatus.ready) {
          _reward(q);
          // Chain straight into the next quest from the same NPC.
          if (npc != null && log.focusFor(npc.def.id) != null && log.status(log.focusFor(npc.def.id)!.id) == QuestStatus.available) {
            talk(npc);
            return;
          }
        }
        close();
      case 'start_event':
        final event = q?.objectives.where((o) => o.type == 'event').firstOrNull?.event;
        close();
        if (event != null) game.events.start(event);
      case 'refill':
        game.profile.potionCharges = game.profile.potionMax;
        game.session.toast('Potions refilled. ${_npc?.def.name ?? 'Someone'} insists you eat something.', icon: game.data.potion.icon);
        close();
      case 'salvage':
        close();
        game.session.shop.value = 'salvage';
      case 'sell':
        close();
        game.session.shop.value = 'sell';
      case 'difficulty':
        close();
        game.session.shop.value = 'difficulty';
      default:
        close();
    }
  }

  void close() {
    _npc = null;
    _quest = null;
    game.session.dialog.value = null;
    game.setPaused(false);
  }

  void _reward(QuestDef q) {
    final r = q.rewards;
    final inv = game.profile.inventory;
    for (final o in q.objectives) {
      if (o.type == 'collect' && o.consume) inv.removeMaterial(o.item!, o.count);
    }
    log.complete(q.id);
    if (r.gold > 0) {
      inv.gold += r.gold;
      game.session.toast('+${r.gold} gold', icon: 'currency_gold', color: 0xffffc94f);
    }
    if (r.shinyBits > 0) {
      inv.shinyBits += r.shinyBits;
      game.session.toast('+${r.shinyBits} Shiny Bits', icon: 'currency_shiny_bits', color: 0xffff4bc8);
    }
    if (r.potionCharges > 0) {
      game.profile.potionMax = (game.profile.potionMax + r.potionCharges).clamp(1, game.data.potion.maxCharges);
      game.profile.potionCharges = game.profile.potionMax;
      game.session.toast('Potion belt upgraded! (${game.profile.potionMax} potions)', icon: game.data.potion.icon, color: 0xffff6b6b);
    }
    final level = game.profile.level;
    for (final i in r.items) {
      game.grantItem(game.items.roll(level: level + 1, heroClass: game.profile.heroClass, rarity: i.rarity, baseId: i.base));
    }
    if (r.unique != null) game.grantItem(game.items.legendary(r.unique!, level));
    game.session.showBanner('QUEST COMPLETE', subtitle: q.name, style: 'quest');
    if (r.xp > 0) game.hero.gainXp(r.xp.toDouble());
    game.onQuestsChanged([q.id]);
    game.profile.inventory.materials.removeWhere((k, v) => v <= 0);
    game.session.bumpInventory();
    game.saveSoon();
  }
}
