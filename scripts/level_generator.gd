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


# --- Tile levels (Act 2 onwards) ---------------------------------------------------------
#
# Laid out like the wilderness in the old isometric ARPGs: a long strip of square
# tiles, GRID_ROWS across the screen (local x, +x towards the camera) by
# GRID_COLS from left to right (local z, from 0 at the camp's edge to -length).
# A random walk lays a guaranteed route of tiles from the camp tile (column 0)
# to the boss tile (the last column); more tiles are added around it until the
# strip is about GRID_FILL full. Tiles next to each other are joined (no wall)
# along the route and wherever a tile was added, and sometimes elsewhere; where
# they aren't, a wall runs between them, so the strip is partly a maze but the
# way from the camp to the boss is always there. Each field tile gets a
# template (open, grove, scatter, pillars or ruins). The boss arena is a walled
# box off the boss tile's right side, joined by a short corridor. The town (the
# fenced square with the lemonade stand, shops and breeder) fills a tile in the
# middle columns.

const TILE := 48.0  ## A tile's side.
const GRID_COLS := 7  ## Tiles from left to right.
const GRID_ROWS := 4  ## Tiles across the screen.
const GRID_FILL := 0.7  ## About this share of the grid's tiles are used.
const EXTRA_LINK_CHANCE := 0.45  ## Two neighbouring tiles not already joined are joined this often.
const WALL_HALF := 0.5  ## Half a wall's thickness (walls run along tile edges).
const OPEN_PLAZA := Vector2(36.0, 34.0)  ## The town square: x by z.
const CAMP_RADIUS := 16.0
## The boss arena: a walled box (x by z) off the boss tile's right side,
## joined to it by a corridor CORRIDOR_WIDTH wide.
const ARENA_BOX := Vector2(56.0, 52.0)
const CORRIDOR_WIDTH := 10.0
const CORRIDOR_LENGTH := 10.0
## The town's gates: the middle of its camera-facing (south) side and of its left (west) side.
const GATE_WIDTH := 6.0
## A tile's sides: s = +x (towards the camera), n = -x, w = +z (towards the camp), e = -z (towards the boss).
const SIDES := {"s": Vector2i(0, 1), "n": Vector2i(0, -1), "w": Vector2i(-1, 0), "e": Vector2i(1, 0)}
const TEMPLATES := ["open", "grove", "scatter", "pillars", "ruins"]
## The key dungeon (DungeonDB): a small maze of DUNGEON_COLS x DUNGEON_ROWS
## rooms, DUNGEON_TILE a side, laid out off to the side of the map (beyond
## the camera-facing edge, out of sight). Its rooms are tiles like the map's
## (in layout.cells, with "grid": "dungeon"), keyed DUNGEON_KEY + their place.
const DUNGEON_TILE := 20.0
const DUNGEON_COLS := 4
const DUNGEON_ROWS := 3
const DUNGEON_KEY := 100
const DUNGEON_GAP := 70.0  ## Between the map's camera-facing edge and the dungeon.
const ENTRANCE_CLEARANCE := 9.0  ## Nothing else is placed this close to the dungeon entrance.


