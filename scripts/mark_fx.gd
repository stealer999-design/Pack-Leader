class_name MarkFX
extends Node3D
## Hunter's Mark's look (after the user's reference): an arcane sigil (a
## hexagram in a ring of runes, pale green-white) flares up beside the caster
## as it looses a red arrow, a red beam of light streaks from it to the spot,
## and where it lands red sparks burst, "HUNTER'S MARK!" pops up, and every
## enemy caught wears a red crosshair reticle (reticle()) while the mark lasts.

const RED := Color(1.0, 0.1, 0.25)
const PINK := Color(1.0, 0.62, 0.7)
const SIGIL_TIME := 1.1
const BEAM_HOLD := 0.25
const BEAM_FADE := 0.3

static var _shader: Shader


static func _material(kind: int, glow: Color, core: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://scripts/hunters_mark.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("glow", glow)
	mat.set_shader_parameter("core", core)
	return mat


static func _quad(mat: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func _glowing(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## The cast: the sigil by the caster (`from`, its bow), the beam to `to`
## reaching it in `travel` seconds, then the burst there over `radius`.
static func cast(parent: Node3D, from: Vector3, to: Vector3, travel: float, radius: float) -> void:
	var fx := MarkFX.new()
	parent.add_child(fx)
	fx._sigil(from, to)
	fx._beam(from, to, travel)
	fx.get_tree().create_timer(travel).timeout.connect(fx._impact.bind(to, radius))
	fx.get_tree().create_timer(maxf(SIGIL_TIME, travel + BEAM_HOLD + BEAM_FADE) + 1.4).timeout.connect(fx.queue_free)


func _sigil(from: Vector3, to: Vector3) -> void:
	var back := from - to
	back.y = 0.0
	back = back.normalized() * 0.5 if back.length() > 0.1 else Vector3.ZERO
	var mat := _material(0, Color(0.3, 1.0, 0.45), Color(0.92, 1.0, 0.9))
	var sigil := _quad(mat)
	add_child(sigil)
	sigil.global_position = from + back + Vector3.UP * 0.9
	sigil.scale = Vector3.ONE * 0.4
	var tween := sigil.create_tween().set_parallel()
	tween.tween_property(sigil, "scale", Vector3.ONE * 1.7, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("spin", v), 0.0, 1.6, SIGIL_TIME)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 0.0, 1.0, 0.15)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.35).set_delay(SIGIL_TIME - 0.35)


## A beam of red light from the bow to the spot, racing out with the arrow,
## holding a moment, then fading.
func _beam(from: Vector3, to: Vector3, travel: float) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var holder := Node3D.new()
	add_child(holder)
	var dir := (to - from) / length
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	holder.global_transform = Transform3D(Basis(side, dir, side.cross(dir)), from)
	var mats: Array[StandardMaterial3D] = []
	for layer in [[0.035, PINK, 1.0], [0.1, RED, 0.65], [0.22, RED, 0.2]]:  # white-hot core, red glow, a wide faint haze
		var tube := CylinderMesh.new()
		tube.top_radius = layer[0]
		tube.bottom_radius = layer[0]
		tube.height = length
		tube.radial_segments = 8
		tube.rings = 1
		var m := MeshInstance3D.new()
		m.mesh = tube
		var mat := _glowing(Color(layer[1], layer[2]))
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position.y = length * 0.5
		holder.add_child(m)
		mats.append(mat)
	holder.scale = Vector3(1, 0.001, 1)
	var tween := holder.create_tween()
	tween.tween_property(holder, "scale:y", 1.0, travel)
	tween.tween_interval(BEAM_HOLD)
	tween.set_parallel()
	for mat in mats:
		tween.tween_property(mat, "albedo_color:a", 0.0, BEAM_FADE)
	tween.tween_property(holder, "scale", Vector3(0.2, 1, 0.2), BEAM_FADE)


func _impact(at: Vector3, radius: float) -> void:
	# a spray of red sparks
	var sparks := CPUParticles3D.new()
	var dot := QuadMesh.new()
	dot.size = Vector2(0.09, 0.09)
	var smat := _glowing(Color(1.0, 1.0, 1.0))
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.vertex_color_use_as_albedo = true
	dot.material = smat
	sparks.mesh = dot
	sparks.amount = 40
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.lifetime = 0.6
	sparks.direction = Vector3.UP
	sparks.spread = 80.0
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 6.0
	sparks.gravity = Vector3(0, -7, 0)
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.7, 0.7, 1.0))
	ramp.set_color(1, Color(1.0, 0.1, 0.2, 0.0))
	sparks.color_ramp = ramp
	add_child(sparks)
	sparks.global_position = at
	sparks.emitting = true
	# a red flash on the ground, spreading over the marked area
	var ring := MeshInstance3D.new()
	var disc := TorusMesh.new()
	disc.inner_radius = 0.965
	disc.outer_radius = 1.0
	disc.rings = 48
	ring.mesh = disc
	var rmat := _glowing(Color(RED, 0.7))
	ring.material_override = rmat
	add_child(ring)
	ring.global_position = Vector3(at.x, at.y - 0.45, at.z)
	ring.scale = Vector3.ONE * 0.2
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(radius, 0.3, radius), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(rmat, "albedo_color:a", 0.0, 0.35).set_delay(0.15)
	# the call-out
	var label := Label3D.new()
	label.text = "HUNTER'S MARK!"
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.008
	label.modulate = Color(1.0, 0.35, 0.4)
	label.outline_modulate = Color(0.2, 0.0, 0.02, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	add_child(label)
	label.global_position = at + Vector3.UP * 2.2
	label.scale = Vector3.ONE * 0.6
	var lt := label.create_tween()
	lt.tween_property(label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_interval(0.6)
	lt.set_parallel()
	lt.tween_property(label, "position:y", label.position.y + 0.6, 0.5)
	lt.tween_property(label, "modulate:a", 0.0, 0.5)
	lt.tween_property(label, "outline_modulate:a", 0.0, 0.5)


## The red crosshair over a marked creature, `size` across at `height`, for
## `duration` seconds (pops in, pulses, fades out at the end).
static func reticle(creature: Node3D, duration: float, size: float, height: float) -> void:
	var old := creature.get_node_or_null("MarkReticle")
	if old:  # marked again: the new one replaces it
		old.name = "OldReticle"
		old.queue_free()
	var mat := _material(1, RED, PINK)
	var mark := _quad(mat)
	mark.name = "MarkReticle"
	creature.add_child(mark)
	mark.position = Vector3(0, height, 0)
	mark.scale = Vector3.ONE * size * 1.8
	var tween := mark.create_tween()
	tween.tween_property(mark, "scale", Vector3.ONE * size, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(duration - 0.6, 0.0))
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.4)
	tween.tween_callback(mark.queue_free)
