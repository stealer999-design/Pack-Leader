class_name SwampFX
## The lizards' ability looks: swamp venomancers in toxic green, sickly purple
## and murky brown, with bubbles, drips, fumes and spores. SwampFX.play() is
## called on every peer (World.play_pet_fx) with the spell's look.

const TOXIC := Color(0.45, 1.0, 0.25)
const DEEP := Color(0.1, 0.32, 0.06)
const PURPLE := Color(0.7, 0.3, 1.0)
const ROT := Color(0.55, 0.85, 0.35)
const MUD := Color(0.36, 0.25, 0.13)
const MUD_LIGHT := Color(0.6, 0.47, 0.28)
const TONGUE := Color(0.95, 0.4, 0.5)
const OUTLINE := Color(0.05, 0.15, 0.02, 0.9)


## `from` the lizard's mouth, `at` the spot (or target), `extra` a duration (a
## cloud's) or a flight time (a spit's); `pts` enemies or allies touched.
static func play(parent: Node3D, look: String, at: Vector3, from: Vector3, radius: float, extra: float,
		allies: PackedVector3Array, enemies: PackedVector3Array) -> void:
	match look:
		"lash", "fang":
			_tongue(parent, from, at, look == "fang")
		"wither", "soul_rot":
			_spit(parent, from, at, radius, extra, look == "soul_rot")
		"bog":  # after the user's reference: a dark bubbling swamp ringed with glowing purple
			# mushrooms and thorny roots, glossy bubbles swelling and popping, a toxic cloud over it
			FXKit.pool(parent, at, radius, Color(0.02, 0.09, 0.03), Color(0.16, 0.5, 0.1), extra, 1.4, 0.03, 0.97)
			FXKit.ring(parent, at, radius, TOXIC, Color(0.85, 1.0, 0.6), 0.45)
			FXKit.debris(parent, at, Color(0.15, 0.4, 0.08), 14, 3.5, 0.09)
			_bog_rim(parent, at, radius, extra)
			_bog_bubbles(parent, at, radius, extra)
			_fumes(parent, at, radius, Color(0.5, 1.0, 0.3, 0.5), extra, 3.0, 0.25, 2.0)
			FXKit.sparkles(parent, at + Vector3.UP * 0.4, radius * 0.85, Color(0.75, 1.0, 0.45), extra, 30.0, 1.2, 0.12)
			FXKit.callout(parent, at + Vector3.UP * 2.6, "TOXIC BOG!", Color(0.7, 1.0, 0.45), OUTLINE)
		"spores":  # a drifting cloud of glowing spores
			FXKit.pool(parent, at, radius, Color(0.45, 0.5, 0.15), Color(0.85, 0.95, 0.45), extra, 0.0, 0.04, 0.5)
			FXKit.sparkles(parent, at + Vector3.UP * 0.8, radius * 0.9, Color(0.9, 1.0, 0.45), extra, 60.0, 0.25, 0.1, false, 2.0, 180.0)
			_fumes(parent, at, radius, Color(0.8, 0.9, 0.4, 0.5), extra)
			FXKit.callout(parent, at + Vector3.UP * 2.4, "SPORE CLOUD!", Color(0.9, 1.0, 0.5), OUTLINE)
		"haze":  # a burst of toxic gas rolling outward
			FXKit.flash(parent, at + Vector3.UP * 0.5, 3.0, Color(0.85, 1.0, 0.6), TOXIC, 0.4)
			FXKit.ring(parent, at, radius, TOXIC, Color(0.85, 1.0, 0.6), 0.55, 0.06)
			FXKit.ring(parent, at, radius * 0.8, Color(0.3, 0.7, 0.15), TOXIC, 0.7, 0.03, 0.1)
			FrostFX._mist(parent, at + Vector3.UP * 0.4, 20, 1.6, Color(0.45, 0.85, 0.25, 0.6), radius * 0.95, 1.2)
			FXKit.sparkles(parent, at + Vector3.UP * 0.4, 0.6, Color(0.7, 1.0, 0.4), 0.0, 50.0, 6.0, 0.1, false, 0.8, 85.0)
			for e in enemies:
				FXKit.float_up(parent, e + Vector3.UP * 1.4, "☠", TOXIC, 56)
			FXKit.callout(parent, at + Vector3.UP * 2.4, "TOXIC HAZE!", Color(0.7, 1.0, 0.45), OUTLINE)
		"plague":  # plague spores burst out; green motes heal the lizard's side
			FXKit.flash(parent, at + Vector3.UP * 0.5, 3.0, Color(0.9, 0.7, 1.0), PURPLE, 0.4)
			FXKit.ring(parent, at, radius, PURPLE, Color(0.9, 0.75, 1.0), 0.6, 0.05)
			FXKit.sparkles(parent, at + Vector3.UP * 0.5, 0.6, Color(0.8, 0.45, 1.0), 0.0, 70.0, 5.0, 0.12, false, 1.3, 85.0, -0.5)
			FrostFX._mist(parent, at + Vector3.UP * 0.4, 12, 1.4, Color(0.6, 0.35, 0.8, 0.5), radius * 0.8, 1.2)
			for a in allies:
				FXKit.sparkles(parent, a + Vector3.UP * 0.4, 0.4, Color(0.6, 1.0, 0.5), 0.0, 20.0, 1.5, 0.1, false, 1.0, 30.0)
				FXKit.float_up(parent, a + Vector3.UP * 1.3, "+", Color(0.6, 1.0, 0.5))
			FXKit.callout(parent, at + Vector3.UP * 2.4, "PLAGUE SPORES!", Color(0.85, 0.65, 1.0), Color(0.15, 0.02, 0.2, 0.9))
		"mud_spring", "spirit_spring":
			var spirit := look == "spirit_spring"
			var c := PURPLE if spirit else MUD_LIGHT
			if spirit:
				FXKit.flash(parent, at + Vector3.UP * 0.5, 3.0, Color(0.9, 0.8, 1.0), PURPLE, 0.4)
				FXKit.sparkles(parent, at, radius * 0.7, Color(0.75, 0.6, 1.0, 0.8), 0.0, 40.0, 2.5, 0.25, false, 1.2, 25.0)
			else:
				FXKit.debris(parent, at, MUD, 26, 5.5, 0.12)
				FrostFX._mist(parent, at + Vector3.UP * 0.3, 10, 1.4, Color(MUD_LIGHT, 0.6), radius * 0.7, 1.0)
			FXKit.ring(parent, at, radius, c, c.lightened(0.4), 0.45, 0.06)
			for e in enemies:
				_roots(parent, e, extra, spirit)
			FXKit.callout(parent, at + Vector3.UP * 2.2, "SPIRIT TRAP!" if spirit else "MUD TRAP!",
					Color(0.85, 0.7, 1.0) if spirit else Color(0.9, 0.75, 0.5), Color(0.1, 0.05, 0.02, 0.9))


