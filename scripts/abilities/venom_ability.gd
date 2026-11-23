class_name VenomAbility
extends PetAbility
## A venomancer's ability: poison that keeps hurting after it lands. `mode`:
## - "spit": a glob of venom flies at the target and splashes everything
##   within `radius` of it;
## - "lash": the tongue yanks the target next to the pet (bosses are too heavy)
##   and poisons it;
## - "nova": a burst of poison at the aimed spot;
## - "cloud": a lingering poison cloud at the target point for
##   `cloud_duration` seconds that poisons whatever stands in it.
## Every hit deals `damage_multiplier` up front and poisons for
## `poison_dps_multiplier` x the pet's damage per second for `poison_duration`.
## Extras: weaken what it hits, heal the pet and its tamer from the hit, or
## heal allies around the pet.

const VENOM := Color(0.45, 0.95, 0.3)
const SPIT_SPEED := 18.0

@export_enum("spit", "lash", "nova", "cloud") var mode := "spit"
@export var poison_dps_multiplier := 0.8
@export var poison_duration := 6.0
@export var cloud_duration := 6.0
@export var weaken_duration := 0.0
@export_range(0.0, 1.0) var weaken_factor := 0.6
## Heals the pet and its tamer for this share of the up-front damage dealt.
@export var heal_from_hit := 0.0
## Heals every ally around the pet for this share of their max health.
@export_range(0.0, 1.0) var heal_allies := 0.0
## The spell's look (SwampFX); "" = the plain green bolt and bursts.
@export var look := ""


func execute(pet: Creature, point: Vector3, target: Creature) -> void:
	var world := pet.world
	var aim := target.global_position if is_instance_valid(target) else point
	match mode:
		"spit":
			var from := pet.global_position + Vector3.UP * 0.5
			var travel := maxf(from.distance_to(aim) / SPIT_SPEED, 0.1)
			if look == "":
				world.play_bolt.rpc(from, aim + Vector3.UP * 0.4, VENOM, travel)
			else:
				world.play_pet_fx.rpc("swamp", look, aim, from, radius, travel, PackedVector3Array(), PackedVector3Array())
			pet.get_tree().create_timer(travel).timeout.connect(_splash.bind(pet, aim))
		"lash":
			if not is_instance_valid(target):
				return
			if look == "":
				world.play_beam.rpc(pet.global_position + Vector3.UP * 0.5, target.global_position + Vector3.UP * 0.5, VENOM)
			else:
				world.play_pet_fx.rpc("swamp", look, target.global_position + Vector3.UP * 0.5, pet.global_position + Vector3.UP * 0.5,
						radius, 0.0, PackedVector3Array(), PackedVector3Array())
			var toward := target.global_position - pet.global_position
			toward.y = 0.0
			target.pull_to(pet.global_position + toward.normalized() * (pet.radius() + target.radius() + 0.3))
			_poison(pet, target)
		"nova":
			var at := world.clamp_to_level(aim)
			if look != "":
				world.play_pet_fx.rpc("swamp", look, at, pet.global_position, radius, 0.0, _allies_at(pet, at), _enemies_at(pet, at))
			_splash(pet, at)
		"cloud":
			var at := world.clamp_to_level(aim)
			world.add_zone(pet, at, radius, cloud_duration, 0.0, VENOM if look == "" else Color(0, 0, 0, 0), pet.ability_damage() * poison_dps_multiplier)
			if look != "":
				world.play_pet_fx.rpc("swamp", look, at, pet.global_position, radius, cloud_duration, PackedVector3Array(), PackedVector3Array())
			_splash(pet, at)
	if heal_allies > 0.0:
		var at := world.clamp_to_level(aim)
		for ally in world.allies_near(pet, at, maxf(radius, 6.0)):
			ally.health.heal(ally.health.max_health * heal_allies)
		if look == "":
			world.play_burst.rpc(at, Color(0.6, 1.0, 0.6), 3.0)


func _splash(pet_ref, at: Vector3) -> void:
	# Called later (an arrow landing, a leap ending): the pet or its target
	# may have been freed by then, so they come in untyped and are checked.
	if not is_instance_valid(pet_ref):
		return
	var pet: Creature = pet_ref
	for enemy in pet.world.enemies_near(pet, at, radius):
		_poison(pet, enemy)
	if look == "":
		pet.world.play_burst.rpc(at, VENOM, maxf(radius, 1.5))


func _allies_at(pet: Creature, at: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if heal_allies > 0.0:
		for ally in pet.world.allies_near(pet, at, maxf(radius, 6.0)):
			out.append(ally.global_position)
	return out


func _enemies_at(pet: Creature, at: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for enemy in pet.world.enemies_near(pet, at, radius):
		out.append(enemy.global_position)
	return out


func _poison(pet: Creature, enemy: Node3D) -> void:
	var dealt := pet.ability_damage() * damage_multiplier
	if dealt > 0.0:
		enemy.receive_damage(dealt, pet)
	var dps := pet.ability_damage() * poison_dps_multiplier
	pet.envenom(enemy, dps, poison_duration, dps)
	if weaken_duration > 0.0 and enemy.has_method("weaken"):
		enemy.weaken(weaken_duration, weaken_factor)
	if heal_from_hit > 0.0 and dealt > 0.0:
		pet.health.heal(dealt * heal_from_hit)
		var tamer := pet.world.get_player(pet.owner_id)
		if tamer:
			tamer.health.heal(dealt * heal_from_hit)
