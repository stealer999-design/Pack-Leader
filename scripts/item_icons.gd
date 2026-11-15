class_name ItemIcons
## Full-colour pictures of gear for the inventory, the stash, the shop and
## pickups: one drawing per base type and tier (a Leather Jacket, a Padded
## Coat and a Ranger's Duster all look different), coloured from the item
## itself:
## - cloth / leather: the item's own colour (ItemDB.item_color);
## - metal: bronze (tier 1), silver (tier 2), gold (tier 3);
## - the accent (a gem, a badge, a stripe, glowing runes): the class colour
##   for class items, else the colour of the item's main bonus (red for pet
##   damage, green for pet health, cyan for cooldowns...);
## - Unique and Set items get a small star or leaf in the corner.
## Drawn as SVG (64x64, a bold ink outline) and cached.

const INK := "#141414"
const METALS := ["#c07a3c", "#cfd4dc", "#f0c95a"]
const METAL_SHADES := ["#7d4a20", "#8c929c", "#a8842c"]
## Accent colour by affix (the item's strongest one wins).
const ACCENTS := {
	"pet_damage": "#ff4a3d", "pet_health": "#4fe07a", "cooldown": "#3fd8ff", "life_hit": "#d0103a",
	"health": "#ff7ab0", "armor": "#9fb4cc", "poison_resist": "#9be03a", "speed": "#ffe24a",
	"magic_find": "#ffb02e", "coin_find": "#ffd84a",
}

static var _cache := {}


## The item's picture, `size` pixels square ({} = no picture).
static func texture(item: Dictionary, size: int) -> Texture2D:
	if not ItemDB.is_item(item):
		return null
	var tier := clampi(int(item.get("tier", 1)), 1, 3)
	var cloth: Color = ItemDB.item_color(item) if not ItemDB.is_rolled(item) else ItemDB.OUTFIT_COLORS[item.type][ItemDB.look_level(item) - 1]
	var accent := accent_color(item)
	var rarity := int(item.get("rarity", 0))
	var key := "%s|%d|%s|%s|%d|%d" % [item.type, tier, cloth.to_html(false), accent, rarity, size]
	if not _cache.has(key):
		var body := _shape(str(item.type), tier, cloth, accent)
		if rarity == ItemDB.UNIQUE:
			body += '<path d="M8 2l1.8 3.8 4.2.6-3 2.9.7 4.1L8 11.4 4.3 13.4l.7-4.1-3-2.9 4.2-.6z" fill="#f0c95a" stroke="%s" stroke-width="1.2"/>' % INK
		elif rarity == ItemDB.SET:
			body += '<path d="M3 13C3 6 7 3 13 3c0 7-4 10-10 10z" fill="#4fe07a" stroke="%s" stroke-width="1.2"/><path d="M4 12l7-7" stroke="%s" stroke-width="1"/>' % [INK, INK]
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" stroke-linejoin="round" stroke-linecap="round">%s</svg>' % body
		var image := Image.new()
		image.load_svg_from_string(svg, size / 64.0)
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


## The accent colour: the class colour for class items, else the strongest affix's.
static func accent_color(item: Dictionary) -> String:
	if ItemDB.is_rolled(item):
		return "#" + ItemDB.PET_GEAR[item["class"]].color.lightened(0.15).to_html(false)
	var best := ""
	var best_power := -1.0
	for id: String in item.get("affixes", {}):
		var p := float(item.affixes[id]) * ItemDB._weight(id)
		if ACCENTS.has(id) and p > best_power:
			best_power = p
			best = id
	return ACCENTS.get(best, "#d9dde4")  # plain items: a pale stone


static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)


