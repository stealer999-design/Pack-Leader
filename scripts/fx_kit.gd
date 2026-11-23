class_name FXKit
## Shared building blocks for the pets' ability looks (HolyFX for the dogs, SwampFX
## for the lizards): flat rune circles, ground rings, starburst flashes, pillars of
## light, rising sparkles, mist, ground pools, ribbons and call-outs. Every piece
## is added to `parent` (top level, world space) and frees itself when done.

static var _pool_shader: Shader
static var _dome_shader: Shader


static func glow(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _mesh(parent: Node, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.top_level = true
	return m


static func _free_after(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(node): node.queue_free())


## A rune circle (MarkFX's sigil) lying on the ground: grows in, turns, holds for
## `duration`, fades. `pulse` makes it breathe.
static func sigil(parent: Node, at: Vector3, size: float, glow_c: Color, core: Color, duration: float, spin := 1.0, alpha := 1.0, pulse := 0.0) -> MeshInstance3D:
	var mat := MarkFX._material(0, glow_c, core)
	mat.set_shader_parameter("lie_flat", true)
	var q := QuadMesh.new(); q.size = Vector2.ONE
	var m := _mesh(parent, q, mat)
	m.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), at + Vector3.UP * 0.06)
	m.scale = Vector3.ONE * size * 0.2
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3.ONE * size, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("spin", v), 0.0, spin * duration, duration + 0.4)
	tw.tween_method(func(v: float) -> void:
		var p := 1.0 - pulse * 0.5 * (1.0 + sin(v * 5.0))
		mat.set_shader_parameter("fade", alpha * p * clampf(v / 0.15, 0.0, 1.0) * clampf((duration + 0.4 - v) / 0.4, 0.0, 1.0)), 0.0, duration + 0.4, duration + 0.4)
	_free_after(m, duration + 0.5)
	return m


## A ring racing out over the ground to `radius` (ring_wave.gdshader).
static func ring(parent: Node, at: Vector3, radius: float, color: Color, core: Color, life := 0.5, width := 0.04, delay := 0.0) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/ring_wave.gdshader")
	mat.set_shader_parameter("width", width); mat.set_shader_parameter("glow", color); mat.set_shader_parameter("core", core)
	mat.set_shader_parameter("progress", 0.0); mat.set_shader_parameter("fade", 0.0)
	var plane := PlaneMesh.new(); plane.size = Vector2.ONE * radius * 2.1
	var m := _mesh(parent, plane, mat)
	m.global_position = at + Vector3.UP * 0.07
	var tw := m.create_tween()
	tw.tween_interval(delay)
	tw.set_parallel()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.05, 0.95, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, life)
	_free_after(m, delay + life + 0.05)


## A spiky flash of light, facing the camera (starburst.gdshader).
static func flash(parent: Node, at: Vector3, size: float, hot: Color, warm: Color, life := 0.4, delay := 0.0) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/starburst.gdshader")
	mat.set_shader_parameter("seed", randf() * 100.0); mat.set_shader_parameter("hot", hot); mat.set_shader_parameter("warm", warm)
	mat.set_shader_parameter("fade", 0.0)
	var q := QuadMesh.new(); q.size = Vector2.ONE
	var m := _mesh(parent, q, mat)
	m.global_position = at
	m.scale = Vector3.ONE * size * 0.25
	var tw := m.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: mat.set_shader_parameter("fade", 1.0))
	tw.set_parallel()
	tw.tween_property(m, "scale", Vector3.ONE * size, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, life).set_delay(0.06)
	_free_after(m, delay + life + 0.2)


