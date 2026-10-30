class_name ItemDB
## Gear: what each item is and does. An item is a small Dictionary
## {type, level, rarity} (saved and sent over the network as is); its name,
## slot and stats are worked out from those here.
##
## So far there are jackets (chest slot), one per level 1-5, which make the
## tamer take less damage. The weapon slot shows the tamer's bat (from the Bat
## Shop; see Player.BATS). Pants, hat, rings and necklace slots are ready for
## future items.

const BAG_SIZE := 24
## Equipment slots, in display order.
const SLOTS := ["weapon", "chest", "pants", "hat", "ring1", "ring2", "necklace"]
const SLOT_NAMES := {
	"weapon": "Weapon", "chest": "Chest", "pants": "Pants", "hat": "Hat",
	"ring1": "Ring", "ring2": "Ring", "necklace": "Necklace",
}
## Icon (UiIcons) shown in each empty slot.
const SLOT_ICONS := {
	"weapon": "bat", "chest": "jacket", "pants": "pants", "hat": "hat",
	"ring1": "ring", "ring2": "ring", "necklace": "necklace",
}

const RARITIES := [
	{"name": "Common", "prefix": "", "color": Color(0.82, 0.82, 0.8), "bonus": 0},
	{"name": "Uncommon", "prefix": "Fine ", "color": Color(0.45, 0.9, 0.45), "bonus": 2},
	{"name": "Rare", "prefix": "Superior ", "color": Color(0.45, 0.65, 1.0), "bonus": 4},
]
## Chance of each rarity when an item drops (common, uncommon, rare).
const RARITY_WEIGHTS := [0.7, 0.23, 0.07]

## Jackets by level (1-5): name, armor (percent less damage taken) and colour.
const JACKETS := [
	{"name": "Tattered Jacket", "armor": 4, "color": Color(0.55, 0.45, 0.35)},
	{"name": "Leather Jacket", "armor": 7, "color": Color(0.45, 0.28, 0.16)},
	{"name": "Padded Jacket", "armor": 10, "color": Color(0.35, 0.42, 0.3)},
	{"name": "Studded Jacket", "armor": 13, "color": Color(0.3, 0.3, 0.36)},
	{"name": "Ranger's Jacket", "armor": 16, "color": Color(0.22, 0.38, 0.28)},
]
const MAX_LEVEL := 5
## Armor from all gear is capped, so the tamer is never unhittable.
const MAX_ARMOR := 60


## A new jacket for an area level (levels past 5 drop level 5 jackets).
static func make_jacket(area_level: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var roll := rng.randf() if rng else randf()
	var rarity := 0
	var acc := 0.0
	for i in RARITY_WEIGHTS.size():
		acc += RARITY_WEIGHTS[i]
		if roll < acc:
			rarity = i
			break
	return {"type": "jacket", "level": clampi(area_level, 1, MAX_LEVEL), "rarity": rarity}


## The slot an item goes in ("" if it can't be worn).
static func slot_of(item: Dictionary) -> String:
	match item.get("type", ""):
		"jacket":
			return "chest"
	return ""


## True if `item` can be worn in equipment `slot` (rings go in either ring slot).
static func fits(item: Dictionary, slot: String) -> bool:
	var own := slot_of(item)
	if own == "":
		return false
	return own == slot or (own == "ring" and slot in ["ring1", "ring2"])


static func display_name(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var rarity: Dictionary = RARITIES[int(item.rarity)]
	match item.type:
		"jacket":
			return rarity.prefix + JACKETS[int(item.level) - 1].name
	return "?"


static func rarity_color(item: Dictionary) -> Color:
	return RARITIES[int(item.get("rarity", 0))].color


## The item's own colour (a jacket's cloth), for icons and the tamer's model.
static func item_color(item: Dictionary) -> Color:
	match item.get("type", ""):
		"jacket":
			return JACKETS[int(item.level) - 1].color
	return Color.WHITE


## Percent less damage taken.
static func armor(item: Dictionary) -> int:
	match item.get("type", ""):
		"jacket":
			return JACKETS[int(item.level) - 1].armor + RARITIES[int(item.rarity)].bonus
	return 0


## A short description for tooltips and the details line.
static func describe(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var lines := ["%s  (level %d)" % [display_name(item), int(item.level)], RARITIES[int(item.rarity)].name + " " + item.type]
	var a := armor(item)
	if a > 0:
		lines.append("Armor: take %d%% less damage" % a)
	return "\n".join(lines)


## An item from a save or a client, made safe: a known type and sensible
## numbers, or {} if it isn't a real item.
static func clean(item) -> Dictionary:
	if not item is Dictionary or not item.has("type"):
		return {}
	match str(item.type):
		"jacket":
			return {
				"type": "jacket",
				"level": clampi(int(item.get("level", 1)), 1, MAX_LEVEL),
				"rarity": clampi(int(item.get("rarity", 0)), 0, RARITIES.size() - 1),
			}
	return {}
