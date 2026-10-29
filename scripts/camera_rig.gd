@tool
extends Node3D
## Isometric camera rig. Yaw/pitch are applied to this node; the Camera3D child
## sits back along local +Z, so it always looks at the rig's origin.
##
## The mouse wheel zooms (the orthographic camera's size; not while the mouse
## is over a menu), smoothly, between
## MIN_ZOOM and MAX_ZOOM. The zoom is kept between levels and saved in
## user://settings.cfg, so it's remembered next time too.

const MIN_ZOOM := 10.0  ## Closest: the camera shows this many units.
const MAX_ZOOM := 40.0  ## Furthest.
const ZOOM_STEP := 1.12  ## Per wheel notch.
const SETTINGS_PATH := "user://settings.cfg"

@export var target: Node3D
@export var follow_speed := 8.0
@export var zoom_speed := 10.0

## The zoom being eased towards. -1 = not loaded yet.
static var _zoom := -1.0
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
	if Engine.is_editor_hint():
		return
	if target:
		global_position = target.global_position
	if _zoom < 0.0:
		var settings := ConfigFile.new()
		settings.load(SETTINGS_PATH)
		_zoom = clampf(settings.get_value("camera", "zoom", camera().size), MIN_ZOOM, MAX_ZOOM)
	camera().size = _zoom


func camera() -> Camera3D:
	return $Camera3D


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not (event is InputEventMouseButton and event.pressed):
		return
	if get_viewport().gui_get_hovered_control() != null:
		return  # the wheel is for the menu or panel under the mouse
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		set_zoom(_zoom / ZOOM_STEP)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		set_zoom(_zoom * ZOOM_STEP)
	else:
		return
	get_viewport().set_input_as_handled()


func set_zoom(zoom: float) -> void:
	_zoom = clampf(zoom, MIN_ZOOM, MAX_ZOOM)
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("camera", "zoom", _zoom)
	settings.save(SETTINGS_PATH)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var cam := camera()
	if not is_equal_approx(cam.size, _zoom):
		cam.size = lerpf(cam.size, _zoom, 1.0 - exp(-zoom_speed * delta))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(target):
		return
	global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))


func _apply_angles() -> void:
	rotation_degrees = Vector3(pitch_degrees, yaw_degrees, 0.0)
