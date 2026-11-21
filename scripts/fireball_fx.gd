class_name FireballFX
extends Node3D
## Fireball's look (and Magma Orb's, with `magma`: a bigger swirling ball of
## molten rock and no trail; and Meteor Shower's, with `meteor`: a burning rock
## streaking down out of the sky on a long tail of flame, that blasts out rock
## chunks and leaves a patch of burning ground): a blazing ball (white-hot heart, boiling flames, a halo)
## with flame tendrils spiralling back from it and embers streaming off,
## flying from the caster to the spot; there it explodes in a ball of fire
## that burns out, flinging sparks, with a flash of light. Purely visual: the
## ability lands the damage when it arrives.

const BALL_SHADER := preload("res://scripts/fire_ball.gdshader")
const TRAIL_SHADER := preload("res://scripts/fire_trail.gdshader")
const BALL_RADIUS := 0.55
const TRAIL_LENGTH := 3.4
const EXPLODE_TIME := 0.55
const MAGMA_RADIUS := 0.8
const SCORCH_SHADER := preload("res://scripts/scorch.gdshader")
const SCORCH_TIME := 2.6

static var _ribbon_mesh: ArrayMesh
static var _dot_mat: StandardMaterial3D

var _trails: Array[ShaderMaterial] = []
var _embers: CPUParticles3D
var _blast_radius := 2.5
var _magma := false
var _meteor := 0.0  ## a meteor of this size (1 = full), 0 = not a meteor


## Throws a fireball from `from` to `to`, arriving after `travel` seconds.
static func play(parent: Node, from: Vector3, to: Vector3, travel: float, blast_radius: float, magma := false, meteor := 0.0) -> void:
	if _ribbon_mesh == null:
		_ribbon_mesh = _make_ribbon()
		_dot_mat = _make_dot_material()
	if meteor > 0.0:
		from = _meteor_start(parent, from, to)
	var fx := FireballFX.new()
	fx._blast_radius = blast_radius
	fx._magma = magma
	fx._meteor = meteor
	parent.add_child(fx)
	fx.global_position = from
	var flat := to - from
	if flat.length() > 0.05:
		fx.look_at(to, Vector3.UP if absf(flat.normalized().y) < 0.95 else Vector3.FORWARD)
	fx._build()
	var tween := fx.create_tween()
	tween.tween_property(fx, "global_position", to, travel).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(fx._explode)


## Meteors streak in from the top right of this player's screen, whichever
## way their camera faces, so their tails show at full length.
static func _meteor_start(parent: Node, from: Vector3, to: Vector3) -> Vector3:
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	if cam == null:
		return from
	var right := cam.global_basis.x
	right.y = 0.0
	var away := -cam.global_basis.z
	away.y = 0.0
	var height := from.y - to.y
	return to + right.normalized() * height * 0.45 + away.normalized() * height * 0.12 + Vector3.UP * height


func _build() -> void:
	if _magma:
		_build_magma()
		return
	if _meteor > 0.0:
		_build_meteor()
		return
	# the ball: an outer shell of flame round a white-hot heart
	for layer in [[BALL_RADIUS * 1.45, 0.75, 0.7], [BALL_RADIUS, 1.25, 1.0]]:
		var mat := ShaderMaterial.new()
		mat.shader = BALL_SHADER
		mat.set_shader_parameter("heat", layer[1])
		mat.set_shader_parameter("strength", layer[2])
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = layer[0]
		sphere.height = layer[0] * 2.0
		sphere.radial_segments = 24
		sphere.rings = 12
		ball.mesh = sphere
		ball.material_override = mat
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ball)
	add_child(_halo(BALL_RADIUS * 4.0, Color(1.0, 0.4, 0.08, 0.3)))
	# two tendrils twisting round each other, and a plume down the middle
	for spec in [[0.0, BALL_RADIUS * 0.9, 0.6], [PI, BALL_RADIUS * 0.9, 0.6], [0.0, 0.0, 1.0]]:
		var mat := ShaderMaterial.new()
		mat.shader = TRAIL_SHADER
		mat.set_shader_parameter("phase", spec[0])
		mat.set_shader_parameter("radius", spec[1])
		mat.set_shader_parameter("width", spec[2])
		mat.set_shader_parameter("strength", 1.0 if spec[1] > 0.0 else 0.6)
		mat.set_shader_parameter("trail_length", 0.2)
		var ribbon := MeshInstance3D.new()
		ribbon.mesh = _ribbon_mesh
		ribbon.material_override = mat
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ribbon.extra_cull_margin = TRAIL_LENGTH + 1.0  # the shader moves it off its template
		add_child(ribbon)
		_trails.append(mat)
		# the trail streams out behind as it leaves the caster
		create_tween().tween_method(func(v: float) -> void: mat.set_shader_parameter("trail_length", v),
				0.2, TRAIL_LENGTH, 0.25)
	_embers = _make_embers()
	add_child(_embers)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 1.2
	light.omni_range = 3.5
	light.shadow_enabled = false
	add_child(light)


