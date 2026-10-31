class_name BossModels
## The bosses' bodies, built from simple meshes like the pets and the tamer.
## Each builder fills a boss's Model node (facing -Z, feet at y = 0) and returns
## the parts Rival animates (see Rival._animate):
##   legs / arms: pivots that swing while walking (arms also slam on attacks)
##   bob: [node, height, amount, speed]: a node that floats or breathes up and down
##   sway: nodes that weave side to side (their rest positions are kept)
##   jaws: pivots that snap shut on attacks
##   person: the PersonModel, for the rival tamer (it animates itself)
## `main` is the boss's own material (hit flashes recolour it).


## The rival tamer: a person like the players, in a wide-brimmed hat and a
## cape in the rival's colour.
static func rival(model: Node3D, main: StandardMaterial3D, color: Color) -> Dictionary:
	var person := PersonModel.new()
	person.name = "Person"
	model.add_child(person)
	person.build(main, Color(0.12, 0.1, 0.1))
	person.scale = Vector3.ONE * 1.08
	person.hair_spikes.visible = false  # under the hat
	var dark := _mat(color.darkened(0.55))
	var hat := _pivot(person._head, Vector3.ZERO)
	_part(hat, _cylinder(0.5, 0.5, 0.04), dark, Vector3(0, 0.18, 0))
	_part(hat, _cylinder(0.22, 0.27, 0.3), dark, Vector3(0, 0.33, 0))
	_part(hat, _cylinder(0.275, 0.275, 0.07), _mat(color.lightened(0.2)), Vector3(0, 0.22, 0))  # band
	# A cape hanging from the shoulders, flaring out at the bottom.
	var cape := _pivot(person._body, Vector3(0, 1.45, 0.17))
	_part(cape, _box(Vector3(0.62, 0.06, 0.08)), dark, Vector3.ZERO)
	_part(cape, _box(Vector3(0.7, 1.15, 0.05)), _mat(color.darkened(0.25)), Vector3(0, -0.58, 0.06), Vector3(8, 0, 0))
	AnimeLook.apply(hat, 0.03)
	AnimeLook.apply(cape, 0.03)
	return {"person": person, "sway": [cape]}


## The Glacier Titan: a hulking golem of packed ice, with crystal spikes on
## its shoulders and back, glowing eyes, and huge fists.
static func titan(model: Node3D, main: StandardMaterial3D) -> Dictionary:
	var crystal := _mat(Color(0.75, 0.92, 1.0))
	crystal.emission_enabled = true
	crystal.emission = Color(0.35, 0.65, 0.95)
	crystal.emission_energy_multiplier = 0.6
	crystal.roughness = 0.15
	var rock := _mat(Color(0.32, 0.38, 0.48))
	var glow := _mat(Color(0.6, 0.95, 1.0), true)
	var legs: Array = []
	for x in [-0.5, 0.5]:
		var hip := _pivot(model, Vector3(x, 1.25, 0))
		_part(hip, _box(Vector3(0.62, 1.05, 0.66)), main, Vector3(0, -0.55, 0))
		_part(hip, _box(Vector3(0.78, 0.32, 0.92)), rock, Vector3(0, -1.08, -0.08))  # feet
		legs.append(hip)
	var body := _pivot(model, Vector3.ZERO)
	_part(body, _box(Vector3(1.5, 0.5, 0.9)), rock, Vector3(0, 1.35, 0))  # hips
	_part(body, _box(Vector3(1.9, 1.35, 1.15)), main, Vector3(0, 2.2, 0), Vector3(-6, 0, 0))  # chest
	_part(body, _box(Vector3(1.3, 0.5, 0.25)), rock, Vector3(0, 2.05, -0.58), Vector3(-6, 0, 0))  # belly plate
	_part(body, _box(Vector3(0.85, 0.72, 0.8)), main, Vector3(0, 3.1, -0.22))  # head, sunk between the shoulders
	_part(body, _box(Vector3(0.95, 0.16, 0.86)), rock, Vector3(0, 3.38, -0.24))  # brow
	for x in [-0.2, 0.2]:
		_part(body, _box(Vector3(0.2, 0.09, 0.06)), glow, Vector3(x, 3.18, -0.63))
	# Crystals: clusters on the shoulders, a ridge down the back, one on the chest.
	for side in [-1.0, 1.0]:
		for i in 3:
			var tilt := Vector3(-10 + i * 12, 0, side * (-15 - i * 14))
			_part(body, _cylinder(0.0, 0.2 - i * 0.03, 0.95 - i * 0.18), crystal,
					Vector3(side * (0.95 + i * 0.12), 3.05 + 0.1 * i, 0.05 - i * 0.18), tilt)
	for i in 4:
		_part(body, _cylinder(0.0, 0.17, 0.7 - i * 0.08), crystal, Vector3(0, 3.0 - i * 0.42, 0.55 + i * 0.03), Vector3(55, 0, 0))
	_part(body, _cylinder(0.0, 0.14, 0.45), crystal, Vector3(0.3, 2.5, -0.62), Vector3(-75, 0, 0))
	var arms: Array = []
	for side in [-1.0, 1.0]:
		var shoulder := _pivot(body, Vector3(side * 1.18, 2.65, 0))
		_part(shoulder, _box(Vector3(0.62, 0.62, 0.62)), rock, Vector3.ZERO)
		_part(shoulder, _box(Vector3(0.5, 1.0, 0.52)), main, Vector3(0, -0.72, 0))
		_part(shoulder, _box(Vector3(0.78, 0.7, 0.8)), main, Vector3(0, -1.48, -0.05))  # fist
		_part(shoulder, _box(Vector3(0.82, 0.16, 0.84)), rock, Vector3(0, -1.2, -0.05))  # knuckle band
		arms.append(shoulder)
	return {"legs": legs, "arms": arms, "bob": [body, 0.0, 0.05, 1.6]}


