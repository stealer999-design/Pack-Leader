class_name TidalWaveFX
extends Node3D
## Tidal Wave's look: a curling wall of water that rears up in front of the
## caster and rolls out across the cone, glowing blue-white streaks racing up
## its face, foam tearing off the crest, spray flying, and churned foam left
## on the ground behind it. Then it collapses and fades. Purely visual: the
## ability times its hits to when the wave reaches each enemy (reach_time).

const WAVE_SHADER := preload("res://scripts/tidal_wave.gdshader")
const FOAM_SHADER := preload("res://scripts/tidal_foam.gdshader")
const NEAR := 0.6  ## Where the wave rises, in front of the caster.
const TRAVEL := 0.8  ## Seconds to roll out to full range.
const COLLAPSE := 0.45  ## Seconds to break and fade after that.
const ARC_STEPS := 36
const SPRAY_EMITTERS := 12
## The wave's side profile, back foot to curling lip: (forward, up) in wave heights.
const PROFILE := [Vector2(-1.5, 0.0), Vector2(-1.0, 0.12), Vector2(-0.55, 0.4), Vector2(-0.2, 0.75),
		Vector2(0.1, 0.97), Vector2(0.4, 1.05), Vector2(0.65, 0.98), Vector2(0.82, 0.8),
		Vector2(0.86, 0.6), Vector2(0.74, 0.44)]

static var _wave_mesh: ArrayMesh
static var _foam_mesh: ArrayMesh
static var _spray_mat: StandardMaterial3D

var radius := 7.0
var half_angle := 0.5
var peak := 2.2
var _t := 0.0
var _wave_mat: ShaderMaterial
var _foam_mat: ShaderMaterial
var _swell_mat: ShaderMaterial  ## a lower second swell rolling in behind the wave
var _sprays: Array[CPUParticles3D] = []
var _light: OmniLight3D


## Seconds after casting that the wave reaches `distance` from the caster.
static func reach_time(distance: float, full_radius: float) -> float:
	var f := clampf((distance - NEAR) / maxf(full_radius - NEAR, 0.1), 0.0, 1.0)
	return TRAVEL * (1.0 - sqrt(1.0 - f))  # inverse of the ease-out in _dist()


## Plays the wave at `origin`, rolling towards `forward` (flat), `cone_degrees` wide.
static func play(parent: Node, origin: Vector3, forward: Vector3, full_radius: float, cone_degrees: float, color: Color) -> void:
	var fx := TidalWaveFX.new()
	fx.radius = full_radius
	fx.half_angle = deg_to_rad(cone_degrees) * 0.5 + 0.12
	fx.peak = clampf(full_radius * 0.32, 1.2, 2.4)
	parent.add_child(fx)
	fx.global_position = origin
	fx.look_at(origin + forward, Vector3.UP)  # -Z towards the target
	fx._build(color)


func _build(color: Color) -> void:
	if _wave_mesh == null:
		_wave_mesh = _make_wave_mesh()
		_foam_mesh = _make_foam_mesh()
		_spray_mat = _make_spray_material()
	_wave_mat = ShaderMaterial.new()
	_wave_mat.shader = WAVE_SHADER
	_wave_mat.set_shader_parameter("half_angle", half_angle)
	_wave_mat.set_shader_parameter("deep", Color(0.01, 0.09, 0.13).lerp(color * 0.15, 0.3))
	_wave_mat.set_shader_parameter("shallow", Color(0.08, 0.42, 0.52).lerp(color * 0.6, 0.25))
	_wave_mat.set_shader_parameter("glow", Color(0.45, 0.9, 1.0).lerp(color.lightened(0.5), 0.2))
	_add_wave(_wave_mat)
	_swell_mat = _wave_mat.duplicate()
	_swell_mat.set_shader_parameter("seed", 3.7)
	_swell_mat.set_shader_parameter("brightness", 0.6)
	_add_wave(_swell_mat)
	_foam_mat = ShaderMaterial.new()
	_foam_mat.shader = FOAM_SHADER
	_foam_mat.set_shader_parameter("half_angle", half_angle)
	_foam_mat.set_shader_parameter("near", NEAR * 0.5)
	_foam_mat.set_shader_parameter("water", Color(0.06, 0.3, 0.38))
	_foam_mat.set_shader_parameter("glow", color.lightened(0.45))
	var foam := MeshInstance3D.new()
	foam.mesh = _foam_mesh
	foam.material_override = _foam_mat
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.extra_cull_margin = radius + 2.0
	foam.position.y = 0.06
	add_child(foam)
	for i in SPRAY_EMITTERS:
		var spray := _make_spray(color)
		add_child(spray)
		_sprays.append(spray)
	_cast_flash(color)
	_light = OmniLight3D.new()
	_light.light_color = color.lightened(0.35)
	_light.light_energy = 3.0
	_light.omni_range = radius * 0.9
	_light.shadow_enabled = false
	add_child(_light)
	_update()


func _add_wave(mat: ShaderMaterial) -> void:
	var wave := MeshInstance3D.new()
	wave.mesh = _wave_mesh
	wave.material_override = mat
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave.extra_cull_margin = radius + 4.0  # the shader moves it far from its template
	add_child(wave)


## A burst of blue-white light at the caster as the spell goes off.
func _cast_flash(color: Color) -> void:
	var flash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	flash.mesh = quad
	var mat: StandardMaterial3D = _spray_mat.duplicate()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = false
	mat.albedo_color = Color(0.75, 0.92, 1.0).lerp(color, 0.25)
	flash.material_override = mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.position = Vector3(0, 0.7, -0.4)
	add_child(flash)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.9, 1.0)
	light.light_energy = 4.0
	light.omni_range = 4.0
	flash.add_child(light)
	var tween := flash.create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector3.ONE * 2.2, 0.45).from(Vector3.ONE * 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45).set_delay(0.1)
	tween.tween_property(light, "light_energy", 0.0, 0.5)
	tween.chain().tween_callback(flash.queue_free)


