class_name Health
extends Node
## Reusable health component. `current` and `max_health` are plain properties
## with setters, so replicating them over the network fires the same signals
## on every peer.

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


func _ready() -> void:
	if current < 0.0:
		current = max_health


func take_damage(amount: float) -> void:
	if invulnerable or is_dead():
		return
	current = maxf(current - amount, 0.0)


func heal(amount: float) -> void:
	if not is_dead():
		current = minf(current + amount, max_health)


func is_dead() -> bool:
	return current <= 0.0


func fraction() -> float:
	return clampf(current / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
