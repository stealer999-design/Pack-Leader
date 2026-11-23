# Measures a reference cat walk (a rigged glTF walking in place, e.g. a 3ds Max CAT rig
# exported from Sketchfab) and writes its motion as curves, scaled by leg height, for
# cat_pet_anims.py to replay on our cats. Only these numbers come into the project, not
# the reference model. python3 cat/extract_ref.py ref.glb cat/ref_walk.json
import sys, os, json, numpy as np
GLB = sys.argv[1]
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'gltf_sample.py')).read())
NS = 60
W0 = sample(0.0)
p = lambda W, n: W[n][:3, 3]
names = list(W0.keys())
def find(*keys):
	return next(n for n in names if all(k in n for k in keys))
hub_h, hub_c = find('Hub001'), find('Hub002')
fwd = p(W0, hub_c) - p(W0, hub_h); fwd[1] = 0; fwd /= np.linalg.norm(fwd)
up = np.array([0, 1.0, 0]); left = np.cross(up, fwd)  # x = left, y = up, z = forward (as our models)
def loc(v): return np.array([v @ left, v @ up, v @ fwd])
legs = {}
for side in 'LR':
	legs['R' + side] = [find(side + 'Leg1'), find(side + 'Leg2'), find(side + 'LegAnkle'), find(side + 'AnkleBone')]
	legs['F' + side] = [find(side + 'ArmCollarbone'), find(side + 'Arm1'), find(side + 'Arm2'), find(side + 'ArmPalm'), find(side + 'PalmBone')]
frames = [sample(L * k / NS) for k in range(NS)]
ground = min(min(p(W, legs[l][-1])[1] for l in legs) for W in frames)
out = {'length': L, 'samples': NS, 'legs': {}, 'body': {}}
for leg, chain in legs.items():
	root = chain[0] if leg[0] == 'R' else chain[1]
	H = float(np.mean([p(W, root)[1] for W in frames]) - ground)
	ank, toe = chain[-2], chain[-1]
	A = np.array([loc(p(W, ank) - p(W, hub_h if leg[0] == 'R' else hub_c)) for W in frames]) / H
	T = np.array([loc(p(W, toe)) for W in frames])
	down = T[:, 1] - T[:, 1].min() < 0.04 * H  # stance: the toe on (or within a hair of) its lowest
	V = np.array([loc(p(W, toe) - p(W, ank)) for W in frames])
	pitch = np.arctan2(-V[:, 2], -V[:, 1])  # + = the paw folded back
	Tn = (T - np.array([T[down, 0].mean(), T[:, 1].min(), T[down, 2].mean()])) / H  # the toe's path, from where it stands
	d = {'side': float(np.sign(np.mean(T[:, 0]))), 'height': H, 'toe': Tn.tolist(), 'ankle': A.tolist(), 'paw_pitch': pitch.tolist(), 'down': down.astype(int).tolist(),
		 'neutral_ankle': A[down].mean(0).tolist(), 'neutral_pitch': float(pitch[down].mean())}
	if leg[0] == 'F':  # the shoulder (top of the arm) moving with the shoulder blade, relative to the chest
		Sh = np.array([loc(p(W, chain[1]) - p(W, hub_c)) for W in frames]) / H
		d['shoulder'] = (Sh - Sh.mean(0)).tolist()
	# the stride: how far the toe slides back per second while it's down
	k = np.where(down & np.roll(down, -1))[0]
	d['slide_speed'] = float(np.median((T[k, 2] - T[(k + 1) % NS, 2]) / H) * NS / L) if len(k) else 0.0
	out['legs'][leg] = d
Hh = np.mean([out['legs'][l]['height'] for l in out['legs']])
B = {}
hips = np.array([loc(p(W, hub_h)) for W in frames]) / Hh; chest = np.array([loc(p(W, hub_c)) for W in frames]) / Hh
B['hips'] = (hips - hips.mean(0)).tolist(); B['chest'] = (chest - chest.mean(0)).tolist()
def ang(v): return np.arctan2(v[..., 1], v[..., 0])
pel = np.array([loc(p(W, legs['RL'][0]) - p(W, legs['RR'][0])) for W in frames])  # across the pelvis
sho = np.array([loc(p(W, legs['FL'][1]) - p(W, legs['FR'][1])) for W in frames])  # across the shoulders
sp = chest * Hh - hips * Hh  # along the spine
for nm, v, a, b in (('pelvis_yaw', pel, 2, 0), ('pelvis_roll', pel, 1, 0), ('shoulder_yaw', sho, 2, 0), ('shoulder_roll', sho, 1, 0), ('spine_pitch', sp, 1, 2), ('spine_yaw', sp, 0, 2)):
	x = np.arctan2(v[:, a], v[:, b]); x = x - x.mean(); B[nm] = x.tolist()
out['body'] = B
out['leg_height'] = float(Hh)
out['travel_per_cycle'] = float(np.mean([out['legs'][l]['slide_speed'] for l in out['legs']]) * L)  # in leg heights
json.dump(out, open(sys.argv[2], 'w'))
print('length %.3f  travel/cycle %.3f leg heights  duty %s' % (L, out['travel_per_cycle'], {l: round(np.mean(d['down']), 2) for l, d in out['legs'].items()}))
for l, d in out['legs'].items():
	A = np.array(d['ankle']); print(l, 'side', d['side'], 'ankle fwd range %.2f..%.2f up %.2f..%.2f' % (A[:, 2].min(), A[:, 2].max(), A[:, 1].min(), A[:, 1].max()), 'pitch %.2f..%.2f' % (min(d['paw_pitch']), max(d['paw_pitch'])), 'first down', d['down'].index(1) if 1 in d['down'] else -1)
for k, v in B.items(): print(k, np.round(np.ptp(np.array(v), 0), 3))
