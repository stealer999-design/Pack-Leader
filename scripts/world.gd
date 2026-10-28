class_name World
extends Node3D
## The shared game world. Spawned on every peer by Main's LevelSpawner; the
## server spawns players and creatures, which the spawners replicate.

@export var player_scene: PackedScene
@export var creature_scene: PackedScene
@export var max_wild_creatures := 18
@export var wild_spawn_interval := 2.5
@export var arena_half_size := 36.0
## Wild creatures never spawn closer than this to a player.
@export var spawn_clearance := 14.0
## Creature level rises by one every this many units from the centre.
@export var level_band_width := 12.0
## Pets within this distance of a kill share the XP.
@export var xp_share_range := 25.0
## How close a player must be to the stable to use it.
@export var stable_range := 4.5

var _spawn_timer := 0.0

@onready var players_root: Node3D = $Players
@onready var creatures_root: Node3D = $Creatures
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var creature_spawner: MultiplayerSpawner = $CreatureSpawner
@onready var stable: Node3D = $Stable
@onready var camera_rig: Node3D = $CameraRig
@onready var hud: HUD = $HUD


func _enter_tree() -> void:
	add_to_group("world")


func _ready() -> void:
	player_spawner.spawn_function = _spawn_player
	creature_spawner.spawn_function = _spawn_creature
	if not multiplayer.is_server():
		return
	Network.player_joined.connect(_on_player_joined)
	Network.player_left.connect(_on_player_left)
	for id in Network.players:
		_on_player_joined(id, Network.players[id])
	for i in max_wild_creatures * 2 / 3:
		_spawn_wild_creature()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = wild_spawn_interval
		if get_wild_creatures().size() < max_wild_creatures:
			_spawn_wild_creature()


# --- Lookups ---------------------------------------------------------------------

func get_player(peer_id: int) -> Player:
	return players_root.get_node_or_null(str(peer_id)) as Player


func get_players() -> Array[Player]:
	var out: Array[Player] = []
	for p: Player in players_root.get_children():
		if not p.is_queued_for_deletion():
			out.append(p)
	return out


func get_creature(creature_name: String) -> Creature:
	return creatures_root.get_node_or_null(creature_name) as Creature


func get_wild_creatures() -> Array[Creature]:
	return _creatures_where(func(c: Creature) -> bool: return c.is_wild())


func get_all_pets() -> Array[Creature]:
	return _creatures_where(func(c: Creature) -> bool: return not c.is_wild())


## A player's party, ordered by party slot.
func get_pets(peer_id: int) -> Array[Creature]:
	var pets := _creatures_where(func(c: Creature) -> bool: return c.owner_id == peer_id)
	pets.sort_custom(func(a: Creature, b: Creature) -> bool: return a.party_slot < b.party_slot)
	return pets


func get_party_pet(peer_id: int, slot: int) -> Creature:
	for pet in get_pets(peer_id):
		if pet.party_slot == slot:
			return pet
	return null


## Every targetable enemy of `attacker` within `max_range` of `center` (no friendly fire).
func enemies_near(attacker: Node3D, center: Vector3, max_range: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var candidates: Array[Node3D] = []
	candidates.append_array(get_players())
	candidates.append_array(_creatures_where(func(_c: Creature) -> bool: return true))
	for node in candidates:
		if not Combat.are_enemies(attacker, node) or not node.is_targetable():
			continue
		var d := Vector2(node.global_position.x - center.x, node.global_position.z - center.z).length()
		if d <= max_range + node.radius():
			out.append(node)
	return out


func nearest_enemy(attacker: Node3D, point: Vector3, max_range: float) -> Creature:
	var best: Creature = null
	var best_dist := INF
	for node in enemies_near(attacker, point, max_range):
		var d := node.global_position.distance_to(point)
		if node is Creature and d < best_dist:
			best = node
			best_dist = d
	return best


## The creature closest to `point` on the ground, if the point is on or near it.
func creature_near(point: Vector3, tolerance := 0.8) -> Creature:
	var best: Creature = null
	var best_dist := INF
	for c in _creatures_where(func(c: Creature) -> bool: return not c.fainted):
		var d := Vector2(c.global_position.x - point.x, c.global_position.z - point.z).length()
		if d < c.radius() + tolerance and d < best_dist:
			best = c
			best_dist = d
	return best


func is_near_stable(point: Vector3) -> bool:
	return Vector2(point.x - stable.global_position.x, point.z - stable.global_position.z).length() <= stable_range


func clamp_to_arena(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, -arena_half_size, arena_half_size), point.y,
			clampf(point.z, -arena_half_size, arena_half_size))


## Server only: spawn slots follow join order so players never overlap.
func player_spawn_point(peer_id: int) -> Vector3:
	var slot := maxi(Network.players.keys().find(peer_id), 0)
	var angle := float(slot) * TAU / 4.0
	return Vector3(cos(angle), 0.0, sin(angle)) * 2.0


func _creatures_where(predicate: Callable) -> Array[Creature]:
	var out: Array[Creature] = []
	for c: Creature in creatures_root.get_children():
		if not c.is_queued_for_deletion() and predicate.call(c):
			out.append(c)
	return out


# --- Server-side -------------------------------------------------------------------

func award_xp(killed: Creature) -> void:
	var amount := killed.species.xp_reward * killed.level
	for pet in get_all_pets():
		if not pet.fainted and pet.global_position.distance_to(killed.global_position) <= xp_share_range:
			pet.gain_xp(amount)


## First free party slot for a player, or -1 if the party is full.
func free_party_slot(peer_id: int) -> int:
	var used := get_pets(peer_id).map(func(p: Creature) -> int: return p.party_slot)
	for slot in Player.MAX_PARTY:
		if slot not in used:
			return slot
	return -1


