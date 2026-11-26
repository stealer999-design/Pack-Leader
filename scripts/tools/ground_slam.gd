extends SceneTree
## Bakes a model's slam so the striking fist stops at the ground instead of
## sinking into it (the Yeti's Charged_Ground_Slam drove its fist nearly half
## its height under the floor). Cuts the clip from the source animation
## (pieces joined end to end, as PetModels.CLIPS), then, frame by frame,
## swings the arm forward at the shoulder just far enough that the fist's
## lowest vertex stays at the feet's level: the fist lands on the ground in
## front of it. Saves the clip as an Animation resource (PetModels.BAKED).
##   godot --headless --path . -s res://scripts/tools/ground_slam.gd
## (settings below: the Yeti's.)

const MODEL := "res://models/pets/yeti.glb"
const SOURCE := "Charged_Ground_Slam"
## The raise (0.2-0.55 s), then the end of the long hold, the slam (the fist
## lands 1.75 s in) and the rise back up (to 2.75 s).
const PIECES := [[0.2, 0.55], [1.25, 2.75]]
const ARM := "mixamorig_RightArm"
const FIST := ["mixamorig_RightHand", "mixamorig_RightForeArm"]
const FEET := ["mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase", "mixamorig_RightToeBase"]
const OUT := "res://models/pets/yeti_slam.res"
const CLEARANCE := 0.02  ## (model units) the fist stops this far above the feet's lowest point

var sk: Skeleton3D
var mi: MeshInstance3D
var scene: Node3D
var verts: PackedVector3Array
var bones: PackedInt32Array
var wts: PackedFloat32Array
var per := 4
var bind_bone: Array[int] = []


func _init() -> void:
	scene = (load(MODEL) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	await process_frame
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	player.active = false
	PetModels._cut_clips(player, {"source": SOURCE, "Slam": PIECES})
	var anim := player.get_animation("Slam")
	sk = scene.find_children("*", "Skeleton3D", true, false)[0]
	mi = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var arrays := mi.mesh.surface_get_arrays(0)
	verts = arrays[Mesh.ARRAY_VERTEX]
	bones = arrays[Mesh.ARRAY_BONES]
	wts = arrays[Mesh.ARRAY_WEIGHTS]
	per = bones.size() / verts.size()
	for i in mi.skin.get_bind_count():
		var bb := mi.skin.get_bind_bone(i)
		bind_bone.append(bb if bb >= 0 else sk.find_bone(mi.skin.get_bind_name(i)))
	var fist_v := _verts_of(FIST.map(func(n): return sk.find_bone(n)), 2)
	var foot_v := _verts_of(FEET.map(func(n): return sk.find_bone(n)), 3)
	var arm := sk.find_bone(ARM)
	var parent := sk.get_bone_parent(arm)
	var root_node := player.get_node(player.root_node)
	# The arm's rotation track, and the forward swing's axis (scene space: the
	# model faces +Z, so turning down (-Y) towards +Z is about -X), in the skeleton's space.
	var track := -1
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D and String(anim.track_get_path(t)).ends_with(":" + ARM):
			track = t
	var to_scene := scene.global_transform.affine_inverse() * sk.global_transform
	var axis := (to_scene.basis.inverse() * Vector3(-1, 0, 0)).normalized()
	var fixed := 0
	var most := 0.0
	for k in anim.track_get_key_count(track):
		var time := anim.track_get_key_time(track, k)
		_pose(anim, root_node, time)
		var ground := _low(foot_v) + CLEARANCE
		if _low(fist_v) >= ground:
			continue
		var rest_local: Quaternion = sk.get_bone_pose_rotation(arm)
		var parent_global := sk.get_bone_global_pose(parent).basis.orthonormalized()
		var arm_global := parent_global * Basis(rest_local)
		var lo := 0.0
		var hi := deg_to_rad(120.0)
		for i in 14:  # the least swing that lifts the fist to the ground
			var mid := (lo + hi) * 0.5
			sk.set_bone_pose_rotation(arm, (parent_global.inverse() * Basis(axis, mid) * arm_global).get_rotation_quaternion())
			sk.force_update_all_bone_transforms()
			if _low(fist_v) < ground:
				lo = mid
			else:
				hi = mid
		var q := (parent_global.inverse() * Basis(axis, hi) * arm_global).get_rotation_quaternion()
		anim.track_set_key_value(track, k, q)
		fixed += 1
		most = maxf(most, rad_to_deg(hi))
	print("ground_slam: %d of %d frames lifted, the most by %.0f degrees" % [fixed, anim.track_get_key_count(track), most])
	# Check: the fist's lowest point over the whole clip.
	var worst := INF
	for k in anim.track_get_key_count(track):
		_pose(anim, root_node, anim.track_get_key_time(track, k))
		worst = minf(worst, _low(fist_v) - _low(foot_v))
	print("ground_slam: lowest the fist goes, against the feet: %.3f; saved %s" % [worst, error_string(ResourceSaver.save(anim, OUT))])
	quit()


## Vertices weighted mostly to `wanted` bones (every `step`th).
func _verts_of(wanted: Array, step: int) -> Array[int]:
	var out: Array[int] = []
	for v in range(0, verts.size(), step):
		var best := -1
		var bw := 0.0
		for j in per:
			if wts[v * per + j] > bw:
				bw = wts[v * per + j]
				best = bind_bone[bones[v * per + j]]
		if best in wanted:
			out.append(v)
	return out


## The lowest of `list`'s skinned vertices, in the scene's space.
func _low(list: Array[int]) -> float:
	var to_scene := scene.global_transform.affine_inverse() * mi.global_transform
	var low := INF
	for v in list:
		var p := Vector3.ZERO
		for j in per:
			var w: float = wts[v * per + j]
			if w > 0.0:
				var bi: int = bones[v * per + j]
				p += (sk.get_bone_global_pose(bind_bone[bi]) * mi.skin.get_bind_pose(bi) * verts[v]) * w
		low = minf(low, (to_scene * p).y)
	return low


func _pose(anim: Animation, root_node: Node, time: float) -> void:
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		var s := root_node.get_node_or_null(NodePath(path.get_concatenated_names())) as Skeleton3D
		if s == null:
			continue
		var b := s.find_bone(path.get_concatenated_subnames())
		match anim.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				s.set_bone_pose_position(b, anim.position_track_interpolate(t, time))
			Animation.TYPE_ROTATION_3D:
				s.set_bone_pose_rotation(b, anim.rotation_track_interpolate(t, time))
			Animation.TYPE_SCALE_3D:
				s.set_bone_pose_scale(b, anim.scale_track_interpolate(t, time))
	sk.force_update_all_bone_transforms()
