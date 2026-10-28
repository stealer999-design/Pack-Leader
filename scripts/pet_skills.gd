class_name PetSkills
## Passive skills: every species learns one at each of UNLOCK_LEVELS. Each skill
## boosts one stat by `amount` (a fraction):
##   damage       the pet's attack and ability damage
##   health       the pet's max health
##   armor        the pet takes this much less damage
##   pack_damage, pack_health, pack_armor
##                the same boost for *every* pet in its owner's party (itself
##                included), while this pet is awake. Pack skills stack.
## Tanks lean on armor and health, strikers on damage and supports on pack buffs.
## Skills only work for pets (yours or a rival's), not for wild creatures.

const UNLOCK_LEVELS: Array[int] = [5, 10, 15, 20, 25, 30]

const STAT_TEXT := {
	"damage": "+%d%% attack damage",
	"health": "+%d%% max health",
	"armor": "takes %d%% less damage",
	"pack_damage": "all your pets: +%d%% attack damage",
	"pack_health": "all your pets: +%d%% max health",
	"pack_armor": "all your pets take %d%% less damage",
}

## Indexed like SpeciesDB. Each entry: [name, stat, amount], in unlock order.
const SKILLS := [
	[  # 0 Mossback (tank)
		["Thick Shell", "armor", 0.08], ["Mossy Hide", "health", 0.10], ["Hardened Shell", "armor", 0.08],
		["Herd Guardian", "pack_armor", 0.05], ["Ancient Bark", "health", 0.15], ["Living Fortress", "armor", 0.10],
	],
	[  # 1 Emberfox (striker)
		["Sharp Claws", "damage", 0.10], ["Fire Blood", "health", 0.08], ["Blazing Pounce", "damage", 0.10],
		["Kindle the Pack", "pack_damage", 0.05], ["Wildfire", "damage", 0.15], ["Inferno Heart", "pack_damage", 0.05],
	],
	[  # 2 Voltwing (striker)
		["Charged Claws", "damage", 0.10], ["Static Coat", "armor", 0.06], ["Overcharge", "damage", 0.10],
		["Battery", "health", 0.10], ["Storm Leader", "pack_damage", 0.05], ["Thunderclap", "damage", 0.15],
	],
	[  # 3 Gloomhorn (bruiser)
		["Heavy Horns", "damage", 0.10], ["Stout", "health", 0.10], ["Iron Hide", "armor", 0.08],
		["Rallying Roar", "pack_health", 0.05], ["Mountain's Weight", "health", 0.15], ["Earthborn", "armor", 0.10],
	],
	[  # 4 Frostfinch (striker)
		["Icy Talons", "damage", 0.10], ["Down Feathers", "health", 0.10], ["Frostbite", "damage", 0.10],
		["Flock Call", "pack_damage", 0.05], ["Frozen Plumage", "armor", 0.08], ["Blizzard Heart", "damage", 0.15],
	],
	[  # 5 Quillpuff (tank)
		["Puffed Quills", "armor", 0.08], ["Blubber", "health", 0.10], ["Ice Plating", "armor", 0.08],
		["Huddle", "pack_armor", 0.05], ["Glacier Body", "health", 0.15], ["Frozen Bastion", "armor", 0.10],
	],
	[  # 6 Aurora Swift (healer)
		["Light Feathers", "health", 0.10], ["Aurora Glow", "pack_health", 0.05], ["Shimmer", "armor", 0.06],
		["Northern Lights", "pack_armor", 0.04], ["Radiance", "health", 0.15], ["Celestial Choir", "pack_health", 0.08],
	],
	[  # 7 Snowl (assassin)
		["Silent Talons", "damage", 0.10], ["Keen Eyes", "damage", 0.10], ["Snow Cloak", "armor", 0.06],
		["Night Hunter", "damage", 0.15], ["Owl's Watch", "pack_damage", 0.05], ["Apex Predator", "damage", 0.15],
	],
	[  # 8 Bloomling (healer)
		["Deep Roots", "health", 0.10], ["Bloom Aura", "pack_health", 0.05], ["Thorny Petals", "armor", 0.06],
		["Pollen Haze", "pack_armor", 0.04], ["Evergreen", "health", 0.15], ["Spring Blessing", "pack_health", 0.08],
	],
	[  # 9 Fangjackal (striker)
		["Sharp Fangs", "damage", 0.10], ["Scrappy", "health", 0.10], ["Venom Glands", "damage", 0.10],
		["Pack Hunter", "pack_damage", 0.05], ["Desert Endurance", "health", 0.15], ["Alpha Bite", "damage", 0.15],
	],
	[  # 10 Dunehound (tank)
		["Thick Coat", "health", 0.10], ["Sand Hide", "armor", 0.08], ["Loyal Guard", "pack_armor", 0.05],
		["Broad Chest", "health", 0.15], ["Dune Stride", "damage", 0.10], ["Stone Hound", "armor", 0.10],
	],
	[  # 11 Cactipup (support)
		["Prickly", "armor", 0.08], ["Water Store", "health", 0.10], ["Spiny Hug", "pack_armor", 0.05],
		["Desert Bloom", "pack_health", 0.05], ["Needle Coat", "armor", 0.10], ["Oasis Heart", "pack_health", 0.08],
	],
	[  # 12 Sunfennec (striker)
		["Sun-Warmed", "damage", 0.10], ["Keen Ears", "armor", 0.06], ["Solar Bite", "damage", 0.10],
		["Sunny Howl", "pack_damage", 0.05], ["Heat Shimmer", "armor", 0.08], ["Noonday Fury", "damage", 0.15],
	],
	[  # 13 Bogleon (striker)
		["Sticky Tongue", "damage", 0.10], ["Camouflage", "armor", 0.08], ["Long Lash", "damage", 0.10],
		["Bog Skin", "health", 0.10], ["Swamp Ambush", "pack_damage", 0.05], ["Chameleon King", "damage", 0.15],
	],
	[  # 14 Mirelurk (tank)
		["Mud Coat", "armor", 0.08], ["Thick Scales", "health", 0.10], ["Murky Hide", "armor", 0.08],
		["Swamp Ward", "pack_armor", 0.05], ["Ancient Lurker", "health", 0.15], ["Bog Titan", "armor", 0.10],
	],
	[  # 15 Wisp Gecko (drainer)
		["Glow Bite", "damage", 0.10], ["Wisp Light", "health", 0.10], ["Spirit Hunger", "damage", 0.10],
		["Guiding Glow", "pack_health", 0.05], ["Ghost Skin", "armor", 0.08], ["Soul Lantern", "pack_damage", 0.05],
	],
	[  # 16 Sporeguana (support)
		["Spore Hide", "armor", 0.08], ["Fungal Bulk", "health", 0.10], ["Spore Mist", "pack_armor", 0.04],
		["Rot Resistance", "health", 0.15], ["Mycelium Link", "pack_health", 0.05], ["Bloom of Decay", "pack_armor", 0.06],
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


## The skills a pet of this species has learned by `level`.
static func learned(species_index: int, level: int) -> Array:
	return all_for(species_index).filter(func(s: Dictionary) -> bool: return level >= s.level)


## The total bonus of one stat from a pet's own learned skills.
static func total(species_index: int, level: int, stat: String) -> float:
	var sum := 0.0
	for skill in learned(species_index, level):
		if skill.stat == stat:
			sum += skill.amount
	return sum


## The skill learned exactly at `level`, or {}.
static func unlocked_at(species_index: int, level: int) -> Dictionary:
	for skill in all_for(species_index):
		if skill.level == level:
			return skill
	return {}


static func describe(skill: Dictionary) -> String:
	return "%s: %s" % [skill.name, STAT_TEXT[skill.stat] % roundi(skill.amount * 100.0)]
