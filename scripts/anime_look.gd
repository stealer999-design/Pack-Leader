class_name AnimeLook
## The anime look for characters (the tamer, pets, monsters and bosses): cel
## shading (hard light and shadow bands with a crisp highlight and a rim of
## light) and black ink outlines around every part.
##
##   AnimeLook.apply(model_root, outline_width)
##
## Outlines are drawn as an "inverted hull": each part is drawn again behind
## itself, pushed out along its normals and turned inside out, in ink. The
## width is in the model's own units, so it scales with the model. Parts too
## small to outline cleanly (eyes, glints, teeth) get cel shading only.

const INK := Color(0.05, 0.04, 0.07)

static var _outlines := {}  ## width -> outline material


## Gives every mesh under `root` cel shading and (if big enough) an outline.
static func apply(root: Node, outline_width := 0.02) -> void:
	for node in _meshes(root):
		var part := node as MeshInstance3D
		var mat := part.material_override as StandardMaterial3D
		if mat == null or mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
				or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue  # glowing or see-through bits (eyes that glow, effects) stay as they are
		toon(mat)
		if part.mesh and _smallest_side(part) > outline_width * 3.0:
			part.material_overlay = outline(outline_width)


## Cel shading on a material (once; materials are shared between parts).
static func toon(mat: StandardMaterial3D) -> void:
	if mat.has_meta("anime"):
		return
	mat.set_meta("anime", true)
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = minf(mat.roughness, 0.55)
	mat.rim_enabled = true
	mat.rim = 0.35
	mat.rim_tint = 0.6


## The ink outline drawn around a part, `width` units thick.
static func outline(width: float) -> StandardMaterial3D:
	var key := snappedf(width, 0.001)
	if not _outlines.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = INK
		mat.cull_mode = BaseMaterial3D.CULL_FRONT
		mat.grow = true
		mat.grow_amount = key
		_outlines[key] = mat
	return _outlines[key]


static func _meshes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if root is MeshInstance3D:
		out.append(root)
	for child in root.get_children():
		out.append_array(_meshes(child))
	return out


## The part's smallest dimension, in its parent's units (scale included).
static func _smallest_side(part: MeshInstance3D) -> float:
	var size := part.mesh.get_aabb().size * part.scale.abs()
	return minf(size.x, minf(size.y, size.z)) if size.z > 0.0001 else minf(size.x, size.y)
