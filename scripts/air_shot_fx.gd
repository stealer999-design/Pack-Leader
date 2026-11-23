class_name AirShotFX
extends Node3D
## An archer's basic shot, "air" look: a real arrow (wooden shaft, steel
## broadhead, three feathered vanes in the species' colour) that appears at
## the bow with a ring of air, flies leaving a pale streak of air behind it
## with two wisps spiralling round its path, and strikes with a burst of air
## and a few sparks. Kept light: archers loose one about once a second.

const TRAIL := 2.2  ## How long the air streak behind the arrow is.
const AIR := Color(0.95, 0.97, 1.0)

static var _parts: Array = []  ## [mesh, material, transform] making up the arrow, built once per feather colour
static var _parts_colour := Color(0, 0, 0, 0)
static var _ring_mesh: TorusMesh

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _travel := 0.2
var _t := 0.0
var _arrow: Node3D
var _mesh: ImmediateMesh
var _landed := false


## An arrow from `from` to `to` in `travel` seconds, its vanes `feather` coloured.
static func play(parent: Node3D, from: Vector3, to: Vector3, feather: Color, travel: float) -> void:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.42
		_ring_mesh.outer_radius = 0.5
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 4
	var fx := AirShotFX.new()
	fx._from = from
	fx._to = to
	fx._travel = maxf(travel, 0.05)
	parent.add_child(fx)
	fx._build(feather)


static func _material(color: Color, metal := 0.0, rough := 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	return mat


## The arrow, pointing along -Z, its tip at z = -0.55.
static func _arrow_parts(feather: Color) -> Array:
	var parts: Array = []
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.022
	shaft.bottom_radius = 0.022
	shaft.height = 0.95
	shaft.radial_segments = 6
	shaft.rings = 1
	var along := Basis(Vector3.RIGHT, -PI / 2.0)  # a cylinder's +Y turned to -Z
	parts.append([shaft, _material(Color(0.58, 0.4, 0.23)), Transform3D(along, Vector3(0, 0, -0.02))])
	var head := CylinderMesh.new()  # a broadhead: a flattened cone of steel
	head.top_radius = 0.0
	head.bottom_radius = 0.06
	head.height = 0.2
	head.radial_segments = 4
	head.rings = 1
	parts.append([head, _material(Color(0.78, 0.8, 0.84), 0.85, 0.3), Transform3D(along.scaled(Vector3(1.5, 1, 0.45)), Vector3(0, 0, -0.55))])
	var collar := CylinderMesh.new()
	collar.top_radius = 0.03
	collar.bottom_radius = 0.03
	collar.height = 0.05
	collar.radial_segments = 6
	collar.rings = 1
	parts.append([collar, _material(Color(0.3, 0.28, 0.27), 0.6, 0.5), Transform3D(along, Vector3(0, 0, -0.44))])
	var vane := BoxMesh.new()  # three feathered vanes at the back, 120 degrees apart
	vane.size = Vector3(0.006, 0.075, 0.24)
	var vmat := _material(feather.lightened(0.25), 0.0, 0.9)
	for k in 3:
		var turn := Basis(Vector3.BACK, TAU * k / 3.0)
		parts.append([vane, vmat, Transform3D(turn, turn * Vector3(0, 0.05, 0) + Vector3(0, 0, 0.36))])
	var nock := BoxMesh.new()
	nock.size = Vector3(0.04, 0.04, 0.04)
	parts.append([nock, _material(Color(0.2, 0.18, 0.16)), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.48))])
	return parts


func _build(feather: Color) -> void:
	if _parts.is_empty() or _parts_colour != feather:
		_parts = _arrow_parts(feather)
		_parts_colour = feather
	_arrow = Node3D.new()
	add_child(_arrow)
	_arrow.top_level = true
	for p in _parts:
		var m := MeshInstance3D.new()
		m.mesh = p[0]
		m.material_override = p[1]
		m.transform = p[2]
		_arrow.add_child(m)
	var dir := (_to - _from).normalized()
	_arrow.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).scaled(Vector3.ONE * 0.3), _from)
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
	_air_ring(_from + dir * 0.3, dir, 0.25, 0.7)  # the air it cleaves as it's loosed


