class_name CreatureModel
## Builds a creature's body out of simple meshes, by body type: cats in
## Greenmeadow, birds in Frostfang Peaks, dogs in Sunscorch Dunes and lizards in
## Mirewood Bog. The parts hang off the creature's Body node, so they lunge,
## faint and flash with it. Heads face -Z; the Body origin sits 0.42 above the
## ground (before the species' size scales the whole model).
##
## Parts that move are hung on named pivots for CreatureAnimator: "Leg0".."Leg3"
## (at the hip; 0/3 and 1/2 step together), "Tail" (at its base) and "Wing0/1".

const GROUND := -0.42
## Where each body type's head and back are, for the hybrids' horns, manes,
## crowns and wings.
const HEAD := {"cat": Vector3(0, 0.2, -0.3), "dog": Vector3(0, 0.24, -0.3), "bird": Vector3(0, 0.32, -0.2),
		"lizard": Vector3(0, -0.1, -0.5)}
const BACK := {"cat": Vector3(0, 0.2, 0.15), "dog": Vector3(0, 0.22, 0.12), "bird": Vector3(0, 0.25, 0.05),
		"lizard": Vector3(0, -0.02, 0.0)}

## Where a collar sits on each body: position (just under the head, where it
## meets the body), tilt (degrees about X) and radius.
const NECK := {
	"cat": [Vector3(0, 0.03, -0.26), -15.0, 0.2], "dog": [Vector3(0, 0.08, -0.26), -15.0, 0.19],
	"bird": [Vector3(0, 0.17, -0.17), -10.0, 0.17], "lizard": [Vector3(0, -0.11, -0.3), -80.0, 0.17],
}

## Meshes and materials are shared between every creature that uses the same one.
static var _cache := {}


## Replaces `body`'s mesh with a `body_type` model. Parts in the species colour use `main`
## (the creature's own material, so flashes and fainting recolour them).
static func build(body: MeshInstance3D, body_type: String, main: StandardMaterial3D, color: Color,
		feature := "none", anime := false) -> void:
	use_style(anime)
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	body.mesh = null
	var m := {
		"anime": anime,  # big anime eyes (a tamer's pets) instead of natural ones
		"main": main,
		"accent": _mat(color.darkened(0.45)),
		"light": _mat(color.lightened(0.45)),
		"eye": _mat(Color(1, 1, 0.95)),
		"pupil": _mat(Color(0.06, 0.05, 0.08)),
		"iris": _mat(Color.from_hsv(fposmod(color.h + 0.5, 1.0), 0.75, 0.7)),  # the opposite hue: it pops
		"glint": _mat(Color.WHITE, true),
		"nose": _mat(Color(0.9, 0.5, 0.55)),
		"beak": _mat(Color(1.0, 0.68, 0.15)),
		"gold": _mat(Color(1.0, 0.82, 0.3)),
		"white": _mat(Color(0.97, 0.96, 0.92)),
	}
	match body_type:
		"bird":
			_bird(body, m)
		"dog":
			_dog(body, m)
		"lizard":
			_lizard(body, m)
		"skeleton":
			_skeleton(body, m)
		"zombie":
			_zombie(body, m)
		"mummy":
			_mummy(body, m)
		"scorpion":
			_scorpion(body, m)
		"imp":
			_imp(body, m)
		"golem":
			_golem(body, m)
		"wraith":
			_wraith(body, m)
		"yeti":
			_yeti(body, m)
		_:
			_cat(body, m)
	match feature:
		"big_ears":  # upright fennec ears, in place of floppy ones
			for ear in body.get_children().filter(func(p: Node) -> bool: return p.name.begins_with("FloppyEar")):
				ear.queue_free()
			for x in [-1.0, 1.0]:
				_part(body, _prism(Vector3(0.2, 0.36, 0.06)), m.main, Vector3(x * 0.15, 0.52, -0.26), Vector3(0, 0, -x * 18))
				_part(body, _prism(Vector3(0.11, 0.22, 0.02)), m.nose, Vector3(x * 0.15, 0.5, -0.3), Vector3(0, 0, -x * 18))
		"spines":
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 14:
				var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.3, 1), rng.randf_range(-0.6, 1)).normalized()
				var spine := _part(body, _cylinder(0.0, 0.018, 0.14), m.light, Vector3(0, -0.02, 0.1) + dir * Vector3(0.28, 0.25, 0.4))
				spine.basis = Basis.looking_at(dir, Vector3.FORWARD if absf(dir.y) > 0.99 else Vector3.UP) \
						* Basis(Vector3.RIGHT, -PI / 2)  # the cone's tip (+Y) points along dir
		# Hybrids from the breeder.
		"horn":  # a gold horn on the forehead
			var head: Vector3 = HEAD.get(body_type, HEAD.cat)
			_part(body, _cylinder(0.0, 0.07, 0.32), m.gold, head + Vector3(0, 0.3, -0.1), Vector3(-30, 0, 0))
			_part(body, _cylinder(0.0, 0.03, 0.12), m.gold, head + Vector3(0, 0.16, -0.2), Vector3(-60, 0, 0))
		"mane":  # a fluffy ring around the head (a frill on lizards, a ruff on birds)
			var head: Vector3 = HEAD.get(body_type, HEAD.cat)
			for i in 10:
				var angle := TAU * i / 10.0
				var at := head + Vector3(cos(angle) * 0.27, sin(angle) * 0.25, 0.1)
				_part(body, _sphere(0.11), m.accent, at, Vector3.ZERO, Vector3(1, 1, 0.8))
		"crown":  # a little gold crown of spikes on top of the head
			var head: Vector3 = HEAD.get(body_type, HEAD.cat)
			for i in 5:
				var angle := TAU * i / 5.0
				_part(body, _cylinder(0.0, 0.035, 0.14), m.gold, head + Vector3(cos(angle) * 0.1, 0.24, sin(angle) * 0.1))
			_part(body, _cylinder(0.12, 0.12, 0.04), m.gold, head + Vector3(0, 0.18, 0))
		"wings":  # a pair of feathered wings, raised up and out from the back
			var back: Vector3 = BACK.get(body_type, BACK.cat)
			for x in [-1.0, 1.0]:
				var wing := _pivot(body, "Wing%d" % (0 if x < 0 else 1), back + Vector3(x * 0.15, 0, 0))
				# Feathered and white, except lizards' leathery dragon wings in their own colours.
				var front_mat: Material = m.accent if body_type == "lizard" else m.white
				var back_mat: Material = m.main if body_type == "lizard" else m.light
				var span := 0.75 if body_type == "lizard" else 1.0
				for f in 3:  # three feathers (or wing ribs) per wing, fanning outwards
					_part(wing, _sphere(0.3 * span), front_mat if f == 0 else back_mat,
							Vector3(x * (0.05 + f * 0.09), 0.22 + f * 0.04, 0.01 + f * 0.05), Vector3(0, 0, -x * (25 + f * 18)),
							Vector3(0.14, 0.95 - f * 0.18, 0.5))


