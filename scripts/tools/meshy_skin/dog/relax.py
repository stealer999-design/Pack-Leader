# The last few stretched edges: wherever an edge still stretches (over 2.5x, as
# stretch.py counts) in any animation, blends the weights of the points around it
# with their neighbours', and checks again, until none are left (or `passes` run out).
# python3 relax.py in.glb out.glb [passes]
import sys, json, struct, numpy as np
sys.path.insert(0, '.')
from glb import load, acc
from skin import Rig
j, bn = load(sys.argv[1]); bn = bytearray(bn); r = Rig(j, bytes(bn))
p = j['meshes'][0]['primitives'][0]; a = p['attributes']
P = acc(j, bn, a['POSITION']).astype(float); J = acc(j, bn, a['JOINTS_0']).astype(int); W = acc(j, bn, a['WEIGHTS_0']).astype(float)
I = acc(j, bn, p['indices']).reshape(-1, 3)
E = np.unique(np.sort(np.concatenate([I[:, [0, 1]], I[:, [1, 2]], I[:, [2, 0]]]), 1), axis=0); E = E[E[:, 0] != E[:, 1]]
L0 = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1)
NB = len(j['skins'][0]['joints']); N = len(P)
D = np.zeros((N, NB)); np.add.at(D, (np.repeat(np.arange(N), 4), J.ravel()), W.ravel())
_, wid = np.unique(np.round(P, 5), axis=0, return_inverse=True); wid = wid.ravel()
poses = [(n, r.length(n) * k / 16) for n in r.anims for k in range(16)]
mats = [r.pose(n, t) for n, t in poses]
def skinned(D):
	Jn = np.argsort(-D, 1)[:, :4]; Wn = np.take_along_axis(D, Jn, 1); Wn /= Wn.sum(1, keepdims=True)
	return Jn, Wn
def bad_edges(D):
	Jn, Wn = skinned(D); worst = np.zeros(len(E))
	for m in mats:
		X = r.skin(m, P, Jn, Wn); worst = np.maximum(worst, (np.linalg.norm(X[E[:, 0]] - X[E[:, 1]], axis=1) - 0.002) / (L0 + 0.002))
	return np.nonzero(worst > 2.5)[0]
for it in range(int(sys.argv[3]) if len(sys.argv) > 3 else 8):
	bad = bad_edges(D); print('pass', it, 'stretched edges', len(bad))
	if len(bad) == 0: break
	pts = np.unique(E[bad].ravel())
	ring = pts
	for _ in range(2 if it >= 6 else 1):  # their neighbours (two rings deep if one isn't enough)
		near = E[np.isin(E[:, 0], ring) | np.isin(E[:, 1], ring)]
		ring = np.unique(np.concatenate([ring, near.ravel()]))
	S = D.copy(); cnt = np.ones(N)
	for a0, a1 in ((0, 1), (1, 0)): np.add.at(S, E[:, a0], D[E[:, a1]]); np.add.at(cnt, E[:, a0], 1)
	D[ring] = S[ring] / cnt[ring][:, None]
	for w in np.unique(wid[ring]):  # welded copies (texture seams) keep one weighting
		g = np.nonzero(wid == w)[0]; D[g] = D[g].mean(0)
Jn, Wn = skinned(D)
def put(i, arr):
	ac = j['accessors'][i]; v = j['bufferViews'][ac['bufferView']]; off = v.get('byteOffset', 0) + ac.get('byteOffset', 0)
	b = arr.tobytes(); bn[off:off + len(b)] = b
put(a['JOINTS_0'], Jn.astype(np.uint8)); put(a['WEIGHTS_0'], Wn.astype(np.float32))
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
while len(bn) % 4: bn.append(0)
open(sys.argv[2], 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bn)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bn), 0x004E4942) + bytes(bn))
