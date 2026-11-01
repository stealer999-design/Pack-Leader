class_name BiomeDB
## The biomes levels cycle through. Level 1 uses the first biome, level 2 the
## second, and so on, wrapping around (with creature levels still rising).
## They are grouped into acts (ACTS): Act 1 is the first four biomes, Act 2 the
## Graveyard, the desert ruins, the volcano and the ice fields (monsters only); after that the cycle starts again, as Act 3, 4, ...
##
## species: indices into SpeciesDB that live in this biome.
## starter_species: if set, the first two creatures near the camp are always this one.
## boss: "rival" (a tamer with one pet), "titan", "wyrm", "witch", "fish",
## "pharaoh", "colossus" or "yeti";
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
		"boss": "pharaoh",
		"boss_name": "the Sand Pharaoh",
		"obstacles": "desert",
		"floor_hue": Vector2(0.09, 0.12), "floor_sat": 0.45, "floor_val": 0.46,
		"camp": Color(0.5, 0.42, 0.3), "arena": Color(0.48, 0.36, 0.22),
		"wall": Color(0.58, 0.46, 0.3), "rock": Color(0.62, 0.5, 0.34),
	},
	{
		"name": "Cinderpeak Caldera",
		"species": [49, 50],  # fire imps and magma golems
		"boss": "colossus",
		"boss_name": "the Magma Colossus",
		"obstacles": "volcano",
		"floor_hue": Vector2(0.0, 0.04), "floor_sat": 0.3, "floor_val": 0.22,
		"camp": Color(0.28, 0.24, 0.23), "arena": Color(0.3, 0.18, 0.14),
		"wall": Color(0.2, 0.17, 0.17), "rock": Color(0.26, 0.22, 0.22),
	},
	{
		"name": "Frostveil Expanse",
		"species": [51, 52],  # frost wraiths and yetis
		"boss": "yeti",
		"boss_name": "the Yeti King",
		"obstacles": "frost",
		"floor_hue": Vector2(0.54, 0.6), "floor_sat": 0.16, "floor_val": 0.55,
		"camp": Color(0.42, 0.47, 0.55), "arena": Color(0.36, 0.42, 0.56),
		"wall": Color(0.62, 0.72, 0.84), "rock": Color(0.55, 0.75, 0.92),
	},
]
## Which biomes make up each act (indices into BIOMES, in order).
const ACTS := [[0, 1, 2, 3], [4, 5, 6, 7]]


static func index_for_level(level_number: int) -> int:
	return (maxi(level_number, 1) - 1) % BIOMES.size()


static func for_level(level_number: int) -> Dictionary:
	return BIOMES[index_for_level(level_number)]


## Where area `level_number` falls: {act: 1, 2, ... (rising each time the
## cycle repeats), area: its place in that act (1-based)}.
static func act_of(level_number: int) -> Dictionary:
	var n := maxi(level_number, 1) - 1
	var cycle := n / BIOMES.size()
	var index := n % BIOMES.size()
	for a in ACTS.size():
		if index in ACTS[a]:
			return {"act": cycle * ACTS.size() + a + 1, "area": ACTS[a].find(index) + 1}
	return {"act": 1, "area": 1}
