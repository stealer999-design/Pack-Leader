class_name PetModels
## Meshy models for pets and wild creatures: res://models/pets/<species>.glb
## (lower-case species name, spaces as underscores). A species with one is drawn
## with it instead of the shapes CreatureModel builds, and animated by its own
## animations (rigged by scripts/tools/meshy_skin/rig_quad.py: Idle, Walk, Swipe
## for its attack, Hiss for its ability; see CreatureAnimator).

const DIR := "res://models/pets/"
## How tall a size-1 creature of each body type stands (the code-built ones).
const HEIGHT := {"cat": 1.25, "dog": 1.25, "bird": 1.1, "skeleton": 1.95, "zombie": 1.95}
## ...or how long, nose to tail tip (lizards: long and low, some much flatter than others).
const LENGTH := {"lizard": 1.93, "scorpion": 1.6}
## Species whose model (made elsewhere, skinned) is sized and placed by its
## posed vertices, not its mesh box (the Sand Scorpion: "SCORPION ANIMATION"
## by hino, Sketchfab, CC-BY-4.0; models/pets/CREDITS.txt).
const POSED_FIT := {"Sand Scorpion": true, "Skeleton": true, "Zombie": true}
## Per species whose model has all its moves in one long animation: the
## stretches (seconds) cut out of it as the animations the game plays. The
## Skeleton ("Skeleton (Animated)" by One_Boy, Sketchfab, CC-BY-4.0): its
## walk (two strides, a seamless loop), one sword strike from its guard back
## to its guard (it lands 0.34 s in), and falling to pieces on the ground.
const CLIPS := {
	"Skeleton": {"source": "Take 001", "Walk": [0.0, 2.4667], "Attack": [27.333, 28.467], "Die": [40.8, 42.8]},
}
## Per species, its model's animations under the names the game plays (the
## Zombie, "Zombie (Rigged & Animated)" by Aiden Studios, Sketchfab, CC-BY-4.0:
## Walk1, Attack1.001 and Idle).
const RENAME := {"Zombie": {"Walk1": "Walk", "Attack1_001": "Attack"}}
## Per species, degrees a model is turned (about up) so it faces its way of
## travel, where it isn't made facing +Z like the Meshy models (measured: the
## Sand Scorpion's pincers point 62 degrees off; it walked half sideways).
const YAW := {"Sand Scorpion": -62.3}
## Per species: a colour multiplied into the model's texture (pale Meshy textures
## wash out in the bright sun).
const TINT := {"voltwing": Color(0.62, 0.74, 0.95), "frostfinch": Color(0.78, 0.85, 0.95)}
## Per species with models/pets/<species>_emit.png: those parts of its texture
## glow (an additive layer). Per species with models/pets/<species>_core.json (from core_shapes.py): a
## core of flickering fire inside the model, capsules riding its bones, seen
## through any gaps in its fur (no cat uses it now; it was made for the retired Cinderhorn).
static var _fire_mat: ShaderMaterial
## How far (Meshy units, x the model's scale) the walk cycle carries the body in a second.
const WALK_PACE := 2.92
## ...per body type, where it differs (lizards scurry: short sprawled legs, quick steps).
const WALK_PACE_BY_TYPE := {"lizard": 1.4, "dog": 1.68, "bird": 0.7}


## How much faster than normal the walk may play, per body type, where it differs
## (dogs trot fast to keep up with their tamer; birds hop quickly on short legs).
const MAX_WALK_SPEED_BY_TYPE := {"dog": 4.0, "bird": 5.0, "cat": 6.0}


## ...and per species, where its model has its own walk: the cats' (meshy_skin/cat/cat_pet_anims.py,
## the reference walk) covers the reference's stride in leg heights, x1.25, per 0.83 s, so each
## cat's pace is its own (rig units a second, like every pace here: stride / cycle).
const WALK_PACE_BY_SPECIES := {"Emberkitty": 0.839, "Mossback": 0.995, "Voltwing": 0.782, "Gloomhorn": 0.862, "Magmashell": 0.881, "Thundershell": 0.708, "Stonehorn": 0.831, "Blitzkitty": 0.794, "Stormhorn": 0.419, "Duskbloom": 0.574,
		"Skeleton": 4.66, "Zombie": 0.25}  # (its feet slide back 4.66 model units a second on the ground)
const MAX_WALK_SPEED_BY_SPECIES := {"Skeleton": 4.0, "Zombie": 4.0}


static func max_walk_speed(body_type: String, species_name := "") -> float:
	return MAX_WALK_SPEED_BY_SPECIES.get(species_name, MAX_WALK_SPEED_BY_TYPE.get(body_type, 3.0))


