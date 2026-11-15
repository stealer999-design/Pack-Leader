class_name SkillWindow
extends PanelContainer
## The skills screen (K): one tab per party pet, and its skill tree. That's six
## skills in a row, unlocked left to right as the pet levels up, each with an
## icon and up to PetSkills.MAX_RANK ranks. Clicking a skill asks the server
## to spend one of the pet's skill points on it.

var player: Player
var _slot := 0  ## The party slot being shown.

var _tabs: HBoxContainer
var _title: Label
var _points: Label
var _tree: SkillTree
var _reset: Button
var _empty: Label


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(980, 0)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = "Skills"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	heading.modulate = Color(1, 0.85, 0.5)
	box.add_child(heading)
	UiIcons.title(heading, "star")
	_tabs = HBoxContainer.new()
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 8)
	box.add_child(_tabs)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	box.add_child(_title)
	_points = Label.new()
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_points)
	_empty = Label.new()
	_empty.text = "No pets in your party. Capture one, or bring one from the stable."
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.custom_minimum_size.y = 200
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_empty)
	_tree = SkillTree.new()
	_tree.trained.connect(func(index: int) -> void: player.request_train_skill.rpc_id(1, _slot, index))
	_tree.untrained.connect(func(index: int) -> void: player.request_untrain_skill.rpc_id(1, _slot, index))
	box.add_child(_tree)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	box.add_child(bottom)
	_reset = Button.new()
	_reset.text = "Reset skills"
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.tooltip_text = "Get back every skill point this pet has spent, to choose again. Free."
	_reset.pressed.connect(func() -> void: player.request_reset_skills.rpc_id(1, _slot))
	UiIcons.button(_reset, "reset")
	bottom.add_child(_reset)
	var hint := Label.new()
	hint.text = "Click a skill to spend a point on it; right-click to take a point back. Pets earn a point at level 5 and every 2 levels after.   [K / Esc] close"
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(hint)


func open() -> void:
	show()
	var pets := _pets()
	if not pets.is_empty() and pets.filter(func(p: Creature) -> bool: return p.party_slot == _slot).is_empty():
		_slot = pets[0].party_slot
	refresh()


func _process(_delta: float) -> void:
	if visible:
		refresh()
		# Stay centred as the contents change size.
		position = ((get_parent_area_size() - size) * 0.5).round()


func refresh() -> void:
	if not is_instance_valid(player):
		return
	var pets := _pets()
	_rebuild_tabs(pets)
	var pet: Creature = null
	for p in pets:
		if p.party_slot == _slot:
			pet = p
	_empty.visible = pet == null
	_tree.visible = pet != null
	_title.visible = pet != null
	_points.visible = pet != null
	_reset.visible = pet != null
	if pet == null:
		return
	_title.text = "%s   Lv%d   ·   %s tree" % [pet.title(), pet.level, PetSkills.tree_name(pet.species_index)]
	_title.modulate = pet.species.color.lightened(0.35)
	var left := PetSkills.points_left(pet.level, pet.skill_ranks)
	_points.text = "Skill points: %d to spend   (%d earned)" % [left, PetSkills.points_for_level(pet.level)]
	if pet.gear_ranks() > 0:
		_points.text += "   ·   Gear: +%d to every unlocked skill" % pet.gear_ranks()
	_points.modulate = Color(1, 0.85, 0.4) if left > 0 else Color(1, 1, 1, 0.7)
	_reset.disabled = PetSkills.points_spent(pet.skill_ranks) == 0
	_tree.show_pet(pet.species_index, pet.level, pet.skill_ranks)


func _pets() -> Array[Creature]:
	return player.world.get_pets(player.peer_id)


func _rebuild_tabs(pets: Array[Creature]) -> void:
	var labels := pets.map(func(p: Creature) -> String: return _tab_text(p))
	var current := _tabs.get_children().map(func(b: Button) -> String: return b.text)
	if labels == current and _tabs.get_child_count() == pets.size():
		for i in pets.size():
			(_tabs.get_child(i) as Button).button_pressed = pets[i].party_slot == _slot
		return
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	for p in pets:
		var tab := Button.new()
		tab.text = _tab_text(p)
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.button_pressed = p.party_slot == _slot
		tab.custom_minimum_size = Vector2(220, 34)
		UiIcons.button(tab, "paw")
		var slot := p.party_slot
		tab.pressed.connect(func() -> void:
			_slot = slot
			refresh())
		_tabs.add_child(tab)


func _tab_text(p: Creature) -> String:
	var left := PetSkills.points_left(p.level, p.skill_ranks)
	return "[%d] %s Lv%d%s" % [p.party_slot + 1, p.title(), p.level,
			"   +%d" % left if left > 0 else ""]


