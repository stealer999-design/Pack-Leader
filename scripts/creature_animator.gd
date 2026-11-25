class_name CreatureAnimator
extends Node
## Animates a creature's CreatureModel on every peer, from how fast it is
## actually moving (measured from its position, so nothing extra is synced):
##
## - cats and dogs: a trotting walk (diagonal legs together), a body bob, tail
##   sway (cats, slow) or wag (dogs, fast and faster when running);
## - birds: legs step, the body hops, the wings flap when moving and twitch at rest;
## - lizards: legs paddle in a sprawl, the body and tail swing side to side;
## - skeletons stride with swinging arms; zombies shamble, lurching side to
##   side with their arms held out in front;
## - everyone breathes a little while standing; fainted pets stay still.

var creature: Creature
var body: Node3D
var body_type := "cat"

var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _tail: Node3D
var _base_y := 0.0
var _last_position := Vector3.INF
var _speed := 0.0
var _phase := 0.0
var _time := 0.0


## A Meshy model's animations (PetModels): played instead of moving the shapes.
var anim: AnimationPlayer
var _one_shot_left := 0.0
## Playing its Die animation (a monster with one, killed): nothing else plays.
var dying := false
## Dancing (a boss whose foe has lost every pet; Creature._set_dancing).
var dancing := false
var _running := false  ## playing its Run (a model with one, moving fast)


func setup(owner_creature: Creature, model_body: Node3D, kind: String, player: AnimationPlayer = null) -> void:
	anim = player
	creature = owner_creature
	body = model_body
	body_type = kind
	_base_y = body.position.y
	for i in 4:
		var leg := body.get_node_or_null("Leg%d" % i) as Node3D
		if leg:
			_legs.append(leg)
	for i in 2:
		var wing := body.get_node_or_null("Wing%d" % i) as Node3D
		if wing:
			_wings.append(wing)
	for i in 2:
		var arm := body.get_node_or_null("Arm%d" % i) as Node3D
		if arm:
			arm.rotation.x = arm.get_meta("rest", 0.0)
			_arms.append(arm)
	_tail = body.get_node_or_null("Tail") as Node3D
	_time = randf() * 10.0  # so a group doesn't breathe in sync


func _process(delta: float) -> void:
	if not is_instance_valid(creature) or delta <= 0.0:
		return
	var pos := creature.global_position
	if _last_position != Vector3.INF:
		var moved := Vector2(pos.x - _last_position.x, pos.z - _last_position.z).length() / delta
		_speed = lerpf(_speed, minf(moved, 20.0), 1.0 - exp(-10.0 * delta))
	_last_position = pos
	_time += delta
	var settle := 1.0 - exp(-10.0 * delta)
	if anim:
		_animate_meshy(delta)
		return
	if creature.fainted:
		for pivot in _legs + _wings:
			pivot.rotation = pivot.rotation.lerp(Vector3.ZERO, settle)
		body.position.y = lerpf(body.position.y, _base_y, settle)
		body.rotation.y = lerpf(body.rotation.y, 0.0, settle)
		return

	# How far into a full stride, by how fast it moves for its size.
	var size := creature.body_size()
	var stride := clampf(_speed / (3.0 * size), 0.0, 1.0)
	_phase += delta * (3.0 + _speed * 2.2 / size)
	var step := sin(_phase)
	var breathe := sin(_time * 2.2) * 0.012 * (1.0 - stride)
	match body_type:
		"bird":
			_walk_bird(step, stride, breathe)
		"lizard":
			_walk_lizard(step, stride, breathe)
		"scorpion":
			_walk_lizard(step, stride, breathe)
		"skeleton", "zombie", "mummy", "imp", "golem", "wraith", "yeti":
			_walk_upright(step, stride, breathe)
		_:
			_walk_four_legs(step, stride, breathe)


## A Meshy model: walk at the pace it moves, stand idle, and play one-off moves.
func _animate_meshy(delta: float) -> void:
	if dying or dancing:
		return
	if creature.fainted:
		anim.pause()
		return
	if _one_shot_left > 0.0:
		_one_shot_left -= delta
		return
	if _speed > 0.3:
		var scale_k: float = body.get_node("Meshy").get_meta("scale", 1.0) * creature.body_size()
		var sp_name: String = creature.species.display_name if creature.species else ""
		var pace := PetModels.walk_pace(body_type, sp_name) * scale_k
		# A model with a Run runs when its walk would play too fast (PetModels.RUN_FROM).
		if anim.has_animation("Run") and PetModels.RUN_PACE_BY_SPECIES.has(sp_name):
			var walk_rate := _speed / maxf(pace, 0.01)
			if walk_rate > PetModels.RUN_FROM or (_running and walk_rate > PetModels.WALK_BELOW):
				_running = true
				var run_pace: float = PetModels.RUN_PACE_BY_SPECIES[sp_name] * scale_k
				if anim.current_animation != "Run":
					anim.play("Run", 0.2)
				anim.speed_scale = clampf(_speed / maxf(run_pace, 0.01), 0.5, 2.0)
				return
			_running = false
		if anim.current_animation != "Walk":
			anim.play("Walk", 0.2)
		anim.speed_scale = clampf(_speed / maxf(pace, 0.01), 0.4, PetModels.max_walk_speed(body_type, sp_name))
	elif anim.current_animation != "Idle" or not anim.is_playing():
		anim.speed_scale = 1.0
		anim.play("Idle", 0.25)


