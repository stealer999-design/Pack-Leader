## Works out a pet's inner core: capsules along its bones (body, neck, legs,
## tail) and a sphere for the head, each sized to sit just inside the model's
## surface (legs and tail only with --limbs: thin ones can poke through). Saved as JSON for PetModels to build at load (a glowing fire core
## seen through gaps in the fur). python3 core_shapes.py config.json rigged.glb out.json
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb import load, acc
cfg = json.load(open(sys.argv[1])); j, bn = load(sys.argv[2])
p = j['meshes'][0]['primitives'][0]; a = p['attributes']
P = acc(j, bn, a['POSITION']).astype(float); J = acc(j, bn, a['JOINTS_0']).astype(int); W = acc(j, bn, a['WEIGHTS_0']).astype(float)
names = [j['nodes'][i]['name'] for i in j['skins'][0]['joints']]
dom = np.array([names[x] for x in J[np.arange(len(J)), W.argmax(1)]])
B = {n: np.array(v[1], float) for n, v in cfg['bones'].items()}
def seg_d(pts, A, Bp):
	ab = Bp - A; t = np.clip(((pts - A) @ ab) / max(ab @ ab, 1e-9), 0, 1); return np.linalg.norm(pts - (A + t[:, None] * ab), axis=1)
shapes = []
def capsule(bone, A, Bp, owners, shrink=0.8, pct=25):
	m = np.isin(dom, owners)
	if m.sum() < 10: return
	r = float(np.percentile(seg_d(P[m], A, Bp), pct)) * shrink
	if r < 0.01: return
	shapes.append({"bone": bone, "a": A.tolist(), "b": Bp.tolist(), "r": r})
sp = cfg['spine'] + ['Head']
for i in range(len(sp) - 1):
	capsule(sp[i], B[sp[i]], B[sp[i + 1]], [sp[i]], 0.55 if i >= len(sp) - 3 else 0.68, 8)  # the neck is thinner
head = [n for n in ['Head'] if n in B][0]
c = np.array(cfg['head']['center'])
m = np.linalg.norm(P - c, axis=1) < cfg['head']['radius'] * 1.3
r = float(np.percentile(np.linalg.norm(P[m] - c, axis=1), 8)) * 0.75 if m.sum() > 10 else cfg['head']['radius'] * 0.5
shapes.append({"bone": "Head", "a": c.tolist(), "b": c.tolist(), "r": r})
for leg in (cfg['legs'] if '--limbs' in sys.argv else []):
	ch = leg['bones'] + [None]; pts = [B[b] for b in leg['bones']] + [np.array(leg['end'])]
	for i, bname in enumerate(leg['bones']):
		capsule(bname, pts[i], pts[i + 1], [bname], 0.6, 8)
tb = cfg['tail']['bones']; pts = [B[b] for b in tb] + [np.array(cfg['tail']['end'])]
for i, bname in (enumerate(tb) if '--limbs' in sys.argv else []):
	capsule(bname, pts[i], pts[i + 1], [bname], 0.55, 8)
json.dump({"scale_note": "model space of the rigged .glb", "shapes": shapes}, open(sys.argv[3], 'w'), indent=1)
print(len(shapes), 'shapes; radii', [round(s['r'], 3) for s in shapes])