## Recreates a pet from stable data next to `near`, in party slot `slot`.
func spawn_pet(peer_id: int, data: Dictionary, near: Vector3, slot: int) -> Creature:
	var offset := Vector2.from_angle(randf() * TAU) * 1.5
	return creature_spawner.spawn({
		"species": data.species, "level": data.level, "xp": data.xp,
		"owner": peer_id, "slot": slot, "pos": near + Vector3(offset.x, 0.0, offset.y),
	}) as Creature


## Sends a HUD message to one player.
func tell(peer_id: int, text: String, color: Color) -> void:
	announce.rpc_id(peer_id, text, color)


func _on_player_joined(peer_id: int, info: Dictionary) -> void:
	player_spawner.spawn({
		"id": peer_id, "name": info.name, "color": info.color, "pos": player_spawn_point(peer_id),
	})


func _on_player_left(peer_id: int) -> void:
	for pet in get_pets(peer_id):
		pet.queue_free()
	var player := get_player(peer_id)
	if player:
		player.queue_free()


func _spawn_wild_creature() -> void:
	for attempt in 12:
		var pos := Vector3(randf_range(-arena_half_size, arena_half_size), 0.0,
				randf_range(-arena_half_size, arena_half_size))
		if _is_blocked(pos):
			continue
		var level := 1 + int(Vector2(pos.x, pos.z).length() / level_band_width) + randi() % 2
		creature_spawner.spawn({"species": SpeciesDB.pick_random_index(), "level": level, "pos": pos})
		return


func _is_blocked(pos: Vector3) -> bool:
	for p in get_players():
		if p.global_position.distance_to(pos) < spawn_clearance:
			return true
	for obstacle: Node3D in get_tree().get_nodes_in_group("obstacles"):
		if Vector2(obstacle.global_position.x - pos.x, obstacle.global_position.z - pos.z).length() < 3.0:
			return true
	return false


# --- Spawn functions (run on every peer) --------------------------------------------

func _spawn_player(data: Dictionary) -> Node:
	var player: Player = player_scene.instantiate()
	player.name = str(data.id)
	player.peer_id = data.id
	player.display_name = data.name
	player.color = data.color
	player.position = data.pos
	return player


func _spawn_creature(data: Dictionary) -> Node:
	var creature: Creature = creature_scene.instantiate()
	creature.species_index = data.species
	creature.level = data.level
	creature.xp = data.get("xp", 0)
	creature.owner_id = data.get("owner", 0)
	creature.party_slot = data.get("slot", -1)
	creature.position = data.pos
	creature.home = data.pos
	return creature


# --- Local / broadcast presentation -----------------------------------------------

func on_local_player_spawned(player: Player) -> void:
	camera_rig.target = player
	camera_rig.global_position = player.global_position
	hud.bind(player)


@rpc("authority", "call_local", "reliable")
func announce(text: String, color: Color) -> void:
	hud.show_message(text, color)


@rpc("authority", "call_local", "unreliable")
func play_capture_fx(from: Vector3, to: Vector3, success: bool) -> void:
	var mat := _fx_material(Color(1, 1, 1, 0.9))
	var orb := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	orb.mesh = mesh
	orb.material_override = mat
	add_child(orb)
	orb.global_position = from
	var result_color := Color(0.4, 1.0, 0.5, 0.8) if success else Color(1.0, 0.35, 0.3, 0.8)
	var tween := orb.create_tween()
	tween.tween_property(orb, "global_position", to, 0.25)
	tween.tween_property(mat, "albedo_color", result_color, 0.05)
	tween.tween_property(orb, "scale", Vector3.ONE * 5.0, 0.3)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(orb.queue_free)


## Expanding ring that ends at `final_radius`.
@rpc("authority", "call_local", "unreliable")
func play_burst(at: Vector3, color: Color, final_radius: float) -> void:
	_ring_fx(at, color, final_radius)


## Jagged lightning bolts between consecutive points, with a flash at each hit.
@rpc("authority", "call_local", "unreliable")
func play_lightning(points: PackedVector3Array) -> void:
	var mat := _fx_material(Color(1.0, 1.0, 0.65, 1.0))
	var bolts: Array[Node3D] = []
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		if a.distance_to(b) < 0.05:
			continue
		var side := (b - a).cross(Vector3.UP).normalized()
		var path: Array[Vector3] = [a]
		for k in range(1, 4):
			path.append(a.lerp(b, k / 4.0) + side * randf_range(-0.35, 0.35) + Vector3.UP * randf_range(-0.15, 0.15))
		path.append(b)
		for k in path.size() - 1:
			bolts.append(_bolt_segment(path[k], path[k + 1], mat))
	for i in range(1, points.size()):  # points[0] is the caster
		_ring_fx(points[i] - Vector3.UP * 0.55, Color(1.0, 1.0, 0.6), 1.0)
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	for bolt in bolts:
		tween.tween_callback(bolt.queue_free)


func _bolt_segment(a: Vector3, b: Vector3, mat: Material) -> MeshInstance3D:
	var bolt := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, a.distance_to(b) + 0.1)
	bolt.mesh = mesh
	bolt.material_override = mat
	add_child(bolt)
	bolt.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
	return bolt


## Local-only feedback ring (e.g. when issuing a pet command).
func ping(at: Vector3, color: Color) -> void:
	_ring_fx(at, color, 1.6)


func _ring_fx(at: Vector3, color: Color, final_radius: float) -> void:
	var mat := _fx_material(color)
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.8
	mesh.outer_radius = 1.0
	ring.mesh = mesh
	ring.material_override = mat
	add_child(ring)
	ring.global_position = at + Vector3.UP * 0.05
	ring.scale = Vector3.ONE * 0.3
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * final_radius, 0.35)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)


func _fx_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat
