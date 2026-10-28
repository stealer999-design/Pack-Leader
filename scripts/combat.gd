class_name Combat
## Combat rules shared by everything that deals damage.
##
## There are two sides:
## - HOSTILE: wild creatures, rival tamers and the rivals' pets.
## - TAMERS: every player and every player's pets.
## Nothing can damage or target something on its own side, so there is no
## friendly fire between pets, players, or different players.

enum Faction { HOSTILE, TAMERS }


static func faction_of(node: Node) -> Faction:
	if node is Rival:
		return Faction.HOSTILE
	if node is Creature and not node.is_player_pet():
		return Faction.HOSTILE
	return Faction.TAMERS


static func are_enemies(a: Node, b: Node) -> bool:
	return is_instance_valid(a) and is_instance_valid(b) and a != b and faction_of(a) != faction_of(b)
