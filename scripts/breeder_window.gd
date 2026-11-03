class_name BreederWindow
extends PanelContainer
## The breeder's window (F at the breeder in the village): pick two of your
## pets of the same kind (from the party or the stable) and see the hybrid
## they would have, then pay to breed them. The server checks everything again (see Player.request_breed).
## The "Sell pets" mode lists every pet (party, reserve and stable): click them
## to mark them and sell them to the breeder (1 coin each, 2 for a hybrid).

var player: Player

var _parents: Array[PetSlot] = []
var _result: PetSlot
var _info: Label
var _breed: Button
var _grid: GridContainer
var _scroll: ScrollContainer
var _list_signature := ""
var _selling := false
var _sell_marked: Array = []  ## [kind, index] of each pet marked to sell.
var _breed_parts: Array[Control] = []  ## Hidden while selling.
var _list_title: Label
var _mode_button: Button
var _sell_button: Button
var _confirm: ConfirmationDialog


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
	greeting.text = "\"Bring me two different pets of the same kind, and I'll raise you something special.\""
	greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	greeting.add_theme_font_size_override("font_size", 14)
	greeting.modulate = Color(1, 1, 1, 0.75)
	box.add_child(greeting)

	_mode_button = Button.new()
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mode_button.pressed.connect(func() -> void: _set_selling(not _selling))
	box.add_child(_mode_button)
	var pair := HBoxContainer.new()
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	pair.add_theme_constant_override("separation", 10)
	box.add_child(pair)
	_breed_parts.append(pair)
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
	_breed_parts.append(_info)

	_list_title = Label.new()
	_list_title.add_theme_font_size_override("font_size", 14)
	box.add_child(_list_title)
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
	_sell_button = Button.new()
	_sell_button.focus_mode = Control.FOCUS_NONE
	_sell_button.custom_minimum_size = Vector2(320, 40)
	_sell_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sell_button.pressed.connect(func() -> void:
		_confirm.dialog_text = "Sell %s to the breeder for %d coin%s?\nThis can't be undone." % [_marked_names(), _marked_total(),
				"" if _marked_total() == 1 else "s"]
		_confirm.popup_centered())
	UiIcons.button(_sell_button, "coin")
	box.add_child(_sell_button)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Sell pets"
	_confirm.confirmed.connect(func() -> void:
		player.request_sell_pets.rpc_id(1, _sell_marked.duplicate())
		_sell_marked.clear())
	add_child(_confirm)

	var hint := Label.new()
	hint.text = "Breeding costs %d coins. The parents stay with you; the baby (at %d%% of their level) joins your party, or the stable.   [F / Esc] close" \
			% [BreedingDB.PRICE, roundi(BreedingDB.BABY_LEVEL_SHARE * 100)]
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.add_theme_font_size_override("font_size", 12)
	box.add_child(hint)


func open() -> void:
	# The pet list gives up height on short screens (the rest of the window is fixed).
	_scroll.custom_minimum_size.y = clampf(get_viewport_rect().size.y - 420.0, 70.0, 150.0)
	_list_signature = ""
	_set_selling(false)
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
		_sell_marked = _sell_marked.filter(func(place: Array) -> bool: return not player.pet_at(place[0], place[1]).is_empty())
		_rebuild_list(candidates)
		# Drop a parent whose pet has moved or changed.
		for i in _parents.size():
			var parent := _parents[i]
			if not parent.source.is_empty() and player.pet_at(parent.source.kind, parent.source.index) != parent.pet:
				_set_parent(i, null)
	if _selling:
		_update_selling()
	else:
		_update_result()


## Switches between breeding and selling pets.
func _set_selling(on: bool) -> void:
	_selling = on
	_sell_marked.clear()
	for part in _breed_parts:
		part.visible = not on
	_sell_button.visible = on
	_mode_button.text = "Back to breeding" if on else "Sell pets to the breeder"
	_mode_button.icon = UiIcons.texture("back" if on else "coin")
	_list_title.text = "Click pets to mark them for sale: 1 coin each, 2 for a hybrid. Collars go back in your bag." if on \
			else "Your pets (party, reserve and stable), by kind: click two of the same kind to pair them"
	_list_signature = ""
	if is_instance_valid(player):
		refresh()


