# The dog pets' animations (all ten share these), built with quad_lib.py on the
# skeleton dog/autofit.py fits (Koleko's bone names). After Koleko's: a walk
# (each paw in turn, left hind, left fore, right hind, right fore), a trot for
# the run, an alert idle, a lunging bite (Swipe, the attack) and a rallying bark
# with the head thrown up (Hiss, the ability). Ears and wings move when the
# rig has them.
import numpy as np

WALK_T = 0.72  # seconds per cycle
WALK_TRAVEL = 0.62  # rig units the body covers per cycle (the pace is travel / T)
RUN_T = 0.46
RUN_TRAVEL = 0.82
HAS_WINGS = 'WingL' in idx


def wings(f, spread, flap=0.0):
	"""folded wings: `spread` opens them out from the back, `flap` beats them"""
	if HAS_WINGS:
		f['WingL'] = (0.1 * flap, 0, -spread - flap)
		f['WingR'] = (0.1 * flap, 0, spread + flap)


def walk(t):
	T = WALK_T; ph = TAU * t / T; f = {}; planted(f)
	walk_like(t, T, {'RL': 0.0, 'FL': 0.25, 'RR': 0.5, 'FR': 0.75}, WALK_TRAVEL, 0.62, 0.07, f)
	f['Hips'] = (0, 0.04 * np.sin(ph), 0.025 * np.sin(ph))
	f['Spine1'] = (0, -0.02 * np.sin(ph), 0); f['Spine2'] = (0, -0.02 * np.sin(ph + 0.4), 0)
	f['Chest'] = (0, -0.04 * np.sin(ph + 0.8), -0.025 * np.sin(ph + 0.8))
	f['Neck'] = (0.04 + 0.03 * np.sin(2 * ph), 0, 0)  # a little nod on each step
	steady_head(f, 0.75)
	tail(f, t, 0.22, 1 / T, lift=0.05, curl=0.06)
	ears(f, back=0.05)
	wings(f, 0.0, 0.05 * np.sin(2 * ph))
	f['_offset'] = (0, -0.008 + 0.012 * np.cos(2 * ph), 0)
	return finish(f)


def run(t):
	"""a trot: diagonal pairs strike together, a moment of float between"""
	T = RUN_T; ph = TAU * t / T; f = {}; planted(f)
	walk_like(t, T, {'FL': 0.0, 'RR': 0.0, 'FR': 0.5, 'RL': 0.5}, RUN_TRAVEL, 0.46, 0.1, f, fore_reach=0.1)
	f['Hips'] = (0, 0.03 * np.sin(ph), 0.03 * np.sin(ph)); f['Chest'] = (0, -0.03 * np.sin(ph), -0.03 * np.sin(ph))
	f['Spine1'] = (0.012 * np.sin(2 * ph), 0, 0)
	f['Neck'] = (0.08, 0, 0)
	steady_head(f, 0.9)
	f['Jaw'] = (0.1 + 0.04 * np.sin(2 * ph), 0, 0)  # panting
	tail(f, t, 0.12, 1 / T, lift=0.1, curl=0.08)
	ears(f, back=0.25)
	wings(f, 0.08, 0.12 * np.sin(2 * ph))
	f['_offset'] = (0, -0.03 + 0.016 * np.cos(2 * ph), 0)
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
	f['Chest'] = (-0.05 * draw + 0.1 * lunge, 0, 0); f['Hips'] = (0.03 * draw - 0.03 * lunge, 0, 0)
	f['Neck'] = (-0.15 * draw + 0.22 * lunge, 0.14 * shake, 0)
	f['Head'] = (-0.1 * draw + 0.06 * lunge, 0.1 * shake, 0.08 * shake)
	f['Jaw'] = (0.08 + 0.4 * env(t, 0.06, 0.22, 0.24, 0.28) - 0.08 * snap, 0, 0)
	for leg in ('FL', 'FR'):
		f['%s_Scap' % leg] = (-0.12 * lunge, 0, 0)
	tail(f, t, 0.12 + 0.15 * lunge, 1.3, lift=0.12 * draw)
	ears(f, back=0.4 * lunge)
	wings(f, 0.2 * draw)
	f['_offset'] = (0, 0.01 * draw - 0.03 * lunge, -0.04 * draw + 0.1 * lunge)
	return finish(f)


def hiss(t):
	"""the ability: a rallying bark, rocking back with the head thrown up, two barks"""
	f = {}; planted(f)
	up = env(t, 0.0, 0.22, 0.75, 1.0)
	bark = env(t, 0.25, 0.32, 0.36, 0.44) + env(t, 0.5, 0.57, 0.61, 0.7)
	f['Hips'] = (0.08 * up, 0, 0); f['Spine1'] = (-0.05 * up, 0, 0); f['Spine2'] = (-0.04 * up, 0, 0)
	f['Chest'] = (-0.1 * up, 0, 0)
	f['Neck'] = (-0.32 * up - 0.06 * bark, 0, 0); f['Head'] = (-0.2 * up + 0.04 * bark, 0, 0)
	f['Jaw'] = (0.06 + 0.42 * bark, 0, 0)
	tail(f, t, 0.3 * up, 2.5, lift=0.25 * up)
	ears(f, back=-0.1 * up)
	wings(f, 0.6 * up, 0.08 * np.sin(TAU * t * 6) * up)  # Solarjackal spreads its wings wide
	f['_offset'] = (0, -0.03 * up, -0.03 * up)  # rocks back onto the hind legs
	return finish(f)


anims.update({'Idle': (4.0, idle), 'Walk': (WALK_T, walk), 'Run': (RUN_T, run), 'Swipe': (0.7, swipe), 'Hiss': (1.0, hiss)})
