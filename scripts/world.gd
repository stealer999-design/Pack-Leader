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
const PATH_YAW := -PI / 4.0  ## The level runs left to right across the screen.
const LOW_WALL_HEIGHT := 0.5
## Obstacle scene names by biome (scenes/obstacles/<name>_<0..3>.tscn).
## Obstacle set per biome, unless the biome names one ("obstacles").
const OBSTACLE_BIOMES := ["meadow", "frost", "desert", "swamp", "graveyard"]
const OBSTACLES_PER_BIOME := 4

@export var player_scene: PackedScene
@export var creature_scene: PackedScene
@export var rival_scene: PackedScene
@export var titan_scene: PackedScene
@export var wyrm_scene: PackedScene
@export var witch_scene: PackedScene
@export var fish_scene: PackedScene
@export var act2_boss_scene: PackedScene  ## The Sand Pharaoh, Magma Colossus and Yeti King (Act2Boss variants).
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
## Creature levels per area (see area_levels).
const AREA_LEVELS := 5
## A pet this many levels above what it beats still gets full experience.
const OVERLEVEL_GRACE := 2
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

## Replicated (tile levels): where the dungeon's key lies (level-local), and
## the key's state: 0 = its Keeper still has it, 1 = dropped at key_pos,
## 2 = picked up, which opens the gate to the boss arena. key_pos is listed
## before key_state in the sync config, so it's there first.
var key_pos := Vector3.ZERO
var key_state := 0:
	set(v):
		key_state = v
		if is_node_ready():
			refresh_key()
var _door_ready := {}  ## Peer id -> when (msec) they can use a dungeon door again.

## Replicated: the furthest area anyone has reached in this game. The travel
## portal can take the party back to any area up to it.
var furthest_level := 0
## Replicated: the Act 1 biomes in the order the players chose them at the
## Crossroads (see BiomeDB.route). Listed before level_state in the sync config
## so clients have it before they build a level.
var route := PackedInt32Array():
	set(v):
		route = v
		BiomeDB.route = Array(v)
## Replicated: the furthest area whose boss has been beaten. A new Act 1 area
## can only be opened at the Crossroads once every chosen one is cleared.
var cleared_level := 0
## Colours of the Crossroads portals, by biome.
const HUB_COLORS := {0: Color(0.45, 0.9, 0.4), 1: Color(0.55, 0.85, 1.0), 2: Color(1.0, 0.75, 0.3), 3: Color(0.6, 0.8, 0.3)}
## The travel portal at the end of every level (next to the exit portal): it
## is always open, and stepping into it opens the travel window (see HUD).
var travel_portal: Node3D

var layout := {}
var level_number: int:
	get:
		return level_state.y

var _advancing := false
var _warming := false  ## A level is warming up behind its loading screen (see _warm_up).
## Server: active ground zones (Sandstorm, toxic puddles...). See add_zone().
var _zones: Array[Dictionary] = []
## Server: armed traps (Mud Trap) waiting for an enemy to step on them. See add_trap().
var _traps: Array[Dictionary] = []
var _star_mesh: ArrayMesh
var _obstacle_scenes := {}
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
@onready var loot_root: Node3D = $Loot
@onready var loot_spawner: MultiplayerSpawner = $LootSpawner
@onready var stable: Node3D = $Stable
@onready var portal: Node3D = $Portal
@onready var camera_rig: Node3D = $CameraRig
@onready var hud: HUD = $HUD


func _enter_tree() -> void:
	add_to_group("world")


## The browser build is much slower than the desktop one: one shadow cascade
## instead of four, drawn nearer (with project.godot's web-only overrides: no
## MSAA, 3D at 75% resolution), on a smaller shadow map with cheaper blur.
func _lighten_for_web() -> void:
	var sun: DirectionalLight3D = $Sun
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)


func _ready() -> void:
	level_root.rotation.y = PATH_YAW
	if OS.has_feature("web"):
		_lighten_for_web()
	_texture_stable()
	player_spawner.spawn_function = _spawn_player
	creature_spawner.spawn_function = _spawn_creature
	rival_spawner.spawn_function = _spawn_rival
	crate_spawner.spawn_function = _spawn_crate
	coin_spawner.spawn_function = _spawn_coin
	loot_spawner.spawn_function = _spawn_loot
	portal.visible = exit_open
	_build_travel_portal()
	if level_state != Vector2i.ZERO:
		_build_level()  # a client joining mid-game
	if not multiplayer.is_server():
		return
	Network.player_joined.connect(_on_player_joined)
	Network.player_left.connect(_on_player_left)
	furthest_level = SaveGame.furthest_level()
	route = SaveGame.route()
	cleared_level = SaveGame.cleared_level()
	_start_level(SaveGame.start_level())
	for id in Network.players:
		_on_player_joined(id, Network.players[id])


func _process(delta: float) -> void:
	if portal.visible:
		portal.rotate_y(delta * 1.5)
	if travel_portal.visible:
		travel_portal.rotate_y(-delta * 1.2)
	_update_darkness(delta)
	var key := level_root.get_node_or_null("KeyPickup") as Node3D
	if key and key.visible:
		var spin := key.get_node("Spin") as Node3D
		spin.rotate_y(delta * 2.0)
		spin.position.y = 1.2 + sin(Time.get_ticks_msec() / 400.0) * 0.12
	var hub := level_root.get_node_or_null("HubPortals")
	if hub:
		for p: Node3D in hub.get_children():
			p.get_node("Ring").rotate_y(delta * 1.3)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_collect_coins()
	_collect_loot()
	_tick_zones(delta)
	_tick_traps(delta)
	_check_checkpoints()
	_check_dungeon_doors()
	_collect_key()
	if is_crossroads() and not _advancing:
		_check_hub_portals()
	if not exit_open or _advancing:
		return
	for p in get_players():
		if not p.downed and _flat_distance(p.global_position, exit_point()) < exit_radius:
			_advancing = true
			get_tree().create_timer(1.0).timeout.connect(_start_level.bind(next_level()))
			return


## True at the Crossroads (level 0), the hub where Act 1 areas are chosen.
func is_crossroads() -> bool:
	return level_number <= BiomeDB.CROSSROADS and level_state != Vector2i.ZERO


## Where the exit portal leads: back to the Crossroads after an Act 1 area
## while some Act 1 areas haven't been chosen yet, otherwise the next area.
func next_level() -> int:
	if level_number >= 1 and level_number >= route.size() and route.size() < BiomeDB.ACTS[0].size():
		return BiomeDB.CROSSROADS
	return level_number + 1


## The Crossroads portal for an Act 1 biome: {state: "cleared" | "open" |
## "locked", level: the area number it leads to (0 if locked)}.
func hub_portal_state(biome_index: int) -> Dictionary:
	var at := Array(route).find(biome_index)
	if at >= 0:
		return {"state": "cleared" if at + 1 <= cleared_level else "open", "level": at + 1}
	if route.size() > maxi(cleared_level, 0):
		return {"state": "locked", "level": 0}
	return {"state": "new", "level": route.size() + 1}


## True once every Act 1 area has been cleared: the Crossroads then has a
## portal on to Act 2.
func act1_cleared() -> bool:
	return cleared_level >= BiomeDB.ACTS[0].size() and route.size() >= BiomeDB.ACTS[0].size()


## Server: a player walking into a Crossroads portal takes everyone to that area.
func _check_hub_portals() -> void:
	var points: Array = layout.get("hub_portals", [])
	for p in get_players():
		if p.downed:
			continue
		if act1_cleared() and layout.has("onward_point") \
				and _flat_distance(p.global_position, level_root.to_global(layout.onward_point)) < exit_radius:
			_advancing = true
			var first_act2 := BiomeDB.ACTS[0].size() + 1
			announce.rpc("%s leads the way on to %s..." % [p.display_name, area_name(first_act2)], Color(1.0, 0.55, 0.45))
			get_tree().create_timer(1.0).timeout.connect(_start_level.bind(first_act2))
			return
		for i in points.size():
			if _flat_distance(p.global_position, level_root.to_global(points[i])) >= exit_radius:
				continue
			var biome_index: int = BiomeDB.ACTS[0][i]
			var info := hub_portal_state(biome_index)
			var area: String = BiomeDB.BIOMES[biome_index].name
			if info.state == "locked":
				if Time.get_ticks_msec() >= int(p.get_meta("hub_told", 0)) and not route.is_empty():
					p.set_meta("hub_told", Time.get_ticks_msec() + 4000)
					var current: String = BiomeDB.BIOMES[route[route.size() - 1]].name
					p.notify("Sealed: beat %s first" % current, "warn", Color(1.0, 0.6, 0.5))
				continue
			if info.state == "new":
				var chosen := route.duplicate()
				chosen.append(biome_index)
				route = chosen
			_advancing = true
			announce.rpc("%s chose %s!" % [p.display_name, area], HUB_COLORS[biome_index])
			get_tree().create_timer(1.0).timeout.connect(_start_level.bind(int(info.level)))
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
	var champion := get_champion()
	if champion:
		return "the " + champion.title()
	if not BiomeDB.has_named_boss(level_number):
		return "the Champion"
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


## At the camp's stable, or the village's (both open the same stable).
func is_near_stable(point: Vector3) -> bool:
	if _flat_distance(point, stable.global_position) <= stable_range:
		return true
	var village_stable := level_root.get_node_or_null("Village/VillageStable") as Node3D
	return village_stable != null and _flat_distance(point, village_stable.global_position) <= stable_range


func shop_position() -> Vector3:
	return level_root.to_global(layout.shop_point) if not layout.is_empty() else Vector3.INF


## The stash chest in the village or town (see Player.stash).
func stash_position() -> Vector3:
	return level_root.to_global(layout.village.frame * layout.village.stash_point) \
			if not layout.is_empty() and layout.has("village") else Vector3.INF


func is_near_stash(point: Vector3) -> bool:
	return _flat_distance(point, stash_position()) <= shop_range


func breeder_position() -> Vector3:
	return level_root.to_global(layout.village.frame * layout.village.breeder_point) if not layout.is_empty() else Vector3.INF


func is_near_breeder(point: Vector3) -> bool:
	return not layout.is_empty() and _flat_distance(point, breeder_position()) <= shop_range


func bat_shop_position() -> Vector3:
	return level_root.to_global(layout.village.frame * layout.village.bat_shop_point) if not layout.is_empty() else Vector3.INF


func is_near_bat_shop(point: Vector3) -> bool:
	return not layout.is_empty() and _flat_distance(point, bat_shop_position()) <= shop_range


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


func travel_point() -> Vector3:
	return clamp_to_level(level_root.to_global(layout.travel_point)) if not layout.is_empty() else Vector3.INF


func is_near_travel_portal(point: Vector3) -> bool:
	return not layout.is_empty() and _flat_distance(point, travel_point()) < exit_radius


## A player picked an area in the travel window: everyone goes there (any area
## reached so far). Server.
@rpc("any_peer", "call_local", "reliable")
func request_travel(number: int) -> void:
	if not multiplayer.is_server() or _advancing:
		return
	var sender := multiplayer.get_remote_sender_id()
	var p := get_player(sender if sender != 0 else 1)
	if p == null or p.downed or not is_near_travel_portal(p.global_position):
		return
	if number < BiomeDB.CROSSROADS or number > furthest_level:
		return
	_advancing = true
	announce.rpc("%s opened the way to %s..." % [p.display_name, area_name(number)], Color(0.85, 0.65, 1.0))
	get_tree().create_timer(1.0).timeout.connect(_start_level.bind(number))


## A copy of the exit portal in violet, signed "Travel".
func _build_travel_portal() -> void:
	travel_portal = portal.duplicate() as Node3D
	travel_portal.name = "TravelPortal"
	travel_portal.visible = false
	add_child(travel_portal)
	var violet := StandardMaterial3D.new()
	violet.albedo_color = Color(0.7, 0.45, 1.0)
	violet.emission_enabled = true
	violet.emission = Color(0.55, 0.3, 0.95)
	violet.emission_energy_multiplier = 1.5
	for part in ["Ring", "Core"]:
		var mesh := travel_portal.get_node(part) as MeshInstance3D
		mesh.material_override = violet if part == "Ring" else _travel_core_material()
	(travel_portal.get_node("Glow") as OmniLight3D).light_color = Color(0.75, 0.55, 1.0)
	var label := travel_portal.get_node("Sign") as Label3D
	label.text = "Travel"
	label.modulate = Color(0.85, 0.7, 1.0)


func _travel_core_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.35, 1.0, 0.55)
	return mat


## 0 at the start camp, 1 at the end of the arena.
func level_progress(point: Vector3) -> float:
	if layout.is_empty():
		return 0.0
	return LevelGenerator.progress(layout, level_root.to_local(point))


## Server only: spawn slots at the start camp follow join order so players never overlap.
func player_spawn_point(peer_id: int) -> Vector3:
	var slot := maxi(Network.players.keys().find(peer_id), 0)
	var offset := Vector3((slot - 1.5) * 1.6, 0.0, 0.0)
	return level_root.to_global(layout.start_point + offset)


## Server only: next to a teammate who is still standing, otherwise at the start camp.
## Where a downed player gets back up: at the lemonade stand once they have
## reached it this level (the checkpoint), otherwise at the camp.
func respawn_point(peer_id: int) -> Vector3:
	var player := get_player(peer_id)
	if player and player.checkpoint:
		return checkpoint_point(peer_id)
	return player_spawn_point(peer_id)


## A spot in front of the lemonade stand, one per player so nobody stacks up.
func checkpoint_point(peer_id: int) -> Vector3:
	var stand := level_root.get_node_or_null("LemonadeStand") as Node3D
	if stand == null:
		return player_spawn_point(peer_id)
	var slot := maxi(Network.players.keys().find(peer_id), 0)
	return clamp_to_level(stand.to_global(Vector3((slot - 1.5) * 1.4, 0.0, -3.5)))


