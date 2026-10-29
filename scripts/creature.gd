class_name Creature
extends CharacterBody3D
## A creature that roams wild until a player captures it; from then on it
## follows and fights for that player as a pet. Every creature in the world can
## be captured. All AI and combat run on the server; clients only see
## replicated state (position, health, owner, level...).

const WILD_LAYER := 4  # physics layer 3
const PET_LAYER := 8  # physics layer 4
const WILD_MASK := 1 | 2 | 4 | 8
const PET_MASK := 1 | 4  # pets don't block players or each other
## How long a queued ability waits for the pet to get in range before giving up.
const CAST_TIMEOUT := 3.0

@export var follow_distance := 2.2
@export var leash_range := 24.0
@export var assist_range := 10.0
@export var wander_radius := 6.0
@export var faint_time := 8.0

# Set by the spawn function before entering the tree.
var species_index := 0
var home := Vector3.ZERO

# Replicated state.
var owner_id := 0:  # 0 = wild, World.RIVAL_ID = the rival's pet, otherwise the owning player's peer id
	set(v):
		owner_id = v
		if is_node_ready():
			_apply_ownership()
## Position in the owner's party (0..MAX_PARTY-1); selects the ability key. -1 when wild.
var party_slot := -1
var level := 1:
	set(v):
		level = v
		if is_node_ready():
			_refresh_label()
var xp := 0
var fainted := false:
	set(v):
		fainted = v
		if is_node_ready():
			_apply_faint()

var species: CreatureSpecies

# Server-only AI state.
var target: Node3D
var focus: Node3D  ## Target the owner explicitly ordered this pet to attack.
var _attack_timer := 0.0
var _wander_timer := 0.0
var _wander_point := Vector3.ZERO
var _knockback := Vector3.ZERO
var _faint_timer := 0.0
var _stun_timer := 0.0
var _guard_timer := 0.0
var _guard_reduction := 0.0
var _slow_timer := 0.0
var _slow_factor := 1.0
var _reflect_timer := 0.0
var _reflect_fraction := 0.0
var _blind_timer := 0.0
var _weaken_timer := 0.0
var _weaken_factor := 1.0
var _leaping := false
var _pending_cast := {}  ## { point, target, time_left } while moving into ability range.
var _stats_timer := 0.0
var _ai_cast_delay := 3.0  ## Rival pets: time until they next consider using their ability.
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## Local clock time when the ability is ready again. Set on every peer by _ability_used.
var _ability_ready_time := 0.0
var _material := StandardMaterial3D.new()

@onready var world: World = get_tree().get_first_node_in_group("world")
@onready var health: Health = $Health
@onready var model: Node3D = $Model
@onready var body: MeshInstance3D = $Model/Body
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var ring: MeshInstance3D = $Ring
@onready var overhead: Node3D = $Overhead
@onready var name_label: Label3D = $Overhead/NameLabel
@onready var bar_fg: MeshInstance3D = $Overhead/BarFg


func _ready() -> void:
	add_to_group("creatures")
	species = SpeciesDB.get_species(species_index)
	_build_visuals()
	health.changed.connect(_on_health_changed)
	if multiplayer.is_server():
		_apply_level_stats()
		health.current = health.max_health
		health.died.connect(_on_died)
		_wander_point = home
		_wander_timer = randf() * 3.0
	_apply_ownership()
	_apply_faint()
	_on_health_changed(health.current, health.max_health)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		overhead.global_basis = cam.global_basis


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_stats_timer -= delta
	if _stats_timer <= 0.0:
		_stats_timer = 1.0
		_refresh_max_health()
	if fainted:
		_tick_faint(delta)
		return
	if _leaping:
		return  # position is driven by the leap tween
	_attack_timer -= delta
	_guard_timer -= delta
	_slow_timer -= delta
	_reflect_timer -= delta
	_blind_timer -= delta
	_weaken_timer -= delta
	# Targets can be freed at any time (killed, captured owner left...).
	if not is_instance_valid(target):
		target = null
	if not is_instance_valid(focus):
		focus = null

	var desired := Vector3.ZERO
	if _stun_timer > 0.0:
		_stun_timer -= delta
	elif is_wild():
		desired = _wild_ai(delta)
	elif is_rival_pet():
		desired = _rival_pet_ai(delta)
	else:
		desired = _pet_ai(delta)
	if _slow_timer > 0.0:
		desired *= _slow_factor
	velocity.x = desired.x + _knockback.x
	velocity.z = desired.z + _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, 40.0 * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()


