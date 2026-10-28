class_name WeakenAbility
extends PetAbility
## A cloud of spores: nearby enemies deal less damage for a while.

@export var duration := 6.0
## Enemies deal this fraction of their normal damage (0.6 = 40% less).
@export_range(0.0, 1.0) var damage_factor := 0.6


func execute(pet: Creature, _point: Vector3, _target: Creature) -> void:
	for enemy in pet.world.enemies_near(pet, pet.global_position, radius):
		if enemy.has_method("weaken"):
			enemy.weaken(duration, damage_factor)
	pet.world.play_burst.rpc(pet.global_position, Color(0.7, 0.35, 0.85), radius)
