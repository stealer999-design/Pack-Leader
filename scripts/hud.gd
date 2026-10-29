class_name HUD
extends CanvasLayer
## Local player's view: health, pet party (with abilities), hover info, the
## message feed and the stable window.

const MAX_MESSAGES := 6

var _player: Player
var _party_refresh := 0.0
var _dialog_closed_frame := -1
var skill_window: SkillWindow
var _stable_party_signature := ""
var _party_slots: Array[PetSlot] = []
var _bed_slots: Array[PetSlot] = []
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
@onready var stance_button: Button = %StanceButton
@onready var skills_button: Button = %SkillsButton
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
	stance_button.pressed.connect(func() -> void: _player.request_toggle_stance.rpc_id(1))
	skills_button.pressed.connect(toggle_skills)
	skill_window = SkillWindow.new()
	skill_window.theme = stable_panel.theme
	skill_window.add_theme_stylebox_override("panel", stable_panel.get_theme_stylebox("panel"))
	add_child(skill_window)


func bind(player: Player) -> void:
	_player = player
	skill_window.player = player
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
	_update_stance()
	_party_refresh -= delta
	if _party_refresh <= 0.0:
		_party_refresh = 0.2
		_rebuild_party()
		if is_stable_open() and _party_signature() != _stable_party_signature:
			_refresh_stable()


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

## Escape closes the stable, shop or skills, but a press that closes the release dialog
## on top of the stable shouldn't close the stable as well.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and release_dialog.visible:
		_dialog_closed_frame = Engine.get_process_frames()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_window_open() \
			and Engine.get_process_frames() != _dialog_closed_frame:
		close_windows()
		get_viewport().set_input_as_handled()


func is_window_open() -> bool:
	return stable_panel.visible or shop_panel.visible or skill_window.visible


func close_windows() -> void:
	stable_panel.hide()
	shop_panel.hide()
	skill_window.hide()


## The skills screen (K) can open anywhere; it replaces any other open window.
func toggle_skills() -> void:
	if skill_window.visible:
		skill_window.hide()
		return
	close_windows()
	skill_window.open()


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
		var party_slot := _new_slot("party", slot, Vector2(170, 120))
		party_slots_box.add_child(party_slot)
		_party_slots.append(party_slot)
	for bed in Player.MAX_STABLE:
		var bed_slot := _new_slot("bed", bed, Vector2(118, 104))
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
	var mouse := stance_button.get_viewport().get_mouse_position()
	for button in [stance_button, skills_button]:
		if button.is_visible_in_tree() and button.get_global_rect().has_point(mouse):
			return true
	return false


func _update_stance() -> void:
	if _player.pets_passive:
		stance_button.text = "Pets: Passive   [T]"
		stance_button.self_modulate = Color(0.55, 0.85, 1.0)
	else:
		stance_button.text = "Pets: Aggressive   [T]"
		stance_button.self_modulate = Color(1.0, 0.7, 0.55)


func _update_coins() -> void:
	var potions := "%d / %d" % [_player.potions, Player.MAX_POTIONS]
	if _player.potion_cooldown_left() > 0.0:
		potions += "  (%.0fs)" % ceilf(_player.potion_cooldown_left())
	coins_label.text = "Coins %d      [Q] Potions %s" % [_player.coins, potions]
	if _player.boost_time_left() > 0.0:
		coins_label.text += "\nLucky Lemonade: capture x%.1f  (%ds)" % [_player.boost_multiplier, ceili(_player.boost_time_left())]


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
				% [c.species.display_name, c.level, roundi(c.capture_chance(_player.capture_boost()) * 100.0), where]
	elif c.owner_id == _player.peer_id:
		hover_label.text = "Your %s  Lv%d" % [c.species.display_name, c.level]
		var left := PetSkills.points_left(c.level, c.skill_ranks)
		if left > 0:
			hover_label.text += "   ·   %d skill point%s to spend  [K]" % [left, "" if left == 1 else "s"]
	else:
		var other = _player.world.get_tamer(c.owner_id)  # Player or Rival
		var owner_name: String = ("Rival " + other.display_name if c.is_rival_pet() else other.display_name) if other else "?"
		hover_label.text = "%s's %s  Lv%d" % [owner_name, c.species.display_name, c.level]


func _rebuild_party() -> void:
	var pets := _player.world.get_pets(_player.peer_id)
	party_title.text = "Pets  %d / %d     Stable  %d / %d" \
			% [pets.size(), Player.MAX_PARTY, _player.stable_count(), Player.MAX_STABLE]
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
		var points := PetSkills.points_left(pet.level, pet.skill_ranks)
		label.text = "[%d]  %s  Lv%d%s%s" % [pet.party_slot + 1, pet.species.display_name, pet.level,
				"  · +%d [K]" % points if points > 0 else "", "   (fainted)" if pet.fainted else ""]
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