## Server: players reach the checkpoint by coming near the lemonade stand, or by
## getting past it anywhere across the path.
func _check_checkpoints() -> void:
	if layout.is_empty() or is_crossroads():
		return
	var stand_progress := level_progress(shop_position())
	var open: bool = layout.get("open", false)
	for p in get_players():
		var reached := _flat_distance(p.global_position, shop_position()) <= shop_range * 2.0
		if open:  # the stand is in the town: walking into town reaches it
			reached = reached or LevelGenerator.in_village(layout, level_root.to_local(p.global_position))
		else:
			reached = reached or level_progress(p.global_position) > stand_progress
		if reached and not p.checkpoint and not p.downed:
			p.checkpoint = true
			show_checkpoint.rpc_id(p.peer_id)
			p.notify("Checkpoint!", "flag", Color(0.5, 1.0, 0.55))


## Raises this player's checkpoint flag at the stand (each player sees their own).
@rpc("authority", "call_local", "reliable")
func show_checkpoint() -> void:
	var flag := level_root.get_node_or_null("LemonadeStand/CheckpointFlag") as Node3D
	if flag == null:
		return
	var cloth := flag.get_node("Cloth") as MeshInstance3D
	(cloth.material_override as StandardMaterial3D).albedo_color = Color(0.3, 0.85, 0.35)
	cloth.create_tween().tween_property(cloth, "position:y", 2.25, 0.8).set_trans(Tween.TRANS_BACK)


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
	if level_number > BiomeDB.CROSSROADS:  # bad-luck protection: count levels with no Rare find
		for p in get_players():
			p.rare_drought = 0 if p.found_rare_this_level else p.rare_drought + 1
			p.found_rare_this_level = false
	for c in _creatures_where(func(c: Creature) -> bool: return not c.is_player_pet()):
		c.queue_free()
	_zones.clear()
	for trap in _traps:
		end_trap.rpc(trap.id, false)
	_traps.clear()
	for node in rivals_root.get_children() + crates_root.get_children() + coins_root.get_children() \
			+ loot_root.get_children():
		node.queue_free()
	exit_open = false
	key_state = 0
	furthest_level = maxi(furthest_level, number)
	level_state = Vector2i(randi_range(1, 2_000_000_000), number)  # rebuilds the level here and on clients

	for p in get_players():
		p.health.current = p.health.max_health
		p.potions = Player.MAX_POTIONS  # a fresh pair of potions every level
		p.downed = false
		p.checkpoint = false
		p._respawn_at.rpc_id(p.peer_id, player_spawn_point(p.peer_id))
	for pet in get_all_pets():
		pet.global_position = player_spawn_point(pet.owner_id) + pet._follow_offset()
		pet.set_focus(null)
		if pet.has_meta("told_overlevelled"):
			pet.remove_meta("told_overlevelled")

	if number <= BiomeDB.CROSSROADS:
		return
	var levels := area_levels(number)
	var base_level := levels.x
	var level_biome := biome()
	var spots: Array = layout.creature_spots
	var pack_species := {}  ## Tile levels: each pack ("group") is all one kind.
	for i in spots.size():
		var spot: Dictionary = spots[i]
		# The first two creatures by the camp are the biome's starter species (if it has one).
		var species: int = level_biome.starter_species if level_biome.has("starter_species") and i < 2 \
				else SpeciesDB.pick_random_index(level_biome.species)
		var leader := false
		if spot.has("group"):
			if not pack_species.has(spot.group):
				pack_species[spot.group] = SpeciesDB.pick_random_index(level_biome.species)
				leader = true  # the first of each pack leads it (a better drop)
			species = pack_species[spot.group]
		creature_spawner.spawn({
			"species": species,
			# Weakest by the camp, strongest near the boss.
			"level": mini(base_level + int(spot.depth * 4.0) + randi() % 2, levels.y),
			"pos": level_root.to_global(spot.pos), "leader": leader,
		})
	for crate: Dictionary in layout.crate_spots:
		crate_spawner.spawn({"pos": level_root.to_global(crate.pos), "gold": crate.gold, "level": number})
	if has_dungeon():
		_spawn_dungeon(levels)
	var boss_pos := level_root.to_global(layout.rival_point)
	if not BiomeDB.has_named_boss(number):
		# The first two levels of Acts 2-5 end with a Champion instead of the named boss.
		creature_spawner.spawn({
			"species": _champion_species(number, level_biome), "level": levels.y + 2,
			"pos": boss_pos, "elite": true,
		})
		announce.rpc("%s: find and defeat %s!" % [level_biome.name, boss_objective_name()], Color(1, 0.9, 0.5))
		return
	rival_spawner.spawn({"type": level_biome.boss, "name": layout.rival_name, "level": number, "pos": boss_pos})
	if level_biome.boss == "rival":
		creature_spawner.spawn({
			"species": layout.rival_species, "level": levels.y,
			"skills": PetSkills.auto_ranks(levels.y), "owner": RIVAL_ID, "slot": 0, "pos": boss_pos + Vector3(1.5, 0.0, 1.5),
		})
	if layout.get("open", false):
		announce.rpc("%s: find and defeat %s!" % [level_biome.name, boss_objective_name()], Color(1, 0.9, 0.5))
	else:
		announce.rpc("%s: defeat %s!" % [level_biome.name, boss_objective_name()], Color(1, 0.9, 0.5))


## Server: the dungeon's packs (as tough as the deeper half of the map) and
## its Keeper, an elite of the area's top level, in the last room.
func _spawn_dungeon(levels: Vector2i) -> void:
	var d: Dictionary = layout.dungeon
	var kinds := {}
	for spot: Dictionary in d.spots:
		var leader: bool = not kinds.has(spot.group)
		if leader:
			kinds[spot.group] = SpeciesDB.pick_random_index(biome().species)
		creature_spawner.spawn({"species": kinds[spot.group], "level": mini(levels.x + 2 + randi() % 3, levels.y),
				"pos": level_root.to_global(spot.pos), "leader": leader})
	creature_spawner.spawn({"species": SpeciesDB.pick_random_index(biome().species), "level": levels.y,
			"pos": level_root.to_global(d.keeper), "keeper": true})


## Server: a dungeon's Keeper fell: it drops the key (and some loot).
func on_keeper_defeated(keeper: Creature) -> void:
	if not has_dungeon() or key_state != 0:
		return
	key_pos = level_root.to_local(keeper.global_position)
	key_pos.y = 0.0
	key_state = 1
	announce.rpc("The %s dropped the %s!" % [keeper.title(), dungeon_theme().key], Color(dungeon_theme().key_color))
	play_burst.rpc(keeper.global_position, dungeon_theme().key_color, 3.0)
	roll_loot(keeper.global_position, 1.0, -1, ItemDB.MAGIC, 2, 0.3, true)


## Server: whoever walks onto the dropped key picks it up for everyone: the gate opens.
func _collect_key() -> void:
	if key_state != 1:
		return
	var at := level_root.to_global(key_pos)
	for p in get_players():
		if not p.downed and _flat_distance(p.global_position, at) < 1.8:
			key_state = 2
			announce.rpc("%s took the %s: the gate to %s is open!" % [p.display_name, dungeon_theme().key, boss_objective_name()],
					Color(dungeon_theme().key_color))
			return


## Server: players walking into the dungeon's entrance go down into it (their
## pets with them), and up its stairs come back out in front of the entrance.
func _check_dungeon_doors() -> void:
	if not has_dungeon() or _advancing:
		return
	var d: Dictionary = layout.dungeon
	var now := Time.get_ticks_msec()
	for p in get_players():
		if p.downed or now < int(_door_ready.get(p.peer_id, 0)):
			continue
		var at := level_root.to_local(p.global_position)
		var to := Vector3.INF
		if Vector2(at.x - d.door.x, at.z - d.door.z).length() < 1.8:
			to = d.arrive
			if key_state == 0:
				tell(p.peer_id, "You enter %s. Find its Keeper and take the %s." % [dungeon_theme().place, dungeon_theme().key],
						Color(dungeon_theme().key_color))
		elif Vector2(at.x - d.exit.x, at.z - d.exit.z).length() < 1.8:
			to = d.back
		if to == Vector3.INF:
			continue
		_door_ready[p.peer_id] = now + 1500
		var dest := level_root.to_global(to)
		p._respawn_at.rpc_id(p.peer_id, dest)
		for pet in get_pets(p.peer_id):
			if not pet.fainted:
				pet.global_position = dest + pet._follow_offset()
				pet.target = null
				pet.set_focus(null)


## Shows the key (dropped or not) and opens or closes the gate (every peer).
func refresh_key() -> void:
	var key := level_root.get_node_or_null("KeyPickup") as Node3D
	if key:
		key.visible = key_state == 1
		key.position = key_pos
	var gate := level_root.get_node_or_null("BossGate") as Node3D
	if gate == null:
		return
	var open := key_state == 2
	(gate.get_node("LockSign") as Label3D).visible = not open
	var shape := gate.get_node("Block").get_child(0) as CollisionShape3D
	shape.set_deferred("disabled", open)
	var bars := gate.get_node("Bars") as Node3D
	var target_y := -3.7 if open else 0.0
	if not is_equal_approx(bars.position.y, target_y):
		var tween := create_tween()
		tween.tween_property(bars, "position:y", target_y, 1.4 if open else 0.01).set_trans(Tween.TRANS_SINE)


## Which monster is the Champion of this level: the biome's "champions" list
## (by area within the act), else a random monster of the biome.
func _champion_species(number: int, level_biome: Dictionary) -> int:
	var picks: Array = level_biome.get("champions", [])
	var area: int = BiomeDB.act_of(number).area - 1
	if area >= 0 and area < picks.size():
		return picks[area]
	return SpeciesDB.pick_random_index(level_biome.species)


## The level's Champion (a giant elite monster), if it has one and it's alive.
func get_champion() -> Creature:
	for c: Creature in get_tree().get_nodes_in_group("creatures"):
		if c.elite and is_instance_valid(c) and not c.is_queued_for_deletion() and not c.health.is_dead():
			return c
	return null


## Server: the Champion guarding this level fell: like beating a boss.
func on_champion_defeated(champion: Creature) -> void:
	announce.rpc("The %s is defeated! A portal has opened." % champion.title(), Color(1, 0.9, 0.5))
	play_burst.rpc(champion.global_position, champion.species.color, 4.0)
	# Champions: 2 items, the first at least Magic, 40% of the time Rare.
	roll_loot(champion.global_position, 1.0, -1, ItemDB.MAGIC, 2, 0.4, true)
	cleared_level = maxi(cleared_level, level_number)
	for p in get_players():
		_give_team_xp(p, roundi(rival_defeat_xp * area_levels(level_number).y / 2.0), area_levels(level_number).y)
	exit_open = true


func on_rival_defeated(rival: Rival) -> void:
	var boss_name := rival.objective_name()
	announce.rpc("%s is defeated! A portal has opened at the end of the path." % (boss_name[0].to_upper() + boss_name.substr(1)),
			Color(1, 0.9, 0.5))
	play_burst.rpc(rival.global_position, rival.color, 4.0)
	# Named bosses: 3 items, the first Rare (10% Unique or Set; Magic in Act 1).
	roll_loot(rival.global_position, 1.0, -1, ItemDB.RARE, 3, 0.0, true, 0.1)
	for pet in _creatures_where(func(c: Creature) -> bool: return c.is_rival_pet()):
		pet.release_to_wild()
		announce.rpc("The rival's %s has gone wild. Capture it!" % pet.species.display_name, Color(0.6, 0.85, 1.0))
	cleared_level = maxi(cleared_level, level_number)
	# About a level's worth for a pet at the top of the area, for every living
	# pet in every tamer's party and reserve (not the stable).
	for p in get_players():
		_give_team_xp(p, roundi(rival_defeat_xp * area_levels(level_number).y / 2.0), area_levels(level_number).y)
	exit_open = true


## Server: a damaging area on the ground. Every 0.5s it hurts the enemies of
## `source` inside it (`dps` per second); `poison_dps` also poisons them.
## The zone ends early if its source is removed. A colour with alpha 0 draws
## nothing (the caller has its own effect, like Cyclone's whirlwind).
func add_zone(source: Node3D, at: Vector3, radius: float, duration: float, dps: float, color: Color,
		poison_dps := 0.0, heal_fraction := 0.0) -> void:
	_zones.append({
		"source": source, "pos": at, "radius": radius, "time_left": duration,
		"dps": dps, "poison_dps": poison_dps, "heal": heal_fraction, "tick": 0.0,
	})
	if color.a > 0.0:
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
		if zone.heal > 0.0:  # a holy zone also heals its source's side (fraction of max health per second)
			var healed := PackedVector3Array()
			for ally in allies_near(zone.source, zone.pos, zone.radius):
				ally.health.heal(ally.health.max_health * zone.heal * 0.5)
				healed.append(ally.global_position)
			zone["beat"] = not zone.get("beat", false)
			if zone["beat"] and not healed.is_empty():  # (a plus sign once a second, not every tick)
				play_heal_marks.rpc(healed)
		if zone.dps <= 0.0 and zone.poison_dps <= 0.0:
			continue
		for enemy in enemies_near(zone.source, zone.pos, zone.radius):
			if zone.dps > 0.0:
				enemy.receive_damage(zone.dps * 0.5, zone.source)
			if zone.poison_dps > 0.0 and enemy.has_method("poison"):
				enemy.poison(zone.poison_dps, 2.0)


## Server: a hidden-in-plain-sight trap on the ground at `at`. When an enemy of
## `source` comes within `trigger_radius`, `on_trigger` is called with the trap's
## position and the trap is used up. It disappears after `duration` seconds, or
## when its source is gone; a source keeps at most `max_traps` (oldest go first).
func add_trap(source: Node3D, at: Vector3, trigger_radius: float, duration: float, max_traps: int,
		on_trigger: Callable, color: Color, look := "") -> void:
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
	play_trap.rpc(_next_trap_id, at, trigger_radius, color, look)


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


