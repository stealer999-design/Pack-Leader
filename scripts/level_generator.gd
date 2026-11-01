class_name LevelGenerator
## Builds the layout of one level from a seed: a single winding path from a
## start camp (with the stable) to the boss arena at the end, bending through
## one to three smooth curves, with the village branching off around halfway.
##
## The level is first laid out "unrolled" in path space: x across the path,
## z = -s where s is the distance along it. The path is then bent along a
## curved centre line (straight at the camp, through the village stretch and
## at the arena, with the curves in between), and every position is mapped
## into the level's local space. The village sits on a straight stretch, so
## it is mapped rigidly (its `frame`).
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
## The curves: each bends the path by MIN_TURN..MAX_TURN degrees along an arc
## of radius MIN_RADIUS..MAX_RADIUS; the path never turns more than MAX_HEADING
## degrees from its starting direction, so it keeps heading across the screen.
const MIN_CURVES := 1
const MAX_CURVES := 3
const MIN_TURN := 35.0
const MAX_TURN := 70.0
const MIN_RADIUS := 34.0
const MAX_RADIUS := 48.0
const MAX_HEADING := 75.0
const STRAIGHT_AROUND_VILLAGE := 24.0  ## The path is straight this far either side of the village.
const SAMPLE_STEP := 1.0  ## Spacing of the centre-line samples.
## The village: a side path off the far wall of the middle segment, at a right
## angle (up the screen), leading to a square with the bat shop.
const VILLAGE_PATH_WIDTH := 12.0
const VILLAGE_PATH_LENGTH := 18.0
const PLAZA_SIZE := Vector2(30.0, 28.0)  ## x (away from the path) by z (along it).

const RIVAL_NAMES := ["Kael", "Mira", "Dax", "Vesper", "Rook", "Sable", "Juno", "Thorne", "Lyra", "Brann"]


