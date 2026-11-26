extends SceneTree
## Bakes the tamer's animations (models/tamer/hero_anims.res, the AnimationLibrary
## HeroModel plays) from the hero's Mixamo clips in models/tamer/hero.glb:
##   Idle   the standing pose Stand_Up2 ends in, breathing (a loop)
##   Walk   Walking, and Run, Running (loops; their paces are measured and printed)
##   Swing  Right_Hand_Sword_Slash's wind-up, strike and follow-through (the bat swing)
##   Throw  Toss_Treat's overhand toss with the left hand (a capture treat)
##   Fall   falling_down (it holds its last frame: lying there while downed)
##   GetUp  Stand_Up2's rise from all fours (back on his feet after being downed)
## In every one the right hand keeps the slash's grip (its fingers' poses), so
## it holds the bat. Also prints where the grip is in the hand, for HeroModel.GRIP.
##   godot --headless --path . -s res://scripts/tools/hero_anims.gd

const MODEL := "res://models/tamer/hero.glb"
const OUT := "res://models/tamer/hero_anims.res"
## [source, from, to] in seconds.
const CLIPS := {
	"Walk": ["Walking", 0.0, -1.0],
	"Run": ["Running", 0.0, -1.0],
	"Swing": ["Right_Hand_Sword_Slash", 0.2, 0.85],
	"Throw": ["Toss_Treat", 0.4, 1.35],
	"Fall": ["falling_down", 0.0, -1.0],
	"GetUp": ["Stand_Up2", 0.0, 1.7],
}
const LOOPS := ["Idle", "Walk", "Run"]
const IDLE_FROM := ["Stand_Up2", 3.0]  ## the standing pose the idle breathes in
const IDLE_LENGTH := 3.2
## How the bat is carried while walking (where it points, on average: he faces
## +Z): forward and down, a little out to his right, not across his legs.
const CARRY := {"Walk": Vector3(-0.2, -0.7, 0.7)}
## The slash's moment whose finger poses make the grip.
const GRIP_FROM := ["Right_Hand_Sword_Slash", 0.5]
const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Pinky"]
const FPS := 30.0

var scene: Node3D
var sk: Skeleton3D
var player: AnimationPlayer
var base: Node


