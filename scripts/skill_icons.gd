class_name SkillIcons
## Skill icons, drawn in code onto any CanvasItem: claw marks for attack damage,
## a heart for max health, a shield for armor. Pack skills (which boost the
## whole party) get a gold paw-print badge.


static func color_for(stat: String) -> Color:
	match stat.trim_prefix("pack_"):
		"damage":
			return Color(1.0, 0.45, 0.3)
		"health":
			return Color(0.4, 0.9, 0.45)
		_:
			return Color(0.45, 0.7, 1.0)


## Draws the icon for `stat` centred on `center`, about `r` in radius.
static func draw_icon(canvas: CanvasItem, stat: String, center: Vector2, r: float, color: Color) -> void:
	match stat.trim_prefix("pack_"):
		"damage":
			_claws(canvas, center, r, color)
		"health":
			_heart(canvas, center, r, color)
		_:
			_shield(canvas, center, r, color)
	if stat.begins_with("pack_"):
		draw_paw(canvas, center + Vector2(-r * 0.95, r * 0.85), r * 0.42, Color(1.0, 0.85, 0.4, color.a))


static func draw_paw(canvas: CanvasItem, center: Vector2, r: float, color: Color) -> void:
	canvas.draw_circle(center, r * 1.15, Color(0.1, 0.08, 0.05, color.a * 0.9))
	canvas.draw_circle(center + Vector2(0, r * 0.3), r * 0.5, color)
	for i in 4:
		var angle := lerpf(-2.4, -0.75, i / 3.0)
		canvas.draw_circle(center + Vector2.from_angle(angle) * r * 0.62 + Vector2(0, r * 0.15), r * 0.22, color)


static func draw_lock(canvas: CanvasItem, center: Vector2, r: float) -> void:
	canvas.draw_circle(center, r * 1.3, Color(0.1, 0.1, 0.12, 0.95))
	canvas.draw_arc(center + Vector2(0, -r * 0.2), r * 0.45, PI, TAU, 12, Color(0.85, 0.85, 0.9), 2.5)
	canvas.draw_rect(Rect2(center + Vector2(-r * 0.6, -r * 0.2), Vector2(r * 1.2, r * 0.9)), Color(0.85, 0.85, 0.9))


static func _claws(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	for i in 3:
		var x := (i - 1) * r * 0.55
		var top := c + Vector2(x + r * 0.35, -r)
		var bottom := c + Vector2(x - r * 0.35, r)
		var side := (bottom - top).orthogonal().normalized() * r * 0.13
		# A slash: wide in the middle, sharp at both ends.
		var mid := (top + bottom) * 0.5
		canvas.draw_colored_polygon(PackedVector2Array([top, mid + side, bottom, mid - side]), color)


static func _heart(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var lobe := r * 0.5
	canvas.draw_circle(c + Vector2(-lobe, -r * 0.3), lobe, color)
	canvas.draw_circle(c + Vector2(lobe, -r * 0.3), lobe, color)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.97, -r * 0.15), c + Vector2(r * 0.97, -r * 0.15), c + Vector2(0, r * 0.95),
	]), color)
	canvas.draw_circle(c + Vector2(-lobe * 1.2, -r * 0.5), lobe * 0.3, Color(1, 1, 1, 0.35 * color.a))  # shine


static func _shield(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array([
		c + Vector2(-r * 0.85, -r * 0.8), c + Vector2(0, -r * 1.0), c + Vector2(r * 0.85, -r * 0.8),
		c + Vector2(r * 0.75, r * 0.15), c + Vector2(0, r * 1.0), c + Vector2(-r * 0.75, r * 0.15),
	])
	canvas.draw_colored_polygon(points, color)
	var inner := PackedVector2Array()
	for p in points:
		inner.append(c + (p - c) * 0.55)
	canvas.draw_colored_polygon(inner, color.lightened(0.35))
