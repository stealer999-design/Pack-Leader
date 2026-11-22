class_name PierceFX
extends Node3D
## Piercing Shot's look (after the user's reference): the arrow streaks out as
## a blazing white-gold bolt dragging a long fiery trail, a crescent of light
## sweeps over its path, and as it tears through each enemy a spiky starburst
## and a spray of sparks flare there. The ribbons (trail and crescent) are
## rebuilt each frame to face the camera.

const SPEED := 32.0  ## The arrow's speed (ArcherShotAbility.ARROW_SPEED).
const TRAIL := 5.0  ## How far the trail stretches behind the head.
const FADE := 0.3
const CRESCENT_TIME := 0.4
const SWING := 2.2  ## How far the crescent bows out to the side (seen from above it curves, not lies on the shot).

static var _burst_shader: Shader

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _length := 1.0
var _hits: PackedVector3Array
var _done: Array = []
var _t := 0.0
var _mesh: ImmediateMesh
var _rise := 0.9  ## The crescent's height over the path (it also bows out to one side, SWING).


## The bolt from `from` to `to` (at SPEED), bursting at each of `hits` (points on the way).
static func play(parent: Node3D, from: Vector3, to: Vector3, hits: PackedVector3Array) -> void:
	if _burst_shader == null:
		_burst_shader = load("res://scripts/starburst.gdshader")
	var fx := PierceFX.new()
	fx._from = from
	fx._to = to
	fx._length = maxf(from.distance_to(to), 0.1)
	fx._hits = hits
	fx._done.resize(hits.size())
	fx._done.fill(false)
	parent.add_child(fx)
	fx._mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = fx._mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mi)
	mi.top_level = true
	mi.global_transform = Transform3D.IDENTITY


func _process(delta: float) -> void:
	_t += delta
	var flight := _length / SPEED
	for k in _hits.size():
		if not _done[k] and _t * SPEED >= _from.distance_to(_hits[k]):
			_done[k] = true
			_burst(_hits[k])
	_draw()
	if _t > flight + TRAIL / SPEED + FADE + 0.1 and _t > CRESCENT_TIME + 0.2:
		queue_free()


func _draw() -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	var dir := (_to - _from) / _length
	var flight := _length / SPEED
	var head := minf(_t * SPEED, _length)
	var tail := clampf(_t * SPEED - TRAIL, 0.0, _length)
	var after := clampf((_t - flight) / FADE, 0.0, 1.0)  # fading once the head has gone its distance
	if head - tail > 0.02 and after < 1.0:
		var pts: Array[Vector3] = []
		var us: Array[float] = []
		for i in 13:
			var u := float(i) / 12.0
			pts.append(_from + dir * lerpf(tail, head, u))
			us.append(u)
		var fade := 1.0 - after
		# a wide golden glow, then the white-hot core: thick at the head, thinning to nothing behind
		_ribbon(pts, us, eye, 1.0, Color(1.0, 0.6, 0.12, 0.5 * fade))
		_ribbon(pts, us, eye, 0.36, Color(1.0, 0.96, 0.8, 0.95 * fade))
	# the crescent: an arc of light sweeping over the path, drawn out then fading
	var c := clampf(_t / CRESCENT_TIME, 0.0, 1.0)
	var cfade := 1.0 - clampf((_t - CRESCENT_TIME) / 0.2, 0.0, 1.0)
	if cfade > 0.0:
		var side := dir.cross(Vector3.UP).normalized()
		var arc: Array[Vector3] = []
		var aus: Array[float] = []
		var reach := 1.0 - pow(1.0 - c, 2.0)
		for i in 17:
			var s := float(i) / 16.0 * reach
			arc.append(_from + dir * (_length * 0.85 * s) + Vector3.UP * (_rise * sin(PI * s)) + side * (SWING * sin(PI * s)))
			aus.append(1.0 - absf(float(i) / 16.0 - 0.5) * 2.0)  # thickest in the middle of the arc
		_ribbon(arc, aus, eye, 0.4, Color(1.0, 0.72, 0.3, 0.6 * cfade))
		_ribbon(arc, aus, eye, 0.13, Color(1.0, 0.97, 0.85, 0.9 * cfade))


## A camera-facing strip through `pts`, `width` wide where `us` is 1, tapering where it is 0.
func _ribbon(pts: Array[Vector3], us: Array[float], eye: Vector3, width: float, color: Color) -> void:
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var along := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := along.cross(eye - pts[i]).normalized()
		var w := width * (0.08 + 0.92 * us[i])
		var col := Color(color.r, color.g, color.b, color.a * (0.15 + 0.85 * us[i]))
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(pts[i] + side * w * 0.5)
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(pts[i] - side * w * 0.5)
	_mesh.surface_end()


func _burst(at: Vector3) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _burst_shader
	mat.set_shader_parameter("seed", randf() * 100.0)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var star := MeshInstance3D.new()
	star.mesh = quad
	star.material_override = mat
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(star)
	star.global_position = at
	star.scale = Vector3.ONE * 0.3
	var tween := star.create_tween().set_parallel()
	tween.tween_property(star, "scale", Vector3.ONE * 2.6, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(star, "rotation:z", 0.3, 0.4)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.3).set_delay(0.1)
	tween.chain().tween_callback(star.queue_free)
	var sparks := CPUParticles3D.new()
	var dot := QuadMesh.new()
	dot.size = Vector2(0.08, 0.08)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.vertex_color_use_as_albedo = true
	dot.material = smat
	sparks.mesh = dot
	sparks.amount = 30
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.lifetime = 0.5
	sparks.direction = (_to - _from).normalized()
	sparks.spread = 70.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 8.0
	sparks.gravity = Vector3(0, -6, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
	ramp.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	sparks.color_ramp = ramp
	add_child(sparks)
	sparks.global_position = at
	sparks.emitting = true
