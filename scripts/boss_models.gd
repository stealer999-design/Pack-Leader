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


## Rival Kael: the textured 3D model (models/rival_kael.glb, made with Meshy
## from a reference picture): a cowboy in a red hat and shirt, dark jeans and
## boots, holding a bat. It's one solid mesh with no skeleton, so it moves as
## a whole: a bounce and a rock while walking (bob, rock) and a lunge with a
## twist when it attacks (lunge). Falls back to the legacy model if the file
## is missing.
const RIVAL_MODEL := "res://models/rival_kael.glb"
const RIVAL_HEIGHT := 2.05  ## How tall he stands, in world units (the players are about 1.95).
## Turns the model to face -Z like everything else (Meshy models face +Z).
const RIVAL_FACING := PI


static func rival(model: Node3D, main: StandardMaterial3D, color: Color) -> Dictionary:
	if not ResourceLoader.exists(RIVAL_MODEL):
		return rival_legacy(model, main, color)
	var body := _pivot(model, Vector3.ZERO)  # bobs and rocks while walking
	var turn := _pivot(body, Vector3.ZERO)  # twists and leans into a swing
	var scene: Node3D = (load(RIVAL_MODEL) as PackedScene).instantiate()
	turn.add_child(scene)
	# Scale to RIVAL_HEIGHT with the feet on the ground, whatever size it was made at.
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var b := mesh.transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var k := RIVAL_HEIGHT / maxf(box.size.y, 0.01)
	scene.scale = Vector3.ONE * k
	scene.position = Vector3(-box.get_center().x * k, -box.position.y * k, -box.get_center().z * k)
	turn.rotation.y = RIVAL_FACING
	return {"bob": [body, 0.0, 0.015, 1.4], "rock": body, "lunge": turn, "flash": scene}


## The rival tamer as he first was (kept for now): a person like the players,
## in a wide-brimmed hat and a cape in the rival's colour.
static func rival_legacy(model: Node3D, main: StandardMaterial3D, color: Color) -> Dictionary:
	var person := PersonModel.new()
	person.name = "Person"
	model.add_child(person)
	person.build(main, Color(0.12, 0.1, 0.1))
	person.scale = Vector3.ONE * 1.08
	var dark := _mat(color.darkened(0.55))
	var hat := _pivot(person._head, Vector3.ZERO)
	_part(hat, _cylinder(0.5, 0.5, 0.04), dark, Vector3(0, 0.18, 0))
	_part(hat, _cylinder(0.22, 0.27, 0.3), dark, Vector3(0, 0.33, 0))
	_part(hat, _cylinder(0.275, 0.275, 0.07), _mat(color.lightened(0.2)), Vector3(0, 0.22, 0))  # band
	# A cape hanging from the shoulders, flaring out at the bottom.
	var cape := _pivot(person._body, Vector3(0, 1.45, 0.17))
	_part(cape, _box(Vector3(0.62, 0.06, 0.08)), dark, Vector3.ZERO)
	_part(cape, _box(Vector3(0.7, 1.15, 0.05)), _mat(color.darkened(0.25)), Vector3(0, -0.58, 0.06), Vector3(8, 0, 0))
	ModelLook.apply(hat, 0.03)
	ModelLook.apply(cape, 0.03)
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


