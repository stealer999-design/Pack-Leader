class_name PetSkills
## Selectable pet skills. Every species has a tree of six skills. Skill i
## unlocks at UNLOCK_LEVELS[i], and each can be trained up to MAX_RANK ranks with
## skill points: a pet earns one at level 5 and one every 2 levels after that
## (13 by level 30, against 24 possible ranks), so owners have to choose.
## Each rank of a skill boosts one stat by `amount` (a fraction):
##   damage       the pet's attack and ability damage
##   health       the pet's max health
##   armor        the pet takes this much less damage
##   pack_damage, pack_health, pack_armor
##                the same boost for *every* pet in its owner's party (itself
##                included), while this pet is awake. Pack skills stack.
## Tanks lean on armor and health, strikers on damage and supports on pack buffs.
## Skills only work for pets (yours or a rival's), not for wild creatures.
## A pet's ranks are an Array of SKILL_COUNT ints, kept on the Creature and in its saved data.

const SKILL_COUNT := 6
const MAX_RANK := 4
const UNLOCK_LEVELS: Array[int] = [5, 10, 15, 20, 25, 30]

const STAT_TEXT := {
	"damage": "+%d%% attack damage",
	"health": "+%d%% max health",
	"armor": "takes %d%% less damage",
	"pack_damage": "all your pets: +%d%% attack damage",
	"pack_health": "all your pets: +%d%% max health",
	"pack_armor": "all your pets take %d%% less damage",
}