## Walking on two legs (the graveyard's monsters): taller, with arms.
static func is_humanoid(body_type: String) -> bool:
	return body_type in ["skeleton", "zombie", "mummy", "imp", "golem", "wraith", "yeti"]


## Two legs from the hips (Leg0/Leg1): thigh, shin and foot, `color` cloth or skin.
static func _biped_legs(b: Node3D, mat: Material, foot: Material, x: float, thick: float) -> void:
	for side in [-1.0, 1.0]:
		var hip := _pivot(b, "Leg%d" % (0 if side < 0 else 1), Vector3(side * x, 0.38, 0))
		_part(hip, _box(Vector3(thick, 0.74, thick * 1.1)), mat, Vector3(0, -0.38, 0))
		_part(hip, _box(Vector3(thick * 1.05, 0.1, thick * 1.5)), foot, Vector3(0, -0.76, -0.05))


## A mummy: wrapped head to toe in old bandages (in the species colour, with
## darker strips), glowing blue eyes in the wrappings, arms reaching out.
static func _mummy(b: Node3D, m: Dictionary) -> void:
	var strip := _mat(Color(0.5, 0.44, 0.33))
	var glow := _mat(Color(0.4, 0.85, 1.0), true)
	_biped_legs(b, m.main, strip, 0.13, 0.17)
	_part(b, _box(Vector3(0.42, 0.62, 0.26)), m.main, Vector3(0, 0.72, 0))
	for i in 5:  # wrapping strips around the body
		_part(b, _box(Vector3(0.44, 0.04, 0.28)), strip, Vector3(0, 0.48 + i * 0.12, 0), Vector3(0, 0, (i % 2) * 10 - 5))
	var head := _pivot(b, "Head", Vector3(0, 1.1, -0.02))
	_part(head, _box(Vector3(0.3, 0.34, 0.3)), m.main, Vector3(0, 0.16, 0))
	for i in 3:
		_part(head, _box(Vector3(0.32, 0.035, 0.32)), strip, Vector3(0, 0.05 + i * 0.11, 0), Vector3(0, 0, i * 7 - 7))
	for x in [-0.07, 0.07]:
		_part(head, _box(Vector3(0.06, 0.035, 0.02)), glow, Vector3(x, 0.2, -0.155))
	for x in [-0.28, 0.28]:
		var shoulder := _pivot(b, "Arm%d" % (0 if x < 0 else 1), Vector3(x, 0.95, 0))
		shoulder.set_meta("rest", 1.3)  # reaching forward
		_part(shoulder, _box(Vector3(0.13, 0.62, 0.14)), m.main, Vector3(0, -0.3, 0))
		_part(shoulder, _box(Vector3(0.15, 0.04, 0.16)), strip, Vector3(0, -0.25, 0))
		_part(shoulder, _box(Vector3(0.05, 0.25, 0.03)), m.main, Vector3(0.03, -0.72, 0.05), Vector3(10, 0, 0))  # a trailing bandage


