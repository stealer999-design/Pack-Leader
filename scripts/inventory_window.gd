class_name InventoryWindow
extends PanelContainer
## The inventory (I): what the tamer wears in its seven slots (weapon, chest,
## pants, hat, two rings, a necklace) and the bag. Everything is drag and drop:
## drag an item onto its gear slot to wear it (swapping with what's there),
## drag worn gear into the bag to take it off, drag within the bag to tidy it,
## or onto the bin to throw it away. Click an item to see it; double-click is a
## shortcut to wear / take off. The server does the moving (Player.request_*).

const EQUIP_SIZE := Vector2(64, 64)
const BAG_SIZE := Vector2(54, 54)
const BAG_COLUMNS := 6

var player: Player

var _equip_slots := {}  ## slot name -> ItemSlot
var _bag_slots: Array[ItemSlot] = []
var _armor: Label
var _bag_title: Label
var _details: Label
var _bin: ItemSlot
var _discard_dialog: ConfirmationDialog
var _discard_index := -1
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
		item_slot.dropped.connect(_on_dropped)
		bag_grid.add_child(item_slot)
		_bag_slots.append(item_slot)

	# The selected item, the bin, and how it works.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	box.add_child(bottom)
	_details = Label.new()
	_details.custom_minimum_size = Vector2(0, 54)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_details)
	_bin = ItemSlot.new()
	_bin.is_bin = true
	_bin.custom_minimum_size = Vector2(64, 54)
	_bin.dropped.connect(_on_dropped)
	_bin.tooltip_text = "Drop an item here to throw it away."
	bottom.add_child(_bin)
	var hint := Label.new()
	hint.text = "Drag items onto your gear to wear them, into the bag to take them off, or onto the bin to throw them away. Click to see an item.   [I / Esc] close"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = UiTheme.TEXT_DIM
	box.add_child(hint)
	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.title = "Throw away?"
	_discard_dialog.ok_button_text = "Throw away"
	_discard_dialog.confirmed.connect(func() -> void:
		if _discard_index >= 0:
			player.request_discard.rpc_id(1, _discard_index)
		_discard_index = -1)
	add_child(_discard_dialog)
	UiIcons.button(_discard_dialog.get_ok_button(), "trash")
	UiIcons.button(_discard_dialog.get_cancel_button(), "back")


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
	if double and _selected and _selected.item.get("type", "") != "bat":
		# A shortcut: wear it / take it off.
		if _selected.bag_index >= 0:
			player.request_equip.rpc_id(1, _selected.bag_index)
		else:
			player.request_unequip.rpc_id(1, _selected.equip_slot)
		_selected = null
	refresh()


## An item dragged from `from` and dropped on `to` (both ItemSlots, or the bin).
func _on_dropped(from: ItemSlot, to: ItemSlot) -> void:
	_selected = null
	if to.is_bin:
		if from.bag_index >= 0:
			_discard_index = from.bag_index
			_discard_dialog.dialog_text = "Throw away the %s?\nIt's gone for good." % ItemDB.display_name(from.item)
			_discard_dialog.popup_centered()
		else:
			player.request_unequip.rpc_id(1, from.equip_slot)  # take it off first; then it can go
		return
	if from.bag_index >= 0 and to.bag_index >= 0:
		player.request_move_in_bag.rpc_id(1, from.bag_index, to.bag_index)
	elif from.bag_index >= 0:
		player.request_equip.rpc_id(1, from.bag_index, to.equip_slot)
	elif to.bag_index >= 0:
		player.request_unequip.rpc_id(1, from.equip_slot, to.bag_index)


func _update_details() -> void:
	if _selected == null:
		_details.text = "Click an item to see what it does."
		return
	var item := _selected.item
	if item.type == "bat":
		_details.text = "%s\nHits for %d. Upgrade it at the Bat Shop in the village." % [item.name, roundi(item.damage)]
		return
	_details.text = ItemDB.describe(item)
	if _selected.bag_index >= 0:
		var worn: Dictionary = player.equipment.get(ItemDB.slot_of(item), {})
		if not worn.is_empty():
			_details.text += "\n(wearing: %s, %d%%)" % [ItemDB.display_name(worn), ItemDB.armor(worn)]


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

	var equip_slot := ""
	var bag_index := -1
	var is_bin := false  ## The throw-away bin.
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

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self, event.double_click)

	func _get_drag_data(_at: Vector2) -> Variant:
		if is_bin or item.is_empty() or item.type == "bat":
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
			elif equip_slot != "" and equip_slot != "weapon":
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
		if item.get("type", "") == "bat":
			border = UiTheme.BORDER
		elif not item.is_empty():
			border = ItemDB.rarity_color(item)
		box.border_color = UiTheme.ACCENT if selected or _drop_hover else border
		if selected or _drop_hover:
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

	## True while an item that could go in this gear slot is being dragged.
	func _fits_dragged() -> bool:
		if equip_slot == "" or equip_slot == "weapon" or not get_viewport().gui_is_dragging():
			return false
		var data = get_viewport().gui_get_drag_data()
		return data is Dictionary and data.has("item_slot") and data.item_slot != self \
				and ItemDB.fits(data.item_slot.item, equip_slot)

	func _tooltip() -> String:
		if is_bin:
			return "Drop an item here to throw it away."
		if item.is_empty():
			return ItemDB.SLOT_NAMES.get(equip_slot, "Empty")
		if item.type == "bat":
			return "%s: hits for %d" % [item.name, roundi(item.damage)]
		return ItemDB.describe(item)
