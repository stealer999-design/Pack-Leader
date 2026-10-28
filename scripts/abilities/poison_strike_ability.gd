class_name PoisonStrikeAbility
extends PetAbility
## Bites the target and poisons it: damage over time.

## Poison damage per second, as a fraction of the pet's attack damage.
@export var poison_dps_multiplier := 0.6
@export var poison_duration := 5.0


func execute(pet: Creature, _point: Vector3, target: Creature) -> void:
	target.receive_damage(pet.get_damage() * damage_multiplier, pet)
	if target.has_method("poison"):
		target.poison(pet.get_damage() * poison_dps_multiplier, poison_duration)
	pet.world.play_burst.rpc(target.global_position, Color(0.45, 0.95, 0.3), 1.2)