## The Sand Pharaoh: a towering mummy king in gold and blue, a striped royal
## headdress, a gold mask over a bandaged face with burning eyes, a broad
## collar, and a crook-headed staff.
static func sand_pharaoh(model: Node3D, main: StandardMaterial3D) -> Dictionary:
	var gold := _mat(Color(0.95, 0.75, 0.25))
	gold.metallic = 0.6
	gold.roughness = 0.35
	var lapis := _mat(Color(0.15, 0.25, 0.65))
	var strip := _mat(Color(0.55, 0.48, 0.36))
	var glow := _mat(Color(0.35, 0.9, 1.0), true)
	var legs: Array = []
	for x in [-0.3, 0.3]:
		var hip := _pivot(model, Vector3(x, 1.4, 0))
		_part(hip, _box(Vector3(0.36, 1.4, 0.4)), main, Vector3(0, -0.7, 0))
		_part(hip, _box(Vector3(0.38, 0.06, 0.42)), strip, Vector3(0, -0.5, 0))
		_part(hip, _box(Vector3(0.38, 0.06, 0.42)), strip, Vector3(0, -1.0, 0))
		legs.append(hip)
	var body := _pivot(model, Vector3.ZERO)
	_part(body, _cylinder(0.55, 0.62, 0.8), lapis, Vector3(0, 1.45, 0))  # royal kilt
	for i in 6:
		_part(body, _box(Vector3(0.08, 0.78, 0.02)), gold, Vector3(0, 1.45, -0.6), Vector3(0, i * 30 - 75, 0))
	_part(body, _box(Vector3(1.0, 1.1, 0.6)), main, Vector3(0, 2.35, 0))  # wrapped chest
	for i in 4:
		_part(body, _box(Vector3(1.02, 0.06, 0.62)), strip, Vector3(0, 2.0 + i * 0.25, 0), Vector3(0, 0, (i % 2) * 6 - 3))
	_part(body, _cylinder(0.75, 0.75, 0.12), gold, Vector3(0, 2.86, 0))  # broad collar
	_part(body, _cylinder(0.76, 0.76, 0.06), lapis, Vector3(0, 2.8, 0))
	var head := _pivot(body, Vector3(0, 3.25, 0))
	_part(head, _box(Vector3(0.48, 0.55, 0.46)), main, Vector3(0, 0, 0))
	_part(head, _box(Vector3(0.44, 0.5, 0.04)), gold, Vector3(0, -0.02, -0.25))  # mask
	for x in [-0.1, 0.1]:
		_part(head, _box(Vector3(0.1, 0.05, 0.02)), glow, Vector3(x, 0.06, -0.28))
	_part(head, _box(Vector3(0.06, 0.24, 0.04)), lapis, Vector3(0, -0.32, -0.24))  # royal beard
	for side in [-1.0, 1.0]:  # the striped headdress falling to the shoulders
		for i in 4:
			_part(head, _box(Vector3(0.1, 0.6, 0.38)), gold if i % 2 == 0 else lapis, Vector3(side * (0.28 + i * 0.03), -0.3, 0.02 + i * 0.01), Vector3(0, 0, side * 8))
	_part(head, _box(Vector3(0.62, 0.22, 0.52)), gold, Vector3(0, 0.3, 0.02))
	_part(head, _cylinder(0.0, 0.06, 0.18), gold, Vector3(0, 0.42, -0.26), Vector3(-30, 0, 0))  # the cobra on the brow
	var arms: Array = []
	for side in [-1.0, 1.0]:
		var shoulder := _pivot(body, Vector3(side * 0.62, 2.7, 0))
		_part(shoulder, _box(Vector3(0.26, 0.95, 0.28)), main, Vector3(0, -0.45, 0))
		_part(shoulder, _cylinder(0.16, 0.16, 0.1), gold, Vector3(0, -0.75, 0))  # bracelet
		_part(shoulder, _box(Vector3(0.22, 0.2, 0.22)), main, Vector3(0, -1.0, 0))
		arms.append(shoulder)
	var staff := _pivot(arms[1], Vector3(0, -1.0, 0))
	_part(staff, _cylinder(0.04, 0.04, 2.8), gold, Vector3(0, 0.6, -0.1))
	_part(staff, TorusMesh.new(), gold, Vector3(0, 2.05, -0.25), Vector3(90, 0, 0), Vector3(0.25, 0.25, 0.25))  # the crook
	arms[1].rotation_degrees.x = 20
	return {"legs": legs, "arms": [arms[0]], "bob": [body, 0.0, 0.04, 1.2]}


