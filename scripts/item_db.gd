class_name ItemDB
## Gear: what each item is and does. An item is a small Dictionary
## {type, level, rarity} (saved and sent over the network as is); its name,
## slot and stats are worked out from those here.
##
## Every kind of gear comes in levels 1-5 (one per area). Jackets, pants, hats
## and boots help the tamer; rings and necklaces buff the tamer's pets. The
## weapon slot shows the tamer's bat (from the Bat Shop; see Player.BATS).
##
## Collars are pet gear: each party pet wears one (Creature.collar, its only
## slot), which buffs that pet alone. Spiked collars add damage, padded ones
## health, studded ones armor.

const BAG_SIZE := 24
## Equipment slots, in display order.
const SLOTS := ["weapon", "chest", "pants", "hat", "boots", "ring1", "ring2", "necklace"]
const SLOT_NAMES := {
	"weapon": "Weapon", "chest": "Chest", "pants": "Pants", "hat": "Hat", "boots": "Boots",
	"ring1": "Ring", "ring2": "Ring", "necklace": "Necklace", "collar": "Collar",
}
## Icon (UiIcons) shown in each empty slot.
const SLOT_ICONS := {
	"weapon": "bat", "chest": "jacket", "pants": "pants", "hat": "hat", "boots": "boots",
	"ring1": "ring", "ring2": "ring", "necklace": "necklace", "collar": "collar",
}

const RARITIES := [
	{"name": "Common", "prefix": "", "color": Color(0.82, 0.82, 0.8)},
	{"name": "Uncommon", "prefix": "Fine ", "color": Color(0.45, 0.9, 0.45)},
	{"name": "Rare", "prefix": "Superior ", "color": Color(0.45, 0.65, 1.0)},
]
## Chance of each rarity when an item drops (common, uncommon, rare).
const RARITY_WEIGHTS := [0.7, 0.23, 0.07]

## What each stat does, for descriptions ("%d" is the amount).
const STATS := {
	"armor": "Tamer: take %d%% less damage",
	"health": "Tamer: +%d max health",
	"speed": "Tamer: move %d%% faster",
	"pet_damage": "Pets: deal %d%% more damage",
	"pet_health": "Pets: +%d%% max health",
	"collar_damage": "This pet: deal %d%% more damage",
	"collar_health": "This pet: +%d%% max health",
	"collar_armor": "This pet: take %d%% less damage",
}