## A column of light from the ground up (three nested see-through cylinders).
static func pillar(parent: Node, at: Vector3, radius: float, height: float, color: Color, core: Color, life := 0.8, grow := 0.12) -> void:
	var holder := Node3D.new(); parent.add_child(holder); holder.top_level = true
	holder.global_position = at
	var mats: Array[StandardMaterial3D] = []
	for layer in [[1.0, color, 0.22], [0.55, color, 0.4], [0.18, core, 0.85]]:
		var c := CylinderMesh.new(); c.top_radius = radius * layer[0] * 0.8; c.bottom_radius = radius * layer[0]; c.height = height
		c.radial_segments = 20; c.rings = 1; c.cap_top = false; c.cap_bottom = false
		var mat := glow(Color(layer[1], layer[2]))
		var m := MeshInstance3D.new(); m.mesh = c; m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position.y = height * 0.5
		holder.add_child(m); mats.append(mat)
	holder.scale = Vector3(0.2, 0.05, 0.2)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector3.ONE, grow).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(life - grow - 0.35, 0.0))
	tw.set_parallel()
	tw.tween_property(holder, "scale", Vector3(0.05, 1.0, 0.05), 0.35)
	for mat in mats:
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	_free_after(holder, life + 0.1)


## Sparkles (little glowing quads) given off over `duration` from a disc (or, with
## `rim`, the edge of it) of `radius`, drifting up at `rise`.
static func sparkles(parent: Node, at: Vector3, radius: float, color: Color, duration: float, per_second := 30.0, rise := 1.5, size := 0.08, rim := false, life := 1.2, spread := 15.0, gravity := 0.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var dot := QuadMesh.new(); dot.size = Vector2.ONE * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = FrostFX.puff_texture()
	dot.material = mat; p.mesh = dot
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = maxi(int(per_second * life), 4)
	p.lifetime = life
	p.one_shot = duration <= 0.0
	p.explosiveness = 0.9 if duration <= 0.0 else 0.0
	if rim:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP; p.emission_ring_radius = radius; p.emission_ring_inner_radius = radius * 0.92; p.emission_ring_height = 0.05
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius
	p.direction = Vector3.UP; p.spread = spread
	p.initial_velocity_min = rise * 0.6; p.initial_velocity_max = rise * 1.2
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = 0.6; p.scale_amount_max = 1.5
	var ramp := Gradient.new(); ramp.set_color(0, Color(color, 0.0)); ramp.add_point(0.15, color); ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	parent.add_child(p); p.top_level = true
	p.global_position = at
	p.emitting = true
	if duration > 0.0:
		p.get_tree().create_timer(duration).timeout.connect(func() -> void: if is_instance_valid(p): p.emitting = false)
	_free_after(p, maxf(duration, 0.0) + life + 0.2)
	return p


## Chunks (small boxes) flung out and falling back: mud, stone.
static func debris(parent: Node, at: Vector3, color: Color, amount := 16, speed := 4.0, size := 0.1, spread := 50.0) -> void:
	var p := CPUParticles3D.new()
	var box := BoxMesh.new(); box.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 1.0
	box.material = mat; p.mesh = box
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = amount; p.one_shot = true; p.explosiveness = 0.95; p.lifetime = 0.9
	p.direction = Vector3.UP; p.spread = spread
	p.initial_velocity_min = speed * 0.5; p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12, 0)
	p.angular_velocity_min = -300.0; p.angular_velocity_max = 300.0
	p.scale_amount_min = 0.5; p.scale_amount_max = 1.4
	parent.add_child(p); p.top_level = true
	p.global_position = at; p.emitting = true
	_free_after(p, 1.2)


