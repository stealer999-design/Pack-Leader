## Turns a four-legged Meshy model's head (modelled looking off to one side) to face
## straight along the body: the head and neck swing round a vertical axis through
## the neck, by an amount that ramps from nothing at the shoulders to the full turn
## at the head, so the neck twists gradually and nothing tears. Works in the rig's
## frame (the config's yaw_deg/scale), and writes the model back in its own frame.
## python3 turn_head_quad.py config.json in.glb out.glb degrees [ramp_from_z ramp_to_z]
import sys, json, struct, numpy as np
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from glb import load, acc
cfg = json.load(open(sys.argv[1])); j, bn = load(sys.argv[2]); bn = bytearray(bn)
deg = float(sys.argv[4])
a = j['meshes'][0]['primitives'][0]['attributes']
P0 = acc(j, bn, a['POSITION']).astype(float); N0 = acc(j, bn, a['NORMAL']).astype(float)
yaw = np.radians(cfg['yaw_deg']); c, s = np.cos(-yaw), np.sin(-yaw)
R = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]]); k = cfg.get('scale', 1.0)
P = P0 @ R.T * k; Nn = N0 @ R.T
neck = np.array(cfg['bones']['Neck'][1]); chest = np.array(cfg['bones']['Chest'][1]); head = np.array(cfg['bones']['Head'][1])
z0 = float(sys.argv[5]) if len(sys.argv) > 5 else (chest[2] + neck[2]) / 2
z1 = float(sys.argv[6]) if len(sys.argv) > 6 else head[2] - 0.05
def ss(x): x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)
# only the neck and head turn: not the fore legs, which reach as far forward
y0 = chest[1] - 0.3; y1 = chest[1] - 0.15
hc = np.array(cfg['head']['center'])
upper_body = np.maximum(ss((P[:, 1] - y0) / (y1 - y0)), (np.linalg.norm(P - hc, axis=1) < cfg['head']['radius'] * 1.1).astype(float))
t = ss((P[:, 2] - z0) / (z1 - z0)) * upper_body * np.radians(deg)
cx, sx = np.cos(t), np.sin(t)
rx = P[:, 0] - neck[0]; rz = P[:, 2] - neck[2]
Q = P.copy(); Q[:, 0] = neck[0] + rx * cx + rz * sx; Q[:, 2] = neck[2] - rx * sx + rz * cx
M = Nn.copy(); M[:, 0] = Nn[:, 0] * cx + Nn[:, 2] * sx; M[:, 2] = -Nn[:, 0] * sx + Nn[:, 2] * cx
Q = (Q / k) @ R; M = M @ R  # back to the model's own frame
def put(i, arr):
	ac = j['accessors'][i]; v = j['bufferViews'][ac['bufferView']]; off = v.get('byteOffset', 0) + ac.get('byteOffset', 0)
	b = arr.astype(np.float32).tobytes(); bn[off:off + len(b)] = b
put(a['POSITION'], Q); put(a['NORMAL'], M)
j['accessors'][a['POSITION']]['min'] = Q.min(0).tolist(); j['accessors'][a['POSITION']]['max'] = Q.max(0).tolist()
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
while len(bn) % 4: bn.append(0)
open(sys.argv[3], 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bn)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bn), 0x004E4942) + bytes(bn))
print('head turned %.1f degrees round the neck, twisting from z %.2f to %.2f' % (deg, z0, z1))
