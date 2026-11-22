# The dog pets' animations (all ten share these), built with quad_lib.py on the
# skeleton dog/autofit.py fits (Koleko's bone names). A trot after the user's
# reference, the dogs' only gait (the game speeds it up or slows it down), an alert idle, a lunging bite (Swipe, the attack) and a rallying bark
# with the head thrown up (Hiss, the ability). Ears and wings move when the
# rig has them.
import numpy as np

WALK_T = 0.5  # seconds per cycle (two diagonal beats)
WALK_TRAVEL = 0.84  # rig units the body covers per cycle (the pace is travel / T)
HAS_WINGS = 'WingL' in idx


def wings(f, spread, flap=0.0):
	"""folded wings: `spread` opens them out from the back, `flap` beats them"""
	if HAS_WINGS:
		f['WingL'] = (0.1 * flap, 0, -spread - flap)
		f['WingR'] = (0.1 * flap, 0, spread + flap)


def walk(t):
	"""the reference's trot (played at every speed): diagonal pairs strike together, left
	fore with right hind, then right fore with left hind, with a moment of float between.
	The body rises off each push and dips as the pair lands, rocking a little nose to
	tail; the head nods with each beat; the paws fold up as they swing through; the tail
	streams out behind, bouncing with the body"""
	T = WALK_T; ph = TAU * t / T; f = {}; planted(f)
	walk_like(t, T, {'FL': 0.0, 'RR': 0.0, 'FR': 0.5, 'RL': 0.5}, WALK_TRAVEL, 0.44, 0.13, f, fore_reach=0.12)
	for leg in ('FL', 'FR'):  # the fore paw flicks up and folds as it swings
		foot, flex = f['_feet'][leg]; f['_feet'][leg] = (foot, flex * 2.0)
	for leg in ('RL', 'RR'):  # the hind paw curls back
		foot, flex = f['_feet'][leg]; f['_feet'][leg] = (foot, flex * 2.4)
	beat = np.cos(2 * ph)  # two beats a cycle: +1 just after a pair lands, -1 at the top of the float
	rock = np.sin(2 * ph)  # nose dips as the fore paw takes the weight, rises as the hind pushes
	f['Hips'] = (0.04 * rock, 0.035 * np.sin(ph), 0.035 * np.sin(ph))
	f['Spine1'] = (-0.02 * rock, 0, 0); f['Spine2'] = (-0.015 * rock, 0, 0)
	f['Chest'] = (-0.02 * rock, -0.035 * np.sin(ph), -0.035 * np.sin(ph))
	f['Neck'] = (0.03 + 0.03 * beat, 0, 0)
	steady_head(f, 0.6)
	f['Head'] = (f['Head'][0] + 0.04 * beat, f['Head'][1], f['Head'][2])  # the nod, lagging a touch
	f['Jaw'] = (0.08 + 0.03 * np.sin(2 * ph), 0, 0)  # panting
	tail(f, t, 0.1, 1 / T, lift=0.06 + 0.05 * beat, curl=0.05)
	ears(f, back=0.15 + 0.08 * beat)
	wings(f, 0.04, 0.08 * beat)
	f['_offset'] = (0, -0.025 - 0.035 * beat, 0)  # rises in the float, dips on landing: clearly seen
	return finish(f)


def idle(t):
	T = 4.0; ph = TAU * t / T; f = {}; planted(f)
	pant = np.sin(TAU * t * 2.0)  # 8 pants over the loop
	f['Spine2'] = (0.01 * pant, 0, 0); f['Chest'] = (-0.01 * pant, 0, 0)
	look = 0.22 * np.sin(ph) + 0.06 * np.sin(3 * ph + 1.0)
	f['Hips'] = (0, 0.015 * np.sin(ph + 0.5), 0.015 * np.sin(ph))
	f['Neck'] = (0.03 * np.sin(2 * ph), look * 0.6, 0); f['Head'] = (0.03 * np.sin(2 * ph + 1), look * 0.4, 0.05 * np.sin(ph))
	f['Jaw'] = (0.08 + 0.05 * pant, 0, 0)
	tail(f, t, 0.35, 0.5, lift=0.05, curl=0.12, lag=0.9)  # a slow, happy wag
	ears(f, back=0.0, twitch_l=0.25 * env(t % 2.0, 0.6, 0.7, 0.75, 0.9), twitch_r=0.25 * env(t % 2.0, 1.4, 1.5, 1.55, 1.7))
	wings(f, 0.03 * np.sin(ph))
	f['_offset'] = (0.006 * np.sin(ph), 0.004 * pant, 0)
	return finish(f)


def swipe(t):
	"""the attack: draws back, lunges with jaws wide, snaps them shut and shakes"""
	f = {}; planted(f)
	draw = env(t, 0.0, 0.14, 0.16, 0.24)
	lunge = env(t, 0.14, 0.24, 0.3, 0.55)
	snap = env(t, 0.24, 0.28, 0.32, 0.38)
	shake = np.sin(TAU * t * 9) * env(t, 0.28, 0.34, 0.42, 0.52)
	f['Spine2'] = (-0.03 * draw + 0.05 * lunge, 0, 0)
	f['Chest'] = (-0.06 * draw + 0.1 * lunge, 0.04 * shake, 0); f['Hips'] = (0.03 * draw - 0.03 * lunge, 0, 0)
	f['Neck'] = (0, 0, 0)  # the neck holds still (bending it stretches the withers); the head does the work
	f['Head'] = (-0.18 * draw + 0.18 * lunge, 0.17 * shake, 0.08 * shake)
	f['Jaw'] = (0.06 + 0.3 * env(t, 0.06, 0.22, 0.24, 0.28) - 0.06 * snap, 0, 0)
	for leg in ('FL', 'FR'):
		f['%s_Scap' % leg] = (-0.12 * lunge, 0, 0)
	tail(f, t, 0.12 + 0.15 * lunge, 1.3, lift=0.12 * draw)
	ears(f, back=0.4 * lunge)
	wings(f, 0.12 * draw)
	f['_offset'] = (0, 0.01 * draw - 0.03 * lunge, -0.04 * draw + 0.1 * lunge)
	return finish(f)


def hiss(t):
	"""the ability: a rallying bark, rocking back with the head thrown up, two barks"""
	f = {}; planted(f)
	up = env(t, 0.0, 0.22, 0.75, 1.0)
	bark = env(t, 0.25, 0.32, 0.36, 0.44) + env(t, 0.5, 0.57, 0.61, 0.7)
	f['Hips'] = (0.08 * up, 0, 0); f['Spine1'] = (-0.06 * up, 0, 0); f['Spine2'] = (-0.07 * up, 0, 0)
	f['Chest'] = (-0.12 * up, 0, 0)
	f['Neck'] = (0, 0, 0); f['Head'] = (-0.42 * up + 0.03 * bark, 0, 0)
	f['Jaw'] = (0.06 + 0.42 * bark, 0, 0)
	tail(f, t, 0.3 * up, 2.5, lift=0.25 * up)
	ears(f, back=-0.1 * up)
	wings(f, 0.35 * up, 0.05 * np.sin(TAU * t * 6) * up)  # Solarjackal spreads its wings wide
	f['_offset'] = (0, -0.03 * up, -0.03 * up)  # rocks back onto the hind legs
	return finish(f)


# (run() is kept for later: the game plays the walk, faster, at every speed for now)
anims.update({'Idle': (4.0, idle), 'Walk': (WALK_T, walk), 'Swipe': (0.7, swipe), 'Hiss': (1.0, hiss)})
