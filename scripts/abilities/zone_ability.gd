class_name ZoneAbility
extends PetAbility
## Creates a lasting damage zone on the ground at the target point.

@export var duration := 5.0
## Damage per second inside the zone, as a fraction of the pet's attack damage.
@export var dps_multiplier := 0.6
@export var color := Color(0.85, 0.7, 0.4)


func execute(pet: Creature, point: Vector3, _target: Creature) -> void:
	var at := pet.world.clamp_to_level(point)
	pet.world.add_zone(pet, at, radius, duration, pet.get_damage() * dps_multiplier, color)