func _update_selling() -> void:
	var count := _sell_marked.size()
	_sell_button.disabled = count == 0
	_sell_button.text = "Sell %d pet%s for %d coin%s" % [count, "" if count == 1 else "s", _marked_total(),
			"" if _marked_total() == 1 else "s"] if count > 0 else "Mark pets to sell"


func _marked_total() -> int:
	var total := 0
	for place in _sell_marked:
		var data: Dictionary = player.pet_at(place[0], place[1])
		if not data.is_empty():
			total += BreedingDB.sell_price(int(data.species))
	return total


func _marked_names() -> String:
	var names := []
	for place in _sell_marked:
		var data: Dictionary = player.pet_at(place[0], place[1])
		if not data.is_empty():
			names.append("your %s (Lv%d)" % [SpeciesDB.get_species(data.species).display_name, data.level])
	return ", ".join(names)


## Every pet this tamer has, grouped by kind (cats, birds, dogs, lizards):
## {pet, source} for each party pet and hay bed.
func _candidates() -> Array:
	var out := []
	for pet in player.world.get_pets(player.peer_id):
		out.append({"pet": pet.to_data(), "source": {"kind": "party", "index": pet.party_slot}})
	for i in player.reserve.size():
		var carried: Dictionary = player.reserve[i]
		if not carried.is_empty():
			out.append({"pet": carried, "source": {"kind": "reserve", "index": i}})
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
		if _selling:
			var where: String = {"party": "in your party", "reserve": "in your reserve", "bed": "in the stable"}[c.source.kind]
			pick.tooltip_text += "\n\n%s. Sells for %d coin%s." % [where.capitalize(), BreedingDB.sell_price(int(c.pet.species)),
					"" if BreedingDB.sell_price(int(c.pet.species)) == 1 else "s"]
		elif why != "":
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
	if _selling:
		var place := [pick.source.kind, pick.source.index]
		if _sell_marked.has(place):
			_sell_marked.erase(place)
		else:
			_sell_marked.append(place)
		_mark_selected()
		_update_selling()
		return
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
	if _selling:
		for pick: PetSlot in _grid.get_children():
			pick.selected = _sell_marked.has([pick.source.kind, pick.source.index])
			pick.modulate = Color.WHITE
		return
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
	var baby_level := BreedingDB.baby_level(int(a.level), int(b.level)) if hybrid >= 0 else 1
	_result.pet = {"species": hybrid, "level": baby_level} if hybrid >= 0 else {}
	var reason := BreedingDB.cannot_breed_reason(a, b)
	if hybrid >= 0:
		var species := SpeciesDB.get_species(hybrid)
		var grown := 1.0 + 0.15 * (baby_level - 1)  # as Creature._level_multiplier
		_info.text = "%s, born at level %d:  %d health, %s attack.   %s: %s" % [species.display_name, baby_level,
				roundi(species.max_health * grown), str(snappedf(species.damage * grown, 0.1)),
				species.ability.display_name, species.ability.description]
		if reason != "":
			_info.text += "\n" + reason
	else:
		_info.text = reason
	if reason == "" and player.coins < BreedingDB.PRICE:
		reason = "Not enough coins"
	_breed.disabled = reason != ""
	# A greyed-out button says why, right on it.
	_breed.text = "Breed  (%d coins)\nyou have %d" % [BreedingDB.PRICE, player.coins] if reason == "" \
			else _short_reason(reason, a, b)
	_breed.tooltip_text = reason


## The reason the button is greyed out, short enough for the button.
func _short_reason(reason: String, a: Dictionary, b: Dictionary) -> String:
	if a.is_empty() or b.is_empty():
		return "Pick two pets\nbelow"
	if reason == "Not enough coins":
		return "Not enough coins\n(%d of %d)" % [player.coins, BreedingDB.PRICE]
	if reason.begins_with("Pets only breed"):
		return "Pick two of the\nsame kind"
	if reason.begins_with("Pick two different"):
		return "Pick two different\nspecies"
	if reason.begins_with("Hybrids"):
		return "Hybrids can't\nbreed"
	return reason


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