## A sand scorpion: a low armoured body, four legs a side (as two pivots each
## side), big pincers and a curled tail with a stinger.
static func _scorpion(b: Node3D, m: Dictionary) -> void:
	var dark: Material = m.accent
	var sting := _mat(Color(0.2, 0.08, 0.05))
	_part(b, _sphere(0.3), m.main, Vector3(0, -0.12, 0.05), Vector3.ZERO, Vector3(1.0, 0.45, 1.5))  # body
	_part(b, _sphere(0.2), m.main, Vector3(0, -0.1, -0.38), Vector3.ZERO, Vector3(1.1, 0.5, 0.9))  # head
	for i in 4:  # plates on the back
		_part(b, _box(Vector3(0.5 - i * 0.05, 0.04, 0.1)), dark, Vector3(0, 0.02, -0.1 + i * 0.13))
	for x in [-0.08, 0.08]:
		_part(b, _sphere(0.035), m.glint, Vector3(x, -0.02, -0.52))
	var i := 0
	for z in [-0.18, 0.18]:
		for side in [-1.0, 1.0]:
			var leg := _pivot(b, "Leg%d" % i, Vector3(side * 0.24, -0.12, z))
			for k in 2:  # two legs from each pivot, splayed
				_part(leg, _cylinder(0.02, 0.03, 0.42), dark, Vector3(side * 0.18, -0.12, (k - 0.5) * 0.14),
						Vector3(0, 0, side * 60))
			i += 1
	for side in [-1.0, 1.0]:  # pincers
		var arm := _pivot(b, "Arm%d" % (0 if side < 0 else 1), Vector3(side * 0.18, -0.1, -0.45))
		_part(arm, _cylinder(0.03, 0.04, 0.3), m.main, Vector3(side * 0.08, 0, -0.14), Vector3(-90, side * 30, 0))
		_part(arm, _sphere(0.09), m.main, Vector3(side * 0.16, 0, -0.32), Vector3.ZERO, Vector3(1.0, 0.6, 1.4))
		_part(arm, _prism(Vector3(0.08, 0.16, 0.05)), dark, Vector3(side * 0.13, 0, -0.45), Vector3(90, 0, 0))
	var tail := _pivot(b, "Tail", Vector3(0, -0.05, 0.42))
	for k in 5:  # segments curling up and over the back
		var a := k * 0.42
		_part(tail, _sphere(0.08 - k * 0.006), m.main, Vector3(0, sin(a) * 0.38, cos(a) * 0.32 - 0.05))
	_part(tail, _cylinder(0.0, 0.05, 0.18), sting, Vector3(0, 0.42, -0.22), Vector3(-120, 0, 0))


## A fire imp: a small red devil with horns, little leathery wings, a pointed
## tail and burning yellow eyes. It hurls fire from range.
static func _imp(b: Node3D, m: Dictionary) -> void:
	var horn := _mat(Color(0.15, 0.08, 0.06))
	var glow := _mat(Color(1.0, 0.85, 0.2), true)
	_biped_legs(b, m.main, horn, 0.11, 0.13)
	_part(b, _sphere(0.24), m.main, Vector3(0, 0.66, 0), Vector3.ZERO, Vector3(1.0, 1.2, 0.85))  # pot belly
	var head := _pivot(b, "Head", Vector3(0, 1.0, -0.02))
	_part(head, _sphere(0.2), m.main, Vector3(0, 0.08, 0))
	for x in [-1.0, 1.0]:
		_part(head, _cylinder(0.0, 0.05, 0.22), horn, Vector3(x * 0.12, 0.26, 0.02), Vector3(-15, 0, -x * 25))
		_part(head, _box(Vector3(0.07, 0.04, 0.02)), glow, Vector3(x * 0.07, 0.1, -0.19), Vector3(0, 0, x * 15))
	_part(head, _box(Vector3(0.1, 0.02, 0.02)), horn, Vector3(0, -0.01, -0.19))  # grin
	for x in [-1.0, 1.0]:
		var wing := _pivot(b, "Wing%d" % (0 if x < 0 else 1), Vector3(x * 0.12, 0.82, 0.18))
		_part(wing, _prism(Vector3(0.36, 0.3, 0.02)), m.accent, Vector3(x * 0.2, 0.06, 0.04), Vector3(0, x * 25, -x * 70))
		var shoulder := _pivot(b, "Arm%d" % (0 if x < 0 else 1), Vector3(x * 0.24, 0.82, 0))
		_part(shoulder, _box(Vector3(0.09, 0.4, 0.1)), m.main, Vector3(0, -0.2, 0))
		_part(shoulder, _sphere(0.06), horn, Vector3(0, -0.42, 0))  # claw
	var tail := _pivot(b, "Tail", Vector3(0, 0.5, 0.18))
	_part(tail, _cylinder(0.015, 0.03, 0.5), m.main, Vector3(0, 0.0, 0.22), Vector3(70, 0, 0))
	_part(tail, _prism(Vector3(0.12, 0.12, 0.03)), horn, Vector3(0, 0.08, 0.46), Vector3(90, 0, 0))


