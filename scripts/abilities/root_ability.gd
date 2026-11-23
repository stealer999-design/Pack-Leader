class_name RootAbility
extends PetAbility
## Mud Trap: the pet hides a pool of sticky mud on the ground where you aim.
## The first enemy to step on it springs it: every enemy within `radius` is
## damaged and rooted (can't move).

@export var root_duration := 2.5
## How close an enemy must come to spring the trap.
@export var trigger_radius := 1.5
## Seconds an unsprung trap lasts.
@export var trap_duration := 30.0
## Traps one pet can have out at once; laying another removes the oldest.
@export var max_traps := 3
## Venom from a sprung trap: poison per second as a share of the pet's damage (0 = none).
@export var poison_dps_multiplier := 0.0
@export var poison_duration := 5.0
## The trap's look (SwampFX): "mud" or "spirit"; "" = the plain brown pool.
@export var look := ""


func execute(pet: Creature, point: Vector3, _target: Creature) -> void:
	var world := pet.world
	var at := world.clamp_to_level(point)  # where you aimed (the pet walks within cast_range first)
	world.add_trap(pet, at, trigger_radius, trap_duration, max_traps, func(trap_pos: Vector3) -> void:
		var damage := pet.ability_damage() * damage_multiplier
		var caught := PackedVector3Array()
		for enemy in world.enemies_near(pet, trap_pos, radius):
			caught.append(enemy.global_position)
			enemy.receive_damage(damage, pet)
			if enemy.has_method("slow"):
				enemy.slow(root_duration, 0.0)
			if poison_dps_multiplier > 0.0 and is_instance_valid(pet):
				pet.envenom(enemy, pet.ability_damage() * poison_dps_multiplier, poison_duration,
						pet.ability_damage() * poison_dps_multiplier)
		if look == "":
			world.play_burst.rpc(trap_pos, Color(0.45, 0.32, 0.18), radius)
		else:
			world.play_pet_fx.rpc("swamp", look + "_spring", trap_pos, trap_pos, radius, root_duration, PackedVector3Array(), caught),
			Color(0.45, 0.32, 0.18), look)
