class_name ArcherShotAbility
extends PetAbility
## An archer's ability: arrows fired from range. `mode` picks the shot:
## - "shot": one arrow at the target (or aimed point), hitting it and anything
##   within `splash_radius` of where it lands;
## - "volley": `arrows` arrows fanned out `spread_degrees` towards the target;
## - "pierce": one arrow that flies `shot_range` units through every enemy in
##   its path;
## - "rain": `arrows` arrows fall from the sky over `radius` around the target;
## - "heal": healing arrows at the `arrows` most injured allies within
##   `shot_range` (heal_fraction of their max health), splashing heal_splash
##   onto allies near them;
## - "mark": Hunter's Mark: a red arrow and beam to the spot (MarkFX) marks every enemy within
##   `radius` for `effect_duration` seconds, and pets crit them every hit;
## - "rally": Eagle Eye: every pet on its side within `radius` of the spot gets
##   +`crit_bonus` crit chance for `effect_duration` seconds.
## Hits can also slow, stun, blind or set burning (damage over time).

const ARROW_SPEED := 32.0
const ARROW_HIT := 1.1  ## How close to an arrow's landing spot (or path) counts as a hit.

@export_enum("shot", "volley", "pierce", "rain", "heal", "mark", "rally") var mode := "shot"
@export var color := Color(0.85, 0.95, 1.0)
@export var arrows := 1
@export var spread_degrees := 30.0
@export var shot_range := 12.0
@export var splash_radius := 0.0
@export var slow_duration := 0.0
@export_range(0.0, 1.0) var slow_factor := 0.5
@export var stun_duration := 0.0
@export var blind_duration := 0.0
@export_range(0.0, 1.0) var heal_fraction := 0.0
@export_range(0.0, 1.0) var heal_splash := 0.0
@export var effect_duration := 6.0
@export_range(0.0, 1.0) var crit_bonus := 0.5
## Burning on each enemy hit: damage per second as a share of the pet's damage, for 4s.
@export var dot_multiplier := 0.0
## A volley's extra look: "cone" is Arrow Cone's golden dome full of arrows (ConeFX).
@export_enum("plain", "cone") var look := "plain"


func cannot_cast_reason(pet: Creature) -> String:
	if mode == "heal" and _injured(pet).is_empty():
		return "Nobody nearby needs healing."
	return ""


func execute(pet: Creature, point: Vector3, target: Creature) -> void:
	var world := pet.world
	var from := pet.global_position + Vector3.UP * 0.7
	var aim := target.global_position if is_instance_valid(target) else point
	aim.y = pet.global_position.y
	var damage := pet.ability_damage() * damage_multiplier
	match mode:
		"shot":
			_fire(pet, from, aim, _hit.bind(pet, aim, damage, maxf(splash_radius, ARROW_HIT), target))
		"volley":
			var forward := (aim - pet.global_position)
			forward.y = 0.0
			forward = forward.normalized() if forward.length() > 0.1 else Vector3.FORWARD
			var reach := maxf(pet.global_position.distance_to(aim), 4.0)
			if look == "cone":
				world.play_arrow_cone.rpc(from, forward, reach, spread_degrees)
			for i in arrows:
				var t := (float(i) / (arrows - 1) - 0.5) if arrows > 1 else 0.0
				var end := pet.global_position + forward.rotated(Vector3.UP, deg_to_rad(spread_degrees) * t) * reach
				_fire(pet, from, end, _hit.bind(pet, end, damage, ARROW_HIT, null))
		"pierce":
			var dir := (aim - pet.global_position)
			dir.y = 0.0
			dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
			var end := pet.global_position + dir * shot_range
			_fire(pet, from, end + Vector3.UP * 0.7, Callable())
			for enemy in world.enemies_near(pet, pet.global_position, shot_range):
				var along := (enemy.global_position - pet.global_position).dot(dir)
				var off := Geometry3D.get_closest_point_to_segment(enemy.global_position, pet.global_position, end)
				if along > 0.0 and Vector2(off.x - enemy.global_position.x, off.z - enemy.global_position.z).length() <= ARROW_HIT + enemy.radius():
					pet.get_tree().create_timer(along / ARROW_SPEED).timeout.connect(_hit_one.bind(pet, enemy.get_instance_id(), damage))
		"rain":
			for i in arrows:
				var spot := world.clamp_to_level(aim + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * radius * sqrt(randf()))
				var sky := spot + Vector3(1.5, 12.0, 1.0)
				var delay := 0.08 * i
				pet.get_tree().create_timer(delay + 0.01).timeout.connect(_fire.bind(pet, sky, spot, _hit.bind(pet, spot, damage, 1.3, null)))
		"mark":
			var at := world.clamp_to_level(aim)
			var to := at + Vector3.UP * 0.5
			var travel := maxf(from.distance_to(to) / ARROW_SPEED, 0.05)
			world.play_hunters_mark.rpc(from, to, travel, radius)  # the sigil, the red beam and the burst
			_fire(pet, from, to, _mark.bind(pet, at), Color(1.0, 0.3, 0.4))
		"rally":
			var at := world.clamp_to_level(aim)
			for ally in world.allies_near(pet, at, radius):
				if ally is Creature:
					(ally as Creature).add_crit(crit_bonus, effect_duration)
			world.play_burst.rpc(at, Color(1.0, 0.85, 0.3), radius)
			world.play_burst.rpc(pet.global_position, Color(1.0, 0.85, 0.3), 2.0)
		"heal":
			for ally in _injured(pet).slice(0, arrows):
				var to: Vector3 = ally.global_position + Vector3.UP * 0.7
				_fire(pet, from, to, _heal.bind(pet, ally.get_instance_id()), Color(0.55, 1.0, 0.55))


