class_name CreatureModel
## Builds a creature's body out of simple meshes, by body type: cats in
## Greenmeadow, birds in Frostfang Peaks, dogs in Sunscorch Dunes and lizards in
## Mirewood Bog. The parts hang off the creature's Body node, so they lunge,
## faint and flash with it. Heads face -Z; the Body origin sits 0.42 above the
## ground (before the species' size scales the whole model).
##
## Parts that move are hung on named pivots for CreatureAnimator: "Leg0".."Leg3"
## (at the hip; 0/3 and 1/2 step together), "Tail" (at its base) and "Wing0/1".

const GROUND := -0.42
## Where each body type's head and back are, for the hybrids' horns, manes,
## crowns and wings.
const HEAD := {"cat": Vector3(0, 0.2, -0.3), "dog": Vector3(0, 0.24, -0.3), "bird": Vector3(0, 0.32, -0.2),
		"lizard": Vector3(0, -0.1, -0.5)}
const BACK := {"cat": Vector3(0, 0.2, 0.15), "dog": Vector3(0, 0.22, 0.12), "bird": Vector3(0, 0.25, 0.05),
		"lizard": Vector3(0, -0.02, 0.0)}

## Where a collar sits on each body: position (just under the head, where it
## meets the body), tilt (degrees about X) and radius.
const NECK := {
	"cat": [Vector3(0, 0.03, -0.26), -15.0, 0.2], "dog": [Vector3(0, 0.08, -0.26), -15.0, 0.19],
	"bird": [Vector3(0, 0.17, -0.17), -10.0, 0.17], "lizard": [Vector3(0, -0.11, -0.3), -80.0, 0.17],
}

## Meshes and materials are shared between every creature that uses the same one.
static var _cache := {}


## Replaces `body`'s mesh with a `body_type` model. Parts in the species colour use `main`
## (the creature's own material, so flashes and fainting recolour them).
static func build(body: MeshInstance3D, body_type: String, main: StandardMaterial3D, color: Color,
		feature := "none") -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	body.mesh = null
	var m := {
		"main": main,
		"accent": _mat(color.darkened(0.45)),
		"light": _mat(color.lightened(0.45)),
		"eye": _mat(Color(1, 1, 0.92), true),
		"pupil": _mat(Color(0.08, 0.08, 0.1)),
		"nose": _mat(Color(0.9, 0.5, 0.55)),
		"beak": _mat(Color(1.0, 0.68, 0.15)),
		"gold": _mat(Color(1.0, 0.82, 0.3)),
		"white": _mat(Color(0.97, 0.96, 0.92)),
	}
	match body_type:
		"bird":
			_bird(body, m)
		"dog":
			_dog(body, m)
		"lizard":
			_lizard(body, m)
		_:
			_cat(body, m)
	match feature:
		"big_ears":  # upright fennec ears, in place of floppy ones
			for ear in body.get_children().filter(func(p: Node) -> bool: return p.name.begins_with("FloppyEar")):
				ear.queue_free()
			for x in [-1.0, 1.0]:
				_part(body, _prism(Vector3(0.2, 0.36, 0.06)), m.main, Vector3(x * 0.15, 0.52, -0.26), Vector3(0, 0, -x * 18))
				_part(body, _prism(Vector3(0.11, 0.22, 0.02)), m.nose, Vector3(x * 0.15, 0.5, -0.3), Vector3(0, 0, -x * 18))
		"spines":
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 14:
				var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.3, 1), rng.randf_range(-0.6, 1)).normalized()
				var spine := _part(body, _cylinder(0.0, 0.018, 0.14), m.light, Vector3(0, -0.02, 0.1) + dir * Vector3(0.28, 0.25, 0.4))
				spine.basis = Basis.looking_at(dir, Vector3.FORWARD if absf(dir.y) > 0.99 else Vector3.UP) \
						* Basis(Vector3.RIGHT, -PI / 2)  # the cone's tip (+Y) points along dir
		# Hybrids from the breeder.
		"horn":  # a gold horn on the forehead
			var head: Vector3 = HEAD.get(body_type, HEAD.cat)
			_part(body, _cylinder(0.0, 0.07, 0.32), m.gold, head + Vector3(0, 0.3, -0.1), Vector3(-30, 0, 0))
			_part(body, _cylinder(0.0, 0.03, 0.12), m.gold, head + Vector3(0, 0.16, -0.2), Vector3(-60, 0, 0))
		"mane":  # a fluffy ring around the head (a frill on lizards, a ruff on birds)
			var head: Vector3 = HEAD.get(body_type, HEAD.cat)
			for i in 10:
				var angle := TAU * i / 10.0
				var at := head + Vector3(cos(angle) * 0.27, sin(angle) * 0.25, 0.1)
				_part(body, _sphere(0.11), m.accent, at, Vector3.ZERO, Vector3(1, 1, 0.8))
		"crown":  # a little gold crown of spikes on top of the head
			var head: Vector3 = HEAD.get(body_type, HEAD.cat)
			for i in 5:
				var angle := TAU * i / 5.0
				_part(body, _cylinder(0.0, 0.035, 0.14), m.gold, head + Vector3(cos(angle) * 0.1, 0.24, sin(angle) * 0.1))
			_part(body, _cylinder(0.12, 0.12, 0.04), m.gold, head + Vector3(0, 0.18, 0))
		"wings":  # a pair of feathered wings, raised up and out from the back
			var back: Vector3 = BACK.get(body_type, BACK.cat)
			for x in [-1.0, 1.0]:
				var wing := _pivot(body, "Wing%d" % (0 if x < 0 else 1), back + Vector3(x * 0.15, 0, 0))
				# Feathered and white, except lizards' leathery dragon wings in their own colours.
				var front_mat: Material = m.accent if body_type == "lizard" else m.white
				var back_mat: Material = m.main if body_type == "lizard" else m.light
				var span := 0.75 if body_type == "lizard" else 1.0
				for f in 3:  # three feathers (or wing ribs) per wing, fanning outwards
					_part(wing, _sphere(0.3 * span), front_mat if f == 0 else back_mat,
							Vector3(x * (0.05 + f * 0.09), 0.22 + f * 0.04, 0.01 + f * 0.05), Vector3(0, 0, -x * (25 + f * 18)),
							Vector3(0.14, 0.95 - f * 0.18, 0.5))


