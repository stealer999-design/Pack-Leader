class_name Loot
extends Node3D
## A dropped item on the ground: a little sack glowing in its rarity colour,
## with a beam of light and the item's name above it. The server hands it to
## the first player who walks over it and has room (see World._collect_loot).

# Set by the spawn function before entering the tree.
var item := {}

var _sack: Node3D


func _ready() -> void:
	var color := ItemDB.rarity_color(item)
	_sack = Node3D.new()
	add_child(_sack)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = ItemDB.item_color(item)
	cloth.emission_enabled = true
	cloth.emission = color * 0.35
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.5
	sphere.material = cloth
	body.mesh = sphere
	body.position.y = 0.25
	_sack.add_child(body)
	var tie := MeshInstance3D.new()
	var knot := CylinderMesh.new()
	knot.top_radius = 0.12
	knot.bottom_radius = 0.06
	knot.height = 0.16
	knot.material = cloth
	tie.mesh = knot
	tie.position.y = 0.55
	_sack.add_child(tie)
	# A beam of light in the rarity colour, so loot is easy to spot.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(color, 0.25)
	var beam := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.05
	shaft.bottom_radius = 0.3
	shaft.height = 2.4
	shaft.material = glow
	beam.mesh = shaft
	beam.position.y = 1.2
	add_child(beam)
	var label := Label3D.new()
	label.text = ItemDB.display_name(item)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.009
	label.font_size = 36
	label.outline_size = 10
	label.modulate = color
	label.position.y = 1.5
	add_child(label)
	# Pop out of whatever dropped it.
	_sack.position.y = 1.0
	create_tween().tween_property(_sack, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_sack.rotate_y(delta * 1.5)
