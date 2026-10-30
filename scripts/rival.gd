class_name Rival
extends CharacterBody3D
## An AI tamer waiting at the end of each level with one pet. It challenges the
## players when they get close; defeating it opens the exit portal.
## Runs on the server; clients see replicated state.

@export var move_speed := 4.5
@export var attack_range := 1.6
@export var attack_cooldown := 1.1
@export var engage_range := 14.0
## The rival never strays further than this from its spot in the arena.
@export var leash_range := 15.0

# Set by the spawn function before entering the tree.
var display_name := "Rival"
var color := Color(0.85, 0.2, 0.25)
var level_number := 1
var home := Vector3.ZERO

# Replicated.
var engaged := false

var target: Node3D
var _attack_timer := 0.0
var _slow_timer := 0.0
var _slow_factor := 1.0
var _blind_timer := 0.0
var _weaken_timer := 0.0
var _weaken_factor := 1.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _material := StandardMaterial3D.new()

@onready var world: World = get_tree().get_first_node_in_group("world")
@onready var health: Health = $Health
@onready var model: Node3D = $Model
@onready var overhead: Node3D = $Overhead
@onready var name_label: Label3D = $Overhead/NameLabel
@onready var bar_fg: MeshInstance3D = $Overhead/BarFg


func _ready() -> void:
	add_to_group("rivals")
	_material.albedo_color = color
	$Model/Body.material_override = _material
	name_label.text = title()
	health.changed.connect(_on_health_changed)
	if multiplayer.is_server():
		health.max_health = roundf(_max_health() * power_scale())
		health.current = health.max_health
		health.died.connect(_on_died)
	_on_health_changed(health.current, health.max_health)
	# The pet may have been replicated before this node; refresh its ring/label colour.
	for c: Creature in world.creatures_root.get_children():
		if c.is_rival_pet() and c.is_node_ready():
			c._apply_ownership()


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		overhead.global_basis = cam.global_basis


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or health.is_dead():
		return
	_attack_timer -= delta
	_slow_timer -= delta
	_blind_timer -= delta
	_weaken_timer -= delta
	var desired := Vector3.ZERO
	if _is_busy():
		_boss_tick(delta)
		return  # mid special move (e.g. burrowed): the move drives the position
	if not engaged:
		for p in world.get_players():
			if p.is_targetable() and _flat_distance(p.global_position) < engage_range:
				_engage()
	else:
		if not _is_valid_target(target) or target.global_position.distance_to(home) > leash_range:
			target = _nearest_enemy()
		desired = _chase_and_attack(target) if target else _steer_to(home)
		_boss_tick(delta)
	if _slow_timer > 0.0:
		desired *= _slow_factor
	velocity.x = desired.x
	velocity.z = desired.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()


## Name shown above the boss and in messages.
func title() -> String:
	return "Rival %s" % display_name


## How the boss is referred to in sentences ("Defeat Rival Kael", "Defeat the Glacier Titan").
func objective_name() -> String:
	return title()


func is_targetable() -> bool:
	return not health.is_dead() and not is_queued_for_deletion()


func radius() -> float:
	return 0.45


func attack_damage() -> float:
	return 6.0 + 2.0 * (level_number - 1)


func slow(duration: float, factor: float) -> void:
	_slow_timer = maxf(_slow_timer, duration)
	_slow_factor = factor


func blind(duration: float) -> void:
	_blind_timer = maxf(_blind_timer, duration)


func weaken(duration: float, factor: float) -> void:
	_weaken_timer = maxf(_weaken_timer, duration)
	_weaken_factor = factor


func poison(dps: float, duration: float) -> void:
	health.add_poison(dps, duration)


## Damage this boss deals after debuffs (Spore Cloud's weaken). Bosses' special
## attacks should pass their damage through this too.
func outgoing(amount: float) -> float:
	return amount * damage_scale() * (_weaken_factor if _weaken_timer > 0.0 else 1.0)


## How much tougher this boss is than its base numbers, matched to the pets
## players bring by now: each area's creatures are five levels higher than the
## last (see World.area_levels), so its boss's health follows the creature
## level multiplier at the top of the area (compared to what the base numbers
## were tuned for).
func power_scale() -> float:
	var top := World.area_levels(level_number).y
	var tuned_for := 2 * level_number + 2
	return (1.0 + 0.15 * (top - 1)) / (1.0 + 0.15 * (tuned_for - 1))


## Bosses hit harder too, but only half as much more, as the tamer's own health
## doesn't grow with levels.
func damage_scale() -> float:
	return 1.0 + (power_scale() - 1.0) * 0.5


## True during a special move that controls the boss's position (no chasing).
func _is_busy() -> bool:
	return false


## Called when a basic attack lands. Bosses override it for on-hit effects.
func _on_attack_hit(_victim: Node3D) -> void:
	pass


func _max_health() -> float:
	return 160.0 + 60.0 * (level_number - 1)


## Extra behaviour while engaged. Bosses override this with their special attacks.
func _boss_tick(_delta: float) -> void:
	pass


func _challenge_text() -> String:
	return "%s challenges you!" % title()


func receive_damage(amount: float, source: Node3D, _knockback := Vector3.ZERO) -> void:
	if not is_targetable():
		return
	if source and not Combat.are_enemies(source, self):
		return
	health.take_damage(amount)
	_flash.rpc()
	if not engaged:
		_engage()
	if not _is_valid_target(target) and _is_valid_target(source):
		target = source


func _engage() -> void:
	engaged = true
	world.announce.rpc(_challenge_text(), color.lightened(0.3))


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for node in world.enemies_near(self, home, leash_range):
		var d := _flat_distance(node.global_position)
		if d < best_dist:
			best = node
			best_dist = d
	return best


func _chase_and_attack(victim: Node3D) -> Vector3:
	var to := victim.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.01:
		return Vector3.ZERO
	model.rotation.y = atan2(-to.x, -to.z)
	if dist > attack_range + victim.radius():
		return to / dist * move_speed
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_swing.rpc()
		if _blind_timer > 0.0 and randf() < 0.5:
			return Vector3.ZERO  # blinded: the attack misses
		victim.receive_damage(outgoing(attack_damage()), self, to / dist * 4.0)
		_on_attack_hit(victim)
	return Vector3.ZERO


func _steer_to(point: Vector3) -> Vector3:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.5:
		return Vector3.ZERO
	model.rotation.y = atan2(-to.x, -to.z)
	return to.normalized() * move_speed


func _is_valid_target(node: Node3D) -> bool:
	return is_instance_valid(node) and Combat.are_enemies(self, node) and node.is_targetable()


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _on_died() -> void:
	world.on_rival_defeated(self)
	queue_free()


func _on_health_changed(current: float, maximum: float) -> void:
	var pct := clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	bar_fg.scale.x = maxf(pct, 0.001)
	bar_fg.position.x = -(1.0 - pct) * (bar_fg.mesh as QuadMesh).size.x * 0.5


@rpc("authority", "call_local", "unreliable")
func _flash() -> void:
	_material.albedo_color = Color.WHITE
	create_tween().tween_property(_material, "albedo_color", color, 0.15)


@rpc("authority", "call_local", "unreliable")
func _swing() -> void:
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3(1.15, 0.9, 1.15), 0.06)
	tween.tween_property(model, "scale", Vector3.ONE, 0.12)
