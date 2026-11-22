class_name SunburstFX
extends Node3D
## Sunburst Arrow's look (after the user's reference): a fiery golden bolt
## flies to the spot and bursts into a blazing sun (a white-hot core and a
## flickering corona), golden arrows of light shoot out from it in every
## direction, a sunlit ring sweeps over the ground, embers rise, and
## "SUNBURST ARROW!" pops up.

const SPEED := 32.0  ## The arrow's speed (ArcherShotAbility.ARROW_SPEED).
const RAYS := 30
const GOLD := Color(1.0, 0.72, 0.2)
const PALE := Color(1.0, 0.96, 0.75)
const ORANGE := Color(1.0, 0.45, 0.08)

static var _sun_shader: Shader
static var _ring_shader: Shader
static var _ray_mesh: CylinderMesh

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _length := 1.0
var _radius := 3.0
var _t := 0.0
var _hit := false
var _mesh: ImmediateMesh
var _rays: Array = []  ## directions
var _mm: MultiMesh
var _glow_mm: MultiMesh


static func play(parent: Node3D, from: Vector3, to: Vector3, radius: float) -> void:
	if _sun_shader == null:
		_sun_shader = load("res://scripts/sun.gdshader")
		_ring_shader = load("res://scripts/ring_wave.gdshader")
		_ray_mesh = CylinderMesh.new()  # a comet streak, wide at the head
		_ray_mesh.top_radius = 0.06
		_ray_mesh.bottom_radius = 0.0
		_ray_mesh.height = 1.0
		_ray_mesh.radial_segments = 6
		_ray_mesh.rings = 1
	var fx := SunburstFX.new()
	fx._from = from
	fx._to = to
	fx._length = maxf(from.distance_to(to), 0.1)
	fx._radius = radius
	parent.add_child(fx)
	fx._build()


func _build() -> void:
	_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.top_level = true
	mi.global_transform = Transform3D.IDENTITY
	for which in 2:  # the rays of light: a bright core and a soft golden glow round each
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _ray_mesh
		mm.instance_count = RAYS
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rmat.albedo_color = Color(PALE, 0.95) if which == 0 else Color(GOLD, 0.45)
		inst.material_override = rmat
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		inst.top_level = true
		inst.global_transform = Transform3D.IDENTITY
		if which == 0:
			_mm = mm
		else:
			_glow_mm = mm
	for k in RAYS:  # spread all round, more out to the sides than up and down
		var a := TAU * k / RAYS + randf_range(-0.08, 0.08)
		var up := randf_range(-0.35, 0.9)
		_rays.append(Vector3(cos(a), up, sin(a)).normalized())
	_update_rays()


func _process(delta: float) -> void:
	_t += delta
	var flight := _length / SPEED
	if not _hit and _t >= flight:
		_hit = true
		_impact()
	_draw_bolt(flight)
	_update_rays()
	if _t > flight + 1.6:
		queue_free()


func _draw_bolt(flight: float) -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	var fade := 1.0 - clampf((_t - flight) / 0.15, 0.0, 1.0)
	if cam == null or fade <= 0.0:
		return
	var dir := (_to - _from) / _length
	var head := minf(_t * SPEED, _length)
	var tail := maxf(head - 3.0, 0.0)
	if head - tail < 0.02:
		return
	for layer in [[0.6, Color(ORANGE, 0.5 * fade)], [0.22, Color(PALE, 0.95 * fade)]]:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in 9:
			var u := float(i) / 8.0
			var p := _from + dir * lerpf(tail, head, u)
			var side := dir.cross(cam.global_position - p).normalized()
			var w: float = layer[0] * (0.1 + 0.9 * u)
			var col: Color = layer[1]
			col.a *= 0.2 + 0.8 * u
			_mesh.surface_set_color(col)
			_mesh.surface_add_vertex(p + side * w * 0.5)
			_mesh.surface_set_color(col)
			_mesh.surface_add_vertex(p - side * w * 0.5)
		_mesh.surface_end()


