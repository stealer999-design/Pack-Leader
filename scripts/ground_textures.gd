class_name GroundTextures
## Ground textures for each biome, painted in code (no image files): a seamless
## 256x256 tile per style and colour, mapped by world position (triplanar), so
## neighbouring floor pieces line up. Cached, so each is made once.
##
## Styles:
##   grass     Greenmeadow: mottled grass, blades, the odd flower
##   snow      Frostfang Peaks: drifts, sparkles and cracked icy patches
##   sand      Sunscorch Dunes: wind ripples and pebbles
##   swamp     Mirewood Bog: mud, moss and dark puddles
##   graveyard Hollowmere Graveyard: dead grass, soil, leaves and bones
##   lava      Cinderpeak Caldera: black basalt with glowing cracks of lava
##   dirt      every camp: trampled ground with stones
##   flagstone every boss arena: big stone slabs
##   cobble    the village square: small cobblestones

const SIZE := 256
const TILE_UNITS := 8.0  ## World units one tile covers.

## Biome index (BiomeDB) -> the path's style.
const BIOME_STYLES := ["grass", "snow", "sand", "swamp", "graveyard", "sand", "lava", "snow"]

static var _cache := {}


## A floor material in `style`, built around `color`.
static func material(style: String, color: Color) -> StandardMaterial3D:
	var key := "%s/%s" % [style, color.to_html(false)]
	if not _cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(_paint(style, color))
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE / TILE_UNITS
		mat.roughness = 0.95
		_cache[key] = mat
	return _cache[key]


static func _paint(style: String, color: Color) -> Image:
	var canvas := Canvas.new(color.to_html().hash() + style.hash())
	match style:
		"grass":
			_grass(canvas, color)
		"snow":
			_snow(canvas, color)
		"sand":
			_sand(canvas, color)
		"swamp":
			_swamp(canvas, color)
		"graveyard":
			_graveyard(canvas, color)
		"lava":
			_lava(canvas, color)
		"flagstone":
			_stones(canvas, color, 4, 0.0, 3)
		"cobble":
			_stones(canvas, color, 8, 0.5, 2)
		_:
			_dirt(canvas, color)
	return canvas.image()


static func _grass(c: Canvas, color: Color) -> void:
	var base := Color.from_hsv(color.h, clampf(color.s * 1.7, 0.0, 0.75), clampf(color.v * 1.1, 0.0, 0.6))
	c.fill_noise(base.darkened(0.12), base.lightened(0.08), 0.015, 3)
	c.blend_noise(base.darkened(0.22), 0.05, 0.6)  # darker clumps
	for i in 2600:  # blades
		var tone := base.darkened(c.rng.randf_range(0.15, 0.4)) if c.rng.randf() < 0.55 \
				else base.lightened(c.rng.randf_range(0.15, 0.35))
		c.stroke(c.rng.randf() * SIZE, c.rng.randf() * SIZE, c.rng.randf_range(-0.5, 0.5), c.rng.randf_range(3, 7), tone)
	for i in 26:  # flowers
		var petal: Color = [Color(1, 0.92, 0.4), Color(0.98, 0.98, 0.95), Color(0.95, 0.6, 0.75)][i % 3]
		c.dot(c.rng.randf() * SIZE, c.rng.randf() * SIZE, 1.6, petal)


static func _snow(c: Canvas, color: Color) -> void:
	var base := color.lerp(Color(0.72, 0.77, 0.85), 0.6)
	c.fill_noise(base.darkened(0.16), base.lightened(0.04), 0.012, 3)  # soft drifts
	# Icy patches: where the noise is high, glassy blue with cracks.
	var ice := Color(0.45, 0.62, 0.8)
	c.blend_noise(ice, 0.01, 0.62, true)
	for i in 40:
		var x := c.rng.randf() * SIZE
		var y := c.rng.randf() * SIZE
		var angle := c.rng.randf() * TAU
		for s in 4:  # a jagged crack
			angle += c.rng.randf_range(-0.8, 0.8)
			var length := c.rng.randf_range(4, 10)
			c.line(x, y, x + cos(angle) * length, y + sin(angle) * length, ice.darkened(0.25), 0.5)
			x += cos(angle) * length
			y += sin(angle) * length
	for i in 350:  # sparkles
		c.dot(c.rng.randf() * SIZE, c.rng.randf() * SIZE, 0.6, Color(0.95, 0.97, 1.0))