static func _cat(b: Node3D, m: Dictionary) -> void:
	_part(b, _sphere(0.3), m.main, Vector3(0, -0.04, 0.08), Vector3.ZERO, Vector3(0.95, 0.85, 1.35))  # torso
	_part(b, _sphere(0.25), m.main, Vector3(0, 0.2, -0.3))  # head
	for x in [-1.0, 1.0]:
		_part(b, _prism(Vector3(0.15, 0.2, 0.07)), m.main, Vector3(x * 0.13, 0.46, -0.3), Vector3(0, 0, -x * 12))
		_part(b, _prism(Vector3(0.08, 0.12, 0.02)), m.nose, Vector3(x * 0.13, 0.44, -0.34), Vector3(0, 0, -x * 12))
		_eye(b, m, Vector3(x * 0.1, 0.25, -0.5), 0.06, true)
		for y in [0.0, 0.04]:  # whiskers
			_part(b, _box(Vector3(0.2, 0.012, 0.012)), m.accent, Vector3(x * 0.17, 0.14 + y, -0.5), Vector3(0, x * 15, x * (y * 300 - 6)))
	_part(b, _prism(Vector3(0.07, 0.05, 0.04)), m.nose, Vector3(0, 0.17, -0.55), Vector3(180, 0, 0))
	_legs(b, m.main, 0.06, 0.14, -0.12, 0.26)
	var tail := _pivot(b, "Tail", Vector3(0, -0.08, 0.4))  # curling up
	_part(tail, _cylinder(0.045, 0.045, 0.36), m.main, Vector3(0, 0.1, 0.1), Vector3(-55, 0, 0))
	_part(tail, _cylinder(0.04, 0.045, 0.3), m.main, Vector3(0, 0.35, 0.2), Vector3(-10, 0, 0))
	_part(tail, _sphere(0.05), m.accent, Vector3(0, 0.5, 0.22))


