class_name PetSlot
extends Control
## One place in the stable window: a hay bed, a party slot, or the release gate.
## Draws its background and (if it holds a pet) the pet, and supports drag and
## drop: drag a pet from one slot and drop it on another. The HUD decides what a
## drop means and asks the server to do it.

signal dropped(from: PetSlot, to: PetSlot)
## Clicked (only "pick" and "parent" slots, in the breeder window).
signal clicked(slot: PetSlot)

## "bed", "party", "release", or "preview" (the picture that follows the mouse while dragging);
## in the breeder window: "pick" (a pet to choose), "parent" or "result".
@export var kind := "bed"
@export var index := 0

## The pet shown here: {species, level, fainted} or {} for empty.
var pet := {}:
	set(v):
		pet = v
		tooltip_text = _tooltip()
		queue_redraw()

var _drop_hover := false
## Highlighted (a picked parent, in the breeder window).
var selected := false:
	set(v):
		selected = v
		queue_redraw()
## Where the pet lives, for the breeder: {kind: "party"/"bed", index}.
var source := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void:
		_drop_hover = false
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if (kind == "pick" or kind == "parent") and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(self)


func _get_drag_data(_at: Vector2) -> Variant:
	if pet.is_empty() or not (kind == "bed" or kind == "party"):
		return null
	var preview := PetSlot.new()
	preview.kind = "preview"
	preview.pet = pet
	preview.size = Vector2(84, 84)
	preview.position = -preview.size * 0.5
	var holder := Control.new()  # centres the preview on the mouse
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"pet_slot": self}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("pet_slot") and data.pet_slot != self \
			and (kind == "bed" or kind == "party" or kind == "release")
	if ok != _drop_hover:
		_drop_hover = ok
		queue_redraw()
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	_drop_hover = false
	queue_redraw()
	dropped.emit(data.pet_slot, self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drop_hover:
		_drop_hover = false
		queue_redraw()


# --- Drawing -------------------------------------------------------------------------

func _draw() -> void:
	match kind:
		"bed":
			_draw_hay_bed()
		"party":
			_draw_cushion()
		"pick", "parent", "result":
			_draw_cushion(false)
		"release":
			_draw_gate()
	if not pet.is_empty():
		var center := size * Vector2(0.5, 0.47 if kind == "bed" else 0.42)
		_draw_pet(center, minf(size.x, size.y) * (0.26 if kind != "preview" else 0.38), kind == "bed")
		if kind != "preview":
			var species := SpeciesDB.get_species(pet.species)
			var label := "%s  Lv%d" % [species.display_name, pet.level]
			_draw_centered_text(label, size.y - 8.0 if kind == "pick" else size.y - 10.0, 9 if kind == "pick" else 13, Color.WHITE)
	if selected:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(1.0, 0.75, 0.85), false, 3.0)
	if _drop_hover:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(1.0, 0.95, 0.5, 0.9), false, 3.0)


func _draw_hay_bed() -> void:
	var frame := Rect2(Vector2(4, 8), size - Vector2(8, 14))
	draw_rect(frame, Color(0.42, 0.27, 0.15))  # wooden frame
	draw_rect(frame.grow(-5), Color(0.86, 0.71, 0.36))  # straw
	# Straw strands: a fixed pseudo-random pattern per bed, so it doesn't flicker.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + index
	var straw := frame.grow(-7)
	for i in 34:
		var from := straw.position + Vector2(rng.randf() * straw.size.x, rng.randf() * straw.size.y)
		var to := from + Vector2.from_angle(rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0)) * rng.randf_range(8.0, 18.0)
		to = to.clamp(straw.position, straw.end)
		draw_line(from, to, Color(0.68, 0.52, 0.22) if i % 3 else Color(0.96, 0.85, 0.5), 1.5)
	# Posts at the corners.
	for corner in [frame.position, Vector2(frame.end.x - 6, frame.position.y)]:
		draw_rect(Rect2(corner + Vector2(0, -6), Vector2(6, 10)), Color(0.36, 0.22, 0.12))
	if pet.is_empty():
		_draw_centered_text("empty", size.y * 0.55, 12, Color(0.45, 0.32, 0.15, 0.8))