## Scatters coins worth `total` around `at` (from a smashed vase).
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
				p.coins += roundi(coin.value * (1.0 + ItemDB.total(p.equipment, "coin_find") / 100.0))
				coin.queue_free()
				break


## Server: loot at `at`, rolled separately for every player (personal loot:
## each sees and picks up only their own). Up to `count` items, each dropping
## with `chance`; the first is at least `min_rarity`, and Rare or better with
## `rare_chance`. `boss` = a boss or Champion: bad-luck protection makes its
## first item Rare after 3 levels without one. Item level = the creature's
## level (`ilvl`), or the area's top creature level. Act 1 drops nothing
## above Magic. Each player's magic find (gear) improves their own rolls.
func roll_loot(at: Vector3, chance: float, ilvl := -1, min_rarity := ItemDB.NORMAL, count := 1,
		rare_chance := 0.0, boss := false, unique_chance := 0.0) -> void:
	if ilvl <= 0:
		ilvl = area_levels(level_number).y
	var first_act: bool = BiomeDB.act_of(level_number).act == 1
	# Half the class items are made for the pets of this area (birds' gear in the peaks...).
	var local_class := SpeciesDB.get_species(biome().species[0]).pet_class()
	for p in get_players():
		for i in count:
			if randf() >= chance:
				continue
			var floor_rarity := min_rarity if i == 0 else ItemDB.NORMAL
			if i == 0 and randf() < rare_chance:
				floor_rarity = ItemDB.RARE
			if i == 0 and boss and p.rare_drought >= 3:
				floor_rarity = ItemDB.RARE
			var rarity := maxi(ItemDB.roll_rarity(null, p.magic_find()), floor_rarity)
			if first_act:
				rarity = mini(rarity, ItemDB.MAGIC)
			# Legendaries (item level 21 on) and, in the last act, set pieces: rolled
			# apart from the rest, better odds from bosses and Champions and with magic find.
			var find := 1.0 + p.magic_find() / 100.0
			var legendary_odds := (LegendaryDB.BOSS_LEGENDARY_CHANCE if boss else LegendaryDB.LEGENDARY_CHANCE) * find
			if i == 0:
				legendary_odds += unique_chance
			var item: Dictionary
			if LegendaryDB.sets_drop_in(level_number) and randf() < LegendaryDB.SET_CHANCE * find:
				var classes := get_pets(p.peer_id).map(func(c: Creature) -> String: return c.species.pet_class())
				item = ItemDB.make_set_piece(ilvl, null, "", classes)
			elif LegendaryDB.band_of(ilvl) >= 0 and randf() < legendary_odds:
				item = ItemDB.make_legendary(ilvl)
			else:
				item = ItemDB.make_item(ilvl, null, local_class, ItemDB.NORMAL, rarity)
			if int(item.rarity) >= ItemDB.RARE:
				p.found_rare_this_level = true
				p.rare_drought = 0
			var spread := Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8)) if count > 1 else Vector3.ZERO
			loot_spawner.spawn({"pos": clamp_to_level(at + spread), "item": item, "owner": p.peer_id})


func _collect_loot() -> void:
	for loot: Loot in loot_root.get_children():
		if loot.is_queued_for_deletion():
			continue
		for p in get_players():
			if p.downed or _flat_distance(p.global_position, loot.global_position) > coin_pickup_radius:
				continue
			if loot.owner_id != 0 and loot.owner_id != p.peer_id:
				continue  # someone else's loot
			if p.add_item(loot.item):
				if ItemDB.is_standout(loot.item):
					announce.rpc("%s found %s, a %s item!" % [p.display_name, ItemDB.display_name(loot.item),
							ItemDB.RARITIES[int(loot.item.rarity)].name.to_lower()], ItemDB.rarity_color(loot.item))
				else:
					tell(p.peer_id, "You found a %s!  [I] inventory" % ItemDB.display_name(loot.item), ItemDB.rarity_color(loot.item))
				show_pickup.rpc(p.peer_id, loot.item)
				loot.queue_free()
				break
			elif p.get_meta("bag_full_told", -1000) < Time.get_ticks_msec() - 5000:
				p.set_meta("bag_full_told", Time.get_ticks_msec())
				tell(p.peer_id, "Your bag is full. Throw something away to pick this up.", Color(1, 0.8, 0.5))


func _spawn_loot(data: Dictionary) -> Node:
	var loot := Loot.new()
	loot.position = data.pos
	loot.item = data.item
	loot.owner_id = data.get("owner", 0)
	return loot


## A wild creature died: every tamer who took part (they, or one of their
## pets, was within xp_share_range) gets its XP for every living pet in their
## party and their reserve, all alike. Pets in the stable don't level.
func award_xp(killed: Creature) -> void:
	var amount := killed.species.xp_reward * killed.level
	for p in get_players():
		var near := p.global_position.distance_to(killed.global_position) <= xp_share_range
		for pet in get_pets(p.peer_id):
			near = near or pet.global_position.distance_to(killed.global_position) <= xp_share_range
		if near:
			_give_team_xp(p, amount, killed.level)


## XP for a tamer's whole team: each living party pet, and each living reserve pet.
func _give_team_xp(p: Player, amount: int, foe_level: int) -> void:
	amount = roundi(amount * (1.0 + LegendaryDB.amount(p.legend_powers(), "mentor") / 100.0))
	for pet in get_pets(p.peer_id):
		if not pet.fainted:
			_give_xp(pet, amount, foe_level)
	var changed := false
	for data: Dictionary in p.reserve:
		if data.is_empty() or data.get("dead", false):
			continue
		var level := int(data.level)
		var gained := maxi(1, roundi(amount * xp_factor(level, foe_level))) if amount > 0 else 0
		var xp := int(data.get("xp", 0)) + gained
		var species := SpeciesDB.get_species(int(data.species))
		while xp >= Creature.xp_needed(level) and level < 99:
			xp -= Creature.xp_needed(level)
			level += 1
			p.notify("%s Lv %d (reserve)" % [species.display_name, level], "levelup", Color(1.0, 0.85, 0.35))
		data["level"] = level
		data["xp"] = xp
		changed = changed or gained > 0
	if changed:
		p._push_stable()


## Creature levels in each area: five per area, rising through the act (the
## first Act 1 area chosen 1-5, the second 6-10, the third 11-15, the fourth
## 16-20), and on into the next act. Returns (lowest, highest).
static func area_levels(number: int) -> Vector2i:
	var low := 1 + (maxi(number, 1) - 1) * AREA_LEVELS
	return Vector2i(low, low + AREA_LEVELS - 1)


## "Act 1 · Area 2" (see BiomeDB.ACTS).
static func area_title(number: int) -> String:
	if number <= BiomeDB.CROSSROADS:
		return "The Crossroads"
	var where := BiomeDB.act_of(number)
	return "Act %d  ·  Area %d" % [where.act, where.area]


## "Act 1 · Area 2, Frostfang Peaks" or "The Crossroads", for messages.
static func area_name(number: int) -> String:
	if number <= BiomeDB.CROSSROADS:
		return "the Crossroads"
	return "%s, %s" % [area_title(number).replace("  ", " "), BiomeDB.for_level(number).name]


## How much of its XP a pet gets for beating something of `foe_level`: all of
## it up to OVERLEVEL_GRACE levels above, then 20% less per extra level, down to
## a tenth (so taking a strong pet back to an easy area levels it slowly).
static func xp_factor(pet_level: int, foe_level: int) -> float:
	var over := pet_level - foe_level - OVERLEVEL_GRACE
	return clampf(1.0 - 0.2 * over, 0.1, 1.0) if over > 0 else 1.0


func _give_xp(pet: Creature, amount: int, foe_level: int) -> void:
	var factor := xp_factor(pet.level, foe_level)
	if factor < 1.0 and not pet.has_meta("told_overlevelled"):
		pet.set_meta("told_overlevelled", true)  # once per pet per area
		popup(pet, "Over-levelled: less XP", "down", Color(0.85, 0.85, 0.7), pet.owner_id)
	pet.gain_xp(maxi(1, roundi(amount * factor)) if amount > 0 else 0)


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
		"species": data.species, "level": data.level, "xp": data.xp, "skills": data.get("skills", []),
		"collar": data.get("collar", {}), "owner": peer_id, "slot": slot, "pos": near + Vector3(offset.x, 0.0, offset.y),
		"dead": data.get("dead", false), "health": data.get("health", 1.0), "name": data.get("name", ""),
	}) as Creature


## Server: a small floating badge (an icon and a few words) over `target` (a
## pet, a creature or a tamer), where the player is already looking: seen by
## `peer_id` only, or by everyone (0). Nothing for the rival (negative ids).
func popup(target: Node3D, text: String, icon: String, color: Color, peer_id := 0) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree() or peer_id < 0:
		return
	var path := get_path_to(target)
	if peer_id > 0:
		show_popup.rpc_id(peer_id, path, text, icon, color)
	else:
		show_popup.rpc(path, text, icon, color)


## The badge: pops up over its target's head, rises and fades. Several at
## once stack upwards.
@rpc("authority", "call_local", "reliable")
func show_popup(path: NodePath, text: String, icon: String, color: Color) -> void:
	var target := get_node_or_null(path) as Node3D
	if target == null:
		return
	var height := 2.7
	if target is Creature:
		height = (target as Creature).overhead.position.y + 0.75
	var stacked := target.get_children().filter(func(c: Node) -> bool: return c.has_meta("popup")).size()
	var badge := Node3D.new()
	badge.set_meta("popup", true)
	badge.position = Vector3.UP * (height + stacked * 0.95)
	target.add_child(badge)
	var sprite := Sprite3D.new()
	sprite.texture = UiIcons.texture(icon, 64)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.render_priority = 10
	sprite.pixel_size = 0.009
	sprite.modulate = color
	sprite.position = Vector3(0, 0.32, 0)
	badge.add_child(sprite)
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 11
	label.pixel_size = 0.009
	label.font_size = 40
	label.outline_size = 12
	label.modulate = color.lightened(0.25)
	label.position = Vector3(0, -0.12, 0)
	badge.add_child(label)
	badge.scale = Vector3.ONE * 0.3
	var tween := badge.create_tween().set_parallel()
	tween.tween_property(badge, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge, "position:y", badge.position.y + 1.1, 2.2).set_delay(0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5).set_delay(1.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(1.8)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.5).set_delay(1.8)
	tween.chain().tween_callback(badge.queue_free)


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
	# Textured ground, by biome: grass, snow, sand or swamp on the path, trampled
	# dirt at the camp, stone slabs in the boss arena.
	var floor_mat := GroundTextures.material(GroundTextures.BIOME_STYLES[layout.biome], layout.floor_tint)
	var camp_mat := GroundTextures.material("dirt", level_biome.camp)
	var arena_mat := GroundTextures.material("flagstone", level_biome.arena)
	var wall_mat := _material(level_biome.wall)

	if layout.get("open", false):
		_build_open(floor_mat, camp_mat, arena_mat, wall_mat)
	else:
		_build_path(floor_mat, camp_mat, arena_mat, wall_mat)

	# Obstacles: copies of the biome's four premade trees and rocks, each turned
	# and sized differently. Picked from the level seed, so every peer agrees.
	var rng := RandomNumberGenerator.new()
	rng.seed = level_state.x
	for rock: Dictionary in layout.rocks:
		var obstacle := _obstacle_scene(layout.biome, rng.randi() % OBSTACLES_PER_BIOME).instantiate() as Node3D
		obstacle.position = rock.pos
		obstacle.rotation.y = rng.randf() * TAU
		var footprint: float = (rock.size.x + rock.size.z) * 0.5
		obstacle.scale = Vector3.ONE * clampf(footprint / 2.0, 0.9, 1.5)
		obstacle.add_to_group("obstacles")
		level_root.add_child(obstacle)

	_build_shop()
	# The village is built in path space, then set on its straight stretch.
	var before := level_root.get_child_count()
	_build_village(level_biome, wall_mat)
	var village_root := Node3D.new()
	village_root.name = "Village"
	village_root.transform = layout.village.frame
	var built := level_root.get_children().slice(before)
	level_root.add_child(village_root)
	for node in built:
		level_root.remove_child(node)
		village_root.add_child(node)
	stable.global_position = level_root.to_global(layout.stable_point)
	stable.rotation.y = PATH_YAW + PI / 2.0
	portal.global_position = level_root.to_global(layout.exit_point)
	(portal.get_node("Sign") as Label3D).text = "Crossroads" if next_level() == BiomeDB.CROSSROADS else "Next level"
	travel_portal.global_position = travel_point()
	travel_portal.visible = true
	if is_crossroads():
		_build_hub_portals()
	ModelLook.apply(level_root)  # walls, buildings, fences, obstacles: realistic surfaces
	ModelLook.apply(stable)
	refresh_key()
	level_changed.emit()
	_warm_up()


