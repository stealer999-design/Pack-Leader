class_name HUD
extends CanvasLayer
## Local player's view: health, pet party (with abilities), hover info, the
## message feed and the stable window.

const MAX_MESSAGES := 4  ## The feed keeps only the big news; the rest pops up over heads (World.popup).

var _player: Player
var _party_refresh := 0.0
var _dialog_closed_frame := -1
var skill_window: SkillWindow
var mini_map: MiniMap
var bat_shop_panel: PanelContainer
var breeder_window: BreederWindow
var pause_menu: PauseMenu
var inventory_window: InventoryWindow
## The action bar along the bottom (health, potion, capture, bat, pets, buttons).
var action_bar: ActionBar
var travel_window: PanelContainer
var _travel_list: VBoxContainer
var _in_travel_portal := false
var _new_gear := 0  ## Gear picked up since the inventory was last opened.
var _bat_shop_info: Label
var _bat_buy_button: Button
## The bat shop's sell grid: one box per bag place; clicked ones are marked to sell.
var _sell_slots: Array = []
var _sell_marked := {}  ## bag index -> true
var _sell_button: Button
var _sell_all_button: Button
var _stable_party_signature := ""
var _party_slots: Array[PetSlot] = []
var _bed_slots: Array[PetSlot] = []
var _reserve_slots: Array[PetSlot] = []
## The slot whose pet is waiting for the release confirmation.
var _pending_release: PetSlot

@onready var name_label: Label = %NameLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var party_title: Label = %PartyTitle
@onready var party_list: VBoxContainer = %PartyList
@onready var hover_label: Label = %HoverLabel
@onready var interact_label: Label = %InteractLabel
@onready var messages: VBoxContainer = %Messages
@onready var downed_label: Label = %DownedLabel
@onready var stable_panel: Control = %StablePanel
@onready var party_slots_box: VBoxContainer = %PartySlots
@onready var bed_grid: GridContainer = %BedGrid
@onready var stable_title: Label = %StableTitle
@onready var release_gate: PetSlot = %ReleaseGate
@onready var release_dialog: ConfirmationDialog = %ReleaseDialog
@onready var coins_label: Label = %CoinsLabel
@onready var shop_panel: Control = %ShopPanel
@onready var shop_info: Label = %ShopInfo
@onready var buy_button: Button = %BuyButton
@onready var boost_button: Button = %BoostButton
@onready var level_label: Label = %LevelLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var progress_bar: ProgressBar = %ProgressBar


func _ready() -> void:
	_build_stable_slots()
	buy_button.pressed.connect(func() -> void: _player.request_buy_potion.rpc_id(1))
	boost_button.pressed.connect(func() -> void: _player.request_buy_boost.rpc_id(1))
	skill_window = SkillWindow.new()
	skill_window.theme = stable_panel.theme
	skill_window.add_theme_stylebox_override("panel", stable_panel.get_theme_stylebox("panel"))
	add_child(skill_window)
	_build_bat_shop_panel()
	breeder_window = BreederWindow.new()
	breeder_window.theme = shop_panel.theme
	breeder_window.add_theme_stylebox_override("panel", shop_panel.get_theme_stylebox("panel"))
	add_child(breeder_window)
	inventory_window = InventoryWindow.new()
	add_child(inventory_window)
	_build_travel_window()
	pause_menu = PauseMenu.new()
	pause_menu.theme = shop_panel.theme
	pause_menu.get_node("Panel").add_theme_stylebox_override("panel", shop_panel.get_theme_stylebox("panel"))
	add_child(pause_menu)
	_decorate()
	mini_map = MiniMap.new()
	add_child(mini_map)
	move_child(mini_map, 0)  # under the windows
	action_bar = ActionBar.new(self)
	health_bar.hide()  # health is the orb on the action bar
	add_child(action_bar)
	move_child(action_bar, 1)
	add_child(action_bar.menu_row)
	move_child(action_bar.menu_row, 2)


