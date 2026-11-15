class_name PersonModel
extends Node3D
## The tamer: a little person built from simple meshes, holding a bat. Faces -Z.
##
## Animates itself on every peer: it walks (legs and arms swing) at the pace it
## is actually moving, measured from its own position, so remote players animate
## too without any extra syncing. swing() plays the bat swing.

const SKIN := Color(0.96, 0.78, 0.62)
const HIP_HEIGHT := 0.82
const SHOULDER_HEIGHT := 1.42
const PANTS := Color(0.22, 0.25, 0.35)  ## Trousers when no pants are worn.
const REST_ARM := 0.2  ## The bat arm at rest: the upper arm a little forward...
const REST_ELBOW := 0.9  ## ...and the elbow bent, so the bat is held out in front, pointing down.

## The shirt. Its material is the player's own, so hit flashes and slows tint it.
var shirt: MeshInstance3D

var _hips: Array[Node3D] = []  ## Left, right leg pivots.
var _knees: Array[Node3D] = []
var _shoulders: Array[Node3D] = []  ## Left, right arm pivots.
var _elbows: Array[Node3D] = []
var _time := 0.0
var _bat_arm: Node3D
var _body: Node3D  ## Everything above the legs; bobs while walking.
var _last_position := Vector3.INF
var _speed := 0.0
var _walk_phase := 0.0
var _last_step := 0  ## Footsteps: which foot-down of the walk cycle sounded last.
var _swinging := false
var _throwing := false  ## The free arm is busy throwing a treat (see throw).
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
## pants, hat and boots: 1-5, see ItemDB.look_level (ItemDB.OUTFIT_COLORS for their colours).
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
	return ItemDB.OUTFIT_COLORS[type][level - 1] if level > 0 else Color(0, 0, 0, 0)


## A hat per level: straw hat, leather cap, wool hat with a bobble, iron helm,
## ranger's hat.
func _set_hat(level: int) -> void:
	if _hat:
		_hat.queue_free()
		_hat = null
	if level <= 0:
		return
	_hat = _pivot(_head, Vector3.ZERO)
	var mat := _mat(ItemDB.OUTFIT_COLORS.hat[level - 1])
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
	ModelLook.apply(_hat, 0.03)


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
		# Thigh from the hip, then a knee joint and the shin and shoe below it.
		var hip := _pivot(self, Vector3(x, HIP_HEIGHT, 0))
		_part(hip, _box(Vector3(0.2, 0.44, 0.22)), pants, Vector3(0, -0.21, 0))
		var knee := _pivot(hip, Vector3(0, -0.42, 0))
		_part(knee, _sphere(0.1), pants, Vector3.ZERO)
		_part(knee, _box(Vector3(0.18, 0.38, 0.2)), pants, Vector3(0, -0.19, 0))
		_part(knee, _box(Vector3(0.21, 0.11, 0.31)), shoe, Vector3(0, -0.36, -0.05))
		# Boots, shown when worn: a taller boot over the shoe and shin.
		var boot := _pivot(knee, Vector3.ZERO)
		boot.visible = false
		_part(boot, _box(Vector3(0.23, 0.26, 0.24)), _boots_mat, Vector3(0, -0.2, 0))
		_part(boot, _box(Vector3(0.24, 0.13, 0.35)), _boots_mat, Vector3(0, -0.34, -0.05))
		_boots.append(boot)
		_hips.append(hip)
		_knees.append(knee)
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
	_build_face(hair_color)
	# Arms: an upper arm in the shirt colour (a jacket sleeve over it when worn),
	# then an elbow joint, a bare forearm and a hand.
	for x in [-0.36, 0.36]:
		var shoulder := _pivot(_body, Vector3(x, SHOULDER_HEIGHT, 0))
		_part(shoulder, _sphere(0.1), body_material, Vector3.ZERO)
		_part(shoulder, _box(Vector3(0.15, 0.32, 0.17)), body_material, Vector3(0, -0.15, 0))
		var sleeve := _part(shoulder, _box(Vector3(0.18, 0.28, 0.2)), _jacket_mat, Vector3(0, -0.13, 0))
		sleeve.visible = false
		_sleeves.append(sleeve)
		var elbow := _pivot(shoulder, Vector3(0, -0.31, 0))
		_part(elbow, _sphere(0.07), skin, Vector3.ZERO)
		_part(elbow, _box(Vector3(0.12, 0.25, 0.14)), skin, Vector3(0, -0.13, 0))
		_part(elbow, _box(Vector3(0.13, 0.11, 0.15)), skin, Vector3(0, -0.3, 0))  # hand
		_shoulders.append(shoulder)
		_elbows.append(elbow)
	# The bat, gripped in the right hand.
	_bat_arm = _shoulders[1]
	var bat := _pivot(_elbows[1], Vector3(0, -0.3, 0))
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
	ModelLook.apply(self, 0.03)


