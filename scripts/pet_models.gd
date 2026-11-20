class_name PetModels
## Meshy models for pets and wild creatures: res://models/pets/<species>.glb
## (lower-case species name, spaces as underscores). A species with one is drawn
## with it instead of the shapes CreatureModel builds, and animated by its own
## animations (rigged by scripts/tools/meshy_skin/rig_quad.py: Idle, Walk, Swipe
## for its attack, Hiss for its ability; see CreatureAnimator).

const DIR := "res://models/pets/"
## How tall a size-1 creature of each body type stands (the code-built ones).
const HEIGHT := {"cat": 1.25, "dog": 1.25}
## Per species: a colour multiplied into the model's texture (pale Meshy textures
## wash out in the bright sun).
const TINT := {"bloomling": Color(0.92, 0.6, 0.68)}
## Per species: a glowing colour for the inside of the model, seen through any
## gaps in it (Cinderhorn: molten red, as if it burns inside).
const INNER_GLOW := {"cinderhorn": Color(0.85, 0.06, 0.02)}
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
	if INNER_GLOW.has(key):  # the outside as usual, its inner faces drawn glowing
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.cull_mode = BaseMaterial3D.CULL_FRONT
		glow.albedo_color = INNER_GLOW[key]
		for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			for i in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(i).duplicate() as StandardMaterial3D
				mat.cull_mode = BaseMaterial3D.CULL_BACK
				mat.next_pass = glow
				mesh.set_surface_override_material(i, mat)
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false).pop_front()
	if player:
		for anim_name in ["Walk", "Idle", "Run"]:
			if player.has_animation(anim_name):
				player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	return player
