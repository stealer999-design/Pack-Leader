class_name PetModels
## Meshy models for pets and wild creatures: res://models/pets/<species>.glb
## (lower-case species name, spaces as underscores). A species with one is drawn
## with it instead of the shapes CreatureModel builds, and animated by its own
## animations (rigged by scripts/tools/meshy_skin/rig_quad.py: Idle, Walk, Swipe
## for its attack, Hiss for its ability; see CreatureAnimator).

const DIR := "res://models/pets/"
## How tall a size-1 creature of each body type stands (the code-built ones).
const HEIGHT := {"cat": 1.25, "dog": 1.25, "lizard": 0.75}
## Per species: a colour multiplied into the model's texture (pale Meshy textures
## wash out in the bright sun).
const TINT := {"voltwing": Color(0.62, 0.74, 0.95)}
## Per species with models/pets/<species>_emit.png: those parts of its texture
## glow (an additive layer). Per species with models/pets/<species>_core.json (from core_shapes.py): a
## core of flickering fire inside the model, capsules riding its bones, seen
## through any gaps in its fur (no cat uses it now; it was made for the retired Cinderhorn).
static var _fire_mat: ShaderMaterial
## How far (Meshy units, x the model's scale) the walk cycle carries the body in a second.
const WALK_PACE := 2.92


static func path_for(species: CreatureSpecies) -> String:
	return DIR + species.display_name.to_lower().replace(" ", "_") + ".glb"


static func has_model(species: CreatureSpecies) -> bool:
	return ResourceLoader.exists(path_for(species))


## Builds the model under `body` (cleared first): scaled to the body type's
## height, feet on the ground, facing -Z. Returns its AnimationPlayer (or null).
static func build(body: MeshInstance3D, species: CreatureSpecies) -> AnimationPlayer:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	body.mesh = null
	var scene: Node3D = (load(path_for(species)) as PackedScene).instantiate()
	scene.name = "Meshy"
	body.add_child(scene)
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var b := mesh.transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var k: float = HEIGHT.get(species.body_type, 1.25) / maxf(box.size.y, 0.01)
	scene.scale = Vector3.ONE * k
	scene.position = Vector3(-box.get_center().x * k, -box.position.y * k, -box.get_center().z * k)
	scene.rotation.y = PI  # Meshy models face +Z
	scene.position = scene.position.rotated(Vector3.UP, PI)
	scene.position.y -= body.position.y  # Body sits raised (for the code-built shapes); feet back on the ground
	scene.set_meta("scale", k)
	var key := species.display_name.to_lower().replace(" ", "_")
	if TINT.has(key):
		for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			for i in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(i).duplicate() as StandardMaterial3D
				mat.albedo_color = TINT[key]
				mesh.set_surface_override_material(i, mat)
	var glow_path := DIR + key + "_emit.png"
	if ResourceLoader.exists(glow_path):  # glowing parts (Magmashell's lava cracks): an additive layer
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.albedo_texture = load(glow_path)
		glow.albedo_color = Color(2.2, 1.6, 1.2)
		for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			mesh.material_overlay = glow
	var core_path := DIR + key + "_core.json"
	if FileAccess.file_exists(core_path):
		_add_fire_core(scene, core_path)
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false).pop_front()
	if player:
		for anim_name in ["Walk", "Idle", "Run"]:
			if player.has_animation(anim_name):
				player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	return player


## Capsules (and a sphere for the head) of flickering fire, each attached to its
## bone so it moves with the body.
static func _add_fire_core(scene: Node3D, path: String) -> void:
	var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false).pop_front()
	if skeleton == null:
		return
	if _fire_mat == null:
		_fire_mat = ShaderMaterial.new()
		_fire_mat.shader = load("res://scripts/pet_fire.gdshader")
		var noise := NoiseTexture2D.new()
		noise.seamless = true
		noise.noise = FastNoiseLite.new()
		(noise.noise as FastNoiseLite).frequency = 0.03
		_fire_mat.set_shader_parameter("noise", noise)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for shape: Dictionary in data.shapes:
		var bone := skeleton.find_bone(shape.bone)
		if bone < 0:
			continue
		var attach := BoneAttachment3D.new()
		attach.bone_idx = bone
		skeleton.add_child(attach)
		var a := Vector3(shape.a[0], shape.a[1], shape.a[2])
		var b := Vector3(shape.b[0], shape.b[1], shape.b[2])
		var r: float = shape.r
		var part := MeshInstance3D.new()
		var mid := (a + b) * 0.5
		var length := a.distance_to(b)
		if length < 0.001:
			var sphere := SphereMesh.new()
			sphere.radius = r
			sphere.height = r * 2.0
			part.mesh = sphere
			part.transform = Transform3D(Basis(), mid)
		else:
			var capsule := CapsuleMesh.new()
			capsule.radius = r
			capsule.height = length + r * 2.0
			part.mesh = capsule
			var up := (b - a) / length
			var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
			part.transform = Transform3D(Basis(side, up, side.cross(up)), mid)
		part.material_override = _fire_mat
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# from model space into the bone's own space
		part.transform = skeleton.get_bone_global_rest(bone).affine_inverse() * part.transform
		attach.add_child(part)