## The model's Die animation, played to its end and held (true if it has one).
func play_death() -> bool:
	if anim == null or not anim.has_animation("Die"):
		return false
	dying = true
	anim.speed_scale = 1.0
	anim.play("Die", 0.05)
	return true


## Starts (on) or ends the model's Dance.
func play_dance(on: bool) -> void:
	if anim == null or not anim.has_animation("Dance"):
		return
	dancing = on
	_one_shot_left = 0.0
	if on:
		anim.speed_scale = 1.0
		anim.play("Dance", 0.2)


## How long the model's Die animation runs (0 without one).
func death_length() -> float:
	return anim.get_animation("Die").length if anim and anim.has_animation("Die") else 0.0


## A one-off animation (an attack, an ability), if the model has it.
func play_once(anim_name: String, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(anim_name) or creature.fainted:
		return
	speed *= PetModels.anim_speed(creature.species.display_name if creature.species else "", anim_name)
	anim.speed_scale = 1.0
	anim.play(anim_name, 0.08, speed)
	_one_shot_left = anim.get_animation(anim_name).length / speed


func _walk_four_legs(step: float, stride: float, breathe: float) -> void:
	for i in _legs.size():
		var forward := step if i == 0 or i == 3 else -step  # diagonal pairs step together
		_legs[i].rotation.x = forward * 0.7 * stride
	body.position.y = _base_y + absf(cos(_phase)) * 0.05 * stride + breathe
	body.rotation.y = 0.0
	if _tail:
		if body_type == "dog":
			_tail.rotation.y = sin(_time * (10.0 + 8.0 * stride)) * 0.55
		else:
			_tail.rotation.y = sin(_time * 2.0) * 0.25 + step * 0.15 * stride
	_flap(stride, 9.0)  # hybrid cats with wings


func _walk_bird(step: float, stride: float, breathe: float) -> void:
	for i in _legs.size():
		_legs[i].rotation.x = (step if i == 0 else -step) * 0.8 * stride
	body.position.y = _base_y + absf(step) * 0.09 * stride + breathe  # little hops
	if _tail:
		_tail.rotation.x = sin(_time * 3.0) * 0.08 - stride * 0.15
	_flap(stride, 16.0)


func _walk_lizard(step: float, stride: float, breathe: float) -> void:
	for i in _legs.size():
		var forward := step if i == 0 or i == 3 else -step
		_legs[i].rotation.y = forward * 0.6 * stride  # paddle forwards and back in the sprawl
	var sway := step * 0.18 * stride
	body.rotation.y = sway
	body.position.y = _base_y + breathe
	if _tail:
		_tail.rotation.y = -sway * 2.2 + sin(_time * 1.5) * 0.12


func _walk_upright(step: float, stride: float, breathe: float) -> void:
	var zombie := body_type == "zombie" or body_type == "mummy"
	if body_type == "wraith":  # no legs: it drifts, bobbing gently, arms out
		body.position.y = _base_y + 0.12 + sin(_time * 2.2) * 0.06
		body.rotation.x = -0.15 * stride
		for i in _arms.size():
			_arms[i].rotation.x = _arms[i].get_meta("rest", 0.0) + sin(_time * 1.6 + i) * 0.12
		return
	for i in _legs.size():
		_legs[i].rotation.x = (step if i == 0 else -step) * (0.45 if zombie else 0.6) * stride
	for i in _arms.size():
		var rest: float = _arms[i].get_meta("rest", 0.0)
		if zombie:  # held out, bobbing a little out of step
			_arms[i].rotation.x = rest + sin(_time * 2.0 + i * 1.7) * 0.08 + step * 0.05 * stride
		else:  # swinging opposite the legs
			_arms[i].rotation.x = rest + (-step if i == 0 else step) * 0.5 * stride
	body.position.y = _base_y + absf(step) * 0.04 * stride + breathe
	body.rotation.z = step * 0.12 * stride if zombie else 0.0  # the lurch
	_flap(stride, 14.0)  # imps' little wings


## Wings: a quick flap while moving, a slow twitch at rest. Wing0 is on the left.
func _flap(stride: float, speed: float) -> void:
	for i in _wings.size():
		var side := -1.0 if i == 0 else 1.0
		var flap := sin(_time * speed) * 0.6 * stride + sin(_time * 1.7) * 0.06
		_wings[i].rotation.z = side * (flap + 0.1 * stride)
