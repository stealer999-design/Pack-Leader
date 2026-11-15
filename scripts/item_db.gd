class_name ItemDB
## Gear, Diablo style: every item is a base type plus rolled affixes.
##
## An item is a Dictionary, saved and sent over the network as is:
##   {v: 2, type: <kind>, tier: 1-3, ilvl: 1-80, rarity: 0-4, class: "" or a pet class,
##    base: {stat: value}, affixes: {affix id: value}, name: "" (rares only)}
## - type: the kind of base item ("jacket", "pants", "hat", "boots", "ring",
##   "necklace", "collar"); collars are pet gear, the rest the tamer's.
## - ilvl: the level of the creature that dropped it. Affix ranges and base
##   tiers grow with it, with no cap.
## - tier: the base tier (BASES): tier 2 drops from item level 21, tier 3 from 51.
## - rarity: NORMAL (base stat only), MAGIC (1-2 affixes), RARE (3-5, and a
##   random name), UNIQUE and SET (reserved for named items).
## - class: a class item (ring, necklace or collar made for cats, dogs, birds
##   or lizards) can roll that class's skill-tree affixes (cls_*); a class
##   collar fits only that class of pet, a class ring or necklace boosts only
##   that class.
## The tamer's bat is not an item: bats are bought at the bat shop (Player.BATS).
## Items saved by older versions are converted by clean() (see _convert_v1).

const VERSION := 2
const BAG_SIZE := 40
## Places in the stash chest in town (kept between runs, see Player.stash).
const STASH_SIZE := 40
const MAX_ILVL := 80
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

const NORMAL := 0
const MAGIC := 1
const RARE := 2
const UNIQUE := 3
const SET := 4
const RARITIES := [
	{"name": "Normal", "color": Color(0.86, 0.86, 0.84)},
	{"name": "Magic", "color": Color(0.45, 0.62, 1.0)},
	{"name": "Rare", "color": Color(1.0, 0.86, 0.3)},
	{"name": "Unique", "color": Color(0.88, 0.62, 0.3)},
	{"name": "Set", "color": Color(0.35, 0.95, 0.4)},
]
## How many affixes each rarity rolls: [fewest, most].
const AFFIX_COUNT := [[0, 0], [1, 2], [3, 5], [4, 6], [2, 4]]
## Chance of each rarity when an item drops (Normal, Magic, Rare, Unique-or-Set).
## A Unique-or-Set roll is a Unique 60% of the time, else a set piece.
const RARITY_WEIGHTS := [0.62, 0.30, 0.07, 0.01]
const SET_SHARE := 0.4
## What the bat shop pays, by rarity, plus 1 coin per 20 item levels.
const SELL_PRICES := [1, 3, 8, 20, 20]
## Armor from all gear is capped, so the tamer is never unhittable.
const MAX_ARMOR := 60

## The base types: their slot, a name per tier and the base stat each tier rolls
## ([low, high] for tiers 1, 2 and 3). Jackets, pants, hats and boots protect
## the tamer; a collar's base health is the wearing pet's (percent).
const BASES := {
	"jacket": {"slot": "chest", "names": ["Leather Jacket", "Padded Coat", "Ranger's Duster"],
			"base": {"armor": [[4, 7], [9, 13], [15, 20]], "health": [[5, 10], [25, 40], [60, 90]]}},
	"pants": {"slot": "pants", "names": ["Work Trousers", "Reinforced Pants", "Trail Breeches"],
			"base": {"armor": [[2, 4], [5, 8], [9, 12]]}},
	"hat": {"slot": "hat", "names": ["Cap", "Hard Hat", "Warden's Hat"],
			"base": {"health": [[10, 30], [45, 70], [110, 160]]}},
	"boots": {"slot": "boots", "names": ["Sneakers", "Hiking Boots", "Pathfinder Boots"],
			"base": {"speed": [[3, 5], [6, 8], [9, 12]]}},
	"ring": {"slot": "ring", "names": ["Band", "Signet", "Seal"], "base": {}},
	"necklace": {"slot": "necklace", "names": ["Cord", "Pendant", "Talisman"], "base": {}},
	"collar": {"slot": "collar", "names": ["Strap", "Studded Collar", "Runed Collar"],
			"base": {"health": [[4, 8], [10, 16], [18, 26]]}},
}
## The item level each base tier starts dropping at.
const TIER_ILVL := [1, 21, 51]
## How often each kind drops, relative to the others (rings fill two slots).
const DROP_WEIGHTS := {"jacket": 1.0, "pants": 1.0, "hat": 1.0, "boots": 1.0, "ring": 1.4, "necklace": 0.9, "collar": 1.6}
## Colours by look (1-5, see look_level) for the tamer's clothes and icons.
const OUTFIT_COLORS := {
	"jacket": [Color(0.55, 0.45, 0.35), Color(0.45, 0.28, 0.16), Color(0.35, 0.42, 0.3), Color(0.3, 0.3, 0.36), Color(0.22, 0.38, 0.28)],
	"pants": [Color(0.45, 0.4, 0.32), Color(0.4, 0.26, 0.15), Color(0.3, 0.36, 0.26), Color(0.26, 0.26, 0.32), Color(0.2, 0.32, 0.24)],
	"hat": [Color(0.85, 0.72, 0.4), Color(0.5, 0.32, 0.18), Color(0.7, 0.22, 0.2), Color(0.6, 0.62, 0.66), Color(0.22, 0.4, 0.28)],
	"boots": [Color(0.62, 0.48, 0.32), Color(0.42, 0.26, 0.14), Color(0.8, 0.78, 0.74), Color(0.76, 0.6, 0.38), Color(0.24, 0.34, 0.22)],
	"ring": [Color(0.85, 0.5, 0.3), Color(0.82, 0.85, 0.9), Color(0.95, 0.92, 0.82), Color(0.75, 0.3, 0.3), Color(1.0, 0.8, 0.3)],
	"necklace": [Color(0.7, 0.55, 0.4), Color(0.95, 0.92, 0.8), Color(0.95, 0.75, 0.7), Color(0.35, 0.8, 0.5), Color(1.0, 0.45, 0.55)],
	"collar": [Color(0.5, 0.33, 0.2), Color(0.35, 0.5, 0.75), Color(0.65, 0.68, 0.74), Color(0.6, 0.35, 0.65), Color(0.85, 0.25, 0.2)],
}

