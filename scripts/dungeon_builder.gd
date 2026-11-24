class_name DungeonBuilder
## Builds a tile level's key dungeon (see DungeonDB, LevelGenerator._dungeon)
## out of simple shapes, under World.level_root:
## - the entrance on the surface, by theme: a stone mausoleum (crypt), a
##   stepped sandstone doorway between obelisks (sandstone), a carved stone
##   archway with glowing runes set into a rock mound (ancient), a mossy rock
##   mound with a dark natural mouth (cave) or an igloo with its tunnel (ice);
## - the dungeon's look inside: pillars (stone columns, rune columns,
##   stalagmites or ice crystals), details along the walls (niches, glyphs,
##   glowing runes, rock lumps, ice shards), braziers with light, and the
##   stairs back up;
## - the key (hidden until the Keeper drops it) and the gate across the
##   corridor to the boss arena (World.refresh_key opens it).
## The rooms' floors and walls themselves are built with the map's tiles
## (World._build_open).

const DOOR_GLOW := 2.2
## A brazier's light underground: energy, range (every dungeon alike, so all are as dark).
const BRAZIER_LIGHT := Vector2(1.0, 8.0)
## Torches (a theme's floor_torch / wall_torch models): their sizes, where a
## wall torch is mounted, and where its flame sits in the model (its units:
## y up, z out from the wall).
const FLOOR_TORCH_HEIGHT := 1.9
const PILLAR_MODEL_HEIGHT := 4.2  ## A theme's pillar model (the crypt's stone column), this tall.
const WALL_TORCH_HEIGHT := 1.4
const WALL_TORCH_MOUNT := 1.75
const WALL_TORCH_FLAME := Vector3(0.0, 44.0, 27.0)


static func build(world: World, layout: Dictionary, theme: Dictionary, theme_id: String, wall_mat: Material) -> void:
	var root: Node3D = world.level_root
	var d: Dictionary = layout.dungeon
	_entrance(root, d.entrance, theme, theme_id)
	_interior(root, layout, theme, theme_id, wall_mat)
	_stairs(root, d.exit, theme)
	_key(root, theme)
	_gate(root, layout.gate, Vector2(layout.corridor_rect.size.x, 0.0), theme)


# --- Shapes ----------------------------------------------------------------------------