func _process(delta: float) -> void:
	_t += delta
	var dir := (_to - _from).normalized()
	var u := clampf(_t / _travel, 0.0, 1.0)
	var head := _from.lerp(_to, u)
	if not _landed:
		var grow := lerpf(0.3, 1.5, clampf(_t / 0.06, 0.0, 1.0))  # it appears at the bow
		_arrow.global_transform = Transform3D(_arrow.global_transform.basis.orthonormalized().scaled(Vector3.ONE * grow), head)
		if u >= 1.0:
			_landed = true
			_arrow.visible = false
			_strike(_to, dir)
	_draw_trail(head, dir)
	if _t > _travel + 0.6:
		queue_free()


## The streak of air behind the arrow, and two wisps spiralling round it; once
## it lands, the tail catches up and they're gone.
func _draw_trail(head: Vector3, dir: Vector3) -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var flown := _from.distance_to(head)
	var tail_len := minf(TRAIL, flown)
	if _landed:
		tail_len = maxf(tail_len - (_t - _travel) * 12.0, 0.0)
	if tail_len < 0.05:
		return
	var eye := cam.global_position
	var back := head - dir * 0.25  # from behind the vanes
	_ribbon(back, dir, tail_len, eye, 0.24, Color(AIR, 0.75), 0.0, 0.0)
	var side := dir.cross(Vector3.UP).normalized() if absf(dir.y) < 0.95 else Vector3.RIGHT
	for k in 2:
		_ribbon(back, dir, tail_len * 0.8, eye, 0.05, Color(AIR, 0.85), 0.16, PI * k + _t * 25.0, side)


## A camera-facing strip running back `length` from `start` against `dir`,
## `width` wide at its head, thinning and fading behind; with `swirl` > 0 it
## coils round the line at that radius.
func _ribbon(start: Vector3, dir: Vector3, length: float, eye: Vector3, width: float, color: Color, swirl: float, phase: float, side := Vector3.ZERO) -> void:
	var up := side.cross(dir).normalized()
	var n := 14
	var pts: Array[Vector3] = []
	for i in n:
		var u := float(i) / (n - 1)
		var p := start - dir * length * u
		if swirl > 0.0:
			var a := phase + u * length * 9.0
			p += (side * cos(a) + up * sin(a)) * swirl * (0.4 + 0.6 * u)
		pts.append(p)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var u := float(i) / (n - 1)
		var along := (pts[maxi(i - 1, 0)] - pts[mini(i + 1, n - 1)]).normalized()
		var s := along.cross(eye - pts[i]).normalized()
		var w := width * (1.0 - u * 0.85)
		var c := Color(color, color.a * (1.0 - u))
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(pts[i] + s * w * 0.5)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(pts[i] - s * w * 0.5)
	_mesh.surface_end()


## A ring of air pushed out across `dir`, from `size` to `size` * 2.2.
func _air_ring(at: Vector3, dir: Vector3, life: float, size: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(AIR, 0.7)
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.top_level = true
	var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, PI / 2.0)  # the torus' axis (+Y) along the flight
	ring.global_transform = Transform3D(basis.scaled(Vector3.ONE * size * 0.5), at)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3.ONE * size * 1.1, life).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", Color(AIR, 0.0), life).from(Color(AIR, 0.7))


func _strike(at: Vector3, dir: Vector3) -> void:
	_air_ring(at, dir, 0.3, 1.0)
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
	sparks.amount = 12
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.lifetime = 0.3
	sparks.direction = -dir + Vector3.UP * 0.5
	sparks.spread = 70.0
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 5.0
	sparks.gravity = Vector3(0, -6, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
	ramp.set_color(1, Color(1.0, 0.65, 0.25, 0.0))
	sparks.color_ramp = ramp
	add_child(sparks)
	sparks.top_level = true
	sparks.global_position = at
	sparks.emitting = true
