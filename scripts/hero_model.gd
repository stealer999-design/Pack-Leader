class_name HeroModel
extends Node3D
## The tamer: the hero (models/tamer/hero.glb: the user's Meshy AI model,
## rigged and animated with Mixamo; his moves baked by tools/hero_anims.gd)
## with his bat in his right hand. Faces -Z, feet at y = 0.
##
## Animates itself on every peer from how fast and which way it actually
## moves (measured from its own position), so remote players animate too with
## no extra syncing: stands breathing, walks or runs with the stride paced to
## the speed. Its parent (the player's Model) faces where the tamer aims; his
## legs face where he's going, and his torso follows them only TORSO_FOLLOWS
## of the way, staying turned towards the aim (his head looks the rest of the
## way). Going backwards he backs off: his legs face the aim and the run plays
## in reverse. swing() and throw() play on the upper body, so the legs keep
## running; set_downed() falls down, and gets back up. The shirt takes the
## player's colour.

const MODEL := "res://models/tamer/hero.glb"
const ANIMS := "res://models/tamer/hero_anims.res"
const SKIN_SHADER := preload("res://scripts/hero_skin.gdshader")
const GEAR_SHADER := preload("res://scripts/hero_gear.gdshader")
const FOLDS := preload("res://models/tamer/gear/folds.png")
const HEIGHT := 1.95  ## Standing height, world units.
## The ground the walk and the run cover in a second at their normal speed
## (model units; measured by tools/hero_anims.gd), to pace the stride.
const WALK_PACE := 1.267
const RUN_PACE := 4.602
const RUN_FROM := 3.0  ## Runs above this speed (world units a second), walks below.
## The fist in the right hand bone's own space (tools/hero_anims.gd), and the
## way a held bat points out of it (from the little finger past the index finger).
const GRIP_AT := Vector3(-0.0105, 0.112, 0.004)
const GRIP_ALONG := Vector3(0.658, 0.303, 0.689)
const FOOT_DOWN := 0.03  ## A foot this near its standing height (model units) is planted.
## How far round his torso turns with his legs when he runs a different way to
## where he aims (the rest of the way it stays towards the aim).
const TORSO_FOLLOWS := 0.4
## Going this far (radians) from where he aims, he backs off instead (and runs
## forward again under BACK_TO, so it doesn't flip back and forth at the edge).
const BACK_FROM := deg_to_rad(120.0)
const BACK_TO := deg_to_rad(95.0)
## The clothes (made from the hero himself by tools/hero_gear.gd), for each look
## level (ItemDB.look_level: 1-2 the first tier's item, 3-4 the second's, 5 the
## third's), in the order of the outfit (jacket, pants, hat, boots).
const GEAR_DIR := "res://models/tamer/gear/"
const GEAR := {
	"jacket": ["jacket_leather", "jacket_leather", "jacket_padded", "jacket_padded", "jacket_duster"],
	"pants": ["pants_work", "pants_work", "pants_reinforced", "pants_reinforced", "pants_breeches"],
	"hat": ["hat_fedora", "hat_fedora", "hat_cowboy", "hat_cowboy", "hat_warden"],
	"boots": ["boots_sneakers", "boots_sneakers", "boots_hiking", "boots_hiking", "boots_pathfinder"],
}
const OUTFIT := ["jacket", "pants", "hat", "boots"]
## How each garment's cloth catches the light (leather and steel shine more).
const FOLD_STRENGTH := 1.3  ## How strongly the clothes underneath crease a garment.
const SHEEN := {"jacket_leather": 0.5, "hat_cowboy": 0.15, "boots_hiking": 0.6, "boots_pathfinder": 0.55}

