class_name CreatureSpecies
extends Resource
## Data for one kind of creature. Add a new .tres in resources/species and
## list it in SpeciesDB to add it to the world.

@export var display_name := "Creature"
@export var color := Color.WHITE
@export var size := 1.0
## The body the creature is built with (see CreatureModel). Each biome has its own.
@export_enum("cat", "bird", "dog", "lizard", "skeleton", "zombie", "mummy", "scorpion", "imp", "golem", "wraith",
		"yeti") var body_type := "cat"
## An extra body detail for this species (see CreatureModel).
@export_enum("none", "big_ears", "spines", "horn", "mane", "wings", "crown") var feature := "none"

## Each kind of body fights its own way. Cats are wizards: their attacks are
## magic bolts fired from range, and their abilities are spells. Dogs are
## paladins: melee tanks with more health and less damage taken, whose hits
## come with Healing Kisses for the most injured ally nearby, who draw wild enemies' attention, and
## whose abilities heal and protect. Birds are archers: they shoot arrows
## from further than anyone, hop back from enemies that get too close, and
## their abilities are all ranged shots. Lizards are venomancers: their bites
## do less up front but stack venom that ticks on, anything that hits them up
## close is poisoned back, and their abilities all poison.
const CLASS_BY_BODY := {"cat": "wizard", "dog": "paladin", "bird": "archer", "lizard": "venomancer"}
const VENOM_HIT_SHARE := 0.7  ## A venomancer's bite does this share of its damage up front...
const VENOM_STACK := 0.4  ## ...and adds this much of its damage per second as venom,
const VENOM_DURATION := 4.0  ## lasting this long,
const VENOM_MAX := 1.2  ## stacking up to this much of its damage per second (3 bites).
## Critical hits on basic attacks: archers are the sharpest shots.
const BASE_CRIT := 0.05
const ARCHER_CRIT := 0.15
const CRIT_MULTIPLIER := 2.0
## Tamed venomancers (lizards) deal this share of their damage: bites, venom,
## toxic blood and abilities. They cleared the game about 35% faster than the
## other families in playtests. Wild lizards keep their full damage.
const VENOMANCER_PET_DAMAGE := 0.65
const TOXIC_BLOOD := 0.25  ## Poison per second (share of its damage) given to what hits it up close.
const PALADIN_HEALTH := 1.35  ## Max health multiplier.
## Wizards (cats) are glass cannons: fragile, but their spells come back fast
## and hit hard.
const WIZARD_HEALTH := 0.7  ## Max health multiplier.
const WIZARD_COOLDOWN := 1.5  ## Seconds between abilities (others: the ability's own, 3s).
const WIZARD_SPELL_DAMAGE := 1.3  ## Ability damage multiplier.
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
## An archer's basic shot: "" a plain arrow, "dust" an arrow tearing up a wake
## of dust and pebbles, with sparks where it hits (DustShotFX).
@export var shot_look := ""

## Monsters that fight from range (fire imps, frost wraiths): magic bolts like a wizard's.
@export var ranged_attack := false

@export_group("Taming")
## 0..1. Higher = easier to capture. Capture chance also scales with missing health.
@export var catch_rate := 0.5
@export var xp_reward := 10

@export_group("Pet")
## Triggered by the owner with the ability key for this pet's party slot.
@export var ability: PetAbility


## The species' class ("wizard", "paladin", "archer", "venomancer", or "" for none).
func pet_class() -> String:
	return CLASS_BY_BODY.get(body_type, "")


func is_wizard() -> bool:
	return pet_class() == "wizard"


func is_ranged() -> bool:
	return pet_class() == "wizard" or pet_class() == "archer" or ranged_attack


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


func is_venomancer() -> bool:
	return pet_class() == "venomancer"