## The Sand Wyrm: a giant armoured worm rearing out of a sand mound, with a
## round toothy maw ringed by mandibles and humps of its body in the sand behind.
static func wyrm(model: Node3D, main: StandardMaterial3D) -> Dictionary:
	var plate := _mat(Color(0.42, 0.27, 0.14))
	var belly := _mat(Color(0.86, 0.7, 0.48))
	var sand := _mat(Color(0.82, 0.68, 0.45))
	var tooth := _mat(Color(0.96, 0.93, 0.82))
	var glow := _mat(Color(1.0, 0.55, 0.15), true)
	_part(model, _sphere(1.35), sand, Vector3(0, -0.1, 0.25), Vector3.ZERO, Vector3(1, 0.3, 1.1))  # mound
	for z in [1.9, 3.1]:  # humps of the body further back, half under the sand
		var r := 0.62 if z < 2.0 else 0.5
		_part(model, _sphere(r), main, Vector3(0.15 * z - 0.3, 0.05, z), Vector3.ZERO, Vector3(1, 0.8, 1.2))
		_part(model, _sphere(r * 1.25), sand, Vector3(0.15 * z - 0.3, -0.1, z), Vector3.ZERO, Vector3(1, 0.25, 1.3))
	# The rearing body: segments curving up and forward, each with a dark plate band.
	var sway: Array = []
	var segments := 5
	for i in segments:
		var t := float(i) / (segments - 1)
		var r := lerpf(0.82, 0.68, t)
		var seg := _pivot(model, Vector3(0, 0.35 + t * 1.75, 0.25 - t * t * 0.75))
		_part(seg, _sphere(r), main, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.75, 1))
		_part(seg, _sphere(r * 0.82), belly, Vector3(0, 0, -r * 0.3), Vector3.ZERO, Vector3(0.9, 0.7, 0.8))
		var band := TorusMesh.new()
		band.inner_radius = r * 0.9
		band.outer_radius = r * 0.99
		_part(seg, band, plate, Vector3(0, r * 0.28, 0), Vector3(-10 - 30 * t, 0, 0))
		if i > 0:
			sway.append(seg)
	# The head, facing forward and down a little, mouth open.
	var head := _pivot(model, Vector3(0, 2.3, -0.65))
	head.rotation_degrees.x = 18
	sway.append(head)
	_part(head, _sphere(0.8), main, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1.05))
	_part(head, _sphere(0.86), plate, Vector3(0, 0.22, 0.12), Vector3.ZERO, Vector3(1, 0.6, 1))  # armoured crown
	_part(head, _cylinder(0.5, 0.5, 0.12), _mat(Color(0.18, 0.06, 0.05)), Vector3(0, 0, -0.78), Vector3(90, 0, 0))  # maw
	for i in 10:  # a ring of teeth pointing into the maw
		var a := TAU * i / 10.0
		var at := Vector3(cos(a) * 0.43, sin(a) * 0.43, -0.82)
		var t := _part(head, _cylinder(0.0, 0.06, 0.2), tooth, at)
		t.basis = Basis.looking_at(-Vector3(cos(a), sin(a), 0.0), Vector3.FORWARD) * Basis(Vector3.RIGHT, -PI / 2.0)
	var jaws: Array = []
	for i in 4:  # mandibles around the maw, opening outwards
		var a := TAU * i / 4.0 + PI / 4.0
		var jaw := _pivot(head, Vector3(cos(a) * 0.55, sin(a) * 0.55, -0.6))
		jaw.rotation.z = a - PI / 2.0
		_part(jaw, _cylinder(0.0, 0.11, 0.75), tooth, Vector3(0, 0.15, -0.3), Vector3(-65, 0, 0))
		jaw.set_meta("open", Vector3(-0.35, 0, 0))
		jaws.append(jaw)
	for x in [-0.42, 0.42]:
		_part(head, _sphere(0.1), glow, Vector3(x, 0.38, -0.55))
	return {"sway": sway, "jaws": jaws}


