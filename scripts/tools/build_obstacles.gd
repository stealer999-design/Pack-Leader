extends SceneTree
## Builds the premade obstacle scenes: four per biome, saved as
## scenes/obstacles/<biome>_<n>.tscn, so levels just place copies of them
## (turned and sized differently) instead of building them at load time.
## Each is a StaticBody3D with one collision cylinder and simple meshes, about
## 2.4 units across. When a Meshy model exists for one (models/scenery/
## <biome>_<n>.glb), it replaces the simple meshes: scaled to the same height,
## standing on the ground, keeping the design's collision. Run after changing a
## design or adding a model:
##   godot --headless --path . -s res://scripts/tools/build_obstacles.gd

const OUT := "res://scenes/obstacles"

var _root: StaticBody3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var designs := {
		"meadow": [_oak, _pine, _boulder, _berry_bush],
		"frost": [_frosted_spruce, _ice_crystals, _snow_boulder, _frozen_tree],
		"desert": [_cactus, _sandstone_pillar, _palm, _desert_boulders],
		"swamp": [_swamp_tree, _vine_tree, _mossy_rock, _old_stump],
		"graveyard": [_headstones, _dead_tree, _crypt, _grave_cross],
		"volcano": [_lava_spire, _charred_tree, _obsidian_shards, _smoking_vent],
	}
	for biome in designs:
		for i in designs[biome].size():
			_root = StaticBody3D.new()
			_root.name = "%s_%d" % [biome.capitalize(), i]
			designs[biome][i].call()
			_use_model("res://models/scenery/%s_%d.glb" % [biome, i])
			var packed := PackedScene.new()
			packed.pack(_root)
			var path := "%s/%s_%d.tscn" % [OUT, biome, i]
			print(path, ": ", error_string(ResourceSaver.save(packed, path)))
			_root.free()
	quit()


## Swaps the design's simple meshes for a Meshy model, if there is one: as tall
## as the design was, centred on it, standing on the ground.
func _use_model(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var old := _bounds(_root, true)
	for child in _root.get_children():
		if child is MeshInstance3D:
			_root.remove_child(child)
			child.free()
	var model: Node3D = (load(path) as PackedScene).instantiate()
	var box := _bounds(model)
	var k := old.size.y / maxf(box.size.y, 0.001)
	model.scale = Vector3.ONE * k
	var centre := box.get_center()
	model.position = Vector3(-centre.x * k, -box.position.y * k, -centre.z * k)
	model.name = "Model"
	_root.add_child(model)
	model.owner = _root  # saved as an instance of the .glb
	# Never block further out than the model reaches (a slimmer model than the design).
	var reach := minf(box.size.x, box.size.z) * k * 0.45
	for child in _root.get_children():
		if child is CollisionShape3D and child.shape is CylinderShape3D and child.shape.radius > reach:
			child.shape.radius = reach
	var glow_path := path.get_basename() + "_emit.png"
	if ResourceLoader.exists(glow_path):
		_glow_model(model, load(glow_path))
	if path.get_file() == "volcano_3.glb":  # the smoking vent
		_add_smoke(Vector3(0, box.size.y * k * 0.85, 0))
	print("  model ", path, ": ", (box.size * k).snapped(Vector3.ONE * 0.01), " (was ", old.size.snapped(Vector3.ONE * 0.01), ")")


## Lava glows: an additive, unlit layer of the glow map over the model (only
## the lava-coloured parts of the texture are bright in it). Done as an overlay
## rather than the material's emission so it looks the same in every renderer.
func _glow_model(model: Node3D, glow: Texture2D) -> void:
	_root.set_editable_instance(model, true)  # so the overlay is saved with the scene
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = glow
	mat.albedo_color = Color(1.6, 1.6, 1.6)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = mat


## Smoke drifting up out of a vent: soft grey puffs that rise, swell and fade.
func _add_smoke(at: Vector3) -> void:
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.position = at
	smoke.amount = 22
	smoke.lifetime = 3.5
	smoke.preprocess = 3.5  # already smoking when the level appears
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.25
	smoke.direction = Vector3.UP
	smoke.spread = 14.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.8
	smoke.gravity = Vector3(0.05, 0.12, 0.0)  # rises a little faster, drifts a touch sideways
	smoke.angle_min = 0.0
	smoke.angle_max = 360.0
	smoke.scale_amount_min = 0.7
	smoke.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.45))
	grow.add_point(Vector2(1.0, 1.6))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.6, 0.57, 0.55, 0.0))
	fade.set_color(1, Color(0.72, 0.7, 0.68, 0.0))
	fade.add_point(0.12, Color(0.58, 0.55, 0.53, 0.85))
	fade.add_point(0.55, Color(0.68, 0.66, 0.64, 0.6))
	smoke.color_ramp = fade
	var puff := QuadMesh.new()
	puff.size = Vector2(1.3, 1.3)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var soft := GradientTexture2D.new()  # a round puff, soft at the edge
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	var edge := Gradient.new()
	edge.set_color(0, Color(1, 1, 1, 1))
	edge.set_color(1, Color(1, 1, 1, 0))
	soft.gradient = edge
	mat.albedo_texture = soft
	puff.material = mat
	smoke.mesh = puff
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(smoke)