static func _sand(c: Canvas, color: Color) -> void:
	var base := color.lightened(0.18)
	c.fill_noise(base.darkened(0.08), base.lightened(0.08), 0.02, 2)
	# Wind ripples: wavy bands (whole periods across the tile, so it wraps).
	var warp := c.noise(0.02, 2)
	for y in SIZE:
		for x in SIZE:
			var wobble := warp[y * SIZE + x] / 255.0 * 4.0
			var band := sin((y + x * 0.25 + wobble * 6.0) / SIZE * TAU * 12.0)
			if band > 0.7:
				c.mix(x, y, base.darkened(0.2), (band - 0.7) * 1.6)
			elif band < -0.85:
				c.mix(x, y, base.lightened(0.15), 0.4)
	for i in 160:  # pebbles
		c.dot(c.rng.randf() * SIZE, c.rng.randf() * SIZE, c.rng.randf_range(0.8, 1.8), base.darkened(c.rng.randf_range(0.25, 0.45)))


static func _swamp(c: Canvas, color: Color) -> void:
	var mud := color.lerp(Color(0.3, 0.24, 0.15), 0.35)
	c.fill_noise(mud.darkened(0.14), mud.lightened(0.08), 0.02, 3)
	c.blend_noise(Color.from_hsv(0.25, 0.45, 0.34), 0.07, 0.6)  # moss tufts
	c.blend_noise(Color(0.22, 0.3, 0.25), 0.016, 0.7)  # puddle rims
	c.blend_noise(Color(0.12, 0.2, 0.19), 0.016, 0.74, true)  # puddles
	for i in 900:  # moss specks and reeds
		var tone := Color.from_hsv(0.24, 0.55, c.rng.randf_range(0.3, 0.5))
		if c.rng.randf() < 0.3:
			c.stroke(c.rng.randf() * SIZE, c.rng.randf() * SIZE, c.rng.randf_range(-0.3, 0.3), c.rng.randf_range(3, 6), tone)
		else:
			c.dot(c.rng.randf() * SIZE, c.rng.randf() * SIZE, 0.9, tone)


## Dead, grey-green grass worn through to dark grave soil, strewn with dry
## leaves, twigs and the odd fragment of bone.
static func _graveyard(c: Canvas, color: Color) -> void:
	var grass := color.lerp(Color(0.32, 0.33, 0.27), 0.5)
	c.fill_noise(grass.darkened(0.2), grass.lightened(0.05), 0.02, 3)
	var soil := Color(0.2, 0.17, 0.15)
	c.blend_noise(soil, 0.012, 0.6)  # bare earth
	c.blend_noise(soil.darkened(0.25), 0.012, 0.68)
	for i in 1100:  # dead grass
		var tone := Color.from_hsv(c.rng.randf_range(0.12, 0.2), 0.25, c.rng.randf_range(0.28, 0.45))
		c.stroke(c.rng.randf() * SIZE, c.rng.randf() * SIZE, c.rng.randf_range(-0.35, 0.35), c.rng.randf_range(2, 5), tone)
	for i in 160:  # fallen leaves
		var leaf := Color.from_hsv(c.rng.randf_range(0.04, 0.1), 0.55, c.rng.randf_range(0.3, 0.5))
		c.dot(c.rng.randf() * SIZE, c.rng.randf() * SIZE, c.rng.randf_range(0.9, 1.6), leaf)
	for i in 30:  # twigs
		var x := c.rng.randf() * SIZE
		var y := c.rng.randf() * SIZE
		var angle := c.rng.randf() * TAU
		var length := c.rng.randf_range(4, 9)
		c.line(x, y, x + cos(angle) * length, y + sin(angle) * length, Color(0.16, 0.12, 0.1), 0.6)
	for i in 22:  # bits of bone
		var x := c.rng.randf() * SIZE
		var y := c.rng.randf() * SIZE
		var angle := c.rng.randf() * TAU
		var bone := Color(0.82, 0.8, 0.72)
		c.line(x, y, x + cos(angle) * 4.0, y + sin(angle) * 4.0, bone, 0.7)
		c.dot(x, y, 1.0, bone)
		c.dot(x + cos(angle) * 4.0, y + sin(angle) * 4.0, 1.0, bone)


