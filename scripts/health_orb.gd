class_name HealthOrb
extends Control
## The tamer's health on the action bar: a glass ball of red liquid that
## drains from the top as you get hurt, with a shine across it and the
## numbers in the middle. It is drawn a little taller than its box, so it
## rises out of the top of the bar.

## The ball's diameter.
var diameter := 80.0
var current := 100.0
var maximum := 100.0

const FILL := Color(0.78, 0.08, 0.1)
const FILL_TOP := Color(1.0, 0.3, 0.25)
const EMPTY := Color(0.07, 0.04, 0.05)
const RIM := Color(0.86, 0.72, 0.48)


func _init(ball_diameter := 80.0, box_height := 60.0) -> void:
	diameter = ball_diameter
	custom_minimum_size = Vector2(ball_diameter, box_height)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Your health. You regenerate after 5 seconds without taking damage."


func set_health(value: float, max_value: float) -> void:
	if is_equal_approx(value, current) and is_equal_approx(max_value, maximum):
		return
	current = value
	maximum = max_value
	queue_redraw()


func _draw() -> void:
	var r := diameter * 0.5
	var center := Vector2(size.x * 0.5, size.y - r)  # sits on the bottom, rises above the top
	var circle := _circle(center, r - 3.0, 48)
	draw_circle(center, r, Color(0, 0, 0, 0.6))  # shadow ring
	draw_colored_polygon(circle, EMPTY)
	# The liquid: the circle clipped below the level.
	var fraction := clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	if fraction > 0.0:
		var level_y := center.y + (r - 3.0) - (r - 3.0) * 2.0 * fraction
		var below := PackedVector2Array([Vector2(center.x - r, level_y), Vector2(center.x + r, level_y),
				Vector2(center.x + r, center.y + r), Vector2(center.x - r, center.y + r)])
		for poly in Geometry2D.intersect_polygons(circle, below):
			draw_colored_polygon(poly, FILL)
		# A lighter band at the surface.
		var band := PackedVector2Array([Vector2(center.x - r, level_y), Vector2(center.x + r, level_y),
				Vector2(center.x + r, level_y + 4.0), Vector2(center.x - r, level_y + 4.0)])
		for poly in Geometry2D.intersect_polygons(circle, band):
			draw_colored_polygon(poly, FILL_TOP)
	# Glass shine: a soft highlight up and to the left.
	draw_set_transform(center + Vector2(-r * 0.32, -r * 0.42), -0.5, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, r * 0.32, Color(1, 1, 1, 0.16))
	draw_set_transform(Vector2.ZERO)
	draw_arc(center, r - 1.5, 0.0, TAU, 48, RIM, 3.0, true)
	draw_arc(center, r - 4.0, 0.0, TAU, 48, Color(0, 0, 0, 0.6), 1.5, true)
	# The numbers.
	var font := get_theme_default_font()
	var text := "%d / %d" % [ceili(maxf(current, 0.0)), roundi(maximum)]
	var font_size := 14
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(center.x - w * 0.5, center.y + 5.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _circle(center: Vector2, radius: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := TAU * i / steps
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _has_point(point: Vector2) -> bool:
	var r := diameter * 0.5
	return point.distance_to(Vector2(size.x * 0.5, size.y - r)) <= r
