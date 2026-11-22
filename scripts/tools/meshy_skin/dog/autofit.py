# Builds a dog rig config from a Meshy model: feet, each leg's line up from its paw,
# the back, head, jaw, ears and tail. Bones as Koleko's (quad_lib.py names).
# python3 autofit.py model.glb out.json [anims.py]
import sys, json, numpy as np
sys.path.insert(0, '.')
from glb import load, acc
j, bn = load(sys.argv[1]); P = acc(j, bn, j['meshes'][0]['primitives'][0]['attributes']['POSITION']).astype(float) * 2.0
ymin = P[:, 1].min(); nose = P[:, 2].max(); tip = P[:, 2].min()
lo = P[:, 1] < ymin + 0.05
feet = {}
for leg, xs, zl, zh in (('FL', 1, 0.0, 0.95), ('FR', -1, 0.0, 0.95), ('RL', 1, -0.95, 0.0), ('RR', -1, -0.95, 0.0)):
	k = lo & (P[:, 2] > zl) & (P[:, 2] < zh) & (P[:, 0] * xs > 0.0); feet[leg] = P[k].mean(0)
fz = (feet['FL'][2] + feet['FR'][2]) / 2; rz = (feet['RL'][2] + feet['RR'][2]) / 2
def torso(z, w=0.04):
	q = P[(abs(P[:, 2] - z) < w) & (abs(P[:, 0]) < 0.06)]
	return q[:, 1].min(), q[:, 1].max()
belly = torso((fz + rz) / 2, 0.08)[0]
def column(f):
	"""the leg's centre line, climbing from the paw to the belly"""
	c = np.array([f[0], f[2]]); out = []
	for y in np.arange(ymin + 0.03, belly + 0.02, 0.03):
		q = P[(abs(P[:, 1] - y) < 0.02) & (np.hypot(P[:, 0] - c[0], P[:, 2] - c[1]) < 0.1) & (P[:, 0] * np.sign(f[0]) > 0)]
		if len(q) > 3: c = 0.5 * c + 0.5 * q[:, [0, 2]].mean(0)
		out.append([c[0], y, c[1]])
	return np.array(out)
def hind_joints(f):
	"""the hind leg's real stifle (knee) and hock from its side outline: the hock is the
	rearmost point of the lower leg; the stifle is where the thin gaskin widens into the
	thigh. Returns (stifle, hock) joint positions, or None if the outline is unclear."""
	side = np.sign(f[0]); c = np.array([f[0], f[2]]); rows = []
	for y in np.arange(ymin + 0.02, belly + 0.1, 0.02):
		m = (abs(P[:, 1] - y) < 0.012) & (np.hypot(P[:, 0] - c[0], P[:, 2] - c[1]) < 0.13) & (P[:, 0] * side > 0.02)
		if m.sum() < 4: continue
		Q = P[m]; c = 0.6 * c + 0.4 * Q[:, [0, 2]].mean(0)
		rows.append((y, Q[:, 2].min(), Q[:, 2].max(), Q[:, 0].mean()))
	if len(rows) < 8: return None
	r = np.array(rows)
	sm = lambda v: np.array([np.median(v[max(0, i - 1):i + 2]) for i in range(len(v))])
	back, front, xs = sm(r[:, 1]), sm(r[:, 2]), sm(r[:, 3]); width = front - back
	L = belly - ymin
	band = (r[:, 0] > ymin + 0.15 * L) & (r[:, 0] < ymin + 0.6 * L)
	if not band.any(): return None
	i = np.nonzero(band)[0][np.argmin(back[band])]
	hock = [xs[i], r[i, 0], back[i] + 0.35 * width[i]]
	gas = (r[:, 0] > r[i, 0] + 0.03) & (r[:, 0] < r[i, 0] + 0.1)
	w0 = np.median(width[gas]) if gas.any() else width[i]
	up = np.nonzero((r[:, 0] > r[i, 0] + 0.08) & (width >= 1.35 * w0))[0]
	ys = r[up[0], 0] if len(up) else r[i, 0] + 0.6 * (belly - r[i, 0])
	ys = min(ys, belly - 0.02)
	k = np.argmin(abs(r[:, 0] - ys))
	stifle = [xs[k], ys, (back[k] + front[k]) / 2]
	return stifle, hock


def at(col, y):
	i = np.argmin(abs(col[:, 1] - y)); return col[i]
B = {}
def mid(z): a, b = torso(z); return (a + b) / 2
hz = rz + 0.02; cz = fz - 0.02
B['Hips'] = ['', [0, mid(hz), hz]]
B['Spine1'] = ['Hips', [0, mid(hz + (cz - hz) / 3), hz + (cz - hz) / 3]]
B['Spine2'] = ['Spine1', [0, mid(hz + 2 * (cz - hz) / 3), hz + 2 * (cz - hz) / 3]]
B['Chest'] = ['Spine2', [0, mid(cz), cz]]
# head: everything well forward of the chest and above the shoulders
top_c = torso(cz)[1]
hp = P[(P[:, 2] > cz + 0.2) & (P[:, 1] > top_c - 0.1)]
skull = hp[(hp[:, 2] > nose - 0.4)]
hc = np.array([0, np.median(skull[:, 1]), nose - 0.22])
B['Neck'] = ['Chest', [0, (B['Chest'][1][1] + hc[1]) / 2 + 0.02, (cz + hc[2]) / 2]]
B['Head'] = ['Neck', [0, hc[1], hc[2] - 0.08]]
snout = P[P[:, 2] > nose - 0.12]
B['Jaw'] = ['Head', [0, snout[:, 1].min() + 0.03, nose - 0.2]]
# tail: down the midline from behind the hips to the tip
tb = []
zs = np.linspace(hz - 0.12, tip + 0.04, 5)
for z in zs:
	q = P[(abs(P[:, 2] - z) < 0.03) & (abs(P[:, 0]) < 0.12) & (P[:, 1] > belly - 0.35)]
	tb.append([q[:, 0].mean(), (q[:, 1].min() + q[:, 1].max()) / 2, z])