## Affixes any item of the listed kinds can roll. `range` = [low, high] at item
## level 1 and [low, high] at item level 80 (in between, both grow evenly);
## `word` names the item ("Savage Band of Vigor"): a prefix or a suffix.
const ALL_KINDS := ["jacket", "pants", "hat", "boots", "ring", "necklace", "collar"]
const AFFIXES := {
	"pet_damage": {"word": "Savage", "prefix": true, "kinds": ALL_KINDS, "range": [3, 6, 40, 60]},
	"pet_health": {"word": "Hearty", "prefix": true, "kinds": ALL_KINDS, "range": [4, 8, 45, 70]},
	"cooldown": {"word": "of Haste", "prefix": false, "kinds": ["necklace", "collar"], "range": [2, 4, 10, 15]},
	"life_hit": {"word": "of the Leech", "prefix": false, "kinds": ["ring", "collar"], "range": [1, 2, 4, 6]},
	"health": {"word": "of Vigor", "prefix": false, "kinds": ["jacket", "pants", "hat", "boots", "ring", "necklace"], "range": [5, 10, 120, 180]},
	"armor": {"word": "Sturdy", "prefix": true, "kinds": ["jacket", "pants", "hat", "boots"], "range": [2, 4, 15, 20]},
	"poison_resist": {"word": "of Warding", "prefix": false, "kinds": ALL_KINDS, "range": [5, 10, 30, 50]},
	"speed": {"word": "Swift", "prefix": true, "kinds": ["boots"], "range": [2, 4, 10, 15]},
	"magic_find": {"word": "of Fortune", "prefix": false, "kinds": ["ring", "necklace", "hat"], "range": [5, 10, 30, 50]},
	"coin_find": {"word": "Gilded", "prefix": true, "kinds": ["ring", "necklace", "hat"], "range": [5, 10, 30, 50]},
}
## Pet affixes (and class affixes) roll this many times their listed range:
## the main tuning knob for how much gear makes up for pets' slower growth.
const PET_AFFIX_SCALE := 1.5
## Kinds that can be class items.
const CLASS_KINDS := ["ring", "necklace", "collar"]
## The four pet classes: their names and colours, and the skill-tree stats
## their class items roll (cls_<stat>).
const PET_GEAR := {
	"wizard": {"title": "Wizard", "pets": "cats", "color": Color(0.6, 0.4, 1.0), "word": "Arcane", "skills_word": "of the Archmage",
			"pool": ["spell_power", "cooldown", "damage", "crit_chance", "health"]},
	"paladin": {"title": "Paladin", "pets": "dogs", "color": Color(0.98, 0.82, 0.35), "word": "Holy", "skills_word": "of the Crusader",
			"pool": ["heal_power", "armor", "health", "cooldown", "damage"]},
	"archer": {"title": "Archer", "pets": "birds", "color": Color(0.35, 0.75, 0.45), "word": "Keen", "skills_word": "of the Hawkeye",
			"pool": ["crit_chance", "crit_damage", "attack_speed", "damage", "spell_power"]},
	"venomancer": {"title": "Venomancer", "pets": "lizards", "color": Color(0.55, 0.9, 0.25), "word": "Venomous", "skills_word": "of the Basilisk",
			"pool": ["dot_power", "dot_duration", "toxic_blood", "armor", "damage"]},
}
## Class affix ranges (percent): [low, high] at item level 1 and at item level 80.
const CLASS_ROLLS := {
	"spell_power": [4, 7, 49, 52], "cooldown": [3, 5, 25, 28], "damage": [3, 6, 33, 36], "health": [4, 8, 49, 53],
	"armor": [2, 4, 24, 27], "heal_power": [5, 9, 50, 54], "crit_chance": [2, 4, 24, 27], "crit_damage": [8, 14, 83, 89],
	"attack_speed": [3, 6, 33, 36], "dot_power": [5, 9, 50, 54], "dot_duration": [6, 10, 51, 55], "toxic_blood": [10, 20, 100, 110],
}
## "+N to every skill rank" for a class: rings, necklaces and collars from item level 30.
const SKILLS_RANGE := [1, 1, 1, 3]
const SKILLS_ILVL := 30
## Class rings and necklaces roll class affixes at this share of a collar's.
const JEWELRY_SCALE := 0.75
## Words for rare items' names.
const RARE_FIRST := ["Grim", "Dusk", "Storm", "Bone", "Ember", "Frost", "Wild", "Iron", "Shadow", "Thorn", "Moon", "Blood",
		"Ash", "Gale", "Rune", "Viper"]
const RARE_SECOND := ["Fang", "Howl", "Mark", "Bond", "Ward", "Claw", "Heart", "Song", "Coil", "Snare", "Crest", "Brand",
		"Veil", "Pact", "Spur", "Knot"]

