# Fits a cat's legs the way Emberkitty's were fitted by hand (after the user's cat skeleton
# diagram and walking-cat reference): measures the cat's body (ground, chest bottom and
# withers over the fore legs, belly and back over the hips) and its paws, and places
# every leg joint, helper bone and muscle in proportion, using Emberkitty's rig as the
# template. Keeps the cat's own spine, head, jaw and tail.
#   python3 cat/autofit.py pets/<cat>.json <cat's meshy.glb> out.json
#   (run from scripts/tools/meshy_skin; needs pets/emberkitty.json and Emberkitty's Meshy
#   model, path in TEMPLATE_GLB or argv[4])
import sys, os, json, copy, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + '/..')
from glb import load, acc
HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, '..', 'pets', 'emberkitty.json')
TEMPLATE_GLB = sys.argv[4] if len(sys.argv) > 4 else os.environ.get('TEMPLATE_GLB')


def points(cfg, path):
	j, bn = load(path); P = acc(j, bn, j['meshes'][0]['primitives'][0]['attributes']['POSITION']).astype(float) * cfg['scale']
	yaw = np.radians(cfg.get('yaw_deg', 0.0))
	return P @ np.array([[np.cos(yaw), 0, -np.sin(yaw)], [0, 1, 0], [np.sin(yaw), 0, np.cos(yaw)]])


def features(cfg, P, zf_rel=None, zh_rel=None):
	legs = {l['bones'][0][:2] if l['bones'][0][0] == 'F' else l['bones'][0][:2]: l for l in cfg['legs']}
	ends = {k: np.array(l['end']) for k, l in legs.items()}
	G = float(P[:, 1].min())
	zF = float(np.mean([ends['FL'][2], ends['FR'][2]])); zR = float(np.mean([ends['RL'][2], ends['RR'][2]])); L = zF - zR
	f = {'G': G, 'zF': zF, 'zR': zR, 'L': L}
	zf = zF + (zf_rel if zf_rel is not None else -0.274) * L  # over the shoulders
	zh = zR + (zh_rel if zh_rel is not None else -0.355) * L  # over the hips
	def junction(front):
		"""where the leg column joins the body, walking up from the ground: the height at which
		the cross-section through that pair of legs suddenly widens fore and aft"""
		lx = np.mean([abs(ends[k][0]) for k in (('FL', 'FR') if front else ('RL', 'RR'))]); zc = zF if front else zR
		lo, hi = (zc - 0.45 * L, zc + 0.25 * L)
		for yy in np.arange(G + 0.08, G + 0.9, 0.01):
			q = P[(np.abs(P[:, 1] - yy) < 0.012) & (np.abs(np.abs(P[:, 0]) - lx) < 0.07) & (P[:, 2] > lo) & (P[:, 2] < hi)]
			if len(q) > 3 and np.ptp(q[:, 2]) > 0.45 * L:
				return float(yy)
		return G + 0.4
	def top(z, B, lo_r, hi_r):
		q = P[(np.abs(P[:, 2] - z) < 0.06) & (np.abs(P[:, 0]) < 0.08)]
		t = float(np.percentile(q[:, 1], 95)) if len(q) else B + lo_r * (B - G)
		return float(np.clip(t, B + lo_r * (B - G), B + hi_r * (B - G)))
	f['Bf'] = junction(True); f['Bh'] = junction(False)
	f['Tf'] = top(zf, f['Bf'], 0.9, 1.6); f['Th'] = top(zh, f['Bh'], 0.5, 1.3)
	return f


# where each joint sits, in terms of the features: (y from, y to, z from, z scale)
RULES = {
	'F_Scap': ('Bf', 'Tf', 'zF', 'front'), 'F_Upper': ('Bf', 'Tf', 'zF', 'front'),
	'F_Lower': ('G', 'Bf', 'paw', 'front'), 'F_Paw': ('G', 'Bf', 'paw', 'front'),
	'R_Upper': ('Bh', 'Th', 'zR', 'hind'), 'R_Lower': ('G', 'Bh', 'paw', 'hind'), 'R_Paw': ('G', 'Bh', 'paw', 'hind'),
}


def scale_of(f, s):
	return {'L': f['L'], 'front': f['Bf'] - f['G'], 'hind': f['Bh'] - f['G']}[s]


# (the shoulders and hips go by the pair's paws; the lower joints by their own leg's paw,
# as a cat modelled mid-stride has one paw ahead of the other)
def to_rel(f, kind, p, paw_z):
	a, b, z0, s = RULES[kind]; z0 = paw_z if z0 == 'paw' else f[z0]
	return ((p[1] - f[a]) / (f[b] - f[a]), (p[2] - z0) / scale_of(f, s))


def from_rel(f, kind, r, x, paw_z):
	a, b, z0, s = RULES[kind]; z0 = paw_z if z0 == 'paw' else f[z0]
	return [round(float(x), 4), round(float(f[a] + r[0] * (f[b] - f[a])), 4), round(float(z0 + r[1] * scale_of(f, s)), 4)]


def kind_of(bone):
	return bone[0] + '_' + bone.split('_')[1]


