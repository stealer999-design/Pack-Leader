## Rigs and animates a four-legged Meshy model (Meshy only rigs humanoids):
## straightens it to face +Z, builds a skeleton (hips, spine, chest, neck, head,
## jaw, tail chain, three bones per leg), weights the mesh by body part with
## smooth blends, and bakes keyframed animations (idle, walk, run, swipe,
## pounce, retch, hiss for Dom; see each animal's folder).
## python3 rig_quad.py <animal>/config.json in.glb out.glb
import sys, json, struct, numpy as np
sys.path.insert(0, '.')
from glb import load, acc
cfg = json.load(open(sys.argv[1])); src, dst = sys.argv[2], sys.argv[3]
j, bn = load(src); bn = bytearray(bn)
p = j['meshes'][0]['primitives'][0]; a = p['attributes']
P0 = acc(j, bn, a['POSITION']).astype(float)
yaw = np.radians(cfg['yaw_deg']); c, s = np.cos(-yaw), np.sin(-yaw)
R = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
P = P0 @ R.T * cfg.get('scale', 1.0)  # scale: so a small model takes the Dom-sized animations
def put(i, arr):
	ac = j['accessors'][i]; v = j['bufferViews'][ac['bufferView']]; off = v.get('byteOffset', 0) + ac.get('byteOffset', 0)
	b = arr.tobytes(); bn[off:off + len(b)] = b
put(a['POSITION'], P.astype(np.float32))
ac = j['accessors'][a['POSITION']]; ac['min'] = P.min(0).tolist(); ac['max'] = P.max(0).tolist()
put(a['NORMAL'], (acc(j, bn, a['NORMAL']).astype(float) @ R.T).astype(np.float32))
if 'TANGENT' in a:
	T = acc(j, bn, a['TANGENT']).astype(float); T[:, :3] = T[:, :3] @ R.T; put(a['TANGENT'], T.astype(np.float32))
# --- skeleton: name -> (parent, position) ---
B = cfg['bones']; names = list(B.keys()); idx = {n: i for i, n in enumerate(names)}
JP = np.array([B[n][1] for n in names], float); par = [idx.get(B[n][0], -1) for n in names]
NB = len(names); N = len(P)
def seg_param(pts, chain):
	"""closest point on a polyline of joint positions: (segment index, t, distance)"""
	best = np.full(len(pts), 1e9); si = np.zeros(len(pts), int); ti = np.zeros(len(pts))
	for i in range(len(chain) - 1):
		A, Bp = chain[i], chain[i + 1]; ab = Bp - A
		t = np.clip(((pts - A) @ ab) / (ab @ ab), 0, 1); d = np.linalg.norm(pts - (A + t[:, None] * ab), axis=1)
		m = d < best; best[m] = d[m]; si[m] = i; ti[m] = t[m]
	return si, ti, best
def chain_weights(pts, bones, end):
	"""weights over a chain of bones (each owns the segment to the next joint, the last to `end`), blended at joints"""
	chain = np.vstack([JP[[idx[b] for b in bones]], end]); si, ti, d = seg_param(pts, chain)
	W = np.zeros((len(pts), NB)); u = si + ti  # 0..len
	for k, b in enumerate(bones):
		W[:, idx[b]] = np.clip(1 - np.abs(u - (k + 0.5)) / 0.75, 0, 1) if len(bones) > 1 else 1
	W[W.sum(1) == 0, idx[bones[0]]] = 1
	return W / W.sum(1, keepdims=True), d
def ss(e0, e1, x): t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)
x, y, z = P[:, 0], P[:, 1], P[:, 2]
# torso (spine chain) is the base for every point
Wt, _ = chain_weights(P, cfg['spine'], np.array(cfg['spine_end']))
W = Wt.copy()
# legs: points below the body near each leg's column
for leg in cfg['legs']:
	bones = leg['bones']; col = JP[[idx[b] for b in bones]]; end = np.array(leg['end'])
	Wl, d = chain_weights(P, bones, end)
	near = 1 - ss(leg['radius'] * 0.8, leg['radius'] * 1.2, d)
	m = near * ss(leg['top'] + 0.08, leg['top'] - 0.08, y)
	W = W * (1 - m)[:, None] + Wl * m[:, None]
# feet (lizards): everything below `paw_below` belongs wholly to the nearest paw
if 'paw_below' in cfg:
	ends = np.array([leg['end'] for leg in cfg['legs']]); paws = [idx[leg['bones'][-1]] for leg in cfg['legs']]
	near = np.argmin(((P[:, None, [0, 2]] - ends[None, :, [0, 2]]) ** 2).sum(2), 1)
	m = ss(cfg['paw_below'] + 0.03, cfg['paw_below'] - 0.03, y)
	Wp = np.zeros((N, NB)); Wp[np.arange(N), np.array(paws)[near]] = 1
	W = W * (1 - m)[:, None] + Wp * m[:, None]
