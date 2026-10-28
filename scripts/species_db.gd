class_name SpeciesDB
## Registry of every creature species. Indices are sent over the network.
## Loaded lazily (not preloaded) to avoid a load cycle with the ability scripts.

const PATHS := [
	"res://resources/species/mossback.tres",
	"res://resources/species/emberfox.tres",
	"res://resources/species/voltwing.tres",
	"res://resources/species/gloomhorn.tres",
	"res://resources/species/frostling.tres",
	"res://resources/species/spikeshell.tres",
	"res://resources/species/aurora_moth.tres",
	"res://resources/species/snowstalker.tres",
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