## The combined box of every mesh under `node` (in `node`'s space); with
## `solid_only`, leaving out see-through parts (smoke).
func _bounds(node: Node3D, solid_only := false) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var mat := mesh.material_override as BaseMaterial3D
		if solid_only and mat and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue  # smoke and the like: not part of the shape
		var xf := Transform3D.IDENTITY
		var n: Node = mesh
		while n != node:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# --- Greenmeadow -----------------------------------------------------------------

func _oak() -> void:
	_collide(0.5, 3.2)
	_trunk(0.28, 1.7, Color(0.42, 0.28, 0.16))
	var leaves := Color(0.3, 0.55, 0.24)
	_sphere(1.1, leaves, Vector3(0, 2.3, 0))
	_sphere(0.8, leaves.lightened(0.1), Vector3(0.65, 1.95, 0.3))
	_sphere(0.85, leaves.darkened(0.1), Vector3(-0.55, 2.0, -0.35))
	_sphere(0.7, leaves.lightened(0.05), Vector3(0.1, 2.9, -0.2))


func _pine() -> void:
	_collide(0.55, 3.4)
	_trunk(0.2, 1.0, Color(0.38, 0.25, 0.15))
	var needles := Color(0.17, 0.4, 0.25)
	_cone(1.25, 1.4, needles, Vector3(0, 1.4, 0))
	_cone(0.95, 1.2, needles.lightened(0.06), Vector3(0, 2.2, 0))
	_cone(0.62, 1.0, needles.lightened(0.12), Vector3(0, 2.9, 0))


func _boulder() -> void:
	_collide(1.1, 1.6)
	var stone := Color(0.52, 0.5, 0.47)
	_rock_pile(stone)
	_block(Vector3(1.4, 0.12, 1.15), Color(0.35, 0.52, 0.27), Vector3(-0.1, 1.24, 0.0), Vector3(4, 18, -3))  # moss


func _berry_bush() -> void:
	_collide(0.9, 1.3)
	var leaves := Color(0.27, 0.5, 0.24)
	for at in [Vector3(0, 0.65, 0), Vector3(0.6, 0.5, 0.25), Vector3(-0.55, 0.5, -0.2), Vector3(0.1, 0.55, -0.6)]:
		_sphere(0.7, leaves, at)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 14:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1), rng.randf_range(-1, 1)).normalized()
		_sphere(0.09, Color(0.85, 0.15, 0.2), Vector3(0, 0.55, 0) + dir * Vector3(0.95, 0.6, 0.95))


# --- Frostfang Peaks ---------------------------------------------------------------

## A spruce frozen solid: every tier white with snow and ice, no green left.
func _frosted_spruce() -> void:
	_collide(0.55, 3.4)
	_trunk(0.2, 1.0, Color(0.5, 0.48, 0.5))
	var frost := Color(0.82, 0.88, 0.96)
	var snow := Color(0.95, 0.97, 1.0)
	for tier in [[1.25, 1.4, 1.4], [0.95, 1.2, 2.2], [0.62, 1.0, 2.9]]:
		_cone(tier[0], tier[1], frost, Vector3(0, tier[2], 0))
		_cone(tier[0] * 0.7, tier[1] * 0.5, snow, Vector3(0, tier[2] + tier[1] * 0.28, 0))
	_sphere(0.85, snow, Vector3(0, 0.05, 0), Vector3(1.0, 0.2, 1.0))  # snow around the base


