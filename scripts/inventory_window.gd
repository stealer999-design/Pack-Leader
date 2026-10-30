class_name InventoryWindow
extends PanelContainer
## The inventory (I): what the tamer wears in its seven slots (weapon, chest,
## pants, hat, two rings, a necklace) and the bag. Click an item to see it,
## double-click (or the button) to put it on or take it off. The server does
## the moving (Player.request_equip / request_unequip / request_discard).

const EQUIP_SIZE := Vector2(64, 64)
const BAG_SIZE := Vector2(54, 54)
const BAG_COLUMNS := 6

var player: Player

var _equip_slots := {}  ## slot name -> ItemSlot
var _bag_slots: Array[ItemSlot] = []
var _armor: Label
var _bag_title: Label
var _details: Label
var _use: Button
var _discard: Button
var _selected: ItemSlot


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

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	box.add_child(columns)
	# Worn gear: hat & necklace, chest & ring, pants & ring, weapon.
	var worn := VBoxContainer.new()
	columns.add_child(worn)
	worn.add_child(_heading("Equipped"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	worn.add_child(grid)
	for slot in ["hat", "necklace", "chest", "ring1", "pants", "ring2", "weapon"]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var item_slot := ItemSlot.new()
		item_slot.equip_slot = slot
		item_slot.custom_minimum_size = EQUIP_SIZE
		item_slot.clicked.connect(_on_slot_clicked)
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
		bag_grid.add_child(item_slot)
		_bag_slots.append(item_slot)

	# The selected item and what to do with it.
	_details = Label.new()
	_details.custom_minimum_size = Vector2(0, 54)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_details)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_use = Button.new()
	_use.focus_mode = Control.FOCUS_NONE
	_use.custom_minimum_size = Vector2(160, 36)
	_use.pressed.connect(_use_selected)
	buttons.add_child(_use)
	_discard = Button.new()
	_discard.text = "Throw away"
	_discard.focus_mode = Control.FOCUS_NONE
	_discard.custom_minimum_size = Vector2(140, 36)
	UiIcons.button(_discard, "trash")
	_discard.pressed.connect(_discard_selected)
	buttons.add_child(_discard)
	var hint := Label.new()
	hint.text = "Click an item to see it; double-click to wear or take off.   [I / Esc] close"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = UiTheme.TEXT_DIM
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buttons.add_child(hint)


func bind(new_player: Player) -> void:
	player = new_player
	player.inventory_changed.connect(refresh)


func open() -> void:
	_selected = null
	show()
	refresh()


func refresh() -> void:
	if not is_instance_valid(player):
		return
	for slot in _equip_slots:
		var item_slot: ItemSlot = _equip_slots[slot]
		item_slot.item = _weapon() if slot == "weapon" else player.equipment.get(slot, {})
	var used := 0
	for item_slot in _bag_slots:
		item_slot.item = player.bag[item_slot.bag_index] if item_slot.bag_index < player.bag.size() else {}
		if not item_slot.item.is_empty():
			used += 1
	_bag_title.text = "Bag   %d / %d" % [used, ItemDB.BAG_SIZE]
	_armor.text = "Armor: take %d%% less damage" % player.armor_percent()
	if _selected and _selected.item.is_empty():
		_selected = null
	for item_slot in _bag_slots + _equip_slots.values():
		item_slot.selected = item_slot == _selected
	_update_details()


## The bat, shown in the weapon slot (it can't be taken off; upgrade it at the Bat Shop).
func _weapon() -> Dictionary:
	var bat: Dictionary = Player.BATS[player.bat_tier]
	return {"type": "bat", "name": bat.name, "damage": bat.damage, "tier": player.bat_tier}


func _on_slot_clicked(item_slot: ItemSlot, double: bool) -> void:
	_selected = item_slot if not item_slot.item.is_empty() else null
	if double and _selected:
		_use_selected()
	refresh()


func _update_details() -> void:
	_use.visible = _selected != null and _selected.item.get("type", "") != "bat"
	_discard.visible = _selected != null and _selected.bag_index >= 0
	if _selected == null:
		_details.text = "Click an item to see what it does."
		return
	var item := _selected.item
	if item.type == "bat":
		_details.text = "%s\nHits for %d. Upgrade it at the Bat Shop in the village." % [item.name, roundi(item.damage)]
		return
	_details.text = ItemDB.describe(item)
	if _selected.bag_index >= 0:
		var slot := ItemDB.slot_of(item)
		var worn: Dictionary = player.equipment.get(slot, {})
		if not worn.is_empty():
			_details.text += "   (wearing: %s, %d%%)" % [ItemDB.display_name(worn), ItemDB.armor(worn)]
		_use.text = "Wear"
		UiIcons.button(_use, "plus")
	else:
		_use.text = "Take off"
		UiIcons.button(_use, "back")


func _use_selected() -> void:
	if _selected == null or _selected.item.get("type", "") == "bat":
		return
	if _selected.bag_index >= 0:
		player.request_equip.rpc_id(1, _selected.bag_index)
	else:
		player.request_unequip.rpc_id(1, _selected.equip_slot)
	_selected = null


func _discard_selected() -> void:
	if _selected and _selected.bag_index >= 0:
		player.request_discard.rpc_id(1, _selected.bag_index)
		_selected = null


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	return label


## One place for an item: an equipment slot or a bag place.
class ItemSlot:
	extends Control

	signal clicked(slot: ItemSlot, double: bool)

	var equip_slot := ""
	var bag_index := -1
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

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			clicked.emit(self, event.double_click)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.11, 0.12, 0.15)
		box.set_corner_radius_all(8)
		box.set_border_width_all(2)
		var border := Color(1, 1, 1, 0.1)
		if item.get("type", "") == "bat":
			border = UiTheme.BORDER
		elif not item.is_empty():
			border = ItemDB.rarity_color(item)
		box.border_color = UiTheme.ACCENT if selected else border
		if selected:
			box.set_border_width_all(3)
		draw_style_box(box, rect)
		var icon_size := int(minf(size.x, size.y) * 0.6)
		var icon_name: String
		var tint: Color
		if item.is_empty():
			if equip_slot == "":
				return
			icon_name = ItemDB.SLOT_ICONS[equip_slot]
			tint = Color(1, 1, 1, 0.18)  # an empty slot shows what goes in it
		elif item.type == "bat":
			icon_name = "bat"
			tint = Color(0.85, 0.65, 0.42)
		else:
			icon_name = ItemDB.SLOT_ICONS[ItemDB.slot_of(item)]
			tint = ItemDB.item_color(item).lightened(0.45)
		var texture := UiIcons.texture(icon_name, icon_size)
		draw_texture(texture, (size - Vector2(icon_size, icon_size)) * 0.5, tint)
		if item.has("level"):
			var font := get_theme_default_font()
			draw_string_outline(font, Vector2(5, size.y - 5), str(int(item.level)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3,
					Color(0, 0, 0, 0.8))
			draw_string(font, Vector2(5, size.y - 5), str(int(item.level)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
					ItemDB.rarity_color(item))

	func _tooltip() -> String:
		if item.is_empty():
			return ItemDB.SLOT_NAMES.get(equip_slot, "Empty")
		if item.type == "bat":
			return "%s: hits for %d" % [item.name, roundi(item.damage)]
		return ItemDB.describe(item)
