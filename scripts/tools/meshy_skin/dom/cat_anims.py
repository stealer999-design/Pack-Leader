# Dom's animations, version 2: keyframed with planted paws (two-bone IK keeps a
# paw fixed on the ground while the body moves over it), rolling shoulder
# blades, a steadied head, a lagging tail and ears.
#
# Each animation is a function of time returning {bone: (rx, ry, rz)} plus an
# optional '_offset' (the hips' movement). Rig globals come from rig_quad.py:
# names, JP (joint positions), par (parent index), idx (name -> index), cfg.
# Rotation sense: +rx turns a bone's +Y toward +Z. A downward leg with +rx
# swings its paw back; a forward-pointing head or jaw with +rx tips down; the
# tail (pointing up and back) with +rx lifts; an upright ear with -rx lies back.
import numpy as np

TAU = 2 * np.pi
LEGS = ['FL', 'FR', 'RL', 'RR']
BEND = {'FL': 1, 'FR': 1, 'RL': -1, 'RR': -1}  # elbows bend back, stifles forward
END = {leg['bones'][-1][:2]: np.array(leg['end'], float) for leg in cfg['legs']}  # paw on the ground
ROOT = idx[cfg['root']]


def Rx(a):
	c, s = np.cos(a), np.sin(a); return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
def Ry(a):
	c, s = np.cos(a), np.sin(a); return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
def Rz(a):
	c, s = np.cos(a), np.sin(a); return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
def emat(e):
	return Ry(e[1]) @ Rx(e[0]) @ Rz(e[2])  # the same order rig_quad.py bakes the quaternions in


def fk(pose):
	"""global rotation and position of every joint"""
	off = np.array(pose.get('_offset', (0, 0, 0)), float)
	GR = [None] * len(names); GP = [None] * len(names)
	for i in range(len(names)):
		e = pose.get(names[i], (0, 0, 0))
		if par[i] < 0:
			GR[i] = emat(e); GP[i] = JP[i] + off
		else:
			GR[i] = GR[par[i]] @ emat(e); GP[i] = GP[par[i]] + GR[par[i]] @ (JP[i] - JP[par[i]])
	return GR, GP


def wrap(a):
	return (a + np.pi) % TAU - np.pi


def solve_leg(pose, leg, foot, flex=0.0):
	"""sets the leg's upper and lower bones so its paw lands on `foot` (a ground point in
	model space), and keeps the paw level (plus `flex`)"""
	up, lo, paw = idx[leg + '_Upper'], idx[leg + '_Lower'], idx[leg + '_Paw']
	GR, GP = fk(pose)
	Rp = GR[par[up]]
	target = foot + (JP[paw] - END[leg])  # where the ankle must be
	t = Rp.T @ (target - GP[up])
	s1 = JP[lo] - JP[up]; s2 = JP[paw] - JP[lo]
	l1 = np.hypot(s1[1], s1[2]); l2 = np.hypot(s2[1], s2[2])
	d = np.clip(np.hypot(t[1], t[2]), abs(l1 - l2) + 1e-3, l1 + l2 - 1e-3)
	th = np.arctan2(t[2], t[1])
	al = np.arccos(np.clip((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1))
	p1 = th + BEND[leg] * al
	a1 = wrap(p1 - np.arctan2(s1[2], s1[1]))
	knee = l1 * np.array([np.cos(p1), np.sin(p1)])
	tt = np.array([d * np.cos(th), d * np.sin(th)])
	p2 = np.arctan2(tt[1] - knee[1], tt[0] - knee[0])
	a2 = wrap(p2 - np.arctan2(s2[2], s2[1]) - a1)
	parent_pitch = np.arctan2(Rp[2, 1], Rp[1, 1])
	pose[leg + '_Upper'] = (a1, 0, 0)
	pose[leg + '_Lower'] = (a2, 0, 0)
	pose[leg + '_Paw'] = (wrap(flex - parent_pitch - a1 - a2), 0, 0)


def rest_foot(leg):
	return END[leg].copy()


def ss(x):
	x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)


def env(t, a, b, c, d=None):
	"""0 before a, eases up to 1 by b, holds to c, eases back to 0 by d (or holds)"""
	if t < a: return 0.0
	if t < b: return float(ss((t - a) / (b - a)))
	if d is None or t < c: return 1.0
	if t < d: return float(1 - ss((t - c) / (d - c)))
	return 0.0


def gait_foot(leg, u, sweep, lift, duty):
	"""a paw's ground target over its step (u: 0..1 through the cycle, stance first)"""
	f = rest_foot(leg)
	if u < duty:  # planted: the ground slides back under the body
		f[2] += sweep * (0.5 - u / duty)
		return f, 0.0
	v = (u - duty) / (1 - duty)  # swinging forward
	e = ss(v)
	f[2] += sweep * (e - 0.5)
	f[1] += lift * np.sin(np.pi * v)
	return f, np.sin(np.pi * v)


def tail(f, t, amp, speed, lift=0.0, curl=0.0, lag=0.7):
	for k in range(4):
		f['Tail%d' % (k + 1)] = (lift * (1.0 if k == 0 else 0.25) + curl * k / 3 * np.sin(TAU * speed * t - k * lag * 0.5),
								 amp * (0.35 + 0.65 * k / 3) * np.sin(TAU * speed * t - k * lag), 0)


def steady_head(f, keep=0.85):
	"""turns the neck and head against the body's sway, so the head stays level and on target"""
	yaw = sum(f.get(b, (0, 0, 0))[1] for b in ['Hips', 'Spine1', 'Spine2', 'Chest'])
	pitch = sum(f.get(b, (0, 0, 0))[0] for b in ['Hips', 'Spine1', 'Spine2', 'Chest'])
	n = f.get('Neck', (0, 0, 0)); h = f.get('Head', (0, 0, 0))
	f['Neck'] = (n[0] - pitch * keep * 0.5, n[1] - yaw * keep * 0.6, n[2])
	f['Head'] = (h[0] - pitch * keep * 0.5, h[1] - yaw * keep * 0.4, h[2])


def ears(f, back=0.0, out=0.0, twitch_l=0.0, twitch_r=0.0):
	f['EarL'] = (-back + twitch_l, 0, out); f['EarR'] = (-back + twitch_r, 0, -out)


def walk_like(t, T, offsets, travel, duty, lift, f):
	sweep = travel * duty
	for leg in LEGS:
		u = (t / T + offsets[leg]) % 1.0
		foot, up = gait_foot(leg, u, sweep, lift, duty)
		if leg[0] == 'F':  # the shoulder blade rolls with the leg
			reach = (foot[2] - END[leg][2]) / max(sweep, 1e-3)
			f[leg + '_Scap'] = (-0.35 * reach, 0, 0)
		f['_feet'][leg] = (foot, (0.45 if leg[0] == 'F' else 0.3) * up)


def finish(f):
	"""plants (or places) every paw last, once the body pose is known"""
	for leg, (foot, flex) in f.pop('_feet', {}).items():
		solve_leg(f, leg, foot, flex)
	return f


def planted(f):
	f['_feet'] = {leg: (rest_foot(leg), 0.0) for leg in LEGS}


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
