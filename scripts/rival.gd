class_name Rival
extends CharacterBody3D
## An AI tamer waiting at the end of each level with one pet. It challenges the
## players when they get close; defeating it opens the exit portal.
## Runs on the server; clients see replicated state.

@export var move_speed := 4.5
@export var attack_range := 1.6
@export var attack_cooldown := 1.1
@export var engage_range := 14.0
## The rival never strays further than this from its spot in the arena.
@export var leash_range := 15.0

# Set by the spawn function before entering the tree.
var display_name := "Rival"
var color := Color(0.85, 0.2, 0.25)
var level_number := 1
var home := Vector3.ZERO

# Replicated.
var engaged := false

var target: Node3D
var _attack_timer := 0.0
var _slow_timer := 0.0
var _slow_factor := 1.0
var _blind_timer := 0.0
var _weaken_timer := 0.0
var _weaken_factor := 1.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _material := StandardMaterial3D.new()
## The model's animated parts (see BossModels).
var _parts := {}
var _last_position := Vector3.INF
var _speed := 0.0
var _time := 0.0
var _phase := 0.0
var _rest := {}  ## node -> its rest position, for swaying parts
var _attacking := false
var _one_shot_left := 0.0  ## seconds left of a rigged rival's swing or challenge
var _strike := 0.0  ## a rigged worm's bite: -1 rearing back .. 1 lunging
var _taunt_left := 0.0  ## server: seconds he stands still (a challenge, or a rigged boss's special move)

## How long a rigged rival stands and throws out his arms when he challenges.
const TAUNT_TIME := 1.6


@onready var world: World = get_tree().get_first_node_in_group("world")
@onready var health: Health = $Health
@onready var model: Node3D = $Model
@onready var overhead: Node3D = $Overhead
@onready var name_label: Label3D = $Overhead/NameLabel
@onready var bar_fg: MeshInstance3D = $Overhead/BarFg


func _ready() -> void:
	add_to_group("rivals")
	_material.albedo_color = color
	_parts = _build_model()
	if not _parts.has("person"):  # the rival tamer's person already has the look
		ModelLook.apply(model, 0.06)
	for node: Node3D in _parts.get("sway", []):
		_rest[node] = node.position
	name_label.text = title()
	health.changed.connect(_on_health_changed)
	if multiplayer.is_server():
		health.max_health = roundf(_max_health() * power_scale())
		health.current = health.max_health
		health.died.connect(_on_died)
	_on_health_changed(health.current, health.max_health)
	# The pet may have been replicated before this node; refresh its ring/label colour.
	for c: Creature in world.creatures_root.get_children():
		if c.is_rival_pet() and c.is_node_ready():
			c._apply_ownership()


func _process(delta: float) -> void:
	_animate(delta)
	var cam := get_viewport().get_camera_3d()
	if cam:
		overhead.global_basis = cam.global_basis


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or health.is_dead():
		return
	_attack_timer -= delta
	_slow_timer -= delta
	_blind_timer -= delta
	_weaken_timer -= delta
	var desired := Vector3.ZERO
	_taunt_left -= delta
	if _taunt_left > 0.0:
		velocity = Vector3.ZERO  # a rigged rival plants his feet for the challenge
		return
	if _is_busy():
		_boss_tick(delta)
		return  # mid special move (e.g. burrowed): the move drives the position
	if not engaged:
		for p in world.get_players():
			if p.is_targetable() and _flat_distance(p.global_position) < engage_range:
				_engage()
	else:
		if not _is_valid_target(target) or target.global_position.distance_to(home) > leash_range:
			target = _nearest_enemy()
		desired = _chase_and_attack(target) if target else _steer_to(home)
		_boss_tick(delta)
	if _slow_timer > 0.0:
		desired *= _slow_factor
	velocity.x = desired.x
	velocity.z = desired.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()


## Name shown above the boss and in messages.
func title() -> String:
	return "Rival %s" % display_name


## How the boss is referred to in sentences ("Defeat Rival Kael", "Defeat the Glacier Titan").
func objective_name() -> String:
	return title()


func is_targetable() -> bool:
	return not health.is_dead() and not is_queued_for_deletion()


func radius() -> float:
	return 0.45


func attack_damage() -> float:
	return 6.0 + 2.0 * (level_number - 1)


func slow(duration: float, factor: float) -> void:
	_slow_timer = maxf(_slow_timer, duration)
	_slow_factor = factor


