class_name PaladinAbility
extends PetAbility
## A paladin's holy ability, built from a few parts (any that are set happen,
## in this order). A burst of golden light marks every cast.
## - smite: hit the target (smite_multiplier) and/or every enemy within
##   `radius` (smite_area_multiplier), optionally blinding them;
## - draw the enemy: taunt enemies within `radius` and guard itself (takes
##   `guard_reduction` less damage for `guard_duration`);
## - heal: every ally within `radius` (heal_allies), the most injured one
##   (heal_injured), the paladin itself (heal_self), and/or the most injured
##   ally for a share of the smite damage (heal_from_smite);
## - shield allies within `radius`;
## - consecrate: holy ground at its feet for `sanctuary_duration` seconds that
##   heals allies (fraction of max health per second) and burns enemies.

const HOLY := Color(1.0, 0.88, 0.45)

@export_group("Smite")
@export var smite_multiplier := 0.0
@export var smite_area_multiplier := 0.0
@export var blind_duration := 0.0
@export_group("Draw the enemy")
@export var taunt := false
@export var guard_duration := 0.0
@export_range(0.0, 1.0) var guard_reduction := 0.0
@export_group("Heal")
@export_range(0.0, 1.0) var heal_allies := 0.0
@export_range(0.0, 1.0) var heal_injured := 0.0
@export_range(0.0, 1.0) var heal_self := 0.0
@export var heal_from_smite := 0.0
@export_group("Shield")
@export_range(0.0, 1.0) var shield_fraction := 0.0
@export var shield_duration := 6.0
@export_group("Consecrate")
@export var sanctuary_duration := 0.0
@export var sanctuary_heal := 0.0
@export var sanctuary_dps_multiplier := 0.0


func execute(pet: Creature, _point: Vector3, target: Creature) -> void:
	var world := pet.world
	var at := pet.global_position
	var dealt := 0.0
	if smite_multiplier > 0.0 and is_instance_valid(target) and target.is_targetable():
		var damage := pet.get_damage() * smite_multiplier
		target.receive_damage(damage, pet)
		dealt += damage
		world.play_beam.rpc(at + Vector3.UP * 0.6, target.global_position + Vector3.UP * 0.6, HOLY)
		world.play_burst.rpc(target.global_position, HOLY, 1.6)
		if taunt:
			target.taunt(pet)
	for enemy in world.enemies_near(pet, at, radius):
		if smite_area_multiplier > 0.0:
			var damage := pet.get_damage() * smite_area_multiplier
			enemy.receive_damage(damage, pet)
			dealt += damage
		if blind_duration > 0.0 and enemy.has_method("blind"):
			enemy.blind(blind_duration)
		if taunt and enemy is Creature:
			enemy.taunt(pet)
	if guard_duration > 0.0:
		pet.guard(guard_duration, guard_reduction)
	var allies := world.allies_near(pet, at, radius)
	for ally in allies:
		if heal_allies > 0.0:
			ally.health.heal(ally.health.max_health * heal_allies)
		if shield_fraction > 0.0 and ally.has_method("add_shield"):
			ally.add_shield(ally.health.max_health * shield_fraction, shield_duration)
	if heal_self > 0.0:
		pet.health.heal(pet.health.max_health * heal_self)
	var injured := _most_injured(allies)
	if injured and (heal_injured > 0.0 or (heal_from_smite > 0.0 and dealt > 0.0)):
		injured.health.heal(injured.health.max_health * heal_injured + dealt * heal_from_smite)
		world.play_beam.rpc(at + Vector3.UP * 0.6, injured.global_position + Vector3.UP * 0.8, Color(0.6, 1.0, 0.6))
		world.play_burst.rpc(injured.global_position, Color(0.6, 1.0, 0.6), 1.2)
	if sanctuary_duration > 0.0:
		world.add_zone(pet, world.clamp_to_level(at), radius, sanctuary_duration,
				pet.get_damage() * sanctuary_dps_multiplier, HOLY, 0.0, sanctuary_heal)
	world.play_burst.rpc(at, HOLY, maxf(radius, 2.0))


static func _most_injured(allies: Array[Node3D]) -> Node3D:
	var best: Node3D = null
	var best_fraction := 0.999
	for ally in allies:
		if ally.health.fraction() < best_fraction:
			best = ally
			best_fraction = ally.health.fraction()
	return best