## The Bog Witch: a hunched, green-skinned witch in a ragged robe, with a
## crooked pointed hat and a gnarled staff topped with a glowing orb. She
## floats a little above the bog.
static func witch(model: Node3D, main: StandardMaterial3D) -> Dictionary:
	var skin := _mat(Color(0.55, 0.72, 0.4))
	var dark := _mat(Color(0.16, 0.12, 0.2))
	var hair := _mat(Color(0.62, 0.62, 0.58))
	var wood := _mat(Color(0.33, 0.22, 0.13))
	var orb := _mat(Color(0.55, 1.0, 0.4), true)
	var eye := _mat(Color(1.0, 0.9, 0.3), true)
	var body := _pivot(model, Vector3.ZERO)
	_part(body, _cylinder(0.24, 0.58, 1.25), main, Vector3(0, 0.78, 0))  # robe
	for i in 9:  # a ragged hem
		var a := TAU * i / 9.0
		_part(body, _cylinder(0.0, 0.1, 0.24), main, Vector3(cos(a) * 0.52, 0.12, sin(a) * 0.52), Vector3(180, 0, 0))
	_part(body, _cylinder(0.3, 0.3, 0.08), dark, Vector3(0, 1.08, 0))  # belt
	_part(body, _box(Vector3(0.12, 0.12, 0.05)), _mat(Color(0.8, 0.7, 0.3)), Vector3(0, 1.08, -0.3))  # buckle
	var top := _pivot(body, Vector3(0, 1.35, 0.05))  # hunched forward
	top.rotation_degrees.x = -14
	_part(top, _cylinder(0.2, 0.28, 0.55), main, Vector3(0, 0.12, 0))
	_part(top, _sphere(0.26), skin, Vector3(0, 0.62, -0.12))  # head
	_part(top, _cylinder(0.0, 0.07, 0.3), skin, Vector3(0, 0.6, -0.48), Vector3(-80, 0, 0))  # long nose
	_part(top, _sphere(0.035), _mat(Color(0.4, 0.55, 0.3)), Vector3(0.05, 0.64, -0.5))  # wart
	_part(top, _sphere(0.08), skin, Vector3(0, 0.42, -0.3))  # pointed chin
	for x in [-0.1, 0.1]:
		_part(top, _sphere(0.045), eye, Vector3(x, 0.68, -0.34))
	for i in 7:  # stringy grey hair falling from under the hat
		var a := PI * 0.15 + PI * 0.7 * i / 6.0
		_part(top, _box(Vector3(0.05, 0.42, 0.05)), hair, Vector3(cos(a) * 0.26, 0.5, sin(a) * 0.2 + 0.02))
	# The hat: a wide brim and a tall cone that bends back at the tip.
	var hat := _pivot(top, Vector3(0, 0.8, -0.1))
	hat.rotation_degrees.x = 10
	_part(hat, _cylinder(0.56, 0.56, 0.04), dark, Vector3.ZERO)
	_part(hat, _cylinder(0.2, 0.3, 0.45), dark, Vector3(0, 0.24, 0))
	_part(hat, _cylinder(0.205, 0.205, 0.07), _mat(Color(0.45, 0.75, 0.3)), Vector3(0, 0.07, 0))  # band
	var tip := _pivot(hat, Vector3(0, 0.46, 0))
	tip.rotation_degrees.x = 35
	_part(tip, _cylinder(0.0, 0.2, 0.55), dark, Vector3(0, 0.26, 0))
	# Arms: a skinny one reaching forward, and the staff hand.
	var arms: Array = []
	for side in [-1.0, 1.0]:
		var shoulder := _pivot(top, Vector3(side * 0.3, 0.32, 0))
		_part(shoulder, _cylinder(0.11, 0.08, 0.55), main, Vector3(0, -0.26, 0))
		_part(shoulder, _sphere(0.07), skin, Vector3(0, -0.57, 0))
		arms.append(shoulder)
	arms[0].rotation_degrees.x = 35  # reaching
	var staff := _pivot(arms[1], Vector3(0.02, -0.57, 0))
	staff.rotation_degrees.x = -35  # held upright against the arm's angle
	_part(staff, _cylinder(0.035, 0.05, 2.0), wood, Vector3(0, 0.25, 0))
	_part(staff, _cylinder(0.09, 0.02, 0.3), wood, Vector3(0, 1.3, 0), Vector3(0, 0, 25))  # gnarled top
	_part(staff, _cylinder(0.02, 0.09, 0.3), wood, Vector3(0.05, 1.3, 0), Vector3(0, 0, -25))
	_part(staff, _sphere(0.15), orb, Vector3(0, 1.5, 0))
	arms[1].rotation_degrees.x = 35
	return {"arms": [arms[0]], "bob": [body, 0.18, 0.08, 1.4]}


