class_name PrismFX
extends Node3D
## Prism Shot's look (after the user's reference): a tall rainbow crystal
## flashes into being just ahead of the archer; the arrow passes through it
## and comes out split into a rainbow beam to the spot, where it bursts in
## rainbow light: a flash of colours, shards of crystal in every colour
## flying out, glittering dust, and "PRISM SHOT!".

const SPEED := 32.0  ## The arrow's speed (ArcherShotAbility.ARROW_SPEED).
const AHEAD := 1.3  ## How far ahead of the bow the prism stands.
const HOLD := 0.15
const FADE := 0.3
const SHARDS := 22
const BANDS := [Color(1.0, 0.3, 0.35), Color(1.0, 0.7, 0.2), Color(0.95, 1.0, 0.35), Color(0.35, 0.85, 1.0), Color(0.75, 0.45, 1.0)]

static var _prism_shader: Shader
static var _burst_shader: Shader
static var _crystal: ArrayMesh
static var _shard_mesh: CylinderMesh

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _length := 1.0
var _radius := 2.5
var _t := 0.0
var _hit := false
var _mesh: ImmediateMesh
var _prism_mat: ShaderMaterial
var _shards: Array = []  ## [node, direction, length, spin]


static func play(parent: Node3D, from: Vector3, to: Vector3, radius: float) -> void:
	if _prism_shader == null:
		_prism_shader = load("res://scripts/prism.gdshader")
		_burst_shader = load("res://scripts/starburst.gdshader")
		_crystal = _bipyramid(0.32, 0.95, 6)
		_shard_mesh = CylinderMesh.new()
		_shard_mesh.top_radius = 0.0
		_shard_mesh.bottom_radius = 0.08
		_shard_mesh.height = 1.0
		_shard_mesh.radial_segments = 4
		_shard_mesh.rings = 1
	var fx := PrismFX.new()
	fx._from = from
	fx._to = to
	fx._length = maxf(from.distance_to(to), AHEAD + 0.5)
	fx._radius = radius
	parent.add_child(fx)
	fx._build()


## A crystal: `sides` faces round, `r` wide, pointed top and bottom `h` from its middle.
static func _bipyramid(r: float, h: float, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		for tip in [Vector3(0, h, 0), Vector3(0, -h * 0.7, 0)]:
			var n: Vector3 = (p1 - p0).cross(tip - p0).normalized()
			if n.dot((p0 + p1 + tip) / 3.0) < 0.0:
				n = -n
			for v in [p0, p1, tip]:
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()


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
	# the prism, standing just ahead of the bow, turned a little across the shot
	var dir := (_to - _from).normalized()
	_prism_mat = ShaderMaterial.new()
	_prism_mat.shader = _prism_shader
	var prism := MeshInstance3D.new()
	prism.mesh = _crystal
	prism.material_override = _prism_mat
	prism.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(prism)
	prism.top_level = true
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	prism.global_transform = Transform3D(Basis(Vector3.UP, atan2(flat.x, flat.z) + 0.5) * Basis(Vector3.FORWARD, 0.15), _from + dir * AHEAD + Vector3.UP * 0.25)
	prism.scale = Vector3(0.2, 0.05, 0.2)
	var tw := prism.create_tween().set_parallel()
	tw.tween_property(prism, "scale", Vector3.ONE * 1.5, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: _prism_mat.set_shader_parameter("shift", v), 0.0, 1.5, 0.9)
	tw.tween_method(func(v: float) -> void: _prism_mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.35).set_delay(0.55)


func _process(delta: float) -> void:
	_t += delta
	var flight := _from.distance_to(_to) / SPEED
	if not _hit and _t >= flight:
		_hit = true
		_impact()
	_draw_beams(flight)
	for s in _shards:
		var node: MeshInstance3D = s[0]
		var age := _t - flight
		var out := 1.0 - pow(1.0 - clampf(age / 0.35, 0.0, 1.0), 3.0)
		var d: Vector3 = s[1]
		var len: float = s[2]
		var basis := Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI / 2.0) * Basis(Vector3.UP, s[3] * age)
		node.global_transform = Transform3D(basis.scaled(Vector3(1.0, len * (0.3 + 0.7 * out), 1.0)), _to + d * (_radius * 0.7 * out + len * 0.5) + Vector3.DOWN * age * age * 2.0)
		(node.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - clampf((age - 0.5) / 0.4, 0.0, 1.0))
	if _t > flight + 1.6:
		queue_free()