# tail
tb = cfg['tail']; Wl, d = chain_weights(P, tb['bones'], np.array(tb['end']))
m = (1 - ss(tb['radius'] * 0.8, tb['radius'] * 1.25, d)) * ss(tb['start_z'] + 0.05, tb['start_z'] - 0.05, z)
W = W * (1 - m)[:, None] + Wl * m[:, None]
# head and jaw
hd = cfg['head']
dh = np.linalg.norm(P - np.array(hd['center']), axis=1)
m = np.maximum(ss(hd['radius'] + 0.04, hd['radius'] - 0.04, dh) * ss(hd['min_y'] - 0.05, hd['min_y'] + 0.05, y), ss(hd['front_z'] - 0.04, hd['front_z'] + 0.04, z))
Wh = np.zeros((N, NB)); Wh[:, idx['Head']] = 1
jw = cfg['jaw']; jm = ss(jw['z0'], jw['z1'], z) * ss(jw['y1'], jw['y0'], y)
Wh[:, idx['Head']] -= jm; Wh[:, idx['Jaw']] += jm
W = W * (1 - m)[:, None] + Wh * m[:, None]
for ear in cfg.get('ears', []):  # ears ride their own bones
	m = ss(ear['radius'] + 0.03, ear['radius'] - 0.03, np.linalg.norm(P - np.array(ear['center']), axis=1)) * ss(ear['min_y'] - 0.02, ear['min_y'] + 0.03, y)
	We = np.zeros((N, NB)); We[:, idx[ear['bone']]] = 1
	W = W * (1 - m)[:, None] + We * m[:, None]
# muscles (config 'muscles'): the skin over a shoulder or thigh, up the side of the body,
# rides that leg's bone: fading out with distance from the bone and towards the midline
for mu in cfg.get('muscles', []):
	A_, B_ = np.array(mu['a']), np.array(mu['b']); ab = B_ - A_
	t = np.clip(((P - A_) @ ab) / (ab @ ab), 0, 1); dd = np.linalg.norm(P - (A_ + t[:, None] * ab), axis=1)
	r = mu['radius']
	m = (1 - ss(r * mu.get('soft', 0.55), r, dd)) * ss(mu['inner'], mu['inner'] + 0.06, mu['side'] * x) * mu.get('strength', 0.85)
	Wm = np.zeros((N, NB)); Wm[:, idx[mu['bone']]] = 1
	W = W * (1 - m)[:, None] + Wm * m[:, None]
# joint helpers (config 'helpers'): a bone at a leg joint that turns half as far as the
# joint; the skin right round the joint rides it, so the joint keeps its thickness
for h in cfg.get('helpers', []):
	leg = next(l for l in cfg['legs'] if l['bones'][0] == h['leg'])
	bones = leg['bones']; chain = np.vstack([JP[[idx[b] for b in bones]], np.array(leg['end'])])
	best = np.full(N, 1e9); u = np.zeros(N)
	for i in range(len(chain) - 1):
		A_, B_ = chain[i], chain[i + 1]; ab = B_ - A_
		t = np.clip(((P - A_) @ ab) / (ab @ ab), 0, 1); dd = np.linalg.norm(P - (A_ + t[:, None] * ab), axis=1)
		mm = dd < best; best[mm] = dd[mm]; u[mm] = i + t[mm]
	on_leg = W[:, [idx[b] for b in bones]].sum(1)  # how much of each point the leg already owns
	share = np.clip(1 - np.abs(u - h['joint']) / h.get('width', 0.3), 0, 1) * 0.8 * on_leg
	W = W * (1 - share)[:, None]; W[:, idx[h['bone']]] += share
# smooth over the mesh a little (welded neighbours)
I = acc(j, bn, p['indices']).reshape(-1, 3).astype(np.int64)
_, wid = np.unique(np.round(P, 5), axis=0, return_inverse=True); wid = wid.ravel(); nW = wid.max() + 1
E = np.unique(np.sort(wid[np.concatenate([I[:, [0, 1]], I[:, [1, 2]], I[:, [2, 0]]])], 1), axis=0); E = E[E[:, 0] != E[:, 1]]
S = np.zeros((nW, NB)); cnt = np.zeros(nW); np.add.at(S, wid, W); np.add.at(cnt, wid, 1); Ww = S / cnt[:, None]
for _ in range(cfg.get('smooth', 2)):
	S = Ww.copy(); cnt = np.ones(nW)
	for a0, a1 in [(0, 1), (1, 0)]: np.add.at(S, E[:, a0], Ww[E[:, a1]]); np.add.at(cnt, E[:, a0], 1)
	Ww = S / cnt[:, None]
