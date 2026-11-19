## Pye: in the named animations, hold the arm (wing) bones in a folded pose,
## (run on the Meshy merged export; skin.py and glb.py sit beside it)
## tucked back along the body, instead of swinging them.
## python3 fold_wings.py in.glb out.glb [--spread] Anim1 [Anim2 ...]
## --spread: held open instead, like a goose squaring up (raised out to the
## sides, the outer feathers sweeping down)
import sys, json, struct, numpy as np
sys.path.insert(0, '.')
from glb import load, acc
from skin import q2m, trs
src, dst, names = sys.argv[1], sys.argv[2], sys.argv[3:]
SPREAD = '--spread' in names; names = [n for n in names if n != '--spread']
j, bn = load(src); bn = bytearray(bn)
N = j['nodes']; parent = {c: i for i, n in enumerate(N) for c in n.get('children', [])}
G = {}
def g(i):
	if i not in G:
		n = N[i]; M = trs(n.get('translation', [0, 0, 0]), n.get('rotation', [0, 0, 0, 1]), n.get('scale', [1, 1, 1]))
		G[i] = (g(parent[i]) @ M) if i in parent else M
	return G[i]
byname = {n.get('name'): i for i, n in enumerate(N)}
def m2q(m):
	w = np.sqrt(max(0, 1 + m[0, 0] + m[1, 1] + m[2, 2])) / 2
	x = np.sqrt(max(0, 1 + m[0, 0] - m[1, 1] - m[2, 2])) / 2 * np.sign(m[2, 1] - m[1, 2])
	y = np.sqrt(max(0, 1 - m[0, 0] + m[1, 1] - m[2, 2])) / 2 * np.sign(m[0, 2] - m[2, 0])
	z = np.sqrt(max(0, 1 - m[0, 0] - m[1, 1] + m[2, 2])) / 2 * np.sign(m[1, 0] - m[0, 1])
	q = np.array([x, y, z, w]); return q / np.linalg.norm(q)
def align(a, b):  # rotation taking direction a to b
	a = a / np.linalg.norm(a); b = b / np.linalg.norm(b); v = np.cross(a, b); c = a @ b
	if np.linalg.norm(v) < 1e-8: return np.eye(3)
	K = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
	return np.eye(3) + K + K @ K * (1 / (1 + c))
# targets in model space (Meshy faces +Z; the bird's left wing is +X): down-back, then back
TARGET = {'Arm': np.array([0.25, -0.75, -0.6]), 'ForeArm': np.array([0.08, -0.4, -0.92]), 'Hand': np.array([0.04, -0.25, -0.97])}
if SPREAD:
	TARGET = {'Arm': np.array([0.8, 0.5, -0.15]), 'ForeArm': np.array([0.9, -0.15, -0.1]), 'Hand': np.array([0.6, -0.75, 0.0])}
fold = {}  # node -> local quaternion
for side, sx in (('Left', 1), ('Right', -1)):
	chain = [side + 'Arm', side + 'ForeArm', side + 'Hand']
	newG = {}
	pg = g(byname[side + 'Shoulder'])[:3, :3]  # the shoulder keeps its rest pose
	for k, b in enumerate(chain):
		i = byname[b]; Gi = g(i)[:3, :3]
		child = byname[chain[k + 1]] if k + 1 < len(chain) else None
		rest_dir = (g(child)[:3, 3] - g(i)[:3, 3]) if child is not None else Gi @ (np.linalg.inv(g(parent[i])[:3, :3] @ np.eye(3)) @ (g(i)[:3, 3] - g(parent[i])[:3, 3]))
		# the bone's direction in its own frame, carried by the parent's new rotation
		cur = pg @ q2m(N[i].get('rotation', [0, 0, 0, 1]))
		d_now = cur @ np.linalg.inv(Gi) @ rest_dir
		t = TARGET[b.replace(side, '')] * np.array([sx, 1, 1])
		Gnew = align(d_now, t) @ cur
		fold[i] = m2q(np.linalg.inv(pg) @ Gnew)
		pg = Gnew
done = 0
for a in j['animations']:
	if a['name'] not in names: continue
	for ch in a['channels']:
		node = ch['target']['node']
		if node in fold and ch['target']['path'] == 'rotation':
			ac = j['accessors'][a['samplers'][ch['sampler']]['output']]; v = j['bufferViews'][ac['bufferView']]
			off = v.get('byteOffset', 0) + ac.get('byteOffset', 0)
			arr = np.tile(fold[node].astype(np.float32), (ac['count'], 1)); b = arr.tobytes(); bn[off:off + len(b)] = b; done += 1
print('wing tracks held folded:', done)
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
open(dst, 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bn)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bn), 0x004E4942) + bytes(bn))
