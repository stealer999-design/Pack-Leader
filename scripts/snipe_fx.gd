class_name SnipeFX
extends Node3D
## Snipe's look (after the user's reference): a glint flashes at the bow, a
## golden tracer races to the target laying a beam of light behind it, and
## the target is struck with a blinding golden flare (a starburst with a wide
## lens-flare streak across it), sparks and "CRITICAL SNIPE!".

const SPEED := 32.0  ## The arrow's speed (ArcherShotAbility.ARROW_SPEED).
const HOLD := 0.12
const FADE := 0.3
const GOLD := Color(1.0, 0.68, 0.18)
const PALE := Color(1.0, 0.96, 0.78)

static var _burst_shader: Shader

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _length := 1.0
var _t := 0.0
var _hit := false
var _mesh: ImmediateMesh


static func play(parent: Node3D, from: Vector3, to: Vector3) -> void:
	if _burst_shader == null:
		_burst_shader = load("res://scripts/starburst.gdshader")
	var fx := SnipeFX.new()
	fx._from = from
	fx._to = to
	fx._length = maxf(from.distance_to(to), 0.1)
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
	fx._flare(from, 0.9, 1.0, 0.18)  # the glint at the bow


func _process(delta: float) -> void:
	_t += delta
	var flight := _length / SPEED
	if not _hit and _t >= flight:
		_hit = true
		_impact()
	_draw_beam(flight)
	if _t > flight + 1.6:
		queue_free()


## The beam: laid down behind the tracer all the way from the bow, held a
## moment once it strikes, then thinning and fading away.
func _draw_beam(flight: float) -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var head := minf(_t * SPEED, _length)
	var after := clampf((_t - flight - HOLD) / FADE, 0.0, 1.0)
	if after >= 1.0 or head < 0.02:
		return
	var dir := (_to - _from) / _length
	var thin := 1.0 - 0.7 * after
	for layer in [[0.55, Color(GOLD, 0.45)], [0.16, Color(PALE, 0.95)]]:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in 9:
			var u := float(i) / 8.0
			var p := _from + dir * head * u
			var side := dir.cross(cam.global_position - p).normalized()
			var w: float = layer[0] * thin * (0.35 + 0.65 * u)  # widening towards the tracer's head
			var col: Color = layer[1]
			col.a *= (1.0 - after) * (0.4 + 0.6 * u)
			_mesh.surface_set_color(col)
			_mesh.surface_add_vertex(p + side * w * 0.5)
			_mesh.surface_set_color(col)
			_mesh.surface_add_vertex(p - side * w * 0.5)
		_mesh.surface_end()


func _impact() -> void:
	_flare(_to, 3.2, 1.0, 0.45)  # the blinding star
	_flare(_to, 8.5, 0.14, 0.55)  # its lens-flare streak, stretched wide across the screen
	var sparks := CPUParticles3D.new()
	var dot := QuadMesh.new()
	dot.size = Vector2(0.09, 0.09)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.vertex_color_use_as_albedo = true
	dot.material = smat
	sparks.mesh = dot
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.amount = 36
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.lifetime = 0.55
	sparks.direction = (_to - _from).normalized() + Vector3.UP * 0.3
	sparks.spread = 75.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 8.0
	sparks.gravity = Vector3(0, -6, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.97, 0.8, 1.0))
	ramp.set_color(1, Color(1.0, 0.55, 0.1, 0.0))
	sparks.color_ramp = ramp
	add_child(sparks)
	sparks.top_level = true
	sparks.global_position = _to
	sparks.emitting = true
	var label := Label3D.new()
	label.text = "CRITICAL SNIPE!"
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.008
	label.modulate = Color(1.0, 0.82, 0.35)
	label.outline_modulate = Color(0.25, 0.1, 0.0, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	add_child(label)
	label.top_level = true
	label.global_position = _to + Vector3.UP * 1.9
	label.scale = Vector3.ONE * 0.6
	var lt := label.create_tween()
	lt.tween_property(label, "scale", Vector3.ONE * 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_interval(0.6)
	lt.set_parallel()
	lt.tween_property(label, "position:y", label.position.y + 0.6, 0.5)
	lt.tween_property(label, "modulate:a", 0.0, 0.5)
	lt.tween_property(label, "outline_modulate:a", 0.0, 0.5)


## A golden starburst at `at`, `width` x `height` (times `width`) across, gone in `life` seconds.
func _flare(at: Vector3, width: float, height: float, life: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _burst_shader
	mat.set_shader_parameter("seed", randf() * 100.0)
	mat.set_shader_parameter("hot", PALE)
	mat.set_shader_parameter("warm", GOLD)
	var star := MarkFX._quad(mat)
	add_child(star)
	star.top_level = true
	star.global_position = at
	star.scale = Vector3(width * 0.2, width * height * 0.2, 1)
	var tw := star.create_tween().set_parallel()
	tw.tween_property(star, "scale", Vector3(width, width * height, 1), 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, life).set_delay(0.06)
	tw.chain().tween_callback(star.queue_free)
