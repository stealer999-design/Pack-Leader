class_name Crate
extends StaticBody3D
## A breakable clay vase on the path (the code still calls them crates).
## One bat hit shatters it and spills coins. Gold vases are rarer and hold
## more coins and a better chance of gear.

## The vase's outline, bottom to top: (height, radius). Turned around its axis.
const PROFILE := [
	Vector2(0.0, 0.2), Vector2(0.04, 0.27), Vector2(0.2, 0.4), Vector2(0.42, 0.47),
	Vector2(0.62, 0.43), Vector2(0.8, 0.29), Vector2(0.9, 0.19), Vector2(0.98, 0.18),
	Vector2(1.06, 0.23), Vector2(1.12, 0.26), Vector2(1.15, 0.24),
]
## Painted stripes around the body (heights); the rest is plain clay.
const BANDS := [Vector2(0.5, 0.56), Vector2(0.66, 0.69)]
const SIDES := 18

static var _mesh: ArrayMesh

# Set by the spawn function before entering the tree.
var gold := false
var level_number := 1

var _material := StandardMaterial3D.new()

@onready var world: World = get_tree().get_first_node_in_group("world")
@onready var model: Node3D = $Model


func _ready() -> void:
	add_to_group("crates")
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = Color(0.95, 0.75, 0.2) if gold else Color(0.8, 0.45, 0.27)
	_material.metallic = 0.6 if gold else 0.0
	_material.roughness = 0.35 if gold else 0.85
	$Model/Vase.mesh = vase_mesh()
	$Model/Vase.material_override = _material
	model.rotation.y = randf() * TAU  # the stripes needn't all line up


func radius() -> float:
	return 0.5


func coin_value() -> int:
	var base := 15 if gold else randi_range(3, 6)
	return base + (level_number - 1) * (3 if gold else 1)


## Server only. Any hit breaks it.
func hit(_damage: float) -> void:
	if is_queued_for_deletion():
		return
	world.spill_coins(global_position, coin_value())
	world.roll_loot(global_position, 0.4 if gold else 0.12)
	world.play_shatter.rpc(global_position, _material.albedo_color)
	queue_free()


## The vase, shared by all of them: a lathed outline with a lip, a dark inside
## at the mouth, and painted stripes (vertex colours, tinted by the material).
static func vase_mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for p: Vector2 in PROFILE:
		var ring := []
		for i in SIDES + 1:
			var a := TAU * i / SIDES
			ring.append(Vector3(cos(a) * p.y, p.x, sin(a) * p.y))
		rings.append(ring)
	for k in PROFILE.size() - 1:
		var y: float = (PROFILE[k].x + PROFILE[k + 1].x) * 0.5
		var shade := Color.WHITE
		for band: Vector2 in BANDS:
			if y >= band.x and y <= band.y:
				shade = Color(0.35, 0.22, 0.16)
		var slope: Vector2 = PROFILE[k + 1] - PROFILE[k]
		for i in SIDES:
			var a0 := TAU * i / SIDES
			var a1 := TAU * (i + 1) / SIDES
			var n0 := Vector3(cos(a0) * slope.x, -slope.y, sin(a0) * slope.x).normalized()
			var n1 := Vector3(cos(a1) * slope.x, -slope.y, sin(a1) * slope.x).normalized()
			var quad := [[rings[k][i], n0], [rings[k + 1][i + 1], n1], [rings[k + 1][i], n0],
					[rings[k][i], n0], [rings[k][i + 1], n1], [rings[k + 1][i + 1], n1]]
			for v in quad:
				st.set_color(shade)
				st.set_normal(v[1])
				st.add_vertex(v[0])
	# The dark mouth and the base.
	var top: Vector2 = PROFILE[-1]
	var bottom: Vector2 = PROFILE[0]
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		for disc in [[top.x - 0.02, top.y * 0.85, Color(0.12, 0.08, 0.06), Vector3.UP],
				[bottom.x, bottom.y, Color.WHITE, Vector3.DOWN]]:
			var c := Vector3(0, disc[0], 0)
			var p0: Vector3 = c + Vector3(cos(a0), 0, sin(a0)) * disc[1]
			var p1: Vector3 = c + Vector3(cos(a1), 0, sin(a1)) * disc[1]
			var tri := [c, p0, p1] if disc[3] == Vector3.UP else [c, p1, p0]
			for v in tri:
				st.set_color(disc[2])
				st.set_normal(disc[3])
				st.add_vertex(v)
	_mesh = st.commit()
	return _mesh