func _ice_crystals() -> void:
	_collide(0.85, 2.6)
	var ice := _mat(Color(0.6, 0.85, 1.0, 0.82))
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.emission_enabled = true
	ice.emission = Color(0.2, 0.4, 0.6)
	ice.metallic = 0.3
	ice.roughness = 0.15
	for c in [[0.32, 2.6, Vector3(0, 1.2, 0), Vector3(0, 0, 4)], [0.26, 1.9, Vector3(0.45, 0.85, 0.2), Vector3(10, 0, -22)],
			[0.22, 1.5, Vector3(-0.45, 0.65, -0.1), Vector3(-8, 0, 25)], [0.18, 1.1, Vector3(0.1, 0.45, -0.5), Vector3(-25, 0, 6)]]:
		var mesh := CylinderMesh.new()
		mesh.top_radius = c[0] * 0.4
		mesh.bottom_radius = c[0]
		mesh.height = c[1]
		mesh.radial_segments = 6
		mesh.rings = 1
		_part(mesh, ice, c[2], c[3])
	_sphere(0.85, Color(0.9, 0.94, 1.0), Vector3(0, 0.05, 0), Vector3(1.0, 0.2, 1.0))  # snow around the base


func _snow_boulder() -> void:
	_collide(1.1, 1.6)
	_rock_pile(Color(0.45, 0.5, 0.58))
	_block(Vector3(1.55, 0.16, 1.3), Color(0.93, 0.96, 1.0), Vector3(-0.1, 1.26, 0.0), Vector3(4, 18, -3))  # snow cap
	_block(Vector3(0.6, 0.1, 0.55), Color(0.93, 0.96, 1.0), Vector3(0.95, 0.72, 0.4), Vector3(-6, -20, 8))


func _frozen_tree() -> void:
	_collide(0.4, 3.0)
	var bark := Color(0.55, 0.58, 0.64)
	_trunk(0.22, 2.4, bark)
	for b in [[Vector3(0.35, 1.5, 0), Vector3(0, 0, -50), 0.9], [Vector3(-0.3, 1.9, 0.1), Vector3(10, 0, 45), 0.8],
			[Vector3(0.05, 2.2, -0.3), Vector3(-45, 0, 0), 0.7], [Vector3(0.1, 2.5, 0.25), Vector3(40, 0, -20), 0.6]]:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.03
		mesh.bottom_radius = 0.08
		mesh.height = b[2]
		mesh.radial_segments = 6
		_part(mesh, _mat(bark), b[0], b[1])
	_sphere(0.6, Color(0.93, 0.96, 1.0), Vector3(0, 0.05, 0), Vector3(1.0, 0.2, 1.0))


# --- Sunscorch Dunes ---------------------------------------------------------------

func _cactus() -> void:
	_collide(0.45, 2.8)
	var green := Color(0.3, 0.55, 0.3)
	var spine := _mat(Color(0.07, 0.06, 0.05))  # black spines
	_cylinder(0.3, 0.3, 2.6, green, Vector3(0, 1.3, 0))
	_sphere(0.3, green, Vector3(0, 2.6, 0))
	_spines(spine, Vector3(0, 0.3, 0), Vector3(0, 2.7, 0), 0.3, 9, 8)  # rings of spines up the trunk
	for arm in [[1.0, 1.0, 0.8], [-1.0, 1.4, 0.6]]:
		var side: float = arm[0]
		_cylinder(0.18, 0.18, 0.5, green, Vector3(side * 0.42, arm[1], 0), Vector3(0, 0, 90))
		_cylinder(0.18, 0.18, arm[2], green, Vector3(side * 0.65, arm[1] + arm[2] * 0.5, 0))
		_sphere(0.18, green, Vector3(side * 0.65, arm[1] + arm[2], 0))
		_spines(spine, Vector3(side * 0.65, arm[1], 0), Vector3(side * 0.65, arm[1] + arm[2] + 0.1, 0), 0.18, 4, 6)
	_sphere(0.12, Color(0.95, 0.5, 0.7), Vector3(0, 2.88, 0))  # a flower on top


## Rings of spines along a vertical cactus stem from `from` to `to`.
func _spines(mat: Material, from: Vector3, to: Vector3, radius: float, rings: int, per_ring: int) -> void:
	for r in rings:
		var at := from.lerp(to, (r + 0.5) / rings)
		for i in per_ring:
			var angle := TAU * i / per_ring + r * 0.4
			var out := Vector3(cos(angle), 0.25, sin(angle)).normalized()
			var base := at + Vector3(cos(angle), 0, sin(angle)) * radius * 0.95
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.0
			mesh.bottom_radius = 0.035
			mesh.height = 0.3
			mesh.radial_segments = 4
			mesh.rings = 1
			var part := _part(mesh, mat, base + out * 0.15)
			var x := out.cross(Vector3.FORWARD if absf(out.z) < 0.9 else Vector3.RIGHT).normalized()
			part.basis = Basis(x, out, x.cross(out))  # the point (Y) outwards


