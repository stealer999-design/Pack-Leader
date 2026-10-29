class_name MiniMap
extends PanelContainer
## The mini map, bottom right: the path around you, oriented like the camera
## (the level runs left to right). Press M to switch to the whole level, large.
##
## Shows the path and rocks, the stable, the lemonade stand, the portal, crates,
## the boss, wild creatures (red), your pets (green), other players and their
## pets (in their colours) and you (an arrow pointing where you aim).
## Everything is drawn from the level layout and the live nodes on this peer.

const COMPACT_SIZE := Vector2(300, 180)
const COMPACT_SCALE := 4.0  ## Pixels per world unit in the corner map.
const REDRAW_INTERVAL := 0.066

var player: Player
var expanded := false

var _canvas: Control
var _style: StyleBoxFlat
var _legend: Label
var _redraw_timer := 0.0
## Level-space -> map-space: map x = how far along the path, map y = across it.
var _scale := COMPACT_SCALE
var _origin := Vector2.ZERO  ## The map-space point at the centre of the canvas.


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_style = StyleBoxFlat.new()
	var style := _style
	style.border_color = Color(0.62, 0.45, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.clip_contents = true
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_draw_map)
	box.add_child(_canvas)
	_legend = Label.new()
	_legend.add_theme_font_size_override("font_size", 13)
	box.add_child(_legend)
	_apply_mode()


func toggle_expanded() -> void:
	expanded = not expanded
	_apply_mode()


func _apply_mode() -> void:
	if expanded:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Clear of the party panel (left) and the messages (top right).
		offset_left = 300
		offset_right = -30
		offset_top = 230
		offset_bottom = -100
		_legend.text = "You (arrow)  ·  your pets: green  ·  wild: red  ·  boss: big red  ·  stand: yellow  ·  bat shop: red  ·  stable: brown  ·  portal: purple       [M] close"
	else:
		set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		offset_left = -20 - COMPACT_SIZE.x
		offset_top = -56 - COMPACT_SIZE.y
		offset_right = -20
		offset_bottom = -56
		_legend.text = "[M] map"
	_style.bg_color = Color(0.05, 0.06, 0.08, 0.95 if expanded else 0.85)
	_legend.modulate = Color(1, 1, 1, 0.6)
	_canvas.queue_redraw()


func _process(delta: float) -> void:
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		_canvas.queue_redraw()


func _world() -> World:
	return player.world if is_instance_valid(player) else null


## A point in level space (from World.level_root) in map space.
static func _to_map(local: Vector3) -> Vector2:
	return Vector2(-local.z, local.x)


func _to_canvas(map_point: Vector2) -> Vector2:
	return _canvas.size * 0.5 + (map_point - _origin) * _scale


func _node_pos(world: World, node: Node3D) -> Vector2:
	return _to_canvas(_to_map(world.level_root.to_local(node.global_position)))