func blind(duration: float) -> void:
	_blind_timer = maxf(_blind_timer, duration)


func weaken(duration: float, factor: float) -> void:
	_weaken_timer = maxf(_weaken_timer, duration)
	_weaken_factor = factor


func poison(dps: float, duration: float) -> void:
	health.add_poison(dps, duration)


## Damage this boss deals after debuffs (Spore Cloud's weaken). Bosses' special
## attacks should pass their damage through this too.
func outgoing(amount: float) -> float:
	return amount * damage_scale() * (_weaken_factor if _weaken_timer > 0.0 else 1.0)


## How much tougher this boss is than its base numbers, matched to the pets
## players bring by now: each area's creatures are five levels higher than the
## last (see World.area_levels), so its boss's health follows the creature
## level multiplier at the top of the area (compared to what the base numbers
## were tuned for).
func power_scale() -> float:
	var top := World.area_levels(level_number).y
	var tuned_for := 2 * level_number + 2
	return (1.0 + 0.15 * (top - 1)) / (1.0 + 0.15 * (tuned_for - 1))


## Bosses hit harder too, but only half as much more, as the tamer's own health
## doesn't grow with levels.
func damage_scale() -> float:
	return 1.0 + (power_scale() - 1.0) * 0.5


## True during a special move that controls the boss's position (no chasing).
func _is_busy() -> bool:
	return false


## Called when a basic attack lands. Bosses override it for on-hit effects.
func _on_attack_hit(_victim: Node3D) -> void:
	pass


func _max_health() -> float:
	return 160.0 + 60.0 * (level_number - 1)


## Extra behaviour while engaged. Bosses override this with their special attacks.
func _boss_tick(_delta: float) -> void:
	pass


func _challenge_text() -> String:
	return "%s challenges you!" % title()


func receive_damage(amount: float, source: Node3D, _knockback := Vector3.ZERO) -> void:
	if not is_targetable():
		return
	if source and not Combat.are_enemies(source, self):
		return
	health.take_damage(amount)
	Combat.leech(source, amount)
	_flash.rpc()
	if not engaged:
		_engage()
	if not _is_valid_target(target) and _is_valid_target(source):
		target = source


func _engage() -> void:
	engaged = true
	if _parts.has("anim") and _parts.anims.has("cast"):
		_taunt_left = TAUNT_TIME
		_taunt.rpc()
	world.announce.rpc(_challenge_text(), color.lightened(0.3))


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for node in world.enemies_near(self, home, leash_range):
		var d := _flat_distance(node.global_position)
		if d < best_dist:
			best = node
			best_dist = d
	return best


func _chase_and_attack(victim: Node3D) -> Vector3:
	var to := victim.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.01:
		return Vector3.ZERO
	model.rotation.y = atan2(-to.x, -to.z)
	if dist > attack_range + victim.radius():
		return to / dist * move_speed
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_swing.rpc()
		if _blind_timer > 0.0 and randf() < 0.5:
			return Vector3.ZERO  # blinded: the attack misses
		victim.receive_damage(outgoing(attack_damage()), self, to / dist * 4.0)
		_on_attack_hit(victim)
	return Vector3.ZERO


func _steer_to(point: Vector3) -> Vector3:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.5:
		return Vector3.ZERO
	model.rotation.y = atan2(-to.x, -to.z)
	return to.normalized() * move_speed


func _is_valid_target(node: Node3D) -> bool:
	return is_instance_valid(node) and Combat.are_enemies(self, node) and node.is_targetable()


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _on_died() -> void:
	world.on_rival_defeated(self)
	queue_free()


func _on_health_changed(current: float, maximum: float) -> void:
	var pct := clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	bar_fg.scale.x = maxf(pct, 0.001)
	bar_fg.position.x = -(1.0 - pct) * (bar_fg.mesh as QuadMesh).size.x * 0.5


@rpc("authority", "call_local", "unreliable")
func _flash() -> void:
	_material.albedo_color = Color.WHITE
	create_tween().tween_property(_material, "albedo_color", color, 0.15)
	if _parts.has("flash"):  # a textured model: a white overlay that fades
		var overlay := StandardMaterial3D.new()
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.albedo_color = Color(1, 1, 1, 0.55)
		for mesh: MeshInstance3D in (_parts.flash as Node).find_children("*", "MeshInstance3D", true, false):
			mesh.material_overlay = overlay
		var fade := create_tween()
		fade.tween_property(overlay, "albedo_color:a", 0.0, 0.15)
		fade.tween_callback(func() -> void:
			for mesh: MeshInstance3D in (_parts.flash as Node).find_children("*", "MeshInstance3D", true, false):
				mesh.material_overlay = null)