## The anime face: sharp eyes with a glint, angled brows and a small mouth,
## under a cap of hair.
func _build_face(hair_color: Color) -> void:
	var hair := _mat(hair_color)
	# A natural face: small dark eyes, brows in the hair colour, a nose and a mouth.
	var eye := _mat(Color(0.12, 0.08, 0.06))
	eye.roughness = 0.15
	eye.set_meta("smooth", true)
	var brow := _mat(hair_color.darkened(0.2))
	var lips := _mat(Color(0.62, 0.38, 0.32))
	for side in [-1.0, 1.0]:
		var x: float = side * 0.085
		_part(_body, _sphere(0.026), eye, Vector3(x, 1.8, -0.25), Vector3.ZERO, Vector3(1.0, 0.8, 0.6))
		_part(_body, _box(Vector3(0.075, 0.016, 0.025)), brow, Vector3(x, 1.845, -0.253), Vector3(0, 0, side * 6))
	_part(_body, _box(Vector3(0.035, 0.06, 0.04)), _mat(SKIN.darkened(0.06)), Vector3(0, 1.74, -0.265))  # nose
	_part(_body, _box(Vector3(0.06, 0.012, 0.02)), lips, Vector3(0, 1.675, -0.258))  # mouth
	_part(_body, _sphere(0.29), hair, Vector3(0, 1.86, 0.05), Vector3(1, 0.75, 1))  # hair


func _process(delta: float) -> void:
	# Walking pace from how far we actually moved (works for remote players too).
	var pos := global_position
	if _last_position != Vector3.INF and delta > 0.0:
		var moved := Vector2(pos.x - _last_position.x, pos.z - _last_position.z).length() / delta
		_speed = lerpf(_speed, moved, 1.0 - exp(-10.0 * delta))
	_last_position = pos
	_time += delta
	var stride := clampf(_speed / 7.0, 0.0, 1.0)
	if stride > 0.03:
		_walk_phase += delta * (5.0 + _speed * 0.75)
	var p := _walk_phase
	# A footstep each time a foot comes down (the body's lowest point).
	var step := floori((p - PI * 0.5) / PI)
	if step != _last_step:
		_last_step = step
		if stride > 0.2:
			SoundFX.play(self, "step", global_position, 0.12)
	var blend := 1.0 - exp(-14.0 * delta)
	# Legs: the thigh swings from the hip; the knee bends most as the leg
	# swings through and stays a little soft when the foot is planted.
	for i in 2:
		var phase := p + PI * i
		var forward := cos(phase)  # > 0 while this leg swings forward
		_hips[i].rotation.x = lerpf(_hips[i].rotation.x, sin(phase) * 0.5 * stride, blend)
		var bend := -(0.08 + 0.75 * maxf(forward, 0.0)) * stride
		_knees[i].rotation.x = lerpf(_knees[i].rotation.x, bend, blend)
	# Body: dips as each foot lands, twists against the legs, leans into the
	# run; standing still it breathes and shifts its weight.
	var bob := (cos(2.0 * p) * 0.5 - 0.5) * 0.06 * stride
	var breathe := sin(_time * 2.0) * 0.012 * (1.0 - stride)
	_body.position.y = lerpf(_body.position.y, bob + breathe, blend)
	if not _swinging:
		_body.rotation.y = lerpf(_body.rotation.y, sin(p) * 0.14 * stride, blend)
	_body.rotation.x = lerpf(_body.rotation.x, -0.1 * stride, blend)
	_body.rotation.z = lerpf(_body.rotation.z, sin(_time * 0.9) * 0.02 * (1.0 - stride), blend)
	# Arms swing against the legs with the elbows bent; the bat arm keeps its grip.
	var free_arm := -sin(p) * 0.55 * stride
	if not _throwing:
		_shoulders[0].rotation.x = lerpf(_shoulders[0].rotation.x, free_arm + 0.05, blend)
		_shoulders[0].rotation.z = lerpf(_shoulders[0].rotation.z, -0.08, blend)
	_elbows[0].rotation.x = lerpf(_elbows[0].rotation.x, 0.3 + (0.35 + 0.4 * maxf(free_arm, 0.0)) * stride, blend)
	if not _swinging:
		_bat_arm.rotation = _bat_arm.rotation.lerp(Vector3(REST_ARM - free_arm * 0.35, 0.0, 0.1), blend)
		_elbows[1].rotation = _elbows[1].rotation.lerp(Vector3(REST_ELBOW, 0.0, 0.0), blend)
	if stride <= 0.03:
		_walk_phase = lerpf(_walk_phase, roundf(_walk_phase / PI) * PI, blend)  # settle with both feet down


