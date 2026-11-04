class_name UiIcons
## Line icons for the menus: small SVG drawings (24x24, light strokes over a
## bold black ink outline, sharp corners: an anime look) turned into textures
## at runtime and cached. Buttons tint them with the theme's icon
## colours (light on the dark panels); title icons are tinted per window.
##
##   UiIcons.texture("save")                 a texture for Button.icon / TextureRect
##   UiIcons.title(label, "stable", color)   puts an icon in front of a title label

const SIZE := 22  ## Pixels, before UI scaling.

## name -> SVG body (inside a 24x24 viewBox). Strokes are drawn 2 wide, round;
## shapes marked fill use currentColor too.
const SHAPES := {
	"play": '<path d="M7 4l12 8-12 8z" fill="#fff"/>',
	"plus": '<path d="M12 5v14M5 12h14"/>',
	"folder": '<path d="M3 6h6l2 2h10v11H3z"/>',
	"trash": '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6"/>',
	"back": '<path d="M19 12H5M11 6l-6 6 6 6"/>',
	"host": '<circle cx="12" cy="12" r="2"/><path d="M8 8a5.6 5.6 0 0 0 0 8M16 8a5.6 5.6 0 0 1 0 8M5 5a10 10 0 0 0 0 14M19 5a10 10 0 0 1 0 14"/>',
	"join": '<path d="M14 4h5v16h-5M3 12h12M11 8l4 4-4 4"/>',
	"save": '<path d="M4 3h12l4 4v14H4zM8 3v5h8V3M8 21v-7h8v7"/>',
	"home": '<path d="M3 11l9-8 9 8M5 9v12h14V9M10 21v-6h4v6"/>',
	"power": '<path d="M12 3v9M6.3 6.3a8 8 0 1 0 11.4 0"/>',
	"pause": '<path d="M8 5v14M16 5v14"/>',
	"close": '<path d="M6 6l12 12M18 6L6 18"/>',
	"potion": '<path d="M9 3h6M10 3v6l-5 9a2 2 0 0 0 2 3h10a2 2 0 0 0 2-3l-5-9V3M7 15h10"/>',
	"lemon": '<path d="M4 18c-1.5-4 .5-9 5-12s10-2.5 11-.5c1.5 4-.5 9-5 12s-9.5 3-11 .5z"/><path d="M8 15l8-8"/>',
	"stall": '<path d="M3 9l2-5h14l2 5M3 9h18M5 9v11h14V9M9 20v-5h6v5"/>',
	"bat": '<path d="M4 20l8-8"/><path d="M11 13l6.5-7.5a2.3 2.3 0 0 1 3.3 3.3L13 15z" fill="#fff"/>',
	"spikes": '<path d="M12 2v4M12 18v4M2 12h4M18 12h4M5 5l3 3M16 16l3 3M19 5l-3 3M8 16l-3 3"/><circle cx="12" cy="12" r="3"/>',
	"upgrade": '<circle cx="12" cy="12" r="9"/><path d="M12 16V8M8 12l4-4 4 4"/>',
	"heart": '<path d="M12 20s-7-4.5-9-9a4.5 4.5 0 0 1 9-3 4.5 4.5 0 0 1 9 3c-2 4.5-9 9-9 9z"/>',
	"paw": '<ellipse cx="12" cy="15.5" rx="4" ry="3.5" fill="#fff"/><circle cx="6" cy="10" r="1.8" fill="#fff"/><circle cx="9.5" cy="6" r="1.8" fill="#fff"/><circle cx="14.5" cy="6" r="1.8" fill="#fff"/><circle cx="18" cy="10" r="1.8" fill="#fff"/>',
	"stable": '<path d="M3 10l9-6 9 6v10H3zM9 20v-6h6v6M9 14l6 6M15 14l-6 6"/>',
	"gate": '<path d="M4 4v16M20 4v16M4 8h8l3 2M4 15h8l3 2M8 8v7"/>',
	"bed": '<path d="M3 18h18M5 18v-4h14v4M7 14l1-3M11 14l1-4M15 14l1-3"/>',
	"star": '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
	"reset": '<path d="M4 12a8 8 0 1 0 2.5-5.8M4 4v5h5"/>',
	"shield": '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/>',
	"sword": '<path d="M5 19L19 5M14 5h5v5M7 14l3 3M4 20l2-2"/>',
	"coin": '<circle cx="12" cy="12" r="8"/><path d="M12 8v8M9.5 10h4a1.5 1.5 0 0 1 0 3h-3a1.5 1.5 0 0 0 0 3h4"/>',
	"map": '<path d="M3 6l6-2 6 2 6-2v14l-6 2-6-2-6 2zM9 4v14M15 6v14"/>',
	"egg": '<path d="M12 3c4 0 7 6 7 11a7 7 0 0 1-14 0c0-5 3-11 7-11z"/>',
	"user": '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
	"bag": '<path d="M5 8h14v12H5zM9 8V6a3 3 0 0 1 6 0v2M5 13h14M11 13v2h2v-2"/>',
	"jacket": '<path d="M8 3l4 3 4-3 4 3-2 4v11H6V10L4 6zM12 6v15M9.5 12h1M13.5 12h1"/>',
	"pants": '<path d="M6 3h12l1 18h-5l-2-10-2 10H5zM6 6h12"/>',
	"boots": '<path d="M7 3h6v10l6 3a2 2 0 0 1 1 2v2H5V3M5 17h15M7 7h6"/>',
	"hat": '<path d="M3 17h18M6 17c0-6 2-10 6-10s6 4 6 10M9 13h6"/>',
	"ring": '<circle cx="12" cy="14" r="6"/><path d="M10 7l2-4 2 4z"/>',
	"necklace": '<path d="M5 3c0 8 3 12 7 12s7-4 7-12"/><path d="M12 15l-2 3 2 3 2-3z"/>',
	"collar": '<path d="M3 8c0-2 4-4 9-4s9 2 9 4-4 5-9 5-9-3-9-5z"/><path d="M12 13v2"/><circle cx="12" cy="18" r="2.6"/>',
	"net": '<circle cx="10" cy="9" r="6.5"/><path d="M4.5 6.5l11 5M5 12l9.5-7.5M10 2.5v13M14.6 13.6l6.4 7.4"/>',
	"levelup": '<path d="M12 3l7 8h-4v9H9v-9H5z" fill="#fff"/>',
	"skull": '<path d="M12 3a7 7 0 0 0-7 7c0 2.6 1.3 4.3 3 5.2V19h8v-3.8c1.7-.9 3-2.6 3-5.2a7 7 0 0 0-7-7z"/><circle cx="9.3" cy="10.5" r="1.6" fill="#fff"/><circle cx="14.7" cy="10.5" r="1.6" fill="#fff"/><path d="M11 19v2M13 19v2"/>',
	"flag": '<path d="M6 21V3M6 4h11l-2.5 4L17 12H6"/>',
	"warn": '<path d="M12 3l9.5 17h-19z"/><path d="M12 9v5M12 17v.5"/>',
	"down": '<path d="M12 21l7-8h-4V4H9v9H5z" fill="#fff"/>',
	"menu": '<path d="M4 6h16M4 12h16M4 18h16"/>',
	"link": '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
}

