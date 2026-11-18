class_name ZombieFish
extends Rival
## Howard the Zombie Fish: the boss at the end of the Hollowmere Graveyard
## (Act 2). A huge rotting fish lurching about on a pair of zombie legs, with
## no pet. He:
## - spits a Rotten Splash: a red warning circle appears under a player or pet,
##   then a gush of foul water hits everything still inside and slows it;
## - calls up the dead at 66% and 33% health: skeletons and a zombie climb out
##   of the graves around him.

const SKELETON := 45  ## SpeciesDB indices.
const ZOMBIE := 46

@export var splash_interval := 4.5
@export var splash_radius := 3.2
@export var splash_warning := 1.1
@export var raise_count := 3

var _splash_timer := 3.0
var _raise_thresholds: Array[float] = [0.66, 0.33]


func _init() -> void:
	color = Color(0.36, 0.46, 0.38)


func _build_model() -> Dictionary:
	return BossModels.zombie_fish(model, _material)


func title() -> String:
	return "Howard the Zombie Fish"


func objective_name() -> String:
	return "Howard the Zombie Fish"


func radius() -> float:
	return 1.0


func attack_damage() -> float:
	return 12.0 + 3.0 * (level_number - 1)


func _max_health() -> float:
	return 600.0 + 100.0 * (level_number - 1)


func _challenge_text() -> String:
	return "Howard the Zombie Fish flops out of his grave!"


func _boss_tick(delta: float) -> void:
	_splash_timer -= delta
	if _splash_timer <= 0.0:
		_splash_timer = splash_interval
		_rotten_splash()
	if not _raise_thresholds.is_empty() and health.fraction() <= _raise_thresholds[0]:
		_raise_thresholds.pop_front()
		_raise_dead()


func _rotten_splash() -> void:
	var victims := world.enemies_near(self, home, leash_range + 6.0)
	if victims.is_empty():
		return
	var spot: Vector3 = victims.pick_random().global_position
	world.play_telegraph.rpc(spot, splash_radius, splash_warning)
	if _parts.has("anim"):  # a rigged Howard stops to cast it
		_taunt_left = splash_warning
		_special_anim.rpc("special")
	get_tree().create_timer(splash_warning).timeout.connect(func() -> void:
		if not is_instance_valid(self) or health.is_dead():
			return
		for enemy in world.enemies_near(self, spot, splash_radius):
			enemy.receive_damage(outgoing(attack_damage() * 1.4), self)
			if enemy.has_method("slow"):
				enemy.slow(2.0, 0.35)
		world.play_burst.rpc(spot, Color(0.45, 0.7, 0.4), splash_radius))


func _raise_dead() -> void:
	world.announce.rpc("Howard the Zombie Fish calls up the dead!", Color(0.65, 1.0, 0.65))
	if _parts.has("anim"):  # a rigged Howard stands and screams them up
		_taunt_left = 2.0
		_special_anim.rpc("scream")
	for i in raise_count:
		var offset := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / raise_count + randf() * 0.5) * 3.5
		var spot := world.clamp_to_level(global_position + offset)
		world.play_burst.rpc(spot, Color(0.4, 0.32, 0.25), 1.2)
		var risen := world.creature_spawner.spawn({
			"species": ZOMBIE if i == 0 else SKELETON, "level": World.area_levels(level_number).x + 2,
			"pos": spot,
		}) as Creature
		risen.target = target
