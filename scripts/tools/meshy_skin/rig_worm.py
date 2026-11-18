## Adds a skeleton to the Meshy Sand Wyrm (a static mesh): a root bone for the
## sand mound, a chain of body bones along the worm's centre line, a head bone
## and a mouth bone (scaled to gape). Weights blend smoothly along the body.
## python3 rig_worm.py in.glb out.glb
import sys, json, struct, numpy as np
sys.path.insert(0, '.')
from glb import load, acc
src, dst = sys.argv[1], sys.argv[2]
j, bn = load(src); bn = bytearray(bn)
p = j['meshes'][0]['primitives'][0]; a = p['attributes']
P = acc(j, bn, a['POSITION']).astype(float)
# Joints (model space, the worm faces +Z): mound root, body, head, mouth.
JN = ['Root', 'Body1', 'Body2', 'Body3', 'Body4', 'Head', 'Mouth']
JP = np.array([[0, -0.6, 0.3], [0, -0.38, 0.33], [0, -0.15, 0.35], [0, 0.07, 0.39],
			   [0, 0.24, 0.47], [0, 0.33, 0.62], [0, 0.33, 0.86]])
END = np.array([0, 0.33, 0.95])  # the mouth's tip
chain = np.vstack([JP[1:6], END])  # body1..head, then the tip: the centre line
seg_len = np.linalg.norm(np.diff(chain, axis=0), axis=1)
S = np.concatenate([[0], np.cumsum(seg_len)])
# closest point on the centre line: arclength s and distance d
best_d = np.full(len(P), 1e9); best_s = np.zeros(len(P))
for i in range(len(chain) - 1):
	A, B = chain[i], chain[i + 1]; ab = B - A
	t = np.clip(((P - A) @ ab) / (ab @ ab), 0, 1)
	d = np.linalg.norm(P - (A + t[:, None] * ab), axis=1)
	m = d < best_d; best_d[m] = d[m]; best_s[m] = S[i] + t[m] * seg_len[i]
NB = len(JN); W = np.zeros((len(P), NB))
mids = (S[:-1] + S[1:]) / 2  # bones Body1..Head own segments 0..4
for i, mid in enumerate(mids):
	sig = 0.55 * seg_len[i]
	W[:, 1 + i] = np.exp(-((best_s - mid) / sig) ** 2)
W /= W.sum(1, keepdims=True)
# the mouth: lips and teeth at the front of the head
mouth = np.clip((P[:, 2] - 0.74) / 0.1, 0, 1) * (best_s > S[4] - 0.05)
W *= (1 - mouth)[:, None]; W[:, 6] += mouth
# the mound and where the worm enters it stay put
y = P[:, 1]
mound = ((y < -0.36) & (best_d > 0.27)) | (y < -0.52)
root = np.where(mound, 1.0, np.clip((-0.3 - y) / 0.14, 0, 1))
W *= (1 - root)[:, None]; W[:, 0] += root
# keep the top four
Jn = np.argsort(-W, 1)[:, :4]; Wn = np.take_along_axis(W, Jn, 1); Wn /= Wn.sum(1, keepdims=True)
print('mound points', mound.sum(), 'mouth points', (mouth > 0.5).sum(), 'per-bone dominant', np.bincount(Jn[:, 0], minlength=NB))
# --- write the skin into the glTF ---
def add(arr, ctype, typ):
	while len(bn) % 4: bn.append(0)
	b = arr.tobytes(); j['bufferViews'].append({'buffer': 0, 'byteOffset': len(bn), 'byteLength': len(b)}); bn.extend(b)
	j['accessors'].append({'bufferView': len(j['bufferViews']) - 1, 'componentType': ctype, 'count': len(arr), 'type': typ})
	return len(j['accessors']) - 1
a['JOINTS_0'] = add(Jn.astype(np.uint8), 5121, 'VEC4')
a['WEIGHTS_0'] = add(Wn.astype(np.float32), 5126, 'VEC4')
first = len(j['nodes'])
for i, name in enumerate(JN):
	local = JP[i] - (JP[i - 1] if i else 0)
	node = {'name': name, 'translation': [float(v) for v in local]}
	if i + 1 < NB: node['children'] = [first + i + 1]
	j['nodes'].append(node)
ibm = np.array([np.eye(4) for _ in JN]);
for i in range(NB): ibm[i][:3, 3] = -JP[i]
ibm_acc = add(ibm.transpose(0, 2, 1).reshape(NB, 16).astype(np.float32), 5126, 'MAT4')
j['skins'] = [{'joints': list(range(first, first + NB)), 'inverseBindMatrices': ibm_acc, 'skeleton': first, 'name': 'Wyrm'}]
mesh_node = next(i for i, n in enumerate(j['nodes']) if 'mesh' in n)
j['nodes'][mesh_node]['skin'] = 0
j['scenes'][j.get('scene', 0)]['nodes'] = [mesh_node, first]
while len(bn) % 4: bn.append(0)
j['buffers'][0]['byteLength'] = len(bn)
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
open(dst, 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bn)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bn), 0x004E4942) + bytes(bn))