func _draw_map() -> void:
	var world := _world()
	if world == null or world.layout.is_empty():
		return
	var layout := world.layout
	var segments: Array = layout.segments
	# Fit the view: the whole level, or a window centred on the player.
	if expanded:
		var bounds := Rect2(_to_map(Vector3(segments[0].center_x, 0, segments[0].z_start)), Vector2.ZERO)
		for seg in segments:
			bounds = bounds.merge(_segment_rect(seg))
		if layout.has("village"):
			var plaza: Rect2 = layout.village.plaza
			bounds = bounds.expand(_to_map(Vector3(plaza.position.x - 1.0, 0, plaza.position.y)))
		_scale = minf(_canvas.size.x / bounds.size.x, _canvas.size.y / bounds.size.y) * 0.96
		_origin = bounds.get_center()
	else:
		_scale = COMPACT_SCALE
		_origin = _to_map(world.level_root.to_local(player.global_position))

	var biome := world.biome()
	var floor_color: Color = layout.floor_tint
	for seg in segments:
		var color := floor_color
		if seg.kind == "start":
			color = biome.camp
		elif seg.kind == "arena":
			color = biome.arena
		_draw_rect_map(_segment_rect(seg), color.darkened(0.15))
	if layout.has("village"):
		var v: Dictionary = layout.village
		var half := LevelGenerator.VILLAGE_PATH_WIDTH * 0.5
		var path_a := _to_map(Vector3(v.wall_x + 0.5, 0, v.z - half))
		var path_b := _to_map(Vector3(v.path_end_x, 0, v.z + half))
		_draw_rect_map(Rect2(path_a, Vector2.ZERO).expand(path_b), floor_color.darkened(0.15))
		var plaza: Rect2 = v.plaza
		var plaza_a := _to_map(Vector3(plaza.position.x, 0, plaza.position.y))
		var plaza_b := _to_map(Vector3(plaza.end.x, 0, plaza.end.y))
		_draw_rect_map(Rect2(plaza_a, Vector2.ZERO).expand(plaza_b), Color(biome.camp).lerp(Color(0.62, 0.58, 0.52), 0.6).darkened(0.15))
		for house in v.houses:
			var size: Vector3 = house.size
			var center := _to_map(house.pos)
			var half_size := Vector2(size.z, size.x) * 0.5
			_draw_rect_map(Rect2(center - half_size, half_size * 2.0), Color(0.62, 0.25, 0.2))
	for rock in layout.rocks:
		var size: Vector3 = rock.size
		var center := _to_map(rock.pos)
		var half := Vector2(size.z, size.x) * 0.5
		_draw_rect_map(Rect2(center - half, half * 2.0), Color(biome.rock).darkened(0.35))

	# Landmarks.
	_draw_stable(_to_canvas(_to_map(layout.stable_point)))
	if layout.has("village"):
		_draw_stable(_to_canvas(_to_map(layout.village.stable_point)))
	var shop_at := _to_canvas(_to_map(layout.shop_point))
	_canvas.draw_circle(shop_at, 6.5, Color(0.2, 0.15, 0.05))
	_canvas.draw_circle(shop_at, 5.0, Color(1.0, 0.88, 0.2))
	if layout.has("village"):
		var bat_at := _to_canvas(_to_map(layout.village.bat_shop_point))
		_canvas.draw_circle(bat_at, 6.5, Color(0.2, 0.05, 0.05))
		_canvas.draw_circle(bat_at, 5.0, Color(0.95, 0.35, 0.3))
		_canvas.draw_line(bat_at + Vector2(-3, 3), bat_at + Vector2(3, -3), Color(0.4, 0.25, 0.12), 2.5)  # a bat
	var portal_at := _to_canvas(_to_map(layout.exit_point))
	_canvas.draw_arc(portal_at, 7.0, 0, TAU, 20, Color(0.75, 0.45, 1.0), 2.5)
	if world.exit_open:
		_canvas.draw_circle(portal_at, 4.5, Color(0.85, 0.6, 1.0))
	for crate: Crate in world.crates_root.get_children():
		var at := _node_pos(world, crate)
		_canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)),
				Color(1.0, 0.8, 0.2) if crate.gold else Color(0.65, 0.45, 0.25))

	# Creatures, the boss and players.
	for c: Creature in world.get_tree().get_nodes_in_group("creatures"):
		if not is_instance_valid(c) or c.is_queued_for_deletion():
			continue
		var color := Color(0.95, 0.3, 0.25)
		var radius := 2.5
		if c.owner_id == player.peer_id:
			color = Color(0.35, 1.0, 0.45)
			radius = 3.5
		elif c.is_player_pet():
			var owner_player := world.get_player(c.owner_id)
			color = owner_player.color.lightened(0.3) if owner_player else Color.WHITE
			radius = 3.0
		elif c.is_rival_pet():
			color = Color(0.75, 0.1, 0.15)
			radius = 3.5
		if c.fainted:
			color = color.darkened(0.5)
		_canvas.draw_circle(_node_pos(world, c), radius, color)
	var rival := world.get_rival()
	if rival and not rival.health.is_dead():
		var at := _node_pos(world, rival)
		_canvas.draw_circle(at, 7.0, Color(0.1, 0.0, 0.0))
		_canvas.draw_circle(at, 5.5, Color(1.0, 0.2, 0.15))
	for p: Player in world.get_players():
		if p != player:
			var at := _node_pos(world, p)
			_canvas.draw_circle(at, 5.0, Color.WHITE)
			_canvas.draw_circle(at, 3.8, p.color)
	_draw_self(world)


func _draw_self(world: World) -> void:
	var at := _node_pos(world, player)
	var facing := -player.model.global_basis.z
	var local := world.level_root.global_basis.inverse() * facing
	var dir := _to_map(local).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var side := dir.orthogonal()
	var arrow := PackedVector2Array([at + dir * 9.0, at - dir * 5.0 + side * 6.0, at - dir * 2.0, at - dir * 5.0 - side * 6.0])
	_canvas.draw_colored_polygon(arrow, Color(0.05, 0.05, 0.05))
	var inner := PackedVector2Array()
	for point in arrow:
		inner.append(at + (point - at) * 0.72)
	_canvas.draw_colored_polygon(inner, player.color.lightened(0.25))


## A little barn: brown with a red roof.
func _draw_stable(at: Vector2) -> void:
	_canvas.draw_rect(Rect2(at - Vector2(6, 3), Vector2(12, 9)), Color(0.6, 0.38, 0.2))
	_canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-8, -3), at + Vector2(8, -3), at + Vector2(0, -10)]),
			Color(0.85, 0.3, 0.25))


func _segment_rect(seg: Dictionary) -> Rect2:
	var a := _to_map(Vector3(seg.center_x - seg.width * 0.5, 0, seg.z_start))
	var b := _to_map(Vector3(seg.center_x + seg.width * 0.5, 0, seg.z_end))
	return Rect2(a, Vector2.ZERO).expand(b)


func _draw_rect_map(rect: Rect2, color: Color) -> void:
	var a := _to_canvas(rect.position)
	var b := _to_canvas(rect.end)
	_canvas.draw_rect(Rect2(a, b - a).abs(), color)
