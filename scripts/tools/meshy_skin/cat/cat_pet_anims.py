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


WRIST_LIFT = 0.07  # how much higher the wrist rides while the paw is folded
WRIST_FOLD = 1.25  # radians the fore paw curls back at the wrist as it swings (the reference rig has no wrist of its own)


def _swing_phase(down):
	"""for each sample, how far through its swing the paw is (0..1), or -1 while it's down"""
	n = len(down); v = [-1.0] * n; k0 = next(k for k in range(n) if down[k] and not down[(k + 1) % n])  # last stance sample
	k = (k0 + 1) % n; run = []
	for _ in range(n):
		if down[k]:
			for i, kk in enumerate(run): v[kk] = (i + 0.5) / len(run)
			run = []
		else:
			run.append(k)
		k = (k + 1) % n
	for i, kk in enumerate(run): v[kk] = (i + 0.5) / len(run)
	return v


SWING = {leg: _swing_phase(REF['legs'][REF_LEG[leg]]['down']) for leg in LEGS}


def swing_at(leg, u):
	"""how far through its swing the paw is at u (0..1), or -1 while it's down"""
	x = (u % 1.0) * NS; k = int(x) % NS; f = x - int(x); a, b = SWING[leg][k], SWING[leg][(k + 1) % NS]
	if a >= 0 and b >= 0: return a * (1 - f) + b * f
	return (a if f < 0.5 else b)


def forearm_pitch(pose, leg):
	"""how far (rx) the forearm has turned from its rest direction, in the side view"""
	GR, GP = fk(pose)
	lo, paw = idx[leg + '_Lower'], idx[leg + '_Paw']
	v0 = JP[paw] - JP[lo]; v = GR[lo] @ v0
	return float(wrap(np.arctan2(v[2], -v[1]) - np.arctan2(v0[2], -v0[1])) * -1.0)


def place_fore(f, leg, toe, u):
	"""the fore leg: the toe on `toe`, the paw curled back from the forearm through its swing
	(fold early, reaching out flat again before it lands), the elbow bending to suit"""
	v = swing_at(leg, u)
	fold = WRIST_FOLD * np.sin(np.pi * min(1.0, v / 0.8)) if v >= 0 else 0.0
	rest = END[leg] - JP[idx[leg + '_Paw']]
	s = fold / WRIST_FOLD  # 0 on the ground .. 1 folded
	flex = fold
	for _ in range(4):  # the paw's angle depends on the forearm's, which depends on where the wrist goes
		# down: the toe stays exactly on its path; folded: the wrist lifts and the paw hangs from it
		foot = toe + (rest - Rx(flex) @ rest) * (1 - s) + np.array([0, WRIST_LIFT * s, 0])
		solve_leg(f, leg, foot, flex)
		flex = forearm_pitch(f, leg) + fold


def walk(t):
	u = t / WALK_T; f = {}
	feet = {}; fore_toes = {}
	for leg in LEGS:
		d = REF['legs'][REF_LEG[leg]]; h = HEIGHT[leg]
		toe = END[leg] + curve(d['toe'], u) * np.array([0.5, 1.0, STRIDE]) * h  # (half its sideways drift)
		flex = curve(d['paw_pitch'], u) - d['neutral_pitch']
		# the ankle (wrist or hock) where the toe lands on `toe` with the paw folded by `flex`
		rest = END[leg] - JP[idx[leg + '_Paw']]
		if leg[0] == 'R':
			feet[leg] = (toe + rest - Rx(flex) @ rest, flex)
		else:
			fore_toes[leg] = toe
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
	finish(f)
	for leg, toe in fore_toes.items():
		place_fore(f, leg, toe, u)
	return f


anims['Walk'] = (WALK_T, walk)
