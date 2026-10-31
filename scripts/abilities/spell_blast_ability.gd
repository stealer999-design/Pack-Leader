class_name SpellBlastAbility
extends PetAbility
## A wizard's attack spell: a blast of magic that lands at the target point
## and hits every enemy within `radius` there.
## - "orb": a ball of magic (a fireball, a magma orb) flies from the caster;
## - "meteor": a burning rock falls out of the sky onto the spot;
## - "lightning": a bolt strikes down from the sky, instantly.
## It can also stun what it hits, leave a burning patch behind, or come down
## as several meteors scattered around the spot.

@export_enum("orb", "meteor", "lightning") var style := "orb"
@export var color := Color(1.0, 0.5, 0.2)
@export var stun_duration := 0.0
## A burning patch left behind: seconds (0 = none) and damage per second as a
## fraction of the pet's attack damage.
@export var burn_duration := 0.0
@export var burn_dps_multiplier := 0.5
## Several meteors (or orbs) scattered up to `spread` units around the spot,
## each dealing the full damage where it lands.
@export var count := 1
@export var spread := 0.0

const ORB_SPEED := 16.0
const METEOR_FALL := 0.55


func execute(pet: Creature, point: Vector3, target: Creature) -> void:
	var world := pet.world
	var center := world.clamp_to_level(target.global_position if is_instance_valid(target) else point)
	var damage := pet.get_damage() * damage_multiplier
	for i in count:
		var impact := center
		if count > 1:
			impact = world.clamp_to_level(center + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / count + randf()) * spread * randf_range(0.4, 1.0))
		var from := pet.global_position + Vector3.UP * 0.8
		var travel := 0.05
		match style:
			"orb":
				travel = maxf(from.distance_to(impact) / ORB_SPEED, 0.1)
			"meteor":
				from = impact + Vector3(2.5, 14.0, 1.5)
				travel = METEOR_FALL + i * 0.18
		world.play_spell.rpc(style, from, impact + Vector3.UP * 0.4, color, travel)
		pet.get_tree().create_timer(travel).timeout.connect(_land.bind(pet, impact, damage))


func _land(pet: Creature, impact: Vector3, damage: float) -> void:
	if not is_instance_valid(pet):
		return
	var world := pet.world
	for enemy in world.enemies_near(pet, impact, radius):
		var push := enemy.global_position - impact
		push.y = 0.0
		enemy.receive_damage(damage, pet, push.normalized() * 4.0)
		if stun_duration > 0.0 and enemy is Creature:
			enemy.stun(stun_duration)
	world.play_burst.rpc(impact, color, radius)
	if burn_duration > 0.0:
		world.add_zone(pet, impact, radius * 0.8, burn_duration, pet.get_damage() * burn_dps_multiplier, color)