## Unique items: one of a kind, named, with fixed affixes that roll near the
## top of their range for the item level (x the multiplier given).
## id: [name, type, tier, class ("" = any), {affix: multiplier}]
const UNIQUES := {
	"gravewarden": ["Gravewarden's Coat", "jacket", 1, "", {"health": 1.3, "armor": 1.2, "poison_resist": 1.0}],
	"strays_overcoat": ["Stray's Overcoat", "jacket", 1, "", {"pet_health": 1.3, "health": 1.0, "coin_find": 1.0}],
	"bonewoven_mantle": ["Bonewoven Mantle", "jacket", 2, "", {"armor": 1.3, "pet_damage": 1.2, "health": 1.2}],
	"pack_leaders_hide": ["Pack Leader's Hide", "jacket", 2, "", {"pet_damage": 1.4, "pet_health": 1.2, "armor": 1.0}],
	"restless_coat": ["Coat of the Restless Dead", "jacket", 3, "", {"armor": 1.3, "health": 1.4, "poison_resist": 1.2, "pet_health": 1.2}],
	"dragonscale": ["Dragonscale Duster", "jacket", 3, "", {"armor": 1.4, "pet_damage": 1.3, "health": 1.2}],
	"mudrunners": ["Mudrunner Trousers", "pants", 1, "", {"armor": 1.2, "poison_resist": 1.3}],
	"patchwork": ["Patchwork Pants of Plenty", "pants", 1, "", {"coin_find": 1.5, "armor": 1.0}],
	"bonewoven_leggings": ["Bonewoven Leggings", "pants", 2, "", {"armor": 1.3, "health": 1.2, "pet_health": 1.1}],
	"tidebreaker": ["Tidebreaker Breeches", "pants", 3, "", {"armor": 1.4, "health": 1.3, "pet_damage": 1.2}],
	"drowned_crown": ["Crown of the Drowned", "hat", 1, "", {"health": 1.3, "magic_find": 1.3}],
	"shepherds_cap": ["Old Shepherd's Cap", "hat", 1, "", {"pet_health": 1.3, "health": 1.1}],
	"howlhelm": ["Howlhelm", "hat", 2, "", {"pet_damage": 1.3, "health": 1.2, "armor": 1.1}],
	"fortunes_feather": ["Fortune's Feather", "hat", 2, "", {"magic_find": 1.5, "coin_find": 1.5, "health": 1.0}],
	"wardens_crown": ["Warden's Crown", "hat", 3, "", {"health": 1.4, "armor": 1.3, "pet_damage": 1.2, "magic_find": 1.1}],
	"ghoststep": ["Ghoststep Boots", "boots", 1, "", {"speed": 1.4, "armor": 1.0}],
	"dunewalkers": ["Dunewalkers", "boots", 2, "", {"speed": 1.3, "poison_resist": 1.3, "health": 1.1}],
	"hikers_blessing": ["Hiker's Blessing", "boots", 2, "", {"speed": 1.2, "pet_health": 1.2}],
	"windrunner_stride": ["Windrunner's Stride", "boots", 3, "", {"speed": 1.5, "pet_damage": 1.2, "health": 1.2}],
	"howards_hook": ["Howard's Hook", "ring", 1, "", {"pet_damage": 1.3, "life_hit": 1.2}],
	"band_of_the_pack": ["Band of the Pack", "ring", 1, "", {"pet_damage": 1.2, "pet_health": 1.2}],
	"lucky_penny": ["Lucky Penny", "ring", 2, "", {"magic_find": 1.5, "coin_find": 1.5}],
	"soulbinder": ["Soulbinder", "ring", 2, "", {"pet_damage": 1.4, "life_hit": 1.4, "health": 1.0}],
	"alphas_signet": ["Alpha's Signet", "ring", 3, "", {"pet_damage": 1.5, "pet_health": 1.3, "life_hit": 1.2}],
	"thousand_fangs": ["Ring of a Thousand Fangs", "ring", 3, "", {"pet_damage": 1.6, "health": 1.2, "poison_resist": 1.1}],
	"kaels_tooth": ["Kael's Tooth Necklace", "necklace", 1, "", {"pet_damage": 1.3, "health": 1.1}],
	"soulbound_locket": ["Soulbound Locket", "necklace", 1, "", {"pet_health": 1.3, "pet_damage": 1.1}],
	"heart_of_the_pack": ["Heart of the Pack", "necklace", 2, "", {"pet_health": 1.5, "cooldown": 1.2, "health": 1.0}],
	"timekeepers_chain": ["Timekeeper's Chain", "necklace", 2, "", {"cooldown": 1.5, "pet_damage": 1.2}],
	"eye_of_the_storm": ["Eye of the Storm", "necklace", 3, "", {"pet_damage": 1.5, "cooldown": 1.4, "pet_health": 1.2}],
	"restless_collar": ["Collar of the Restless Dead", "collar", 1, "", {"pet_damage": 1.3, "pet_health": 1.2}],
	"gravediggers_collar": ["Gravedigger's Collar", "collar", 2, "", {"pet_health": 1.5, "poison_resist": 1.2, "life_hit": 1.1}],
	"bone_plate_collar": ["Bone Plate Collar", "collar", 3, "", {"pet_damage": 1.4, "pet_health": 1.4, "life_hit": 1.3}],
	"emberheart": ["Emberheart", "collar", 2, "wizard", {"cls_spell_power": 1.4, "cls_cooldown": 1.2, "pet_damage": 1.1}],
	"archmages_spark": ["Archmage's Spark", "ring", 3, "wizard", {"cls_skills": 1.0, "cls_spell_power": 1.3}],
	"saints_halo": ["Saint's Halo", "collar", 2, "paladin", {"cls_heal_power": 1.4, "cls_armor": 1.2, "pet_health": 1.2}],
	"crusaders_relic": ["Crusader's Relic", "necklace", 3, "paladin", {"cls_skills": 1.0, "cls_health": 1.3, "cls_heal_power": 1.2}],
	"falconers_hood": ["Falconer's Hood", "collar", 2, "archer", {"cls_crit_chance": 1.4, "cls_crit_damage": 1.3}],
	"hawkeye_loop": ["Hawkeye Loop", "ring", 3, "archer", {"cls_skills": 1.0, "cls_attack_speed": 1.3}],
	"vipers_coil": ["Viper's Coil", "collar", 2, "venomancer", {"cls_dot_power": 1.4, "cls_toxic_blood": 1.3}],
	"basilisk_fang": ["Basilisk Fang", "necklace", 3, "venomancer", {"cls_skills": 1.0, "cls_dot_duration": 1.3, "cls_dot_power": 1.2}],
}
## The four class sets: four pieces each (worn by the tamer, or the collar by
## a party pet of the class), with bonuses for that class's pets at 2 and 4
## pieces worn (skill-tree stats, percent).
const SETS := {
	"archmage": {"name": "Archmage's Regalia", "class": "wizard", "bonus": {2: {"spell_power": 20}, 4: {"cooldown": 25, "damage": 20}},
		"pieces": {
			"archmage_hood": ["Archmage's Hood", "hat", {"health": 1.1, "cls_spell_power": 1.2}],
			"archmage_focus": ["Archmage's Focus", "necklace", {"cls_cooldown": 1.2, "pet_damage": 1.1}],
			"archmage_seal": ["Archmage's Seal", "ring", {"cls_damage": 1.2, "magic_find": 1.0}],
			"archmage_band": ["Archmage's Familiar Band", "collar", {"cls_spell_power": 1.3, "pet_health": 1.1}],
		}},
	"crusader": {"name": "Crusader's Oath", "class": "paladin", "bonus": {2: {"heal_power": 25}, 4: {"health": 30, "armor": 15}},
		"pieces": {
			"crusader_plate": ["Crusader's Tabard", "jacket", {"armor": 1.2, "cls_health": 1.2}],
			"crusader_greaves": ["Crusader's Greaves", "pants", {"armor": 1.1, "cls_armor": 1.2}],
			"crusader_beads": ["Crusader's Prayer Beads", "necklace", {"cls_heal_power": 1.3, "pet_health": 1.1}],
			"crusader_collar": ["Crusader's Mantle Collar", "collar", {"cls_heal_power": 1.2, "cls_health": 1.2}],
		}},
	"hawkeye": {"name": "Hawkeye's Gear", "class": "archer", "bonus": {2: {"crit_chance": 10}, 4: {"crit_damage": 50, "attack_speed": 15}},
		"pieces": {
			"hawkeye_boots": ["Hawkeye's Treads", "boots", {"speed": 1.2, "cls_attack_speed": 1.2}],
			"hawkeye_ring": ["Hawkeye's Loop", "ring", {"cls_crit_chance": 1.3, "pet_damage": 1.0}],
			"hawkeye_pendant": ["Hawkeye's Feather", "necklace", {"cls_crit_damage": 1.3, "cooldown": 1.0}],
			"hawkeye_hood": ["Hawkeye's Jesses", "collar", {"cls_crit_chance": 1.2, "cls_damage": 1.2}],
		}},
	"basilisk": {"name": "Basilisk's Coils", "class": "venomancer", "bonus": {2: {"dot_power": 25}, 4: {"dot_duration": 30, "toxic_blood": 50}},
		"pieces": {
			"basilisk_crown": ["Basilisk's Crest", "hat", {"health": 1.1, "cls_dot_power": 1.2}],
			"basilisk_ring": ["Basilisk's Eye", "ring", {"cls_toxic_blood": 1.3, "poison_resist": 1.1}],
			"basilisk_fang_set": ["Basilisk's Venom Sac", "necklace", {"cls_dot_duration": 1.3, "pet_damage": 1.0}],
			"basilisk_collar": ["Basilisk's Scale Collar", "collar", {"cls_dot_power": 1.3, "cls_armor": 1.1}],
		}},
}


