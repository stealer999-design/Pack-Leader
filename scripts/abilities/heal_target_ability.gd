class_name HealTargetAbility
extends PetAbility
## Heals the most injured ally nearby: a pet or a player, including the owner.


## Fraction of the ally's maximum health restored.
@export_range(0.0, 1.0) var heal_fraction := 0.45


func cannot_cast_reason(pet: Creature) -> String:
	return "" if _most_injured(pet) else "Nobody nearby needs healing."


func execute(pet: Creature, _point: Vector3, _target: Creature) -> void:
	var ally := _most_injured(pet)
	if ally == null:
		return
	ally.health.heal(ally.health.max_health * heal_fraction)
	pet.world.play_beam.rpc(pet.global_position + Vector3.UP * 0.5, ally.global_position + Vector3.UP * 0.8,
			Color(0.5, 1.0, 0.55))
	pet.world.play_burst.rpc(ally.global_position, Color(0.5, 1.0, 0.55), 1.4)


func _most_injured(pet: Creature) -> Node3D:
	var best: Node3D = null
	var best_fraction := 0.999
	for ally in pet.world.allies_near(pet, pet.global_position, radius):
		var fraction: float = ally.health.fraction()
		if fraction < best_fraction:
			best = ally
			best_fraction = fraction
	return best
