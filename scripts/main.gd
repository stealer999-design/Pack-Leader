extends Node
## Root scene: connection menu plus the replicated level container.
##
## Shortcuts for quick testing, from the command line:
##   godot -- --host --name=Alice
##   godot -- --join=127.0.0.1 --name=Bob
##   godot -- --solo
##   add --slot=2 to play save slot 2 (otherwise the most recent save is chosen)
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
@onready var save_label: Label = %SaveLabel
@onready var load_panel: Control = %LoadPanel
@onready var slot_list: VBoxContainer = %SlotList
@onready var delete_dialog: ConfirmationDialog = %DeleteDialog
@onready var level: Node = $Level

var _slot_to_delete := -1
var _dialog_closed_frame := -1


func _ready() -> void:
	%NewGameButton.pressed.connect(new_game)
	%LoadGameButton.pressed.connect(open_load_panel)
	%BackButton.pressed.connect(close_load_panel)
	delete_dialog.canceled.connect(func() -> void: _dialog_closed_frame = Engine.get_process_frames())
	delete_dialog.confirmed.connect(func() -> void:
		SaveGame.delete_slot(_slot_to_delete)
		if _slot_to_delete == SaveGame.slot:
			SaveGame.choose_slot(_slot_to_delete)  # now a new game there
		_refresh_save_label()
		open_load_panel())
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
	if args.has("slot"):
		load_slot(clampi(int(args.slot) - 1, 0, SaveGame.MAX_SLOTS - 1))
	else:
		var latest := SaveGame.latest_slot()
		if latest >= 0:
			load_slot(latest)
		else:
			SaveGame.choose_slot(0)
			_refresh_save_label()
	if args.has("name"):
		name_edit.text = args.name
	if args.has("host"):
		host_game.call_deferred()
	elif args.has("join"):
		address_edit.text = args.join
		join_game.call_deferred()
	elif args.has("solo"):
		play_solo.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	# A press that just closed the delete dialog shouldn't close the panel behind it too.
	if event.is_action_pressed("ui_cancel") and load_panel.visible \
			and Engine.get_process_frames() != _dialog_closed_frame:
		close_load_panel()
		get_viewport().set_input_as_handled()


# --- Saves ------------------------------------------------------------------------------

func new_game() -> void:
	var free := SaveGame.first_empty_slot()
	if free < 0:
		status_label.text = "All %d save slots are in use. Open Load Game and delete one first." % SaveGame.MAX_SLOTS
		return
	SaveGame.choose_slot(free)
	_refresh_save_label()
	status_label.text = "New game in slot %d. Now pick Play solo, Host or Join." % (free + 1)


func load_slot(index: int) -> void:
	SaveGame.choose_slot(index)
	if not SaveGame.loaded.is_empty():
		name_edit.text = SaveGame.loaded.get("name", name_edit.text)
	_refresh_save_label()


func open_load_panel() -> void:
	for child in slot_list.get_children():
		child.queue_free()
	for i in SaveGame.MAX_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var label := Label.new()
		label.text = SaveGame.describe(i)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.modulate = Color.WHITE if SaveGame.has_save(i) else Color(1, 1, 1, 0.5)
		row.add_child(label)
		var load_button := Button.new()
		load_button.text = "Playing" if i == SaveGame.slot and SaveGame.has_save(i) else "Load"
		load_button.disabled = not SaveGame.has_save(i)
		load_button.pressed.connect(func() -> void:
			load_slot(i)
			close_load_panel()
			status_label.text = "Loaded slot %d. Now pick Play solo, Host or Join." % (i + 1))
		row.add_child(load_button)
		var delete_button := Button.new()
		delete_button.text = "Delete"
		delete_button.disabled = not SaveGame.has_save(i)
		delete_button.pressed.connect(func() -> void:
			_slot_to_delete = i
			delete_dialog.dialog_text = "Delete %s?\nThis can't be undone." % SaveGame.describe(i)
			delete_dialog.popup_centered())
		row.add_child(delete_button)
		slot_list.add_child(row)
	menu.hide()
	load_panel.show()


func close_load_panel() -> void:
	load_panel.hide()
	menu.show()


func _refresh_save_label() -> void:
	if SaveGame.loaded.is_empty():
		save_label.text = "New game  ·  saves to slot %d" % (SaveGame.slot + 1)
	else:
		save_label.text = "Continue  ·  " + SaveGame.describe(SaveGame.slot)


# --- Starting a game -------------------------------------------------------------------

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


## The in-game menu's "Quit to main menu": save, leave the game, back to the title screen.
func quit_to_menu() -> void:
	_on_connection_lost("Game saved. Pick up where you left off any time.")
	_refresh_save_label()


func _on_connection_lost(message: String) -> void:
	get_tree().paused = false
	SaveGame.save_now()
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