## Behind a short loading screen, shows the camera everything this level can
## show, once: every effect (bolts, arrows, spells, bursts, zones, loot, coins,
## pickups...), and the whole level at once (every creature, the boss, every
## building and obstacle), and loads every sound and icon. The GPU compiles
## each kind of material the first time it draws it, which would otherwise be
## a little freeze the first time each one appears in play.
func _warm_up() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or DisplayServer.get_name() == "headless" or _warming:
		return
	_warming = true
	var overlay := CanvasLayer.new()
	overlay.layer = 120
	add_child(overlay)
	var curtain := ColorRect.new()
	curtain.color = Color(0.04, 0.045, 0.06)
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(curtain)
	var label := Label.new()
	label.text = "Loading %s..." % (area_name(level_number) if level_number > BiomeDB.CROSSROADS else "the Crossroads")
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.modulate = Color(0.95, 0.9, 0.75)
	curtain.add_child(label)
	SoundFX.muted = true
	SoundFX.preload_all()
	UiIcons.preload_all()
	await get_tree().process_frame

	# One of every effect, just in front of the camera.
	var forward := -cam.global_basis.z
	var p := cam.global_position + forward * 20.0
	var side := cam.global_basis.x
	var color := Color(1.0, 0.5, 0.3)
	play_bolt(p, p + side * 2.0, color, 0.5)
	play_arrow(p, p + side * 2.0, color, 0.5)
	play_spell("orb", p, p + side * 2.0, color, 0.5)
	play_spell("meteor", p + Vector3.UP * 3.0, p, color, 0.5)
	play_spell("lightning", p, p, color, 0.05)
	play_lightning(PackedVector3Array([p, p + side, p + side * 2.0]))
	play_burst(p, color, 2.0)
	play_shatter(p, color)
	play_capture_fx(p, p + side * 2.0, true)
	play_capture_fx(p, p + side * 2.0, false)
	play_heart(p)
	play_bonk(p)
	play_vortex(p, 2.0, 0.5, color)
	play_kiss(p, p + side * 2.0)
	play_cast(p, color)
	play_beam(p, p + side * 2.0, color)
	play_zone(p, 2.0, 0.5, color)
	play_trap(-99, p, 2.0, color)
	play_telegraph(p, 2.0, 0.4)
	var samples: Array[Node3D] = []
	for item in [ItemDB.make("jacket", 1, ItemDB.NORMAL), ItemDB.make("ring", 30, ItemDB.RARE)]:
		var sack := Loot.new()
		sack.item = item
		sack.position = p
		add_child(sack)
		samples.append(sack)
	var coin: Node3D = coin_scene.instantiate()
	coin.position = p + side
	add_child(coin)
	samples.append(coin)
	var me := get_player(multiplayer.get_unique_id())
	if me:
		samples.append(me.play_pickup(ItemDB.make("hat", 1, ItemDB.MAGIC)))
		me._play_swing_fx()

	# The whole level at once: pull the camera far back and wide for a few
	# frames (creatures spawned by the server arrive during them).
	var rig := get_node("CameraRig")
	rig.set_process(false)
	var old := [cam.size, cam.far, cam.position]
	cam.position = cam.position + Vector3(0, 0, 500.0)
	cam.far = 2000.0
	cam.size = 450.0
	for i in 3:
		await get_tree().create_timer(0.2).timeout
	cam.size = old[0]
	cam.far = old[1]
	cam.position = old[2]
	rig.set_process(true)
	end_trap(-99, false)
	for sample in samples:
		if is_instance_valid(sample):
			sample.queue_free()
	await get_tree().create_timer(0.35).timeout  # let the sample effects finish under the curtain
	SoundFX.muted = false
	overlay.queue_free()
	_warming = false


## The Crossroads portals: a copy of the exit portal for each Act 1 biome, in
## its colour, signed with its name, its pets and the creature levels it would
## have (or "Cleared", or sealed while the current area's boss still stands).
func _build_hub_portals() -> void:
	var root := Node3D.new()
	root.name = "HubPortals"
	level_root.add_child(root)
	if act1_cleared() and layout.has("onward_point"):
		# The way on to Act 2, in red, beside the Travel portal.
		var onward := portal.duplicate() as Node3D
		onward.name = "Onward"
		onward.visible = true
		root.add_child(onward)
		onward.global_position = level_root.to_global(layout.onward_point)
		var red := Color(1.0, 0.4, 0.3)
		var ring := _material(red)
		ring.emission_enabled = true
		ring.emission = red * 0.8
		ring.emission_energy_multiplier = 1.6
		(onward.get_node("Ring") as MeshInstance3D).material_override = ring
		var core := StandardMaterial3D.new()
		core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		core.albedo_color = Color(red, 0.5)
		(onward.get_node("Core") as MeshInstance3D).material_override = core
		(onward.get_node("Glow") as OmniLight3D).light_color = red
		var first_act2 := BiomeDB.ACTS[0].size() + 1
		var label := onward.get_node("Sign") as Label3D
		label.text = "On to Act 2\n%s\nLv %d-%d" % [BiomeDB.for_level(first_act2).name, area_levels(first_act2).x, area_levels(first_act2).y]
		label.modulate = red.lightened(0.35)
	var points: Array = layout.get("hub_portals", [])
	for i in points.size():
		var biome_index: int = BiomeDB.ACTS[0][i]
		var info := hub_portal_state(biome_index)
		var color: Color = HUB_COLORS.get(biome_index, Color.WHITE)
		if info.state == "locked":
			color = Color(0.45, 0.45, 0.5)
		var hub_portal := portal.duplicate() as Node3D
		hub_portal.name = "Hub%d" % i
		hub_portal.visible = true
		root.add_child(hub_portal)
		hub_portal.global_position = level_root.to_global(points[i])
		hub_portal.rotation.y = 0.0
		var ring := _material(color)
		ring.emission_enabled = info.state != "locked"
		ring.emission = color * 0.8
		ring.emission_energy_multiplier = 1.4
		(hub_portal.get_node("Ring") as MeshInstance3D).material_override = ring
		var core := StandardMaterial3D.new()
		core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		core.albedo_color = Color(color, 0.5 if info.state != "locked" else 0.2)
		(hub_portal.get_node("Core") as MeshInstance3D).material_override = core
		(hub_portal.get_node("Glow") as OmniLight3D).light_color = color
		(hub_portal.get_node("Glow") as OmniLight3D).visible = info.state != "locked"
		var biome_data: Dictionary = BiomeDB.BIOMES[biome_index]
		var status := ""
		match info.state:
			"cleared":
				status = "Cleared  ·  Lv %d-%d" % [area_levels(info.level).x, area_levels(info.level).y]
			"open":
				status = "Lv %d-%d" % [area_levels(info.level).x, area_levels(info.level).y]
			"new":
				status = "Lv %d-%d" % [area_levels(info.level).x, area_levels(info.level).y]
			"locked":
				status = "Sealed"
		var label := hub_portal.get_node("Sign") as Label3D
		label.text = "%s\n%s\n%s" % [biome_data.name, BiomeDB.PET_TEXT.get(biome_index, ""), status]
		label.modulate = color.lightened(0.35)


## The lemonade stand halfway along the path: counter, striped awning, potion
## bottles and the vendor. Its front faces the middle of the path.
func _build_shop() -> void:
	var shop := _build_stall("LemonadeStand", layout.shop_point, layout.shop_side * PI / 2.0 + layout.shop_yaw,
			Color(1.0, 0.85, 0.2), "Lemonade Stand\nPotions", Color(1.0, 0.9, 0.4))
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

	# The checkpoint flag beside the stand: grey until this player reaches it.
	var flag := Node3D.new()
	flag.name = "CheckpointFlag"
	flag.position = Vector3(2.1, 0.0, -0.5)
	shop.add_child(flag)
	_add_mesh(flag, Vector3(0.0, 1.4, 0.0), Vector3(0.08, 2.8, 0.08), _material(Color(0.62, 0.42, 0.24)))
	var cloth := MeshInstance3D.new()
	cloth.name = "Cloth"
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(0.9, 0.55, 0.04)
	cloth.mesh = cloth_mesh
	cloth.material_override = _material(Color(0.6, 0.6, 0.6))
	cloth.position = Vector3(0.47, 1.2, 0.0)  # low: raised when reached
	flag.add_child(cloth)


## The premade obstacle scenes (scripts/tools/build_obstacles.gd), loaded once.
func _obstacle_scene(biome_index: int, variant: int) -> PackedScene:
	var obstacle_set: String = BiomeDB.BIOMES[biome_index].get("obstacles",
			OBSTACLE_BIOMES[biome_index % OBSTACLE_BIOMES.size()])
	var path := "res://scenes/obstacles/%s_%d.tscn" % [obstacle_set, variant]
	if not _obstacle_scenes.has(path):
		_obstacle_scenes[path] = load(path)
	return _obstacle_scenes[path]


## The stable building in the scene: shared building textures and a door handle.
## Its door faces south (towards the camera) once placed. The village's stable
## is a copy, so it matches.
func _texture_stable() -> void:
	(stable.get_node("Walls") as CSGBox3D).material = BuildingTextures.wall()
	(stable.get_node("Roof") as CSGCylinder3D).material = BuildingTextures.roof()
	var door := stable.get_node("Door") as CSGBox3D
	door.material = BuildingTextures.door()
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	sphere.material = _material(Color(0.95, 0.78, 0.35))
	knob.mesh = sphere
	knob.position = door.position + Vector3(0.32, 0.0, 0.06)
	stable.add_child(knob)


## The village off the middle of the path: a side path up to a square with a few
## houses and the bat shop. A safe place: no creatures are placed there.
func _build_village(level_biome: Dictionary, wall_mat: Material) -> void:
	var v: Dictionary = layout.village
	var plaza: Rect2 = v.plaza
	var half := LevelGenerator.VILLAGE_PATH_WIDTH * 0.5
	var path_len: float = v.wall_x - v.path_end_x
	var cobbles := GroundTextures.material("cobble", Color(level_biome.camp).lerp(Color(0.5, 0.47, 0.43), 0.6))
	if layout.get("open", false):
		_build_town_square(v, cobbles)
	else:
		_build_village_walls(v, cobbles, wall_mat)
	_build_village_contents(v)


## The path levels' village: a side path through a doorway in the path's far
## wall, up to a walled square.
func _build_village_walls(v: Dictionary, cobbles: Material, wall_mat: Material) -> void:
	var plaza: Rect2 = v.plaza
	var half := LevelGenerator.VILLAGE_PATH_WIDTH * 0.5
	var path_len: float = v.wall_x - v.path_end_x
	# Floors: the side path (reaching into the doorway) and the square.
	_add_box(Vector3(v.path_end_x + path_len * 0.5 + 0.5, -0.5, v.z), Vector3(path_len + 1.0, 1.0, half * 2.0),
			GroundTextures.material(GroundTextures.BIOME_STYLES[layout.biome], layout.floor_tint))
	_add_box(Vector3(plaza.get_center().x, -0.5, plaza.get_center().y), Vector3(plaza.size.x, 1.0, plaza.size.y), cobbles)
	# Side path walls.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(v.path_end_x + path_len * 0.5, 1.0, v.z + side * (half + 0.5)), Vector3(path_len, 2.0, 1.0), wall_mat)
	# Square walls: tall at the back and sides; low on the camera's side, with a gap for the path.
	_add_wall_z(plaza.position.x - 0.5, plaza.end.y + 1.0, plaza.position.y - 1.0, wall_mat)
	for z in [plaza.position.y - 0.5, plaza.end.y + 0.5]:
		_add_box(Vector3(plaza.get_center().x, 1.0, z), Vector3(plaza.size.x + 2.0, 2.0, 1.0), wall_mat)
	_add_wall_z(plaza.end.x + 0.5, plaza.end.y + 1.0, v.z + half, wall_mat, true)
	_add_wall_z(plaza.end.x + 0.5, v.z - half, plaza.position.y - 1.0, wall_mat, true)


## The houses, the village stable, the bat shop, the breeder and the sign:
## the same in both kinds of village.
func _build_village_contents(v: Dictionary) -> void:
	# Houses: plaster walls, a shingled roof, and a plank door and a window on
	# the south side (local +x), facing the camera.
	var roof_mat := BuildingTextures.roof()
	var house_mat := BuildingTextures.wall()
	var door_mat := BuildingTextures.door()
	var glass := _material(Color(0.55, 0.75, 0.95))
	var frame_mat := _material(Color(0.36, 0.23, 0.13))
	for house in v.houses:
		var size: Vector3 = house.size
		var body := _add_box(house.pos + Vector3.UP * size.y * 0.5, size, house_mat)
		body.add_to_group("obstacles")
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(size.x + 0.6, 1.6, size.z + 0.6)
		prism.material = roof_mat
		roof.mesh = prism
		roof.position = house.pos + Vector3.UP * (size.y + 0.8)
		level_root.add_child(roof)
		var front_x: float = house.pos.x + size.x * 0.5
		_add_door(Vector3(front_x, 0.0, house.pos.z - 0.9), door_mat, frame_mat)
		_add_mesh(level_root, Vector3(front_x + 0.03, 1.9, house.pos.z + 1.2), Vector3(0.12, 0.95, 1.05), frame_mat)
		_add_mesh(level_root, Vector3(front_x + 0.09, 1.9, house.pos.z + 1.2), Vector3(0.04, 0.8, 0.9), glass)  # in front of the frame

	# A second stable, in the front corner of the square (a copy of the camp's).
	var village_stable := stable.duplicate() as Node3D
	village_stable.name = "VillageStable"
	level_root.add_child(village_stable)
	village_stable.position = v.stable_point
	village_stable.rotation = Vector3(0.0, PI / 2.0, 0.0)  # like the camp's, relative to the level

	# The bat shop: a stall at the back of the square, facing the way in.
	var shop := _build_stall("BatShop", v.bat_shop_point, -PI / 2.0, Color(0.75, 0.2, 0.2), "Bat Shop\nUpgrades",
			Color(1.0, 0.6, 0.5))
	var bat_wood := _material(Color(0.62, 0.4, 0.22))
	var spike_mat := _material(Color(0.75, 0.77, 0.8))
	for x in [-0.7, 0.6]:  # bats on the counter, one of them spiked
		var bat := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.07
		mesh.bottom_radius = 0.035
		mesh.height = 0.8
		mesh.material = bat_wood
		bat.mesh = mesh
		bat.position = Vector3(x, 1.14, -0.1)
		bat.rotation = Vector3(0.0, 0.3, PI / 2.0)
		shop.add_child(bat)
		if x > 0.0:
			for i in 4:
				var spike := MeshInstance3D.new()
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.03
				cone.height = 0.1
				cone.material = spike_mat
				spike.mesh = cone
				spike.position = Vector3(0.0, 0.25 - i * 0.07, 0.0) + Vector3.FORWARD.rotated(Vector3.UP, i * 1.6) * 0.07
				spike.rotation = Vector3(PI / 2.0, i * 1.6, 0.0)
				bat.add_child(spike)

	# The breeder: a pink stall facing into the square, with a hay pen beside it.
	var breeder := _build_stall("Breeder", v.breeder_point, PI, Color(0.95, 0.55, 0.7), "Breeder\nAll pets", Color(1.0, 0.7, 0.85))
	var fence_mat := _material(Color(0.55, 0.38, 0.22))
	var pen := Node3D.new()
	pen.position = Vector3(3.6, 0.0, 0.4)  # in the stall's frame: beside it
	breeder.add_child(pen)
	for x in [-1.3, 1.3]:
		_add_mesh(pen, Vector3(x, 0.45, 0.0), Vector3(0.1, 0.9, 2.6), fence_mat)
	for z in [-1.3, 1.3]:
		_add_mesh(pen, Vector3(0.0, 0.45, z), Vector3(2.6, 0.1, 0.1), fence_mat)
		_add_mesh(pen, Vector3(0.0, 0.75, z), Vector3(2.6, 0.1, 0.1), fence_mat)
	_add_mesh(pen, Vector3(0.0, 0.12, 0.0), Vector3(2.4, 0.24, 2.4), _material(Color(0.86, 0.71, 0.36)))  # hay
	var heart := Label3D.new()
	heart.text = "<3"
	heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heart.font_size = 40
	heart.outline_size = 10
	heart.modulate = Color(1.0, 0.5, 0.65)
	heart.position = Vector3(0.0, 1.4, 0.0)
	pen.add_child(heart)
	_build_stash_chest(v.stash_point)

	var sign := Label3D.new()
	sign.text = "Village"
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.pixel_size = 0.012
	sign.font_size = 44
	sign.outline_size = 12
	sign.modulate = Color(0.95, 0.9, 0.75)
	sign.position = Vector3(v.wall_x - 1.0, 3.2, v.z)
	if layout.get("open", false):
		sign.text = "Town"
		sign.position = Vector3(v.plaza.end.x + 1.0, 3.0, v.gates.south)  # over the south gate
	level_root.add_child(sign)