## The Magma Colossus: a mountain of black rock walking on stumpy legs, lava
## pouring through the cracks, a crown of smoking spikes, molten eyes, and
## fists like boulders.
static func magma_colossus(model: Node3D, main: StandardMaterial3D) -> Dictionary:
	var lava := _mat(Color(1.0, 0.45, 0.08), true)
	var ember := _mat(Color(1.0, 0.75, 0.2), true)
	var legs: Array = []
	for x in [-0.55, 0.55]:
		var hip := _pivot(model, Vector3(x, 1.2, 0))
		_part(hip, _box(Vector3(0.75, 1.2, 0.8)), main, Vector3(0, -0.6, 0))
		_part(hip, _box(Vector3(0.77, 0.06, 0.82)), lava, Vector3(0, -0.55, 0))
		legs.append(hip)
	var body := _pivot(model, Vector3.ZERO)
	_part(body, _box(Vector3(2.0, 1.6, 1.3)), main, Vector3(0, 2.1, 0), Vector3(-5, 0, 0))
	for crack in [[Vector3(0.3, 2.2, -0.66), Vector3(0.13, 1.2, 0.05), 20], [Vector3(-0.4, 2.0, -0.66), Vector3(0.12, 0.9, 0.05), -25],
			[Vector3(0, 1.6, -0.62), Vector3(1.6, 0.12, 0.05), 0], [Vector3(0.62, 2.5, -0.1), Vector3(0.05, 0.12, 1.0), 0],
			[Vector3(-0.62, 2.4, -0.1), Vector3(0.05, 0.12, 1.0), 0]]:
		_part(body, _box(crack[1]), lava, crack[0], Vector3(-5, 0, crack[2]))
	_part(body, _sphere(0.45), lava, Vector3(0, 2.2, -0.45), Vector3.ZERO, Vector3(1, 1, 0.4))  # the molten heart
	var head := _pivot(body, Vector3(0, 3.15, -0.2))
	_part(head, _box(Vector3(0.9, 0.7, 0.8)), main, Vector3.ZERO)
	for x in [-0.2, 0.2]:
		_part(head, _box(Vector3(0.18, 0.08, 0.04)), lava, Vector3(x, 0.05, -0.41))
	_part(head, _box(Vector3(0.5, 0.06, 0.04)), lava, Vector3(0, -0.18, -0.41))  # glowing mouth
	for i in 5:  # a crown of smoking spikes
		var a := PI * (0.15 + 0.7 * i / 4.0)
		_part(head, _cylinder(0.0, 0.12, 0.6), main, Vector3(cos(a) * 0.38, 0.55, -sin(a) * 0.1 + 0.1), Vector3(0, 0, rad_to_deg(PI / 2.0 - a) * 0.6))
		_part(head, _sphere(0.06), ember, Vector3(cos(a) * 0.44, 0.88, -sin(a) * 0.1 + 0.1))
	var arms: Array = []
	for side in [-1.0, 1.0]:
		var shoulder := _pivot(body, Vector3(side * 1.25, 2.6, 0))
		_part(shoulder, _box(Vector3(0.7, 0.7, 0.7)), main, Vector3.ZERO)
		_part(shoulder, _box(Vector3(0.5, 1.0, 0.55)), main, Vector3(0, -0.75, 0))
		_part(shoulder, _box(Vector3(0.52, 0.05, 0.57)), lava, Vector3(0, -0.6, 0))
		_part(shoulder, _box(Vector3(0.85, 0.75, 0.85)), main, Vector3(0, -1.5, -0.05))  # fist
		_part(shoulder, _box(Vector3(0.87, 0.05, 0.87)), lava, Vector3(0, -1.3, -0.05))
		arms.append(shoulder)
	return {"legs": legs, "arms": arms, "bob": [body, 0.0, 0.05, 1.4]}


