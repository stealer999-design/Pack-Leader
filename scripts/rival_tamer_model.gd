class_name RivalTamerModel
extends PersonModel
## The rival tamer, modelled on a reference picture: a tall, lean man in a red
## cowboy hat with a studded band, a short-sleeved red work shirt (open at the
## collar, buttoned, with a chest pocket), dark worn jeans with a cargo pocket,
## a brown leather belt with a silver buckle and brown leather boots, holding a
## battered wooden bat down at his side.
##
## Smooth lofted shapes (not boxes), with real proportions (a small head on a
## long body), and photographic cloth, denim, leather, felt, skin and wood
## (resources/textures/rival/, cut from the reference) mapped on with
## triplanar projection. It keeps PersonModel's joints (hips, knees,
## shoulders, elbows, body, head), so it walks and swings like the players.

const TEX := "res://resources/textures/rival/%s.png"
const SEGMENTS := 24

var _textures := {}


func build(_body_material: StandardMaterial3D, hair_color: Color) -> void:
	rest_arm = 0.08  # the bat hangs at his side, arm almost straight
	rest_elbow = 0.18
	var shirt_mat := _cloth(Color(0.68, 0.33, 0.33))  # faded red work shirt
	var jeans := _photo("jeans", 7.0, Color(1.05, 1.05, 1.1))
	var leather := _photo("boot", 8.0, Color(1.1, 1.05, 1.0))
	var felt := _cloth(Color(0.6, 0.11, 0.11))  # red felt
	var skin := _cloth(Color(0.78, 0.58, 0.46))  # tanned skin
	var belt_mat := _plain(Color(0.33, 0.2, 0.12), 0.6)
	var wood := _photo("bat", 5.0, Color(1.1, 1.05, 1.0))
	var hair := _plain(hair_color.lightened(0.08), 0.6)
	var silver := _plain(Color(0.8, 0.8, 0.82), 0.35)
	silver.metallic = 0.3  # (fully metallic reads black with nothing to reflect)
	var sole := _plain(Color(0.16, 0.11, 0.08), 0.9)

	# Legs: long, lean, in slightly baggy jeans down over the boots.
	for x in [-0.105, 0.105]:
		var hip := _pivot(self, Vector3(x, 0.92, 0))
		_loft(hip, [[0.04, 0.115, 0.125], [-0.1, 0.105, 0.115], [-0.25, 0.09, 0.1], [-0.42, 0.075, 0.085], [-0.47, 0.072, 0.08]], jeans, Vector3.ZERO, Basis.IDENTITY, false)
		if x > 0.0:  # a cargo pocket on the outside of the left thigh
			var pocket := _part(hip, _box(Vector3(0.03, 0.14, 0.1)), jeans, Vector3(0.095, -0.24, 0.0))
			pocket.rotation_degrees.z = 3.0
		var knee := _pivot(hip, Vector3(0, -0.45, 0))
		_loft(knee, [[0.02, 0.073, 0.082], [-0.12, 0.066, 0.074], [-0.3, 0.06, 0.066], [-0.36, 0.068, 0.072]], jeans, Vector3.ZERO, Basis.IDENTITY, false)
		# The boot: a shaft under the jeans, the foot, a sole and a heel.
		_loft(knee, [[-0.3, 0.058, 0.064], [-0.42, 0.062, 0.07]], leather)
		var foot := _pivot(knee, Vector3(0, -0.43, -0.06))
		_loft(foot, [[0.04, 0.06, 0.1], [-0.02, 0.065, 0.14], [-0.05, 0.062, 0.14]], leather, Vector3(0, 0, -0.03))
		_part(foot, _box(Vector3(0.13, 0.025, 0.29)), sole, Vector3(0, -0.06, -0.03))
		_part(foot, _box(Vector3(0.11, 0.04, 0.07)), sole, Vector3(0, -0.05, 0.08))  # heel
		_hips.append(hip)
		_knees.append(knee)

	_body = _pivot(self, Vector3.ZERO)
	# Torso: narrow waist, broad chest and shoulders, in the shirt.
	shirt = _loft(_body, [[0.84, 0.155, 0.1], [0.95, 0.152, 0.104], [1.08, 0.17, 0.112], [1.2, 0.2, 0.124],
			[1.32, 0.225, 0.122], [1.41, 0.215, 0.108], [1.46, 0.16, 0.085], [1.49, 0.08, 0.06], [1.5, 0.055, 0.05]], shirt_mat)
	# Belt and buckle.
	_loft(_body, [[0.86, 0.165, 0.11], [0.91, 0.167, 0.112]], belt_mat)
	_part(_body, _box(Vector3(0.07, 0.05, 0.02)), silver, Vector3(0, 0.885, -0.115))
	# The open collar: a V of skin at the throat, and the two collar points.
	_part(_body, _prism(0.1, 0.13), skin, Vector3(0, 1.4, -0.105), Vector3(0, 0, 180))
	for side in [-1.0, 1.0]:
		var flap := _part(_body, _box(Vector3(0.085, 0.07, 0.015)), shirt_mat, Vector3(side * 0.06, 1.455, -0.085))
		flap.rotation_degrees = Vector3(-30, side * 20, side * 35)
	# Buttons down the front, and a pocket on the left of the chest.
	for i in 4:
		_part(_body, _sphere(0.009), _plain(Color(0.85, 0.82, 0.78), 0.4), Vector3(0, 1.3 - i * 0.12, -0.122 - 0.004 * (1 - i / 3.0)))
	_part(_body, _box(Vector3(0.08, 0.075, 0.012)), shirt_mat, Vector3(0.09, 1.26, -0.125))
	# Neck and head.
	_loft(_body, [[1.46, 0.052, 0.052], [1.56, 0.048, 0.05]], skin)
	_loft(_body, [[1.54, 0.05, 0.06], [1.57, 0.075, 0.085], [1.62, 0.088, 0.1], [1.68, 0.093, 0.105], [1.73, 0.09, 0.1],
			[1.77, 0.072, 0.085], [1.795, 0.035, 0.045]], skin, Vector3(0, 0, -0.005))
	_part(_body, _box(Vector3(0.12, 0.04, 0.06)), skin, Vector3(0, 1.57, -0.06))  # jaw
	_head = _pivot(_body, Vector3(0, 1.7, 0))
	_build_rival_face(hair, skin)
	# The hat: a creased crown and a wide brim curled up at the sides.
	var hat := _pivot(_head, Vector3.ZERO)
	_loft(hat, [[0.06, 0.1, 0.115], [0.12, 0.096, 0.11], [0.16, 0.085, 0.1], [0.175, 0.06, 0.08]], felt)
	_part(hat, _box(Vector3(0.02, 0.03, 0.17)), felt, Vector3(0, 0.17, 0))  # the crease on top
	_loft(hat, [[0.06, 0.103, 0.118], [0.085, 0.103, 0.118]], belt_mat)  # band
	for i in 7:
		var ang := TAU * i / 7.0
		_part(hat, _sphere(0.012), silver, Vector3(cos(ang) * 0.105, 0.072, sin(ang) * 0.12))
	var brim := MeshInstance3D.new()
	brim.mesh = _brim(0.1, 0.27, 0.06)
	brim.material_override = felt
	brim.position.y = 0.055
	hat.add_child(brim)
	_hat = hat

	# Arms: lean and long, short sleeves to the biceps, bare forearms.
	for x in [-0.245, 0.245]:
		var shoulder := _pivot(_body, Vector3(x, 1.4, 0))
		_loft(shoulder, [[0.05, 0.075, 0.08], [0.0, 0.078, 0.08], [-0.14, 0.072, 0.074], [-0.2, 0.07, 0.072]], shirt_mat, Vector3.ZERO, Basis.IDENTITY, false)
		_loft(shoulder, [[-0.19, 0.052, 0.054], [-0.27, 0.046, 0.048], [-0.31, 0.042, 0.044]], skin, Vector3.ZERO, Basis.IDENTITY, false)
		var elbow := _pivot(shoulder, Vector3(0, -0.31, 0))
		_loft(elbow, [[0.0, 0.042, 0.044], [-0.08, 0.045, 0.046], [-0.2, 0.034, 0.036], [-0.25, 0.03, 0.034]], skin, Vector3.ZERO, Basis.IDENTITY, false)
		_loft(elbow, [[-0.25, 0.034, 0.045], [-0.3, 0.04, 0.05], [-0.34, 0.028, 0.04]], skin)  # hand
		_shoulders.append(shoulder)
		_elbows.append(elbow)
	_bat_arm = _shoulders[1]
	# The bat, held low in the right hand, the barrel down and forward.
	var bat := _pivot(_elbows[1], Vector3(0, -0.3, 0))
	bat.name = "Bat"
	bat.rotation.x = -1.15
	_loft(bat, [[0.06, 0.02, 0.02], [0.0, 0.019, 0.019], [-0.15, 0.022, 0.022], [-0.45, 0.04, 0.04], [-0.7, 0.05, 0.05], [-0.74, 0.03, 0.03]],
			wood, Vector3.ZERO, Basis(Vector3.RIGHT, -PI / 2.0))
	_spikes = _pivot(bat, Vector3.ZERO)
	_spikes.visible = false
	_chain = _pivot(bat, Vector3.ZERO)
	_chain.visible = false
	_rest_bat()


