class_name PetSlot
extends Control
## One place in the stable window: a hay bed, a party slot, or the release gate.
## Draws its background and (if it holds a pet) the pet, and supports drag and
## drop: drag a pet from one slot and drop it on another. The HUD decides what a
## drop means and asks the server to do it.

signal dropped(from: PetSlot, to: PetSlot)

## "bed", "party", "release", or "preview" (the picture that follows the mouse while dragging).
@export var kind := "bed"
@export var index := 0

## The pet shown here: {species, level, fainted} or {} for empty.
var pet := {}:
	set(v):
		pet = v
		tooltip_text = _tooltip()
		queue_redraw()

var _drop_hover := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void:
		_drop_hover = false
		queue_redraw())


func _get_drag_data(_at: Vector2) -> Variant:
	if pet.is_empty() or kind == "release" or kind == "preview":
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
	var ok: bool = data is Dictionary and data.has("pet_slot") and data.pet_slot != self and kind != "preview"
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
		"release":
			_draw_gate()
	if not pet.is_empty():
		var center := size * Vector2(0.5, 0.47 if kind == "bed" else 0.42)
		_draw_pet(center, minf(size.x, size.y) * (0.26 if kind != "preview" else 0.38), kind == "bed")
		if kind != "preview":
			var species := SpeciesDB.get_species(pet.species)
			var label := "%s  Lv%d" % [species.display_name, pet.level]
			_draw_centered_text(label, size.y - 10.0, 13, Color.WHITE)
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


func _draw_cushion() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.2, 0.3, 0.45)
	box.border_color = Color(0.5, 0.7, 0.95)
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	draw_circle(Vector2(18, 18), 12.0, Color(0.5, 0.7, 0.95))
	_draw_text_at(str(index + 1), Vector2(13, 24), 16, Color(0.1, 0.15, 0.25))  # ability key
	if pet.is_empty():
		_draw_centered_text("empty slot", size.y * 0.55, 13, Color(1, 1, 1, 0.45))


func _draw_gate() -> void:
	var post := Color(0.42, 0.27, 0.15)
	draw_rect(Rect2(Vector2(8, 6), Vector2(8, size.y - 12)), post)
	draw_rect(Rect2(Vector2(size.x - 16, 6), Vector2(8, size.y - 12)), post)
	for y in [size.y * 0.3, size.y * 0.6]:
		draw_rect(Rect2(Vector2(16, y), Vector2(size.x * 0.35, 6)), Color(0.55, 0.38, 0.22))  # half-open gate
	draw_rect(Rect2(Vector2(16, size.y * 0.3), Vector2(6, size.y * 0.3 + 6)), Color(0.55, 0.38, 0.22))
	_draw_centered_text("Release", size.y * 0.5 + 6, 16, Color(1, 0.85, 0.75))
	_draw_centered_text("drop a pet here", size.y - 8, 11, Color(1, 1, 1, 0.55))


## A pet portrait: body, ears and eyes (closed while sleeping), in its species colour.
func _draw_pet(center: Vector2, r: float, sleeping: bool) -> void:
	var species := SpeciesDB.get_species(pet.species)
	var body := species.color.darkened(0.5) if pet.get("fainted", false) else species.color
	draw_circle(center + Vector2(0, r * 0.18), r * 1.05, Color(0, 0, 0, 0.25))  # shadow
	for side in [-1.0, 1.0]:
		var ear := PackedVector2Array([
			center + Vector2(side * r * 0.75, -r * 0.45), center + Vector2(side * r * 0.25, -r * 0.8),
			center + Vector2(side * r * 0.55, -r * 1.35),
		])
		draw_colored_polygon(ear, Color(0.15, 0.12, 0.12))
	draw_circle(center, r, body)
	draw_circle(center + Vector2(-r * 0.3, -r * 0.35), r * 0.3, body.lightened(0.35))  # shine
	for side in [-1.0, 1.0]:
		var eye := center + Vector2(side * r * 0.35, -r * 0.05)
		if sleeping:
			draw_arc(eye, r * 0.14, 0.2, PI - 0.2, 8, Color(0.1, 0.1, 0.1), 2.0)
		else:
			draw_circle(eye, r * 0.15, Color.WHITE)
			draw_circle(eye + Vector2(0, r * 0.03), r * 0.07, Color(0.1, 0.1, 0.1))
	if sleeping:
		_draw_text_at("z", center + Vector2(r * 0.9, -r * 0.9), 14, Color(1, 1, 1, 0.85))
		_draw_text_at("z", center + Vector2(r * 1.25, -r * 1.35), 11, Color(1, 1, 1, 0.6))


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
		return "Empty. Drag a pet here." if kind != "release" else "Drop a pet here to release it into the wild."
	var species := SpeciesDB.get_species(pet.species)
	var text := "%s  Lv%d" % [species.display_name, pet.level]
	if species.ability:
		text += "\n%s: %s" % [species.ability.display_name, species.ability.description]
	return text + "\n\nDrag to move it."
