class_name ShieldAbility
extends PetAbility
## Gives every ally nearby (pets and players) a shield that absorbs damage.

## Shield size as a fraction of each ally's maximum health.
@export_range(0.0, 1.0) var shield_fraction := 0.3
@export var duration := 6.0


func execute(pet: Creature, _point: Vector3, _target: Creature) -> void:
	for ally in pet.world.allies_near(pet, pet.global_position, radius):
		if ally.has_method("add_shield"):
			ally.add_shield(ally.health.max_health * shield_fraction, duration)
	pet.world.play_burst.rpc(pet.global_position, Color(1.0, 0.85, 0.3), radius)
