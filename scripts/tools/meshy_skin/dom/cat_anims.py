# Dom's animations, built with quad_lib.py (planted paws, rotation sense, helpers).
import numpy as np
TAU = 2 * np.pi

# --- the animations ---------------------------------------------------------------

def walk(t):
	T = 1.0; ph = TAU * t / T; f = {}; planted(f)
	walk_like(t, T, {'RL': 0.0, 'FL': 0.25, 'RR': 0.5, 'FR': 0.75}, 0.5, 0.64, 0.08, f)
	f['Hips'] = (0, 0.06 * np.sin(ph), 0.02 * np.sin(ph))
	f['Spine1'] = (0, -0.03 * np.sin(ph), 0); f['Spine2'] = (0, -0.03 * np.sin(ph + 0.4), 0)
	f['Chest'] = (0, -0.05 * np.sin(ph + 0.8), -0.02 * np.sin(ph + 0.8))
	f['Neck'] = (0.03 * np.sin(2 * ph), 0, 0)
	steady_head(f); ears(f, 0.05)
	tail(f, t, 0.22, 1 / T, lift=-0.05, curl=0.1)
	f['_offset'] = (0, -0.01 + 0.012 * np.cos(2 * ph), 0)
	return finish(f)


def run(t):
	T = 0.5; ph = TAU * t / T; f = {}; planted(f)
	walk_like(t, T, {'FL': 0.0, 'FR': 0.07, 'RL': 0.5, 'RR': 0.57}, 1.1, 0.34, 0.16, f)
	flex = np.sin(ph - 0.6)  # the spine gathers as the hind legs reach forward, stretches as they push
	f['Hips'] = (0.16 * flex, 0, 0); f['Spine1'] = (-0.12 * flex, 0, 0); f['Spine2'] = (-0.08 * flex, 0, 0)
	f['Chest'] = (0.06 * flex, 0, 0)
	steady_head(f, 0.9); ears(f, 0.35)
	tail(f, t, 0.1, 1 / T, lift=-0.35, curl=0.15)
	f['_offset'] = (0, 0.035 * np.sin(2 * ph + 0.5) - 0.02, 0.02 * flex)
	return finish(f)


def idle(t):
	T = 4.0; ph = TAU * t / T; f = {}; planted(f)
	breath = np.sin(3 * ph)
	f['Spine2'] = (0.012 * breath, 0, 0); f['Chest'] = (-0.01 * breath, 0, 0)
	look = 0.22 * np.sin(ph) + 0.07 * np.sin(3 * ph + 1.0)
	f['Hips'] = (0, 0.02 * np.sin(ph + 0.5), 0.015 * np.sin(ph))
	f['Neck'] = (0.03 * np.sin(2 * ph), look * 0.6, 0); f['Head'] = (0.04 * np.sin(2 * ph + 1), look * 0.4, 0.05 * np.sin(ph))
	twl = -0.5 * env(t, 1.2, 1.28, 1.32, 1.45); twr = -0.5 * env(t, 2.9, 2.98, 3.02, 3.15)
	ears(f, 0.0, 0.0, twl, twr)
	tail(f, t, 0.45, 1 / T, lift=0.0, curl=0.25, lag=0.9)
	f['_offset'] = (0.012 * np.sin(ph), 0.004 * breath, 0)
	return finish(f)


def swipe(t):
	f = {}; planted(f)
	cock = env(t, 0.0, 0.18, 0.2, 0.28)  # weight back, paw drawn up and back
	strike = env(t, 0.2, 0.28, 0.36, 0.55)  # whips down and forward
	drag = env(t, 0.32, 0.42, 0.45, 0.72)  # claws rake back to the ground
	f['Spine1'] = (-0.05 * cock, 0, 0); f['Chest'] = (-0.16 * cock + 0.1 * strike, 0.1 * strike, 0)
	f['Hips'] = (0.06 * cock - 0.04 * strike, 0, 0)
	paw = rest_foot('FR')
	paw += np.array([0.03, 0.42, -0.02]) * cock + np.array([-0.04, -0.3, 0.34]) * strike + np.array([0, -0.12, -0.2]) * drag
	paw[1] = max(paw[1], END['FR'][1])
	f['_feet']['FR'] = (paw, 0.9 * cock - 0.5 * strike)
	f['FR_Scap'] = (-0.3 * cock - 0.25 * strike, 0, 0)
	f['Neck'] = (0.1 * strike, 0, 0); f['Head'] = (-0.1 * cock + 0.12 * strike, 0.1 * strike, 0)
	f['Jaw'] = (0.3 * env(t, 0.15, 0.25, 0.4, 0.6), 0, 0)
	ears(f, 0.5 * env(t, 0.0, 0.15, 0.5, 0.75))
	tail(f, t, 0.25 + 0.35 * strike, 1.4, lift=0.15 * cock)
	f['_offset'] = (0, 0.04 * cock - 0.02 * strike, -0.04 * cock + 0.06 * strike)
	return finish(f)


