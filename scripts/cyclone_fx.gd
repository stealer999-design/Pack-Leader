class_name CycloneFX
extends Node3D
## Cyclone's look: a whirlwind at the spot for its duration. A funnel of dusty
## wind streaks (three layers spinning at different speeds), widening as it
## climbs; stones and debris whirling round inside it; dust churning on the
## ground beneath; and now and then a crackle of lightning in the funnel.

const SHADER := preload("res://scripts/cyclone.gdshader")
const HEIGHT := 2.8
const DEBRIS := 48

static var _debris_mesh: SphereMesh
static var _debris_mat: StandardMaterial3D

var _radius := 3.0
var _duration := 4.0
var _t := 0.0
var _mats: Array[ShaderMaterial] = []
var _debris: MultiMesh
var _orbits := []  ## per piece: [radius, height, speed, phase, bob]
var _next_spark := 0.3


static func play(parent: Node, at: Vector3, radius: float, duration: float) -> void:
	if _debris_mesh == null:
		_debris_mesh = SphereMesh.new()
		_debris_mesh.radius = 0.06
		_debris_mesh.height = 0.1
		_debris_mesh.radial_segments = 5
		_debris_mesh.rings = 3
		_debris_mat = StandardMaterial3D.new()
		_debris_mat.albedo_color = Color(0.32, 0.27, 0.22)
		_debris_mat.roughness = 1.0
	var fx := CycloneFX.new()
	fx._radius = radius
	fx._duration = duration
	parent.add_child(fx)
	fx.global_position = Vector3(at.x, 0.0, at.z)
	fx._build()


func _build() -> void:
	# the funnel: three open cones, the inner ones narrower and faster
	for layer in [[1.0, 5.0, 0.0], [0.85, 6.0, 5.2], [0.7, 7.5, 3.3], [0.5, 9.5, 7.1]]:
		var cone := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = _radius * 0.75 * layer[0]
		mesh.bottom_radius = _radius * 0.3 * layer[0]
		mesh.height = HEIGHT * (0.8 + 0.2 * layer[0])
		mesh.radial_segments = 32
		mesh.rings = 6
		mesh.cap_top = false
		mesh.cap_bottom = false
		cone.mesh = mesh
		cone.position.y = mesh.height * 0.5
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("speed", layer[1])
		mat.set_shader_parameter("seed", layer[2])
		cone.material_override = mat
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cone)
		_mats.append(mat)
	# dust churning on the ground
	var dust := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * _radius * 1.6
	dust.mesh = plane
	var dust_mat := ShaderMaterial.new()
	dust_mat.shader = SHADER
	dust_mat.set_shader_parameter("ground", 1.0)
	dust_mat.set_shader_parameter("speed", 5.0)
	dust.material_override = dust_mat
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.position.y = 0.04
	add_child(dust)
	_mats.append(dust_mat)
	# debris whirling round
	_debris = MultiMesh.new()
	_debris.transform_format = MultiMesh.TRANSFORM_3D
	_debris.mesh = _debris_mesh
	_debris.instance_count = DEBRIS
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = _debris
	inst.material_override = _debris_mat
	add_child(inst)
	for i in DEBRIS:
		var h := randf_range(0.15, HEIGHT * 0.9)
		var r := lerpf(_radius * 0.28, _radius * 0.72, h / HEIGHT) * randf_range(0.8, 1.15)
		_orbits.append([r, h, randf_range(4.0, 7.5), randf() * TAU, randf_range(0.1, 0.35), randf_range(0.6, 1.8)])
	_update()


func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration + 0.4:
		queue_free()
		return
	_update()
	if _t >= _next_spark and _t < _duration - 0.3:  # a crackle of lightning in the wind
		_next_spark = _t + randf_range(0.35, 0.8)
		var a := randf() * TAU
		var h := randf_range(0.6, HEIGHT * 0.8)
		var r := lerpf(_radius * 0.2, _radius * 0.6, h / HEIGHT)
		var from := global_position + Vector3(cos(a) * r, h, sin(a) * r)
		var to := global_position + Vector3(cos(a + 1.2) * r, h - randf_range(0.3, 0.8), sin(a + 1.2) * r)
		LightningFX.play(get_parent(), PackedVector3Array([from, to]), 0.3)


func _update() -> void:
	var fade := minf(clampf(_t / 0.3, 0.0, 1.0), 1.0 - clampf((_t - _duration) / 0.4, 0.0, 1.0))
	for mat in _mats:
		mat.set_shader_parameter("fade", fade)
	var grow := clampf(_t / 0.3, 0.0, 1.0)
	for i in DEBRIS:
		var o: Array = _orbits[i]
		var a: float = o[3] + _t * o[2]
		var h: float = o[1] + sin(_t * 3.0 + o[3]) * o[4]
		var r: float = o[0] * grow
		var basis := Basis(Vector3(0.3, 1, 0.5).normalized(), _t * 9.0 + o[3]).scaled(Vector3.ONE * o[5] * fade)
		_debris.set_instance_transform(i, Transform3D(basis, Vector3(cos(a) * r, h, sin(a) * r)))
