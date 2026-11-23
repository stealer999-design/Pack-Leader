class_name SpeciesDB
## Registry of every creature species. Indices are sent over the network.
## Loaded lazily (not preloaded) to avoid a load cycle with the ability scripts.

const PATHS := [
	"res://resources/species/mossback.tres",
	"res://resources/species/emberkitty.tres",
	"res://resources/species/voltwing.tres",
	"res://resources/species/gloomhorn.tres",
	"res://resources/species/frostling.tres",
	"res://resources/species/spikeshell.tres",
	"res://resources/species/aurora_moth.tres",
	"res://resources/species/snowstalker.tres",
	"res://resources/species/sandviper.tres",
	"res://resources/species/dunescuttle.tres",
	"res://resources/species/cactling.tres",
	"res://resources/species/sunfennec.tres",
	"res://resources/species/bogtoad.tres",
	"res://resources/species/mirelurk.tres",
	"res://resources/species/marsh_wisp.tres",
	"res://resources/species/sporecap.tres",
	# Hybrids: only from the breeder (see BreedingDB), never wild.
	"res://resources/species/magmashell.tres",
	"res://resources/species/thundershell.tres",
	"res://resources/species/stonehorn.tres",
	"res://resources/species/blitzkitty.tres",
	"res://resources/species/stormhorn.tres",
	"res://resources/species/duskbloom.tres",
	"res://resources/species/glacipuff.tres",
	"res://resources/species/shimmerwing.tres",
	"res://resources/species/rimeowl.tres",
	"res://resources/species/prismpuff.tres",
	"res://resources/species/quillowl.tres",
	"res://resources/species/dawnowl.tres",
	"res://resources/species/duneripper.tres",
	"res://resources/species/thornjackal.tres",
	"res://resources/species/solarjackal.tres",
	"res://resources/species/cactihound.tres",
	"res://resources/species/sunhound.tres",
	"res://resources/species/bloomfennec.tres",
	"res://resources/species/swampdrake.tres",
	"res://resources/species/glowleon.tres",
	"res://resources/species/toxileon.tres",
	"res://resources/species/wraithlurk.tres",
	"res://resources/species/mossdrake.tres",
	"res://resources/species/sporewisp.tres",
	# Graveyard monsters (Act 2): never pets.
	"res://resources/species/skeleton.tres",
	"res://resources/species/zombie.tres",
	# Act 2's other monsters: desert, volcano, ice.
	"res://resources/species/mummy.tres",
	"res://resources/species/sand_scorpion.tres",
	"res://resources/species/fire_imp.tres",
	"res://resources/species/magma_golem.tres",
	"res://resources/species/frost_wraith.tres",
	"res://resources/species/yeti.tres",
]

static var _all: Array[CreatureSpecies] = []


static func all() -> Array[CreatureSpecies]:
	if _all.is_empty():
		for path in PATHS:
			_all.append(load(path))
	return _all


static func get_species(index: int) -> CreatureSpecies:
	return all()[clampi(index, 0, PATHS.size() - 1)]


## Weighted random pick among `indices` (every species if empty).
static func pick_random_index(indices: Array = []) -> int:
	if indices.is_empty():
		indices = range(all().size())
	var total := 0.0
	for i in indices:
		total += all()[i].spawn_weight
	var roll := randf() * total
	for i in indices:
		roll -= all()[i].spawn_weight
		if roll <= 0.0:
			return i
	return indices[-1]
