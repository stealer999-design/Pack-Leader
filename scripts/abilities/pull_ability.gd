class_name PullAbility
extends PetAbility
## Lashes the target and yanks it next to the pet. Bosses are too heavy to
## pull, but still take the damage.


func execute(pet: Creature, _point: Vector3, target: Creature) -> void:
	pet.world.play_beam.rpc(pet.global_position + Vector3.UP * 0.5, target.global_position + Vector3.UP * 0.5,
			Color(0.95, 0.45, 0.55))
	var toward := target.global_position - pet.global_position
	toward.y = 0.0
	target.pull_to(pet.global_position + toward.normalized() * (pet.radius() + target.radius() + 0.3))
	target.receive_damage(pet.ability_damage() * damage_multiplier, pet)
