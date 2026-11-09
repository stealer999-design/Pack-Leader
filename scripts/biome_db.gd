class_name BiomeDB
## The biomes levels cycle through, 16 levels a cycle (LEVELS), with creature
## levels still rising. Act 1 is the first four biomes (one level each, in the
## order chosen at the Crossroads); Acts 2-5 are three levels each of the
## Graveyard, the desert ruins, the volcano and the ice fields (monsters only).
## After level 16 the cycle starts again, as Act 6, 7, ...
##
## species: indices into SpeciesDB that live in this biome.
## starter_species: if set, the first two creatures near the camp are always this one.
## boss: "rival" (a tamer with one pet), "titan", "wyrm", "witch", "fish",
## "pharaoh", "lion", "cat", "colossus", "firedog", "yeti" or "parrot";
## champions: optional species of the Champions ending the act's first two levels.
## obstacles: which obstacle set dresses the level (default by position).
## boss_name: how the boss is named in objectives (rivals get a random name).

const BIOMES := [
	{
		"name": "Greenmeadow",
		"species": [0, 1, 2, 3, 8],
		"starter_species": 8,
		"boss": "rival",
		"floor_hue": Vector2(0.22, 0.36), "floor_sat": 0.25, "floor_val": 0.38,
		"camp": Color(0.45, 0.43, 0.38), "arena": Color(0.36, 0.3, 0.3),
		"wall": Color(0.4, 0.38, 0.42), "rock": Color(0.55, 0.5, 0.45),
	},
	{
		"name": "Frostfang Peaks",
		"species": [4, 5, 6, 7],
		"boss": "titan",
		"boss_name": "the Glacier Titan",
		"floor_hue": Vector2(0.56, 0.62), "floor_sat": 0.22, "floor_val": 0.42,
		"camp": Color(0.36, 0.4, 0.48), "arena": Color(0.3, 0.34, 0.46),
		"wall": Color(0.5, 0.58, 0.7), "rock": Color(0.42, 0.62, 0.82),
	},
	{
		"name": "Sunscorch Dunes",
		"species": [9, 10, 11, 12],
		"boss": "wyrm",
		"boss_name": "the Sand Wyrm",
		"floor_hue": Vector2(0.08, 0.11), "floor_sat": 0.5, "floor_val": 0.42,
		"camp": Color(0.45, 0.36, 0.25), "arena": Color(0.42, 0.3, 0.2),
		"wall": Color(0.5, 0.38, 0.25), "rock": Color(0.55, 0.42, 0.28),
	},
	{
		"name": "Mirewood Bog",
		"species": [13, 14, 15, 16],
		"boss": "witch",
		"boss_name": "the Bog Witch",
		"floor_hue": Vector2(0.2, 0.28), "floor_sat": 0.4, "floor_val": 0.3,
		"camp": Color(0.32, 0.29, 0.22), "arena": Color(0.24, 0.27, 0.2),
		"wall": Color(0.26, 0.32, 0.22), "rock": Color(0.36, 0.3, 0.24),
	},
	{
		"name": "Hollowmere Graveyard",
		"species": [45, 46],  # skeletons and zombies: monsters, not pets
		"boss": "fish",
		"boss_name": "Howard the Zombie Fish",
		"floor_hue": Vector2(0.18, 0.26), "floor_sat": 0.16, "floor_val": 0.3,
		"camp": Color(0.3, 0.29, 0.3), "arena": Color(0.26, 0.25, 0.3),
		"wall": Color(0.3, 0.3, 0.34), "rock": Color(0.42, 0.42, 0.45),
	},
	{
		"name": "Scorchsand Ruins",
		"species": [47, 48],  # mummies and sand scorpions
		"boss": "cat",
		"boss_name": "Dom the House Cat",
		# The Champions at the end of the act's first two levels, in order
		# (default: a random monster of the biome).
		"champions": [45, 47],  # a skeleton, then a mummy
		"obstacles": "desert",
		"floor_hue": Vector2(0.09, 0.12), "floor_sat": 0.45, "floor_val": 0.46,
		"camp": Color(0.5, 0.42, 0.3), "arena": Color(0.48, 0.36, 0.22),
		"wall": Color(0.58, 0.46, 0.3), "rock": Color(0.62, 0.5, 0.34),
	},
	{
		"name": "Cinderpeak Caldera",
		"species": [49, 50],  # fire imps and magma golems
		"boss": "firedog",
		"boss_name": "Koleko the Fire Dog",
		"obstacles": "volcano",
		"floor_hue": Vector2(0.0, 0.04), "floor_sat": 0.3, "floor_val": 0.22,
		"camp": Color(0.28, 0.24, 0.23), "arena": Color(0.3, 0.18, 0.14),
		"wall": Color(0.2, 0.17, 0.17), "rock": Color(0.26, 0.22, 0.22),
	},
	{
		"name": "Frostveil Expanse",
		"species": [51, 52],  # frost wraiths and yetis
		"boss": "parrot",
		"boss_name": "Pie the Parrot",
		"obstacles": "frost",
		"floor_hue": Vector2(0.54, 0.6), "floor_sat": 0.16, "floor_val": 0.55,
		"camp": Color(0.42, 0.47, 0.55), "arena": Color(0.36, 0.42, 0.56),
		"wall": Color(0.62, 0.72, 0.84), "rock": Color(0.55, 0.75, 0.92),
	},
]
## Which biomes make up each act (indices into BIOMES): Act 1 is the four
## Crossroads areas (in the order the players choose); each of Acts 2-5 is one
## monster biome, three levels long.
const ACTS := [[0, 1, 2, 3], [4], [5], [6], [7]]
## One cycle of levels, in order: the biome of each (-1 = an Act 1 area, in
## the chosen order). After the last the cycle starts again (Act 6 is Act 1's
## areas, stronger, and so on).
const LEVELS := [-1, -1, -1, -1, 4, 4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 7]
## Which levels of the cycle (positions in LEVELS) each act covers.
const ACT_LEVELS := [[0, 1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12], [13, 14, 15]]


