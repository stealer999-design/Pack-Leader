class_name BreederWindow
extends PanelContainer
## The breeder's window (F at the breeder in the village): pick two of your
## pets of the same kind (from the party or the stable) and see the hybrid
## they would have, then pay to breed them. The server checks everything again (see Player.request_breed).

var player: Player

var _parents: Array[PetSlot] = []
var _result: PetSlot
var _info: Label
var _breed: Button
var _grid: GridContainer
var _scroll: ScrollContainer
var _list_signature := ""


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Breeder"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(1.0, 0.7, 0.85)
	box.add_child(title)
	UiIcons.title(title, "heart")
	var greeting := Label.new()
	greeting.text = "\"Two different pets of the same kind, level %d or higher, and I'll raise you something special.\"" \
			% BreedingDB.MIN_PARENT_LEVEL
	greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	greeting.add_theme_font_size_override("font_size", 14)
	greeting.modulate = Color(1, 1, 1, 0.75)
	box.add_child(greeting)

	var pair := HBoxContainer.new()
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	pair.add_theme_constant_override("separation", 10)
	box.add_child(pair)
	# The parents, the result and the Breed button share one compact row, so the
	# button is always on screen, even in a short browser window.
	for i in 2:
		var parent := _slot("parent", Vector2(92, 84))
		parent.clicked.connect(func(_s: PetSlot) -> void: _set_parent(i, null))
		pair.add_child(parent)
		_parents.append(parent)
		pair.add_child(_sign("+" if i == 0 else "="))
	_result = _slot("result", Vector2(100, 90))
	pair.add_child(_result)
	_breed = Button.new()
	_breed.focus_mode = Control.FOCUS_NONE
	_breed.custom_minimum_size = Vector2(190, 56)
	_breed.pressed.connect(_on_breed)
	UiIcons.button(_breed, "egg")
	pair.add_child(_breed)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(700, 36)
	_info.add_theme_font_size_override("font_size", 14)
	box.add_child(_info)

	var list_title := Label.new()
	list_title.text = "Your pets (party and stable), by kind: click two of the same kind to pair them"
	list_title.add_theme_font_size_override("font_size", 14)
	box.add_child(list_title)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.custom_minimum_size = Vector2(700, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 9
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)

	var hint := Label.new()
	hint.text = "Breeding costs %d coins. The parents stay with you; the baby (level 1) joins your party, or the stable.   [F / Esc] close" \
			% BreedingDB.PRICE
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.add_theme_font_size_override("font_size", 12)
	box.add_child(hint)


func open() -> void:
	# The pet list gives up height on short screens (the rest of the window is fixed).
	_scroll.custom_minimum_size.y = clampf(get_viewport_rect().size.y - 420.0, 70.0, 150.0)
	_list_signature = ""
	for parent in _parents:
		_set_parent(_parents.find(parent), null)
	show()
	refresh()


func refresh() -> void:
	if not is_instance_valid(player):
		return
	var candidates := _candidates()
	var signature := str(candidates)
	if signature != _list_signature:
		_list_signature = signature
		_rebuild_list(candidates)
		# Drop a parent whose pet has moved or changed.
		for i in _parents.size():
			var parent := _parents[i]
			if not parent.source.is_empty() and player.pet_at(parent.source.kind, parent.source.index) != parent.pet:
				_set_parent(i, null)
	_update_result()


## Every pet this tamer has, grouped by kind (cats, birds, dogs, lizards):
## {pet, source} for each party pet and hay bed.
func _candidates() -> Array:
	var out := []
	for pet in player.world.get_pets(player.peer_id):
		out.append({"pet": pet.to_data(), "source": {"kind": "party", "index": pet.party_slot}})
	for i in player.stable.size():
		var bed: Dictionary = player.stable[i]
		if not bed.is_empty():
			out.append({"pet": bed, "source": {"kind": "bed", "index": i}})
	var order := ["cat", "bird", "dog", "lizard"]
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return order.find(SpeciesDB.get_species(x.pet.species).body_type) < order.find(SpeciesDB.get_species(y.pet.species).body_type))
	return out


func _rebuild_list(candidates: Array) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for c in candidates:
		var pick := _slot("pick", Vector2(74, 62))
		pick.pet = c.pet
		pick.source = c.source
		var why := _cannot_be_parent(c.pet)
		if why != "":
			pick.tooltip_text += "\n" + why
		pick.clicked.connect(_on_pick)
		_grid.add_child(pick)
	_mark_selected()


func _cannot_be_parent(pet: Dictionary) -> String:
	if BreedingDB.is_hybrid(pet.species):
		return "Hybrids can't be bred again."
	if int(pet.level) < BreedingDB.MIN_PARENT_LEVEL:
		return "Too young: level %d or higher to breed." % BreedingDB.MIN_PARENT_LEVEL
	return ""


func _on_pick(pick: PetSlot) -> void:
	for i in _parents.size():
		if _parents[i].source == pick.source:
			_set_parent(i, null)  # clicking a picked cat again un-picks it
			return
	_set_parent(0 if _parents[0].pet.is_empty() else 1, pick)


func _set_parent(i: int, pick: PetSlot) -> void:
	_parents[i].pet = pick.pet if pick else {}
	_parents[i].source = pick.source if pick else {}
	_mark_selected()
	_update_result()


func _mark_selected() -> void:
	# Once one parent is picked, pets of other kinds fade out: no cross-breeding.
	var first: Dictionary = _parents[0].pet if not _parents[0].pet.is_empty() else _parents[1].pet
	var kind: String = SpeciesDB.get_species(first.species).body_type if not first.is_empty() else ""
	for pick: PetSlot in _grid.get_children():
		pick.selected = _parents.any(func(p: PetSlot) -> bool: return p.source == pick.source)
		var usable := _cannot_be_parent(pick.pet) == "" \
				and (kind == "" or SpeciesDB.get_species(pick.pet.species).body_type == kind)
		pick.modulate = Color.WHITE if usable or pick.selected else Color(1, 1, 1, 0.35)


func _update_result() -> void:
	var a := _parents[0].pet
	var b := _parents[1].pet
	var hybrid := BreedingDB.hybrid_of(a.species, b.species) if not a.is_empty() and not b.is_empty() else -1
	_result.pet = {"species": hybrid, "level": 1} if hybrid >= 0 else {}
	var reason := BreedingDB.cannot_breed_reason(a, b)
	if hybrid >= 0:
		var species := SpeciesDB.get_species(hybrid)
		_info.text = "%s:  %d health, %s attack at level 1.   %s: %s" % [species.display_name, roundi(species.max_health),
				str(species.damage), species.ability.display_name, species.ability.description]
		if reason != "":
			_info.text += "\n" + reason
	else:
		_info.text = reason
	if reason == "" and player.coins < BreedingDB.PRICE:
		reason = "not enough coins"
	_breed.disabled = reason != ""
	_breed.text = "Breed  (%d coins)\nyou have %d" % [BreedingDB.PRICE, player.coins]


func _on_breed() -> void:
	var a := _parents[0].source
	var b := _parents[1].source
	if a.is_empty() or b.is_empty():
		return
	player.request_breed.rpc_id(1, a.kind, a.index, b.kind, b.index)
	_set_parent(0, null)
	_set_parent(1, null)


func _slot(kind: String, min_size: Vector2) -> PetSlot:
	var slot := PetSlot.new()
	slot.kind = kind
	slot.custom_minimum_size = min_size
	slot.pet = {}
	return slot


func _sign(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 34)
	return label
