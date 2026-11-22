# Builds a lizard rig config from a Meshy model's shape: feet, body line, head, tail
# (and wings, if any stick up above the back). python3 autofit.py model.glb out.json [scale]
import sys, json, numpy as np
sys.path.insert(0, '.')
from glb import load, acc
j, bn = load(sys.argv[1]); P = acc(j, bn, j['meshes'][0]['primitives'][0]['attributes']['POSITION']) * 2.0  # "x2 units"
ymin = P[:, 1].min(); nose = P[:, 2].max(); tip = P[:, 2].min()
lo = P[:, 1] < ymin + 0.05
feet = {}
for leg, xs, zl, zh in (('FL', 1, 0.2, 0.95), ('FR', -1, 0.2, 0.95), ('RL', 1, -0.6, 0.2), ('RR', -1, -0.6, 0.2)):
	k = lo & (P[:, 2] > zl) & (P[:, 2] < zh) & (P[:, 0] * xs > 0.03); feet[leg] = P[k].mean(0)
def body(z, w=0.03):
	q = P[(abs(P[:, 2] - z) < w) & (abs(P[:, 0]) < 0.07)]
	return q[:, 1].min(), q[:, 1].max()
fz = (feet['FL'][2] + feet['FR'][2]) / 2; rz = (feet['RL'][2] + feet['RR'][2]) / 2
def mid(z):
	a, b = body(z); return (a + b) / 2
belly = body((fz + rz) / 2, 0.05)[0]; under_f = under_r = belly
# the underside sits between the legs; legs reach well below it
scale = float(sys.argv[3]) if len(sys.argv) > 3 else round(min(4.0, max(2.0, 0.48 / (belly - ymin))) * 2) / 2  # legs of ~0.48 rig units, as the shared walk expects
K = scale / 2
def m(p): return [round(float(v) * K, 4) for v in p]
hz = rz - 0.02; cz = fz - 0.04; s1 = (hz + cz) / 2
neck_z = cz + (nose - cz) * 0.35; head_z = cz + (nose - cz) * 0.55; jaw_z = cz + (nose - cz) * 0.78
B = {'Hips': ['', m([0, mid(hz), hz])], 'Spine1': ['Hips', m([0, mid(s1), s1])], 'Chest': ['Spine1', m([0, mid(cz), cz])],
	 'Neck': ['Chest', m([0, mid(neck_z), neck_z])], 'Head': ['Neck', m([0, mid(head_z), head_z])],
	 'Jaw': ['Head', m([0, body(jaw_z)[0] + 0.03, jaw_z])]}
# tail: down the midline from behind the hips to the tip, in thirds
tz = [hz - 0.15, hz - 0.15 + (tip - hz + 0.15) * 0.33, hz - 0.15 + (tip - hz + 0.15) * 0.62]
for i, z in enumerate(tz):
	q = P[abs(P[:, 2] - z) < 0.03]; c = q.mean(0)
	B['Tail%d' % (i + 1)] = ['Hips' if i == 0 else 'Tail%d' % i, m([c[0], (q[:, 1].min() + q[:, 1].max()) / 2, z])]
qt = P[P[:, 2] < tip + 0.03]; tail_end = m([qt[:, 0].mean(), qt[:, 1].mean(), tip])
legs = []
for leg, f in feet.items():
	front = leg[0] == 'F'; par = 'Chest' if front else 'Hips'; under = under_f if front else under_r
	sx = np.sign(f[0]); end = np.array([f[0], ymin + 0.012, f[2]])
	paw = end + np.array([0, 0.035, -0.045 if front else -0.025])
	lower = np.array([f[0] * 1.05, under - 0.4 * (under - paw[1]), f[2] - (0.05 if front else 0.0)])
	upper = np.array([sx * max(0.06, abs(f[0]) * 0.55), (under + mid(f[2])) / 2, f[2] - (0.05 if front else 0.02)])
	B[leg + '_Upper'] = [par, m(upper)]; B[leg + '_Lower'] = [leg + '_Upper', m(lower)]; B[leg + '_Paw'] = [leg + '_Lower', m(paw)]
	legs.append({'bones': [leg + '_Upper', leg + '_Lower', leg + '_Paw'], 'end': m(end), 'radius': 0.1, 'top': round((under + 0.02) * K, 4)})
hc = [0, mid(head_z + 0.1), head_z + 0.1]; hr = max(0.17, 0.55 * (nose - neck_z))
cfg = {'yaw_deg': 0.0, 'scale': scale, 'root': 'Hips', 'lib': 'lizard_lib.py', 'anims': 'lizard_anims.py', 'bones': B,
	   'spine': ['Hips', 'Spine1', 'Chest', 'Neck'], 'spine_end': B['Head'][1], 'legs': legs,
	   'paw_below': round((ymin + 0.06) * K, 4),
	   'tail': {'bones': ['Tail1', 'Tail2', 'Tail3'], 'end': tail_end, 'radius': 0.25, 'start_z': round((hz - 0.1) * K, 4)},
	   'head': {'center': m(hc), 'radius': round(hr * K, 4), 'min_y': round((hc[1] - 0.12) * K, 4), 'front_z': round((nose + 0.05) * K, 4)},
	   'jaw': {'z0': round((jaw_z - 0.02) * K, 4), 'z1': round((jaw_z + 0.03) * K, 4), 'y0': round((body(jaw_z)[0] + 0.01) * K, 4), 'y1': round((mid(jaw_z) - 0.0) * K, 4)},
	   'smooth': 3}
# wings: points well above the back, out to each side
top = np.array([body(z)[1] for z in (hz, s1, cz)]).max()
wing = P[(P[:, 1] > top + 0.06) & (abs(P[:, 0]) > 0.05) & (P[:, 2] > hz - 0.1) & (P[:, 2] < cz + 0.1)]
if len(wing) > 200:
	ears = []
	for side, nm in ((1, 'WingL'), (-1, 'WingR')):
		w = wing[wing[:, 0] * side > 0]; root = [side * 0.05, top + 0.02, w[:, 2].mean()]
		B[nm] = ['Spine1', m(root)]
		c = w.mean(0); r = np.linalg.norm(w - c, axis=1).max() * 1.05
		ears.append({'bone': nm, 'center': m(c), 'radius': round(r * K, 4), 'min_y': round((top - 0.02) * K, 4)})
	cfg['ears'] = ears
print(sys.argv[1], 'scale', scale, 'feet', {k: v.round(2).tolist() for k, v in feet.items()}, 'under', round(under_f, 2), round(under_r, 2), 'wings', 'ears' in cfg)
def py(o):
	if isinstance(o, dict): return {k: py(v) for k, v in o.items()}
	if isinstance(o, (list, tuple)): return [py(v) for v in o]
	if isinstance(o, (np.floating, np.integer)): return round(float(o), 4)
	return o
cfg = py(cfg)
json.dump(cfg, open(sys.argv[2], 'w'), indent=1)