## Indexed like SpeciesDB. Each entry: [name, stat, amount per rank], in unlock order.
const SKILLS := [
	[  # 0 Mossback (tank)
		["Thick Shell", "armor", 0.04], ["Mossy Hide", "health", 0.05], ["Hardened Shell", "armor", 0.04],
		["Herd Guardian", "pack_armor", 0.025], ["Ancient Bark", "health", 0.075], ["Living Fortress", "armor", 0.05],
	],
	[  # 1 Emberfox (striker)
		["Sharp Claws", "damage", 0.05], ["Fire Blood", "health", 0.04], ["Blazing Pounce", "damage", 0.05],
		["Kindle the Pack", "pack_damage", 0.025], ["Wildfire", "damage", 0.075], ["Inferno Heart", "pack_damage", 0.025],
	],
	[  # 2 Voltwing (striker)
		["Charged Claws", "damage", 0.05], ["Static Coat", "armor", 0.03], ["Overcharge", "damage", 0.05],
		["Battery", "health", 0.05], ["Storm Leader", "pack_damage", 0.025], ["Thunderclap", "damage", 0.075],
	],
	[  # 3 Gloomhorn (bruiser)
		["Heavy Horns", "damage", 0.05], ["Stout", "health", 0.05], ["Iron Hide", "armor", 0.04],
		["Rallying Roar", "pack_health", 0.025], ["Mountain's Weight", "health", 0.075], ["Earthborn", "armor", 0.05],
	],
	[  # 4 Frostfinch (striker)
		["Icy Talons", "damage", 0.05], ["Down Feathers", "health", 0.05], ["Frostbite", "damage", 0.05],
		["Flock Call", "pack_damage", 0.025], ["Frozen Plumage", "armor", 0.04], ["Blizzard Heart", "damage", 0.075],
	],
	[  # 5 Quillpuff (tank)
		["Puffed Quills", "armor", 0.04], ["Blubber", "health", 0.05], ["Ice Plating", "armor", 0.04],
		["Huddle", "pack_armor", 0.025], ["Glacier Body", "health", 0.075], ["Frozen Bastion", "armor", 0.05],
	],
	[  # 6 Aurora Swift (healer)
		["Light Feathers", "health", 0.05], ["Aurora Glow", "pack_health", 0.025], ["Shimmer", "armor", 0.03],
		["Northern Lights", "pack_armor", 0.02], ["Radiance", "health", 0.075], ["Celestial Choir", "pack_health", 0.04],
	],
	[  # 7 Snowl (assassin)
		["Silent Talons", "damage", 0.05], ["Keen Eyes", "damage", 0.05], ["Snow Cloak", "armor", 0.03],
		["Night Hunter", "damage", 0.075], ["Owl's Watch", "pack_damage", 0.025], ["Apex Predator", "damage", 0.075],
	],
	[  # 8 Bloomling (healer)
		["Deep Roots", "health", 0.05], ["Bloom Aura", "pack_health", 0.025], ["Thorny Petals", "armor", 0.03],
		["Pollen Haze", "pack_armor", 0.02], ["Evergreen", "health", 0.075], ["Spring Blessing", "pack_health", 0.04],
	],
	[  # 9 Fangjackal (striker)
		["Sharp Fangs", "damage", 0.05], ["Scrappy", "health", 0.05], ["Venom Glands", "damage", 0.05],
		["Pack Hunter", "pack_damage", 0.025], ["Desert Endurance", "health", 0.075], ["Alpha Bite", "damage", 0.075],
	],
	[  # 10 Dunehound (tank)
		["Thick Coat", "health", 0.05], ["Sand Hide", "armor", 0.04], ["Loyal Guard", "pack_armor", 0.025],
		["Broad Chest", "health", 0.075], ["Dune Stride", "damage", 0.05], ["Stone Hound", "armor", 0.05],
	],
	[  # 11 Cactipup (support)
		["Prickly", "armor", 0.04], ["Water Store", "health", 0.05], ["Spiny Hug", "pack_armor", 0.025],
		["Desert Bloom", "pack_health", 0.025], ["Needle Coat", "armor", 0.05], ["Oasis Heart", "pack_health", 0.04],
	],
	[  # 12 Sunfennec (striker)
		["Sun-Warmed", "damage", 0.05], ["Keen Ears", "armor", 0.03], ["Solar Bite", "damage", 0.05],
		["Sunny Howl", "pack_damage", 0.025], ["Heat Shimmer", "armor", 0.04], ["Noonday Fury", "damage", 0.075],
	],
	[  # 13 Bogleon (striker)
		["Sticky Tongue", "damage", 0.05], ["Camouflage", "armor", 0.04], ["Long Lash", "damage", 0.05],
		["Bog Skin", "health", 0.05], ["Swamp Ambush", "pack_damage", 0.025], ["Chameleon King", "damage", 0.075],
	],
	[  # 14 Mirelurk (tank)
		["Mud Coat", "armor", 0.04], ["Thick Scales", "health", 0.05], ["Murky Hide", "armor", 0.04],
		["Swamp Ward", "pack_armor", 0.025], ["Ancient Lurker", "health", 0.075], ["Bog Titan", "armor", 0.05],
	],
	[  # 15 Wisp Gecko (drainer)
		["Glow Bite", "damage", 0.05], ["Wisp Light", "health", 0.05], ["Spirit Hunger", "damage", 0.05],
		["Guiding Glow", "pack_health", 0.025], ["Ghost Skin", "armor", 0.04], ["Soul Lantern", "pack_damage", 0.025],
	],
	[  # 16 Sporeguana (support)
		["Spore Hide", "armor", 0.04], ["Fungal Bulk", "health", 0.05], ["Spore Mist", "pack_armor", 0.02],
		["Rot Resistance", "health", 0.075], ["Mycelium Link", "pack_health", 0.025], ["Bloom of Decay", "pack_armor", 0.03],
	],
	# Hybrids (from the breeder): a little stronger per rank than wild pets.
	[  # 17 Magmashell (tank)
		["Lava Shell", "armor", 0.05], ["Ember Heart", "health", 0.06], ["Molten Hide", "armor", 0.05],
		["Hearth Ward", "pack_armor", 0.03], ["Volcanic Bulk", "health", 0.09], ["Magma Fortress", "armor", 0.06],
	],
	[  # 18 Thundershell (tank)
		["Charged Shell", "armor", 0.05], ["Capacitor", "health", 0.06], ["Arc Plating", "armor", 0.05],
		["Storm Ward", "pack_armor", 0.03], ["Living Battery", "health", 0.09], ["Thunder Fortress", "armor", 0.06],
	],
	[  # 19 Stonehorn (bruiser)
		["Granite Horn", "damage", 0.06], ["Bedrock", "health", 0.06], ["Stone Skin", "armor", 0.05],
		["Mountain Call", "pack_health", 0.03], ["Boulder Body", "health", 0.09], ["Avalanche Horn", "damage", 0.09],
	],
	[  # 20 Mossbloom (healer)
		["Deep Moss", "health", 0.06], ["Grove Song", "pack_health", 0.03], ["Bark Petals", "armor", 0.04],
		["Canopy", "pack_armor", 0.025], ["Old Growth", "health", 0.09], ["Heart of the Grove", "pack_health", 0.05],
	],
	[  # 21 Blitzfox (striker)
		["Lightning Claws", "damage", 0.06], ["Quick Spark", "health", 0.05], ["Flashfire", "damage", 0.06],
		["Rally Spark", "pack_damage", 0.03], ["Blitz", "damage", 0.09], ["Storm Blaze", "pack_damage", 0.03],
	],
	[  # 22 Cinderhorn (bruiser)
		["Burning Horn", "damage", 0.06], ["Coal Hide", "armor", 0.05], ["Smoulder", "damage", 0.06],
		["War Drum", "pack_damage", 0.03], ["Furnace Heart", "health", 0.09], ["Meteor Horn", "damage", 0.09],
	],
	[  # 23 Sunpetal (healer)
		["Sunlit Petals", "health", 0.06], ["Warm Glow", "pack_health", 0.03], ["Ember Bark", "armor", 0.04],
		["Solar Bloom", "pack_damage", 0.025], ["Rebirth", "health", 0.09], ["Phoenix Choir", "pack_health", 0.05],
	],
	[  # 24 Stormhorn (striker)
		["Thunder Horn", "damage", 0.06], ["Storm Hide", "armor", 0.04], ["Overload", "damage", 0.06],
		["Rolling Thunder", "pack_damage", 0.03], ["Tempest", "damage", 0.09], ["Sky Breaker", "damage", 0.09],
	],
	[  # 25 Sparkblossom (support)
		["Static Petals", "armor", 0.05], ["Bright Bloom", "health", 0.06], ["Spark Ward", "pack_armor", 0.03],
		["Charged Pollen", "pack_damage", 0.03], ["Lightning Rod", "armor", 0.06], ["Storm Garden", "pack_armor", 0.04],
	],
	[  # 26 Duskbloom (bruiser)
		["Night Horn", "damage", 0.06], ["Shadow Petals", "armor", 0.05], ["Gloom Bulk", "health", 0.06],
		["Twilight Veil", "pack_armor", 0.03], ["Nightfall", "damage", 0.09], ["Eclipse", "pack_health", 0.04],
	],
]

