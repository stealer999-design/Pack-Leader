class_name RootAbility
extends PetAbility
## Mud Trap: the pet hides a pool of sticky mud on the ground where it stands.
## The first enemy to step on it springs it: every enemy within `radius` is
## damaged and rooted (can't move).

@export var root_duration := 2.5
## How close an enemy must come to spring the trap.
@export var trigger_radius := 1.5
## Seconds an unsprung trap lasts.
@export var trap_duration := 30.0
## Traps one pet can have out at once; laying another removes the oldest.
@export var max_traps := 3


func execute(pet: Creature, _point: Vector3, _target: Creature) -> void:
	var world := pet.world
	var at := world.clamp_to_level(pet.global_position)
	world.add_trap(pet, at, trigger_radius, trap_duration, max_traps, func(trap_pos: Vector3) -> void:
		var damage := pet.get_damage() * damage_multiplier
		for enemy in world.enemies_near(pet, trap_pos, radius):
			enemy.receive_damage(damage, pet)
			if enemy.has_method("slow"):
				enemy.slow(root_duration, 0.0)
		world.play_burst.rpc(trap_pos, Color(0.45, 0.32, 0.18), radius), Color(0.45, 0.32, 0.18))
