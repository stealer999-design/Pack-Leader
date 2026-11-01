class_name BlindAbility
extends PetAbility
## A blinding flash: damages nearby enemies and makes half their attacks miss.

@export var blind_duration := 4.0


func execute(pet: Creature, _point: Vector3, _target: Creature) -> void:
	var damage := pet.ability_damage() * damage_multiplier
	for enemy in pet.world.enemies_near(pet, pet.global_position, radius):
		enemy.receive_damage(damage, pet)
		if enemy.has_method("blind"):
			enemy.blind(blind_duration)
	pet.world.play_burst.rpc(pet.global_position, Color(1.0, 0.95, 0.6), radius)