## His face: deep-set dark eyes under heavy brows, a straight nose, a firm
## mouth and stubble, framed by messy dark hair over the ears.
func _build_rival_face(hair: StandardMaterial3D, skin: StandardMaterial3D) -> void:
	var eye := _plain(Color(0.1, 0.07, 0.05), 0.2)
	eye.set_meta("smooth", true)
	var white := _plain(Color(0.92, 0.9, 0.86), 0.3)
	white.set_meta("smooth", true)
	var brow := _plain(Color(0.12, 0.08, 0.06), 0.9)
	var lips := _plain(Color(0.55, 0.36, 0.32), 0.7)
	var stubble := _plain(Color(0.35, 0.28, 0.24), 1.0)
	stubble.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stubble.albedo_color.a = 0.12
	for side in [-1.0, 1.0]:
		var x: float = side * 0.04
		_part(_body, _sphere(0.016), white, Vector3(x, 1.68, -0.092), Vector3.ZERO, Vector3(1.3, 0.7, 0.5))
		_part(_body, _sphere(0.009), eye, Vector3(x, 1.68, -0.1))
		_part(_body, _box(Vector3(0.045, 0.012, 0.02)), brow, Vector3(x, 1.7, -0.098), Vector3(0, 0, side * -8))
		_part(_body, _sphere(0.022), skin, Vector3(side * 0.094, 1.67, 0.0), Vector3.ZERO, Vector3(0.45, 1.0, 0.75))  # ears
	_part(_body, _prism(0.026, 0.05), skin, Vector3(0, 1.655, -0.106), Vector3(-15, 0, 0))  # nose
	_part(_body, _box(Vector3(0.04, 0.007, 0.012)), lips, Vector3(0, 1.618, -0.098))  # mouth
	_part(_body, _sphere(0.07), stubble, Vector3(0, 1.6, -0.055), Vector3.ZERO, Vector3(1.15, 0.6, 0.75))
	# Messy dark hair: a cap with tufts falling over the forehead and ears.
	_part(_body, _sphere(0.1), hair, Vector3(0, 1.74, 0.018), Vector3.ZERO, Vector3(1.0, 0.72, 1.04))
	# Tufts: a few falling over the forehead, the rest over the ears and the nape.
	var tufts := [Vector3(-0.05, 1.765, -0.07), Vector3(0.04, 1.77, -0.072), Vector3(-0.088, 1.715, 0.03),
			Vector3(0.088, 1.715, 0.03), Vector3(-0.06, 1.675, 0.075), Vector3(0.06, 1.675, 0.075), Vector3(0.0, 1.665, 0.09)]
	var spin := [10.0, -15.0, 20.0, -20.0, 12.0, -12.0, 0.0]
	for i in tufts.size():
		_part(_body, _sphere(0.032), hair, tufts[i], Vector3(spin[i], spin[i] * 2.0, spin[i]), Vector3(1.0, 0.6, 0.85))


