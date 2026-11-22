# The lizard animation library (rig_quad.py animation files exec it), for
# sprawling legs: each leg reaches out sideways from the body and down, so its
# two-bone IK works in 3D (the elbow or knee stays bent up and out, the way it
# sits in the model), not in a fore-and-aft plane like quad_lib.py's.
#
# Each animation is a function of time returning {bone: (rx, ry, rz)} plus an
# optional '_offset' (the hips' movement). Rig globals come from rig_quad.py:
# names, JP (joint positions), par (parent index), idx (name -> index), cfg.
# Rotation sense: +rx turns a bone's +Y toward +Z (a forward-pointing head or
# jaw tips down); +ry turns +Z toward +X (the body yaws towards +X).
import numpy as np

TAU = 2 * np.pi
LEGS = ['FL', 'FR', 'RL', 'RR']
TAILS = [n for n in names if n.startswith('Tail')]  # (lizards with curled tails rig only two)
TAIL_K = 1.0 if len(TAILS) <= 2 else 0.3  # long straight tails: the same swing at the tip
END = {leg['bones'][-1][:2]: np.array(leg['end'], float) for leg in cfg['legs']}  # paw on the ground


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
	"""a paw's ground target through its step (u 0..1, stance first): planted, the ground
	slides it back under the body; then it swings forward in a low arc, up and out"""
	f = END[leg].copy(); side = np.sign(f[0])
	if u < duty:
		f[2] += sweep * (0.5 - u / duty)
		return f
	v = (u - duty) / (1 - duty); e = ss(v); arc = np.sin(np.pi * v)
	f[2] += sweep * (e - 0.5)
	f[1] += lift * arc
	f[0] += side * lift * 0.5 * arc  # sprawled: the paw swings round, out to the side
	return f


def gait(f, t, T, travel, duty, lift, bend, roll=0.0):
	"""the lizard trot of the reference: diagonal pairs step together (left fore with right
	hind), the spine bending side to side so each shoulder and hip swings forward with its
	leg, the tail swinging the other way. Returns the phase (radians)."""
	ph = TAU * t / T
	offsets = {'FL': 0.0, 'RR': 0.0, 'FR': 0.5, 'RL': 0.5}
	sweep = travel * duty
	for leg in LEGS:
		u = (t / T + offsets[leg]) % 1.0
		f['_feet'][leg] = (step_foot(leg, u, sweep, lift, duty), 0.0)
	# FL (+x) reaches furthest forward at the start of its stance (ph = 0): the chest turns
	# its +x shoulder forward then (negative yaw), the hips their -x side (RR) forward.
	c = np.cos(ph)
	f['Hips'] = (0, bend * c, roll * np.sin(ph))
	f['Spine1'] = (0, -bend * c, 0)
	f['Chest'] = (0, -bend * c, -roll * np.sin(ph))
	f['Neck'] = (0, bend * c * 0.7, 0); f['Head'] = (0, bend * c * 0.3, 0)  # the head stays on course
	for k, b in enumerate(TAILS):  # a wave running down the tail
		f[b] = (0, -bend * (1.3 - 0.4 * k) * TAIL_K * np.cos(ph - 0.7 * (k + 1)), 0)
	return ph


def finish(f):
	for leg, (foot, toe) in f.pop('_feet', {}).items():
		solve_leg(f, leg, foot, toe)
	return f
