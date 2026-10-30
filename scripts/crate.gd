class_name Crate
extends StaticBody3D
## A breakable crate on the path. Players smash it with their attack and it
## spills coins. Gold crates take more hits and hold more coins.

# Set by the spawn function before entering the tree.
var gold := false
var level_number := 1

var _hp := 20.0
var _material := StandardMaterial3D.new()

@onready var world: World = get_tree().get_first_node_in_group("world")
@onready var model: Node3D = $Model


func _ready() -> void:
	add_to_group("crates")
	_hp = 40.0 if gold else 20.0
	_material.albedo_color = Color(0.95, 0.75, 0.2) if gold else Color(0.6, 0.42, 0.25)
	_material.metallic = 0.6 if gold else 0.0
	_material.roughness = 0.35 if gold else 0.9
	$Model/Box.material_override = _material


func radius() -> float:
	return 0.6


func coin_value() -> int:
	var base := 15 if gold else randi_range(3, 6)
	return base + (level_number - 1) * (3 if gold else 1)


## Server only.
func hit(damage: float) -> void:
	if is_queued_for_deletion():
		return
	_hp -= damage
	if _hp > 0.0:
		_shake.rpc()
		return
	world.spill_coins(global_position, coin_value())
	world.roll_loot(global_position, 0.4 if gold else 0.12)
	world.play_burst.rpc(global_position, _material.albedo_color, 1.5)
	queue_free()


@rpc("authority", "call_local", "unreliable")
func _shake() -> void:
	var tween := create_tween()
	tween.tween_property(model, "rotation:z", 0.15, 0.05)
	tween.tween_property(model, "rotation:z", -0.1, 0.05)
	tween.tween_property(model, "rotation:z", 0.0, 0.05)
