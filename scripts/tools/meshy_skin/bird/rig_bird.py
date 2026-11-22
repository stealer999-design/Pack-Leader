## Rigs and animates a Meshy bird from two models of it: one standing with its wings
## folded (the bird itself) and one with its wings spread (only its wings are used).
## The folded model gets a skeleton (hips, spine, chest, neck, head, lower beak,
## tail, two three-bone legs, a bone per folded wing); the spread model's open wings
## are cut out, scaled and placed at the folded bird's shoulders, on two-bone wing
## chains of their own (WingOpenL/R), and kept shrunk to nothing until a flap: then
## the folded wings tuck away as the open ones sweep out. Animations are python
## functions of time (bird_anims.py) returning {bone: (rx, ry, rz)}, an optional
## '_offset' for the hips and '_scale' {bone: s}.
## python3 rig_bird.py config.json folded.glb spread.glb out.glb
import sys, os, io, json, struct, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + '/..')
from glb import load, acc
from PIL import Image
cfg = json.load(open(sys.argv[1])); base = os.path.dirname(os.path.abspath(sys.argv[1]))
j, bn = load(sys.argv[2]); bn = bytearray(bn)
js_, bs_ = load(sys.argv[3])
K = cfg['scale']
p = j['meshes'][0]['primitives'][0]; a = p['attributes']
P = acc(j, bn, a['POSITION']).astype(float) * K
UV = acc(j, bn, a['TEXCOORD_0'])
def texture_colours(jj, bb, uv):
	ti = jj['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']; im = jj['images'][jj['textures'][ti]['source']]; v = jj['bufferViews'][im['bufferView']]
	A = np.asarray(Image.open(io.BytesIO(bytes(bb[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]))).convert('RGB')).astype(float); h, w, _ = A.shape
	return A[np.clip((uv[:, 1] * h).astype(int), 0, h - 1), np.clip((uv[:, 0] * w).astype(int), 0, w - 1)]
C = texture_colours(j, bn, UV); lum = C.mean(1)
def put(i, arr):
	ac = j['accessors'][i]; v = j['bufferViews'][ac['bufferView']]; off = v.get('byteOffset', 0) + ac.get('byteOffset', 0)
	b = arr.tobytes(); bn[off:off + len(b)] = b
put(a['POSITION'], P.astype(np.float32)); j['accessors'][a['POSITION']]['min'] = P.min(0).tolist(); j['accessors'][a['POSITION']]['max'] = P.max(0).tolist()
# --- skeleton ---
B = cfg['bones']; names = list(B.keys()); idx = {n: i for i, n in enumerate(names)}
JP = np.array([B[n][1] for n in names], float); par = [idx.get(B[n][0], -1) for n in names]
NB = len(names); N = len(P)
def ss(e0, e1, x): t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)
def chain_weights(pts, bones, end):
	chain = np.vstack([JP[[idx[b] for b in bones]], end])
	best = np.full(len(pts), 1e9); si = np.zeros(len(pts), int); ti = np.zeros(len(pts))
	for i in range(len(chain) - 1):
		A_, B_ = chain[i], chain[i + 1]; ab = B_ - A_
		t = np.clip(((pts - A_) @ ab) / (ab @ ab), 0, 1); d = np.linalg.norm(pts - (A_ + t[:, None] * ab), axis=1)
		m = d < best; best[m] = d[m]; si[m] = i; ti[m] = t[m]
	W = np.zeros((len(pts), NB)); u = si + ti
	for k, b in enumerate(bones):
		W[:, idx[b]] = np.clip(1 - np.abs(u - (k + 0.5)) / 0.75, 0, 1) if len(bones) > 1 else 1
	W[W.sum(1) == 0, idx[bones[0]]] = 1
	return W / W.sum(1, keepdims=True), best