def pounce(t):
	f = {}; planted(f)
	crouch = env(t, 0.0, 0.14, 0.4, 0.48)
	wiggle = np.sin(TAU * t * 7) * env(t, 0.12, 0.2, 0.36, 0.42)
	push = env(t, 0.4, 0.48, 0.5, 0.56)  # hind legs drive up and forward
	air = env(t, 0.46, 0.56, 0.68, 0.8)
	land = env(t, 0.72, 0.8, 0.84, 1.0)
	f['Hips'] = (0.05 * crouch - 0.12 * air, 0.14 * wiggle, 0.04 * wiggle)
	f['Spine1'] = (0.08 * crouch - 0.08 * air, -0.05 * wiggle, 0); f['Spine2'] = (0.05 * crouch - 0.06 * air, 0, 0)
	f['Chest'] = (0.12 * crouch - 0.12 * air + 0.1 * land, 0, 0)
	f['Head'] = (-0.25 * crouch + 0.1 * air, 0, 0); f['Neck'] = (0.15 * crouch, 0, 0)
	f['Jaw'] = (0.35 * air, 0, 0)
	ears(f, -0.15 * crouch + 0.4 * air)
	tail(f, t, 0.12 * crouch, 3.5, lift=-0.5 * crouch + 0.25 * air, curl=0.2 * crouch)
	f['_offset'] = (0.02 * wiggle, -0.15 * crouch + 0.12 * air - 0.05 * land, 0.12 * air + 0.04 * push)
	# planted for the crouch and landing, legs flung out in the air
	f = finish(f)
	if air > 0:
		for s in 'LR':
			for b, fk_angle in [('F%s_Upper' % s, -0.85), ('F%s_Lower' % s, 0.25), ('F%s_Paw' % s, -0.3),
								('R%s_Upper' % s, 0.65), ('R%s_Lower' % s, -0.1), ('R%s_Paw' % s, 0.45)]:
				e = f.get(b, (0, 0, 0))
				f[b] = (e[0] * (1 - air) + fk_angle * air, 0, 0)
		for s in 'LR':
			e = f.get('F%s_Scap' % s, (0, 0, 0)); f['F%s_Scap' % s] = (e[0] - 0.3 * air, 0, 0)
	return f


def retch(t):
	f = {}; planted(f)
	low = env(t, 0.0, 0.25, 1.35, 1.6)
	heaves = [0.45, 0.78, 1.08]
	heave = sum(env(t, h - 0.1, h, h + 0.02, h + 0.16) for h in heaves)
	hurl = env(t, 1.18, 1.26, 1.3, 1.45)
	f['Spine1'] = (-0.14 * low - 0.22 * heave - 0.1 * hurl, 0, 0); f['Spine2'] = (-0.08 * low - 0.15 * heave, 0, 0)
	f['Chest'] = (0.18 * low + 0.18 * heave + 0.12 * hurl, 0, 0)
	f['Neck'] = (0.4 * low + 0.12 * heave + 0.2 * hurl, 0, 0); f['Head'] = (-0.15 * low - 0.1 * heave - 0.15 * hurl, 0, 0)
	f['Jaw'] = (0.12 * heave + 0.45 * hurl, 0, 0)
	ears(f, 0.6 * low)
	tail(f, t, 0.06, 1.0, lift=-0.4 * low)
	f['_offset'] = (0, -0.03 * low + 0.025 * heave, -0.02 * low + 0.02 * hurl)
	return finish(f)


def hiss(t):
	f = {}; planted(f)
	arch = env(t, 0.0, 0.25, 1.15, 1.4)
	open_ = env(t, 0.18, 0.3, 1.0, 1.2)
	tremble = np.sin(TAU * t * 11) * open_
	f['Hips'] = (0.12 * arch, 0.12 * arch, 0); f['Spine1'] = (-0.32 * arch, 0.06 * arch, 0)
	f['Spine2'] = (-0.12 * arch, 0, 0); f['Chest'] = (0.3 * arch, -0.1 * arch, 0)
	f['Neck'] = (0.12 * arch, -0.1 * arch, 0); f['Head'] = (-0.3 * open_ + 0.02 * tremble, -0.08 * arch, 0)
	f['Jaw'] = (0.45 * open_, 0, 0)
	ears(f, 1.0 * arch, 0.35 * arch)
	for k in range(4):  # bottle-brush tail, straight up, quivering
		f['Tail%d' % (k + 1)] = ((0.65 if k == 0 else -0.05) * arch, 0.03 * tremble, 0)
	f['_offset'] = (0, 0.07 * arch, -0.03 * arch)  # up on stiff legs
	return finish(f)


anims.update({'Idle': (4.0, idle), 'Walk': (1.0, walk), 'Run': (0.5, run), 'Swipe': (0.75, swipe),
			  'Pounce': (1.0, pounce), 'Retch': (1.6, retch), 'Hiss': (1.4, hiss)})
