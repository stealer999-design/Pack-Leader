class_name PersonModel
extends Node3D
## The tamer: a little person built from simple meshes, holding a bat. Faces -Z.
##
## Animates itself on every peer: it walks (legs and arms swing) at the pace it
## is actually moving, measured from its own position, so remote players animate
## too without any extra syncing. swing() plays the bat swing.

const SKIN := Color(0.96, 0.78, 0.62)
const HIP_HEIGHT := 0.8
const SHOULDER_HEIGHT := 1.42
const PANTS := Color(0.22, 0.25, 0.35)  ## Trousers when no pants are worn.
const REST_ARM := 0.35  ## The bat arm's angle at rest: a little forward, bat pointing ahead and down.

## The shirt. Its material is the player's own, so hit flashes and slows tint it.
var shirt: MeshInstance3D

var _hips: Array[Node3D] = []  ## Left, right leg pivots.
var _shoulders: Array[Node3D] = []  ## Left, right arm pivots.
var _bat_arm: Node3D
var _body: Node3D  ## Everything above the legs; bobs while walking.
var _last_position := Vector3.INF
var _speed := 0.0
var _walk_phase := 0.0
var _swinging := false
var _spikes: Node3D
var _chain: Node3D
var _jacket: Node3D
var _jacket_mat := StandardMaterial3D.new()
var _sleeves: Array[MeshInstance3D] = []
var _pants_mat: StandardMaterial3D
var _boots: Array[Node3D] = []
var _boots_mat := StandardMaterial3D.new()
var _head: Node3D
var _hat: Node3D


## Dresses the tamer: `outfit` holds the level (0 = none) of the worn jacket,
## pants, hat and boots (see ItemDB.KINDS for their colours).
func set_outfit(outfit: PackedInt32Array) -> void:
	if _jacket == null or outfit.size() < 4:
		return
	set_jacket(_color("jacket", outfit[0]))
	var pants := _color("pants", outfit[1])
	_pants_mat.albedo_color = pants if pants.a > 0.0 else PANTS
	_set_hat(outfit[2])
	var boots := _color("boots", outfit[3])
	for boot in _boots:
		boot.visible = boots.a > 0.0
	_boots_mat.albedo_color = boots


## Puts on a jacket in `color` (alpha 0 = no jacket): a coat over the shirt
## with a collar and sleeves down to the elbow.
func set_jacket(color: Color) -> void:
	if _jacket == null:
		return
	_jacket.visible = color.a > 0.0
	for sleeve in _sleeves:
		sleeve.visible = _jacket.visible
	_jacket_mat.albedo_color = color


func _color(type: String, level: int) -> Color:
	return ItemDB.KINDS[type].colors[level - 1] if level > 0 else Color(0, 0, 0, 0)


## A hat per level: straw hat, leather cap, wool hat with a bobble, iron helm,
## ranger's hat.
func _set_hat(level: int) -> void:
	if _hat:
		_hat.queue_free()
		_hat = null
	if level <= 0:
		return
	_hat = _pivot(_head, Vector3.ZERO)
	var mat := _mat(ItemDB.KINDS.hat.colors[level - 1])
	match level:
		1:  # straw hat: a wide flat brim
			_part(_hat, _cylinder(0.46, 0.46, 0.03), mat, Vector3(0, 0.2, 0))
			_part(_hat, _cylinder(0.22, 0.25, 0.18), mat, Vector3(0, 0.3, 0))
			_part(_hat, _cylinder(0.255, 0.255, 0.05), _mat(Color(0.6, 0.25, 0.2)), Vector3(0, 0.24, 0))  # band
		2:  # leather cap with a peak
			_part(_hat, _sphere(0.3), mat, Vector3(0, 0.1, 0.02), Vector3.ZERO, Vector3(1, 0.7, 1))
			_part(_hat, _box(Vector3(0.36, 0.03, 0.22)), mat, Vector3(0, 0.07, -0.3))
		3:  # wool hat with a bobble
			_part(_hat, _sphere(0.31), mat, Vector3(0, 0.12, 0.02), Vector3.ZERO, Vector3(1, 0.85, 1))
			_part(_hat, _cylinder(0.31, 0.31, 0.08), _mat(Color(0.92, 0.9, 0.85)), Vector3(0, 0.02, 0.02))
			_part(_hat, _sphere(0.09), _mat(Color(0.92, 0.9, 0.85)), Vector3(0, 0.4, 0.02))
		4:  # iron helm with a nose guard
			mat.metallic = 0.7
			mat.roughness = 0.35
			_part(_hat, _sphere(0.32), mat, Vector3(0, 0.06, 0.01), Vector3.ZERO, Vector3(1, 0.9, 1))
			_part(_hat, _cylinder(0.33, 0.33, 0.06), mat, Vector3(0, -0.02, 0.01))
			_part(_hat, _box(Vector3(0.05, 0.16, 0.04)), mat, Vector3(0, -0.08, -0.32))
		_:  # ranger's hat: a medium brim, a tall crown and a feather
			_part(_hat, _cylinder(0.4, 0.4, 0.03), mat, Vector3(0, 0.2, 0), Vector3(-6, 0, 0))
			_part(_hat, _cylinder(0.2, 0.25, 0.24), mat, Vector3(0, 0.33, 0))
			_part(_hat, _box(Vector3(0.03, 0.3, 0.07)), _mat(Color(0.85, 0.2, 0.15)), Vector3(0.25, 0.4, 0.05), Vector3(0, 0, -25))


