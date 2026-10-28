class_name CreatureSpecies
extends Resource
## Data for one kind of creature. Add a new .tres in resources/species and
## list it in SpeciesDB to add it to the world.

@export var display_name := "Creature"
@export var color := Color.WHITE
@export var size := 1.0

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

@export_group("Taming")
## 0..1. Higher = easier to capture. Capture chance also scales with missing health.
@export var catch_rate := 0.5
@export var xp_reward := 10

@export_group("Pet")
## Triggered by the owner with the ability key for this pet's party slot.
@export var ability: PetAbility
