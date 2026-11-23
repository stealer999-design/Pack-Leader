class_name HolyFX
## The dogs' ability looks: holy paladins in gold, white and warm sunlight, with
## pale holy blue for protection and red for a taunt. HolyFX.play() is called on
## every peer (World.play_pet_fx) with the spell's look and where it happened.

const GOLD := Color(1.0, 0.78, 0.25)
const PALE := Color(1.0, 0.96, 0.78)
const WHITE := Color(1.0, 1.0, 0.95)
const SUN := Color(1.0, 0.55, 0.12)
const HEAL := Color(0.7, 1.0, 0.45)
const BLUE := Color(0.55, 0.8, 1.0)
const RED := Color(1.0, 0.2, 0.2)
const OUTLINE := Color(0.3, 0.15, 0.0, 0.9)


## `at` the spot, `from` where the dog started (a leap), `allies`/`enemies` the
## ones it touched.
static func play(parent: Node3D, look: String, at: Vector3, from: Vector3, radius: float, duration: float,
		allies: PackedVector3Array, enemies: PackedVector3Array) -> void:
	match look:
		"sanctuary":  # blessed ground: a turning circle of gold runes, light rising off it
			FXKit.sigil(parent, at, radius * 2.1, GOLD, PALE, duration, 0.6, 0.85, 0.15)
			FXKit.ring(parent, at, radius, GOLD, PALE, 0.5)
			FXKit.sparkles(parent, at, radius * 0.9, PALE, duration, 50.0, 1.2, 0.18)
			FXKit.sparkles(parent, at, radius, GOLD, duration, 35.0, 0.9, 0.14, true)
			FXKit.callout(parent, at + Vector3.UP * 2.2, "SANCTUARY!", PALE, OUTLINE)
		"sunlit":  # a wide disc of sunlight: runes, shafts of light from above, embers
			FXKit.sigil(parent, at, radius * 2.1, SUN, PALE, duration, 0.4, 0.9, 0.2)
			FXKit.pool(parent, at, radius * 0.95, Color(1.0, 0.6, 0.15), Color(1.0, 0.95, 0.6), duration, 0.0, 0.6, 0.35)
			FXKit.ring(parent, at, radius, SUN, PALE, 0.6)
			for k in 5:
				var p := at + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 5.0 + 0.3) * radius * randf_range(0.2, 0.7)
				FXKit.pillar(parent, p, 0.35, 6.0, Color(1.0, 0.85, 0.45), WHITE, duration, 0.3)
			FXKit.sparkles(parent, at, radius * 0.9, Color(1.0, 0.55, 0.15), duration, 40.0, 1.6, 0.15)
			for e in enemies:
				FXKit.flash(parent, e + Vector3.UP * 0.5, 1.4, WHITE, SUN, 0.35)
			FXKit.callout(parent, at + Vector3.UP * 2.4, "SUNLIT SANCTUARY!", Color(1.0, 0.85, 0.4), OUTLINE)
		"consecration":  # hallowed ground ringed with holy fire
			FXKit.sigil(parent, at, radius * 2.1, WHITE, GOLD, duration, -0.5, 0.9, 0.25)
			FXKit.ring(parent, at, radius, GOLD, WHITE, 0.5)
			FXKit.sparkles(parent, at, radius, Color(1.0, 0.6, 0.15), duration, 110.0, 2.2, 0.38, true, 0.7, 8.0)
			FXKit.sparkles(parent, at, radius, Color(1.0, 0.95, 0.7), duration, 60.0, 2.8, 0.2, true, 0.6, 5.0)
			FXKit.sparkles(parent, at, radius * 0.8, PALE, duration, 25.0, 0.8, 0.14)
			FXKit.callout(parent, at + Vector3.UP * 2.2, "CONSECRATION!", WHITE, OUTLINE)
		"blessing":  # a pillar of golden light, petals of light, a "+" off everyone healed
			FXKit.pillar(parent, at, 1.4, 9.0, GOLD, WHITE, 1.1)
			FXKit.flash(parent, at + Vector3.UP * 0.6, 4.0, WHITE, GOLD, 0.45)
			FXKit.ring(parent, at, radius, GOLD, PALE, 0.6)
			FXKit.sparkles(parent, at + Vector3.UP * 0.5, radius * 0.7, Color(1.0, 0.85, 0.6), 0.0, 60.0, 3.0, 0.12, false, 1.4, 70.0, -1.0)
			for a in allies:
				FXKit.pillar(parent, a, 0.45, 2.5, HEAL, WHITE, 0.7, 0.1)
			FXKit.callout(parent, at + Vector3.UP * 2.6, "BLESSING!", PALE, OUTLINE)
		"holy_light":  # a beam from the sky, a blinding flash, rays of light
			FXKit.pillar(parent, at, 0.9, 14.0, WHITE, WHITE, 0.6, 0.08)
			FXKit.flash(parent, at + Vector3.UP * 0.6, radius * 1.4, WHITE, GOLD, 0.5, 0.05)
			FXKit.flash(parent, at + Vector3.UP * 0.6, radius * 2.2, PALE, Color(1.0, 0.7, 0.3), 0.6, 0.1)
			FXKit.ring(parent, at, radius, GOLD, WHITE, 0.5, 0.05, 0.05)
			for e in enemies:
				FXKit.flash(parent, e + Vector3.UP * 0.7, 1.3, WHITE, GOLD, 0.4, 0.1)
			FXKit.callout(parent, at + Vector3.UP * 2.6, "HOLY LIGHT!", WHITE, OUTLINE)
		"aegis":  # a golden honeycomb dome over the allies (each gets a blue shield icon, play_shield_icons)
			FXKit.dome(parent, at, radius, Color(1.0, 0.85, 0.4), 1.6)
			FXKit.ring(parent, at, radius, GOLD, PALE, 0.5)
			FXKit.callout(parent, at + Vector3.UP * 2.6, "AEGIS!", PALE, OUTLINE)
		"shield_wall":  # tower shields slam down in a ring; a red pulse taunts
			_shield_ring(parent, at, radius, duration)
			FXKit.ring(parent, at, radius * 1.1, RED, Color(1.0, 0.7, 0.6), 0.6, 0.05, 0.25)
			FXKit.callout(parent, at + Vector3.UP * 2.6, "SHIELD WALL!", PALE, OUTLINE)
		"guardian", "challenge", "judgement":
			_leap_trail(parent, from, at)
			FXKit.ring(parent, at, 2.2, GOLD, PALE, 0.4)  # the landing
			FXKit.debris(parent, at, Color(0.75, 0.62, 0.45), 14, 4.0, 0.08)
			FXKit.ring(parent, at, radius, RED, Color(1.0, 0.7, 0.6), 0.6, 0.05, 0.15)  # the taunt
			for e in enemies:
				FXKit.float_up(parent, e + Vector3.UP * 1.6, "!", RED, 64)
			if look == "guardian":
				FXKit.dome(parent, at, 1.3, Color(1.0, 0.85, 0.4), 1.6)
				FXKit.sigil(parent, at, 3.0, GOLD, PALE, 1.2, 1.0)
				FXKit.callout(parent, at + Vector3.UP * 2.4, "GUARDIAN'S VOW!", PALE, OUTLINE)
			elif look == "challenge":
				for e in enemies:
					_claws(parent, e + Vector3.UP * 0.6)
				FXKit.callout(parent, at + Vector3.UP * 2.4, "CHALLENGE!", Color(1.0, 0.6, 0.5), OUTLINE)
			else:
				_hammer(parent, at)
				FXKit.callout(parent, at + Vector3.UP * 2.8, "JUDGEMENT!", PALE, OUTLINE)