## The Yeti King: a giant white yeti with a crown of ice, a frosted blue face
## with small fierce eyes and tusks, a cloak of fur, and huge arms.
static func yeti_king(model: Node3D, main: StandardMaterial3D) -> Dictionary:
	var face := _mat(Color(0.42, 0.58, 0.8))
	var ice := _mat(Color(0.7, 0.92, 1.0))
	ice.emission_enabled = true
	ice.emission = Color(0.3, 0.6, 0.9)
	ice.emission_energy_multiplier = 0.6
	var tusk := _mat(Color(0.95, 0.93, 0.85))
	var dark := _mat(Color(0.05, 0.08, 0.15))
	var legs: Array = []
	for x in [-0.5, 0.5]:
		var hip := _pivot(model, Vector3(x, 1.15, 0))
		_part(hip, _cylinder(0.32, 0.36, 1.15), main, Vector3(0, -0.55, 0))
		_part(hip, _box(Vector3(0.6, 0.18, 0.85)), face, Vector3(0, -1.08, -0.15))  # big feet
		legs.append(hip)
	var body := _pivot(model, Vector3.ZERO)
	_part(body, _sphere(1.1), main, Vector3(0, 2.15, 0.05), Vector3.ZERO, Vector3(1.0, 0.95, 0.8))  # shaggy bulk
	for i in 12:  # fur tufts
		var a := TAU * i / 12.0
		_part(body, _cylinder(0.0, 0.2, 0.5), main, Vector3(cos(a) * 1.0, 1.7 + (i % 3) * 0.35, sin(a) * 0.75),
				Vector3(0, 0, rad_to_deg(-a) + 90))
	var head := _pivot(body, Vector3(0, 3.15, -0.3))
	_part(head, _sphere(0.55), main, Vector3.ZERO)
	_part(head, _sphere(0.38), face, Vector3(0, -0.05, -0.28), Vector3.ZERO, Vector3(1.0, 0.9, 0.7))
	for x in [-0.14, 0.14]:
		_part(head, _sphere(0.06), dark, Vector3(x, 0.06, -0.55))
		_part(head, _box(Vector3(0.14, 0.04, 0.04)), dark, Vector3(x, 0.15, -0.55), Vector3(0, 0, -signf(x) * 20))  # scowl
		_part(head, _cylinder(0.0, 0.05, 0.22), tusk, Vector3(x * 0.8, -0.3, -0.5), Vector3(-160, 0, 0))
	for i in 7:  # the crown of ice
		var a := PI * (0.1 + 0.8 * i / 6.0)
		_part(head, _cylinder(0.0, 0.08, 0.45 + (i % 2) * 0.2), ice, Vector3(cos(a) * 0.4, 0.5, -sin(a) * 0.15 + 0.05))
	var arms: Array = []
	for side in [-1.0, 1.0]:
		var shoulder := _pivot(body, Vector3(side * 1.05, 2.6, 0))
		_part(shoulder, _sphere(0.4), main, Vector3.ZERO)
		_part(shoulder, _cylinder(0.3, 0.38, 1.4), main, Vector3(0, -0.75, 0))
		_part(shoulder, _sphere(0.36), face, Vector3(0, -1.55, -0.05))  # huge hands
		arms.append(shoulder)
	return {"legs": legs, "arms": arms, "bob": [body, 0.0, 0.06, 1.3]}