## A magma golem: hulking blocks of black basalt with lava glowing in the
## cracks between them, glowing eyes, and huge stone fists.
static func _golem(b: Node3D, m: Dictionary) -> void:
	var lava := _mat(Color(1.0, 0.45, 0.1), true)
	_biped_legs(b, m.main, m.main, 0.15, 0.22)
	_part(b, _box(Vector3(0.62, 0.62, 0.4)), m.main, Vector3(0, 0.76, 0), Vector3(0, 0, 3))  # chest
	_part(b, _box(Vector3(0.64, 0.05, 0.42)), lava, Vector3(0, 0.62, 0))  # a molten seam
	_part(b, _box(Vector3(0.05, 0.4, 0.42)), lava, Vector3(0.08, 0.86, 0), Vector3(0, 0, 18))
	var head := _pivot(b, "Head", Vector3(0, 1.1, -0.05))
	_part(head, _box(Vector3(0.32, 0.26, 0.3)), m.main, Vector3(0, 0.1, 0))
	for x in [-0.07, 0.07]:
		_part(head, _box(Vector3(0.07, 0.04, 0.02)), lava, Vector3(x, 0.12, -0.155))
	for x in [-0.42, 0.42]:
		var shoulder := _pivot(b, "Arm%d" % (0 if x < 0 else 1), Vector3(x, 0.98, 0))
		_part(shoulder, _box(Vector3(0.22, 0.24, 0.22)), m.main, Vector3.ZERO)
		_part(shoulder, _box(Vector3(0.17, 0.5, 0.18)), m.main, Vector3(0, -0.32, 0))
		_part(shoulder, _box(Vector3(0.26, 0.22, 0.26)), m.main, Vector3(0, -0.66, 0))  # fist
		_part(shoulder, _box(Vector3(0.27, 0.03, 0.27)), lava, Vector3(0, -0.56, 0))


## A frost wraith: a hooded ghost of ice that drifts above the ground, its robe
## trailing into wisps, two cold eyes in the hood, and pale reaching hands. It
## throws shards of frost from range.
static func _wraith(b: Node3D, m: Dictionary) -> void:
	var dark := _mat(Color(0.05, 0.08, 0.15))
	var glow := _mat(Color(0.55, 0.95, 1.0), true)
	_part(b, _cylinder(0.18, 0.34, 0.9), m.main, Vector3(0, 0.38, 0))  # robe, tapering up
	for i in 6:  # ragged wisps at the hem
		var a := TAU * i / 6.0
		_part(b, _cylinder(0.0, 0.07, 0.3), m.main, Vector3(cos(a) * 0.26, -0.18, sin(a) * 0.26), Vector3(180, 0, 0))
	var head := _pivot(b, "Head", Vector3(0, 0.95, 0))
	_part(head, _sphere(0.22), m.main, Vector3(0, 0.1, 0.03), Vector3.ZERO, Vector3(1.0, 1.15, 1.0))  # hood
	_part(head, _sphere(0.15), dark, Vector3(0, 0.08, -0.08))  # the dark inside the hood
	for x in [-0.05, 0.05]:
		_part(head, _sphere(0.03), glow, Vector3(x, 0.1, -0.2))
	for x in [-0.26, 0.26]:
		var shoulder := _pivot(b, "Arm%d" % (0 if x < 0 else 1), Vector3(x, 0.78, 0))
		shoulder.set_meta("rest", 0.9)
		_part(shoulder, _cylinder(0.06, 0.1, 0.45), m.main, Vector3(0, -0.2, 0))  # sleeve
		_part(shoulder, _box(Vector3(0.07, 0.12, 0.05)), m.light, Vector3(0, -0.47, 0))  # bony hand


## A yeti: a big shaggy white ape with a blue face, short horns, long arms
## hanging to its knuckles and thick legs.
static func _yeti(b: Node3D, m: Dictionary) -> void:
	var face := _mat(Color(0.45, 0.6, 0.8))
	var horn := _mat(Color(0.85, 0.82, 0.72))
	var dark := _mat(Color(0.08, 0.1, 0.15))
	_biped_legs(b, m.main, face, 0.16, 0.24)
	_part(b, _sphere(0.4), m.main, Vector3(0, 0.72, 0.02), Vector3.ZERO, Vector3(1.1, 1.0, 0.85))  # shaggy body
	for i in 8:  # tufts of fur
		var a := TAU * i / 8.0
		_part(b, _cylinder(0.0, 0.08, 0.2), m.main, Vector3(cos(a) * 0.38, 0.5 + (i % 2) * 0.3, sin(a) * 0.3),
				Vector3(0, 0, rad_to_deg(-a) + 90))
	var head := _pivot(b, "Head", Vector3(0, 1.1, -0.1))
	_part(head, _sphere(0.24), m.main, Vector3(0, 0.08, 0))
	_part(head, _sphere(0.16), face, Vector3(0, 0.03, -0.12), Vector3.ZERO, Vector3(1.0, 0.9, 0.7))
	for x in [-1.0, 1.0]:
		_part(head, _sphere(0.035), dark, Vector3(x * 0.06, 0.08, -0.24))
		_part(head, _cylinder(0.0, 0.05, 0.16), horn, Vector3(x * 0.17, 0.26, 0.0), Vector3(0, 0, -x * 35))
	_part(head, _box(Vector3(0.12, 0.03, 0.02)), dark, Vector3(0, -0.04, -0.25))  # mouth
	for x in [-0.42, 0.42]:
		var shoulder := _pivot(b, "Arm%d" % (0 if x < 0 else 1), Vector3(x, 0.95, 0))
		_part(shoulder, _cylinder(0.1, 0.13, 0.75), m.main, Vector3(0, -0.36, 0))
		_part(shoulder, _sphere(0.12), face, Vector3(0, -0.76, 0))  # big hand


