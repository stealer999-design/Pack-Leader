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
	var path := _generate_path(level_seed, level_number)
	if BiomeDB.is_open_level(level_number):
		return generate_open(level_seed, path)
	return path


static func _generate_path(level_seed: int, level_number: int) -> Dictionary:
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
		# The Crossroads: the way on to Act 2 (open once Act 1 is cleared), beside the Travel portal.
		"onward_point": map_point(bent, Vector3(arena_center + 4.5, 0.0, z + 4.0)),
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
		# The stash chest: in the middle of the square, clear of the stalls.
		"stash_point": Vector3(plaza.get_center().x, 0.0, plaza.get_center().y + 5.0),
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
	if layout.get("open", false):
		return (v.plaza as Rect2).grow(-margin).has_point(point)
	var path := Rect2(v.path_end_x, v.z - VILLAGE_PATH_WIDTH * 0.5, v.wall_x - v.path_end_x + 2.0, VILLAGE_PATH_WIDTH)
	return path.grow(-margin).has_point(point) or (v.plaza as Rect2).grow(-margin).has_point(point)


## Clamps a local point so it stays on the walkable floor.
static func clamp_to_floor(layout: Dictionary, local_point: Vector3, margin := 1.0) -> Vector3:
	if layout.get("open", false):
		return _clamp_open(layout, local_point, margin)
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
	if layout.get("open", false):  # from the camp (left) to the arena (right)
		return clampf((layout.left_z - local_point.z) / layout.total_length, 0.0, 1.0)
	return clampf(project(layout, local_point).x / layout.total_length, 0.0, 1.0)


# --- Open levels (Act 2) ---------------------------------------------------------------
#
# A big field instead of a path: a rounded box with gently wavy edges, OPEN_SIZE
# across, with the start camp at its left end (z near 0) and the boss arena at
# its right end (z near -length). Local x runs across the screen (+x towards the
# camera), as on paths. The town sits off-centre in the middle, fenced in, with
# the lemonade stand inside it. The level has exactly as many creature packs,
# vases and obstacles as the path level from the same seed would, spread out.

const OPEN_SIZE := Vector2(224.0, 328.0)  ## x (across the screen) by z (left to right).
const OPEN_POINTS := 192  ## Points around the boundary.
const OPEN_PLAZA := Vector2(36.0, 34.0)  ## The town square: x by z.
const CAMP_RADIUS := 16.0
const ARENA_RADIUS := 21.0
## The boss arena: a walled box (x by z) outside the field's right edge,
## joined to it by a corridor CORRIDOR_WIDTH wide.
const ARENA_BOX := Vector2(56.0, 52.0)
const CORRIDOR_WIDTH := 10.0
## The town's gates: the middle of its camera-facing (south) side and of its left (west) side.
const GATE_WIDTH := 6.0