## Magma Orb: a big churning sphere of lava, molten arms swirling over dark
## crust inside a thin skin of flame. Just the orb, no trail.
func _build_magma() -> void:
	for layer in [[MAGMA_RADIUS * 1.12, 0.6, 0.4, 0.0], [MAGMA_RADIUS, 0.95, 1.0, 1.0]]:
		var mat := ShaderMaterial.new()
		mat.shader = BALL_SHADER
		mat.set_shader_parameter("heat", layer[1])
		mat.set_shader_parameter("strength", layer[2])
		mat.set_shader_parameter("magma", layer[3])
		mat.set_shader_parameter("flicker", 4.0)
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = layer[0]
		sphere.height = layer[0] * 2.0
		sphere.radial_segments = 32
		sphere.rings = 16
		ball.mesh = sphere
		ball.material_override = mat
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ball)
	add_child(_halo(MAGMA_RADIUS * 3.6, Color(1.0, 0.35, 0.06, 0.3)))
	_embers = _make_embers()  # kept for _explode, but never emits: no trail
	_embers.emitting = false
	add_child(_embers)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.15)
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.shadow_enabled = false
	add_child(light)


## A meteor: a burning rock (a dark crust cracked with fire inside a skin of
## flame) on a long, straight tail of fire, shedding embers.
func _build_meteor() -> void:
	var m := _meteor
	for layer in [[0.7 * m, 0.7, 0.55, 0.0], [0.5 * m, 0.95, 1.0, 1.0]]:
		var mat := ShaderMaterial.new()
		mat.shader = BALL_SHADER
		mat.set_shader_parameter("heat", layer[1])
		mat.set_shader_parameter("strength", layer[2])
		mat.set_shader_parameter("magma", layer[3])
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = layer[0]
		sphere.height = layer[0] * 2.0
		ball.mesh = sphere
		ball.material_override = mat
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ball)
	add_child(_halo(2.6 * m, Color(1.0, 0.4, 0.08, 0.35)))
	var mat := ShaderMaterial.new()
	mat.shader = TRAIL_SHADER
	mat.set_shader_parameter("radius", 0.0)
	mat.set_shader_parameter("twist", 0.0)
	mat.set_shader_parameter("spin", 0.0)
	mat.set_shader_parameter("width", 1.2 * m)
	mat.set_shader_parameter("trail_length", 0.3)
	var tail := MeshInstance3D.new()
	tail.mesh = _ribbon_mesh
	tail.material_override = mat
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tail.extra_cull_margin = 8.0
	add_child(tail)
	create_tween().tween_method(func(v: float) -> void: mat.set_shader_parameter("trail_length", v),
			0.3, 5.5 * m, 0.3)
	_embers = _make_embers()
	_embers.amount = int(30 * m) + 6
	_embers.emission_sphere_radius = 0.35 * m
	add_child(_embers)


## Where a meteor lands: rock chunks thrown out, and the ground left burning.
func _meteor_impact() -> void:
	var m := _meteor
	var scorch := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (_blast_radius * 1.1 * m + 0.6)
	quad.orientation = PlaneMesh.FACE_Y
	scorch.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = SCORCH_SHADER
	mat.set_shader_parameter("seed", randf() * 50.0)
	scorch.material_override = mat
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(scorch)
	scorch.global_position = Vector3(global_position.x, 0.04, global_position.z)
	scorch.global_rotation = Vector3(0, randf() * TAU, 0)
	create_tween().tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v),
			1.0, 0.0, SCORCH_TIME).set_ease(Tween.EASE_IN)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.12, 0.08, 0.07)
	rock_mat.roughness = 0.9
	rock_mat.emission_enabled = true
	rock_mat.emission = Color(1.0, 0.35, 0.05)
	rock_mat.emission_energy_multiplier = 0.2
	for i in int(5 + 5 * m):
		var rock := MeshInstance3D.new()
		var mesh := SphereMesh.new()  # a few sides only, so it's lumpy
		var r := randf_range(0.07, 0.17) * (0.5 + m * 0.6)
		mesh.radius = r
		mesh.height = r * randf_range(1.3, 2.0)
		mesh.radial_segments = 5
		mesh.rings = 3
		rock.mesh = mesh
		rock.material_override = rock_mat
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rock)
		var start := Vector3(global_position.x, 0.2, global_position.z)
		var out := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(1.0, 2.6) * (0.6 + m * 0.5)
		var up := randf_range(2.5, 5.0)
		var time := randf_range(0.45, 0.75)
		var spin := Vector3(randf(), randf(), randf()) * 12.0
		rock.global_position = start
		var tween := rock.create_tween()
		tween.tween_method(func(t: float) -> void:
				rock.global_position = start + out * t + Vector3.UP * (up * t * time - 4.9 * t * t * time * time)
				rock.rotation = spin * t, 0.0, 1.0, time)
		tween.tween_property(rock, "scale", Vector3.ZERO, 0.6).set_delay(0.5)


## It strikes: the ball and tendrils go, a fireball blooms and burns out.
func _explode() -> void:
	for child in get_children():
		if child != _embers:
			child.queue_free()
	_embers.emitting = false  # the trail's last sparks drift on
	var size := maxf(_blast_radius * 0.65, 1.0)
	if _meteor > 0.0:
		size = maxf(_blast_radius * 0.5 * _meteor, 0.7)
		_meteor_impact()
	var blast := Node3D.new()
	add_child(blast)
	var layers := []
	for layer in [[0.75, 1.3], [1.0, 0.85]]:
		var mat := ShaderMaterial.new()
		mat.shader = BALL_SHADER
		mat.set_shader_parameter("heat", layer[1])
		mat.set_shader_parameter("flicker", 10.0)
		mat.set_shader_parameter("wisp", 1.0)
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = layer[0]
		sphere.height = layer[0] * 2.0
		ball.mesh = sphere
		ball.material_override = mat
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blast.add_child(ball)
		layers.append(mat)
	var halo := _halo(size * 2.2, Color(1.0, 0.38, 0.06, 0.35))
	blast.add_child(halo)
	var sparks := _make_burst()
	add_child(sparks)
	sparks.emitting = true
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 2.0
	light.omni_range = size * 2.5
	light.shadow_enabled = false
	light.position.y = 0.6
	add_child(light)
	var hot := 1.0 if _meteor > 0.0 else 1.3  # meteors burst redder, rock and fire
	var tween := create_tween().set_parallel()
	tween.tween_property(blast, "scale", Vector3.ONE * size, EXPLODE_TIME).from(Vector3.ONE * 0.3) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for mat: ShaderMaterial in layers:
		tween.tween_method(func(v: float) -> void:
				mat.set_shader_parameter("erode", 0.1 + v * 0.9)
				mat.set_shader_parameter("heat", lerpf(hot, 0.45, v)), 0.0, 1.0, EXPLODE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_property(halo.material_override, "albedo_color:a", 0.0, EXPLODE_TIME * 0.8)
	tween.tween_property(light, "light_energy", 0.0, EXPLODE_TIME)
	tween.chain().tween_interval(SCORCH_TIME - EXPLODE_TIME if _meteor > 0.0 else 0.6)  # the sparks land (and the ground stops burning)
	tween.chain().tween_callback(queue_free)


## A soft glow that faces the camera, added on top of what's behind it.
func _halo(size: float, color: Color) -> MeshInstance3D:
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	halo.mesh = quad
	var mat: StandardMaterial3D = _dot_mat.duplicate()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = false
	mat.albedo_color = color
	halo.material_override = mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return halo


func _make_embers() -> CPUParticles3D:
	var p := _sparks_base()
	p.local_coords = false  # they're left behind in the air as the ball flies on
	p.amount = 48
	p.lifetime = 0.55
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = BALL_RADIUS
	p.direction = Vector3(0, 0.3, 1)  # backwards, a little up
	p.spread = 40.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.5
	p.gravity = Vector3(0, 1.5, 0)  # embers rise
	return p


func _make_burst() -> CPUParticles3D:
	var p := _sparks_base()
	p.local_coords = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 70
	p.lifetime = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.5
	p.gravity = Vector3(0, -9.0, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	return p


func _sparks_base() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	ramp.add_point(0.4, Color(1.0, 0.55, 0.12, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.1, 0.02, 0.0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	quad.material = _dot_mat
	p.mesh = quad
	return p


## Soft round dots, added on top of what's behind (glows and sparks).
static func _make_dot_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
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


## A strip: UV.x along it (0..1), UV.y across (0..1); the shader places it.
static func _make_ribbon() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 40
	for i in steps + 1:
		for j in 2:
			st.set_uv(Vector2(float(i) / steps, j))
			st.add_vertex(Vector3.ZERO)
	for i in steps:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	return st.commit()