W = Ww[wid]
Jn = np.argsort(-W, 1)[:, :4]; Wn = np.take_along_axis(W, Jn, 1); Wn /= Wn.sum(1, keepdims=True)
print('dominant bone counts', dict(zip(names, np.bincount(Jn[:, 0], minlength=NB).tolist())))
def add(arr, ctype, typ, minmax=False):
	while len(bn) % 4: bn.append(0)
	b = arr.tobytes(); j['bufferViews'].append({'buffer': 0, 'byteOffset': len(bn), 'byteLength': len(b)}); bn.extend(b)
	accd = {'bufferView': len(j['bufferViews']) - 1, 'componentType': ctype, 'count': len(arr), 'type': typ}
	if minmax: accd['min'] = [float(arr.min())]; accd['max'] = [float(arr.max())]
	j['accessors'].append(accd); return len(j['accessors']) - 1
a['JOINTS_0'] = add(Jn.astype(np.uint8), 5121, 'VEC4'); a['WEIGHTS_0'] = add(Wn.astype(np.float32), 5126, 'VEC4')
first = len(j['nodes'])
for i, n in enumerate(names):
	loc = JP[i] - (JP[par[i]] if par[i] >= 0 else 0)
	node = {'name': n, 'translation': [float(v) for v in loc]}
	kids = [first + k for k in range(NB) if par[k] == i]
	if kids: node['children'] = kids
	j['nodes'].append(node)
ibm = np.array([np.eye(4) for _ in names])
for i in range(NB): ibm[i][:3, 3] = -JP[i]
j['skins'] = [{'joints': list(range(first, first + NB)), 'inverseBindMatrices': add(ibm.transpose(0, 2, 1).reshape(NB, 16).astype(np.float32), 5126, 'MAT4'), 'skeleton': first}]
mesh_node = next(i for i, n in enumerate(j['nodes']) if 'mesh' in n); j['nodes'][mesh_node]['skin'] = 0
j['scenes'][j.get('scene', 0)]['nodes'] = [mesh_node] + [first + i for i in range(NB) if par[i] < 0]
# --- animations: python functions of t returning {bone: (rx, ry, rz)} and optional root offset ---
anims = {}
import os
base = os.path.dirname(os.path.abspath(sys.argv[1]))  # animation files sit beside the config
env = {'np': np, 'anims': anims, 'cfg': cfg, 'names': names, 'JP': JP, 'par': par, 'idx': idx, 'os': os, 'base': base}  # (base: the config's folder, for data files)
if cfg.get('lib'):
	exec(open(os.path.join(base, cfg['lib'])).read(), env)
for anims_file in (cfg['anims'] if isinstance(cfg['anims'], list) else [cfg['anims']]):  # (a list: later files add to or replace earlier ones' animations)
	exec(open(os.path.join(base, anims_file)).read(), env)
def quat(e):
	cx, sx = np.cos(e[0] / 2), np.sin(e[0] / 2); cy, sy = np.cos(e[1] / 2), np.sin(e[1] / 2); cz, sz = np.cos(e[2] / 2), np.sin(e[2] / 2)
	qx = np.array([sx, 0, 0, cx]); qy = np.array([0, sy, 0, cy]); qz = np.array([0, 0, sz, cz])
	def mul(q1, q2):
		x1, y1, z1, w1 = q1; x2, y2, z2, w2 = q2
		return np.array([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2, w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2])
	return mul(mul(qy, qx), qz)
j['animations'] = []
for name, (length, fn) in anims.items():
	ts = np.linspace(0, length, int(round(length * 30)) + 1)
	frames = [fn(t) for t in ts]; tin = add(ts.astype(np.float32), 5126, 'SCALAR', True)
	for f in frames:  # joint helpers turn half as far as their joint
		for h in cfg.get('helpers', []):
			e = f.get(h['half_of'], (0, 0, 0)); f[h['bone']] = (e[0] * 0.5, e[1] * 0.5, e[2] * 0.5)
	samplers, channels = [], []
	for bname in names:
		q = np.array([quat(f.get(bname, (0, 0, 0))) for f in frames], np.float32)
		samplers.append({'input': tin, 'output': add(q, 5126, 'VEC4'), 'interpolation': 'LINEAR'})
		channels.append({'sampler': len(samplers) - 1, 'target': {'node': first + idx[bname], 'path': 'rotation'}})
	root = cfg['root']
	tr = np.array([JP[idx[root]] - (JP[par[idx[root]]] if par[idx[root]] >= 0 else 0) + np.array(f.get('_offset', (0, 0, 0))) for f in frames], np.float32)
	samplers.append({'input': tin, 'output': add(tr, 5126, 'VEC3'), 'interpolation': 'LINEAR'})
	channels.append({'sampler': len(samplers) - 1, 'target': {'node': first + idx[root], 'path': 'translation'}})
	j['animations'].append({'name': name, 'samplers': samplers, 'channels': channels})
print('animations', list(anims))
while len(bn) % 4: bn.append(0)
j['buffers'][0]['byteLength'] = len(bn)
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
open(dst, 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bn)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bn), 0x004E4942) + bytes(bn))
