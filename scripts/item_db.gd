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
	# Never rolled with the others: legendary items drop on their own (see
	# World.roll_legendary) and are one of a kind (KINDS[...].legendary).
	{"name": "Legendary", "prefix": "", "color": Color(1.0, 0.55, 0.12)},
]
const LEGENDARY := 3  ## The Legendary rarity's index.
## What the bat shop pays for an item, by rarity (Common, Fine, Superior, Legendary).
const SELL_PRICES := [1, 2, 3, 5]
## Chance of each rarity when an ordinary item drops (common, uncommon, rare).
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
		"legendary": {"name": "Gravewarden's Coat", "value": 22, "extra": {"health": 25}},
	},
	"pants": {
		"slot": "pants", "stat": "armor", "values": [2, 4, 6, 8, 10], "rarity_step": 1,
		"names": ["Patched Trousers", "Leather Pants", "Padded Pants", "Studded Pants", "Ranger's Pants"],
		"colors": [Color(0.45, 0.4, 0.32), Color(0.4, 0.26, 0.15), Color(0.3, 0.36, 0.26),
				Color(0.26, 0.26, 0.32), Color(0.2, 0.32, 0.24)],
		"legendary": {"name": "Bonewoven Leggings", "value": 14, "extra": {"speed": 5}},
	},
	"hat": {
		"slot": "hat", "stat": "health", "values": [10, 15, 20, 25, 30], "rarity_step": 5,
		"names": ["Straw Hat", "Leather Cap", "Wool Hat", "Iron Helm", "Ranger's Hat"],
		"colors": [Color(0.85, 0.72, 0.4), Color(0.5, 0.32, 0.18), Color(0.7, 0.22, 0.2),
				Color(0.6, 0.62, 0.66), Color(0.22, 0.4, 0.28)],
		"legendary": {"name": "Crown of the Drowned", "value": 45, "extra": {"armor": 4}},
	},
	"boots": {
		"slot": "boots", "stat": "speed", "values": [3, 5, 7, 9, 11], "rarity_step": 2,
		"names": ["Worn Sandals", "Leather Boots", "Fur Boots", "Desert Striders", "Ranger's Boots"],
		"colors": [Color(0.62, 0.48, 0.32), Color(0.42, 0.26, 0.14), Color(0.8, 0.78, 0.74),
				Color(0.76, 0.6, 0.38), Color(0.24, 0.34, 0.22)],
		"legendary": {"name": "Ghoststep Boots", "value": 16, "extra": {"armor": 4}},
	},
	"ring": {
		"slot": "ring", "stat": "pet_damage", "values": [3, 5, 7, 9, 12], "rarity_step": 2,
		"names": ["Copper Ring", "Fang Ring", "Silver Ring", "Claw Ring", "Alpha Ring"],
		"colors": [Color(0.85, 0.5, 0.3), Color(0.95, 0.92, 0.82), Color(0.82, 0.85, 0.9),
				Color(0.75, 0.3, 0.3), Color(1.0, 0.8, 0.3)],
		"legendary": {"name": "Howard's Hook", "value": 18, "extra": {"pet_health": 6}},
	},
	"necklace": {
		"slot": "necklace", "stat": "pet_health", "values": [5, 8, 11, 14, 18], "rarity_step": 3,
		"names": ["Bead Necklace", "Tooth Necklace", "Shell Pendant", "Jade Amulet", "Heart of the Pack"],
		"colors": [Color(0.7, 0.55, 0.4), Color(0.95, 0.92, 0.8), Color(0.95, 0.75, 0.7),
				Color(0.35, 0.8, 0.5), Color(1.0, 0.45, 0.55)],
		"legendary": {"name": "Soulbound Locket", "value": 25, "extra": {"pet_damage": 6}},
	},
	"spiked_collar": {
		"slot": "collar", "stat": "collar_damage", "values": [5, 8, 11, 14, 18], "rarity_step": 2,
		"names": ["Thorn Collar", "Spiked Collar", "Fang Collar", "Razor Collar", "Alpha Collar"],
		"colors": [Color(0.45, 0.6, 0.3), Color(0.5, 0.3, 0.2), Color(0.92, 0.88, 0.75),
				Color(0.65, 0.68, 0.74), Color(0.85, 0.25, 0.2)],
		"legendary": {"name": "Collar of the Restless Dead", "value": 25, "extra": {"collar_health": 8}},
	},
	"padded_collar": {
		"slot": "collar", "stat": "collar_health", "values": [6, 10, 14, 18, 22], "rarity_step": 3,
		"names": ["Cloth Collar", "Padded Collar", "Fleece Collar", "Quilted Collar", "Guardian Collar"],
		"colors": [Color(0.7, 0.62, 0.5), Color(0.35, 0.5, 0.75), Color(0.9, 0.88, 0.82),
				Color(0.6, 0.35, 0.65), Color(0.3, 0.7, 0.45)],
		"legendary": {"name": "Gravedigger's Collar", "value": 30, "extra": {"collar_armor": 6}},
	},
	"studded_collar": {
		"slot": "collar", "stat": "collar_armor", "values": [4, 6, 8, 10, 12], "rarity_step": 2,
		"names": ["Leather Collar", "Studded Collar", "Iron Collar", "Steel Collar", "Warden Collar"],
		"colors": [Color(0.5, 0.33, 0.2), Color(0.3, 0.22, 0.16), Color(0.45, 0.45, 0.5),
				Color(0.72, 0.75, 0.8), Color(0.3, 0.4, 0.7)],
		"legendary": {"name": "Bone Plate Collar", "value": 16, "extra": {"collar_damage": 8}},
	},
}
## Class collars ("pet_gear"): pet gear made for one class of pet (only cats
## can wear a Wizard collar, and so on), with 1-3 random stats from that
## class's pool, one per rarity step (Common 1, Fine 2, Superior 3). An item is
## {type: "pet_gear", class, level, rarity, stats: {stat: percent}}; the stats
## are the skill-tree stats (see PetSkills) and add to this pet's own.
## (The older spiked/padded/studded collars, and the legendary collars, still
## work for any pet.)
const PET_GEAR := {
	"wizard": {
		"title": "Wizard", "pets": "cats", "color": Color(0.6, 0.4, 1.0),
		"names": ["Charmed Collar", "Runed Collar", "Arcane Collar", "Mystic Collar", "Archmage's Collar"],
		"pool": ["spell_power", "cooldown", "damage", "crit_chance", "health"],
	},
	"paladin": {
		"title": "Paladin", "pets": "dogs", "color": Color(0.98, 0.82, 0.35),
		"names": ["Blessed Collar", "Silver Collar", "Holy Collar", "Templar's Collar", "Crusader's Collar"],
		"pool": ["heal_power", "armor", "health", "cooldown", "damage"],
	},
	"archer": {
		"title": "Archer", "pets": "birds", "color": Color(0.35, 0.75, 0.45),
		"names": ["Feathered Collar", "Hunter's Collar", "Ranger's Collar", "Hawkeye Collar", "Windrunner Collar"],
		"pool": ["crit_chance", "crit_damage", "attack_speed", "damage", "spell_power"],
	},
	"venomancer": {
		"title": "Venomancer", "pets": "lizards", "color": Color(0.55, 0.9, 0.25),
		"names": ["Viper Collar", "Toxic Collar", "Venom Collar", "Plague Collar", "Basilisk Collar"],
		"pool": ["dot_power", "dot_duration", "toxic_blood", "armor", "damage"],
	},
}
## How much of each stat a class collar can roll (percent): [low, high] at
## level 1, plus `per_level` more for each level above.
const PET_STAT_ROLLS := {
	"spell_power": [4, 7, 3], "cooldown": [3, 5, 1.5], "damage": [3, 6, 2], "health": [4, 8, 3],
	"armor": [2, 4, 1.5], "heal_power": [5, 9, 3], "crit_chance": [2, 4, 1.5], "crit_damage": [8, 14, 5],
	"attack_speed": [3, 6, 2], "dot_power": [5, 9, 3], "dot_duration": [6, 10, 3], "toxic_blood": [10, 20, 6],
}
## Class rings and necklaces ("class_ring", "class_necklace"): tamer gear that
## boosts every party pet of one class, rolled like class collars (1-3 random
## stats from the class's pool, by rarity) at three quarters of a collar's
## strength. {type, class, level, rarity, stats}. (The older rings and
## necklaces, which boost every pet a little, still work.)
const CLASS_JEWELRY := {
	"class_ring": {
		"slot": "ring", "label": "ring",
		"names": {
			"wizard": ["Spark Ring", "Rune Ring", "Arcane Band", "Mystic Band", "Archmage's Signet"],
			"paladin": ["Prayer Ring", "Silver Band", "Holy Band", "Templar's Ring", "Crusader's Signet"],
			"archer": ["Fletcher's Ring", "Hunter's Band", "Ranger's Ring", "Hawkeye Band", "Windrunner Signet"],
			"venomancer": ["Fang Ring", "Toxic Band", "Venom Ring", "Plague Band", "Basilisk Signet"],
		},
	},
	"class_necklace": {
		"slot": "necklace", "label": "necklace",
		"names": {
			"wizard": ["Spark Pendant", "Rune Pendant", "Arcane Amulet", "Mystic Amulet", "Archmage's Talisman"],
			"paladin": ["Prayer Beads", "Silver Pendant", "Holy Amulet", "Templar's Amulet", "Crusader's Talisman"],
			"archer": ["Feather Pendant", "Hunter's Pendant", "Ranger's Amulet", "Hawkeye Amulet", "Windrunner Talisman"],
			"venomancer": ["Fang Pendant", "Toxic Pendant", "Venom Amulet", "Plague Amulet", "Basilisk Talisman"],
		},
	},
}
const JEWELRY_SCALE := 0.75
## How often each kind drops, relative to the others (rings fill two slots).
const DROP_WEIGHTS := {"jacket": 1.0, "pants": 1.0, "hat": 1.0, "boots": 1.0, "class_ring": 1.4, "class_necklace": 0.9,
		"pet_gear": 1.6}
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
	if is_rolled_type(type):
		return make_rolled(type, area_level, _roll_rarity(rng), "", rng)
	return make(type, area_level, _roll_rarity(rng))