## Every kind of item: its slot, the stat it gives, how much at levels 1-5,
## how much more each rarity step adds, and a name and colour per level.
const KINDS := {
	"jacket": {
		"slot": "chest", "stat": "armor", "values": [4, 7, 10, 13, 16], "rarity_step": 2,
		"names": ["Tattered Jacket", "Leather Jacket", "Padded Jacket", "Studded Jacket", "Ranger's Jacket"],
		"colors": [Color(0.55, 0.45, 0.35), Color(0.45, 0.28, 0.16), Color(0.35, 0.42, 0.3),
				Color(0.3, 0.3, 0.36), Color(0.22, 0.38, 0.28)],
	},
	"pants": {
		"slot": "pants", "stat": "armor", "values": [2, 4, 6, 8, 10], "rarity_step": 1,
		"names": ["Patched Trousers", "Leather Pants", "Padded Pants", "Studded Pants", "Ranger's Pants"],
		"colors": [Color(0.45, 0.4, 0.32), Color(0.4, 0.26, 0.15), Color(0.3, 0.36, 0.26),
				Color(0.26, 0.26, 0.32), Color(0.2, 0.32, 0.24)],
	},
	"hat": {
		"slot": "hat", "stat": "health", "values": [10, 15, 20, 25, 30], "rarity_step": 5,
		"names": ["Straw Hat", "Leather Cap", "Wool Hat", "Iron Helm", "Ranger's Hat"],
		"colors": [Color(0.85, 0.72, 0.4), Color(0.5, 0.32, 0.18), Color(0.7, 0.22, 0.2),
				Color(0.6, 0.62, 0.66), Color(0.22, 0.4, 0.28)],
	},
	"boots": {
		"slot": "boots", "stat": "speed", "values": [3, 5, 7, 9, 11], "rarity_step": 2,
		"names": ["Worn Sandals", "Leather Boots", "Fur Boots", "Desert Striders", "Ranger's Boots"],
		"colors": [Color(0.62, 0.48, 0.32), Color(0.42, 0.26, 0.14), Color(0.8, 0.78, 0.74),
				Color(0.76, 0.6, 0.38), Color(0.24, 0.34, 0.22)],
	},
	"ring": {
		"slot": "ring", "stat": "pet_damage", "values": [3, 5, 7, 9, 12], "rarity_step": 2,
		"names": ["Copper Ring", "Fang Ring", "Silver Ring", "Claw Ring", "Alpha Ring"],
		"colors": [Color(0.85, 0.5, 0.3), Color(0.95, 0.92, 0.82), Color(0.82, 0.85, 0.9),
				Color(0.75, 0.3, 0.3), Color(1.0, 0.8, 0.3)],
	},
	"necklace": {
		"slot": "necklace", "stat": "pet_health", "values": [5, 8, 11, 14, 18], "rarity_step": 3,
		"names": ["Bead Necklace", "Tooth Necklace", "Shell Pendant", "Jade Amulet", "Heart of the Pack"],
		"colors": [Color(0.7, 0.55, 0.4), Color(0.95, 0.92, 0.8), Color(0.95, 0.75, 0.7),
				Color(0.35, 0.8, 0.5), Color(1.0, 0.45, 0.55)],
	},
	"spiked_collar": {
		"slot": "collar", "stat": "collar_damage", "values": [5, 8, 11, 14, 18], "rarity_step": 2,
		"names": ["Thorn Collar", "Spiked Collar", "Fang Collar", "Razor Collar", "Alpha Collar"],
		"colors": [Color(0.45, 0.6, 0.3), Color(0.5, 0.3, 0.2), Color(0.92, 0.88, 0.75),
				Color(0.65, 0.68, 0.74), Color(0.85, 0.25, 0.2)],
	},
	"padded_collar": {
		"slot": "collar", "stat": "collar_health", "values": [6, 10, 14, 18, 22], "rarity_step": 3,
		"names": ["Cloth Collar", "Padded Collar", "Fleece Collar", "Quilted Collar", "Guardian Collar"],
		"colors": [Color(0.7, 0.62, 0.5), Color(0.35, 0.5, 0.75), Color(0.9, 0.88, 0.82),
				Color(0.6, 0.35, 0.65), Color(0.3, 0.7, 0.45)],
	},
	"studded_collar": {
		"slot": "collar", "stat": "collar_armor", "values": [4, 6, 8, 10, 12], "rarity_step": 2,
		"names": ["Leather Collar", "Studded Collar", "Iron Collar", "Steel Collar", "Warden Collar"],
		"colors": [Color(0.5, 0.33, 0.2), Color(0.3, 0.22, 0.16), Color(0.45, 0.45, 0.5),
				Color(0.72, 0.75, 0.8), Color(0.3, 0.4, 0.7)],
	},
}
## How often each kind drops, relative to the others (rings fill two slots).
const DROP_WEIGHTS := {"jacket": 1.0, "pants": 1.0, "hat": 1.0, "boots": 1.0, "ring": 1.4, "necklace": 0.9,
		"spiked_collar": 0.5, "padded_collar": 0.5, "studded_collar": 0.5}
const MAX_LEVEL := 5
## Armor from all gear is capped, so the tamer is never unhittable.
const MAX_ARMOR := 60