## The bat swing, like a batter: wind up with the bat cocked back over the
## right shoulder and the body turned away, step into it and whip the body
## round so the bat sweeps flat across the front, follow through to the left
## with the arm extending, then recover to the grip.
func swing(duration := 0.32) -> void:
	_swinging = true
	var tween := create_tween()
	_pose(tween, duration * 0.3, Vector3(2.5, -0.5, 0.3), 1.3, 0.55, Vector3(0.2, 0, -0.25), Tween.EASE_OUT)  # wind up
	_pose(tween, duration * 0.18, Vector3(1.45, 0.35, 0.15), 0.25, -0.45, Vector3(1.0, 0, -0.1), Tween.EASE_IN)  # strike
	_pose(tween, duration * 0.2, Vector3(1.1, 1.3, 0.1), 0.5, -0.75, Vector3(0.6, 0, 0.0), Tween.EASE_OUT)  # follow through
	_pose(tween, duration * 0.32, Vector3(REST_ARM, 0.0, 0.1), REST_ELBOW, 0.0, Vector3(0.05, 0, -0.08), Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: _swinging = false)


## An underarm toss with the free hand (a capture treat): the arm swings
## back, then forward and up to let go, then settles.
func throw(duration := 0.4) -> void:
	_throwing = true
	var tween := create_tween()
	tween.tween_property(_shoulders[0], "rotation", Vector3(-0.9, 0.0, -0.15), duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_body, "rotation:y", -0.25, duration * 0.35)
	tween.tween_property(_shoulders[0], "rotation", Vector3(1.9, 0.0, -0.1), duration * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_body, "rotation:y", 0.2, duration * 0.25)
	tween.tween_property(_shoulders[0], "rotation", Vector3(0.05, 0.0, -0.08), duration * 0.4).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_body, "rotation:y", 0.0, duration * 0.4)
	tween.tween_callback(func() -> void: _throwing = false)


## One step of the swing: bat arm (shoulder rotation, elbow bend), body turn,
## and the free arm, all moving together.
func _pose(tween: Tween, time: float, shoulder: Vector3, elbow: float, turn: float, free_arm: Vector3,
		ease: Tween.EaseType) -> void:
	tween.tween_property(_bat_arm, "rotation", shoulder, time).set_trans(Tween.TRANS_QUAD).set_ease(ease)
	tween.parallel().tween_property(_elbows[1], "rotation:x", elbow, time).set_trans(Tween.TRANS_QUAD).set_ease(ease)
	tween.parallel().tween_property(_body, "rotation:y", turn, time).set_trans(Tween.TRANS_QUAD).set_ease(ease)
	tween.parallel().tween_property(_shoulders[0], "rotation", free_arm, time).set_trans(Tween.TRANS_QUAD).set_ease(ease)


func _rest_bat() -> void:
	_bat_arm.rotation = Vector3(REST_ARM, 0.0, 0.1)
	_elbows[1].rotation = Vector3(REST_ELBOW, 0.0, 0.0)


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
