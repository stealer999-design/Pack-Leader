class_name FrostFX
extends Node3D
## Frost Arrow's look (after the user's reference): the arrow flies as an icy
## bolt trailing white-blue light, and where it lands ice bursts out: a flash,
## a ring of frosty runes (MarkFX's sigil in ice blue), shards of ice crystal
## shooting outward, frost mist rolling over the ground, snowflakes drifting,
## and "FROSTED!" popping up.

const SPEED := 32.0  ## The arrow's speed (ArcherShotAbility.ARROW_SPEED).
const TRAIL := 3.5
const FADE := 0.25
const ICE := Color(0.55, 0.85, 1.0)
const WHITE := Color(0.92, 0.98, 1.0)
const SHARDS := 16

static var _burst_shader: Shader
static var _shard_mesh: CylinderMesh
static var _puff: ImageTexture

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _length := 1.0
var _radius := 1.8
var _t := 0.0
var _landed := false
var _mesh: ImmediateMesh
var _shards: Array = []  ## [node, direction, length]


static func play(parent: Node3D, from: Vector3, to: Vector3, radius: float) -> void:
	if _burst_shader == null:
		_burst_shader = load("res://scripts/starburst.gdshader")
		_shard_mesh = CylinderMesh.new()  # a long four-sided crystal, pointed at the tip
		_shard_mesh.top_radius = 0.0
		_shard_mesh.bottom_radius = 0.09
		_shard_mesh.height = 1.0
		_shard_mesh.radial_segments = 4
		_shard_mesh.rings = 1
	var fx := FrostFX.new()
	fx._from = from
	fx._to = to
	fx._length = maxf(from.distance_to(to), 0.1)
	fx._radius = radius
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
	if not _landed and _t >= flight:
		_landed = true
		_impact()
	_draw_trail()
	for s in _shards:  # the crystals shoot out, slowing, and melt away
		var node: MeshInstance3D = s[0]
		var age := _t - flight
		var out := 1.0 - pow(1.0 - clampf(age / 0.3, 0.0, 1.0), 3.0)
		var dir: Vector3 = s[1]
		var len: float = s[2]
		var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI / 2.0)
		node.global_transform = Transform3D(basis.scaled(Vector3(1.0, len * (0.3 + 0.7 * out), 1.0)), _to + dir * (_radius * 0.55 * out + len * 0.5))
		var mat := node.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.85 * (1.0 - clampf((age - 0.55) / 0.35, 0.0, 1.0))
	if _t > flight + 2.0:
		queue_free()


func _draw_trail() -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dir := (_to - _from) / _length
	var head := minf(_t * SPEED, _length)
	var tail := clampf(_t * SPEED - TRAIL, 0.0, _length)
	var fade := 1.0 - clampf((_t - _length / SPEED) / FADE, 0.0, 1.0)
	if head - tail < 0.02 or fade <= 0.0:
		return
	for layer in [[0.7, Color(ICE, 0.5 * fade)], [0.24, Color(WHITE, 0.95 * fade)]]:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in 11:
			var u := float(i) / 10.0
			var p := _from + dir * lerpf(tail, head, u)
			var side := dir.cross(cam.global_position - p).normalized()
			# a little shimmer, as if frost crystals glint along it
			var w: float = layer[0] * (0.1 + 0.9 * u) * (0.85 + 0.15 * sin(u * 30.0 + _t * 40.0))
			var col: Color = layer[1]
			col.a *= 0.15 + 0.85 * u
			_mesh.surface_set_color(col)
			_mesh.surface_add_vertex(p + side * w * 0.5)
			_mesh.surface_set_color(col)
			_mesh.surface_add_vertex(p - side * w * 0.5)
		_mesh.surface_end()


