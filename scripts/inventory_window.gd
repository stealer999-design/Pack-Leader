class_name InventoryWindow
extends PanelContainer
## The inventory (I): what the tamer wears in its eight slots (weapon, chest,
## pants, hat, boots, two rings, a necklace) and the bag. Everything is drag and drop:
## drag an item onto its gear slot to wear it (swapping with what's there),
## drag worn gear into the bag to take it off, drag within the bag to tidy it,
## or onto the bin to throw it away. Click an item to see it; double-click is a
## shortcut to wear / take off. To clear out lots of junk at once, press Select
## (or right-click an item): click bag items to mark them, then Throw away.
## The Pets tab shows the party pets instead of the tamer's gear: each pet has
## one slot, for a collar (drag collars from the bag onto it). The server does
## the moving (Player.request_*).

const EQUIP_SIZE := Vector2(64, 64)
const BAG_SIZE := Vector2(50, 50)
const BAG_COLUMNS := 8

var player: Player

var _equip_slots := {}  ## slot name -> ItemSlot
var _bag_slots: Array[ItemSlot] = []
var _armor: Label
var _bag_title: Label
var _details: RichTextLabel
var _compare: RichTextLabel
var _bin: ItemSlot
var _discard_dialog: ConfirmationDialog
var _discard_indices: Array[int] = []
var _hint: Label
## Select mode: clicking bag items marks them to throw away together.
var _selecting := false
var _marked := {}  ## bag index -> true
var _select_button: Button
var _all_button: Button
var _throw_button: Button
var _selected: ItemSlot
var _tamer_column: VBoxContainer
var _pets_column: VBoxContainer
var _tamer_tab: Button
var _pets_tab: Button
## One row per party slot: {portrait: PetSlot, collar: ItemSlot, label: Label}.
var _pet_rows: Array[Dictionary] = []
## One row per reserve place: {portrait: PetSlot, label: Label}.
var _reserve_rows: Array[Dictionary] = []
var _pets_signature := ""


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = UiTheme.ACCENT
	box.add_child(title)
	UiIcons.title(title, "bag")
	# Tabs: the tamer's gear, or the pets' collars (the bag is shared).
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	var group := ButtonGroup.new()
	_tamer_tab = _small_button("Tamer", "user", "What your tamer wears")
	_pets_tab = _small_button("Pets", "paw", "Your party pets' collars")
	for tab in [_tamer_tab, _pets_tab]:
		tab.toggle_mode = true
		tab.button_group = group
		tab.custom_minimum_size.x = 120
		tabs.add_child(tab)
	_tamer_tab.button_pressed = true
	_tamer_tab.toggled.connect(func(on: bool) -> void: _show_tab(not on))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	box.add_child(columns)
	# Worn gear: hat & necklace, chest & ring, pants & ring, boots & weapon.
	var worn := VBoxContainer.new()
	_tamer_column = worn
	columns.add_child(worn)
	worn.add_child(_heading("Equipped"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	worn.add_child(grid)
	for slot in ["hat", "necklace", "chest", "ring1", "pants", "ring2", "boots", "weapon"]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var item_slot := ItemSlot.new()
		item_slot.equip_slot = slot
		item_slot.custom_minimum_size = EQUIP_SIZE
		item_slot.clicked.connect(_on_slot_clicked)
		item_slot.dropped.connect(_on_dropped)
		cell.add_child(item_slot)
		var name_label := Label.new()
		name_label.text = ItemDB.SLOT_NAMES[slot]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.modulate = UiTheme.TEXT_DIM
		cell.add_child(name_label)
		grid.add_child(cell)
		_equip_slots[slot] = item_slot
	_armor = Label.new()
	_armor.add_theme_font_size_override("font_size", 14)
	worn.add_child(_armor)
	# The pets' collars (the Pets tab), in the same place.
	_pets_column = VBoxContainer.new()
	_pets_column.visible = false
	_pets_column.add_theme_constant_override("separation", 6)
	columns.add_child(_pets_column)
	_pets_column.add_child(_heading("Party pets: one collar each"))
	for i in Player.MAX_PARTY:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_pets_column.add_child(row)
		var portrait := PetSlot.new()
		portrait.kind = "party"
		portrait.index = i
		portrait.custom_minimum_size = Vector2(100, 84)
		portrait.dropped.connect(_on_pet_dropped)
		portrait.rename_requested.connect(func(slot: PetSlot) -> void: player.world.hud.open_rename(slot))
		row.add_child(portrait)
		var collar := ItemSlot.new()
		collar.equip_slot = "collar"
		collar.pet_slot = i
		collar.custom_minimum_size = EQUIP_SIZE
		collar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		collar.clicked.connect(_on_slot_clicked)
		collar.dropped.connect(_on_dropped)
		row.add_child(collar)
		var label := Label.new()
		label.custom_minimum_size = Vector2(170, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)
		_pet_rows.append({"portrait": portrait, "collar": collar, "label": label})
	# The reserve: pets carried along, swapped in by dragging them onto a party pet.
	var reserve_heading := _heading("Reserve: drag onto a party pet to swap")
	reserve_heading.tooltip_text = "Pets you carry but who aren't fighting. Swap them in and out at any time, even mid-fight\n(drag between the reserve and the party, either way). A dead pet can't go back in until it rests at a stable."
	reserve_heading.mouse_filter = Control.MOUSE_FILTER_PASS
	_pets_column.add_child(reserve_heading)
	var reserve_row := HBoxContainer.new()
	reserve_row.add_theme_constant_override("separation", 8)
	_pets_column.add_child(reserve_row)
	for i in Player.MAX_RESERVE:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		reserve_row.add_child(cell)
		var portrait := PetSlot.new()
		portrait.kind = "reserve"
		portrait.index = i
		portrait.custom_minimum_size = Vector2(96, 84)
		portrait.dropped.connect(_on_pet_dropped)
		portrait.rename_requested.connect(func(slot: PetSlot) -> void: player.world.hud.open_rename(slot))
		cell.add_child(portrait)
		var label := Label.new()
		label.custom_minimum_size = Vector2(96, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		cell.add_child(label)
		_reserve_rows.append({"portrait": portrait, "label": label})
	# The bag.
	var bag_box := VBoxContainer.new()
	columns.add_child(bag_box)
	_bag_title = _heading("Bag")
	bag_box.add_child(_bag_title)
	var bag_grid := GridContainer.new()
	bag_grid.columns = BAG_COLUMNS
	bag_grid.add_theme_constant_override("h_separation", 6)
	bag_grid.add_theme_constant_override("v_separation", 6)
	bag_box.add_child(bag_grid)
	for i in ItemDB.BAG_SIZE:
		var item_slot := ItemSlot.new()
		item_slot.bag_index = i
		item_slot.custom_minimum_size = BAG_SIZE
		item_slot.clicked.connect(_on_slot_clicked)
		item_slot.marked_toggled.connect(_on_slot_marked)
		item_slot.dropped.connect(_on_dropped)
		bag_grid.add_child(item_slot)
		_bag_slots.append(item_slot)

	# The selected item, the bin, and how it works.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	box.add_child(bottom)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = true
	_details.scroll_active = false
	_details.custom_minimum_size = Vector2(0, 54)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_font_size_override("normal_font_size", 13)
	bottom.add_child(_details)
	# Beside it: how a bag item compares with what it would replace.
	_compare = RichTextLabel.new()
	_compare.bbcode_enabled = true
	_compare.fit_content = true
	_compare.scroll_active = false
	_compare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_compare.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compare.add_theme_font_size_override("normal_font_size", 13)
	bottom.add_child(_compare)
	_select_button = _small_button("Select", "close", "Mark items to throw away together (or right-click an item)")
	_select_button.toggle_mode = true
	_select_button.toggled.connect(_set_selecting)
	bottom.add_child(_select_button)
	_all_button = _small_button("All", "plus", "Mark everything in the bag (click items to unmark them)")
	_all_button.pressed.connect(_mark_all)
	bottom.add_child(_all_button)
	_throw_button = _small_button("Throw away", "trash", "Throw away every marked item")
	_throw_button.pressed.connect(_throw_marked)
	bottom.add_child(_throw_button)
	_bin = ItemSlot.new()
	_bin.is_bin = true
	_bin.custom_minimum_size = Vector2(64, 54)
	_bin.dropped.connect(_on_dropped)
	_bin.tooltip_text = "Drop an item here to throw it away."
	bottom.add_child(_bin)
	var hint := Label.new()
	_hint = hint
	hint.custom_minimum_size = Vector2(0, 36)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = UiTheme.TEXT_DIM
	box.add_child(hint)
	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.title = "Throw away?"
	_discard_dialog.ok_button_text = "Throw away"
	_discard_dialog.confirmed.connect(func() -> void:
		if _discard_indices.size() == 1:
			player.request_discard.rpc_id(1, _discard_indices[0])
		elif _discard_indices.size() > 1:
			player.request_discard_many.rpc_id(1, _discard_indices)
			_set_selecting(false)
		_discard_indices.clear())
	add_child(_discard_dialog)
	UiIcons.button(_discard_dialog.get_ok_button(), "trash")
	UiIcons.button(_discard_dialog.get_cancel_button(), "back")


func bind(new_player: Player) -> void:
	player = new_player
	player.inventory_changed.connect(refresh)


func open() -> void:
	_selected = null
	_set_selecting(false)
	show()
	refresh()


func refresh() -> void:
	if not is_instance_valid(player):
		return
	for slot in _equip_slots:
		var item_slot: ItemSlot = _equip_slots[slot]
		item_slot.item = player.equipment.get(slot, {})
		if slot == "weapon" and item_slot.item.is_empty():
			item_slot.item = _weapon()
	var used := 0
	for item_slot in _bag_slots:
		item_slot.item = player.bag[item_slot.bag_index] if item_slot.bag_index < player.bag.size() else {}
		item_slot.upgrade = is_upgrade(item_slot.item)
		if not item_slot.item.is_empty():
			used += 1
	_bag_title.text = "Bag   %d / %d" % [used, ItemDB.BAG_SIZE]
	var gear := player.equipment
	_armor.text = "Tamer:  %d%% armor · %d health · +%d%% speed" % [
			player.armor_percent(), roundi(player.health.max_health), ItemDB.total(gear, "speed")]
	var all_pets := [ItemDB.total(gear, "pet_damage"), ItemDB.total(gear, "pet_health")]
	if all_pets[0] > 0 or all_pets[1] > 0:  # the older rings and necklaces, for every pet
		_armor.text += "\nAll pets:  +%d%% damage · +%d%% health" % all_pets
	# Class rings and necklaces: what they add up to for each class of pet.
	for pet_class in ItemDB.PET_GEAR:
		var sums := {}
		for slot in gear:
			var item: Dictionary = gear[slot]
			if ItemDB.is_class_jewelry(item) and item["class"] == pet_class:
				for id: String in item.affixes:
					if id.begins_with("cls_"):
						sums[id.substr(4)] = sums.get(id.substr(4), 0) + int(item.affixes[id])
		if not sums.is_empty():
			var parts := []
			for stat in sums:
				parts.append(PetSkills.STAT_TEXT.get(stat, "+%d to every skill rank") % sums[stat])
			_armor.text += "\n%s (%s):  %s" % [ItemDB.PET_GEAR[pet_class].title, ItemDB.PET_GEAR[pet_class].pets, " · ".join(parts)]
	for index in _marked.keys():
		if player.bag[index].is_empty():
			_marked.erase(index)
	for item_slot in _bag_slots:
		item_slot.marked = _marked.has(item_slot.bag_index)
		item_slot.no_drag = _selecting
	_update_select_controls()
	if _selected and _selected.item.is_empty():
		_selected = null
	_refresh_pets()
	for item_slot in _bag_slots + _equip_slots.values() + _pet_rows.map(func(r: Dictionary) -> ItemSlot: return r.collar):
		item_slot.selected = item_slot == _selected
	_update_details()


func _process(_delta: float) -> void:
	# Pets come and go (and level up, faint, change collars) without a signal here.
	if visible and _pets_column.visible and _pets_data() != _pets_signature:
		refresh()


## Party pets as data, by party slot ({} for an empty slot).
func _pets_data() -> String:
	var out := []
	for i in Player.MAX_PARTY:
		var pet := player.world.get_party_pet(player.peer_id, i) if is_instance_valid(player) else null
		out.append([pet.species_index, pet.level, pet.fainted, pet.collar, pet.nickname] if pet else [])
	if is_instance_valid(player):
		out.append(player.reserve)
	return str(out)


func _refresh_pets() -> void:
	_pets_signature = _pets_data()
	for i in _pet_rows.size():
		var row: Dictionary = _pet_rows[i]
		var pet := player.world.get_party_pet(player.peer_id, i)
		row.portrait.pet = {"species": pet.species_index, "level": pet.level, "fainted": pet.fainted,
				"skills": pet.skill_ranks, "name": pet.nickname} if pet else {}
		row.collar.locked = pet == null
		row.collar.pet_species = pet.species if pet else null
		row.collar.item = pet.collar if pet else {}
		if pet == null:
			row.label.text = "Empty party slot"
			row.label.modulate = UiTheme.TEXT_DIM
		elif pet.collar.is_empty():
			row.label.text = "No collar.\nDrag one here from the bag."
			row.label.modulate = UiTheme.TEXT_DIM
		else:
			row.label.text = "%s\n%s" % [ItemDB.display_name(pet.collar), ItemDB.effect(pet.collar).replace("This pet: ", "")]
			row.label.modulate = ItemDB.rarity_color(pet.collar).lightened(0.3)
		if pet and pet.fainted:
			row.label.text = "DEAD: can't fight or be healed until it rests at a stable. Drag a reserve pet onto it to swap."
			row.label.modulate = Color(1.0, 0.55, 0.5)
	for i in _reserve_rows.size():
		var row: Dictionary = _reserve_rows[i]
		var data: Dictionary = player.reserve[i] if i < player.reserve.size() else {}
		var dead: bool = data.get("dead", false)
		row.portrait.pet = {} if data.is_empty() else {"species": data.species, "level": data.level, "fainted": dead,
				"skills": data.get("skills", PetSkills.empty_ranks()), "name": data.get("name", "")}
		if data.is_empty():
			row.label.text = "empty"
			row.label.modulate = UiTheme.TEXT_DIM
		elif dead:
			row.label.text = "Dead: rest at a stable"
			row.label.modulate = Color(1.0, 0.55, 0.5)
		else:
			row.label.text = "Health %d%%" % roundi(float(data.get("health", 1.0)) * 100.0)
			row.label.modulate = UiTheme.TEXT if data.has("health") else UiTheme.TEXT_DIM


## A pet dragged between the party and the reserve (or within either): swap them.
func _on_pet_dropped(from: PetSlot, to: PetSlot) -> void:
	if from.pet.is_empty() or not is_instance_valid(player):
		return
	player.request_swap.rpc_id(1, from.kind, from.index, to.kind, to.index)


func _show_tab(pets: bool) -> void:
	_tamer_column.visible = not pets
	_pets_column.visible = pets
	_selected = null
	if is_instance_valid(player):
		refresh()


## The shop bat, shown in the weapon slot when no Legendary or set bat is worn
## (it can't be taken off; upgrade it at the Bat Shop).
func _weapon() -> Dictionary:
	var bat: Dictionary = Player.BATS[player.bat_tier]
	return {"type": "shop_bat", "name": bat.name, "damage": bat.damage, "tier": player.bat_tier}


func _on_slot_clicked(item_slot: ItemSlot, double: bool) -> void:
	if _selecting:
		if item_slot.bag_index >= 0 and not item_slot.item.is_empty():
			_toggle_mark(item_slot.bag_index)
		return
	_selected = item_slot if not item_slot.item.is_empty() else null
	if double and _selected and _selected.item.get("type", "") != "shop_bat":
		# A shortcut: wear it / take it off.
		if _selected.bag_index >= 0 and ItemDB.is_collar(_selected.item):
			var pet_slot := _collar_target(_selected.item)
			if pet_slot >= 0:
				player.request_equip_collar.rpc_id(1, _selected.bag_index, pet_slot)
		elif _selected.bag_index >= 0:
			player.request_equip.rpc_id(1, _selected.bag_index)
		elif _selected.pet_slot >= 0:
			player.request_unequip_collar.rpc_id(1, _selected.pet_slot)
		else:
			player.request_unequip.rpc_id(1, _selected.equip_slot)
		_selected = null
	refresh()


## An item dragged from `from` and dropped on `to` (both ItemSlots, or the bin).
func _on_dropped(from: ItemSlot, to: ItemSlot) -> void:
	_selected = null
	if to.is_bin:
		if from.bag_index >= 0:
			_discard_indices.assign([from.bag_index])
			_discard_dialog.dialog_text = "Throw away the %s?\nIt's gone for good." % ItemDB.display_name(from.item)
			_discard_dialog.popup_centered()
		elif from.pet_slot >= 0:
			player.request_unequip_collar.rpc_id(1, from.pet_slot)  # take it off first; then it can go
		else:
			player.request_unequip.rpc_id(1, from.equip_slot)  # take it off first; then it can go
		return
	if from.bag_index >= 0 and to.bag_index >= 0:
		player.request_move_in_bag.rpc_id(1, from.bag_index, to.bag_index)
	elif from.bag_index >= 0 and to.pet_slot >= 0:
		player.request_equip_collar.rpc_id(1, from.bag_index, to.pet_slot)
	elif from.pet_slot >= 0 and to.bag_index >= 0:
		player.request_unequip_collar.rpc_id(1, from.pet_slot, to.bag_index)
	elif from.bag_index >= 0:
		player.request_equip.rpc_id(1, from.bag_index, to.equip_slot)
	elif to.bag_index >= 0:
		player.request_unequip.rpc_id(1, from.equip_slot, to.bag_index)


## The party pet a double-clicked collar goes on: the first it fits without a
## collar, else the first it fits.
func _collar_target(item: Dictionary) -> int:
	var first := -1
	for i in Player.MAX_PARTY:
		var pet := player.world.get_party_pet(player.peer_id, i)
		if pet == null or not ItemDB.fits_pet(item, pet.species):
			continue
		if pet.collar.is_empty():
			return i
		if first < 0:
			first = i
	return first


## Right-click: mark an item to throw away (starting select mode).
func _on_slot_marked(item_slot: ItemSlot) -> void:
	if item_slot.bag_index < 0 or item_slot.item.is_empty():
		return
	if not _selecting:
		_set_selecting(true)
	_toggle_mark(item_slot.bag_index)


func _toggle_mark(index: int) -> void:
	if _marked.has(index):
		_marked.erase(index)
	else:
		_marked[index] = true
	refresh()


func _set_selecting(on: bool) -> void:
	_selecting = on
	_marked.clear()
	_select_button.set_pressed_no_signal(on)
	_selected = null
	if is_instance_valid(player):
		refresh()
	else:
		_update_select_controls()


func _mark_all() -> void:
	for i in player.bag.size():
		if not player.bag[i].is_empty():
			_marked[i] = true
	refresh()


func _throw_marked() -> void:
	if _marked.is_empty():
		return
	_discard_indices.assign(_marked.keys())
	_discard_indices.sort()
	var names := _discard_indices.map(func(i: int) -> String: return ItemDB.display_name(player.bag[i]))
	var listed := ", ".join(names.slice(0, 6)) + (", and %d more" % (names.size() - 6) if names.size() > 6 else "")
	_discard_dialog.dialog_text = "Throw away %d item%s?\n%s\nThey're gone for good." % [names.size(),
			"" if names.size() == 1 else "s", listed]
	_discard_dialog.popup_centered()


func _update_select_controls() -> void:
	_all_button.visible = _selecting
	_throw_button.visible = _selecting
	_throw_button.disabled = _marked.is_empty()
	_throw_button.text = "Throw away (%d)" % _marked.size()
	_select_button.text = "Done" if _selecting else "Select"
	_hint.text = "Click bag items to mark them (click again to unmark), then Throw away. Right-click also marks.   [Done] back   [I / Esc] close" \
			if _selecting else \
			"Drag items onto your gear to wear them, into the bag to take them off, or onto the bin to throw them away. Collars go on pets in the Pets tab. Click to see an item; right-click or Select to throw away several.   [I / Esc] close"


func _small_button(text: String, icon: String, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 40)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiIcons.button(button, icon)
	return button


func _update_details() -> void:
	_compare.text = ""
	if _selecting:
		_details.text = "%d marked" % _marked.size()
		return
	if _selected == null:
		_details.text = "Click an item to see what it does."
		return
	var item := _selected.item
	if item.type == "shop_bat":
		_details.text = "%s\nHits for %d. Upgrade it at the Bat Shop in the village." % [item.name, roundi(item.damage)]
		return
	_details.text = "[color=#%s]%s[/color]" % [ItemDB.rarity_color(item).to_html(false), ItemDB.describe(item)]
	if _selected.bag_index >= 0:
		var against := worn_to_compare(item)
		if not against.is_empty():
			_compare.text = compare_text(item, against.item, against.name)
		if ItemDB.is_collar(item) and not _pets_column.visible:
			_details.text += "\n(Open the Pets tab to put it on a pet.)"


## What a bag item would replace, to compare it with: {item, name} (the worn
## piece in its slot, the weaker ring, or the worst collar among the pets who
## can wear it), or {} if nothing is worn there.
func worn_to_compare(item: Dictionary) -> Dictionary:
	if ItemDB.is_collar(item):
		var worst := {}
		for pet in player.world.get_pets(player.peer_id):
			if ItemDB.fits_pet(item, pet.species) and (worst.is_empty()
					or ItemDB.power(pet.collar) < ItemDB.power(worst.item)):
				worst = {"item": pet.collar, "name": "%s's collar" % pet.title()}
		return worst
	var slot := ItemDB.default_slot(item)
	var worn: Dictionary = player.equipment.get(slot, {})
	if slot == "ring1":
		var other: Dictionary = player.equipment.get("ring2", {})
		if other.is_empty() or (not worn.is_empty() and ItemDB.power(other, _party_classes()) < ItemDB.power(worn, _party_classes())):
			worn = other
	return {"item": worn, "name": ItemDB.display_name(worn) if not worn.is_empty() else "nothing"}


## "Compared with your Leather Jacket:" and a green or red line per stat that changes.
static func compare_text(item: Dictionary, worn: Dictionary, worn_name: String) -> String:
	var lines := ["[color=#9aa4b2]Instead of %s:[/color]" % worn_name]
	var changes := ItemDB.compare(item, worn)
	if changes.is_empty():
		lines.append("[color=#9aa4b2]no change[/color]")
	for change in changes:
		lines.append("[color=%s]%s[/color]" % ["#6fdc7a" if change[1] > 0.0 else "#ff7a6e", change[0]])
	return "\n".join(lines)


## True if a bag item would be an upgrade for the tamer or one of the pets.
func is_upgrade(item: Dictionary) -> bool:
	if not ItemDB.is_item(item):
		return false
	var classes := _party_classes()
	var against := worn_to_compare(item)
	if against.is_empty():
		return false
	return ItemDB.power(item, classes) > ItemDB.power(against.item, classes) + 0.5


func _party_classes() -> Array:
	var out := []
	for pet in player.world.get_pets(player.peer_id):
		out.append(pet.species.pet_class())
	return out


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	return label


## One place for an item: an equipment slot or a bag place.
class ItemSlot:
	extends Control

	signal clicked(slot: ItemSlot, double: bool)
	signal dropped(from: ItemSlot, to: ItemSlot)
	signal marked_toggled(slot: ItemSlot)  ## Right-clicked.

	var equip_slot := ""
	var bag_index := -1
	var is_bin := false  ## The throw-away bin.
	var pet_slot := -1  ## For a pet's collar slot: the party slot of that pet.
	var pet_species: CreatureSpecies  ## ...and its species (class collars must match its class).
	var locked := false:  ## A collar slot with no pet in that party slot.
		set(v):
			if v != locked:
				locked = v
				queue_redraw()
	var no_drag := false  ## In select mode clicks mark items instead.
	var marked := false:  ## Marked to throw away.
		set(v):
			if v != marked:
				marked = v
				queue_redraw()
	var _drop_hover := false
	var item := {}:
		set(v):
			item = v
			tooltip_text = _tooltip()
			queue_redraw()
	var selected := false:
		set(v):
			if v != selected:
				selected = v
				queue_redraw()
	## A green arrow in the corner: better than what's worn (see InventoryWindow.is_upgrade).
	var upgrade := false:
		set(v):
			if v != upgrade:
				upgrade = v
				queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self, event.double_click)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			marked_toggled.emit(self)
			accept_event()

	func _get_drag_data(_at: Vector2) -> Variant:
		if is_bin or no_drag or item.is_empty() or item.type == "shop_bat":
			return null
		var preview := ItemSlot.new()
		preview.item = item
		preview.size = size
		preview.position = -size * 0.5
		preview.modulate = Color(1, 1, 1, 0.85)
		var holder := Control.new()  # centres the preview on the mouse
		holder.add_child(preview)
		set_drag_preview(holder)
		return {"item_slot": self}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		var ok := false
		if data is Dictionary and data.has("item_slot") and data.item_slot != self:
			var from: ItemSlot = data.item_slot
			if is_bin:
				ok = true
			elif bag_index >= 0:
				# Into the bag: anything from the bag; worn gear unless a misfit is in the way.
				ok = from.bag_index >= 0 or item.is_empty() or ItemDB.fits(item, from.equip_slot)
			elif pet_slot >= 0:
				ok = not locked and from.bag_index >= 0 and ItemDB.fits_pet(from.item, pet_species)
			elif equip_slot != "":
				ok = ItemDB.fits(from.item, equip_slot)
		if ok != _drop_hover:
			_drop_hover = ok
			queue_redraw()
		return ok

	func _drop_data(_at: Vector2, data: Variant) -> void:
		_drop_hover = false
		queue_redraw()
		dropped.emit(data.item_slot, self)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
			_drop_hover = false
			queue_redraw()
		if what == NOTIFICATION_DRAG_BEGIN:
			queue_redraw()  # light up the places this item can go

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.11, 0.12, 0.15)
		box.set_corner_radius_all(8)
		box.set_border_width_all(2)
		if is_bin:
			box.bg_color = Color(0.2, 0.08, 0.08) if _drop_hover else Color(0.13, 0.1, 0.1)
			box.border_color = Color(1.0, 0.45, 0.4) if _drop_hover else Color(1, 1, 1, 0.12)
			draw_style_box(box, rect)
			var bin_size := int(minf(size.x, size.y) * 0.5)
			draw_texture(UiIcons.texture("trash", bin_size), (size - Vector2(bin_size, bin_size)) * 0.5,
					Color(1.0, 0.6, 0.55) if _drop_hover else Color(1, 1, 1, 0.45))
			return
		if _fits_dragged():
			box.bg_color = Color(0.2, 0.18, 0.1)  # where the dragged item can go
		var border := Color(1, 1, 1, 0.1)
		if item.get("type", "") == "shop_bat":
			border = UiTheme.BORDER
		elif not item.is_empty():
			border = ItemDB.rarity_color(item)
		box.border_color = UiTheme.ACCENT if selected or _drop_hover else border
		if selected or _drop_hover:
			box.set_border_width_all(3)
		elif ItemDB.is_standout(item):  # rare and better: a thick frame and a glow in its colour
			box.set_border_width_all(3)
			box.bg_color = ItemDB.rarity_color(item).darkened(0.8)
			box.shadow_color = Color(ItemDB.rarity_color(item), 0.45)
			box.shadow_size = 6
		draw_style_box(box, rect)
		var icon_size := int(minf(size.x, size.y) * 0.6)
		var icon_name: String
		var tint: Color
		if item.is_empty():
			if equip_slot == "":
				return
			icon_name = ItemDB.SLOT_ICONS[equip_slot]
			tint = Color(1, 1, 1, 0.07 if locked else 0.18)  # an empty slot shows what goes in it
		elif item.type == "shop_bat":
			var art_size := int(minf(size.x, size.y) * 0.86)
			var picture := ItemIcons.shop_bat(int(item.tier), art_size)
			if picture:  # the bat itself
				draw_texture(picture, (size - Vector2(art_size, art_size)) * 0.5)
				icon_name = ""
			else:
				icon_name = "bat"
				tint = Color(0.85, 0.65, 0.42)
		else:  # gear: its own full-colour picture (ItemIcons), a little bigger
			var art_size := int(minf(size.x, size.y) * 0.86)
			draw_texture(ItemIcons.texture(item, art_size), (size - Vector2(art_size, art_size)) * 0.5)
			icon_name = ""
		if icon_name != "":
			var texture := UiIcons.texture(icon_name, icon_size)
			draw_texture(texture, (size - Vector2(icon_size, icon_size)) * 0.5, tint)
		if item.has("ilvl"):
			var font := get_theme_default_font()
			draw_string_outline(font, Vector2(5, size.y - 5), str(int(item.ilvl)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3,
					Color(0, 0, 0, 0.8))
			draw_string(font, Vector2(5, size.y - 5), str(int(item.ilvl)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
					ItemDB.rarity_color(item))
		if upgrade and not marked:  # better than what's worn: a green arrow, top right
			var tip := Vector2(size.x - 9, 4)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(6, 8), tip + Vector2(-6, 8)]), Color(0.45, 0.95, 0.5))
			draw_rect(Rect2(tip + Vector2(-2.5, 8), Vector2(5, 6)), Color(0.45, 0.95, 0.5))
		if marked:  # marked to throw away: red, with a cross in the corner
			var mark := StyleBoxFlat.new()
			mark.bg_color = Color(0.8, 0.15, 0.1, 0.3)
			mark.border_color = Color(1.0, 0.4, 0.35)
			mark.set_border_width_all(3)
			mark.set_corner_radius_all(8)
			draw_style_box(mark, rect)
			var cross := int(size.x * 0.32)
			draw_texture(UiIcons.texture("close", cross), Vector2(size.x - cross - 3, 3), Color(1.0, 0.55, 0.5))

	## True while an item that could go in this gear slot is being dragged.
	func _fits_dragged() -> bool:
		if equip_slot == "" or not get_viewport().gui_is_dragging():
			return false
		var data = get_viewport().gui_get_drag_data()
		if not (data is Dictionary and data.has("item_slot") and data.item_slot != self) or locked:
			return false
		if pet_slot >= 0:
			return data.item_slot.bag_index >= 0 and ItemDB.fits_pet(data.item_slot.item, pet_species)
		return ItemDB.fits(data.item_slot.item, equip_slot)

	func _tooltip() -> String:
		if is_bin:
			return "Drop an item here to throw it away."
		if item.is_empty():
			return ItemDB.SLOT_NAMES.get(equip_slot, "Empty")
		if item.type == "shop_bat":
			return "%s: hits for %d" % [item.name, roundi(item.damage)]
		var price := ItemDB.sell_price(item)
		return ItemDB.describe(item) + "\nSells for %d coin%s at the bat shop." % [price, "" if price == 1 else "s"]