## A party cushion (`numbered` with its ability key), or a breeder slot in pink.
func _draw_cushion(numbered := true) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.2, 0.3, 0.45) if numbered else Color(0.36, 0.2, 0.3)
	box.border_color = Color(0.5, 0.7, 0.95) if numbered else Color(0.95, 0.6, 0.75)
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	if numbered:
		draw_circle(Vector2(18, 18), 12.0, Color(0.5, 0.7, 0.95))
		_draw_text_at(str(index + 1), Vector2(13, 24), 16, Color(0.1, 0.15, 0.25))  # ability key
	if pet.is_empty():
		var text: String = {"parent": "pick a cat", "result": "?"}.get(kind, "empty slot")
		_draw_centered_text(text, size.y * 0.55, 13 if kind != "result" else 30, Color(1, 1, 1, 0.45))


func _draw_gate() -> void:
	var post := Color(0.42, 0.27, 0.15)
	draw_rect(Rect2(Vector2(8, 6), Vector2(8, size.y - 12)), post)
	draw_rect(Rect2(Vector2(size.x - 16, 6), Vector2(8, size.y - 12)), post)
	for y in [size.y * 0.3, size.y * 0.6]:
		draw_rect(Rect2(Vector2(16, y), Vector2(size.x * 0.35, 6)), Color(0.55, 0.38, 0.22))  # half-open gate
	draw_rect(Rect2(Vector2(16, size.y * 0.3), Vector2(6, size.y * 0.3 + 6)), Color(0.55, 0.38, 0.22))
	_draw_centered_text("Release", size.y * 0.5 + 6, 16, Color(1, 0.85, 0.75))
	_draw_centered_text("drop a pet here", size.y - 8, 11, Color(1, 1, 1, 0.55))


## A pet portrait in its species colour, shaped by its body type: a cat, bird,
## dog or lizard. Eyes are closed while it sleeps on a hay bed.
func _draw_pet(center: Vector2, r: float, sleeping: bool) -> void:
	var species := SpeciesDB.get_species(pet.species)
	var body := species.color.darkened(0.5) if pet.get("fainted", false) else species.color
	var accent := body.darkened(0.45)
	var light := body.lightened(0.45)
	var kind := species.body_type
	var eye_y := -0.05
	var eye_x := 0.35
	draw_circle(center + Vector2(0, r * 0.18), r * 1.05, Color(0, 0, 0, 0.25))  # shadow
	# Hybrid features behind the body: a mane (or frill, or ruff) and wings.
	if species.feature == "mane":
		for i in 12:
			draw_circle(center + Vector2.from_angle(TAU * i / 12.0) * r * 0.95, r * 0.3, accent)
	if species.feature == "wings":
		for side in [-1.0, 1.0]:
			_ellipse(center + Vector2(side * r * 1.15, -r * 0.2), Vector2(r * 0.32, r * 0.6), light)
	match kind:
		"bird":
			for i in 3:  # crest
				_triangle(center + Vector2((i - 1) * r * 0.22, -r * 0.85), r * 0.14, r * 0.4, accent)
			for side in [-1.0, 1.0]:  # wings
				_ellipse(center + Vector2(side * r * 0.95, r * 0.15), Vector2(r * 0.3, r * 0.55), accent)
			draw_circle(center, r, body)
			_ellipse(center + Vector2(0, r * 0.45), Vector2(r * 0.6, r * 0.45), light)  # breast
		"dog":
			if species.feature == "big_ears":
				for side in [-1.0, 1.0]:
					_triangle(center + Vector2(side * r * 0.55, -r * 0.6), r * 0.32, r * 0.95, body)
			draw_circle(center, r, body)
			if species.feature != "big_ears":
				for side in [-1.0, 1.0]:  # floppy ears
					_ellipse(center + Vector2(side * r * 0.85, -r * 0.1), Vector2(r * 0.25, r * 0.5), accent)
			_ellipse(center + Vector2(0, r * 0.38), Vector2(r * 0.42, r * 0.3), light)  # snout
			draw_circle(center + Vector2(0, r * 0.25), r * 0.12, Color(0.1, 0.1, 0.1))  # nose
			eye_y = -0.25
		"lizard":
			for i in 5:  # spikes
				_triangle(center + Vector2((i - 2) * r * 0.3, -r * 0.55), r * 0.12, r * 0.3, accent)
			_ellipse(center, Vector2(r * 1.2, r * 0.7), body)
			draw_line(center + Vector2(-r * 0.5, r * 0.3), center + Vector2(r * 0.5, r * 0.3), accent, 2.0)  # grin
			eye_y = -0.45
			eye_x = 0.55
			for side in [-1.0, 1.0]:  # bulging eye sockets
				draw_circle(center + Vector2(side * r * eye_x, r * eye_y), r * 0.26, body)
		_:  # cat
			for side in [-1.0, 1.0]:
				var ear := PackedVector2Array([
					center + Vector2(side * r * 0.75, -r * 0.45), center + Vector2(side * r * 0.25, -r * 0.8),
					center + Vector2(side * r * 0.55, -r * 1.35),
				])
				draw_colored_polygon(ear, body)
			draw_circle(center, r, body)
			for side in [-1.0, 1.0]:  # whiskers
				for dy in [0.2, 0.35]:
					draw_line(center + Vector2(side * r * 0.35, r * dy), center + Vector2(side * r * 1.15, r * (dy * 1.4 - 0.05)),
							Color(0.1, 0.1, 0.1, 0.6), 1.0)
			_triangle(center + Vector2(0, r * 0.25), r * 0.1, -r * 0.12, Color(0.9, 0.5, 0.55))  # nose
	if kind != "lizard":
		draw_circle(center + Vector2(-r * 0.3, -r * 0.35), r * 0.3, body.lightened(0.35))  # shine
	for side in [-1.0, 1.0]:
		var eye := center + Vector2(side * r * eye_x, r * eye_y)
		if sleeping:
			draw_arc(eye, r * 0.14, 0.2, PI - 0.2, 8, Color(0.1, 0.1, 0.1), 2.0)
		else:
			draw_circle(eye, r * 0.15, Color.WHITE)
			draw_circle(eye + Vector2(0, r * 0.03), r * 0.07, Color(0.1, 0.1, 0.1))
	# ...and in front: a horn or a crown.
	var gold := Color(1.0, 0.82, 0.3)
	if species.feature == "horn":
		_triangle(center + Vector2(0, -r * 0.7), r * 0.14, r * 0.6, gold)
	if species.feature == "crown":
		for i in 3:
			_triangle(center + Vector2((i - 1) * r * 0.28, -r * 0.82), r * 0.12, r * 0.38, gold)
		draw_rect(Rect2(center + Vector2(-r * 0.45, -r * 0.9), Vector2(r * 0.9, r * 0.14)), gold)
	if kind == "bird":  # beak, drawn over the face
		_triangle(center + Vector2(0, r * 0.12), r * 0.18, -r * 0.3, Color(1.0, 0.68, 0.15))
	if sleeping:
		_draw_text_at("z", center + Vector2(r * 0.9, -r * 0.9), 14, Color(1, 1, 1, 0.85))
		_draw_text_at("z", center + Vector2(r * 1.25, -r * 1.35), 11, Color(1, 1, 1, 0.6))


