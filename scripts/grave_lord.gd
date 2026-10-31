class_name GraveLord
extends Rival
## The Grave Lord: the boss at the end of the Hollowmere Graveyard (Act 2).
##
## A giant skeleton king with a greatsword and no pet. It:
## - makes Grasping Hands burst out of the ground: a red warning circle appears
##   under a player or pet, then bony hands claw everything still inside and
##   hold it (slowed);
## - raises the dead at 66% and 33% health: skeletons and a zombie climb out
##   of the earth around it.

const SKELETON := 45  ## SpeciesDB indices.
const ZOMBIE := 46

@export var hands_interval := 4.5
@export var hands_radius := 3.2
@export var hands_warning := 1.1
@export var raise_count := 3

var _hands_timer := 3.0
var _raise_thresholds: Array[float] = [0.66, 0.33]


func _init() -> void:
	color = Color(0.86, 0.84, 0.76)


func _build_model() -> Dictionary:
	return BossModels.grave_lord(model, _material)


func title() -> String:
	return "Grave Lord"


func objective_name() -> String:
	return "the Grave Lord"


func radius() -> float:
	return 1.0


func attack_damage() -> float:
	return 12.0 + 3.0 * (level_number - 1)


func _max_health() -> float:
	return 600.0 + 100.0 * (level_number - 1)


func _challenge_text() -> String:
	return "The Grave Lord rises from its tomb!"


func _boss_tick(delta: float) -> void:
	_hands_timer -= delta
	if _hands_timer <= 0.0:
		_hands_timer = hands_interval
		_grasping_hands()
	if not _raise_thresholds.is_empty() and health.fraction() <= _raise_thresholds[0]:
		_raise_thresholds.pop_front()
		_raise_dead()


func _grasping_hands() -> void:
	var victims := world.enemies_near(self, home, leash_range + 6.0)
	if victims.is_empty():
		return
	var spot: Vector3 = victims.pick_random().global_position
	world.play_telegraph.rpc(spot, hands_radius, hands_warning)
	get_tree().create_timer(hands_warning).timeout.connect(func() -> void:
		if not is_instance_valid(self) or health.is_dead():
			return
		for enemy in world.enemies_near(self, spot, hands_radius):
			enemy.receive_damage(outgoing(attack_damage() * 1.4), self)
			if enemy.has_method("slow"):
				enemy.slow(2.0, 0.35)
		world.play_burst.rpc(spot, Color(0.55, 0.9, 0.55), hands_radius))


func _raise_dead() -> void:
	world.announce.rpc("The Grave Lord raises the dead!", Color(0.65, 1.0, 0.65))
	for i in raise_count:
		var offset := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / raise_count + randf() * 0.5) * 3.5
		var spot := world.clamp_to_level(global_position + offset)
		world.play_burst.rpc(spot, Color(0.4, 0.32, 0.25), 1.2)
		var risen := world.creature_spawner.spawn({
			"species": ZOMBIE if i == 0 else SKELETON, "level": World.area_levels(level_number).x + 2,
			"pos": spot,
		}) as Creature
		risen.target = target