x, y, z = P[:, 0], P[:, 1], P[:, 2]
W, _ = chain_weights(P, cfg['spine'], np.array(cfg['spine_end']))
# tail: behind and below the hips
tb = cfg['tail']; Wt, d = chain_weights(P, tb['bones'], np.array(tb['end']))
m = ss(tb['start_y'] + 0.05, tb['start_y'] - 0.05, y) * ss(tb['start_z'] + 0.05, tb['start_z'] - 0.05, z) * (1 - ss(tb['radius'] * 0.8, tb['radius'] * 1.2, d))
W = W * (1 - m)[:, None] + Wt * m[:, None]
# head (and the lower beak)
hd = cfg['head']; m = ss(hd['below'] - 0.04, hd['below'] + 0.04, y)
Wh = np.zeros((N, NB)); Wh[:, idx['Head']] = 1
jw = cfg['jaw']; jm = (np.linalg.norm(P - np.array(jw['center']), axis=1) < jw['radius']) & (lum < jw['dark']) & (y < jw['below'])
jm = jm.astype(float)
Wh[:, idx['Head']] -= jm; Wh[:, idx['Jaw']] += jm
W = W * (1 - m)[:, None] + Wh * m[:, None]
# folded wings: the dark feathers down each side
for side, nm in ((1, 'WingL'), (-1, 'WingR')):
	fw = cfg['folded_wing']
	m = (lum < fw['dark']).astype(float) * ss(fw['inner'] - 0.03, fw['inner'] + 0.03, side * x) * ss(fw['top'] + 0.04, fw['top'] - 0.04, y) * ss(fw['bottom'] - 0.04, fw['bottom'] + 0.04, y)
	Ww = np.zeros((N, NB)); Ww[:, idx[nm]] = 1
	W = W * (1 - m)[:, None] + Ww * m[:, None]
# legs: below the belly, near each leg's line (everything below `foot_below` wholly on its foot)
for leg in cfg['legs']:
	bones = leg['bones']; end = np.array(leg['end'])
	Wl, d = chain_weights(P, bones, end)
	side = np.sign(end[0])
	m = (1 - ss(leg['radius'] * 0.8, leg['radius'] * 1.2, d)) * ss(leg['top'] + 0.04, leg['top'] - 0.04, y) * (side * x > 0.02)
	foot = (y < cfg['foot_below']) & (side * x > 0.02)
	Wf = np.zeros((N, NB)); Wf[:, idx[bones[-1]]] = 1
	W = W * (1 - m)[:, None] + Wl * m[:, None]
	W[foot] = Wf[foot]
# smooth over the mesh (welded neighbours), legs and wings kept apart from each other
I = acc(j, bn, p['indices']).reshape(-1, 3).astype(np.int64)
_, wid = np.unique(np.round(P, 5), axis=0, return_inverse=True); wid = wid.ravel(); nW = wid.max() + 1
E = np.unique(np.sort(wid[np.concatenate([I[:, [0, 1]], I[:, [1, 2]], I[:, [2, 0]]])], 1), axis=0); E = E[E[:, 0] != E[:, 1]]
S = np.zeros((nW, NB)); cnt = np.zeros(nW); np.add.at(S, wid, W); np.add.at(cnt, wid, 1); Ww = S / cnt[:, None]
for _ in range(cfg.get('smooth', 2)):
	S = Ww.copy(); cnt = np.ones(nW)
	for a0, a1 in [(0, 1), (1, 0)]: np.add.at(S, E[:, a0], Ww[E[:, a1]]); np.add.at(cnt, E[:, a0], 1)
	Ww = S / cnt[:, None]
W = Ww[wid]
# no point keeps weight from the other side's leg or wing
for i_b, n in enumerate(names):
	if n.startswith('L_') or n == 'WingL': W[P[:, 0] < 0, i_b] = 0
	if n.startswith('R_') or n == 'WingR': W[P[:, 0] > 0, i_b] = 0
