import 'package:flutter/material.dart';

import '../../content/game_data.dart';
import '../../game/dungeon_realms_game.dart';
import '../../rules/inventory.dart';
import '../../rules/items.dart';
import '../theme.dart';
import '../widgets/art.dart';
import 'panel_host.dart';

String formatStat(GameData data, String stat, double value, {bool signed = true}) {
  final def = data.stats[stat];
  final name = def?.name ?? stat;
  final sign = signed && value >= 0 ? '+' : '';
  if (def?.format == 'percent') return '$sign${(value * 100).toStringAsFixed(value * 100 < 10 ? 1 : 0)}% $name';
  if (def?.format == 'flat_per_second') return '$sign${value.toStringAsFixed(1)} $name/sec';
  return '$sign${value.round()} $name';
}

String itemIcon(GameData data, ItemInstance item) => item.legendaryId != null ? data.legendaries[item.legendaryId]!.icon : data.bases[item.baseId]!.icon;

/// Character sheet + bag. [mode] is `equip`, `salvage` or `sell`.
class InventoryPanel extends StatefulWidget {
  const InventoryPanel({super.key, required this.game, required this.mode, required this.onClose});

  final DungeonRealmsGame game;
  final String mode;
  final VoidCallback onClose;

  @override
  State<InventoryPanel> createState() => _InventoryPanelState();
}

class _InventoryPanelState extends State<InventoryPanel> {
  ItemInstance? _selected;

  DungeonRealmsGame get game => widget.game;
  GameData get data => game.data;
  Inventory get inv => game.profile.inventory;

  @override
  Widget build(BuildContext context) {
    // Shops are run by the NPC offering the service (npcs.json "shop").
    final shop = data.npcs.values.where((n) => n.services.contains(widget.mode)).firstOrNull;
    final title = switch (widget.mode) {
      'salvage' => shop?.shopTitle ?? 'Salvage Bench',
      'sell' => shop?.shopTitle ?? 'Trading Post',
      _ => 'Hero & Inventory',
    };
    final subtitle = switch (widget.mode) {
      'salvage' => shop?.shopBlurb ?? 'Break gear into Shiny Bits.',
      'sell' => shop?.shopBlurb ?? 'Sell gear for gold.',
      _ => 'Tap an item to inspect it. Legendary powers change how skills work.',
    };
    return ModalFrame(
      title: title,
      subtitle: subtitle,
      onClose: widget.onClose,
      maxWidth: 1080,
      child: ValueListenableBuilder<int>(
        valueListenable: game.session.inventoryVersion,
        builder: (context, _, _) => LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 760;
            final left = _CharacterColumn(game: game, selected: _selected, onSelect: _select);
            final right = _BagColumn(game: game, selected: _selected, onSelect: _select);
            final details = _selected == null
                ? null
                : _ItemDetails(game: game, item: _selected!, mode: widget.mode, onDone: () => setState(() => _selected = null));
            if (wide) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 290, child: left),
                    const SizedBox(width: 14),
                    Expanded(child: right),
                    if (details != null) ...[const SizedBox(width: 14), SizedBox(width: 300, child: details)],
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (details != null) ...[details, const SizedBox(height: 12)],
                  right,
                  const SizedBox(height: 12),
                  left,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _select(ItemInstance item) => setState(() => _selected = _selected?.uid == item.uid ? null : item);
}

class _ItemSlot extends StatelessWidget {
  const _ItemSlot({required this.game, required this.item, required this.size, this.placeholderIcon, this.selected = false, this.onTap, this.upgrade = false});

  final DungeonRealmsGame game;
  final ItemInstance? item;
  final double size;
  final String? placeholderIcon;
  final bool selected;
  final bool upgrade;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final color = i == null ? DR.line : DR.rarity(i.rarity);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: RadialGradient(colors: [i == null ? const Color(0xff1a2132) : color.withValues(alpha: 0.28), const Color(0xff0d1220)]),
          border: Border.all(
            color: selected ? DR.gold : color.withValues(alpha: i == null ? 1 : 0.8),
            width: selected ? 3 : 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (i != null)
              IconImage(itemIcon(game.data, i), size: size * 0.74)
            else if (placeholderIcon != null)
              IconImage(placeholderIcon!, size: size * 0.6, opacity: 0.18),
            if (upgrade) const Positioned(top: 2, right: 3, child: Icon(Icons.arrow_upward_rounded, color: DR.green, size: 16)),
          ],
        ),
      ),
    );
  }
}

class _CharacterColumn extends StatelessWidget {
  const _CharacterColumn({required this.game, required this.selected, required this.onSelect});

  final DungeonRealmsGame game;
  final ItemInstance? selected;
  final void Function(ItemInstance) onSelect;

