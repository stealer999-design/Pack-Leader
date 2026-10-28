@tool
extends Node3D
## Isometric camera rig. Yaw/pitch are applied to this node; the Camera3D child
## sits back along local +Z, so it always looks at the rig's origin.

@export var target: Node3D
@export var follow_speed := 8.0
@export_range(-89.0, 0.0) var pitch_degrees := -35.264:  # true isometric angle
	set(v):
		pitch_degrees = v
		_apply_angles()
@export_range(-180.0, 180.0) var yaw_degrees := 45.0:
	set(v):
		yaw_degrees = v
		_apply_angles()


func _ready() -> void:
	_apply_angles()
	if target and not Engine.is_editor_hint():
		global_position = target.global_position


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(target):
		return
	global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))


func _apply_angles() -> void:
	rotation_degrees = Vector3(pitch_degrees, yaw_degrees, 0.0)
