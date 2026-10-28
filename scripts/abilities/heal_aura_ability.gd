class_name HealAuraAbility
extends PetAbility
## Heals every ally around the pet (pets and players on the same side).

## Fraction of each ally's maximum health restored.
@export_range(0.0, 1.0) var heal_fraction := 0.35


func execute(pet: Creature, _point: Vector3, _target: Creature) -> void:
	for ally in pet.world.allies_near(pet, pet.global_position, radius):
		ally.health.heal(ally.health.max_health * heal_fraction)
	pet.world.play_burst.rpc(pet.global_position, Color(0.5, 1.0, 0.6), radius)