  @override
  Widget build(BuildContext context) {
    final data = game.data;
    final profile = game.profile;
    final hero = data.heroes[profile.heroClass]!;
    final look = hero.look(profile.look);
    final stats = game.hero.stats;
    Widget slot(String id) {
      final s = data.slots.firstWhere((x) => x.id == id);
      final item = profile.inventory.equipped[id];
      return Column(
        children: [
          _ItemSlot(
            game: game,
            item: item,
            size: 62,
            placeholderIcon: s.icon,
            selected: item != null && item.uid == selected?.uid,
            onTap: item == null ? null : () => onSelect(item),
          ),
          const SizedBox(height: 2),
          Text(s.name, style: DR.body(10, color: DR.muted)),
        ],
      );
    }

    final rows = <(String, String)>[
      ('Attack', stats.attack.round().toString()),
      ('Health', stats.maxHp.round().toString()),
      ('Armor', stats.armor.round().toString()),
      ('Crit Chance', '${(stats.critChance * 100).toStringAsFixed(1)}%'),
      ('Crit Damage', '+${(stats.critDamage * 100).round()}%'),
      ('Attack Speed', '${(stats.attackSpeed * 100).round()}%'),
      ('Move Speed', stats.moveSpeed.toStringAsFixed(1)),
      if (stats.cooldownReduction > 0) ('Cooldown Red.', '${(stats.cooldownReduction * 100).round()}%'),
      if (stats.damageBonus > 0) ('Damage Bonus', '+${(stats.damageBonus * 100).round()}%'),
      if (stats.hpRegen > 0) ('Regen', '${stats.hpRegen.toStringAsFixed(1)}/s'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x0dffffff),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DR.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(children: [slot('head'), const SizedBox(height: 8), slot('chest')]),
              Column(
                children: [
                  ConceptPortrait(sheet: look.sheet, crop: look.crop('idle'), size: 104),
                  const SizedBox(height: 6),
                  Text('Level ${profile.level} ${hero.name}', style: DR.title(15)),
                  Text(look.name, style: DR.body(11, color: DR.muted)),
                ],
              ),
              Column(children: [slot('weapon'), const SizedBox(height: 8), slot('trinket')]),
            ],
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [slot('hands'), slot('feet')]),
          const SizedBox(height: 10),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(
                children: [
                  Text(k, style: DR.body(13, color: DR.muted)),
                  const Spacer(),
                  Text(v, style: DR.body(13, weight: FontWeight.w900)),
                ],
              ),
            ),
          if (game.hero.powers.all.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final p in game.hero.powers.all)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x14ffb92a),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x40ffc94f)),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${p.name}: ',
                        style: DR.body(12, color: DR.gold, weight: FontWeight.w900),
                      ),
                      TextSpan(
                        text: p.description,
                        style: DR.body(12, color: const Color(0xffffe8a0)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 10),
          for (final job in game.data.dayJobs.values) _DayJobRow(game: game, jobId: job.id),
        ],
      ),
    );
  }
}

class _DayJobRow extends StatelessWidget {
  const _DayJobRow({required this.game, required this.jobId});

  final DungeonRealmsGame game;
  final String jobId;