static var _cache := {}


## Draws every icon at the sizes the HUD uses, so none is drawn for the first
## time mid-play (see World._warm_up). Only does the work once.
static func preload_all() -> void:
	if _cache.size() >= SHAPES.size() * 4:
		return
	for icon_name in SHAPES:
		for icon_size in [SIZE, 24, 32, 48]:
			texture(icon_name, icon_size)


## The icon as a texture, `size` pixels square.
static func texture(icon_name: String, size := SIZE) -> Texture2D:
	var key := "%s@%d" % [icon_name, size]
	if not _cache.has(key):
		# Anime style: a bold black ink stroke under a sharp-cornered light one.
		var shape: String = SHAPES.get(icon_name, SHAPES.star)
		var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-1 -1 26 26" width="26" height="26" ' \
				+ 'fill="none" stroke-linecap="square" stroke-linejoin="miter" stroke-miterlimit="6">' \
				+ '<g stroke="#000" stroke-width="4.6">' + shape.replace('fill="#fff"', 'fill="#000"') + '</g>' \
				+ '<g stroke="#fff" stroke-width="2.3">' + shape + '</g></svg>'
		var image := Image.new()
		image.load_svg_from_string(svg, size / 26.0)
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


## Gives a button an icon (tinted by the theme, so it lights up with the text).
static func button(target: Button, icon_name: String) -> void:
	target.icon = texture(icon_name)
	target.expand_icon = false


## Puts an icon in front of a window's title label: the label moves into a
## centred row with the icon, tinted `color` (the title's colour by default).
static func title(label: Label, icon_name: String, color := Color(0, 0, 0, 0), size := 30) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = label.size_flags_horizontal
	var parent := label.get_parent()
	var at := label.get_index()
	parent.remove_child(label)
	parent.add_child(row)
	parent.move_child(row, at)
	var icon := TextureRect.new()
	icon.texture = texture(icon_name, size)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.modulate = color if color.a > 0.0 else label.modulate
	row.add_child(icon)
	row.add_child(label)