# --- Queries (safe on any peer) ------------------------------------------------

func is_wild() -> bool:
	return owner_id == 0


func is_player_pet() -> bool:
	return owner_id > 0


func is_rival_pet() -> bool:
	return owner_id == World.RIVAL_ID


func is_targetable() -> bool:
	return not fainted and not health.is_dead() and not is_queued_for_deletion()


func radius() -> float:
	return 0.45 * species.size


func get_damage() -> float:
	return species.damage * _level_multiplier() * (1.0 + skill_bonus("damage")) \
			* (_weaken_factor if _weaken_timer > 0.0 else 1.0)


## The total boost to `stat` ("damage", "health" or "armor") from passive skills:
## this pet's own, plus the pack skills of every awake pet in the same party.
func skill_bonus(stat: String) -> float:
	if is_wild() or species == null:
		return 0.0
	var bonus := PetSkills.total(species_index, level, stat)
	if world:
		for ally in world.get_pets(owner_id):
			if not ally.fainted:
				bonus += PetSkills.total(ally.species_index, ally.level, "pack_" + stat)
	return minf(bonus, PetSkills.MAX_ARMOR) if stat == "armor" else bonus


func xp_to_next() -> int:
	return 20 * level


## Chance (0..1) that a capture attempt succeeds. Zero at full health.
## `boost` multiplies it (Lucky Lemonade); it never goes above 95%.
func capture_chance(boost := 1.0) -> float:
	var missing := 1.0 - health.fraction()
	return clampf(species.catch_rate * missing * 1.6 / (1.0 + 0.1 * (level - 1)) * boost, 0.0, 0.95)


func ability_cooldown_left() -> float:
	return maxf(_ability_ready_time - _now(), 0.0)


## Data needed to recreate this pet later (used by the stable).
func to_data() -> Dictionary:
	return {"species": species_index, "level": level, "xp": xp}


# --- Server-side actions ---------------------------------------------------------

func receive_damage(amount: float, source: Node3D, knockback := Vector3.ZERO) -> void:
	if not is_targetable():
		return
	if source and not Combat.are_enemies(source, self):
		return  # no friendly fire
	amount *= 1.0 - skill_bonus("armor")
	if _guard_timer > 0.0:
		amount *= 1.0 - _guard_reduction
		knockback = Vector3.ZERO
	_knockback = knockback
	health.take_damage(amount)
	_flash.rpc()
	# Reflected damage has no source, so it can't bounce back again.
	if _reflect_timer > 0.0 and source and is_instance_valid(source):
		source.receive_damage(amount * _reflect_fraction, null)
	if health.is_dead():
		return
	# Fight back against whoever hit us (wild creatures retaliate, pets defend themselves).
	if source and _is_valid_target(source) and (is_wild() or target == null) and _pending_cast.is_empty():
		target = source


func tame(new_owner: int, slot: int) -> void:
	owner_id = new_owner
	party_slot = slot
	target = null
	focus = null
	_stun_timer = 0.0
	_knockback = Vector3.ZERO
	health.current = maxf(health.current, health.max_health * 0.5)


## The rival was defeated: its pet goes wild, weakened, ready to be captured.
func release_to_wild() -> void:
	owner_id = 0
	party_slot = -1
	fainted = false
	target = null
	focus = null
	_pending_cast = {}
	home = global_position
	health.current = health.max_health * 0.3


func on_capture_failed(player: Node3D) -> void:
	target = player


## Pet command from the owner: attack `new_focus`, or regroup if null.
func set_focus(new_focus: Node3D) -> void:
	focus = new_focus
	target = new_focus
	_pending_cast = {}


