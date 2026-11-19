# Keyframed animations for a four-legged rig: functions of time -> {bone: (rx, ry, rz)}.
# +rx tips a bone's far end toward -Y if it points +Z (head down, jaw open) and swings a
# downward leg's paw backward; -rx swings it forward. Tail bones point up/back: +rx lifts.
import numpy as np
TAU = 2 * np.pi
LEGS = ['FL', 'FR', 'RL', 'RR']
def gait(t, T, offsets, swing, lift, f):
	ph = TAU * t / T
	for leg in LEGS:
		a = ph + TAU * offsets[leg]
		front = leg[0] == 'F'
		up = max(0.0, np.cos(a))  # the paw is off the ground for half the cycle
		f[leg + '_Upper'] = (-swing * np.sin(a), 0, 0)
		f[leg + '_Lower'] = ((lift if front else -lift * 0.6) * up, 0, 0)
		f[leg + '_Paw'] = ((0.5 if front else 0.4) * up, 0, 0)
def tail_sway(t, f, amp, speed=1.0, lift=0.0):
	for k in range(4):
		f['Tail%d' % (k + 1)] = (lift * (1 if k == 0 else 0.3), amp * (k + 1) / 4 * np.sin(TAU * t * speed - k * 0.6), 0)
def walk(t):
	f = {}; T = 1.0; gait(t, T, {'RL': 0, 'FL': 0.25, 'RR': 0.5, 'FR': 0.75}, 0.35, 0.7, f)
	ph = TAU * t / T
	f['Spine1'] = (0, 0.04 * np.sin(ph), 0); f['Chest'] = (0, -0.04 * np.sin(ph), 0)
	f['Head'] = (0.04 * np.sin(2 * ph), -0.03 * np.sin(ph), 0); tail_sway(t, f, 0.25, 1.0)
	f['_offset'] = (0, 0.012 * np.cos(2 * ph), 0); return f
def run(t):
	f = {}; T = 0.6; gait(t, T, {'FL': 0, 'FR': 0.08, 'RL': 0.5, 'RR': 0.58}, 0.6, 1.0, f)
	ph = TAU * t / T
	f['Spine1'] = (0.12 * np.sin(ph), 0, 0); f['Chest'] = (-0.1 * np.sin(ph), 0, 0)
	f['Head'] = (-0.06 * np.sin(ph), 0, 0); tail_sway(t, f, 0.12, 1.0, lift=-0.3)
	f['_offset'] = (0, 0.04 * np.sin(ph), 0); return f
def idle(t):
	f = {}; T = 3.0; ph = TAU * t / T
	f['Chest'] = (0.015 * np.sin(2 * ph), 0, 0); f['Neck'] = (0, 0.12 * np.sin(ph), 0)
	f['Head'] = (0.05 * np.sin(ph + 1), 0.08 * np.sin(ph), 0.04 * np.sin(ph * 0.5))
	tail_sway(t, f, 0.5, 1 / T); f['_offset'] = (0, 0.006 * np.sin(2 * ph), 0); return f
def env(t, a, b, c):  # 0 before a, rises to 1 at b, back to 0 at c
	return float(np.clip((t - a) / (b - a), 0, 1) if t < b else np.clip((c - t) / (c - b), 0, 1))
def swipe(t):
	f = {}
	raise_ = env(t, 0.0, 0.22, 0.7); strike = env(t, 0.22, 0.36, 0.6)
	f['FR_Upper'] = (-1.5 * raise_ + 1.0 * strike, -0.4 * raise_, 0.3 * raise_)
	f['FR_Lower'] = (-0.6 * raise_ + 0.4 * strike, 0, 0); f['FR_Paw'] = (-0.5 * raise_, 0, 0)
	f['Chest'] = (-0.18 * raise_ + 0.1 * strike, 0, 0); f['Hips'] = (0.05 * raise_, 0, 0)
	f['Head'] = (0.15 * strike, 0, 0); f['Jaw'] = (0.35 * env(t, 0.1, 0.3, 0.6), 0, 0)
	tail_sway(t, f, 0.2, 1.5, lift=0.3 * raise_); f['_offset'] = (0, 0.05 * raise_, 0.05 * strike); return f