func bind(player: Player) -> void:
	_player = player
	skill_window.player = player
	mini_map.player = player
	breeder_window.player = player
	inventory_window.bind(player)
	action_bar.player = player
	name_label.text = player.display_name
	name_label.modulate = player.color.lightened(0.3)
	player.health.changed.connect(_on_health_changed)
	player.stable_changed.connect(_on_stable_changed)
	_on_health_changed(player.health.current, player.health.max_health)


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	downed_label.visible = _player.downed
	var near_stable := _player.world.is_near_stable(_player.global_position)
	var near_shop := _player.world.is_near_shop(_player.global_position)
	if is_stable_open() and not near_stable:
		close_stable()
	if shop_panel.visible and not near_shop:
		shop_panel.hide()
	var near_bat_shop := _player.world.is_near_bat_shop(_player.global_position)
	if bat_shop_panel.visible and not near_bat_shop:
		bat_shop_panel.hide()
	# The travel portal: stepping in opens the travel window; stepping out closes it.
	var near_travel := _player.world.is_near_travel_portal(_player.global_position) and not _player.downed
	if near_travel and not _in_travel_portal and not is_window_open():
		open_travel()
	if not near_travel and travel_window.visible:
		travel_window.hide()
	_in_travel_portal = near_travel
	var near_breeder := _player.world.is_near_breeder(_player.global_position)
	if breeder_window.visible and not near_breeder:
		breeder_window.hide()
	interact_label.visible = (near_stable or near_shop or near_bat_shop or near_breeder) and not is_window_open()
	if near_stable:
		interact_label.text = "[F]  Open stable"
	elif near_shop:
		interact_label.text = "[F]  Visit the lemonade stand"
	elif near_bat_shop:
		interact_label.text = "[F]  Visit the bat shop"
	else:
		interact_label.text = "[F]  Visit the breeder"
	if shop_panel.visible:
		_update_shop()
	if bat_shop_panel.visible:
		_update_bat_shop()
	if breeder_window.visible:
		breeder_window.refresh()
	_update_hover()
	_update_objective()
	_update_coins()
	_party_refresh -= delta
	if _party_refresh <= 0.0:
		_party_refresh = 0.2
		_rebuild_party()
		if is_stable_open() and _party_signature() != _stable_party_signature:
			_refresh_stable()


