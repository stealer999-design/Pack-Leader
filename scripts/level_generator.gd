class_name LevelGenerator
## Builds the layout of one level from a seed: a single path that always
## heads the same way (local -Z), winding left and right, from a start camp
## (with the stable) to the boss arena at the end.
##
## Pure data and fully deterministic: every peer generates the same layout from
## the same seed, so only the seed has to be sent over the network.

const SEGMENT_LENGTH := 32.0
const START_LENGTH := 36.0
const START_WIDTH := 44.0
const ARENA_LENGTH := 52.0
const ARENA_WIDTH := 56.0
const MIN_PATH_WIDTH := 24.0
const MAX_PATH_WIDTH := 40.0
const SHOP_CLEARANCE := 9.0  ## No rocks, creatures or crates this close to the lemonade stand.
const MAX_SWAY := 20.0  ## How far the path may drift sideways from its start line.
## The village: a side path off the far wall of the middle segment, at a right
## angle (up the screen), leading to a square with the bat shop.
const VILLAGE_PATH_WIDTH := 12.0
const VILLAGE_PATH_LENGTH := 18.0
const PLAZA_SIZE := Vector2(30.0, 28.0)  ## x (away from the path) by z (along it).

const RIVAL_NAMES := ["Kael", "Mira", "Dax", "Vesper", "Rook", "Sable", "Juno", "Thorne", "Lyra", "Brann"]


