class_name PetModels
## Meshy models for pets and wild creatures: res://models/pets/<species>.glb
## (lower-case species name, spaces as underscores). A species with one is drawn
## with it instead of the shapes CreatureModel builds, and animated by its own
## animations (rigged by scripts/tools/meshy_skin/rig_quad.py: Idle, Walk, Swipe
## for its attack, Hiss for its ability; see CreatureAnimator).

const DIR := "res://models/pets/"
## How tall a size-1 creature of each body type stands (the code-built ones).
const HEIGHT := {"cat": 1.25, "dog": 1.25, "bird": 1.1, "skeleton": 1.95, "zombie": 1.95, "mummy": 1.95, "imp": 1.4, "golem": 1.95, "yeti": 1.8, "wraith": 1.9}
## Per species: how high it floats (the Frost Wraith hovers; its animations
## never bob it up and down).
const HOVER := {"Frost Wraith": 0.35}
## ...or how long, nose to tail tip (lizards: long and low, some much flatter than others).
const LENGTH := {"lizard": 1.93, "scorpion": 1.6}
## Species whose model (made elsewhere, skinned) is sized and placed by its
## posed vertices, not its mesh box (the Sand Scorpion: "SCORPION ANIMATION"
## by hino, Sketchfab, CC-BY-4.0; models/pets/CREDITS.txt).
const POSED_FIT := {"Sand Scorpion": true, "Skeleton": true, "Zombie": true, "Mummy": true, "Fire Imp": true, "Magma Golem": true, "Yeti": true}
## Per species: stretches (seconds) cut out of one of its model's animations
## (`source`) as the animations the game plays. The armoured Skeleton's
## Attack is 2.8 s of crouch, wind-up, lunge and recovery: its attack plays
## only the wind-up, the lunge (0.7 s in) and the landing.
const CLIPS := {
	"Skeleton": {"source": "Attack", "Swipe": [0.35, 1.75], "Hiss": [0.35, 1.75]},
	"Magma Golem": {"source": "Attack", "Swipe": [0.35, 1.75], "Hiss": [0.35, 1.75]},  # the same slam
}
## Per species: animations baked by a tool, as Animation resources, under the
## names the game plays. The Yeti's slam (scripts/tools/ground_slam.gd): its
## Charged_Ground_Slam without most of the long hold with its fist raised
## (0.2-0.55 s, then 1.25-2.75 s: the fist lands 0.85 s in), its arm swung
## forward where the fist would have sunk into the ground, so it lands on it.
const BAKED := {"Yeti": {"Swipe": "res://models/pets/yeti_slam.res", "Hiss": "res://models/pets/yeti_slam.res"}}
## Per species, how much faster a one-off animation plays, so it's over
## before the next attack (each species' attack_cooldown).
const ANIM_SPEED := {
	"Skeleton": {"Swipe": 1.6, "Hiss": 1.6},  # 1.4 s -> 0.88 s (cooldown 0.9)
	"Mummy": {"Swipe": 1.25, "Hiss": 1.25},  # 1.67 s -> 1.33 s (cooldown 1.4)
	"Zombie": {"Swipe": 1.6, "Hiss": 1.6},  # 2.16 s -> 1.35 s (cooldown 1.4)
	"Fire Imp": {"Swipe": 1.3},  # 1.07 s -> 0.82 s (cooldown 1.2): the bolt flies as its arms fly open
	"Yeti": {"Swipe": 1.3, "Hiss": 1.3},  # 1.85 s -> 1.42 s (cooldown 1.5)
}


static func anim_speed(species_name: String, anim_name: String) -> float:
	return ANIM_SPEED.get(species_name, {}).get(anim_name, 1.0)
## Per species, its model's animations under the names the game plays: the
## Zombie ("Zombie (Rigged & Animated)" by Aiden Studios, Sketchfab,
## CC-BY-4.0: Walk1, Attack1.001 and Idle), and the user's Meshy models
## animated with Mixamo: the armoured Skeleton (Walking, Attack, Dead and
## Alert, its stance when still) and the Mummy, the Tombwalker (Walking, a
## lunging swipe, Skill_03, and All_Night_Dance, kept as Dance; no Idle and
## no death).
const RENAME := {
	"Zombie": {"Walk1": "Walk", "Attack1_001": "Attack"},
	"Skeleton": {"Walking": "Walk", "Alert": "Idle", "Dead": "Die"},
	"Mummy": {"Walking": "Walk", "Skill_03": "Attack", "All_Night_Dance": "Dance"},
	# The Ember Imp (the user's, Meshy and Mixamo): it scurries (Running: its walk
	# would play 6x to keep up), stands Alert, casts with Skill_01 (leans back and
	# flings its arms wide: its fire bolt), spins and lunges with Skill_03 (its
	# ability) and, killed, plays Dead.
	"Fire Imp": {"Running": "Walk", "Alert": "Idle", "Dead": "Die", "Skill_01": "Swipe", "Skill_03": "Hiss"},
	# The fire golem (the user's, Meshy and Mixamo): it walks when it wanders and
	# runs when it chases (Running, see RUN_PACE_BY_SPECIES), slams with its
	# Attack (CLIPS) and, killed, plays Dead. No idle: it stands in its walk's first pose.
	"Magma Golem": {"Walking": "Walk", "Running": "Run", "Dead": "Die"},
	# The Yeti (the user's, Meshy and Mixamo): walks, runs when it chases, slams
	# (CLIPS). No idle (its walk's first pose) and no death.
	"Yeti": {"Walking": "Walk", "Running": "Run"},
}
## Per species, degrees a model is turned (about up) so it faces its way of
## travel, where it isn't made facing +Z like the Meshy models (measured: the
## Sand Scorpion's pincers point 62 degrees off; it walked half sideways).
const YAW := {"Sand Scorpion": -62.3}
## Per species: a colour multiplied into the model's texture (pale Meshy textures
## wash out in the bright sun).
const TINT := {"voltwing": Color(0.62, 0.74, 0.95), "frostfinch": Color(0.78, 0.85, 0.95),
		"fire_imp": Color(1.0, 0.42, 0.32)}  # red, to stand out on the volcano's dark rock
