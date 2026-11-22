# Pye the Parrot's animations (bird_lib.py). A waddle on planted feet; an idle
# with head tilts; a run with his open wings half up like a goose charging; a
# peck; Feather Flurry (rears up and beats his open wings, after the dove
# reference: up into a V, then a sweeping downstroke with the tips curling);
# and a squawk with two beats for his summons.
import numpy as np

WALK_T = 0.9
WALK_TRAVEL = 0.5  # rig units a cycle


def flap(ph):
	"""one wing beat: (lift, sweep, tip) at phase ph (0 = top of the upstroke)"""
	lift = 0.35 + 0.75 * np.cos(ph)  # high V at the top, below level at the bottom
	sweep = 0.25 * np.sin(ph)  # forward on the downstroke
	tip = 0.45 * np.cos(ph - 0.9) - 0.1  # the outer half lags: trails up, curls down
	return lift, sweep, tip


def walk(t):
	f = {}; planted(f)
	ph = waddle(f, t, WALK_T, WALK_TRAVEL, 0.62, 0.07)
	sway = np.cos(ph)  # leans over the foot that's down
	f['Hips'] = (0.05, 0.06 * np.sin(ph), 0.07 * sway)
	f['Spine'] = (0, 0, -0.03 * sway); f['Chest'] = (0, -0.04 * np.sin(ph), -0.02 * sway)
	f['Neck'] = (0.05 * np.sin(2 * ph), 0, 0.05 * sway); f['Head'] = (0, 0.04 * np.sin(ph), 0.04 * sway)
	f['Tail1'] = (0, -0.1 * np.sin(ph - 0.6), 0)
	f['WingL'] = (0, 0, 0.03 + 0.03 * sway); f['WingR'] = (0, 0, -0.03 + 0.03 * sway)
	open_wings(f, 0.0)
	f['_offset'] = (0, -0.01 + 0.015 * np.cos(2 * ph), 0)
	return finish(f)


def run(t):
	"""a charging waddle, wings half up and beating like a goose"""
	T = 0.55; f = {}; planted(f)
	ph = waddle(f, t, T, 0.55, 0.5, 0.1)
	sway = np.cos(ph)
	f['Hips'] = (0.22, 0.05 * np.sin(ph), 0.06 * sway)
	f['Spine'] = (0.08, 0, 0); f['Chest'] = (0.05, 0, 0)
	f['Neck'] = (0.25, 0, 0); f['Head'] = (-0.2, 0, 0)  # neck out, head level
	lift, sweep, tip = flap(TAU * t / T * 2)
	open_wings(f, 0.75, 0.25 + 0.3 * lift, 0.15 + 0.3 * sweep, 0.5 * tip)
	f['Tail1'] = (-0.1, 0, 0)
	f['_offset'] = (0, -0.03 + 0.02 * np.cos(2 * ph), 0)
	return finish(f)


def idle(t):
	T = 4.0; ph = TAU * t / T; f = {}; planted(f)
	breathe = np.sin(TAU * t * 0.75)
	tilt = 0.35 * env(t, 0.6, 0.9, 1.6, 1.9) - 0.3 * env(t, 2.4, 2.7, 3.3, 3.6)  # a curious head tilt each way
	look = 0.25 * np.sin(ph)
	f['Chest'] = (-0.015 * breathe, 0, 0)
	f['Neck'] = (0, look * 0.5, 0); f['Head'] = (0.03 * np.sin(2 * ph), look * 0.5, tilt)
	f['Tail1'] = (0, 0.05 * np.sin(ph), 0)
	ruffle = env(t, 3.6, 3.7, 3.75, 3.95)  # a little shake of the feathers
	f['WingL'] = (0, 0, 0.05 * ruffle + 0.01 * breathe); f['WingR'] = (0, 0, -0.05 * ruffle - 0.01 * breathe)
	open_wings(f, 0.0)
	f['_offset'] = (0, 0.005 * breathe, 0)
	return finish(f)


def peck(t):
	"""leans in and strikes with his beak, open then snapped shut, on the spot"""
	f = {}; planted(f)
	draw = env(t, 0.0, 0.15, 0.18, 0.28)
	strike = env(t, 0.18, 0.3, 0.38, 0.75)
	f['Hips'] = (0.06 * draw + 0.25 * strike, 0, 0)
	f['Spine'] = (-0.05 * draw + 0.15 * strike, 0, 0); f['Chest'] = (-0.08 * draw + 0.12 * strike, 0, 0)
	f['Neck'] = (-0.15 * draw + 0.35 * strike, 0, 0); f['Head'] = (-0.1 * draw + 0.2 * strike, 0, 0)
	f['Jaw'] = (0.45 * env(t, 0.08, 0.22, 0.26, 0.32), 0, 0)
	f['Tail1'] = (-0.2 * strike, 0, 0)
	f['WingL'] = (0, 0, 0.08 * strike); f['WingR'] = (0, 0, -0.08 * strike)
	open_wings(f, 0.0)
	f['_offset'] = (0, -0.03 * strike, 0.04 * strike)
	return finish(f)


def flurry(t):
	"""Feather Flurry: rears up, sweeps his wings open and beats them three times"""
	f = {}; planted(f)
	L = 1.5
	show = env(t, 0.05, 0.2, 1.25, 1.42)
	up = env(t, 0.0, 0.2, 1.3, 1.5)
	beats = TAU * 3 * np.clip((t - 0.18) / 1.05, 0, 1)
	lift, sweep, tip = flap(beats)
	f['Hips'] = (-0.12 * up, 0, 0); f['Spine'] = (-0.06 * up, 0, 0); f['Chest'] = (-0.1 * up + 0.04 * np.sin(beats), 0, 0)
	f['Neck'] = (0.12 * up, 0, 0); f['Head'] = (0.05 * up, 0, 0)
	f['Tail1'] = (0.3 * up, 0, 0)  # the tail fans down as he rears
	open_wings(f, show, show * lift + (1 - show) * 0.3, show * sweep, show * tip)
	f['_offset'] = (0, 0.04 * up + 0.02 * np.sin(beats), -0.03 * up)
	return finish(f)


def squawk(t):
	"""his summons: head thrown up, beak wide, two big beats"""
	f = {}; planted(f)
	up = env(t, 0.0, 0.18, 0.85, 1.0)
	show = env(t, 0.1, 0.25, 0.75, 0.92)
	beats = TAU * 2 * np.clip((t - 0.22) / 0.6, 0, 1)
	lift, sweep, tip = flap(beats)
	f['Hips'] = (-0.08 * up, 0, 0); f['Chest'] = (-0.1 * up, 0, 0)
	f['Neck'] = (-0.25 * up, 0, 0); f['Head'] = (-0.3 * up, 0, 0)
	f['Jaw'] = (0.55 * env(t, 0.15, 0.25, 0.7, 0.85) + 0.05 * np.sin(TAU * t * 10) * up, 0, 0)
	f['Tail1'] = (0.2 * up, 0, 0)
	open_wings(f, show, show * lift + (1 - show) * 0.3, show * sweep, show * tip)
	f['_offset'] = (0, 0.03 * up, 0)
	return finish(f)


anims.update({'Idle': (4.0, idle), 'Walk': (WALK_T, walk), 'Run': (0.55, run), 'Peck': (0.8, peck),
			  'Flurry': (1.5, flurry), 'Squawk': (1.0, squawk)})