## An open level's town: a cobbled square inside a white picket fence, with a
## gate in its south side (towards the camera) and its west side (towards the camp).
func _build_town_square(v: Dictionary, cobbles: Material) -> void:
	var plaza: Rect2 = v.plaza
	# The cobbles sit a hair above the field so they don't flicker with it.
	var floor_mesh := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(plaza.size.x, 0.04, plaza.size.y)
	slab.material = cobbles
	floor_mesh.mesh = slab
	floor_mesh.position = Vector3(plaza.get_center().x, 0.0, plaza.get_center().y)
	level_root.add_child(floor_mesh)
	var gap := LevelGenerator.GATE_WIDTH * 0.5
	var south: float = v.gates.south
	var west: float = v.gates.west
	var x0 := plaza.position.x
	var x1 := plaza.end.x
	var z0 := plaza.position.y
	var z1 := plaza.end.y
	# Each run of fence: from -> to (in the town's frame).
	var runs := [
		[Vector3(x0, 0, z0), Vector3(x0, 0, z1)],  # north (far side)
		[Vector3(x1, 0, z0), Vector3(x1, 0, south - gap)],  # south, either side of the gate
		[Vector3(x1, 0, south + gap), Vector3(x1, 0, z1)],
		[Vector3(x0, 0, z0), Vector3(x1, 0, z0)],  # east (towards the arena)
		[Vector3(x0, 0, z1), Vector3(west - gap, 0, z1)],  # west, either side of the gate
		[Vector3(west + gap, 0, z1), Vector3(x1, 0, z1)],
	]
	var white := _material(Color(0.93, 0.91, 0.86))
	var picket := BoxMesh.new()
	picket.size = Vector3(0.14, 1.05, 0.07)
	picket.material = white
	var transforms: Array[Transform3D] = []
	for run in runs:
		var from: Vector3 = run[0]
		var to: Vector3 = run[1]
		var length := from.distance_to(to)
		if length < 0.3:
			continue
		var dir := (to - from) / length
		var yaw := atan2(dir.x, dir.z)
		# Solid (a thin wall the height of the fence), rails, posts and pickets.
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, 1.3, length)
		shape.shape = box
		body.add_child(shape)
		body.position = (from + to) * 0.5 + Vector3.UP * 0.65
		body.rotation.y = yaw
		level_root.add_child(body)
		for rail_y in [0.35, 0.8]:
			var rail := _add_mesh(level_root, (from + to) * 0.5 + Vector3.UP * rail_y, Vector3(0.06, 0.09, length), white)
			rail.rotation.y = yaw
		var posts := maxi(1, ceili(length / 2.5))
		for k in posts + 1:
			var at := from.lerp(to, float(k) / posts)
			var post := _add_mesh(level_root, at + Vector3.UP * 0.65, Vector3(0.16, 1.3, 0.16), white)
			post.rotation.y = yaw
		var count := int(length / 0.36)
		for k in count:
			var at := from.lerp(to, (k + 0.5) / count) + Vector3.UP * 0.55
			# A pointed look: every picket a touch taller in the middle of its span.
			transforms.append(Transform3D(Basis(Vector3.UP, yaw), at))
	var pickets := MultiMesh.new()
	pickets.transform_format = MultiMesh.TRANSFORM_3D
	pickets.mesh = picket
	pickets.instance_count = transforms.size()
	for k in transforms.size():
		pickets.set_instance_transform(k, transforms[k])
	var fence := MultiMeshInstance3D.new()
	fence.name = "PicketFence"
	fence.multimesh = pickets
	level_root.add_child(fence)
	# Gateposts: taller, with a little cap, either side of each gate.
	for gate_post in [Vector3(x1, 0, south - gap), Vector3(x1, 0, south + gap), Vector3(west - gap, 0, z1), Vector3(west + gap, 0, z1)]:
		_add_mesh(level_root, gate_post + Vector3.UP * 0.85, Vector3(0.24, 1.7, 0.24), white)
		_add_mesh(level_root, gate_post + Vector3.UP * 1.75, Vector3(0.34, 0.1, 0.34), _material(Color(0.6, 0.4, 0.25)))


## A plank door in a dark frame, with a brass handle, on a wall facing local +x
## (south, towards the camera); `at` is the bottom-centre of the wall face.
func _add_door(at: Vector3, door_mat: Material, frame_mat: Material) -> void:
	_add_mesh(level_root, at + Vector3(0.03, 0.95, 0.0), Vector3(0.1, 1.9, 1.2), frame_mat)
	_add_mesh(level_root, at + Vector3(0.07, 0.9, 0.0), Vector3(0.06, 1.8, 1.0), door_mat)
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	sphere.material = _material(Color(0.95, 0.78, 0.35))
	knob.mesh = sphere
	knob.position = at + Vector3(0.13, 0.9, 0.32)
	level_root.add_child(knob)


## A wall along z at local `x`, from `z_from` to `z_to`.
func _add_wall_z(x: float, z_from: float, z_to: float, mat: Material, low := false, height := 2.0) -> void:
	var length := absf(z_from - z_to)
	if length > 0.05:
		_add_box(Vector3(x, height * 0.5, (z_from + z_to) * 0.5), Vector3(1.0, height, length), mat, low)


## A market stall in level space at `point`, turned by `rot_y` (its counter faces
## local -Z): counter, posts, a striped awning in `stripe` and white, a vendor
## behind the counter and a sign. Returns it so the caller can add goods.
func _build_stall(stall_name: String, point: Vector3, rot_y: float, stripe: Color, sign_text: String,
		sign_color: Color) -> Node3D:
	var stall := Node3D.new()
	stall.name = stall_name
	level_root.add_child(stall)
	stall.position = point
	stall.rotation.y = rot_y

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.9, 2.0, 2.6)
	shape.shape = box
	shape.position = Vector3(0.0, 1.0, 0.7)
	body.add_child(shape)
	stall.add_child(body)

	var wood := BuildingTextures.door()
	var light_wood := _material(Color(0.82, 0.66, 0.42))
	_add_mesh(stall, Vector3(0.0, 0.5, 0.0), Vector3(2.6, 1.0, 0.8), wood)
	_add_mesh(stall, Vector3(0.0, 1.04, 0.0), Vector3(2.9, 0.08, 1.0), light_wood)
	for post in [Vector2(-1.35, -0.45), Vector2(1.35, -0.45), Vector2(-1.35, 1.7), Vector2(1.35, 1.7)]:
		_add_mesh(stall, Vector3(post.x, 1.35, post.y), Vector3(0.12, 2.7, 0.12), wood)
	var stripe_mat := _material(stripe)
	var white := _material(Color(0.97, 0.95, 0.88))
	for i in 6:
		_add_mesh(stall, Vector3(-1.25 + i * 0.5, 2.72, 0.62), Vector3(0.5, 0.08, 2.6), stripe_mat if i % 2 == 0 else white)

	# The vendor behind the counter.
	var vendor := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	capsule.material = _material(Color(0.95, 0.75, 0.55))
	vendor.mesh = capsule
	vendor.position = Vector3(0.0, 0.85, 0.85)
	stall.add_child(vendor)
	_add_mesh(stall, Vector3(0.0, 0.95, 0.5), Vector3(0.6, 0.8, 0.05), stripe_mat)  # apron
	var hat := MeshInstance3D.new()
	var brim := CylinderMesh.new()
	brim.top_radius = 0.42
	brim.bottom_radius = 0.42
	brim.height = 0.05
	brim.material = stripe_mat
	hat.mesh = brim
	hat.position = Vector3(0.0, 1.72, 0.85)
	stall.add_child(hat)

	var sign := Label3D.new()
	sign.text = sign_text
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.pixel_size = 0.011
	sign.font_size = 44
	sign.outline_size = 12
	sign.modulate = sign_color
	sign.position = Vector3(0.0, 3.5, 0.6)
	stall.add_child(sign)
	return stall


## The stash: a big iron-bound wooden chest on the square, its lid open a crack
## with a warm glow inside, and a sign. F opens it (HUD.open_stash).
func _build_stash_chest(point: Vector3) -> void:
	var chest := Node3D.new()
	chest.name = "Stash"
	level_root.add_child(chest)
	chest.position = point
	chest.rotation.y = -PI / 2.0  # facing into the square
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.2, 1.2)
	shape.shape = box
	shape.position = Vector3(0.0, 0.6, 0.0)
	body.add_child(shape)
	chest.add_child(body)
	var wood := BuildingTextures.door()
	var iron := _material(Color(0.25, 0.25, 0.28))
	var gold := _material(Color(0.95, 0.78, 0.35))
	_add_mesh(chest, Vector3(0.0, 0.42, 0.0), Vector3(1.8, 0.84, 1.1), wood)
	var lid := Node3D.new()
	lid.position = Vector3(0.0, 0.84, 0.55)
	lid.rotation.x = 0.35  # open a crack
	chest.add_child(lid)
	_add_mesh(lid, Vector3(0.0, 0.12, -0.55), Vector3(1.84, 0.24, 1.14), wood)
	for x in [-0.7, 0.0, 0.7]:  # iron bands
		_add_mesh(chest, Vector3(x, 0.42, 0.0), Vector3(0.1, 0.86, 1.14), iron)
		_add_mesh(lid, Vector3(x, 0.12, -0.55), Vector3(0.1, 0.26, 1.18), iron)
	_add_mesh(chest, Vector3(0.0, 0.62, -0.57), Vector3(0.24, 0.3, 0.06), gold)  # the lock
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.45)
	glow.light_energy = 0.8
	glow.omni_range = 2.5
	glow.position = Vector3(0.0, 1.0, 0.0)
	chest.add_child(glow)
	var sign := Label3D.new()
	sign.text = "Stash"
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.pixel_size = 0.01
	sign.font_size = 40
	sign.outline_size = 10
	sign.modulate = Color(1.0, 0.85, 0.5)
	sign.position = Vector3(0.0, 1.9, 0.0)
	chest.add_child(sign)


