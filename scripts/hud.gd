class_name HUD
extends CanvasLayer
## Local player's view: health, pet party (with abilities), hover info, the
## message feed and the stable window.

const MAX_MESSAGES := 6

var _player: Player
var _party_refresh := 0.0
var _stable_party_signature := ""
## Party slot chosen for a swap in the stable window (-1 = none).
var _selected_slot := -1
## Stable index waiting for a second click to confirm release (-1 = none).
var _confirm_release := -1

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
@onready var stable_party_list: VBoxContainer = %StablePartyList
@onready var stable_title: Label = %StableTitle
@onready var stable_list: VBoxContainer = %StableList
@onready var coins_label: Label = %CoinsLabel
@onready var shop_panel: Control = %ShopPanel
@onready var shop_info: Label = %ShopInfo
@onready var buy_button: Button = %BuyButton
@onready var level_label: Label = %LevelLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var progress_bar: ProgressBar = %ProgressBar


func _ready() -> void:
	buy_button.pressed.connect(func() -> void: _player.request_buy_potion.rpc_id(1))


func bind(player: Player) -> void:
	_player = player
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
	interact_label.visible = (near_stable or near_shop) and not is_window_open()
	interact_label.text = "[F]  Open stable" if near_stable else "[F]  Visit the lemonade stand"
	if shop_panel.visible:
		_update_shop()
	_update_hover()
	_update_objective()
	_update_coins()
	_party_refresh -= delta
	if _party_refresh <= 0.0:
		_party_refresh = 0.2
		_rebuild_party()
		if is_stable_open() and _party_signature() != _stable_party_signature:
			_rebuild_stable()


