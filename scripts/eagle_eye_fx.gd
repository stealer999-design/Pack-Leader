class_name EagleEyeFX
extends Node3D
## Eagle Eye's look (in the style of the other archer spells; the user asked
## for an orange ring glowing and growing out from the bird): a golden sigil
## (MarkFX's) flares over the bird and "EAGLE EYE!" pops up, a glowing orange
## ring races out over the ground to the buff's reach with a fainter one
## behind it, and each pet it passes flares with a golden starburst as the
## buff takes hold.

const GROW := 0.65  ## Seconds for the ring to reach its full size.
const FADE := 0.3
const GOLD := Color(1.0, 0.55, 0.1)
const PALE := Color(1.0, 0.93, 0.65)

static var _ring_shader: Shader
static var _burst_shader: Shader

var _center := Vector3.ZERO
var _radius := 6.0
var _allies: PackedVector3Array
var _done: Array = []
var _rings: Array = []  ## [material, delay, width]
var _ring_nodes: Array = []
var _t := 0.0


## From `center` (the bird, on the ground) out to `radius`, flaring on each of `allies`.
static func play(parent: Node3D, center: Vector3, radius: float, allies: PackedVector3Array) -> void:
	if _ring_shader == null:
		_ring_shader = load("res://scripts/ring_wave.gdshader")
		_burst_shader = load("res://scripts/starburst.gdshader")
	var fx := EagleEyeFX.new()
	fx._center = center
	fx._radius = radius
	fx._allies = allies
	fx._done.resize(allies.size())
	fx._done.fill(false)
	parent.add_child(fx)
	fx._build()


func _build() -> void:
	for spec in [[0.0, 0.035], [0.14, 0.02]]:  # the ring, and a thinner one following it
		var mat := ShaderMaterial.new()
		mat.shader = _ring_shader
		mat.set_shader_parameter("width", spec[1])
		mat.set_shader_parameter("progress", 0.0)
		mat.set_shader_parameter("glow", GOLD)
		mat.set_shader_parameter("core", PALE)
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * _radius * 2.0
		var ring := MeshInstance3D.new()
		ring.mesh = plane
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		ring.top_level = true
		ring.global_position = _center + Vector3.UP * (0.06 + 0.01 * _rings.size())
		_rings.append([mat, spec[0]])
	# the sigil over the bird, in gold
	var sig_mat := MarkFX._material(0, GOLD, PALE)
	var sigil := MarkFX._quad(sig_mat)
	add_child(sigil)
	sigil.top_level = true
	sigil.global_position = _center + Vector3.UP * 1.9
	sigil.scale = Vector3.ONE * 0.4
	var st := sigil.create_tween().set_parallel()
	st.tween_property(sigil, "scale", Vector3.ONE * 1.6, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	st.tween_method(func(v: float) -> void: sig_mat.set_shader_parameter("spin", v), 0.0, 1.4, 1.1)
	st.tween_method(func(v: float) -> void: sig_mat.set_shader_parameter("fade", v), 0.0, 1.0, 0.12)
	st.tween_method(func(v: float) -> void: sig_mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.35).set_delay(0.75)
	# the call-out
	var label := Label3D.new()
	label.text = "EAGLE EYE!"
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.008
	label.modulate = Color(1.0, 0.75, 0.3)
	label.outline_modulate = Color(0.25, 0.08, 0.0, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	add_child(label)
	label.top_level = true
	label.global_position = _center + Vector3.UP * 3.0
	label.scale = Vector3.ONE * 0.6
	var lt := label.create_tween()
	lt.tween_property(label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_interval(0.7)
	lt.set_parallel()
	lt.tween_property(label, "position:y", label.position.y + 0.6, 0.5)
	lt.tween_property(label, "modulate:a", 0.0, 0.5)
	lt.tween_property(label, "outline_modulate:a", 0.0, 0.5)


func _process(delta: float) -> void:
	_t += delta
	for r in _rings:
		var mat: ShaderMaterial = r[0]
		var s := clampf((_t - r[1]) / GROW, 0.0, 1.0)
		s = 1.0 - pow(1.0 - s, 2.2)  # fast out of the bird, easing as it reaches its edge
		mat.set_shader_parameter("progress", s * 0.97)
		var fade := 1.0 - clampf((_t - r[1] - GROW) / FADE, 0.0, 1.0)
		mat.set_shader_parameter("fade", fade * (1.0 if r[1] == 0.0 else 0.6) * clampf((_t - r[1]) / 0.05, 0.0, 1.0))
	# flare on each pet as the leading ring reaches it
	var reached := (1.0 - pow(1.0 - clampf(_t / GROW, 0.0, 1.0), 2.2)) * _radius * 0.97
	for k in _allies.size():
		var flat := Vector2(_allies[k].x - _center.x, _allies[k].z - _center.z).length()
		if not _done[k] and reached >= flat:
			_done[k] = true
			_flare(_allies[k])
	if _t > GROW + FADE + 0.9:
		queue_free()


func _flare(at: Vector3) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _burst_shader
	mat.set_shader_parameter("seed", randf() * 100.0)
	mat.set_shader_parameter("hot", PALE)
	mat.set_shader_parameter("warm", GOLD)
	var star := MarkFX._quad(mat)
	add_child(star)
	star.top_level = true
	star.global_position = at + Vector3.UP * 0.7
	star.scale = Vector3.ONE * 0.3
	var tw := star.create_tween().set_parallel()
	tw.tween_property(star, "scale", Vector3.ONE * 1.8, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(star, "global_position:y", at.y + 1.3, 0.5)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.4).set_delay(0.1)