func set_spiked(spiked: bool) -> void:
	if _spikes:
		_spikes.visible = spiked


## Shows the bat for a tier of Player.BATS: plain wood, spiked, or wrapped in chain.
func set_bat_tier(tier: int) -> void:
	set_spiked(tier == 1)
	if _chain:
		_chain.visible = tier >= 2


func build(body_material: StandardMaterial3D, hair_color: Color) -> void:
	var pants := _mat(PANTS)
	_pants_mat = pants
	_boots_mat.roughness = 0.85
	var shoe := _mat(Color(0.18, 0.13, 0.1))
	var skin := _mat(SKIN)
	var hair := _mat(hair_color)
	for x in [-0.14, 0.14]:
		var hip := _pivot(self, Vector3(x, HIP_HEIGHT, 0))
		_part(hip, _box(Vector3(0.2, 0.7, 0.22)), pants, Vector3(0, -0.38, 0))
		_part(hip, _box(Vector3(0.22, 0.12, 0.32)), shoe, Vector3(0, -0.74, -0.05))
		# Boots, shown when worn: a taller boot over the shoe and lower leg.
		var boot := _pivot(hip, Vector3.ZERO)
		boot.visible = false
		_part(boot, _box(Vector3(0.25, 0.32, 0.27)), _boots_mat, Vector3(0, -0.6, 0))
		_part(boot, _box(Vector3(0.25, 0.14, 0.36)), _boots_mat, Vector3(0, -0.73, -0.05))
		_boots.append(boot)
		_hips.append(hip)
	_body = _pivot(self, Vector3.ZERO)
	shirt = _part(_body, _box(Vector3(0.56, 0.66, 0.32)), body_material, Vector3(0, 1.12, 0))
	# A jacket over the shirt, shown when one is worn (open at the front).
	_jacket = _pivot(_body, Vector3.ZERO)
	_jacket.visible = false
	_jacket_mat.roughness = 0.8
	for x in [-0.17, 0.17]:
		_part(_jacket, _box(Vector3(0.25, 0.7, 0.36)), _jacket_mat, Vector3(x, 1.11, 0.0))
	_part(_jacket, _box(Vector3(0.62, 0.12, 0.38)), _jacket_mat, Vector3(0, 1.44, 0.01))  # collar
	_part(_body, _box(Vector3(0.58, 0.1, 0.34)), _mat(Color(0.3, 0.2, 0.12)), Vector3(0, 0.82, 0))  # belt
	# Head.
	_part(_body, _box(Vector3(0.14, 0.1, 0.14)), skin, Vector3(0, 1.5, 0))  # neck
	_part(_body, _sphere(0.27), skin, Vector3(0, 1.78, 0))
	_head = _pivot(_body, Vector3(0, 1.86, 0))  # hats go on here
	_part(_body, _sphere(0.29), hair, Vector3(0, 1.86, 0.05), Vector3(1, 0.75, 1))
	for x in [-0.1, 0.1]:
		_part(_body, _sphere(0.045), _mat(Color(0.1, 0.1, 0.12)), Vector3(x, 1.8, -0.25))
	_part(_body, _box(Vector3(0.1, 0.03, 0.03)), _mat(Color(0.75, 0.35, 0.35)), Vector3(0, 1.68, -0.26))  # smile
	# Arms: sleeve in the shirt colour, then a hand.
	for x in [-0.36, 0.36]:
		var shoulder := _pivot(_body, Vector3(x, SHOULDER_HEIGHT, 0))
		_part(shoulder, _box(Vector3(0.16, 0.36, 0.18)), body_material, Vector3(0, -0.17, 0))
		var sleeve := _part(shoulder, _box(Vector3(0.19, 0.3, 0.21)), _jacket_mat, Vector3(0, -0.14, 0))
		sleeve.visible = false
		_sleeves.append(sleeve)
		_part(shoulder, _box(Vector3(0.13, 0.26, 0.15)), skin, Vector3(0, -0.47, 0))
		_shoulders.append(shoulder)
	# The bat, in the right hand, resting on the shoulder.
	_bat_arm = _shoulders[1]
	# Held like a real grip: angled 45 degrees forward from the arm.
	var bat := _pivot(_bat_arm, Vector3(0, -0.58, 0))
	bat.name = "Bat"
	bat.rotation.x = -PI / 4.0
	var wood := _mat(Color(0.62, 0.4, 0.22))
	_part(bat, _cylinder(0.035, 0.035, 0.3), _mat(Color(0.2, 0.12, 0.08)), Vector3(0, 0.0, 0), Vector3(-90, 0, 0))  # grip
	_part(bat, _cylinder(0.09, 0.045, 0.65), wood, Vector3(0, 0, -0.47), Vector3(-90, 0, 0))
	_part(bat, _sphere(0.09), wood, Vector3(0, 0, -0.8))
	# Spikes, shown once the bat is upgraded: steel cones around the barrel.
	_spikes = _pivot(bat, Vector3.ZERO)
	_spikes.visible = false
	var steel := _mat(Color(0.78, 0.8, 0.84))
	steel.metallic = 0.7
	steel.roughness = 0.35
	for i in 12:
		var along := -0.5 - (i / 4) * 0.13
		var angle := i * TAU / 4.0 + (i / 4) * 0.8
		var out := Vector3(cos(angle), sin(angle), 0.0)
		var spike := _part(_spikes, _cylinder(0.0, 0.05, 0.22), steel, Vector3(0, 0, along) + out * 0.13)
		spike.basis = Basis.looking_at(out, Vector3.FORWARD) * Basis(Vector3.RIGHT, -PI / 2.0)  # tip outwards
	# The Chain Bat: a heavy chain wound three times around the barrel, its
	# links alternating flat and edge-on, with a loose end and a padlock.
	_chain = _pivot(bat, Vector3.ZERO)
	_chain.visible = false
	var iron := _mat(Color(0.66, 0.67, 0.72))
	iron.metallic = 0.8
	iron.roughness = 0.4
	var link := TorusMesh.new()
	link.inner_radius = 0.026
	link.outer_radius = 0.048
	link.rings = 10
	link.ring_segments = 6
	var links := 22
	for i in links:
		var t := float(i) / (links - 1)
		var z := lerpf(-0.28, -0.76, t)
		var barrel := 0.045 + 0.045 * clampf((-z - 0.145) / 0.65, 0.0, 1.0)
		var angle := t * TAU * 3.0
		var out := Vector3(cos(angle), sin(angle), 0.0)
		var part := _part(_chain, link, iron, Vector3(0, 0, z) + out * (barrel + 0.025))
		var along := Vector3(-sin(angle), cos(angle), -0.16).normalized()  # around the barrel
		part.basis = Basis.looking_at(along, out) * Basis(Vector3.FORWARD, PI / 2.0 if i % 2 else 0.0) \
				* Basis(Vector3.RIGHT, PI / 2.0)
	for i in 4:  # the loose end, trailing back along the barrel
		var part := _part(_chain, link, iron, Vector3(0.13, 0.02, -0.25 + i * 0.06))
		part.rotation = Vector3(0, PI / 2.0 if i % 2 else 0.0, PI / 2.0)
	_part(_chain, _box(Vector3(0.07, 0.08, 0.04)), _mat(Color(0.65, 0.55, 0.3)), Vector3(0.13, 0.0, 0.0))  # padlock
	_rest_bat()


