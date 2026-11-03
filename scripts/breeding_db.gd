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
	# Birds
	"4+5": 27,  # Glacipuff
	"4+6": 28,  # Shimmerwing
	"4+7": 29,  # Rimeowl
	"5+6": 30,  # Prismpuff
	"5+7": 31,  # Quillowl
	"6+7": 32,  # Dawnowl
	# Dogs
	"9+10": 33,  # Duneripper
	"9+11": 34,  # Thornjackal
	"9+12": 35,  # Solarjackal
	"10+11": 36,  # Cactihound
	"10+12": 37,  # Sunhound
	"11+12": 38,  # Bloomfennec
	# Lizards
	"13+14": 39,  # Swampdrake
	"13+15": 40,  # Glowleon
	"13+16": 41,  # Toxileon
	"14+15": 42,  # Wraithlurk
	"14+16": 43,  # Mossdrake
	"15+16": 44,  # Sporewisp
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