static func _bird(b: Node3D, m: Dictionary) -> void:
	_part(b, _sphere(0.32), m.main, Vector3(0, 0.0, 0.03), Vector3.ZERO, Vector3(1, 1, 1.1))  # body
	_part(b, _sphere(0.25), m.light, Vector3(0, -0.06, -0.1), Vector3.ZERO, Vector3(0.95, 1, 0.9))  # breast
	_part(b, _sphere(0.21), m.main, Vector3(0, 0.32, -0.2))  # head
	_part(b, _cylinder(0.0, 0.08, 0.22), m.beak, Vector3(0, 0.29, -0.44), Vector3(-90, 0, 0))
	for i in 3:  # crest
		_part(b, _prism(Vector3(0.05, 0.16, 0.08)), m.accent, Vector3(0, 0.55 - i * 0.03, -0.22 + i * 0.07), Vector3(-25 - i * 15, 0, 0))
	for x in [-1.0, 1.0]:
		_eye(b, m, Vector3(x * 0.11, 0.36, -0.36), 0.055, false)
		var wing := _pivot(b, "Wing%d" % (0 if x < 0 else 1), Vector3(x * 0.24, 0.2, 0.0))  # at the shoulder
		_part(wing, _sphere(0.28), m.accent, Vector3(x * 0.06, -0.16, 0.06), Vector3(0, 0, x * 15), Vector3(0.28, 0.65, 1.0))
		var leg := _pivot(b, "Leg%d" % (0 if x < 0 else 1), Vector3(x * 0.1, -0.23, 0.0))  # at the hip
		_part(leg, _cylinder(0.025, 0.025, 0.2), m.beak, Vector3(0, -0.1, 0.0))
		_part(leg, _box(Vector3(0.1, 0.03, 0.14)), m.beak, Vector3(0, -0.19, -0.04))  # foot
	var tail := _pivot(b, "Tail", Vector3(0, 0.05, 0.3))
	_part(tail, _box(Vector3(0.24, 0.04, 0.3)), m.accent, Vector3(0, 0.01, 0.1), Vector3(28, 0, 0))  # tail feathers
	_part(tail, _box(Vector3(0.14, 0.04, 0.22)), m.main, Vector3(0, 0.06, 0.16), Vector3(40, 0, 0))


static func _dog(b: Node3D, m: Dictionary) -> void:
	_part(b, _sphere(0.3), m.main, Vector3(0, -0.02, 0.08), Vector3.ZERO, Vector3(0.95, 0.85, 1.45))  # torso
	_part(b, _sphere(0.23), m.main, Vector3(0, 0.24, -0.3))  # head
	_part(b, _sphere(0.13), m.light, Vector3(0, 0.15, -0.5), Vector3.ZERO, Vector3(1, 0.8, 1.3))  # snout
	_part(b, _sphere(0.05), m.pupil, Vector3(0, 0.2, -0.66))  # nose
	_part(b, _box(Vector3(0.07, 0.02, 0.1)), m.nose, Vector3(0, 0.07, -0.55), Vector3(-25, 0, 0))  # tongue
	for x in [-1.0, 1.0]:
		_eye(b, m, Vector3(x * 0.1, 0.3, -0.48), 0.055, false)
		_part(b, _box(Vector3(0.11, 0.24, 0.06)), m.accent, Vector3(x * 0.21, 0.24, -0.28), Vector3(0, 0, x * 28)).name = "FloppyEar"
	_legs(b, m.main, 0.065, 0.15, -0.14, 0.3)
	var tail := _pivot(b, "Tail", Vector3(0, 0.03, 0.45))  # wags
	_part(tail, _cylinder(0.025, 0.045, 0.34), m.main, Vector3(0, 0.13, 0.11), Vector3(-40, 0, 0))
	_part(tail, _sphere(0.045), m.light, Vector3(0, 0.27, 0.22))


