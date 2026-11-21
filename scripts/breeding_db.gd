class_name BreedingDB
## The breeder in the village pairs two different species of the same kind
## (cats with cats, birds with birds, dogs with dogs, lizards with lizards; never
## across kinds) into a hybrid: a new, stronger species with a powered-up
## ability. Each pair of species has its own hybrid.
##
## The parents stay with their owner; the hybrid arrives at 75% of the
## parents' level (see baby_level).

const PRICE := 25
const MIN_PARENT_LEVEL := 1  ## Any level can breed; raise it to require older parents.
## The baby's level, as a share of its parents' (average) level, rounded down.
const BABY_LEVEL_SHARE := 0.75


## The level a hybrid is born at: 75% of its parents' average level, rounded
## down (two level 10 parents have a level 7 baby), and at least 1.
static func baby_level(a_level: int, b_level: int) -> int:
	return maxi(1, floori((a_level + b_level) / 2.0 * BABY_LEVEL_SHARE))

## "a+b" (species indices, smaller first) -> the hybrid's species index.
const HYBRIDS := {
	# Cats
	"0+1": 16,  # Mossback + Emberfox = Magmashell
	"0+2": 17,  # Mossback + Voltwing = Thundershell
	"0+3": 18,  # Mossback + Gloomhorn = Stonehorn
	"1+2": 19,  # Emberfox + Voltwing = Blitzfox
	"1+3": 21,  # Emberfox + Gloomhorn = Duskbloom
	"2+3": 20,  # Voltwing + Gloomhorn = Stormhorn
	# Birds
	"4+5": 22,  # Glacipuff
	"4+6": 23,  # Shimmerwing
	"4+7": 24,  # Rimeowl
	"5+6": 25,  # Prismpuff
	"5+7": 26,  # Quillowl
	"6+7": 27,  # Dawnowl
	# Dogs
	"8+9": 28,  # Duneripper
	"8+10": 29,  # Thornjackal
	"8+11": 30,  # Solarjackal
	"9+10": 31,  # Cactihound
	"9+11": 32,  # Sunhound
	"10+11": 33,  # Bloomfennec
	# Lizards
	"12+13": 34,  # Swampdrake
	"12+14": 35,  # Glowleon
	"12+15": 36,  # Toxileon
	"13+14": 37,  # Wraithlurk
	"13+15": 38,  # Mossdrake
	"14+15": 39,  # Sporewisp
}


## The hybrid of two species, or -1 if they can't be bred together.
static func hybrid_of(a: int, b: int) -> int:
	return HYBRIDS.get("%d+%d" % [mini(a, b), maxi(a, b)], -1)


## What the breeder pays for a pet: 1 coin, or 2 for a hybrid (only bred, never caught).
const SELL_PRICE := 1
const HYBRID_SELL_PRICE := 2


static func sell_price(species_index: int) -> int:
	return HYBRID_SELL_PRICE if is_hybrid(species_index) else SELL_PRICE


static func is_hybrid(species_index: int) -> bool:
	return HYBRIDS.values().has(species_index)


## Why these two pets (stable/party data: {species, level}) can't be bred, or "".
static func cannot_breed_reason(a: Dictionary, b: Dictionary) -> String:
	if a.is_empty() or b.is_empty():
		return "Pick two pets."
	if is_hybrid(a.species) or is_hybrid(b.species):
		return "Hybrids can't be bred again."
	var kind_a := SpeciesDB.get_species(a.species).body_type
	if kind_a != SpeciesDB.get_species(b.species).body_type:
		return "Pets only breed with their own kind (a %s can't breed with a %s)." \
				% [kind_a, SpeciesDB.get_species(b.species).body_type]
	if a.species == b.species:
		return "Pick two different kinds of %s." % kind_a
	if int(a.level) < MIN_PARENT_LEVEL or int(b.level) < MIN_PARENT_LEVEL:
		return "Both parents must be level %d or higher." % MIN_PARENT_LEVEL
	if hybrid_of(a.species, b.species) < 0:
		return "Those two can't be bred."
	return ""