## An arrow from `from` to `to`; `on_land` runs when it gets there.
func _fire(pet_ref, from: Vector3, to: Vector3, on_land: Callable, tint := Color(0, 0, 0, 0)) -> void:
	# Called later (an arrow landing, a leap ending): the pet or its target
	# may have been freed by then, so they come in untyped and are checked.
	if not is_instance_valid(pet_ref):
		return
	var pet: Creature = pet_ref
	var travel := maxf(from.distance_to(to) / ARROW_SPEED, 0.05)
	pet.world.play_arrow.rpc(from, to, tint if tint.a > 0.0 else color, travel)
	if on_land.is_valid():
		pet.get_tree().create_timer(travel).timeout.connect(on_land)


func _hit(pet_ref, at: Vector3, damage: float, hit_radius: float, target_ref) -> void:
	# Called later (an arrow landing, a leap ending): the pet or its target
	# may have been freed by then, so they come in untyped and are checked.
	if not is_instance_valid(pet_ref):
		return
	var pet: Creature = pet_ref
	var target: Creature = target_ref if is_instance_valid(target_ref) else null
	var victims: Array[Node3D] = []
	if is_instance_valid(target) and splash_radius <= 0.0:
		if target.is_targetable():
			victims.append(target)  # a single aimed arrow hits only its target (wherever it stepped)
	else:
		victims = pet.world.enemies_near(pet, at, hit_radius)
		if is_instance_valid(target) and target.is_targetable() and not victims.has(target):
			victims.append(target)  # it may have stepped away a little: an arrow aimed at it still hits
	for enemy in victims:
		_apply(pet, enemy, damage)
	if splash_radius > 0.0:
		pet.world.play_burst.rpc(at, color, splash_radius)


func _mark(pet_ref, at: Vector3) -> void:
	# Called later (an arrow landing, a leap ending): the pet or its target
	# may have been freed by then, so they come in untyped and are checked.
	if not is_instance_valid(pet_ref):
		return
	var pet: Creature = pet_ref
	for enemy in pet.world.enemies_near(pet, at, radius):
		if enemy is Creature:
			(enemy as Creature).mark(effect_duration)


func _hit_one(pet_ref, enemy_id: int, damage: float) -> void:
	# Called later (an arrow landing, a leap ending): the pet or its target
	# may have been freed by then, so they come in untyped and are checked.
	if not is_instance_valid(pet_ref):
		return
	var pet: Creature = pet_ref
	var enemy := instance_from_id(enemy_id) as Node3D
	if is_instance_valid(pet) and is_instance_valid(enemy) and enemy.is_targetable():
		_apply(pet, enemy, damage)


func _apply(pet: Creature, enemy: Node3D, damage: float) -> void:
	enemy.receive_damage(damage, pet)
	if slow_duration > 0.0 and enemy.has_method("slow"):
		enemy.slow(slow_duration, slow_factor)
	if stun_duration > 0.0 and enemy is Creature:
		enemy.stun(stun_duration)
	if blind_duration > 0.0 and enemy.has_method("blind"):
		enemy.blind(blind_duration)
	if dot_multiplier > 0.0:
		pet.envenom(enemy, pet.ability_damage() * dot_multiplier, 4.0, pet.ability_damage() * dot_multiplier)


func _heal(pet_ref, ally_id: int) -> void:
	# Called later (an arrow landing, a leap ending): the pet or its target
	# may have been freed by then, so they come in untyped and are checked.
	if not is_instance_valid(pet_ref):
		return
	var pet: Creature = pet_ref
	var ally := instance_from_id(ally_id) as Node3D
	if not is_instance_valid(pet) or not is_instance_valid(ally) or not ally.is_targetable():
		return
	ally.health.heal(ally.health.max_health * heal_fraction)
	if heal_splash > 0.0:
		for other in pet.world.allies_near(pet, ally.global_position, 3.0):
			if other != ally:
				other.health.heal(other.health.max_health * heal_splash)
	pet.world.play_burst.rpc(ally.global_position, Color(0.55, 1.0, 0.55), 1.6)


## Allies within shot_range that are hurt, most injured first.
func _injured(pet: Creature) -> Array:
	var hurt := pet.world.allies_near(pet, pet.global_position, shot_range).filter(
			func(a: Node3D) -> bool: return a.health.fraction() < 0.999)
	hurt.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.health.fraction() < b.health.fraction())
	return hurt