## A class collar: for `pet_class` (or a random class), with rarity + 1
## different random stats from the class's pool, scaled to its level.
static func make_pet_gear(area_level: int, rarity: int, pet_class := "", rng: RandomNumberGenerator = null) -> Dictionary:
	return make_rolled("pet_gear", area_level, rarity, pet_class, rng)


## True for the class items with rolled stats: class collars, rings and necklaces.
static func is_rolled_type(type: String) -> bool:
	return type == "pet_gear" or CLASS_JEWELRY.has(type)


static func is_rolled(item: Dictionary) -> bool:
	return is_rolled_type(item.get("type", "")) and PET_GEAR.has(item.get("class", ""))


static func is_class_jewelry(item: Dictionary) -> bool:
	return is_rolled(item) and CLASS_JEWELRY.has(item.type)


## A class item of `type` (pet_gear, class_ring, class_necklace) for `pet_class`
## (or a random class): rarity + 1 different random stats from the class's
## pool, scaled to its level (jewelry at JEWELRY_SCALE).
static func make_rolled(type: String, area_level: int, rarity: int, pet_class := "", rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if not PET_GEAR.has(pet_class):
		pet_class = PET_GEAR.keys()[rng.randi() % PET_GEAR.size()]
	var level := clampi(area_level, 1, MAX_LEVEL)
	rarity = clampi(rarity, 0, 2)
	var pool: Array = PET_GEAR[pet_class].pool.duplicate()
	var scale := 1.0 if type == "pet_gear" else JEWELRY_SCALE
	var rolled := {}
	for i in rarity + 1:
		var stat: String = pool.pop_at(rng.randi() % pool.size())
		var roll: Array = PET_STAT_ROLLS[stat]
		rolled[stat] = maxi(1, roundi((rng.randi_range(roll[0], roll[1]) + roll[2] * (level - 1)) * scale))
	return {"type": type, "class": pet_class, "level": level, "rarity": rarity, "stats": rolled}


## How much of a skill-tree stat a piece of the tamer's class jewelry gives a
## pet of `pet_class` (percent; 0 for other classes or other items).
static func class_bonus(item: Dictionary, pet_class: String, stat: String) -> float:
	if not is_class_jewelry(item) or item["class"] != pet_class:
		return 0.0
	return float(item.stats.get(stat, 0))


static func is_pet_gear(item: Dictionary) -> bool:
	return item.get("type", "") == "pet_gear" and PET_GEAR.has(item.get("class", ""))


## True if a pet of `species` can wear `item` (class collars need the right class).
static func fits_pet(item: Dictionary, species: CreatureSpecies) -> bool:
	if not is_collar(item):
		return false
	return not is_pet_gear(item) or (species != null and species.pet_class() == item["class"])


## How much of a skill-tree stat (see PetSkills) a pet's class collar gives (percent).
static func pet_bonus(item: Dictionary, stat: String) -> float:
	return float(item.stats.get(stat, 0)) if is_pet_gear(item) else 0.0


## A random legendary item: any kind, its one-of-a-kind version (always level 5).
static func make_legendary(rng: RandomNumberGenerator = null) -> Dictionary:
	var kinds := KINDS.keys()
	var type: String = kinds[(rng.randi() if rng else randi()) % kinds.size()]
	return make(type, MAX_LEVEL, LEGENDARY)


## What the bat shop pays for this item (1-5 coins).
static func sell_price(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	return SELL_PRICES[clampi(int(item.get("rarity", 0)), 0, SELL_PRICES.size() - 1)]


static func is_legendary(item: Dictionary) -> bool:
	return int(item.get("rarity", 0)) == LEGENDARY and KINDS.has(item.get("type", ""))


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
	if is_pet_gear(item):
		return "collar"
	if is_class_jewelry(item):
		return CLASS_JEWELRY[item.type].slot
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
	if is_pet_gear(item):
		return RARITIES[int(item.rarity)].prefix + PET_GEAR[item["class"]].names[int(item.level) - 1]
	if is_class_jewelry(item):
		return RARITIES[int(item.rarity)].prefix + CLASS_JEWELRY[item.type].names[item["class"]][int(item.level) - 1]
	if item.is_empty() or not KINDS.has(item.get("type", "")):
		return ""
	if is_legendary(item):
		return KINDS[item.type].legendary.name
	return RARITIES[int(item.rarity)].prefix + KINDS[item.type].names[int(item.level) - 1]


static func rarity_color(item: Dictionary) -> Color:
	return RARITIES[int(item.get("rarity", 0))].color


## The item's own colour (a jacket's cloth, a ring's metal), for icons and the tamer's model.
static func item_color(item: Dictionary) -> Color:
	if is_rolled(item):
		return PET_GEAR[item["class"]].color
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
	if is_legendary(item):
		return kind.legendary.value
	return kind.values[int(item.level) - 1] + kind.rarity_step * int(item.rarity)


## Everything the item gives, as {stat: amount}: its main stat, plus a
## legendary item's extra one.
static func stats(item: Dictionary) -> Dictionary:
	var stat := stat_of(item)
	if stat == "":
		return {}
	var out := {stat: amount(item)}
	if is_legendary(item):
		for extra: String in KINDS[item.type].legendary.extra:
			out[extra] = out.get(extra, 0) + int(KINDS[item.type].legendary.extra[extra])
	return out


## How much of `stat` a set of worn gear gives in total (armor is capped).
static func total(equipment: Dictionary, stat: String) -> int:
	var sum := 0
	for slot in equipment:
		sum += int(stats(equipment[slot]).get(stat, 0))
	return mini(sum, MAX_ARMOR) if stat == "armor" else sum


## What the item does, in a few words ("Pets: deal 7% more damage"); a
## legendary item's two effects are joined by `separator`.
static func effect(item: Dictionary, separator := "\n") -> String:
	var lines := []
	if is_rolled(item):
		var who := "This pet: " if is_pet_gear(item) else "Your %s: " % PET_GEAR[item["class"]].pets
		for stat: String in item.stats:
			lines.append(who + PetSkills.STAT_TEXT[stat] % int(item.stats[stat]))
		return separator.join(lines)
	var all := stats(item)
	for stat: String in all:
		lines.append(STATS[stat] % all[stat])
	return separator.join(lines)


## A short description for tooltips and the details line.
static func describe(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var kind: String = "pet collar" if is_collar(item) else SLOT_NAMES[default_slot(item)].to_lower()
	if is_pet_gear(item):
		var gear: Dictionary = PET_GEAR[item["class"]]
		kind = "%s collar (for %s only)" % [gear.title, gear.pets]
	elif is_class_jewelry(item):
		var gear: Dictionary = PET_GEAR[item["class"]]
		kind = "%s %s (boosts your %s)" % [gear.title, CLASS_JEWELRY[item.type].label, gear.pets]
	if is_legendary(item):
		return "\n".join([display_name(item), "Legendary %s" % kind, effect(item)])
	return "\n".join(["%s  (level %d)" % [display_name(item), int(item.level)],
			"%s %s" % [RARITIES[int(item.rarity)].name, kind], effect(item)])


static func is_collar(item: Dictionary) -> bool:
	return slot_of(item) == "collar"


## An item from a save or a client, made safe: a known type and sensible
## numbers, or {} if it isn't a real item.
static func clean(item) -> Dictionary:
	if item is Dictionary and is_rolled_type(str(item.get("type", ""))):
		var type := str(item.type)
		var scale := 1.0 if type == "pet_gear" else JEWELRY_SCALE
		var pet_class := str(item.get("class", ""))
		if not PET_GEAR.has(pet_class) or not item.get("stats") is Dictionary:
			return {}
		var rarity := clampi(int(item.get("rarity", 0)), 0, 2)
		var level := clampi(int(item.get("level", 1)), 1, MAX_LEVEL)
		var stats := {}
		for stat in item.stats:
			if str(stat) in PET_GEAR[pet_class].pool and stats.size() < rarity + 1:
				var roll: Array = PET_STAT_ROLLS[str(stat)]  # no more than the best possible roll
				stats[str(stat)] = clampi(int(item.stats[stat]), 1, maxi(1, roundi((roll[1] + roll[2] * (level - 1)) * scale)))
		if stats.is_empty():
			return {}
		return {"type": type, "class": pet_class, "level": level, "rarity": rarity, "stats": stats}
	if not item is Dictionary or not KINDS.has(str(item.get("type", ""))):
		return {}
	return make(str(item.type), int(item.get("level", 1)), int(item.get("rarity", 0)))