## A white beam from the bow into the prism, and out of it a rainbow: five
## coloured bands side by side, converging on the spot.
func _draw_beams(flight: float) -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var total := _from.distance_to(_to)
	var dir := (_to - _from) / total
	var head := minf(_t * SPEED, total)
	var fade := 1.0 - clampf((_t - flight - HOLD) / FADE, 0.0, 1.0)
	if fade <= 0.0:
		return
	var eye := cam.global_position
	var at_prism := minf(head, AHEAD)
	_strip(_from, _from + dir * at_prism, eye, 0.12, Color(1, 1, 1, 0.9 * fade), 0.0)
	if head > AHEAD:
		var start := _from + dir * AHEAD
		var end := _from + dir * head
		for b in BANDS.size():
			var offset := (b - (BANDS.size() - 1) * 0.5) * 0.09
			var c: Color = BANDS[b]
			_strip(start, end, eye, 0.1, Color(c, 0.85 * fade), offset)


## A camera-facing strip from `a` to `b`, `w` wide, shifted `offset` sideways
## at `a` and back to the middle at the far end (the bands fan out of the prism).
func _strip(a: Vector3, b: Vector3, eye: Vector3, w: float, color: Color, offset: float) -> void:
	var along := (b - a).normalized()
	if (b - a).length() < 0.01:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 6:
		var u := float(i) / 5.0
		var p := a.lerp(b, u)
		var side := along.cross(eye - p).normalized()
		var spread := offset * 4.0 * u * (1.0 - u) * 2.0  # bowing apart in the middle
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(p + side * (spread + w * 0.5))
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(p + side * (spread - w * 0.5))
	_mesh.surface_end()


func _impact() -> void:
	for spec in [[Color(1.0, 0.6, 0.9), 3.4, 0.0], [Color(0.4, 0.9, 1.0), 2.8, 0.6], [Color(1.0, 0.85, 0.3), 2.2, 1.2]]:
		var mat := ShaderMaterial.new()  # a flash of rainbow light: three starbursts in different colours
		mat.shader = _burst_shader
		mat.set_shader_parameter("seed", randf() * 100.0)
		mat.set_shader_parameter("hot", Color(1, 1, 1))
		mat.set_shader_parameter("warm", spec[0])
		var star := MarkFX._quad(mat)
		add_child(star)
		star.top_level = true
		star.global_position = _to
		star.rotation.z = spec[2]
		star.scale = Vector3.ONE * 0.3
		var tw := star.create_tween().set_parallel()
		tw.tween_property(star, "scale", Vector3.ONE * spec[1], 0.1).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.45).set_delay(0.06)
		tw.chain().tween_callback(star.queue_free)
	for k in SHARDS:  # crystal shards of every colour flying out
		var a := TAU * k / SHARDS + randf_range(-0.12, 0.12)
		var d := Vector3(cos(a), randf_range(-0.1, 0.9), sin(a)).normalized()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(Color.from_hsv(float(k) / SHARDS, 0.45, 1.0), 0.9)
		var shard := MeshInstance3D.new()
		shard.mesh = _shard_mesh
		shard.material_override = mat
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shard)
		shard.top_level = true
		_shards.append([shard, d, randf_range(0.45, 0.95), randf_range(-6.0, 6.0)])
	var dust := CPUParticles3D.new()  # glittering dust in every colour
	var dot := QuadMesh.new()
	dot.size = Vector2(0.08, 0.08)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.vertex_color_use_as_albedo = true
	dot.material = smat
	dust.mesh = dot
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.amount = 50
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.lifetime = 1.0
	dust.direction = Vector3.UP
	dust.spread = 90.0
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 5.0
	dust.gravity = Vector3(0, -4, 0)
	var hues := Gradient.new()
	hues.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	hues.colors = PackedColorArray([Color(1, 0.5, 0.6), Color(1, 0.85, 0.4), Color(0.6, 1, 0.6), Color(0.5, 0.85, 1), Color(0.85, 0.6, 1)])
	dust.color_initial_ramp = hues
	add_child(dust)
	dust.top_level = true
	dust.global_position = _to
	dust.emitting = true
	var label := Label3D.new()
	label.text = "PRISM SHOT!"
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.008
	label.modulate = Color(1.0, 0.85, 1.0)
	label.outline_modulate = Color(0.25, 0.05, 0.3, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	add_child(label)
	label.top_level = true
	label.global_position = _to + Vector3.UP * 2.0
	label.scale = Vector3.ONE * 0.6
	var lt := label.create_tween()
	lt.tween_property(label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_interval(0.6)
	lt.set_parallel()
	lt.tween_property(label, "position:y", label.position.y + 0.6, 0.5)
	lt.tween_property(label, "modulate:a", 0.0, 0.5)
	lt.tween_property(label, "outline_modulate:a", 0.0, 0.5)