func _add_mesh(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mesh.mesh = box
	mesh.position = pos
	parent.add_child(mesh)
	return mesh


## The winding path: a floor ribbon (camp dirt, the biome's ground, arena
## flagstones) and a wall along each edge, following the bent centre line, with
## a doorway in the far wall into the village and walls across both ends.
func _build_path(floor_mat: Material, camp_mat: Material, arena_mat: Material, wall_mat: StandardMaterial3D) -> void:
	var total: float = layout.total_length
	var camp_end := LevelGenerator.START_LENGTH
	var arena_start := total - LevelGenerator.ARENA_LENGTH
	_add_floor_ribbon(0.0, camp_end, camp_mat)
	_add_floor_ribbon(camp_end, arena_start, floor_mat)
	_add_floor_ribbon(arena_start, total, arena_mat)
	wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var door_half := LevelGenerator.VILLAGE_PATH_WIDTH * 0.5
	var door_s: float = layout.village.s
	_add_wall_strip(-1.0, 0.0, door_s - door_half, wall_mat)
	_add_wall_strip(-1.0, door_s + door_half, total, wall_mat)
	_add_wall_strip(1.0, 0.0, total, wall_mat, true)
	for end in [[0.0, 0.5], [total, -0.5]]:
		var at := LevelGenerator.map_point(layout, Vector3(0.0, 1.0, -end[0] + end[1]))
		var cap := _add_box(at, Vector3(LevelGenerator.half_width(layout, end[0]) * 2.0 + 2.0, 2.0, 1.0), wall_mat)
		cap.rotation.y = LevelGenerator.heading_at(layout, end[0])


## A tile level (Act 2 on): each tile's floor, a wall along every side where
## it isn't joined to the next tile (low on the camera's side, so it never
## hides anyone), knee-high ruins, trampled dirt at the camp and the boss
## arena off the boss tile's right side.
func _build_open(floor_mat: Material, camp_mat: Material, arena_mat: Material, wall_mat: StandardMaterial3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dungeon_rooms: Array[SurfaceTool] = []  # the dungeon's floors, a room each
	for cell: Dictionary in layout.cells:
		var r: Rect2 = cell.rect
		var closed: Dictionary = cell.closed
		# Tucked under the walls on closed sides; edge to edge with the next tile on open ones.
		var lo := Vector2(r.position.x - (0.6 if closed.n else 0.0), r.position.y - (0.6 if closed.e else 0.0))
		var hi := Vector2(r.end.x + (0.6 if closed.s else 0.0), r.end.y + (0.6 if closed.w else 0.0))
		if cell.get("grid", "") == "dungeon":
			# Each dungeon room's floor is its own mesh, so only the lights near
			# it count against a renderer's lights-per-mesh limit (the glows round
			# the party, the braziers).
			var room := SurfaceTool.new()
			room.begin(Mesh.PRIMITIVE_TRIANGLES)
			_up_quad(room, Vector3(lo.x, 0, lo.y), Vector3(hi.x, 0, lo.y), Vector3(hi.x, 0, hi.y), Vector3(lo.x, 0, hi.y))
			dungeon_rooms.append(room)
		else:
			_up_quad(st, Vector3(lo.x, 0, lo.y), Vector3(hi.x, 0, lo.y), Vector3(hi.x, 0, hi.y), Vector3(lo.x, 0, hi.y))
	var floor_mesh := st.commit()
	floor_mesh.surface_set_material(0, floor_mat)
	_add_solid(floor_mesh, floor_mesh)
	var theme := dungeon_theme()
	if layout.has("dungeon"):
		var dungeon_floor_mat := _dungeon_floor_material(theme)
		for room in dungeon_rooms:
			var room_floor := room.commit()
			room_floor.surface_set_material(0, dungeon_floor_mat)
			_add_solid(room_floor, room_floor)
	var dungeon_wall := _dungeon_wall_material(theme)
	# The camp patch, just above the floor (no collision of its own).
	_add_disc(layout.camp_center, LevelGenerator.CAMP_RADIUS, camp_mat)
	_build_boss_arena(floor_mat, arena_mat, wall_mat)
	wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var corridor: Rect2 = layout.corridor_rect
	for cell: Dictionary in layout.cells:
		var r: Rect2 = cell.rect
		var under_ground: bool = cell.get("grid", "") == "dungeon"
		var mat: Material = dungeon_wall if under_ground else wall_mat
		var high := DUNGEON_WALL_HEIGHT if under_ground else 2.0
		# A theme with wall models (DungeonBuilder) draws its far and side walls
		# with them: the walls here are then solid but not drawn.
		var modelled: bool = under_ground and theme.has("models")
		for side: String in LevelGenerator.SIDES:
			if not cell.closed[side]:
				continue
			var neighbour: bool = layout.cell_index.has(cell.cell + LevelGenerator.SIDES[side])
			# A wall between two tiles is built once, from its s or w tile.
			if neighbour and (side == "n" or side == "e"):
				continue
			match side:
				"s":  # towards the camera: always low (between two modelled rooms, the models show it)
					_add_wall_z(r.end.x, r.end.y + WALL_OVERLAP, r.position.y - WALL_OVERLAP,
							null if modelled and neighbour else mat, true, high)
				"n":
					_add_wall_z(r.position.x, r.end.y + WALL_OVERLAP, r.position.y - WALL_OVERLAP, null if modelled else mat, false, high)
				"w":
					_add_wall_x(r.end.y, r.position.x - WALL_OVERLAP, r.end.x + WALL_OVERLAP, null if modelled else mat, false, high)
				"e":
					if cell.kind == "boss":  # the doorway into the corridor to the boss
						_add_wall_x(r.position.y, r.position.x - WALL_OVERLAP, corridor.position.x - 0.5, mat)
						_add_wall_x(r.position.y, corridor.end.x + 0.5, r.end.x + WALL_OVERLAP, mat)
					else:
						_add_wall_x(r.position.y, r.position.x - WALL_OVERLAP, r.end.x + WALL_OVERLAP,
								null if modelled and not neighbour else (null if modelled else mat), false, high)
	# Ruins: broken stubs of stone wall, a run of blocks of uneven height.
	var ruin_mat := GroundTextures.material("cobble", Color(biome().rock).lerp(Color(0.6, 0.57, 0.52), 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = level_state.x ^ 0x2b1
	if layout.has("dungeon"):
		DungeonBuilder.build(self, layout, theme, DungeonDB.theme_id(layout.biome), dungeon_wall)
	for stub: Rect2 in layout.ruins:
		var along_x := stub.size.x > stub.size.y
		var length := maxf(stub.size.x, stub.size.y)
		var blocks := maxi(roundi(length / 2.2), 2)
		for k in blocks:
			var t := (k + 0.5) / blocks
			var height := rng.randf_range(0.5, 1.5) if k % 2 == 0 else rng.randf_range(0.35, 1.0)
			var center := Vector3(lerpf(stub.position.x, stub.end.x, t) if along_x else stub.get_center().x, height * 0.5,
					stub.get_center().y if along_x else lerpf(stub.position.y, stub.end.y, t))
			var block := length / blocks - 0.08
			var size := Vector3(block if along_x else 1.0, height, 1.0 if along_x else block)
			_add_box(center + Vector3(rng.randf_range(-0.1, 0.1), 0.0, rng.randf_range(-0.1, 0.1)), size, ruin_mat)


const WALL_OVERLAP := 0.5  ## Walls run this far past a tile's corner, so corners close.
const DUNGEON_WALL_HEIGHT := 3.2


## The dungeon walls' material, by theme (carved ice glows faintly).
func _dungeon_wall_material(theme: Dictionary) -> StandardMaterial3D:
	if theme.has("wall_texture"):
		return DungeonBuilder.textured(theme.wall_texture, theme.wall_tile)
	var mat := _material(theme.wall)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if DungeonDB.theme_id(layout.get("biome", 0)) == "ice":
		mat.roughness = 0.15
		mat.metallic_specular = 0.9
		if not theme.has("models"):  # (with wall models, only the low camera-side walls use it: unlit)
			mat.emission_enabled = true
			mat.emission = Color(theme.wall).darkened(0.55)
	return mat


## The dungeon floor's material: a theme's own texture (the ice halls' ice),
## else a ground style in its floor colour.
func _dungeon_floor_material(theme: Dictionary) -> Material:
	if not theme.has("floor_texture"):
		return GroundTextures.material(theme.floor_style, theme.floor)
	var base: String = theme.floor_texture
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(base + "color.png")
	mat.normal_enabled = true
	mat.normal_texture = load(base + "normal.png")
	if theme.has("floor_roughness"):  # a matte floor: one roughness all over, little shine
		mat.roughness = float(theme.floor_roughness)
		mat.metallic_specular = 0.25
	else:
		mat.roughness_texture = load(base + "roughness.png")
		mat.roughness = 1.0
		mat.metallic_specular = 0.8
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / float(theme.get("floor_tile", 5.0))
	return mat


# --- Darkness underground (every peer, for its own player) ---------------------------
## Down in a dungeon the sun and the ambient light fade almost out, and a soft
## light glows round every tamer and pet: the light comes from you, your pets,
## the braziers and the fountain.
const DARK_SUN := 0.05
const DARK_AMBIENT := 0.06
const TAMER_GLOW := {"energy": 3.2, "range": 9.5, "color": Color(1.0, 0.92, 0.8)}
const PET_GLOW := {"energy": 1.8, "range": 5.5}
var _dark := 0.0
var _sun_energy := -1.0
var _ambient_energy := -1.0


func _update_darkness(delta: float) -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if sun == null or env_node == null:
		return
	if _sun_energy < 0.0:
		_sun_energy = sun.light_energy
		_ambient_energy = env_node.environment.ambient_light_energy
	var me := get_player(multiplayer.get_unique_id())
	var target := 1.0 if me and in_dungeon(me.global_position) else 0.0
	if is_equal_approx(_dark, target) and target == 0.0:
		return
	_dark = move_toward(_dark, target, delta * 1.6)
	sun.light_energy = lerpf(_sun_energy, DARK_SUN, _dark)
	env_node.environment.ambient_light_energy = lerpf(_ambient_energy, DARK_AMBIENT, _dark)
	for p in get_players():
		_glow(p, TAMER_GLOW.energy, TAMER_GLOW.range, TAMER_GLOW.color)
	for pet in get_all_pets():
		_glow(pet, PET_GLOW.energy, PET_GLOW.range, Color(pet.species.color).lerp(Color.WHITE, 0.55))


## A soft light round `who` (made the first time), as bright as it's dark.
func _glow(who: Node3D, energy: float, reach: float, color: Color) -> void:
	var light := who.get_node_or_null("DarkGlow") as OmniLight3D
	if light == null:
		light = OmniLight3D.new()
		light.name = "DarkGlow"
		light.position = Vector3(0.0, 2.2, 0.0)
		light.omni_range = reach
		light.omni_attenuation = 1.4
		light.light_color = color
		light.shadow_enabled = false
		who.add_child(light)
	light.light_energy = energy * _dark
	light.visible = _dark > 0.01


func dungeon_theme() -> Dictionary:
	return DungeonDB.theme(layout.get("biome", 0))


func has_dungeon() -> bool:
	return not layout.is_empty() and layout.has("dungeon")


## True if a point (global) is down in the level's dungeon.
func in_dungeon(point: Vector3) -> bool:
	return has_dungeon() and LevelGenerator.in_dungeon(layout, level_root.to_local(point))


## A tile level's boss arena: a walled box of flagstones off the boss tile's
## right side, joined to it by a walled corridor through a doorway in its wall.
## Walls facing the camera are low, like everywhere else.
func _build_boss_arena(floor_mat: Material, arena_mat: Material, wall_mat: Material) -> void:
	if not layout.has("arena_rect"):
		return
	var box: Rect2 = layout.arena_rect  # x across the screen, y = z (left to right)
	var corridor: Rect2 = layout.corridor_rect
	var mouth: Vector3 = layout.mouth
	# Floors (with collision): the arena, and the corridor out to the field's edge.
	_add_box(Vector3(box.get_center().x, -0.5, box.get_center().y), Vector3(box.size.x, 1.0, box.size.y), arena_mat)
	var corridor_end := mouth.z + 1.5  # tucked just under the field's floor
	var floor_len := corridor_end - box.end.y
	_add_box(Vector3(corridor.get_center().x, -0.501, box.end.y + floor_len * 0.5), Vector3(corridor.size.x, 1.0, floor_len), floor_mat)
	# The arena's walls: far side and both ends tall, the camera's side low, a
	# doorway on the left (corridor) side.
	var x0 := box.position.x
	var x1 := box.end.x
	var z0 := box.position.y
	var z1 := box.end.y
	_add_wall_z(x0 - 0.5, z1 + 1.0, z0 - 1.0, wall_mat)
	_add_wall_z(x1 + 0.5, z1 + 1.0, z0 - 1.0, wall_mat, true)
	_add_wall_x(z0 - 0.5, x0 - 1.0, x1 + 1.0, wall_mat)
	_add_wall_x(z1 + 0.5, x0 - 1.0, corridor.position.x - 1.0, wall_mat)
	_add_wall_x(z1 + 0.5, corridor.end.x + 1.0, x1 + 1.0, wall_mat, true)
	# The corridor's walls, from the arena to where they meet the field's wall.
	for side in [-1.0, 1.0]:
		var x: float = corridor.get_center().x + side * (corridor.size.x * 0.5 + 0.5)
		_add_wall_z(x, z1, mouth.z, wall_mat, side > 0.0)


## A wall along x at local `z`, from `x_from` to `x_to`.
func _add_wall_x(z: float, x_from: float, x_to: float, mat: Material, low := false, height := 2.0) -> void:
	var length := absf(x_to - x_from)
	if length > 0.05:
		_add_box(Vector3((x_from + x_to) * 0.5, height * 0.5, z), Vector3(length, height, 1.0), mat, low)


## A flat disc of `mat` on the ground (camp dirt, arena flagstones).
func _add_disc(at: Vector3, radius: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 40
	var lift := Vector3.UP * 0.02
	for i in steps:
		var a := at + lift + Vector3(cos(TAU * i / steps), 0.0, sin(TAU * i / steps)) * radius
		var b := at + lift + Vector3(cos(TAU * (i + 1) / steps), 0.0, sin(TAU * (i + 1) / steps)) * radius
		_up_quad(st, at + lift, a, b, at + lift)
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.mesh.surface_set_material(0, mat)
	level_root.add_child(mesh)


## Floor from `s_from` to `s_to` along the path: a ribbon at ground level with
## trimesh collision.
func _add_floor_ribbon(s_from: float, s_to: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := _ribbon_rows(s_from, s_to)
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		_up_quad(st, a[0], a[1], b[1], b[0])
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	_add_solid(mesh, mesh)


## A wall along one edge of the path (`side` -1 = the far edge, +1 = the
## camera's), 1 unit thick and 2 tall; a `low` one is drawn knee-high so it
## never hides anyone, but still blocks at full height.
func _add_wall_strip(side: float, s_from: float, s_to: float, mat: Material, low := false) -> void:
	if s_to - s_from < 0.5:
		return
	var visual := _wall_mesh(side, s_from, s_to, LOW_WALL_HEIGHT if low else 2.0, mat)
	var solid := visual if not low else _wall_mesh(side, s_from, s_to, 2.0, mat)
	_add_solid(visual, solid)


func _wall_mesh(side: float, s_from: float, s_to: float, height: float, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev := []
	var s := s_from
	while true:
		var half := LevelGenerator.half_width(layout, s)
		var inner := LevelGenerator.map_point(layout, Vector3(side * half, 0.0, -s))
		var outer := LevelGenerator.map_point(layout, Vector3(side * (half + 1.0), 0.0, -s))
		var row := [inner, outer, inner + Vector3.UP * height, outer + Vector3.UP * height]
		if not prev.is_empty():
			_quad(st, prev[0], row[0], row[2], prev[2])  # inner face
			_quad(st, prev[1], row[1], row[3], prev[3])  # outer face
			_quad(st, prev[2], row[2], row[3], prev[3])  # top
		prev = row
		if s >= s_to:
			break
		s = minf(s + 2.0, s_to)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## Rows of [left edge, right edge] points every 1.5 units from `s_from` to `s_to`.
func _ribbon_rows(s_from: float, s_to: float) -> Array:
	var rows := []
	var s := s_from
	while true:
		var half := LevelGenerator.half_width(layout, s) + 0.6  # tucked under the walls
		rows.append([LevelGenerator.map_point(layout, Vector3(-half, 0.0, -s)),
				LevelGenerator.map_point(layout, Vector3(half, 0.0, -s))])
		if s >= s_to:
			break
		s = minf(s + 1.5, s_to)
	return rows


## A quad facing up (wound so its front is seen from above), with up normals.
func _up_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for tri in [[a, b, c], [a, c, d]]:
		if (tri[1] - tri[0]).cross(tri[2] - tri[0]).y > 0.0:
			tri = [tri[0], tri[2], tri[1]]
		for v in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


## A static body in level space showing `visual`, solid where `solid` is.
func _add_solid(visual: ArrayMesh, solid: ArrayMesh) -> void:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = visual
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var trimesh := solid.create_trimesh_shape()
	trimesh.backface_collision = true
	shape.shape = trimesh
	body.add_child(shape)
	level_root.add_child(body)


## A solid box in level space. A `low` box (the walls on the camera's side of the
## path, local +x) is drawn only knee-high so it never hides the players behind
## it, but still blocks movement at full height.
func _add_box(local_pos: Vector3, size: Vector3, mat: Material, low := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	if mat != null:  # (no material: solid but not drawn, as under a dungeon's wall models)
		var mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = size
		box_mesh.material = mat
		mesh.mesh = box_mesh
		if low:
			box_mesh.size.y = LOW_WALL_HEIGHT
			mesh.position.y = (LOW_WALL_HEIGHT - size.y) * 0.5
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
	creature.skill_ranks = PetSkills.clean_ranks(data.get("skills", []), data.level)
	var collar := ItemDB.clean(data.get("collar", {}))
	creature.collar = collar if ItemDB.fits_pet(collar, SpeciesDB.get_species(data.species)) else {}
	creature.owner_id = data.get("owner", 0)
	creature.party_slot = data.get("slot", -1)
	creature.nickname = Creature.clean_name(data.get("name", ""))
	creature.elite = data.get("elite", false)
	creature.pack_leader = data.get("leader", false)
	creature.keeper = data.get("keeper", false)
	creature.position = data.pos
	creature.home = data.pos
	if data.get("dead", false):
		creature.set_meta("dead_on_spawn", true)  # a dead pet stays dead (see Creature._ready)
	elif data.has("health"):
		creature.set_meta("health_fraction", clampf(float(data.health), 0.01, 1.0))
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
		"titan": titan_scene, "wyrm": wyrm_scene, "witch": witch_scene, "fish": fish_scene,
	}.get(data.get("type", "rival"), rival_scene)
	if Act2Boss.VARIANTS.has(data.get("type", "")):
		scene = act2_boss_scene
	var rival: Rival = scene.instantiate()
	if rival is Act2Boss:
		(rival as Act2Boss).variant = data.type
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
	# A little dog biscuit: a bar with two round knobs at each end.
	var treat := Node3D.new()
	add_child(treat)
	treat.global_position = from
	var biscuit := _material(Color(0.86, 0.62, 0.32))
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.3, 0.09, 0.1)
	bar.mesh = bar_mesh
	bar.material_override = biscuit
	treat.add_child(bar)
	for x in [-0.15, 0.15]:
		for z in [-0.05, 0.05]:
			var knob := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.065
			sphere.height = 0.13
			knob.mesh = sphere
			knob.material_override = biscuit
			knob.position = Vector3(x, 0.0, z)
			treat.add_child(knob)
	_add_glow(treat, Color(1.0, 0.85, 0.5), 0.35)
	# It arcs over, tumbling, and lands on the creature as the server decides.
	var flight := Player.TREAT_FLIGHT
	var arc := 1.4 + from.distance_to(to) * 0.12
	var tween := treat.create_tween()
	tween.tween_method(func(t: float) -> void:
		treat.global_position = from.lerp(to, t) + Vector3.UP * sin(PI * t) * arc
		treat.rotation = Vector3(t * 9.0, t * 4.0, 0.0), 0.0, 1.0, flight)
	if success:
		# Gobbled up: it shrinks into the creature with a pink puff.
		tween.tween_property(treat, "scale", Vector3.ONE * 0.05, 0.15)
		tween.tween_callback(func() -> void: _ring_fx(to, Color(1.0, 0.55, 0.75), 1.2))
	else:
		# Turned down: it bounces off and drops to the ground.
		var side := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * 1.2
		var ground := Vector3(to.x, from.y - 1.3, to.z) + side
		tween.tween_property(treat, "global_position", to + side * 0.5 + Vector3.UP * 0.6, 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(treat, "global_position", ground, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(treat, "scale", Vector3.ONE * 0.05, 0.3).set_delay(0.3)
	tween.tween_callback(treat.queue_free)


## A pink heart that pops up over a creature that has just been caught, then
## rises and fades.
@rpc("authority", "call_local", "reliable")
func play_heart(at: Vector3) -> void:
	var heart := Sprite3D.new()
	heart.texture = UiIcons.texture("heart_full", 64)
	heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heart.no_depth_test = true
	heart.render_priority = 10
	heart.pixel_size = 0.014
	heart.modulate = Color(1.0, 0.45, 0.65)
	add_child(heart)
	heart.global_position = at
	heart.scale = Vector3.ONE * 0.2
	var tween := heart.create_tween().set_parallel()
	tween.tween_property(heart, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(heart, "global_position", at + Vector3.UP * 1.2, 1.6).set_delay(0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(heart, "modulate:a", 0.0, 0.5).set_delay(1.3)
	tween.chain().tween_callback(heart.queue_free)


## The bat's bonk: a ring of little yellow stars that pops up and spins around
## the spot (above the head of whatever was hit), then fades.
## Everyone sees gear picked up: it pops up over the tamer who got it (see
## Player.play_pickup); that tamer's Inventory button also marks it as new.
@rpc("authority", "call_local", "reliable")
func show_pickup(peer_id: int, item: Dictionary) -> void:
	var p := get_player(peer_id)
	if p:
		p.play_pickup(ItemDB.clean(item))
	if peer_id == multiplayer.get_unique_id() and hud:
		hud.note_new_gear()


@rpc("authority", "call_local", "unreliable")
func play_bonk(at: Vector3) -> void:
	if _star_mesh == null:
		_star_mesh = _make_star_mesh()
	var ring := Node3D.new()
	add_child(ring)
	ring.global_position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_color = Color(1.0, 0.92, 0.3)
	for i in 5:
		var star := MeshInstance3D.new()
		star.mesh = _star_mesh
		star.material_override = mat
		star.position = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 5.0) * 0.45
		ring.add_child(star)
	ring.scale = Vector3.ONE * 0.2
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "rotation:y", TAU * 0.6, 0.7)
	tween.tween_property(ring, "position:y", at.y + 0.3, 0.7)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3).set_delay(0.4)
	tween.chain().tween_callback(ring.queue_free)


## A flat five-pointed star, 0.32 across, facing +Z (billboarded when drawn).
func _make_star_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	for i in 10:
		var r := 0.16 if i % 2 == 0 else 0.07
		var angle := PI / 2.0 + TAU * i / 10.0
		points.append(Vector3(cos(angle) * r, sin(angle) * r, 0.0))
	for i in 10:
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(points[i])
		st.add_vertex(points[(i + 1) % 10])
	return st.commit()


## Expanding ring that ends at `final_radius`.
@rpc("authority", "call_local", "unreliable")
func play_burst(at: Vector3, color: Color, final_radius: float) -> void:
	_ring_fx(at, color, final_radius)


## A vase breaking: clay shards fly out, bounce on the ground and fade, with
## a puff of dust (a ring in the vase's colour).
@rpc("authority", "call_local", "unreliable")
func play_shatter(at: Vector3, color: Color) -> void:
	_ring_fx(at, color.lightened(0.2), 1.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.85
	var fx := Node3D.new()
	add_child(fx)
	fx.global_position = at
	var tween := fx.create_tween().set_parallel()
	for i in 12:
		var shard := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(randf_range(0.12, 0.26), randf_range(0.03, 0.06), randf_range(0.1, 0.22))
		shard.mesh = mesh
		shard.material_override = mat
		var start := Vector3(randf_range(-0.25, 0.25), randf_range(0.2, 1.0), randf_range(-0.25, 0.25))
		shard.position = start
		shard.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		fx.add_child(shard)
		var out := Vector3(start.x, 0, start.z).normalized() if Vector2(start.x, start.z).length() > 0.05 \
				else Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
		var land := out * randf_range(0.8, 1.8) + Vector3(0, 0.04, 0)
		var peak := start.lerp(land, 0.4) + Vector3.UP * randf_range(0.5, 1.0)
		var time := randf_range(0.35, 0.5)
		tween.tween_property(shard, "position", peak, time * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "position", land, time * 0.55).set_delay(time * 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(shard, "rotation", shard.rotation + Vector3(randf_range(-6, 6), randf_range(-6, 6), 0), time)
		tween.tween_property(shard, "rotation:x", 0.0, 0.1).set_delay(time)  # lie flat
		tween.tween_property(shard, "rotation:z", 0.0, 0.1).set_delay(time)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5).set_delay(1.2)
	tween.chain().tween_callback(fx.queue_free)


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


## A wizard's magic bolt: a glowing orb with a fading trail that flies from
## `from` to `to` in `travel` seconds and bursts on arrival.
@rpc("authority", "call_local", "unreliable")
func play_bolt(from: Vector3, to: Vector3, color: Color, travel: float) -> void:
	var fx := Node3D.new()
	add_child(fx)
	fx.global_position = from
	var core := MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.16
	orb.height = 0.32
	core.mesh = orb
	core.material_override = _fx_material(Color(1, 1, 1, 0.95))
	fx.add_child(core)
	var glow := MeshInstance3D.new()
	var halo := SphereMesh.new()
	halo.radius = 0.3
	halo.height = 0.6
	glow.mesh = halo
	glow.material_override = _fx_material(Color(color, 0.55))
	fx.add_child(glow)
	_add_glow(fx, color, 0.9)
	_add_trail(fx, color, 0.35)
	var tween := fx.create_tween()
	tween.tween_property(fx, "global_position", to, travel)
	tween.tween_callback(func() -> void:
		_ring_fx(to - Vector3.UP * 0.55, color, 0.9)
		fx.queue_free())


## An arrow: a shaft with a pointed head and pale fletching, flying from
## `from` to `to` in `travel` seconds, pointing the way it flies.
@rpc("authority", "call_local", "unreliable")
func play_arrow(from: Vector3, to: Vector3, color: Color, travel: float) -> void:
	if from.distance_to(to) < 0.05:
		return
	var arrow := Node3D.new()
	add_child(arrow)
	var shaft := MeshInstance3D.new()
	var stick := BoxMesh.new()
	stick.size = Vector3(0.05, 0.05, 0.8)
	shaft.mesh = stick
	shaft.material_override = _fx_material(Color(0.55, 0.4, 0.25))
	arrow.add_child(shaft)
	var head := MeshInstance3D.new()
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.07
	tip.height = 0.2
	head.mesh = tip
	head.material_override = _fx_material(color)
	head.position.z = -0.48
	head.rotation.x = -PI / 2.0  # the cylinder's tip points along -Z, the way it flies
	arrow.add_child(head)
	for side in [-1.0, 1.0]:
		var feather := MeshInstance3D.new()
		var vane := BoxMesh.new()
		vane.size = Vector3(0.16, 0.01, 0.2)
		feather.mesh = vane
		feather.material_override = _fx_material(Color(color, 0.9))
		feather.position = Vector3(side * 0.06, 0, 0.36)
		feather.rotation.z = side * 0.4
		arrow.add_child(feather)
	arrow.look_at_from_position(from, to, Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.FORWARD)
	_add_glow(arrow, color, 0.7)
	_add_trail(arrow, color, 0.22)
	var tween := arrow.create_tween()
	tween.tween_property(arrow, "global_position", to, travel)
	tween.tween_callback(func() -> void:
		_ring_fx(to - Vector3.UP * 0.6, color, 0.6)
		arrow.queue_free())


## A whirlwind (Cyclone): a funnel of dusty wind, debris and dust at `at` for `duration` seconds.
@rpc("authority", "call_local", "unreliable")
func play_vortex(at: Vector3, radius: float, duration: float, _color: Color) -> void:
	CycloneFX.play(self, at, radius, duration)


## A paladin's Healing Kiss: a pink heart floats from the kisser to the one
## it heals, then rises from them and fades.
@rpc("authority", "call_local", "unreliable")
func play_kiss(from: Vector3, to: Vector3) -> void:
	var heart := Sprite3D.new()
	heart.texture = UiIcons.texture("heart", 48)
	heart.modulate = Color(1.0, 0.45, 0.65)
	heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heart.no_depth_test = true
	heart.shaded = false
	heart.pixel_size = 0.012
	add_child(heart)
	heart.global_position = from
	var tween := heart.create_tween()
	if from.distance_to(to) > 0.5:
		tween.tween_property(heart, "global_position", to, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(heart, "global_position:y", to.y + 0.8, 0.6)
	tween.parallel().tween_property(heart, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.tween_callback(heart.queue_free)


## A wizard casting: a glowing circle of light under the caster with a ring
## of sparks rising out of it.
@rpc("authority", "call_local", "unreliable")
func play_cast(at: Vector3, color: Color) -> void:
	var fx := Node3D.new()
	add_child(fx)
	fx.global_position = at + Vector3.UP * 0.06
	var mat := _fx_material(Color(color, 0.85))
	for r in [1.1, 0.75]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = r - 0.07
		torus.outer_radius = r
		ring.mesh = torus
		ring.material_override = mat
		fx.add_child(ring)
	for i in 6:  # rune marks between the rings
		var mark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.02, 0.26)
		mark.mesh = box
		mark.material_override = mat
		var a := TAU * i / 6.0
		mark.position = Vector3(cos(a), 0, sin(a)) * 0.92
		mark.rotation.y = -a
		fx.add_child(mark)
	var sparks := Node3D.new()
	fx.add_child(sparks)
	for i in 8:
		var spark := MeshInstance3D.new()
		var dot := SphereMesh.new()
		dot.radius = 0.07
		dot.height = 0.14
		spark.mesh = dot
		spark.material_override = mat
		var a := TAU * i / 8.0
		spark.position = Vector3(cos(a), 0.1, sin(a)) * 0.9
		sparks.add_child(spark)
	fx.scale = Vector3.ONE * 0.4
	var tween := fx.create_tween().set_parallel()
	tween.tween_property(fx, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(fx, "rotation:y", PI, 0.8)
	tween.tween_property(sparks, "position:y", 1.6, 0.8)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35).set_delay(0.45)
	tween.chain().tween_callback(fx.queue_free)


## A spell on its way (see SpellBlastAbility): an "orb" flying from `from`,
## a "meteor" falling from the sky, or a "lightning" bolt striking down; it
## lands at `to` after `travel` seconds.
@rpc("authority", "call_local", "unreliable")
func play_spell(style: String, from: Vector3, to: Vector3, color: Color, travel: float) -> void:
	if style == "lightning":
		play_lightning(PackedVector3Array([to + Vector3(0.6, 12.0, 0.4), to + Vector3.UP * 0.5]))
		_ring_fx(to, color, 2.0)
		return
	var size := 0.55 if style == "meteor" else 0.4
	var fx := Node3D.new()
	add_child(fx)
	fx.global_position = from
	for layer in [[size, Color(1, 1, 1, 0.95)], [size * 1.8, Color(color, 0.6)], [size * 2.6, Color(color, 0.25)]]:
		var shell := MeshInstance3D.new()
		var orb := SphereMesh.new()
		orb.radius = layer[0]
		orb.height = layer[0] * 2.0
		shell.mesh = orb
		shell.material_override = _fx_material(layer[1])
		fx.add_child(shell)
	_add_glow(fx, color, size * 3.2)
	_add_trail(fx, color, size * 0.9)
	var tween := fx.create_tween()
	tween.tween_property(fx, "global_position", to, travel).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN if style == "meteor" else Tween.EASE_OUT)
	tween.tween_callback(fx.queue_free)


## Fireball (a blazing ball with spiralling flame tendrils) or, with `magma`,
## Magma Orb (a swirling ball of lava), or with `meteor` (its size) one of
## Meteor Shower's meteors: it flies to `to` and explodes.
@rpc("authority", "call_local", "unreliable")
func play_fireball(from: Vector3, to: Vector3, travel: float, blast_radius: float, magma := false, meteor := 0.0) -> void:
	FireballFX.play(self, from, to, travel, blast_radius, magma, meteor)


## Static Arc (and Thunderstorm's bolts, `width` thicker): crackling, forking
## lightning from points[0] through each point after.
@rpc("authority", "call_local", "unreliable")
func play_arc(points: PackedVector3Array, width := 1.0) -> void:
	LightningFX.play(self, points, width)


## Lightning Bolt: a massive bolt from `sky` to `impact`, an arc from the
## caster's `paw`, and electricity bursting out along the ground.
@rpc("authority", "call_local", "unreliable")
func play_thunderbolt(sky: Vector3, impact: Vector3, paw: Vector3, radius: float) -> void:
	LightningFX.play(self, PackedVector3Array([sky, impact]), 2.6)
	LightningFX.play(self, PackedVector3Array([paw, impact + Vector3.UP * 0.6]), 0.8)
	StormFX.play(self, impact, radius * 1.3, 0.3, true)


## Thunder Chain: chains of lightning from the caster's `paw` to `center`, a
## ring of chain round it, and chains out to each of `targets`.
@rpc("authority", "call_local", "unreliable")
func play_chains(paw: Vector3, center: Vector3, targets: PackedVector3Array) -> void:
	ChainFX.play(self, paw, center, targets)


## Thunderstorm: a storm cloud over `center`, electricity crackling beneath it
## (with `ice`, Hailstorm's frosty vortex).
@rpc("authority", "call_local", "unreliable")
func play_storm(center: Vector3, radius: float, duration: float, burst := false, ice := false) -> void:
	StormFX.play(self, center, radius, duration, burst, ice)


## One of Hailstorm's hailstones, falling from `from` to `to` and shattering.
@rpc("authority", "call_local", "unreliable")
func play_hail(from: Vector3, to: Vector3, travel: float, radius: float) -> void:
	HailFX.play(self, from, to, travel, radius)


## Tidal Wave: a wall of water rolling out from `origin` towards `forward`.
@rpc("authority", "call_local", "unreliable")
func play_wave(origin: Vector3, forward: Vector3, radius: float, cone_degrees: float, color: Color) -> void:
	TidalWaveFX.play(self, origin, forward, radius, cone_degrees, color)


## Green plus signs floating up off each of `at` (someone healed by a dog's spell).
@rpc("authority", "call_local", "unreliable")
func play_heal_marks(at: PackedVector3Array) -> void:
	for p in at:
		FXKit.heal_marks(self, p)


## A little blue shield over each of `who` (paths of pets or players a dog's spell
## shielded or protected) for `duration` seconds.
@rpc("authority", "call_local", "unreliable")
func play_shield_icons(who: Array, duration: float) -> void:
	for path in who:
		var node := get_node_or_null(path) as Node3D
		if node:
			FXKit.shield_icon(node, duration)


## A dog's or lizard's ability look (HolyFX / SwampFX): `family` "holy" or
## "swamp", `look` the spell's, at `at` from `from`.
@rpc("authority", "call_local", "unreliable")
func play_pet_fx(family: String, look: String, at: Vector3, from: Vector3, radius: float, extra: float,
		allies: PackedVector3Array, enemies: PackedVector3Array) -> void:
	if family == "holy":
		HolyFX.play(self, look, at, from, radius, extra, allies, enemies)
	else:
		SwampFX.play(self, look, at, from, radius, extra, allies, enemies)


## An archer's basic shot with the "air" look: a real arrow with a streak of
## air behind it and wisps spiralling round its path (AirShotFX).
@rpc("authority", "call_local", "unreliable")
func play_air_shot(from: Vector3, to: Vector3, feather: Color, travel: float) -> void:
	AirShotFX.play(self, from, to, feather, travel)


## Sunburst Arrow: a fiery bolt from `from` bursting into a blazing sun at
## `to`, rays of light and sunlight over `radius` (SunburstFX).
@rpc("authority", "call_local", "unreliable")
func play_sunburst(from: Vector3, to: Vector3, radius: float) -> void:
	SunburstFX.play(self, from, to, radius)


## Rain of Arrows: a streak shot up from `from`, a circle of runes over
## `center`, and glowing arrows raining down, landing on `spots` at `times`
## among many more (RainFX).
@rpc("authority", "call_local", "unreliable")
func play_arrow_rain(from: Vector3, center: Vector3, radius: float, spots: PackedVector3Array, times: PackedFloat32Array) -> void:
	RainFX.play(self, from, center, radius, spots, times)


## Prism Shot: a rainbow crystal ahead of the bow (`from`), a rainbow beam
## out of it to `to`, and a rainbow burst there over `radius` (PrismFX).
@rpc("authority", "call_local", "unreliable")
func play_prism_shot(from: Vector3, to: Vector3, radius: float) -> void:
	PrismFX.play(self, from, to, radius)


## Snipe: a glint at the bow (`from`), a golden tracer and beam to `to`, and a
## blinding golden flare there (SnipeFX).
@rpc("authority", "call_local", "unreliable")
func play_snipe(from: Vector3, to: Vector3) -> void:
	SnipeFX.play(self, from, to)


## Eagle Eye: a glowing orange ring growing out from `center` (the bird) to
## `radius`, flaring on each of `allies` as it reaches them (EagleEyeFX).
@rpc("authority", "call_local", "unreliable")
func play_eagle_eye(center: Vector3, radius: float, allies: PackedVector3Array) -> void:
	EagleEyeFX.play(self, center, radius, allies)


## Hail Volley: a wave of icy arrows arcing from `from` down onto each of
## `ends`, ice erupting where they land after `travel` seconds (HailVolleyFX).
@rpc("authority", "call_local", "unreliable")
func play_hail_volley(from: Vector3, ends: PackedVector3Array, travel: float) -> void:
	HailVolleyFX.play(self, from, ends, travel)


## Frost Arrow: an icy bolt from `from` to `to` bursting into ice, runes,
## frost mist and snow over `radius` (FrostFX).
@rpc("authority", "call_local", "unreliable")
func play_frost_arrow(from: Vector3, to: Vector3, radius: float) -> void:
	FrostFX.play(self, from, to, radius)


## Piercing Shot: a blazing bolt from `from` to `to` with a fiery trail and a
## crescent of light, bursting at each of `hits` as it passes (PierceFX).
@rpc("authority", "call_local", "unreliable")
func play_piercing_shot(from: Vector3, to: Vector3, hits: PackedVector3Array) -> void:
	PierceFX.play(self, from, to, hits)


## Arrow Cone: a golden dome swept out from `from` towards `forward`, full
## of streaking arrows (ConeFX).
@rpc("authority", "call_local", "unreliable")
func play_arrow_cone(from: Vector3, forward: Vector3, reach: float, spread_degrees: float) -> void:
	ConeFX.play(self, from, forward, reach, spread_degrees)


## Hunter's Mark: a sigil by the caster's bow at `from`, a red beam to `to`
## (reached in `travel` seconds) and a burst there over `radius` (MarkFX).
@rpc("authority", "call_local", "unreliable")
func play_hunters_mark(from: Vector3, to: Vector3, travel: float, radius: float) -> void:
	MarkFX.cast(self, from, to, travel, radius)


## A short beam between two points (e.g. a heal).
@rpc("authority", "call_local", "unreliable")
func play_beam(from: Vector3, to: Vector3, color: Color) -> void:
	var mat := _fx_material(color)
	var beam := _bolt_segment(from, to, mat)
	# A wide, soft, glowing sheath around the beam, and a light at each end.
	var sheath_mat := _additive_material(Color(color, 0.5))
	var sheath := _bolt_segment(from, to, sheath_mat)
	sheath.scale = Vector3(3.0, 3.0, 1.0)
	beam.add_child(_make_light(color, 3.0))
	sheath.reparent(beam)
	var end_glow := Node3D.new()
	beam.add_child(end_glow)
	end_glow.global_position = to
	_add_glow(end_glow, color, 0.8)
	var tween := beam.create_tween().set_parallel()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_property(sheath_mat, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(beam.queue_free)


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
func play_trap(id: int, at: Vector3, radius: float, color: Color, look := "") -> void:
	var trap := Node3D.new()
	trap.name = "Trap%d" % id
	add_child(trap)
	if look != "":  # (a lizard's: SwampFX's mud puddle or ghostly rune)
		SwampFX.trap(trap, at, radius, look)
		return
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


## Makes a projectile glow, so shots are easy to see: a soft halo that always
## faces the camera (added on top of what's behind it, so it brightens) and a
## small light that lights up the ground it flies over. `radius` is the halo's.
func _add_glow(parent: Node3D, color: Color, radius: float) -> void:
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 2.0
	halo.mesh = quad
	halo.material_override = _glow_material(color)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(halo)
	parent.add_child(_make_light(color, radius * 3.5 + 1.0))


func _make_light(color: Color, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color.lightened(0.2)
	light.light_energy = 1.8
	light.omni_range = light_range
	light.shadow_enabled = false
	return light


## A glowing trail behind a projectile: every few hundredths of a second it
## leaves a small halo that shrinks and fades.
func _add_trail(projectile: Node3D, color: Color, radius: float) -> void:
	var timer := Timer.new()
	timer.wait_time = 0.035
	timer.autostart = true
	projectile.add_child(timer)
	var mat := _glow_material(Color(color, 0.7))
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(projectile):
			return
		var puff := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * radius * 2.0
		puff.mesh = quad
		puff.material_override = mat
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)
		puff.global_position = projectile.global_position
		var tween := puff.create_tween()
		tween.tween_property(puff, "scale", Vector3.ONE * 0.1, 0.3)
		tween.tween_callback(puff.queue_free))


static var _glow_materials := {}
static var _glow_texture: Texture2D


## An additive, camera-facing material with a soft round falloff (cached by colour).
func _glow_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _glow_materials.has(key):
		if _glow_texture == null:
			var gradient := Gradient.new()
			gradient.set_color(0, Color(1, 1, 1, 1))
			gradient.set_color(1, Color(1, 1, 1, 0))
			gradient.add_point(0.25, Color(1, 1, 1, 0.85))
			gradient.add_point(0.55, Color(1, 1, 1, 0.3))
			var texture := GradientTexture2D.new()
			texture.gradient = gradient
			texture.fill = GradientTexture2D.FILL_RADIAL
			texture.fill_from = Vector2(0.5, 0.5)
			texture.fill_to = Vector2(1.0, 0.5)
			texture.width = 64
			texture.height = 64
			_glow_texture = texture
		var mat := _additive_material(color)
		mat.albedo_texture = _glow_texture
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glow_materials[key] = mat
	return _glow_materials[key]


func _additive_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	return mat


func _fx_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat
