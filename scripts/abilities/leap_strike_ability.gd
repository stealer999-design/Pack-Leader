class_name LeapStrikeAbility
extends PetAbility
## Leaps to the target point and damages every enemy around the landing spot.

@export var leap_time := 0.35
@export var knockback := 6.0


func execute(pet: Creature, point: Vector3, _target: Creature) -> void:
	var to := point - pet.global_position
	to.y = 0.0
	var landing := pet.world.clamp_to_level(pet.global_position + to.limit_length(cast_range))
	var damage := pet.ability_damage() * damage_multiplier
	pet.leap_to(landing, leap_time, func() -> void:
		for enemy in pet.world.enemies_near(pet, landing, radius):
			var push := enemy.global_position - landing
			push.y = 0.0
			enemy.receive_damage(damage, pet, push.normalized() * knockback)
		pet.world.play_burst.rpc(landing, pet.species.color, radius))
