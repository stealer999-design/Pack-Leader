extends SceneTree
## Builds the premade obstacle scenes: four per biome, saved as
## scenes/obstacles/<biome>_<n>.tscn, so levels just place copies of them
## (turned and sized differently) instead of building them at load time.
## Each is a StaticBody3D with one collision cylinder and simple meshes, about
## 2.4 units across. Run after changing a design:
##   godot --headless --path . -s res://scripts/tools/build_obstacles.gd

const OUT := "res://scenes/obstacles"

var _root: StaticBody3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var designs := {
		"meadow": [_oak, _pine, _boulder, _berry_bush],
		"frost": [_snowy_pine, _ice_crystals, _snow_boulder, _frozen_tree],
		"desert": [_cactus, _sandstone_pillar, _palm, _desert_boulders],
		"swamp": [_swamp_tree, _giant_mushroom, _mossy_rock, _old_stump],
	}
	for biome in designs:
		for i in designs[biome].size():
			_root = StaticBody3D.new()
			_root.name = "%s_%d" % [biome.capitalize(), i]
			designs[biome][i].call()
			var packed := PackedScene.new()
			packed.pack(_root)
			var path := "%s/%s_%d.tscn" % [OUT, biome, i]
			print(path, ": ", error_string(ResourceSaver.save(packed, path)))
			_root.free()
	quit()


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
	_sphere(1.1, stone, Vector3(0, 0.6, 0), Vector3(1.15, 0.75, 1.0))
	_sphere(0.5, stone.darkened(0.1), Vector3(0.95, 0.3, 0.45))
	_sphere(0.9, Color(0.35, 0.52, 0.27), Vector3(-0.1, 1.05, 0.05), Vector3(0.85, 0.25, 0.75))  # moss


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

func _snowy_pine() -> void:
	_collide(0.55, 3.4)
	_trunk(0.2, 1.0, Color(0.36, 0.26, 0.2))
	var needles := Color(0.15, 0.32, 0.28)
	var snow := Color(0.93, 0.96, 1.0)
	for tier in [[1.25, 1.4, 1.4], [0.95, 1.2, 2.2], [0.62, 1.0, 2.9]]:
		_cone(tier[0], tier[1], needles, Vector3(0, tier[2], 0))
		_cone(tier[0] * 0.7, tier[1] * 0.5, snow, Vector3(0, tier[2] + tier[1] * 0.28, 0))


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
	var stone := Color(0.45, 0.5, 0.58)
	_sphere(1.1, stone, Vector3(0, 0.6, 0), Vector3(1.15, 0.75, 1.0))
	_sphere(0.55, stone.darkened(0.12), Vector3(-0.9, 0.3, 0.4))
	_sphere(1.0, Color(0.93, 0.96, 1.0), Vector3(0, 1.0, 0), Vector3(0.95, 0.3, 0.85))  # snow cap


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
	_cylinder(0.3, 0.3, 2.6, green, Vector3(0, 1.3, 0))
	_sphere(0.3, green, Vector3(0, 2.6, 0))
	for arm in [[1.0, 1.0, 0.8], [-1.0, 1.4, 0.6]]:
		var side: float = arm[0]
		_cylinder(0.18, 0.18, 0.5, green, Vector3(side * 0.42, arm[1], 0), Vector3(0, 0, 90))
		_cylinder(0.18, 0.18, arm[2], green, Vector3(side * 0.65, arm[1] + arm[2] * 0.5, 0))
		_sphere(0.18, green, Vector3(side * 0.65, arm[1] + arm[2], 0))
	_sphere(0.12, Color(0.95, 0.5, 0.7), Vector3(0, 2.88, 0))  # a flower on top


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
	_sphere(0.95, sand, Vector3(0, 0.6, 0), Vector3(1.1, 0.8, 1.0))
	_sphere(0.6, sand.darkened(0.08), Vector3(0.95, 0.35, -0.3), Vector3(1.0, 0.75, 1.1))
	_sphere(0.45, sand.lightened(0.08), Vector3(-0.75, 0.25, 0.65))


