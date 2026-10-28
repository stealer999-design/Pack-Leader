class_name SandWyrm
extends Rival
## The Sand Wyrm: the boss of Sunscorch Dunes levels.
##
## Every few seconds it burrows: it sinks into the sand (it can't be targeted or
## hit while underground), tunnels under a player or pet while a warning circle
## grows there, then erupts, damaging and knocking back everything in the
## circle. At half health it whips up sandstorms around the arena.

@export var burrow_interval := 6.0
@export var tunnel_time := 1.6
@export var erupt_radius := 3.5
@export var sandstorm_count := 3

## Replicated: true while underground.
var burrowed := false:
	set(v):
		burrowed = v
		if is_node_ready():
			_apply_burrowed()

var _burrow_timer := 3.0
var _sandstorm_done := false


func _init() -> void:
	color = Color(0.6, 0.4, 0.2)


func title() -> String:
	return "Sand Wyrm"


func objective_name() -> String:
	return "the Sand Wyrm"


func radius() -> float:
	return 1.0


func is_targetable() -> bool:
	return super() and not burrowed


func attack_damage() -> float:
	return 11.0 + 3.0 * (level_number - 1)


func _max_health() -> float:
	return 420.0 + 110.0 * (level_number - 1)


func _challenge_text() -> String:
	return "The Sand Wyrm bursts out of the dunes!"


func _is_busy() -> bool:
	return burrowed


func _boss_tick(delta: float) -> void:
	if burrowed:
		return
	_burrow_timer -= delta
	if _burrow_timer <= 0.0:
		_burrow_timer = burrow_interval
		_burrow()
	if not _sandstorm_done and health.fraction() <= 0.5:
		_sandstorm_done = true
		_summon_sandstorms()


func _burrow() -> void:
	var victims := world.enemies_near(self, home, leash_range + 6.0)
	if victims.is_empty():
		return
	var spot := world.clamp_to_level(victims.pick_random().global_position)
	burrowed = true
	target = null
	world.play_telegraph.rpc(spot, erupt_radius, tunnel_time)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position", spot, tunnel_time)
	tween.tween_callback(_erupt.bind(spot))


func _erupt(spot: Vector3) -> void:
	burrowed = false
	if health.is_dead():
		return
	for enemy in world.enemies_near(self, spot, erupt_radius):
		var push := enemy.global_position - spot
		push.y = 0.0
		enemy.receive_damage(outgoing(attack_damage() * 1.8), self, push.normalized() * 8.0)
	world.play_burst.rpc(spot, Color(0.85, 0.7, 0.4), erupt_radius)


func _summon_sandstorms() -> void:
	world.announce.rpc("The Sand Wyrm whips up a sandstorm!", color.lightened(0.3))
	for i in sandstorm_count:
		var offset := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / sandstorm_count) * 7.0
		world.add_zone(self, world.clamp_to_level(home + offset), 3.5, 10.0, outgoing(6.0 + 2.0 * (level_number - 1)),
				Color(0.85, 0.7, 0.4))


func _apply_burrowed() -> void:
	# Sink into (or rise out of) the sand. Collision is off while underground.
	$CollisionShape3D.set_deferred("disabled", burrowed)
	overhead.visible = not burrowed
	create_tween().tween_property(model, "position:y", -3.5 if burrowed else 0.0, 0.3)
