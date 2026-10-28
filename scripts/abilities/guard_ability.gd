class_name GuardAbility
extends PetAbility
## Taunts nearby wild creatures onto the pet and reduces the damage it takes.

@export var duration := 4.0
@export_range(0.0, 1.0) var damage_reduction := 0.5


func execute(pet: Creature, _point: Vector3, _target: Creature) -> void:
	pet.guard(duration, damage_reduction)
	for enemy in pet.world.enemies_near(pet, pet.global_position, radius):
		if enemy is Creature:
			enemy.taunt(pet)
	pet.world.play_burst.rpc(pet.global_position, Color(0.4, 0.7, 1.0), radius * 0.6)
