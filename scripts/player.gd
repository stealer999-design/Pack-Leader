class_name Player
extends CharacterBody3D
## A tamer. Each client moves its own player locally (owner-authoritative
## position, for responsiveness). Attacks, captures, pet commands, abilities
## and stable actions are requests sent to the server, which validates them.

signal stable_changed
signal inventory_changed

const MAX_PARTY := 3
const MAX_STABLE := 20
const RIVAL_COMMAND := "@rival"
## Potions a player can carry. Everyone starts each level with a full set.
const MAX_POTIONS := 2
## The bats a tamer can wield, upgraded at the village bat shop. Every bat
## still stops at 1 HP on creatures, so they stay ready to capture.
const BATS := [
	{"name": "Wooden Bat", "damage": 12.0, "price": 0},
	{"name": "Spiked Bat", "damage": 22.0, "price": 60},
]
const HAIR_COLORS: Array[Color] = [Color(0.3, 0.18, 0.1), Color(0.12, 0.1, 0.08), Color(0.85, 0.65, 0.3),
		Color(0.6, 0.25, 0.12), Color(0.45, 0.32, 0.2)]

@export_group("Movement")
@export var move_speed := 10.5
@export var acceleration := 80.0
@export var dash_speed := 20.0
@export var dash_duration := 0.15
@export var dash_cooldown := 0.8

@export_group("Combat")
## Deliberately weak: the player weakens creatures, the pets do the real fighting.
@export var attack_range := 2.4
@export var attack_arc_degrees := 120.0
@export var attack_cooldown := 0.4
@export var knockback := 6.0
@export var respawn_time := 4.0

@export_group("Recovery")
## Seconds without taking damage before health starts coming back.
@export var regen_delay := 5.0
## Fraction of max health regenerated per second once out of combat.
@export var regen_rate := 0.03
## Coins per potion at the lemonade stand.
@export var potion_price := 10
## Lucky Lemonade, the stand's capture boost: price, duration and multiplier.
@export var boost_price := 15
@export var boost_duration := 90.0
@export var boost_multiplier := 1.5
## Fraction of max health a potion restores.
@export_range(0.0, 1.0) var potion_heal := 0.5
@export var potion_cooldown := 8.0

@export_group("Taming")
@export var capture_range := 9.0
@export var capture_cooldown := 1.5

# Set by the spawn function before entering the tree.
var peer_id := 1
var display_name := "Player"
var color := Color.WHITE

# Replicated from the server.
var coins := 0
var potions := MAX_POTIONS
## Pet stance. Passive pets follow but never attack, so creatures survive to be captured.
var pets_passive := false
## Gear (see ItemDB): the bag (BAG_SIZE places, {} = empty) and what's worn,
## by slot. The server holds the real ones and sends them to the owner.
var bag: Array[Dictionary] = []
var equipment := {}
## The worn jacket's level (0 = none). Replicated, so everyone sees it.
var jacket_level := 0:
	set(v):
		jacket_level = v
		if person:
			person.set_jacket(ItemDB.JACKETS[v - 1].color if v > 0 else Color(0, 0, 0, 0))
## Index into BATS. Replicated, so everyone sees the spikes.
var bat_tier := 0:
	set(v):
		bat_tier = v
		if person:
			person.set_spiked(bat_tier >= 1)
## Server: reached this level's checkpoint (the lemonade stand), so respawns there.
var checkpoint := false
var downed := false:
	set(v):
		downed = v
		if is_node_ready():
			_apply_downed()

## The stable's hay beds: MAX_STABLE entries, each a pet as data
## ({species, level, xp}) or {} for an empty bed. Authoritative on the server and
## mirrored to the owning client only.
var stable: Array[Dictionary] = []

## Creature under the mouse cursor (local player only).
var hovered_creature: Creature

var _aim_dir := Vector3.FORWARD
var _aim_point := Vector3.ZERO
var _attack_timer := 0.0
var _capture_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_dir := Vector3.ZERO
var _server_attack_timer := 0.0
var _server_capture_timer := 0.0
var _server_potion_timer := 0.0
var _potion_timer := 0.0
## Seconds of Lucky Lemonade left. Authoritative on the server; the owner keeps a
## local copy (started by _boost_started) for the HUD and hover capture chance.
var _boost_timer := 0.0
var _since_hit := 0.0  ## Server: seconds since this player last took damage.
var _restored := false  ## Server: a save has been restored for this player.
var _slow_timer := 0.0
var _slow_factor := 1.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _material := StandardMaterial3D.new()
var _swing_fx: MeshInstance3D
## Server: where this tamer has recently walked, oldest first. Every point is
## somewhere a pet can stand, so pets cut off by a wall or rock follow it.
var trail: Array[Vector3] = []
const TRAIL_STEP := 0.8
const TRAIL_LENGTH := 60
var person: PersonModel