## Sunmane, the Desert Lion: a huge tawny lion with a great shaggy dark mane,
## a broad muzzle, amber eyes, round ears and a tufted tail. Four legs that
## trot (front left with back right), a jaw that snaps on attacks.
static func desert_lion(model: Node3D, main: StandardMaterial3D) -> Dictionary:
	var mane := _mat(Color(0.45, 0.24, 0.1))
	var muzzle := _mat(Color(0.93, 0.82, 0.62))
	var dark := _mat(Color(0.08, 0.05, 0.04))
	var eye := _mat(Color(1.0, 0.7, 0.15), true)
	var pad := _mat(Color(0.35, 0.22, 0.14))
	var legs: Array = []
	# Order: front left, front right, back right, back left (trot pairs share a phase).
	for spot in [Vector3(-0.45, 1.3, -1.0), Vector3(0.45, 1.3, -1.0), Vector3(0.45, 1.3, 1.0), Vector3(-0.45, 1.3, 1.0)]:
		var hip := _pivot(model, spot)
		_part(hip, _cylinder(0.2, 0.28, 1.2), main, Vector3(0, -0.6, 0))
		_part(hip, _sphere(0.24), pad, Vector3(0, -1.2, -0.08), Vector3.ZERO, Vector3(1.0, 0.6, 1.3))  # paw
		legs.append(hip)
	var body := _pivot(model, Vector3.ZERO)
	_part(body, _sphere(0.9), main, Vector3(0, 1.75, 0.15), Vector3.ZERO, Vector3(0.85, 0.75, 1.65))  # long body
	_part(body, _sphere(0.6), muzzle, Vector3(0, 1.35, 0.1), Vector3.ZERO, Vector3(0.9, 0.4, 1.6))  # pale belly
	# The mane: a great ball of dark fur round the neck, with shaggy tufts.
	_part(body, _sphere(1.0), mane, Vector3(0, 2.3, -1.05), Vector3.ZERO, Vector3(1.0, 1.05, 0.8))
	for i in 16:
		var a := TAU * i / 16.0
		_part(body, _cylinder(0.0, 0.22, 0.6), mane, Vector3(cos(a) * 0.95, 2.3 + sin(a) * 0.95, -0.95),
				Vector3(0, 0, rad_to_deg(a) - 90))
	var head := _pivot(body, Vector3(0, 2.35, -2.0))
	_part(head, _sphere(0.52), main, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.95, 1.0))
	_part(head, _sphere(0.3), muzzle, Vector3(0, -0.14, -0.42), Vector3.ZERO, Vector3(1.0, 0.75, 1.0))  # broad muzzle
	_part(head, _box(Vector3(0.2, 0.12, 0.12)), dark, Vector3(0, -0.02, -0.7))  # nose
	_part(head, _box(Vector3(0.04, 0.14, 0.04)), dark, Vector3(0, -0.14, -0.7))
	for x in [-0.2, 0.2]:
		_part(head, _sphere(0.08), eye, Vector3(x, 0.17, -0.42))
		_part(head, _sphere(0.035), dark, Vector3(x, 0.17, -0.49))
		_part(head, _box(Vector3(0.2, 0.05, 0.06)), mane, Vector3(x, 0.27, -0.42), Vector3(0, 0, -signf(x) * 15))  # brow
		_part(head, _sphere(0.15), main, Vector3(x * 2.0, 0.45, 0.0), Vector3.ZERO, Vector3(1.0, 1.0, 0.5))  # round ears
		_part(head, _cylinder(0.0, 0.04, 0.16), muzzle, Vector3(x * 0.6, -0.3, -0.62), Vector3(-180, 0, 0))  # fangs
	var jaw := _pivot(head, Vector3(0, -0.32, -0.15))
	_part(jaw, _sphere(0.22), muzzle, Vector3(0, -0.04, -0.28), Vector3.ZERO, Vector3(1.0, 0.45, 1.1))
	jaw.set_meta("open", Vector3(-0.35, 0, 0))
	var tail := _pivot(body, Vector3(0, 1.9, 1.5))
	_part(tail, _cylinder(0.06, 0.09, 1.3), main, Vector3(0, -0.3, 0.55), Vector3(-60, 0, 0))
	_part(tail, _sphere(0.16), mane, Vector3(0, -0.62, 1.12), Vector3.ZERO, Vector3(1.0, 1.4, 1.0))  # the tuft
	return {"legs": legs, "jaws": [jaw], "sway": [tail], "bob": [body, 0.0, 0.05, 1.4]}