## A skeleton: bones in the species colour, a ribcage, a grinning skull with
## red points of light in its eye sockets, and a rusty sword. Arm0/Arm1 swing.
static func _skeleton(b: Node3D, m: Dictionary) -> void:
	var socket := _mat(Color(0.08, 0.06, 0.06))
	var ember := _mat(Color(1.0, 0.25, 0.15), true)
	var rust := _mat(Color(0.5, 0.36, 0.26))
	for x in [-0.12, 0.12]:
		var hip := _pivot(b, "Leg%d" % (0 if x < 0 else 1), Vector3(x, 0.38, 0))
		_part(hip, _cylinder(0.04, 0.045, 0.38), m.main, Vector3(0, -0.2, 0))  # thigh bone
		_part(hip, _sphere(0.06), m.main, Vector3(0, -0.4, 0))  # knee
		_part(hip, _cylinder(0.035, 0.04, 0.36), m.main, Vector3(0, -0.6, 0))  # shin
		_part(hip, _box(Vector3(0.11, 0.05, 0.2)), m.main, Vector3(0, -0.78, -0.05))  # foot
	_part(b, _box(Vector3(0.32, 0.12, 0.16)), m.main, Vector3(0, 0.42, 0))  # pelvis
	_part(b, _cylinder(0.035, 0.035, 0.6), m.main, Vector3(0, 0.72, 0.03))  # spine
	for i in 4:  # ribs, smaller towards the bottom
		var rib := TorusMesh.new()
		rib.inner_radius = 0.13 + i * -0.015
		rib.outer_radius = rib.inner_radius + 0.035
		_part(b, rib, m.main, Vector3(0, 0.95 - i * 0.09, 0), Vector3.ZERO, Vector3(1.15, 1, 0.8))
	_part(b, _box(Vector3(0.05, 0.3, 0.04)), m.main, Vector3(0, 0.83, -0.12))  # breastbone
	_part(b, _box(Vector3(0.5, 0.06, 0.08)), m.main, Vector3(0, 1.02, 0))  # collarbones
	_part(b, _cylinder(0.03, 0.03, 0.1), m.main, Vector3(0, 1.08, 0))  # neck
	_part(b, _sphere(0.16), m.main, Vector3(0, 1.24, 0), Vector3.ZERO, Vector3(0.95, 1, 1.05))  # skull
	_part(b, _box(Vector3(0.17, 0.07, 0.13)), m.main, Vector3(0, 1.1, -0.06))  # jaw
	for x in [-0.06, 0.06]:
		_part(b, _sphere(0.045), socket, Vector3(x, 1.26, -0.13))
		_part(b, _sphere(0.017), ember, Vector3(x, 1.26, -0.17))
	_part(b, _box(Vector3(0.03, 0.04, 0.02)), socket, Vector3(0, 1.19, -0.16))  # nose hole
	for x in [-0.26, 0.26]:
		var shoulder := _pivot(b, "Arm%d" % (0 if x < 0 else 1), Vector3(x, 1.0, 0))
		_part(shoulder, _sphere(0.05), m.main, Vector3.ZERO)
		_part(shoulder, _cylinder(0.03, 0.035, 0.3), m.main, Vector3(0, -0.17, 0))
		_part(shoulder, _cylinder(0.025, 0.03, 0.28), m.main, Vector3(0, -0.47, 0))
		_part(shoulder, _box(Vector3(0.07, 0.09, 0.05)), m.main, Vector3(0, -0.64, 0))  # hand
		if x > 0:  # a rusty sword in the right hand, pointing forward
			_part(shoulder, _box(Vector3(0.04, 0.06, 0.62)), rust, Vector3(0, -0.66, -0.34))
			_part(shoulder, _box(Vector3(0.2, 0.03, 0.04)), rust, Vector3(0, -0.66, -0.04))  # guard


