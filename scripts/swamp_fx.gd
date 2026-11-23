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
		"bog":  # a pool of bubbling poison, fumes rising off it
			FXKit.pool(parent, at, radius, DEEP, TOXIC, extra, 1.0, 0.4)
			FXKit.ring(parent, at, radius, TOXIC, Color(0.85, 1.0, 0.6), 0.45)
			FXKit.debris(parent, at, Color(0.2, 0.45, 0.1), 12, 3.0, 0.08)
			FXKit.sparkles(parent, at, radius * 0.85, Color(0.5, 0.9, 0.3, 0.55), extra, 25.0, 0.7, 0.45, false, 1.6, 20.0)
			FXKit.sparkles(parent, at, radius * 0.85, Color(0.8, 1.0, 0.5), extra, 20.0, 1.0, 0.07)
			FXKit.callout(parent, at + Vector3.UP * 2.2, "TOXIC BOG!", Color(0.7, 1.0, 0.45), OUTLINE)
		"spores":  # a drifting cloud of glowing spores
			FXKit.pool(parent, at, radius, Color(0.35, 0.4, 0.1), Color(0.85, 0.95, 0.4), extra, 0.0, 0.25)
			FXKit.sparkles(parent, at + Vector3.UP * 0.8, radius * 0.9, Color(0.9, 1.0, 0.45), extra, 60.0, 0.25, 0.1, false, 2.0, 180.0)
			FXKit.sparkles(parent, at + Vector3.UP * 0.6, radius * 0.8, Color(0.65, 0.8, 0.3, 0.45), extra, 18.0, 0.3, 0.7, false, 2.2, 180.0)
			FrostFX._mist(parent, at + Vector3.UP * 0.4, 12, 1.6, Color(0.75, 0.85, 0.35, 0.55), radius * 0.6, 1.4)
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
			FXKit.ribbon(im, pts, cam.global_position, 0.14, TONGUE, 0.7)
		else:
			tip.visible = false
	var driver := Timer.new(); driver.wait_time = 1.0 / 60.0; driver.autostart = true; node.add_child(driver)
	driver.timeout.connect(func() -> void: tick.call(driver.wait_time))
	FXKit.sparkles(parent, to + Vector3.UP * 0.3, 0.3, TOXIC, 0.0, 20.0, 2.0, 0.08, false, 0.5, 70.0, -6.0)
	if fangs:
		parent.get_tree().create_timer(0.3).timeout.connect(func() -> void: _snap(parent, near + Vector3.UP * 0.5, cam))
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