## Per species: its model glows ([colour, strength]): its own texture lit in that
## colour (brightest where the texture is, as the imp's lava cracks), bright
## enough that the bloom puts a halo round it.
const SELF_GLOW := {"fire_imp": [Color(1.0, 0.45, 0.1), 0.9], "magma_golem": [Color(1.0, 0.45, 0.1), 0.6]}
## Per species: a small light it carries ([colour, energy, range]), a pool of
## its glow on the ground round it.
const AURA := {"fire_imp": [Color(1.0, 0.45, 0.12), 1.2, 2.6], "magma_golem": [Color(1.0, 0.45, 0.12), 2.6, 4.5]}
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
		"Skeleton": 1.22, "Zombie": 0.25, "Mummy": 0.72, "Fire Imp": 1.98, "Magma Golem": 0.6, "Yeti": 1.15, "Frost Wraith": 0.01}  # (its feet slide back 4.66 model units a second on the ground)
const MAX_WALK_SPEED_BY_SPECIES := {"Skeleton": 4.0, "Zombie": 4.0, "Mummy": 4.0, "Fire Imp": 4.0, "Magma Golem": 2.0, "Yeti": 2.0, "Frost Wraith": 1.0}  # (no feet: its hover plays at its own pace)
## Per species whose model has a Run: its pace (as WALK_PACE_BY_SPECIES). It
## runs once the walk would play faster than RUN_FROM (and walks again below
## WALK_BELOW, so it doesn't flicker between the two).
const RUN_PACE_BY_SPECIES := {"Magma Golem": 1.87, "Yeti": 1.9}
const RUN_FROM := 1.7
const WALK_BELOW := 1.3


static func max_walk_speed(body_type: String, species_name := "") -> float:
	return MAX_WALK_SPEED_BY_SPECIES.get(species_name, MAX_WALK_SPEED_BY_TYPE.get(body_type, 3.0))


static func walk_pace(body_type: String, species_name := "") -> float:
	return WALK_PACE_BY_SPECIES.get(species_name, WALK_PACE_BY_TYPE.get(body_type, WALK_PACE))


static func path_for(species: CreatureSpecies) -> String:
	var base := DIR + species.display_name.to_lower().replace(" ", "_")
	if not ResourceLoader.exists(base + ".glb") and ResourceLoader.exists(base + ".scn"):
		return base + ".scn"  # rigged and animated here (the Frost Wraith: scripts/tools/rig_wraith.gd)
	return base + ".glb"


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
	if clip_player and BAKED.has(species.display_name):
		for baked_name: String in BAKED[species.display_name]:
			if not clip_player.has_animation(baked_name):
				clip_player.get_animation_library("").add_animation(baked_name, (load(BAKED[species.display_name][baked_name]) as Animation).duplicate())
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
	scene.position.y += HOVER.get(species.display_name, 0.0)
	scene.set_meta("scale", k)
	var key := species.display_name.to_lower().replace(" ", "_")
	if TINT.has(key) or SELF_GLOW.has(key):
		for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			for i in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(i).duplicate() as StandardMaterial3D
				if TINT.has(key):
					mat.albedo_color = TINT[key]
				if SELF_GLOW.has(key):
					mat.emission_enabled = true
					mat.emission = SELF_GLOW[key][0]
					mat.emission_energy_multiplier = SELF_GLOW[key][1]
					mat.emission_texture = mat.albedo_texture
					mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				mesh.set_surface_override_material(i, mat)
	if AURA.has(key):
		var aura := OmniLight3D.new()
		aura.name = "Aura"
		aura.light_color = AURA[key][0]
		aura.light_energy = AURA[key][1]
		aura.omni_range = AURA[key][2]
		aura.shadow_enabled = false
		aura.position = Vector3(0.0, 0.9 - body.position.y, 0.0)
		body.add_child(aura)
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
		# One stretch [from, to], or several [[from, to], ...] joined end to end
		# (to leave out a long held pose in the middle).
		var pieces: Array = clips[clip_name] if clips[clip_name][0] is Array else [clips[clip_name]]
		var anim := Animation.new()
		var length := 0.0
		for piece: Array in pieces:
			length += float(piece[1]) - float(piece[0])
		anim.length = length
		for t in src.get_track_count():
			var kind := src.track_get_type(t)
			if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				continue
			var nt := anim.add_track(kind)
			anim.track_set_path(nt, src.track_get_path(t))
			var offset := 0.0
			for piece: Array in pieces:
				var from: float = piece[0]
				var to: float = piece[1]
				var steps := maxi(ceili((to - from) * 30.0), 1)
				for i in steps + 1:
					var at := minf(from + (to - from) * i / steps, to)
					var key := offset + at - from
					if i == 0 and offset > 0.0:
						key += 0.001  # (just after the last piece's final key)
					match kind:
						Animation.TYPE_POSITION_3D:
							anim.position_track_insert_key(nt, key, src.position_track_interpolate(t, at))
						Animation.TYPE_ROTATION_3D:
							anim.rotation_track_insert_key(nt, key, src.rotation_track_interpolate(t, at))
						Animation.TYPE_SCALE_3D:
							anim.scale_track_insert_key(nt, key, src.scale_track_interpolate(t, at))
				offset += to - from
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
