class_name World
extends Node3D
## The shared game world. Spawned on every peer by Main's LevelSpawner.
##
## Each level is generated from a seed (see LevelGenerator): a start camp with
## the stable, a winding path full of wild creatures, and an arena with a rival
## tamer at the end. Only `level_state` (seed + number) is replicated; every peer
## builds the same geometry from it. The server spawns players, creatures and
## the rival, which the spawners replicate.

signal level_changed

## owner_id used for the rival's pet.
const RIVAL_ID := -1
## Direction the path runs in. 45° makes it run straight up the screen.
const PATH_YAW := PI / 4.0

@export var player_scene: PackedScene
@export var creature_scene: PackedScene
@export var rival_scene: PackedScene
@export var titan_scene: PackedScene
@export var wyrm_scene: PackedScene
@export var witch_scene: PackedScene
@export var crate_scene: PackedScene
@export var coin_scene: PackedScene
## Pets within this distance of a kill share the XP.
@export var xp_share_range := 25.0
## How close a player must be to the stable to use it.
@export var stable_range := 4.5
## How close a player must be to the lemonade stand to shop.
@export var shop_range := 4.5
## Stepping this close to the open portal starts the next level.
@export var exit_radius := 2.5
## XP every pet gets for defeating a rival (x level number).
@export var rival_defeat_xp := 40
## Players pick up coins within this distance.
@export var coin_pickup_radius := 1.4

## Replicated: x = seed, y = level number. Changing it rebuilds the level on every peer.
var level_state := Vector2i.ZERO:
	set(v):
		level_state = v
		if is_node_ready():
			_build_level()
## Replicated: true once the rival is defeated.
var exit_open := false:
	set(v):
		exit_open = v
		if is_node_ready():
			portal.visible = v

var layout := {}
var level_number: int:
	get:
		return level_state.y

var _advancing := false
## Server: active ground zones (Sandstorm, toxic puddles...). See add_zone().
var _zones: Array[Dictionary] = []
## Server: armed traps (Mud Trap) waiting for an enemy to step on them. See add_trap().
var _traps: Array[Dictionary] = []
var _next_trap_id := 0

@onready var level_root: Node3D = $Level
@onready var players_root: Node3D = $Players
@onready var creatures_root: Node3D = $Creatures
@onready var rivals_root: Node3D = $Rivals
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var creature_spawner: MultiplayerSpawner = $CreatureSpawner
@onready var rival_spawner: MultiplayerSpawner = $RivalSpawner
@onready var crates_root: Node3D = $Crates
@onready var coins_root: Node3D = $Coins
@onready var crate_spawner: MultiplayerSpawner = $CrateSpawner
@onready var coin_spawner: MultiplayerSpawner = $CoinSpawner
@onready var stable: Node3D = $Stable
@onready var portal: Node3D = $Portal
@onready var camera_rig: Node3D = $CameraRig
@onready var hud: HUD = $HUD


func _enter_tree() -> void:
	add_to_group("world")


func _ready() -> void:
	level_root.rotation.y = PATH_YAW
	player_spawner.spawn_function = _spawn_player
	creature_spawner.spawn_function = _spawn_creature
	rival_spawner.spawn_function = _spawn_rival
	crate_spawner.spawn_function = _spawn_crate
	coin_spawner.spawn_function = _spawn_coin
	portal.visible = exit_open
	if level_state != Vector2i.ZERO:
		_build_level()  # a client joining mid-game
	if not multiplayer.is_server():
		return
	Network.player_joined.connect(_on_player_joined)
	Network.player_left.connect(_on_player_left)
	_start_level(SaveGame.start_level())
	for id in Network.players:
		_on_player_joined(id, Network.players[id])


func _process(delta: float) -> void:
	if portal.visible:
		portal.rotate_y(delta * 1.5)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_collect_coins()
	_tick_zones(delta)
	_tick_traps(delta)
	if not exit_open or _advancing:
		return
	for p in get_players():
		if not p.downed and _flat_distance(p.global_position, exit_point()) < exit_radius:
			_advancing = true
			announce.rpc("%s stepped through the portal..." % p.display_name, p.color.lightened(0.3))
			get_tree().create_timer(1.0).timeout.connect(_start_level.bind(level_number + 1))
			return


