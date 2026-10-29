class_name PauseMenu
extends Control
## The in-game menu (Esc when no other window is open): resume, save now, or
## quit to the main menu (which saves first). In solo the game pauses while it
## is open; in multiplayer the game keeps running for everyone.

var _title: Label
var _note: Label
var _quit_game: Button


func _init() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working while the game is paused
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(360, 0)
	margin.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.modulate = Color(1, 0.85, 0.5)
	box.add_child(_title)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.modulate = Color(1, 1, 1, 0.7)
	box.add_child(_note)
	box.add_child(_button("Resume", close))
	box.add_child(_button("Save game", _save))
	box.add_child(_button("Quit to main menu", _quit_to_menu))
	_quit_game = _button("Quit game", _quit_game_pressed)
	_quit_game.visible = not OS.has_feature("web")  # a browser tab can't close itself
	box.add_child(_quit_game)
	var hint := Label.new()
	hint.text = "[Esc] resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	box.add_child(hint)


func open() -> void:
	var solo := multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	_title.text = "Paused" if solo else "Menu"
	_note.text = _slot_text() + ("" if solo else "\nThe game keeps running for the other players.")
	show()
	get_tree().paused = solo


func close() -> void:
	hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _save() -> void:
	SaveGame.save_now(true)
	_note.text = "Saved to slot %d at %s." % [SaveGame.slot + 1, Time.get_time_string_from_system().substr(0, 5)]


func _quit_to_menu() -> void:
	close()
	get_tree().current_scene.quit_to_menu()


func _quit_game_pressed() -> void:
	close()
	SaveGame.save_now()
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()


func _slot_text() -> String:
	return "Saving to slot %d. Your game also saves automatically." % (SaveGame.slot + 1) if SaveGame.slot >= 0 else ""


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(action)
	return button
