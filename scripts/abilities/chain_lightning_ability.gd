class_name ChainLightningAbility
extends PetAbility
## Hits the target, then jumps to the nearest other enemies.

@export var chain_count := 3
@export var chain_range := 5.0
## Each jump deals this fraction of the previous hit.
@export var falloff := 0.75


func execute(pet: Creature, _point: Vector3, target: Creature) -> void:
	var hit: Array[Node3D] = []
	var points := PackedVector3Array([pet.global_position + Vector3.UP * 0.6])
	var damage := pet.ability_damage() * damage_multiplier
	var current: Node3D = target
	while current and hit.size() < chain_count:
		hit.append(current)
		points.append(current.global_position + Vector3.UP * 0.6)
		current.receive_damage(damage, pet)
		damage *= falloff
		current = _next_jump(pet, current, hit)
	pet.world.play_lightning.rpc(points)


func _next_jump(pet: Creature, from: Node3D, already_hit: Array[Node3D]) -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for enemy in pet.world.enemies_near(pet, from.global_position, chain_range):
		var d := enemy.global_position.distance_to(from.global_position)
		if enemy not in already_hit and d < best_dist:
			best = enemy
			best_dist = d
	return best