## Koleko: a huge fire dog of black, cracked rock with lava glowing through
## the cracks, a crest of flames down his neck and back, tall pointed ears,
## a long snout full of glowing fangs, burning eyes and a tail of fire.
static func fire_dog(model: Node3D, main: StandardMaterial3D) -> Dictionary:
	var lava := _mat(Color(1.0, 0.45, 0.08), true)
	var flame := _mat(Color(1.0, 0.62, 0.15), true)
	var hot := _mat(Color(1.0, 0.9, 0.5), true)
	var dark := _mat(Color(0.05, 0.04, 0.04))
	var legs: Array = []
	# Order: front left, front right, back right, back left (trot pairs share a phase).
	for spot in [Vector3(-0.42, 1.25, -0.95), Vector3(0.42, 1.25, -0.95), Vector3(0.42, 1.25, 0.95), Vector3(-0.42, 1.25, 0.95)]:
		var hip := _pivot(model, spot)
		_part(hip, _cylinder(0.17, 0.25, 1.2), main, Vector3(0, -0.6, 0))
		_part(hip, _box(Vector3(0.36, 0.05, 0.4)), lava, Vector3(0, -0.45, 0))  # a glowing crack
		_part(hip, _sphere(0.22), main, Vector3(0, -1.18, -0.1), Vector3.ZERO, Vector3(1.0, 0.6, 1.4))  # paw
		legs.append(hip)
	var body := _pivot(model, Vector3.ZERO)
	_part(body, _sphere(0.85), main, Vector3(0, 1.75, 0.1), Vector3.ZERO, Vector3(0.8, 0.72, 1.65))  # lean body
	_part(body, _sphere(0.75), main, Vector3(0, 2.0, -0.85), Vector3.ZERO, Vector3(0.95, 0.95, 0.9))  # deep chest
	for i in 5:  # lava cracks along the flanks
		for side in [-1.0, 1.0]:
			_part(body, _box(Vector3(0.04, 0.5, 0.06)), lava, Vector3(side * 0.66, 1.75, -0.6 + i * 0.35), Vector3(0, 0, side * (15 + i * 9)))
	for i in 9:  # the crest of flames from the neck down the back
		var z := -1.25 + i * 0.3
		var top := 2.75 if z < -0.5 else 2.42  # chest, then the back
		_part(body, _cylinder(0.0, 0.2, 0.7 - i * 0.04), flame if i % 2 == 0 else lava, Vector3(0, top, z), Vector3(30, 0, 0))
	var head := _pivot(body, Vector3(0, 2.55, -1.55))
	_part(head, _sphere(0.45), main, Vector3.ZERO, Vector3.ZERO, Vector3(0.95, 0.9, 1.05))
	_part(head, _box(Vector3(0.36, 0.3, 0.65)), main, Vector3(0, -0.1, -0.55))  # long snout
	_part(head, _box(Vector3(0.18, 0.12, 0.1)), dark, Vector3(0, 0.02, -0.88))  # nose
	for x in [-0.18, 0.18]:
		_part(head, _sphere(0.08), hot, Vector3(x, 0.14, -0.36))  # burning eyes
		_part(head, _box(Vector3(0.18, 0.05, 0.06)), dark, Vector3(x, 0.24, -0.38), Vector3(0, 0, -signf(x) * 20))  # glare
		_part(head, _cylinder(0.0, 0.14, 0.55), main, Vector3(x * 1.3, 0.55, 0.05), Vector3(-10, 0, signf(x) * -15))  # tall ears
		_part(head, _cylinder(0.0, 0.07, 0.35), lava, Vector3(x * 1.3, 0.52, 0.0), Vector3(-10, 0, signf(x) * -15))
		_part(head, _cylinder(0.0, 0.035, 0.14), hot, Vector3(x * 0.6, -0.3, -0.75), Vector3(-180, 0, 0))  # fangs
	var jaw := _pivot(head, Vector3(0, -0.25, -0.25))
	_part(jaw, _box(Vector3(0.3, 0.1, 0.6)), main, Vector3(0, -0.05, -0.3))
	_part(jaw, _box(Vector3(0.24, 0.03, 0.5)), lava, Vector3(0, 0.01, -0.3))  # fire in the mouth
	jaw.set_meta("open", Vector3(-0.35, 0, 0))
	var tail := _pivot(body, Vector3(0, 2.0, 1.45))
	_part(tail, _cylinder(0.08, 0.1, 0.9), main, Vector3(0, 0.29, 0.34), Vector3(50, 0, 0))
	_part(tail, _cylinder(0.0, 0.22, 0.8), flame, Vector3(0, 0.83, 0.99), Vector3(50, 0, 0))  # a tail of fire
	_part(tail, _cylinder(0.0, 0.12, 0.55), hot, Vector3(0, 0.75, 0.89), Vector3(50, 0, 0))
	return {"legs": legs, "jaws": [jaw], "sway": [tail], "bob": [body, 0.0, 0.05, 1.6]}


