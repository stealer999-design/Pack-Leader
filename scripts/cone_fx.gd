class_name ConeFX
extends Node3D
## Arrow Cone's look (after the user's reference): a translucent golden dome
## sweeps out from the archer across the cone it shoots into, and a storm of
## glowing golden arrows streaks out through it (as well as the real arrows,
## which do the damage). The dome swells out in a moment, holds, and fades.

const SWEEP := 0.22  ## Seconds for the dome to reach its full size.
const HOLD := 0.45
const FADE := 0.35
const STREAKS := 64
const DOME_UP := 0.85  ## The dome's height, in radians of arc above the ground (about 50 degrees).

static var _shader: Shader
static var _streak_mesh: CylinderMesh

var _origin := Vector3.ZERO
var _reach := 6.0
var _mat: ShaderMaterial
var _dome: MeshInstance3D
var _mm: MultiMesh
var _glow_mm: MultiMesh
var _arrows: Array = []  ## [direction, speed, delay]
var _t := 0.0


## A cone from `origin` (the bow) towards `forward` (flat), `reach` long and
## `spread_degrees` wide.
static func play(parent: Node3D, origin: Vector3, forward: Vector3, reach: float, spread_degrees: float) -> void:
	if _shader == null:
		_shader = load("res://scripts/arrow_cone.gdshader")
		_streak_mesh = CylinderMesh.new()  # a comet streak: wide at the head, tapering to nothing behind
		_streak_mesh.top_radius = 0.035
		_streak_mesh.bottom_radius = 0.0
		_streak_mesh.height = 1.0
		_streak_mesh.radial_segments = 6
		_streak_mesh.rings = 1
	var fx := ConeFX.new()
	parent.add_child(fx)
	fx._origin = origin
	fx._reach = reach
	fx._build(forward, spread_degrees)


func _build(forward: Vector3, spread_degrees: float) -> void:
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var half := deg_to_rad(spread_degrees) * 0.5 + 0.12  # a little wider than the arrows fly
	# the dome: a sector of a sphere round the bow, built facing -Z and turned to `forward`
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 28
	var rows := 10
	for i in cols:
		for j in rows:
			var quad := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]
			for c in quad:
				var u: float = float(c[0]) / cols
				var v: float = float(c[1]) / rows
				var yaw := lerpf(-half, half, u)
				var pitch := v * DOME_UP
				var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
				st.set_uv(Vector2(u, v))
				st.set_normal(dir)
				st.add_vertex(dir)
	_dome = MeshInstance3D.new()
	_dome.mesh = st.commit()
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_dome.material_override = _mat
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dome)
	var ground := _origin - Vector3.UP * 0.6
	_dome.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), ground)
	_dome.scale = Vector3.ONE * 0.2
	# the storm of golden arrows: a bright core and a soft glow round each
	for which in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _streak_mesh
		mm.instance_count = STREAKS
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.93, 0.65) if which == 0 else Color(1.0, 0.68, 0.15, 0.45)
		inst.material_override = mat
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		if which == 0:
			_mm = mm
		else:
			_glow_mm = mm
	for k in STREAKS:
		var yaw := randf_range(-half + 0.08, half - 0.08)
		var pitch := randf_range(0.0, 0.45)
		var dir := (Basis.looking_at(forward, Vector3.UP) * Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))).normalized()
		_arrows.append([dir, randf_range(11.0, 17.0), randf_range(0.0, SWEEP + HOLD * 0.8)])
	_update()


func _process(delta: float) -> void:
	_t += delta
	_update()
	if _t > SWEEP + HOLD + FADE:
		queue_free()


func _update() -> void:
	var grow := clampf(_t / SWEEP, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 3.0)
	_dome.scale = Vector3.ONE * maxf(_reach * grow, 0.05)
	var fade := 1.0 - clampf((_t - SWEEP - HOLD) / FADE, 0.0, 1.0)
	_mat.set_shader_parameter("fade", fade * clampf(_t / 0.06, 0.0, 1.0))
	for k in STREAKS:
		var a: Array = _arrows[k]
		var flown: float = (_t - a[2]) * a[1]
		var tf := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), _origin)  # not loosed yet, or already gone
		if flown > 0.0 and flown < _reach:
			var dir: Vector3 = a[0]
			var length := minf(1.4, flown)  # a streak trailing behind the head
			var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
			# the cylinder runs along +Y: turned so its head (+Y) leads, along -Z
			tf = Transform3D(basis * Basis(Vector3.RIGHT, -PI / 2.0).scaled(Vector3(1, length, 1)), _origin + dir * (flown - length * 0.5))
		_mm.set_instance_transform(k, tf)
		_glow_mm.set_instance_transform(k, Transform3D(tf.basis * Basis.IDENTITY.scaled(Vector3(3.0, 1.1, 3.0)), tf.origin))