## A triangle standing on a base of half-width `half` centred at `base`, `height` tall
## (pointing up; a negative height points it down).
func _triangle(base: Vector2, half: float, height: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([base + Vector2(-half, 0), base + Vector2(half, 0), base + Vector2(0, -height)]), color)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radii / radii.x)
	draw_circle(Vector2.ZERO, radii.x, color)
	draw_set_transform(Vector2.ZERO)


func _draw_centered_text(text: String, baseline: float, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(font, Vector2((size.x - width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, 4, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2((size.x - width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_text_at(text: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(get_theme_default_font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _tooltip() -> String:
	if pet.is_empty():
		if kind == "parent" or kind == "result":
			return "Pick two different cats below."
		return "Empty. Drag a pet here." if kind != "release" else "Drop a pet here to release it into the wild."
	var species := SpeciesDB.get_species(pet.species)
	var text := "%s  Lv%d" % [species.display_name, pet.level]
	if species.pet_class() == "wizard":
		text += "  ·  Wizard (ranged magic attacks; its ability is a spell)"
	elif species.is_archer():
		text += "  ·  Archer (shoots arrows from long range and keeps its distance; its ability is a ranged shot)"
	elif species.is_paladin():
		text += "  ·  Paladin (a melee tank: +35% health, 15% less damage, its hits heal the most hurt ally, enemies go for it first; its ability heals or protects)"
	if species.ability:
		text += "\n%s: %s" % [species.ability.display_name, species.ability.description]
	var ranks: Array = pet.get("skills", PetSkills.empty_ranks())
	var skills := PetSkills.all_for(pet.species)
	text += "\n\nSkills:"
	for i in skills.size():
		if int(ranks[i]) > 0:
			text += "\n  %s  %d/%d: %s" % [skills[i].name, ranks[i], PetSkills.MAX_RANK, PetSkills.effect_text(skills[i], ranks[i])]
	if PetSkills.points_spent(ranks) == 0:
		text += "  none trained yet"
	var left := PetSkills.points_left(pet.level, ranks)
	if left > 0:
		text += "\n  %d skill point%s to spend (in the party, press K)" % [left, "" if left == 1 else "s"]
	return text + ("\n\nDrag to move it." if kind == "bed" or kind == "party" else "")