## Pye the Parrot: a giant grey parrot standing on two scaly legs: soft grey
## feathers (paler on the head, darker on the wings), a bright red tail, a
## white face patch round each eye and a big black hooked beak (the lower
## half snaps).
static func parrot(model: Node3D, main: StandardMaterial3D) -> Dictionary:
	var coverts := _mat(Color(0.26, 0.27, 0.3))  # darker grey wing feathers
	var flight := _mat(Color(0.17, 0.18, 0.2))  # dark grey flight feathers
	var red := _mat(Color(0.85, 0.1, 0.08))
	var pale := _mat(Color(0.52, 0.53, 0.56))
	var face := _mat(Color(0.97, 0.95, 0.92))
	var beak := _mat(Color(0.1, 0.1, 0.11))
	var beak_dark := _mat(Color(0.18, 0.17, 0.18))
	var scale_mat := _mat(Color(0.45, 0.42, 0.45))
	var dark := _mat(Color(0.03, 0.03, 0.03))
	var legs: Array = []
	for x in [-0.32, 0.32]:
		var hip := _pivot(model, Vector3(x, 1.0, 0.0))
		_part(hip, _cylinder(0.09, 0.11, 1.0), scale_mat, Vector3(0, -0.5, 0))
		for t in [-25.0, 0.0, 25.0]:  # toes forward
			_part(hip, _cylinder(0.04, 0.06, 0.45), scale_mat, Vector3(sin(deg_to_rad(t)) * 0.2, -0.98, -0.2), Vector3(-90, t, 0))
		_part(hip, _cylinder(0.04, 0.06, 0.35), scale_mat, Vector3(0, -0.98, 0.17), Vector3(90, 0, 0))  # and one back
		legs.append(hip)
	var body := _pivot(model, Vector3.ZERO)
	_part(body, _sphere(0.75), main, Vector3(0, 1.85, 0.05), Vector3(-15, 0, 0), Vector3(0.9, 1.25, 0.85))  # plump upright body
	_part(body, _sphere(0.55), main, Vector3(0, 2.7, -0.12))  # neck and chest
	# The tail: grey at the root, bright red below, hanging down behind.
	var tail := _pivot(body, Vector3(0, 1.3, 0.55))
	_part(tail, _box(Vector3(0.4, 1.0, 0.06)), main, Vector3(0, -0.2, 0.18), Vector3(-25, 0, 0))
	_part(tail, _box(Vector3(0.42, 0.75, 0.08)), red, Vector3(0, -0.95, 0.53), Vector3(-25, 0, 0))  # the red tail
	# Wings folded at the sides: grey shoulders, darker coverts and flight feathers.
	var arms: Array = []
	for side in [-1.0, 1.0]:
		var shoulder := _pivot(body, Vector3(side * 0.68, 2.5, 0.0))
		_part(shoulder, _sphere(0.35), main, Vector3(0, -0.2, 0.05), Vector3.ZERO, Vector3(0.5, 1.0, 1.0))
		_part(shoulder, _box(Vector3(0.12, 0.45, 0.6)), coverts, Vector3(0, -0.6, 0.1), Vector3(-10, 0, 0))
		_part(shoulder, _box(Vector3(0.1, 0.9, 0.55)), flight, Vector3(0, -1.2, 0.25), Vector3(-15, 0, 0))
		arms.append(shoulder)
	var head := _pivot(body, Vector3(0, 3.25, -0.2))
	_part(head, _sphere(0.5), pale, Vector3.ZERO, Vector3.ZERO, Vector3(0.95, 1.0, 1.05))
	for x in [-1.0, 1.0]:
		_part(head, _sphere(0.22), face, Vector3(x * 0.38, 0.0, -0.18), Vector3.ZERO, Vector3(0.4, 1.0, 1.1))  # white face patch
		_part(head, _sphere(0.08), dark, Vector3(x * 0.45, 0.06, -0.2))
		_part(head, _sphere(0.03), face, Vector3(x * 0.5, 0.09, -0.23))  # a glint
	# The big hooked beak.
	_part(head, _sphere(0.26), beak, Vector3(0, -0.02, -0.5), Vector3.ZERO, Vector3(0.8, 1.0, 1.0))
	_part(head, _cylinder(0.0, 0.12, 0.35), beak, Vector3(0, -0.22, -0.66), Vector3(-160, 0, 0))  # the hook
	var jaw := _pivot(head, Vector3(0, -0.2, -0.35))
	_part(jaw, _sphere(0.18), beak_dark, Vector3(0, -0.04, -0.12), Vector3.ZERO, Vector3(0.8, 0.6, 1.0))
	jaw.set_meta("open", Vector3(-0.35, 0, 0))
	return {"legs": legs, "arms": arms, "jaws": [jaw], "sway": [tail], "bob": [body, 0.0, 0.06, 2.0]}


