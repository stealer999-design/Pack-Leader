class_name ModelLook
## The game's look for everything built from simple shapes (the tamer, pets,
## monsters, bosses, buildings, walls, obstacles): natural, realistic shading
## instead of a cartoon one.
##
##   ModelLook.apply(model_root)
##
## Every plain-coloured part gets physically based shading (soft Burley
## diffuse, GGX highlights), colours a little less saturated, like real fur,
## hide and paint, and fine surface detail: a mottled grain in its colour and
## a bump map, so a body reads as fur or skin and a wall as stone instead of a
## flat plastic shape. Painted textures (ground, buildings) get bump maps from
## their own paint (see GroundTextures.with_bumps). Glowing and see-through
## parts, and parts flagged "smooth" (eyes), are left as they are.

static var _grain: Texture2D
static var _bumps: Texture2D


## Gives every mesh under `root` the realistic look.
static func apply(root: Node, _unused := 0.0) -> void:
	for node in _meshes(root):
		var part := node as MeshInstance3D
		part.material_overlay = null  # no cartoon outlines
		var mat := part.material_override as StandardMaterial3D
		if mat == null and part.mesh:
			mat = part.mesh.surface_get_material(0) as StandardMaterial3D if part.mesh.get_surface_count() > 0 else null
		if mat:
			realistic(mat)


## One material, once (materials are shared between parts).
static func realistic(mat: StandardMaterial3D) -> void:
	if mat.has_meta("real"):
		return
	mat.set_meta("real", true)
	if mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
			or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.albedo_texture != null:
		return  # glowing, see-through or already painted
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.rim_enabled = false
	if mat.has_meta("smooth"):
		return  # eyes: glossy, no grain
	var c := mat.albedo_color
	mat.albedo_color = Color.from_hsv(c.h, c.s * 0.78, c.v * 0.93, c.a)
	if mat.metallic < 0.2:
		mat.roughness = maxf(mat.roughness, 0.72)
	mat.albedo_texture = grain()
	mat.normal_enabled = true
	mat.normal_texture = bumps()
	mat.normal_scale = 0.7
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 2.2
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


## A soft, mottled grain (light grey to white) that the colour is multiplied by.
static func grain() -> Texture2D:
	if _grain == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.045
		noise.fractal_octaves = 4
		var texture := NoiseTexture2D.new()
		texture.width = 256
		texture.height = 256
		texture.seamless = true
		texture.generate_mipmaps = true
		texture.noise = noise
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.74, 0.74, 0.74))
		ramp.set_color(1, Color(1.0, 1.0, 1.0))
		texture.color_ramp = ramp
		_grain = texture
	return _grain


## Fine bumps (fur, skin, grain, stone): a normal map made from noise.
static func bumps() -> Texture2D:
	if _bumps == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = 0.11
		noise.fractal_octaves = 3
		var texture := NoiseTexture2D.new()
		texture.width = 256
		texture.height = 256
		texture.seamless = true
		texture.as_normal_map = true
		texture.bump_strength = 6.0
		texture.generate_mipmaps = true
		texture.noise = noise
		_bumps = texture
	return _bumps


static func _meshes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if root is MeshInstance3D:
		out.append(root)
	for child in root.get_children():
		out.append_array(_meshes(child))
	return out