## A textured material (<base>color.png, normal.png, roughness.png), mapped by
## world position every `tile` units, tinted by `tint`.
static func textured(base: String, tile: float, tint := Color.WHITE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.albedo_texture = load(base + "color.png")
	mat.normal_enabled = true
	mat.normal_texture = load(base + "normal.png")
	mat.roughness_texture = load(base + "roughness.png")
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / tile
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _mat(color: Color, glow := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = energy
	return mat


## A doorway's darkness: flat black, unlit.
static func _dark() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.02, 0.02, 0.03)
	return mat


static func _glow_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color.lightened(0.2)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = DOOR_GLOW
	return mat


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	part.rotation = rot
	part.scale = scale
	parent.add_child(part)
	return part


## A box with its four upright edges rounded off (`radius`, in `segments`
## faces each, smooth-shaded), centred on the origin: a pillar or a cap with
## soft corners. Cached by size.
static var _prisms := {}


static func rounded_prism(size: Vector3, radius: float, segments := 4, top_round := 0.0, round_steps := 4) -> ArrayMesh:
	var key := "%s|%s|%d|%s" % [size, radius, segments, top_round]
	if _prisms.has(key):
		return _prisms[key]
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	radius = minf(radius, minf(hx, hz))
	# The outline seen from above: each corner an arc round its own centre.
	var ring: Array[Vector2] = []
	var normals: Array[Vector2] = []
	var corners := [Vector2(hx, hz), Vector2(-hx, hz), Vector2(-hx, -hz), Vector2(hx, -hz)]
	for c in 4:
		var centre: Vector2 = corners[c] - Vector2(signf(corners[c].x), signf(corners[c].y)) * radius
		for k in segments + 1:
			var a := (c + k / float(segments)) * PI / 2.0
			var dir := Vector2(cos(a), sin(a))
			ring.append(centre + dir * radius)
			normals.append(dir)
	# The side, from the bottom up, in levels: straight up to where the top
	# edge starts to round over (`top_round`), then curving in to the top.
	var top := size.y * 0.5
	var rt := minf(top_round, size.y)
	var levels: Array[Dictionary] = [{"y": -top, "in": 0.0, "up": 0.0}, {"y": top - rt, "in": 0.0, "up": 0.0}]
	if rt > 0.0:
		for k in range(1, round_steps + 1):
			var th := k / float(round_steps) * PI / 2.0
			levels.append({"y": top - rt + rt * sin(th), "in": rt * (1.0 - cos(th)), "up": th})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := ring.size()
	var point := func(i: int, lv: Dictionary) -> Vector3:
		var q: Vector2 = ring[i] - normals[i] * float(lv["in"])
		return Vector3(q.x, lv["y"], q.y)
	var normal := func(i: int, lv: Dictionary) -> Vector3:
		var th: float = lv["up"]
		return Vector3(normals[i].x * cos(th), sin(th), normals[i].y * cos(th)).normalized()
	for i in n:
		var j := (i + 1) % n
		for l in levels.size() - 1:
			var lo: Dictionary = levels[l]
			var hi: Dictionary = levels[l + 1]
			# Clockwise seen from outside (Godot's front faces).
			for v in [[i, lo], [j, lo], [j, hi], [i, lo], [j, hi], [i, hi]]:
				st.set_normal(normal.call(v[0], v[1]))
				st.add_vertex(point.call(v[0], v[1]))
		# The top and bottom, as fans from the middle.
		var last: Dictionary = levels[-1]
		for v in [Vector3(0.0, top, 0.0), point.call(i, last), point.call(j, last)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
		for v in [Vector3(0.0, -top, 0.0), point.call(j, levels[0]), point.call(i, levels[0])]:
			st.set_normal(Vector3.DOWN)
			st.add_vertex(v)
	var mesh := st.commit()
	_prisms[key] = mesh
	return mesh


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, mat, rot)


static func _ball(parent: Node3D, pos: Vector3, scale: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	return _add(parent, mesh, pos, mat, Vector3.ZERO, scale)


static func _cylinder(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, mat: Material,
		rot := Vector3.ZERO, sides := 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	return _add(parent, mesh, pos, mat, rot)


## Something solid there (an invisible box).
static func _solid(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)


static func _light(parent: Node3D, pos: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	parent.add_child(light)


static func _sign(parent: Node3D, text: String, pos: Vector3, color: Color) -> Label3D:
	var sign := Label3D.new()
	sign.text = text
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.pixel_size = 0.012
	sign.font_size = 40
	sign.outline_size = 12
	sign.modulate = color
	sign.position = pos
	parent.add_child(sign)
	return sign


# --- The entrance ------------------------------------------------------------------------
# Built facing the camera (+x), the doorway at the front, about 2-3 units out
# from its centre; World moves whoever walks up to it into the dungeon.

static func _entrance(root: Node3D, at: Vector3, theme: Dictionary, theme_id: String) -> void:
	var e := Node3D.new()
	e.name = "DungeonEntrance"
	e.position = at
	root.add_child(e)
	var stone := _mat(theme.wall)
	var trim := _mat(theme.trim)
	var dark := _dark()
	var glow := _glow_mat(theme.glow)
	match theme_id:
		"crypt":  # the graveyard's own crypt (a textured model), scaled up, its iron door to the camera
			var crypt := (load("res://scenes/obstacles/graveyard_2.tscn") as PackedScene).instantiate() as Node3D
			crypt.rotation.y = PI / 2.0
			crypt.scale = Vector3.ONE * 2.6
			e.add_child(crypt)
			_blacken_crypt_gate(crypt, e)
			_open_crypt_door(e)
			for z in [-1.9, 1.9]:  # ghostly candles either side of the steps
				_cylinder(e, 0.07, 0.07, 0.45, Vector3(3.2, 0.22, z), _mat(Color(0.9, 0.88, 0.8)))
				_ball(e, Vector3(3.2, 0.55, z), Vector3(0.09, 0.15, 0.09), glow)
			_light(e, Vector3(3.6, 1.6, 0.0), theme.glow, 0.9, 5.0)
		"sandstone":  # a stepped sandstone block, a doorway between obelisks
			_box(e, Vector3(6.0, 1.4, 8.0), Vector3(-0.5, 0.7, 0.0), stone)
			_box(e, Vector3(5.0, 1.2, 6.6), Vector3(-0.9, 2.0, 0.0), stone)
			_box(e, Vector3(3.8, 1.0, 5.0), Vector3(-1.3, 3.1, 0.0), stone)
			for z in [-2.4, 2.4]:
				_cylinder(e, 0.12, 0.45, 4.2, Vector3(2.9, 2.1, z), trim, Vector3(0.0, PI / 4.0, 0.0), 4)
				_solid(e, Vector3(0.8, 4.0, 0.8), Vector3(2.9, 2.0, z))
			for z in [-1.15, 1.15]:
				_box(e, Vector3(0.6, 2.6, 0.6), Vector3(2.55, 1.3, z), trim)
			_box(e, Vector3(0.8, 0.6, 3.0), Vector3(2.55, 2.85, 0.0), trim)
			_cylinder(e, 0.42, 0.42, 0.1, Vector3(2.98, 2.85, 0.0), glow, Vector3(0.0, 0.0, PI / 2.0))
			_box(e, Vector3(0.1, 2.3, 1.7), Vector3(2.52, 1.15, 0.0), dark)
			_box(e, Vector3(1.2, 0.15, 2.4), Vector3(3.2, 0.07, 0.0), trim)
			_solid(e, Vector3(6.0, 3.6, 8.0), Vector3(-0.5, 1.8, 0.0))
		"ancient":  # a rock mound with a carved archway and glowing runes: someone built this
			for b in [[Vector3(-2.8, 1.0, 0.0), Vector3(3.6, 3.2, 4.6)], [Vector3(-1.8, 0.6, 2.9), Vector3(2.4, 2.0, 2.4)],
					[Vector3(-1.9, 0.5, -3.0), Vector3(2.4, 1.9, 2.6)], [Vector3(-3.8, 1.4, 0.5), Vector3(3.0, 3.0, 3.0)],
					[Vector3(0.7, 0.6, 2.6), Vector3(1.3, 1.2, 1.3)], [Vector3(0.6, 0.5, -2.6), Vector3(1.2, 1.1, 1.4)]]:
				_ball(e, b[0], b[1], stone)
			_box(e, Vector3(0.3, 2.7, 2.2), Vector3(1.75, 1.35, 0.0), dark)
			for z in [-1.5, 1.5]:
				_box(e, Vector3(0.9, 3.0, 0.9), Vector3(2.0, 1.5, z), trim)
				for y in [0.7, 1.3, 1.9, 2.5]:
					_box(e, Vector3(0.05, 0.28, 0.14), Vector3(2.47, y, z), glow)
				_solid(e, Vector3(0.9, 3.0, 0.9), Vector3(2.0, 1.5, z))
			_box(e, Vector3(1.1, 0.8, 4.0), Vector3(2.0, 3.3, 0.0), trim)
			_box(e, Vector3(0.05, 0.14, 2.8), Vector3(2.57, 3.3, 0.0), glow)
			_light(e, Vector3(3.2, 2.0, 0.0), theme.glow, 1.4, 6.0)
			_solid(e, Vector3(5.0, 3.6, 6.6), Vector3(-2.0, 1.8, 0.0))
			_solid(e, Vector3(1.6, 1.4, 1.6), Vector3(0.7, 0.7, 2.6))
			_solid(e, Vector3(1.6, 1.4, 1.6), Vector3(0.6, 0.7, -2.6))
		"cave":  # a mossy rock mound with a dark natural mouth, vines and glowing mushrooms
			var moss := _mat(Color(theme.trim))
			for b in [[Vector3(-2.8, 1.0, 0.0), Vector3(3.6, 3.0, 5.0)], [Vector3(-1.8, 0.7, 2.7), Vector3(2.4, 2.2, 2.6)],
					[Vector3(-1.6, 0.6, -2.8), Vector3(2.4, 2.0, 2.4)], [Vector3(0.2, 2.5, 0.0), Vector3(1.6, 0.9, 3.2)],
					[Vector3(0.6, 0.8, 1.9), Vector3(1.2, 1.1, 1.2)], [Vector3(0.6, 0.8, -1.9), Vector3(1.2, 1.1, 1.2)]]:
				_ball(e, b[0], b[1], stone)
			for b in [[Vector3(-2.4, 3.6, 0.4), Vector3(2.4, 0.5, 3.0)], [Vector3(-0.2, 3.2, 0.8), Vector3(1.2, 0.35, 1.4)],
					[Vector3(-1.6, 2.4, -2.6), Vector3(1.6, 0.4, 1.6)], [Vector3(0.6, 1.75, 1.9), Vector3(0.9, 0.3, 0.9)]]:
				_ball(e, b[0], b[1], moss)
			_ball(e, Vector3(0.75, 1.0, 0.0), Vector3(0.6, 1.45, 1.35), dark)
			for z in [-0.9, -0.35, 0.3, 0.85]:
				_cylinder(e, 0.035, 0.035, 1.2, Vector3(1.5, 1.9, z), moss)
			for m in [Vector3(2.2, 0.15, 2.2), Vector3(1.9, 0.15, -2.3), Vector3(1.0, 0.15, 3.0)]:
				_cylinder(e, 0.05, 0.05, 0.3, m, _mat(Color(0.85, 0.85, 0.75)))
				_ball(e, m + Vector3(0.0, 0.2, 0.0), Vector3(0.22, 0.1, 0.22), glow)
			_light(e, Vector3(2.4, 1.0, 0.0), theme.glow, 0.8, 5.0)
			_solid(e, Vector3(4.6, 3.2, 6.6), Vector3(-2.3, 1.6, 0.0))
			for z in [-1.9, 1.9]:
				_solid(e, Vector3(1.8, 1.6, 1.6), Vector3(0.6, 0.8, z))
		"ice":  # an igloo of ice blocks, with its tunnel
			var snow := _mat(Color(0.93, 0.95, 0.98))
			_ball(e, Vector3(-0.4, 0.05, 0.0), Vector3(4.4, 0.35, 4.4), snow)
			var dome := SphereMesh.new()
			dome.radius = 2.6
			dome.height = 2.6
			dome.is_hemisphere = true
			dome.radial_segments = 24
			dome.rings = 8
			_add(e, dome, Vector3(-0.8, 0.0, 0.0), stone)
			for h in [0.65, 1.25, 1.8, 2.25]:
				var ring := TorusMesh.new()
				var r := sqrt(2.62 * 2.62 - h * h)
				ring.inner_radius = r - 0.04
				ring.outer_radius = r + 0.04
				_add(e, ring, Vector3(-0.8, h, 0.0), trim)
			_cylinder(e, 1.25, 1.25, 2.6, Vector3(1.6, 0.0, 0.0), stone, Vector3(0.0, 0.0, PI / 2.0), 20)
			_cylinder(e, 0.95, 0.95, 0.1, Vector3(2.92, 0.0, 0.0), _dark(), Vector3(0.0, 0.0, PI / 2.0), 20)
			_solid(e, Vector3(5.2, 2.7, 5.2), Vector3(-0.8, 1.3, 0.0))
			_solid(e, Vector3(2.6, 1.3, 2.5), Vector3(1.5, 0.65, 0.0))
	_sign(e, theme.entrance, Vector3(2.4, {"crypt": 8.0, "ice": 3.6}.get(theme_id, 5.4), 0.0), Color(theme.key_color).lightened(0.3))


## The crypt model's iron gate, thrown open: its arched doorway (measured on
## the model: the gate's plane 1.6 out from the centre (its lock a little
## further, so the darkness stands at 1.9), 2.3 wide, from the top
## step at 0.85 up to a pointed top at 4.6) covered by darkness, and two iron
## gate leaves swung wide on their hinges at the jambs.
const CRYPT_DOOR := {"x": 1.5, "hinge_x": 2.08, "half": 1.1, "bottom": 0.85, "spring": 3.85, "top": 4.6}


## The crypt model's own closed gate and padlock, turned black to match the
## darkness behind them: each of its meshes is split in two, the triangles
## in the doorway (CRYPT_GATE, in the entrance's space) drawn flat black.
const CRYPT_GATE := {"x": Vector2(1.35, 2.0), "z": 1.05, "y": Vector2(0.8, 4.65)}
static var _black_gate_meshes := {}


static func _blacken_crypt_gate(crypt: Node3D, e: Node3D) -> void:
	var black := _dark()
	for m in crypt.find_children("*", "MeshInstance3D", true, false):
		var part := m as MeshInstance3D
		if part.mesh == null or part.mesh.get_surface_count() == 0:
			continue
		var key := part.mesh.resource_path + "|" + str(part.mesh.get_instance_id())
		if not _black_gate_meshes.has(key):
			_black_gate_meshes[key] = _split_gate(part, crypt, e, black)
		part.mesh = _black_gate_meshes[key]


static func _split_gate(part: MeshInstance3D, crypt: Node3D, e: Node3D, black: Material) -> ArrayMesh:
	# From the mesh's own space to the entrance's.
	var t := crypt.transform
	var chain := Transform3D()
	var up: Node = part
	while up != crypt and up != null:
		if up is Node3D:
			chain = (up as Node3D).transform * chain
		up = up.get_parent()
	t = t * chain
	var arrays := part.mesh.surface_get_arrays(0)
	var material := part.mesh.surface_get_material(0)
	if part.get_surface_override_material(0):
		material = part.get_surface_override_material(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
	var g := CRYPT_GATE
	var keep := PackedInt32Array()
	var gate := PackedInt32Array()
	for i in range(0, indices.size(), 3):
		var c: Vector3 = t * ((verts[indices[i]] + verts[indices[i + 1]] + verts[indices[i + 2]]) / 3.0)
		var inside: bool = c.x > g.x.x and c.x < g.x.y and absf(c.z) < g.z and c.y > g.y.x and c.y < g.y.y
		var target := gate if inside else keep
		target.append(indices[i])
		target.append(indices[i + 1])
		target.append(indices[i + 2])
	var mesh := ArrayMesh.new()
	for pair in [[keep, material], [gate, black]]:
		if (pair[0] as PackedInt32Array).is_empty():
			continue
		var a := arrays.duplicate()
		a[Mesh.ARRAY_INDEX] = pair[0]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
	return mesh


static func _open_crypt_door(e: Node3D) -> void:
	var d := CRYPT_DOOR
	var dark := _dark()
	var tall: float = d.spring - d.bottom
	_box(e, Vector3(0.04, tall, d.half * 2.0), Vector3(d.x, d.bottom + tall * 0.5, 0.0), dark)
	var arch := PrismMesh.new()  # the pointed top
	arch.size = Vector3(d.half * 2.0, d.top - d.spring, 0.04)
	_add(e, arch, Vector3(d.x, (d.spring + d.top) * 0.5, 0.0), dark, Vector3(0.0, PI / 2.0, 0.0))
	var iron := _mat(Color(0.2, 0.18, 0.16))
	iron.metallic = 0.6
	iron.roughness = 0.55
	var rust := _mat(Color(0.36, 0.24, 0.15))
	for side in [-1.0, 1.0]:
		# A leaf hinged at its jamb, swung out ~105 degrees towards the camera.
		var hinge := Node3D.new()
		hinge.position = Vector3(d.hinge_x, d.bottom, side * (d.half + 0.05))
		hinge.rotation.y = -side * deg_to_rad(100.0)  # outwards, towards the camera
		e.add_child(hinge)
		var width: float = d.half
		var height: float = tall + 0.35
		for y in [0.12, height * 0.5, height - 0.1]:  # rails
			_box(hinge, Vector3(0.06, 0.08, width), Vector3(0.0, y, -side * width * 0.5), rust)
		_box(hinge, Vector3(0.07, height, 0.07), Vector3(0.0, height * 0.5, 0.0), iron)  # the hinge stile
		_box(hinge, Vector3(0.07, height, 0.07), Vector3(0.0, height * 0.5, -side * width), iron)
		for k in range(1, 5):  # bars, with spear points
			var z: float = -side * width * k / 5.0
			_cylinder(hinge, 0.025, 0.025, height, Vector3(0.0, height * 0.5, z), iron, Vector3.ZERO, 6)
			_cylinder(hinge, 0.0, 0.06, 0.2, Vector3(0.0, height + 0.1, z), iron, Vector3.ZERO, 6)


# --- Inside --------------------------------------------------------------------------------

static func _interior(root: Node3D, layout: Dictionary, theme: Dictionary, theme_id: String, wall_mat: Material) -> void:
	var d: Dictionary = layout.dungeon
	var inside := Node3D.new()
	inside.name = "Dungeon"
	root.add_child(inside)
	if theme.has("models"):
		_interior_models(inside, layout, theme)
		return
	var stone := _mat(theme.wall)
	var trim := _mat(theme.trim)
	var glow := _glow_mat(theme.glow)
	var column: Material = stone  # the pillars' shafts and caps
	var cap: Material = trim
	if theme.has("pillar_texture"):
		column = textured(theme.pillar_texture, theme.pillar_tile)
		cap = textured(theme.wall_texture if theme.has("wall_texture") else theme.pillar_texture, 2.0, Color(0.8, 0.76, 0.7))
	# The Keeper room's doorway: a frame of two posts and a lintel.
	for cell: Dictionary in layout.cells:
		if cell.get("doorway", "") != "s":
			continue
		var r: Rect2 = cell.rect
		var mid := r.get_center().y
		var half := World.DOORWAY_HALF
		for z in [mid - half, mid + half]:
			_add(inside, rounded_prism(Vector3(1.3, 3.8, 1.3), 0.26), Vector3(r.end.x, 1.9, z), column)
			_solid(inside, Vector3(1.3, 3.8, 1.3), Vector3(r.end.x, 1.9, z))
			# A light on the room's front at each post, so the way in shows from across the hall.
			var lamp := Vector3(r.end.x + 0.9, 2.6, z)
			if theme.has("floor_torch"):
				_flame(inside, lamp + Vector3(0.0, -0.25, 0.0), 0.5)
				_flicker(inside, lamp + Vector3(0.6, 0.4, 0.0), 1.1, 8.0)
			else:
				_ball(inside, lamp, Vector3(0.16, 0.22, 0.16), glow)
				_light(inside, lamp + Vector3(0.8, 0.4, 0.0), theme.glow, 1.2, 8.0)
		_add(inside, rounded_prism(Vector3(1.5, 0.7, half * 2.0 + 1.8), 0.3), Vector3(r.end.x, 4.15, mid), cap)
		if theme_id == "ancient":
			_box(inside, Vector3(0.05, 0.14, half * 2.0), Vector3(r.end.x + 0.76, 4.15, mid), glow)
	# Pillars.
	for p: Vector3 in d.pillars:
		if theme.has("pillar_model"):
			_model(inside, theme.pillar_model, p, PILLAR_MODEL_HEIGHT)
			var thick: float = theme.get("pillar_width", 1.3)
			_solid(inside, Vector3(thick, 3.4, thick), p + Vector3(0.0, 1.7, 0.0))
			continue
		match theme_id:
			"cave":  # stalagmites
				_cylinder(inside, 0.12, 0.85, 3.2, p + Vector3(0.0, 1.6, 0.0), stone, Vector3.ZERO, 9)
			"ice":  # ice crystals
				_cylinder(inside, 0.15, 0.75, 3.6, p + Vector3(0.0, 1.8, 0.0), wall_mat, Vector3(0.0, 0.4, 0.0), 6)
			_:
				_add(inside, rounded_prism(Vector3(1.2, 3.4, 1.2), 0.24), p + Vector3(0.0, 1.7, 0.0), column)
				# The cap: the base's slab upside down, its bottom edge rounded over.
				_add(inside, rounded_prism(Vector3(1.5, 0.3, 1.5), 0.3, 4, 0.13), p + Vector3(0.0, 3.4, 0.0), cap, Vector3(PI, 0.0, 0.0))
				_add(inside, rounded_prism(Vector3(1.5, 0.3, 1.5), 0.3, 4, 0.13), p + Vector3(0.0, 0.15, 0.0), cap)  # the base: its top edge rounded over
				if theme_id == "ancient":
					_box(inside, Vector3(1.22, 0.12, 1.22), p + Vector3(0.0, 2.4, 0.0), glow)
		_solid(inside, Vector3(1.2, 3.4, 1.2), p + Vector3(0.0, 1.7, 0.0))
	# Along the walls (the far and side walls; the low camera-side ones stay bare).
	var decor := MultiMesh.new()
	decor.transform_format = MultiMesh.TRANSFORM_3D
	var shape: Mesh
	var shape_mat: Material = trim
	match theme_id:
		"cave":
			var lump := SphereMesh.new()
			lump.radius = 1.0
			lump.height = 2.0
			lump.radial_segments = 10
			lump.rings = 6
			shape = lump
			shape_mat = stone
		"ice":
			var shard := CylinderMesh.new()
			shard.top_radius = 0.02
			shard.bottom_radius = 0.35
			shard.height = 1.6
			shard.radial_segments = 5
			shape = shard
			shape_mat = wall_mat
		"ancient":
			var rune := BoxMesh.new()
			rune.size = Vector3(0.06, 0.22, 1.1)
			shape = rune
			shape_mat = glow
		_:
			var niche := BoxMesh.new()
			niche.size = Vector3(0.08, 0.9, 1.2)
			shape = niche
			shape_mat = _dark() if theme_id == "crypt" else trim
	decor.mesh = shape
	var spots: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.arrive.x * 1000.0 + d.arrive.z)
	for cell: Dictionary in layout.cells:
		if cell.get("grid", "") != "dungeon" or theme.has("wall_torch"):
			continue  # (a theme with wall torches leaves its walls bare)
		var r: Rect2 = cell.rect
		for side in ["n", "w", "e"]:
			if not cell.closed[side]:
				continue
			for k in range(1, 5):
				var t := k / 5.0
				var pos: Vector3
				var inward: Vector3
				match side:
					"n":
						pos = Vector3(r.position.x + 0.55, 0.0, lerpf(r.position.y, r.end.y, t))
						inward = Vector3(1, 0, 0)
					"w":
						pos = Vector3(lerpf(r.position.x, r.end.x, t), 0.0, r.end.y - 0.55)
						inward = Vector3(0, 0, -1)
					"e":
						pos = Vector3(lerpf(r.position.x, r.end.x, t), 0.0, r.position.y + 0.55)
						inward = Vector3(0, 0, 1)
				var basis := Basis.looking_at(-inward, Vector3.UP).rotated(Vector3.UP, PI / 2.0)
				match theme_id:
					"cave":
						var sz := rng.randf_range(0.5, 1.1)
						spots.append(Transform3D(Basis().scaled(Vector3(sz, sz * rng.randf_range(0.8, 1.6), sz)), pos + Vector3(0.0, sz * 0.4, 0.0)))
					"ice":
						spots.append(Transform3D(Basis().rotated(inward.cross(Vector3.UP), -0.35).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), pos + Vector3(0.0, 0.7, 0.0)))
					"ancient":
						spots.append(Transform3D(basis, pos + Vector3(0.0, 2.3, 0.0) - inward * 0.02))
					_:
						spots.append(Transform3D(basis, pos + Vector3(0.0, 1.7, 0.0) - inward * 0.03))
	decor.instance_count = spots.size()
	for i in spots.size():
		decor.set_instance_transform(i, spots[i])
	var decor_node := MultiMeshInstance3D.new()
	decor_node.multimesh = decor
	decor_node.material_override = shape_mat
	inside.add_child(decor_node)
	# Braziers (with light) in the first room, the Keeper's and a few between.
	var lit := 0
	for cell: Dictionary in layout.cells:
		if cell.get("grid", "") != "dungeon":
			continue
		var r: Rect2 = cell.rect
		var wanted: bool = cell.kind != "dungeon" or (lit < 6 and rng.randf() < 0.45)
		if not wanted:
			continue
		lit += 1
		for z in ([-3.5, 3.5] if cell.kind == "dungeon_keeper" else [0.0]):
			var at := Vector3(r.position.x + 1.6, 0.0, r.get_center().y + z)
			if theme.has("floor_torch"):  # a torch on its tripod, burning
				_model(inside, theme.floor_torch, at, FLOOR_TORCH_HEIGHT)
				_solid(inside, Vector3(0.7, FLOOR_TORCH_HEIGHT, 0.7), at + Vector3(0.0, FLOOR_TORCH_HEIGHT * 0.5, 0.0))
				_flame(inside, at + Vector3(0.0, FLOOR_TORCH_HEIGHT * 0.83, 0.0), 0.65)
				_flicker(inside, at + Vector3(0.0, FLOOR_TORCH_HEIGHT + 0.5, 0.0), BRAZIER_LIGHT.x, BRAZIER_LIGHT.y)
				continue
			_cylinder(inside, 0.12, 0.2, 1.0, at + Vector3(0.0, 0.5, 0.0), trim)
			_cylinder(inside, 0.45, 0.25, 0.3, at + Vector3(0.0, 1.1, 0.0), trim)
			_ball(inside, at + Vector3(0.0, 1.35, 0.0), Vector3(0.3, 0.42, 0.3), glow)
			_solid(inside, Vector3(0.8, 1.3, 0.8), at + Vector3(0.0, 0.65, 0.0))
			# Each brazier's own light, as dim as the ice halls' (BRAZIER_LIGHT).
			_light(inside, at + Vector3(0.6, 2.4, 0.0), theme.glow, BRAZIER_LIGHT.x, BRAZIER_LIGHT.y)
	if theme.has("wall_torch"):
		_wall_torches(inside, layout, theme)


## Wall torches: two on each room's far wall (facing the camera), where it
## has one, either side of its middle.
static func _wall_torches(inside: Node3D, layout: Dictionary, theme: Dictionary) -> void:
	for cell: Dictionary in layout.cells:
		if cell.get("grid", "") != "dungeon" or not cell.closed.n:
			continue
		var r: Rect2 = cell.rect
		for side in [-1.0, 1.0]:  # two per wall, either side of its middle (where a floor torch may stand)
			_wall_torch(inside, theme, Vector3(r.position.x + 0.5, WALL_TORCH_MOUNT, r.get_center().y + side * 5.5))


static func _wall_torch(inside: Node3D, theme: Dictionary, at: Vector3) -> void:
	var torch := (load(theme.wall_torch) as PackedScene).instantiate() as Node3D
	var k := WALL_TORCH_HEIGHT / maxf(_bounds(torch).size.y, 0.001)
	torch.scale = Vector3.ONE * k
	torch.rotation.y = PI / 2.0  # its back plate on the wall, the torch leaning out into the room
	torch.position = at
	inside.add_child(torch)
	var flame_at: Vector3 = at + Vector3(WALL_TORCH_FLAME.z * k, WALL_TORCH_FLAME.y * k, 0.0)
	_flame(inside, flame_at, 0.5)
	_flicker(inside, flame_at + Vector3(0.6, 0.3, 0.0), 0.8, 7.0)


## A burning flame, `height` tall, its foot at `at`: two flame cards (the
## torch_flame shader, each moving its own way) round a smaller, hotter core,
## and a few sparks rising and fading.
static func _flame(parent: Node3D, at: Vector3, height: float) -> void:
	var f := Node3D.new()
	f.name = "Flame"
	f.position = at
	parent.add_child(f)
	var shader := load("res://scripts/torch_flame.gdshader") as Shader
	for layer in [[0.62, 1.0, 1.7], [0.5, 0.88, 1.5], [0.3, 0.55, 2.6]]:  # width, height, brightness
		var card := QuadMesh.new()
		card.size = Vector2(height * layer[0], height * layer[1])
		card.center_offset = Vector3(0.0, height * layer[1] * 0.5, 0.0)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("seed", randf() * 50.0)
		mat.set_shader_parameter("intensity", layer[2])
		mat.set_shader_parameter("speed", randf_range(0.85, 1.15))
		var part := MeshInstance3D.new()
		part.mesh = card
		part.material_override = mat
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(part)
	var sparks := CPUParticles3D.new()
	sparks.amount = 7
	sparks.lifetime = 1.1
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = height * 0.12
	sparks.direction = Vector3.UP
	sparks.spread = 22.0
	sparks.initial_velocity_min = 0.5
	sparks.initial_velocity_max = 1.1
	sparks.gravity = Vector3(0.0, 0.3, 0.0)
	sparks.position = Vector3(0.0, height * 0.35, 0.0)
	var dot := QuadMesh.new()
	dot.size = Vector2(0.035, 0.035)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.albedo_color = Color(1.0, 0.65, 0.25)
	dot.material = spark_mat
	sparks.mesh = dot
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.85, 0.5, 1.0))
	fade.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	sparks.color_ramp = fade
	f.add_child(sparks)


## A torch's flickering light.
static func _flicker(parent: Node3D, at: Vector3, energy: float, reach: float) -> void:
	var light := FlickerLight.new()
	light.position = at
	light.light_color = Color(1.0, 0.64, 0.32)
	light.light_energy = energy
	light.omni_range = reach
	parent.add_child(light)


## A model (a .glb), `size` units tall (wider or deeper by `stretch`), turned
## `turn` about the vertical, standing on the floor at `at`.
static func _model(parent: Node3D, path: String, at: Vector3, height: float, turn := 0.0, stretch := Vector3.ONE) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	var aabb := _bounds(node)
	var k := height / maxf(aabb.size.y, 0.001)
	node.scale = Vector3(k * stretch.x, k, k * stretch.z)
	node.rotation.y = turn
	# Standing on the floor, centred on `at` (some models aren't made round their middle).
	var centre := Vector3(aabb.get_center().x * k * stretch.x, 0.0, aabb.get_center().z * k * stretch.z).rotated(Vector3.UP, turn)
	node.position = at + Vector3(-centre.x, -aabb.position.y * k, -centre.z)
	parent.add_child(node)
	return node


## A model's bounds (its meshes, unscaled).
static func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		# Through the model's own node transforms (Sketchfab exports nest scales and turns).
		var t := Transform3D()
		var up: Node = m
		while up != node and up != null:
			if up is Node3D:
				t = (up as Node3D).transform * t
			up = up.get_parent()
		var part := t * (m as MeshInstance3D).get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## A dungeon with models (the ice halls): carved wall segments along the far
## and side walls (the box walls there are solid but not drawn), support
## pillars, brazier pillars with light, an archway against the Keeper room's
## far wall and a fountain plaza in a quiet room. The models face +z as made.
static func _interior_models(inside: Node3D, layout: Dictionary, theme: Dictionary) -> void:
	var d: Dictionary = layout.dungeon
	var models: Dictionary = theme.models
	# The walls: every closed side of a room, once. A wall between two rooms is
	# one row of pieces down its middle (not a row from each side).
	var walls := RandomNumberGenerator.new()
	walls.seed = int(d.arrive.x * 7919.0 + d.arrive.z * 31.0) ^ 0x1ce
	var done := {}
	for cell: Dictionary in layout.cells:
		if cell.get("grid", "") != "dungeon":
			continue
		for side in ["n", "w", "e"]:
			if not cell.closed[side]:
				continue
			var across: Vector2i = cell.cell + LevelGenerator.SIDES[side]
			var shared: bool = layout.cell_index.has(across)
			if shared and side != "n":
				var key := LevelGenerator._link_key(cell.cell, across)
				if done.has(key):
					continue
				done[key] = true
			_wall_run(inside, models.wall, walls, cell.rect, side, shared)
	for p: Vector3 in d.pillars:
		_model(inside, models.pillar, p, 3.8)
		_solid(inside, Vector3(1.1, 3.6, 1.1), p + Vector3(0.0, 1.8, 0.0))
	# Brazier pillars, lit: in the first room, the Keeper's and a few between.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.arrive.x * 1000.0 + d.arrive.z)
	var lit := 0
	for cell: Dictionary in layout.cells:
		if cell.get("grid", "") != "dungeon":
			continue
		var r: Rect2 = cell.rect
		if not (cell.kind != "dungeon" or (lit < 6 and rng.randf() < 0.45)):
			continue
		lit += 1
		for z in ([-3.5, 3.5] if cell.kind == "dungeon_keeper" else [-6.0, 6.0]):
			var at := Vector3(r.position.x + 2.6, 0.0, r.get_center().y + z)
			_model(inside, models.brazier, at, 2.9)
			_solid(inside, Vector3(0.8, 2.8, 0.8), at + Vector3(0.0, 1.4, 0.0))
			_light(inside, at + Vector3(0.6, 3.2, 0.0), theme.glow, BRAZIER_LIGHT.x, BRAZIER_LIGHT.y)
	# The Keeper's room (open halls): its south wall, the camera's side, walled
	# either side of the archway in its middle, the way in to fight the Keeper.
	# (Its other walls are the usual closed sides.)
	for cell: Dictionary in layout.cells:
		if cell.get("doorway", "") != "s":
			continue
		var r: Rect2 = cell.rect
		var mid := r.get_center().y
		var gap := 3.3
		var x := r.end.x
		for span in [[mid + gap, r.end.y], [r.position.y, mid - gap]]:
			var lo: float = span[0] if span[0] < span[1] else span[1]
			var hi: float = span[1] if span[0] < span[1] else span[0]
			_wall_run(inside, models.wall, walls, Rect2(x, lo, 0.0, hi - lo), "n", true)
			_solid(inside, Vector3(1.0, 3.4, hi - lo + 1.0), Vector3(x, 1.7, (lo + hi) * 0.5))
		_model(inside, models.arch, Vector3(x, 0.0, mid), 6.4, PI / 2.0, Vector3(1.0, 1.0, 0.55))
		for z in [-gap, gap]:
			_solid(inside, Vector3(1.6, 5.0, 0.8), Vector3(x, 2.5, mid + z))
	# The fountain plaza.
	if d.centre != Vector3.INF:
		var f := _model(inside, models.centre, d.centre, 2.3)
		var aabb := _bounds(f)
		var wide := 9.6 / maxf(aabb.size.x, 0.001)
		f.scale = Vector3(wide, f.scale.y, wide)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 4.4
		cyl.height = 2.0
		shape.shape = cyl
		body.add_child(shape)
		body.position = d.centre + Vector3(0.0, 1.0, 0.0)
		inside.add_child(body)
		_light(inside, d.centre + Vector3(0.0, 3.5, 0.0), theme.glow, 1.4, 11.0)


## One wall of a room, dressed with wall models: 2-4 pieces of random widths
## (overlapping a little so they meet), each a little taller or shorter,
## deeper or shallower and turned a touch, half of them mirrored, and now and
## then one turned round to show the model's smooth ice back. `middle`: a wall
## between two rooms, one row down its middle; otherwise the pieces stand
## against the wall line, facing into the room.
const WALL_HEIGHT := 3.4
const WALL_DEPTH := 1.7


static func _wall_run(parent: Node3D, path: String, rng: RandomNumberGenerator, r: Rect2, side: String, middle: bool) -> void:
	var length := r.size.y if side == "n" else r.size.x
	var count := rng.randi_range(maxi(1, floori(length / 10.0)), maxi(1, floori(length / 5.0)))
	var shares: Array[float] = []
	var total := 0.0
	for i in count:
		shares.append(rng.randf_range(0.7, 1.3))
		total += shares[-1]
	var along := 0.0
	for i in count:
		var width := length * shares[i] / total
		var t := (along + width * 0.5) / length
		along += width
		var depth := WALL_DEPTH * rng.randf_range(0.85, 1.2)
		var inset := 0.0 if middle else depth * 0.5 - 0.5 + rng.randf_range(-0.12, 0.12)
		var at: Vector3
		var turn := 0.0
		match side:
			"n":  # faces +x, into the room and the camera
				at = Vector3(r.position.x + inset, 0.0, lerpf(r.end.y, r.position.y, t))
				turn = PI / 2.0
			"w":
				at = Vector3(lerpf(r.position.x, r.end.x, t), 0.0, r.end.y - inset)
				turn = PI
			"e":
				at = Vector3(lerpf(r.position.x, r.end.x, t), 0.0, r.position.y + inset)
		# Sometimes the smooth back faces out (never on a far wall between rooms:
		# its face is the one the camera sees).
		if (middle and side != "n") or (not middle and rng.randf() < 0.2):
			turn += PI if rng.randf() < 0.5 else 0.0
		turn += rng.randf_range(-0.06, 0.06)
		var seg := _model(parent, path, at, WALL_HEIGHT * rng.randf_range(0.85, 1.2), turn)
		var aabb := _bounds(seg)
		var mirror := -1.0 if rng.randf() < 0.5 else 1.0
		seg.scale.x = mirror * width * 1.12 / maxf(aabb.size.x, 0.001)
		seg.scale.z = depth / maxf(aabb.size.z, 0.001)


## The stairs back up, against the first room's left wall.
static func _stairs(root: Node3D, at: Vector3, theme: Dictionary) -> void:
	var s := Node3D.new()
	s.name = "DungeonExit"
	s.position = at
	root.add_child(s)
	var trim := _mat(Color(theme.trim).lightened(0.15))
	for k in 4:
		_box(s, Vector3(3.0, 0.25 + 0.25 * k, 0.6), Vector3(0.0, (0.25 + 0.25 * k) * 0.5, 1.2 + 0.6 * k - 0.9), trim)
	_box(s, Vector3(2.4, 2.4, 0.1), Vector3(0.0, 1.2, 2.1), _dark())
	_light(s, Vector3(0.0, 2.2, 0.0), Color(1.0, 0.95, 0.85), 1.0, 7.0)
	_sign(s, "Way out", Vector3(0.0, 3.0, 0.8), Color(0.95, 0.92, 0.8))


## The key, floating and turning (hidden until the Keeper drops it; World.refresh_key).
static func _key(root: Node3D, theme: Dictionary) -> void:
	var k := Node3D.new()
	k.name = "KeyPickup"
	k.visible = false
	root.add_child(k)
	var spin := Node3D.new()
	spin.name = "Spin"
	spin.position = Vector3(0.0, 1.2, 0.0)
	k.add_child(spin)
	var gold := _mat(theme.key_color, theme.key_color, 1.2)
	gold.metallic = 0.8
	gold.roughness = 0.3
	var bow := TorusMesh.new()
	bow.inner_radius = 0.16
	bow.outer_radius = 0.3
	_add(spin, bow, Vector3(0.0, 0.45, 0.0), gold, Vector3(PI / 2.0, 0.0, 0.0))
	_box(spin, Vector3(0.09, 0.85, 0.09), Vector3(0.0, -0.15, 0.0), gold)
	_box(spin, Vector3(0.22, 0.08, 0.09), Vector3(0.1, -0.45, 0.0), gold)
	_box(spin, Vector3(0.16, 0.08, 0.09), Vector3(0.08, -0.28, 0.0), gold)
	_light(k, Vector3(0.0, 1.4, 0.0), theme.key_color, 1.6, 5.0)
	_ball(k, Vector3(0.0, 0.03, 0.0), Vector3(0.7, 0.02, 0.7), _glow_mat(theme.key_color))


## The gate across the corridor to the boss: two posts, a beam and iron bars.
static func _gate(root: Node3D, at: Vector3, span: Vector2, theme: Dictionary) -> void:
	var g := Node3D.new()
	g.name = "BossGate"
	g.position = at
	root.add_child(g)
	var half := span.x * 0.5
	var stone := _mat(Color(theme.trim).darkened(0.1))
	var iron := _mat(Color(0.18, 0.18, 0.2))
	iron.metallic = 0.7
	iron.roughness = 0.45
	for x in [-half - 0.4, half + 0.4]:
		_box(g, Vector3(1.0, 4.2, 1.0), Vector3(x, 2.1, 0.0), stone)
	_box(g, Vector3(span.x + 1.8, 0.7, 1.1), Vector3(0.0, 4.25, 0.0), stone)
	var bars := Node3D.new()
	bars.name = "Bars"
	g.add_child(bars)
	var x := -half + 0.35
	while x <= half - 0.3:
		_cylinder(bars, 0.07, 0.07, 3.8, Vector3(x, 1.9, 0.0), iron, Vector3.ZERO, 8)
		x += 0.7
	for y in [0.8, 2.6]:
		_box(bars, Vector3(span.x, 0.12, 0.14), Vector3(0.0, y, 0.0), iron)
	var block := StaticBody3D.new()
	block.name = "Block"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span.x + 1.0, 4.0, 0.8)
	shape.shape = box
	block.add_child(shape)
	block.position = Vector3(0.0, 2.0, 0.0)
	g.add_child(block)
	var sign := _sign(g, "Locked: find the %s" % theme.key, Vector3(0.0, 5.2, 0.0), Color(theme.key_color).lightened(0.3))
	sign.name = "LockSign"