# --- Mesh helpers -------------------------------------------------------------------

static func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
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


static func _mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _sphere(r: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	return mesh


## Howard the Zombie Fish: a huge rotting fish carried on a pair of zombie
## legs in torn trousers, little zombie arms reaching out from under his gills.
## One bulging eye, one crossed out, ribs showing through a torn flank, a row
## of stitches, a ragged fin down his back, and an old fishhook in his lip.
static func zombie_fish(model: Node3D, main: StandardMaterial3D) -> Dictionary:
	var belly := _mat(Color(0.72, 0.76, 0.62))
	var rot := _mat(Color(0.3, 0.36, 0.28))
	var fin := _mat(Color(0.36, 0.48, 0.42))
	var bone := _mat(Color(0.86, 0.84, 0.74))
	var dark := _mat(Color(0.1, 0.06, 0.07))
	var skin := _mat(Color(0.45, 0.6, 0.38))
	var trousers := _mat(Color(0.24, 0.24, 0.32))
	var white := _mat(Color(0.95, 0.95, 0.88))
	var hook := _mat(Color(0.75, 0.62, 0.3))
	hook.metallic = 0.7
	var legs: Array = []
	for x in [-0.42, 0.42]:
		var hip := _pivot(model, Vector3(x, 1.35, 0.15))
		_part(hip, _box(Vector3(0.36, 1.0, 0.4)), trousers, Vector3(0, -0.5, 0))
		_part(hip, _box(Vector3(0.3, 0.35, 0.32)), skin, Vector3(0, -1.12, 0))  # bare shin
		_part(hip, _box(Vector3(0.34, 0.16, 0.55)), skin, Vector3(0, -1.28, -0.1))  # foot
		legs.append(hip)
	var body := _pivot(model, Vector3.ZERO)
	_part(body, _sphere(1.0), main, Vector3(0, 2.15, 0), Vector3.ZERO, Vector3(0.8, 0.85, 1.55))
	_part(body, _sphere(0.9), belly, Vector3(0, 1.95, -0.15), Vector3.ZERO, Vector3(0.7, 0.62, 1.35))
	_part(body, _sphere(0.4), rot, Vector3(-0.55, 2.3, 0.45), Vector3.ZERO, Vector3(0.6, 1, 1.3))  # a rotten patch
	# The torn right flank, ribs showing.
	_part(body, _sphere(0.45), dark, Vector3(0.6, 2.1, 0.25), Vector3.ZERO, Vector3(0.5, 1.0, 1.3))
	for i in 4:
		_part(body, _box(Vector3(0.06, 0.62, 0.06)), bone, Vector3(0.74, 2.1, -0.1 + i * 0.22), Vector3(0, 0, 8))
	for i in 6:  # stitches across the left side
		_part(body, _box(Vector3(0.04, 0.2, 0.04)), dark, Vector3(-0.78, 2.35 - i * 0.04, -0.6 + i * 0.2), Vector3(0, 0, -20))
	_part(body, _box(Vector3(0.04, 0.04, 1.1)), dark, Vector3(-0.79, 2.25, -0.1))
	# The head: a wide mouth with jagged teeth, a dropping lower jaw.
	_part(body, _box(Vector3(1.0, 0.16, 0.5)), dark, Vector3(0, 2.0, -1.38))  # mouth
	for i in 6:
		_part(body, _cylinder(0.0, 0.06, 0.18), white, Vector3(-0.38 + i * 0.15, 1.96, -1.5), Vector3(180, 0, 0))
	var jaw := _pivot(body, Vector3(0, 1.85, -0.9))
	_part(jaw, _box(Vector3(0.95, 0.18, 0.7)), belly, Vector3(0, -0.05, -0.38))
	for i in 5:
		_part(jaw, _cylinder(0.0, 0.05, 0.16), white, Vector3(-0.3 + i * 0.15, 0.1, -0.66))
	jaw.set_meta("open", Vector3(-0.35, 0, 0))
	_part(body, TorusMesh.new(), hook, Vector3(0.35, 2.02, -1.55), Vector3(0, 90, 0), Vector3(0.12, 0.12, 0.12))
	_part(body, _cylinder(0.008, 0.008, 1.2), white, Vector3(0.36, 2.6, -1.5))  # a snapped line
	# Eyes: the left bulging, the right crossed out.
	_part(body, _sphere(0.24), white, Vector3(-0.58, 2.45, -1.0))
	_part(body, _sphere(0.08), dark, Vector3(-0.74, 2.47, -1.08))
	for angle in [45, -45]:
		_part(body, _box(Vector3(0.05, 0.32, 0.06)), dark, Vector3(0.66, 2.45, -1.0), Vector3(angle, 0, 0))
	# Fins: a ragged one down the back, small side fins, and the tail.
	for i in 6:
		var h := 0.75 - absf(i - 2.0) * 0.12
		_part(body, _cylinder(0.0, 0.1, h), fin, Vector3(0, 2.85 + h * 0.3, -0.6 + i * 0.28), Vector3(-20, 0, 0))
	_part(body, _box(Vector3(0.05, 0.3, 1.5)), fin, Vector3(0, 2.95, -0.05))
	var tail := _pivot(body, Vector3(0, 2.15, 1.45))
	for side in [-1.0, 1.0]:
		_part(tail, _box(Vector3(0.08, 0.95, 0.5)), fin, Vector3(0, side * 0.38, 0.4), Vector3(side * -35, 0, 0))
	# Little zombie arms reaching forward from under the gills.
	var arms: Array = []
	for side in [-1.0, 1.0]:
		var shoulder := _pivot(body, Vector3(side * 0.62, 1.75, -0.75))
		_part(shoulder, _box(Vector3(0.2, 0.55, 0.2)), skin, Vector3(0, -0.27, 0))
		_part(shoulder, _box(Vector3(0.22, 0.16, 0.24)), skin, Vector3(0, -0.6, 0))
		shoulder.rotation.x = 1.25
		arms.append(shoulder)
	return {"legs": legs, "arms": arms, "jaws": [jaw], "sway": [tail], "bob": [body, 0.0, 0.06, 1.8]}