## A zombie: green-grey skin in the species colour, a torn shirt and trousers,
## a lolling head with dim yellow eyes, and both arms reaching forward.
static func _zombie(b: Node3D, m: Dictionary) -> void:
	var shirt := _mat(Color(0.42, 0.36, 0.3))
	var trousers := _mat(Color(0.24, 0.24, 0.3))
	var dark := _mat(Color(0.12, 0.1, 0.08))
	var eye := _mat(Color(0.95, 0.9, 0.35), true)
	for x in [-0.13, 0.13]:
		var hip := _pivot(b, "Leg%d" % (0 if x < 0 else 1), Vector3(x, 0.38, 0))
		_part(hip, _box(Vector3(0.17, 0.72, 0.19)), trousers, Vector3(0, -0.38, 0))
		_part(hip, _box(Vector3(0.18, 0.1, 0.27)), m.main, Vector3(0, -0.76, -0.05))  # bare foot
	_part(b, _box(Vector3(0.44, 0.58, 0.26)), shirt, Vector3(0, 0.72, 0))  # torso
	_part(b, _box(Vector3(0.2, 0.22, 0.27)), m.main, Vector3(0.1, 0.62, -0.005), Vector3(0, 0, 12))  # a rip showing skin
	_part(b, _box(Vector3(0.46, 0.08, 0.28)), dark, Vector3(0, 0.44, 0))  # belt
	var head := _pivot(b, "Head", Vector3(0, 1.08, -0.02))
	head.rotation_degrees = Vector3(12, 0, 14)  # lolling to one side
	_part(head, _box(Vector3(0.12, 0.1, 0.12)), m.main, Vector3(0, 0.02, 0))  # neck
	_part(head, _box(Vector3(0.3, 0.32, 0.3)), m.main, Vector3(0, 0.2, 0))
	_part(head, _box(Vector3(0.32, 0.08, 0.32)), dark, Vector3(0, 0.37, 0.02))  # patchy hair
	for x in [-0.07, 0.07]:
		_part(head, _box(Vector3(0.07, 0.05, 0.02)), eye, Vector3(x, 0.23, -0.155))
	_part(head, _box(Vector3(0.14, 0.04, 0.02)), dark, Vector3(0.02, 0.1, -0.155), Vector3(0, 0, -8))  # slack mouth
	for x in [-0.29, 0.29]:
		var shoulder := _pivot(b, "Arm%d" % (0 if x < 0 else 1), Vector3(x, 0.95, 0))
		shoulder.set_meta("rest", 1.35)  # reaching forward
		_part(shoulder, _box(Vector3(0.14, 0.32, 0.15)), shirt, Vector3(0, -0.15, 0))  # sleeve
		_part(shoulder, _box(Vector3(0.11, 0.3, 0.12)), m.main, Vector3(0, -0.44, 0))  # forearm
		_part(shoulder, _box(Vector3(0.12, 0.1, 0.13)), m.main, Vector3(0, -0.63, 0))  # hand


static func _cat(b: Node3D, m: Dictionary) -> void:
	_part(b, _sphere(0.3), m.main, Vector3(0, -0.04, 0.08), Vector3.ZERO, Vector3(0.95, 0.85, 1.35))  # torso
	_part(b, _sphere(0.25), m.main, Vector3(0, 0.2, -0.3))  # head
	for x in [-1.0, 1.0]:
		_part(b, _prism(Vector3(0.15, 0.2, 0.07)), m.main, Vector3(x * 0.13, 0.46, -0.3), Vector3(0, 0, -x * 12))
		_part(b, _prism(Vector3(0.08, 0.12, 0.02)), m.nose, Vector3(x * 0.13, 0.44, -0.34), Vector3(0, 0, -x * 12))
		_eye(b, m, Vector3(x * 0.1, 0.25, -0.5), 0.06, true)
		for y in [0.0, 0.04]:  # whiskers
			_part(b, _box(Vector3(0.2, 0.012, 0.012)), m.accent, Vector3(x * 0.17, 0.14 + y, -0.5), Vector3(0, x * 15, x * (y * 300 - 6)))
	_part(b, _prism(Vector3(0.07, 0.05, 0.04)), m.nose, Vector3(0, 0.17, -0.55), Vector3(180, 0, 0))
	_legs(b, m.main, 0.06, 0.14, -0.12, 0.26)
	var tail := _pivot(b, "Tail", Vector3(0, -0.08, 0.4))  # curling up
	_part(tail, _cylinder(0.045, 0.045, 0.36), m.main, Vector3(0, 0.1, 0.1), Vector3(-55, 0, 0))
	_part(tail, _cylinder(0.04, 0.045, 0.3), m.main, Vector3(0, 0.35, 0.2), Vector3(-10, 0, 0))
	_part(tail, _sphere(0.05), m.accent, Vector3(0, 0.5, 0.22))


static func _bird(b: Node3D, m: Dictionary) -> void:
	_part(b, _sphere(0.32), m.main, Vector3(0, 0.0, 0.03), Vector3.ZERO, Vector3(1, 1, 1.1))  # body
	_part(b, _sphere(0.25), m.light, Vector3(0, -0.06, -0.1), Vector3.ZERO, Vector3(0.95, 1, 0.9))  # breast
	_part(b, _sphere(0.21), m.main, Vector3(0, 0.32, -0.2))  # head
	_part(b, _cylinder(0.0, 0.08, 0.22), m.beak, Vector3(0, 0.29, -0.44), Vector3(-90, 0, 0))
	for i in 3:  # crest
		_part(b, _prism(Vector3(0.05, 0.16, 0.08)), m.accent, Vector3(0, 0.55 - i * 0.03, -0.22 + i * 0.07), Vector3(-25 - i * 15, 0, 0))
	for x in [-1.0, 1.0]:
		_eye(b, m, Vector3(x * 0.11, 0.36, -0.36), 0.055, false)
		var wing := _pivot(b, "Wing%d" % (0 if x < 0 else 1), Vector3(x * 0.24, 0.2, 0.0))  # at the shoulder
		_part(wing, _sphere(0.28), m.accent, Vector3(x * 0.06, -0.16, 0.06), Vector3(0, 0, x * 15), Vector3(0.28, 0.65, 1.0))
		var leg := _pivot(b, "Leg%d" % (0 if x < 0 else 1), Vector3(x * 0.1, -0.23, 0.0))  # at the hip
		_part(leg, _cylinder(0.025, 0.025, 0.2), m.beak, Vector3(0, -0.1, 0.0))
		_part(leg, _box(Vector3(0.1, 0.03, 0.14)), m.beak, Vector3(0, -0.19, -0.04))  # foot
	var tail := _pivot(b, "Tail", Vector3(0, 0.05, 0.3))
	_part(tail, _box(Vector3(0.24, 0.04, 0.3)), m.accent, Vector3(0, 0.01, 0.1), Vector3(28, 0, 0))  # tail feathers
	_part(tail, _box(Vector3(0.14, 0.04, 0.22)), m.main, Vector3(0, 0.06, 0.16), Vector3(40, 0, 0))


