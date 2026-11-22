# The bird animation library (rig_bird.py animation files exec it): two legs whose
# feet stay planted on the ground (a 3D two-bone IK, from the lizards' library), and
# the helpers for a waddle and for wings. Rig globals come from rig_bird.py: names,
# JP (joint positions), par (parent index), idx (name -> index), cfg.
# Rotation sense: +rx turns a bone's +Y toward +Z (the spine and head tip forward);
# +rz turns +X toward +Y (the left wing, pointing +X, rises).
import numpy as np

TAU = 2 * np.pi
LEGS = ['L', 'R']
END = {leg['bones'][-1][0]: np.array(leg['end'], float) for leg in cfg['legs']}  # foot on the ground


def Rx(a):
	c, s = np.cos(a), np.sin(a); return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
def Ry(a):
	c, s = np.cos(a), np.sin(a); return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
def Rz(a):
	c, s = np.cos(a), np.sin(a); return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
def emat(e):
	return Ry(e[1]) @ Rx(e[0]) @ Rz(e[2])  # the order rig_quad.py bakes the quaternions in


def euler(R):
	"""(rx, ry, rz) with emat(e) == R"""
	a = np.arcsin(np.clip(-R[1, 2], -1, 1))
	return (float(a), float(np.arctan2(R[0, 2], R[2, 2])), float(np.arctan2(R[1, 0], R[1, 1])))


def fk(pose):
	off = np.array(pose.get('_offset', (0, 0, 0)), float)
	GR = [None] * len(names); GP = [None] * len(names)
	for i in range(len(names)):
		e = pose.get(names[i], (0, 0, 0))
		if par[i] < 0:
			GR[i] = emat(e); GP[i] = JP[i] + off
		else:
			GR[i] = GR[par[i]] @ emat(e); GP[i] = GP[par[i]] + GR[par[i]] @ (JP[i] - JP[par[i]])
	return GR, GP


def turn(a, b):
	"""the smallest rotation taking direction a to direction b"""
	a = a / np.linalg.norm(a); b = b / np.linalg.norm(b)
	v = np.cross(a, b); c = float(a @ b); s = np.linalg.norm(v)
	if s < 1e-9:
		return np.eye(3)
	k = v / s; K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
	return np.eye(3) + s * K + (1 - c) * K @ K


def solve_leg(pose, leg, foot, toe=0.0):
	"""sets the leg so its paw lands flat on `foot` (a ground point, model space), the
	elbow/knee bent the way it is at rest; `toe` turns the paw (yaw)"""
	up, lo, paw = idx[leg + '_Upper'], idx[leg + '_Lower'], idx[leg + '_Paw']
	GR, GP = fk(pose)
	Gp = GR[par[up]]; S = GP[up]
	A = foot + (JP[paw] - END[leg])  # where the wrist/ankle must be
	l1 = np.linalg.norm(JP[lo] - JP[up]); l2 = np.linalg.norm(JP[paw] - JP[lo])
	D = A - S; d = np.clip(np.linalg.norm(D), abs(l1 - l2) + 1e-3, l1 + l2 - 1e-3); u = D / np.linalg.norm(D)
	pole = Gp @ (JP[lo] - JP[up]); v = pole - (pole @ u) * u; v /= max(np.linalg.norm(v), 1e-9)
	a = (l1 * l1 - l2 * l2 + d * d) / (2 * d); h = np.sqrt(max(l1 * l1 - a * a, 0.0))
	E = S + u * a + v * h  # the elbow/knee
	R1 = turn(Gp @ (JP[lo] - JP[up]), E - S); G1 = R1 @ Gp
	R2 = turn(G1 @ (JP[paw] - JP[lo]), S + u * d - E); G2 = R2 @ G1
	pose[leg + '_Upper'] = euler(Gp.T @ G1)
	pose[leg + '_Lower'] = euler(G1.T @ G2)
	pose[leg + '_Paw'] = euler(G2.T @ Ry(toe))  # flat on the ground


def ss(x):
	x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)


def env(t, a, b, c, d=None):
	"""0 before a, eases up to 1 by b, holds to c, eases back to 0 by d (or holds)"""
	if t < a: return 0.0
	if t < b: return float(ss((t - a) / (b - a)))
	if d is None or t < c: return 1.0
	if t < d: return float(1 - ss((t - c) / (d - c)))
	return 0.0


def planted(f):
	f['_feet'] = {leg: (END[leg].copy(), 0.0) for leg in LEGS}


def step_foot(leg, u, sweep, lift, duty):
	"""a foot's ground target through its step (u 0..1, stance first)"""
	f = END[leg].copy()
	if u < duty:
		f[2] += sweep * (0.5 - u / duty)
		return f
	v = (u - duty) / (1 - duty); e = ss(v)
	f[2] += sweep * (e - 0.5); f[1] += lift * np.sin(np.pi * v)
	return f


def waddle(f, t, T, travel, duty, lift):
	"""the feet step in turn; returns the phase (radians), 0 as the left foot lands"""
	for leg, off in (('L', 0.0), ('R', 0.5)):
		u = (t / T + off) % 1.0
		f['_feet'][leg] = (step_foot(leg, u, travel * duty, lift, duty), 0.0)
	return TAU * t / T


def open_wings(f, show, lift=0.0, sweep=0.0, tip=0.0, folded=None):
	"""the open wings: `show` 0..1 sweeps them out (the folded ones tuck away), `lift`
	raises them (radians; 0 = straight out), `sweep` brings them forward, `tip` bends
	the outer half (down for a downstroke)"""
	s = max(show, 0.0)
	f.setdefault('_scale', {})
	f['_scale']['WingOpenL1'] = s; f['_scale']['WingOpenR1'] = s
	fold = 1.0 - 0.95 * ss(show * 1.4) if folded is None else folded
	f['_scale']['WingL'] = fold; f['_scale']['WingR'] = fold
	f['WingOpenL1'] = (0, -sweep, lift); f['WingOpenR1'] = (0, sweep, -lift)
	f['WingOpenL2'] = (0, -0.3 * sweep, tip); f['WingOpenR2'] = (0, 0.3 * sweep, -tip)


def finish(f):
	for leg, (foot, toe) in f.pop('_feet', {}).items():
		solve_leg(f, leg, foot, toe)
	return f
