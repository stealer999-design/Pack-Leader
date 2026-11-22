# Turns a Meshy bird's head (modelled looking off to one side) to face forward:
# the head swings round a vertical axis through its centre and slides over the
# body's midline, the neck below twisting gradually so nothing tears.
# python3 turn_head.py in.glb out.glb  (prints what it did)
import sys, io, json, struct, numpy as np
sys.path.insert(0, '.')
from glb import load, acc
from PIL import Image
j, bn = load(sys.argv[1]); bn = bytearray(bn)
p = j['meshes'][0]['primitives'][0]; a = p['attributes']
P = acc(j, bn, a['POSITION']).astype(float); N = acc(j, bn, a['NORMAL']).astype(float); UV = acc(j, bn, a['TEXCOORD_0'])
ti = j['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']; im = j['images'][j['textures'][ti]['source']]; v = j['bufferViews'][im['bufferView']]
A = np.asarray(Image.open(io.BytesIO(bytes(bn[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]))).convert('RGB')).astype(float); h, w, _ = A.shape
C = A[np.clip((UV[:, 1] * h).astype(int), 0, h - 1), np.clip((UV[:, 0] * w).astype(int), 0, w - 1)]
top = P[:, 1].max(); span = top - P[:, 1].min()
y0, y1 = top - 0.32 * span, top - 0.22 * span  # the neck: the twist happens between these heights
head = P[:, 1] > y1
hc = P[head][:, [0, 2]].mean(0)
beak = P[head & (C.max(1) < 55)][:, [0, 2]].mean(0)  # the beak is the dark part of the head
d = beak - hc; ang = np.arctan2(d[0], d[1])  # 0 = facing +z
body_x = P[(P[:, 1] < y0) & (P[:, 1] > y0 - 0.1 * span)][:, 0].mean()
def ss(x): x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)
k = ss((P[:, 1] - y0) / (y1 - y0))
th = -ang * k
c, s = np.cos(th), np.sin(th)
rx = P[:, 0] - hc[0]; rz = P[:, 2] - hc[1]
Q = P.copy()
Q[:, 0] = hc[0] + rx * c + rz * s + (body_x - hc[0]) * k
Q[:, 2] = hc[1] - rx * s + rz * c
M = N.copy(); M[:, 0] = N[:, 0] * c + N[:, 2] * s; M[:, 2] = -N[:, 0] * s + N[:, 2] * c
def put(i, arr):
	ac = j['accessors'][i]; vv = j['bufferViews'][ac['bufferView']]; off = vv.get('byteOffset', 0) + ac.get('byteOffset', 0)
	b = arr.astype(np.float32).tobytes(); bn[off:off + len(b)] = b
put(a['POSITION'], Q); put(a['NORMAL'], M)
j['accessors'][a['POSITION']]['min'] = Q.min(0).tolist(); j['accessors'][a['POSITION']]['max'] = Q.max(0).tolist()
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
while len(bn) % 4: bn.append(0)
open(sys.argv[2], 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bn)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bn), 0x004E4942) + bytes(bn))
print('head turned %.0f degrees, moved %.3f sideways; neck twist between y %.3f and %.3f' % (np.degrees(-ang), body_x - hc[0], y0, y1))