for i in range(4):
	B['Tail%d' % (i + 1)] = ['Hips' if i == 0 else 'Tail%d' % i, tb[i]]
legs = []
for leg, f in feet.items():
	front = leg[0] == 'F'; col = column(f); leglen = belly - ymin
	end = [f[0], ymin + 0.012, f[2]]
	paw = at(col, ymin + (0.08 if front else 0.22 * leglen + 0.04))
	lower = at(col, ymin + (0.55 if front else 0.6) * leglen)
	if not front:
		hj = hind_joints(f)
		if hj: lower, paw = hj  # the real stifle and hock
	upper = at(col, belly)
	upper = [upper[0], belly + 0.06, upper[2]]
	par = 'Chest' if front else 'Hips'
	if front:
		B[leg + '_Scap'] = ['Chest', [f[0] * 0.6, mid(cz) + 0.08, upper[2] - 0.04]]
		B[leg + '_Upper'] = [leg + '_Scap', upper]
		bones = [leg + '_Scap', leg + '_Upper', leg + '_Lower', leg + '_Paw']
	else:
		B[leg + '_Upper'] = ['Hips', upper]
		bones = [leg + '_Upper', leg + '_Lower', leg + '_Paw']
	B[leg + '_Lower'] = [leg + '_Upper', list(lower)]; B[leg + '_Paw'] = [leg + '_Lower', list(paw)]
	legs.append({'bones': bones, 'end': end, 'radius': 0.11, 'top': belly + 0.02})
# helper bones at each hind stifle and hock: they turn half as far as the joint below
# them and carry the skin round the joint, so it keeps its thickness as it bends
helpers = []
for leg in ('RL', 'RR'):
	helpers.append({'bone': leg + '_KneeFix', 'parent': leg + '_Upper', 'at': B[leg + '_Lower'][1], 'half_of': leg + '_Lower', 'leg': leg + '_Upper', 'joint': 1})
	helpers.append({'bone': leg + '_HockFix', 'parent': leg + '_Lower', 'at': B[leg + '_Paw'][1], 'half_of': leg + '_Paw', 'leg': leg + '_Upper', 'joint': 2})
for h in helpers:
	B[h['bone']] = [h['parent'], list(h['at'])]
cfg = {'yaw_deg': 0.0, 'scale': 2.0, 'root': 'Hips', 'lib': 'quad_lib.py', 'anims': sys.argv[3] if len(sys.argv) > 3 else 'dog_pet_anims.py',
	   'bones': B, 'spine': ['Hips', 'Spine1', 'Spine2', 'Chest', 'Neck'], 'spine_end': B['Head'][1], 'legs': legs,
	   'tail': {'bones': ['Tail1', 'Tail2', 'Tail3', 'Tail4'], 'end': tb[4], 'radius': 0.14, 'start_z': hz - 0.08},
	   'head': {'center': list(hc), 'radius': float(max(0.2, (nose - hc[2]) + 0.06)), 'min_y': float(snout[:, 1].min() - 0.08), 'front_z': float(nose + 0.05)},
	   'jaw': {'z0': float(nose - 0.24), 'z1': float(nose - 0.16), 'y0': float(snout[:, 1].min() + 0.02), 'y1': float(snout[:, 1].min() + 0.07)},
	   'smooth': 3, 'helpers': helpers}
# ears: what sticks up above the skull, either side
crown = hc[1] + 0.12
ear_pts = P[(P[:, 1] > crown) & (P[:, 2] > cz + 0.2) & (abs(P[:, 0]) > 0.03)]
if len(ear_pts) > 80:
	ears = []
	for side, nm in ((1, 'EarL'), (-1, 'EarR')):
		e = ear_pts[ear_pts[:, 0] * side > 0]; c = e.mean(0)
		B[nm] = ['Head', [c[0] * 0.7, crown, c[2]]]
		ears.append({'bone': nm, 'center': list(c), 'radius': float(np.linalg.norm(e - c, axis=1).max() * 1.05), 'min_y': float(crown - 0.02)})
	cfg['ears'] = ears
# wings (winged hybrids): what rises well above the back between hips and chest
back = max(torso(z)[1] for z in np.linspace(hz, cz, 5))
wing = P[(P[:, 1] > back + 0.06) & (P[:, 2] > hz - 0.15) & (P[:, 2] < cz + 0.1) & (abs(P[:, 0]) > 0.02)]
if len(wing) > 200:
	cfg.setdefault('ears', [])
	for side, nm in ((1, 'WingL'), (-1, 'WingR')):
		w = wing[wing[:, 0] * side > 0]; c = w.mean(0)
		B[nm] = ['Spine2', [side * 0.05, back + 0.02, float(np.median(w[:, 2]))]]
		cfg['ears'].append({'bone': nm, 'center': list(c), 'radius': float(np.linalg.norm(w - c, axis=1).max() * 1.05), 'min_y': float(back + 0.02)})
def py(o):
	if isinstance(o, dict): return {k: py(v) for k, v in o.items()}
	if isinstance(o, (list, tuple, np.ndarray)): return [py(v) for v in o]
	if isinstance(o, (np.floating, float, np.integer)): return round(float(o), 4)
	return o
json.dump(py(cfg), open(sys.argv[2], 'w'), indent=1)
print(sys.argv[1], 'belly', round(belly, 2), 'feet', {k: v[[0, 2]].round(2).tolist() for k, v in feet.items()}, 'ears/wings', [e['bone'] for e in cfg.get('ears', [])])