func _init() -> void:
	scene = (load(MODEL) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	await process_frame
	player = scene.find_children("*", "AnimationPlayer", true, false)[0]
	player.active = false
	sk = scene.find_children("*", "Skeleton3D", true, false)[0]
	base = player.get_node(player.root_node)
	var sk_path := String(base.get_path_to(sk))

	# The grip: the right hand's finger poses mid-swing.
	var grip := {}
	_pose(player.get_animation(GRIP_FROM[0]), GRIP_FROM[1])
	for finger: String in FINGERS:
		for i in range(1, 5):
			var b := sk.find_bone("mixamorig_RightHand%s%d" % [finger, i])
			if b >= 0:
				grip[b] = sk.get_bone_pose_rotation(b)
	var grip_along := _print_grip()

	var lib := AnimationLibrary.new()
	for clip_name: String in CLIPS:
		var spec: Array = CLIPS[clip_name]
		var src := player.get_animation(spec[0])
		var to: float = spec[2] if spec[2] > 0.0 else src.length
		lib.add_animation(clip_name, _cut(src, spec[1], to))
	lib.add_animation("Idle", _idle())
	for anim_name in lib.get_animation_list():
		var anim := lib.get_animation(anim_name)
		anim.loop_mode = Animation.LOOP_LINEAR if anim_name in LOOPS else Animation.LOOP_NONE
		_hold_grip(anim, grip, sk_path)
		if CARRY.has(anim_name):
			print("hero_anims: %s carries the bat turned %d degrees" % [anim_name, _carry(anim, CARRY[anim_name], grip_along, sk_path)])
	for gait in ["Walk", "Run"]:
		print("hero_anims: %s pace %.3f model units a second (length %.3f s)" % [gait, _pace(lib.get_animation(gait)), lib.get_animation(gait).length])
	print("hero_anims: ", lib.get_animation_list(), " saved ", error_string(ResourceSaver.save(lib, OUT)))
	quit()


## [from, to] of `src` resampled at FPS, starting at 0.
func _cut(src: Animation, from: float, to: float) -> Animation:
	var anim := Animation.new()
	anim.length = to - from
	var steps := maxi(ceili((to - from) * FPS), 1)
	for t in src.get_track_count():
		var kind := src.track_get_type(t)
		if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var nt := anim.add_track(kind)
		anim.track_set_path(nt, src.track_get_path(t))
		for i in steps + 1:
			var at := minf(from + (to - from) * i / steps, to)
			match kind:
				Animation.TYPE_POSITION_3D:
					anim.position_track_insert_key(nt, at - from, src.position_track_interpolate(t, at))
				Animation.TYPE_ROTATION_3D:
					anim.rotation_track_insert_key(nt, at - from, src.rotation_track_interpolate(t, at))
				Animation.TYPE_SCALE_3D:
					anim.scale_track_insert_key(nt, at - from, src.scale_track_interpolate(t, at))
	return anim


## Standing still: the pose Stand_Up2 settles in, breathing: the chest rises
## and falls, the head and arms easing with it, and the weight shifts a little.
func _idle() -> Animation:
	var src := player.get_animation(IDLE_FROM[0])
	_pose(src, IDLE_FROM[1])
	var anim := Animation.new()
	anim.length = IDLE_LENGTH
	# Each bone's pitch (about the body's left-right axis, + leaning back) and
	# roll (about its front-back axis) with the breath (0..1..0).
	var breath := {"mixamorig_Spine": [0.008, 0.0], "mixamorig_Spine1": [0.012, 0.0], "mixamorig_Spine2": [0.016, 0.0],
			"mixamorig_Neck": [-0.012, 0.0], "mixamorig_Head": [-0.01, 0.0],
			"mixamorig_LeftArm": [0.0, -0.03], "mixamorig_RightArm": [0.0, 0.03],
			"mixamorig_LeftForeArm": [0.0, -0.02], "mixamorig_RightForeArm": [0.0, 0.02]}
	var steps := int(IDLE_LENGTH * FPS)
	for t in src.get_track_count():
		var kind := src.track_get_type(t)
		if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var path := src.track_get_path(t)
		var bone_name := String(path.get_concatenated_subnames())
		var b := sk.find_bone(bone_name)
		var nt := anim.add_track(kind)
		anim.track_set_path(nt, path)
		match kind:
			Animation.TYPE_SCALE_3D:
				anim.scale_track_insert_key(nt, 0.0, sk.get_bone_pose_scale(b))
			Animation.TYPE_POSITION_3D:
				var at := sk.get_bone_pose_position(b)
				if bone_name != "mixamorig_Hips":
					anim.position_track_insert_key(nt, 0.0, at)
					continue
				for i in steps + 1:  # the weight shifts side to side, slower than the breath
					var time := IDLE_LENGTH * i / steps
					anim.position_track_insert_key(nt, time, at + Vector3(sin(TAU * time / IDLE_LENGTH) * 0.006, 0, 0))
			Animation.TYPE_ROTATION_3D:
				var q := sk.get_bone_pose_rotation(b)
				if not breath.has(bone_name):
					anim.rotation_track_insert_key(nt, 0.0, q)
					continue
				# About the body's own axes, whatever way the bone's frame is turned.
				var global_basis := sk.get_bone_global_pose(b).basis.orthonormalized()
				var pitch_axis := (global_basis.inverse() * Vector3.RIGHT).normalized()
				var roll_axis := (global_basis.inverse() * Vector3.BACK).normalized()
				var amounts: Array = breath[bone_name]
				for i in steps + 1:
					var time := IDLE_LENGTH * i / steps
					var b01 := 0.5 - 0.5 * cos(TAU * time / IDLE_LENGTH)
					var turn := Quaternion(pitch_axis, amounts[0] * b01) * Quaternion(roll_axis, amounts[1] * b01)
					anim.rotation_track_insert_key(nt, time, q * turn)
	return anim


## Replaces the right hand's finger tracks with the grip (held all through).
func _hold_grip(anim: Animation, grip: Dictionary, sk_path: String) -> void:
	for b: int in grip:
		var path := NodePath("%s:%s" % [sk_path, sk.get_bone_name(b)])
		var track := anim.find_track(path, Animation.TYPE_ROTATION_3D)
		if track >= 0:
			anim.remove_track(track)
		track = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, path)
		anim.rotation_track_insert_key(track, 0.0, grip[b])