## A trap lying in wait: a half-hidden mud puddle, or a faint ghostly rune.
static func trap(holder: Node3D, at: Vector3, radius: float, look: String) -> void:
	if look == "spirit":
		FXKit.sigil(holder, at, radius * 2.2, Color(0.6, 0.35, 1.0), Color(0.85, 0.75, 1.0), 600.0, 0.3, 0.45, 0.4)
	else:
		FXKit.pool(holder, at, radius, Color(0.25, 0.17, 0.08), Color(0.48, 0.36, 0.2), 600.0, 0.4, 0.1)


## Roots (or spectral tendrils) bursting up round a caught enemy and gripping it.
static func _roots(parent: Node3D, at: Vector3, hold: float, spirit: bool) -> void:
	var mat := FXKit.glow(Color(0.75, 0.55, 1.0, 0.75)) if spirit else StandardMaterial3D.new()
	if not spirit:
		mat.albedo_color = Color(0.32, 0.22, 0.11); mat.roughness = 1.0
	for k in 6:
		var a := TAU * k / 6.0 + randf_range(-0.3, 0.3)
		var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = 0.07; c.height = 1.0; c.radial_segments = 5; c.rings = 1
		var m := MeshInstance3D.new(); m.mesh = c; m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(m); m.top_level = true
		var base := at + Vector3(cos(a), 0, sin(a)) * 0.55
		var lean := (at + Vector3.UP * 0.9 - base).normalized()
		var basis := Basis.looking_at(lean, Vector3.FORWARD if absf(lean.y) > 0.95 else Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2.0)
		var tall := randf_range(0.8, 1.2)
		var grown := Transform3D(basis.scaled(Vector3(1, tall, 1)), base + lean * tall * 0.5)
		var sunk := Transform3D(basis.scaled(Vector3(1, 0.02, 1)), base)
		m.global_transform = sunk
		var tw := m.create_tween()
		tw.tween_interval(0.03 * k)
		tw.tween_property(m, "global_transform", grown, 0.15).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(hold - 0.4, 0.2))
		tw.tween_property(m, "global_transform", sunk, 0.3).set_ease(Tween.EASE_IN)
		tw.tween_callback(m.queue_free)


