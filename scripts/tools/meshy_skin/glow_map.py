## Makes a glow (emission) map from a Meshy model's colour texture: only the
## lava-coloured parts (bright, strongly orange/red) light up.
## python3 glow_map.py model.glb out_emit.png [--yellow]  (--yellow: yellow-hot lava too)
import sys, io, os, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb import load
from PIL import Image, ImageFilter
j, bn = load(sys.argv[1]); bn = bytes(bn)
ti = j['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']
im = j['images'][j['textures'][ti]['source']]; v = j['bufferViews'][im['bufferView']]; o = v.get('byteOffset', 0)
pic = Image.open(io.BytesIO(bn[o:o + v['byteLength']])).convert('RGB')
a = np.asarray(pic).astype(np.float32); r, g, b = a[..., 0], a[..., 1], a[..., 2]
def ramp(x, lo, hi): return np.clip((x - lo) / (hi - lo), 0, 1)
hot = ramp(r, 120, 200) * ramp(r / (g + 1), 1.1, 1.6) * ramp(r / (b + 1), 1.6, 3.0)
if '--yellow' in sys.argv:
	hot = np.maximum(hot, ramp(r, 170, 230) * ramp(g, 140, 210) * ramp((r + g) / 2 / (b + 1), 1.5, 2.5))
glow = (a * hot[..., None]).clip(0, 255).astype(np.uint8)
out = Image.fromarray(glow).resize((1024, 1024), Image.LANCZOS)
out.save(sys.argv[2]); print(sys.argv[2], 'glowing %.1f%%' % ((hot > 0.3).mean() * 100))