# --- Shapes --------------------------------------------------------------------------

## A smooth body of revolution-ish rings: each ring = [y, x radius, z radius]
## (in order, top or bottom first), joined into one mesh with soft normals.
func _loft(parent: Node3D, rings: Array, mat: Material, offset := Vector3.ZERO, turn := Basis.IDENTITY, caps := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for r in rings:
		var ring := []
		for i in SEGMENTS + 1:
			var a := TAU * i / SEGMENTS
			ring.append(turn * Vector3(cos(a) * float(r[1]), float(r[0]), sin(a) * float(r[2])) + offset)
		pts.append(ring)
	for j in pts.size() - 1:
		for i in SEGMENTS:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i + 1]
			var c: Vector3 = pts[j + 1][i]
			var d: Vector3 = pts[j + 1][i + 1]
			if float(rings[j][0]) > float(rings[j + 1][0]):  # keep faces pointing outwards
				st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
				st.add_vertex(b); st.add_vertex(d); st.add_vertex(c)
			else:
				st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
				st.add_vertex(b); st.add_vertex(c); st.add_vertex(d)
	# Close both ends (limbs leave them open: they're hidden inside the next part).
	for end in ([0, pts.size() - 1] if caps else []):
		var center := Vector3.ZERO
		for p: Vector3 in pts[end]:
			center += p
		center /= pts[end].size()
		var top: bool = end == 0 if float(rings[0][0]) > float(rings[-1][0]) else end == pts.size() - 1
		for i in SEGMENTS:
			if top:
				st.add_vertex(center); st.add_vertex(pts[end][i + 1]); st.add_vertex(pts[end][i])
			else:
				st.add_vertex(center); st.add_vertex(pts[end][i]); st.add_vertex(pts[end][i + 1])
	st.index()  # share vertices, so the normals are smooth across the rings
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh


## A cowboy hat's brim: a flat ring from `inner` to `outer`, its sides curled
## up by `curl` (more the further out), the front and back flat.
func _brim(inner: float, outer: float, curl: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	var grid := []
	for j in rings + 1:
		var r := lerpf(inner, outer, j / float(rings))
		var row := []
		for i in SEGMENTS + 1:
			var a := TAU * i / SEGMENTS
			var side := absf(cos(a))  # 1 at the sides (x), 0 front and back
			var lift := curl * pow(j / float(rings), 2.0) * pow(side, 2.0)
			row.append(Vector3(cos(a) * r, lift - 0.012 * (1.0 - side) * j / rings, sin(a) * r * 1.12))
		grid.append(row)
	for j in rings:
		for i in SEGMENTS:
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i + 1]
			var c: Vector3 = grid[j + 1][i]
			var d: Vector3 = grid[j + 1][i + 1]
			for tri in [[a, c, b], [b, c, d], [a, b, c], [b, d, c]]:  # both faces
				for v: Vector3 in tri:
					st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _prism(width: float, height: float) -> PrismMesh:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(width, height, 0.02)
	return mesh


## A material painted with one of the reference's photo swatches, projected
## from three sides (no UVs needed), `scale` repeats per unit.
func _photo(name: String, scale: float, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TEX % name)
	mat.albedo_color = tint
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale
	mat.roughness = 0.85
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


## A plain material with the game's realistic fine grain and bumps (ModelLook).
func _cloth(color: Color) -> StandardMaterial3D:
	var mat := _plain(color, 0.85)
	ModelLook.realistic(mat)
	mat.albedo_color = color  # keep the reference's colour (realistic() mutes it)
	return mat


func _plain(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	return mat
