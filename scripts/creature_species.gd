class_name CreatureSpecies
extends Resource
## Data for one kind of creature. Add a new .tres in resources/species and
## list it in SpeciesDB to add it to the world.

@export var display_name := "Creature"
@export var color := Color.WHITE
@export var size := 1.0
## The body the creature is built with (see CreatureModel). Each biome has its own.
@export_enum("cat", "bird", "dog", "lizard", "skeleton", "zombie") var body_type := "cat"
## An extra body detail for this species (see CreatureModel).
@export_enum("none", "big_ears", "spines", "horn", "mane", "wings", "crown") var feature := "none"

## Each kind of body fights its own way. Cats are wizards: their attacks are
## magic bolts fired from range, and their abilities are spells. Dogs are
## paladins: melee tanks with more health and less damage taken, whose hits
## heal the most injured ally nearby, who draw wild enemies' attention, and
## whose abilities heal and protect. Birds are archers: they shoot arrows
## from further than anyone, hop back from enemies that get too close, and
## their abilities are all ranged shots.
const CLASS_BY_BODY := {"cat": "wizard", "dog": "paladin", "bird": "archer"}
const PALADIN_HEALTH := 1.35  ## Max health multiplier.
const PALADIN_DAMAGE_TAKEN := 0.85  ## Damage taken multiplier.
const PALADIN_HEAL_ON_HIT := 0.3  ## Share of each hit's damage healed onto the most injured ally.
const PALADIN_HEAL_RANGE := 8.0
## How far the ranged classes attack from (world units, whatever their size).
const RANGED_ATTACK_RANGE := 6.5
const ARCHER_ATTACK_RANGE := 8.5
## Archers back away from an enemy that's after them and closer than this.
const ARCHER_KITE_DISTANCE := 2.8

@export_group("Stats (level 1)")
@export var max_health := 50.0
@export var damage := 6.0
@export var move_speed := 4.0
@export var attack_range := 1.0
@export var attack_cooldown := 1.0

@export_group("Wild behaviour")
## Aggressive creatures attack on sight; others only fight back.
@export var aggressive := true
@export var aggro_range := 9.0
@export var spawn_weight := 1.0

## Monsters (the undead of the graveyard) are not creatures you can tame: they
## can't be captured, and the tamer's bat can finish them off.
@export var monster := false

@export_group("Taming")
## 0..1. Higher = easier to capture. Capture chance also scales with missing health.
@export var catch_rate := 0.5
@export var xp_reward := 10

@export_group("Pet")
## Triggered by the owner with the ability key for this pet's party slot.
@export var ability: PetAbility


## The species' class ("wizard", "paladin", "archer", or "" for plain melee fighters).
func pet_class() -> String:
	return CLASS_BY_BODY.get(body_type, "")


func is_ranged() -> bool:
	return pet_class() == "wizard" or pet_class() == "archer"


func is_archer() -> bool:
	return pet_class() == "archer"


## How far its basic attack reaches (melee: by its size), before the target's own radius.
func attack_reach() -> float:
	if is_archer():
		return ARCHER_ATTACK_RANGE
	if is_ranged():
		return RANGED_ATTACK_RANGE
	return attack_range * size


func is_paladin() -> bool:
	return pet_class() == "paladin"
