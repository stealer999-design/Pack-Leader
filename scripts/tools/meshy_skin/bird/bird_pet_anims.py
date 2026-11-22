# The bird pets' animations (bird_lib.py; all of them share these), on the skeleton
# bird/autofit.py fits. Like Pye: the folded model is the bird, and its spread model's
# open wings stay hidden until a flap. A bouncy waddle (the game speeds it up for a
# run), an idle with head tilts and a feather ruffle, a peck (Swipe, the attack), and
# a wing-beating display (Hiss, the ability) after the dove reference: wings swept up
# into a V, then a sweeping downstroke with the tips curling.
import numpy as np

WALK_T = 0.6
WALK_TRAVEL = 0.42  # rig units a cycle


def flap(ph):
	"""one wing beat: (lift, sweep, tip) at phase ph (0 = top of the upstroke)"""
	lift = 0.35 + 0.75 * np.cos(ph)
	sweep = 0.25 * np.sin(ph)
	tip = 0.45 * np.cos(ph - 0.9) - 0.1
	return lift, sweep, tip


def walk(t):
	f = {}; planted(f)
	ph = waddle(f, t, WALK_T, WALK_TRAVEL, 0.58, 0.09)
	sway = np.cos(ph)  # leans over the foot that's down
	f['Hips'] = (0.04, 0.06 * np.sin(ph), 0.08 * sway)
	f['Spine'] = (0, 0, -0.03 * sway); f['Chest'] = (0, -0.04 * np.sin(ph), -0.03 * sway)
	f['Neck'] = (0.04 * np.sin(2 * ph), 0, 0.04 * sway); f['Head'] = (0.03 * np.sin(2 * ph + 0.6), 0.04 * np.sin(ph), 0.04 * sway)
	f['Tail1'] = (0, -0.12 * np.sin(ph - 0.6), 0); f['Tail2'] = (0, -0.08 * np.sin(ph - 1.2), 0)
	f['WingL'] = (0, 0, 0.03 + 0.04 * sway); f['WingR'] = (0, 0, -0.03 + 0.04 * sway)
	open_wings(f, 0.0)
	f['_offset'] = (0, -0.01 + 0.025 * np.cos(2 * ph), 0)  # a bounce on each step
	return finish(f)


def run(t):
	"""a scurry, wings half open and beating for balance"""
	T = 0.45; f = {}; planted(f)
	ph = waddle(f, t, T, 0.45, 0.5, 0.11)
	sway = np.cos(ph)
	f['Hips'] = (0.15, 0.05 * np.sin(ph), 0.06 * sway)
	f['Spine'] = (0.05, 0, 0); f['Neck'] = (0.1, 0, 0); f['Head'] = (-0.15, 0, 0)
	lift, sweep, tip = flap(TAU * t / T * 2)
	open_wings(f, 0.75, 0.25 + 0.3 * lift, 0.15 + 0.3 * sweep, 0.5 * tip)
	f['_offset'] = (0, -0.02 + 0.025 * np.cos(2 * ph), 0)
	return finish(f)


def idle(t):
	T = 4.0; ph = TAU * t / T; f = {}; planted(f)
	breathe = np.sin(TAU * t * 0.75)
	tilt = 0.3 * env(t, 0.6, 0.9, 1.6, 1.9) - 0.25 * env(t, 2.4, 2.7, 3.3, 3.6)  # a curious head tilt each way
	look = 0.25 * np.sin(ph)
	f['Chest'] = (-0.015 * breathe, 0, 0)
	f['Neck'] = (0, look * 0.5, 0); f['Head'] = (0.03 * np.sin(2 * ph), look * 0.5, tilt)
	f['Tail1'] = (0, 0.06 * np.sin(ph), 0)
	ruffle = env(t, 3.6, 3.7, 3.75, 3.95) * np.sin(TAU * t * 8)  # a quick shake of the feathers
	f['WingL'] = (0, 0, 0.04 * ruffle + 0.01 * breathe); f['WingR'] = (0, 0, -0.04 * ruffle - 0.01 * breathe)
	f['Spine'] = (0, 0.03 * ruffle, 0)
	open_wings(f, 0.0)
	f['_offset'] = (0, 0.006 * breathe, 0)
	return finish(f)


def swipe(t):
	"""the attack: leans in and pecks, beak open then snapped shut"""
	f = {}; planted(f)
	draw = env(t, 0.0, 0.13, 0.16, 0.24)
	strike = env(t, 0.16, 0.26, 0.32, 0.6)
	f['Hips'] = (0.05 * draw + 0.22 * strike, 0, 0)
	f['Spine'] = (-0.05 * draw + 0.12 * strike, 0, 0); f['Chest'] = (-0.08 * draw + 0.1 * strike, 0, 0)
	f['Neck'] = (-0.12 * draw + 0.25 * strike, 0, 0); f['Head'] = (-0.1 * draw + 0.15 * strike, 0, 0)
	f['Jaw'] = (0.4 * env(t, 0.06, 0.18, 0.22, 0.28), 0, 0)
	f['Tail1'] = (-0.2 * strike, 0, 0)
	f['WingL'] = (0, 0, 0.1 * draw); f['WingR'] = (0, 0, -0.1 * draw)
	open_wings(f, 0.0)
	f['_offset'] = (0, -0.03 * strike, 0.05 * strike)
	return finish(f)


def hiss(t):
	"""the ability: stretches up, sweeps the wings open and beats them twice, calling"""
	f = {}; planted(f)
	up = env(t, 0.0, 0.18, 0.85, 1.0)
	show = env(t, 0.06, 0.2, 0.78, 0.94)
	beats = TAU * 2 * np.clip((t - 0.18) / 0.62, 0, 1)
	lift, sweep, tip = flap(beats)
	f['Hips'] = (-0.08 * up, 0, 0); f['Spine'] = (-0.04 * up, 0, 0); f['Chest'] = (-0.06 * up + 0.04 * np.sin(beats), 0, 0)
	f['Neck'] = (-0.1 * up, 0, 0); f['Head'] = (-0.15 * up, 0, 0)
	f['Jaw'] = (0.35 * env(t, 0.2, 0.3, 0.6, 0.75), 0, 0)
	f['Tail1'] = (0.2 * up, 0, 0)
	open_wings(f, show, show * lift + (1 - show) * 0.3, show * sweep, show * tip)
	f['_offset'] = (0, 0.03 * up + 0.015 * np.sin(beats), 0)
	return finish(f)


anims.update({'Idle': (4.0, idle), 'Walk': (WALK_T, walk), 'Run': (0.45, run), 'Swipe': (0.6, swipe), 'Hiss': (1.0, hiss)})