static func _dog(b: Node3D, m: Dictionary) -> void:
	_part(b, _sphere(0.3), m.main, Vector3(0, -0.02, 0.08), Vector3.ZERO, Vector3(0.95, 0.85, 1.45))  # torso
	_part(b, _sphere(0.23), m.main, Vector3(0, 0.24, -0.3))  # head
	_part(b, _sphere(0.13), m.light, Vector3(0, 0.15, -0.5), Vector3.ZERO, Vector3(1, 0.8, 1.3))  # snout
	_part(b, _sphere(0.05), m.pupil, Vector3(0, 0.2, -0.66))  # nose
	_part(b, _box(Vector3(0.07, 0.02, 0.1)), m.nose, Vector3(0, 0.07, -0.55), Vector3(-25, 0, 0))  # tongue
	for x in [-1.0, 1.0]:
		_eye(b, m, Vector3(x * 0.1, 0.3, -0.48), 0.055, false)
		_part(b, _box(Vector3(0.11, 0.24, 0.06)), m.accent, Vector3(x * 0.21, 0.24, -0.28), Vector3(0, 0, x * 28)).name = "FloppyEar"
	_legs(b, m.main, 0.065, 0.15, -0.14, 0.3)
	var tail := _pivot(b, "Tail", Vector3(0, 0.03, 0.45))  # wags
	_part(tail, _cylinder(0.025, 0.045, 0.34), m.main, Vector3(0, 0.13, 0.11), Vector3(-40, 0, 0))
	_part(tail, _sphere(0.045), m.light, Vector3(0, 0.27, 0.22))


static func _lizard(b: Node3D, m: Dictionary) -> void:
	_part(b, _sphere(0.28), m.main, Vector3(0, -0.18, 0.05), Vector3.ZERO, Vector3(1, 0.62, 1.8))  # long, low body
	_part(b, _sphere(0.2), m.main, Vector3(0, -0.1, -0.5), Vector3.ZERO, Vector3(1, 0.75, 1.35))  # head
	_part(b, _box(Vector3(0.22, 0.015, 0.12)), m.pupil, Vector3(0, -0.15, -0.71))  # mouth line
	for i in 5:  # back spikes
		_part(b, _prism(Vector3(0.05, 0.12, 0.1)), m.accent, Vector3(0, -0.02 - absf(i - 1.5) * 0.015, -0.3 + i * 0.16))
	for x in [-1.0, 1.0]:
		_eye(b, m, Vector3(x * 0.13, 0.0, -0.52), 0.075, true)
		for z in [-0.22, 0.3]:  # sprawled legs, pivoting at the shoulder/hip
			var index := (0 if z < 0.0 else 1) + (0 if x < 0 else 2)
			var leg := _pivot(b, "Leg%d" % index, Vector3(x * 0.18, -0.22, z))
			_part(leg, _cylinder(0.05, 0.05, 0.24), m.main, Vector3(x * 0.09, -0.08, 0), Vector3(0, 0, x * 55))
			_part(leg, _sphere(0.06), m.accent, Vector3(x * 0.18, -0.17, -0.03), Vector3.ZERO, Vector3(1.2, 0.5, 1.4))
		_part(b, _sphere(0.08), m.accent, Vector3(x * 0.12, -0.08, 0.12 + x * 0.12), Vector3.ZERO, Vector3(1, 0.3, 1.2))  # spots
	var tail := _pivot(b, "Tail", Vector3(0, -0.24, 0.38))  # swishes side to side
	_part(tail, _cylinder(0.015, 0.12, 0.75), m.main, Vector3(0, 0, 0.34), Vector3(80, 0, 0))


# --- Helpers --------------------------------------------------------------------------

## An anime eye: a narrowed white with a coloured iris, a sharp pupil (a slit
## for `slit` eyes), a glint of light, and a heavy brow angled down towards the
## nose for a fierce look.
## A natural eye: a small, glossy, dark eyeball set into the head (cats and
## lizards have an amber eye with a slit pupil); the light catches it.
static func _eye(b: Node3D, m: Dictionary, at: Vector3, r: float, slit: bool) -> void:
	if m.get("anime", false):
		_anime_eye(b, m, at, r, slit)
		return
	var dark := _mat(Color(0.05, 0.035, 0.03))
	dark.roughness = 0.12
	dark.set_meta("smooth", true)
	if slit:
		var amber := _mat(Color(0.72, 0.55, 0.16))
		amber.roughness = 0.12
		amber.set_meta("smooth", true)
		_part(b, _sphere(r * 0.72), amber, at, Vector3.ZERO, Vector3(1.0, 1.0, 0.75))
		_part(b, _box(Vector3(r * 0.16, r * 0.9, r * 0.12)), dark, at + Vector3(0, 0, -r * 0.52))
	else:
		_part(b, _sphere(r * 0.66), dark, at, Vector3.ZERO, Vector3(1.0, 1.0, 0.75))