## Returns:
## {
##   segments: [{ z_start, z_end, center_x, width, kind }]   kind = "start" | "path" | "arena"
##   rocks: [{ pos: Vector3, size: Vector3 }]
##   creature_spots: [{ pos: Vector3, depth: float }]   depth = 0..1 along the path
##   crate_spots: [{ pos: Vector3, gold: bool }]
##   shop_point: Vector3, shop_side: float (-1 = the far wall, as seen by the camera)
##   village: { segment: int, z: float, wall_x: float, path_end_x: float,
##              plaza: Rect2 (x, z), bat_shop_point, stable_point: Vector3, houses: [{ pos: Vector3, size: Vector3 }] }
##   start_point, stable_point, rival_point, exit_point: Vector3
##   total_length: float, rival_name: String, rival_species: int, floor_tint: Color,
##   biome: int (index into BiomeDB.BIOMES)
## }
## All positions are in the level's local space (start at z = 0, end at z = -total_length).
static func generate(level_seed: int, level_number: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	var biome := BiomeDB.for_level(level_number)
	var segments: Array[Dictionary] = []
	var rocks: Array[Dictionary] = []
	var spots: Array[Dictionary] = []
	var crates: Array[Dictionary] = []

	var z := 0.0
	segments.append({"z_start": z, "z_end": z - START_LENGTH, "center_x": 0.0, "width": START_WIDTH, "kind": "start"})
	z -= START_LENGTH

	var path_count := 5 + mini(level_number, 5)
	var center := 0.0
	for i in path_count:
		center = clampf(center + rng.randf_range(-10.0, 10.0), -MAX_SWAY, MAX_SWAY)
		var width := rng.randf_range(MIN_PATH_WIDTH, MAX_PATH_WIDTH)
		var seg := {"z_start": z, "z_end": z - SEGMENT_LENGTH, "center_x": center, "width": width, "kind": "path"}
		segments.append(seg)
		_add_rocks(rng, seg, rocks)
		# Keep the first stretch next to the camp clear so the camp is safe.
		_add_creature_spots(rng, seg, rocks, spots, float(i + 1) / path_count, 8.0 if i == 0 else 2.0)
		_add_crate_spots(rng, seg, rocks, spots, crates)
		z -= SEGMENT_LENGTH

	# The village branches off the middle path segment; the lemonade stand is
	# against the far wall of the segment before it, with a clear, safe area around it.
	var village_index := 1 + path_count / 2
	var village := _village(segments[village_index], village_index)
	var shop_seg: Dictionary = segments[village_index - 1]
	# Always on the far wall (local -x), so the stand faces the camera; the near
	# wall is drawn low and the stand would be seen from behind there.
	var shop_side := -1.0
	var shop_point := Vector3(shop_seg.center_x + shop_side * (shop_seg.width * 0.5 - 3.0), 0.0,
			(shop_seg.z_start + shop_seg.z_end) * 0.5)
	var away_from_shop := func(item: Dictionary) -> bool:
		return Vector2(item.pos.x - shop_point.x, item.pos.z - shop_point.z).length() > SHOP_CLEARANCE
	rocks.assign(rocks.filter(away_from_shop))
	spots.assign(spots.filter(away_from_shop))
	crates.assign(crates.filter(away_from_shop))
	# Keep the way into the village clear.
	var clear_of_village := func(item: Dictionary) -> bool:
		return item.pos.x > village.wall_x + 7.0 or absf(item.pos.z - village.z) > VILLAGE_PATH_WIDTH * 0.5 + 3.0
	rocks.assign(rocks.filter(clear_of_village))
	spots.assign(spots.filter(clear_of_village))
	crates.assign(crates.filter(clear_of_village))

	var arena_center := clampf(center, -12.0, 12.0)
	var arena := {"z_start": z, "z_end": z - ARENA_LENGTH, "center_x": arena_center, "width": ARENA_WIDTH, "kind": "arena"}
	segments.append(arena)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		rocks.append({
			"pos": Vector3(arena_center + corner.x * 14.0, 0.0, z - ARENA_LENGTH * 0.5 + corner.y * 12.0),
			"size": Vector3(3.0, 3.5, 3.0),
		})
	z -= ARENA_LENGTH

	return {
		"segments": segments,
		"rocks": rocks,
		"creature_spots": spots,
		"crate_spots": crates,
		"shop_point": shop_point,
		"shop_side": shop_side,
		"village": village,
		"start_point": Vector3(0.0, 0.0, -14.0),
		"stable_point": Vector3(-8.0, 0.0, -16.0),
		"rival_point": Vector3(arena_center, 0.0, arena.z_start - ARENA_LENGTH * 0.55),
		"exit_point": Vector3(arena_center, 0.0, z + 4.0),
		"total_length": -z,
		"rival_name": RIVAL_NAMES[rng.randi() % RIVAL_NAMES.size()],
		"rival_species": biome.species[rng.randi() % biome.species.size()],
		"floor_tint": Color.from_hsv(rng.randf_range(biome.floor_hue.x, biome.floor_hue.y),
				biome.floor_sat, biome.floor_val),
		"biome": BiomeDB.index_for_level(level_number),
	}


## The segment containing local z, or the nearest one.
static func segment_at(layout: Dictionary, local_z: float) -> Dictionary:
	for seg: Dictionary in layout.segments:
		if local_z <= seg.z_start and local_z >= seg.z_end:
			return seg
	return layout.segments[0] if local_z > 0.0 else layout.segments[-1]


## The village's side path and square, from its segment.
static func _village(seg: Dictionary, index: int) -> Dictionary:
	var z: float = (seg.z_start + seg.z_end) * 0.5
	var wall_x: float = seg.center_x - seg.width * 0.5
	var path_end_x := wall_x - VILLAGE_PATH_LENGTH
	var plaza := Rect2(path_end_x - PLAZA_SIZE.x, z - PLAZA_SIZE.y * 0.5, PLAZA_SIZE.x, PLAZA_SIZE.y)
	return {
		"segment": index,
		"z": z,
		"wall_x": wall_x,
		"path_end_x": path_end_x,
		"plaza": plaza,
		# Against the far side of the square, facing the way in.
		"bat_shop_point": Vector3(plaza.position.x + 4.0, 0.0, z),
		# In the front corner of the square, opposite the third house.
		"stable_point": Vector3(plaza.end.x - 5.0, 0.0, plaza.end.y - 4.5),
		"houses": [
			{"pos": Vector3(plaza.position.x + 5.0, 0.0, plaza.position.y + 5.0), "size": Vector3(6.0, 3.2, 5.0)},
			{"pos": Vector3(plaza.position.x + 5.0, 0.0, plaza.end.y - 5.0), "size": Vector3(6.0, 3.6, 5.0)},
			{"pos": Vector3(plaza.end.x - 6.0, 0.0, plaza.position.y + 4.5), "size": Vector3(5.0, 3.0, 5.0)},
		],
	}


## True if a local point is on the village's side path or square (with `margin` to the walls).
static func in_village(layout: Dictionary, local_point: Vector3, margin := 0.0) -> bool:
	if not layout.has("village"):
		return false
	var v: Dictionary = layout.village
	var point := Vector2(local_point.x, local_point.z)
	var path := Rect2(v.path_end_x, v.z - VILLAGE_PATH_WIDTH * 0.5, v.wall_x - v.path_end_x + 2.0, VILLAGE_PATH_WIDTH)
	return path.grow(-margin).has_point(point) or (v.plaza as Rect2).grow(-margin).has_point(point)


## Clamps a local point so it stays on the walkable floor.
static func clamp_to_floor(layout: Dictionary, local_point: Vector3, margin := 1.0) -> Vector3:
	if in_village(layout, local_point, margin):
		return local_point
	var p := local_point
	p.z = clampf(p.z, -layout.total_length + margin, -margin)
	var seg := segment_at(layout, p.z)
	var half: float = seg.width * 0.5 - margin
	p.x = clampf(p.x, seg.center_x - half, seg.center_x + half)
	return p


static func _add_rocks(rng: RandomNumberGenerator, seg: Dictionary, rocks: Array[Dictionary]) -> void:
	for i in rng.randi_range(3, 6):
		var half: float = seg.width * 0.5 - 2.5
		var size := Vector3(rng.randf_range(1.5, 3.5), rng.randf_range(1.5, 3.0), rng.randf_range(1.5, 3.5))
		rocks.append({
			"pos": Vector3(seg.center_x + rng.randf_range(-half, half), 0.0,
					rng.randf_range(seg.z_end + 3.0, seg.z_start - 3.0)),
			"size": size,
		})


## Crates sit near the walls of each path segment, clear of rocks and creatures.
static func _add_crate_spots(rng: RandomNumberGenerator, seg: Dictionary, rocks: Array[Dictionary],
		spots: Array[Dictionary], crates: Array[Dictionary]) -> void:
	var want := rng.randi_range(2, 4)
	for attempt in 16:
		if want <= 0:
			return
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var pos := Vector3(seg.center_x + side * (seg.width * 0.5 - rng.randf_range(1.5, 4.0)), 0.0,
				rng.randf_range(seg.z_end + 2.0, seg.z_start - 2.0))
		var blocked := false
		for rock: Dictionary in rocks:
			if Vector2(rock.pos.x - pos.x, rock.pos.z - pos.z).length() < 3.0:
				blocked = true
		for spot: Dictionary in spots + crates:
			if Vector2(spot.pos.x - pos.x, spot.pos.z - pos.z).length() < 2.5:
				blocked = true
		if not blocked:
			crates.append({"pos": pos, "gold": rng.randf() < 0.12})
			want -= 1


static func _add_creature_spots(rng: RandomNumberGenerator, seg: Dictionary, rocks: Array[Dictionary],
		spots: Array[Dictionary], depth: float, entry_clearance: float) -> void:
	var placed := 0
	var want := rng.randi_range(4, 6)
	for attempt in 24:
		if placed >= want:
			return
		var half: float = seg.width * 0.5 - 2.0
		var pos := Vector3(seg.center_x + rng.randf_range(-half, half), 0.0,
				rng.randf_range(seg.z_end + 2.0, seg.z_start - entry_clearance))
		var blocked := false
		for rock: Dictionary in rocks:
			if Vector2(rock.pos.x - pos.x, rock.pos.z - pos.z).length() < 2.5:
				blocked = true
		if not blocked:
			spots.append({"pos": pos, "depth": depth})
			placed += 1
