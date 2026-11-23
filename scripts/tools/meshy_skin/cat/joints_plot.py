# Draws a cat's side silhouette with its config's joints over it, to check where the
# legs bend:
# side silhouette of a model (one side's half) with a config's joints: python3 joints_plot.py cfg.json meshy.glb out.png [side]
import sys, json, numpy as np
sys.path.insert(0, '/home/user/pack-leader/scripts/tools/meshy_skin')
from glb import load, acc
from PIL import Image, ImageDraw
c = json.load(open(sys.argv[1])); side = float(sys.argv[4]) if len(sys.argv) > 4 else -1
j, bn = load(sys.argv[2]); P = acc(j, bn, j['meshes'][0]['primitives'][0]['attributes']['POSITION']).astype(float) * c['scale']
B = c['bones']; S = 700; lo = np.array([-1.0, -0.7]); span = 2.0
def px(z, y): return int((z - lo[0]) / span * S), int(S - (y - lo[1]) / span * S)
im = Image.new('RGB', (S, S), (235, 120, 150)); d = ImageDraw.Draw(im)
for p in P[side * P[:, 0] > 0.04]:
	x, y = px(-p[2], p[1]); d.ellipse((x - 2, y - 2, x + 2, y + 2), (255, 255, 255))
for n, (par, pos) in B.items():
	if side * pos[0] < -0.01 or 'Fix' in n: continue
	if par and par in B and side * B[par][1][0] >= -0.01:
		d.line([px(-B[par][1][2], B[par][1][1]), px(-pos[2], pos[1])], (40, 40, 160), 3)
	x, y = px(-pos[2], pos[1]); d.ellipse((x - 5, y - 5, x + 5, y + 5), (220, 20, 20))
for l in c['legs']:
	e = l['end']
	if side * e[0] > 0: x, y = px(-e[2], e[1]); d.ellipse((x - 4, y - 4, x + 4, y + 4), (20, 160, 20))
im.save(sys.argv[3])