## Returns:
## {
##   segments: [{ z_start, z_end, center_x, width, kind }]   in path space (z = -s); kind = "start" | "path" | "arena"
##   centerline: PackedVector3Array (level-local, one point every SAMPLE_STEP of s)
##   headings: PackedFloat32Array (the path's yaw at each sample; 0 = local -Z)
##   widths: [Vector2(s, width)] knots, smoothly interpolated (see half_width)
##   shop_yaw: float, travel_point: Vector3
##   rocks: [{ pos: Vector3, size: Vector3 }]
##   creature_spots: [{ pos: Vector3, depth: float }]   depth = 0..1 along the path
##   crate_spots: [{ pos: Vector3, gold: bool }]
##   shop_point: Vector3, shop_side: float (-1 = the far wall, as seen by the camera)
##   village: { segment: int, s: float, frame: Transform3D (path space -> level-local, rigid),
##              (in path space:) z: float, wall_x: float, path_end_x: float,
##              plaza: Rect2 (x, z), bat_shop_point, stable_point, breeder_point: Vector3, houses: [{ pos: Vector3, size: Vector3 }] }
##   start_point, stable_point, rival_point, exit_point: Vector3
##   hub_portals: [Vector3]   the Crossroads only (level 0): one portal per Act 1 biome (BiomeDB.ACTS[0] order)
##   total_length: float, rival_name: String, rival_species: int, floor_tint: Color,
##   biome: int (index into BiomeDB.BIOMES)
## }
## Positions are in the level's local space unless noted (the village's are in
## path space: map them with village.frame).
static func generate(level_seed: int, level_number: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	var biome := BiomeDB.for_level(level_number)
	# The Crossroads (level 0): a short, straight, peaceful walk past the
	# lemonade stand and the village to a plaza with a portal to each Act 1 area.
	var hub := level_number <= BiomeDB.CROSSROADS
	var segments: Array[Dictionary] = []
	var rocks: Array[Dictionary] = []
	var spots: Array[Dictionary] = []
	var crates: Array[Dictionary] = []

	var z := 0.0
	segments.append({"z_start": z, "z_end": z - START_LENGTH, "center_x": 0.0, "width": START_WIDTH, "kind": "start"})
	z -= START_LENGTH

	var path_count := 2 if hub else 5 + mini(level_number, 5)
	var center := 0.0
	for i in path_count:
		var width := rng.randf_range(MIN_PATH_WIDTH, MAX_PATH_WIDTH)
		var seg := {"z_start": z, "z_end": z - SEGMENT_LENGTH, "center_x": center, "width": width, "kind": "path"}
		segments.append(seg)
		if hub:
			z -= SEGMENT_LENGTH
			continue
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

	var arena_center := 0.0
	var arena := {"z_start": z, "z_end": z - ARENA_LENGTH, "center_x": arena_center, "width": ARENA_WIDTH, "kind": "arena"}
	segments.append(arena)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		if hub:
			break
		rocks.append({
			"pos": Vector3(arena_center + corner.x * 14.0, 0.0, z - ARENA_LENGTH * 0.5 + corner.y * 12.0),
			"size": Vector3(3.0, 3.5, 3.0),
		})
	z -= ARENA_LENGTH

	# Bend the unrolled path: build the centre line, then map everything onto it.
	var total := -z
	var widths: Array[Vector2] = [Vector2(0.0, START_WIDTH), Vector2(START_LENGTH - 4.0, START_WIDTH)]
	for seg: Dictionary in segments:
		if seg.kind == "path":
			widths.append(Vector2(-(seg.z_start + seg.z_end) * 0.5, seg.width))
	widths.append(Vector2(total - ARENA_LENGTH + 4.0, ARENA_WIDTH))
	widths.append(Vector2(total, ARENA_WIDTH))
	var village_s: float = -village.z
	var line := {}
	for attempt in 16:
		line = _centerline(rng, total, village_s, attempt >= 12)
		var trial := {"centerline": line.points, "headings": line.headings, "widths": widths, "total_length": total}
		village["frame"] = _rigid_frame(trial, village_s)
		if not _hits_village(trial, village, village_s):
			break
	var bent := {"centerline": line.points, "headings": line.headings, "widths": widths, "total_length": total}
	village["s"] = village_s
	# Everything unrolled stays inside the path's (now smoothly varying) width.
	for list in [rocks, spots, crates]:
		for item: Dictionary in list:
			var item_s: float = -item.pos.z
			var half := half_width(bent, item_s) - 2.0
			item.pos = map_point(bent, Vector3(clampf(item.pos.x, -half, half), 0.0, item.pos.z))
	var shop_s: float = -shop_point.z
	# The Crossroads portals: a row along the plaza (left to right on screen),
	# one per Act 1 biome, before the Travel portal at the far end.
	var hub_portals: Array[Vector3] = []
	if hub:
		var count: int = BiomeDB.ACTS[0].size()
		for i in count:
			var along := 9.0 + i * 9.5
			hub_portals.append(map_point(bent, Vector3(arena_center + 3.0, 0.0, arena.z_start - along)))

	return {
		"segments": segments,
		"centerline": line.points,
		"headings": line.headings,
		"widths": widths,
		"shop_yaw": heading_at(bent, shop_s),
		"rocks": rocks,
		"creature_spots": spots,
		"crate_spots": crates,
		"shop_point": map_point(bent, shop_point),
		"shop_side": shop_side,
		"village": village,
		"start_point": map_point(bent, Vector3(0.0, 0.0, -14.0)),
		"stable_point": map_point(bent, Vector3(-8.0, 0.0, -16.0)),
		"rival_point": map_point(bent, Vector3(arena_center, 0.0, arena.z_start - ARENA_LENGTH * 0.55)),
		"exit_point": map_point(bent, Vector3(arena_center, 0.0, z + 4.0)),
		"travel_point": map_point(bent, Vector3(arena_center - 4.5, 0.0, z + 4.0)),
		"hub_portals": hub_portals,
		"total_length": total,
		"rival_name": RIVAL_NAMES[rng.randi() % RIVAL_NAMES.size()],
		"rival_species": biome.species[rng.randi() % biome.species.size()],
		"floor_tint": Color.from_hsv(rng.randf_range(biome.floor_hue.x, biome.floor_hue.y),
				biome.floor_sat, biome.floor_val),
		"biome": BiomeDB.index_for_level(level_number),
	}


## The centre line: straight through the camp, the village stretch and the
## arena, bending through 1-3 arcs elsewhere (curving alternately left and
## right, never turning more than MAX_HEADING from the start). Returns
## {points: PackedVector3Array, headings: PackedFloat32Array}, a sample every
## SAMPLE_STEP. `gentle`: a last-resort, flatter path (if the village collides).
static func _centerline(rng: RandomNumberGenerator, total: float, village_s: float, gentle: bool) -> Dictionary:
	# Where curves may go: before the village, and after it (before the arena).
	var ranges := [
		Vector2(START_LENGTH + 6.0, village_s - STRAIGHT_AROUND_VILLAGE),
		Vector2(village_s + STRAIGHT_AROUND_VILLAGE, total - ARENA_LENGTH - 6.0),
	]
	var count := rng.randi_range(MIN_CURVES, MAX_CURVES)
	# Share the curves out between the two stretches (the longer one gets more).
	var per_range := [0, 0]
	for i in count:
		var room := [ranges[0].y - ranges[0].x - per_range[0] * 45.0, ranges[1].y - ranges[1].x - per_range[1] * 45.0]
		per_range[0 if room[0] >= room[1] else 1] += 1
	var arcs: Array[Dictionary] = []
	var heading := 0.0
	var turn_sign := 1.0 if rng.randf() < 0.5 else -1.0
	for r in 2:
		var span: Vector2 = ranges[r]
		var n: int = per_range[r]
		if n == 0 or span.y - span.x < 20.0:
			continue
		var slot := (span.y - span.x) / n
		for k in n:
			var radius := rng.randf_range(MIN_RADIUS, MAX_RADIUS)
			var turn := deg_to_rad(rng.randf_range(MIN_TURN, MAX_TURN) * (0.6 if gentle else 1.0))
			var length := minf(radius * turn, slot - 4.0)
			if length < 12.0:
				continue
			turn = length / radius
			var dir := turn_sign
			if absf(heading + dir * turn) > deg_to_rad(MAX_HEADING):
				dir = -dir
			heading += dir * turn
			turn_sign = -dir  # the next curve bends the other way: an S
			var start := span.x + slot * k + rng.randf_range(0.0, maxf(slot - length - 2.0, 0.0))
			arcs.append({"from": start, "to": start + length, "rate": dir * turn / length})
	var points := PackedVector3Array()
	var headings := PackedFloat32Array()
	var at := Vector3.ZERO
	var yaw := 0.0
	var steps := ceili(total / SAMPLE_STEP)
	for i in steps + 1:
		var s := i * SAMPLE_STEP
		points.append(at)
		headings.append(yaw)
		# Advance one step: the heading turns while inside an arc.
		var mid := s + SAMPLE_STEP * 0.5
		for arc in arcs:
			if mid >= arc.from and mid < arc.to:
				yaw += arc.rate * SAMPLE_STEP
		at += _forward(yaw) * SAMPLE_STEP
	return {"points": points, "headings": headings}


## The path's forward direction for a heading (0 = local -Z; positive turns left).
static func _forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## A point on the centre line, `s` along the path.
static func point_at(layout: Dictionary, s: float) -> Vector3:
	var points: PackedVector3Array = layout.centerline
	var f := clampf(s / SAMPLE_STEP, 0.0, points.size() - 1.0)
	var i := mini(floori(f), points.size() - 2)
	return points[i].lerp(points[i + 1], f - i)


## The path's heading (yaw) `s` along it.
static func heading_at(layout: Dictionary, s: float) -> float:
	var headings: PackedFloat32Array = layout.headings
	var f := clampf(s / SAMPLE_STEP, 0.0, headings.size() - 1.0)
	var i := mini(floori(f), headings.size() - 2)
	return lerpf(headings[i], headings[i + 1], f - i)


## Half the path's width `s` along it (the width eases smoothly between knots).
static func half_width(layout: Dictionary, s: float) -> float:
	var knots: Array = layout.widths
	if s <= knots[0].x:
		return knots[0].y * 0.5
	for i in knots.size() - 1:
		var a: Vector2 = knots[i]
		var b: Vector2 = knots[i + 1]
		if s <= b.x:
			return lerpf(a.y, b.y, smoothstep(a.x, b.x, s)) * 0.5
	return knots[-1].y * 0.5


## A path-space point (x across, z = -s) mapped onto the bent path.
static func map_point(layout: Dictionary, p: Vector3) -> Vector3:
	var s := -p.z
	var forward := _forward(heading_at(layout, s))
	var across := forward.cross(Vector3.UP)  # path space +x
	var total: float = layout.total_length
	# Beyond either end, carry straight on.
	var beyond := 0.0
	if s < 0.0:
		beyond = s
	elif s > total:
		beyond = s - total
	return point_at(layout, s) + forward * beyond + across * p.x + Vector3.UP * p.y


## The level-local point back to path space: Vector2(s, x) of the nearest
## point of the centre line.
static func project(layout: Dictionary, local_point: Vector3) -> Vector2:
	var points: PackedVector3Array = layout.centerline
	var best := 0
	var best_d := INF
	var p := Vector2(local_point.x, local_point.z)
	for i in range(0, points.size(), 4):  # coarse, then refine around the best
		var d := p.distance_squared_to(Vector2(points[i].x, points[i].z))
		if d < best_d:
			best_d = d
			best = i
	for i in range(maxi(best - 4, 0), mini(best + 5, points.size())):
		var d := p.distance_squared_to(Vector2(points[i].x, points[i].z))
		if d < best_d:
			best_d = d
			best = i
	var s := best * SAMPLE_STEP
	var x := 0.0
	for pass_i in 3:  # slide along to where the point is square across the path
		var forward := _forward(heading_at(layout, s))
		var offset := local_point - point_at(layout, s)
		offset.y = 0.0
		s += offset.dot(forward)
		x = offset.dot(forward.cross(Vector3.UP))
	return Vector2(s, x)


## The rigid transform from path space to level-local for a straight stretch
## around `s` (where the village is).
static func _rigid_frame(layout: Dictionary, s: float) -> Transform3D:
	var forward := _forward(heading_at(layout, s))
	var across := forward.cross(Vector3.UP)
	var basis := Basis(across, Vector3.UP, -forward)
	return Transform3D(basis, point_at(layout, s) - forward * s)


## True if the path (away from the village) runs into the village's side path or square.
static func _hits_village(layout: Dictionary, village: Dictionary, village_s: float) -> bool:
	var to_village: Transform3D = village.frame.affine_inverse()
	var plaza: Rect2 = village.plaza
	var side := Rect2(village.path_end_x, village.z - VILLAGE_PATH_WIDTH * 0.5, village.wall_x - village.path_end_x, VILLAGE_PATH_WIDTH)
	var points: PackedVector3Array = layout.centerline
	for i in range(0, points.size(), 2):
		var s := i * SAMPLE_STEP
		if absf(s - village_s) < STRAIGHT_AROUND_VILLAGE + 10.0:
			continue
		var q := to_village * points[i]
		var margin := half_width(layout, s) + 4.0
		if plaza.grow(margin).has_point(Vector2(q.x, q.z)) or side.grow(margin).has_point(Vector2(q.x, q.z)):
			return true
	return false


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
		# Against the screen-right side of the square, facing into it, with its hay pen.
		"breeder_point": Vector3(plaza.get_center().x + 1.0, 0.0, plaza.position.y + 3.0),
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
	var q: Vector3 = v.frame.affine_inverse() * local_point
	var point := Vector2(q.x, q.z)
	var path := Rect2(v.path_end_x, v.z - VILLAGE_PATH_WIDTH * 0.5, v.wall_x - v.path_end_x + 2.0, VILLAGE_PATH_WIDTH)
	return path.grow(-margin).has_point(point) or (v.plaza as Rect2).grow(-margin).has_point(point)


## Clamps a local point so it stays on the walkable floor.
static func clamp_to_floor(layout: Dictionary, local_point: Vector3, margin := 1.0) -> Vector3:
	if in_village(layout, local_point, margin):
		return local_point
	var sx := project(layout, local_point)
	var s := clampf(sx.x, margin, layout.total_length - margin)
	var half := half_width(layout, s) - margin
	var out := map_point(layout, Vector3(clampf(sx.y, -half, half), 0.0, -s))
	out.y = local_point.y
	return out


## How far along the path a local point is (0 at the camp's back wall, 1 at the arena's end).
static func progress(layout: Dictionary, local_point: Vector3) -> float:
	return clampf(project(layout, local_point).x / layout.total_length, 0.0, 1.0)


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