## Owner asked this pet to use its ability at `point` (optionally on `cast_target`).
## Returns an error message, or "" if the cast was queued.
func queue_ability(point: Vector3, cast_target: Creature) -> String:
	var ability := species.ability
	if ability == null:
		return "Your %s has no ability." % species.display_name
	if fainted:
		return "Your %s has fainted." % species.display_name
	if ability_cooldown_left() > 0.0:
		return "%s is recharging (%.1fs)." % [ability.display_name, ability_cooldown_left()]
	var reason := ability.cannot_cast_reason(self)
	if reason != "":
		return reason
	if ability.needs_target:
		if cast_target == null or not _is_valid_target(cast_target):
			cast_target = world.nearest_enemy(self, point, 4.0)
		if cast_target == null:
			return "%s needs a wild creature to target." % ability.display_name
	_pending_cast = {"point": point, "target": cast_target, "time_left": CAST_TIMEOUT}
	return ""


func stun(duration: float) -> void:
	_stun_timer = maxf(_stun_timer, duration)
	_status_fx.rpc("stun", duration)


## Movement speed is multiplied by `factor` for `duration` seconds (0 = rooted).
func slow(duration: float, factor: float) -> void:
	_slow_timer = maxf(_slow_timer, duration)
	_slow_factor = factor
	_status_fx.rpc("root" if factor <= 0.0 else "slow", duration)


## Half of this creature's attacks miss for `duration` seconds.
func blind(duration: float) -> void:
	_blind_timer = maxf(_blind_timer, duration)
	_status_fx.rpc("blind", duration)


## This creature deals `factor` times its normal damage for `duration` seconds.
func weaken(duration: float, factor: float) -> void:
	_weaken_timer = maxf(_weaken_timer, duration)
	_weaken_factor = factor
	_status_fx.rpc("weaken", duration)


func poison(dps: float, duration: float) -> void:
	health.add_poison(dps, duration)
	_status_fx.rpc("poison", duration)


func add_shield(amount: float, duration: float) -> void:
	health.add_shield(amount, duration)
	_status_fx.rpc("shield", duration)


## Yanked to `point` (e.g. by a Bogleon's tongue).
func pull_to(point: Vector3, duration := 0.2) -> void:
	_pending_cast = {}
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position", world.clamp_to_level(point), duration)


func reflect(duration: float, fraction: float) -> void:
	_reflect_timer = duration
	_reflect_fraction = fraction
	_status_fx.rpc("reflect", duration)


func guard(duration: float, reduction: float) -> void:
	_guard_timer = duration
	_guard_reduction = reduction
	_status_fx.rpc("guard", duration)


## Forces a wild creature to attack `taunter`.
func taunt(taunter: Node3D) -> void:
	if is_wild() and _is_valid_target(taunter):
		target = taunter


## Moves to `point` in an arc over `duration`, then calls `on_land`.
func leap_to(point: Vector3, duration: float, on_land: Callable) -> void:
	_leaping = true
	_leap_fx.rpc(duration)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position", point, duration)
	tween.tween_callback(func() -> void:
		_leaping = false
		on_land.call())


func gain_xp(amount: int) -> void:
	if is_wild():
		return
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		_apply_level_stats()
		health.current = health.max_health
		world.tell(owner_id, "Your %s grew to level %d!" % [species.display_name, level], Color(0.6, 0.85, 1.0))
		var skill := PetSkills.unlocked_at(species_index, level)
		if not skill.is_empty():
			world.tell(owner_id, "Your %s learned %s" % [species.display_name, PetSkills.describe(skill)],
					Color(1.0, 0.85, 0.4))


# --- AI (server only) ----------------------------------------------------------

func _wild_ai(delta: float) -> Vector3:
	if target and (not _is_valid_target(target) or _flat_distance(target.global_position) > leash_range):
		target = null
	if target == null and species.aggressive:
		target = _nearest_hostile(species.aggro_range)
	if target:
		return _chase_and_attack(target)

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(2.0, 5.0)
		var offset := Vector2.from_angle(randf() * TAU) * randf() * wander_radius
		_wander_point = home + Vector3(offset.x, 0.0, offset.y)
	return _steer_to(_wander_point, species.move_speed * 0.4)