## Black basalt, ash and cinders, split by glowing cracks of lava (each crack
## a jagged line with a hot core and a red glow around it).
static func _lava(c: Canvas, color: Color) -> void:
	var rock := color.lerp(Color(0.13, 0.11, 0.11), 0.5)
	c.fill_noise(rock.darkened(0.3), rock.lightened(0.06), 0.02, 3)
	c.blend_noise(Color(0.3, 0.28, 0.27), 0.03, 0.66)  # ash drifts
	c.blend_noise(Color(0.35, 0.08, 0.03), 0.012, 0.72)  # heat glowing under the rock
	var glow := Color(0.85, 0.2, 0.04)
	var hot := Color(1.0, 0.62, 0.15)
	for i in 26:
		var x := c.rng.randf() * SIZE
		var y := c.rng.randf() * SIZE
		var angle := c.rng.randf() * TAU
		for s in 6:  # a jagged crack
			angle += c.rng.randf_range(-0.7, 0.7)
			var length := c.rng.randf_range(5, 14)
			var x1 := x + cos(angle) * length
			var y1 := y + sin(angle) * length
			for w in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
				c.line(x + w.x, y + w.y, x1 + w.x, y1 + w.y, glow, 0.45)
			c.line(x, y, x1, y1, hot, 0.95)
			x = x1
			y = y1
	for i in 140:  # cinders
		c.dot(c.rng.randf() * SIZE, c.rng.randf() * SIZE, c.rng.randf_range(0.5, 1.0), hot if c.rng.randf() < 0.3 else Color(0.06, 0.05, 0.05))


static func _dirt(c: Canvas, color: Color) -> void:
	c.fill_noise(color.darkened(0.1), color.lightened(0.06), 0.015, 3)
	c.blend_noise(color.darkened(0.16), 0.03, 0.58)
	for i in 220:  # stones
		var r := c.rng.randf_range(0.8, 2.0)
		var x := c.rng.randf() * SIZE
		var y := c.rng.randf() * SIZE
		c.dot(x, y, r, color.lightened(c.rng.randf_range(0.1, 0.3)))
		c.dot(x + r * 0.3, y + r * 0.4, r * 0.5, color.darkened(0.1))


## Stone slabs (`per_row` across the tile, a power of two so they tile) with
## dark mortar; `offset` shifts every other row (0.5 = brickwork); `mortar` is
## the gap in pixels.
static func _stones(c: Canvas, color: Color, per_row: int, offset: float, mortar: int) -> void:
	var cell := SIZE / per_row
	var tones := []
	for i in per_row * per_row:
		var shade := c.rng.randf_range(-0.1, 0.08)
		tones.append(color.lightened(shade) if shade > 0.0 else color.darkened(-shade))
	var grain := c.noise(0.06, 2)
	for y in SIZE:
		var row := y / cell
		var shift := int(cell * offset) if row % 2 == 1 else 0
		for x in SIZE:
			var sx := posmod(x + shift, SIZE)
			var col := sx / cell
			var inner_x := sx % cell
			var inner_y := y % cell
			var edge := mini(mini(inner_x, cell - 1 - inner_x), mini(inner_y, cell - 1 - inner_y))
			var g := grain[y * SIZE + x] / 255.0
			if edge < mortar:
				c.set_px(x, y, color.darkened(0.42))
			else:
				var tone: Color = tones[row * per_row + col]
				tone = tone.darkened(0.12 * (1.0 - clampf(edge / 4.0, 0.0, 1.0)))  # rounded edges
				c.set_px(x, y, tone.lerp(tone.darkened(0.15), g * 0.6))


