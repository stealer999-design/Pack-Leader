class_name ActionBar
extends PanelContainer
## The action bar along the bottom of the screen, ARPG style:
##   left:   your health orb with a tiny Potion button (Q), Capture (E) and
##           your bat (LMB)
##   middle: your three pets (1 2 3): portrait, level, health and experience,
##           and their ability's cooldown
##   right:  Pet stance (T) and your coins
## Every box can be clicked as well as using its key; hovering one explains it.
## Inventory (I), Skills (K) and the Menu (Esc) are tiny buttons in `menu_row`,
## which the HUD places just under the mini map.

const SLOT := Vector2(45, 45)
const TINY_SLOT := Vector2(32, 32)
const PET_SLOT := Vector2(63, 63)
const ORB_SIZE := 80.0
const SIDE_WIDTH := 240.0  ## Both sides the same width, so the pets sit in the middle.

var hud: HUD
var player: Player
var health_orb: HealthOrb
var potion_slot: ActionSlot
var capture_slot: ActionSlot
var bat_slot: ActionSlot
var pet_slots: Array[ActionSlot] = []
var _portraits: Array[PetSlot] = []
var stance_slot: ActionSlot
var inventory_slot: ActionSlot
var skills_slot: ActionSlot
var menu_slot: ActionSlot
## Inventory, skills and menu: tiny buttons under the mini map (added by the HUD).
var menu_row: HBoxContainer
var coins_label: Label


func _init(owner_hud: HUD) -> void:
	hud = owner_hud
	name = "ActionBar"
	theme = UiTheme.get_theme()
	add_theme_stylebox_override("panel", _style())
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -8.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	# Left: health, potion, capture, bat (right-aligned, towards the pets).
	var left := HBoxContainer.new()
	left.custom_minimum_size.x = SIDE_WIDTH
	left.alignment = BoxContainer.ALIGNMENT_END
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	health_orb = HealthOrb.new(ORB_SIZE, PET_SLOT.y)
	left.add_child(health_orb)
	potion_slot = _tiny(left, "potion", "Potion (Q): heals 50% of your health. You get a fresh pair every level; buy more at the lemonade stand.")
	potion_slot.size_flags_vertical = Control.SIZE_SHRINK_END
	potion_slot.icon_tint = Color(1.0, 0.45, 0.5)
	potion_slot.pressed.connect(func() -> void: player.use_potion())
	capture_slot = _slot(left, "E", "net", "")
	capture_slot.icon_tint = Color(0.6, 0.9, 1.0)
	capture_slot.pressed.connect(func() -> void: player.try_capture())
	bat_slot = _slot(left, "LMB", "bat", "")
	bat_slot.icon_tint = Color(0.95, 0.75, 0.5)

	# Middle: the pets.
	var pets := HBoxContainer.new()
	pets.add_theme_constant_override("separation", 6)
	row.add_child(pets)
	for i in Player.MAX_PARTY:
		var slot := ActionSlot.new(PET_SLOT)
		_small_text(slot)
		slot.key_text = str(i + 1)
		pets.add_child(slot)
		var portrait := PetSlot.new()
		portrait.kind = "preview"
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.position = Vector2(9, 9)
		portrait.size = PET_SLOT - Vector2(18, 22)
		slot.add_picture(portrait)
		pet_slots.append(slot)
		_portraits.append(portrait)
		slot.pressed.connect(_on_pet_pressed.bind(i))

	# Right: stance, inventory, skills, menu (left-aligned, from the pets).
	var right := HBoxContainer.new()
	right.custom_minimum_size.x = SIDE_WIDTH
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	stance_slot = _slot(right, "T", "sword", "")
	stance_slot.pressed.connect(func() -> void: player.request_toggle_stance.rpc_id(1))
	menu_row = HBoxContainer.new()
	menu_row.name = "MenuButtons"
	menu_row.add_theme_constant_override("separation", 5)
	menu_row.alignment = BoxContainer.ALIGNMENT_END
	menu_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	menu_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu_row.offset_right = -20.0
	menu_row.offset_left = -20.0 - 3 * TINY_SLOT.x - 10.0
	menu_row.offset_top = -54.0  # just under the mini map (see MiniMap)
	menu_row.offset_bottom = -54.0 + TINY_SLOT.y
	inventory_slot = _tiny(menu_row, "bag", "Inventory (I): what you're wearing and the bag of gear you've found, and your pets' collars.")
	inventory_slot.pressed.connect(func() -> void: hud.toggle_inventory())
	skills_slot = _tiny(menu_row, "star", "Pet skills (K): spend the skill points your pets earn as they level up.")
	skills_slot.pressed.connect(func() -> void: hud.toggle_skills())
	menu_slot = _tiny(menu_row, "menu", "Menu (Esc): save, settings, and quit to the title screen.")
	menu_slot.pressed.connect(func() -> void:
		hud.close_windows()
		hud.pause_menu.open())
	var coins := HBoxContainer.new()
	coins.add_theme_constant_override("separation", 6)
	coins.tooltip_text = "Coins: from vases, wild creatures and bosses. Spend them at the lemonade stand and the bat shop."
	coins.mouse_filter = Control.MOUSE_FILTER_PASS
	right.add_child(coins)
	var coin_icon := TextureRect.new()
	coin_icon.texture = UiIcons.texture("coin", 24)
	coin_icon.modulate = Color(1.0, 0.85, 0.35)
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coins.add_child(coin_icon)
	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 16)
	coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	coins_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coins.add_child(coins_label)


