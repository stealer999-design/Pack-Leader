class_name SlamAbility
extends PetAbility
## Damages and stuns every enemy around the pet.

@export var stun_duration := 2.0
@export var knockback := 7.0


func execute(pet: Creature, _point: Vector3, _target: Creature) -> void:
	var damage := pet.get_damage() * damage_multiplier
	for enemy in pet.world.enemies_near(pet, pet.global_position, radius):
		var push := enemy.global_position - pet.global_position
		push.y = 0.0
		enemy.receive_damage(damage, pet, push.normalized() * knockback)
		if enemy is Creature:
			enemy.stun(stun_duration)
	pet.world.play_burst.rpc(pet.global_position, pet.species.color.lightened(0.3), radius)