func _impact() -> void:
	var at := _to
	# the flash: a white-blue starburst
	var star_mat := ShaderMaterial.new()
	star_mat.shader = _burst_shader
	star_mat.set_shader_parameter("seed", randf() * 100.0)
	star_mat.set_shader_parameter("hot", Color(1.0, 1.0, 1.0))
	star_mat.set_shader_parameter("warm", ICE)
	var star := _quad(star_mat)
	add_child(star)
	star.global_position = at + Vector3.UP * 0.4
	star.scale = Vector3.ONE * 0.3
	var st := star.create_tween().set_parallel()
	st.tween_property(star, "scale", Vector3.ONE * _radius * 1.6, 0.1).set_ease(Tween.EASE_OUT)
	st.tween_method(func(v: float) -> void: star_mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.35).set_delay(0.08)
	# the frost runes: MarkFX's sigil in ice blue, flaring behind the strike
	var rune_mat := MarkFX._material(0, Color(0.45, 0.8, 1.0), Color(0.93, 0.98, 1.0))
	var rune := _quad(rune_mat)
	add_child(rune)
	rune.global_position = at + Vector3.UP * 0.9
	rune.scale = Vector3.ONE * 0.5
	var rt := rune.create_tween().set_parallel()
	rt.tween_property(rune, "scale", Vector3.ONE * _radius * 1.3, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rt.tween_method(func(v: float) -> void: rune_mat.set_shader_parameter("spin", v), 0.0, -1.2, 1.0)
	rt.tween_method(func(v: float) -> void: rune_mat.set_shader_parameter("fade", v), 0.75, 0.0, 0.35).set_delay(0.5)
	# the ice crystals, bursting out mostly upward and away
	for k in SHARDS:
		var a := TAU * k / SHARDS + randf_range(-0.15, 0.15)
		var up := randf_range(0.15, 1.0)
		var dir := Vector3(cos(a), up, sin(a)).normalized()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(WHITE.lerp(ICE, randf() * 0.7), 0.85)
		var shard := MeshInstance3D.new()
		shard.mesh = _shard_mesh
		shard.material_override = mat
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shard)
		shard.top_level = true
		_shards.append([shard, dir, randf_range(0.5, 1.1)])
	# frost mist rolling out over the ground, and snowflakes
	_mist(self, at + Vector3.UP * 0.2, 14, 1.1, Color(0.92, 0.97, 1.0, 0.7), 1.8, 1.3)
	add_child(_particles(at + Vector3.UP * 0.6, 40, 1.6, Vector2(0.07, 0.07), Color(1.0, 1.0, 1.0, 0.95), 1.0, 3.5, -1.2, 70.0, false))
	# the call-out
	var label := Label3D.new()
	label.text = "FROSTED!"
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.008
	label.modulate = Color(0.7, 0.92, 1.0)
	label.outline_modulate = Color(0.02, 0.1, 0.25, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	add_child(label)
	label.global_position = at + Vector3.UP * 2.3
	label.scale = Vector3.ONE * 0.6
	var lt := label.create_tween()
	lt.tween_property(label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_interval(0.6)
	lt.set_parallel()
	lt.tween_property(label, "position:y", label.position.y + 0.6, 0.5)
	lt.tween_property(label, "modulate:a", 0.0, 0.5)
	lt.tween_property(label, "outline_modulate:a", 0.0, 0.5)


static func _quad(mat: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## A one-shot puff of particles: `soft` ones are mist (round, growing, fading).
static func _particles(at: Vector3, amount: int, life: float, size: Vector2, color: Color, v_min: float, v_max: float,
		gravity: float, spread: float, soft: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh: PrimitiveMesh
	var dot := QuadMesh.new()
	dot.size = size
	mesh = dot
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if soft:  # a soft round puff: white in the middle, fading to nothing at the edge
		if _puff == null:  # made once (a fresh one is blank for its first frame)
			var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
			for y in 64:
				for x in 64:
					var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
					img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.5))
			_puff = ImageTexture.create_from_image(img)
		mat.albedo_texture = _puff
	mesh.material = mat
	p.mesh = mesh
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = life
	p.direction = Vector3.UP if not soft else Vector3(1, 0.05, 0)
	p.spread = spread if not soft else 180.0
	p.flatness = 0.0 if not soft else 0.9
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.gravity = Vector3(0, gravity, 0)
	if soft:
		var grow := Curve.new()
		grow.add_point(Vector2(0, 0.5))
		grow.add_point(Vector2(1, 1.8))
		p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.top_level = true
	p.position = at
	p.emitting = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # (mist would throw dark blots on the ground)
	return p


## Frost mist: `count` soft white puffs rolling out over the ground from `at`,
## swelling and fading over `life` seconds (tweened quads: the particle
## system drew such puffs black for their first moments).
static func _mist(parent: Node3D, at: Vector3, count: int, size: float, color: Color, reach: float, life: float) -> void:
	puff_texture()
	for k in count:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = _puff
		mat.albedo_color = color
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * size
		var puff := MeshInstance3D.new()
		puff.mesh = quad
		puff.material_override = mat
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(puff)
		puff.top_level = true
		var a := TAU * k / count + randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0.0, sin(a)) * reach * randf_range(0.6, 1.0)
		puff.global_position = at + Vector3(0, randf_range(0.0, 0.25), 0)
		puff.scale = Vector3.ONE * 0.5
		var tw := puff.create_tween().set_parallel()
		tw.tween_property(puff, "global_position", puff.global_position + out + Vector3.UP * 0.2, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(puff, "scale", Vector3.ONE * randf_range(1.4, 2.0), life).set_ease(Tween.EASE_OUT)
		tw.tween_property(mat, "albedo_color:a", 0.0, life * 0.7).set_delay(life * 0.3)
		tw.chain().tween_callback(puff.queue_free)


## A soft round puff (white, fading to nothing at its edge), made once: for
## mist, dust and smoke.
static func puff_texture() -> ImageTexture:
	if _puff == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.5))
		_puff = ImageTexture.create_from_image(img)
	return _puff
