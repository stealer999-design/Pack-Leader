class_name DungeonDB
## The key dungeons of the tile levels (Act 2 on): every level has a small
## dungeon, entered through a themed entrance somewhere on the map. At its far
## end an elite Keeper guards the key that unlocks the gate to the boss arena
## (LevelGenerator lays it out; World builds it, moves players in and out, and
## opens the gate when someone picks up the key).
##
## Each biome has its own kind of dungeon (BiomeDB's "dungeon"):
## - crypt: the graveyard's stone crypts, a mausoleum on the surface.
## - sandstone: the desert's sandstone-walled vaults, a stepped stone doorway.
## - ancient: the volcano's mysterious caves, carved long ago by someone: a
##   worked stone archway with glowing runes, set into a rock mound.
## - cave: the swamp's natural caves, a mossy rock mound with a dark mouth.
## - ice: the frozen halls, an igloo over a tunnel into carved ice walls.

const THEMES := {
	"crypt": {
		"place": "the crypt", "entrance": "Crypt", "key": "Crypt Key", "keeper": "Crypt Keeper",
		# Worn grey flagstones (ambientCG Bricks008), fully dull; a dark stone pillar
		# model standing in the middle of each room (LevelGenerator._dungeon).
		"floor_texture": "res://textures/dungeon/crypt/floor_", "floor_tile": 18.0, "floor_roughness": 1.0, "floor_specular": 0.05,
		"floor_aligned": true,  # its stones run along the walls (not on the world grid, which is diagonal to them)
		"pillar_model": "res://models/dungeon/crypt/stone_pillar.glb", "pillar_width": 0.9, "centre_pillars": true,
		# Concrete walls (ambientCG Concrete030) in the walls' own grey, a carved
		# crown moulding along the top of every tall wall, in the same concrete.
		"wall_texture": "res://textures/dungeon/crypt/wall_", "wall_tile": 5.0, "wall_tint": Color(0.89, 0.88, 0.99),
		"crown_moulding": true,
		# Torches (models/dungeon/torches/): on tripods in place of braziers, and on
		# the tall walls, between its burial niches.
		"floor_torch": "res://models/dungeon/torches/floor_torch.glb",
		"wall_torch": "res://models/dungeon/torches/wall_torch.glb", "wall_torch_offset": 4.0,
		# Their light white (turned down, as dim as the braziers'), so the grey stone stays grey.
		"torch_light": Color(1.0, 1.0, 1.0), "torch_strength": 0.7,
		"wall": Color(0.34, 0.33, 0.36), "trim": Color(0.22, 0.21, 0.24), "floor_style": "flagstone",
		"floor": Color(0.3, 0.29, 0.32), "glow": Color(0.6, 0.85, 1.0), "key_color": Color(0.75, 0.85, 1.0),
	},
	"sandstone": {
		"place": "the sandstone vault", "entrance": "Vault", "key": "Sun Key", "keeper": "Vault Keeper",
		"floor_texture": "res://textures/dungeon/sandstone/tiles144_", "floor_tile": 8.0, "floor_roughness": 0.9,
		# Sandstone from ambientCG (CC0): dressed blocks (Bricks084) for the walls,
		# rough layered stone (Bricks083) for the pillars, wall_tile / pillar_tile
		# units a repeat.
		"wall_texture": "res://textures/dungeon/sandstone/wall_", "wall_tile": 4.0,
		# Torches (models/dungeon/torches/): on tripods in place of braziers, and on
		# the tall walls, which are otherwise bare.
		"floor_torch": "res://models/dungeon/torches/floor_torch.glb",
		"wall_torch": "res://models/dungeon/torches/wall_torch.glb", "bare_walls": true,
		"torch_light": Color(1.0, 0.5, 0.18), "torch_strength": 1.0,  # their light orange, warming the sandstone
		"pillar_texture": "res://textures/dungeon/sandstone/pillar_", "pillar_tile": 9.0,
		"wall": Color(0.8, 0.64, 0.42), "trim": Color(0.62, 0.47, 0.3), "floor_style": "flagstone",
		"floor": Color(0.7, 0.57, 0.38), "glow": Color(1.0, 0.72, 0.3), "key_color": Color(1.0, 0.82, 0.35),
	},
	"ancient": {
		"place": "the ancient caves", "entrance": "Ancient Cave", "key": "Ember Key", "keeper": "Cave Keeper",
		"wall": Color(0.2, 0.18, 0.19), "trim": Color(0.34, 0.3, 0.28), "floor_style": "flagstone",
		"floor": Color(0.2, 0.17, 0.17), "glow": Color(1.0, 0.45, 0.12), "key_color": Color(1.0, 0.5, 0.2),
	},
	"cave": {
		"place": "the bog cave", "entrance": "Cave", "key": "Bog Key", "keeper": "Cave Lurker",
		"wall": Color(0.3, 0.32, 0.25), "trim": Color(0.22, 0.3, 0.16), "floor_style": "swamp",
		"floor": Color(0.42, 0.45, 0.32), "glow": Color(0.55, 1.0, 0.6), "key_color": Color(0.6, 1.0, 0.55),
	},
	"ice": {
		"place": "the ice halls", "entrance": "Igloo", "key": "Frost Key", "keeper": "Ice Warden",
		# Models (Meshy, low poly; see DungeonBuilder): carved ice wall segments,
		# support pillars, brazier pillars, an archway and a fountain plaza.
		"models": {
			"wall": "res://models/dungeon/ice/wall_segment.glb", "pillar": "res://models/dungeon/ice/support_pillar.glb",
			"brazier": "res://models/dungeon/ice/brazier_pillar.glb", "arch": "res://models/dungeon/ice/archway.glb",
			"centre": "res://models/dungeon/ice/fountain.glb",
		},
		# An open hall instead of a maze: walls only round the outside and round
		# the Keeper's corner room, entered through an archway (LevelGenerator._hall).
		"open_hall": true,
		# The floor: a photo-scanned ice texture (textures/dungeon/ice/), tiled every floor_tile units.
		"floor_texture": "res://textures/dungeon/ice/ice002_", "floor_tile": 14.0,
		"wall": Color(0.72, 0.86, 0.97), "trim": Color(0.55, 0.74, 0.92), "floor_style": "snow",
		"floor": Color(0.72, 0.84, 0.96), "glow": Color(0.55, 0.9, 1.0), "key_color": Color(0.6, 0.95, 1.0),
	},
}
## The dungeon of each biome (by BiomeDB.BIOMES index); others get a crypt.
const BY_BIOME := {3: "cave", 4: "crypt", 5: "sandstone", 6: "ancient", 7: "ice"}


static func theme_id(biome_index: int) -> String:
	return BY_BIOME.get(biome_index, "crypt")


static func theme(biome_index: int) -> Dictionary:
	return THEMES[theme_id(biome_index)]