  @override
  Widget build(BuildContext context) {
    final job = game.data.dayJobs[jobId]!;
    final p = game.profile.dayJob(jobId);
    final frac = p.level >= job.maxLevel ? 1.0 : (p.xp / job.xpToNext(p.level)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          IconImage(job.icon, size: 26),
          const SizedBox(width: 6),
          Text('${job.name} ${p.level}', style: DR.body(13, weight: FontWeight.w900)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: frac, minHeight: 6, color: DR.green, backgroundColor: const Color(0xcc12161f)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BagColumn extends StatelessWidget {
  const _BagColumn({required this.game, required this.selected, required this.onSelect});

  final DungeonRealmsGame game;
  final ItemInstance? selected;
  final void Function(ItemInstance) onSelect;

  @override
  Widget build(BuildContext context) {
    final inv = game.profile.inventory;
    final data = game.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('Bag ${inv.bag.length}/${inv.capacity}', style: DR.title(17)),
            const Spacer(),
            const IconImage('currency_gold', size: 20),
            Text(
              ' ${inv.gold}',
              style: DR.body(14, color: DR.gold, weight: FontWeight.w900),
            ),
            const SizedBox(width: 12),
            const IconImage('currency_shiny_bits', size: 20),
            Text(
              ' ${inv.shinyBits}',
              style: DR.body(14, color: DR.pink, weight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            const gap = 8.0;
            final cols = (c.maxWidth / 64).floor().clamp(4, 8);
            final size = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < inv.capacity; i++)
                  if (i < inv.bag.length)
                    _ItemSlot(
                      game: game,
                      item: inv.bag[i],
                      size: size,
                      selected: inv.bag[i].uid == selected?.uid,
                      upgrade: _isUpgrade(inv.bag[i]),
                      onTap: () => onSelect(inv.bag[i]),
                    )
                  else
                    _ItemSlot(game: game, item: null, size: size),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text('Materials', style: DR.title(15)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            for (final m in data.materials.values)
              Tooltip(
                message: '${m.name}\n${m.description}',
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                  decoration: BoxDecoration(
                    color: const Color(0x10ffffff),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: DR.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconImage(m.icon, size: 26, opacity: inv.materialCount(m.id) > 0 ? 1 : 0.35),
                      const SizedBox(width: 4),
                      Text('${inv.materialCount(m.id)}', style: DR.body(13, weight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  bool _isUpgrade(ItemInstance item) {
    final base = game.data.bases[item.baseId]!;
    if (!base.usableBy(game.profile.heroClass)) return false;
    final current = game.profile.inventory.equipped[base.slot];
    return current == null || itemScore(item) > itemScore(current) * 1.05;
  }
}

class _ItemDetails extends StatelessWidget {
  const _ItemDetails({required this.game, required this.item, required this.mode, required this.onDone});

  final DungeonRealmsGame game;
  final ItemInstance item;
  final String mode;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final data = game.data;
    final base = data.bases[item.baseId]!;
    final slot = data.slots.firstWhere((s) => s.id == base.slot);
    final rarity = data.rarity(item.rarity);
    final color = DR.rarity(item.rarity);
    final legendary = item.legendaryId == null ? null : data.legendaries[item.legendaryId];
    final equipped = game.profile.inventory.equipped[base.slot];
    final isEquipped = equipped?.uid == item.uid;
    final compare = !isEquipped && equipped != null;
    final usable = base.usableBy(game.profile.heroClass);
    final value = Inventory.itemValue(item, data);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff0e1422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 18)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconImage(itemIcon(data, item), size: 52),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: DR.title(19, color: color)),
                    Text(
                      '${rarity.name.toUpperCase()} ${slot.name.toUpperCase()} • iLvl ${item.level}',
                      style: DR.body(11, color: color.withValues(alpha: 0.85), weight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final e in item.stats.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(formatStat(data, e.key, e.value), style: DR.body(14, color: statColor(e.key))),
                  ),
                  if (compare) _Delta(data: data, stat: e.key, delta: e.value - (equipped.stats[e.key] ?? 0)),
                ],
              ),
            ),
          if (compare)
            for (final e in equipped.stats.entries.where((e) => !item.stats.containsKey(e.key)))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(formatStat(data, e.key, 0), style: DR.body(14, color: DR.muted)),
                    ),
                    _Delta(data: data, stat: e.key, delta: -e.value),
                  ],
                ),
              ),
          if (legendary != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x14ffb92a),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x40ffc94f)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    legendary.power.name,
                    style: DR.body(14, color: DR.gold, weight: FontWeight.w900),
                  ),
                  Text(legendary.power.description, style: DR.body(13, color: const Color(0xffffe8a0))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '“${legendary.flavor}”',
              style: DR.body(12, color: DR.muted, weight: FontWeight.w600).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (!usable) ...[const SizedBox(height: 8), Text('Your hero can\'t use this.', style: DR.body(12, color: DR.red))],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (mode == 'equip' && !isEquipped && usable)
                GoldButton(
                  label: 'Equip',
                  compact: true,
                  onPressed: () {
                    game.equip(item);
                    onDone();
                  },
                ),
              if (mode == 'equip' && isEquipped)
                GhostButton(
                  label: 'Unequip',
                  compact: true,
                  onPressed: () {
                    game.unequip(base.slot);
                    onDone();
                  },
                ),
              if (!isEquipped && mode == 'salvage')
                GoldButton(
                  label: 'Salvage (+${rarity.salvage} bits)',
                  compact: true,
                  onPressed: () {
                    game.salvage(item);
                    onDone();
                  },
                ),
              if (!isEquipped && mode == 'equip')
                GhostButton(
                  label: 'Salvage (+${rarity.salvage} bits)',
                  compact: true,
                  onPressed: () {
                    game.salvage(item);
                    onDone();
                  },
                ),
              if (!isEquipped && mode == 'sell')
                GoldButton(
                  label: 'Sell (+$value gold)',
                  compact: true,
                  onPressed: () {
                    game.sell(item);
                    onDone();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.data, required this.stat, required this.delta});

  final GameData data;
  final String stat;
  final double delta;

  @override
  Widget build(BuildContext context) {
    if (delta.abs() < 1e-6) return const SizedBox.shrink();
    final up = delta > 0;
    final percent = data.stats[stat]?.isPercent ?? false;
    final text = percent ? '${(delta * 100).abs().toStringAsFixed(1)}%' : delta.abs().round().toString();
    return Text(
      '${up ? '▲' : '▼'} $text',
      style: DR.body(12, color: up ? DR.green : DR.red, weight: FontWeight.w900),
    );
  }
}