@onready var world: World = get_tree().get_first_node_in_group("world")
@onready var health: Health = $Health
@onready var model: Node3D = $Model
@onready var name_label: Label3D = $NameLabel


func _enter_tree() -> void:
	# The owning peer controls this node (and its position sync); the server
	# keeps authority over StateSync (health, downed).
	set_multiplayer_authority(peer_id, false)
	$PositionSync.set_multiplayer_authority(peer_id)


func _ready() -> void:
	add_to_group("players")
	for i in MAX_STABLE:
		stable.append({})
	for i in ItemDB.BAG_SIZE:
		bag.append({})
	for slot in ItemDB.SLOTS:
		equipment[slot] = {}
	_material.albedo_color = color
	person = PersonModel.new()
	person.name = "Person"
	model.add_child(person)
	person.build(_material, HAIR_COLORS[absi(peer_id) % HAIR_COLORS.size()])
	person.set_spiked(bat_tier >= 1)
	jacket_level = jacket_level  # dress the model
	name_label.text = display_name
	name_label.modulate = color.lightened(0.3)
	_swing_fx = _build_swing_fx()
	model.add_child(_swing_fx)
	if multiplayer.is_server():
		health.died.connect(_on_died)
	if is_multiplayer_authority():
		world.on_local_player_spawned(self)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_record_trail()
		_server_attack_timer -= delta
		_server_capture_timer -= delta
		_server_potion_timer -= delta
		if not is_multiplayer_authority():
			_boost_timer -= delta  # the owner counts down below
		_regenerate(delta)
	if not is_multiplayer_authority():
		return

	_attack_timer -= delta
	_capture_timer -= delta
	_dash_cooldown_timer -= delta
	_slow_timer -= delta
	_potion_timer -= delta
	_boost_timer -= delta
	_update_aim()

	if downed:
		velocity = Vector3.ZERO
		return

	var move_dir := _camera_relative(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
		_dash_dir = move_dir if move_dir != Vector3.ZERO else _aim_dir
		_dash_timer = dash_duration
		_dash_cooldown_timer = dash_cooldown

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
	else:
		var target_velocity := move_dir * move_speed * (_slow_factor if _slow_timer > 0.0 else 1.0)
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	health.invulnerable = _dash_timer > 0.0  # replicated to the server

	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	model.rotation.y = atan2(-_aim_dir.x, -_aim_dir.z)

	if Input.is_action_just_pressed("potion") and _potion_timer <= 0.0:
		if potions > 0 and health.current < health.max_health:
			_potion_timer = potion_cooldown
		request_potion.rpc_id(1)  # the server explains if it can't be used

	if Input.is_action_just_pressed("inventory"):
		world.hud.toggle_inventory()
	if Input.is_action_just_pressed("map"):
		world.hud.mini_map.toggle_expanded()
	if Input.is_action_just_pressed("skills"):
		world.hud.toggle_skills()
	if Input.is_action_just_pressed("interact"):
		if world.hud.is_window_open():
			world.hud.close_windows()
		elif world.is_near_stable(global_position):
			world.hud.open_stable()
		elif world.is_near_shop(global_position):
			world.hud.open_shop()
		elif world.is_near_bat_shop(global_position):
			world.hud.open_bat_shop()
		elif world.is_near_breeder(global_position):
			world.hud.open_breeder()
	if world.hud.is_window_open():
		return  # mouse is busy with the stable or shop window

	if Input.is_action_just_pressed("pet_stance"):
		request_toggle_stance.rpc_id(1)

	if Input.is_action_pressed("attack") and _attack_timer <= 0.0 and not world.hud.is_mouse_over_buttons():
		_attack_timer = attack_cooldown
		_play_swing_fx()
		request_attack.rpc_id(1, _aim_dir)

	if Input.is_action_just_pressed("capture") and _capture_timer <= 0.0 and hovered_creature:
		_capture_timer = capture_cooldown
		request_capture.rpc_id(1, hovered_creature.name)

	if Input.is_action_just_pressed("command"):
		var rival := world.get_rival()
		if hovered_creature and Combat.are_enemies(self, hovered_creature):
			world.ping(hovered_creature.global_position, Color(1, 0.35, 0.3))
			request_command.rpc_id(1, hovered_creature.name)
		elif rival and rival.global_position.distance_to(_aim_point) < rival.radius() + 1.0:
			world.ping(rival.global_position, Color(1, 0.35, 0.3))
			request_command.rpc_id(1, RIVAL_COMMAND)
		else:
			world.ping(global_position, color)
			request_command.rpc_id(1, "")

	for slot in MAX_PARTY:
		if Input.is_action_just_pressed("ability_%d" % (slot + 1)):
			var target_name := String(hovered_creature.name) if hovered_creature else ""
			request_ability.rpc_id(1, slot, _aim_point, target_name)


func is_targetable() -> bool:
	return not downed and not is_queued_for_deletion()


func radius() -> float:
	return 0.4


func capture_boost() -> float:
	return boost_multiplier if _boost_timer > 0.0 else 1.0


func boost_time_left() -> float:
	return maxf(_boost_timer, 0.0)


func potion_cooldown_left() -> float:
	return maxf(_potion_timer, 0.0)


func party_is_full() -> bool:
	return world.get_pets(peer_id).size() >= MAX_PARTY


func stable_count() -> int:
	return stable.filter(func(bed: Dictionary) -> bool: return not bed.is_empty()).size()


func stable_is_full() -> bool:
	return stable_count() >= MAX_STABLE


func _first_empty_bed() -> int:
	for i in stable.size():
		if stable[i].is_empty():
			return i
	return -1


func _valid_place(kind: String, index: int) -> bool:
	if kind == "party":
		return index >= 0 and index < MAX_PARTY
	return kind == "bed" and index >= 0 and index < stable.size()


## Server: the pet in `bed` joins the party in `slot`; whoever was in that slot
## takes its place in the bed.
func _bed_to_party(bed: int, slot: int) -> void:
	var data := stable[bed]
	if data.is_empty():
		return
	var current := world.get_party_pet(peer_id, slot)
	if current:
		stable[bed] = current.to_data()
		current.queue_free()
	else:
		stable[bed] = {}
	world.spawn_pet(peer_id, data, global_position, slot)


# --- Requests (client -> server) -------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func request_attack(aim: Vector3) -> void:
	if not _sent_by_owner() or downed or _server_attack_timer > 0.0:
		return
	_server_attack_timer = attack_cooldown * 0.8  # small tolerance for jitter
	aim.y = 0.0
	if aim.length_squared() < 0.01:
		return
	aim = aim.normalized()
	var half_arc := deg_to_rad(attack_arc_degrees) * 0.5
	for enemy in world.enemies_near(self, global_position, attack_range):
		var to := enemy.global_position - global_position
		to.y = 0.0
		if aim.angle_to(to.normalized()) <= half_arc:
			var damage := bat_damage()
			if enemy is Creature:
				# The bat only weakens creatures: it never takes them below 1 HP,
				# so they're left ready to capture (a 99% chance at 1 HP).
				damage = maxf(minf(damage, enemy.health.current - 1.0), 0.0)
			enemy.receive_damage(damage, self, to.normalized() * knockback)
			world.play_bonk.rpc(enemy.global_position + Vector3.UP * (enemy.radius() * 2.0 + 0.4))
	for crate in world.crates_near(global_position, attack_range):
		var to := crate.global_position - global_position
		to.y = 0.0
		if to.length() < 0.01 or aim.angle_to(to.normalized()) <= half_arc:
			crate.hit(bat_damage())
			world.play_bonk.rpc(crate.global_position + Vector3.UP * 1.2)
	_show_swing.rpc(aim)


@rpc("any_peer", "call_local", "reliable")
func request_potion() -> void:
	if not _sent_by_owner() or downed or _server_potion_timer > 0.0:
		return
	if health.current >= health.max_health:
		world.tell(peer_id, "You're already at full health.", Color(1, 0.8, 0.5))
		return
	if potions <= 0:
		world.tell(peer_id, "You're out of potions. Buy more at the lemonade stand halfway along the path.",
				Color(1, 0.8, 0.5))
		return
	_server_potion_timer = potion_cooldown * 0.8
	potions -= 1
	health.heal(health.max_health * potion_heal)
	world.play_burst.rpc(global_position, Color(0.5, 1.0, 0.55), 1.5)


@rpc("any_peer", "call_local", "reliable")
func request_buy_potion() -> void:
	if not _sent_by_owner() or downed:
		return
	if not world.is_near_shop(global_position):
		world.tell(peer_id, "You need to be at the lemonade stand.", Color(1, 0.8, 0.5))
		return
	if potions >= MAX_POTIONS:
		world.tell(peer_id, "You can only carry %d potions." % MAX_POTIONS, Color(1, 0.8, 0.5))
		return
	if coins < potion_price:
		world.tell(peer_id, "A potion costs %d coins (you have %d). Smash crates for coins!" % [potion_price, coins],
				Color(1, 0.8, 0.5))
		return
	coins -= potion_price
	potions += 1
	world.tell(peer_id, "Thanks! One fresh potion.", Color(1, 0.85, 0.35))


func bat_damage() -> float:
	return BATS[bat_tier].damage


## The next bat up, or {} if this tamer already has the best one.
func next_bat() -> Dictionary:
	return BATS[bat_tier + 1] if bat_tier + 1 < BATS.size() else {}


## The pet data ({species, level, ...}) at a party slot or hay bed, or {}.
func pet_at(kind: String, index: int) -> Dictionary:
	if not _valid_place(kind, index):
		return {}
	if kind == "bed":
		return stable[index]
	var pet := world.get_party_pet(peer_id, index)
	return pet.to_data() if pet else {}


## Breeds two of this tamer's cats (each a party slot or a hay bed) at the
## village breeder. The parents stay; the hybrid joins the party, or a bed.
@rpc("any_peer", "call_local", "reliable")
func request_breed(a_kind: String, a_index: int, b_kind: String, b_index: int) -> void:
	if not _sent_by_owner() or downed:
		return
	if not world.is_near_breeder(global_position):
		world.tell(peer_id, "You need to be at the breeder in the village.", Color(1, 0.8, 0.5))
		return
	if a_kind == b_kind and a_index == b_index:
		return
	var a := pet_at(a_kind, a_index)
	var b := pet_at(b_kind, b_index)
	var reason := BreedingDB.cannot_breed_reason(a, b)
	if reason != "":
		world.tell(peer_id, reason, Color(1, 0.8, 0.5))
		return
	if coins < BreedingDB.PRICE:
		world.tell(peer_id, "Breeding costs %d coins (you have %d)." % [BreedingDB.PRICE, coins], Color(1, 0.8, 0.5))
		return
	var slot := world.free_party_slot(peer_id)
	var bed := _first_empty_bed()
	if slot < 0 and bed < 0:
		world.tell(peer_id, "There's no room for a new pet: free a party slot or a hay bed first.", Color(1, 0.8, 0.5))
		return
	coins -= BreedingDB.PRICE
	var hybrid := BreedingDB.hybrid_of(a.species, b.species)
	var baby := {"species": hybrid, "level": 1, "xp": 0, "skills": PetSkills.empty_ranks()}
	var where := "joined your party"
	if slot >= 0:
		world.spawn_pet(peer_id, baby, global_position, slot)
	else:
		stable[bed] = baby
		_push_stable()
		where = "is waiting in the stable"
	world.announce.rpc("%s's %s and %s had a %s!" % [display_name, SpeciesDB.get_species(a.species).display_name,
			SpeciesDB.get_species(b.species).display_name, SpeciesDB.get_species(hybrid).display_name], Color(1.0, 0.7, 0.85))
	world.tell(peer_id, "Your new %s %s." % [SpeciesDB.get_species(hybrid).display_name, where], Color(1.0, 0.7, 0.85))
	world.play_burst.rpc(global_position, Color(1.0, 0.6, 0.8), 2.2)


@rpc("any_peer", "call_local", "reliable")
func request_buy_bat() -> void:
	if not _sent_by_owner() or downed:
		return
	if not world.is_near_bat_shop(global_position):
		world.tell(peer_id, "You need to be at the bat shop in the village.", Color(1, 0.8, 0.5))
		return
	var bat := next_bat()
	if bat.is_empty():
		world.tell(peer_id, "You already have the best bat in the shop.", Color(1, 0.8, 0.5))
		return
	if coins < bat.price:
		world.tell(peer_id, "The %s costs %d coins (you have %d)." % [bat.name, bat.price, coins], Color(1, 0.8, 0.5))
		return
	coins -= bat.price
	bat_tier += 1
	world.tell(peer_id, "You got the %s! It hits for %d (it still stops at 1 HP on creatures)."
			% [bat.name, roundi(bat.damage)], Color(1.0, 0.85, 0.4))
	world.play_burst.rpc(global_position, Color(0.85, 0.85, 0.9), 1.8)


@rpc("any_peer", "call_local", "reliable")
func request_buy_boost() -> void:
	if not _sent_by_owner() or downed:
		return
	if not world.is_near_shop(global_position):
		world.tell(peer_id, "You need to be at the lemonade stand.", Color(1, 0.8, 0.5))
		return
	if coins < boost_price:
		world.tell(peer_id, "Lucky Lemonade costs %d coins (you have %d)." % [boost_price, coins], Color(1, 0.8, 0.5))
		return
	coins -= boost_price
	_boost_started.rpc(boost_duration)
	world.tell(peer_id, "Lucky Lemonade! Capture chance x%.1f for %ds." % [boost_multiplier, int(boost_duration)],
			Color(1, 0.9, 0.3))
	world.play_burst.rpc(global_position, Color(1.0, 0.9, 0.3), 1.8)


@rpc("any_peer", "call_local", "reliable")
func request_capture(creature_name: String) -> void:
	if not _sent_by_owner() or downed or _server_capture_timer > 0.0:
		return
	var c := world.get_creature(creature_name)
	if c and c.is_rival_pet():
		world.tell(peer_id, "That pet belongs to the rival. Defeat the rival first!", Color(1, 0.8, 0.5))
		return
	if c == null or not c.is_wild() or not c.is_targetable():
		return
	if c.global_position.distance_to(global_position) > capture_range + c.radius():
		world.tell(peer_id, "Too far away to capture.", Color(1, 0.8, 0.5))
		return
	if party_is_full() and stable_is_full():
		world.tell(peer_id, "Your party and stable are both full. Release a pet at the stable first.", Color(1, 0.8, 0.5))
		return
	_server_capture_timer = capture_cooldown * 0.8
	var success := randf() < c.capture_chance(capture_boost())
	world.play_capture_fx.rpc(global_position + Vector3.UP * 1.2, c.global_position + Vector3.UP * c.radius(), success)
	if not success:
		c.on_capture_failed(self)
		world.tell(peer_id, "The %s broke free!" % c.species.display_name, Color(1, 0.6, 0.4))
		return
	world.announce.rpc("%s captured a %s!" % [display_name, c.species.display_name], color.lightened(0.3))
	if party_is_full():
		stable[_first_empty_bed()] = c.to_data()
		c.queue_free()
		_push_stable()
		world.tell(peer_id, "Your party is full, so the %s was sent to the stable (%d/%d)." \
				% [c.species.display_name, stable_count(), MAX_STABLE], Color(0.6, 0.85, 1.0))
	else:
		c.tame(peer_id, world.free_party_slot(peer_id))


## Empty name = regroup (pets drop their focus and return to you).
## RIVAL_COMMAND = attack the rival tamer. Sending pets at an enemy switches Passive pets back to Aggressive.
@rpc("any_peer", "call_local", "reliable")
func request_command(creature_name: String) -> void:
	if not _sent_by_owner():
		return
	var focus: Node3D = null
	if creature_name == RIVAL_COMMAND:
		focus = world.get_rival()
	elif creature_name != "":
		focus = world.get_creature(creature_name)
	if focus and not Combat.are_enemies(self, focus):
		focus = null
	# Sending pets at an enemy ends Passive stance: they're told to fight.
	if focus and pets_passive:
		pets_passive = false
		world.tell(peer_id, "Pets are AGGRESSIVE again: attacking!", Color(1, 0.7, 0.5))
	for pet in world.get_pets(peer_id):
		pet.set_focus(focus)


## Spends one of a party pet's skill points on skill `index`.
@rpc("any_peer", "call_local", "reliable")
func request_train_skill(slot: int, index: int) -> void:
	if not _sent_by_owner():
		return
	var pet := world.get_party_pet(peer_id, slot)
	if pet == null:
		return
	var reason := PetSkills.cannot_train_reason(pet.level, pet.skill_ranks, index)
	if reason != "":
		world.tell(peer_id, reason, Color(1, 0.6, 0.4))
		return
	var ranks := pet.skill_ranks.duplicate()
	ranks[index] += 1
	pet.skill_ranks = ranks  # a new array, so the change replicates
	pet.refresh_max_health()


## Gives back all of a party pet's skill points, to spend again. Free.
@rpc("any_peer", "call_local", "reliable")
func request_reset_skills(slot: int) -> void:
	if not _sent_by_owner():
		return
	var pet := world.get_party_pet(peer_id, slot)
	if pet == null or PetSkills.points_spent(pet.skill_ranks) == 0:
		return
	pet.skill_ranks = PetSkills.empty_ranks()
	pet.refresh_max_health()
	world.tell(peer_id, "Your %s's skill points are back to spend." % pet.species.display_name, Color(0.6, 0.85, 1.0))


@rpc("any_peer", "call_local", "reliable")
func request_toggle_stance() -> void:
	if not _sent_by_owner():
		return
	pets_passive = not pets_passive
	for pet in world.get_pets(peer_id):
		pet.set_focus(null)
	if pets_passive:
		world.tell(peer_id, "Pets are PASSIVE: they won't attack, so you can weaken and capture creatures.",
				Color(0.6, 0.85, 1.0))
	else:
		world.tell(peer_id, "Pets are AGGRESSIVE: they'll defend you and fight again.", Color(1, 0.7, 0.5))


## Ask the pet in party `slot` to use its ability at `point` (or on `target_name`).
@rpc("any_peer", "call_local", "reliable")
func request_ability(slot: int, point: Vector3, target_name: String) -> void:
	if not _sent_by_owner() or downed:
		return
	var pet := world.get_party_pet(peer_id, slot)
	if pet == null:
		world.tell(peer_id, "No pet in slot %d." % (slot + 1), Color(1, 0.8, 0.5))
		return
	var target := world.get_creature(target_name) if target_name != "" else null
	var error := pet.queue_ability(point, target)
	if error != "":
		world.tell(peer_id, error, Color(1, 0.8, 0.5))


## The owner's saved progress (see SaveGame), sent once after spawning. Saves
## live on each player's own computer, so everything is checked before use.
@rpc("any_peer", "call_local", "reliable")
func request_restore(data: Dictionary) -> void:
	if not _sent_by_owner() or _restored:
		return
	_restored = true
	coins = clampi(int(data.get("coins", 0)), 0, 999_999)
	potions = clampi(int(data.get("potions", MAX_POTIONS)), 0, MAX_POTIONS)
	bat_tier = clampi(int(data.get("bat", 0)), 0, BATS.size() - 1)
	var saved_bag = data.get("bag", [])
	if saved_bag is Array:
		for i in mini(saved_bag.size(), bag.size()):
			bag[i] = ItemDB.clean(saved_bag[i])
	var saved_gear = data.get("equipment", {})
	if saved_gear is Dictionary:
		for slot in ItemDB.SLOTS:
			var item := ItemDB.clean(saved_gear.get(slot, {}))
			equipment[slot] = item if ItemDB.slot_of(item) == slot else {}
	_gear_changed()
	var beds = data.get("stable", [])
	if beds is Array:
		for i in mini(beds.size(), MAX_STABLE):
			stable[i] = _clean_pet(beds[i])
	var party = data.get("party", [])
	var restored_pets := 0
	if party is Array:
		for entry in party.slice(0, MAX_PARTY):
			var pet := _clean_pet(entry)
			if pet.is_empty():
				continue
			var slot := clampi(int(entry.get("slot", 0)), 0, MAX_PARTY - 1)
			if world.get_party_pet(peer_id, slot):
				slot = world.free_party_slot(peer_id)
			if slot >= 0:
				world.spawn_pet(peer_id, pet, global_position, slot)
				restored_pets += 1
	_push_stable()
	world.tell(peer_id, "Welcome back, %s! %d pets in your party, %d in the stable." \
			% [display_name, restored_pets, stable_count()], Color(0.7, 0.9, 0.7))


## A saved pet made safe to use: a real species and sensible numbers, or {}.
static func _clean_pet(entry) -> Dictionary:
	if not entry is Dictionary or not entry.has("species"):
		return {}
	var species := int(entry.species)
	if species < 0 or species >= SpeciesDB.PATHS.size():
		return {}
	var level := clampi(int(entry.get("level", 1)), 1, 99)
	return {
		"species": species,
		"level": level,
		"xp": clampi(int(entry.get("xp", 0)), 0, 1_000_000),
		"skills": PetSkills.clean_ranks(entry.get("skills", []), level),
	}


## Drag and drop in the stable window. `kind` is "party" (index = party slot)
## or "bed" (index = hay bed). Covers every combination:
## bed -> party: take the pet out (swapping with the pet in that slot, if any);
## party -> bed: put the pet to bed (swapping with the pet in that bed, if any);
## bed -> bed / party -> party: swap the two places.
@rpc("any_peer", "call_local", "reliable")
func request_stable_move(from_kind: String, from_index: int, to_kind: String, to_index: int) -> void:
	if not _can_use_stable() or not _valid_place(from_kind, from_index) or not _valid_place(to_kind, to_index):
		return
	if from_kind == to_kind and from_index == to_index:
		return
	if from_kind == "party" and to_kind == "party":
		var a := world.get_party_pet(peer_id, from_index)
		var b := world.get_party_pet(peer_id, to_index)
		if a:
			a.party_slot = to_index
		if b:
			b.party_slot = from_index
	elif from_kind == "bed" and to_kind == "bed":
		var moved := stable[from_index]
		stable[from_index] = stable[to_index]
		stable[to_index] = moved
	elif from_kind == "bed":
		_bed_to_party(from_index, to_index)
	else:
		var pet := world.get_party_pet(peer_id, from_index)
		if pet == null:
			return
		if stable[to_index].is_empty():
			stable[to_index] = pet.to_data()
			pet.queue_free()
		else:
			_bed_to_party(to_index, from_index)
	_push_stable()


## Releases the pet in a bed or party slot back into the wild.
@rpc("any_peer", "call_local", "reliable")
func request_stable_release(kind: String, index: int) -> void:
	if not _can_use_stable() or not _valid_place(kind, index):
		return
	var species_index := -1
	if kind == "bed" and not stable[index].is_empty():
		species_index = stable[index].species
		stable[index] = {}
	elif kind == "party":
		var pet := world.get_party_pet(peer_id, index)
		if pet:
			species_index = pet.species_index
			pet.queue_free()
	if species_index < 0:
		return
	_push_stable()
	world.tell(peer_id, "You released your %s back into the wild." % SpeciesDB.get_species(species_index).display_name,
			Color(0.8, 0.8, 0.8))


# --- Server-side -----------------------------------------------------------------

func receive_damage(amount: float, source: Node3D, _knockback := Vector3.ZERO) -> void:
	if downed:
		return
	if source and not Combat.are_enemies(source, self):
		return  # no friendly fire
	_since_hit = 0.0
	health.take_damage(amount * (1.0 - armor_percent() / 100.0))
	_flash.rpc()


## Server: out of combat, health slowly comes back.
func _regenerate(delta: float) -> void:
	_since_hit += delta
	if not downed and _since_hit >= regen_delay and health.current < health.max_health:
		health.heal(health.max_health * regen_rate * delta)


func poison(dps: float, duration: float) -> void:
	health.add_poison(dps, duration)


func add_shield(amount: float, duration: float) -> void:
	health.add_shield(amount, duration)


## Server: slows this player. Movement runs on the owning client, so it is applied there.
func slow(duration: float, factor: float) -> void:
	_apply_slow.rpc_id(peer_id, duration, factor)


func _on_died() -> void:
	downed = true
	world.announce.rpc("%s is down!" % display_name, Color(1, 0.45, 0.4))
	await get_tree().create_timer(respawn_time).timeout
	if not is_inside_tree():
		return
	health.current = health.max_health
	downed = false
	_respawn_at.rpc_id(peer_id, world.respawn_point(peer_id))


func _can_use_stable() -> bool:
	if not _sent_by_owner():
		return false
	if not world.is_near_stable(global_position):
		world.tell(peer_id, "You need to be at the stable.", Color(1, 0.8, 0.5))
		return false
	return true


func _push_stable() -> void:
	_sync_stable.rpc_id(peer_id, stable)


func _sent_by_owner() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	return multiplayer.is_server() and sender == peer_id


func _sent_by_server() -> bool:
	return multiplayer.get_remote_sender_id() <= 1


# --- Server -> clients -------------------------------------------------------------

@rpc("any_peer", "call_local", "unreliable")
func _show_swing(aim: Vector3) -> void:
	if not _sent_by_server() or is_multiplayer_authority():
		return  # the owner already played it locally
	model.rotation.y = atan2(-aim.x, -aim.z)
	_play_swing_fx()


@rpc("any_peer", "call_local", "unreliable")
func _flash() -> void:
	if not _sent_by_server():
		return
	_material.albedo_color = Color.WHITE
	create_tween().tween_property(_material, "albedo_color", color, 0.15)


@rpc("any_peer", "call_local", "reliable")
func _apply_slow(duration: float, factor: float) -> void:
	if _sent_by_server():
		_slow_timer = maxf(_slow_timer, duration)
		_slow_factor = factor
		_material.albedo_color = color.lerp(Color(0.7, 0.9, 1.0), 0.6)
		create_tween().tween_property(_material, "albedo_color", color, duration)


## Starts (or refreshes) Lucky Lemonade on every peer, so the owner's HUD and the
## server's capture roll agree.
@rpc("any_peer", "call_local", "reliable")
func _boost_started(duration: float) -> void:
	if _sent_by_server():
		_boost_timer = duration


@rpc("any_peer", "call_local", "reliable")
func _respawn_at(point: Vector3) -> void:
	if _sent_by_server():
		global_position = point
		velocity = Vector3.ZERO


# --- Gear ------------------------------------------------------------------------

## Percent less damage taken, from everything worn (capped).
func armor_percent() -> int:
	var total := 0
	for slot in equipment:
		total += ItemDB.armor(equipment[slot])
	return mini(total, ItemDB.MAX_ARMOR)


func first_empty_bag_place() -> int:
	for i in bag.size():
		if bag[i].is_empty():
			return i
	return -1


## Server: puts a found item in the bag. False if the bag is full.
func add_item(item: Dictionary) -> bool:
	var place := first_empty_bag_place()
	if place < 0:
		return false
	bag[place] = item
	_push_inventory()
	return true


## Wears the item in bag place `index`; whatever was in that slot goes back in its place.
@rpc("any_peer", "call_local", "reliable")
func request_equip(index: int) -> void:
	if not _sent_by_owner() or index < 0 or index >= bag.size() or bag[index].is_empty():
		return
	var item := bag[index]
	var slot := ItemDB.slot_of(item)
	if slot == "":
		return
	bag[index] = equipment[slot]
	equipment[slot] = item
	_gear_changed()


@rpc("any_peer", "call_local", "reliable")
func request_unequip(slot: String) -> void:
	if not _sent_by_owner() or not equipment.has(slot) or equipment[slot].is_empty() or slot == "weapon":
		return
	var place := first_empty_bag_place()
	if place < 0:
		world.tell(peer_id, "Your bag is full.", Color(1, 0.8, 0.5))
		return
	bag[place] = equipment[slot]
	equipment[slot] = {}
	_gear_changed()


@rpc("any_peer", "call_local", "reliable")
func request_discard(index: int) -> void:
	if not _sent_by_owner() or index < 0 or index >= bag.size() or bag[index].is_empty():
		return
	world.tell(peer_id, "You threw away the %s." % ItemDB.display_name(bag[index]), Color(0.8, 0.8, 0.8))
	bag[index] = {}
	_push_inventory()


func _gear_changed() -> void:
	var jacket: Dictionary = equipment.chest
	jacket_level = int(jacket.level) if not jacket.is_empty() else 0
	_push_inventory()


func _push_inventory() -> void:
	_sync_inventory.rpc_id(peer_id, bag, equipment)


@rpc("any_peer", "call_local", "reliable")
func _sync_inventory(new_bag: Array, new_equipment: Dictionary) -> void:
	if not _sent_by_server():
		return
	if not multiplayer.is_server():  # the server already holds the real ones
		bag.assign(new_bag)
		equipment = new_equipment
	inventory_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func _sync_stable(data: Array) -> void:
	if not _sent_by_server():
		return
	if not multiplayer.is_server():  # the server already holds the real list
		stable.assign(data)  # typed arrays arrive untyped over RPC
	stable_changed.emit()


# --- Local helpers -----------------------------------------------------------------

func _record_trail() -> void:
	var at := global_position
	if trail.is_empty() or Vector2(at.x - trail[-1].x, at.z - trail[-1].z).length() >= TRAIL_STEP:
		trail.append(at)
		if trail.size() > TRAIL_LENGTH:
			trail.pop_front()


## Converts 2D input into a world direction relative to the camera, so "up" is
## always up-screen regardless of the isometric yaw.
func _camera_relative(input: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null or input == Vector2.ZERO:
		return Vector3.ZERO
	var right := cam.global_basis.x
	var forward := -cam.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return (right.normalized() * input.x - forward.normalized() * input.y).normalized() * minf(input.length(), 1.0)


## Aims toward where the mouse ray hits the ground plane, and finds the hovered creature.
func _update_aim() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var ground := Plane(Vector3.UP, global_position.y)
	var hit = ground.intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	if hit == null:
		return
	_aim_point = hit
	hovered_creature = world.creature_near(hit)
	var to: Vector3 = hit - global_position
	to.y = 0.0
	if to.length() > 0.1:
		_aim_dir = to.normalized()


func _apply_downed() -> void:
	var tween := create_tween()
	tween.tween_property(model, "rotation:x", -PI / 2.0 if downed else 0.0, 0.3)


func _play_swing_fx() -> void:
	person.swing(attack_cooldown * 0.7)
	_swing_fx.visible = true
	_swing_fx.scale = Vector3(0.6, 1.0, 0.6)
	var tween := create_tween()
	tween.tween_property(_swing_fx, "scale", Vector3.ONE, 0.08)
	tween.tween_callback(_swing_fx.hide).set_delay(0.05)


## Builds a flat fan mesh matching the attack arc, so the visual always
## matches the exported range/arc values.
func _build_swing_fx() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 16
	var half_arc := deg_to_rad(attack_arc_degrees) * 0.5
	for i in segments:
		var a0 := lerpf(-half_arc, half_arc, float(i) / segments)
		var a1 := lerpf(-half_arc, half_arc, float(i + 1) / segments)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(-sin(a0), 0.0, -cos(a0)) * attack_range)
		st.add_vertex(Vector3(-sin(a1), 0.0, -cos(a1)) * attack_range)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.95, 0.8, 0.18)  # a faint swoosh behind the bat
	var fx := MeshInstance3D.new()
	fx.mesh = st.commit()
	fx.material_override = mat
	fx.position.y = 0.1
	fx.visible = false
	return fx