## The Act 1 biomes, in the order the players chose them at the Crossroads
## (World.route, synced). Act 1's areas follow this order; areas not chosen yet
## fall back to the remaining biomes in their usual order.
static var route: Array = []
## Level 0 is the Crossroads, the hub where the players pick their next Act 1
## area. It looks like Greenmeadow.
const CROSSROADS := 0
## What lives in each Act 1 biome, for the Crossroads signs.
const PET_TEXT := {0: "Cats  ·  Wizards", 1: "Birds  ·  Archers", 2: "Dogs  ·  Paladins", 3: "Lizards  ·  Venomancers"}


static func index_for_level(level_number: int) -> int:
	if level_number <= CROSSROADS:
		return 0
	var position := (level_number - 1) % LEVELS.size()
	if LEVELS[position] < 0:
		return act1_order()[ACT_LEVELS[0].find(position)]
	return LEVELS[position]


## The Act 1 biomes in play order: the chosen route, then the rest.
static func act1_order() -> Array:
	var order := route.filter(func(b) -> bool: return b in ACTS[0])
	for b in ACTS[0]:
		if b not in order:
			order.append(b)
	return order


static func for_level(level_number: int) -> Dictionary:
	return BIOMES[index_for_level(level_number)]


## Where area `level_number` falls: {act: 1, 2, ... (rising each time the
## cycle repeats), area: its place in that act (1-based)}.
## Acts 2-5 (and their repeats) are open fields instead of a winding path
## (see LevelGenerator.generate_open).
static func is_open_level(level_number: int) -> bool:
	if level_number <= CROSSROADS:
		return false
	return LEVELS[(level_number - 1) % LEVELS.size()] >= 0


## True if this level ends with its biome's named boss: every Act 1 area, and
## the last level of each later act. The other levels end with a Champion (a
## giant, much tougher monster of the act; see World._start_level).
static func has_named_boss(level_number: int) -> bool:
	if level_number <= CROSSROADS:
		return false
	var position := (level_number - 1) % LEVELS.size()
	for act in ACT_LEVELS:
		if position in act:
			return act == ACT_LEVELS[0] or position == act[-1]
	return true


static func act_of(level_number: int) -> Dictionary:
	if level_number <= CROSSROADS:
		return {"act": 1, "area": 0}
	var n := maxi(level_number, 1) - 1
	var cycle := n / LEVELS.size()
	var index := n % LEVELS.size()
	for a in ACT_LEVELS.size():
		if index in ACT_LEVELS[a]:
			return {"act": cycle * ACT_LEVELS.size() + a + 1, "area": ACT_LEVELS[a].find(index) + 1}
	return {"act": 1, "area": 1}
