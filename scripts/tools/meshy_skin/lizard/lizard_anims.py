# The lizards' animations (all of them share these), built with lizard_lib.py.
# Walk follows the reference: a sprawling trot, diagonal pairs stepping
# together, the spine swinging side to side and the tail swinging against it.
# Swipe is the attack (a darting bite), Hiss the ability (rearing up, jaws wide).
import numpy as np

WALK_T = 0.5  # seconds per cycle (two diagonal steps)
WALK_TRAVEL = 0.7  # rig units the body covers per cycle (pace = travel / T)


def walk(t):
	f = {}; planted(f)
	ph = gait(f, t, WALK_T, WALK_TRAVEL, 0.6, 0.09, 0.2, 0.04)
	f['_offset'] = (0, -0.07 + 0.01 * np.cos(2 * ph), 0)  # crouched low (the legs reach further), a slight bob
	f['Jaw'] = (0.0, 0, 0)
	return finish(f)


def run(t):
	T = 0.4; f = {}; planted(f)
	ph = gait(f, t, T, WALK_TRAVEL, 0.5, 0.12, 0.3, 0.06)
	f['_offset'] = (0, -0.07 + 0.015 * np.cos(2 * ph), 0)
	return finish(f)


def idle(t):
	T = 4.0; ph = TAU * t / T; f = {}; planted(f)
	breathe = np.sin(TAU * t * 0.75)  # 3 breaths a loop
	look = 0.28 * np.sin(ph) + 0.1 * np.sin(3 * ph + 1.0)
	f['Hips'] = (0, 0.03 * np.sin(ph + 0.5), 0)
	f['Chest'] = (-0.015 * breathe, 0, 0)
	f['Neck'] = (0.03 * np.sin(2 * ph), look * 0.5, 0.05 * np.sin(ph))
	f['Head'] = (0.02 * np.sin(2 * ph + 1), look * 0.5, 0.06 * np.sin(ph + 0.4))
	f['Jaw'] = (0.04 * max(0.0, np.sin(TAU * t * 1.5)) * env(t % 2.0, 1.2, 1.3, 1.6, 1.8), 0, 0)  # a little gulp
	for k, b in enumerate(TAILS):
		f[b] = (0, (0.08 - 0.02 * k) * np.sin(ph - 0.8 * k), 0)
	f['_offset'] = (0, 0.006 * breathe, 0)
	return finish(f)


def swipe(t):
	"""the attack: draws back, darts forward with a snapping bite, recovers"""
	f = {}; planted(f)
	draw = env(t, 0.0, 0.14, 0.16, 0.24)
	dart = env(t, 0.16, 0.26, 0.32, 0.55)
	snap = env(t, 0.24, 0.27, 0.3, 0.36)
	f['Hips'] = (0.03 * draw - 0.03 * dart, 0, 0)
	f['Chest'] = (-0.08 * draw + 0.1 * dart, 0, 0)
	f['Neck'] = (-0.25 * draw + 0.28 * dart, 0, 0)
	f['Head'] = (-0.12 * draw + 0.1 * dart, 0, 0)
	f['Jaw'] = (0.5 * env(t, 0.08, 0.2, 0.24, 0.28) - 0.05 * snap, 0, 0)
	f['Tail1'] = (0, 0.15 * np.sin(TAU * t * 2.5) * dart, 0)
	f['_offset'] = (0, 0.03 * draw - 0.01 * dart, -0.06 * draw + 0.14 * dart)
	return finish(f)


def hiss(t):
	"""the ability: rears up on its fore legs, gapes and hisses, tail lashing"""
	f = {}; planted(f)
	up = env(t, 0.0, 0.25, 0.75, 1.0)
	shake = np.sin(TAU * t * 9) * env(t, 0.25, 0.35, 0.65, 0.8)
	f['Hips'] = (-0.05 * up, 0, 0)
	f['Spine1'] = (-0.12 * up, 0, 0)
	f['Chest'] = (-0.15 * up, 0, 0)
	f['Neck'] = (-0.1 * up + 0.02 * shake, 0.03 * shake, 0)
	f['Head'] = (-0.1 * up, 0, 0)
	f['Jaw'] = (0.55 * env(t, 0.15, 0.3, 0.7, 0.9) + 0.04 * shake, 0, 0)
	for k, b in enumerate(TAILS):
		f[b] = (0, (0.35 - 0.1 * k) * TAIL_K * np.sin(TAU * t * 3 - k) * up, 0)
	f['_offset'] = (0, 0.06 * up, -0.03 * up)
	return finish(f)


anims.update({'Idle': (4.0, idle), 'Walk': (WALK_T, walk), 'Run': (0.4, run), 'Swipe': (0.6, swipe), 'Hiss': (1.0, hiss)})