func _slot(parent: Control, key: String, icon_name: String, tip: String) -> ActionSlot:
	var slot := ActionSlot.new(SLOT)
	_small_text(slot)
	slot.key_text = key
	slot.icon = UiIcons.texture(icon_name, 48)
	slot.tooltip_text = tip
	parent.add_child(slot)
	return slot


## Smaller writing for the (25% smaller) bar's boxes.
func _small_text(slot: ActionSlot) -> void:
	slot.key_size = 10
	slot.badge_size = 11
	slot.cooldown_size = 15
	slot.caption_size = 11


## A tiny button: just the icon (the key is in its tooltip) and a small badge.
func _tiny(parent: Control, icon_name: String, tip: String) -> ActionSlot:
	var slot := ActionSlot.new(TINY_SLOT)
	slot.icon = UiIcons.texture(icon_name, 32)
	slot.icon_scale = 0.72
	slot.badge_size = 11
	slot.pill_badge = true
	slot.tooltip_text = tip
	parent.add_child(slot)
	return slot


func _style() -> StyleBoxFlat:
	var style := UiTheme.panel_style(Color(0.06, 0.065, 0.085, 0.9))
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


## True while the mouse is over the bar or the tiny buttons (so clicking them doesn't swing the bat).
func has_mouse() -> bool:
	var mouse := get_viewport().get_mouse_position()
	return (is_visible_in_tree() and get_global_rect().has_point(mouse)) \
			or (menu_row.is_visible_in_tree() and menu_row.get_global_rect().has_point(mouse))


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var world := player.world
	coins_label.text = str(player.coins)
	health_orb.set_health(player.health.current, player.health.max_health)
	# Potion.
	potion_slot.badge = "%d" % player.potions
	potion_slot.dim = player.potions <= 0
	potion_slot.cooldown = player.potion_cooldown_fraction()
	potion_slot.cooldown_text = ""
	potion_slot.refresh()
	# Capture: lit when there's a tameable creature to throw at.
	var target := player.capture_target()
	var can_capture := target != null and not target.is_monster() and target.is_wild()
	capture_slot.highlight = can_capture
	capture_slot.dim = target == null
	capture_slot.cooldown = player.capture_cooldown_fraction()
	if player.boost_time_left() > 0.0:
		capture_slot.badge = "x%.1f" % player.boost_multiplier
	else:
		capture_slot.badge = ""
	if can_capture:
		capture_slot.tooltip_text = "Capture (E): throw at the %s (%d%% chance).\nWeaken creatures first: the lower their health, the better the chance." \
				% [target.species.display_name, roundi(target.capture_chance(player.capture_boost()) * 100.0)]
	else:
		capture_slot.tooltip_text = "Capture (E): throw at the creature under the mouse, or the nearest one in range.\nWeaken creatures first: the lower their health, the better the chance. Monsters can't be tamed."
	capture_slot.refresh()
	# Bat.
	var bat: Dictionary = Player.BATS[player.bat_tier]
	bat_slot.cooldown = player.attack_cooldown_fraction()
	bat_slot.tooltip_text = "%s (LMB): hits for %d. Hold to keep swinging.\nIt weakens creatures without killing them (they stop at 1 HP), so you can capture them; it finishes off monsters." \
			% [bat.name, roundi(bat.damage)]
	bat_slot.icon_tint = [Color(0.95, 0.75, 0.5), Color(0.85, 0.85, 0.9), Color(0.75, 0.8, 0.95)][clampi(player.bat_tier, 0, 2)]
	bat_slot.refresh()
	# Pets.
	var by_slot := {}
	for pet in world.get_pets(player.peer_id):
		by_slot[pet.party_slot] = pet
	var any_points := 0
	for i in pet_slots.size():
		var slot := pet_slots[i]
		var portrait := _portraits[i]
		var pet: Creature = by_slot.get(i)
		if pet == null:
			if not portrait.pet.is_empty():
				portrait.pet = {}
			slot.health = -1.0
			slot.xp = -1.0
			slot.cooldown = 0.0
			slot.badge = ""
			slot.caption = "Empty"
			slot.dim = false
			slot.tooltip_text = "An empty party place. Capture a creature (E) or bring a pet from the stable."
			slot.refresh()
			continue
		var data := {"species": pet.species_index, "level": pet.level, "fainted": pet.fainted}
		if portrait.pet.get("species", -1) != data.species or portrait.pet.get("level", -1) != data.level \
				or portrait.pet.get("fainted", false) != data.fainted:
			portrait.pet = data
		slot.caption = "Fainted" if pet.fainted else ""
		slot.dim = pet.fainted
		slot.health = pet.health.current / maxf(pet.health.max_health, 1.0)
		slot.xp = float(pet.xp) / maxf(pet.xp_to_next(), 1.0)
		var points := PetSkills.points_left(pet.level, pet.skill_ranks)
		any_points += points
		slot.badge = "Lv%d%s" % [pet.level, "  +" if points > 0 else ""]
		var ability := pet.species.ability
		slot.cooldown = pet.ability_cooldown_fraction() if ability else 0.0
		slot.cooldown_text = "%d" % ceili(pet.ability_cooldown_left()) if slot.cooldown > 0.0 else ""
		slot.highlight = ability != null and slot.cooldown <= 0.0 and not pet.fainted
		slot.highlight_color = pet.species.color.lightened(0.4)
		var tip := "%s  ·  Level %d  ·  %s\nHealth %d / %d" % [pet.species.display_name, pet.level,
				pet.species.pet_class().capitalize(),
				ceili(pet.health.current), roundi(pet.health.max_health)]
		if ability:
			tip += "\n\nAbility (%d): %s\n%s" % [i + 1, ability.display_name, ability.description]
		if points > 0:
			tip += "\n\n%d skill point%s to spend (K)." % [points, "" if points == 1 else "s"]
		tip += "\nClick to open the skills."
		slot.tooltip_text = tip
		slot.refresh()
	# Stance.
	stance_slot.icon = UiIcons.texture("shield" if player.pets_passive else "sword", 48)
	stance_slot.icon_tint = Color(0.55, 0.85, 1.0) if player.pets_passive else Color(1.0, 0.7, 0.55)
	stance_slot.badge = "Passive" if player.pets_passive else "Attack"
	stance_slot.badge_color = stance_slot.icon_tint
	stance_slot.tooltip_text = "Pet stance (T): %s.\nAggressive pets fight anything near you; Passive pets follow you but never attack, so you can weaken a creature yourself and capture it." \
			% ("Passive" if player.pets_passive else "Aggressive")
	stance_slot.refresh()
	skills_slot.badge = "+%d" % any_points if any_points > 0 else ""
	skills_slot.highlight = any_points > 0
	skills_slot.refresh()


## Clicking a pet: open its skills.
func _on_pet_pressed(_index: int) -> void:
	hud.toggle_skills()