W /= W.sum(1, keepdims=True)
Jn = np.argsort(-W, 1)[:, :4]; Wn = np.take_along_axis(W, Jn, 1); Wn /= Wn.sum(1, keepdims=True)
print('dominant bone counts', {n: c for n, c in zip(names, np.bincount(Jn[:, 0], minlength=NB).tolist()) if c})
# --- glb helpers ---
def add(arr, ctype, typ, minmax=False):
	while len(bn) % 4: bn.append(0)
	b = arr.tobytes(); j['bufferViews'].append({'buffer': 0, 'byteOffset': len(bn), 'byteLength': len(b)}); bn.extend(b)
	accd = {'bufferView': len(j['bufferViews']) - 1, 'componentType': ctype, 'count': len(arr), 'type': typ}
	if minmax: accd['min'] = arr.min(0).tolist() if arr.ndim > 1 else [float(arr.min())]; accd['max'] = arr.max(0).tolist() if arr.ndim > 1 else [float(arr.max())]
	j['accessors'].append(accd); return len(j['accessors']) - 1
a['JOINTS_0'] = add(Jn.astype(np.uint8), 5121, 'VEC4'); a['WEIGHTS_0'] = add(Wn.astype(np.float32), 5126, 'VEC4')
# --- the open wings, from the spread model ---
pa = js_['meshes'][0]['primitives'][0]['attributes']
Ps = acc(js_, bs_, pa['POSITION']).astype(float) * cfg['spread_scale']
Ns = acc(js_, bs_, pa['NORMAL']).astype(float); UVs = acc(js_, bs_, pa['TEXCOORD_0'])
Is = acc(js_, bs_, js_['meshes'][0]['primitives'][0]['indices']).reshape(-1, 3).astype(np.int64)
ow = cfg['open_wing']; root_s = np.array(ow['root_spread']) * cfg['spread_scale']
wing_pt = (np.abs(Ps[:, 0]) > ow['inner'] * cfg['spread_scale']) & (Ps[:, 1] > ow['above'] * cfg['spread_scale'])
keep = wing_pt[Is].all(1)
Q = Ps.copy(); Jw = np.zeros((len(Ps), 4), np.uint8); Wwg = np.zeros((len(Ps), 4), np.float32)
for side, nm in ((1, 'L'), (-1, 'R')):
	s = np.sign(Ps[:, 0]) == side
	r_s = root_s * np.array([side, 1, 1]); r_f = np.array(ow['root_folded']) * np.array([side, 1, 1])
	Q[s] = (Ps[s] - r_s) * ow['size'] + r_f
	b1, b2 = idx['WingOpen%s1' % nm], idx['WingOpen%s2' % nm]
	span = np.abs(Q[s, 0] - r_f[0]); t = np.clip((span - ow['elbow'] * 0.7) / (ow['elbow'] * 0.6), 0, 1)
	Jw[s, 0] = b1; Jw[s, 1] = b2; Wwg[s, 0] = 1 - t; Wwg[s, 1] = t
prim = {'attributes': {'POSITION': add(Q.astype(np.float32), 5126, 'VEC3', True), 'NORMAL': add(Ns.astype(np.float32), 5126, 'VEC3'),
	'TEXCOORD_0': add(UVs.astype(np.float32), 5126, 'VEC2'), 'JOINTS_0': add(Jw, 5121, 'VEC4'), 'WEIGHTS_0': add(Wwg, 5126, 'VEC4')},
	'indices': add(Is[keep].reshape(-1).astype(np.uint32), 5125, 'SCALAR')}