func _update_rays() -> void:
	var age := _t - _length / SPEED
	for k in RAYS:
		var tf := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), _to)
		if age > 0.0 and age < 0.5:
			var d: Vector3 = _rays[k]
			var out := 1.0 - pow(1.0 - age / 0.5, 2.0)
			var head := _radius * (0.35 + 1.25 * out)
			var length := minf(1.6, head * 0.6) * (1.0 - age / 0.5 * 0.6)
			var basis := Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI / 2.0)
			tf = Transform3D(basis.scaled(Vector3(1, length, 1)), _to + d * (head - length * 0.5))
		_mm.set_instance_transform(k, tf)
		_glow_mm.set_instance_transform(k, Transform3D(tf.basis * Basis.IDENTITY.scaled(Vector3(3.0, 1.05, 3.0)), tf.origin))


func _impact() -> void:
	# the sun
	var mat := ShaderMaterial.new()
	mat.shader = _sun_shader
	mat.set_shader_parameter("seed", randf() * 100.0)
	var sun := MarkFX._quad(mat)
	add_child(sun)
	sun.top_level = true
	sun.global_position = _to + Vector3.UP * 0.4
	sun.scale = Vector3.ONE * 0.3
	var size := _radius * 2.0
	var tw := sun.create_tween()
	tw.tween_property(sun, "scale", Vector3.ONE * size, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sun, "scale", Vector3.ONE * size * 1.08, 0.35)
	tw.set_parallel()
	tw.tween_property(sun, "scale", Vector3.ONE * size * 0.6, 0.35)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.35)
	tw.chain().tween_callback(sun.queue_free)
	# sunlight sweeping over the ground
	var rmat := ShaderMaterial.new()
	rmat.shader = _ring_shader
	rmat.set_shader_parameter("width", 0.05)
	rmat.set_shader_parameter("glow", ORANGE)
	rmat.set_shader_parameter("core", PALE)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * _radius * 2.2
	var ring := MeshInstance3D.new()
	ring.mesh = plane
	ring.material_override = rmat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.top_level = true
	ring.global_position = Vector3(_to.x, _to.y - 0.45, _to.z)
	var rt := ring.create_tween().set_parallel()
	rt.tween_method(func(v: float) -> void: rmat.set_shader_parameter("progress", v), 0.1, 0.95, 0.4).set_ease(Tween.EASE_OUT)
	rt.tween_method(func(v: float) -> void: rmat.set_shader_parameter("fade", v), 1.0, 0.0, 0.5).set_delay(0.3)
	rt.chain().tween_callback(ring.queue_free)
	# embers rising
	var embers := CPUParticles3D.new()
	var dot := QuadMesh.new()
	dot.size = Vector2(0.08, 0.08)
	var emat := StandardMaterial3D.new()
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	emat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	emat.vertex_color_use_as_albedo = true
	dot.material = emat
	embers.mesh = dot
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	embers.amount = 40
	embers.one_shot = true
	embers.explosiveness = 0.8
	embers.lifetime = 1.2
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = _radius * 0.6
	embers.direction = Vector3.UP
	embers.spread = 30.0
	embers.initial_velocity_min = 1.0
	embers.initial_velocity_max = 3.0
	embers.gravity = Vector3(0, 1.0, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
	ramp.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
	embers.color_ramp = ramp
	add_child(embers)
	embers.top_level = true
	embers.global_position = _to
	embers.emitting = true
	# the call-out
	var label := Label3D.new()
	label.text = "SUNBURST ARROW!"
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.008
	label.modulate = Color(1.0, 0.8, 0.3)
	label.outline_modulate = Color(0.3, 0.08, 0.0, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	add_child(label)
	label.top_level = true
	label.global_position = _to + Vector3.UP * (_radius * 0.75 + 1.0)
	label.scale = Vector3.ONE * 0.6
	var lt := label.create_tween()
	lt.tween_property(label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_interval(0.7)
	lt.set_parallel()
	lt.tween_property(label, "position:y", label.position.y + 0.6, 0.5)
	lt.tween_property(label, "modulate:a", 0.0, 0.5)
	lt.tween_property(label, "outline_modulate:a", 0.0, 0.5)