## A tutorial tip in a window in the middle of the screen. Solo games pause
## behind it (the other players' games can't be paused). Closed with its
## button, Enter, Esc, or E, which also runs `on_e` (e.g. throw the treat).
func show_tutorial(title_text: String, body: String, on_e: Callable = Callable()) -> void:
	var panel := TutorialPanel.new()
	panel.name = "Tutorial"
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.theme = UiTheme.get_theme()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	box.add_child(title)
	UiIcons.title(title, "net", UiTheme.ACCENT)
	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(460, 0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 18)
	box.add_child(text)
	var button := Button.new()
	button.text = "Got it   [E]"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(200, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiIcons.button(button, "play")
	box.add_child(button)
	var solo := multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	if solo:
		get_tree().paused = true
	var close := func(run_e: bool) -> void:
		if not is_instance_valid(panel):
			return
		panel.queue_free()
		if solo:
			get_tree().paused = false
		if run_e and on_e.is_valid():
			on_e.call()
	button.pressed.connect(close.bind(false))
	panel.close = close


## The tutorial window: keeps listening while the game is paused behind it.
## E closes it and does its action; Enter or Esc just close it.
class TutorialPanel:
	extends PanelContainer

	var close: Callable

	func _input(event: InputEvent) -> void:
		if not close.is_valid() or not event.is_pressed() or event.is_echo():
			return
		if event.is_action_pressed("capture"):
			get_viewport().set_input_as_handled()
			close.call(true)
		elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			close.call(false)


func show_message(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	messages.add_child(label)
	if messages.get_child_count() > MAX_MESSAGES:
		messages.get_child(0).queue_free()
	var tween := label.create_tween()
	tween.tween_interval(4.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)


# --- Windows ---------------------------------------------------------------------------

## Escape closes the stable, shop or skills, but a press that closes the release dialog
## on top of the stable shouldn't close the stable as well.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (release_dialog.visible or inventory_window._discard_dialog.visible):
		_dialog_closed_frame = Engine.get_process_frames()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not is_window_open() and not mini_map.expanded:
		pause_menu.open()  # nothing else to close: the in-game menu
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and mini_map.expanded:
		mini_map.toggle_expanded()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and is_window_open() \
			and Engine.get_process_frames() != _dialog_closed_frame:
		close_windows()
		get_viewport().set_input_as_handled()


func is_window_open() -> bool:
	return stable_panel.visible or shop_panel.visible or skill_window.visible or bat_shop_panel.visible \
			or breeder_window.visible or pause_menu.visible or inventory_window.visible or travel_window.visible


func close_windows() -> void:
	stable_panel.hide()
	shop_panel.hide()
	skill_window.hide()
	bat_shop_panel.hide()
	breeder_window.hide()
	inventory_window.hide()
	travel_window.hide()


## The inventory (I) can open anywhere; it replaces any other open window.
func toggle_inventory() -> void:
	if inventory_window.visible:
		inventory_window.hide()
		return
	close_windows()
	inventory_window.open()
	_new_gear = 0
	_update_inventory_button()


## Gear just picked up: the Inventory button says how many new items there
## are (until the inventory is opened) and flashes.
func note_new_gear() -> void:
	_new_gear += 1
	_update_inventory_button()
	if inventory_window.visible:
		_new_gear = 0
		_update_inventory_button()
		return
	action_bar.inventory_slot.flash()


func _update_inventory_button() -> void:
	var slot := action_bar.inventory_slot
	slot.badge = "%d" % _new_gear if _new_gear > 0 else ""
	slot.highlight = _new_gear > 0
	slot.refresh()


## The skills screen (K) can open anywhere; it replaces any other open window.
func toggle_skills() -> void:
	if skill_window.visible:
		skill_window.hide()
		return
	close_windows()
	skill_window.open()


func open_breeder() -> void:
	breeder_window.open()


func open_bat_shop() -> void:
	_sell_marked.clear()
	bat_shop_panel.show()
	_update_bat_shop()


func _update_bat_shop() -> void:
	# The sell grid follows the bag (items can arrive or leave while it's open).
	var total := 0
	for i in _sell_slots.size():
		var slot = _sell_slots[i]
		var item: Dictionary = _player.bag[i] if i < _player.bag.size() else {}
		if slot.item != item:
			slot.item = item
		if item.is_empty():
			_sell_marked.erase(i)
		slot.marked = _sell_marked.has(i)
		if _sell_marked.has(i):
			total += ItemDB.sell_price(item)
	var count := _sell_marked.size()
	_sell_button.disabled = count == 0
	_sell_button.text = "Sell %d item%s for %d coin%s" % [count, "" if count == 1 else "s", total, "" if total == 1 else "s"] \
			if count > 0 else "Mark items to sell"
	var any := _player.bag.any(func(it: Dictionary) -> bool: return not it.is_empty())
	_sell_all_button.disabled = not any
	_sell_all_button.text = "Unmark all" if any and count == _player.bag.filter(func(it: Dictionary) -> bool: return not it.is_empty()).size() else "Mark all"
	var current: Dictionary = Player.BATS[_player.bat_tier]
	var next := _player.next_bat()
	_bat_shop_info.text = "Your bat: %s (hits for %d).   You have %d coins." % [current.name, roundi(current.damage), _player.coins]
	if next.is_empty():
		_bat_buy_button.text = "You have the best bat in the shop"
		_bat_buy_button.disabled = true
	elif _player.world.level_number < int(next.get("min_area", 1)):
		_bat_buy_button.text = "%s: hits for %d   (%d coins, sold from Act 2)" % [next.name, roundi(next.damage), next.price]
		_bat_buy_button.disabled = true
	elif _player.coins < next.price:
		_bat_buy_button.text = "%s: hits for %d   (%d coins, not enough)" % [next.name, roundi(next.damage), next.price]
		_bat_buy_button.disabled = true
	else:
		_bat_buy_button.text = "Upgrade to the %s: hits for %d   (%d coins)" % [next.name, roundi(next.damage), next.price]
		_bat_buy_button.disabled = false


## Icons on the scene's windows and buttons (the windows built in code add their own).
func _decorate() -> void:
	UiIcons.title(stable_panel.get_node("Margin/VBox/Title"), "stable", UiTheme.ACCENT)
	UiIcons.title(stable_panel.get_node("Margin/VBox/Columns/PartyColumn/PartyHeader"), "paw", UiTheme.TEXT, 20)
	UiIcons.title(stable_title, "bed", UiTheme.TEXT, 20)
	UiIcons.title(shop_panel.get_node("Margin/VBox/Title"), "stall", Color(1.0, 0.88, 0.4))
	UiIcons.button(buy_button, "potion")
	UiIcons.button(boost_button, "lemon")
	UiIcons.button(release_dialog.get_ok_button(), "gate")
	UiIcons.button(release_dialog.get_cancel_button(), "back")


## The bat shop window, built like the lemonade stand's.
func _build_bat_shop_panel() -> void:
	bat_shop_panel = PanelContainer.new()
	bat_shop_panel.name = "BatShopPanel"
	bat_shop_panel.visible = false
	bat_shop_panel.theme = shop_panel.theme
	bat_shop_panel.add_theme_stylebox_override("panel", shop_panel.get_theme_stylebox("panel"))
	bat_shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	bat_shop_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bat_shop_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(bat_shop_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	bat_shop_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Bat Shop"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = Color(1.0, 0.6, 0.5)
	box.add_child(title)
	UiIcons.title(title, "bat")
	var greeting := Label.new()
	greeting.text = "\"A better bat bonks harder, but don't worry: it still won't knock 'em out.\""
	greeting.modulate = Color(1, 1, 1, 0.75)
	box.add_child(greeting)
	_bat_shop_info = Label.new()
	box.add_child(_bat_shop_info)
	_bat_buy_button = Button.new()
	_bat_buy_button.focus_mode = Control.FOCUS_NONE
	_bat_buy_button.custom_minimum_size = Vector2(520, 40)
	_bat_buy_button.pressed.connect(func() -> void: _player.request_buy_bat.rpc_id(1))
	UiIcons.button(_bat_buy_button, "upgrade")
	box.add_child(_bat_buy_button)
	# Selling gear: the bag, click items to mark them, then sell.
	var sell_title := Label.new()
	sell_title.text = "Sell gear: click items in your bag to mark them   (Common 1, Fine 2, Superior 3, Legendary 5 coins)"
	sell_title.add_theme_font_size_override("font_size", 14)
	box.add_child(sell_title)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for i in ItemDB.BAG_SIZE:
		var slot := InventoryWindow.ItemSlot.new()
		slot.bag_index = i
		slot.no_drag = true
		slot.custom_minimum_size = Vector2(58, 58)
		slot.clicked.connect(func(s, _double: bool) -> void:
			if s.item.is_empty():
				return
			if _sell_marked.has(s.bag_index):
				_sell_marked.erase(s.bag_index)
			else:
				_sell_marked[s.bag_index] = true
			_update_bat_shop())
		grid.add_child(slot)
		_sell_slots.append(slot)
	var sell_row := HBoxContainer.new()
	sell_row.add_theme_constant_override("separation", 10)
	box.add_child(sell_row)
	_sell_all_button = Button.new()
	_sell_all_button.focus_mode = Control.FOCUS_NONE
	_sell_all_button.pressed.connect(func() -> void:
		var everything := {}
		for i in _player.bag.size():
			if not _player.bag[i].is_empty():
				everything[i] = true
		_sell_marked = {} if everything.size() == _sell_marked.size() else everything
		_update_bat_shop())
	sell_row.add_child(_sell_all_button)
	_sell_button = Button.new()
	_sell_button.focus_mode = Control.FOCUS_NONE
	_sell_button.custom_minimum_size = Vector2(300, 36)
	_sell_button.pressed.connect(func() -> void:
		if _sell_marked.is_empty():
			return
		_player.request_sell_items.rpc_id(1, _sell_marked.keys())
		_sell_marked.clear())
	UiIcons.button(_sell_button, "coin")
	sell_row.add_child(_sell_button)
	var hint := Label.new()
	hint.text = "Every bat stops at 1 HP on creatures, and a creature at 1 HP is a 99% catch.   [F / Esc] close"
	hint.modulate = Color(1, 1, 1, 0.6)
	box.add_child(hint)


func open_shop() -> void:
	shop_panel.show()
	_update_shop()


func _update_shop() -> void:
	var price := _player.potion_price
	shop_info.text = "You have %d coins and %d / %d potions." % [_player.coins, _player.potions, Player.MAX_POTIONS]
	if _player.boost_time_left() > 0.0:
		shop_info.text += "\nLucky Lemonade active: %ds left." % ceili(_player.boost_time_left())
	if _player.potions >= Player.MAX_POTIONS:
		buy_button.text = "Your bag is full"
		buy_button.disabled = true
	elif _player.coins < price:
		buy_button.text = "Not enough coins"
		buy_button.disabled = true
	else:
		buy_button.text = "Potion: heals %d%%   (%d coins)" % [roundi(_player.potion_heal * 100.0), price]
		buy_button.disabled = false
	var boost := "Lucky Lemonade: capture chance x%.1f for %ds   (%d coins)" \
			% [_player.boost_multiplier, int(_player.boost_duration), _player.boost_price]
	if _player.coins < _player.boost_price:
		boost_button.text = "Lucky Lemonade: not enough coins (%d)" % _player.boost_price
		boost_button.disabled = true
	else:
		boost_button.text = ("Refresh " + boost) if _player.boost_time_left() > 0.0 else boost
		boost_button.disabled = false


# --- Stable window -------------------------------------------------------------------

func is_stable_open() -> bool:
	return stable_panel.visible


func open_stable() -> void:
	stable_panel.show()
	_refresh_stable()


func close_stable() -> void:
	stable_panel.hide()
	release_dialog.hide()


func _on_stable_changed() -> void:
	if is_stable_open():
		_refresh_stable()


func _build_stable_slots() -> void:
	for slot in Player.MAX_PARTY:
		var party_slot := _new_slot("party", slot, Vector2(170, 110))
		party_slots_box.add_child(party_slot)
		_party_slots.append(party_slot)
	var reserve_title := Label.new()
	reserve_title.text = "Reserve"
	reserve_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reserve_title.add_theme_font_size_override("font_size", 16)
	reserve_title.tooltip_text = "Pets you carry: swap them in at any time from the action bar."
	reserve_title.mouse_filter = Control.MOUSE_FILTER_PASS
	party_slots_box.add_child(reserve_title)
	var reserve_row := HBoxContainer.new()
	reserve_row.add_theme_constant_override("separation", 6)
	party_slots_box.add_child(reserve_row)
	for i in Player.MAX_RESERVE:
		var reserve_slot := _new_slot("reserve", i, Vector2(78, 84))
		reserve_row.add_child(reserve_slot)
		_reserve_slots.append(reserve_slot)
	for bed in Player.MAX_STABLE:
		var bed_slot := _new_slot("bed", bed, Vector2(110, 92))
		bed_grid.add_child(bed_slot)
		_bed_slots.append(bed_slot)
	release_gate.dropped.connect(_on_slot_dropped)
	release_dialog.confirmed.connect(func() -> void:
		if _pending_release and not _pending_release.pet.is_empty():
			_player.request_stable_release.rpc_id(1, _pending_release.kind, _pending_release.index)
		_pending_release = null)


func _new_slot(kind: String, index: int, min_size: Vector2) -> PetSlot:
	var slot := PetSlot.new()
	slot.kind = kind
	slot.index = index
	slot.custom_minimum_size = min_size
	slot.dropped.connect(_on_slot_dropped)
	return slot


## Shows the current party and beds in the slots.
func _refresh_stable() -> void:
	_stable_party_signature = _party_signature()
	for slot in Player.MAX_PARTY:
		var pet := _player.world.get_party_pet(_player.peer_id, slot)
		_party_slots[slot].pet = {
			"species": pet.species_index, "level": pet.level, "fainted": pet.fainted, "skills": pet.skill_ranks,
		} if pet else {}
	for bed in Player.MAX_STABLE:
		var data: Dictionary = _player.stable[bed] if bed < _player.stable.size() else {}
		_bed_slots[bed].pet = {"species": data.species, "level": data.level} if not data.is_empty() else {}
	for i in Player.MAX_RESERVE:
		var data: Dictionary = _player.reserve[i] if i < _player.reserve.size() else {}
		_reserve_slots[i].pet = {"species": data.species, "level": data.level, "fainted": data.get("dead", false)} \
				if not data.is_empty() else {}
	stable_title.text = "Hay beds  %d / %d" % [_player.stable_count(), Player.MAX_STABLE]


## A pet was dragged from `from` and dropped on `to`.
func _on_slot_dropped(from: PetSlot, to: PetSlot) -> void:
	if from.pet.is_empty():
		return
	if to.kind == "release":
		_pending_release = from
		var species := SpeciesDB.get_species(from.pet.species)
		release_dialog.dialog_text = "Release your %s (Lv%d) back into the wild?\nThis can't be undone." \
				% [species.display_name, from.pet.level]
		release_dialog.popup_centered()
		return
	_player.request_stable_move.rpc_id(1, from.kind, from.index, to.kind, to.index)


func _party_signature() -> String:
	return ",".join(_player.world.get_pets(_player.peer_id).map(
			func(p: Creature) -> String: return "%s:%d:%d:%s" % [p.name, p.party_slot, p.level, p.fainted]))


# --- Always-on HUD -------------------------------------------------------------------

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [ceili(maxf(current, 0.0)), roundi(maximum)]


## True while the mouse is over a HUD button, so clicking it doesn't also swing.
func is_mouse_over_buttons() -> bool:
	return action_bar.has_mouse()


func _update_coins() -> void:
	# Coins and potions are on the action bar; this line only shows a Lucky Lemonade.
	coins_label.visible = _player.boost_time_left() > 0.0
	if coins_label.visible:
		coins_label.text = "Lucky Lemonade: capture x%.1f  (%ds)" % [_player.boost_multiplier, ceili(_player.boost_time_left())]


func _update_objective() -> void:
	var world := _player.world
	if world.layout.is_empty():
		return
	var levels := World.area_levels(world.level_number)
	level_label.text = "%s  ·  %s  (Lv %d-%d)" % [World.area_title(world.level_number), world.biome().name, levels.x, levels.y]
	progress_bar.value = world.level_progress(_player.global_position) * 100.0
	var rival := world.get_rival()
	if world.is_crossroads():
		level_label.text = "The Crossroads"
		objective_label.text = "Act 1 is cleared! The red portal at the far end leads on to Act 2." if world.act1_cleared() \
				else "Walk into a portal to choose your next area. Each area you clear makes the next one stronger."
	elif world.exit_open:
		objective_label.text = "Boss defeated! Take the %s portal, or the violet Travel portal to go back." \
				% ("Crossroads" if world.next_level() == BiomeDB.CROSSROADS else "Next level")
	elif rival and rival.engaged:
		objective_label.text = "Defeat %s!" % rival.objective_name()
	else:
		objective_label.text = ("Find and defeat %s" if world.layout.get("open", false) \
				else "Follow the path and defeat %s at the end.") % world.boss_objective_name()


func _update_hover() -> void:
	var c := _player.hovered_creature
	if c == null or not is_instance_valid(c):
		hover_label.text = ""
	elif c.is_wild() and c.is_monster():
		hover_label.text = "%s  Lv%d   —   a monster: it can't be captured. Bat it or send pets  [RMB]" \
				% [c.species.display_name, c.level]
	elif c.is_wild():
		var where := ""
		if _player.party_is_full():
			where = "  (party full: goes to your reserve)" if _player.reserve_count() < Player.MAX_RESERVE \
					else "  (party and reserve full: goes to the stable)"
		hover_label.text = "Wild %s  Lv%d   —   capture chance %d%%  [E]%s   ·   send pets  [RMB]" \
				% [c.species.display_name, c.level, roundi(c.capture_chance(_player.capture_boost()) * 100.0), where]
	elif c.owner_id == _player.peer_id:
		hover_label.text = "Your %s  Lv%d%s" % [c.species.display_name, c.level,
				"  ·  " + c.species.pet_class().capitalize() if c.species.pet_class() != "" else ""]
		var left := PetSkills.points_left(c.level, c.skill_ranks)
		if left > 0:
			hover_label.text += "   ·   %d skill point%s to spend  [K]" % [left, "" if left == 1 else "s"]
	else:
		var other = _player.world.get_tamer(c.owner_id)  # Player or Rival
		var owner_name: String = ("Rival " + other.display_name if c.is_rival_pet() else other.display_name) if other else "?"
		hover_label.text = "%s's %s  Lv%d" % [owner_name, c.species.display_name, c.level]


func _rebuild_party() -> void:
	var pets := _player.world.get_pets(_player.peer_id)
	party_title.text = "Pets  %d / %d     Reserve  %d / %d     Stable  %d / %d" \
			% [pets.size(), Player.MAX_PARTY, _player.reserve_count(), Player.MAX_RESERVE, _player.stable_count(), Player.MAX_STABLE]
	for child in party_list.get_children():
		child.queue_free()
	if pets.is_empty():  # your pets are shown on the action bar
		var hint := Label.new()
		var undead: bool = _player.world.biome().species.all(
				func(i: int) -> bool: return SpeciesDB.get_species(i).monster)
		hint.text = "The undead can't be tamed:\nbring pets from the stable." if undead \
				else "Weaken a wild creature with your bat,\nthen press E to capture it."
		hint.modulate = Color(1, 1, 1, 0.6)
		party_list.add_child(hint)


## The travel window (the violet portal at the end of each level): a button for
## every area reached so far. Picking one takes the whole party there.
func _build_travel_window() -> void:
	travel_window = PanelContainer.new()
	travel_window.visible = false
	travel_window.set_anchors_preset(Control.PRESET_CENTER)
	travel_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	travel_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(travel_window)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	travel_window.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Travel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(0.85, 0.7, 1.0)
	box.add_child(title)
	UiIcons.title(title, "map")
	var info := Label.new()
	info.text = "Go back to any area you've reached: to catch the pets that live there,\nor to level up your pets before going on. Everyone travels together."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 13)
	info.modulate = UiTheme.TEXT_DIM
	box.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_travel_list = VBoxContainer.new()
	_travel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_travel_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_travel_list)
	var hint := Label.new()
	hint.text = "Step out of the portal or press Esc to close."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = UiTheme.TEXT_DIM
	box.add_child(hint)


func open_travel() -> void:
	close_windows()
	for child in _travel_list.get_children():
		child.queue_free()
	var world := _player.world
	for n in range(BiomeDB.CROSSROADS, world.furthest_level + 1):
		var levels := World.area_levels(n)
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 40)
		var here := "   ·  you are here" if n == world.level_number else ""
		if n <= BiomeDB.CROSSROADS:
			button.text = "The Crossroads   (choose an Act 1 area)%s" % here
		else:
			button.text = "%s  ·  %s   (creatures Lv %d-%d)%s" % [World.area_title(n), BiomeDB.for_level(n).name,
					levels.x, levels.y, here]
		UiIcons.button(button, "map")
		button.pressed.connect(func() -> void:
			world.request_travel.rpc_id(1, n)
			travel_window.hide())
		_travel_list.add_child(button)
	travel_window.show()
