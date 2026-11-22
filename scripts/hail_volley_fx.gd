class_name HailVolleyFX
extends Node3D
## Hail Volley's look (after the user's reference): a wave of icy arrows arcs
## up from the archer and comes crashing down across the volley's landing
## spots; where they land, spikes of ice erupt from the ground amid frost mist
## and snow, and "HAIL VOLLEY!" pops up. (The volley's real arrows, which do
## the damage, fly hidden inside the wave.)

const ARROWS := 44
const ICE := Color(0.55, 0.85, 1.0)
const WHITE := Color(0.92, 0.98, 1.0)
const SPIKES := 5  ## Ice spikes per landing spot.

static var _streak_mesh: CylinderMesh
static var _spike_mesh: CylinderMesh

var _from := Vector3.ZERO
var _arrows: Array = []  ## [end, height, delay, duration]
var _mm: MultiMesh
var _glow_mm: MultiMesh
var _t := 0.0
var _life := 2.0


## From `from` (the bow) onto each of `ends` (the landing spots, on the
## ground), the first arrows landing after `travel` seconds.
static func play(parent: Node3D, from: Vector3, ends: PackedVector3Array, travel: float) -> void:
	if _streak_mesh == null:
		_streak_mesh = CylinderMesh.new()  # a comet streak, wide at the head
		_streak_mesh.top_radius = 0.045
		_streak_mesh.bottom_radius = 0.0
		_streak_mesh.height = 1.0
		_streak_mesh.radial_segments = 6
		_streak_mesh.rings = 1
		_spike_mesh = CylinderMesh.new()  # a four-sided crystal, pointed
		_spike_mesh.top_radius = 0.0
		_spike_mesh.bottom_radius = 0.13
		_spike_mesh.height = 1.0
		_spike_mesh.radial_segments = 4
		_spike_mesh.rings = 1
	var fx := HailVolleyFX.new()
	fx._from = from
	parent.add_child(fx)
	fx._build(ends, travel)


func _build(ends: PackedVector3Array, travel: float) -> void:
	for which in 2:  # a bright icy core and a soft blue glow round each arrow
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _streak_mesh
		mm.instance_count = ARROWS
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(WHITE, 0.95) if which == 0 else Color(ICE, 0.4)
		inst.material_override = mat
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		inst.top_level = true
		inst.global_transform = Transform3D.IDENTITY
		if which == 0:
			_mm = mm
		else:
			_glow_mm = mm
	for k in ARROWS:
		var end: Vector3 = ends[k % ends.size()] + Vector3(randf_range(-0.9, 0.9), 0, randf_range(-0.9, 0.9))
		var duration := randf_range(0.32, 0.45)
		var delay := maxf(travel - duration, 0.0) + randf_range(0.0, 0.25)
		_arrows.append([end, randf_range(1.6, 2.8), delay, duration])
	for end in ends:  # the ice erupts as the first arrows land
		get_tree().create_timer(travel + 0.05).timeout.connect(_erupt.bind(end))
	var mid := Vector3.ZERO
	for end in ends:
		mid += end
	mid /= maxf(ends.size(), 1)
	get_tree().create_timer(travel + 0.05).timeout.connect(_call_out.bind(mid))
	_life = travel + 2.0
	_update()


func _process(delta: float) -> void:
	_t += delta
	_update()
	if _t > _life:
		queue_free()


func _point(a: Array, s: float) -> Vector3:
	var end: Vector3 = a[0]
	return _from.lerp(end, s) + Vector3.UP * (a[1] * 4.0 * s * (1.0 - s))


func _update() -> void:
	for k in ARROWS:
		var a: Array = _arrows[k]
		var s: float = (_t - a[2]) / a[3]
		var tf := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), _from)  # not loosed yet, or landed
		if s > 0.0 and s < 1.0:
			var head := _point(a, s)
			var back := _point(a, maxf(s - 0.12, 0.0))
			var along := head - back
			var length := along.length()
			if length > 0.01:
				var dir := along / length
				var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI / 2.0)
				tf = Transform3D(basis.scaled(Vector3(1, length, 1)), (head + back) * 0.5)
		_mm.set_instance_transform(k, tf)
		_glow_mm.set_instance_transform(k, Transform3D(tf.basis * Basis.IDENTITY.scaled(Vector3(3.0, 1.05, 3.0)), tf.origin))


## Spikes of ice bursting up out of the ground round `at`, then sinking away.
func _erupt(at: Vector3) -> void:
	for k in SPIKES:
		var a := TAU * k / SPIKES + randf_range(-0.4, 0.4)
		var lean := randf_range(0.15, 0.6)
		var dir := Vector3(cos(a) * sin(lean), cos(lean), sin(a) * sin(lean))
		var tall := randf_range(0.7, 1.4)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(WHITE.lerp(ICE, randf() * 0.8), 0.85)
		var spike := MeshInstance3D.new()
		spike.mesh = _spike_mesh
		spike.material_override = mat
		spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spike)
		spike.top_level = true
		var base := Vector3(at.x, at.y, at.z) + Vector3(cos(a), 0, sin(a)) * randf_range(0.05, 0.45)
		var basis := Basis.looking_at(dir, Vector3.FORWARD if absf(dir.y) > 0.95 else Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2.0)
		var grown := Transform3D(basis.scaled(Vector3(1, tall, 1)), base + dir * tall * 0.5)
		var sunk := Transform3D(basis.scaled(Vector3(1, 0.05, 1)), base)
		spike.global_transform = sunk
		var tw := spike.create_tween()
		tw.tween_property(spike, "global_transform", grown, 0.1).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.45 + randf() * 0.2)
		tw.set_parallel()
		tw.tween_property(spike, "global_transform", sunk, 0.4).set_ease(Tween.EASE_IN)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	FrostFX._mist(self, at + Vector3.UP * 0.2, 7, 1.0, Color(0.92, 0.97, 1.0, 0.65), 1.1, 1.1)
	add_child(FrostFX._particles(at + Vector3.UP * 0.4, 16, 1.2, Vector2(0.07, 0.07), Color(1, 1, 1, 0.95), 1.5, 4.0, -3.0, 60.0, false))


func _call_out(at: Vector3) -> void:
	var label := Label3D.new()
	label.text = "HAIL VOLLEY!"
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.008
	label.modulate = Color(0.7, 0.92, 1.0)
	label.outline_modulate = Color(0.02, 0.1, 0.25, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	add_child(label)
	label.top_level = true
	label.global_position = at + Vector3.UP * 2.4
	label.scale = Vector3.ONE * 0.6
	var lt := label.create_tween()
	lt.tween_property(label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_interval(0.6)
	lt.set_parallel()
	lt.tween_property(label, "position:y", label.position.y + 0.6, 0.5)
	lt.tween_property(label, "modulate:a", 0.0, 0.5)
	lt.tween_property(label, "outline_modulate:a", 0.0, 0.5)
