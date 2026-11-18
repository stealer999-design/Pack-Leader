## Howard's Meshy/Mixamo skin: a fish has no arms, but the rig does. Its body was
## tied to the left shoulder and its side fins to the arm bones, so they warped
## and stretched into blades whenever the arms moved. Everything on the shoulder
## and arm chains goes to the upper spine instead. python3 fix_fish.py in out
import numpy as np, sys, json, struct
sys.path.insert(0, '.')
from glb import load, acc
src, dst = sys.argv[1], sys.argv[2]
j, bn = load(src)
p = j['meshes'][0]['primitives'][0]; a = p['attributes']
J = acc(j, bn, a['JOINTS_0']).astype(int); W = acc(j, bn, a['WEIGHTS_0']).astype(float)
names = [j['nodes'][i]['name'] for i in j['skins'][0]['joints']]
spine2 = names.index('mixamorig:Spine2')
arms = [i for i, n in enumerate(names) if any(k in n for k in ('Shoulder', 'Arm', 'Hand'))]
N = len(J); D = np.zeros((N, len(names)))
for k in range(4): np.add.at(D, (np.arange(N), J[:, k]), W[:, k])
D[:, spine2] += D[:, arms].sum(1); D[:, arms] = 0
Jn = np.argsort(-D, 1)[:, :4]; Wn = np.take_along_axis(D, Jn, 1); Wn /= Wn.sum(1, keepdims=True)
print('moved to Spine2 from', [names[i] for i in arms])
def put(i, arr):
	ac = j['accessors'][i]; v = j['bufferViews'][ac['bufferView']]; off = v.get('byteOffset', 0) + ac.get('byteOffset', 0)
	b = arr.tobytes(); bn[off:off + len(b)] = b
put(a['JOINTS_0'], Jn.astype(np.uint8)); put(a['WEIGHTS_0'], Wn.astype(np.float32))
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
open(dst, 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bn)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bn), 0x004E4942) + bytes(bn))