## The tile layout, with the same keys as a path layout (where they make sense)
## plus: open: true, tile: true, cells: [{cell: Vector2i(col, row), rect: Rect2
## (x, z), kind: "camp" | "town" | "boss" | "field", template: String, closed:
## {s, n, w, e: bool}}], cell_index: {Vector2i: int}, ruins: [Rect2] (low
## wall stubs), bounds: Rect2 (x, z; the whole level), camp_center /
## arena_center / mouth: Vector3, arena_rect / corridor_rect: Rect2, left_z.
## `path` is the path layout from the same seed: its counts, rival and colours
## are reused.
static func generate_open(level_seed: int, path: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed ^ 0x711e5
	var present := {}  # Vector2i(col, row) -> true
	var links := {}  # _link_key(a, b) -> true: joined, no wall between
	var link := func(a: Vector2i, b: Vector2i) -> void: links[_link_key(a, b)] = true
	var inside := func(c: Vector2i) -> bool: return c.x >= 0 and c.x < GRID_COLS and c.y >= 0 and c.y < GRID_ROWS

	# The route: left to right, now and then stepping up or down a row.
	var at := Vector2i(0, rng.randi_range(0, GRID_ROWS - 1))
	var route: Array[Vector2i] = [at]
	present[at] = true
	var steps_here := 0
	while at.x < GRID_COLS - 1:
		var next := at + Vector2i(1, 0)
		if steps_here < 2 and at.x > 0 and rng.randf() < 0.45:
			var dir := 1 if rng.randf() < 0.5 else -1
			for d in [dir, -dir]:
				var side_step := at + Vector2i(0, d)
				if inside.call(side_step) and not present.has(side_step):
					next = side_step
					break
		steps_here = steps_here + 1 if next.x == at.x else 0
		link.call(at, next)
		at = next
		route.append(at)
		present[at] = true

	# Grow more tiles off the ones already there.
	var target := roundi(GRID_COLS * GRID_ROWS * GRID_FILL)
	for guard in 200:
		if present.size() >= target:
			break
		var options: Array[Vector2i] = []
		for c: Vector2i in present:
			for d: Vector2i in SIDES.values():
				var n := c + d
				if inside.call(n) and not present.has(n) and n.x < GRID_COLS - 1 and not options.has(n):
					options.append(n)
		if options.is_empty():
			break
		var add: Vector2i = options[rng.randi() % options.size()]
		var touching: Array[Vector2i] = []
		for d: Vector2i in SIDES.values():
			if present.has(add + d):
				touching.append(add + d)
		present[add] = true
		link.call(add, touching[rng.randi() % touching.size()])
	# ...and join some more neighbours, for loops and wide-open stretches.
	var ordered: Array[Vector2i] = []
	for c: Vector2i in present:
		ordered.append(c)
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for c in ordered:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = c + d
			if present.has(n) and not links.has(_link_key(c, n)) and rng.randf() < EXTRA_LINK_CHANCE:
				link.call(c, n)

	# The town: a tile in the middle columns, away from the route if it can be (a side room).
	var camp_cell := route[0]
	var boss_cell := route[-1]
	var middle: Array[Vector2i] = []
	var side_rooms: Array[Vector2i] = []
	for c in ordered:
		if c.x >= 2 and c.x <= GRID_COLS - 3:
			middle.append(c)
			if not route.has(c):
				side_rooms.append(c)
	var pool := side_rooms if not side_rooms.is_empty() and rng.randf() < 0.6 else middle
	var town_cell: Vector2i = pool[rng.randi() % pool.size()]

	var cells: Array[Dictionary] = []
	var cell_index := {}
	for c in ordered:
		var kind := "field"
		if c == camp_cell:
			kind = "camp"
		elif c == boss_cell:
			kind = "boss"
		elif c == town_cell:
			kind = "town"
		var closed := {}
		for side: String in SIDES:
			closed[side] = not links.has(_link_key(c, c + SIDES[side]))
		cell_index[c] = cells.size()
		cells.append({"cell": c, "rect": cell_rect(c), "kind": kind, "closed": closed,
				"template": TEMPLATES[rng.randi() % TEMPLATES.size()] if kind == "field" else kind})

	# The dungeon's entrance: a field tile in the middle columns, kept open.
	var entrance_options := cells.filter(func(c: Dictionary) -> bool:
		return c.kind == "field" and c.cell.x >= 2 and c.cell.x <= GRID_COLS - 2)
	if entrance_options.is_empty():
		entrance_options = cells.filter(func(c: Dictionary) -> bool: return c.kind == "field")
	var entrance_cell: Dictionary = entrance_options[rng.randi() % entrance_options.size()]
	entrance_cell.template = "open"
	entrance_cell.entrance = true
	var entrance_at := Vector3(entrance_cell.rect.get_center().x - 4.0, 0.0, entrance_cell.rect.get_center().y)
	var hall: bool = DungeonDB.theme(path.biome).get("open_hall", false)
	var dungeon := _dungeon(rng, cells, cell_index, entrance_at, hall)
	if DungeonDB.theme(path.biome).get("centre_pillars", false):
		_centre_pillars(dungeon, cells)

	# The boss arena, off the boss tile's right side.
	var boss_rect := cell_rect(boss_cell)
	var arena_x := boss_rect.get_center().x
	var mouth_z := boss_rect.position.y
	var box_near_z := mouth_z - CORRIDOR_LENGTH
	var arena_rect := Rect2(arena_x - ARENA_BOX.x * 0.5, box_near_z - ARENA_BOX.y, ARENA_BOX.x, ARENA_BOX.y)
	var corridor_rect := Rect2(arena_x - CORRIDOR_WIDTH * 0.5, box_near_z, CORRIDOR_WIDTH, CORRIDOR_LENGTH + 2.0)
	var right_z := arena_rect.position.y
	var grid_rect := Rect2(-GRID_ROWS * TILE * 0.5, -GRID_COLS * TILE, GRID_ROWS * TILE, GRID_COLS * TILE)
	var layout := {"open": true, "tile": true, "cells": cells, "cell_index": cell_index, "left_z": 0.0,
			"total_length": -right_z, "arena_rect": arena_rect, "corridor_rect": corridor_rect,
			"mouth": Vector3(arena_x, 0.0, mouth_z), "bounds": grid_rect.merge(arena_rect), "dungeon": dungeon,
			# The gate across the corridor to the boss, opened by the dungeon's key.
			"gate": Vector3(arena_x, 0.0, mouth_z - 3.0)}
	var camp_center := Vector3(cell_rect(camp_cell).get_center().x, 0.0, cell_rect(camp_cell).get_center().y)
	var arena_center := Vector3(arena_x, 0.0, arena_rect.get_center().y)
	var mouth := Vector3(arena_x, 0.0, mouth_z)

	var plaza := Rect2(-OPEN_PLAZA.x * 0.5, -OPEN_PLAZA.y * 0.5, OPEN_PLAZA.x, OPEN_PLAZA.y)
	var town_rect := cell_rect(town_cell)
	var town := Vector3(town_rect.get_center().x, 0.0, town_rect.get_center().y)
	var village := _village_open(plaza)
	village["frame"] = Transform3D(Basis(), town)
	var shop_local := Vector3(plaza.get_center().x + 5.0, 0.0, plaza.get_center().y + 6.0)

	# What's in each field tile, by its template. Everything keeps clear of the
	# tile's edges (so the ways between tiles stay open), of the camp, the town
	# and the way into the boss arena.
	var rocks: Array[Dictionary] = []
	var ruins: Array[Rect2] = []
	var taken: Array[Vector3] = []
	var keep_out := func(p: Vector3, room: float) -> bool:
		if walkable_distance(layout, p) < room:
			return true
		if Vector2(p.x - camp_center.x, p.z - camp_center.z).length() < CAMP_RADIUS + 6.0:
			return true
		if Vector2(p.x - mouth.x, p.z - mouth.z).length() < 14.0:
			return true
		if Vector2(p.x - entrance_at.x, p.z - entrance_at.z).length() < ENTRANCE_CLEARANCE:
			return true
		if cell_at(layout, p) >= 0 and layout.cells[cell_at(layout, p)].get("grid", "") == "dungeon":
			return true  # the dungeon fills itself (_dungeon)
		var q := p - town
		return plaza.grow(7.0).has_point(Vector2(q.x, q.z))
	var far_enough := func(p: Vector3, spacing: float) -> bool:
		for other in taken:
			if Vector2(other.x - p.x, other.z - p.z).length() < spacing:
				return false
		for r in ruins:
			if r.grow(2.5).has_point(Vector2(p.x, p.z)):
				return false
		return true
	var add_rock := func(p: Vector3) -> void:
		if not keep_out.call(p, 6.0) and far_enough.call(p, 4.5):
			taken.append(p)
			rocks.append({"pos": p, "size": Vector3(rng.randf_range(1.5, 3.5), rng.randf_range(1.5, 3.0), rng.randf_range(1.5, 3.5))})
	for cell: Dictionary in cells:
		if cell.get("grid", "") == "dungeon":
			continue
		var r: Rect2 = cell.rect
		var mid := Vector3(r.get_center().x, 0.0, r.get_center().y)
		var spread := func() -> Vector3:
			return Vector3(rng.randf_range(r.position.x + 8.0, r.end.x - 8.0), 0.0, rng.randf_range(r.position.y + 8.0, r.end.y - 8.0))
		match cell.template:
			"open":
				for i in rng.randi_range(1, 3):
					add_rock.call(spread.call())
			"scatter":
				for i in rng.randi_range(5, 8):
					add_rock.call(spread.call())
			"grove":  # a ring of trees round a clearing, with a gap or two
				var count := rng.randi_range(8, 11)
				var radius := rng.randf_range(9.0, 12.0)
				var turn := rng.randf() * TAU
				var gaps := [rng.randi() % count, rng.randi() % count]
				for i in count:
					if gaps.has(i):
						continue
					var a := turn + TAU * i / count
					add_rock.call(mid + Vector3(cos(a), 0.0, sin(a)) * radius)
			"pillars":
				for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
					add_rock.call(mid + Vector3(corner.x, 0.0, corner.y) * rng.randf_range(9.0, 12.0))
			"ruins":  # two or three broken wall stubs, knee high
				for i in rng.randi_range(2, 3):
					var length := rng.randf_range(6.0, 10.0)
					var off := Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0))
					var stub := Rect2(mid.x + off.x - length * 0.5, mid.z + off.y - 0.5, length, 1.0) if rng.randf() < 0.5 \
							else Rect2(mid.x + off.x - 0.5, mid.z + off.y - length * 0.5, 1.0, length)
					var clear := true
					for other in ruins:
						if other.grow(4.0).intersects(stub):
							clear = false
					if clear:
						ruins.append(stub)
				for i in rng.randi_range(0, 2):
					add_rock.call(spread.call())
	# The arena's four corner rocks, as on the path levels.
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		rocks.append({"pos": arena_center + Vector3(corner.x * 14.0, 0.0, corner.y * 12.0), "size": Vector3(3.0, 3.5, 3.0)})

	var sample_in := func(r: Rect2, room: float, spacing: float) -> Vector3:
		for attempt in 60:
			var p := Vector3(rng.randf_range(r.position.x + room, r.end.x - room), 0.0, rng.randf_range(r.position.y + room, r.end.y - room))
			if not keep_out.call(p, room) and far_enough.call(p, spacing):
				return p
		return Vector3.INF
	# Creature packs: as many creatures as the path level had, in packs of
	# PACK_MIN-PACK_MAX, dealt out over the field tiles (and the boss tile)
	# from a shuffled deck, so they're spread over the whole strip. Deeper
	# packs, further right, are tougher (World._start_level).
	var deck: Array[Rect2] = []
	for cell: Dictionary in cells:
		if cell.kind == "field" or cell.kind == "boss":
			deck.append(cell.rect)
	var sizes := pack_sizes(rng, path.creature_spots.size())
	var spots: Array[Dictionary] = []
	var dealt: Array[Rect2] = []
	for group in sizes.size():
		if dealt.is_empty():
			dealt = deck.duplicate()
			_shuffle(rng, dealt)
		var home: Vector3 = sample_in.call(dealt.pop_back(), 8.0, 14.0)
		if home == Vector3.INF:
			continue
		taken.append(home)
		var depth := progress(layout, home)
		var size: int = sizes[group]
		for k in size:
			var angle: float = TAU * k / size + rng.randf_range(-0.3, 0.3)
			spots.append({"pos": home + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(1.5, 4.5), "depth": depth, "group": group})
	# Vases: the same number (and as many gold ones), anywhere but the camp and town.
	var crates: Array[Dictionary] = []
	for crate: Dictionary in path.crate_spots:
		var p: Vector3 = sample_in.call(deck[rng.randi() % deck.size()], 3.0, 6.0)
		if p == Vector3.INF:
			continue
		taken.append(p)
		crates.append({"pos": p, "gold": crate.gold})

	layout.merge({
		"rocks": rocks,
		"ruins": ruins,
		"creature_spots": spots,
		"crate_spots": crates,
		"village": village,
		"shop_point": village.frame * shop_local,
		"shop_side": -1.0,
		"shop_yaw": 0.0,  # faces the camera
		"camp_center": camp_center,
		"arena_center": arena_center,
		"start_point": camp_center + Vector3(0.0, 0.0, 4.0),
		"stable_point": camp_center + Vector3(-8.0, 0.0, 2.0),
		"rival_point": arena_center,
		"exit_point": Vector3(arena_x, 0.0, right_z + 7.0),
		# Tile levels: the Travel portal is at the camp (the arena is behind the key gate).
		"travel_point": camp_center + Vector3(5.0, 0.0, -6.0),
		"hub_portals": [],
		"rival_name": path.rival_name,
		"rival_species": path.rival_species,
		"floor_tint": path.floor_tint,
		"biome": path.biome,
	})
	return layout


