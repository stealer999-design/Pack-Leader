# Meshy sometimes joins the insides of two legs that nearly touch; those triangles tear
# as the legs step apart. Drops (makes degenerate) every triangle whose corners ride
# different legs, and takes any other leg's weight off each leg's points (the rig's
# smoothing leaks it across those triangles). python3 cut_legs.py in.glb out.glb [belly_y]
import sys, numpy as np
sys.path.insert(0, '.')
from glb import load, acc
import json, struct
j, bn = load(sys.argv[1]); bn = bytearray(bn)
p = j['meshes'][0]['primitives'][0]; a = p['attributes']
J = acc(j, bn, a['JOINTS_0']).astype(int); W = acc(j, bn, a['WEIGHTS_0']).astype(float)
names = [j['nodes'][i]['name'] for i in j['skins'][0]['joints']]
leg_of = np.array([n[:2] if n[:2] in ('FL', 'FR', 'RL', 'RR') and '_' in n else '' for n in names])
dom = leg_of[J[np.arange(len(J)), W.argmax(1)]]
# weights: a point on one leg keeps nothing from another leg
bone_leg = leg_of[J]
other = (bone_leg != '') & (dom[:, None] != '') & (bone_leg != dom[:, None])
leaked = int((other & (W > 0)).any(1).sum())
W[other] = 0.0
# and no point keeps weight from a leg on the far side of the body (the chest between the
# front legs, the belly between the hind ones), fading in from the midline
P = acc(j, bn, a['POSITION']).astype(float)
side_of = np.array([{'L': 1.0, 'R': -1.0}.get(n[1], 0.0) if len(n) > 1 else 0.0 for n in leg_of])[J]
far = (side_of * np.sign(P[:, 0])[:, None] < 0)
fade = np.clip(np.abs(P[:, 0]) / 0.05, 0, 1)[:, None]
W = np.where(far, W * (1 - fade), W)
# body points on the midline (the chest and belly between the legs) follow the spine only
# (any point there, not just body points; the legs' inner faces lower down keep theirs)
legb = leg_of[J] != ''
belly = float(sys.argv[3]) if len(sys.argv) > 3 else -1e9  # the belly's height (rig units)
mid = np.maximum(np.clip((np.abs(P[:, 0]) - 0.025) / 0.07, 0, 1), np.clip((belly - 0.08 - P[:, 1]) / 0.06, 0, 1))[:, None]
W = np.where(legb, W * mid, W)
W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
wa = j['accessors'][a['WEIGHTS_0']]; wv = j['bufferViews'][wa['bufferView']]; woff = wv.get('byteOffset', 0) + wa.get('byteOffset', 0)
wb = W.astype(np.float32).tobytes(); bn[woff:woff + len(wb)] = wb
ac = j['accessors'][p['indices']]; I = acc(j, bn, p['indices']).reshape(-1, 3).copy()
d = dom[I]
bad = ((d[:, 0] != d[:, 1]) & (d[:, 0] != '') & (d[:, 1] != '')) | ((d[:, 1] != d[:, 2]) & (d[:, 1] != '') & (d[:, 2] != '')) | ((d[:, 0] != d[:, 2]) & (d[:, 0] != '') & (d[:, 2] != ''))
I[bad] = I[bad][:, :1]  # collapse onto the first corner
v = j['bufferViews'][ac['bufferView']]; off = v.get('byteOffset', 0) + ac.get('byteOffset', 0)
dt = {5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[ac['componentType']]
b = I.reshape(-1).astype(dt).tobytes(); bn[off:off + len(b)] = b
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
while len(bn) % 4: bn.append(0)
open(sys.argv[2], 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bn)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bn), 0x004E4942) + bytes(bn))
print(sys.argv[2], 'triangles between legs cut', int(bad.sum()), 'points unhooked from other legs', leaked)
