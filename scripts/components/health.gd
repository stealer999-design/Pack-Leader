class_name Health
extends Node
## Reusable health component. `current` and `max_health` are plain properties
## with setters, so replicating them over the network fires the same signals
## on every peer.
##
## Also holds two effects that work on anything with health (creatures,
## bosses and players), run on the server:
## - poison: damage over time;
## - shield: a pool that absorbs damage before health does.

signal changed(current: float, maximum: float)
signal died

@export var max_health := 100.0:
	set(v):
		max_health = v
		changed.emit(current, max_health)

var current := -1.0:  # -1 = not initialised yet
	set(v):
		var was_alive := current > 0.0
		current = v
		changed.emit(current, max_health)
		if was_alive and current <= 0.0:
			died.emit()

## Set by the owning client (e.g. while dashing) and replicated to the server.
var invulnerable := false

# Server-side effects.
var shield := 0.0
var _shield_timer := 0.0
var _poison_dps := 0.0
var _poison_timer := 0.0


func _ready() -> void:
	if current < 0.0:
		current = max_health


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _shield_timer > 0.0:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			shield = 0.0
	if _poison_timer > 0.0:
		_poison_timer -= delta
		if not is_dead():
			current = maxf(current - _poison_dps * delta, 0.0)  # poison ignores shields and dodges


func take_damage(amount: float) -> void:
	if invulnerable or is_dead():
		return
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		if amount <= 0.0:
			return
	current = maxf(current - amount, 0.0)


func heal(amount: float) -> void:
	if not is_dead():
		current = minf(current + amount, max_health)


## Server: `dps` damage per second for `duration` seconds. A stronger or longer
## poison replaces a weaker one; they don't stack.
func add_poison(dps: float, duration: float) -> void:
	_poison_dps = maxf(dps, _poison_dps if _poison_timer > 0.0 else 0.0)
	_poison_timer = maxf(_poison_timer, duration)


## Server: absorbs up to `amount` damage for `duration` seconds.
func add_shield(amount: float, duration: float) -> void:
	shield = maxf(shield, amount)
	_shield_timer = maxf(_shield_timer, duration)


func is_poisoned() -> bool:
	return _poison_timer > 0.0


func is_dead() -> bool:
	return current <= 0.0


func fraction() -> float:
	return clampf(current / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
