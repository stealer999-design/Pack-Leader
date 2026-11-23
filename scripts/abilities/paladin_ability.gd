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
## - armor: allies within `radius` take `armor_reduction` less damage for
##   `armor_duration` (pets; players get an equal shield);
## - consecrate: holy ground for `sanctuary_duration` seconds that heals
##   allies (fraction of max health per second) and burns enemies.
## Everything happens around the aimed spot (the mouse); with `leap` the
## paladin first bounds there itself, then lets fly on landing.

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
@export_group("Armor")
@export var armor_duration := 0.0
@export_range(0.0, 1.0) var armor_reduction := 0.3
@export_group("Leap")
@export var leap := false
@export_group("Look")
## The spell's look (HolyFX); "" = the plain golden bursts.
@export var look := ""
@export_group("Consecrate")
@export var sanctuary_duration := 0.0
@export var sanctuary_heal := 0.0
@export var sanctuary_dps_multiplier := 0.0


func execute(pet: Creature, point: Vector3, target: Creature) -> void:
	var at := pet.world.clamp_to_level(point)
	if leap:
		pet.leap_to(at, 0.45, _effects.bind(pet, at, target, pet.global_position))
	else:
		_effects(pet, at, target, pet.global_position)


func _effects(pet_ref, at: Vector3, target_ref, from := Vector3.ZERO) -> void:
	# Called later (an arrow landing, a leap ending): the pet or its target
	# may have been freed by then, so they come in untyped and are checked.
	if not is_instance_valid(pet_ref):
		return
	var pet: Creature = pet_ref
	var target: Creature = target_ref if is_instance_valid(target_ref) else null
	var world := pet.world
	if not is_instance_valid(target) and smite_multiplier > 0.0:
		target = world.nearest_enemy(pet, at, maxf(radius, 3.0))
	var dealt := 0.0
	if smite_multiplier > 0.0 and is_instance_valid(target) and target.is_targetable():
		var damage := pet.ability_damage() * smite_multiplier
		target.receive_damage(damage, pet)
		dealt += damage
		world.play_beam.rpc(at + Vector3.UP * 0.6, target.global_position + Vector3.UP * 0.6, HOLY)
		world.play_burst.rpc(target.global_position, HOLY, 1.6)
		if taunt:
			target.taunt(pet)
	for enemy in world.enemies_near(pet, at, radius):
		if smite_area_multiplier > 0.0:
			var damage := pet.ability_damage() * smite_area_multiplier
			enemy.receive_damage(damage, pet)
			dealt += damage
		if blind_duration > 0.0 and enemy.has_method("blind"):
			enemy.blind(blind_duration)
		if taunt and enemy is Creature:
			enemy.taunt(pet)
	var hit := PackedVector3Array()
	for enemy in world.enemies_near(pet, at, radius):
		hit.append(enemy.global_position)
	var shielded: Array = []  # (node paths: a blue shield goes over each)
	var protect_for := 0.0
	var healed := PackedVector3Array()  # (green plus signs go up off each)
	if guard_duration > 0.0:
		pet.guard(guard_duration, guard_reduction)
		shielded.append(pet.get_path()); protect_for = maxf(protect_for, guard_duration)
		if look == "":
			world.play_burst.rpc(pet.global_position, Color(0.4, 0.7, 1.0), 1.6)
	var allies := world.allies_near(pet, at, radius)
	var power := pet.heal_power()
	for ally in allies:
		if heal_allies > 0.0:
			ally.health.heal(ally.health.max_health * heal_allies * power)
			healed.append(ally.global_position)
		if shield_fraction > 0.0 or armor_duration > 0.0:
			if not shielded.has(ally.get_path()): shielded.append(ally.get_path())
			protect_for = maxf(protect_for, maxf(shield_duration if shield_fraction > 0.0 else 0.0, armor_duration))
		if shield_fraction > 0.0 and ally.has_method("add_shield"):
			ally.add_shield(ally.health.max_health * shield_fraction * power, shield_duration)
		if armor_duration > 0.0:
			if ally is Creature:
				(ally as Creature).guard(armor_duration, armor_reduction)
			elif ally.has_method("add_shield"):
				ally.add_shield(ally.health.max_health * armor_reduction * power, armor_duration)
	if heal_self > 0.0:
		pet.health.heal(pet.health.max_health * heal_self * power)
		if not healed.has(pet.global_position): healed.append(pet.global_position)
	var injured := _most_injured(allies)
	if injured and (heal_injured > 0.0 or (heal_from_smite > 0.0 and dealt > 0.0)):
		injured.health.heal((injured.health.max_health * heal_injured + dealt * heal_from_smite) * power)
		if not healed.has(injured.global_position): healed.append(injured.global_position)
	if not healed.is_empty():
		world.play_heal_marks.rpc(healed)
	if not shielded.is_empty():
		world.play_shield_icons.rpc(shielded, protect_for)
		world.play_beam.rpc(at + Vector3.UP * 0.6, injured.global_position + Vector3.UP * 0.8, Color(0.6, 1.0, 0.6))
		if look == "":
			world.play_burst.rpc(injured.global_position, Color(0.6, 1.0, 0.6), 1.2)
	if sanctuary_duration > 0.0:
		world.add_zone(pet, world.clamp_to_level(at), radius, sanctuary_duration,
				pet.ability_damage() * sanctuary_dps_multiplier, HOLY if look == "" else Color(0, 0, 0, 0), 0.0, sanctuary_heal * power)
	if look == "":
		world.play_burst.rpc(at, HOLY, maxf(radius, 2.0))
		return
	var touched := PackedVector3Array()
	for ally in allies:
		touched.append(ally.global_position)
	var lasting := maxf(sanctuary_duration, maxf(armor_duration, shield_duration if shield_fraction > 0.0 else 0.0))
	world.play_pet_fx.rpc("holy", look, at, from, radius, lasting, touched, hit)


static func _most_injured(allies: Array[Node3D]) -> Node3D:
	var best: Node3D = null
	var best_fraction := 0.999
	for ally in allies:
		if ally.health.fraction() < best_fraction:
			best = ally
			best_fraction = ally.health.fraction()
	return best