func _pet_ai(delta: float) -> Vector3:
	var master_player := world.get_tamer(owner_id)
	if master_player == null:
		return Vector3.ZERO
	if _flat_distance(master_player.global_position) > leash_range:
		global_position = master_player.global_position + _follow_offset()
		target = null
		focus = null
		_pending_cast = {}
		return Vector3.ZERO

	if not _pending_cast.is_empty():
		return _tick_pending_cast(delta)

	# Passive stance: never attack (so the owner can weaken a creature and capture
	# it), just stay close. Abilities the owner triggers still go through above.
	if master_player is Player and master_player.pets_passive:
		target = null
		focus = null
		return _steer_to(master_player.global_position + _follow_offset(), _follow_speed(master_player))

	if focus and not _is_valid_target(focus):
		focus = null
	if focus:
		target = focus
	elif target == null or not _is_valid_target(target) \
			or target.global_position.distance_to(master_player.global_position) > assist_range * 1.5:
		target = _threat_to(master_player)
	if target:
		return _chase_and_attack(target)

	return _steer_to(master_player.global_position + _follow_offset(), _follow_speed(master_player))


## Pets amble near their owner but run to catch up when left behind, at least
## as fast as the owner moves, so they keep up with a running tamer.
func _follow_speed(master_player: Node3D) -> float:
	if _flat_distance(master_player.global_position + _follow_offset()) <= 3.0:
		return species.move_speed
	var owner_speed: float = master_player.get("move_speed") if master_player.get("move_speed") != null else 0.0
	return maxf(species.move_speed * 1.6, owner_speed * 1.1)


## The rival's pet stays by the rival until the fight starts, then attacks the
## nearest player or pet and uses its ability whenever it is ready.
func _rival_pet_ai(delta: float) -> Vector3:
	var rival := world.get_tamer(owner_id) as Rival
	if rival == null:
		return Vector3.ZERO
	if not _pending_cast.is_empty():
		return _tick_pending_cast(delta)
	if not rival.engaged:
		return _steer_to(rival.global_position + _follow_offset(), species.move_speed)
	if not _is_valid_target(target) or target.global_position.distance_to(rival.home) > rival.leash_range + 4.0:
		target = _nearest_hostile(rival.leash_range + 4.0)
	if target == null:
		return _steer_to(rival.global_position + _follow_offset(), species.move_speed)
	_ai_cast_delay -= delta
	if _ai_cast_delay <= 0.0 and ability_cooldown_left() <= 0.0:
		_ai_cast_delay = randf_range(1.0, 3.0)
		queue_ability(target.global_position, target as Creature)
	return _chase_and_attack(target)


## Moves into range of a queued ability, then casts it.
func _tick_pending_cast(delta: float) -> Vector3:
	var ability := species.ability
	var cast_target: Creature = _pending_cast.target
	_pending_cast.time_left -= delta
	if _pending_cast.time_left <= 0.0 or (ability.needs_target and not _is_valid_target(cast_target)):
		_pending_cast = {}
		return Vector3.ZERO
	var point: Vector3 = cast_target.global_position if cast_target else _pending_cast.point
	if ability.cast_range > 0.0 and _flat_distance(point) > ability.cast_range:
		return _steer_to(point, species.move_speed * 1.3)

	_pending_cast = {}
	if _flat_distance(point) > 0.1:
		model.rotation.y = atan2(-(point.x - global_position.x), -(point.z - global_position.z))
	_ability_used.rpc(ability.cooldown)
	ability.execute(self, point, cast_target)
	return Vector3.ZERO


func _chase_and_attack(victim: Node3D) -> Vector3:
	var to := victim.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.01:
		return Vector3.ZERO
	model.rotation.y = atan2(-to.x, -to.z)
	var victim_radius: float = victim.radius() if victim.has_method("radius") else 0.4
	if dist > species.attack_range * species.size + victim_radius:
		return to / dist * species.move_speed
	if _attack_timer <= 0.0:
		_attack_timer = species.attack_cooldown
		_lunge.rpc()
		if _blind_timer > 0.0 and randf() < 0.5:
			return Vector3.ZERO  # blinded: the attack misses
		victim.receive_damage(get_damage(), self, to / dist * 3.0)
	return Vector3.ZERO


