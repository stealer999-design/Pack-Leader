extends SceneTree
## Rigs and animates the Frost Wraith, a static model (Meshy, no skeleton):
## a body bone and a bone at each shoulder. Each arm's vertices (out past the
## body, in front of its cape, from its shoulder down to its claws) ride their
## shoulder, blended into the body near it; everything else rides the body.
## The animations are made here: Idle (the arms drift), Walk (it hovers
## forward: leaning in, its arms trailing, no bob), Swipe (its attack: both
## arms wind back and swing forward, claws sweeping in) and Hiss (its
## ability: arms flung up and out). Saved as a scene PetModels loads like a
## .glb (res://models/pets/frost_wraith.scn).
##   godot --headless --path . -s res://scripts/tools/rig_wraith.gd

const SOURCE := "res://models/pets/frost_wraith_source.glb"
const OUT := "res://models/pets/frost_wraith.scn"
const BODY_AT := Vector3(0.0, -0.1, 0.0)
const SHOULDER := Vector3(0.15, 0.18, 0.03)  ## the right shoulder (+x); the left mirrors it
## Each arm traced through the mesh (from front and side views, the arm's
## vertices tinted by this weight): shoulder, wrist (where it leaves the
## sleeve), hand, claw tips; the arms reach forward, claws out in front.
const ARM_LINE := {
	1: [Vector3(-0.14, 0.19, 0.03), Vector3(-0.21, 0.13, 0.07), Vector3(-0.25, 0.02, 0.13), Vector3(-0.25, -0.13, 0.2)],  # ArmL (-x)
	2: [Vector3(0.13, 0.19, 0.03), Vector3(0.18, 0.10, 0.07), Vector3(0.25, 0.0, 0.15), Vector3(0.31, -0.09, 0.21)],  # ArmR (+x)
}
const ARM_CORE := 0.045  ## within this of the line: wholly the arm
const ARM_OUT := 0.08  ## beyond this: wholly the body


func _init() -> void:
	var src := (load(SOURCE) as PackedScene).instantiate() as Node3D
	var src_mesh: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	var arrays := src_mesh.mesh.surface_get_arrays(0)
	var material := src_mesh.get_active_material(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

	var root_node := Node3D.new()
	root_node.name = "FrostWraith"
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	root_node.add_child(skeleton)
	skeleton.owner = root_node
	skeleton.add_bone("Body")
	skeleton.set_bone_rest(0, Transform3D(Basis(), BODY_AT))
	for side in ["ArmL", "ArmR"]:
		var b := skeleton.get_bone_count()
		skeleton.add_bone(side)
		skeleton.set_bone_parent(b, 0)
		var x := -SHOULDER.x if side == "ArmL" else SHOULDER.x
		skeleton.set_bone_rest(b, Transform3D(Basis(), Vector3(x, SHOULDER.y, SHOULDER.z) - BODY_AT))
	skeleton.reset_bone_poses()

	# Weights: an arm is what's out past the body's sides, in front of the cape,
	# between the shoulder and a little below the claws.
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var on_arms := 0
	for p in verts:
		var aw := arm_weight(p)
		var arm: int = aw[0]
		var w: float = aw[1]
		bones.append_array([0, arm, 0, 0])
		weights.append_array([1.0 - w, w, 0.0, 0.0])
		if w > 0.5:
			on_arms += 1
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var skin := Skin.new()
	for b in skeleton.get_bone_count():
		skin.add_named_bind(skeleton.get_bone_name(b), skeleton.get_bone_global_rest(b).affine_inverse())
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mesh
	body.skin = skin
	skeleton.add_child(body)
	body.owner = root_node
	body.skeleton = NodePath("..")

	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root_node.add_child(player)
	player.owner = root_node
	var lib := AnimationLibrary.new()
	# Each pose: [time, body lean (+ forward), arm pitch (+ back, - forward and up),
	# arm swing (+ in towards the front), arm raise (+ up and out)].
	lib.add_animation("Idle", _anim(3.0, true, [
		[0.0, 0.04, 0.05, 0.0, 0.0], [1.5, 0.04, -0.07, 0.06, 0.08], [3.0, 0.04, 0.05, 0.0, 0.0]], 0.6))
	lib.add_animation("Walk", _anim(2.0, true, [
		[0.0, 0.16, 0.32, -0.08, 0.05], [1.0, 0.16, 0.22, -0.02, 0.12], [2.0, 0.16, 0.32, -0.08, 0.05]], 1.0))
	lib.add_animation("Swipe", _anim(0.8, false, [
		[0.0, 0.08, 0.1, 0.0, 0.0], [0.25, 0.0, 0.65, -0.25, 0.25], [0.42, 0.22, -1.15, 0.55, 0.1],
		[0.55, 0.24, -1.05, 0.6, 0.05], [0.8, 0.08, 0.1, 0.0, 0.0]], 0.0))
	lib.add_animation("Hiss", _anim(1.0, false, [
		[0.0, 0.05, 0.05, 0.0, 0.0], [0.3, -0.08, -0.35, -0.2, 1.05], [0.7, -0.08, -0.4, -0.2, 1.1],
		[1.0, 0.05, 0.05, 0.0, 0.0]], 0.0))
	player.add_animation_library("", lib)

	var packed := PackedScene.new()
	packed.pack(root_node)
	print("rig_wraith: %d of %d vertices on the arms; saved %s" % [on_arms, verts.size(), error_string(ResourceSaver.save(packed, OUT))])
	quit()


## [arm bone, weight] for a vertex: near its side's arm line, fading in from the shoulder.
static func arm_weight(p: Vector3) -> Array:
	var arm := 1 if p.x < 0.0 else 2
	var line: Array = ARM_LINE[arm]
	var best := INF
	var along := 0.0
	var total := 0.0
	for i in line.size() - 1:
		total += (line[i + 1] - line[i]).length()
	var walked := 0.0
	for i in line.size() - 1:
		var a: Vector3 = line[i]
		var b: Vector3 = line[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + (b - a) * t)
		if d < best:
			best = d
			along = (walked + (b - a).length() * t) / total
		walked += (b - a).length()
	var w := 1.0 - smoothstep(ARM_CORE, ARM_OUT, best)
	w *= smoothstep(0.02, 0.22, along)  # blends into the body at the shoulder
	return [arm, w]


## An animation through `poses`; `sway` (loops) rocks the arms out of step a little.
func _anim(length: float, loop: bool, poses: Array, sway: float) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var body := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(body, "Skeleton3D:Body")
	var arms := {}
	for side in ["ArmL", "ArmR"]:
		arms[side] = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(arms[side], "Skeleton3D:" + side)
	for pose: Array in poses:
		var t: float = pose[0]
		anim.rotation_track_insert_key(body, t, Quaternion(Vector3.RIGHT, pose[1]))
		for side in ["ArmL", "ArmR"]:
			var s := -1.0 if side == "ArmL" else 1.0  # the left arm mirrors the right
			var out_of_step := sway * 0.06 * sin(TAU * t / length + (0.0 if side == "ArmL" else PI)) if loop else 0.0
			# Swing in towards the front is about up (the right arm turns -, the left +);
			# raise up and out is about the forward axis (the right arm +, the left -).
			var q := Quaternion(Vector3.UP, -s * pose[3]) * Quaternion(Vector3.BACK, s * pose[4]) \
					* Quaternion(Vector3.RIGHT, pose[2] + out_of_step)
			anim.rotation_track_insert_key(arms[side], t, q)
	return anim