## Dom: a giant orange house cat (tabby stripes, white chest, socks and
## muzzle), with green eyes, pointed ears, whiskers and a tall curling tail.
## Four legs that trot, a jaw that opens to hiss (and to be sick).
static func house_cat(model: Node3D, main: StandardMaterial3D) -> Dictionary:
	var stripe := _mat(Color(0.62, 0.28, 0.05))
	var white := _mat(Color(0.96, 0.94, 0.9))
	var pink := _mat(Color(0.95, 0.55, 0.6))
	var eye := _mat(Color(0.45, 0.9, 0.3), true)
	var dark := _mat(Color(0.04, 0.04, 0.04))
	var legs: Array = []
	# Order: front left, front right, back right, back left (trot pairs share a phase).
	for spot in [Vector3(-0.32, 1.0, -0.8), Vector3(0.32, 1.0, -0.8), Vector3(0.32, 1.0, 0.8), Vector3(-0.32, 1.0, 0.8)]:
		var hip := _pivot(model, spot)
		_part(hip, _cylinder(0.13, 0.17, 1.0), main, Vector3(0, -0.5, 0))
		_part(hip, _cylinder(0.14, 0.14, 0.12), stripe, Vector3(0, -0.35, 0))
		_part(hip, _sphere(0.17), white, Vector3(0, -0.98, -0.06), Vector3.ZERO, Vector3(1.0, 0.6, 1.3))  # white socks
		legs.append(hip)
	var body := _pivot(model, Vector3.ZERO)
	_part(body, _sphere(0.7), main, Vector3(0, 1.45, 0.05), Vector3.ZERO, Vector3(0.75, 0.68, 1.6))  # long body
	_part(body, _sphere(0.45), white, Vector3(0, 1.3, -0.75), Vector3.ZERO, Vector3(0.85, 1.0, 0.8))  # white chest
	for i in 5:  # tabby stripes over the back
		_part(body, TorusMesh.new(), stripe, Vector3(0, 1.45, -0.55 + i * 0.27), Vector3(90, 0, 0),
				Vector3(0.6, 0.15, 0.55))
	var head := _pivot(body, Vector3(0, 2.05, -1.05))
	_part(head, _sphere(0.48), main, Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.95, 1.0))
	_part(head, _sphere(0.22), white, Vector3(0, -0.15, -0.38), Vector3.ZERO, Vector3(1.2, 0.8, 0.8))  # white muzzle
	_part(head, _box(Vector3(0.1, 0.07, 0.06)), pink, Vector3(0, -0.06, -0.55))  # nose
	for i in 3:  # stripes on the brow
		_part(head, _box(Vector3(0.05, 0.22, 0.05)), stripe, Vector3((i - 1) * 0.12, 0.32, -0.36), Vector3(-30, 0, 0))
	for x in [-1.0, 1.0]:
		_part(head, _sphere(0.11), eye, Vector3(x * 0.2, 0.08, -0.4), Vector3.ZERO, Vector3(1.0, 1.0, 0.6))
		_part(head, _box(Vector3(0.025, 0.14, 0.02)), dark, Vector3(x * 0.2, 0.08, -0.47))  # slit pupils
		var ear := _part(head, _cylinder(0.0, 0.2, 0.4), main, Vector3(x * 0.3, 0.45, -0.02), Vector3(0, 0, x * -18))
		_part(ear, _cylinder(0.0, 0.11, 0.25), pink, Vector3(0, -0.04, -0.07))
		for w in 3:  # whiskers
			_part(head, _box(Vector3(0.5, 0.012, 0.012)), white, Vector3(x * 0.38, -0.14 - w * 0.05, -0.42), Vector3(0, x * 10, x * (w - 1) * 10))
	var jaw := _pivot(head, Vector3(0, -0.24, -0.2))
	_part(jaw, _sphere(0.16), white, Vector3(0, -0.03, -0.2), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
	jaw.set_meta("open", Vector3(-0.35, 0, 0))
	# A tall tail curling up at the tip.
	var tail := _pivot(body, Vector3(0, 1.6, 1.1))
	_part(tail, _cylinder(0.08, 0.1, 1.0), main, Vector3(0, 0.45, 0.2), Vector3(20, 0, 0))
	_part(tail, _cylinder(0.07, 0.08, 0.5), stripe, Vector3(0, 1.05, 0.28), Vector3(-25, 0, 0))
	_part(tail, _sphere(0.08), main, Vector3(0, 1.3, 0.18))
	return {"legs": legs, "jaws": [jaw], "sway": [tail], "bob": [body, 0.0, 0.04, 1.6]}
