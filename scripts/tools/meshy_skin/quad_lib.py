# The four-legged animation library (rig_quad.py animation files exec it):
# keyframing with planted paws (two-bone IK keeps a
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
import os

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
	if 'EarL' in idx:  # (an animal without ear bones just ignores this)
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