## Tamer stats: what they do, for descriptions ("%d" is the amount).
const TAMER_TEXT := {
	"armor": "Tamer: take %d%% less damage",
	"health": "Tamer: +%d max health",
	"speed": "Tamer: move %d%% faster",
	"poison_resist": "Tamer and pets: take %d%% less poison",
	"magic_find": "%d%% better odds of good items",
	"coin_find": "%d%% more coins",
}
## Pet stats from affixes: the skill-tree stat each feeds, and its words
## ("%s" = who: "Pets" or "This pet").
const PET_AFFIX_STAT := {"pet_damage": "damage", "pet_health": "health", "cooldown": "cooldown", "life_hit": "life_hit",
		"poison_resist": "poison_resist"}
const PET_TEXT := {
	"damage": "%s: deal %d%% more damage",
	"health": "%s: +%d%% max health",
	"cooldown": "%s: abilities recharge %d%% faster",
	"life_hit": "%s: heal %d%% of the damage dealt",
	"poison_resist": "%s: take %d%% less poison",
}


# --- Making items ----------------------------------------------------------------

static func _rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return rng


## A random item for item level `ilvl`. `local_class` (optional) makes half of
## the class items that drop made for that class (birds' gear in the peaks...).
## `min_rarity` raises the rarity to at least that.
static func make_item(ilvl: int, rng: RandomNumberGenerator = null, local_class := "", min_rarity := NORMAL,
		rarity := -1) -> Dictionary:
	rng = _rng(rng)
	var total := 0.0
	for kind in DROP_WEIGHTS:
		total += DROP_WEIGHTS[kind]
	var pick := rng.randf() * total
	var type: String = DROP_WEIGHTS.keys()[0]
	for kind in DROP_WEIGHTS:
		pick -= DROP_WEIGHTS[kind]
		if pick < 0.0:
			type = kind
			break
	if rarity < 0:
		rarity = roll_rarity(rng)
	rarity = maxi(rarity, min_rarity)
	if rarity >= UNIQUE:
		return make_set_piece(ilvl, rng) if rng.randf() < SET_SHARE else make_unique(ilvl, rng)
	return make(type, ilvl, rarity, rng, local_class)


## A random unique item that can drop at `ilvl` (its tier must have started dropping).
static func make_unique(ilvl: int, rng: RandomNumberGenerator = null, id := "") -> Dictionary:
	rng = _rng(rng)
	ilvl = clampi(ilvl, 1, MAX_ILVL)
	if not UNIQUES.has(id):
		var options := UNIQUES.keys().filter(func(k: String) -> bool: return UNIQUES[k][2] <= max_tier(ilvl))
		id = options[rng.randi() % options.size()]
	var spec: Array = UNIQUES[id]
	var item := _fixed_item(spec[1], spec[2], ilvl, UNIQUE, spec[3], spec[4], rng)
	item.unique = id
	return item


## A random set piece (sets drop from item level 30).
static func make_set_piece(ilvl: int, rng: RandomNumberGenerator = null, piece := "") -> Dictionary:
	rng = _rng(rng)
	ilvl = clampi(maxi(ilvl, 30), 1, MAX_ILVL)
	var set_id := ""
	for sid: String in SETS:
		if SETS[sid].pieces.has(piece):
			set_id = sid
	if set_id == "":
		set_id = SETS.keys()[rng.randi() % SETS.size()]
		var pieces: Array = SETS[set_id].pieces.keys()
		piece = pieces[rng.randi() % pieces.size()]
	var spec: Array = SETS[set_id].pieces[piece]
	var item := _fixed_item(spec[1], max_tier(ilvl), ilvl, SET, SETS[set_id]["class"], spec[2], rng)
	item.unique = piece
	item.set = set_id
	return item


