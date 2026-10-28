class_name LevelGenerator
## Builds the layout of one level from a seed: a single path that always
## heads the same way (local -Z), winding left and right, from a start camp
## (with the stable) to a rival's arena at the end.
##
## Pure data and fully deterministic: every peer generates the same layout from
## the same seed, so only the seed has to be sent over the network.

const SEGMENT_LENGTH := 16.0
const START_LENGTH := 18.0
const START_WIDTH := 22.0
const ARENA_LENGTH := 26.0
const ARENA_WIDTH := 28.0
const MAX_SWAY := 10.0  ## How far the path may drift sideways from its start line.

const RIVAL_NAMES := ["Kael", "Mira", "Dax", "Vesper", "Rook", "Sable", "Juno", "Thorne", "Lyra", "Brann"]


## Returns:
## {
##   segments: [{ z_start, z_end, center_x, width, kind }]   kind = "start" | "path" | "arena"
##   rocks: [{ pos: Vector3, size: Vector3 }]
##   creature_spots: [{ pos: Vector3, depth: float }]   depth = 0..1 along the path
##   start_point, stable_point, rival_point, exit_point: Vector3
##   total_length: float, rival_name: String, rival_species: int, floor_tint: Color
## }
## All positions are in the level's local space (start at z = 0, end at z = -total_length).
static func generate(level_seed: int, level_number: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	var segments: Array[Dictionary] = []
	var rocks: Array[Dictionary] = []
	var spots: Array[Dictionary] = []

	var z := 0.0
	segments.append({"z_start": z, "z_end": z - START_LENGTH, "center_x": 0.0, "width": START_WIDTH, "kind": "start"})
	z -= START_LENGTH

	var path_count := 5 + mini(level_number, 5)
	var center := 0.0
	for i in path_count:
		center = clampf(center + rng.randf_range(-5.0, 5.0), -MAX_SWAY, MAX_SWAY)
		var width := rng.randf_range(12.0, 20.0)
		var seg := {"z_start": z, "z_end": z - SEGMENT_LENGTH, "center_x": center, "width": width, "kind": "path"}
		segments.append(seg)
		_add_rocks(rng, seg, rocks)
		# Keep the first stretch next to the camp clear so the camp is safe.
		_add_creature_spots(rng, seg, rocks, spots, float(i + 1) / path_count, 8.0 if i == 0 else 2.0)
		z -= SEGMENT_LENGTH

	var arena_center := clampf(center, -6.0, 6.0)
	var arena := {"z_start": z, "z_end": z - ARENA_LENGTH, "center_x": arena_center, "width": ARENA_WIDTH, "kind": "arena"}
	segments.append(arena)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		rocks.append({
			"pos": Vector3(arena_center + corner.x * 7.0, 0.0, z - ARENA_LENGTH * 0.5 + corner.y * 6.0),
			"size": Vector3(2.0, 2.5, 2.0),
		})
	z -= ARENA_LENGTH

	return {
		"segments": segments,
		"rocks": rocks,
		"creature_spots": spots,
		"start_point": Vector3(0.0, 0.0, -7.0),
		"stable_point": Vector3(-7.0, 0.0, -9.0),
		"rival_point": Vector3(arena_center, 0.0, arena.z_start - ARENA_LENGTH * 0.55),
		"exit_point": Vector3(arena_center, 0.0, z + 4.0),
		"total_length": -z,
		"rival_name": RIVAL_NAMES[rng.randi() % RIVAL_NAMES.size()],
		"rival_species": rng.randi() % SpeciesDB.PATHS.size(),
		"floor_tint": Color.from_hsv(rng.randf_range(0.22, 0.36), 0.25, 0.38),
	}


## The segment containing local z, or the nearest one.
static func segment_at(layout: Dictionary, local_z: float) -> Dictionary:
	for seg: Dictionary in layout.segments:
		if local_z <= seg.z_start and local_z >= seg.z_end:
			return seg
	return layout.segments[0] if local_z > 0.0 else layout.segments[-1]


## Clamps a local point so it stays on the walkable floor.
static func clamp_to_floor(layout: Dictionary, local_point: Vector3, margin := 1.0) -> Vector3:
	var p := local_point
	p.z = clampf(p.z, -layout.total_length + margin, -margin)
	var seg := segment_at(layout, p.z)
	var half: float = seg.width * 0.5 - margin
	p.x = clampf(p.x, seg.center_x - half, seg.center_x + half)
	return p


static func _add_rocks(rng: RandomNumberGenerator, seg: Dictionary, rocks: Array[Dictionary]) -> void:
	for i in rng.randi_range(1, 3):
		var half: float = seg.width * 0.5 - 2.5
		var size := Vector3(rng.randf_range(1.5, 3.0), rng.randf_range(1.5, 3.0), rng.randf_range(1.5, 3.0))
		rocks.append({
			"pos": Vector3(seg.center_x + rng.randf_range(-half, half), 0.0,
					rng.randf_range(seg.z_end + 3.0, seg.z_start - 3.0)),
			"size": size,
		})


static func _add_creature_spots(rng: RandomNumberGenerator, seg: Dictionary, rocks: Array[Dictionary],
		spots: Array[Dictionary], depth: float, entry_clearance: float) -> void:
	var placed := 0
	var want := rng.randi_range(2, 3)
	for attempt in 12:
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