## The tongue: whips out to the target and reels it in; Swamp Fang adds a snap of fangs.
static func _tongue(parent: Node3D, from: Vector3, to: Vector3, fangs: bool) -> void:
	var node := Node3D.new(); parent.add_child(node)
	var im := FXKit.ribbon_node(node, 1.0)
	var tip := MeshInstance3D.new(); var ball := SphereMesh.new(); ball.radius = 0.12; ball.height = 0.24
	tip.mesh = ball; tip.material_override = FXKit.glow(TONGUE.lightened(0.2)); tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(tip); tip.top_level = true
	var dir := (to - from); dir.y = 0.0
	var near := from + dir.normalized() * 1.0 if dir.length() > 0.1 else from
	var t := [0.0]
	var cam := parent.get_viewport().get_camera_3d()
	var tick := func(delta: float) -> void:
		t[0] += delta
		var out := clampf(t[0] / 0.09, 0.0, 1.0)  # whips out...
		var back := clampf((t[0] - 0.12) / 0.2, 0.0, 1.0)  # ...and reels the target in
		var tip_at: Vector3 = from.lerp(to, out).lerp(near, back)
		tip.global_position = tip_at
		im.clear_surfaces()
		if cam and t[0] < 0.4:
			var pts: Array = []
			for i in 10:
				var u := float(i) / 9.0
				pts.append(from.lerp(tip_at, u) + Vector3.UP * 0.15 * sin(PI * u) * (1.0 - back))
			FXKit.ribbon(im, pts, cam.global_position, 0.24, TONGUE, 0.6)
		else:
			tip.visible = false
	var driver := Timer.new(); driver.wait_time = 1.0 / 60.0; driver.autostart = true; node.add_child(driver)
	driver.timeout.connect(func() -> void: tick.call(driver.wait_time))
	FXKit.sparkles(parent, to + Vector3.UP * 0.3, 0.3, TOXIC, 0.0, 20.0, 2.0, 0.08, false, 0.5, 70.0, -6.0)
	if fangs:
		parent.get_tree().create_timer(0.3).timeout.connect(func() -> void: _snap(parent, near + Vector3.UP * 0.5, cam))
	else:
		FXKit.callout(parent, to + Vector3.UP * 1.6, "VENOM LASH!", Color(1.0, 0.6, 0.7), OUTLINE)
	parent.get_tree().create_timer(1.0).timeout.connect(node.queue_free)


## Two great fangs snapping shut, and a splash of venom.
static func _snap(parent: Node3D, at: Vector3, cam: Camera3D) -> void:
	var up := cam.global_basis.y if cam else Vector3.UP
	var mat := FXKit.glow(Color(1.0, 1.0, 0.95, 0.95))
	for side in [1.0, -1.0]:
		var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = 0.13; c.height = 0.6; c.radial_segments = 6; c.rings = 1
		var m := MeshInstance3D.new(); m.mesh = c; m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(m); m.top_level = true
		var open_at: Vector3 = at + up * 0.7 * side
		m.global_transform = Transform3D(Basis(Vector3.RIGHT, PI) if side > 0 else Basis.IDENTITY, open_at)  # (upper fang points down)
		var tw := m.create_tween()
		tw.tween_property(m, "global_position", at + up * 0.18 * side, 0.08).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.15)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.2)
		tw.tween_callback(m.queue_free)
	parent.get_tree().create_timer(0.08).timeout.connect(func() -> void:
		FXKit.flash(parent, at, 1.6, Color(0.85, 1.0, 0.6), TOXIC, 0.35)
		FXKit.sparkles(parent, at, 0.3, TOXIC, 0.0, 40.0, 3.5, 0.1, false, 0.6, 80.0, -8.0)
		FXKit.callout(parent, at + Vector3.UP * 1.6, "SWAMP FANG!", Color(0.7, 1.0, 0.45), OUTLINE))


