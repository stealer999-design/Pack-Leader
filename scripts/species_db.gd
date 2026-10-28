class_name SpeciesDB
## Registry of every creature species. Indices are sent over the network.
## Loaded lazily (not preloaded) to avoid a load cycle with the ability scripts.

const PATHS := [
	"res://resources/species/mossback.tres",
	"res://resources/species/emberfox.tres",
	"res://resources/species/voltwing.tres",
	"res://resources/species/gloomhorn.tres",
]

static var _all: Array[CreatureSpecies] = []


static func all() -> Array[CreatureSpecies]:
	if _all.is_empty():
		for path in PATHS:
			_all.append(load(path))
	return _all


static func get_species(index: int) -> CreatureSpecies:
	return all()[clampi(index, 0, PATHS.size() - 1)]


static func pick_random_index() -> int:
	var total := 0.0
	for s in all():
		total += s.spawn_weight
	var roll := randf() * total
	for i in all().size():
		roll -= all()[i].spawn_weight
		if roll <= 0.0:
			return i
	return all().size() - 1
