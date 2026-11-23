# The cat pets' animations: Dom's (dom/cat_anims.py) with a new walk, after the
# user's walking-cat reference (a white cat on pink): short, even steps in the
# cat's lateral sequence (each hind paw a quarter-cycle ahead of the fore paw on
# its side), the fore leg kept a straight column that folds only at the wrist as
# it lifts and lands just ahead of the chest, the hind leg keeping its Z and
# folding at the hock, the body low and level with a gentle bob.
# (Listed after dom/cat_anims.py in a config's 'anims': it replaces only the walk.)

WALK_T = 0.8  # seconds per cycle
WALK_TRAVEL = 0.62  # how far the body moves per cycle (pace = travel / T)
WALK_DUTY = 0.64  # share of the cycle each paw is down
FORE_REACH = 0.1  # the furthest a fore paw lands ahead of where it stands
FORE_LIFT = 0.35  # share of the paws' lift the fore paws take


def walk(t):
	T = WALK_T; ph = TAU * t / T; f = {}; planted(f)
	walk_like(t, T, {'RL': 0.0, 'FL': 0.25, 'RR': 0.5, 'FR': 0.75}, WALK_TRAVEL, WALK_DUTY, 0.07, f, fore_reach=FORE_REACH)
	for leg in ('FL', 'FR'):  # the fore paw barely lifts and folds back at the wrist instead, so
		foot, flex = f['_feet'][leg]  # the elbow never rides up into the chest
		foot = foot.copy(); foot[1] = rest_foot(leg)[1] + (foot[1] - rest_foot(leg)[1]) * FORE_LIFT
		f['_feet'][leg] = (foot, flex * 2.4)
	for leg in ('RL', 'RR'):  # the hind paw curls at the hock
		foot, flex = f['_feet'][leg]; f['_feet'][leg] = (foot, flex * 1.6)
	sway = np.sin(ph)
	f['Hips'] = (0, 0.04 * sway, 0.02 * sway)
	f['Spine1'] = (0, -0.02 * sway, 0); f['Spine2'] = (0, -0.02 * np.sin(ph + 0.4), 0)
	f['Chest'] = (0, -0.04 * np.sin(ph + 0.8), -0.02 * np.sin(ph + 0.8))
	f['Neck'] = (0.08 + 0.02 * np.sin(2 * ph), 0, 0)  # head carried a little low, as in the reference
	steady_head(f); ears(f, 0.05)
	tail(f, t, 0.15, 1 / T, lift=-0.03, curl=0.12)
	f['_offset'] = (0, -0.02 + 0.01 * np.cos(2 * ph), 0)
	return finish(f)


anims['Walk'] = (WALK_T, walk)
