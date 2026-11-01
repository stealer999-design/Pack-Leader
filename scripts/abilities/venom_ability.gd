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


func execute(pet: Creature, point: Vector3, target: Creature) -> void:
	var world := pet.world
	var aim := target.global_position if is_instance_valid(target) else point
	match mode:
		"spit":
			var from := pet.global_position + Vector3.UP * 0.5
			var travel := maxf(from.distance_to(aim) / SPIT_SPEED, 0.1)
			world.play_bolt.rpc(from, aim + Vector3.UP * 0.4, VENOM, travel)
			pet.get_tree().create_timer(travel).timeout.connect(_splash.bind(pet, aim))
		"lash":
			if not is_instance_valid(target):
				return
			world.play_beam.rpc(pet.global_position + Vector3.UP * 0.5, target.global_position + Vector3.UP * 0.5, VENOM)
			var toward := target.global_position - pet.global_position
			toward.y = 0.0
			target.pull_to(pet.global_position + toward.normalized() * (pet.radius() + target.radius() + 0.3))
			_poison(pet, target)
		"nova":
			_splash(pet, world.clamp_to_level(aim))
		"cloud":
			var at := world.clamp_to_level(aim)
			world.add_zone(pet, at, radius, cloud_duration, 0.0, VENOM, pet.ability_damage() * poison_dps_multiplier)
			_splash(pet, at)
	if heal_allies > 0.0:
		var at := world.clamp_to_level(aim)
		for ally in world.allies_near(pet, at, maxf(radius, 6.0)):
			ally.health.heal(ally.health.max_health * heal_allies)
		world.play_burst.rpc(at, Color(0.6, 1.0, 0.6), 3.0)


func _splash(pet: Creature, at: Vector3) -> void:
	if not is_instance_valid(pet):
		return
	for enemy in pet.world.enemies_near(pet, at, radius):
		_poison(pet, enemy)
	pet.world.play_burst.rpc(at, VENOM, maxf(radius, 1.5))


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
