class_name Titan
extends Rival
## The Glacier Titan: the boss at the end of Frostfang Peaks levels.
##
## Huge and slow, it has no pet. Instead it:
## - calls down an Avalanche: a red warning circle appears under a player or
##   pet, and after a short delay everything still inside is hit and slowed;
## - summons Frostfinches (which can be captured) at 66% and 33% health.

const FROSTLING := 4  ## SpeciesDB index.

@export var avalanche_interval := 5.0
@export var avalanche_radius := 3.5
@export var avalanche_warning := 1.2
@export var summon_count := 2

var _avalanche_timer := 3.0
var _summon_thresholds: Array[float] = [0.66, 0.33]


func _init() -> void:
	color = Color(0.55, 0.75, 0.95)


func title() -> String:
	return "Glacier Titan"


func objective_name() -> String:
	return "the Glacier Titan"


func radius() -> float:
	return 1.1


func attack_damage() -> float:
	return 12.0 + 3.0 * (level_number - 1)


func _max_health() -> float:
	return 450.0 + 120.0 * (level_number - 1)


func _challenge_text() -> String:
	return "The Glacier Titan awakens!"


func _boss_tick(delta: float) -> void:
	_avalanche_timer -= delta
	if _avalanche_timer <= 0.0:
		_avalanche_timer = avalanche_interval
		_cast_avalanche()
	if not _summon_thresholds.is_empty() and health.fraction() <= _summon_thresholds[0]:
		_summon_thresholds.pop_front()
		_summon_frostlings()


func _cast_avalanche() -> void:
	var victims := world.enemies_near(self, home, leash_range + 6.0)
	if victims.is_empty():
		return
	var spot: Vector3 = victims.pick_random().global_position
	world.play_telegraph.rpc(spot, avalanche_radius, avalanche_warning)
	get_tree().create_timer(avalanche_warning).timeout.connect(func() -> void:
		if not is_instance_valid(self) or health.is_dead():
			return
		for enemy in world.enemies_near(self, spot, avalanche_radius):
			enemy.receive_damage(outgoing(attack_damage() * 1.6), self)
			if enemy.has_method("slow"):
				enemy.slow(2.5, 0.5)
		world.play_burst.rpc(spot, Color(0.75, 0.9, 1.0), avalanche_radius))


func _summon_frostlings() -> void:
	world.announce.rpc("The Glacier Titan calls its Frostfinches!", color.lightened(0.3))
	for i in summon_count:
		var offset := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * 3.0
		var frostling := world.creature_spawner.spawn({
			"species": FROSTLING, "level": World.area_levels(level_number).x + 2,
			"pos": world.clamp_to_level(global_position + offset),
		}) as Creature
		frostling.target = target
