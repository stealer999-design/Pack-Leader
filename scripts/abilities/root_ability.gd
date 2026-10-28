class_name RootAbility
extends PetAbility
## Sticky mud at the target point: damages and roots (can't move) enemies there.

@export var root_duration := 2.5


func execute(pet: Creature, point: Vector3, _target: Creature) -> void:
	var at := pet.world.clamp_to_level(point)
	var damage := pet.get_damage() * damage_multiplier
	for enemy in pet.world.enemies_near(pet, at, radius):
		enemy.receive_damage(damage, pet)
		if enemy.has_method("slow"):
			enemy.slow(root_duration, 0.0)
	pet.world.play_burst.rpc(at, Color(0.45, 0.32, 0.18), radius)