static func walk_pace(body_type: String, species_name := "") -> float:
	return WALK_PACE_BY_SPECIES.get(species_name, WALK_PACE_BY_TYPE.get(body_type, WALK_PACE))


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
	# A skinned model made elsewhere (POSED_FIT): its mesh box isn't where it
	# stands. Measured in its walk's first pose (its bones' rests can be far
	# from how it moves: the Sand Scorpion's walk carries it far off its rest).
	var clip_player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false).pop_front()
	if clip_player and CLIPS.has(species.display_name):
		_cut_clips(clip_player, CLIPS[species.display_name])
	if clip_player and RENAME.has(species.display_name):
		var lib := clip_player.get_animation_library("")
		for old: String in RENAME[species.display_name]:
			if clip_player.has_animation(old) and not clip_player.has_animation(RENAME[species.display_name][old]):
				lib.add_animation(RENAME[species.display_name][old], clip_player.get_animation(old).duplicate())
	if POSED_FIT.has(species.display_name):
		var first_player: AnimationPlayer = clip_player
		if first_player and first_player.has_animation("Walk"):
			_pose_first_frame(first_player, "Walk")
		var posed := _skinned_box(scene)
		if posed.size != Vector3.ZERO:
			box = posed
	var k: float = HEIGHT.get(species.body_type, 1.25) / maxf(box.size.y, 0.01)
	if LENGTH.has(species.body_type):
		k = LENGTH[species.body_type] / maxf(box.size.z, 0.01)
	scene.scale = Vector3.ONE * k
	scene.position = Vector3(-box.get_center().x * k, -box.position.y * k, -box.get_center().z * k)
	var turn: float = PI + deg_to_rad(YAW.get(species.display_name, 0.0))  # Meshy models face +Z
	scene.rotation.y = turn
	scene.position = scene.position.rotated(Vector3.UP, turn)
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
		_alias_animations(player)
		for anim_name in ["Walk", "Idle", "Run"]:
			if player.has_animation(anim_name):
				player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	return player


## Cuts a model's one long animation into the clips the game plays (see CLIPS),
## each resampled at 30 frames a second from its stretch of the source.
static func _cut_clips(player: AnimationPlayer, clips: Dictionary) -> void:
	var lib := player.get_animation_library("")
	if lib == null or not player.has_animation(clips.source):
		return
	var src := player.get_animation(clips.source)
	for clip_name: String in clips:
		if clip_name == "source" or player.has_animation(clip_name):
			continue
		var from: float = clips[clip_name][0]
		var to: float = clips[clip_name][1]
		var anim := Animation.new()
		anim.length = to - from
		var steps := maxi(ceili((to - from) * 30.0), 1)
		for t in src.get_track_count():
			var kind := src.track_get_type(t)
			if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				continue
			var nt := anim.add_track(kind)
			anim.track_set_path(nt, src.track_get_path(t))
			for i in steps + 1:
				var at := minf(from + (to - from) * i / steps, to)
				var key := at - from
				match kind:
					Animation.TYPE_POSITION_3D:
						anim.position_track_insert_key(nt, key, src.position_track_interpolate(t, at))
					Animation.TYPE_ROTATION_3D:
						anim.rotation_track_insert_key(nt, key, src.rotation_track_interpolate(t, at))
					Animation.TYPE_SCALE_3D:
						anim.scale_track_insert_key(nt, key, src.scale_track_interpolate(t, at))
		lib.add_animation(clip_name, anim)


## Puts a model's skeletons in `anim_name`'s first frame (by hand: the model
## needn't be in the tree yet).
static func _pose_first_frame(player: AnimationPlayer, anim_name: String) -> void:
	var anim := player.get_animation(anim_name)
	var root := player.get_node_or_null(player.root_node)
	if root == null:
		return
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		var skeleton := root.get_node_or_null(NodePath(path.get_concatenated_names())) as Skeleton3D
		if skeleton == null:
			continue
		var bone := skeleton.find_bone(path.get_concatenated_subnames())
		if bone < 0:
			continue
		match anim.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone, anim.position_track_interpolate(t, 0.0))
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, anim.rotation_track_interpolate(t, 0.0))
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(bone, anim.scale_track_interpolate(t, 0.0))
	for skeleton: Skeleton3D in root.find_children("*", "Skeleton3D", true, false):
		skeleton.force_update_all_bone_transforms()  # (else the global poses keep the rest)


## The box round a skinned model as it stands posed (in `scene`'s space), from
## its vertices through their bones; an empty box for a model with no skin.
static func _skinned_box(scene: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null:
			continue
		var skeleton := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if skeleton == null:
			continue
		var to_scene := Transform3D()
		var up: Node = skeleton
		while up != null and up != scene:
			if up is Node3D:
				to_scene = (up as Node3D).transform * to_scene
			up = up.get_parent()
		var binds: Array[Transform3D] = []
		for i in mi.skin.get_bind_count():
			var bone := mi.skin.get_bind_bone(i)
			if bone < 0:
				bone = skeleton.find_bone(mi.skin.get_bind_name(i))
			binds.append(to_scene * skeleton.get_bone_global_pose(maxi(bone, 0)) * mi.skin.get_bind_pose(i))
		for sfc in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(sfc)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null:
				continue
			var per := (bones as Array).size() / maxi(verts.size(), 1)
			for v in verts.size():
				var p := Vector3.ZERO
				for j in per:
					var w: float = weights[v * per + j]
					if w > 0.0:
						p += (binds[bones[v * per + j]] * verts[v]) * w
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
	return box


## A model made elsewhere (not rigged by rig_quad.py, e.g. the Sand Scorpion
## and the Skeleton, with Walk, Attack and Die): its attack also serves as Swipe (the attack)
## and Hiss (the ability), and with no Idle it stands in its walk's first pose.
static func _alias_animations(player: AnimationPlayer) -> void:
	var lib := player.get_animation_library("")
	if lib == null:
		return
	if not player.has_animation("Swipe") and player.has_animation("Attack"):
		lib.add_animation("Swipe", player.get_animation("Attack").duplicate())  # (a copy: one animation can't go by two names)
	if not player.has_animation("Hiss") and player.has_animation("Attack"):
		lib.add_animation("Hiss", player.get_animation("Attack").duplicate())
	if not player.has_animation("Idle") and player.has_animation("Walk"):
		var pose := player.get_animation("Walk").duplicate() as Animation
		pose.length = 0.001  # only its first keys: the walk's opening pose, held
		lib.add_animation("Idle", pose)


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
