class_name ActionSlot
extends Control
## One box on the action bar (see ActionBar): a framed square with an icon (or
## a pet's portrait), its key in the top-left corner, a dark cooldown sweep
## that drains clockwise, an optional count or badge in the bottom-right, and
## (for pets) health and experience strips along the bottom. Clicking it emits
## `pressed`.

signal pressed

const FRAME := Color(0.86, 0.72, 0.48, 0.8)
const BACK := Color(0.1, 0.1, 0.13, 0.95)
const SHADE := Color(0.0, 0.0, 0.0, 0.62)

## The key, shown in the corner ("LMB", "1", "E"...).
var key_text := ""
var icon: Texture2D
var icon_tint := Color.WHITE
## The icon's size, as a share of the box.
var icon_scale := 0.62
## Font sizes: the badge, the key in the corner, the cooldown seconds, the caption.
var badge_size := 14
var key_size := 12
var cooldown_size := 18
var caption_size := 13
## Tiny buttons show the badge as a red pill on the top-right corner.
var pill_badge := false
## 0 = ready, 1 = just used.
var cooldown := 0.0
## Seconds left, drawn over the sweep (empty for none).
var cooldown_text := ""
## Bottom-right corner text (a count, "+2", "3 new").
var badge := ""
var badge_color := Color(1.0, 0.85, 0.5)
## Greyed out (nothing to do: no potions, nothing to capture, fainted pet).
var dim := false
## Lit border (ready to use, e.g. a weakened creature in range for capture).
var highlight := false
var highlight_color := Color(1.0, 0.9, 0.45)
## Pet strips: health and experience, 0..1 (negative = none).
var health := -1.0
var xp := -1.0
## A caption across the middle (e.g. "Fainted", "Empty").
var caption := ""

var _hover := false
## Everything but the background is drawn on this child, kept on top, so a
## portrait added to the slot sits between the two.
var _overlay := Control.new()


func _init(slot_size := Vector2(64, 64)) -> void:
	custom_minimum_size = slot_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hover = true
		refresh())
	mouse_exited.connect(func() -> void:
		_hover = false
		refresh())
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


## Redraws the slot after its fields change.
func refresh() -> void:
	queue_redraw()
	_overlay.queue_redraw()


## Adds a picture (a pet portrait) under the slot's overlays.
func add_picture(picture: Control) -> void:
	add_child(picture)
	move_child(picture, 0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		var tween := create_tween()
		pivot_offset = size / 2.0
		tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.05)
		tween.tween_property(self, "scale", Vector2.ONE, 0.08)
		pressed.emit()


## Grows and shrinks a couple of times to catch the eye.
func flash() -> void:
	pivot_offset = size / 2.0
	var tween := create_tween()
	for i in 2:
		tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12)
		tween.tween_property(self, "scale", Vector2.ONE, 0.15)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var inner := rect.grow(-3.0)
	draw_rect(rect, BACK)
	# A soft inner gradient: lighter at the top.
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.45)), Color(1, 1, 1, 0.05))


func _draw_overlay() -> void:
	var c := _overlay
	var rect := Rect2(Vector2.ZERO, size)
	var inner := rect.grow(-3.0)
	if icon:
		var side := minf(inner.size.x, inner.size.y) * icon_scale
		var at := inner.position + (inner.size - Vector2(side, side)) * Vector2(0.5, 0.42 if health >= 0.0 else 0.5)
		c.draw_texture_rect(icon, Rect2(at, Vector2(side, side)), false, icon_tint if not dim else Color(icon_tint, 0.35))
	# Pet strips along the bottom.
	if health >= 0.0:
		var bar := Rect2(inner.position.x + 2, inner.end.y - 10, inner.size.x - 4, 5)
		c.draw_rect(bar, Color(0, 0, 0, 0.7))
		var hp_color := Color(0.35, 0.9, 0.4) if health > 0.35 else Color(1.0, 0.45, 0.3)
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(health, 0, 1), bar.size.y)), hp_color)
	if xp >= 0.0:
		var bar := Rect2(inner.position.x + 2, inner.end.y - 5, inner.size.x - 4, 3)
		c.draw_rect(bar, Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(xp, 0, 1), bar.size.y)), Color(0.5, 0.72, 1.0))
	if dim:
		c.draw_rect(inner, Color(0, 0, 0, 0.45))
	# The cooldown: a dark wedge, from 12 o'clock clockwise, shrinking as it recovers.
	if cooldown > 0.001:
		var center := inner.get_center()
		var radius := inner.size.length()
		var points := PackedVector2Array([center])
		var steps := 24
		var start := -PI / 2.0 + TAU * (1.0 - cooldown)
		for i in steps + 1:
			var angle := start + TAU * cooldown * i / steps
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		_draw_clipped(c, points, inner)
		if cooldown_text != "":
			_text(c, cooldown_text, inner.get_center() + Vector2(0, cooldown_size * 0.38), cooldown_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	if caption != "":
		_text(c, caption, inner.get_center() + Vector2(0, caption_size * 0.38), caption_size, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	# Frame.
	var frame_color := FRAME
	var width := 2.0
	if highlight:
		frame_color = highlight_color
		width = 3.0
	if _hover:
		frame_color = frame_color.lightened(0.35)
	c.draw_rect(rect.grow(-1.0), frame_color, false, width)
	if key_text != "":
		var font := get_theme_default_font()
		var w := font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_size).x
		c.draw_rect(Rect2(Vector2(2, 2), Vector2(w + 6, key_size + 4)), Color(0, 0, 0, 0.7))
		_text(c, key_text, Vector2(5, key_size + 2), key_size, Color(1.0, 0.92, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	if badge != "":
		var y := inner.end.y - (11.0 if health >= 0.0 else 4.0)
		if pill_badge:  # tiny buttons: a little pill on the top-right corner
			var font := get_theme_default_font()
			var w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_size).x + 6.0
			var pill := Rect2(Vector2(size.x - w + 3.0, -5.0), Vector2(w, 14.0))
			c.draw_rect(pill, Color(0.75, 0.15, 0.15))
			_text(c, badge, Vector2(pill.end.x - 3.0, pill.end.y - 3.0), badge_size, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			_text(c, badge, Vector2(inner.end.x - 1, y + 2), badge_size, badge_color, HORIZONTAL_ALIGNMENT_RIGHT)


## The cooldown wedge, clipped to the box (the wedge's far points lie outside it).
func _draw_clipped(c: CanvasItem, points: PackedVector2Array, clip: Rect2) -> void:
	var box := PackedVector2Array([clip.position, Vector2(clip.end.x, clip.position.y), clip.end, Vector2(clip.position.x, clip.end.y)])
	for poly in Geometry2D.intersect_polygons(points, box):
		c.draw_colored_polygon(poly, SHADE)


func _text(c: CanvasItem, text: String, at: Vector2, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	c.draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.9))
	c.draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
