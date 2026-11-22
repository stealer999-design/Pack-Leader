class_name DustShotFX
extends Node3D
## An archer's basic shot, "dust" look (after the user's reference): the arrow
## tears through the air leaving a widening wake of dust behind it, kicks up
## pebbles as it goes, and strikes with a spray of sparks and a puff of dust.
## Kept light: every archer looses one of these about once a second.

const DUST := Color(0.9, 0.86, 0.78)  # pale: a brown dust vanishes against sand
const PUFFS := 10

static var _pebble_mesh: BoxMesh

var _puffs: Array = []  ## [node, material, start, drift to, size, appears at]
var _t := 0.0


## The arrow from `from` to `to`, arriving in `travel` seconds (the arrow
## itself is World.play_arrow's).
static func play(parent: Node3D, from: Vector3, to: Vector3, travel: float) -> void:
	if _pebble_mesh == null:
		_pebble_mesh = BoxMesh.new()
		_pebble_mesh.size = Vector3(0.1, 0.08, 0.1)
	var fx := DustShotFX.new()
	parent.add_child(fx)
	fx._build(from, to, travel)


func _build(from: Vector3, to: Vector3, travel: float) -> void:
	var tex := FrostFX.puff_texture()
	var dir := (to - from).normalized()
	for k in PUFFS:  # the wake: puffs left along the path as the arrow passes, bigger towards the target
		var u := (k + 0.5) / PUFFS
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = tex
		mat.albedo_color = Color(DUST.darkened(randf() * 0.12), 0.0)
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		var puff := MeshInstance3D.new()
		puff.mesh = quad
		puff.material_override = mat
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)
		puff.top_level = true
		var at := from.lerp(to, u) + Vector3.DOWN * (0.25 * u)
		puff.global_position = at
		var size := lerpf(0.5, 1.7, u)
		puff.visible = false
		_puffs.append([puff, mat, at, at + dir * 0.4 + Vector3.UP * 0.15, size, travel * u])
	get_tree().create_timer(travel * 0.5).timeout.connect(_pebbles.bind(from.lerp(to, 0.7) + Vector3.DOWN * 0.4, dir))
	get_tree().create_timer(travel).timeout.connect(_strike.bind(to, dir))
	get_tree().create_timer(travel + 1.0).timeout.connect(queue_free)


func _process(delta: float) -> void:
	_t += delta
	for p in _puffs:  # each appears as the arrow passes, swells and drifts on, and fades
		var age: float = _t - p[5]
		var node: MeshInstance3D = p[0]
		if age < 0.0 or age > 0.6:
			node.visible = false
			continue
		node.visible = true
		var e := 1.0 - pow(1.0 - clampf(age / 0.45, 0.0, 1.0), 2.0)
		node.global_position = (p[2] as Vector3).lerp(p[3], e)
		node.scale = Vector3.ONE * p[4] * lerpf(0.4, 1.0, e)
		var mat: StandardMaterial3D = p[1]
		var c := mat.albedo_color
		c.a = 0.85 * clampf(age / 0.04, 0.0, 1.0) * (1.0 - clampf((age - 0.15) / 0.45, 0.0, 1.0))
		mat.albedo_color = c


## Pebbles kicked up under the arrow's path, flung forward and falling back.
func _pebbles(at: Vector3, dir: Vector3) -> void:
	var p := CPUParticles3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.36, 0.3)
	mat.roughness = 1.0
	_pebble_mesh.material = mat
	p.mesh = _pebble_mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = 10
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = (dir + Vector3.UP * 1.2).normalized()
	p.spread = 35.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -12, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	add_child(p)
	p.top_level = true
	p.global_position = at
	p.emitting = true


## Sparks where it strikes, and a puff of dust.
func _strike(at: Vector3, dir: Vector3) -> void:
	var sparks := CPUParticles3D.new()
	var dot := QuadMesh.new()
	dot.size = Vector2(0.06, 0.06)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.vertex_color_use_as_albedo = true
	dot.material = smat
	sparks.mesh = dot
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.amount = 14
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.lifetime = 0.3
	sparks.direction = -dir + Vector3.UP * 0.5
	sparks.spread = 70.0
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 5.0
	sparks.gravity = Vector3(0, -6, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	ramp.set_color(1, Color(1.0, 0.6, 0.2, 0.0))
	sparks.color_ramp = ramp
	add_child(sparks)
	sparks.top_level = true
	sparks.global_position = at
	sparks.emitting = true
	FrostFX._mist(self, at + Vector3.DOWN * 0.3, 4, 0.9, Color(DUST, 0.7), 0.6, 0.5)