func _sandstone_pillar() -> void:
	_collide(0.95, 3.0)
	var tones := [Color(0.76, 0.52, 0.33), Color(0.68, 0.44, 0.27), Color(0.8, 0.58, 0.38), Color(0.7, 0.47, 0.3)]
	var y := 0.0
	for i in 4:
		var h: float = [0.9, 0.8, 0.7, 0.5][i]
		var w: float = [1.9, 1.6, 1.4, 1.1][i]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(w, h, w * 0.9)
		_part(mesh, _mat(tones[i]), Vector3(0.05 * i, y + h * 0.5, -0.04 * i), Vector3(0, i * 9, 0))
		y += h


func _palm() -> void:
	_collide(0.4, 3.4)
	var bark := Color(0.55, 0.4, 0.25)
	var at := Vector3.ZERO
	for i in 6:  # a trunk leaning further at each segment
		var lean := 4.0 + i * 3.5
		var seg := Vector3(sin(deg_to_rad(lean)) * 0.55, cos(deg_to_rad(lean)) * 0.55, 0)
		_cylinder(0.16 - i * 0.012, 0.18 - i * 0.012, 0.6, bark if i % 2 else bark.darkened(0.12), at + seg * 0.5,
				Vector3(0, 0, -lean))
		at += seg
	var frond := Color(0.25, 0.55, 0.22)
	for i in 7:
		var angle := TAU * i / 7.0
		var dir := Vector3(cos(angle), 0, sin(angle))
		var leaf := SphereMesh.new()
		leaf.radius = 0.5
		leaf.height = 1.0
		var part := _part(leaf, _mat(frond if i % 2 else frond.lightened(0.1)), at + dir * 0.6 + Vector3.DOWN * 0.15)
		part.scale = Vector3(1.6, 0.15, 0.45)
		part.rotation = Vector3(0, -angle, -0.35)
	_sphere(0.12, Color(0.45, 0.32, 0.18), at + Vector3(0.12, -0.15, 0.1))  # coconuts
	_sphere(0.12, Color(0.45, 0.32, 0.18), at + Vector3(-0.1, -0.18, -0.08))


func _desert_boulders() -> void:
	_collide(1.05, 1.5)
	var sand := Color(0.72, 0.5, 0.32)
	_rock_pile(sand)
	_block(Vector3(0.7, 0.55, 0.6), sand.lightened(0.08), Vector3(-0.85, 0.27, 0.7), Vector3(0, 35, 6))


# --- Mirewood Bog -----------------------------------------------------------------

func _swamp_tree() -> void:
	_collide(0.55, 3.2)
	var bark := Color(0.28, 0.24, 0.18)
	_trunk(0.32, 2.0, bark)
	for i in 4:  # roots
		var angle := TAU * i / 4.0 + 0.4
		_cylinder(0.06, 0.12, 0.8, bark, Vector3(cos(angle) * 0.4, 0.25, sin(angle) * 0.4),
				Vector3(rad_to_deg(sin(angle)) * 0.9, 0, -rad_to_deg(cos(angle)) * 0.9))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var tips := _crown(Vector3(0, 1.95, 0), bark, Color(0.16, 0.26, 0.14), rng, 5, 1.0)
	var moss := _mat(Color(0.45, 0.5, 0.36))
	for tip in tips:  # moss hanging from the branches
		var length := rng.randf_range(0.5, 0.9)
		var strand := BoxMesh.new()
		strand.size = Vector3(0.06, length, 0.06)
		_part(strand, moss, tip + Vector3(0, -length * 0.5 - 0.05, 0))


