extends SceneTree
## Bakes the tamer's clothes (models/tamer/gear/<name>.res), made from the hero
## himself (models/tamer/hero.glb) so they fit him: a garment is the part of
## his body it covers, cut cleanly along its edges (the neckline, waist, cuffs,
## hems), pushed out a little along the surface and keeping the same skin
## weights, so it bends and swings with him. Its edges get a hem (a thickness),
## and some get more: lapels down an open front, a stand-up collar, a long
## coat's skirt, quilting, knee pads, baggy thighs, a sole, a boot's cuff.
## Hats are shapes riding the head bone. A mesh's first surface takes the
## item's colour (ItemDB.OUTFIT_COLORS), the second (when there is one) is trim.
## Also makes folds.png: the creases, seams and wear of the hero's own clothes
## (his texture's light and shade, without its colours) for the garments' cloth.
##   godot --headless --path . -s res://scripts/tools/hero_gear.gd
## Sizes are the hero's own (model units, standing in his rest pose: about 1.7
## tall, arms out, facing +Z, his left at +X).

const MODEL := "res://models/tamer/hero.glb"
const OUT := "res://models/tamer/gear/"
const FOLDS_SIZE := 1024
const FOLDS_BLUR := 12  ## (pixels) the creases are the paint against its surroundings this far round
const NECK_CUT := 1.445  ## A jacket's neckline at the side of the neck (a little lower in front)...
const WRIST := 0.595  ## ...and its cuffs (how far out from the middle).
const BELT := 0.975  ## Trousers come up to here...
const ANKLE := 0.16  ## ...and down to here.
const NECK := Vector3(0.008, 0.0, -0.045)  ## The middle of the neck, seen from above.
const MIDDLE := Vector3(0.0, 0.0, -0.02)  ## The middle of the body, seen from above.
const FRONT_X := 0.005  ## The middle of his front (an open jacket's opening).
const KNEE_Y := 0.52
const HEAD := Vector3(0.003, 1.625, -0.018)  ## Where a hat's band sits (the middle of the head).

## The garments: [name, kind, settings]. thick: how far it stands off the body;
## waist: a jacket's length; vneck: an open front's width [at the waist, at
## the neck]; collar: "lapel" (folded over, down the open front) or "stand";
## skirt: a long coat's hem height; quilt: a padded coat's puffs; pads: knee
## pads standing this far off; baggy: full thighs; top: a boot's height; sole:
## the sole's height; cuff: a boot top folded over [out, down].
const PIECES := [
	["jacket_leather", "jacket", {"waist": 0.9, "thick": 0.011, "vneck": [0.045, 0.085], "collar": "lapel"}],
	["jacket_padded", "jacket", {"waist": 0.84, "thick": 0.02, "quilt": 0.007, "collar": "stand"}],
	["jacket_duster", "jacket", {"waist": 0.86, "thick": 0.013, "vneck": [0.04, 0.08], "collar": "lapel", "skirt": 0.4}],
	["pants_work", "pants", {"thick": 0.007}],
	["pants_reinforced", "pants", {"thick": 0.008, "pads": 0.013}],
	["pants_breeches", "pants", {"thick": 0.007, "baggy": 0.026}],
	["boots_sneakers", "boots", {"top": 0.105, "thick": 0.011, "sole": 0.028}],
	["boots_hiking", "boots", {"top": 0.235, "thick": 0.013, "sole": 0.032}],
	["boots_pathfinder", "boots", {"top": 0.4, "thick": 0.015, "sole": 0.03, "cuff": [0.024, 0.045]}],
]


## A garment's spot: a point on the body (rest pose) with its normals, UV
## and skinning. `copy` tells apart the copies of a point that UV seams make;
## `id` is the point itself (for finding a garment's edges).
class Spot:
	var p: Vector3
	var n: Vector3  ## Smoothed: the way the garment stands off.
	var shade: Vector3  ## The surface's own normal, for its lighting.
	var uv: Vector2
	var bones: PackedInt32Array
	var weights: PackedFloat32Array
	var region: String
	var copy: String
	var id: String


