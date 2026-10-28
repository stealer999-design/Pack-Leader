class_name LifeDrainAbility
extends PetAbility
## Drains the target: damages it and heals the pet and its tamer.

## Fraction of the damage dealt that is returned as healing (to each).
@export_range(0.0, 2.0) var heal_fraction := 0.6


func execute(pet: Creature, _point: Vector3, target: Creature) -> void:
	var damage := pet.get_damage() * damage_multiplier
	var before := target.health.current
	target.receive_damage(damage, pet)
	var dealt := maxf(before - target.health.current, 0.0)
	pet.world.play_beam.rpc(target.global_position + Vector3.UP * 0.5, pet.global_position + Vector3.UP * 0.5,
			Color(0.5, 1.0, 0.8))
	pet.health.heal(dealt * heal_fraction)
	var tamer = pet.world.get_tamer(pet.owner_id)
	if tamer and tamer.has_method("receive_damage"):
		tamer.health.heal(dealt * heal_fraction)
