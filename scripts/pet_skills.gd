class_name PetSkills
## Selectable pet skills. Every pet has a tree of six skills from its class
## (CLASS_TREES: wizards, paladins, archers and venomancers each have their
## own). Skill i unlocks at UNLOCK_LEVELS[i], and each can be trained up to
## MAX_RANK ranks with skill points: a pet earns one at level 5 and one every
## 2 levels after that (13 by level 30, against 24 possible ranks), so owners
## have to choose. Each rank boosts one stat by `amount` (a fraction):
##   damage, health, armor     the pet's attack damage, max health, damage taken
##   spell_power               its ability damage (and poison from abilities)
##   cooldown                  its ability cooldowns (shorter)
##   heal_power                its heals and shields, including holy strikes
##   crit_chance, crit_damage  its critical hits (chance; extra damage on a crit)
##   attack_speed              its basic attacks come faster
##   dot_power, dot_duration   its poison and burns (stronger; last longer)
##   toxic_blood               the poison it gives whatever hits it
##   pack_<stat>               the same boost for *every* pet in its owner's
##                             party (itself included), while this pet is awake.
## Skills only work for pets (yours or a rival's), not for wild creatures.
## A pet's ranks are an Array of SKILL_COUNT ints, kept on the Creature and in its saved data.

const SKILL_COUNT := 6
const MAX_RANK := 4
const UNLOCK_LEVELS: Array[int] = [5, 10, 15, 20, 25, 30]

const STAT_TEXT := {
	"damage": "+%d%% attack damage",
	"health": "+%d%% max health",
	"armor": "takes %d%% less damage",
	"spell_power": "+%d%% ability damage",
	"cooldown": "abilities recharge %d%% faster",
	"heal_power": "+%d%% healing and shields",
	"crit_chance": "+%d%% critical hit chance",
	"crit_damage": "crits deal +%d%% more damage",
	"attack_speed": "attacks %d%% faster",
	"dot_power": "+%d%% poison and burn damage",
	"dot_duration": "poison and burns last %d%% longer",
	"toxic_blood": "+%d%% toxic blood poison",
	"pack_damage": "all your pets: +%d%% attack damage",
	"pack_health": "all your pets: +%d%% max health",
	"pack_armor": "all your pets take %d%% less damage",
	"pack_spell_power": "all your pets: +%d%% ability damage",
	"pack_crit_chance": "all your pets: +%d%% critical hit chance",
	"pack_heal_power": "all your pets: +%d%% healing and shields",
}

## Each class's tree: [name, stat, amount per rank], in unlock order.
const CLASS_TREES := {
	"wizard": [
		["Arcane Focus", "spell_power", 0.08], ["Mana Flow", "cooldown", 0.06], ["Charged Bolts", "damage", 0.06],
		["Ley Lines", "pack_spell_power", 0.03], ["Spell Ward", "armor", 0.04], ["Archmage", "spell_power", 0.12],
	],
	"paladin": [
		["Holy Strength", "heal_power", 0.1], ["Iron Hide", "armor", 0.04], ["Devotion", "cooldown", 0.06],
		["Aura of Protection", "pack_armor", 0.025], ["Vitality", "health", 0.07], ["Beacon of Light", "pack_heal_power", 0.06],
	],
	"archer": [
		["Sharpshooter", "crit_chance", 0.04], ["Quick Draw", "attack_speed", 0.07], ["Deadly Precision", "crit_damage", 0.2],
		["Hunting Party", "pack_crit_chance", 0.02], ["Steady Aim", "damage", 0.06], ["Volley Master", "spell_power", 0.1],
	],
	"venomancer": [
		["Potent Venom", "dot_power", 0.08], ["Thick Scales", "armor", 0.04], ["Lingering Toxins", "dot_duration", 0.12],
		["Toxic Blood", "toxic_blood", 0.25], ["Plague Bearer", "pack_damage", 0.025], ["Virulence", "dot_power", 0.12],
	],
}

## The tree's name, as shown in the skill window.
const TREE_NAMES := {"wizard": "Wizard", "paladin": "Paladin", "archer": "Archer", "venomancer": "Venomancer"}

## Caps, so nothing becomes unkillable or casts nonstop.
const MAX_COOLDOWN := 0.5

## Armor from all sources is capped, so nothing becomes unkillable.
const MAX_ARMOR := 0.6


## Every skill of a species (its class's tree): [{name, stat, amount, level}]
## in unlock order.
static func all_for(species_index: int) -> Array:
	var out := []
	if species_index < 0 or species_index >= SpeciesDB.PATHS.size():
		return out
	var tree: Array = CLASS_TREES.get(SpeciesDB.get_species(species_index).pet_class(), [])
	for i in tree.size():
		var entry: Array = tree[i]
		out.append({"name": entry[0], "stat": entry[1], "amount": entry[2], "level": UNLOCK_LEVELS[i]})
	return out


## "Wizard" etc. for a species' tree ("" if it has none).
static func tree_name(species_index: int) -> String:
	return TREE_NAMES.get(SpeciesDB.get_species(species_index).pet_class(), "")


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