if __name__ == '__main__':
	T = json.load(open(TEMPLATE)); PT = points(T, TEMPLATE_GLB)
	TB = T['bones']
	fT = features(T, PT, (0.42 - 0.59) / 0.62, (-0.25 - (-0.03)) / 0.62)  # where Emberkitty was measured by hand
	# (its ends: the mean toe z of each pair, its length L)
	c = json.load(open(sys.argv[1])); P = points(c, sys.argv[2])
	f = features(c, P)
	print('%s: ground %.2f, chest bottom %.2f, withers %.2f, belly %.2f, back at the hips %.2f, length %.2f' % (
		os.path.basename(sys.argv[1]), f['G'], f['Bf'], f['Tf'], f['Bh'], f['Th'], f['L']))
	out = copy.deepcopy(c)
	B = out['bones']
	for leg in out['legs']:
		tl = next(l for l in T['legs'] if l['bones'][0][:2] == leg['bones'][0][:2])
		for bone in leg['bones']:
			k = kind_of(bone); tb = TB[[n for n in TB if n.startswith(bone[:2]) and n.endswith(bone.split('_')[1])][0]][1]
			B[bone][1] = from_rel(f, k, to_rel(fT, k, tb, tl['end'][2]), B[bone][1][0], leg['end'][2])
			if k == 'R_Upper':  # the hip sits by the pelvis (the spine's Hips joint), not just so far behind the paw
				B[bone][1][2] = round(B['Hips'][1][2] + (tb[2] - TB['Hips'][1][2]), 4)
		sc = scale_of(f, 'front' if leg['bones'][0][0] == 'F' else 'hind') / scale_of(fT, 'front' if leg['bones'][0][0] == 'F' else 'hind')
		front = leg['bones'][0][0] == 'F'
		top_from, top_to = ('G', 'Bf') if front else ('G', 'Bh')
		leg['top'] = round(f[top_from] + (tl['top'] - fT[top_from]) / (fT[top_to] - fT[top_from]) * (f[top_to] - f[top_from]), 4)
		thick = leg['radius'] / tl['radius']  # (the leg's own radius, as first fitted: legs grow longer without growing thicker)
		if 'blend' in tl: leg['blend'] = tl['blend']
	# the fore leg's elbow and wrist: on the leg itself, as far from its middle (along the
	# walk) as Emberkitty's are from the middle of its leg (a cat modelled leaning or mid-stride
	# can leave a joint placed in proportion off its leg)
	def column(PP, leg_end, yy, side):
		q = PP[(np.abs(PP[:, 1] - yy) < 0.02) & (side * PP[:, 0] > 0.02) & (np.abs(PP[:, 2] - leg_end[2]) < 0.3)]
		if len(q) < 4: return None
		# the leg's own run of points nearest its paw (not the chest beside it)
		zs = np.sort(q[:, 2]); gaps = np.where(np.diff(zs) > 0.04)[0]
		runs = np.split(zs, gaps + 1); run = min(runs, key=lambda r: abs(np.median(r) - leg_end[2]))
		return float((run.min() + run.max()) / 2)
	for leg in out['legs']:
		if leg['bones'][0][0] != 'F': continue
		nm = leg['bones'][0][:2]; side = np.sign(leg['end'][0])
		tl = next(l for l in T['legs'] if l['bones'][0][:2] == nm)
		for bone in (nm + '_Lower', nm + '_Paw'):
			tz = column(PT, tl['end'], TB[bone][1][1], side); cz = column(P, leg['end'], B[bone][1][1], side)
			if tz is None or cz is None: continue
			off = (TB[bone][1][2] - tz) * scale_of(f, 'front') / scale_of(fT, 'front')
			B[bone][1][2] = round(cz + off, 4)
	# helpers and muscles: the template's, each point moved with the joint it belongs to
	def joint_of(p, leg2):  # the template joint nearest p, among that leg's
		names = [n for n in TB if n[:2] == leg2 and 'Fix' not in n]
		return min(names, key=lambda n: np.linalg.norm(np.array(TB[n][1]) - np.array(p)))
	def move(p, leg2):
		n = joint_of(p, leg2); k = kind_of(n)
		d = np.array(p) - np.array(TB[n][1])  # (a muscle's top sits above its joint: keep that offset, scaled)
		sc = scale_of(f, RULES[k][3]) / scale_of(fT, RULES[k][3])
		return [round(float(v), 4) for v in np.array(B[n][1]) + d * sc]
	out['helpers'] = []
	for h in T['helpers']:
		h2 = dict(h); h2['at'] = move(h['at'], h['bone'][:2]); out['helpers'].append(h2); B[h['bone']] = [h['parent'], h2['at']]
	out['muscles'] = []
	for m in T['muscles']:
		m2 = dict(m); leg2 = m['bone'][:2]
		m2['a'] = move(m['a'], leg2); m2['b'] = move(m['b'], leg2)
		ol = next(l for l in c['legs'] if l['bones'][0][:2] == leg2); tl2 = next(l for l in T['legs'] if l['bones'][0][:2] == leg2)
		m2['radius'] = round(m['radius'] * ol['radius'] / tl2['radius'], 4)
		out['muscles'].append(m2)
	out['anims'] = ['../dom/cat_anims.py', '../cat/cat_pet_anims.py']
	json.dump(out, open(sys.argv[3], 'w'), indent=1)
