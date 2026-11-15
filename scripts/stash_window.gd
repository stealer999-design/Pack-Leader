class_name StashWindow
extends PanelContainer
## The stash chest in town (F): ItemDB.STASH_SIZE places for gear kept between
## runs, beside the bag. Click an item to move it across (stash to bag or bag
## to stash); the server does the moving (Player.request_stash_move).

const SLOT_SIZE := Vector2(46, 46)
const COLUMNS := 8

var player: Player
var _stash_slots: Array = []
var _bag_slots: Array = []
var _stash_title: Label
var _bag_title: Label
var _details: Label


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
	title.text = "Stash"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = UiTheme.ACCENT
	box.add_child(title)
	UiIcons.title(title, "bag")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	box.add_child(columns)
	_stash_title = Label.new()
	_bag_title = Label.new()
	_stash_slots = _grid(columns, _stash_title, ItemDB.STASH_SIZE, "stash")
	_bag_slots = _grid(columns, _bag_title, ItemDB.BAG_SIZE, "bag")
	_details = Label.new()
	_details.custom_minimum_size = Vector2(0, 40)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 13)
	box.add_child(_details)
	var hint := Label.new()
	hint.text = "Click an item to move it between the stash and your bag. The stash keeps your gear between runs.   [F / Esc] close"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = UiTheme.TEXT_DIM
	box.add_child(hint)


func _grid(parent: Control, heading: Label, count: int, kind: String) -> Array:
	var column := VBoxContainer.new()
	parent.add_child(column)
	heading.add_theme_font_size_override("font_size", 15)
	column.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	column.add_child(grid)
	var out := []
	for i in count:
		var slot := InventoryWindow.ItemSlot.new()
		slot.bag_index = i
		slot.no_drag = true
		slot.custom_minimum_size = SLOT_SIZE
		slot.clicked.connect(func(s, _double: bool) -> void:
			if s.item.is_empty():
				return
			player.request_stash_move.rpc_id(1, kind, s.bag_index))
		slot.mouse_entered.connect(func() -> void:
			_details.text = ItemDB.describe(slot.item) if not slot.item.is_empty() else "")
		grid.add_child(slot)
		out.append(slot)
	return out


func bind(new_player: Player) -> void:
	player = new_player
	player.inventory_changed.connect(refresh)


func open() -> void:
	show()
	refresh()


func refresh() -> void:
	if player == null or not visible:
		return
	var used := 0
	for slot in _stash_slots:
		slot.item = player.stash[slot.bag_index] if slot.bag_index < player.stash.size() else {}
		used += 0 if slot.item.is_empty() else 1
	_stash_title.text = "Stash   %d / %d" % [used, ItemDB.STASH_SIZE]
	used = 0
	for slot in _bag_slots:
		slot.item = player.bag[slot.bag_index] if slot.bag_index < player.bag.size() else {}
		used += 0 if slot.item.is_empty() else 1
	_bag_title.text = "Bag   %d / %d" % [used, ItemDB.BAG_SIZE]