func show_message(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	messages.add_child(label)
	if messages.get_child_count() > MAX_MESSAGES:
		messages.get_child(0).queue_free()
	var tween := label.create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


# --- Windows ---------------------------------------------------------------------------

func is_window_open() -> bool:
	return stable_panel.visible or shop_panel.visible


func close_windows() -> void:
	stable_panel.hide()
	shop_panel.hide()


func open_shop() -> void:
	shop_panel.show()
	_update_shop()


func _update_shop() -> void:
	var price := _player.potion_price
	shop_info.text = "Potion: %d coins each   (heals %d%%)\nYou have %d coins and %d / %d potions." \
			% [price, roundi(_player.potion_heal * 100.0), _player.coins, _player.potions, Player.MAX_POTIONS]
	if _player.potions >= Player.MAX_POTIONS:
		buy_button.text = "Your bag is full"
		buy_button.disabled = true
	elif _player.coins < price:
		buy_button.text = "Not enough coins"
		buy_button.disabled = true
	else:
		buy_button.text = "Buy a potion (%d coins)" % price
		buy_button.disabled = false


# --- Stable window -------------------------------------------------------------------

func is_stable_open() -> bool:
	return stable_panel.visible


func open_stable() -> void:
	_selected_slot = -1
	_confirm_release = -1
	stable_panel.show()
	_rebuild_stable()


func close_stable() -> void:
	stable_panel.hide()


func _on_stable_changed() -> void:
	_confirm_release = -1
	if is_stable_open():
		_rebuild_stable()


func _rebuild_stable() -> void:
	_stable_party_signature = _party_signature()
	for child in stable_party_list.get_children() + stable_list.get_children():
		child.queue_free()
	var party_full := _player.party_is_full()
	if _player.world.get_party_pet(_player.peer_id, _selected_slot) == null:
		_selected_slot = -1

	for slot in Player.MAX_PARTY:
		var pet := _player.world.get_party_pet(_player.peer_id, slot)
		var row := HBoxContainer.new()
		var select := Button.new()
		select.toggle_mode = true
		select.custom_minimum_size = Vector2(230, 0)
		select.alignment = HORIZONTAL_ALIGNMENT_LEFT
		select.text = "[%d]  %s" % [slot + 1, _pet_text(pet.species_index, pet.level) if pet else "(empty)"]
		select.disabled = pet == null
		select.button_pressed = slot == _selected_slot
		select.tooltip_text = "Select, then pick a stable pet to swap with."
		select.toggled.connect(func(on: bool) -> void:
			_selected_slot = slot if on else -1
			_rebuild_stable())
		row.add_child(select)
		var store := Button.new()
		store.text = "Store"
		store.disabled = pet == null or _player.stable_is_full()
		store.pressed.connect(func() -> void: _player.request_stable_store.rpc_id(1, slot))
		row.add_child(store)
		stable_party_list.add_child(row)

	stable_title.text = "Stable  %d / %d" % [_player.stable.size(), Player.MAX_STABLE]
	if _player.stable.is_empty():
		var empty := Label.new()
		empty.text = "No pets stored yet.\nPets you capture with a full party come here."
		empty.modulate = Color(1, 1, 1, 0.6)
		stable_list.add_child(empty)
	for i in _player.stable.size():
		var data: Dictionary = _player.stable[i]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = _pet_text(data.species, data.level)
		label.modulate = SpeciesDB.get_species(data.species).color.lightened(0.35)
		label.custom_minimum_size = Vector2(270, 0)
		row.add_child(label)
		var take := Button.new()
		if not party_full:
			take.text = "Take"
		elif _selected_slot >= 0:
			take.text = "Swap with [%d]" % (_selected_slot + 1)
		else:
			take.text = "Take"
			take.disabled = true
			take.tooltip_text = "Party is full: select a party pet to swap with."
		take.pressed.connect(func() -> void:
			_player.request_stable_take.rpc_id(1, i, _selected_slot if party_full else -1)
			_selected_slot = -1)
		row.add_child(take)
		var release := Button.new()
		release.text = "Confirm?" if _confirm_release == i else "Release"
		release.pressed.connect(func() -> void:
			if _confirm_release == i:
				_player.request_stable_release.rpc_id(1, i)
			else:
				_confirm_release = i
				_rebuild_stable())
		row.add_child(release)
		stable_list.add_child(row)


func _party_signature() -> String:
	return ",".join(_player.world.get_pets(_player.peer_id).map(
			func(p: Creature) -> String: return "%s:%d:%d" % [p.name, p.party_slot, p.level]))


func _pet_text(species_index: int, level: int) -> String:
	var species := SpeciesDB.get_species(species_index)
	var ability_name := species.ability.display_name if species.ability else "-"
	return "%s  Lv%d  (%s)" % [species.display_name, level, ability_name]


# --- Always-on HUD -------------------------------------------------------------------

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [ceili(maxf(current, 0.0)), roundi(maximum)]


func _update_coins() -> void:
	var potions := "%d / %d" % [_player.potions, Player.MAX_POTIONS]
	if _player.potion_cooldown_left() > 0.0:
		potions += "  (%.0fs)" % ceilf(_player.potion_cooldown_left())
	coins_label.text = "Coins %d      [Q] Potions %s" % [_player.coins, potions]


func _update_objective() -> void:
	var world := _player.world
	if world.layout.is_empty():
		return
	level_label.text = "Level %d  ·  %s" % [world.level_number, world.biome().name]
	progress_bar.value = world.level_progress(_player.global_position) * 100.0
	var rival := world.get_rival()
	if world.exit_open:
		objective_label.text = "Rival defeated! Step into the portal at the end of the path."
	elif rival and rival.engaged:
		objective_label.text = "Defeat %s!" % rival.objective_name()
	else:
		objective_label.text = "Follow the path and defeat %s at the end." % world.boss_objective_name()


func _update_hover() -> void:
	var c := _player.hovered_creature
	if c == null or not is_instance_valid(c):
		hover_label.text = ""
	elif c.is_wild():
		var where := "  (party full: goes to stable)" if _player.party_is_full() else ""
		hover_label.text = "Wild %s  Lv%d   —   capture chance %d%%  [E]%s   ·   send pets  [RMB]" \
				% [c.species.display_name, c.level, roundi(c.capture_chance() * 100.0), where]
	elif c.owner_id == _player.peer_id:
		hover_label.text = "Your %s  Lv%d" % [c.species.display_name, c.level]
	else:
		var other = _player.world.get_tamer(c.owner_id)  # Player or Rival
		var owner_name: String = ("Rival " + other.display_name if c.is_rival_pet() else other.display_name) if other else "?"
		hover_label.text = "%s's %s  Lv%d" % [owner_name, c.species.display_name, c.level]


func _rebuild_party() -> void:
	var pets := _player.world.get_pets(_player.peer_id)
	party_title.text = "Pets  %d / %d     Stable  %d / %d" \
			% [pets.size(), Player.MAX_PARTY, _player.stable.size(), Player.MAX_STABLE]
	for child in party_list.get_children():
		child.queue_free()
	if pets.is_empty():
		var hint := Label.new()
		hint.text = "Weaken a wild creature,\nthen press E to capture it."
		hint.modulate = Color(1, 1, 1, 0.6)
		party_list.add_child(hint)
	for pet in pets:
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 1)
		var label := Label.new()
		label.text = "[%d]  %s  Lv%d%s" % [pet.party_slot + 1, pet.species.display_name, pet.level,
				"   (fainted)" if pet.fainted else ""]
		label.modulate = pet.species.color.lightened(0.35)
		entry.add_child(label)
		entry.add_child(_bar(pet.health.current, pet.health.max_health, Color(0.35, 0.9, 0.4), 14))
		entry.add_child(_bar(pet.xp, pet.xp_to_next(), Color(0.5, 0.7, 1.0), 5))
		if pet.species.ability:
			var ability := Label.new()
			var cd := pet.ability_cooldown_left()
			ability.text = "      %s   %s" % [pet.species.ability.display_name, "%.1fs" % cd if cd > 0.0 else "ready"]
			ability.tooltip_text = pet.species.ability.description
			ability.modulate = Color(1, 1, 1, 0.55) if cd > 0.0 else Color(1.0, 0.9, 0.5)
			ability.add_theme_font_size_override("font_size", 14)
			entry.add_child(ability)
		party_list.add_child(entry)


func _bar(value: float, maximum: float, color: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(240, height)
	bar.show_percentage = false
	bar.max_value = maximum
	bar.value = value
	bar.self_modulate = color
	return bar