## The open-field layout, with the same keys as a path layout (where they make
## sense) plus: open: true, boundary: PackedVector3Array (level-local, closed),
## center: Vector3, camp_center / arena_center: Vector3, gates: [Rect2] (in the
## town's frame). `path` is the path layout from the same seed: its counts,
## rival and colours are reused.
static func generate_open(level_seed: int, path: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed ^ 0x5eed
	var length := OPEN_SIZE.y
	var center := Vector3(0.0, 0.0, -length * 0.5)
	var boundary := _open_boundary(rng, center)
	var flat := PackedVector2Array()
	for point in boundary:
		flat.append(Vector2(point.x, point.z))
	# Where the wavy edge really is at the left end (the camp).
	var left_z := boundary[OPEN_POINTS / 4].z
	# The boss arena: a box outside the right-hand edge, anywhere up or down it,
	# joined to the field by a corridor through a gap in the wall.
	var arena_x := rng.randf_range(-OPEN_SIZE.x * 0.3, OPEN_SIZE.x * 0.3)
	var mouth_z := _right_edge_z(boundary, center, arena_x)
	var clear_z := INF  # the box must sit beyond the edge all across its width
	for k in 13:
		var x := arena_x - ARENA_BOX.x * 0.5 - 2.0 + (ARENA_BOX.x + 4.0) * k / 12.0
		clear_z = minf(clear_z, _right_edge_z(boundary, center, x))
	var box_near_z := minf(clear_z - 4.0, mouth_z - 10.0)  # the arena's left (corridor) side
	var arena_rect := Rect2(arena_x - ARENA_BOX.x * 0.5, box_near_z - ARENA_BOX.y, ARENA_BOX.x, ARENA_BOX.y)
	var corridor_rect := Rect2(arena_x - CORRIDOR_WIDTH * 0.5, box_near_z, CORRIDOR_WIDTH, mouth_z + 8.0 - box_near_z)
	var right_z := arena_rect.position.y
	length = left_z - right_z
	var layout := {"open": true, "boundary": boundary, "boundary_2d": flat, "center": center, "total_length": length,
			"left_z": left_z, "arena_rect": arena_rect, "corridor_rect": corridor_rect,
			"mouth": Vector3(arena_x, 0.0, mouth_z)}
	var camp_center := Vector3(0.0, 0.0, left_z - CAMP_RADIUS - 2.0)
	var arena_center := Vector3(arena_x, 0.0, arena_rect.get_center().y)
	var mouth := Vector3(arena_x, 0.0, mouth_z)

	# The town: somewhere in the middle, but not dead centre and not near the edges.
	var plaza := Rect2(-OPEN_PLAZA.x * 0.5, -OPEN_PLAZA.y * 0.5, OPEN_PLAZA.x, OPEN_PLAZA.y)
	var town := Vector3.ZERO
	for attempt in 40:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		town = center + Vector3(side * rng.randf_range(22.0, 48.0), 0.0, rng.randf_range(-55.0, 55.0))
		if Vector2(town.x - center.x, town.z - center.z).length() < 24.0:
			continue
		var fits := true
		for corner in [Vector2(plaza.position.x, plaza.position.y), Vector2(plaza.end.x, plaza.position.y),
				Vector2(plaza.position.x, plaza.end.y), Vector2(plaza.end.x, plaza.end.y)]:
			if _edge_distance(layout, town + Vector3(corner.x, 0.0, corner.y)) < 30.0:
				fits = false
		# ...and well clear of the camp and the boss arena.
		for zone in [[camp_center, CAMP_RADIUS + 10.0], [mouth, 24.0]]:
			var local: Vector3 = zone[0] - town
			var nearest := Vector2(clampf(local.x, plaza.position.x, plaza.end.x), clampf(local.z, plaza.position.y, plaza.end.y))
			if nearest.distance_to(Vector2(local.x, local.z)) < zone[1]:
				fits = false
		if fits:
			break
	var village := _village_open(plaza)
	village["frame"] = Transform3D(Basis(), town)
	var shop_local := Vector3(plaza.get_center().x + 5.0, 0.0, plaza.get_center().y + 6.0)

	# Everything else is spread over the field, clear of the camp, the arena,
	# the town (and its fence) and each other.
	var keep_out := func(p: Vector3, edge: float) -> bool:
		if _edge_distance(layout, p) < edge:
			return true
		if Vector2(p.x - camp_center.x, p.z - camp_center.z).length() < CAMP_RADIUS + 6.0:
			return true
		if Vector2(p.x - mouth.x, p.z - mouth.z).length() < 14.0:  # keep the way to the boss clear
			return true
		var q := p - town
		return plaza.grow(7.0).has_point(Vector2(q.x, q.z))
	var taken: Array[Vector3] = []
	var far_enough := func(p: Vector3, spacing: float) -> bool:
		for other in taken:
			if Vector2(other.x - p.x, other.z - p.z).length() < spacing:
				return false
		return true
	var sample := func(edge: float, spacing: float) -> Vector3:
		for attempt in 200:
			var p := center + Vector3(rng.randf_range(-OPEN_SIZE.x * 0.5, OPEN_SIZE.x * 0.5), 0.0,
					rng.randf_range(-length * 0.5, length * 0.5))
			if not keep_out.call(p, edge) and far_enough.call(p, spacing):
				return p
		return Vector3.INF

	# Obstacles: as many as the path level had (its arena's four corner rocks
	# stay round the arena here too).
	var rocks: Array[Dictionary] = []
	var path_rocks: Array = path.rocks
	var arena_rocks := 4
	for i in maxi(path_rocks.size() - arena_rocks, 0):
		var p: Vector3 = sample.call(5.0, 11.0)
		if p != Vector3.INF:
			taken.append(p)
			rocks.append({"pos": p, "size": path_rocks[i].size})
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		rocks.append({"pos": arena_center + Vector3(corner.x * 14.0, 0.0, corner.y * 12.0), "size": Vector3(3.0, 3.5, 3.0)})

	# Creature packs: as many creatures as the path level had, in packs of
	# PACK_MIN-PACK_MAX, each pack around its own point (and all one kind: see
	# World._start_level, which picks a species per "group"). Deeper packs,
	# further right, are tougher.
	var sizes := pack_sizes(rng, path.creature_spots.size())
	var spots: Array[Dictionary] = []
	for group in sizes.size():
		var size: int = sizes[group]
		var home: Vector3 = sample.call(8.0, 30.0)
		if home == Vector3.INF:
			home = sample.call(6.0, 6.0)
		if home == Vector3.INF:
			continue
		taken.append(home)
		var depth := progress(layout, home)
		for k in size:
			var angle: float = TAU * k / size + rng.randf_range(-0.3, 0.3)
			var pos := home + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(1.5, 4.5)
			spots.append({"pos": pos, "depth": depth, "group": group})

	# Vases: the same number (and as many gold ones), spread out.
	var crates: Array[Dictionary] = []
	for crate: Dictionary in path.crate_spots:
		var p: Vector3 = sample.call(3.0, 10.0)
		if p == Vector3.INF:
			continue
		taken.append(p)
		crates.append({"pos": p, "gold": crate.gold})

	layout.merge({
		"rocks": rocks,
		"creature_spots": spots,
		"crate_spots": crates,
		"village": village,
		"shop_point": village.frame * shop_local,
		"shop_side": -1.0,
		"shop_yaw": 0.0,  # faces the camera
		"camp_center": camp_center,
		"arena_center": arena_center,
		"start_point": Vector3(0.0, 0.0, left_z - 14.0),
		"stable_point": Vector3(-8.0, 0.0, left_z - 16.0),
		"rival_point": arena_center,
		"exit_point": Vector3(arena_x, 0.0, right_z + 7.0),
		"travel_point": Vector3(arena_x - 4.5, 0.0, right_z + 7.0),
		"hub_portals": [],
		"rival_name": path.rival_name,
		"rival_species": path.rival_species,
		"floor_tint": path.floor_tint,
		"biome": path.biome,
	})
	return layout


const PACK_MIN := 3
const PACK_MAX := 5


## Splits `total` creatures into packs of PACK_MIN-PACK_MAX (a smaller total
## makes one smaller pack).
static func pack_sizes(rng: RandomNumberGenerator, total: int) -> Array[int]:
	var sizes: Array[int] = []
	var left := total
	while left > 0:
		var size := rng.randi_range(PACK_MIN, PACK_MAX)
		if left <= PACK_MAX:
			size = left
		elif left - size < PACK_MIN:
			size = left - PACK_MIN  # leave a full pack for last
		sizes.append(size)
		left -= size
	return sizes


## The field's edge: a rounded box (a superellipse) with slow waves along it,
## OPEN_POINTS points around `center`, counter-clockwise seen from above.
static func _open_boundary(rng: RandomNumberGenerator, center: Vector3) -> PackedVector3Array:
	var a := OPEN_SIZE.x * 0.5
	var b := OPEN_SIZE.y * 0.5
	var phases := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var amounts := [rng.randf_range(0.03, 0.06), rng.randf_range(0.02, 0.04), rng.randf_range(0.01, 0.025)]
	var points := PackedVector3Array()
	for i in OPEN_POINTS:
		var t := TAU * i / OPEN_POINTS
		var c := cos(t)
		var s := sin(t)
		var r := 1.0 / pow(pow(absf(c) / a, 4.0) + pow(absf(s) / b, 4.0), 0.25)
		r *= 1.0 + amounts[0] * sin(2.0 * t + phases[0]) + amounts[1] * sin(3.0 * t + phases[1]) \
				+ amounts[2] * sin(5.0 * t + phases[2])
		points.append(center + Vector3(c * r, 0.0, s * r))
	return points


## The town square and what's in it, in the town's own frame (+x towards the camera).
static func _village_open(plaza: Rect2) -> Dictionary:
	var v := _village({"z_start": 0.0, "z_end": 0.0, "center_x": 0.0, "width": 0.0}, 0)
	v.plaza = plaza
	v.z = plaza.get_center().y
	v.wall_x = plaza.end.x
	v.path_end_x = plaza.end.x
	v.bat_shop_point = Vector3(plaza.position.x + 4.0, 0.0, plaza.get_center().y)
	v.stable_point = Vector3(plaza.end.x - 5.0, 0.0, plaza.end.y - 4.5)
	v.breeder_point = Vector3(plaza.get_center().x + 1.0, 0.0, plaza.position.y + 3.0)
	v.stash_point = Vector3(plaza.get_center().x - 5.0, 0.0, plaza.get_center().y + 6.0)  # clear of the lemonade stand
	v.houses = [
		{"pos": Vector3(plaza.position.x + 5.0, 0.0, plaza.position.y + 5.0), "size": Vector3(6.0, 3.2, 5.0)},
		{"pos": Vector3(plaza.position.x + 5.0, 0.0, plaza.end.y - 5.0), "size": Vector3(6.0, 3.6, 5.0)},
		{"pos": Vector3(plaza.end.x - 6.0, 0.0, plaza.position.y + 4.5), "size": Vector3(5.0, 3.0, 5.0)},
	]
	# Gates in the fence: south (towards the camera) and west (towards the camp).
	v.gates = {"south": plaza.get_center().y, "west": plaza.get_center().x}
	v.s = 0.0
	return v


## Where the field's right-hand edge is (its z) at local `x`.
static func _right_edge_z(boundary: PackedVector3Array, center: Vector3, x: float) -> float:
	var best := INF
	var n := boundary.size()
	for i in n:
		var a := boundary[i]
		var b := boundary[(i + 1) % n]
		if a.z > center.z or b.z > center.z:
			continue  # only the right-hand half
		if (a.x - x) * (b.x - x) <= 0.0 and absf(b.x - a.x) > 0.0001:
			var z := lerpf(a.z, b.z, (x - a.x) / (b.x - a.x))
			best = minf(best, z)
	return best if best < INF else center.z - OPEN_SIZE.y * 0.5


## How far inside the walkable ground a local point is (negative = outside):
## the field, the corridor to the boss and the boss arena.
static func walkable_distance(layout: Dictionary, p: Vector3) -> float:
	var best := _edge_distance(layout, p)
	for key in ["arena_rect", "corridor_rect"]:
		if layout.has(key):
			best = maxf(best, _rect_inside(layout[key], Vector2(p.x, p.z)))
	return best


## How far inside a rectangle a point is (negative = outside).
static func _rect_inside(rect: Rect2, q: Vector2) -> float:
	var inside := minf(minf(q.x - rect.position.x, rect.end.x - q.x), minf(q.y - rect.position.y, rect.end.y - q.y))
	if inside >= 0.0:
		return inside
	var nearest := Vector2(clampf(q.x, rect.position.x, rect.end.x), clampf(q.y, rect.position.y, rect.end.y))
	return -q.distance_to(nearest)


## How far inside the field's edge a local point is (negative = outside).
static func _edge_distance(layout: Dictionary, p: Vector3) -> float:
	var polygon: PackedVector2Array = layout.boundary_2d
	var flat := Vector2(p.x, p.z)
	var best := INF
	var n := polygon.size()
	for i in n:
		best = minf(best, flat.distance_to(Geometry2D.get_closest_point_to_segment(flat, polygon[i], polygon[(i + 1) % n])))
	return best if Geometry2D.is_point_in_polygon(flat, polygon) else -best


## Keeps a point inside the field, `margin` from its edge.
static func _clamp_open(layout: Dictionary, local_point: Vector3, margin: float) -> Vector3:
	var center: Vector3 = layout.center
	var flat := Vector2(local_point.x, local_point.z)
	# Most points are nowhere near the edge: the middle 2/3 of the field is always inside.
	if margin <= 8.0 and absf(flat.x - center.x) < OPEN_SIZE.x * 0.33 and absf(flat.y - center.z) < OPEN_SIZE.y * 0.33:
		return local_point
	if walkable_distance(layout, local_point) >= margin:
		return local_point
	# In (or nearest to) the arena or its corridor: keep it in that box.
	for key in ["arena_rect", "corridor_rect"]:
		if layout.has(key):
			var rect: Rect2 = layout[key]
			if _rect_inside(rect, flat) > _edge_distance(layout, local_point) and _rect_inside(rect, flat) > -6.0:
				var inner := rect.grow(-minf(margin, rect.size.x * 0.4))
				return Vector3(clampf(flat.x, inner.position.x, inner.end.x), local_point.y, clampf(flat.y, inner.position.y, inner.end.y))
	# Pull it towards the middle until it's far enough in.
	var to := Vector2(center.x, center.z) - flat
	var lo := 0.0
	var hi := 1.0
	for i in 12:
		var mid := (lo + hi) * 0.5
		var trial := flat + to * mid
		if _edge_distance(layout, Vector3(trial.x, 0.0, trial.y)) >= margin:
			hi = mid
		else:
			lo = mid
	var out := flat + to * hi
	return Vector3(out.x, local_point.y, out.y)


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