## One base item's drawing: `c` its cloth colour, `a` the accent.
static func _shape(type: String, tier: int, cloth: Color, a: String) -> String:
	var c := _hex(cloth.lightened(0.18))
	var d := _hex(cloth.darkened(0.25))
	var hi := _hex(cloth.lightened(0.45))
	var m: String = METALS[tier - 1]
	var ms: String = METAL_SHADES[tier - 1]
	var leather := "#7a4a2a"
	var k := INK
	match type + str(tier):
		# --- Chest -------------------------------------------------------------
		"jacket1":  # Leather Jacket: lapels, a zip, two pockets, a badge
			return ('<path d="M20 9l6-2 6 7 6-7 6 2 10 7 4 24-8 2-2-11v25H16V31l-2 11-8-2 4-24z" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
				+ '<path d="M26 7l6 15 6-15-3-1-3 9-3-9z" fill="%s" stroke="%s" stroke-width="2"/>' % [d, k]
				+ '<path d="M32 22v34" stroke="%s" stroke-width="2.5"/><path d="M32 22v34" stroke="%s" stroke-width="1" stroke-dasharray="1.5 1.5"/>' % [ms, m]
				+ '<rect x="19" y="40" width="9" height="6" rx="1" fill="%s" stroke="%s" stroke-width="1.6"/><rect x="36" y="40" width="9" height="6" rx="1" fill="%s" stroke="%s" stroke-width="1.6"/>' % [d, k, d, k]
				+ '<path d="M21 16c2 4 2 10 0 14" stroke="%s" stroke-width="1.5" fill="none"/>' % hi
				+ '<circle cx="41" cy="28" r="3.2" fill="%s" stroke="%s" stroke-width="1.5"/>' % [a, k])
		"jacket2":  # Padded Coat: quilted puffy rows, a high collar, toggles
			var rows := ""
			for y in [23, 31, 39, 47]:
				rows += '<path d="M17 %dQ32 %d 47 %d" stroke="%s" stroke-width="1.6" fill="none"/>' % [y, y + 3, y, d]
			return ('<path d="M19 10l7-3h12l7 3 11 7 3 25-9 2-2-12v26H17V32l-2 12-9-2 3-25z" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
				+ rows
				+ '<path d="M24 6h16v7c-3 3-13 3-16 0z" fill="%s" stroke="%s" stroke-width="2"/>' % [d, k]
				+ '<path d="M32 14v42" stroke="%s" stroke-width="1.8"/>' % k
				+ '<rect x="34" y="21" width="5" height="2.6" rx="1.2" fill="%s" stroke="%s" stroke-width="1"/><rect x="34" y="29" width="5" height="2.6" rx="1.2" fill="%s" stroke="%s" stroke-width="1"/><rect x="34" y="37" width="5" height="2.6" rx="1.2" fill="%s" stroke="%s" stroke-width="1"/>' % [m, k, m, k, a, k]
				+ '<path d="M12 22c-1 6-2 12-2 18" stroke="%s" stroke-width="1.5" fill="none"/>' % hi)
		"jacket3":  # Ranger's Duster: a long flared coat, a shoulder cape, a belt and buckle
			return ('<path d="M20 9l6-2 6 6 6-6 6 2 9 8 4 24-7 2-3-12 7 29H12l7-29-3 12-7-2 4-24z" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
				+ '<path d="M14 15c5-6 31-6 36 0l-3 9c-7-4-23-4-30 0z" fill="%s" stroke="%s" stroke-width="2"/>' % [d, k]
				+ '<path d="M32 13v47" stroke="%s" stroke-width="1.8"/>' % k
				+ '<rect x="17" y="33" width="30" height="5" fill="%s" stroke="%s" stroke-width="1.8"/>' % [leather, k]
				+ '<rect x="28" y="31.5" width="8" height="8" rx="1.5" fill="%s" stroke="%s" stroke-width="1.8"/><circle cx="32" cy="35.5" r="2.2" fill="%s"/>' % [m, k, a]
				+ '<path d="M26 44l-4 14M38 44l4 14" stroke="%s" stroke-width="1.5"/>' % d)
		# --- Pants ---------------------------------------------------------------
		"pants1":  # Work Trousers: a waistband, a stitched knee patch, a button
			return ('<path d="M17 8h30l4 50H37l-5-30-5 30H13z" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
				+ '<rect x="17" y="8" width="30" height="6" fill="%s" stroke="%s" stroke-width="2"/>' % [d, k]
				+ '<rect x="17" y="38" width="8" height="8" fill="%s" stroke="%s" stroke-width="1.6"/><path d="M18.5 39.5h5v5h-5z" fill="none" stroke="%s" stroke-width="0.9" stroke-dasharray="1.4 1.2"/>' % [hi, k, k]
				+ '<circle cx="32" cy="11" r="1.8" fill="%s" stroke="%s" stroke-width="1"/>' % [a, k]
				+ '<path d="M32 14v12" stroke="%s" stroke-width="1.5"/>' % k)
		"pants2":  # Reinforced Pants: metal knee pads and belt loops
			return ('<path d="M17 8h30l4 50H37l-5-30-5 30H13z" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
				+ '<rect x="17" y="8" width="30" height="6" fill="%s" stroke="%s" stroke-width="2"/>' % [d, k]
				+ '<path d="M21 8v6M28 8v6M36 8v6M43 8v6" stroke="%s" stroke-width="1.5"/>' % k
				+ '<ellipse cx="21" cy="40" rx="5" ry="6" fill="%s" stroke="%s" stroke-width="1.8"/><ellipse cx="43" cy="40" rx="5" ry="6" fill="%s" stroke="%s" stroke-width="1.8"/>' % [m, k, m, k]
				+ '<circle cx="21" cy="40" r="1.6" fill="%s"/><circle cx="43" cy="40" r="1.6" fill="%s"/>' % [a, a]
				+ '<path d="M32 14v12" stroke="%s" stroke-width="1.5"/>' % k)
		"pants3":  # Trail Breeches: a belt with a buckle, side straps, cuffs
			return ('<path d="M17 9h30l3 43H37l-5-26-5 26H14z" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
				+ '<path d="M14 52h13l-1 6H14zM37 52h13l0 6H38z" fill="%s" stroke="%s" stroke-width="2"/>' % [leather, k]
				+ '<rect x="16" y="8" width="32" height="6" fill="%s" stroke="%s" stroke-width="2"/>' % [leather, k]
				+ '<rect x="28" y="6.5" width="8" height="9" rx="1.5" fill="%s" stroke="%s" stroke-width="1.8"/><circle cx="32" cy="11" r="2.2" fill="%s"/>' % [m, k, a]
				+ '<path d="M18 22l3 6M18 30l3 6M46 22l-3 6M46 30l-3 6" stroke="%s" stroke-width="2"/>' % [ms])
		# --- Hat -----------------------------------------------------------------
		"hat1":  # Cap: a soft crown, a peak, a button and a front badge
			return ('<path d="M14 38C14 18 22 14 32 14s18 4 18 24z" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
				+ '<path d="M8 38c10-4 36-4 48 1l2 5c-14-4-38-4-52 0z" fill="%s" stroke="%s" stroke-width="2.2"/>' % [d, k]
				+ '<circle cx="32" cy="13" r="2.5" fill="%s" stroke="%s" stroke-width="1.5"/>' % [d, k]
				+ '<path d="M32 15v21M22 18c-3 6-4 12-4 19M42 18c3 6 4 12 4 19" stroke="%s" stroke-width="1.2" fill="none"/>' % d
				+ '<circle cx="32" cy="29" r="4" fill="%s" stroke="%s" stroke-width="1.6"/>' % [a, k])
		"hat2":  # Hard Hat: a domed shell with a ridge, a rim and a lamp
			return ('<path d="M12 40C12 20 21 12 32 12s20 8 20 28z" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
				+ '<path d="M27 13h10l-1 27h-8z" fill="%s" stroke="%s" stroke-width="1.8"/>' % [hi, k]
				+ '<rect x="7" y="39" width="50" height="6" rx="3" fill="%s" stroke="%s" stroke-width="2.2"/>' % [d, k]
				+ '<rect x="25" y="25" width="14" height="10" rx="3" fill="%s" stroke="%s" stroke-width="1.8"/>' % [m, k]
				+ '<circle cx="32" cy="30" r="3.3" fill="%s" stroke="%s" stroke-width="1.2"/>' % [a, k]
				+ '<path d="M28 34l-6 10M36 34l6 10" stroke="%s" stroke-width="1" opacity="0.6"/>' % a)
		"hat3":  # Warden's Hat: a wide brim, a dented crown, a band and a feather
			return ('<ellipse cx="32" cy="42" rx="29" ry="8" fill="%s" stroke="%s" stroke-width="2.5"/>' % [d, k]
				+ '<path d="M17 42c0-18 4-26 15-26s15 8 15 26c-8 3-22 3-30 0z" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
				+ '<path d="M26 18l6 5 6-5" stroke="%s" stroke-width="1.6" fill="none"/>' % d
				+ '<path d="M17 36c8 3 22 3 30 0v5c-8 3-22 3-30 0z" fill="%s" stroke="%s" stroke-width="1.6"/>' % [a, k]
				+ '<path d="M44 36c4-10 10-18 16-22-2 9-7 17-14 24z" fill="%s" stroke="%s" stroke-width="1.8"/><path d="M46 36l12-20" stroke="%s" stroke-width="1"/>' % [hi, k, k]
				+ '<circle cx="24" cy="38.5" r="1.8" fill="%s" stroke="%s" stroke-width="1"/>' % [m, k])
		# --- Boots ---------------------------------------------------------------
		"boots1":  # Sneakers: a low shoe, laces and a stripe
			return ('<path d="M10 34c0-8 6-12 14-12l10 2 8 8 12 4c3 1 4 4 4 8v4H10z" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
				+ '<path d="M8 48h52v5c0 2-1 3-3 3H11c-2 0-3-1-3-3z" fill="#f2efe8" stroke="%s" stroke-width="2.2"/>' % k
				+ '<path d="M26 25l6 4M29 23l6 5M32 22l6 6" stroke="%s" stroke-width="1.6"/>' % k
				+ '<path d="M16 42c10-6 22-6 32 0" stroke="%s" stroke-width="3" fill="none"/>' % a)
		"boots2":  # Hiking Boots: ankle high, crossed laces, a thick tread
			return ('<path d="M16 10h16v24l14 4c6 2 10 5 10 10v3H14V12z" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
				+ '<path d="M12 50h46v6H12z" fill="%s" stroke="%s" stroke-width="2.2"/><path d="M16 56v-3M22 56v-3M28 56v-3M34 56v-3M40 56v-3M46 56v-3M52 56v-3" stroke="%s" stroke-width="1.5"/>' % ["#3a2a20", k, "#77665a"]
				+ '<path d="M20 14l10 5M30 14l-10 5M20 21l10 5M30 21l-10 5M20 28l10 5M30 28l-10 5" stroke="%s" stroke-width="1.5"/>' % a
				+ '<rect x="14" y="8" width="20" height="5" rx="2" fill="%s" stroke="%s" stroke-width="1.8"/>' % [d, k]
				+ '<circle cx="21" cy="17" r="1" fill="%s"/><circle cx="21" cy="24" r="1" fill="%s"/><circle cx="29" cy="17" r="1" fill="%s"/><circle cx="29" cy="24" r="1" fill="%s"/>' % [m, m, m, m])
		"boots3":  # Pathfinder Boots: tall, a folded cuff, buckled straps
			return ('<path d="M17 6h17v30l14 4c6 2 9 5 9 10v2H15V8z" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
				+ '<path d="M13 52h46v5H13z" fill="#2a1f18" stroke="%s" stroke-width="2.2"/>' % k
				+ '<path d="M14 4h22v8H14z" fill="%s" stroke="%s" stroke-width="2"/>' % [d, k]
				+ '<rect x="15" y="18" width="20" height="4" fill="%s" stroke="%s" stroke-width="1.5"/><rect x="15" y="28" width="20" height="4" fill="%s" stroke="%s" stroke-width="1.5"/>' % [leather, k, leather, k]
				+ '<rect x="26" y="17" width="5" height="6" rx="1" fill="%s" stroke="%s" stroke-width="1.3"/><rect x="26" y="27" width="5" height="6" rx="1" fill="%s" stroke="%s" stroke-width="1.3"/>' % [m, k, m, k]
				+ '<circle cx="28.5" cy="8" r="2.2" fill="%s" stroke="%s" stroke-width="1"/>' % [a, k])
		# --- Rings ---------------------------------------------------------------
		"ring1":  # Band: a plain metal band, an engraved line and a chip of stone
			return ('<ellipse cx="32" cy="36" rx="20" ry="18" fill="none" stroke="%s" stroke-width="12"/>' % k
				+ '<ellipse cx="32" cy="36" rx="20" ry="18" fill="none" stroke="%s" stroke-width="7"/>' % m
				+ '<path d="M16 28c4-6 10-9 16-9" stroke="#fff" stroke-width="2" fill="none" opacity="0.7"/>'
				+ '<ellipse cx="32" cy="36" rx="20" ry="18" fill="none" stroke="%s" stroke-width="1" stroke-dasharray="3 3"/>' % ms
				+ '<circle cx="32" cy="18" r="3.5" fill="%s" stroke="%s" stroke-width="1.6"/>' % [a, k])
		"ring2":  # Signet: a band with a flat face engraved with a paw
			return ('<ellipse cx="32" cy="40" rx="18" ry="16" fill="none" stroke="%s" stroke-width="11"/>' % k
				+ '<ellipse cx="32" cy="40" rx="18" ry="16" fill="none" stroke="%s" stroke-width="6"/>' % m
				+ '<ellipse cx="32" cy="20" rx="13" ry="10" fill="%s" stroke="%s" stroke-width="2.4"/>' % [m, k]
				+ '<ellipse cx="32" cy="20" rx="9" ry="6.5" fill="%s" stroke="%s" stroke-width="1.4"/>' % [a, k]
				+ '<circle cx="32" cy="22" r="2.3" fill="%s"/><circle cx="28.5" cy="18" r="1.1" fill="%s"/><circle cx="32" cy="16.5" r="1.1" fill="%s"/><circle cx="35.5" cy="18" r="1.1" fill="%s"/>' % [ms, ms, ms, ms])
		"ring3":  # Seal: a heavy band, a crown of prongs and a big cut gem
			return ('<ellipse cx="32" cy="42" rx="18" ry="15" fill="none" stroke="%s" stroke-width="12"/>' % k
				+ '<ellipse cx="32" cy="42" rx="18" ry="15" fill="none" stroke="%s" stroke-width="7"/>' % m
				+ '<path d="M20 26l4-12 8 6 8-6 4 12z" fill="%s" stroke="%s" stroke-width="2.2"/>' % [m, k]
				+ '<path d="M32 7l9 9-9 12-9-12z" fill="%s" stroke="%s" stroke-width="2.2"/>' % [a, k]
				+ '<path d="M23 16h18M32 7v21M27 16l5-9 5 9" stroke="#fff" stroke-width="0.9" opacity="0.6" fill="none"/>')
		# --- Necklaces -------------------------------------------------------------
		"necklace1":  # Cord: a leather cord with a fang and a bead
			return ('<path d="M10 6c0 18 9 28 22 28s22-10 22-28" fill="none" stroke="%s" stroke-width="5"/>' % k
				+ '<path d="M10 6c0 18 9 28 22 28s22-10 22-28" fill="none" stroke="%s" stroke-width="2.6"/>' % leather
				+ '<path d="M28 34c0 10 2 18 4 24 2-6 4-14 4-24z" fill="#f4eedc" stroke="%s" stroke-width="2"/>' % k
				+ '<circle cx="32" cy="33" r="3.6" fill="%s" stroke="%s" stroke-width="1.6"/>' % [a, k])
		"necklace2":  # Pendant: a fine chain and an oval locket with a stone
			var links := ""
			for i in 11:
				var t := i / 10.0
				var x := 10.0 + 44.0 * t
				var y := 6.0 + 26.0 * sin(PI * t)
				links += '<circle cx="%.1f" cy="%.1f" r="2" fill="none" stroke="%s" stroke-width="1.4"/>' % [x, y, m]
			return (links
				+ '<ellipse cx="32" cy="44" rx="10" ry="13" fill="%s" stroke="%s" stroke-width="2.4"/>' % [m, k]
				+ '<ellipse cx="32" cy="44" rx="5.5" ry="7.5" fill="%s" stroke="%s" stroke-width="1.6"/>' % [a, k]
				+ '<path d="M30 40c1-2 3-2 4 0" stroke="#fff" stroke-width="1" fill="none" opacity="0.7"/>'
				+ '<circle cx="32" cy="31" r="2.2" fill="%s" stroke="%s" stroke-width="1.2"/>' % [ms, k])
		"necklace3":  # Talisman: a double chain and a sun disc around a big gem
			var rays := ""
			for i in 12:
				var ang := TAU * i / 12.0
				rays += '<path d="M%.1f %.1fL%.1f %.1f" stroke="%s" stroke-width="2.2"/>' % [32 + cos(ang) * 11, 44 + sin(ang) * 11,
						32 + cos(ang) * 16, 44 + sin(ang) * 16, m]
			return ('<path d="M8 4c0 16 10 24 24 26M56 4c0 16-10 24-24 26" fill="none" stroke="%s" stroke-width="2.4" stroke-dasharray="3 2"/>' % m
				+ '<path d="M13 4c0 12 8 18 19 20M51 4c0 12-8 18-19 20" fill="none" stroke="%s" stroke-width="1.6" stroke-dasharray="2 2"/>' % ms
				+ rays
				+ '<circle cx="32" cy="44" r="11" fill="%s" stroke="%s" stroke-width="2.4"/>' % [m, k]
				+ '<path d="M32 36l7 8-7 8-7-8z" fill="%s" stroke="%s" stroke-width="1.8"/>' % [a, k]
				+ '<path d="M29 41l3-3" stroke="#fff" stroke-width="1.2" opacity="0.7"/>')
		# --- Collars ---------------------------------------------------------------
		"collar1":  # Strap: a leather band, a buckle and a round tag
			return ('<ellipse cx="32" cy="26" rx="24" ry="13" fill="none" stroke="%s" stroke-width="12"/>' % k
				+ '<ellipse cx="32" cy="26" rx="24" ry="13" fill="none" stroke="%s" stroke-width="7.5"/>' % c
				+ '<ellipse cx="32" cy="26" rx="24" ry="13" fill="none" stroke="%s" stroke-width="1" stroke-dasharray="2 2"/>' % d
				+ '<rect x="47" y="27" width="9" height="9" rx="1.5" fill="none" stroke="%s" stroke-width="2.6"/>' % m
				+ '<path d="M32 39v5" stroke="%s" stroke-width="2"/><circle cx="32" cy="50" r="6" fill="%s" stroke="%s" stroke-width="2"/>' % [m, a, k]
				+ '<path d="M29.5 50h5" stroke="%s" stroke-width="1.4"/>' % k)
		"collar2":  # Studded Collar: a thick band with metal studs and a tag
			var studs := ""
			for i in 9:
				var ang := PI * (0.12 + 0.76 * i / 8.0)
				studs += '<circle cx="%.1f" cy="%.1f" r="2.4" fill="%s" stroke="%s" stroke-width="1.2"/>' % [32 - cos(ang) * 24, 26 + sin(ang) * 13, m, k]
			return ('<ellipse cx="32" cy="26" rx="24" ry="13" fill="none" stroke="%s" stroke-width="13"/>' % k
				+ '<ellipse cx="32" cy="26" rx="24" ry="13" fill="none" stroke="%s" stroke-width="8.5"/>' % c
				+ studs
				+ '<path d="M32 40v4" stroke="%s" stroke-width="2"/><path d="M32 44l7 6-7 8-7-8z" fill="%s" stroke="%s" stroke-width="2"/>' % [m, a, k])
		"collar3":  # Runed Collar: a dark band with glowing runes, a clasp and a gem
			var runes := ""
			for i in 5:
				var ang := PI * (0.2 + 0.6 * i / 4.0)
				var x := 32 - cos(ang) * 24
				var y := 26 + sin(ang) * 13
				runes += '<path d="M%.1f %.1fl2-3 2 3-2 3zM%.1f %.1fv4" stroke="%s" stroke-width="1.3" fill="none"/>' % [x - 2, y, x, y - 2, a]
			return ('<ellipse cx="32" cy="26" rx="24" ry="13" fill="none" stroke="%s" stroke-width="13"/>' % k
				+ '<ellipse cx="32" cy="26" rx="24" ry="13" fill="none" stroke="%s" stroke-width="8.5"/>' % d
				+ runes
				+ '<rect x="26" y="34" width="12" height="7" rx="2" fill="%s" stroke="%s" stroke-width="1.8"/>' % [m, k]
				+ '<path d="M32 41v3" stroke="%s" stroke-width="2"/><circle cx="32" cy="50" r="6.5" fill="%s" stroke="%s" stroke-width="2.2"/>' % [m, a, k]
				+ '<path d="M29 48l3-2 3 2" stroke="#fff" stroke-width="1.1" fill="none" opacity="0.7"/>')
	return '<circle cx="32" cy="32" r="20" fill="%s" stroke="%s" stroke-width="2.5"/>' % [c, k]
