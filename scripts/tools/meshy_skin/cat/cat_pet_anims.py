# The cat pets' walk, replayed from a reference cat walk (cat/ref_walk.json, measured
# by cat/extract_ref.py from a professionally animated walking cat the user found):
# each toe follows the reference toe's path over the ground (scaled by leg height:
# the cat's lateral sequence, how far each paw reaches, how high it lifts), the paw
# folds as much as the reference paw does (the leg solver places our own wrist,
# elbow, hock and stifle so the toe lands exactly there), the shoulder blades roll
# with the reference's shoulders, and the body bobs, surges, twists and rolls as the
# reference's hips and shoulders do. Listed after dom/cat_anims.py in a config's
# 'anims': it replaces only the walk.
import json

REF = json.load(open(os.path.join(base, '..', 'cat', 'ref_walk.json')))
WALK_T = REF['length']
NS = REF['samples']
HEIGHT = {}  # each leg's height, top joint to the ground
for leg in LEGS:
	top = leg + '_Upper'
	HEIGHT[leg] = JP[idx[top]][1] - END[leg][1]
H = float(np.mean(list(HEIGHT.values())))
STRIDE = 1.25  # the reference's steps, lengthened (the user found them a bit short)
BODY_ROLL = 0.35  # how much of the reference's hip and shoulder roll (side to side tilt) to keep
WALK_TRAVEL = REF['travel_per_cycle'] * H * STRIDE  # how far the body moves per cycle (pace = travel / T)
SIDE = {leg: np.sign(END[leg][0]) for leg in LEGS}
REF_LEG = {leg: next(k for k, d in REF['legs'].items() if k[0] == leg[0] and d['side'] == SIDE[leg]) for leg in LEGS}


def curve(c, u):
	"""a sampled periodic curve at u (0..1), linearly interpolated"""
	c = np.asarray(c); x = (u % 1.0) * NS; k = int(x) % NS; f = x - int(x)
	return c[k] * (1 - f) + c[(k + 1) % NS] * f


def walk(t):
	u = t / WALK_T; f = {}
	feet = {}
	for leg in LEGS:
		d = REF['legs'][REF_LEG[leg]]; h = HEIGHT[leg]
		toe = END[leg] + curve(d['toe'], u) * np.array([0.5, 1.0, STRIDE]) * h  # (half its sideways drift)
		flex = curve(d['paw_pitch'], u) - d['neutral_pitch']
		# the ankle (wrist or hock) where the toe lands on `toe` with the paw folded by `flex`
		rest = END[leg] - JP[idx[leg + '_Paw']]
		feet[leg] = (toe + rest - Rx(flex) @ rest, flex)
		if leg[0] == 'F':  # the shoulder blade rolls with the reference's shoulder
			sh = curve(d['shoulder'], u) * h
			scap = np.linalg.norm(JP[idx[leg + '_Upper']] - JP[idx[leg + '_Scap']])
			f[leg + '_Scap'] = (-sh[2] / scap, 0, 0)
	B = REF['body']
	hips = curve(B['hips'], u) * H
	f['_offset'] = (0, hips[1], hips[2] * STRIDE)
	pitch = curve(B['spine_pitch'], u); pyaw = curve(B['pelvis_yaw'], u); proll = BODY_ROLL * curve(B['pelvis_roll'], u)
	syaw = curve(B['shoulder_yaw'], u) - pyaw; sroll = BODY_ROLL * curve(B['shoulder_roll'], u) - proll
	f['Hips'] = (-pitch, -pyaw, proll)
	f['Spine1'] = (0, -0.3 * syaw, 0.3 * sroll); f['Spine2'] = (0, -0.35 * syaw, 0.35 * sroll)
	f['Chest'] = (0, -0.35 * syaw, 0.35 * sroll)
	f['Neck'] = (0.06, 0, 0)  # head carried a little low
	steady_head(f); ears(f, 0.05)
	tail(f, t, 0.15, 1 / WALK_T, lift=-0.03, curl=0.12)
	f['_feet'] = feet
	return finish(f)


anims['Walk'] = (WALK_T, walk)