# the spread model's texture as a second material
ti = js_['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']; im = js_['images'][js_['textures'][ti]['source']]; v = js_['bufferViews'][im['bufferView']]
img = bytes(bs_[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']])
while len(bn) % 4: bn.append(0)
j['bufferViews'].append({'buffer': 0, 'byteOffset': len(bn), 'byteLength': len(img)}); bn.extend(img)
j['images'].append({'bufferView': len(j['bufferViews']) - 1, 'mimeType': im.get('mimeType', 'image/png')})
j['textures'].append({'source': len(j['images']) - 1, **({'sampler': js_['textures'][ti]['sampler']} if 'sampler' in js_['textures'][ti] and j.get('samplers') else {})})
mat = json.loads(json.dumps(j['materials'][0])); mat['name'] = 'open_wings'
mat['pbrMetallicRoughness'] = {'baseColorTexture': {'index': len(j['textures']) - 1}, 'metallicFactor': 0.0, 'roughnessFactor': 0.9}
mat.pop('normalTexture', None); mat['doubleSided'] = True
j['materials'].append(mat); prim['material'] = len(j['materials']) - 1
j['meshes'][0]['primitives'].append(prim)
print('open wings: %d triangles' % keep.sum())
# --- nodes and skin ---
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
# --- animations ---
anims = {}
env = {'np': np, 'anims': anims, 'cfg': cfg, 'names': names, 'JP': JP, 'par': par, 'idx': idx}
exec(open(os.path.join(base, cfg['lib'])).read(), env)
exec(open(os.path.join(base, cfg['anims'])).read(), env)
def quat(e):
	cx, sx = np.cos(e[0] / 2), np.sin(e[0] / 2); cy, sy = np.cos(e[1] / 2), np.sin(e[1] / 2); cz, sz = np.cos(e[2] / 2), np.sin(e[2] / 2)
	qx = np.array([sx, 0, 0, cx]); qy = np.array([0, sy, 0, cy]); qz = np.array([0, 0, sz, cz])
	def mul(q1, q2):
		x1, y1, z1, w1 = q1; x2, y2, z2, w2 = q2
		return np.array([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2, w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2])
	return mul(mul(qy, qx), qz)
HIDDEN = 0.001  # open wings, folded away to nothing
j['animations'] = []
for name, (length, fn) in anims.items():
	ts = np.linspace(0, length, int(round(length * 30)) + 1)
	frames = [fn(t) for t in ts]; tin = add(ts.astype(np.float32), 5126, 'SCALAR', True)
	samplers, channels = [], []
	for bname in names:
		q = np.array([quat(f.get(bname, (0, 0, 0))) for f in frames], np.float32)
		samplers.append({'input': tin, 'output': add(q, 5126, 'VEC4'), 'interpolation': 'LINEAR'})
		channels.append({'sampler': len(samplers) - 1, 'target': {'node': first + idx[bname], 'path': 'rotation'}})
	for bname in names:
		if not (bname.startswith('WingOpen') and bname.endswith('1')) and not bname in ('WingL', 'WingR'):
			continue
		dflt = HIDDEN if bname.startswith('WingOpen') else 1.0
		sc = np.array([[max(f.get('_scale', {}).get(bname, dflt), HIDDEN)] * 3 for f in frames], np.float32)
		samplers.append({'input': tin, 'output': add(sc, 5126, 'VEC3'), 'interpolation': 'LINEAR'})
		channels.append({'sampler': len(samplers) - 1, 'target': {'node': first + idx[bname], 'path': 'scale'}})
	root = cfg['root']
	tr = np.array([JP[idx[root]] + np.array(f.get('_offset', (0, 0, 0))) for f in frames], np.float32)
	samplers.append({'input': tin, 'output': add(tr, 5126, 'VEC3'), 'interpolation': 'LINEAR'})
	channels.append({'sampler': len(samplers) - 1, 'target': {'node': first + idx[root], 'path': 'translation'}})
	j['animations'].append({'name': name, 'samplers': samplers, 'channels': channels})
print('animations', list(anims))
while len(bn) % 4: bn.append(0)
j['buffers'][0]['byteLength'] = len(bn)
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
open(sys.argv[4], 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bn)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bn), 0x004E4942) + bytes(bn))
