class_name BatModels
## The tamer's bats (Player.BATS), one model each, held at the grip: the grip
## is at the origin and the bat points along -Z, in world units (about 0.95
## long). A bat with a model file (models/bats/<file>.glb, any size: it's
## scaled to LENGTH, handle end towards +Z) uses it; the others are built here
## from simple shapes.

const DIR := "res://models/bats/"
const LENGTH := 0.95  ## Knob to tip.
const GRIP_BACK := 0.13  ## How far the handle reaches back past the grip.
const BARREL_FROM := -0.17  ## The taper from the handle to the barrel starts here...
const BARREL_TO := -0.77  ## ...and the barrel ends here (its rounded end beyond).
## Each bat's file name and the shapes to fall back on, by Player.BATS tier.
const BATS := [
	{"file": "wooden_bat", "shape": "wood"},
	{"file": "spiked_bat", "shape": "spiked"},
	{"file": "chain_bat", "shape": "chain"},
	{"file": "barbed_wire_bat", "shape": "barbed"},
	{"file": "steel_slugger", "shape": "steel"},
	{"file": "ember_bat", "shape": "ember"},
]
const WOOD := Color(0.62, 0.4, 0.22)
const TAPE := Color(0.2, 0.12, 0.08)


## The bat for `tier`.
static func build(tier: int) -> Node3D:
	var spec: Dictionary = BATS[clampi(tier, 0, BATS.size() - 1)]
	var path: String = DIR + spec.file + ".glb"
	if ResourceLoader.exists(path):
		return _from_file(path)
	var bat := Node3D.new()
	bat.name = "Bat"
	match spec.shape:
		"spiked":
			_wooden(bat, WOOD, TAPE)
			_spikes(bat)
		"chain":
			_wooden(bat, WOOD, TAPE)
			_chain(bat)
		"barbed":
			_wooden(bat, Color(0.5, 0.32, 0.19), Color(0.16, 0.16, 0.17))
			_barbed_wire(bat)
		"steel":
			_wooden(bat, Color(0.3, 0.19, 0.12), Color(0.55, 0.12, 0.1))
			_steel(bat)
		"ember":
			_wooden(bat, Color(0.11, 0.085, 0.075), Color(0.25, 0.08, 0.05))
			_embers(bat)
		_:
			_wooden(bat, WOOD, TAPE)
	ModelLook.apply(bat, 0.03)
	return bat


## A model file: stood along -Z by its longest side and scaled to LENGTH, the
## grip GRIP_BACK from the handle's end.
static func _from_file(path: String) -> Node3D:
	var bat := Node3D.new()
	bat.name = "Bat"
	var scene: Node3D = (load(path) as PackedScene).instantiate()
	bat.add_child(scene)
	var box := _bounds(scene)
	var k := LENGTH / maxf(box.size.z, 0.001)
	scene.scale = Vector3.ONE * k
	var center := box.get_center()
	scene.position = Vector3(-center.x * k, -center.y * k, -(box.end.z * k) + GRIP_BACK)
	return bat


