class_name BiomeDB
## The biomes levels cycle through. Level 1 uses the first biome, level 2 the
## second, and so on, wrapping around (with creature levels still rising).
##
## species: indices into SpeciesDB that live in this biome.
## starter_species: if set, the first two creatures near the camp are always this one.
## boss: "rival" (a tamer with one pet) or "titan" (the Glacier Titan).

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
		"floor_hue": Vector2(0.56, 0.62), "floor_sat": 0.22, "floor_val": 0.42,
		"camp": Color(0.36, 0.4, 0.48), "arena": Color(0.3, 0.34, 0.46),
		"wall": Color(0.5, 0.58, 0.7), "rock": Color(0.42, 0.62, 0.82),
	},
]


static func index_for_level(level_number: int) -> int:
	return (maxi(level_number, 1) - 1) % BIOMES.size()


static func for_level(level_number: int) -> Dictionary:
	return BIOMES[index_for_level(level_number)]