func _process(delta: float) -> void:
	_t += delta
	_update()
	if _t >= TRAVEL + COLLAPSE + 0.6:  # let the last spray land
		queue_free()


func _dist(p: float) -> float:
	return NEAR + (radius - NEAR) * (1.0 - (1.0 - p) * (1.0 - p))


func _update() -> void:
	var p := clampf(_t / TRAVEL, 0.0, 1.0)
	var breaking := clampf((_t - TRAVEL) / COLLAPSE, 0.0, 1.0)
	var dist := _dist(p) + breaking * 0.8
	var height := peak * smoothstep(0.0, 0.28, p) * (1.0 - 0.7 * breaking)
	var fade := 1.0 - breaking
	_wave_mat.set_shader_parameter("dist", dist)
	_wave_mat.set_shader_parameter("height", maxf(height, 0.01))
	_wave_mat.set_shader_parameter("fade", fade)
	var swell_dist := maxf(dist - peak * 1.6, NEAR * 0.5)
	_swell_mat.set_shader_parameter("dist", swell_dist)
	_swell_mat.set_shader_parameter("height", maxf(height * 0.5 * smoothstep(0.15, 0.45, p), 0.01))
	_swell_mat.set_shader_parameter("fade", fade * 0.85)
	_foam_mat.set_shader_parameter("dist", maxf(dist - 0.2, NEAR * 0.5 + 0.05))
	_foam_mat.set_shader_parameter("fade", 1.0 - clampf((_t - TRAVEL * 0.6) / (COLLAPSE + TRAVEL * 0.4), 0.0, 1.0))
	# spray flies off the lip, all along the crest
	for i in _sprays.size():
		var across := (i + 0.5) / _sprays.size()
		var a := lerpf(-half_angle, half_angle, across) * 0.9
		var taper := pow(sin(PI * across), 0.6)
		var h := height * (0.35 + 0.65 * taper)
		var r := dist + 0.6 * h
		_sprays[i].position = Vector3(sin(a) * r, h * 0.95, -cos(a) * r)
		_sprays[i].emitting = _t < TRAVEL + COLLAPSE * 0.6 and height > 0.3
	_light.position = Vector3(0, height * 0.7 + 0.4, -dist)
	_light.light_energy = 3.0 * fade


func _make_spray(color: Color) -> CPUParticles3D:
	var spray := CPUParticles3D.new()
	spray.local_coords = false  # spray stays where it was flung while the wave rolls on
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spray.amount = 36
	spray.lifetime = 0.85
	spray.explosiveness = 0.0
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	spray.emission_sphere_radius = 0.35
	var forward := global_basis * Vector3.FORWARD
	spray.direction = (forward + Vector3.UP * 1.2).normalized()
	spray.spread = 35.0
	spray.initial_velocity_min = 3.0
	spray.initial_velocity_max = 7.5
	spray.gravity = Vector3(0, -11.0, 0)
	spray.scale_amount_min = 0.5
	spray.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.95))
	ramp.set_color(1, Color(color.lightened(0.3), 0.0))
	spray.color_ramp = ramp
	var size := Curve.new()
	size.add_point(Vector2(0, 0.6))
	size.add_point(Vector2(0.3, 1.0))
	size.add_point(Vector2(1, 0.4))
	spray.scale_amount_curve = size
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.42)
	quad.material = _spray_mat
	spray.mesh = quad
	return spray


static func _make_spray_material() -> StandardMaterial3D:
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


## The wave's template: the profile (smoothed) swept across the arc; the
## shader bends it into place.
static func _make_wave_mesh() -> ArrayMesh:
	var curve := Curve2D.new()
	for pt in PROFILE:
		curve.add_point(pt)
	for i in curve.point_count:  # smooth (Catmull-Rom style handles)
		var prev: Vector2 = PROFILE[maxi(i - 1, 0)]
		var next: Vector2 = PROFILE[mini(i + 1, PROFILE.size() - 1)]
		var handle := (next - prev) * 0.25
		curve.set_point_in(i, -handle)
		curve.set_point_out(i, handle)
	var length := curve.get_baked_length()
	var steps := 28
	var profile: Array[Vector2] = []
	for s in steps + 1:
		profile.append(curve.sample_baked(length * s / steps))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in ARC_STEPS + 1:
		for s in steps + 1:
			var tangent := profile[mini(s + 1, steps)] - profile[maxi(s - 1, 0)]
			var n := Vector2(-tangent.y, tangent.x).normalized()
			st.set_normal(Vector3(n.x, n.y, 0))
			st.set_uv(Vector2(float(a) / ARC_STEPS, float(s) / steps))
			st.add_vertex(Vector3(profile[s].x, profile[s].y, 0))
	_grid_indices(st, ARC_STEPS, steps)
	return st.commit()


static func _make_foam_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 10
	for a in ARC_STEPS + 1:
		for s in rows + 1:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(float(a) / ARC_STEPS, float(s) / rows))
			st.add_vertex(Vector3.ZERO)
	_grid_indices(st, ARC_STEPS, rows)
	return st.commit()


static func _grid_indices(st: SurfaceTool, columns: int, rows: int) -> void:
	for a in columns:
		for s in rows:
			var i := a * (rows + 1) + s
			var j := i + rows + 1
			st.add_index(i)
			st.add_index(j)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(j)
			st.add_index(j + 1)