func _process(delta: float) -> void:
	# Walking pace from how far we actually moved (works for remote players too).
	var pos := global_position
	if _last_position != Vector3.INF and delta > 0.0:
		var moved := Vector2(pos.x - _last_position.x, pos.z - _last_position.z).length() / delta
		_speed = lerpf(_speed, moved, 1.0 - exp(-12.0 * delta))
	_last_position = pos
	var stride := clampf(_speed / 6.0, 0.0, 1.0)
	_walk_phase += delta * (4.0 + _speed * 1.1) * (1.0 if stride > 0.05 else 0.0)
	var swing := sin(_walk_phase) * 0.75 * stride
	_hips[0].rotation.x = swing
	_hips[1].rotation.x = -swing
	_shoulders[0].rotation.x = -swing * 0.8
	if not _swinging:
		_bat_arm.rotation.x = lerpf(_bat_arm.rotation.x, REST_ARM + swing * 0.3, 1.0 - exp(-15.0 * delta))
	_body.position.y = absf(sin(_walk_phase)) * 0.06 * stride
	if stride <= 0.05:  # settle back to standing
		_walk_phase = 0.0
		for pivot in _hips:
			pivot.rotation.x = lerpf(pivot.rotation.x, 0.0, 1.0 - exp(-12.0 * delta))


## The bat swing: wind up over the right shoulder, sweep it flat across the
## front, follow through to the left, then back to rest.
func swing(duration := 0.28) -> void:
	_swinging = true
	var tween := create_tween()
	tween.tween_property(_bat_arm, "rotation", Vector3(2.4, -0.7, 0.0), duration * 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bat_arm, "rotation", Vector3(0.85, 0.3, 0.0), duration * 0.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_bat_arm, "rotation", Vector3(0.85, 1.4, 0.0), duration * 0.2)
	tween.tween_property(_bat_arm, "rotation", Vector3(REST_ARM, 0.0, 0.0), duration * 0.3)
	tween.tween_callback(func() -> void: _swinging = false)


func _rest_bat() -> void:
	_bat_arm.rotation = Vector3(REST_ARM, 0.0, 0.0)


# --- Mesh helpers -------------------------------------------------------------------

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	return pivot


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO,
		scl := Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	part.rotation_degrees = rot_deg
	part.scale = scl
	parent.add_child(part)
	return part


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _sphere(r: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	return mesh
