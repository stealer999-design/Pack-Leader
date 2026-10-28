extends Node
## Root scene: connection menu plus the replicated level container.
##
## Command-line shortcuts for quick local testing (run two instances):
##   godot -- --host --name=Alice
##   godot -- --join=127.0.0.1 --name=Bob

const WORLD_SCENE := preload("res://scenes/world.tscn")

@onready var menu: Control = %Menu
@onready var name_edit: LineEdit = %NameEdit
@onready var address_edit: LineEdit = %AddressEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel
@onready var level: Node = $Level


func _ready() -> void:
	host_button.pressed.connect(host_game)
	join_button.pressed.connect(join_game)
	multiplayer.connected_to_server.connect(menu.hide)
	multiplayer.connection_failed.connect(_on_connection_lost.bind("Could not connect."))
	multiplayer.server_disconnected.connect(_on_connection_lost.bind("Disconnected from host."))

	var args := _parse_user_args()
	if args.has("name"):
		name_edit.text = args.name
	if args.has("host"):
		host_game.call_deferred()
	elif args.has("join"):
		address_edit.text = args.join
		join_game.call_deferred()


func host_game() -> void:
	Network.player_name = name_edit.text
	var err := Network.host()
	if err != OK:
		status_label.text = "Could not host: %s" % error_string(err)
		return
	menu.hide()
	level.add_child(WORLD_SCENE.instantiate())
	Network.register_host()


func join_game() -> void:
	Network.player_name = name_edit.text
	var err := Network.join(address_edit.text.strip_edges())
	if err != OK:
		status_label.text = "Could not join: %s" % error_string(err)
		return
	status_label.text = "Connecting..."
	host_button.disabled = true
	join_button.disabled = true


func _on_connection_lost(message: String) -> void:
	# Tear the world down before closing the peer, so no world node ever
	# processes a frame with an offline (self-as-server) peer.
	for child in level.get_children():
		level.remove_child(child)
		child.queue_free()
	Network.close()
	menu.show()
	status_label.text = message
	host_button.disabled = false
	join_button.disabled = false


func _parse_user_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else true
	return args