# --- Lookups ---------------------------------------------------------------------

func get_player(peer_id: int) -> Player:
	return players_root.get_node_or_null(str(peer_id)) as Player


func get_players() -> Array[Player]:
	var out: Array[Player] = []
	for p: Player in players_root.get_children():
		if not p.is_queued_for_deletion():
			out.append(p)
	return out


func get_rival() -> Rival:
	for r: Rival in rivals_root.get_children():
		if not r.is_queued_for_deletion():
			return r
	return null


## The player or rival that owns pets with this owner id.
func get_tamer(owner_id: int) -> Node3D:
	return get_rival() if owner_id == RIVAL_ID else get_player(owner_id)


func get_creature(creature_name: String) -> Creature:
	return creatures_root.get_node_or_null(creature_name) as Creature


func get_wild_creatures() -> Array[Creature]:
	return _creatures_where(func(c: Creature) -> bool: return c.is_wild())


## Every player-owned pet.
func get_all_pets() -> Array[Creature]:
	return _creatures_where(func(c: Creature) -> bool: return c.is_player_pet())


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


## Everything on the hostile side: wild creatures, rivals and rival pets.
func get_hostiles() -> Array[Node3D]:
	var out: Array[Node3D] = []
	out.append_array(_creatures_where(func(c: Creature) -> bool: return not c.is_player_pet()))
	var rival := get_rival()
	if rival:
		out.append(rival)
	return out