## A glob of venom arcing to the spot, splatting into a withering pool; a wisp of
## stolen life floats back to the lizard. Soul Rot is purple, with a skull.
static func _spit(parent: Node3D, from: Vector3, to: Vector3, radius: float, travel: float, rot: bool) -> void:
	var c := Color(0.75, 0.45, 1.0) if rot else TOXIC
	var deep := Color(0.25, 0.08, 0.35) if rot else DEEP
	var glob := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 0.2; s.height = 0.4
	glob.mesh = s; glob.material_override = FXKit.glow(c.lightened(0.2)); glob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glob); glob.top_level = true; glob.global_position = from
	var trail := FXKit.sparkles(parent, from, 0.1, c, travel, 60.0, 0.0, 0.12, false, 0.35, 180.0, -3.0)
	var tw := glob.create_tween()
	tw.tween_method(func(u: float) -> void:
		var p := from.lerp(to, u) + Vector3.UP * 1.2 * 4.0 * u * (1.0 - u)
		glob.global_position = p
		if is_instance_valid(trail): trail.global_position = p, 0.0, 1.0, maxf(travel, 0.1))
	tw.tween_callback(func() -> void:
		glob.queue_free()
		FXKit.flash(parent, to + Vector3.UP * 0.3, 2.2, c.lightened(0.5), c, 0.35)
		FXKit.pool(parent, to, radius * 1.2, deep, c, 1.6, 0.6)
		FXKit.debris(parent, to, c.darkened(0.3), 10, 3.5, 0.08)
		FrostFX._mist(parent, to + Vector3.UP * 0.3, 7, 1.0, Color(0.55, 0.5, 0.6, 0.55) if rot else Color(0.55, 0.65, 0.45, 0.55), 0.9, 1.2)
		if rot:
			FXKit.float_up(parent, to + Vector3.UP * 0.9, "☠", Color(0.85, 0.7, 1.0), 96)
		_drain(parent, to + Vector3.UP * 0.6, from, c)
		FXKit.callout(parent, to + Vector3.UP * 2.0, "SOUL ROT!" if rot else "WITHER!", c.lightened(0.3), OUTLINE))


## A wisp of stolen life floating back to the caster.
static func _drain(parent: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	var p := FXKit.sparkles(parent, from, 0.15, color.lightened(0.3), 0.5, 50.0, 0.1, 0.12, false, 0.4, 180.0)
	var tw := p.create_tween()
	tw.tween_interval(0.15)
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(p): p.global_position = from.lerp(to, u) + Vector3.UP * 0.8 * sin(PI * u), 0.0, 1.0, 0.5)
	tw.tween_callback(func() -> void: FXKit.flash(parent, to, 1.0, Color(0.85, 1.0, 0.8), Color(0.5, 1.0, 0.5), 0.3))


## Fumes rising off a pool for `duration`: soft puffs (FrostFX._mist) every so often.
static func _fumes(parent: Node3D, at: Vector3, radius: float, color: Color, duration: float, size := 1.3, every := 0.6, high := 1.2) -> void:
	var n := int(duration / every)
	for k in n:
		parent.get_tree().create_timer(every * k).timeout.connect(func() -> void:
			var p := at + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * radius * 0.6 * sqrt(randf())
			FrostFX._mist(parent, p + Vector3.UP * randf_range(0.4, high), 3, size, color, radius * 0.3, 1.6))