## A unique or set item's body: its base, class and fixed affixes, rolled near
## the top of their range (x the multiplier, 90-100%).
static func _fixed_item(type: String, tier: int, ilvl: int, rarity: int, pet_class: String, affix_mults: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var base := {}
	for stat: String in BASES[type].base:
		var r: Array = BASES[type].base[stat][tier - 1]
		base[stat] = r[1]
	var affixes := {}
	for id: String in affix_mults:
		affixes[id] = maxi(1, roundi(affix_range(id, ilvl, type).y * float(affix_mults[id]) * rng.randf_range(0.9, 1.0)))
	return {"v": VERSION, "type": type, "tier": tier, "ilvl": ilvl, "rarity": rarity, "class": pet_class,
			"base": base, "affixes": affixes, "name": ""}


## A rarity for a drop. `magic_find` (percent, from gear) makes Rare items
## that much likelier and Magic items half that much.
static func roll_rarity(rng: RandomNumberGenerator = null, magic_find := 0.0) -> int:
	var weights := [RARITY_WEIGHTS[0], RARITY_WEIGHTS[1] * (1.0 + magic_find / 200.0), RARITY_WEIGHTS[2] * (1.0 + magic_find / 100.0),
			RARITY_WEIGHTS[3] * (1.0 + magic_find / 100.0)]
	var total: float = weights[0] + weights[1] + weights[2] + weights[3]
	var roll := _rng(rng).randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return RARE


## The best base tier that drops at `ilvl` (1-3).
static func max_tier(ilvl: int) -> int:
	var tier := 1
	for i in TIER_ILVL.size():
		if ilvl >= TIER_ILVL[i]:
			tier = i + 1
	return tier


## An item of `type` at `ilvl` and `rarity` (Unique and Set roll as Rare for now).
static func make(type: String, ilvl: int, rarity := NORMAL, rng: RandomNumberGenerator = null, local_class := "") -> Dictionary:
	rng = _rng(rng)
	if not BASES.has(type):
		type = "jacket"
	ilvl = clampi(ilvl, 1, MAX_ILVL)
	rarity = clampi(rarity, NORMAL, RARE)
	if BASES[type].base.is_empty():
		rarity = maxi(rarity, MAGIC)  # rings and necklaces are never plain
	var tier := max_tier(ilvl)
	if tier > 1 and rng.randf() < 0.3:
		tier -= 1  # now and then an older base still drops
	var base := {}
	for stat: String in BASES[type].base:
		var r: Array = BASES[type].base[stat][tier - 1]
		base[stat] = rng.randi_range(r[0], r[1])
	var pet_class := ""
	if type in CLASS_KINDS and rarity >= MAGIC and rng.randf() < 0.45:
		pet_class = local_class if PET_GEAR.has(local_class) and rng.randf() < 0.5 \
				else PET_GEAR.keys()[rng.randi() % PET_GEAR.size()]
	var affixes := {}
	var count := rng.randi_range(AFFIX_COUNT[rarity][0], AFFIX_COUNT[rarity][1])
	var pool := affix_pool(type, pet_class, ilvl)
	if pet_class != "":  # a class item always has at least one class affix
		var class_pool := pool.filter(func(id: String) -> bool: return id.begins_with("cls_"))
		var first: String = class_pool[rng.randi() % class_pool.size()]
		affixes[first] = roll_value(first, ilvl, type, rng)
		pool.erase(first)
	while affixes.size() < count and not pool.is_empty():
		var id: String = pool.pop_at(rng.randi() % pool.size())
		affixes[id] = roll_value(id, ilvl, type, rng)
	var item := {"v": VERSION, "type": type, "tier": tier, "ilvl": ilvl, "rarity": rarity, "class": pet_class,
			"base": base, "affixes": affixes, "name": ""}
	if rarity == RARE:
		item.name = "%s %s" % [RARE_FIRST[rng.randi() % RARE_FIRST.size()], RARE_SECOND[rng.randi() % RARE_SECOND.size()]]
	return item


## Every affix an item of `type` (made for `pet_class`, or "") can roll at `ilvl`.
static func affix_pool(type: String, pet_class: String, ilvl: int) -> Array:
	var out := []
	for id: String in AFFIXES:
		if type in AFFIXES[id].kinds:
			out.append(id)
	if PET_GEAR.has(pet_class) and type in CLASS_KINDS:
		for stat: String in PET_GEAR[pet_class].pool:
			out.append("cls_" + stat)
		if ilvl >= SKILLS_ILVL:
			out.append("cls_skills")
	return out


## [low, high] an affix rolls at `ilvl` on an item of `type`.
static func affix_range(id: String, ilvl: int, type: String) -> Vector2i:
	var r: Array
	var scale := 1.0
	if id == "cls_skills":
		r = SKILLS_RANGE
	elif id.begins_with("cls_"):
		r = CLASS_ROLLS.get(id.substr(4), [0, 0, 0, 0])
		scale = 1.0 if type == "collar" else JEWELRY_SCALE
	else:
		r = AFFIXES.get(id, {}).get("range", [0, 0, 0, 0])
	if id != "cls_skills" and (id.begins_with("cls_") or PET_AFFIX_STAT.has(id) and id != "poison_resist"):
		scale *= PET_AFFIX_SCALE
	var t := clampf((ilvl - 1) / float(MAX_ILVL - 1), 0.0, 1.0)
	var lo := maxi(1, roundi(lerpf(r[0], r[2], t) * scale))
	var hi := maxi(lo, roundi(lerpf(r[1], r[3], t) * scale))
	return Vector2i(lo, hi)


static func roll_value(id: String, ilvl: int, type: String, rng: RandomNumberGenerator) -> int:
	var r := affix_range(id, ilvl, type)
	return rng.randi_range(r.x, r.y)


# --- What an item is ---------------------------------------------------------------

static func is_item(item) -> bool:
	return item is Dictionary and not item.is_empty() and BASES.has(item.get("type", ""))


## The slot an item goes in ("ring" fits either ring slot; "collar" is worn by pets).
static func slot_of(item: Dictionary) -> String:
	return BASES.get(item.get("type", ""), {}).get("slot", "")


## The equipment slot an item goes in when worn without choosing one.
static func default_slot(item: Dictionary) -> String:
	var slot := slot_of(item)
	return "ring1" if slot == "ring" else slot


## True if `item` can be worn in equipment `slot` (rings go in either ring slot).
static func fits(item: Dictionary, slot: String) -> bool:
	var own := slot_of(item)
	if own == "" or own == "collar":
		return false
	return own == slot or (own == "ring" and slot in ["ring1", "ring2"])


static func is_collar(item: Dictionary) -> bool:
	return slot_of(item) == "collar"


## A class item: made for one class of pet.
static func is_rolled(item: Dictionary) -> bool:
	return PET_GEAR.has(item.get("class", ""))


## A class collar: only that class of pet can wear it.
static func is_pet_gear(item: Dictionary) -> bool:
	return is_collar(item) and is_rolled(item)


## A class ring or necklace: boosts that class of pet.
static func is_class_jewelry(item: Dictionary) -> bool:
	return is_rolled(item) and not is_collar(item)


## True if a pet of `species` can wear `item` (class collars need the right class).
static func fits_pet(item: Dictionary, species: CreatureSpecies) -> bool:
	if not is_collar(item):
		return false
	return not is_rolled(item) or (species != null and species.pet_class() == item["class"])


## Rare and better: shown with a beam, a chime and an announcement.
static func is_standout(item: Dictionary) -> bool:
	return is_item(item) and int(item.get("rarity", 0)) >= RARE


## 1-5: how fancy the tamer looks wearing it (tier, plus one for a rare).
static func look_level(item: Dictionary) -> int:
	if not is_item(item):
		return 0
	return clampi(int(item.tier) * 2 - 1 + (1 if int(item.rarity) >= RARE else 0), 1, 5)


static func display_name(item: Dictionary) -> String:
	if not is_item(item):
		return ""
	var base_name: String = BASES[item.type].names[clampi(int(item.tier), 1, 3) - 1]
	var rarity := int(item.rarity)
	if rarity == UNIQUE and UNIQUES.has(item.get("unique", "")):
		return UNIQUES[item.unique][0]
	if rarity == SET and SETS.has(item.get("set", "")) and SETS[item.set].pieces.has(item.get("unique", "")):
		return SETS[item.set].pieces[item.unique][0]
	if rarity >= RARE and str(item.get("name", "")) != "":
		return "%s %s" % [item.name, base_name]
	if rarity == NORMAL:
		return base_name
	var prefix := ""
	var suffix := ""
	for id: String in item.affixes:
		var word := _affix_word(id, item)
		if word.is_empty():
			continue
		if word.prefix and prefix == "":
			prefix = word.text + " "
		elif not word.prefix and suffix == "":
			suffix = " " + word.text
	return prefix + base_name + suffix


static func _affix_word(id: String, item: Dictionary) -> Dictionary:
	if id == "cls_skills" and is_rolled(item):
		return {"text": PET_GEAR[item["class"]].skills_word, "prefix": false}
	if id.begins_with("cls_") and is_rolled(item):
		return {"text": PET_GEAR[item["class"]].word, "prefix": true}
	if AFFIXES.has(id):
		return {"text": AFFIXES[id].word, "prefix": AFFIXES[id].prefix}
	return {}


static func rarity_color(item: Dictionary) -> Color:
	return RARITIES[clampi(int(item.get("rarity", 0)), 0, RARITIES.size() - 1)].color


## The item's own colour (a jacket's cloth, a ring's metal), for icons and the tamer's model.
static func item_color(item: Dictionary) -> Color:
	if is_rolled(item):
		return PET_GEAR[item["class"]].color
	if not is_item(item):
		return Color.WHITE
	return OUTFIT_COLORS[item.type][look_level(item) - 1]


## What the bat shop pays for this item.
static func sell_price(item: Dictionary) -> int:
	if not is_item(item):
		return 0
	return SELL_PRICES[clampi(int(item.rarity), 0, SELL_PRICES.size() - 1)] + int(item.ilvl) / 20


# --- What an item does ---------------------------------------------------------------

## What a tamer's item (not a collar) adds to the tamer's totals, as
## {stat: amount}: tamer stats ("armor", "health", "speed", "poison_resist",
## "magic_find", "coin_find") and every-pet stats ("pet_" + a skill-tree stat).
static func stats(item: Dictionary) -> Dictionary:
	var out := {}
	if not is_item(item) or is_collar(item):
		return out
	for stat: String in item.base:
		out[stat] = out.get(stat, 0) + int(item.base[stat])
	for id: String in item.affixes:
		var value := int(item.affixes[id])
		if TAMER_TEXT.has(id):
			out[id] = out.get(id, 0) + value
		if PET_AFFIX_STAT.has(id):
			var key: String = "pet_" + PET_AFFIX_STAT[id]
			out[key] = out.get(key, 0) + value
	return out


## How much of `stat` a set of worn gear gives in total (armor is capped).
static func total(equipment: Dictionary, stat: String) -> int:
	var sum := 0
	for slot in equipment:
		sum += int(stats(equipment[slot]).get(stat, 0))
	return mini(sum, MAX_ARMOR) if stat == "armor" else sum


## How much of a skill-tree stat (or "skills": extra ranks) one of the tamer's
## class rings or necklaces gives a pet of `pet_class`.
static func class_bonus(item: Dictionary, pet_class: String, stat: String) -> float:
	if not is_class_jewelry(item) or item["class"] != pet_class:
		return 0.0
	return float(item.affixes.get("cls_" + stat, 0))


## Set bonuses for a pet of `pet_class`: the pieces of that class's set worn
## by the tamer (`equipment`) and by party pets (`collars`) are counted, and
## each bonus whose piece count is reached adds its `stat` (percent).
static func set_bonus(stat: String, pet_class: String, equipment: Dictionary, collars: Array) -> float:
	var sum := 0.0
	for set_id: String in SETS:
		if SETS[set_id]["class"] != pet_class:
			continue
		var worn := {}
		for item in equipment.values() + collars:
			if item is Dictionary and item.get("set", "") == set_id and int(item.get("rarity", 0)) == SET:
				worn[item.get("unique", "")] = true
		for count: int in SETS[set_id].bonus:
			if worn.size() >= count:
				sum += float(SETS[set_id].bonus[count].get(stat, 0))
	return sum


## How much of a skill-tree stat (or "skills") a collar gives the pet wearing it.
static func pet_bonus(item: Dictionary, stat: String) -> float:
	if not is_collar(item):
		return 0.0
	var sum := float(item.base.get(stat, 0))
	for id: String in item.affixes:
		if PET_AFFIX_STAT.get(id, "") == stat or id == "cls_" + stat:
			sum += float(item.affixes[id])
	return sum


## What the item does, one line per stat; joined by `separator`.
static func effect(item: Dictionary, separator := "\n") -> String:
	if not is_item(item):
		return ""
	var lines := []
	var collar := is_collar(item)
	var who := "This pet" if collar else "Pets"
	for stat: String in item.base:
		var value := int(item.base[stat])
		lines.append(PET_TEXT.health % [who, value] if collar else TAMER_TEXT[stat] % value)
	for id: String in item.affixes:
		var value := int(item.affixes[id])
		if id.begins_with("cls_") and is_rolled(item):
			var owner: String = "This pet" if collar else "Your %s" % PET_GEAR[item["class"]].pets
			if id == "cls_skills":
				lines.append("%s: +%d to every skill rank" % [owner, value])
			else:
				var words: String = PetSkills.STAT_TEXT.get(id.substr(4), "+%d%%") % value
				if not collar:
					words = words.replace("takes ", "take ")  # "Your dogs: take 4% less damage"
				lines.append("%s: %s" % [owner, words])
		elif id == "poison_resist" and not collar:
			lines.append(TAMER_TEXT[id] % value)
		elif PET_AFFIX_STAT.has(id):
			lines.append(PET_TEXT[PET_AFFIX_STAT[id]] % [who, value])
		elif TAMER_TEXT.has(id):
			lines.append(TAMER_TEXT[id] % value)
	return separator.join(lines)


## A short description for tooltips and the details line.
static func describe(item: Dictionary) -> String:
	if not is_item(item):
		return ""
	var kind: String = "pet collar" if is_collar(item) else SLOT_NAMES[default_slot(item)].to_lower()
	if is_rolled(item):
		var gear: Dictionary = PET_GEAR[item["class"]]
		kind = "%s collar (for %s only)" % [gear.title, gear.pets] if is_collar(item) \
				else "%s %s (boosts your %s)" % [gear.title, kind, gear.pets]
	var lines := [display_name(item), "%s %s  ·  item level %d" % [RARITIES[int(item.rarity)].name, kind, int(item.ilvl)]]
	var fx := effect(item)
	if fx != "":
		lines.append(fx)
	if int(item.rarity) == SET and SETS.has(item.get("set", "")):
		var set_info: Dictionary = SETS[item.set]
		var parts := []
		for count: int in set_info.bonus:
			var words := []
			for stat: String in set_info.bonus[count]:
				words.append(PetSkills.STAT_TEXT.get(stat, "+%d%%").replace("takes ", "take ") % int(set_info.bonus[count][stat]))
			parts.append("%d pieces: %s" % [count, ", ".join(words)])
		lines.append("%s (your %s): %s" % [set_info.name, PET_GEAR[set_info["class"]].pets, "; ".join(parts)])
	return "\n".join(lines)


# --- Comparing items ---------------------------------------------------------------

## Everything an item gives, as {key: amount}, for comparing two items of the
## same slot. Tamer gear: its stats() keys, plus "cls:<class>:<stat>" for class
## affixes. Collars: skill-tree stats for the pet wearing it (and "skills").
static func summary(item: Dictionary) -> Dictionary:
	if not is_item(item):
		return {}
	if is_collar(item):
		var out := {}
		for stat: String in item.base:
			out[stat] = out.get(stat, 0) + int(item.base[stat])
		for id: String in item.affixes:
			var stat: String = PET_AFFIX_STAT.get(id, id.substr(4) if id.begins_with("cls_") else "")
			if stat != "":
				out[stat] = out.get(stat, 0) + int(item.affixes[id])
		return out
	var out := stats(item)
	out.erase("pet_poison_resist")  # shown once, as "Tamer and pets"
	for id: String in item.affixes:
		if id.begins_with("cls_") and is_rolled(item):
			out["cls:%s:%s" % [item["class"], id.substr(4)]] = int(item.affixes[id])
	return out


## Words for one summary() entry ("Pets: deal 7% more damage"); a negative
## value reads "Lose: ..." with the amount lost.
static func summary_text(key: String, value: int, collar: bool) -> String:
	if value < 0:
		return "Lose: " + _summary_words(key, -value, collar)
	return _summary_words(key, value, collar)


static func _summary_words(key: String, value: int, collar: bool) -> String:
	if collar:
		if key == "skills":
			return "This pet: +%d to every skill rank" % value
		if PET_TEXT.has(key):
			return PET_TEXT[key] % ["This pet", value]
		return "This pet: " + PetSkills.STAT_TEXT.get(key, key + " %d") % value
	if key.begins_with("cls:"):
		var bits := key.split(":")
		var pets: String = PET_GEAR.get(bits[1], {}).get("pets", "pets")
		if bits[2] == "skills":
			return "Your %s: +%d to every skill rank" % [pets, value]
		var words: String = PetSkills.STAT_TEXT.get(bits[2], bits[2] + " %d").replace("takes ", "take ")
		return "Your %s: %s" % [pets, words % value]
	if key.begins_with("pet_") and PET_TEXT.has(key.substr(4)):
		return PET_TEXT[key.substr(4)] % ["Pets", value]
	return TAMER_TEXT.get(key, key + " %d") % value


## What changes if `new` replaces `old`: one line per stat that differs, as
## [words, change] (change > 0 = better), biggest gains first.
static func compare(new: Dictionary, old: Dictionary) -> Array:
	var a := summary(new)
	var b := summary(old)
	var collar := is_collar(new)
	var out := []
	for key in a.keys() + b.keys().filter(func(k): return not a.has(k)):
		var delta := int(a.get(key, 0)) - int(b.get(key, 0))
		if delta != 0:
			out.append([summary_text(key, delta, collar), delta * _weight(key, collar)])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[1] > y[1])
	return out


