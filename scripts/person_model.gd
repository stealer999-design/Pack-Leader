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


func build(body_material: StandardMaterial3D, hair_color: Color) -> void:
	var pants := _mat(Color(0.22, 0.25, 0.35))
	var shoe := _mat(Color(0.18, 0.13, 0.1))
	var skin := _mat(SKIN)
	var hair := _mat(hair_color)
	for x in [-0.14, 0.14]:
		var hip := _pivot(self, Vector3(x, HIP_HEIGHT, 0))
		_part(hip, _box(Vector3(0.2, 0.7, 0.22)), pants, Vector3(0, -0.38, 0))
		_part(hip, _box(Vector3(0.22, 0.12, 0.32)), shoe, Vector3(0, -0.74, -0.05))
		_hips.append(hip)
	_body = _pivot(self, Vector3.ZERO)
	shirt = _part(_body, _box(Vector3(0.56, 0.66, 0.32)), body_material, Vector3(0, 1.12, 0))
	_part(_body, _box(Vector3(0.58, 0.1, 0.34)), _mat(Color(0.3, 0.2, 0.12)), Vector3(0, 0.82, 0))  # belt
	# Head.
	_part(_body, _box(Vector3(0.14, 0.1, 0.14)), skin, Vector3(0, 1.5, 0))  # neck
	_part(_body, _sphere(0.27), skin, Vector3(0, 1.78, 0))
	_part(_body, _sphere(0.29), hair, Vector3(0, 1.86, 0.05), Vector3(1, 0.75, 1))
	for x in [-0.1, 0.1]:
		_part(_body, _sphere(0.045), _mat(Color(0.1, 0.1, 0.12)), Vector3(x, 1.8, -0.25))
	_part(_body, _box(Vector3(0.1, 0.03, 0.03)), _mat(Color(0.75, 0.35, 0.35)), Vector3(0, 1.68, -0.26))  # smile
	# Arms: sleeve in the shirt colour, then a hand.
	for x in [-0.36, 0.36]:
		var shoulder := _pivot(_body, Vector3(x, SHOULDER_HEIGHT, 0))
		_part(shoulder, _box(Vector3(0.16, 0.36, 0.18)), body_material, Vector3(0, -0.17, 0))
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