## The anime eye (a tamer's pets): a big white eye, a bright iris in the
## opposite hue, a pupil (a slit for cats and lizards), a glint and a fierce brow.
static func _anime_eye(b: Node3D, m: Dictionary, at: Vector3, r: float, slit: bool) -> void:
	var side := signf(at.x) if absf(at.x) > 0.001 else 1.0
	_part(b, _sphere(r), m.eye, at, Vector3(0, 0, side * 12), Vector3(1.15, 0.9, 0.9))
	_part(b, _sphere(r * 0.62), m.iris, at + Vector3(-side * r * 0.1, -r * 0.05, -r * 0.55), Vector3.ZERO, Vector3(0.85, 1.05, 0.6))
	var pupil: Mesh = _box(Vector3(r * 0.22, r * 0.95, r * 0.2)) if slit else _sphere(r * 0.3)
	_part(b, pupil, m.pupil, at + Vector3(-side * r * 0.1, -r * 0.05, -r * 0.85))
	_part(b, _sphere(r * 0.16), m.glint, at + Vector3(-side * r * 0.35, r * 0.2, -r * 0.92))
	_part(b, _box(Vector3(r * 2.2, r * 0.32, r * 0.6)), m.pupil, at + Vector3(side * r * 0.15, r * 1.12, -r * 0.4),
			Vector3(0, 0, side * 22))  # brow, low at the nose end


## Four legs, each on a pivot at the hip: Leg0 front-left, Leg1 back-left,
## Leg2 front-right, Leg3 back-right.
static func _legs(b: Node3D, mat: Material, r: float, x: float, front: float, back: float) -> void:
	var height := 0.3
	var index := 0
	for side in [-1.0, 1.0]:
		for z in [front, back]:
			var leg := _pivot(b, "Leg%d" % index, Vector3(side * x, GROUND + height, z))
			_part(leg, _cylinder(r, r, height), mat, Vector3(0, -height * 0.5, 0))
			index += 1


static func _pivot(parent: Node3D, pivot_name: String, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = pos
	parent.add_child(pivot)
	return pivot


static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO,
		scl := Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	part.rotation_degrees = rot_deg
	part.scale = scl
	parent.add_child(part)
	return part


static func _cached(key: String, make: Callable) -> Resource:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


## Which look the materials being built are for (see use_style): materials are
## shared between creatures, so each look keeps its own.
static var _style_key := "real"


## Builds what follows (a body, a collar) for the anime look or the realistic one.
static func use_style(anime: bool) -> void:
	_style_key = "anime" if anime else "real"


static func _mat(color: Color, unshaded := false) -> StandardMaterial3D:
	return _cached("mat%s%s%s" % [color.to_html(), unshaded, _style_key], _new_mat.bind(color, unshaded))


static func _new_mat(color: Color, unshaded: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


static func _sphere(r: float) -> SphereMesh:
	return _cached("_sphere%s" % [[r]], _new_sphere.bind(r))


static func _new_sphere(r: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	return _cached("_box%s" % [[size]], _new_box.bind(size))


static func _new_box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _prism(size: Vector3) -> PrismMesh:
	return _cached("_prism%s" % [[size]], _new_prism.bind(size))


static func _new_prism(size: Vector3) -> PrismMesh:
	var mesh := PrismMesh.new()
	mesh.size = size
	return mesh


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	return _cached("_cylinder%s" % [[top, bottom, height]], _new_cylinder.bind(top, bottom, height))


static func _new_cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return mesh


## A collar in `color` around the neck, with a little gold tag hanging at the front.
static func add_collar(body: Node3D, body_type: String, color: Color) -> Node3D:
	var neck: Array = NECK.get(body_type, NECK.cat)
	var collar := Node3D.new()
	collar.name = "Collar"
	collar.position = neck[0]
	collar.rotation_degrees.x = neck[1]
	body.add_child(collar)
	var torus := TorusMesh.new()
	torus.inner_radius = neck[2] - 0.035
	torus.outer_radius = neck[2] + 0.04  # chunky, so it reads from the game camera
	torus.rings = 24
	torus.ring_segments = 8
	var band := MeshInstance3D.new()
	band.mesh = torus
	band.material_override = _mat(color)
	collar.add_child(band)
	var tag := MeshInstance3D.new()
	tag.mesh = _sphere(0.06)
	tag.material_override = _mat(Color(1.0, 0.82, 0.3))
	tag.position = Vector3(0, 0, -neck[2] - 0.05)  # at the front of the neck
	tag.scale = Vector3(1, 1, 0.5)
	collar.add_child(tag)
	return collar
