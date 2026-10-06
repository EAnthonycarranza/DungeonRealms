import '../content/game_data.dart';
import 'items.dart';

/// Bag, equipment, materials and wallet for one hero.
class Inventory {
  Inventory({List<ItemInstance>? bag, Map<String, ItemInstance>? equipped, Map<String, int>? materials, this.gold = 0, this.shinyBits = 0, this.capacity = 30})
    : bag = bag ?? [],
      equipped = equipped ?? {},
      materials = materials ?? {};

  final List<ItemInstance> bag;
  final Map<String, ItemInstance> equipped;
  final Map<String, int> materials;
  int gold;
  int shinyBits;
  final int capacity;

  bool get isFull => bag.length >= capacity;

  /// Adds to the bag. Returns false when the bag is full.
  bool addItem(ItemInstance item) {
    if (isFull) return false;
    bag.add(item);
    return true;
  }

  int materialCount(String id) => materials[id] ?? 0;

  void addMaterial(String id, int amount) => materials[id] = materialCount(id) + amount;

  bool removeMaterial(String id, int amount) {
    final have = materialCount(id);
    if (have < amount) return false;
    materials[id] = have - amount;
    return true;
  }

  /// Equips [item] from the bag; the previously equipped item goes back into
  /// the bag in its place.
  void equip(ItemInstance item, GameData data) {
    final slot = data.bases[item.baseId]!.slot;
    final index = bag.indexWhere((i) => i.uid == item.uid);
    final previous = equipped[slot];
    equipped[slot] = item;
    if (index >= 0) {
      if (previous != null) {
        bag[index] = previous;
      } else {
        bag.removeAt(index);
      }
    } else if (previous != null) {
      bag.add(previous);
    }
  }

  bool unequip(String slot) {
    final item = equipped[slot];
    if (item == null || isFull) return false;
    equipped.remove(slot);
    bag.add(item);
    return true;
  }

  /// Breaks an item from the bag into Shiny Bits. Returns bits gained.
  int salvage(ItemInstance item, GameData data) {
    final removed = bag.indexWhere((i) => i.uid == item.uid);
    if (removed < 0) return 0;
    bag.removeAt(removed);
    final bits = data.rarity(item.rarity).salvage;
    shinyBits += bits;
    return bits;
  }

  /// Sells an item from the bag for gold. Returns gold gained.
  int sell(ItemInstance item, GameData data) {
    final removed = bag.indexWhere((i) => i.uid == item.uid);
    if (removed < 0) return 0;
    bag.removeAt(removed);
    final value = itemValue(item, data);
    gold += value;
    return value;
  }

  static int itemValue(ItemInstance item, GameData data) => (4 + item.level * 3 * data.rarity(item.rarity).valueMult).round();

  Map<String, Object?> toJson() => {
    'bag': [for (final i in bag) i.toJson()],
    'equipped': {for (final e in equipped.entries) e.key: e.value.toJson()},
    'materials': materials,
    'gold': gold,
    'shinyBits': shinyBits,
  };

  factory Inventory.fromJson(Map<String, Object?> j) => Inventory(
    bag: [for (final i in (j['bag'] as List?) ?? const []) ItemInstance.fromJson((i as Map).cast<String, Object?>())],
    equipped: {for (final e in ((j['equipped'] as Map?) ?? const {}).entries) e.key as String: ItemInstance.fromJson((e.value as Map).cast<String, Object?>())},
    materials: {for (final e in ((j['materials'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()},
    gold: ((j['gold'] as num?) ?? 0).toInt(),
    shinyBits: ((j['shinyBits'] as num?) ?? 0).toInt(),
  );
}
