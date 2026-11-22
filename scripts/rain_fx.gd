class_name RainFX
extends Node3D
## Rain of Arrows' look (after the user's reference): the archer looses a
## streak of light straight up, a glowing circle of runes (MarkFX's sigil,
## lying flat, blue-white) opens in the sky over the spot, and a downpour of
## glowing arrows falls from it, each landing with a ripple of light; the
## volley's real arrows fall among them, landing just as they hit.

const HEIGHT := 4.8  ## How high over the ground the circle hangs.
const FALL := 22.0  ## How fast the arrows fall.
const EXTRA := 40  ## Arrows besides the real ones, for the look of the downpour.
const BLUE := Color(0.5, 0.8, 1.0)
const WHITE := Color(0.92, 0.97, 1.0)

static var _streak_mesh: CylinderMesh
static var _ring_shader: Shader

var _from := Vector3.ZERO
var _center := Vector3.ZERO
var _radius := 3.8
var _drops: Array = []  ## [ground point, land time, landed]
var _mm: MultiMesh
var _glow_mm: MultiMesh
var _mesh: ImmediateMesh
var _t := 0.0
var _end := 2.0


## From the bow (`from`) up to a circle over `center`, arrows landing on each
## of `spots` at the matching `times` (seconds from now) and on `EXTRA` more.
static func play(parent: Node3D, from: Vector3, center: Vector3, radius: float, spots: PackedVector3Array, times: PackedFloat32Array) -> void:
	if _streak_mesh == null:
		_streak_mesh = CylinderMesh.new()  # a comet streak, wide at the head
		_streak_mesh.top_radius = 0.06
		_streak_mesh.bottom_radius = 0.0
		_streak_mesh.height = 1.0
		_streak_mesh.radial_segments = 6
		_streak_mesh.rings = 1
		_ring_shader = load("res://scripts/ring_wave.gdshader")
	var fx := RainFX.new()
	fx._from = from
	fx._center = center
	fx._radius = radius
	parent.add_child(fx)
	fx._build(spots, times)


func _build(spots: PackedVector3Array, times: PackedFloat32Array) -> void:
	var first := 10.0
	var last := 0.0
	for i in spots.size():
		_drops.append([spots[i], times[i], false])
		first = minf(first, times[i])
		last = maxf(last, times[i])
	for k in EXTRA:
		var spot := _center + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * _radius * sqrt(randf())
		_drops.append([spot, randf_range(first - 0.05, last + 0.15), false])
	_end = last + 1.2
	for which in 2:  # a bright core and a soft blue glow round each arrow
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _streak_mesh
		mm.instance_count = _drops.size()
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(WHITE, 0.95) if which == 0 else Color(BLUE, 0.5)
		inst.material_override = mat
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		inst.top_level = true
		inst.global_transform = Transform3D.IDENTITY
		if which == 0:
			_mm = mm
		else:
			_glow_mm = mm
	# the streak shot up into the sky
	_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	var lmat := StandardMaterial3D.new()
	lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lmat.vertex_color_use_as_albedo = true
	lmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = lmat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.top_level = true
	mi.global_transform = Transform3D.IDENTITY
	# the circle of runes in the sky, lying flat
	var mat := MarkFX._material(0, BLUE, WHITE)
	mat.set_shader_parameter("lie_flat", true)
	var circle := MarkFX._quad(mat)
	add_child(circle)
	circle.top_level = true
	circle.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(_center.x, _center.y + HEIGHT, _center.z))
	circle.scale = Vector3.ONE * 0.4
	var tw := circle.create_tween().set_parallel()
	tw.tween_property(circle, "scale", Vector3.ONE * _radius * 2.05, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("spin", v), 0.0, 2.0, _end)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 0.0, 1.0, 0.15)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.35).set_delay(last + 0.2)
	# the call-out
	var label := Label3D.new()
	label.text = "RAIN OF ARROWS!"
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.008
	label.modulate = Color(0.75, 0.92, 1.0)
	label.outline_modulate = Color(0.02, 0.08, 0.25, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	add_child(label)
	label.top_level = true
	label.global_position = _center + Vector3.UP * (HEIGHT + 0.8)
	label.scale = Vector3.ONE * 0.6
	var lt := label.create_tween()
	lt.tween_interval(0.12)
	lt.tween_property(label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_interval(0.8)
	lt.set_parallel()
	lt.tween_property(label, "position:y", label.position.y + 0.6, 0.5)
	lt.tween_property(label, "modulate:a", 0.0, 0.5)
	lt.tween_property(label, "outline_modulate:a", 0.0, 0.5)
	label.modulate.a = 0.0
	label.create_tween().tween_property(label, "modulate:a", 1.0, 0.1).set_delay(0.12)
	_update()


func _process(delta: float) -> void:
	_t += delta
	_update()
	if _t > _end:
		queue_free()


func _update() -> void:
	var fall_time := HEIGHT / FALL
	for k in _drops.size():
		var d: Array = _drops[k]
		var spot: Vector3 = d[0]
		var left: float = d[1] - _t  # seconds till it lands
		var tf := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), spot)
		if left > 0.0 and left < fall_time:
			var height := left * FALL
			var length := minf(1.5, HEIGHT - height + 0.01)
			# the cylinder's head (+Y) points down, the way it falls
			tf = Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3(1, length, 1)), spot + Vector3.UP * (height + length * 0.5))
		elif left <= 0.0 and not d[2]:
			d[2] = true
			_splash(spot)
		_mm.set_instance_transform(k, tf)
		_glow_mm.set_instance_transform(k, Transform3D(tf.basis * Basis.IDENTITY.scaled(Vector3(3.0, 1.05, 3.0)), tf.origin))
	# the streak of light shot up from the bow to the circle
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	var up := clampf(_t / 0.15, 0.0, 1.0)
	var fade := 1.0 - clampf((_t - 0.2) / 0.25, 0.0, 1.0)
	if cam and fade > 0.0:
		var sky := Vector3(_center.x, _center.y + HEIGHT, _center.z)
		var tail := _from.lerp(sky, maxf(up - 0.6, 0.0))
		var head := _from.lerp(sky, up)
		for layer in [[0.45, Color(BLUE, 0.5 * fade)], [0.14, Color(WHITE, 0.95 * fade)]]:
			if head.distance_to(tail) < 0.02:
				break
			var along := (head - tail).normalized()
			_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			for i in 6:
				var u := float(i) / 5.0
				var p := tail.lerp(head, u)
				var side := along.cross(cam.global_position - p).normalized()
				var w: float = layer[0] * (0.2 + 0.8 * u)
				_mesh.surface_set_color(layer[1])
				_mesh.surface_add_vertex(p + side * w * 0.5)
				_mesh.surface_set_color(layer[1])
				_mesh.surface_add_vertex(p - side * w * 0.5)
			_mesh.surface_end()


## A little ripple of light where an arrow lands.
func _splash(at: Vector3) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _ring_shader
	mat.set_shader_parameter("width", 0.08)
	mat.set_shader_parameter("glow", BLUE)
	mat.set_shader_parameter("core", WHITE)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 1.4
	var ring := MeshInstance3D.new()
	ring.mesh = plane
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.top_level = true
	ring.global_position = at + Vector3.UP * 0.05
	var tw := ring.create_tween().set_parallel()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.1, 0.95, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	tw.chain().tween_callback(ring.queue_free)
