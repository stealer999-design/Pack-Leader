## Bleeds each UV island's colour out into the empty texture around it, so a
## shrunk or mipmapped texture doesn't pull the background colour into the
## edges of leaves and other small pieces. With --fill-grey, flat grey patches
## (triangles Meshy left unpainted, common on foliage) are filled from around
## them too. python3 pad_texture.py in.glb out.glb [--fill-grey]
import sys, io, json, struct, numpy as np
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb import load, acc
from PIL import Image, ImageDraw
src, dst = sys.argv[1], sys.argv[2]
j, bn = load(src); bn = bytes(bn)
p = j['meshes'][0]['primitives'][0]
UV = acc(j, bn, p['attributes']['TEXCOORD_0']); I = acc(j, bn, p['indices']).reshape(-1, 3)
ti = j['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']
img_i = j['textures'][ti]['source']; im = j['images'][img_i]; v = j['bufferViews'][im['bufferView']]
off = v.get('byteOffset', 0)
pic = Image.open(io.BytesIO(bn[off:off + v['byteLength']])).convert('RGB'); W, H = pic.size
mask = Image.new('L', (W, H), 0); d = ImageDraw.Draw(mask)
for t in I:
	d.polygon([(UV[k][0] * W, UV[k][1] * H) for k in t], fill=255, outline=255)
m = np.asarray(mask) > 0
a = np.asarray(pic).astype(np.float32)
if '--fill-grey' in sys.argv:
	grey = (np.ptp(a, axis=2) < 10) & (a.mean(2) > 90) & (a.mean(2) < 175)
	print('unpainted grey %.1f%%' % (grey.mean() * 100))
	m &= ~grey
bg = a[~m].mean(0) if (~m).any() else None
print('covered %.1f%%, background mean colour %s' % (m.mean() * 100, None if bg is None else bg.round()))
# grow the islands outward step by step, each new pixel the mean of its covered neighbours
filled = m.copy(); col = a * m[..., None]
for _ in range(48):
	acc_c = np.zeros_like(col); cnt = np.zeros(m.shape, np.float32)
	for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)):
		sh_f = np.roll(np.roll(filled, dy, 0), dx, 1); sh_c = np.roll(np.roll(col, dy, 0), dx, 1)
		acc_c += sh_c * sh_f[..., None]; cnt += sh_f
	new = (~filled) & (cnt > 0)
	if not new.any(): break
	col[new] = acc_c[new] / cnt[new][:, None]; filled |= new
col[~filled] = a[m].mean(0)
out = io.BytesIO(); Image.fromarray(col.clip(0, 255).astype(np.uint8)).save(out, 'PNG'); data = out.getvalue()
# rebuild the binary chunk with the new image
views = j['bufferViews']; blobs = []
for k, bv in enumerate(views):
	o = bv.get('byteOffset', 0); blobs.append(data if k == im['bufferView'] else bn[o:o + bv['byteLength']])
nb = bytearray()
for k, bv in enumerate(views):
	while len(nb) % 4: nb.append(0)
	bv['byteOffset'] = len(nb); bv['byteLength'] = len(blobs[k]); nb.extend(blobs[k])
while len(nb) % 4: nb.append(0)
j['buffers'][0]['byteLength'] = len(nb)
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
open(dst, 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(nb)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(nb), 0x004E4942) + bytes(nb))
