class_name ChainFX
extends Node3D
## Thunder Chain's look: chains of lightning. A chain of glowing links shoots
## from the caster to the spot, a ring of chain spins round the strike, and
## chains lash out from it to every enemy struck. The links slide along as
## if hauled tight, electricity crackles over them (LightningFX), and after a
## moment they fade away.

const LINK := 0.34  ## Length of one link.
const SHOOT := 0.14  ## Seconds for a chain to reach its end.
const HOLD := 0.55
const FADE := 0.25
const RING_RADIUS := 1.25
const RING_LINKS := 22

static var _link_mesh: TorusMesh
static var _core_mat: StandardMaterial3D

var _segments: Array = []  ## [from, to, delay]
var _core: MultiMesh
var _glow: MultiMesh
var _glow_mat: StandardMaterial3D
var _center := Vector3.ZERO
var _t := 0.0


## Chains from `paw` to `center`, then from `center` to each of `targets`.
static func play(parent: Node, paw: Vector3, center: Vector3, targets: PackedVector3Array) -> void:
	if _link_mesh == null:
		_link_mesh = TorusMesh.new()
		_link_mesh.inner_radius = 0.075
		_link_mesh.outer_radius = 0.135
		_link_mesh.rings = 8
		_link_mesh.ring_segments = 6
		_core_mat = StandardMaterial3D.new()
		_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_core_mat.albedo_color = Color(0.85, 0.94, 1.0)
	var fx := ChainFX.new()
	fx._center = center
	fx._segments.append([paw, center, 0.0])
	for t in targets:
		fx._segments.append([center, t, SHOOT * 0.8])
	parent.add_child(fx)
	fx._build(paw, targets)


func _build(paw: Vector3, targets: PackedVector3Array) -> void:
	var count := RING_LINKS * 2
	for seg in _segments:
		count += int(seg[0].distance_to(seg[1]) / LINK) + 2
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.albedo_color = Color(0.3, 0.55, 1.0, 0.5)
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for which in 2:  # a blue glow round each link, and its white-hot core
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _link_mesh
		mm.instance_count = count
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.material_override = _glow_mat if which == 0 else _core_mat
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		if which == 0:
			_glow = mm
		else:
			_core = mm
	# electricity crackling along the chains, sparks and a flash at each end
	LightningFX.play(self, PackedVector3Array([paw, _center]), 0.35)
	for t in targets:
		LightningFX.play(self, PackedVector3Array([_center, t]), 0.3)
	_update()


func _process(delta: float) -> void:
	_t += delta
	if _t >= SHOOT * 2.0 + HOLD + FADE + 0.6:
		queue_free()
		return
	_update()


func _update() -> void:
	var fade := 1.0 - clampf((_t - SHOOT * 2.0 - HOLD) / FADE, 0.0, 1.0)
	var thick := 0.4 + 0.6 * fade  # links thin away as the chain fades
	_glow_mat.albedo_color.a = 0.5 * fade
	var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	var i := 0
	var slide := fmod(_t * 3.0, LINK * 2.0)  # hauled along: links creep towards the targets
	for seg in _segments:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var length := a.distance_to(b)
		var reach := clampf((_t - seg[2]) / SHOOT, 0.0, 1.0) * length
		var dir := (b - a).normalized()
		var n := int(length / LINK) + 2
		for k in n:
			var along := k * LINK + slide - LINK * 2.0
			if along < 0.0 or along > reach or fade <= 0.0:
				_place(i, hidden, hidden)
				i += 1
				continue
			var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
			# alternate links turned a quarter-turn, stretched along the chain
			basis = basis * Basis(Vector3.FORWARD, PI * 0.5 * (k % 2))
			basis = (basis * Basis.from_scale(Vector3(1.0, 1.0, 1.7) * thick))
			var pos := a + dir * along
			_place(i, Transform3D(basis, pos), Transform3D((basis * Basis.from_scale(Vector3.ONE * 1.6)), pos))
			i += 1
	# the ring of chain spinning round the strike (two loops, crossed)
	var spin := _t * 4.0
	var grow := clampf((_t - SHOOT) / SHOOT, 0.0, 1.0)
	for loop in 2:
		var tilt := Basis(Vector3.RIGHT, 0.35 if loop == 0 else -0.5) * Basis(Vector3.FORWARD, 0.0 if loop == 0 else 1.1)
		for k in RING_LINKS:
			if fade <= 0.0 or grow <= 0.0:
				_place(i, hidden, hidden)
				i += 1
				continue
			var ang := TAU * k / RING_LINKS + spin * (1.0 if loop == 0 else -1.0)
			var r := RING_RADIUS * grow
			var pos := _center + tilt * Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			var tangent := tilt * Vector3(-sin(ang), 0.0, cos(ang))
			var basis := Basis.looking_at(tangent, Vector3.UP) * Basis(Vector3.FORWARD, PI * 0.5 * (k % 2))
			basis = (basis * Basis.from_scale(Vector3(1.0, 1.0, 1.7) * thick))
			_place(i, Transform3D(basis, pos), Transform3D((basis * Basis.from_scale(Vector3.ONE * 1.6)), pos))
			i += 1
	while i < _core.instance_count:
		_place(i, hidden, hidden)
		i += 1


func _place(i: int, core: Transform3D, glow: Transform3D) -> void:
	if i < _core.instance_count:
		_core.set_instance_transform(i, core)
		_glow.set_instance_transform(i, glow)
