## Drop simulation for the Legendary and set odds (LegendaryDB): plays each
## area 5-16 1000 times on generated layouts (monsters, Alphas, vases, the
## boss) and prints Legendaries and set pieces per run. Run with:
##   godot --headless -s scripts/tools/dropsim.gd
extends SceneTree
func _init():
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var hist_all := {}
	print("area  levels  items/run  legendaries/run   P(0)  P(1)  P(2+)   sets/run")
	for area in range(5, 17):
		var runs := 1000
		var legs := 0; var items := 0; var sets := 0
		var hist := {0: 0, 1: 0, 2: 0}
		for r in runs:
			var L := LevelGenerator.generate(rng.randi(), area)
			var groups := {}
			for sp in L.creature_spots: groups[sp.get("group", -1)] = true
			var alphas := groups.size()
			var normal: int = L.creature_spots.size() - alphas
			var drops := []  # [chance, boss, extra_legendary]
			for i in normal: drops.append([0.08, false, 0.0])
			for i in alphas: drops.append([0.35, false, 0.0])
			for c in L.crate_spots: drops.append([0.5 if c.gold else 0.12, false, 0.0])
			if BiomeDB.has_named_boss(area):
				drops.append([1.0, true, 0.1]); drops.append([1.0, true, 0.0]); drops.append([1.0, true, 0.0])
			else:
				drops.append([1.0, true, 0.0]); drops.append([1.0, true, 0.0])
			var got := 0
			for d in drops:
				if rng.randf() >= d[0]: continue
				items += 1
				if LegendaryDB.sets_drop_in(area) and rng.randf() < LegendaryDB.SET_CHANCE:
					sets += 1; continue
				var odds: float = (LegendaryDB.BOSS_LEGENDARY_CHANCE if d[1] else LegendaryDB.LEGENDARY_CHANCE) + d[2]
				if rng.randf() < odds: got += 1
			legs += got
			hist[mini(got, 2)] += 1
		print("%4d  %d-%d  %9.1f  %15.2f   %3d%%  %3d%%  %3d%%   %8.2f" % [area, 1 + (area - 1) * 5, area * 5, items / float(runs), legs / float(runs),
				100 * hist[0] / runs, 100 * hist[1] / runs, 100 * hist[2] / runs, sets / float(runs)])
	quit()