var verts: PackedVector3Array
var normals: PackedVector3Array
var uvs: PackedVector2Array
var bones: PackedInt32Array
var wts: PackedFloat32Array
var idx: PackedInt32Array
var corners: Array[Spot] = []
var head_bind := -1
var binds := {}
var made := {}  ## Corners made by cuts, by copy.


func _init() -> void:
	var scene := (load(MODEL) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	var body: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var arrays := body.mesh.surface_get_arrays(0)
	verts = arrays[Mesh.ARRAY_VERTEX]
	normals = arrays[Mesh.ARRAY_NORMAL]
	uvs = arrays[Mesh.ARRAY_TEX_UV]
	bones = arrays[Mesh.ARRAY_BONES]
	wts = arrays[Mesh.ARRAY_WEIGHTS]
	idx = arrays[Mesh.ARRAY_INDEX]
	for b in body.skin.get_bind_count():
		binds[String(body.skin.get_bind_name(b)).replace("mixamorig_", "")] = b
	head_bind = binds["Head"]
	_prepare(body.skin)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_folds((body.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture)
	for piece: Array in PIECES:
		_save(_garment(piece[1], piece[2]), piece[0])
	_save(_shaped_hat(FEDORA), "hat_fedora")
	_save(_shaped_hat(COWBOY), "hat_cowboy")
	_save(_hat_warden(), "hat_warden")
	quit()


func _save(mesh: ArrayMesh, mesh_name: String) -> void:
	var tris := 0
	for s in mesh.get_surface_count():
		tris += mesh.surface_get_array_index_len(s) / 3
	print("hero_gear: %s, %d surfaces, %d triangles: %s" % [mesh_name, mesh.get_surface_count(), tris,
			error_string(ResourceSaver.save(mesh, OUT + mesh_name + ".res"))])


## A corner for each of the body's vertices: normals smoothed over every copy
## of a point, and the region of the body that moves it most.
func _prepare(skin: Skin) -> void:
	var first := {}
	var weld := PackedInt32Array()
	weld.resize(verts.size())
	var sums := {}
	for v in verts.size():
		var key := Vector3i((verts[v] * 20000.0).round())
		if not first.has(key):
			first[key] = v
			sums[v] = Vector3.ZERO
		weld[v] = first[key]
		sums[weld[v]] += normals[v]
	for v in verts.size():
		var c := Spot.new()
		c.p = verts[v]
		c.n = (sums[weld[v]] as Vector3).normalized()
		c.shade = normals[v]
		c.uv = uvs[v]
		c.bones = bones.slice(v * 4, v * 4 + 4)
		c.weights = wts.slice(v * 4, v * 4 + 4)
		c.copy = str(v)
		c.id = str(weld[v])
		var best := 0
		for j in 4:
			if c.weights[j] > c.weights[best]:
				best = j
		var bone := String(skin.get_bind_name(c.bones[best])).replace("mixamorig_", "")
		if bone.begins_with("Head") or bone.begins_with("Bone_") or bone == "headfront":
			c.region = "head"
		elif bone.contains("Hand"):
			c.region = "hand"
		elif bone.contains("Foot") or bone.contains("Toe"):
			c.region = "feet"
		elif bone.contains("UpLeg") or bone.ends_with("Leg"):
			c.region = "legs"
		elif bone == "Hips":
			c.region = "hips"
		else:
			c.region = "torso"  # spine, neck, shoulders, arms
		corners.append(c)


# --- Garments made from the body ---------------------------------------------------

## The cuts that shape a kind of garment: [name, side] where side(p) >= 0 keeps p.
func _cuts(kind: String, s: Dictionary) -> Array:
	match kind:
		"jacket":
			var cuts := [
				["waist", func(p: Vector3) -> float: return p.y - s.waist],
				["neck", func(p: Vector3) -> float: return NECK_CUT - 0.22 * (p.z - NECK.z) - p.y],
				["wrist", func(p: Vector3) -> float: return WRIST - absf(p.x)],
			]
			if s.has("vneck"):
				cuts.append(["vneck", func(p: Vector3) -> float: return _vneck(p, s)])
			return cuts
		"pants":
			return [
				["belt", func(p: Vector3) -> float: return BELT - p.y],
				["ankle", func(p: Vector3) -> float: return p.y - ANKLE],
			]
		"boots":
			return [["top", func(p: Vector3) -> float: return s.top - p.y]]
	return []


## An open front, wider towards the neck: >= 0 outside the opening (and all
## round the back).
func _vneck(p: Vector3, s: Dictionary) -> float:
	var up := clampf((p.y - s.waist) / (NECK_CUT - s.waist), 0.0, 1.0)
	var half := lerpf(s.vneck[0], s.vneck[1], up * up) * 0.5
	return maxf(absf(p.x - FRONT_X) - half, (MIDDLE.z + 0.02) - p.z)


## How far a garment stands off the body at a corner.
func _offset(kind: String, s: Dictionary, c: Spot) -> float:
	var p := c.p
	var out: float = s.thick
	if s.has("quilt"):  # puffy rows of quilting: round the body, and round the sleeves
		var along := p.y if absf(p.x) < 0.2 else absf(p.x) * 1.3
		out += s.quilt * absf(sin(along * 46.0))
	if s.has("baggy") and c.region == "legs":  # full at the thigh, gathered at the knee
		out += s.baggy * sin(clampf((p.y - KNEE_Y) / (BELT - 0.08 - KNEE_Y), 0.0, 1.0) * PI)
	if kind == "jacket":
		out += {"hips": 0.01, "legs": 0.016}.get(c.region, 0.0)  # over the trousers
	return out


func _garment(kind: String, s: Dictionary) -> ArrayMesh:
	var cuts := _cuts(kind, s)
	var offset := func(c: Spot) -> float: return _offset(kind, s, c)
	var main := []  # polygons (arrays of corners) in the main colour
	var trim := []
	var pads := []
	for t in range(0, idx.size(), 3):
		var poly := [corners[idx[t]], corners[idx[t + 1]], corners[idx[t + 2]]]
		if kind == "jacket" and poly.any(func(c: Spot) -> bool: return c.region == "head"):
			continue  # (hair down the back of the neck)
		for cut: Array in cuts:
			poly = _clip(poly, cut[1], cut[0])
			if poly.size() < 3:
				break
		if poly.size() < 3:
			continue
		if s.has("sole"):  # split at the sole
			var sole := _clip(poly, func(p: Vector3) -> float: return s.sole - p.y, "sole")
			if sole.size() >= 3:
				trim.append(sole)
			poly = _clip(poly, func(p: Vector3) -> float: return p.y - s.sole, "sole")
			if poly.size() < 3:
				continue
		main.append(poly)
		if s.has("pads"):
			var pad := poly
			for cut: Array in [["pad_top", func(p: Vector3) -> float: return KNEE_Y + 0.06 - p.y],
					["pad_low", func(p: Vector3) -> float: return p.y - (KNEE_Y - 0.055)],
					["pad_front", func(p: Vector3) -> float: return p.z + 0.004]]:
				pad = _clip(pad, cut[1], cut[0])
				if pad.size() < 3:
					break
			if pad.size() >= 3:
				pads.append(pad)
	var mesh := ArrayMesh.new()
	var st := _begin()
	var edges := _shell(st, main, offset)
	if s.has("collar"):
		_collar(st, edges, s, offset, cuts)
	if s.has("skirt"):
		_skirt(st, edges, s, offset)
	st.index()
	st.commit(mesh)
	if not trim.is_empty() or not pads.is_empty() or s.has("cuff"):
		st = _begin()
		_shell(st, trim, func(c: Spot) -> float: return _offset(kind, s, c) + 0.003)
		if not pads.is_empty():
			_shell(st, pads, func(c: Spot) -> float: return _offset(kind, s, c) + s.pads)
		if s.has("cuff"):
			_cuff(st, edges, s, offset)
		st.index()
		st.commit(mesh)
	return mesh


## The part of polygon `poly` where side(p) >= 0 (Sutherland-Hodgman). A corner
## a cut makes on an edge is named after the edge and the cut, so the polygons
## either side of the edge share it.
func _clip(poly: Array, side: Callable, cut: String) -> Array:
	var out := []
	for i in poly.size():
		var a: Spot = poly[i]
		var b: Spot = poly[(i + 1) % poly.size()]
		var fa: float = side.call(a.p)
		var fb: float = side.call(b.p)
		if fa >= 0.0:
			out.append(a)
		if (fa >= 0.0) != (fb >= 0.0):
			out.append(_between(a, b, fa / (fa - fb), cut))
	return out


func _between(a: Spot, b: Spot, t: float, cut: String) -> Spot:
	var copy := "%s~%s~%s" % ([a.copy, b.copy, cut] if a.copy < b.copy else [b.copy, a.copy, cut])
	if made.has(copy):
		return made[copy]
	var c := Spot.new()
	c.p = a.p.lerp(b.p, t)
	c.n = a.n.lerp(b.n, t).normalized()
	c.shade = a.shade.lerp(b.shade, t).normalized()
	c.uv = a.uv.lerp(b.uv, t)
	var mix := {}  # the two corners' skinning blended (the four strongest kept)
	for j in 4:
		mix[a.bones[j]] = float(mix.get(a.bones[j], 0.0)) + a.weights[j] * (1.0 - t)
		mix[b.bones[j]] = float(mix.get(b.bones[j], 0.0)) + b.weights[j] * t
	var order: Array = mix.keys()
	order.sort_custom(func(x: int, y: int) -> bool: return mix[x] > mix[y])
	var total := 0.0
	for j in mini(4, order.size()):
		total += mix[order[j]]
	for j in 4:
		c.bones.append(order[j] if j < order.size() else 0)
		c.weights.append(mix[order[j]] / total if j < order.size() else 0.0)
	c.region = a.region if t < 0.5 else b.region
	c.copy = copy
	c.id = "%s~%s~%s" % ([a.id, b.id, cut] if a.id < b.id else [b.id, a.id, cut])
	made[copy] = c
	return c


func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _add(st: SurfaceTool, c: Spot, at: Vector3, normal: Vector3) -> void:
	st.set_normal(normal)
	st.set_uv(c.uv)
	st.set_bones(c.bones)
	st.set_weights(c.weights)
	st.add_vertex(at)


func _out(c: Spot, offset: Callable) -> Vector3:
	return c.p + c.n * float(offset.call(c))


## The polygons (fanned into triangles), each corner pushed out by `offset`;
## then a hem along the open edges, back down to the skin. Returns those
## edges: [from, to, a corner inside], in their polygons' winding.
func _shell(st: SurfaceTool, polys: Array, offset: Callable) -> Array:
	var count := {}
	for poly: Array in polys:
		for k in poly.size():
			var key := _edge(poly[k], poly[(k + 1) % poly.size()])
			count[key] = int(count.get(key, 0)) + 1
		for k in range(1, poly.size() - 1):
			for c: Spot in [poly[0], poly[k], poly[k + 1]]:
				_add(st, c, _out(c, offset), c.shade)
	var edges := []
	for poly: Array in polys:
		for k in poly.size():
			var a: Spot = poly[k]
			var b: Spot = poly[(k + 1) % poly.size()]
			if count[_edge(a, b)] == 1:
				edges.append([a, b, poly[(k + 2) % poly.size()]])
	for e: Array in edges:  # the hem
		var a: Spot = e[0]
		var b: Spot = e[1]
		var away := ((a.p + b.p) * 0.5 - (e[2] as Spot).p).normalized()
		_quad(st, [a, b, b, a], [_out(a, offset), _out(b, offset), b.p + b.n * 0.002, a.p + a.n * 0.002], away)
	return edges


func _edge(a: Spot, b: Spot) -> String:
	return a.id + "|" + b.id if a.id < b.id else b.id + "|" + a.id


## Two triangles (corners in order round the quad), each corner skinned like
## the corner in `from`, wound so their front faces `normal`.
func _quad(st: SurfaceTool, from: Array, at: Array, normal: Vector3) -> void:
	for k in _winding(at, normal):
		_add(st, from[k], at[k], normal)


## The order to draw a quad's two triangles in so they face `normal` (Godot's
## front faces wind clockwise).
func _winding(at: Array, normal: Vector3) -> Array:
	var front := ((at[2] as Vector3) - (at[0] as Vector3)).cross((at[1] as Vector3) - (at[0] as Vector3))
	return [0, 1, 2, 0, 2, 3] if front.dot(normal) >= 0.0 else [0, 2, 1, 0, 3, 2]


## Is a corner on one of the cuts named?
func _on(c: Spot, cuts: Array, names: Array) -> bool:
	for cut: Array in cuts:
		if cut[0] in names and absf((cut[1] as Callable).call(c.p)) < 0.002:
			return true
	return false


## The collar: "stand" rises round the neck; "lapel" folds over and lies down
## the open front.
func _collar(st: SurfaceTool, edges: Array, s: Dictionary, offset: Callable, cuts: Array) -> void:
	for e: Array in edges:
		var a: Spot = e[0]
		var b: Spot = e[1]
		var neck := _on(a, cuts, ["neck"]) and _on(b, cuts, ["neck"])
		var front: bool = _on(a, cuts, ["vneck"]) and _on(b, cuts, ["vneck"]) and a.p.y > s.waist + 0.03
		if not neck and not front:
			continue
		var rows := []  # the collar's rows of points, from the jacket's edge out
		for c: Spot in [a, b]:
			var base := _out(c, offset)
			var out := Vector3(c.p.x - NECK.x, 0.0, c.p.z - NECK.z).normalized()
			if s.collar == "stand":
				rows.append([base, base + Vector3.UP * 0.045 + out * 0.012])
			elif neck:  # turned over: up a little, then out and down
				var fold := base + Vector3.UP * 0.024 + out * 0.006
				rows.append([base, fold, fold + out * 0.032 - Vector3.UP * 0.016])
			else:  # a lapel down the front: lying out to the side
				var side := Vector3(signf(c.p.x - FRONT_X), 0.0, 0.0)
				var flat := (side - c.n * side.dot(c.n)).normalized()
				rows.append([base, base + c.n * 0.006 + flat * 0.004, base + c.n * 0.008 + flat * 0.034])
		for k in (rows[0] as Array).size() - 1:
			var at: Array = [rows[0][k], rows[1][k], rows[1][k + 1], rows[0][k + 1]]
			var normal: Vector3 = ((at[1] as Vector3) - (at[0] as Vector3)).cross((at[3] as Vector3) - (at[0] as Vector3)).normalized()
			if normal.dot(a.n) < 0.0:
				normal = -normal
			_quad(st, [a, b, b, a], at, normal)


## A long coat's skirt: from the jacket's bottom edge down to `skirt`, standing
## clear of the hips and thighs (and baggy trousers) all round, a little flared;
## its lower part follows the thighs.
func _skirt(st: SurfaceTool, edges: Array, s: Dictionary, offset: Callable) -> void:
	var bins := 48
	var rows := 8
	# How far the body reaches out in each direction (seen from above) at each
	# of the skirt's rows, and anywhere above it (cloth hangs down from the
	# widest point), clear by a little, smoothed round.
	var reach := []
	for k in rows + 1:
		var row := PackedFloat32Array()
		row.resize(bins)
		reach.append(row)
	for v in verts.size():
		var p := verts[v]
		if p.y < s.skirt or p.y > s.waist or absf(p.x) > 0.3:
			continue
		var d := Vector2(p.x - MIDDLE.x, p.z - MIDDLE.z)
		var bin := int(fposmod(d.angle(), TAU) / TAU * bins) % bins
		var from := ceili((s.waist - p.y) / (s.waist - s.skirt) * rows)
		for k in range(clampi(from, 0, rows), rows + 1):
			reach[k][bin] = maxf(reach[k][bin], d.length() + 0.035)
	for k in rows + 1:
		var widest := PackedFloat32Array()
		widest.resize(bins)
		for i in bins:
			for j in range(-2, 3):
				widest[i] = maxf(widest[i], reach[k][(i + j + bins) % bins])
		for i in bins:
			var round_about := 0.0
			for j in range(-2, 3):
				round_about += widest[(i + j + bins) % bins] / 5.0
			reach[k][i] = round_about
	for e: Array in edges:
		var a: Spot = e[0]
		var b: Spot = e[1]
		if absf(a.p.y - s.waist) > 0.002 or absf(b.p.y - s.waist) > 0.002:
			continue
		var ring := []  # rows of [corner, position, skinning] for a and b
		for k in rows + 1:
			var f := float(k) / rows
			var row := []
			for c: Spot in [a, b]:
				var top := _out(c, offset)
				var d := Vector2(top.x - MIDDLE.x, top.z - MIDDLE.z)
				var bin := int(fposmod(d.angle(), TAU) / TAU * bins) % bins
				var r := maxf(d.length(), reach[k][bin]) + 0.04 * f if k > 0 else d.length()
				var flat := d.normalized() * r
				row.append([c, Vector3(MIDDLE.x + flat.x, lerpf(top.y, s.skirt, f), MIDDLE.z + flat.y), _skirt_weights(c, f)])
			ring.append(row)
		for k in rows:
			var q := [ring[k][0], ring[k][1], ring[k + 1][1], ring[k + 1][0]]
			var mid: Vector3 = ((q[0][1] as Vector3) + (q[2][1] as Vector3)) * 0.5
			var outward := Vector3(mid.x - MIDDLE.x, 0.0, mid.z - MIDDLE.z).normalized()
			for n in _winding(q.map(func(corner: Array) -> Vector3: return corner[1]), outward):
				var corner: Array = q[n]
				var skinning: Array = corner[2]
				var at: Vector3 = corner[1]
				st.set_normal(Vector3(at.x - MIDDLE.x, 0.0, at.z - MIDDLE.z).normalized())  # smooth all round
				st.set_uv((corner[0] as Spot).uv)
				st.set_bones(skinning[0])
				st.set_weights(skinning[1])
				st.add_vertex(corner[1])


## A skirt point's skinning: the hips at the top, more and more the thigh on
## its side lower down (the middle front and back stay between them).
func _skirt_weights(c: Spot, f: float) -> Array:
	var side: int = binds["LeftUpLeg" if c.p.x > 0.0 else "RightUpLeg"]
	var leg := clampf(f * 0.75, 0.0, 0.75) * clampf(absf(c.p.x) / 0.09, 0.0, 1.0)
	return [PackedInt32Array([binds["Hips"], side, 0, 0]), PackedFloat32Array([1.0 - leg, leg, 0.0, 0.0])]


## A boot's cuff: its top edge folded out and down.
func _cuff(st: SurfaceTool, edges: Array, s: Dictionary, offset: Callable) -> void:
	for e: Array in edges:
		var a: Spot = e[0]
		var b: Spot = e[1]
		if absf(a.p.y - s.top) > 0.002 or absf(b.p.y - s.top) > 0.002:
			continue
		var at := []
		for c: Spot in [a, b]:
			var top := c.p + c.n * (float(offset.call(c)) + 0.004)
			at.append(top + Vector3.UP * 0.008)
			at.append(top + c.n * float(s.cuff[0]) - Vector3.UP * float(s.cuff[1]))
		_quad(st, [a, b, b, a], [at[0], at[2], at[3], at[1]], a.n)


# --- The cloth's creases --------------------------------------------------------------

## folds.png: the hero's paint as light and shade against its surroundings
## (0.5 = as bright as round about), so a garment shows the creases, seams and
## wear of the clothes it covers in its own colour. The surroundings leave out
## the unpainted background, so the islands' edges don't glow.
func _folds(texture: Texture2D) -> void:
	var img := texture.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	img.resize(FOLDS_SIZE, FOLDS_SIZE, Image.INTERPOLATE_CUBIC)
	var data := img.get_data()
	var n := FOLDS_SIZE
	var lum := PackedFloat32Array()
	lum.resize(n * n)
	var sum := PackedFloat64Array()  # summed areas of the paint and of where there is paint
	var cover := PackedFloat64Array()
	sum.resize((n + 1) * (n + 1))
	cover.resize((n + 1) * (n + 1))
	for y in n:
		var row_sum := 0.0
		var row_cover := 0.0
		for x in n:
			var i := y * n + x
			var l := (0.299 * data[i * 3] + 0.587 * data[i * 3 + 1] + 0.114 * data[i * 3 + 2]) / 255.0
			lum[i] = l
			if l > 0.05:
				row_sum += l
				row_cover += 1.0
			sum[(y + 1) * (n + 1) + x + 1] = sum[y * (n + 1) + x + 1] + row_sum
			cover[(y + 1) * (n + 1) + x + 1] = cover[y * (n + 1) + x + 1] + row_cover
	var out := PackedByteArray()
	out.resize(n * n)
	var r := FOLDS_BLUR
	for y in n:
		var y0 := maxi(y - r, 0)
		var y1 := mini(y + r + 1, n)
		for x in n:
			var x0 := maxi(x - r, 0)
			var x1 := mini(x + r + 1, n)
			var area := cover[y1 * (n + 1) + x1] - cover[y0 * (n + 1) + x1] - cover[y1 * (n + 1) + x0] + cover[y0 * (n + 1) + x0]
			var shade := 0.5
			var l := lum[y * n + x]
			if area > 0.0 and l > 0.05:
				var around := (sum[y1 * (n + 1) + x1] - sum[y0 * (n + 1) + x1] - sum[y1 * (n + 1) + x0] + sum[y0 * (n + 1) + x0]) / area
				shade = clampf(0.5 + (l / maxf(around, 0.02) - 1.0) * 0.5, 0.0, 1.0)
			out[y * n + x] = int(shade * 255.0)
	var folds := Image.create_from_data(n, n, false, Image.FORMAT_L8, out)
	print("hero_gear: folds.png ", error_string(folds.save_png(OUT + "folds.png")))


# --- Hats: shapes on the head bone ---------------------------------------------------

## Hats in the Warden's Hat's style (see _shaped_hat). A fedora: a medium
## crown with a dent along the top and pinched at the front, a broad band,
## and a snap brim, down at the front and up at the back.
const FEDORA := {"crown": [0.105, 0.117, 0.112, 0.84], "crease": 0.026, "pinch": [0.13, 0.6],
		"brim": [0.165, 0.18], "curl": [0.006, 0.024, 0.02], "band": 0.03}
## A cowboy hat: a tall crown with a deep crease along the top and pinched
## at the front, and a wide brim rolled up at the sides, dipping at the front.
const COWBOY := {"crown": [0.106, 0.12, 0.138, 0.87], "crease": 0.034, "pinch": [0.11, 0.62],
		"brim": [0.205, 0.228], "curl": [0.07, 0.016, 0.004], "band": 0.022}


## A felt hat: an oval crown (`crown`: its radii across and front to back,
## height, and how much it narrows to the top), its top dented by `crease`
## along the middle, front to back, and pinched either side of the front
## (`pinch`: how much, and how far round from the front); a brim out to
## `brim` (its radii), curling (`curl`: the sides up, the front down, the back
## up, by its edge); and a band of height `band` round the crown (the trim).
func _shaped_hat(s: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := _begin()
	var around := 40
	var rows := []
	for i in 9:  # the crown's side, bottom to top
		rows.append(_hat_ring(around, func(a: float) -> Vector3: return _crown_point(s, a, i / 8.0)))
	for i in range(5, -1, -1):  # its top, from the edge in to the middle
		var u := i / 5.0
		rows.append(_hat_ring(around, func(a: float) -> Vector3: return _crown_top(s, a, u)))
	_hat_rows(st, rows)
	rows = []
	for i in 7:  # the brim, from the crown out
		rows.append(_hat_ring(around, func(a: float) -> Vector3: return _brim_point(s, a, i / 6.0)))
	var edge: PackedVector3Array = rows[-1]  # the brim's edge, given a little thickness
	var under := PackedVector3Array()
	for p in edge:
		under.append(p - Vector3.UP * 0.007)
	rows.append(under)
	_hat_rows(st, rows)
	st.index()
	st.generate_normals()
	st.commit(mesh)
	st = _begin()  # trim: the band
	var crown: Array = s.crown
	var top: float = s.band / crown[2]
	rows = []
	for v in [0.0, top]:
		rows.append(_hat_ring(around, func(a: float) -> Vector3:
				var p := _crown_point(s, a, v)
				return HEAD + (p - HEAD) * Vector3(1.03, 1.0, 1.03)))
	_hat_rows(st, rows)
	st.index()
	st.generate_normals()
	st.commit(mesh)
	return mesh


## A point on a hat's crown: `a` the angle round from the front (towards his
## left), `v` the height up it (0..1).
func _crown_point(s: Dictionary, a: float, v: float) -> Vector3:
	var crown: Array = s.crown
	var pinch: Array = s.pinch
	var from_front := wrapf(a, -PI, PI)
	var dent: float = pinch[0] * (exp(-pow((absf(from_front) - pinch[1]) / 0.35, 2.0))) * smoothstep(0.35, 1.0, v)
	var narrow: float = lerpf(1.0, crown[3], v) * (1.0 - dent)
	var dip: float = s.crease * pow(cos(a), 2.0) * smoothstep(0.55, 1.0, v)
	return HEAD + Vector3(sin(a) * crown[0] * narrow, crown[2] * v - dip, cos(a) * crown[1] * narrow)


## A point on the crown's top: `u` from its edge (1) in to the middle (0),
## dipping into the crease along the middle.
func _crown_top(s: Dictionary, a: float, u: float) -> Vector3:
	var crown: Array = s.crown
	var edge := _crown_point(s, a, 1.0) - HEAD
	return HEAD + Vector3(edge.x * u, crown[2] - s.crease * (1.0 - pow(u * sin(a), 2.0)), edge.z * u)


## A point on the brim: `u` from the crown (0) out to its edge (1).
func _brim_point(s: Dictionary, a: float, u: float) -> Vector3:
	var crown: Array = s.crown
	var brim: Array = s.brim
	var curl: Array = s.curl
	var front := maxf(cos(a), 0.0)
	var back := maxf(-cos(a), 0.0)
	var lift: float = u * u * (curl[0] * sin(a) * sin(a) - curl[1] * front * front + curl[2] * back * back)
	return HEAD + Vector3(sin(a) * lerpf(crown[0] * 0.985, brim[0], u), lift, cos(a) * lerpf(crown[1] * 0.985, brim[1], u))


func _hat_ring(count: int, at: Callable) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for k in count:
		ring.append(at.call(TAU * k / count))
	return ring


## Joins rings of points (all the same size, closed) into a surface, riding the head bone.
func _hat_rows(st: SurfaceTool, rows: Array) -> void:
	for r in rows.size() - 1:
		var a: PackedVector3Array = rows[r]
		var b: PackedVector3Array = rows[r + 1]
		for k in a.size():
			var k2 := (k + 1) % a.size()
			for p in [a[k], b[k], b[k2], a[k], b[k2], a[k2]]:
				st.set_bones(PackedInt32Array([head_bind, 0, 0, 0]))
				st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
				st.add_vertex(p)


## A warden's hat: a broad flat brim and a tall crown with a band and a feather.
func _hat_warden() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := _begin()
	_shape(st, _disc(0.22, 0.01), Transform3D(Basis(), HEAD))
	var crown := CylinderMesh.new()
	crown.top_radius = 0.085
	crown.bottom_radius = 0.112
	crown.height = 0.13
	crown.radial_segments = 20
	crown.rings = 1
	_shape(st, crown.get_mesh_arrays(), Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.08)), HEAD + Vector3(0, 0.065, 0)))
	st.index()
	st.commit(mesh)
	st = _begin()  # trim: the band and a feather
	_shape(st, _ring(0.113, 0.03), Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.08)), HEAD + Vector3(0, 0.02, 0)))
	var feather := BoxMesh.new()
	feather.size = Vector3(0.012, 0.13, 0.03)
	_shape(st, feather.get_mesh_arrays(), Transform3D(Basis(Vector3.BACK, -0.45), HEAD + Vector3(0.1, 0.07, -0.02)))
	st.index()
	st.commit(mesh)
	return mesh


func _disc(r: float, h: float) -> Array:
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = h
	disc.radial_segments = 28
	disc.rings = 1
	return disc.get_mesh_arrays()


func _ring(r: float, h: float) -> Array:
	var ring := CylinderMesh.new()
	ring.top_radius = r
	ring.bottom_radius = r
	ring.height = h
	ring.radial_segments = 24
	ring.rings = 1
	ring.cap_top = false
	ring.cap_bottom = false
	return ring.get_mesh_arrays()


## A shape's triangles, placed by `xf`, riding the head bone.
func _shape(st: SurfaceTool, arrays: Array, xf: Transform3D) -> void:
	var pts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tex: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in order:
		st.set_normal((xf.basis.inverse().transposed() * ns[i]).normalized())
		st.set_uv(tex[i])
		st.set_bones(PackedInt32Array([head_bind, 0, 0, 0]))
		st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		st.add_vertex(xf * pts[i])
