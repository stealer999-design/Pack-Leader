class_name SkillIcons
## Skill icons, drawn in code onto any CanvasItem: claw marks for attack damage,
## a heart for max health, a shield for armor, a star for spell power, a clock
## for cooldowns, a cross for healing, a crosshair for crit chance, a burst for
## crit damage, chevrons for attack speed, a droplet for poison, an hourglass
## for poison duration and a spiked droplet for toxic blood. Pack skills
## (which boost the whole party) get a gold paw-print badge.


static func color_for(stat: String) -> Color:
	match stat.trim_prefix("pack_"):
		"damage":
			return Color(1.0, 0.45, 0.3)
		"health":
			return Color(0.4, 0.9, 0.45)
		"spell_power":
			return Color(0.75, 0.5, 1.0)
		"cooldown":
			return Color(0.5, 0.85, 1.0)
		"heal_power":
			return Color(1.0, 0.88, 0.45)
		"crit_chance", "crit_damage":
			return Color(1.0, 0.7, 0.2)
		"attack_speed":
			return Color(0.6, 1.0, 0.85)
		"dot_power", "dot_duration", "toxic_blood":
			return Color(0.55, 0.95, 0.3)
		_:
			return Color(0.45, 0.7, 1.0)


## Draws the icon for `stat` centred on `center`, about `r` in radius.
static func draw_icon(canvas: CanvasItem, stat: String, center: Vector2, r: float, color: Color) -> void:
	match stat.trim_prefix("pack_"):
		"damage":
			_claws(canvas, center, r, color)
		"health":
			_heart(canvas, center, r, color)
		"spell_power":
			_star(canvas, center, r, color, 5, 0.42)
		"cooldown":
			_clock(canvas, center, r, color)
		"heal_power":
			_cross(canvas, center, r, color)
		"crit_chance":
			_crosshair(canvas, center, r, color)
		"crit_damage":
			_star(canvas, center, r, color, 8, 0.5)
		"attack_speed":
			_chevrons(canvas, center, r, color)
		"dot_power":
			_drop(canvas, center, r, color)
		"dot_duration":
			_hourglass(canvas, center, r, color)
		"toxic_blood":
			_drop(canvas, center, r * 0.8, color)
			for i in 6:
				var a := TAU * i / 6.0
				canvas.draw_line(center + Vector2.from_angle(a) * r * 0.75, center + Vector2.from_angle(a) * r * 1.05, color, 2.0)
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


static func _star(canvas: CanvasItem, c: Vector2, r: float, color: Color, points: int, inner: float) -> void:
	var poly := PackedVector2Array()
	for i in points * 2:
		var a := -PI / 2.0 + PI * i / points
		poly.append(c + Vector2.from_angle(a) * r * (1.0 if i % 2 == 0 else inner))
	canvas.draw_colored_polygon(poly, color)


static func _clock(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	canvas.draw_arc(c, r * 0.85, 0, TAU, 24, color, maxf(r * 0.18, 2.0))
	canvas.draw_line(c, c + Vector2(0, -r * 0.6), color, maxf(r * 0.15, 2.0))
	canvas.draw_line(c, c + Vector2(r * 0.45, 0), color, maxf(r * 0.15, 2.0))


static func _cross(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-r * 0.28, -r * 0.9), Vector2(r * 0.56, r * 1.8)), color)
	canvas.draw_rect(Rect2(c + Vector2(-r * 0.9, -r * 0.28), Vector2(r * 1.8, r * 0.56)), color)


static func _crosshair(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var w := maxf(r * 0.15, 2.0)
	canvas.draw_arc(c, r * 0.65, 0, TAU, 24, color, w)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		canvas.draw_line(c + d * r * 0.35, c + d * r * 1.0, color, w)
	canvas.draw_circle(c, r * 0.14, color)


static func _chevrons(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	for i in 3:
		var x := (i - 1) * r * 0.55
		canvas.draw_polyline(PackedVector2Array([c + Vector2(x - r * 0.3, -r * 0.7), c + Vector2(x + r * 0.2, 0),
				c + Vector2(x - r * 0.3, r * 0.7)]), color, maxf(r * 0.2, 2.0))


static func _drop(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	canvas.draw_circle(c + Vector2(0, r * 0.3), r * 0.6, color)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, r * 0.15), c + Vector2(0, -r * 1.0),
			c + Vector2(r * 0.55, r * 0.15)]), color)


static func _hourglass(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.9), c + Vector2(r * 0.7, -r * 0.9), c]), color)
	canvas.draw_colored_polygon(PackedVector2Array([c, c + Vector2(r * 0.7, r * 0.9), c + Vector2(-r * 0.7, r * 0.9)]), color)
	canvas.draw_line(c + Vector2(-r * 0.85, -r * 0.95), c + Vector2(r * 0.85, -r * 0.95), color, 2.0)
	canvas.draw_line(c + Vector2(-r * 0.85, r * 0.95), c + Vector2(r * 0.85, r * 0.95), color, 2.0)