## Turns the right forearm and hand about their own length (half each, the same
## all through the clip) so the bat points, on average, as near `target` as it can.
func _carry(anim: Animation, target: Vector3, grip_along: Vector3, sk_path: String) -> int:
	var bones := [sk.find_bone("mixamorig_RightForeArm"), sk.find_bone("mixamorig_RightHand")]
	var tracks := bones.map(func(b): return anim.find_track(NodePath("%s:%s" % [sk_path, sk.get_bone_name(b)]), Animation.TYPE_ROTATION_3D))
	var shoulder := sk.get_bone_parent(bones[0])
	var poses := []  # [upper arm's global basis, forearm's rotation, hand's rotation] through the clip
	for i in 24:
		_pose(anim, anim.length * i / 24.0)
		poses.append([sk.get_bone_global_pose(shoulder).basis.orthonormalized(),
				sk.get_bone_pose_rotation(bones[0]), sk.get_bone_pose_rotation(bones[1])])
	var best := 0
	var best_score := -INF
	for deg in range(-90, 91, 5):
		var half := Quaternion(Vector3.UP, deg_to_rad(deg) * 0.5)  # about the bone's own length (+Y)
		var score := 0.0
		for pose: Array in poses:
			var hand: Basis = pose[0] * Basis(pose[1] * half) * Basis(pose[2] * half)
			score += (hand * grip_along).normalized().dot(target.normalized())
		if score > best_score:
			best_score = score
			best = deg
	var turn := Quaternion(Vector3.UP, deg_to_rad(best) * 0.5)
	for track: int in tracks:
		for k in anim.track_get_key_count(track):
			anim.track_set_key_value(track, k, (anim.track_get_key_value(track, k) as Quaternion) * turn)
	return best


## How fast the ground goes by under a planted foot (model units a second).
func _pace(anim: Animation) -> float:
	var feet := [sk.find_bone("mixamorig_LeftFoot"), sk.find_bone("mixamorig_RightFoot")]
	var samples := 240
	var lows := [INF, INF]
	var track := []
	for i in samples + 1:
		var t := anim.length * i / samples
		_pose(anim, t)
		var at := [sk.get_bone_global_pose(feet[0]).origin, sk.get_bone_global_pose(feet[1]).origin]
		track.append(at)
		for f in 2:
			lows[f] = minf(lows[f], at[f].y)
	var moved := 0.0
	var time := 0.0
	for i in samples:
		for f in 2:
			if track[i][f].y < lows[f] + 0.012 and track[i + 1][f].y < lows[f] + 0.012:
				moved += track[i][f].z - track[i + 1][f].z  # planted: sliding back (he faces +Z)
				time += anim.length / samples
	return moved / maxf(time, 0.001)


## Where the bat goes in the right hand, in the hand bone's own space: through
## the fist (between the knuckles and the curled fingertips), along the knuckles
## from the little finger to the index finger.
func _print_grip() -> Vector3:
	var hand := sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHand"))
	var knuckles := Vector3.ZERO
	var tips := Vector3.ZERO
	for finger in ["Index", "Middle", "Ring", "Pinky"]:
		knuckles += sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHand%s1" % finger)).origin / 4.0
		tips += sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHand%s3" % finger)).origin / 4.0
	var center := (knuckles + tips) * 0.5
	var along := sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHandIndex1")).origin \
			- sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHandPinky1")).origin
	var local_center := hand.affine_inverse() * center
	var local_along := (hand.basis.inverse() * along).normalized()
	print("hero_anims: grip at %s along %s (hand space); knuckles to tips %.3f" % [local_center, local_along, knuckles.distance_to(tips)])
	return local_along


func _pose(anim: Animation, time: float) -> void:
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		var s := base.get_node_or_null(NodePath(path.get_concatenated_names())) as Skeleton3D
		if s == null:
			continue
		var b := s.find_bone(path.get_concatenated_subnames())
		if b < 0:
			continue
		match anim.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				s.set_bone_pose_position(b, anim.position_track_interpolate(t, time))
			Animation.TYPE_ROTATION_3D:
				s.set_bone_pose_rotation(b, anim.rotation_track_interpolate(t, time))
			Animation.TYPE_SCALE_3D:
				s.set_bone_pose_scale(b, anim.scale_track_interpolate(t, time))
	sk.force_update_all_bone_transforms()
