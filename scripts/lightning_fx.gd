class_name LightningFX
extends Node3D
## Static Arc's look: crackling lightning along a path of points (the caster,
## then each enemy it jumps to). Each leg is several jagged strands with forks
## splitting off them, re-struck every few hundredths of a second so it
## flickers and writhes, a white-hot core inside a blue glow. Sparks burst
## and the air flashes where it hits, and a glow sits at the caster's end.

const DURATION := 0.42  ## Seconds it crackles before fading.
const FADE := 0.16
const RESTRIKE := 0.045  ## Seconds between re-drawing the bolts (the flicker).
const STRANDS := 3
const GLOW := Color(0.3, 0.55, 1.0, 0.5)
const HAZE := Color(0.45, 0.7, 1.0, 0.18)  ## a wide faint haze round the main strands
const CORE := Color(0.92, 0.97, 1.0, 1.0)

static var _mat: StandardMaterial3D
static var _dot_mat: StandardMaterial3D

var _points: PackedVector3Array
var _mesh := ImmediateMesh.new()
var _t := 0.0
var _next_strike := 0.0
var _alpha := 1.0


## Lightning from points[0] through each following point in turn.
static func play(parent: Node, points: PackedVector3Array) -> void:
	if points.size() < 2:
		return
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.vertex_color_use_as_albedo = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_dot_mat = _make_dot_material()
	var fx := LightningFX.new()
	fx._points = points
	parent.add_child(fx)
	fx._build()


func _build() -> void:
	var bolts := MeshInstance3D.new()
	bolts.mesh = _mesh
	bolts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bolts)
	# the caster's end glows; every struck point flashes and throws sparks
	add_child(_halo(_points[0], 1.4, Color(0.6, 0.82, 1.0, 0.75)))
	for i in range(1, _points.size()):
		add_child(_halo(_points[i], 1.8, Color(0.55, 0.78, 1.0, 0.6)))
		var sparks := _make_sparks()
		add_child(sparks)
		sparks.global_position = _points[i]
		sparks.emitting = true
		var light := OmniLight3D.new()
		light.light_color = Color(0.6, 0.8, 1.0)
		light.light_energy = 2.0
		light.omni_range = 3.5
		light.shadow_enabled = false
		add_child(light)
		light.global_position = _points[i] + Vector3.UP * 0.3
		create_tween().tween_property(light, "light_energy", 0.0, DURATION + FADE)
	_strike()


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION + FADE + 0.5:  # (the sparks land)
		queue_free()
		return
	_alpha = 1.0 - clampf((_t - DURATION) / FADE, 0.0, 1.0)
	for child in get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D and child.mesh is QuadMesh:
			var mat: StandardMaterial3D = child.material_override
			mat.albedo_color.a = child.get_meta("alpha", 1.0) * _alpha
	if _t >= _next_strike and _alpha > 0.0:
		_strike()


## Draws a fresh set of bolts (each call is one flicker).
func _strike() -> void:
	_next_strike = _t + RESTRIKE
	_mesh.clear_surfaces()
	if _alpha <= 0.0:
		return
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else Vector3(0, 30, 20)
	var paths: Array = []
	for i in _points.size() - 1:
		var a := _points[i]
		var b := _points[i + 1]
		if a.distance_to(b) < 0.05:
			continue
		for s in STRANDS:
			var main := _jagged(a, b, 0.22 if s == 0 else 0.34)
			paths.append([main, 1.0 if s == 0 else 0.6])
			# forks splitting off and dying out
			for f in randi_range(1, 3):
				var k := randi_range(1, main.size() - 2)
				var from: Vector3 = main[k]
				var ahead := (b - a).normalized()
				var off := ahead.cross(Vector3.UP).normalized() * randf_range(-1.0, 1.0) + Vector3.UP * randf_range(-0.4, 0.6)
				var reach := a.distance_to(b) * randf_range(0.12, 0.3)
				paths.append([_jagged(from, from + (ahead + off * 0.8).normalized() * reach, 0.3), 0.4])
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	for p in paths:  # haze, then glow, then the white core over it
		if p[1] >= 1.0:
			_strip(p[0], 0.9, Color(HAZE, HAZE.a * _alpha), eye)
	for p in paths:
		_strip(p[0], 0.36 * p[1], Color(GLOW, GLOW.a * _alpha), eye)
	for p in paths:
		_strip(p[0], 0.09 * p[1] + 0.03, Color(CORE, _alpha), eye)
	_mesh.surface_end()


## A jagged line from a to b: the midpoints pushed out sideways, again and again.
func _jagged(a: Vector3, b: Vector3, rough: float) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	var amount := a.distance_to(b) * rough
	for level in 4:
		var finer := PackedVector3Array()
		for i in pts.size() - 1:
			var p := pts[i]
			var q := pts[i + 1]
			var dir := (q - p).normalized()
			var side := dir.cross(Vector3.UP)
			if side.length() < 0.1:
				side = dir.cross(Vector3.RIGHT)
			side = side.normalized()
			var up := side.cross(dir).normalized()
			finer.append(p)
			finer.append((p + q) * 0.5 + side * randf_range(-1.0, 1.0) * amount + up * randf_range(-0.6, 0.6) * amount)
		finer.append(pts[-1])
		pts = finer
		amount *= 0.5
	return pts


## A ribbon along `pts`, `width` wide, turned to face the camera at `eye`.
func _strip(pts: PackedVector3Array, width: float, color: Color, eye: Vector3) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var along := b - a
		var side_a := along.cross(eye - a).normalized() * width * 0.5
		var side_b := along.cross(eye - b).normalized() * width * 0.5
		var taper := 1.0 - float(i) / pts.size() * 0.3
		for v in [a - side_a * taper, a + side_a * taper, b + side_b * taper, a - side_a * taper, b + side_b * taper, b - side_b * taper]:
			_mesh.surface_set_color(color)
			_mesh.surface_add_vertex(v)


func _halo(at: Vector3, size: float, color: Color) -> MeshInstance3D:
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	halo.mesh = quad
	var mat: StandardMaterial3D = _dot_mat.duplicate()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = false
	mat.albedo_color = color
	halo.material_override = mat
	halo.set_meta("alpha", color.a)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = at
	return halo


func _make_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.local_coords = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 24
	p.lifetime = 0.45
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(0.4, 0.65, 1.0, 0.0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	quad.material = _dot_mat
	p.mesh = quad
	return p


static func _make_dot_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = g
	mat.albedo_texture = dot
	return mat