## The bog's rim: glowing purple mushrooms and thorny purple roots round its edge,
## growing up out of the ground and sinking away when it dries up.
static func _bog_rim(parent: Node3D, at: Vector3, radius: float, duration: float) -> void:
	var stalk := FXKit.glow(Color(0.85, 0.8, 0.95, 1.0))
	var root_mat := StandardMaterial3D.new(); root_mat.albedo_color = Color(0.6, 0.2, 0.55); root_mat.roughness = 0.6; root_mat.emission_enabled = true; root_mat.emission = Color(0.25, 0.05, 0.25)
	var nodes: Array = []
	for k in 9:  # mushrooms in little clumps
		var a := TAU * k / 9.0 + randf_range(-0.2, 0.2)
		var base := at + Vector3(cos(a), 0, sin(a)) * radius * randf_range(0.85, 1.05)
		for j in randi_range(1, 3):
			var m := Node3D.new(); parent.add_child(m); m.top_level = true
			var h := randf_range(0.25, 0.55); var w := randf_range(0.14, 0.26)
			var st := CylinderMesh.new(); st.top_radius = w * 0.25; st.bottom_radius = w * 0.35; st.height = h; st.radial_segments = 6; st.rings = 1
			var sm := MeshInstance3D.new(); sm.mesh = st; sm.material_override = stalk; sm.position.y = h * 0.5; m.add_child(sm)
			var cap := SphereMesh.new(); cap.radius = w; cap.height = w; cap.is_hemisphere = true; cap.radial_segments = 12; cap.rings = 4
			var hue := randf_range(0.78, 0.9)
			var cm := MeshInstance3D.new(); cm.mesh = cap; cm.material_override = FXKit.glow(Color.from_hsv(hue, 0.65, 1.0, 1.0)); cm.position.y = h; m.add_child(cm)
			var halo := SphereMesh.new(); halo.radius = w * 1.8; halo.height = w * 2.0
			var gm := MeshInstance3D.new(); gm.mesh = halo; gm.material_override = FXKit.glow(Color.from_hsv(hue, 0.7, 1.0, 0.18)); gm.position.y = h; m.add_child(gm)
			for c in m.get_children(): (c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.global_position = base + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
			nodes.append(m)
	for k in 18:  # thorny roots arching out of the ground round the edge
		var a := TAU * k / 18.0 + randf_range(-0.15, 0.15)
		var base := at + Vector3(cos(a), 0, sin(a)) * radius * randf_range(0.9, 1.1)
		var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = 0.13; c.height = 1.0; c.radial_segments = 6; c.rings = 1
		var r := MeshInstance3D.new(); r.mesh = c; r.material_override = root_mat; r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var holder := Node3D.new(); parent.add_child(holder); holder.top_level = true; holder.add_child(r)
		var out := Vector3(cos(a), 0, sin(a)); var lean := (out * randf_range(-0.6, 0.5) + Vector3.UP).normalized()
		var tall := randf_range(0.7, 1.3)
		r.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(1, tall, 1)), Vector3(0, tall * 0.5, 0))
		holder.global_transform = Transform3D(Basis.looking_at(lean, out) * Basis(Vector3.RIGHT, -PI / 2.0), base)
		nodes.append(holder)
	for n in nodes:
		var node: Node3D = n
		var full := node.scale
		node.scale = Vector3(full.x, 0.02, full.z)
		var tw := node.create_tween()
		tw.tween_interval(randf_range(0.05, 0.3))
		tw.tween_property(node, "scale", full, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(maxf(duration - 0.8, 0.2))
		tw.tween_property(node, "scale", Vector3(full.x, 0.02, full.z), 0.35).set_ease(Tween.EASE_IN)
		tw.tween_callback(node.queue_free)


## Glossy green bubbles swelling up out of the bog and popping, over `duration`.
static func _bog_bubbles(parent: Node3D, at: Vector3, radius: float, duration: float) -> void:
	var n := int(duration / 0.12)
	for k in n:
		parent.get_tree().create_timer(0.12 * k + randf() * 0.1).timeout.connect(func() -> void:
			var p := at + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * radius * 0.85 * sqrt(randf())
			var size := randf_range(0.22, 0.45)
			var mat := FXKit.glow(Color(0.45, 1.0, 0.3, 0.85))
			mat.render_priority = 2  # (drawn over the pool, which is see-through too)
			var sph := SphereMesh.new(); sph.radius = 1.0; sph.height = 1.0; sph.is_hemisphere = true; sph.radial_segments = 14; sph.rings = 6
			var b := MeshInstance3D.new(); b.mesh = sph; b.material_override = mat; b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var shine := MeshInstance3D.new(); var hs := SphereMesh.new(); hs.radius = 0.25; hs.height = 0.5
			shine.mesh = hs; shine.material_override = FXKit.glow(Color(0.95, 1.0, 0.85, 0.9)); (shine.material_override as StandardMaterial3D).render_priority = 3; shine.position = Vector3(-0.35, 0.65, 0.2); b.add_child(shine)
			parent.add_child(b); b.top_level = true; b.global_position = p + Vector3.UP * 0.05
			b.scale = Vector3.ONE * 0.02
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector3.ONE * size, randf_range(0.5, 0.9)).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func() -> void:
				FXKit.sparkles(parent, p + Vector3.UP * size * 0.6, size * 0.5, Color(0.7, 1.0, 0.5), 0.0, 20.0, 1.5, 0.06, false, 0.35, 80.0, -4.0)
				b.queue_free()))