## A random piece of gear for an area level (levels past 5 drop level 5 gear).
static func make_item(area_level: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var total := 0.0
	for kind in DROP_WEIGHTS:
		total += DROP_WEIGHTS[kind]
	var pick := (rng.randf() if rng else randf()) * total
	var type: String = DROP_WEIGHTS.keys()[0]
	for kind in DROP_WEIGHTS:
		pick -= DROP_WEIGHTS[kind]
		if pick < 0.0:
			type = kind
			break
	return make(type, area_level, _roll_rarity(rng))


static func make(type: String, level: int, rarity := 0) -> Dictionary:
	return {"type": type, "level": clampi(level, 1, MAX_LEVEL), "rarity": clampi(rarity, 0, RARITIES.size() - 1)}


static func _roll_rarity(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf() if rng else randf()
	var acc := 0.0
	for i in RARITY_WEIGHTS.size():
		acc += RARITY_WEIGHTS[i]
		if roll < acc:
			return i
	return 0


## The slot an item goes in ("ring" for rings, which fit either ring slot;
## "collar" for collars, worn by pets; "" if it can't be worn).
static func slot_of(item: Dictionary) -> String:
	var kind: Dictionary = KINDS.get(item.get("type", ""), {})
	return kind.get("slot", "")


## The equipment slot an item goes in when worn without choosing one.
static func default_slot(item: Dictionary) -> String:
	var slot := slot_of(item)
	return "ring1" if slot == "ring" else slot


## True if `item` can be worn in equipment `slot` (rings go in either ring slot).
static func fits(item: Dictionary, slot: String) -> bool:
	var own := slot_of(item)
	if own == "":
		return false
	return own == slot or (own == "ring" and slot in ["ring1", "ring2"])


static func display_name(item: Dictionary) -> String:
	if item.is_empty() or not KINDS.has(item.get("type", "")):
		return ""
	return RARITIES[int(item.rarity)].prefix + KINDS[item.type].names[int(item.level) - 1]


static func rarity_color(item: Dictionary) -> Color:
	return RARITIES[int(item.get("rarity", 0))].color


## The item's own colour (a jacket's cloth, a ring's metal), for icons and the tamer's model.
static func item_color(item: Dictionary) -> Color:
	if not KINDS.has(item.get("type", "")):
		return Color.WHITE
	return KINDS[item.type].colors[int(item.level) - 1]


## The stat this item gives ("armor", "health", "speed", "pet_damage", "pet_health").
static func stat_of(item: Dictionary) -> String:
	return KINDS.get(item.get("type", ""), {}).get("stat", "")


## How much of its stat the item gives (a percent, or health points for "health").
static func amount(item: Dictionary) -> int:
	if not KINDS.has(item.get("type", "")):
		return 0
	var kind: Dictionary = KINDS[item.type]
	return kind.values[int(item.level) - 1] + kind.rarity_step * int(item.rarity)


## How much of `stat` a set of worn gear gives in total (armor is capped).
static func total(equipment: Dictionary, stat: String) -> int:
	var sum := 0
	for slot in equipment:
		if stat_of(equipment[slot]) == stat:
			sum += amount(equipment[slot])
	return mini(sum, MAX_ARMOR) if stat == "armor" else sum


## What the item does, in a few words ("Pets: deal 7% more damage").
static func effect(item: Dictionary) -> String:
	var stat := stat_of(item)
	return STATS[stat] % amount(item) if stat != "" else ""


## A short description for tooltips and the details line.
static func describe(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var kind: String = "pet collar" if is_collar(item) else SLOT_NAMES[default_slot(item)].to_lower()
	return "\n".join(["%s  (level %d)" % [display_name(item), int(item.level)],
			"%s %s" % [RARITIES[int(item.rarity)].name, kind], effect(item)])


static func is_collar(item: Dictionary) -> bool:
	return slot_of(item) == "collar"


## An item from a save or a client, made safe: a known type and sensible
## numbers, or {} if it isn't a real item.
static func clean(item) -> Dictionary:
	if not item is Dictionary or not KINDS.has(str(item.get("type", ""))):
		return {}
	return make(str(item.type), int(item.get("level", 1)), int(item.get("rarity", 0)))
