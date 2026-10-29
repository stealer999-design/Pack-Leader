class_name BuildingTextures
## Textures for the buildings (village houses, both stables and the market
## stalls), painted in code like GroundTextures and shared by every building:
## one for roofs (clay shingles), one for walls (plaster with a few stones
## showing) and one for doors and woodwork (planks). Mapped by world position.

const SIZE := GroundTextures.SIZE

static var _cache := {}


static func roof() -> StandardMaterial3D:
	return _material("roof", 3.0)


static func wall() -> StandardMaterial3D:
	return _material("wall", 4.0)


static func door() -> StandardMaterial3D:
	return _material("door", 1.5)


static func _material(style: String, tile_units: float) -> StandardMaterial3D:
	if not _cache.has(style):
		var canvas := GroundTextures.Canvas.new(style.hash())
		match style:
			"roof":
				_shingles(canvas)
			"wall":
				_plaster(canvas)
			_:
				_planks(canvas)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(canvas.image())
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE / tile_units
		mat.roughness = 0.9
		_cache[style] = mat
	return _cache[style]


## Overlapping clay shingles in staggered rows, each darker at its lower edge.
static func _shingles(c: GroundTextures.Canvas) -> void:
	var clay := Color(0.62, 0.26, 0.2)
	var rows := 16
	var row_h := SIZE / rows
	var per_row := 8
	var w := SIZE / per_row
	var grain := c.noise(0.05, 2)
	var tones := []
	for i in rows * per_row:
		var shade := c.rng.randf_range(-0.1, 0.1)
		tones.append(clay.lightened(shade) if shade > 0.0 else clay.darkened(-shade))
	for y in SIZE:
		var row := y / row_h
		var shift := w / 2 if row % 2 == 1 else 0
		var inner_y := y % row_h
		for x in SIZE:
			var sx := posmod(x + shift, SIZE)
			var col := sx / w
			var inner_x := sx % w
			var tone: Color = tones[row * per_row + col]
			tone = tone.darkened(0.35 * pow(float(inner_y) / row_h, 3.0))  # shadow under the next row
			if inner_x == 0:
				tone = tone.darkened(0.35)  # the gap between shingles
			c.set_px(x, y, tone.lerp(tone.darkened(0.15), grain[y * SIZE + x] / 255.0 * 0.6))


## Warm plaster, softly mottled, with the odd stone showing through.
static func _plaster(c: GroundTextures.Canvas) -> void:
	var plaster := Color(0.76, 0.68, 0.56)  # the sun brightens it a lot
	c.fill_noise(plaster.darkened(0.14), plaster.lightened(0.03), 0.02, 3)
	c.blend_noise(plaster.darkened(0.22), 0.04, 0.6)  # weathering
	for i in 30:  # bare stones
		var x := c.rng.randf() * SIZE
		var y := c.rng.randf() * SIZE
		for s in 3:
			var sx := x + c.rng.randf_range(-10, 10)
			var sy := y + c.rng.randf_range(-6, 6)
			var r := c.rng.randf_range(3, 5)
			c.dot(sx, sy, r + 1.0, plaster.darkened(0.4))
			c.dot(sx, sy, r, Color(0.56, 0.5, 0.45).lightened(c.rng.randf_range(-0.05, 0.1)))


## Vertical boards with dark gaps, wood grain and a few knots.
static func _planks(c: GroundTextures.Canvas) -> void:
	var wood := Color(0.48, 0.31, 0.18)
	var boards := 8
	var board_w := SIZE / boards
	var tones := []
	for i in boards:
		var shade := c.rng.randf_range(-0.08, 0.1)
		tones.append(wood.lightened(shade) if shade > 0.0 else wood.darkened(-shade))
	var fast := FastNoiseLite.new()
	fast.seed = 77
	fast.frequency = 0.08
	for y in SIZE:
		for x in SIZE:
			var board := x / board_w
			var inner := x % board_w
			var tone: Color = tones[board]
			if inner < 2:
				c.set_px(x, y, wood.darkened(0.55))
				continue
			# Grain: noise stretched along the board (it wraps every board height).
			var grain := fast.get_noise_2d(x * 3.0, sin(y * TAU / SIZE) * 6.0 + cos(y * TAU / SIZE) * 6.0)
			c.set_px(x, y, tone.lerp(tone.darkened(0.25), clampf(grain * 0.8 + 0.4, 0.0, 1.0)))
	for i in 10:  # knots
		var x := c.rng.randf() * SIZE
		var y := c.rng.randf() * SIZE
		c.dot(x, y, 2.5, wood.darkened(0.45))
		c.dot(x, y, 1.2, wood.darkened(0.25))