## Every targetable enemy of `attacker` within `max_range` of `center` (no friendly fire).
func enemies_near(attacker: Node3D, center: Vector3, max_range: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var candidates: Array[Node3D] = []
	candidates.append_array(get_players())
	candidates.append_array(_creatures_where(func(_c: Creature) -> bool: return true))
	var rival := get_rival()
	if rival:
		candidates.append(rival)
	for node in candidates:
		if not Combat.are_enemies(attacker, node) or not node.is_targetable():
			continue
		if _flat_distance(node.global_position, center) <= max_range + node.radius():
			out.append(node)
	return out


## Every targetable ally of `caster` (same side, including itself) within `max_range` of `center`.
func allies_near(caster: Node3D, center: Vector3, max_range: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var candidates: Array[Node3D] = []
	candidates.append_array(get_players())
	candidates.append_array(_creatures_where(func(_c: Creature) -> bool: return true))
	var rival := get_rival()
	if rival:
		candidates.append(rival)
	for node in candidates:
		if Combat.are_enemies(caster, node) or not node.is_targetable():
			continue
		if _flat_distance(node.global_position, center) <= max_range + node.radius():
			out.append(node)
	return out


## The biome of the current level (see BiomeDB).
func biome() -> Dictionary:
	return BiomeDB.BIOMES[layout.get("biome", 0)]


## "Rival Kael" or "the Glacier Titan", for objective text.
func boss_objective_name() -> String:
	var boss := get_rival()
	if boss:
		return boss.objective_name()
	return biome().get("boss_name", "Rival %s" % layout.get("rival_name", ""))


func nearest_enemy(attacker: Node3D, point: Vector3, max_range: float) -> Creature:
	var best: Creature = null
	var best_dist := INF
	for node in enemies_near(attacker, point, max_range):
		var d := node.global_position.distance_to(point)
		if node is Creature and d < best_dist:
			best = node
			best_dist = d
	return best


## Crates whose edge is within `max_range` of `center`.
func crates_near(center: Vector3, max_range: float) -> Array[Crate]:
	var out: Array[Crate] = []
	for crate: Crate in crates_root.get_children():
		if not crate.is_queued_for_deletion() and _flat_distance(crate.global_position, center) <= max_range + crate.radius():
			out.append(crate)
	return out


## The creature closest to `point` on the ground, if the point is on or near it.
func creature_near(point: Vector3, tolerance := 0.8) -> Creature:
	var best: Creature = null
	var best_dist := INF
	for c in _creatures_where(func(c: Creature) -> bool: return not c.fainted):
		var d := _flat_distance(c.global_position, point)
		if d < c.radius() + tolerance and d < best_dist:
			best = c
			best_dist = d
	return best


func is_near_stable(point: Vector3) -> bool:
	return _flat_distance(point, stable.global_position) <= stable_range


func shop_position() -> Vector3:
	return level_root.to_global(layout.shop_point) if not layout.is_empty() else Vector3.INF


func is_near_shop(point: Vector3) -> bool:
	return not layout.is_empty() and _flat_distance(point, shop_position()) <= shop_range


## Keeps a point on the walkable floor of the current level.
func clamp_to_level(point: Vector3) -> Vector3:
	if layout.is_empty():
		return point
	var clamped := LevelGenerator.clamp_to_floor(layout, level_root.to_local(point))
	var out := level_root.to_global(clamped)
	out.y = point.y
	return out


func exit_point() -> Vector3:
	return level_root.to_global(layout.exit_point) if not layout.is_empty() else Vector3.ZERO


## 0 at the start camp, 1 at the end of the arena.
func level_progress(point: Vector3) -> float:
	if layout.is_empty():
		return 0.0
	return clampf(-level_root.to_local(point).z / layout.total_length, 0.0, 1.0)


## Server only: spawn slots at the start camp follow join order so players never overlap.
func player_spawn_point(peer_id: int) -> Vector3:
	var slot := maxi(Network.players.keys().find(peer_id), 0)
	var offset := Vector3((slot - 1.5) * 1.6, 0.0, 0.0)
	return level_root.to_global(layout.start_point + offset)


## Server only: next to a teammate who is still standing, otherwise at the start camp.
func respawn_point(peer_id: int) -> Vector3:
	for p in get_players():
		if p.peer_id != peer_id and not p.downed:
			return clamp_to_level(p.global_position + Vector3(1.5, 0.0, 1.5))
	return player_spawn_point(peer_id)


func _creatures_where(predicate: Callable) -> Array[Creature]:
	var out: Array[Creature] = []
	for c: Creature in creatures_root.get_children():
		if not c.is_queued_for_deletion() and predicate.call(c):
			out.append(c)
	return out


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Level flow (server) -------------------------------------------------------------

func _start_level(number: int) -> void:
	_advancing = false
	for c in _creatures_where(func(c: Creature) -> bool: return not c.is_player_pet()):
		c.queue_free()
	_zones.clear()
	for trap in _traps:
		end_trap.rpc(trap.id, false)
	_traps.clear()
	for node in rivals_root.get_children() + crates_root.get_children() + coins_root.get_children():
		node.queue_free()
	exit_open = false
	level_state = Vector2i(randi_range(1, 2_000_000_000), number)  # rebuilds the level here and on clients

	for p in get_players():
		p.health.current = p.health.max_health
		p.potions = Player.MAX_POTIONS  # a fresh pair of potions every level
		p.downed = false
		p._respawn_at.rpc_id(p.peer_id, player_spawn_point(p.peer_id))
	for pet in get_all_pets():
		pet.global_position = player_spawn_point(pet.owner_id) + pet._follow_offset()
		pet.set_focus(null)

	var base_level := 1 + (number - 1) * 2
	var level_biome := biome()
	var spots: Array = layout.creature_spots
	for i in spots.size():
		var spot: Dictionary = spots[i]
		# The first two creatures by the camp are the biome's starter species (if it has one).
		var species: int = level_biome.starter_species if level_biome.has("starter_species") and i < 2 \
				else SpeciesDB.pick_random_index(level_biome.species)
		creature_spawner.spawn({
			"species": species,
			"level": base_level + int(spot.depth * 2.5) + randi() % 2,
			"pos": level_root.to_global(spot.pos),
		})
	for crate: Dictionary in layout.crate_spots:
		crate_spawner.spawn({"pos": level_root.to_global(crate.pos), "gold": crate.gold, "level": number})
	var boss_pos := level_root.to_global(layout.rival_point)
	rival_spawner.spawn({"type": level_biome.boss, "name": layout.rival_name, "level": number, "pos": boss_pos})
	if level_biome.boss == "rival":
		creature_spawner.spawn({
			"species": layout.rival_species, "level": base_level + 1,
			"owner": RIVAL_ID, "slot": 0, "pos": boss_pos + Vector3(1.5, 0.0, 1.5),
		})
	announce.rpc("Level %d, %s: follow the path and defeat %s!" % [number, level_biome.name, boss_objective_name()],
			Color(1, 0.9, 0.5))
	announce.rpc("A lemonade stand halfway along the path sells potions.", Color(1, 0.85, 0.35))


func on_rival_defeated(rival: Rival) -> void:
	var boss_name := rival.objective_name()
	announce.rpc("%s is defeated! A portal has opened at the end of the path." % (boss_name[0].to_upper() + boss_name.substr(1)),
			Color(1, 0.9, 0.5))
	play_burst.rpc(rival.global_position, rival.color, 4.0)
	for pet in _creatures_where(func(c: Creature) -> bool: return c.is_rival_pet()):
		pet.release_to_wild()
		announce.rpc("The rival's %s has gone wild. Capture it!" % pet.species.display_name, Color(0.6, 0.85, 1.0))
	for pet in get_all_pets():
		if not pet.fainted:
			pet.gain_xp(rival_defeat_xp * level_number)
	exit_open = true


## Server: a damaging area on the ground. Every 0.5s it hurts the enemies of
## `source` inside it (`dps` per second); `poison_dps` also poisons them.
## The zone ends early if its source is removed.
func add_zone(source: Node3D, at: Vector3, radius: float, duration: float, dps: float, color: Color,
		poison_dps := 0.0) -> void:
	_zones.append({
		"source": source, "pos": at, "radius": radius, "time_left": duration,
		"dps": dps, "poison_dps": poison_dps, "tick": 0.0,
	})
	play_zone.rpc(at, radius, duration, color)


func _tick_zones(delta: float) -> void:
	for zone in _zones.duplicate():
		zone.time_left -= delta
		zone.tick -= delta
		if zone.time_left <= 0.0 or not is_instance_valid(zone.source):
			_zones.erase(zone)
			continue
		if zone.tick > 0.0:
			continue
		zone.tick = 0.5
		for enemy in enemies_near(zone.source, zone.pos, zone.radius):
			enemy.receive_damage(zone.dps * 0.5, zone.source)
			if zone.poison_dps > 0.0 and enemy.has_method("poison"):
				enemy.poison(zone.poison_dps, 2.0)


## Server: a hidden-in-plain-sight trap on the ground at `at`. When an enemy of
## `source` comes within `trigger_radius`, `on_trigger` is called with the trap's
## position and the trap is used up. It disappears after `duration` seconds, or
## when its source is gone; a source keeps at most `max_traps` (oldest go first).
func add_trap(source: Node3D, at: Vector3, trigger_radius: float, duration: float, max_traps: int,
		on_trigger: Callable, color: Color) -> void:
	var own := _traps.filter(func(t: Dictionary) -> bool: return t.source == source)
	while own.size() >= max_traps:
		var oldest: Dictionary = own.pop_front()
		_traps.erase(oldest)
		end_trap.rpc(oldest.id, false)
	_next_trap_id += 1
	_traps.append({
		"id": _next_trap_id, "source": source, "pos": at, "radius": trigger_radius,
		"time_left": duration, "on_trigger": on_trigger,
	})
	play_trap.rpc(_next_trap_id, at, trigger_radius, color)


func _tick_traps(delta: float) -> void:
	for trap in _traps.duplicate():
		trap.time_left -= delta
		if trap.time_left <= 0.0 or not is_instance_valid(trap.source):
			_traps.erase(trap)
			end_trap.rpc(trap.id, false)
		elif not enemies_near(trap.source, trap.pos, trap.radius).is_empty():
			_traps.erase(trap)
			end_trap.rpc(trap.id, true)
			trap.on_trigger.call(trap.pos)


## Scatters coins worth `total` around `at` (from a smashed crate).
func spill_coins(at: Vector3, total: int) -> void:
	var count := clampi(total, 1, 6)
	for i in count:
		var value := total / count + (1 if i < total % count else 0)
		var offset := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / count + randf() * 0.5) * randf_range(0.8, 1.6)
		coin_spawner.spawn({"pos": clamp_to_level(at + offset), "value": value})


func _collect_coins() -> void:
	for coin: Coin in coins_root.get_children():
		if coin.is_queued_for_deletion():
			continue
		for p in get_players():
			if not p.downed and _flat_distance(p.global_position, coin.global_position) <= coin_pickup_radius:
				p.coins += coin.value
				coin.queue_free()
				break


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


## Sends a HUD message to one player (ignored for the rival).
func tell(peer_id: int, text: String, color: Color) -> void:
	if peer_id > 0:
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


# --- Level geometry (every peer) -------------------------------------------------------

func _build_level() -> void:
	layout = LevelGenerator.generate(level_state.x, level_state.y)
	for child in level_root.get_children():
		level_root.remove_child(child)
		child.queue_free()

	var level_biome := biome()
	var floor_mat := _material(layout.floor_tint)
	var camp_mat := _material(level_biome.camp)
	var arena_mat := _material(level_biome.arena)
	var wall_mat := _material(level_biome.wall)
	var rock_mat := _material(level_biome.rock)

	var segments: Array = layout.segments
	for i in segments.size():
		var seg: Dictionary = segments[i]
		var length: float = seg.z_start - seg.z_end
		var mid_z: float = (seg.z_start + seg.z_end) * 0.5
		var mat: Material = {"start": camp_mat, "arena": arena_mat}.get(seg.kind, floor_mat)
		_add_box(Vector3(seg.center_x, -0.5, mid_z), Vector3(seg.width, 1.0, length + 0.5), mat)
		for side in [-1.0, 1.0]:
			_add_box(Vector3(seg.center_x + side * (seg.width * 0.5 + 0.5), 1.0, mid_z),
					Vector3(1.0, 2.0, length), wall_mat)
		if i > 0:
			_add_join_walls(segments[i - 1], seg, wall_mat)
	var first: Dictionary = segments[0]
	var last: Dictionary = segments[-1]
	_add_box(Vector3(first.center_x, 1.0, first.z_start + 0.5), Vector3(first.width + 2.0, 2.0, 1.0), wall_mat)
	_add_box(Vector3(last.center_x, 1.0, last.z_end - 0.5), Vector3(last.width + 2.0, 2.0, 1.0), wall_mat)

	for rock: Dictionary in layout.rocks:
		var body := _add_box(rock.pos + Vector3.UP * rock.size.y * 0.5, rock.size, rock_mat)
		body.add_to_group("obstacles")

	_build_shop()
	stable.global_position = level_root.to_global(layout.stable_point)
	stable.rotation.y = PATH_YAW + PI / 2.0
	portal.global_position = level_root.to_global(layout.exit_point)
	level_changed.emit()


## The lemonade stand halfway along the path: counter, striped awning, potion
## bottles and the vendor. Its front faces the middle of the path.
func _build_shop() -> void:
	var shop := Node3D.new()
	shop.name = "LemonadeStand"
	level_root.add_child(shop)
	shop.position = layout.shop_point
	shop.rotation.y = layout.shop_side * PI / 2.0

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.9, 2.0, 2.6)
	shape.shape = box
	shape.position = Vector3(0.0, 1.0, 0.7)
	body.add_child(shape)
	shop.add_child(body)

	var wood := _material(Color(0.62, 0.42, 0.24))
	var light_wood := _material(Color(0.82, 0.66, 0.42))
	_add_mesh(shop, Vector3(0.0, 0.5, 0.0), Vector3(2.6, 1.0, 0.8), wood)
	_add_mesh(shop, Vector3(0.0, 1.04, 0.0), Vector3(2.9, 0.08, 1.0), light_wood)
	for post in [Vector2(-1.35, -0.45), Vector2(1.35, -0.45), Vector2(-1.35, 1.7), Vector2(1.35, 1.7)]:
		_add_mesh(shop, Vector3(post.x, 1.35, post.y), Vector3(0.12, 2.7, 0.12), wood)
	var yellow := _material(Color(1.0, 0.85, 0.2))
	var white := _material(Color(0.97, 0.95, 0.88))
	for i in 6:
		_add_mesh(shop, Vector3(-1.25 + i * 0.5, 2.72, 0.62), Vector3(0.5, 0.08, 2.6), yellow if i % 2 == 0 else white)
	var potion_mat := _material(Color(0.95, 0.25, 0.35))
	potion_mat.emission_enabled = true
	potion_mat.emission = Color(0.5, 0.05, 0.1)
	for x in [-0.8, -0.4, 0.4, 0.8]:
		var bottle := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.06
		cylinder.bottom_radius = 0.1
		cylinder.height = 0.3
		cylinder.material = potion_mat
		bottle.mesh = cylinder
		bottle.position = Vector3(x, 1.23, -0.1)
		shop.add_child(bottle)
	var lemon_mat := _material(Color(1.0, 0.9, 0.15))
	var lemon := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.22
	sphere.material = lemon_mat
	lemon.mesh = sphere
	lemon.position = Vector3(0.0, 1.18, -0.15)
	shop.add_child(lemon)

	# The vendor behind the counter.
	var vendor := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	capsule.material = _material(Color(0.95, 0.75, 0.55))
	vendor.mesh = capsule
	vendor.position = Vector3(0.0, 0.85, 0.85)
	shop.add_child(vendor)
	_add_mesh(shop, Vector3(0.0, 0.95, 0.5), Vector3(0.6, 0.8, 0.05), yellow)  # apron
	var hat := MeshInstance3D.new()
	var brim := CylinderMesh.new()
	brim.top_radius = 0.42
	brim.bottom_radius = 0.42
	brim.height = 0.05
	brim.material = yellow
	hat.mesh = brim
	hat.position = Vector3(0.0, 1.72, 0.85)
	shop.add_child(hat)

	var sign := Label3D.new()
	sign.text = "Lemonade Stand\nPotions"
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.pixel_size = 0.011
	sign.font_size = 44
	sign.outline_size = 12
	sign.modulate = Color(1.0, 0.9, 0.4)
	sign.position = Vector3(0.0, 3.5, 0.6)
	shop.add_child(sign)