## How good an item is, roughly, as one number (for the upgrade arrow).
## `pet_classes`: the classes in the party (class affixes for others count little).
static func power(item: Dictionary, pet_classes: Array = []) -> float:
	var sum := 0.0
	var collar := is_collar(item)
	for key: String in summary(item):
		var weight := _weight(key, collar)
		if key.begins_with("cls:") and not key.split(":")[1] in pet_classes:
			weight *= 0.1
		sum += weight * float(summary(item)[key])
	return sum


const _WEIGHTS := {
	"armor": 1.5, "health": 0.12, "speed": 0.8, "poison_resist": 0.3, "magic_find": 0.25, "coin_find": 0.1,
	"pet_damage": 1.0, "pet_health": 0.8, "pet_cooldown": 1.2, "pet_life_hit": 3.0,
	"damage": 1.0, "cooldown": 1.2, "life_hit": 3.0, "skills": 12.0,
}


static func _weight(key: String, collar := false) -> float:
	if collar and key == "health":
		return 0.8  # a pet's health, in percent
	if key.begins_with("cls:"):
		return 12.0 if key.ends_with(":skills") else 0.8
	if _WEIGHTS.has(key):
		return _WEIGHTS[key]
	return 0.8  # a class collar's skill-tree stats


# --- Saves and the network ------------------------------------------------------------

## An item from a save or a client, made safe: a known base, sensible numbers,
## only affixes that base can have, none above their best roll; or {} if it
## isn't a real item. Items from older versions are converted first.
static func clean(item) -> Dictionary:
	if not item is Dictionary or item.is_empty():
		return {}
	if int(item.get("v", 1)) < VERSION:
		item = _convert_v1(item)
		if item.is_empty():
			return {}
	var type := str(item.get("type", ""))
	if not BASES.has(type):
		return {}
	var fixed := int(item.get("rarity", 0))
	if fixed == UNIQUE or fixed == SET:
		return _clean_fixed(item)
	var ilvl := clampi(int(item.get("ilvl", 1)), 1, MAX_ILVL)
	var tier := clampi(int(item.get("tier", 1)), 1, 3)
	var rarity := clampi(int(item.get("rarity", 0)), NORMAL, RARE)
	var pet_class := str(item.get("class", ""))
	if not PET_GEAR.has(pet_class) or not type in CLASS_KINDS:
		pet_class = ""
	var base := {}
	var saved_base = item.get("base", {})
	if saved_base is Dictionary:
		for stat in saved_base:
			if BASES[type].base.has(str(stat)):
				var top: int = BASES[type].base[str(stat)][2][1]  # never above the best tier's best roll
				base[str(stat)] = clampi(int(saved_base[stat]), 1, top)
	var affixes := {}
	var saved_affixes = item.get("affixes", {})
	var pool := affix_pool(type, pet_class, MAX_ILVL)
	if saved_affixes is Dictionary:
		for id in saved_affixes:
			if str(id) in pool and affixes.size() < AFFIX_COUNT[RARE][1]:
				affixes[str(id)] = clampi(int(saved_affixes[id]), 1, affix_range(str(id), ilvl, type).y)
	var name := str(item.get("name", "")).left(32) if rarity == RARE else ""
	return {"v": VERSION, "type": type, "tier": tier, "ilvl": ilvl, "rarity": rarity, "class": pet_class,
			"base": base, "affixes": affixes, "name": name}


## A unique or set item from a save or a client: rebuilt from its table entry,
## keeping its rolls (none above the best possible).
static func _clean_fixed(item: Dictionary) -> Dictionary:
	var id := str(item.get("unique", ""))
	var ilvl := clampi(int(item.get("ilvl", 1)), 1, MAX_ILVL)
	var rng := RandomNumberGenerator.new()
	var fresh: Dictionary
	var mults: Dictionary
	if int(item.rarity) == UNIQUE and UNIQUES.has(id):
		fresh = make_unique(ilvl, rng, id)
		mults = UNIQUES[id][4]
	elif int(item.rarity) == SET and SETS.has(str(item.get("set", ""))) and SETS[str(item.set)].pieces.has(id):
		fresh = make_set_piece(ilvl, rng, id)
		mults = SETS[str(item.set)].pieces[id][2]
	else:
		return {}
	var saved = item.get("affixes", {})
	for affix: String in fresh.affixes:
		var top := maxi(1, roundi(affix_range(affix, int(fresh.ilvl), fresh.type).y * float(mults[affix])))
		if saved is Dictionary and saved.has(affix):
			fresh.affixes[affix] = clampi(int(saved[affix]), 1, top)
	return fresh


## Items from before version 2 (levels 1-5, one stat each): the same stats in
## the new form. Common becomes Normal, Fine Magic, Superior Rare; Legendary
## items are retired (gone). Old items with a bonus that the new Normal items
## don't have (rings, necklaces, collars) become at least Magic.
const _V1 := {
	"jacket": ["jacket", "base", "armor", [4, 7, 10, 13, 16], 2],
	"pants": ["pants", "base", "armor", [2, 4, 6, 8, 10], 1],
	"hat": ["hat", "base", "health", [10, 15, 20, 25, 30], 5],
	"boots": ["boots", "base", "speed", [3, 5, 7, 9, 11], 2],
	"ring": ["ring", "affix", "pet_damage", [3, 5, 7, 9, 12], 2],
	"necklace": ["necklace", "affix", "pet_health", [5, 8, 11, 14, 18], 3],
	"spiked_collar": ["collar", "affix", "pet_damage", [5, 8, 11, 14, 18], 2],
	"padded_collar": ["collar", "base", "health", [6, 10, 14, 18, 22], 3],
	"studded_collar": ["collar", "affix", "pet_health", [4, 6, 8, 10, 12], 2],
}


static func _convert_v1(old: Dictionary) -> Dictionary:
	var type := str(old.get("type", ""))
	var rarity := int(old.get("rarity", 0))
	var level := clampi(int(old.get("level", 1)), 1, 5)
	if rarity >= 3:
		return {}  # legendary items are retired
	rarity = clampi(rarity, 0, 2)
	var item := {"v": VERSION, "tier": 1, "ilvl": level * 5, "rarity": rarity, "class": "", "base": {}, "affixes": {}, "name": ""}
	if _V1.has(type):
		var spec: Array = _V1[type]
		item.type = spec[0]
		var value: int = spec[3][level - 1] + spec[4] * rarity
		if spec[1] == "base":
			item.base[spec[2]] = value
		else:
			item.affixes[spec[2]] = value
			item.rarity = maxi(rarity, MAGIC)
		return item
	if type in ["pet_gear", "class_ring", "class_necklace"] and old.get("stats") is Dictionary:
		item.type = {"pet_gear": "collar", "class_ring": "ring", "class_necklace": "necklace"}[type]
		item["class"] = str(old.get("class", ""))
		item.rarity = maxi(rarity, MAGIC)
		for stat in old.stats:
			item.affixes["cls_" + str(stat)] = int(old.stats[stat])
		return item
	return {}