func _steer_to(point: Vector3, speed: float) -> Vector3:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.6:
		return Vector3.ZERO
	model.rotation.y = atan2(-to.x, -to.z)
	return to.normalized() * speed


## Wild creatures attack players and pets.
func _nearest_hostile(max_range: float) -> Node3D:
	var best: Node3D = null
	var best_dist := max_range
	var candidates: Array[Node3D] = []
	candidates.append_array(world.get_players())
	candidates.append_array(world.get_all_pets())
	for c in candidates:
		var d := _flat_distance(c.global_position)
		if d < best_dist and _is_valid_target(c):
			best = c
			best_dist = d
	return best


## Pets defend: the nearest enemy (wild creature, rival or rival pet) that is
## fighting the owner or the owner's pets.
func _threat_to(master_player: Node3D) -> Node3D:
	var best: Node3D = null
	var best_dist := assist_range
	for enemy in world.get_hostiles():
		var enemy_target = enemy.get("target")
		if not is_instance_valid(enemy_target) or not _is_valid_target(enemy):
			continue
		var on_our_side: bool = enemy_target == master_player \
				or (enemy_target is Creature and enemy_target.owner_id == owner_id)
		var d := enemy.global_position.distance_to(master_player.global_position)
		if on_our_side and d < best_dist:
			best = enemy
			best_dist = d
	return best


## Valid targets are alive and on the other side. This is what makes pets drop a
## target the moment it is captured by anyone.
func _is_valid_target(node: Node3D) -> bool:
	return is_instance_valid(node) and Combat.are_enemies(self, node) and node.is_targetable()


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _follow_offset() -> Vector3:
	var angle := 2.4 + maxi(party_slot, 0) * TAU / Player.MAX_PARTY
	return Vector3(cos(angle), 0.0, sin(angle)) * follow_distance


func _tick_faint(delta: float) -> void:
	_faint_timer -= delta
	if _faint_timer > 0.0:
		return
	var master_player := world.get_tamer(owner_id)
	if master_player:
		global_position = master_player.global_position + _follow_offset()
	health.current = health.max_health * 0.5
	fainted = false


func _on_died() -> void:
	if is_wild():
		world.award_xp(self)
		world.play_burst.rpc(global_position, species.color, 2.5)
		queue_free()
	else:
		fainted = true
		_faint_timer = faint_time
		target = null
		focus = null
		_pending_cast = {}
		world.tell(owner_id, "Your %s fainted! It recovers in %ds." % [species.display_name, int(faint_time)], Color(1, 0.6, 0.4))


func _apply_level_stats() -> void:
	health.max_health = roundf(species.max_health * _level_multiplier() * (1.0 + skill_bonus("health")))


## Pack health skills come and go as pets join, faint and wake up: keep max
## health current, scaling health with it so the bar stays at the same fraction.
func _refresh_max_health() -> void:
	var old_max := health.max_health
	_apply_level_stats()
	if not is_equal_approx(old_max, health.max_health) and old_max > 0.0 and health.current > 0.0:
		health.current = health.current * health.max_health / old_max


func _level_multiplier() -> float:
	return 1.0 + 0.15 * (level - 1)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Visuals (all peers) ---------------------------------------------------------

func _build_visuals() -> void:
	_material.albedo_color = species.color
	CreatureModel.build(body, species.body_type, _material, species.color, species.feature)
	model.scale = Vector3.ONE * species.size
	ring.scale = Vector3.ONE * species.size
	var shape := SphereShape3D.new()
	shape.radius = radius()
	collision.shape = shape
	collision.position.y = radius()
	overhead.position.y = 0.9 * species.size + 0.5


