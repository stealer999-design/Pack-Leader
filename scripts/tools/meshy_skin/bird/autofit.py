# Builds a bird rig config (for rig_bird.py) from its two Meshy models, folded and spread:
# feet, legs, body line, head and beak, tail, the folded wings' patch on each side, and
# where to cut the open wings from the spread model (leaving out brown bows and quivers)
# and how big to make them. python3 autofit.py folded.glb spread.glb out.json [anims.py]
import sys, io, json, numpy as np
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)) + '/..')
from glb import load, acc
from PIL import Image
K = 2.0  # rig units per model unit
def model(path):
	j, bn = load(path); a = j['meshes'][0]['primitives'][0]['attributes']
	P = acc(j, bn, a['POSITION']).astype(float); UV = acc(j, bn, a['TEXCOORD_0'])
	ti = j['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']; im = j['images'][j['textures'][ti]['source']]; v = j['bufferViews'][im['bufferView']]
	A = np.asarray(Image.open(io.BytesIO(bytes(bn[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]))).convert('RGB')).astype(float); h, w, _ = A.shape
	C = A[np.clip((UV[:, 1] * h).astype(int), 0, h - 1), np.clip((UV[:, 0] * w).astype(int), 0, w - 1)]
	return P, C
F, CF = model(sys.argv[1]); S, CS = model(sys.argv[2])
brown = lambda C: (C[:, 0] > C[:, 2] + 18) & (C[:, 0] > C[:, 1] + 4)  # wood and leather: bows, quivers, straps
P = F * K
y0 = P[:, 1].min(); core = P[np.abs(P[:, 0]) < 0.3]
top = np.percentile(core[:, 1], 99.5); H = top - y0
def sl(y, w=0.04): return P[np.abs(P[:, 1] - y) < w]
lo = (P[:, 1] < y0 + 0.05) & ~brown(CF)  # (a bow can rest on the ground beside the feet)
y0 = P[lo, 1].min(); lo = (P[:, 1] < y0 + 0.05) & ~brown(CF)
lo &= P[:, 2] > np.percentile(P[lo, 2], 90) - 0.25  # (a long tail or a fluffy belly can touch the ground behind them)
cx = np.median(P[lo, 0])  # the feet may sit a little off the middle: split them by 2-means on x
for _ in range(20):
	xl = P[lo, 0]; cx = (xl[xl > cx].mean() + xl[xl <= cx].mean()) / 2
feet = {s: P[lo & (np.sign(P[:, 0] - cx) == sg)].mean(0) for s, sg in (('L', 1), ('R', -1))}
fz = (feet['L'][2] + feet['R'][2]) / 2
# head: the top fifth of the bird, near the midline; beak: its front-most part
hp = core[core[:, 1] > y0 + 0.8 * H]
hc = np.array([0.0, hp[:, 1].mean(), hp[:, 2].mean()])
headpts = P[(np.linalg.norm(P - hc, axis=1) < 0.25 * H) & ~brown(CF)]
beak = headpts[headpts[:, 2] > np.percentile(headpts[:, 2], 96)].mean(0)
# body: chest at about two thirds up; hips low over the feet
mid = lambda y: (lambda q: (q[:, 2].min() + q[:, 2].max()) / 2)(sl(y)[np.abs(sl(y)[:, 0]) < 0.15])
hipy = y0 + 0.3 * H; chy = y0 + 0.62 * H; neky = y0 + 0.78 * H
B = {'Hips': ['', [0, hipy, mid(hipy)]], 'Spine': ['Hips', [0, y0 + 0.45 * H, mid(y0 + 0.45 * H)]],
	 'Chest': ['Spine', [0, chy, mid(chy)]], 'Neck': ['Chest', [0, neky, (mid(neky) + hc[2]) / 2]],
	 'Head': ['Neck', [0, hc[1], hc[2]]], 'Jaw': ['Head', [0, beak[1] - 0.02, beak[2] - 0.08 * H]]}
# tail: the rearmost low part
back = P[(P[:, 1] < y0 + 0.5 * H) & (np.abs(P[:, 0]) < 0.2)]
tip = back[back[:, 2] < np.percentile(back[:, 2], 2)].mean(0)
hz = B['Hips'][1]
B['Tail1'] = ['Hips', [0, hz[1] - 0.05 * H, hz[2] - 0.1 * H]]
B['Tail2'] = ['Tail1', list((np.array(B['Tail1'][1]) + tip) / 2)]
half = np.percentile(np.abs(sl(chy)[:, 0]), 95)
# legs, scaled from Pye's: hip a quarter up, knee, ankle just above the foot
legs = []
for s, f in feet.items():
	sx = np.sign(f[0]); x = f[0] * 0.85
	B[s + '_Upper'] = ['Hips', [x, y0 + 0.23 * H, fz - 0.05 * H]]
	B[s + '_Lower'] = [s + '_Upper', [x * 1.05, y0 + 0.15 * H, fz - 0.03 * H]]
	B[s + '_Paw'] = [s + '_Lower', [x * 1.1, y0 + 0.04 * H, fz - 0.02 * H]]
	legs.append({'bones': [s + '_Upper', s + '_Lower', s + '_Paw'], 'end': [f[0], y0 + 0.01, f[2] + 0.04 * H], 'radius': 0.09 * H, 'top': y0 + 0.2 * H})
# folded wings: a patch on each side, from the shoulder down
shoulder_y = y0 + 0.68 * H
for side, nm in ((1, 'WingL'), (-1, 'WingR')):
	B[nm] = ['Chest', [side * half * 0.75, shoulder_y, mid(chy)]]
# open wings, from the spread model: everything out to the side of its body, in the wing's
# height band, that isn't brown gear
Ss = S  # model units
sy0 = Ss[:, 1].min(); score = Ss[np.abs(Ss[:, 0]) < 0.12]; stop = np.percentile(score[:, 1], 99.5)
ratio = H / (K * (stop - sy0))  # spread model -> folded bird
far = Ss[np.abs(Ss[:, 0]) > 0.7 * np.abs(Ss[:, 0]).max()]
band = (np.percentile(far[:, 1], 1) - 0.06, np.percentile(far[:, 1], 99) + 0.04)
body_half_s = np.percentile(np.abs(Ss[(Ss[:, 1] > band[0]) & (Ss[:, 1] < band[1]) & (np.abs(Ss[:, 0]) < 0.25)][:, 0]), 50)
root_s = [body_half_s, (band[0] + band[1]) / 2 + 0.03, float(np.median(far[:, 2]))]
span = (np.abs(Ss[:, 0]).max() - root_s[0]) * K * ratio
rf = [half * 0.85, shoulder_y, mid(chy)]
for side, s in ((1, 'L'), (-1, 'R')):
	B['WingOpen%s1' % s] = ['Chest', [side * rf[0], rf[1], rf[2]]]
	B['WingOpen%s2' % s] = ['WingOpen%s1' % s, [side * (rf[0] + 0.5 * span), rf[1], rf[2]]]
cfg = {'scale': K, 'root': 'Hips', 'lib': 'bird_lib.py', 'anims': sys.argv[4] if len(sys.argv) > 4 else 'bird_pet_anims.py', 'bones': B,
	   'spine': ['Hips', 'Spine', 'Chest', 'Neck'], 'spine_end': B['Head'][1], 'legs': legs, 'foot_below': y0 + 0.06 * H,
	   'tail': {'bones': ['Tail1', 'Tail2'], 'end': list(tip), 'radius': 0.2 * H, 'start_y': hz[1], 'start_z': hz[2] - 0.05 * H},
	   'head': {'below': y0 + 0.74 * H, 'center': list(hc + np.array([0, 0, 0.08 * H])), 'radius': 0.24 * H},
	   'jaw': {'center': list(beak), 'radius': 0.07 * H, 'dark': 999, 'below': beak[1] + 0.01},
	   'folded_wing': {'dark': 999, 'inner': half * 0.55, 'top': shoulder_y + 0.04 * H, 'bottom': y0 + 0.22 * H, 'skip_brown': True},
	   'spread_scale': K * ratio,
	   'open_wing': {'inner': body_half_s, 'above': band[0], 'below': band[1], 'skip_brown': True,
					 'root_spread': root_s, 'root_folded': rf, 'size': 1.0, 'elbow': 0.5 * span},
	   'smooth': 3}
def py(o):
	if isinstance(o, dict): return {k: py(v) for k, v in o.items()}
	if isinstance(o, (list, tuple, np.ndarray)): return [py(v) for v in o]
	if isinstance(o, (np.floating, float, np.integer)): return round(float(o), 4)
	return o
json.dump(py(cfg), open(sys.argv[3], 'w'), indent=1)
print(sys.argv[1].split('/')[-1], 'height %.2f, chest half-width %.2f, spread->folded x%.2f, wing band %.2f..%.2f, span %.2f' % (H, half, ratio, band[0], band[1], span))