# --- Mirewood Bog -----------------------------------------------------------------

func _swamp_tree() -> void:
	_collide(0.55, 3.2)
	var bark := Color(0.28, 0.24, 0.18)
	_trunk(0.32, 2.0, bark)
	for i in 4:  # roots
		var angle := TAU * i / 4.0 + 0.4
		_cylinder(0.06, 0.12, 0.8, bark, Vector3(cos(angle) * 0.4, 0.25, sin(angle) * 0.4),
				Vector3(rad_to_deg(sin(angle)) * 0.9, 0, -rad_to_deg(cos(angle)) * 0.9))
	var leaves := Color(0.2, 0.32, 0.18)
	_sphere(1.15, leaves, Vector3(0, 2.4, 0), Vector3(1.1, 0.7, 1.1))
	_sphere(0.75, leaves.lightened(0.08), Vector3(0.55, 2.7, 0.2))
	var moss := _mat(Color(0.45, 0.5, 0.36))
	for i in 9:  # hanging moss
		var angle := TAU * i / 9.0
		var strand := BoxMesh.new()
		strand.size = Vector3(0.06, 0.8, 0.06)
		_part(strand, moss, Vector3(cos(angle) * 1.0, 1.8, sin(angle) * 1.0))


func _giant_mushroom() -> void:
	_collide(0.45, 2.4)
	_cylinder(0.24, 0.32, 1.6, Color(0.86, 0.82, 0.7), Vector3(0, 0.8, 0))
	var cap := Color(0.58, 0.22, 0.42)
	_sphere(1.1, cap, Vector3(0, 1.75, 0), Vector3(1.2, 0.5, 1.2))
	for i in 7:
		var angle := TAU * i / 7.0
		_sphere(0.12, Color(0.95, 0.92, 0.85), Vector3(cos(angle) * 0.75, 2.0, sin(angle) * 0.75), Vector3(1, 0.5, 1))
	_sphere(0.14, Color(0.95, 0.92, 0.85), Vector3(0, 2.28, 0), Vector3(1, 0.5, 1))


func _mossy_rock() -> void:
	_collide(1.1, 1.6)
	var stone := Color(0.35, 0.38, 0.33)
	_sphere(1.1, stone, Vector3(0, 0.55, 0), Vector3(1.2, 0.7, 1.0))
	_sphere(0.95, Color(0.3, 0.46, 0.24), Vector3(0.1, 0.95, -0.05), Vector3(0.9, 0.3, 0.8))
	_sphere(0.45, stone.lightened(0.05), Vector3(-0.95, 0.25, 0.35))
	_sphere(0.35, Color(0.3, 0.46, 0.24), Vector3(-0.95, 0.5, 0.35), Vector3(1, 0.4, 1))


func _old_stump() -> void:
	_collide(0.7, 1.1)
	var wood := Color(0.36, 0.3, 0.24)
	_cylinder(0.55, 0.65, 0.9, wood, Vector3(0, 0.45, 0))
	_cylinder(0.5, 0.5, 0.04, Color(0.6, 0.48, 0.32), Vector3(0, 0.91, 0))  # cut top
	for i in 5:
		var angle := TAU * i / 5.0
		_cylinder(0.05, 0.14, 0.7, wood, Vector3(cos(angle) * 0.65, 0.15, sin(angle) * 0.65),
				Vector3(rad_to_deg(sin(angle)) * 1.2, 0, -rad_to_deg(cos(angle)) * 1.2))
	for m in [Vector3(0.5, 0.95, 0.2), Vector3(0.35, 0.92, -0.35)]:  # little mushrooms on the rim
		_cylinder(0.03, 0.03, 0.15, Color(0.9, 0.88, 0.8), m)
		_sphere(0.1, Color(0.85, 0.55, 0.25), m + Vector3(0, 0.1, 0), Vector3(1, 0.5, 1))


# --- Helpers ------------------------------------------------------------------------

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
