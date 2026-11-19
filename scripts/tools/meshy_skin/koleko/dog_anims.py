# Koleko's animations, built with quad_lib.py (planted paws, rotation sense, helpers).
# A heavy hellhound: slower, weightier steps than Dom, head carried low, and a
# mouth that really opens (his teeth show in the model).
import numpy as np
TAU = 2 * np.pi


def walk(t):
	T = 1.1; ph = TAU * t / T; f = {}; planted(f)
	walk_like(t, T, {'RL': 0.0, 'FL': 0.25, 'RR': 0.5, 'FR': 0.75}, 0.55, 0.64, 0.09, f)
	f['Hips'] = (0, 0.05 * np.sin(ph), 0.03 * np.sin(ph))
	f['Spine1'] = (0, -0.03 * np.sin(ph), 0); f['Spine2'] = (0, -0.03 * np.sin(ph + 0.4), 0)
	f['Chest'] = (0, -0.05 * np.sin(ph + 0.8), -0.03 * np.sin(ph + 0.8))
	f['Neck'] = (0.08 + 0.04 * np.sin(2 * ph), 0, 0)  # head carried low, nodding with each step
	steady_head(f, 0.7)
	tail(f, t, 0.18, 1 / T, lift=0.0, curl=0.08)
	f['Jaw'] = (0.06 + 0.04 * np.sin(4 * ph), 0, 0)  # panting
	f['_offset'] = (0, -0.012 + 0.015 * np.cos(2 * ph), 0)
	return finish(f)


def run(t):
	T = 0.55; ph = TAU * t / T; f = {}; planted(f)
	walk_like(t, T, {'FL': 0.0, 'FR': 0.1, 'RL': 0.5, 'RR': 0.6}, 1.25, 0.32, 0.17, f)
	flex = np.sin(ph - 0.6)  # gathers as the hind legs reach forward, stretches as they drive
	f['Hips'] = (0.15 * flex, 0, 0); f['Spine1'] = (-0.12 * flex, 0, 0); f['Spine2'] = (-0.08 * flex, 0, 0)
	f['Chest'] = (0.06 * flex, 0, 0); f['Neck'] = (0.12, 0, 0)
	steady_head(f, 0.85)
	f['Jaw'] = (0.18 + 0.06 * np.sin(2 * ph), 0, 0)
	tail(f, t, 0.08, 1 / T, lift=-0.25, curl=0.12)
	f['_offset'] = (0, 0.04 * np.sin(2 * ph + 0.5) - 0.025, 0.02 * flex)
	return finish(f)


def idle(t):
	T = 4.0; ph = TAU * t / T; f = {}; planted(f)
	pant = np.sin(TAU * t * 2.5)  # 10 pants over the loop
	f['Spine2'] = (0.012 * pant, 0, 0); f['Chest'] = (-0.012 * pant, 0, 0)
	look = 0.2 * np.sin(ph) + 0.06 * np.sin(3 * ph + 1.0)
	f['Hips'] = (0, 0.02 * np.sin(ph + 0.5), 0.02 * np.sin(ph))
	f['Neck'] = (0.1 + 0.03 * np.sin(2 * ph), look * 0.6, 0); f['Head'] = (0.03 * np.sin(2 * ph + 1), look * 0.4, 0.04 * np.sin(ph))
	f['Jaw'] = (0.12 + 0.07 * pant, 0, 0)
	tail(f, t, 0.3, 1 / T, curl=0.15, lag=0.9)
	f['_offset'] = (0.012 * np.sin(ph), 0.006 * pant, 0)
	return finish(f)


def bite(t):
	f = {}; planted(f)
	draw = env(t, 0.0, 0.16, 0.18, 0.26)  # head back, lips up
	lunge = env(t, 0.16, 0.26, 0.3, 0.55)  # drives forward, jaws wide
	snap = env(t, 0.26, 0.3, 0.34, 0.4)  # and slams them shut
	shake = np.sin(TAU * t * 9) * env(t, 0.3, 0.36, 0.46, 0.56)
	f['Chest'] = (-0.06 * draw + 0.12 * lunge, 0, 0); f['Hips'] = (0.03 * draw - 0.04 * lunge, 0, 0)
	f['Neck'] = (-0.2 * draw + 0.3 * lunge, 0.18 * shake, 0)
	f['Head'] = (-0.12 * draw + 0.08 * lunge, 0.12 * shake, 0.1 * shake)
	f['Jaw'] = (0.1 + 0.45 * env(t, 0.08, 0.24, 0.26, 0.3) - 0.1 * snap, 0, 0)
	for leg in ('FL', 'FR'):
		f['%s_Scap' % leg] = (-0.15 * lunge, 0, 0)
	tail(f, t, 0.15 + 0.2 * lunge, 1.3, lift=0.15 * draw)
	f['_offset'] = (0, 0.01 * draw - 0.04 * lunge, -0.05 * draw + 0.12 * lunge)
	return finish(f)


def spit(t):
	"""Lava Spit: rears back and draws breath, then heaves his head forward and spits"""
	f = {}; planted(f)
	rear = env(t, 0.0, 0.42, 0.48, 0.6)
	heave = env(t, 0.48, 0.58, 0.68, 1.0)
	gape = env(t, 0.5, 0.56, 0.7, 0.95)
	breathe = np.sin(TAU * t * 3) * env(t, 0.1, 0.2, 0.38, 0.46)
	f['Hips'] = (0.06 * rear, 0, 0); f['Spine1'] = (-0.08 * rear, 0, 0)
	f['Chest'] = (-0.16 * rear + 0.18 * heave + 0.015 * breathe, 0, 0)
	f['Neck'] = (-0.35 * rear + 0.4 * heave, 0, 0); f['Head'] = (-0.2 * rear + 0.1 * heave, 0, 0)
	f['Jaw'] = (0.1 + 0.12 * rear + 0.5 * gape, 0, 0)
	tail(f, t, 0.12, 1.0, lift=0.2 * rear - 0.1 * heave)
	f['_offset'] = (0, 0.03 * rear - 0.03 * heave, -0.06 * rear + 0.07 * heave)
	return finish(f)


def howl(t):
	"""calls his fire imps: settles back on his haunches, muzzle to the sky"""
	f = {}; planted(f)
	up = env(t, 0.0, 0.35, 1.25, 1.6)
	cry = env(t, 0.3, 0.45, 1.15, 1.4)
	quiver = np.sin(TAU * t * 7) * cry
	f['Hips'] = (0.18 * up, 0, 0); f['Spine1'] = (-0.12 * up, 0, 0); f['Spine2'] = (-0.08 * up, 0, 0)
	f['Chest'] = (-0.18 * up, 0, 0)
	f['Neck'] = (-0.7 * up, 0, 0); f['Head'] = (-0.55 * up + 0.02 * quiver, 0.02 * quiver, 0)
	f['Jaw'] = (0.1 + 0.32 * cry + 0.03 * quiver, 0, 0)
	tail(f, t, 0.05, 1.0, lift=-0.3 * up)
	f['_offset'] = (0, -0.08 * up, -0.06 * up)  # sinks back onto the hind legs
	return finish(f)


anims.update({'Idle': (4.0, idle), 'Walk': (1.1, walk), 'Run': (0.55, run), 'Bite': (0.7, bite),
			  'Spit': (1.2, spit), 'Howl': (1.6, howl)})