## The challenge: a rigged rival throws out his arms (the spell-cast animation).
@rpc("authority", "call_local", "reliable")
func _taunt() -> void:
	if _parts.has("anim") and _parts.anims.has("cast"):
		var anim: Animation = (_parts.anim as AnimationPlayer).get_animation(_parts.anims.cast)
		_play_once(_parts.anims.cast, 0.0, anim.length / TAUNT_TIME)


## Plays a one-off animation (a swing, the challenge) from `from` seconds in;
## walking and standing resume once it ends (see _animate).
func _play_once(anim_name: String, from: float, speed: float) -> void:
	var player: AnimationPlayer = _parts.anim
	player.speed_scale = 1.0
	player.play(anim_name, 0.08, speed)
	player.seek(from, true)
	_attacking = true
	_one_shot_left = (player.get_animation(anim_name).length - from) / speed


## A rigged boss's special-move animation (BossModels "special"), if it has one.
@rpc("authority", "call_local", "reliable")
func _special_anim() -> void:
	if _parts.has("anim") and _parts.anims.has("special"):
		var special: Array = _parts.anims.special
		_play_once(special[0], special[1], special[2])


@rpc("authority", "call_local", "unreliable")
func _swing() -> void:
	if _parts.has("worm"):  # rear back, then lunge with the maw wide
		var strike := create_tween()
		strike.tween_property(self, "_strike", -1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		strike.tween_property(self, "_strike", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		strike.tween_property(self, "_strike", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
		return
	if _parts.has("anim"):
		# Meshy's attack (Kael's skips the wind-up so the bat lands just after the hit).
		var anims: Dictionary = _parts.anims
		_play_once(anims.attack, anims.attack_from, anims.attack_speed)
		return
	if _parts.has("person"):
		_parts.person.swing()  # the rival swings a bat like the players
		return
	if _parts.has("lunge"):  # a solid model: lean in and twist through the swing, then recover
		var turn: Node3D = _parts.lunge
		var rest_y := turn.rotation.y
		var lunge := create_tween()
		lunge.tween_property(turn, "rotation", Vector3(-0.12, rest_y + 0.45, 0.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		lunge.tween_property(turn, "rotation", Vector3(0.22, rest_y - 0.6, 0.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		lunge.tween_property(turn, "rotation", Vector3(0.0, rest_y, 0.0), 0.25).set_trans(Tween.TRANS_SINE)
		lunge.parallel().tween_property(turn, "position:z", 0.0, 0.25)
		turn.position.z = -0.25  # a step into it
		return
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3(1.08, 0.94, 1.08), 0.06)
	tween.tween_property(model, "scale", Vector3.ONE, 0.12)
	# Arms slam forward; jaws gape and snap shut.
	_attacking = true
	var strike := create_tween().set_parallel()
	for arm: Node3D in _parts.get("arms", []):
		var rest := arm.rotation.x
		strike.tween_property(arm, "rotation:x", rest + 1.9, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		strike.tween_property(arm, "rotation:x", rest, 0.25).set_delay(0.18)
	for jaw: Node3D in _parts.get("jaws", []):
		var open: Vector3 = jaw.get_meta("open", Vector3.ZERO)
		strike.tween_property(jaw, "rotation:x", open.x * 2.5, 0.1)
		strike.tween_property(jaw, "rotation:x", 0.25, 0.08).set_delay(0.12)
		strike.tween_property(jaw, "rotation:x", 0.0, 0.2).set_delay(0.25)
	strike.chain().tween_callback(func() -> void: _attacking = false)


## A rigged worm (the Sand Wyrm): a wave sways up the body, faster and wider
## while it moves; a strike (-1 rearing back .. 1 lunging) bends the whole
## chain, and the maw breathes and gapes.
func _animate_worm() -> void:
	var skeleton: Skeleton3D = _parts.worm
	var bones: Array = _parts.bones
	var stride := clampf(_speed / 3.0, 0.0, 1.0)
	for i in bones.size():
		var yaw := sin(_time * (1.3 + stride * 2.0) - i * 0.7) * (0.05 + 0.1 * stride)
		var pitch := sin(_time * 1.1 - i * 0.6) * 0.035 + _strike * (0.16 if _strike > 0.0 else 0.12)
		skeleton.set_bone_pose_rotation(bones[i], Quaternion.from_euler(Vector3(pitch, yaw, 0.0)))
	var gape := 1.0 + (sin(_time * 2.2) * 0.5 + 0.5) * 0.06 + absf(_strike) * 0.3
	skeleton.set_bone_pose_scale(_parts.mouth, Vector3(gape, gape, 1.0))


## A rigged model (Rival Kael): run, walk or stand ready, between one-off moves.
func _animate_rigged(delta: float) -> void:
	var player: AnimationPlayer = _parts.anim
	if _attacking:
		_one_shot_left -= delta
		if _one_shot_left > 0.0:
			return
		_attacking = false
	var anims: Dictionary = _parts.anims
	if _speed > anims.get("run_from", 2.6):
		_loop(player, anims.run, clampf(_speed / anims.run_pace, 0.7, 1.5))
	elif _speed > 0.4:
		_loop(player, anims.walk, clampf(_speed / anims.walk_pace, 0.6, 1.6))
	elif anims.idle is String:
		_loop(player, anims.idle, 1.0)
	elif player.current_animation != anims.idle[0] or player.get_playing_speed() != 0.0:
		# No idle in Meshy's sets: hold one pose (Kael: the attack's opening stance).
		player.speed_scale = 1.0
		player.play(anims.idle[0], 0.25, 0.0)
		player.seek(anims.idle[1], true)


func _loop(player: AnimationPlayer, anim_name: String, speed: float) -> void:
	if player.current_animation != anim_name:
		player.play(anim_name, 0.2)
	player.speed_scale = speed


## Builds the boss's body into Model; returns its animated parts (BossModels).
## The rival tamer is a person; other bosses override this.
func _build_model() -> Dictionary:
	return BossModels.rival(model, _material, color)


## Walking legs and arms (paced by how fast it actually moves, so clients
## animate too), breathing or floating, weaving bodies and idle jaws.
func _animate(delta: float) -> void:
	var pos := global_position
	if _last_position != Vector3.INF and delta > 0.0:
		var moved := Vector2(pos.x - _last_position.x, pos.z - _last_position.z).length() / delta
		_speed = lerpf(_speed, minf(moved, 20.0), 1.0 - exp(-10.0 * delta))
	_last_position = pos
	_time += delta
	var stride := clampf(_speed / 3.0, 0.0, 1.0)
	if _parts.has("anim"):
		_animate_rigged(delta)
		return
	if _parts.has("worm"):
		_animate_worm()
		return
	_phase += delta * (2.5 + _speed * 1.2)
	var legs: Array = _parts.get("legs", [])
	for i in legs.size():
		legs[i].rotation.x = lerpf(legs[i].rotation.x, sin(_phase + PI * i) * 0.55 * stride, 1.0 - exp(-12.0 * delta))
	if not _attacking:
		var arms: Array = _parts.get("arms", [])
		for i in arms.size():
			var base: float = arms[i].get_meta("rest", arms[i].rotation.x)
			arms[i].set_meta("rest", base)
			arms[i].rotation.x = base - sin(_phase + PI * i) * 0.4 * stride + sin(_time * 1.3 + i) * 0.04
		for jaw: Node3D in _parts.get("jaws", []):
			jaw.rotation.x = (sin(_time * 2.4) * 0.5 + 0.5) * jaw.get_meta("open", Vector3.ZERO).x
	if _parts.has("bob"):
		var bob: Array = _parts.bob
		bob[0].position.y = bob[1] + sin(_time * bob[3]) * bob[2] + absf(sin(_phase)) * 0.06 * stride
	if _parts.has("rock"):  # a solid model: rock side to side with each step, leaning into the walk
		var rock: Node3D = _parts.rock
		rock.rotation.z = lerpf(rock.rotation.z, sin(_phase) * 0.07 * stride, 1.0 - exp(-10.0 * delta))
		rock.rotation.x = lerpf(rock.rotation.x, -0.08 * stride, 1.0 - exp(-6.0 * delta))
	var sway: Array = _parts.get("sway", [])
	for i in sway.size():
		var node: Node3D = sway[i]
		var rest: Vector3 = _rest.get(node, node.position)
		node.position = rest + Vector3(sin(_time * 1.8 - i * 0.6) * 0.1 * (i + 1) / sway.size(), 0, 0)
