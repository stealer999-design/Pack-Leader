class_name PetAbility
extends Resource
## Base class for pet abilities. Subclass it, override execute(), and assign a
## .tres of the subclass to a species' `ability`. execute() runs on the server.

@export var display_name := "Ability"
@export_multiline var description := ""
@export var cooldown := 8.0
## How close the pet must be to the target point. 0 = cast instantly where the pet stands.
@export var cast_range := 0.0
## If true, the ability needs a wild creature to aim at (the hovered one, or the nearest to the cursor).
@export var needs_target := false
## Ability damage = pet's attack damage x this.
@export var damage_multiplier := 1.0
@export var radius := 0.0


func execute(_pet: Creature, _point: Vector3, _target: Creature) -> void:
	pass