## A call-out over the spot ("SANCTUARY!").
static func callout(parent: Node, at: Vector3, text: String, color: Color, outline: Color) -> void:
	var label := Label3D.new()
	label.text = text; label.font_size = 56; label.outline_size = 14; label.pixel_size = 0.008
	label.modulate = color; label.outline_modulate = outline
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test = true; label.render_priority = 2
	parent.add_child(label); label.top_level = true
	label.global_position = at; label.scale = Vector3.ONE * 0.6
	var lt := label.create_tween()
	lt.tween_property(label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_interval(0.7)
	lt.set_parallel()
	lt.tween_property(label, "position:y", label.position.y + 0.6, 0.5)
	lt.tween_property(label, "modulate:a", 0.0, 0.5)
	lt.tween_property(label, "outline_modulate:a", 0.0, 0.5)
	lt.chain().tween_callback(label.queue_free)


## A small symbol floating up off someone ("+" for a heal).
static func float_up(parent: Node, at: Vector3, text: String, color: Color, size := 72) -> void:
	var label := Label3D.new()
	label.text = text; label.font_size = size; label.outline_size = 10; label.pixel_size = 0.008
	label.modulate = color; label.outline_modulate = Color(color.darkened(0.7), 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test = true
	parent.add_child(label); label.top_level = true
	label.global_position = at
	var tw := label.create_tween().set_parallel()
	tw.tween_property(label, "global_position:y", at.y + 1.0, 0.9)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.tween_property(label, "outline_modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)


## A pool on the ground (pool.gdshader): bubbling poison, mud, spore-dust.
static func pool(parent: Node, at: Vector3, radius: float, deep: Color, light: Color, duration: float, bubbles := 1.0, swirl := 0.0, opacity := 1.0) -> MeshInstance3D:
	if _pool_shader == null:
		_pool_shader = load("res://scripts/pool.gdshader")
	var mat := ShaderMaterial.new(); mat.shader = _pool_shader
	mat.set_shader_parameter("deep", deep); mat.set_shader_parameter("light", light)
	mat.set_shader_parameter("bubbles", bubbles); mat.set_shader_parameter("swirl", swirl)
	mat.set_shader_parameter("seed", randf() * 50.0); mat.set_shader_parameter("fade", 0.0); mat.set_shader_parameter("opacity", opacity)
	var plane := PlaneMesh.new(); plane.size = Vector2.ONE * radius * 2.0
	var m := _mesh(parent, plane, mat)
	m.global_position = at + Vector3.UP * 0.05
	m.scale = Vector3(0.2, 1, 0.2)
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 0.0, 1.0, 0.2)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.5).set_delay(maxf(duration - 0.5, 0.2))
	_free_after(m, duration + 0.1)
	return m


## A see-through dome (hex_dome.gdshader) over `radius`, rising and fading.
static func dome(parent: Node, at: Vector3, radius: float, color: Color, life := 1.4) -> void:
	if _dome_shader == null:
		_dome_shader = load("res://scripts/hex_dome.gdshader")
	var mat := ShaderMaterial.new(); mat.shader = _dome_shader
	mat.set_shader_parameter("tint", color); mat.set_shader_parameter("fade", 0.0)
	var s := SphereMesh.new(); s.radius = 1.0; s.height = 2.0; s.is_hemisphere = true; s.radial_segments = 48; s.rings = 16
	var m := _mesh(parent, s, mat)
	m.global_position = at
	m.scale = Vector3(radius, radius * 0.55, radius) * 0.3
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3(radius, radius * 0.55, radius), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 0.0, 1.0, 0.15)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.5).set_delay(maxf(life - 0.5, 0.1))
	_free_after(m, life + 0.1)


## A ribbon through `pts` facing the camera, `width` wide (tapering to `tail` at the end).
static func ribbon(im: ImmediateMesh, pts: Array, eye: Vector3, width: float, color: Color, tail := 1.0) -> void:
	if pts.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var along: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := along.cross(eye - p).normalized()
		var w := width * lerpf(1.0, tail, float(i) / (n - 1))
		im.surface_set_color(color); im.surface_add_vertex(p + side * w * 0.5)
		im.surface_set_color(color); im.surface_add_vertex(p - side * w * 0.5)
	im.surface_end()


## A camera-facing ribbon mesh in world space, gone after `life` seconds.
static func ribbon_node(parent: Node, life := 5.0) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m := _mesh(parent, im, mat)
	m.global_transform = Transform3D.IDENTITY
	_free_after(m, life)
	return im