func _apply_ownership() -> void:
	collision_layer = 0 if fainted else (PET_LAYER if is_player_pet() else WILD_LAYER)
	collision_mask = PET_MASK if is_player_pet() else WILD_MASK
	ring.visible = not is_wild()
	var bar_mat := bar_fg.material_override as StandardMaterial3D
	bar_mat.albedo_color = Color(0.3, 0.9, 0.35) if is_player_pet() else Color(0.9, 0.25, 0.2)
	if not is_wild():
		var master_player = world.get_tamer(owner_id) if world else null  # Player or Rival
		var color: Color = master_player.color if master_player else Color.WHITE
		(ring.material_override as StandardMaterial3D).albedo_color = color
	_refresh_label()


func _apply_faint() -> void:
	_apply_ownership()
	body.rotation.z = PI / 2.0 if fainted else 0.0
	_material.albedo_color = species.color.darkened(0.6) if fainted else species.color


func _refresh_label() -> void:
	if species == null:
		return
	name_label.text = "%s  Lv%d" % [species.display_name, level]
	var master_player = world.get_tamer(owner_id) if world and not is_wild() else null  # Player or Rival
	name_label.modulate = master_player.color.lightened(0.3) if master_player else Color.WHITE


func _on_health_changed(current: float, maximum: float) -> void:
	var pct := clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	bar_fg.scale.x = maxf(pct, 0.001)
	bar_fg.position.x = -(1.0 - pct) * 0.5


@rpc("authority", "call_local", "unreliable")
func _flash() -> void:
	if fainted:
		return
	_material.albedo_color = Color.WHITE
	create_tween().tween_property(_material, "albedo_color", species.color, 0.15)


@rpc("authority", "call_local", "unreliable")
func _lunge() -> void:
	var tween := create_tween()
	tween.tween_property(body, "position:z", -0.25, 0.06)
	tween.tween_property(body, "position:z", 0.0, 0.12)


@rpc("authority", "call_local", "reliable")
func _ability_used(cooldown: float) -> void:
	_ability_ready_time = _now() + cooldown
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3.ONE * species.size * 1.25, 0.08)
	tween.tween_property(model, "scale", Vector3.ONE * species.size, 0.15)


@rpc("authority", "call_local", "unreliable")
func _leap_fx(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(model, "position:y", 1.5, duration * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(model, "position:y", 0.0, duration * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## Temporary status visuals: bubbles for "guard", "reflect" and "shield";
## rings at the feet for "slow", "root", "poison" and "weaken"; a spinning
## halo for "stun" and "blind".
@rpc("authority", "call_local", "unreliable")
func _status_fx(kind: String, duration: float) -> void:
	var fx := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bubble_colors := {
		"guard": Color(0.4, 0.7, 1.0, 0.3), "reflect": Color(0.85, 0.95, 1.0, 0.45), "shield": Color(1.0, 0.85, 0.3, 0.35),
	}
	var ring_colors := {
		"slow": Color(0.55, 0.85, 1.0, 0.8), "root": Color(0.45, 0.32, 0.18, 0.95),
		"poison": Color(0.45, 0.95, 0.3, 0.8), "weaken": Color(0.7, 0.35, 0.85, 0.8),
	}
	if kind in bubble_colors:
		var sphere := SphereMesh.new()
		sphere.radius = radius() * 1.8
		sphere.height = radius() * 3.6
		fx.mesh = sphere
		fx.position.y = radius()
		mat.albedo_color = bubble_colors[kind]
	elif kind in ring_colors:
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = radius() * 1.1
		ring_mesh.outer_radius = radius() * 1.5
		fx.mesh = ring_mesh
		fx.position.y = 0.08
		mat.albedo_color = ring_colors[kind]
	else:
		var halo := TorusMesh.new()
		halo.inner_radius = 0.25
		halo.outer_radius = 0.35
		fx.mesh = halo
		fx.position.y = overhead.position.y - 0.25
		mat.albedo_color = Color(1.0, 0.95, 0.6, 0.9) if kind == "blind" else Color(1.0, 0.9, 0.3, 0.9)
		fx.create_tween().set_loops(ceili(duration / 0.5)).tween_property(fx, "rotation:y", TAU, 0.5).from(0.0)
	fx.material_override = mat
	add_child(fx)
	get_tree().create_timer(duration).timeout.connect(fx.queue_free)
