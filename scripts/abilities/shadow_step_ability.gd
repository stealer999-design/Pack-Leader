class_name ShadowStepAbility
extends PetAbility
## Teleports behind the target and strikes it.


func execute(pet: Creature, _point: Vector3, target: Creature) -> void:
	var from := pet.global_position
	var away := target.global_position - from
	away.y = 0.0
	var behind := target.global_position + away.normalized() * (target.radius() + pet.radius() + 0.3)
	pet.global_position = pet.world.clamp_to_level(behind)
	pet.world.play_burst.rpc(from, Color(0.45, 0.3, 0.7), 1.5)
	pet.world.play_burst.rpc(pet.global_position, Color(0.45, 0.3, 0.7), 1.5)
	target.receive_damage(pet.get_damage() * damage_multiplier, pet, away.normalized() * 3.0)