## A wrapping RGB pixel buffer with a few painting tools.
class Canvas:
	var rng := RandomNumberGenerator.new()
	var _seed := 0
	var _data := PackedByteArray()

	func _init(seed_value: int) -> void:
		_seed = seed_value
		rng.seed = seed_value
		_data.resize(SIZE * SIZE * 3)

	func image() -> Image:
		var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, _data)
		img.generate_mipmaps()
		return img

	## Seamless noise, 0..255 per pixel.
	func noise(frequency: float, octaves: int) -> PackedByteArray:
		var fast := FastNoiseLite.new()
		fast.seed = _seed + rng.randi() % 1000
		fast.frequency = frequency
		fast.fractal_octaves = octaves
		var img := fast.get_seamless_image(SIZE, SIZE)
		img.convert(Image.FORMAT_L8)
		return img.get_data()

	func fill_noise(dark: Color, light: Color, frequency: float, octaves: int) -> void:
		var n := noise(frequency, octaves)
		for i in SIZE * SIZE:
			var col := dark.lerp(light, n[i] / 255.0)
			_data[i * 3] = int(col.r8)
			_data[i * 3 + 1] = int(col.g8)
			_data[i * 3 + 2] = int(col.b8)

	## Mixes `color` in where the noise is above `threshold` (softly; `hard` for crisp edges).
	func blend_noise(color: Color, frequency: float, threshold: float, hard := false) -> void:
		var n := noise(frequency, 3)
		for i in SIZE * SIZE:
			var v := n[i] / 255.0
			if v > threshold:
				var amount := 1.0 if hard and v > threshold + 0.03 else clampf((v - threshold) * 6.0, 0.0, 0.9)
				_mix_index(i, color, amount)

	func set_px(x: int, y: int, color: Color) -> void:
		var i := (posmod(y, SIZE) * SIZE + posmod(x, SIZE)) * 3
		_data[i] = int(color.r8)
		_data[i + 1] = int(color.g8)
		_data[i + 2] = int(color.b8)

	func mix(x: int, y: int, color: Color, amount: float) -> void:
		_mix_index(posmod(y, SIZE) * SIZE + posmod(x, SIZE), color, amount)

	func _mix_index(i: int, color: Color, amount: float) -> void:
		amount = clampf(amount, 0.0, 1.0)
		_data[i * 3] = int(lerpf(_data[i * 3], color.r8, amount))
		_data[i * 3 + 1] = int(lerpf(_data[i * 3 + 1], color.g8, amount))
		_data[i * 3 + 2] = int(lerpf(_data[i * 3 + 2], color.b8, amount))

	func dot(x: float, y: float, r: float, color: Color) -> void:
		for dy in range(-ceili(r), ceili(r) + 1):
			for dx in range(-ceili(r), ceili(r) + 1):
				var d := sqrt(dx * dx + dy * dy)
				if d <= r + 0.5:
					mix(int(x) + dx, int(y) + dy, color, clampf(r + 0.5 - d, 0.0, 1.0))

	## A short blade-like stroke, mostly upwards, leaning by `lean`.
	func stroke(x: float, y: float, lean: float, length: float, color: Color) -> void:
		for s in int(length):
			mix(int(x + lean * s), int(y - s), color, 0.85 * (1.0 - float(s) / length * 0.5))

	func line(x0: float, y0: float, x1: float, y1: float, color: Color, amount: float) -> void:
		var steps := int(maxf(absf(x1 - x0), absf(y1 - y0))) + 1
		for s in steps:
			var t := float(s) / steps
			mix(int(lerpf(x0, x1, t)), int(lerpf(y0, y1, t)), color, amount)
