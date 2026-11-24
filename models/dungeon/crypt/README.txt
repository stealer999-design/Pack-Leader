gothic_pillar_lite.scn: the crypt's pillar, a gothic column supplied for the game
(gothic_pillar.glb, 594k triangles), baked down to ~54k triangles by
scripts/tools/simplify_model.gd (Godot's own mesh simplifier):
  godot --headless -s scripts/tools/simplify_model.gd -- <gothic_pillar.glb> res://models/dungeon/crypt/gothic_pillar_lite.scn 60000
gothic_pillar_0.jpg / _1.png are its textures.
