class_name BreedingDB
## The breeder in the village pairs two pets of the same kind (so far: cats,
## two different species) into a hybrid: a new, stronger species with a
## powered-up ability. Each pair of species has its own hybrid.
##
## The parents stay with their owner; the hybrid arrives at level 1.

const PRICE := 50
const MIN_PARENT_LEVEL := 5

## "a+b" (species indices, smaller first) -> the hybrid's species index.
const HYBRIDS := {
	"0+1": 17,  # Mossback + Emberfox = Magmashell
	"0+2": 18,  # Mossback + Voltwing = Thundershell
	"0+3": 19,  # Mossback + Gloomhorn = Stonehorn
	"0+8": 20,  # Mossback + Bloomling = Mossbloom
	"1+2": 21,  # Emberfox + Voltwing = Blitzfox
	"1+3": 22,  # Emberfox + Gloomhorn = Cinderhorn
	"1+8": 23,  # Emberfox + Bloomling = Sunpetal
	"2+3": 24,  # Voltwing + Gloomhorn = Stormhorn
	"2+8": 25,  # Voltwing + Bloomling = Sparkblossom
	"3+8": 26,  # Gloomhorn + Bloomling = Duskbloom
}


## The hybrid of two species, or -1 if they can't be bred together.
static func hybrid_of(a: int, b: int) -> int:
	return HYBRIDS.get("%d+%d" % [mini(a, b), maxi(a, b)], -1)


static func is_hybrid(species_index: int) -> bool:
	return HYBRIDS.values().has(species_index)


## Why these two pets (stable/party data: {species, level}) can't be bred, or "".
static func cannot_breed_reason(a: Dictionary, b: Dictionary) -> String:
	if a.is_empty() or b.is_empty():
		return "Pick two pets."
	if SpeciesDB.get_species(a.species).body_type != "cat" or SpeciesDB.get_species(b.species).body_type != "cat":
		return "The breeder only works with cats so far."
	if is_hybrid(a.species) or is_hybrid(b.species):
		return "Hybrids can't be bred again."
	if a.species == b.species:
		return "Pick two different kinds of cat."
	if int(a.level) < MIN_PARENT_LEVEL or int(b.level) < MIN_PARENT_LEVEL:
		return "Both parents must be level %d or higher." % MIN_PARENT_LEVEL
	if hybrid_of(a.species, b.species) < 0:
		return "Those two can't be bred."
	return ""