## The six skills of one pet in a row, joined by lines; each is a SkillNode.
class SkillTree:
	extends Control

	signal trained(index: int)
	signal untrained(index: int)

	const NODE_SIZE := Vector2(148, 210)
	const GAP := 12.0

	var _nodes: Array[SkillNode] = []

	func _init() -> void:
		custom_minimum_size = Vector2(PetSkills.SKILL_COUNT * (NODE_SIZE.x + GAP) - GAP, NODE_SIZE.y)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for i in PetSkills.SKILL_COUNT:
			var node := SkillNode.new()
			node.position = Vector2(i * (NODE_SIZE.x + GAP), 0)
			node.size = NODE_SIZE
			node.clicked.connect(func() -> void: trained.emit(i))
			node.right_clicked.connect(func() -> void: untrained.emit(i))
			add_child(node)
			_nodes.append(node)

	func show_pet(species_index: int, level: int, ranks: Array) -> void:
		var skills := PetSkills.all_for(species_index)
		for i in _nodes.size():
			_nodes[i].set_skill(skills[i], int(ranks[i]), level, PetSkills.cannot_train_reason(level, ranks, i))
		queue_redraw()

	func _draw() -> void:
		# Connectors between the icons: lit once the next skill is unlocked.
		for i in _nodes.size() - 1:
			var y := SkillNode.ICON_CENTER_Y
			var from := Vector2(_nodes[i].position.x + NODE_SIZE.x * 0.5 + SkillNode.ICON_RADIUS, y)
			var to := Vector2(_nodes[i + 1].position.x + NODE_SIZE.x * 0.5 - SkillNode.ICON_RADIUS, y)
			var lit := not _nodes[i + 1].locked
			draw_line(from, to, Color(0.95, 0.8, 0.45) if lit else Color(1, 1, 1, 0.2), 4.0 if lit else 2.0)


## One skill: a round icon, its name, rank pips and what it does.
class SkillNode:
	extends Control

	signal clicked
	signal right_clicked

	const ICON_RADIUS := 34.0
	const ICON_CENTER_Y := 46.0

	var skill := {}
	var rank := 0
	var locked := true
	var can_train := false
	var _reason := ""  ## Why it can't be trained ("" if it can).
	var _hover := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func set_skill(new_skill: Dictionary, new_rank: int, pet_level: int, reason: String) -> void:
		skill = new_skill
		rank = new_rank
		locked = pet_level < new_skill.level
		can_train = reason == ""
		_reason = reason
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_train or rank > 0 else Control.CURSOR_ARROW
		tooltip_text = _tooltip()
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			clicked.emit()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			if rank > 0:
				right_clicked.emit()

	func _draw() -> void:
		if skill.is_empty():
			return
		var center := Vector2(size.x * 0.5, ICON_CENTER_Y)
		var color := SkillIcons.color_for(skill.stat)
		var dim := 0.35 if locked else 1.0
		# Card behind the skill.
		var card := StyleBoxFlat.new()
		card.bg_color = Color(1, 1, 1, 0.06 if not _hover or locked else 0.12)
		card.set_corner_radius_all(10)
		card.border_color = Color(0.95, 0.8, 0.45, 0.9) if can_train else Color(1, 1, 1, 0.12)
		card.set_border_width_all(2 if can_train else 1)
		draw_style_box(card, Rect2(Vector2.ZERO, size))
		# Icon disc and ring: the ring fills a quarter per rank.
		draw_circle(center, ICON_RADIUS + 5, Color(0, 0, 0, 0.45))
		draw_circle(center, ICON_RADIUS, color.darkened(0.65) * Color(1, 1, 1, dim))
		draw_arc(center, ICON_RADIUS + 3, 0, TAU, 48, Color(1, 1, 1, 0.15), 3.0)
		if rank > 0:
			draw_arc(center, ICON_RADIUS + 3, -PI / 2, -PI / 2 + TAU * rank / PetSkills.MAX_RANK, 48,
					Color(1.0, 0.85, 0.4), 4.0)
		SkillIcons.draw_icon(self, skill.stat, center, ICON_RADIUS * 0.62, Color(color, dim))
		if locked:
			SkillIcons.draw_lock(self, center + Vector2(ICON_RADIUS * 0.62, ICON_RADIUS * 0.62), 11.0)
		# Name, pips and effect.
		_text(skill.name, 98, 15, Color(1, 1, 1, dim))
		var pip_w := 18.0
		var start := size.x * 0.5 - (PetSkills.MAX_RANK * pip_w) * 0.5
		for i in PetSkills.MAX_RANK:
			var pip := Rect2(Vector2(start + i * pip_w + 3, 108), Vector2(pip_w - 6, 8))
			draw_rect(pip, Color(1.0, 0.85, 0.4) if i < rank else Color(1, 1, 1, 0.18 * dim))
		_text("Rank %d / %d" % [rank, PetSkills.MAX_RANK], 134, 12, Color(1, 1, 1, 0.75 * dim))
		if locked:
			_text("Unlocks at Lv%d" % skill.level, 160, 13, Color(1, 0.6, 0.45))
		else:
			var shown := maxi(rank, 1)
			_wrapped(("Now: " if rank > 0 else "Rank 1: ") + PetSkills.effect_text(skill, shown), 154, 12,
					color.lightened(0.3))
			if rank < PetSkills.MAX_RANK and rank > 0:
				_wrapped("Next: " + PetSkills.effect_text(skill, rank + 1), 184, 11, Color(1, 1, 1, 0.6))

	func _text(text: String, baseline: float, font_size: int, color: Color) -> void:
		var font := get_theme_default_font()
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2((size.x - width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	func _wrapped(text: String, top: float, font_size: int, color: Color) -> void:
		draw_multiline_string(get_theme_default_font(), Vector2(8, top), text, HORIZONTAL_ALIGNMENT_CENTER,
				size.x - 16, font_size, 2, color)

	func _tooltip() -> String:
		var lines := ["%s   (rank %d / %d)" % [skill.name, rank, PetSkills.MAX_RANK]]
		for r in range(1, PetSkills.MAX_RANK + 1):
			lines.append("  Rank %d: %s" % [r, PetSkills.effect_text(skill, r)])
		if PetSkills.is_pack(skill):
			lines.append("Pack skill: works for every pet in your party while this one is awake.")
		lines.append(_reason if not can_train else "Click to spend a skill point.")
		if rank > 0:
			lines.append("Right-click to take a point back.")
		return "\n".join(lines)
