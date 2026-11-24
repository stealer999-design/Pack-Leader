stone_pillar.glb: the crypt's pillar, a slender dark stone column supplied for the game
(26k triangles), one in the middle of each room (DungeonDB "crypt").
crown_moulding_lite.res: the crypt's crown moulding (fancy_crown_moulding.glb, supplied
for the game, 71k triangles), baked down to ~3.8k triangles for repeating along every
wall top by scripts/tools/cluster_model.gd:
  godot --headless -s scripts/tools/cluster_model.gd -- <fancy_crown_moulding.glb> res://models/dungeon/crypt/crown_moulding_lite.res 34
