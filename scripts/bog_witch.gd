class_name BogWitch
extends Rival
## The Bog Witch: the boss of Mirewood Bog levels.
##
## A ranged caster: her bolts hit from a distance and poison. She blinks away
## when someone gets close, drops toxic puddles (with a warning circle first)
## under players and pets, and summons Bogleons at 60% and 30% health.

const BOGLEON := 12  ## SpeciesDB index.

@export var blink_cooldown := 5.0
@export var blink_trigger_range := 3.5
@export var puddle_interval := 7.0
@export var puddle_radius := 3.0
@export var puddle_warning := 1.0
@export var summon_count := 2

var _blink_timer := 0.0
var _puddle_timer := 4.0
var _summon_thresholds: Array[float] = [0.6, 0.3]


func _init() -> void:
	color = Color(0.45, 0.3, 0.55)


func _build_model() -> Dictionary:
	return BossModels.witch(model, _material)


func title() -> String:
	return "Bog Witch"


func objective_name() -> String:
	return "the Bog Witch"


func attack_damage() -> float:
	return 8.0 + 2.0 * (level_number - 1)


func _max_health() -> float:
	return 360.0 + 100.0 * (level_number - 1)


func _challenge_text() -> String:
	return "The Bog Witch cackles. \"More lizards for my stew!\""


## Her bolts poison.
func _on_attack_hit(victim: Node3D) -> void:
	world.play_beam.rpc(global_position + Vector3.UP * 1.6, victim.global_position + Vector3.UP * 0.6,
			Color(0.5, 0.95, 0.3))
	if victim.has_method("poison"):
		victim.poison(outgoing(2.0 + 0.5 * level_number), 4.0)


func _boss_tick(delta: float) -> void:
	_blink_timer -= delta
	_puddle_timer -= delta
	if _blink_timer <= 0.0 and not world.enemies_near(self, global_position, blink_trigger_range).is_empty():
		_blink_timer = blink_cooldown
		_blink()
	if _puddle_timer <= 0.0:
		_puddle_timer = puddle_interval
		_drop_puddles()
	if not _summon_thresholds.is_empty() and health.fraction() <= _summon_thresholds[0]:
		_summon_thresholds.pop_front()
		_summon_toads()


## Teleports to a spot in the arena well away from whoever got close.
func _blink() -> void:
	var from := global_position
	var best := from
	for attempt in 8:
		var offset := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(6.0, leash_range)
		var spot := world.clamp_to_level(home + offset)
		if world.enemies_near(self, spot, 5.0).is_empty():
			best = spot
			break
	global_position = best
	world.play_burst.rpc(from, color.lightened(0.2), 1.5)
	world.play_burst.rpc(best, color.lightened(0.2), 1.5)


func _drop_puddles() -> void:
	var victims := world.enemies_near(self, home, leash_range + 6.0)
	if victims.is_empty():
		return
	if _parts.has("anim"):  # a rigged witch stops to cast the puddles
		_taunt_left = puddle_warning
		_special_anim.rpc()
	victims.shuffle()
	for victim in victims.slice(0, 2):
		var spot := world.clamp_to_level(victim.global_position)
		world.play_telegraph.rpc(spot, puddle_radius, puddle_warning)
		get_tree().create_timer(puddle_warning).timeout.connect(func() -> void:
			if is_instance_valid(self) and not health.is_dead():
				world.add_zone(self, spot, puddle_radius, 5.0, outgoing(4.0 + 1.5 * level_number), Color(0.45, 0.9, 0.3),
						outgoing(2.0 + level_number)))


func _summon_toads() -> void:
	world.announce.rpc("The Bog Witch summons her Bogleons!", color.lightened(0.3))
	for i in summon_count:
		var offset := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * 2.5
		var toad := world.creature_spawner.spawn({
			"species": BOGLEON, "level": World.area_levels(level_number).x + 2,
			"pos": world.clamp_to_level(global_position + offset),
		}) as Creature
		toad.target = target