## A tile's square in level space: x across the screen, y = z.
static func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(-GRID_ROWS * TILE * 0.5 + c.y * TILE, -(c.x + 1) * TILE, TILE, TILE)


static func _link_key(a: Vector2i, b: Vector2i) -> String:
	if b.x < a.x or (b.x == a.x and b.y < a.y):
		var t := a
		a = b
		b = t
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]


static func _shuffle(rng: RandomNumberGenerator, list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Variant = list[i]
		list[i] = list[j]
		list[j] = t


## The tile a level-local point is on (its index in layout.cells), or -1.
static func cell_at(layout: Dictionary, p: Vector3) -> int:
	var c := Vector2i(floori(-p.z / TILE), floori((p.x + GRID_ROWS * TILE * 0.5) / TILE))
	var i: int = layout.cell_index.get(c, -1)
	if i >= 0:
		return i
	var o := dungeon_origin()
	var d := Vector2i(DUNGEON_KEY + floori((o.y - p.z) / DUNGEON_TILE), DUNGEON_KEY + floori((p.x - o.x) / DUNGEON_TILE))
	return layout.cell_index.get(d, -1)


## The dungeon's corner: x of its far side, z of its left (camp) side.
static func dungeon_origin() -> Vector2:
	return Vector2(GRID_ROWS * TILE * 0.5 + DUNGEON_GAP, -30.0)


## A dungeon room's square (`c` = its place, column and row).
static func dungeon_rect(c: Vector2i) -> Rect2:
	var o := dungeon_origin()
	return Rect2(o.x + c.y * DUNGEON_TILE, o.y - (c.x + 1) * DUNGEON_TILE, DUNGEON_TILE, DUNGEON_TILE)


## True if a level-local point is in the dungeon.
static func in_dungeon(layout: Dictionary, p: Vector3) -> bool:
	var d: Dictionary = layout.get("dungeon", {})
	return not d.is_empty() and (d.bounds as Rect2).grow(2.0).has_point(Vector2(p.x, p.z))


## The key dungeon: a maze of rooms (a random spanning tree, plus a few
## loops), added to `cells` (as "grid": "dungeon"). You arrive in the first
## room (at the left, its stairs back up against its left wall) and the
## Keeper waits in the room furthest from it, round its four pillars; two or
## three packs hold the rooms between. Returns {entrance, back (where you come
## out, in front of the entrance), arrive, exit, keeper: Vector3, spots:
## [{pos, group}], pillars: [Vector3], bounds: Rect2}.
static func _dungeon(rng: RandomNumberGenerator, cells: Array[Dictionary], cell_index: Dictionary,
		entrance_at: Vector3, hall := false) -> Dictionary:
	var inside := func(c: Vector2i) -> bool: return c.x >= 0 and c.x < DUNGEON_COLS and c.y >= 0 and c.y < DUNGEON_ROWS
	var start := Vector2i(0, rng.randi_range(0, DUNGEON_ROWS - 1))
	var links := {}
	if hall:
		return _hall(rng, cells, cell_index, entrance_at, start)
	# The Keeper's room: the far back corner, walled all round but for a
	# doorway in the middle of its south wall (the camera's side), as in every
	# dungeon. The maze fills the other rooms and leads to that doorway.
	var far := Vector2i(DUNGEON_COLS - 1, 0)
	var seen := {start: true, far: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var here: Vector2i = stack[-1]
		var next: Array[Vector2i] = []
		for d: Vector2i in SIDES.values():
			if inside.call(here + d) and not seen.has(here + d):
				next.append(here + d)
		if next.is_empty():
			stack.pop_back()
			continue
		var go: Vector2i = next[rng.randi() % next.size()]
		links[_link_key(here, go)] = true
		seen[go] = true
		stack.append(go)
	for c: Vector2i in seen:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if c != far and c + d != far and seen.has(c + d) and rng.randf() < 0.2:
				links[_link_key(c, c + d)] = true
	links[_link_key(far, far + Vector2i(0, 1))] = true  # the doorway
	var pillars: Array[Vector3] = []
	var spots: Array[Dictionary] = []
	var middle_rooms: Array[Rect2] = []
	for col in DUNGEON_COLS:
		for row in DUNGEON_ROWS:
			var c := Vector2i(col, row)
			var closed := {}
			for side: String in SIDES:
				closed[side] = not links.has(_link_key(c, c + SIDES[side]))
			var kind := "dungeon_entry" if c == start else ("dungeon_keeper" if c == far else "dungeon")
			var r := dungeon_rect(c)
			cell_index[Vector2i(DUNGEON_KEY + col, DUNGEON_KEY + row)] = cells.size()
			cells.append({"cell": Vector2i(DUNGEON_KEY + col, DUNGEON_KEY + row), "rect": r, "kind": kind, "closed": closed,
					"template": kind, "grid": "dungeon"})
			if c == far:
				cells[-1].doorway = "s"  # walled either side of its doorway (World, DungeonBuilder)
			var mid := Vector3(r.get_center().x, 0.0, r.get_center().y)
			if kind == "dungeon_keeper":
				for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
					pillars.append(mid + Vector3(k.x, 0.0, k.y) * 6.0)
			elif kind == "dungeon":
				middle_rooms.append(r)
				if rng.randf() < 0.5:
					for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
						pillars.append(mid + Vector3(k.x, 0.0, k.y) * 5.5)
	# Packs in two or three of the rooms between (packs of 3-4, round the room's middle).
	_shuffle(rng, middle_rooms)
	var packs := mini(rng.randi_range(2, 3), middle_rooms.size())
	for group in packs:
		var r: Rect2 = middle_rooms[group]
		var mid := Vector3(r.get_center().x, 0.0, r.get_center().y)
		var size := rng.randi_range(3, 4)
		for k in size:
			var angle: float = TAU * k / size + rng.randf_range(-0.3, 0.3)
			spots.append({"pos": mid + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(1.5, 3.2), "group": 1000 + group})
	# A quiet room (no pack) for a centrepiece, if the theme has one (the ice halls' fountain).
	var centre := Vector3.INF
	if middle_rooms.size() > packs:
		var quiet: Rect2 = middle_rooms[packs]
		centre = Vector3(quiet.get_center().x, 0.0, quiet.get_center().y)
	var first := dungeon_rect(start)
	var keeper_room := dungeon_rect(far)
	var o := dungeon_origin()
	return {
		"entrance": entrance_at,
		"door": entrance_at + Vector3(2.6, 0.0, 0.0),  # walk in here
		"back": entrance_at + Vector3(5.5, 0.0, 0.0),  # where you come out
		"arrive": Vector3(first.get_center().x, 0.0, first.get_center().y),
		"exit": Vector3(first.get_center().x, 0.0, first.end.y - 2.5),  # the stairs back up
		"keeper": Vector3(keeper_room.get_center().x, 0.0, keeper_room.get_center().y),
		"spots": spots, "pillars": pillars, "centre": centre,
		"bounds": Rect2(o.x, o.y - DUNGEON_COLS * DUNGEON_TILE, DUNGEON_ROWS * DUNGEON_TILE, DUNGEON_COLS * DUNGEON_TILE),
	}


## An open hall (a theme's "open_hall", the ice halls): no walls between its
## rooms, only round the outside, except the Keeper's room in the far back
## corner, walled all round but for a doorway (an archway) in the middle of
## its south wall (the camera's side). One pillar stands somewhere in each
## room but the Keeper's and the quiet room with the centrepiece; packs and
## the centrepiece as in a maze.
static func _hall(rng: RandomNumberGenerator, cells: Array[Dictionary], cell_index: Dictionary,
		entrance_at: Vector3, start: Vector2i) -> Dictionary:
	var keeper := Vector2i(DUNGEON_COLS - 1, 0)
	var links := {}
	for col in DUNGEON_COLS:
		for row in DUNGEON_ROWS:
			var c := Vector2i(col, row)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = c + d
				if n.x >= DUNGEON_COLS or n.y >= DUNGEON_ROWS:
					continue
				if (c == keeper or n == keeper) and not (c == keeper and n == keeper + Vector2i(0, 1)):
					continue  # the Keeper's room is walled, but for its south doorway
				links[_link_key(c, n)] = true
	var middle_rooms: Array[Rect2] = []
	for col in DUNGEON_COLS:
		for row in DUNGEON_ROWS:
			var c := Vector2i(col, row)
			var closed := {}
			for side: String in SIDES:
				closed[side] = not links.has(_link_key(c, c + SIDES[side]))
			var kind := "dungeon_entry" if c == start else ("dungeon_keeper" if c == keeper else "dungeon")
			var r := dungeon_rect(c)
			cell_index[Vector2i(DUNGEON_KEY + col, DUNGEON_KEY + row)] = cells.size()
			var cell := {"cell": Vector2i(DUNGEON_KEY + col, DUNGEON_KEY + row), "rect": r, "kind": kind, "closed": closed,
					"template": kind, "grid": "dungeon"}
			if c == keeper:
				cell.doorway = "s"  # open for walking, but walled either side of an archway (DungeonBuilder)
			cells.append(cell)
			if kind == "dungeon":
				middle_rooms.append(r)
	_shuffle(rng, middle_rooms)
	var spots: Array[Dictionary] = []
	var packs := mini(rng.randi_range(2, 3), middle_rooms.size())
	for group in packs:
		var r: Rect2 = middle_rooms[group]
		var mid := Vector3(r.get_center().x, 0.0, r.get_center().y)
		var size := rng.randi_range(3, 4)
		for k in size:
			var angle: float = TAU * k / size + rng.randf_range(-0.3, 0.3)
			spots.append({"pos": mid + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(1.5, 3.2), "group": 1000 + group})
	var centre := Vector3.INF
	var quiet := Rect2()
	if middle_rooms.size() > packs:
		quiet = middle_rooms[packs]
		centre = Vector3(quiet.get_center().x, 0.0, quiet.get_center().y)
	var first := dungeon_rect(start)
	var exit := Vector3(first.get_center().x, 0.0, first.end.y - 2.5)
	# One pillar per room, somewhere off its middle (clear of the packs, the stairs and the walls).
	var pillars: Array[Vector3] = []
	for col in DUNGEON_COLS:
		for row in DUNGEON_ROWS:
			var c := Vector2i(col, row)
			var r := dungeon_rect(c)
			if c == keeper or r == quiet:
				continue
			var mid := Vector3(r.get_center().x, 0.0, r.get_center().y)
			for attempt in 12:
				var angle := rng.randf() * TAU
				var p := mid + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(4.5, 6.8)
				if Vector2(p.x - exit.x, p.z - exit.z).length() > 4.0:
					pillars.append(p)
					break
	var keeper_room := dungeon_rect(keeper)
	var o := dungeon_origin()
	return {
		"entrance": entrance_at,
		"door": entrance_at + Vector3(2.6, 0.0, 0.0),
		"back": entrance_at + Vector3(5.5, 0.0, 0.0),
		"arrive": Vector3(first.get_center().x, 0.0, first.get_center().y),
		"exit": exit,
		"keeper": Vector3(keeper_room.get_center().x, 0.0, keeper_room.get_center().y),
		"spots": spots, "pillars": pillars, "centre": centre, "hall": true,
		"bounds": Rect2(o.x, o.y - DUNGEON_COLS * DUNGEON_TILE, DUNGEON_ROWS * DUNGEON_TILE, DUNGEON_COLS * DUNGEON_TILE),
	}


## A theme's "centre_pillars": one pillar in the middle of each room instead,
## but the first (where you arrive) and the Keeper's (where it stands).
static func _centre_pillars(dungeon: Dictionary, cells: Array[Dictionary]) -> void:
	var pillars: Array[Vector3] = []
	for cell: Dictionary in cells:
		if cell.get("grid", "") == "dungeon" and cell.kind == "dungeon":
			var r: Rect2 = cell.rect
			pillars.append(Vector3(r.get_center().x, 0.0, r.get_center().y))
	dungeon.pillars = pillars


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


## How far inside the walkable ground a local point is (negative = outside):
## the tiles (walls run along their closed sides), the corridor to the boss
## and the boss arena.
static func walkable_distance(layout: Dictionary, p: Vector3) -> float:
	var best := _tiles_distance(layout, p)
	for key in ["arena_rect", "corridor_rect"]:
		if layout.has(key):
			best = maxf(best, _rect_inside(layout[key], Vector2(p.x, p.z)))
	return best


## How far a point is from the walls of the tile it's on (negative off the tiles).
static func _tiles_distance(layout: Dictionary, p: Vector3) -> float:
	var q := Vector2(p.x, p.z)
	var i := cell_at(layout, p)
	if i < 0:  # off the tiles: how far from the nearest one
		var best := -INF
		for cell: Dictionary in layout.cells:
			best = maxf(best, _rect_inside(cell.rect, q))
		return best - WALL_HALF
	var cell: Dictionary = layout.cells[i]
	var r: Rect2 = cell.rect
	var closed: Dictionary = cell.closed
	var d := INF
	if closed.n:
		d = minf(d, q.x - r.position.x)
	if closed.s:
		d = minf(d, r.end.x - q.x)
	if closed.e:
		d = minf(d, q.y - r.position.y)
	if closed.w:
		d = minf(d, r.end.y - q.y)
	# A corner between two open sides: a wall ends there unless the tile
	# across the corner is joined to both of those neighbours.
	for xs in ["n", "s"]:
		for zs in ["w", "e"]:
			if closed[xs] or closed[zs]:
				continue
			var here: Vector2i = cell.cell
			var a: Vector2i = here + SIDES[xs]
			var b: Vector2i = here + SIDES[zs]
			var diag: Vector2i = here + SIDES[xs] + SIDES[zs]
			var joined: bool = layout.cell_index.has(diag) and _joined(layout, a, diag) and _joined(layout, b, diag)
			if not joined:
				var corner := Vector2(r.position.x if xs == "n" else r.end.x, r.end.y if zs == "w" else r.position.y)
				d = minf(d, q.distance_to(corner))
	return d - WALL_HALF


## True if tiles `a` and `b` (neighbours) are joined, with no wall between.
static func _joined(layout: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	var i: int = layout.cell_index.get(a, -1)
	if i < 0 or not layout.cell_index.has(b):
		return false
	for side: String in SIDES:
		if a + SIDES[side] == b:
			return not layout.cells[i].closed[side]
	return false


## How far inside a rectangle a point is (negative = outside).
static func _rect_inside(rect: Rect2, q: Vector2) -> float:
	var inside := minf(minf(q.x - rect.position.x, rect.end.x - q.x), minf(q.y - rect.position.y, rect.end.y - q.y))
	if inside >= 0.0:
		return inside
	var nearest := Vector2(clampf(q.x, rect.position.x, rect.end.x), clampf(q.y, rect.position.y, rect.end.y))
	return -q.distance_to(nearest)


## Keeps a point on the tiles (or in the arena or its corridor), `margin` from the walls.
static func _clamp_open(layout: Dictionary, local_point: Vector3, margin: float) -> Vector3:
	if walkable_distance(layout, local_point) >= margin:
		return local_point
	var flat := Vector2(local_point.x, local_point.z)
	var tiles := _tiles_distance(layout, local_point)
	# In (or nearest to) the arena or its corridor: keep it in that box.
	for key in ["arena_rect", "corridor_rect"]:
		if layout.has(key):
			var rect: Rect2 = layout[key]
			var inside := _rect_inside(rect, flat)
			if inside > tiles and inside > -6.0:
				var inner := rect.grow(-minf(margin, rect.size.x * 0.4))
				return Vector3(clampf(flat.x, inner.position.x, inner.end.x), local_point.y, clampf(flat.y, inner.position.y, inner.end.y))
	# The tile it's on (or the nearest): clamp inside its closed sides.
	var i := cell_at(layout, local_point)
	if i < 0:
		var best := -INF
		for k in layout.cells.size():
			var inside := _rect_inside(layout.cells[k].rect, flat)
			if inside > best:
				best = inside
				i = k
	var cell: Dictionary = layout.cells[i]
	var r: Rect2 = cell.rect
	var inset := margin + WALL_HALF
	var lo := Vector2(r.position.x + (inset if cell.closed.n else 0.0), r.position.y + (inset if cell.closed.e else 0.0))
	var hi := Vector2(r.end.x - (inset if cell.closed.s else 0.0), r.end.y - (inset if cell.closed.w else 0.0))
	var out := Vector2(clampf(flat.x, lo.x, hi.x), clampf(flat.y, lo.y, hi.y))
	if _tiles_distance(layout, Vector3(out.x, 0.0, out.y)) < margin * 0.5:
		# Against a wall's end at a corner: pull it towards the tile's middle.
		var to := r.get_center() - out
		var a := 0.0
		var b := 1.0
		for k in 10:
			var m := (a + b) * 0.5
			var trial := out + to * m
			if _tiles_distance(layout, Vector3(trial.x, 0.0, trial.y)) >= margin:
				b = m
			else:
				a = m
		out += to * b
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