## A tall, gnarled swamp tree with spreading, branchy limbs and long vines
## hanging almost to the ground.
func _vine_tree() -> void:
	_collide(0.5, 3.6)
	var bark := Color(0.25, 0.22, 0.17)
	_cylinder(0.22, 0.34, 1.6, bark, Vector3(0, 0.8, 0), Vector3(0, 0, 4))
	_cylinder(0.16, 0.22, 1.3, bark, Vector3(0.12, 2.2, 0), Vector3(0, 0, -8))  # a bend in the trunk
	for i in 3:  # buttress roots
		var angle := TAU * i / 3.0 + 0.3
		_cylinder(0.05, 0.13, 0.8, bark, Vector3(cos(angle) * 0.35, 0.22, sin(angle) * 0.35),
				Vector3(rad_to_deg(sin(angle)) * 1.0, 0, -rad_to_deg(cos(angle)) * 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var tips := _crown(Vector3(0.2, 2.8, 0), bark, Color(0.14, 0.25, 0.14), rng, 6, 1.15)
	var vine := _mat(Color(0.24, 0.42, 0.2))
	var leaf := _mat(Color(0.3, 0.52, 0.24))
	for tip in tips:  # vines dropping from the branches
		var length := rng.randf_range(1.2, minf(2.4, tip.y - 0.3))
		var top: Vector3 = tip + Vector3(0, -0.05, 0)
		var strand := CylinderMesh.new()
		strand.top_radius = 0.05
		strand.bottom_radius = 0.03
		strand.height = length
		strand.radial_segments = 5
		strand.rings = 1
		_part(strand, vine, top + Vector3.DOWN * length * 0.5)
		for l in 3:  # leaves along the vine
			var leaf_mesh := SphereMesh.new()
			leaf_mesh.radius = 0.11
			leaf_mesh.height = 0.22
			leaf_mesh.radial_segments = 6
			leaf_mesh.rings = 3
			var part := _part(leaf_mesh, leaf, top + Vector3(0.05 if l % 2 else -0.05, -length * (0.25 + l * 0.27), 0))
			part.scale = Vector3(1.0, 0.5, 1.6)


func _mossy_rock() -> void:
	_collide(1.1, 1.6)
	var stone := Color(0.35, 0.38, 0.33)
	_rock_pile(stone)
	var moss := Color(0.3, 0.46, 0.24)
	_block(Vector3(1.3, 0.12, 1.05), moss, Vector3(-0.1, 1.24, 0.0), Vector3(4, 18, -3))
	_block(Vector3(0.5, 0.08, 0.45), moss, Vector3(0.95, 0.68, 0.4), Vector3(-6, -20, 8))


func _old_stump() -> void:
	_collide(0.7, 1.1)
	var wood := Color(0.36, 0.3, 0.24)
	_cylinder(0.55, 0.65, 0.9, wood, Vector3(0, 0.45, 0))
	_cylinder(0.5, 0.5, 0.04, Color(0.6, 0.48, 0.32), Vector3(0, 0.91, 0))  # cut top
	for i in 5:
		var angle := TAU * i / 5.0
		_cylinder(0.05, 0.14, 0.7, wood, Vector3(cos(angle) * 0.65, 0.15, sin(angle) * 0.65),
				Vector3(rad_to_deg(sin(angle)) * 1.2, 0, -rad_to_deg(cos(angle)) * 1.2))
	_sphere(0.3, Color(0.3, 0.46, 0.24), Vector3(0.3, 0.92, 0.1), Vector3(1.0, 0.3, 0.9))  # moss on the cut


# --- Hollowmere Graveyard -----------------------------------------------------------

## Three weathered headstones leaning in the grass: a rounded one, a cross
## and a slab, each with a little mound of grave earth.
func _headstones() -> void:
	_collide(1.1, 1.3)
	var stone := Color(0.5, 0.5, 0.52)
	var earth := Color(0.22, 0.18, 0.15)
	# Rounded headstone.
	_block(Vector3(0.62, 0.8, 0.16), stone, Vector3(-0.45, 0.4, 0.1), Vector3(-6, 10, 3))
	_cylinder(0.31, 0.31, 0.16, stone, Vector3(-0.47, 0.8, 0.08), Vector3(90 - 6, 10, 0))
	_block(Vector3(0.36, 0.05, 0.02), stone.darkened(0.35), Vector3(-0.45, 0.62, 0.0), Vector3(-6, 10, 3))  # inscription
	_sphere(0.45, earth, Vector3(-0.45, 0.0, -0.45), Vector3(1.0, 0.25, 1.4))
	# Stone cross.
	_block(Vector3(0.16, 1.1, 0.14), stone.darkened(0.08), Vector3(0.55, 0.55, -0.15), Vector3(4, -20, -8))
	_block(Vector3(0.6, 0.16, 0.14), stone.darkened(0.08), Vector3(0.6, 0.82, -0.15), Vector3(4, -20, -8))
	_sphere(0.4, earth, Vector3(0.45, 0.0, -0.65), Vector3(1.0, 0.22, 1.3))
	# A low cracked slab with moss.
	_block(Vector3(0.5, 0.5, 0.14), stone.lightened(0.05), Vector3(0.05, 0.25, 0.75), Vector3(-14, 35, 0))
	_block(Vector3(0.3, 0.06, 0.15), Color(0.3, 0.4, 0.26), Vector3(0.05, 0.5, 0.76), Vector3(-14, 35, 0))


## A dead, twisted tree: black bare branches reaching out, no leaves.
func _dead_tree() -> void:
	_collide(0.5, 3.0)
	var bark := Color(0.15, 0.13, 0.12)
	_cylinder(0.22, 0.38, 1.8, bark, Vector3(0, 0.9, 0), Vector3(0, 0, 4))
	for i in 4:  # roots
		var angle := TAU * i / 4.0 + 0.4
		_branch(Vector3(0, 0.3, 0), Vector3(cos(angle) * 0.75, 0.0, sin(angle) * 0.75), 0.14, 0.05, bark)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var tips: Array[Vector3] = [Vector3(0.12, 1.75, 0)]
	for depth in 3:
		var next: Array[Vector3] = []
		for from in tips:
			for k in 2:
				var angle := rng.randf() * TAU
				var reach := 0.75 - depth * 0.15
				var to := from + Vector3(cos(angle) * reach, rng.randf_range(0.25, 0.6) - depth * 0.08, sin(angle) * reach)
				_branch(from, to, 0.13 - depth * 0.035, 0.07 - depth * 0.02, bark)
				next.append(to)
		tips = next


## A small stone crypt: steps, pillars either side of an iron door, a pitched
## roof and a cross on top.
func _crypt() -> void:
	_collide(1.25, 2.4)
	var stone := Color(0.46, 0.46, 0.5)
	var dark := Color(0.12, 0.12, 0.14)
	_block(Vector3(2.2, 0.2, 2.0), stone.darkened(0.15), Vector3(0, 0.1, 0))  # base
	_block(Vector3(1.8, 1.5, 1.6), stone, Vector3(0, 0.95, 0.05))
	_block(Vector3(0.7, 1.05, 0.06), dark, Vector3(0, 0.72, -0.77))  # iron door
	_block(Vector3(0.05, 1.0, 0.07), Color(0.3, 0.3, 0.32), Vector3(0, 0.72, -0.8))  # door split
	for x in [-0.6, 0.6]:
		_cylinder(0.11, 0.13, 1.5, stone.lightened(0.08), Vector3(x, 0.95, -0.82))
	_block(Vector3(1.0, 0.1, 0.4), stone.darkened(0.1), Vector3(0, 0.05, -1.05))  # step
	for side in [-1.0, 1.0]:  # the pitched roof: two slabs meeting at a ridge
		_block(Vector3(1.15, 0.14, 1.9), stone.darkened(0.2), Vector3(side * 0.47, 1.98, 0.05), Vector3(0, 0, -side * 32))
	_block(Vector3(0.1, 0.55, 0.1), stone.lightened(0.1), Vector3(0, 2.55, -0.7))  # cross
	_block(Vector3(0.36, 0.1, 0.1), stone.lightened(0.1), Vector3(0, 2.65, -0.7))


## A tall stone cross on a stepped plinth, over a long grave mound with a
## wilted wreath.
func _grave_cross() -> void:
	_collide(0.9, 2.4)
	var stone := Color(0.55, 0.54, 0.52)
	_block(Vector3(0.9, 0.25, 0.9), stone.darkened(0.1), Vector3(0, 0.12, 0))
	_block(Vector3(0.6, 0.3, 0.6), stone, Vector3(0, 0.38, 0))
	_block(Vector3(0.22, 1.9, 0.2), stone.lightened(0.05), Vector3(0, 1.45, 0))
	_block(Vector3(0.9, 0.22, 0.2), stone.lightened(0.05), Vector3(0, 1.9, 0))
	var ring := TorusMesh.new()  # the ring of a Celtic cross
	ring.inner_radius = 0.24
	ring.outer_radius = 0.31
	_part(ring, _mat(stone), Vector3(0, 1.9, 0), Vector3(90, 0, 0))
	_sphere(0.55, Color(0.21, 0.17, 0.14), Vector3(0, 0.0, 0.9), Vector3(0.9, 0.3, 1.5))  # mound
	var wreath := TorusMesh.new()
	wreath.inner_radius = 0.12
	wreath.outer_radius = 0.2
	_part(wreath, _mat(Color(0.3, 0.32, 0.18)), Vector3(0.1, 0.17, 0.75), Vector3(-10, 0, 8))


# --- Cinderpeak Caldera -------------------------------------------------------------

## A tall spire of black volcanic rock with lava glowing in its cracks.
func _lava_spire() -> void:
	_collide(0.9, 3.0)
	var basalt := Color(0.14, 0.12, 0.12)
	_cylinder(0.25, 0.85, 2.4, basalt, Vector3(0, 1.2, 0), Vector3(0, 0, 4))
	_cylinder(0.0, 0.3, 0.8, basalt.lightened(0.05), Vector3(0.08, 2.75, 0), Vector3(0, 0, 6))
	_cylinder(0.12, 0.45, 1.2, basalt.darkened(0.1), Vector3(0.7, 0.6, 0.35), Vector3(0, 0, -18))
	for crack in [[Vector3(0.0, 0.9, -0.62), Vector3(0.07, 1.1, 0.05), 12], [Vector3(0.3, 1.6, -0.38), Vector3(0.06, 0.7, 0.05), -20],
			[Vector3(-0.42, 0.6, -0.5), Vector3(0.06, 0.6, 0.05), 25]]:
		_part(_box_mesh(crack[1]), _glow(Color(1.0, 0.45, 0.08)), crack[0], Vector3(0, -20, crack[2]))
	_sphere(0.35, Color(1.0, 0.4, 0.05), Vector3(-0.5, 0.0, -0.75), Vector3(1.2, 0.15, 1.0)).material_override = _glow(Color(1.0, 0.4, 0.05))


## A burnt tree: a charcoal trunk with stumpy broken limbs, embers glowing in it.
func _charred_tree() -> void:
	_collide(0.45, 2.6)
	var char_color := Color(0.08, 0.07, 0.07)
	_cylinder(0.18, 0.34, 2.0, char_color, Vector3(0, 1.0, 0), Vector3(0, 0, -5))
	_branch(Vector3(0.05, 1.5, 0), Vector3(0.75, 2.15, 0.2), 0.12, 0.05, char_color)
	_branch(Vector3(0.0, 1.8, 0), Vector3(-0.6, 2.4, -0.25), 0.1, 0.04, char_color)
	_branch(Vector3(0.0, 1.1, 0), Vector3(-0.5, 1.35, 0.45), 0.09, 0.04, char_color)
	for i in 4:
		var angle := TAU * i / 4.0 + 0.2
		_branch(Vector3(0, 0.25, 0), Vector3(cos(angle) * 0.6, 0.0, sin(angle) * 0.6), 0.12, 0.04, char_color)
	for at in [Vector3(0.1, 0.7, -0.3), Vector3(-0.18, 1.3, -0.2), Vector3(0.15, 1.75, -0.15)]:
		_sphere(0.06, Color(1, 0.5, 0.1), at).material_override = _glow(Color(1.0, 0.5, 0.1))
	_sphere(0.6, Color(0.25, 0.24, 0.24), Vector3(0, 0.0, 0), Vector3(1.2, 0.12, 1.2))  # ash


## A cluster of glassy black obsidian shards jutting from the ground.
func _obsidian_shards() -> void:
	_collide(1.0, 1.8)
	var glass := _mat(Color(0.08, 0.06, 0.12))
	glass.roughness = 0.1
	glass.metallic = 0.4
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 6:
		var angle := TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
		var dist := 0.2 + (i % 3) * 0.28
		var height := rng.randf_range(0.9, 2.0)
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = rng.randf_range(0.2, 0.32)
		mesh.height = height
		mesh.radial_segments = 4
		mesh.rings = 1
		_part(mesh, glass, Vector3(cos(angle) * dist, height * 0.45, sin(angle) * dist),
				Vector3(rng.randf_range(-15, 15), rng.randf() * 90.0, rng.randf_range(-15, 15)))
	_sphere(0.8, Color(0.16, 0.13, 0.13), Vector3.ZERO, Vector3(1.0, 0.15, 1.0))


## A smoking vent: a low cone of rock with a pool of lava in the top and puffs
## of grey smoke hanging over it.
func _smoking_vent() -> void:
	_collide(1.1, 1.2)
	var basalt := Color(0.18, 0.14, 0.13)
	_cylinder(0.55, 1.15, 0.9, basalt, Vector3(0, 0.45, 0))
	_cylinder(0.5, 0.5, 0.04, Color(1, 0.5, 0.1), Vector3(0, 0.9, 0)).material_override = _glow(Color(1.0, 0.5, 0.1))
	_rock_pile_small(basalt.darkened(0.2), Vector3(1.0, 0, 0.5))
	var smoke := _mat(Color(0.45, 0.43, 0.42, 0.55))
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 4:
		var puff := _sphere(0.3 + i * 0.1, Color.WHITE, Vector3(sin(i * 1.7) * 0.15, 1.25 + i * 0.45, cos(i * 1.7) * 0.15))
		puff.material_override = smoke


func _rock_pile_small(stone: Color, at: Vector3) -> void:
	_block(Vector3(0.6, 0.45, 0.5), stone, at + Vector3(0, 0.22, 0), Vector3(5, 25, -4))
	_block(Vector3(0.35, 0.3, 0.3), stone.lightened(0.08), at + Vector3(-0.35, 0.15, 0.3), Vector3(0, -30, 6))


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## Glowing lava: bright, lit from inside.
func _glow(color: Color) -> StandardMaterial3D:
	var mat := _mat(color)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	return mat


# --- Helpers ------------------------------------------------------------------------

## A chunky rock: a big tilted block with a smaller one leaning on it and a
## little one at its foot (squared off, not round).
func _rock_pile(stone: Color) -> void:
	_block(Vector3(1.8, 1.2, 1.5), stone, Vector3(0, 0.6, 0), Vector3(4, 18, -3))
	_block(Vector3(0.9, 0.75, 0.85), stone.darkened(0.1), Vector3(0.95, 0.35, 0.4), Vector3(-6, -20, 8))
	_block(Vector3(0.55, 0.4, 0.5), stone.lightened(0.06), Vector3(-0.6, 0.18, -0.85), Vector3(0, 40, -5))


func _block(size: Vector3, color: Color, at: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(mesh, _mat(color), at, rot_deg)


## A branchy crown from the top of a trunk: `count` limbs reaching up and out,
## each forking into twigs with small, sparse clumps of leaves. Returns the
## twig tips (for hanging moss and vines).
func _crown(top: Vector3, bark: Color, leaves: Color, rng: RandomNumberGenerator, count: int, reach: float) -> Array[Vector3]:
	var tips: Array[Vector3] = []
	var leaf_mat := _mat(leaves)
	var leaf_light := _mat(leaves.lightened(0.06))
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(angle), 0, sin(angle))
		# The limb: up and out, gently curving through a mid point.
		var mid := top + out * reach * 0.5 + Vector3.UP * rng.randf_range(0.35, 0.6)
		var end := top + out * reach * rng.randf_range(0.9, 1.2) + Vector3.UP * rng.randf_range(0.5, 0.85)
		_branch(top, mid, 0.13, 0.09, bark)
		_branch(mid, end, 0.09, 0.05, bark)
		for f in 2:  # twigs forking off the limb's end
			var side := out.rotated(Vector3.UP, (f - 0.5) * rng.randf_range(0.9, 1.4))
			var tip := end + side * rng.randf_range(0.35, 0.6) + Vector3.UP * rng.randf_range(-0.05, 0.25)
			_branch(end, tip, 0.05, 0.025, bark)
			tips.append(tip)
			for l in 5:  # a small, loose clump of leaves at the tip
				var clump := _sphere(0.13, leaves,
						tip + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.08, 0.14), rng.randf_range(-0.2, 0.2)))
				clump.material_override = leaf_mat if l % 2 else leaf_light
				clump.scale = Vector3(1.1, 0.75, 1.0)
		# A few leaves along the limb, too.
		var along := _sphere(0.15, leaves, mid.lerp(end, 0.5) + Vector3.UP * 0.08)
		along.material_override = leaf_mat
		along.scale = Vector3(1.1, 0.5, 1.0)
	return tips


