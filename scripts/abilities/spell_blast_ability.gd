class_name SpellBlastAbility
extends PetAbility
## A wizard's damage spell, aimed at the mouse (fire, lightning, air or water).
## `style` is its shape:
## - "orb": a ball of magic flies from the caster and bursts where it lands;
## - "fireball": the same, drawn as a blazing fireball with spiralling flame
##   tendrils that explodes where it lands (FireballFX);
## - "magma": the same, drawn as a big swirling orb of lava, no trail (FireballFX);
## - "meteor": burning rocks (or hail) fall out of the sky onto the spot;
## - "lightning": a bolt strikes down from the sky, instantly;
## - "storm": `count` lightning bolts strike enemies around the spot, one
##   after another over `duration` seconds;
## - "wave": a curling wall of water (TidalWaveFX) rolls out from the caster
##   towards the spot across a cone (`cone_degrees` wide, `radius` long),
##   hitting everything in it as it reaches them;
## - "vortex": a whirlwind spins at the spot for `duration` seconds, hurting
##   and slowing what's inside.
## Hits can also stun, slow, knock back, set burning (damage over time),
## leave a burning patch, or arc on as chain lightning to `chain` more enemies.

@export_enum("orb", "fireball", "magma", "meteor", "lightning", "storm", "wave", "vortex") var style := "orb"
@export var color := Color(1.0, 0.5, 0.2)
@export var stun_duration := 0.0
@export var slow_duration := 0.0
@export_range(0.0, 1.0) var slow_factor := 0.5
@export var knockback := 4.0
## Burning (damage over time) on each enemy hit: per second, as a share of
## the pet's damage, for burn_duration (0 = none).
@export var dot_multiplier := 0.0
## A burning patch left behind: seconds (0 = none) and damage per second as a
## fraction of the pet's attack damage.
@export var burn_duration := 0.0
@export var burn_dps_multiplier := 0.5
## Several meteors (or bolts) scattered up to `spread` units around the spot,
## each dealing the full damage where it lands.
@export var count := 1
@export var spread := 0.0
## Chain lightning: after the hit, the spell arcs on to this many more enemies.
@export var chain := 0
@export var cone_degrees := 50.0
## How long a storm or vortex lasts.
@export var duration := 3.0

const ORB_SPEED := 16.0
const METEOR_FALL := 0.55
const CHAIN_RANGE := 6.0


func execute(pet: Creature, point: Vector3, target: Creature) -> void:
	var world := pet.world
	var center := world.clamp_to_level(target.global_position if is_instance_valid(target) else point)
	var damage := pet.ability_damage() * damage_multiplier
	match style:
		"wave":
			_wave(pet, center, damage)
			return
		"vortex":
			_vortex(pet, center, damage)
			return
		"storm":
			for i in count:
				pet.get_tree().create_timer(duration * i / maxf(count, 1)).timeout.connect(
						_storm_strike.bind(pet, center, damage))
			world.play_zone.rpc(center, spread, duration, Color(color, 0.5))
			return
	for i in count:
		var impact := center
		if count > 1:
			impact = world.clamp_to_level(center + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / count + randf()) * spread * randf_range(0.4, 1.0))
		var from := pet.global_position + Vector3.UP * 0.8
		var travel := 0.05
		match style:
			"orb", "fireball", "magma":
				travel = maxf(from.distance_to(impact) / ORB_SPEED, 0.1)
			"meteor":
				from = impact + Vector3(2.5, 14.0, 1.5)
				travel = METEOR_FALL + i * 0.15
		if style == "fireball" or style == "magma":
			world.play_fireball.rpc(from, impact + Vector3.UP * 0.5, travel, radius, style == "magma")
		else:
			world.play_spell.rpc(style, from, impact + Vector3.UP * 0.4, color, travel)
		pet.get_tree().create_timer(travel).timeout.connect(_land.bind(pet, impact, damage))


func _land(pet_ref, impact: Vector3, damage: float) -> void:
	# Called later (an arrow landing, a leap ending): the pet or its target
	# may have been freed by then, so they come in untyped and are checked.
	if not is_instance_valid(pet_ref):
		return
	var pet: Creature = pet_ref
	var world := pet.world
	var hit := world.enemies_near(pet, impact, radius)
	for enemy in hit:
		_hit(pet, enemy, damage, impact)
	world.play_burst.rpc(impact, color, radius)
	if burn_duration > 0.0:
		world.add_zone(pet, impact, radius * 0.8, burn_duration, pet.ability_damage() * burn_dps_multiplier, color)
	if chain > 0:
		_chain_from(pet, impact, hit, damage * 0.7)