func _add_mesh(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mesh.mesh = box
	mesh.position = pos
	parent.add_child(mesh)
	return mesh


## Closes the gaps where two path segments of different width/offset meet.
func _add_join_walls(prev: Dictionary, next: Dictionary, mat: Material) -> void:
	var z: float = next.z_start
	for side in [-1.0, 1.0]:
		var a: float = prev.center_x + side * prev.width * 0.5
		var b: float = next.center_x + side * next.width * 0.5
		var lo := minf(a, b) - (1.0 if side < 0.0 else 0.0)
		var hi := maxf(a, b) + (1.0 if side > 0.0 else 0.0)
		if hi - lo > 0.05:
			_add_box(Vector3((lo + hi) * 0.5, 1.0, z), Vector3(hi - lo, 2.0, 1.0), mat)


func _add_box(local_pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = mat
	mesh.mesh = box_mesh
	body.add_child(mesh)
	body.position = local_pos
	level_root.add_child(body)
	return body


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


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


## Spawns the level's boss: a rival tamer or the Glacier Titan (both are Rivals).
func _spawn_crate(data: Dictionary) -> Node:
	var crate: Crate = crate_scene.instantiate()
	crate.position = data.pos
	crate.gold = data.gold
	crate.level_number = data.level
	return crate


func _spawn_coin(data: Dictionary) -> Node:
	var coin: Coin = coin_scene.instantiate()
	coin.position = data.pos
	coin.value = data.value
	return coin


func _spawn_rival(data: Dictionary) -> Node:
	var scene: PackedScene = {
		"titan": titan_scene, "wyrm": wyrm_scene, "witch": witch_scene,
	}.get(data.get("type", "rival"), rival_scene)
	var rival: Rival = scene.instantiate()
	rival.display_name = data.name
	rival.level_number = data.level
	rival.position = data.pos
	rival.home = data.pos
	return rival


# --- Local / broadcast presentation -----------------------------------------------

func on_local_player_spawned(player: Player) -> void:
	camera_rig.target = player
	camera_rig.global_position = player.global_position
	hud.bind(player)
	SaveGame.on_local_player_spawned(player, self)


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


## A short beam between two points (e.g. a heal).
@rpc("authority", "call_local", "unreliable")
func play_beam(from: Vector3, to: Vector3, color: Color) -> void:
	var mat := _fx_material(color)
	var beam := _bolt_segment(from, to, mat)
	var tween := beam.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(beam.queue_free)


## A pulsing coloured disc on the ground for `duration` seconds (a damage zone).
@rpc("authority", "call_local", "reliable")
func play_zone(at: Vector3, radius: float, duration: float, color: Color) -> void:
	var mat := _fx_material(Color(color, 0.4))
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.05
	disc.mesh = mesh
	disc.material_override = mat
	add_child(disc)
	disc.global_position = at + Vector3.UP * 0.07
	var pulse := disc.create_tween().set_loops(maxi(ceili(duration / 0.8), 1))
	pulse.tween_property(mat, "albedo_color:a", 0.6, 0.4)
	pulse.tween_property(mat, "albedo_color:a", 0.3, 0.4)
	get_tree().create_timer(duration).timeout.connect(disc.queue_free)


## A trap on the ground: a dark disc with a lighter rim and a few lumps.
@rpc("authority", "call_local", "reliable")
func play_trap(id: int, at: Vector3, radius: float, color: Color) -> void:
	var trap := Node3D.new()
	trap.name = "Trap%d" % id
	add_child(trap)
	trap.global_position = at + Vector3.UP * 0.05
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = radius
	rim_mesh.bottom_radius = radius
	rim_mesh.height = 0.04
	rim.mesh = rim_mesh
	rim.material_override = _fx_material(Color(color.lightened(0.25), 0.75))
	trap.add_child(rim)
	var pool := MeshInstance3D.new()
	var pool_mesh := CylinderMesh.new()
	pool_mesh.top_radius = radius * 0.8
	pool_mesh.bottom_radius = radius * 0.8
	pool_mesh.height = 0.06
	pool.mesh = pool_mesh
	pool.material_override = _fx_material(Color(color.darkened(0.35), 0.9))
	trap.add_child(pool)
	for i in 4:
		var lump := MeshInstance3D.new()
		var lump_mesh := SphereMesh.new()
		lump_mesh.radius = radius * 0.12
		lump_mesh.height = radius * 0.12
		lump.mesh = lump_mesh
		lump.material_override = pool.material_override
		lump.position = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 4.0 + 0.6) * radius * 0.45 + Vector3.UP * 0.04
		trap.add_child(lump)
	trap.scale = Vector3(0.2, 1.0, 0.2)
	trap.create_tween().tween_property(trap, "scale", Vector3.ONE, 0.25)


@rpc("authority", "call_local", "reliable")
func end_trap(id: int, sprung: bool) -> void:
	var trap := get_node_or_null("Trap%d" % id)
	if trap == null:
		return
	if sprung:
		trap.queue_free()
		return
	var tween := trap.create_tween()
	tween.tween_property(trap, "scale", Vector3(0.05, 1.0, 0.05), 0.3)
	tween.tween_callback(trap.queue_free)


## A red warning circle that fills up over `delay` seconds (boss attacks).
@rpc("authority", "call_local", "reliable")
func play_telegraph(at: Vector3, radius: float, delay: float) -> void:
	var mat := _fx_material(Color(1.0, 0.25, 0.2, 0.35))
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	disc.mesh = mesh
	disc.material_override = mat
	add_child(disc)
	disc.global_position = at + Vector3.UP * 0.06
	disc.scale = Vector3(0.15, 1.0, 0.15)
	var tween := disc.create_tween()
	tween.tween_property(disc, "scale", Vector3.ONE, delay)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.65, delay)
	tween.tween_callback(disc.queue_free)


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
