class_name HailFX
extends Node3D
## One of Hailstorm's hailstones: a jagged chunk of ice falling out of the
## frosty vortex (StormFX with ice), shedding snow; where it lands it
## shatters into flying ice shards and a burst of snow and leaves a patch of
## frost on the ground that melts away.

const SCORCH_SHADER := preload("res://scripts/scorch.gdshader")
const FROST_TIME := 2.0

static var _ice_mat: StandardMaterial3D
static var _snow_mat: StandardMaterial3D

var _stone: MeshInstance3D
var _snow: CPUParticles3D
var _radius := 1.3


static func play(parent: Node, from: Vector3, to: Vector3, travel: float, radius: float) -> void:
	if _ice_mat == null:
		_ice_mat = StandardMaterial3D.new()
		_ice_mat.albedo_color = Color(0.78, 0.9, 1.0, 0.92)
		_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ice_mat.roughness = 0.15
		_ice_mat.metallic_specular = 1.0
		_ice_mat.emission_enabled = true
		_ice_mat.emission = Color(0.45, 0.7, 1.0)
		_ice_mat.emission_energy_multiplier = 0.35
		_ice_mat.rim_enabled = true
		_ice_mat.rim = 1.0
		LightningFX.ensure_materials()
		_snow_mat = LightningFX._dot_mat
	var fx := HailFX.new()
	fx._radius = radius
	parent.add_child(fx)
	fx.global_position = from
	fx._build()
	var tween := fx.create_tween()
	tween.tween_property(fx, "global_position", to, travel).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(fx._shatter)


func _build() -> void:
	_stone = MeshInstance3D.new()
	_stone.mesh = _chunk(randf_range(0.28, 0.38))
	_stone.material_override = _ice_mat
	_stone.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	add_child(_stone)
	_snow = _particles(30, 0.5, 0.25, Vector3.UP * 0.5, 30.0, 0.3, 1.2, Vector3(0, -2.0, 0), 0.22)
	_snow.local_coords = false
	add_child(_snow)
	_snow.emitting = true


func _process(delta: float) -> void:
	if is_instance_valid(_stone):
		_stone.rotate_x(delta * 5.0)
		_stone.rotate_z(delta * 3.0)


## It lands: ice shards fly, snow bursts up, the ground frosts over.
func _shatter() -> void:
	_stone.queue_free()
	_snow.emitting = false
	var ground := Vector3(global_position.x, 0.0, global_position.z)
	# frost on the ground
	var frost := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (_radius * 1.6 + 0.4)
	quad.orientation = PlaneMesh.FACE_Y
	frost.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = SCORCH_SHADER
	mat.set_shader_parameter("ice", 1.0)
	mat.set_shader_parameter("seed", randf() * 50.0)
	frost.material_override = mat
	frost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(frost)
	frost.global_position = ground + Vector3.UP * 0.035
	frost.global_rotation = Vector3(0, randf() * TAU, 0)
	create_tween().tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, FROST_TIME).set_ease(Tween.EASE_IN)
	# a burst of snow
	var burst := _particles(40, 0.7, 0.4, Vector3.UP, 70.0, 2.0, 5.0, Vector3(0, -5.0, 0), 0.4)
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.local_coords = false
	add_child(burst)
	burst.global_position = ground + Vector3.UP * 0.3
	burst.emitting = true
	# shards of ice thrown out
	for i in 7:
		var shard := MeshInstance3D.new()
		shard.mesh = _chunk(randf_range(0.08, 0.16))
		shard.material_override = _ice_mat
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shard)
		var start := ground + Vector3.UP * 0.25
		var out := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(0.8, 2.0)
		var up := randf_range(2.5, 4.5)
		var time := randf_range(0.4, 0.6)
		var spin := Vector3(randf(), randf(), randf()) * 14.0
		shard.global_position = start
		var tween := shard.create_tween()
		tween.tween_method(func(t: float) -> void:
				shard.global_position = start + out * t + Vector3.UP * (up * t * time - 4.9 * t * t * time * time)
				shard.rotation = spin * t, 0.0, 1.0, time)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.4).set_delay(0.3)
	var done := create_tween()
	done.tween_interval(FROST_TIME)
	done.tween_callback(queue_free)


## A jagged lump of ice (a sphere with few sides, stretched).
func _chunk(size: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * randf_range(1.5, 2.3)
	mesh.radial_segments = 5
	mesh.rings = 3
	return mesh


func _particles(amount: int, lifetime: float, emit_radius: float, direction: Vector3, spread: float,
		speed_min: float, speed_max: float, gravity: Vector3, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = emit_radius
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = gravity
	p.damping_min = 1.0
	p.damping_max = 2.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.95))
	ramp.set_color(1, Color(0.75, 0.88, 1.0, 0.0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _snow_mat
	p.mesh = quad
	return p