## Tower shields of gold dropping from above into a ring, holding, sinking away.
static func _shield_ring(parent: Node3D, at: Vector3, radius: float, duration: float) -> void:
	var n := 9
	var face := FXKit.glow(Color(0.95, 0.68, 0.2, 0.92))
	var trim := FXKit.glow(Color(1.0, 0.97, 0.8, 1.0))
	var hold := minf(duration, 2.5)
	for k in n:
		var a := TAU * k / n
		var pos := at + Vector3(cos(a), 0, sin(a)) * radius
		var shield := Node3D.new(); parent.add_child(shield); shield.top_level = true
		var body := BoxMesh.new(); body.size = Vector3(1.0, 1.5, 0.14)
		var m := MeshInstance3D.new(); m.mesh = body; m.material_override = face; m.position.y = 0.75; shield.add_child(m)
		for y in [0.04, 1.46]:
			var rim := BoxMesh.new(); rim.size = Vector3(1.1, 0.12, 0.18)
			var r := MeshInstance3D.new(); r.mesh = rim; r.material_override = trim; r.position.y = y; shield.add_child(r)
		for x in [-0.5, 0.5]:
			var side := BoxMesh.new(); side.size = Vector3(0.1, 1.5, 0.18)
			var r2 := MeshInstance3D.new(); r2.mesh = side; r2.material_override = trim; r2.position = Vector3(x, 0.75, 0); shield.add_child(r2)
		var bar := BoxMesh.new(); bar.size = Vector3(0.12, 0.9, 0.2)
		var cross := MeshInstance3D.new(); cross.mesh = bar; cross.material_override = trim; cross.position.y = 0.8; shield.add_child(cross)
		var bar2 := BoxMesh.new(); bar2.size = Vector3(0.6, 0.12, 0.2)
		var cross2 := MeshInstance3D.new(); cross2.mesh = bar2; cross2.material_override = trim; cross2.position.y = 0.95; shield.add_child(cross2)
		for c in shield.get_children(): (c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shield.global_transform = Transform3D(Basis(Vector3.UP, -a + PI / 2.0), pos + Vector3.UP * 3.0)  # facing outward
		var tw := shield.create_tween()
		tw.tween_interval(0.03 * k)
		tw.tween_property(shield, "global_position:y", at.y, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func() -> void: FXKit.debris(parent, pos, Color(0.75, 0.62, 0.45), 5, 2.5, 0.07))
		tw.tween_interval(hold)
		tw.tween_property(shield, "global_position:y", at.y - 1.3, 0.4).set_ease(Tween.EASE_IN)
		tw.tween_callback(shield.queue_free)


## A golden streak along the dog's leap, fading.
static func _leap_trail(parent: Node3D, from: Vector3, to: Vector3) -> void:
	if from.distance_to(to) < 0.3:
		return
	var im := FXKit.ribbon_node(parent, 0.5)
	var pts: Array = []
	for i in 16:
		var u := float(i) / 15.0
		pts.append(from.lerp(to, u) + Vector3.UP * (0.6 + 1.5 * 4.0 * u * (1.0 - u)))
	var cam := parent.get_viewport().get_camera_3d()
	if cam == null:
		return
	FXKit.ribbon(im, pts, cam.global_position, 0.5, Color(GOLD, 0.55), 0.2)
	FXKit.ribbon(im, pts, cam.global_position, 0.16, Color(WHITE, 0.9), 0.2)


## Three red claw slashes across an enemy.
static func _claws(parent: Node3D, at: Vector3) -> void:
	var cam := parent.get_viewport().get_camera_3d()
	if cam == null:
		return
	var im := FXKit.ribbon_node(parent, 0.35)
	var right := cam.global_basis.x; var up := cam.global_basis.y
	for k in 3:
		var pts: Array = []
		for i in 8:
			var u := float(i) / 7.0
			pts.append(at + right * (-0.5 + u + (k - 1) * 0.25) * 0.9 + up * (0.5 - u) * 0.9 + right * 0.08 * sin(u * PI))
		FXKit.ribbon(im, pts, cam.global_position, 0.1, Color(1.0, 0.35, 0.3, 0.95), 0.1)


## A hammer of light crashing down on the spot.
static func _hammer(parent: Node3D, at: Vector3) -> void:
	var h := Node3D.new(); parent.add_child(h); h.top_level = true
	var mat := FXKit.glow(Color(1.0, 0.9, 0.55, 0.9))
	var core := FXKit.glow(Color(1.0, 1.0, 0.9, 1.0))
	var head := BoxMesh.new(); head.size = Vector3(1.6, 0.8, 0.8)
	var hm := MeshInstance3D.new(); hm.mesh = head; hm.material_override = mat; h.add_child(hm)
	var band := BoxMesh.new(); band.size = Vector3(0.3, 0.85, 0.85)
	for x in [-0.55, 0.55]:
		var b := MeshInstance3D.new(); b.mesh = band; b.material_override = core; b.position.x = x; h.add_child(b)
	var shaft := CylinderMesh.new(); shaft.top_radius = 0.09; shaft.bottom_radius = 0.09; shaft.height = 1.8
	var sm := MeshInstance3D.new(); sm.mesh = shaft; sm.material_override = core; sm.position.y = 1.2; h.add_child(sm)
	for c in h.get_children(): (c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.global_transform = Transform3D(Basis(Vector3.FORWARD, 0.6), at + Vector3(0, 4.5, 0))
	var tw := h.create_tween()
	tw.tween_property(h, "global_transform", Transform3D(Basis(Vector3.FORWARD, -0.2), at + Vector3(0, 0.5, 0)), 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		FXKit.flash(parent, at + Vector3.UP * 0.6, 4.5, WHITE, GOLD, 0.5)
		FXKit.ring(parent, at, 4.0, GOLD, WHITE, 0.5, 0.05)
		FXKit.debris(parent, at, Color(0.75, 0.62, 0.45), 20, 5.0, 0.1))
	tw.tween_interval(0.25)
	tw.set_parallel()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_property(core, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(h.queue_free)