## The meshes' bounds under `scene`, in its own space.
static func _bounds(scene: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var to_scene := Transform3D()
		var node: Node = mesh
		while node != scene and node is Node3D:
			to_scene = (node as Node3D).transform * to_scene
			node = node.get_parent()
		var b := to_scene * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## How thick the bat is at `z` (along it).
static func radius_at(z: float) -> float:
	return lerpf(0.026, 0.06, clampf((BARREL_FROM - z) / (BARREL_FROM - BARREL_TO), 0.0, 1.0))


## The bat itself: a taped grip with a knob, swelling to a rounded barrel.
static func _wooden(bat: Node3D, wood_color: Color, tape_color: Color) -> void:
	var wood := _mat(wood_color)
	var tape := _mat(tape_color)
	_part(bat, _cylinder(0.022, 0.022, 0.3), tape, Vector3(0, 0, -0.02), Vector3(-90, 0, 0))  # grip
	_part(bat, _cylinder(0.035, 0.035, 0.03), tape, Vector3(0, 0, GRIP_BACK), Vector3(-90, 0, 0))  # knob
	_part(bat, _cylinder(radius_at(BARREL_TO), radius_at(BARREL_FROM), BARREL_FROM - BARREL_TO), wood,
			Vector3(0, 0, (BARREL_FROM + BARREL_TO) * 0.5), Vector3(-90, 0, 0))  # the taper to the barrel
	_part(bat, _sphere(0.06), wood, Vector3(0, 0, BARREL_TO), Vector3.ZERO, Vector3(1, 1, 0.8))  # rounded end


## Steel spikes driven through the barrel, three rings of four.
static func _spikes(bat: Node3D) -> void:
	var steel := _mat(Color(0.78, 0.8, 0.84))
	steel.metallic = 0.7
	steel.roughness = 0.35
	for i in 12:
		var along := -0.52 - (i / 4) * 0.1
		var angle := i * TAU / 4.0 + (i / 4) * 0.8
		var out := Vector3(cos(angle), sin(angle), 0.0)
		var spike := _part(bat, _cylinder(0.0, 0.03, 0.14), steel, Vector3(0, 0, along) + out * 0.08)
		spike.basis = Basis.looking_at(out, Vector3.FORWARD) * Basis(Vector3.RIGHT, -PI / 2.0)  # tip outwards


## A heavy chain wound three times round the barrel, its links alternating
## flat and edge-on, with a loose end and a padlock.
static func _chain(bat: Node3D) -> void:
	var iron := _mat(Color(0.66, 0.67, 0.72))
	iron.metallic = 0.8
	iron.roughness = 0.4
	var link := TorusMesh.new()
	link.inner_radius = 0.016
	link.outer_radius = 0.03
	link.rings = 10
	link.ring_segments = 6
	var links := 22
	for i in links:
		var t := float(i) / (links - 1)
		var z := lerpf(-0.3, -0.74, t)
		var angle := t * TAU * 3.0
		var out := Vector3(cos(angle), sin(angle), 0.0)
		var part := _part(bat, link, iron, Vector3(0, 0, z) + out * (radius_at(z) + 0.016))
		var along := Vector3(-sin(angle), cos(angle), -0.16).normalized()  # around the barrel
		part.basis = Basis.looking_at(along, out) * Basis(Vector3.FORWARD, PI / 2.0 if i % 2 else 0.0) \
				* Basis(Vector3.RIGHT, PI / 2.0)
	for i in 4:  # the loose end, trailing back along the barrel
		var part := _part(bat, link, iron, Vector3(0.08, 0.012, -0.28 + i * 0.04))
		part.rotation = Vector3(0, PI / 2.0 if i % 2 else 0.0, PI / 2.0)
	_part(bat, _box(Vector3(0.045, 0.05, 0.025)), _mat(Color(0.65, 0.55, 0.3)), Vector3(0.08, 0.0, -0.1))  # padlock


## Barbed wire coiled loosely round the barrel, a barb (two twisted points)
## every so often, its ends tucked under the coils.
static func _barbed_wire(bat: Node3D) -> void:
	var wire := _mat(Color(0.72, 0.72, 0.75))
	wire.metallic = 0.6
	wire.roughness = 0.4
	var tubes := SurfaceTool.new()
	tubes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var coil := PackedVector3Array()
	var steps := 90
	for i in steps + 1:
		var t := float(i) / steps
		var z := lerpf(-0.24, -0.75, t)
		var angle := t * TAU * 5.5
		coil.append(Vector3(cos(angle), sin(angle), 0.0) * (radius_at(z) + 0.007) + Vector3(0, 0, z))
	_tube(tubes, coil, 0.0065)
	for i in range(4, steps - 2, 6):  # the barbs: short spikes standing out of the wire, crossed
		var at := coil[i]
		var out := Vector3(at.x, at.y, 0.0).normalized()
		var along := (coil[i + 1] - coil[i - 1]).normalized()
		var across := out.cross(along).normalized()
		for d in [across + out * 0.8, -across + out * 0.8]:
			var dir := (d as Vector3).normalized()
			_tube(tubes, PackedVector3Array([at - dir * 0.014, at + dir * 0.036]), 0.0042)
	tubes.generate_normals()
	_part(bat, tubes.commit(), wire, Vector3.ZERO)


## A steel slugger: a steel cap on the end, three riveted steel bands and a
## steel knob, over dark wood with a red grip.
static func _steel(bat: Node3D) -> void:
	var steel := _mat(Color(0.72, 0.74, 0.78))
	steel.metallic = 0.85
	steel.roughness = 0.3
	_part(bat, _cylinder(0.063, radius_at(-0.66) + 0.004, 0.11), steel, Vector3(0, 0, -0.715), Vector3(-90, 0, 0))  # the cap
	_part(bat, _sphere(0.063), steel, Vector3(0, 0, -0.77), Vector3.ZERO, Vector3(1, 1, 0.55))  # its rounded end
	for z in [-0.33, -0.45, -0.57]:
		var r := radius_at(z) + 0.005
		_part(bat, _cylinder(r, r, 0.028), steel, Vector3(0, 0, z), Vector3(-90, 0, 0))
		for k in 6:  # rivets round the band
			var angle: float = k * TAU / 6.0 + z * 9.0
			_part(bat, _sphere(0.007), steel, Vector3(cos(angle), sin(angle), 0.0) * (r + 0.001) + Vector3(0, 0, z))
	_part(bat, _cylinder(0.038, 0.038, 0.032), steel, Vector3(0, 0, GRIP_BACK), Vector3(-90, 0, 0))  # the knob


## The Ember Bat: charred black wood split by cracks that glow like live
## coals, the end smouldering.
static func _embers(bat: Node3D) -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.5, 0.12)
	var cracks := SurfaceTool.new()
	cracks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for c in 7:  # cracks running along the barrel, wandering round it
		var angle := c * TAU / 7.0 + rng.randf_range(-0.2, 0.2)
		var z := rng.randf_range(-0.22, -0.3)
		var line := PackedVector3Array()
		var end := rng.randf_range(-0.62, -0.74)
		while z > end:
			line.append(Vector3(cos(angle), sin(angle), 0.0) * (radius_at(z) + 0.0015) + Vector3(0, 0, z))
			z -= rng.randf_range(0.03, 0.06)
			angle += rng.randf_range(-0.35, 0.35)
		if line.size() >= 2:
			_tube(cracks, line, 0.0035)
	_part(bat, cracks.commit(), glow, Vector3.ZERO)
	var tip := _part(bat, _sphere(0.061), glow, Vector3(0, 0, -0.775), Vector3.ZERO, Vector3(1, 1, 0.55))  # the smouldering end
	tip.transparency = 0.25


## A round tube along `points` (a few sides is plenty this thin).
static func _tube(st: SurfaceTool, points: PackedVector3Array, radius: float, sides := 5) -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var along := (b - a).normalized()
		var side := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized()
		var up := along.cross(side)
		for k in sides:
			var t0 := TAU * k / sides
			var t1 := TAU * (k + 1) / sides
			var o0 := (side * cos(t0) + up * sin(t0)) * radius
			var o1 := (side * cos(t1) + up * sin(t1)) * radius
			for corner in [a + o0, b + o0, b + o1, a + o0, b + o1, a + o1]:
				st.add_vertex(corner)


static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO,
		scl := Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	part.rotation_degrees = rot_deg
	part.scale = scl
	parent.add_child(part)
	return part


static func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _sphere(r: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	return mesh
