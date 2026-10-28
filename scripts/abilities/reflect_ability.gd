class_name ReflectAbility
extends PetAbility
## Coats the pet in armor that sends part of every hit back to the attacker.

@export var duration := 5.0
@export_range(0.0, 1.0) var reflect_fraction := 0.6


func execute(pet: Creature, _point: Vector3, _target: Creature) -> void:
	pet.reflect(duration, reflect_fraction)
	pet.world.play_burst.rpc(pet.global_position, Color(0.7, 0.85, 1.0), 2.0)
