class_name Player
extends CharacterBody3D
## A tamer. Each client moves its own player locally (owner-authoritative
## position, for responsiveness). Attacks, captures, pet commands, abilities
## and stable actions are requests sent to the server, which validates them.

signal stable_changed

const MAX_PARTY := 3
const MAX_STABLE := 12
const RIVAL_COMMAND := "@rival"

@export_group("Movement")
@export var move_speed := 6.0
@export var acceleration := 50.0
@export var dash_speed := 20.0
@export var dash_duration := 0.15
@export var dash_cooldown := 0.8

@export_group("Combat")
## Deliberately weak: the player weakens creatures, the pets do the real fighting.
@export var attack_damage := 12.0
@export var attack_range := 2.4
@export var attack_arc_degrees := 120.0
@export var attack_cooldown := 0.4
@export var knockback := 6.0
@export var respawn_time := 4.0

@export_group("Taming")
@export var capture_range := 9.0
@export var capture_cooldown := 1.5

# Set by the spawn function before entering the tree.
var peer_id := 1
var display_name := "Player"
var color := Color.WHITE

# Replicated from the server.
var downed := false:
	set(v):
		downed = v
		if is_node_ready():
			_apply_downed()

## Stabled pets as data ({species, level, xp}). Authoritative on the server and
## mirrored to the owning client only.
var stable: Array[Dictionary] = []

## Creature under the mouse cursor (local player only).
var hovered_creature: Creature

var _aim_dir := Vector3.FORWARD
var _aim_point := Vector3.ZERO
var _attack_timer := 0.0
var _capture_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_dir := Vector3.ZERO
var _server_attack_timer := 0.0
var _server_capture_timer := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _material := StandardMaterial3D.new()
var _swing_fx: MeshInstance3D

@onready var world: World = get_tree().get_first_node_in_group("world")
@onready var health: Health = $Health
@onready var model: Node3D = $Model
@onready var name_label: Label3D = $NameLabel


func _enter_tree() -> void:
	# The owning peer controls this node (and its position sync); the server
	# keeps authority over StateSync (health, downed).
	set_multiplayer_authority(peer_id, false)
	$PositionSync.set_multiplayer_authority(peer_id)