## A cylinder from `from` to `to`, `r_from` thick at the start tapering to `r_to`.
func _branch(from: Vector3, to: Vector3, r_from: float, r_to: float, color: Color) -> void:
	var dir := to - from
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r_from
	mesh.top_radius = r_to
	mesh.height = dir.length()
	mesh.radial_segments = 6
	mesh.rings = 1
	var part := _part(mesh, _mat(color), (from + to) * 0.5)
	var up := dir.normalized()
	var x := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	part.basis = Basis(x, up, x.cross(up))  # the cylinder's axis (Y) along the branch

## One collision cylinder, standing on the ground.
func _collide(radius: float, height: float) -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position.y = height * 0.5
	_add(shape)


func _trunk(radius: float, height: float, color: Color) -> void:
	_cylinder(radius * 0.8, radius, height, color, Vector3(0, height * 0.5, 0))


func _cone(radius: float, height: float, color: Color, base: Vector3) -> void:
	_cylinder(0.0, radius, height, color, base + Vector3(0, height * 0.5, 0))


func _cylinder(top: float, bottom: float, height: float, color: Color, at: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return _part(mesh, _mat(color), at, rot_deg)


func _sphere(radius: float, color: Color, at: Vector3, scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var part := _part(mesh, _mat(color), at)
	part.scale = scale
	return part


func _part(mesh: Mesh, mat: Material, at: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = at
	part.rotation_degrees = rot_deg
	_add(part)
	return part


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


func _add(node: Node) -> void:
	_root.add_child(node)
	node.owner = _root
