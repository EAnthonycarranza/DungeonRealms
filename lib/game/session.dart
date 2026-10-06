import 'package:flutter/foundation.dart';

import '../content/game_data.dart';
import '../rules/hero_profile.dart';
import '../rules/items.dart';
import 'input.dart';

/// Hero portrait expressions (matches the concept-art sheets).
enum PortraitMood { idle, stunned, attack, ultimate, panic }

class AbilityHud {
  AbilityHud({
    required this.slot,
    required this.abilityId,
    required this.name,
    required this.icon,
    required this.description,
    required this.cooldown,
    required this.remaining,
    required this.unlocked,
    required this.unlockLevel,
    required this.isUltimate,
    required this.ready,
    required this.aim,
    required this.range,
    required this.radius,
  });

  final AbilitySlotId slot;
  final String abilityId;
  final String name;
  final String icon;
  final String description;
  final double cooldown;
  final double remaining;
  final bool unlocked;
  final int unlockLevel;
  final bool isUltimate;
  final bool ready;
  final AimMode aim;
  final double range;
  final double radius;

  double get cooldownFraction => cooldown <= 0 ? 0 : (remaining / cooldown).clamp(0, 1);
}

class TrackerObjective {
  const TrackerObjective(this.text, this.have, this.need);
  final String text;
  final int have, need;
  bool get done => have >= need;
}

class QuestTrackerEntry {
  const QuestTrackerEntry(this.questId, this.name, this.objectives, {required this.ready, required this.giverName});
  final String questId, name;
  final List<TrackerObjective> objectives;
  final bool ready;
  final String giverName;
}

class BossHud {
  const BossHud({required this.name, required this.title, required this.hpFraction, required this.phase, required this.elite, this.vulnerable = false});
  final String name;
  final String? title;
  final double hpFraction;
  final int phase;
  final bool elite;
  final bool vulnerable;
}

class EventHud {
  const EventHud({
    required this.name,
    required this.description,
    required this.timeLeft,
    required this.targetName,
    required this.targetHp,
    required this.wave,
    required this.waves,
  });
  final String name, description;
  final double timeLeft;
  final String? targetName;
  final double targetHp;
  final int wave, waves;
}

class InteractPrompt {
  const InteractPrompt(this.label, this.icon, {this.detail});
  final String label, icon;
  final String? detail;
}

class Toast {
  Toast(this.text, {this.icon, this.color, this.rarity}) : created = DateTime.now();
  final String text;
  final String? icon;
  final int? color;
  final String? rarity;
  final DateTime created;
}

class BannerMessage {
  BannerMessage(this.title, {this.subtitle, this.style = 'area'}) : created = DateTime.now();
  final String title;
  final String? subtitle;

  /// area | quest | level | boss | event | danger
  final String style;
  final DateTime created;
}

class DialogOption {
  const DialogOption(this.id, this.label, {this.primary = false});
  final String id, label;
  final bool primary;
}

class DialogState {
  const DialogState({required this.npc, required this.text, required this.options, this.questName});
  final NpcDef npc;
  final String text;
  final String? questName;
  final List<DialogOption> options;
}

class DeathState {
  const DeathState({required this.killer, required this.quip});
  final String killer, quip;
}

/// Everything the game exposes to the Flutter UI.
///
/// The game writes these notifiers; widgets listen. Widgets never reach into
/// entities directly - if the UI needs something new, add it here.
class GameSession {
  final hp = ValueNotifier<double>(1);
  final maxHp = ValueNotifier<double>(1);
  final level = ValueNotifier<int>(1);
  final xpFraction = ValueNotifier<double>(0);
  final gold = ValueNotifier<int>(0);
  final shinyBits = ValueNotifier<int>(0);
  final abilities = ValueNotifier<List<AbilityHud>>(const []);
  final dodge = ValueNotifier<AbilityHud?>(null);
  final ultimateCharge = ValueNotifier<double>(0);
  final potion = ValueNotifier<(int, int, double)>((0, 0, 0));
  final mood = ValueNotifier<PortraitMood>(PortraitMood.idle);
  final tracker = ValueNotifier<List<QuestTrackerEntry>>(const []);
  final prompt = ValueNotifier<InteractPrompt?>(null);
  final boss = ValueNotifier<BossHud?>(null);
  final event = ValueNotifier<EventHud?>(null);
  final toasts = ValueNotifier<List<Toast>>(const []);
  final banner = ValueNotifier<BannerMessage?>(null);
  final dialog = ValueNotifier<DialogState?>(null);
  final death = ValueNotifier<DeathState?>(null);
  final gathering = ValueNotifier<(String, double)?>(null);
  final areaName = ValueNotifier<String>('');
  final inventoryVersion = ValueNotifier<int>(0);
  final questsVersion = ValueNotifier<int>(0);
  final waypointPicker = ValueNotifier<bool>(false);
  final shop = ValueNotifier<String?>(null);
  final loading = ValueNotifier<bool>(true);

  /// Touch aim indicator: (slot, world target or null).
  final aimPreview = ValueNotifier<AbilitySlotId?>(null);

  late final GameCommands commands;

  void toast(String text, {String? icon, int? color, String? rarity}) {
    final list = [...toasts.value, Toast(text, icon: icon, color: color, rarity: rarity)];
    toasts.value = list.length > 6 ? list.sublist(list.length - 6) : list;
  }

  void showBanner(String title, {String? subtitle, String style = 'area'}) => banner.value = BannerMessage(title, subtitle: subtitle, style: style);

  void bumpInventory() => inventoryVersion.value++;
  void bumpQuests() => questsVersion.value++;
}

/// Commands the UI can send to the running game.
abstract interface class GameCommands {
  GameData get data;
  HeroProfile get profile;
  InputState get input;

  void chooseDialogOption(String id);
  void closeDialog();
  void equip(ItemInstance item);
  void unequip(String slot);
  void salvage(ItemInstance item);
  void sell(ItemInstance item);
  void travelTo(String waypointId);
  void respawn();
  void setPaused(bool paused);
  void setDifficulty(String id);
  Future<void> saveNow();
  String questStatusLabel(String questId);
}