func _ready() -> void:
	add_to_group("players")
	_material.albedo_color = color
	$Model/Body.material_override = _material
	name_label.text = display_name
	name_label.modulate = color.lightened(0.3)
	_swing_fx = _build_swing_fx()
	model.add_child(_swing_fx)
	if multiplayer.is_server():
		health.died.connect(_on_died)
	if is_multiplayer_authority():
		world.on_local_player_spawned(self)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_attack_timer -= delta
		_server_capture_timer -= delta
	if not is_multiplayer_authority():
		return

	_attack_timer -= delta
	_capture_timer -= delta
	_dash_cooldown_timer -= delta
	_update_aim()

	if downed:
		velocity = Vector3.ZERO
		return

	var move_dir := _camera_relative(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
		_dash_dir = move_dir if move_dir != Vector3.ZERO else _aim_dir
		_dash_timer = dash_duration
		_dash_cooldown_timer = dash_cooldown

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
	else:
		var target_velocity := move_dir * move_speed
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	health.invulnerable = _dash_timer > 0.0  # replicated to the server

	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	model.rotation.y = atan2(-_aim_dir.x, -_aim_dir.z)

	if Input.is_action_just_pressed("interact"):
		if world.hud.is_stable_open():
			world.hud.close_stable()
		elif world.is_near_stable(global_position):
			world.hud.open_stable()
	if world.hud.is_stable_open():
		return  # mouse is busy with the stable window

	if Input.is_action_pressed("attack") and _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_play_swing_fx()
		request_attack.rpc_id(1, _aim_dir)

	if Input.is_action_just_pressed("capture") and _capture_timer <= 0.0 and hovered_creature:
		_capture_timer = capture_cooldown
		request_capture.rpc_id(1, hovered_creature.name)

	if Input.is_action_just_pressed("command"):
		var rival := world.get_rival()
		if hovered_creature and Combat.are_enemies(self, hovered_creature):
			world.ping(hovered_creature.global_position, Color(1, 0.35, 0.3))
			request_command.rpc_id(1, hovered_creature.name)
		elif rival and rival.global_position.distance_to(_aim_point) < 1.5:
			world.ping(rival.global_position, Color(1, 0.35, 0.3))
			request_command.rpc_id(1, RIVAL_COMMAND)
		else:
			world.ping(global_position, color)
			request_command.rpc_id(1, "")

	for slot in MAX_PARTY:
		if Input.is_action_just_pressed("ability_%d" % (slot + 1)):
			var target_name := String(hovered_creature.name) if hovered_creature else ""
			request_ability.rpc_id(1, slot, _aim_point, target_name)


func is_targetable() -> bool:
	return not downed and not is_queued_for_deletion()


func radius() -> float:
	return 0.4


func party_is_full() -> bool:
	return world.get_pets(peer_id).size() >= MAX_PARTY


func stable_is_full() -> bool:
	return stable.size() >= MAX_STABLE


# --- Requests (client -> server) -------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func request_attack(aim: Vector3) -> void:
	if not _sent_by_owner() or downed or _server_attack_timer > 0.0:
		return
	_server_attack_timer = attack_cooldown * 0.8  # small tolerance for jitter
	aim.y = 0.0
	if aim.length_squared() < 0.01:
		return
	aim = aim.normalized()
	var half_arc := deg_to_rad(attack_arc_degrees) * 0.5
	for enemy in world.enemies_near(self, global_position, attack_range):
		var to := enemy.global_position - global_position
		to.y = 0.0
		if aim.angle_to(to.normalized()) <= half_arc:
			enemy.receive_damage(attack_damage, self, to.normalized() * knockback)
	_show_swing.rpc(aim)


@rpc("any_peer", "call_local", "reliable")
func request_capture(creature_name: String) -> void:
	if not _sent_by_owner() or downed or _server_capture_timer > 0.0:
		return
	var c := world.get_creature(creature_name)
	if c and c.is_rival_pet():
		world.tell(peer_id, "That pet belongs to the rival. Defeat the rival first!", Color(1, 0.8, 0.5))
		return
	if c == null or not c.is_wild() or not c.is_targetable():
		return
	if c.global_position.distance_to(global_position) > capture_range + c.radius():
		world.tell(peer_id, "Too far away to capture.", Color(1, 0.8, 0.5))
		return
	if party_is_full() and stable_is_full():
		world.tell(peer_id, "Your party and stable are both full. Release a pet at the stable first.", Color(1, 0.8, 0.5))
		return
	_server_capture_timer = capture_cooldown * 0.8
	var success := randf() < c.capture_chance()
	world.play_capture_fx.rpc(global_position + Vector3.UP * 1.2, c.global_position + Vector3.UP * c.radius(), success)
	if not success:
		c.on_capture_failed(self)
		world.tell(peer_id, "The %s broke free!" % c.species.display_name, Color(1, 0.6, 0.4))
		return
	world.announce.rpc("%s captured a %s!" % [display_name, c.species.display_name], color.lightened(0.3))
	if party_is_full():
		stable.append(c.to_data())
		c.queue_free()
		_push_stable()
		world.tell(peer_id, "Your party is full, so the %s was sent to the stable (%d/%d)." \
				% [c.species.display_name, stable.size(), MAX_STABLE], Color(0.6, 0.85, 1.0))
	else:
		c.tame(peer_id, world.free_party_slot(peer_id))


## Empty name = regroup (pets drop their focus and return to you).
## RIVAL_COMMAND = attack the rival tamer.
@rpc("any_peer", "call_local", "reliable")
func request_command(creature_name: String) -> void:
	if not _sent_by_owner():
		return
	var focus: Node3D = null
	if creature_name == RIVAL_COMMAND:
		focus = world.get_rival()
	elif creature_name != "":
		focus = world.get_creature(creature_name)
	if focus and not Combat.are_enemies(self, focus):
		focus = null
	for pet in world.get_pets(peer_id):
		pet.set_focus(focus)


## Ask the pet in party `slot` to use its ability at `point` (or on `target_name`).
@rpc("any_peer", "call_local", "reliable")
func request_ability(slot: int, point: Vector3, target_name: String) -> void:
	if not _sent_by_owner() or downed:
		return
	var pet := world.get_party_pet(peer_id, slot)
	if pet == null:
		world.tell(peer_id, "No pet in slot %d." % (slot + 1), Color(1, 0.8, 0.5))
		return
	var target := world.get_creature(target_name) if target_name != "" else null
	var error := pet.queue_ability(point, target)
	if error != "":
		world.tell(peer_id, error, Color(1, 0.8, 0.5))


@rpc("any_peer", "call_local", "reliable")
func request_stable_store(slot: int) -> void:
	if not _can_use_stable():
		return
	var pet := world.get_party_pet(peer_id, slot)
	if pet == null or stable_is_full():
		return
	stable.append(pet.to_data())
	pet.queue_free()
	_push_stable()


## Takes stable entry `index` into the party. If `swap_slot` >= 0, the pet in
## that party slot goes into the stable in its place.
@rpc("any_peer", "call_local", "reliable")
func request_stable_take(index: int, swap_slot: int) -> void:
	if not _can_use_stable() or index < 0 or index >= stable.size():
		return
	var data := stable[index]
	var slot := world.free_party_slot(peer_id)
	if swap_slot >= 0:
		var swapped := world.get_party_pet(peer_id, swap_slot)
		if swapped == null:
			return
		stable[index] = swapped.to_data()
		swapped.queue_free()
		slot = swap_slot
	elif slot >= 0:
		stable.remove_at(index)
	else:
		return  # party full and no swap chosen
	world.spawn_pet(peer_id, data, global_position, slot)
	_push_stable()


@rpc("any_peer", "call_local", "reliable")
func request_stable_release(index: int) -> void:
	if not _can_use_stable() or index < 0 or index >= stable.size():
		return
	var released: Dictionary = stable.pop_at(index)
	_push_stable()
	world.tell(peer_id, "You released your %s back into the wild." \
			% SpeciesDB.get_species(released.species).display_name, Color(0.8, 0.8, 0.8))


# --- Server-side -----------------------------------------------------------------

func receive_damage(amount: float, source: Node3D, _knockback := Vector3.ZERO) -> void:
	if downed:
		return
	if source and not Combat.are_enemies(source, self):
		return  # no friendly fire
	health.take_damage(amount)
	_flash.rpc()


func _on_died() -> void:
	downed = true
	world.announce.rpc("%s is down!" % display_name, Color(1, 0.45, 0.4))
	await get_tree().create_timer(respawn_time).timeout
	if not is_inside_tree():
		return
	health.current = health.max_health
	downed = false
	_respawn_at.rpc_id(peer_id, world.respawn_point(peer_id))


func _can_use_stable() -> bool:
	if not _sent_by_owner():
		return false
	if not world.is_near_stable(global_position):
		world.tell(peer_id, "You need to be at the stable.", Color(1, 0.8, 0.5))
		return false
	return true


func _push_stable() -> void:
	_sync_stable.rpc_id(peer_id, stable)


func _sent_by_owner() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	return multiplayer.is_server() and sender == peer_id


func _sent_by_server() -> bool:
	return multiplayer.get_remote_sender_id() <= 1


# --- Server -> clients -------------------------------------------------------------

@rpc("any_peer", "call_local", "unreliable")
func _show_swing(aim: Vector3) -> void:
	if not _sent_by_server() or is_multiplayer_authority():
		return  # the owner already played it locally
	model.rotation.y = atan2(-aim.x, -aim.z)
	_play_swing_fx()


@rpc("any_peer", "call_local", "unreliable")
func _flash() -> void:
	if not _sent_by_server():
		return
	_material.albedo_color = Color.WHITE
	create_tween().tween_property(_material, "albedo_color", color, 0.15)


@rpc("any_peer", "call_local", "reliable")
func _respawn_at(point: Vector3) -> void:
	if _sent_by_server():
		global_position = point
		velocity = Vector3.ZERO


@rpc("any_peer", "call_local", "reliable")
func _sync_stable(data: Array) -> void:
	if not _sent_by_server():
		return
	if not multiplayer.is_server():  # the server already holds the real list
		stable.assign(data)  # typed arrays arrive untyped over RPC
	stable_changed.emit()


# --- Local helpers -----------------------------------------------------------------

## Converts 2D input into a world direction relative to the camera, so "up" is
## always up-screen regardless of the isometric yaw.
func _camera_relative(input: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null or input == Vector2.ZERO:
		return Vector3.ZERO
	var right := cam.global_basis.x
	var forward := -cam.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return (right.normalized() * input.x - forward.normalized() * input.y).normalized() * minf(input.length(), 1.0)


## Aims toward where the mouse ray hits the ground plane, and finds the hovered creature.
func _update_aim() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var ground := Plane(Vector3.UP, global_position.y)
	var hit = ground.intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	if hit == null:
		return
	_aim_point = hit
	hovered_creature = world.creature_near(hit)
	var to: Vector3 = hit - global_position
	to.y = 0.0
	if to.length() > 0.1:
		_aim_dir = to.normalized()


func _apply_downed() -> void:
	var tween := create_tween()
	tween.tween_property(model, "rotation:x", -PI / 2.0 if downed else 0.0, 0.3)


func _play_swing_fx() -> void:
	_swing_fx.visible = true
	_swing_fx.scale = Vector3(0.6, 1.0, 0.6)
	var tween := create_tween()
	tween.tween_property(_swing_fx, "scale", Vector3.ONE, 0.08)
	tween.tween_callback(_swing_fx.hide).set_delay(0.05)


## Builds a flat fan mesh matching the attack arc, so the visual always
## matches the exported range/arc values.
func _build_swing_fx() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 16
	var half_arc := deg_to_rad(attack_arc_degrees) * 0.5
	for i in segments:
		var a0 := lerpf(-half_arc, half_arc, float(i) / segments)
		var a1 := lerpf(-half_arc, half_arc, float(i + 1) / segments)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(-sin(a0), 0.0, -cos(a0)) * attack_range)
		st.add_vertex(Vector3(-sin(a1), 0.0, -cos(a1)) * attack_range)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.45)
	var fx := MeshInstance3D.new()
	fx.mesh = st.commit()
	fx.material_override = mat
	fx.position.y = 0.1
	fx.visible = false
	return fx