## One enemy hit by the spell: damage pushing it away from `from`, then the extras.
func _hit(pet: Creature, enemy: Node3D, damage: float, from: Vector3) -> void:
	var push := enemy.global_position - from
	push.y = 0.0
	enemy.receive_damage(damage, pet, push.normalized() * knockback)
	if stun_duration > 0.0 and enemy is Creature:
		enemy.stun(stun_duration)
	if slow_duration > 0.0 and enemy.has_method("slow"):
		enemy.slow(slow_duration, slow_factor)
	if dot_multiplier > 0.0 and enemy.get("health") != null:
		pet.envenom(enemy, pet.ability_damage() * dot_multiplier, maxf(burn_duration, 3.0), pet.ability_damage() * dot_multiplier)


## Lightning arcing from enemy to enemy (each new one within CHAIN_RANGE of the last).
func _chain_from(pet: Creature, start: Vector3, already: Array[Node3D], damage: float) -> void:
	var points := PackedVector3Array([start + Vector3.UP * 0.6])
	var last := start
	var struck := already.duplicate()
	for i in chain:
		var next: Node3D = null
		var best := CHAIN_RANGE
		for enemy in pet.world.enemies_near(pet, last, CHAIN_RANGE):
			var d := enemy.global_position.distance_to(last)
			if not struck.has(enemy) and d < best:
				next = enemy
				best = d
		if next == null:
			break
		struck.append(next)
		_hit(pet, next, damage, last)
		last = next.global_position
		points.append(last + Vector3.UP * 0.6)
	if points.size() > 1:
		pet.world.play_lightning.rpc(points)


func _storm_strike(pet_ref, center: Vector3, damage: float) -> void:
	# Called later (an arrow landing, a leap ending): the pet or its target
	# may have been freed by then, so they come in untyped and are checked.
	if not is_instance_valid(pet_ref):
		return
	var pet: Creature = pet_ref
	var world := pet.world
	var foes := world.enemies_near(pet, center, spread)
	var spot: Vector3 = foes.pick_random().global_position if not foes.is_empty() \
			else world.clamp_to_level(center + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * spread * randf())
	world.play_spell.rpc("lightning", spot, spot, color, 0.05)
	_land(pet, spot, damage)


## A cone sweeping out from the caster towards `toward`.
func _wave(pet: Creature, toward: Vector3, damage: float) -> void:
	var world := pet.world
	var origin := pet.global_position
	var forward := toward - origin
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.1 else -pet.model.global_basis.z
	var half := deg_to_rad(cone_degrees) * 0.5
	for enemy in world.enemies_near(pet, origin, radius):
		var to := enemy.global_position - origin
		to.y = 0.0
		if to.length() < 0.5 or forward.angle_to(to.normalized()) <= half + 0.15:
			# hit when the wave rolls over it
			pet.get_tree().create_timer(TidalWaveFX.reach_time(to.length(), radius)).timeout.connect(
					_wave_hit.bind(pet, enemy, damage, origin))
	world.play_wave.rpc(origin, forward, radius, cone_degrees, color)
	if burn_duration > 0.0:
		world.add_zone(pet, world.clamp_to_level(origin + forward * radius * 0.6), radius * 0.4, burn_duration,
				pet.ability_damage() * burn_dps_multiplier, color)


func _wave_hit(pet_ref, enemy_ref, damage: float, origin: Vector3) -> void:
	if is_instance_valid(pet_ref) and is_instance_valid(enemy_ref) and not enemy_ref.is_queued_for_deletion():
		_hit(pet_ref, enemy_ref, damage, origin)


## A whirlwind at `center`: damage and a slow now, then damage every half second.
func _vortex(pet: Creature, center: Vector3, damage: float) -> void:
	var world := pet.world
	for enemy in world.enemies_near(pet, center, radius):
		var pull := center - enemy.global_position
		pull.y = 0.0
		enemy.receive_damage(damage, pet, pull.normalized() * 3.0)  # drawn into the middle
		if enemy.has_method("slow"):
			enemy.slow(duration, slow_factor)
	world.add_zone(pet, center, radius, duration, pet.ability_damage() * burn_dps_multiplier, Color(color, 0.6))
	world.play_vortex.rpc(center, radius, duration, color)