static func _lizard(b: Node3D, m: Dictionary) -> void:
	_part(b, _sphere(0.28), m.main, Vector3(0, -0.18, 0.05), Vector3.ZERO, Vector3(1, 0.62, 1.8))  # long, low body
	_part(b, _sphere(0.2), m.main, Vector3(0, -0.1, -0.5), Vector3.ZERO, Vector3(1, 0.75, 1.35))  # head
	_part(b, _box(Vector3(0.22, 0.015, 0.12)), m.pupil, Vector3(0, -0.15, -0.71))  # mouth line
	for i in 5:  # back spikes
		_part(b, _prism(Vector3(0.05, 0.12, 0.1)), m.accent, Vector3(0, -0.02 - absf(i - 1.5) * 0.015, -0.3 + i * 0.16))
	for x in [-1.0, 1.0]:
		_eye(b, m, Vector3(x * 0.13, 0.0, -0.52), 0.075, true)
		for z in [-0.22, 0.3]:  # sprawled legs, pivoting at the shoulder/hip
			var index := (0 if z < 0.0 else 1) + (0 if x < 0 else 2)
			var leg := _pivot(b, "Leg%d" % index, Vector3(x * 0.18, -0.22, z))
			_part(leg, _cylinder(0.05, 0.05, 0.24), m.main, Vector3(x * 0.09, -0.08, 0), Vector3(0, 0, x * 55))
			_part(leg, _sphere(0.06), m.accent, Vector3(x * 0.18, -0.17, -0.03), Vector3.ZERO, Vector3(1.2, 0.5, 1.4))
		_part(b, _sphere(0.08), m.accent, Vector3(x * 0.12, -0.08, 0.12 + x * 0.12), Vector3.ZERO, Vector3(1, 0.3, 1.2))  # spots
	var tail := _pivot(b, "Tail", Vector3(0, -0.24, 0.38))  # swishes side to side
	_part(tail, _cylinder(0.015, 0.12, 0.75), m.main, Vector3(0, 0, 0.34), Vector3(80, 0, 0))


# --- Helpers --------------------------------------------------------------------------

static func _eye(b: Node3D, m: Dictionary, at: Vector3, r: float, slit: bool) -> void:
	_part(b, _sphere(r), m.eye, at)
	var pupil: Mesh = _box(Vector3(r * 0.4, r * 1.3, r * 0.3)) if slit else _sphere(r * 0.5)
	_part(b, pupil, m.pupil, at + Vector3(0, 0, -r * 0.85))


## Four legs, each on a pivot at the hip: Leg0 front-left, Leg1 back-left,
## Leg2 front-right, Leg3 back-right.
static func _legs(b: Node3D, mat: Material, r: float, x: float, front: float, back: float) -> void:
	var height := 0.3
	var index := 0
	for side in [-1.0, 1.0]:
		for z in [front, back]:
			var leg := _pivot(b, "Leg%d" % index, Vector3(side * x, GROUND + height, z))
			_part(leg, _cylinder(r, r, height), mat, Vector3(0, -height * 0.5, 0))
			index += 1


static func _pivot(parent: Node3D, pivot_name: String, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = pos
	parent.add_child(pivot)
	return pivot


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


static func _cached(key: String, make: Callable) -> Resource:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


static func _mat(color: Color, unshaded := false) -> StandardMaterial3D:
	return _cached("mat%s%s" % [color.to_html(), unshaded], _new_mat.bind(color, unshaded))


static func _new_mat(color: Color, unshaded: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


static func _sphere(r: float) -> SphereMesh:
	return _cached("_sphere%s" % [[r]], _new_sphere.bind(r))


static func _new_sphere(r: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	return _cached("_box%s" % [[size]], _new_box.bind(size))


static func _new_box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _prism(size: Vector3) -> PrismMesh:
	return _cached("_prism%s" % [[size]], _new_prism.bind(size))


static func _new_prism(size: Vector3) -> PrismMesh:
	var mesh := PrismMesh.new()
	mesh.size = size
	return mesh


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	return _cached("_cylinder%s" % [[top, bottom, height]], _new_cylinder.bind(top, bottom, height))


static func _new_cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return mesh


## A collar in `color` around the neck, with a little gold tag hanging at the front.
static func add_collar(body: Node3D, body_type: String, color: Color) -> Node3D:
	var neck: Array = NECK.get(body_type, NECK.cat)
	var collar := Node3D.new()
	collar.name = "Collar"
	collar.position = neck[0]
	collar.rotation_degrees.x = neck[1]
	body.add_child(collar)
	var torus := TorusMesh.new()
	torus.inner_radius = neck[2] - 0.035
	torus.outer_radius = neck[2] + 0.04  # chunky, so it reads from the game camera
	torus.rings = 24
	torus.ring_segments = 8
	var band := MeshInstance3D.new()
	band.mesh = torus
	band.material_override = _mat(color)
	collar.add_child(band)
	var tag := MeshInstance3D.new()
	tag.mesh = _sphere(0.06)
	tag.material_override = _mat(Color(1.0, 0.82, 0.3))
	tag.position = Vector3(0, 0, -neck[2] - 0.05)  # at the front of the neck
	tag.scale = Vector3(1, 1, 0.5)
	collar.add_child(tag)
	return collar