## Armor from all sources is capped, so nothing becomes unkillable.
const MAX_ARMOR := 0.6


## Every skill of a species: [{name, stat, amount, level}] in unlock order.
static func all_for(species_index: int) -> Array:
	var out := []
	if species_index < 0 or species_index >= SKILLS.size():
		return out
	for i in SKILLS[species_index].size():
		var entry: Array = SKILLS[species_index][i]
		out.append({"name": entry[0], "stat": entry[1], "amount": entry[2], "level": UNLOCK_LEVELS[i]})
	return out


static func empty_ranks() -> Array:
	var ranks := []
	ranks.resize(SKILL_COUNT)
	ranks.fill(0)
	return ranks


## Skill points a pet has earned by `level`.
static func points_for_level(level: int) -> int:
	return 0 if level < 5 else (level - 5) / 2 + 1


static func points_spent(ranks: Array) -> int:
	var sum := 0
	for r in ranks:
		sum += int(r)
	return sum


static func points_left(level: int, ranks: Array) -> int:
	return points_for_level(level) - points_spent(ranks)


## Why skill `index` can't be trained another rank, or "" if it can.
static func cannot_train_reason(level: int, ranks: Array, index: int) -> String:
	if index < 0 or index >= SKILL_COUNT:
		return "No such skill."
	if level < UNLOCK_LEVELS[index]:
		return "Unlocks at level %d." % UNLOCK_LEVELS[index]
	if int(ranks[index]) >= MAX_RANK:
		return "Already at the top rank."
	if points_left(level, ranks) <= 0:
		return "No skill points left. Pets earn one every 2 levels from level 5."
	return ""


## `ranks` made safe: SKILL_COUNT ints in 0..MAX_RANK, no skill above the pet's
## level and no more points than it has earned (otherwise all ranks are reset).
static func clean_ranks(ranks, level: int) -> Array:
	var out := empty_ranks()
	if not ranks is Array:
		return out
	for i in mini(ranks.size(), SKILL_COUNT):
		var r := clampi(int(ranks[i]), 0, MAX_RANK)
		out[i] = r if level >= UNLOCK_LEVELS[i] else 0
	return out if points_left(level, out) >= 0 else empty_ranks()


## How a computer-controlled tamer trains a pet: one rank at a time, round-robin
## over the unlocked skills.
static func auto_ranks(level: int) -> Array:
	var ranks := empty_ranks()
	var progress := true
	while progress and points_left(level, ranks) > 0:
		progress = false
		for i in SKILL_COUNT:
			if points_left(level, ranks) > 0 and cannot_train_reason(level, ranks, i) == "":
				ranks[i] += 1
				progress = true
	return ranks


## The total bonus to one stat from a pet's trained skills.
static func total(species_index: int, ranks: Array, stat: String) -> float:
	var sum := 0.0
	var skills := all_for(species_index)
	for i in mini(skills.size(), ranks.size()):
		if skills[i].stat == stat:
			sum += skills[i].amount * int(ranks[i])
	return sum


## "+5% attack damage" for `rank` ranks of `skill`.
static func effect_text(skill: Dictionary, rank: int) -> String:
	return STAT_TEXT[skill.stat] % roundi(skill.amount * rank * 100.0)


static func is_pack(skill: Dictionary) -> bool:
	return skill.stat.begins_with("pack_")
