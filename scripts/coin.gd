class_name Coin
extends Node3D
## A coin on the ground. The server hands it to the first player who walks
## over it (see World._collect_coins).

# Set by the spawn function before entering the tree.
var value := 1

@onready var mesh: Node3D = $Mesh


func _ready() -> void:
	add_to_group("coins")
	# Pop out of the crate.
	mesh.position.y = 1.2
	create_tween().tween_property(mesh, "position:y", 0.45, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	mesh.rotate_y(delta * 3.0)
