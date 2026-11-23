# Variant of a cat config: raises the hip to a real hip joint, places knee and hock,
# and adds joint helpers and muscles (rig_quad.py's 'helpers' / 'muscles').
# The cats' first rigs pivoted the hind leg at the belly, so the thigh folded into a
# lump as it swung back; here the hip sits halfway up the body, the stifle and hock at
# cat-like heights, each with a half-turning helper bone, and the skin over the thigh,
# shoulder and upper arm rides its leg. (Run from scripts/tools/meshy_skin.)
# python3 cat/cat_fix.py pets/<cat>.json meshy.glb out.json [hip_frac knee_frac hock_frac thigh_r front]
#   defaults 0.5 0.55 0.3 0.13 1
import json, sys, os, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + '/..')
from glb import load, acc
c = json.load(open(sys.argv[1]))
args = sys.argv[4:] + ['0.5', '0.55', '0.3', '0.13', '1'][len(sys.argv[4:]):]
hip_frac, knee_frac, hock_frac, thigh_r = map(float, args[:4]); front = args[4] == '1'
B = c['bones']
j, bn = load(sys.argv[2]); P = acc(j, bn, j['meshes'][0]['primitives'][0]['attributes']['POSITION']).astype(float) * c['scale']
yaw = np.radians(c.get('yaw_deg', 0.0))  # (as rig_quad.py turns the model)
P = P @ np.array([[np.cos(yaw), 0, -np.sin(yaw)], [0, 1, 0], [np.sin(yaw), 0, np.cos(yaw)]])
hz = np.mean([B[l['bones'][0]][1][2] for l in c['legs'] if l['bones'][0][0] == 'R'])
mid = P[(np.abs(P[:, 2] - hz) < 0.05) & (np.abs(P[:, 0]) < 0.05)]
belly, top = float(mid[:, 1].min()), float(mid[:, 1].max())  # the body at the hips, on the midline
print('belly %.3f top %.3f at z %.2f' % (belly, top, hz))
helpers, muscles = [], []
for leg in c['legs']:
	bs = leg['bones']; name = bs[0][:2]; side = 1.0 if B[bs[0]][1][0] > 0 else -1.0; end = np.array(leg['end'])
	if name[0] == 'R':
		up, lo, paw = bs
		hip = np.array(B[up][1]); ground = end[1]
		if hip_frac >= 0: hip[1] = belly + hip_frac * (top - belly)
		H = hip[1] - ground
		knee = np.array(B[lo][1]); hock = np.array(B[paw][1])
		if knee_frac >= 0: knee[1] = ground + knee_frac * H; knee[2] = hip[2] + 0.06  # the stifle forward of the hip
		if hock_frac >= 0: hock[1] = ground + hock_frac * H; hock[2] = end[2] - 0.08  # the hock behind the paw
		B[up][1] = [round(v, 4) for v in hip]; B[lo][1] = [round(v, 4) for v in knee]; B[paw][1] = [round(v, 4) for v in hock]
		leg['top'] = min(leg['top'], round(belly + 0.05, 3))
		helpers += [{'bone': name + '_HipFix', 'parent': 'Hips', 'at': B[up][1], 'half_of': up, 'leg': up, 'joint': 0, 'width': 0.45},
					{'bone': name + '_KneeFix', 'parent': up, 'at': B[lo][1], 'half_of': lo, 'leg': up, 'joint': 1},
					{'bone': name + '_HockFix', 'parent': lo, 'at': B[paw][1], 'half_of': paw, 'leg': up, 'joint': 2}]
		if thigh_r > 0:
			muscles.append({'bone': up, 'a': B[up][1], 'b': B[lo][1], 'radius': thigh_r, 'soft': 0.3, 'side': side, 'inner': 0.03, 'strength': 0.95})
	elif front:
		scap, up, lo, paw = bs
		helpers.append({'bone': name + '_WristFix', 'parent': lo, 'at': B[paw][1], 'half_of': paw, 'leg': scap, 'joint': 3})
		muscles += [{'bone': scap, 'a': [B[scap][1][0], top, B[scap][1][2] - 0.04], 'b': B[up][1], 'radius': 0.09, 'side': side, 'inner': 0.04},
					{'bone': up, 'a': B[up][1], 'b': B[lo][1], 'radius': 0.07, 'side': side, 'inner': 0.05, 'strength': 0.6}]
for h in helpers: B[h['bone']] = [h['parent'], h['at']]
c['helpers'] = helpers; c['muscles'] = muscles
json.dump(c, open(sys.argv[3], 'w'), indent=1)
