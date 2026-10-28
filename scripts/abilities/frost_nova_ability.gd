class_name FrostNovaAbility
extends PetAbility
## Icy burst around the pet: damages and slows every enemy nearby.

@export var slow_duration := 3.0
## Enemies move at this fraction of their normal speed while slowed.
@export_range(0.0, 1.0) var slow_factor := 0.5


func execute(pet: Creature, _point: Vector3, _target: Creature) -> void:
	var damage := pet.get_damage() * damage_multiplier
	for enemy in pet.world.enemies_near(pet, pet.global_position, radius):
		enemy.receive_damage(damage, pet)
		if enemy.has_method("slow"):
			enemy.slow(slow_duration, slow_factor)
	pet.world.play_burst.rpc(pet.global_position, Color(0.6, 0.9, 1.0), radius)