def pounce(t):
	f = {}
	crouch = env(t, 0.0, 0.4, 0.62); leap = env(t, 0.42, 0.6, 0.9); wig = np.sin(TAU * t * 6) * env(t, 0.1, 0.3, 0.42)
	for s in 'LR':
		f['F%s_Upper' % s] = (-0.35 * crouch - 1.1 * leap, 0, 0); f['F%s_Lower' % s] = (0.9 * crouch + 0.2 * leap, 0, 0)
		f['F%s_Paw' % s] = (-0.4 * crouch - 0.3 * leap, 0, 0)
		f['R%s_Upper' % s] = (-0.6 * crouch + 0.9 * leap, 0, 0); f['R%s_Lower' % s] = (0.7 * crouch - 0.3 * leap, 0, 0)
		f['R%s_Paw' % s] = (-0.4 * crouch + 0.5 * leap, 0, 0)
	f['Hips'] = (0.06 * wig, 0.12 * wig, 0); f['Chest'] = (0.1 * crouch - 0.15 * leap, 0, 0)
	f['Head'] = (-0.2 * crouch, 0, 0); f['Jaw'] = (0.35 * leap, 0, 0)
	tail_sway(t, f, 0.3 * crouch, 3.0, lift=-0.4 * crouch + 0.3 * leap)
	f['_offset'] = (0, -0.16 * crouch + 0.1 * leap, 0.1 * leap); return f
def retch(t):
	f = {}; hunch = env(t, 0.0, 0.3, 1.4); pump = max(0.0, np.sin(TAU * t * 2.2)) * env(t, 0.2, 0.5, 1.2); hurl = env(t, 0.95, 1.05, 1.3)
	f['Spine1'] = (-0.22 * hunch - 0.1 * pump, 0, 0); f['Chest'] = (0.2 * hunch + 0.1 * pump, 0, 0)
	f['Neck'] = (0.45 * hunch + 0.15 * pump + 0.1 * hurl, 0, 0); f['Head'] = (0.25 * hunch - 0.1 * pump, 0, 0)
	f['Jaw'] = (0.2 * pump + 0.5 * hurl, 0, 0)
	for s in 'LR': f['F%s_Lower' % s] = (0.3 * hunch, 0, 0); f['F%s_Upper' % s] = (-0.15 * hunch, 0, 0)
	tail_sway(t, f, 0.1, 1.0, lift=-0.3 * hunch); f['_offset'] = (0, -0.05 * hunch, 0); return f
def hiss(t):
	f = {}; arch = env(t, 0.0, 0.25, 1.4); h = env(t, 0.2, 0.35, 1.2); shake = np.sin(TAU * t * 9) * h
	f['Spine1'] = (-0.3 * arch, 0, 0); f['Chest'] = (0.25 * arch, 0, 0); f['Hips'] = (0.1 * arch, 0, 0)
	f['Neck'] = (-0.1 * arch, 0, 0); f['Head'] = (-0.2 * h + 0.03 * shake, 0, 0); f['Jaw'] = (0.5 * h, 0, 0)
	for k in range(4): f['Tail%d' % (k + 1)] = ((0.5 if k == 0 else 0.15) * arch, 0.05 * shake, 0)
	for s in 'LR':
		f['R%s_Upper' % s] = (0.15 * arch, 0, 0); f['F%s_Upper' % s] = (-0.12 * arch, 0, 0)
	f['_offset'] = (0, 0.06 * arch, -0.04 * arch); return f
anims.update({'Idle': (3.0, idle), 'Walk': (1.0, walk), 'Run': (0.6, run), 'Swipe': (0.7, swipe),
			  'Pounce': (0.9, pounce), 'Retch': (1.4, retch), 'Hiss': (1.4, hiss)})
