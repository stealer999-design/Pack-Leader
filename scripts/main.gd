extends Node
## Root scene: connection menu plus the replicated level container.
##
## Shortcuts for quick testing, from the command line:
##   godot -- --host --name=Alice
##   godot -- --join=127.0.0.1 --name=Bob
##   godot -- --solo
## or, in the browser build, as URL parameters:
##   index.html?join=wss://example.com&name=Bob
##   index.html?solo

const WORLD_SCENE := preload("res://scenes/world.tscn")

@onready var menu: Control = %Menu
@onready var name_edit: LineEdit = %NameEdit
@onready var address_edit: LineEdit = %AddressEdit
@onready var solo_button: Button = %SoloButton
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel
@onready var level: Node = $Level


func _ready() -> void:
	solo_button.pressed.connect(play_solo)
	host_button.pressed.connect(host_game)
	join_button.pressed.connect(join_game)
	multiplayer.connected_to_server.connect(menu.hide)
	multiplayer.connection_failed.connect(_on_connection_lost.bind("Could not connect."))
	multiplayer.server_disconnected.connect(_on_connection_lost.bind("Disconnected from host."))
	if not Network.can_host():
		host_button.hide()
		address_edit.placeholder_text = "Host address (e.g. wss://...)"
		status_label.text = "Play solo, or join a game hosted from the desktop version."

	var args := _launch_args()
	if args.has("name"):
		name_edit.text = args.name
	if args.has("host"):
		host_game.call_deferred()
	elif args.has("join"):
		address_edit.text = args.join
		join_game.call_deferred()
	elif args.has("solo"):
		play_solo.call_deferred()


func play_solo() -> void:
	Network.player_name = name_edit.text
	Network.start_solo()
	_start_world()


func host_game() -> void:
	Network.player_name = name_edit.text
	var err := Network.host()
	if err != OK:
		status_label.text = "Could not host: %s" % error_string(err)
		return
	_start_world()


func join_game() -> void:
	Network.player_name = name_edit.text
	var err := Network.join(address_edit.text)
	if err != OK:
		status_label.text = "Could not join: %s" % error_string(err)
		return
	status_label.text = "Connecting to %s ..." % Network.server_url(address_edit.text)
	_set_buttons_disabled(true)


func _start_world() -> void:
	menu.hide()
	level.add_child(WORLD_SCENE.instantiate())
	Network.register_host()


func _on_connection_lost(message: String) -> void:
	# Tear the world down before closing the peer, so no world node ever
	# processes a frame with an offline (self-as-server) peer.
	for child in level.get_children():
		level.remove_child(child)
		child.queue_free()
	Network.close()
	menu.show()
	status_label.text = message
	_set_buttons_disabled(false)


func _set_buttons_disabled(disabled: bool) -> void:
	solo_button.disabled = disabled
	host_button.disabled = disabled
	join_button.disabled = disabled


## Command-line user args (desktop) or URL query parameters (browser).
func _launch_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else true
	if OS.has_feature("web"):
		var query = JavaScriptBridge.eval("window.location.search")
		if query is String:
			for pair in query.trim_prefix("?").split("&", false):
				var parts: PackedStringArray = pair.split("=", true, 1)
				args[parts[0].uri_decode()] = parts[1].uri_decode() if parts.size() > 1 else true
	return args
