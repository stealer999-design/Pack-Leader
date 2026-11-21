class_name StormFX
extends Node3D
## Thunderstorm's look: a dark storm cloud wheels over the spot for the
## storm's length, flickering with lightning inside, while electricity
## crackles across the ground beneath it (jagged forks re-struck many times a
## second) and the air flickers blue. The bolts themselves strike down from
## the cloud one by one (sky_point, drawn by LightningFX).
## With `burst` (Lightning Bolt's impact) there's no cloud: forks of
## electricity race outwards along the ground from the middle and die away.

const CLOUD_HEIGHT := 3.8
const CLOUD_SHADER := preload("res://scripts/storm_cloud.gdshader")
const RESTRIKE := 0.07
const FADE := 0.5

var _radius := 4.0
var _duration := 3.0
var _t := 0.0
var _next := 0.0
var _cloud_mat: ShaderMaterial
var _ground := ImmediateMesh.new()
var _light: OmniLight3D
var _burst := false
var _ice := false  ## Hailstorm: a pale frosty vortex, no lightning


## Where a bolt from the storm at `center` starts: in the cloud, near its middle.
static func sky_point(center: Vector3) -> Vector3:
	return center + Vector3(randf_range(-0.8, 0.8), CLOUD_HEIGHT - 0.2, randf_range(-0.8, 0.8))


static func play(parent: Node, center: Vector3, radius: float, duration: float, burst := false, ice := false) -> void:
	LightningFX.ensure_materials()
	var fx := StormFX.new()
	fx._burst = burst
	fx._ice = ice
	fx._radius = radius
	fx._duration = duration
	parent.add_child(fx)
	fx.global_position = Vector3(center.x, 0.0, center.z)
	fx._build()


func _build() -> void:
	if not _burst:
		_build_cloud()
	var ground := MeshInstance3D.new()
	ground.mesh = _ground
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.75, 1.0)
	_light.omni_range = _radius * 1.8
	_light.shadow_enabled = false
	_light.position.y = 1.5
	add_child(_light)
	_update()


func _build_cloud() -> void:
	var cloud := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * _radius * 1.7
	cloud.mesh = plane
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = CLOUD_SHADER
	_cloud_mat.set_shader_parameter("seed", randf() * 40.0)
	_cloud_mat.set_shader_parameter("ice", 1.0 if _ice else 0.0)
	cloud.material_override = _cloud_mat
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud.position.y = CLOUD_HEIGHT
	add_child(cloud)


func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration + FADE:
		queue_free()
		return
	_update()


func _update() -> void:
	var fade := 1.0 - clampf((_t - _duration) / FADE, 0.0, 1.0)
	var flicker := randf() if randf() < 0.3 else 0.0
	if _burst:
		_light.light_energy = 3.0 * fade
	else:
		fade = minf(clampf(_t / 0.35, 0.0, 1.0), fade)
		_cloud_mat.set_shader_parameter("fade", fade)
		_cloud_mat.set_shader_parameter("flash", 0.0 if _ice else flicker)
		_light.light_energy = (0.6 + flicker * 1.6) * fade
	if _t >= _next and not _ice:
		_next = _t + RESTRIKE
		_crackle(fade)


## Fresh forks of electricity skittering over the ground.
func _crackle(fade: float) -> void:
	_ground.clear_surfaces()
	if fade <= 0.0:
		return
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else global_position + Vector3(0, 30, 20)
	var paths: Array = []
	for i in randi_range(7, 11):
		var a := global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * _radius * sqrt(randf()) * 0.9
		var b := a + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(0.8, 2.2)
		if _burst:  # racing outwards from the strike
			a = global_position
			b = a + Vector3.FORWARD.rotated(Vector3.UP, TAU * (i + randf()) / 9.0) * _radius * randf_range(0.7, 1.25)
		var pts := LightningFX.jagged(a, b, 0.3)
		for k in pts.size():
			pts[k].y = 0.06  # lying on the floor
		paths.append(pts)
	_ground.surface_begin(Mesh.PRIMITIVE_TRIANGLES, LightningFX._mat)
	for pts in paths:
		LightningFX.strip(_ground, pts, 0.34, Color(0.3, 0.55, 1.0, 0.55 * fade), eye)
	for pts in paths:
		LightningFX.strip(_ground, pts, 0.09, Color(0.92, 0.97, 1.0, fade), eye)
	_ground.surface_end()