var _scene: Node3D
var _skeleton: Skeleton3D
var _tree: AnimationTree
var _body: MeshInstance3D
var _hand: BoneAttachment3D
var _bat: Node3D
var _bat_tier := -1
var _scale := 1.0
var _last_position := Vector3.INF
var _speed := 0.0
var _velocity := Vector3.ZERO  ## Smoothed, along the ground.
var _legs := 0.0  ## How far (radians) his legs are turned from where he aims.
var _backwards := false
var _twist: TorsoTwist
var _gait := "idle"
var _downed := false
var _rise_left := 0.0
var _feet: Array[int] = []
var _foot_rest: Array[float] = []
var _foot_up: Array[bool] = [false, false]
var _overlay: StandardMaterial3D
var _tint_tween: Tween
var _worn := {}  ## Kind -> look level shown.
var _gear := {}  ## Kind -> its MeshInstance3D.


## Puts the hero together: `body_material` is the player's own material, whose
## colour the shirt takes (the hair colour isn't used: the hero has his own).
func build(body_material: StandardMaterial3D, _hair_color := Color.BLACK) -> void:
	_scene = (load(MODEL) as PackedScene).instantiate()
	add_child(_scene)
	_skeleton = _scene.find_children("*", "Skeleton3D", true, false)[0]
	_body = _scene.find_children("*", "MeshInstance3D", true, false)[0]
	# HEIGHT tall with his feet on the ground, turned to face -Z (Meshy's face +Z).
	var box := _body.get_aabb()
	_scale = HEIGHT / box.size.y
	_scene.scale = Vector3.ONE * _scale
	_scene.position.y = -box.position.y * _scale
	_scene.rotation.y = PI
	var skin := ShaderMaterial.new()
	skin.shader = SKIN_SHADER
	skin.set_shader_parameter("albedo_tex", (_body.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture)
	skin.set_shader_parameter("shirt_color", body_material.albedo_color)
	_body.material_override = skin
	_hand = BoneAttachment3D.new()
	_hand.name = "RightHand"
	_skeleton.add_child(_hand)
	_hand.bone_name = "mixamorig_RightHand"
	for side in ["Left", "Right"]:
		var foot := _skeleton.find_bone("mixamorig_%sFoot" % side)
		_feet.append(foot)
		_foot_rest.append(_skeleton.get_bone_global_rest(foot).origin.y)
	_twist = TorsoTwist.new()
	_twist.name = "TorsoTwist"
	for bone in ["Spine", "Spine1", "Spine2"]:
		_twist.spine.append(_skeleton.find_bone("mixamorig_" + bone))
	for bone in ["Neck", "Head"]:
		_twist.head.append(_skeleton.find_bone("mixamorig_" + bone))
	_skeleton.add_child(_twist)
	_build_tree()


## Shows the bat for a tier of Player.BATS (BatModels), gripped in the right fist.
func set_bat_tier(tier: int) -> void:
	if _hand == null or tier == _bat_tier:
		return
	_bat_tier = tier
	if _bat:
		_bat.queue_free()
	_bat = BatModels.build(tier)
	_hand.add_child(_bat)
	# Bats point along -Z from the grip, in world units (the hand is at the model's scale).
	var basis := Basis.looking_at(GRIP_ALONG.normalized(), Vector3.UP).scaled(Vector3.ONE / _scale)
	_bat.transform = Transform3D(basis, GRIP_AT)


## Dresses the tamer: `outfit` holds the level (0 = none) of the worn jacket,
## pants, hat and boots: 1-5, see ItemDB.look_level (ItemDB.OUTFIT_COLORS for their colours).
func set_outfit(outfit: PackedInt32Array) -> void:
	if _body == null:
		return
	for i in OUTFIT.size():
		_wear(OUTFIT[i], outfit[i] if i < outfit.size() else 0)


## Puts on (or takes off, level 0) a kind of garment: skinned to his skeleton
## like his body, so it moves with him.
func _wear(kind: String, level: int) -> void:
	if int(_worn.get(kind, 0)) == level:
		return
	_worn[kind] = level
	if _gear.has(kind):
		(_gear[kind] as Node).queue_free()
		_gear.erase(kind)
	var looks: Array = GEAR[kind]
	if level <= 0 or level > looks.size():
		return
	var garment: String = looks[level - 1]
	var mesh := load(GEAR_DIR + garment + ".res") as ArrayMesh
	var part := MeshInstance3D.new()
	part.name = kind.capitalize()
	part.mesh = mesh
	part.skin = _body.skin
	_body.get_parent().add_child(part)
	part.transform = _body.transform
	part.skeleton = part.get_path_to(_skeleton)
	var color: Color = ItemDB.OUTFIT_COLORS[kind][level - 1]
	var folds := 0.0 if kind == "hat" else FOLD_STRENGTH
	part.set_surface_override_material(0, _cloth(color, SHEEN.get(garment, 0.0), folds))
	if mesh.get_surface_count() > 1:
		part.set_surface_override_material(1, _cloth(_trim(garment, color), 0.3, folds * 0.5))
	_gear[kind] = part
	if _overlay and _tint_tween and _tint_tween.is_running():
		part.material_overlay = _overlay


## A garment's cloth: its colour, with the creases and seams of the clothes
## it covers (hats have none), seen from both sides (inside a sleeve or a hem).
func _cloth(color: Color, sheen: float, folds := 1.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GEAR_SHADER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("folds", FOLDS)
	mat.set_shader_parameter("fold_strength", folds)
	mat.set_shader_parameter("roughness", lerpf(0.9, 0.45, sheen))
	mat.set_shader_parameter("specular", lerpf(0.3, 0.5, sheen))
	return mat


## The trim's colour: soles, pads, bands and ridges.
func _trim(garment: String, color: Color) -> Color:
	match garment:
		"boots_sneakers":
			return Color(0.92, 0.9, 0.86)  # white soles
		"boots_hiking", "boots_pathfinder":
			return Color(0.16, 0.13, 0.11)  # dark rubber soles (and the cuff)
		"pants_reinforced":
			return color.darkened(0.3)  # knee pads
		"hat_warden":
			return Color(0.25, 0.17, 0.1)  # band and feather
		"hat_fedora":
			return Color(0.11, 0.09, 0.08)  # a dark ribbon
		"hat_cowboy":
			return Color(0.45, 0.28, 0.15)  # a leather band
	return color.darkened(0.3)


## The bat swing, over `duration` seconds: wind up with the bat cocked back,
## whip it across the front and follow through. The legs keep moving.
func swing(duration := 0.32) -> void:
	if _tree == null:
		return
	_tree.set("parameters/SwingRate/scale", _length("Swing") / maxf(duration, 0.05))
	_tree.set("parameters/SwingShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## An overhand toss with the free (left) hand: a capture treat.
func throw(duration := 0.4) -> void:
	if _tree == null:
		return
	_tree.set("parameters/ThrowRate/scale", _length("Throw") / maxf(duration, 0.05))
	_tree.set("parameters/ThrowShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Downed: he falls and lies there; back up, he gets to his feet (cut short
## if he sets off walking).
func set_downed(on: bool) -> void:
	if _tree == null or on == _downed:
		return
	_downed = on
	_tree.set("parameters/State/transition_request", "down" if on else "rise")
	_rise_left = 0.0 if on else _length("GetUp")


## A white flash when hit.
func flash() -> void:
	_tint(Color(1, 1, 1, 0.55), 0.15)


## An icy tint while slowed, fading over `duration`.
func chill(duration: float) -> void:
	_tint(Color(0.7, 0.9, 1.0, 0.4), duration)


func _process(delta: float) -> void:
	if _tree == null:
		return
	# Pace from how far he actually moved (works for remote players too; a
	# jump of several units in a frame is a teleport, not a run).
	var pos := global_position
	if _last_position != Vector3.INF and delta > 0.0:
		var step := Vector3(pos.x - _last_position.x, 0.0, pos.z - _last_position.z)
		if step.length() < 3.0:
			var blend := 1.0 - exp(-10.0 * delta)
			_speed = lerpf(_speed, step.length() / delta, blend)
			_velocity = _velocity.lerp(step / delta, blend)
	_last_position = pos
	_turn_legs(delta)
	if _rise_left > 0.0:
		_rise_left -= delta
		if _rise_left <= 0.0 or _speed > 1.5:
			_rise_left = 0.0
			_tree.set("parameters/State/transition_request", "up")
	var gait := _gait
	match _gait:
		"idle":
			if _speed > 0.6:
				gait = "run" if _speed > RUN_FROM else "walk"
		"walk":
			if _speed < 0.35:
				gait = "idle"
			elif _speed > RUN_FROM:
				gait = "run"
		"run":
			if _speed < RUN_FROM * 0.8:
				gait = "walk" if _speed > 0.35 else "idle"
	if gait != _gait:
		_gait = gait
		_tree.set("parameters/Gait/transition_request", gait)
	var way := -1.0 if _backwards else 1.0  # backing off: the stride plays in reverse
	_tree.set("parameters/WalkRate/scale", way * clampf(_speed / (WALK_PACE * _scale), 0.6, 2.2))
	_tree.set("parameters/RunRate/scale", way * clampf(_speed / (RUN_PACE * _scale), 0.75, 1.5))
	_footsteps()


## Turns his legs to where he's going (he faces where he aims: our parent), or,
## going backwards, to face the aim while he backs off; his torso turns back
## towards the aim but for TORSO_FOLLOWS of the way, and his head looks at it.
func _turn_legs(delta: float) -> void:
	var target := 0.0
	var parent := get_parent() as Node3D
	if parent and _speed > 1.0 and not _downed and _rise_left <= 0.0:
		var aim := -parent.global_basis.z
		var off := wrapf(atan2(-_velocity.x, -_velocity.z) - atan2(-aim.x, -aim.z), -PI, PI)
		if _backwards and absf(off) < BACK_TO:
			_backwards = false
		elif not _backwards and absf(off) > BACK_FROM:
			_backwards = true
		target = wrapf(off + PI, -PI, PI) if _backwards else off
	elif _speed < 0.5:
		_backwards = false
	_legs = lerp_angle(_legs, target, 1.0 - exp(-12.0 * delta))
	rotation.y = _legs
	_twist.torso = -_legs * (1.0 - TORSO_FOLLOWS)
	_twist.look = -_legs * TORSO_FOLLOWS


## A footstep each time a foot comes down (its bone back near its standing height).
func _footsteps() -> void:
	for f in 2:
		var y := _skeleton.get_bone_global_pose(_feet[f]).origin.y
		if _foot_up[f] and y < _foot_rest[f] + FOOT_DOWN:
			_foot_up[f] = false
			if _speed > 1.0 and not _downed:
				SoundFX.play(self, "step", global_position, 0.12)
		elif not _foot_up[f] and y > _foot_rest[f] + FOOT_DOWN * 2.0:
			_foot_up[f] = true


## The animation tree: the gait (idle, walk or run, paced), the swing and the
## throw over it on the upper body only, and falling down and getting up over all.
func _build_tree() -> void:
	var player: AnimationPlayer = _scene.find_children("*", "AnimationPlayer", true, false)[0]
	for lib_name in player.get_animation_library_list():
		player.remove_animation_library(lib_name)
	player.add_animation_library("", load(ANIMS))
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_scene.add_child(_tree)  # its root node (its parent) is the model's root, like the player's
	_tree.anim_player = _tree.get_path_to(player)
	var upper: Array[NodePath] = []
	var spine := _skeleton.find_bone("mixamorig_Spine")
	var skeleton_path := String(_scene.get_path_to(_skeleton))
	for b in _skeleton.get_bone_count():
		var at := b
		while at >= 0 and at != spine:
			at = _skeleton.get_bone_parent(at)
		if at == spine:
			upper.append(NodePath("%s:%s" % [skeleton_path, _skeleton.get_bone_name(b)]))
	var bt := AnimationNodeBlendTree.new()
	for anim_name in ["Idle", "Walk", "Run", "Swing", "Throw", "Fall", "GetUp"]:
		var node := AnimationNodeAnimation.new()
		node.animation = anim_name
		bt.add_node(anim_name, node)
	for anim_name in ["Walk", "Run", "Swing", "Throw"]:
		bt.add_node(anim_name + "Rate", AnimationNodeTimeScale.new())
		bt.connect_node(anim_name + "Rate", 0, anim_name)
	var gait := AnimationNodeTransition.new()
	gait.xfade_time = 0.2
	for input in ["idle", "walk", "run"]:
		gait.add_input(input)
	bt.add_node("Gait", gait)
	bt.connect_node("Gait", 0, "Idle")
	bt.connect_node("Gait", 1, "WalkRate")
	bt.connect_node("Gait", 2, "RunRate")
	var below := "Gait"
	for shot_name in ["Swing", "Throw"]:
		var shot := AnimationNodeOneShot.new()
		shot.fadein_time = 0.05
		shot.fadeout_time = 0.15
		shot.filter_enabled = true
		for path in upper:
			shot.set_filter_path(path, true)
		bt.add_node(shot_name + "Shot", shot)
		bt.connect_node(shot_name + "Shot", 0, below)
		bt.connect_node(shot_name + "Shot", 1, shot_name + "Rate")
		below = shot_name + "Shot"
	var state := AnimationNodeTransition.new()
	state.xfade_time = 0.3
	for input in ["up", "down", "rise"]:
		state.add_input(input)
	bt.add_node("State", state)
	bt.connect_node("State", 0, below)
	bt.connect_node("State", 1, "Fall")
	bt.connect_node("State", 2, "GetUp")
	bt.connect_node("output", 0, "State")
	_tree.tree_root = bt
	_tree.active = true
	_tree.set("parameters/Gait/transition_request", "idle")  # (transitions start with no state)
	_tree.set("parameters/State/transition_request", "up")


func _length(anim_name: String) -> float:
	var player := _tree.get_node(_tree.anim_player) as AnimationPlayer
	return player.get_animation(anim_name).length


## Lays a colour over everything he wears and holds, fading out over `fade` seconds.
func _tint(color: Color, fade: float) -> void:
	if _overlay == null:
		_overlay = StandardMaterial3D.new()
		_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = color
	_set_overlay(_overlay)
	if _tint_tween:
		_tint_tween.kill()
	_tint_tween = create_tween()
	_tint_tween.tween_property(_overlay, "albedo_color:a", 0.0, fade)
	_tint_tween.tween_callback(_set_overlay.bind(null))


func _set_overlay(mat: Material) -> void:
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = mat


## Turns his spine (shared between its bones), then his neck and head, about
## the up axis, after the animation has posed him: so his legs can face where
## he runs while his torso and head turn towards where he aims.
class TorsoTwist extends SkeletonModifier3D:
	var spine: Array[int] = []
	var head: Array[int] = []
	var torso := 0.0  ## Radians, + to his left.
	var look := 0.0

	func _process_modification() -> void:
		var skeleton := get_skeleton()
		if skeleton == null or (is_zero_approx(torso) and is_zero_approx(look)):
			return
		for bone in spine:
			_turn(skeleton, bone, torso / spine.size())
		for bone in head:
			_turn(skeleton, bone, look / head.size())

	## Turns a bone about the skeleton's up axis (its parents' turns, being
	## about that same axis, don't move it).
	func _turn(skeleton: Skeleton3D, bone: int, angle: float) -> void:
		var axis := (skeleton.get_bone_global_pose(bone).basis.orthonormalized().inverse() * Vector3.UP).normalized()
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(axis, angle))
