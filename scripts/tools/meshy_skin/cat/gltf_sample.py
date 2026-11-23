# Samples a glTF's first animation: world matrices of every named node at a time
# (exec it, then sample(t) -> {name: 4x4}; L is the length; GLB the path).
import sys, json, numpy as np
sys.path.insert(0, '/home/user/pack-leader/scripts/tools/meshy_skin')
from glb import load, acc
j, bn = load(GLB)
nodes = j['nodes']; N = len(nodes)
par = [-1] * N
for i, n in enumerate(nodes):
	for c in n.get('children', []): par[c] = i
def qmat(q):
	x, y, z, w = q
	return np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)], [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)], [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
def local(n, over):
	if 'matrix' in n and not over: return np.array(n['matrix']).reshape(4, 4).T
	t = over.get('translation', n.get('translation', [0, 0, 0])); r = over.get('rotation', n.get('rotation', [0, 0, 0, 1])); s = over.get('scale', n.get('scale', [1, 1, 1]))
	M = np.eye(4); M[:3, :3] = qmat(r) @ np.diag(s); M[:3, 3] = t; return M
a = j['animations'][0]
chan = {}
for c in a['channels']:
	smp = a['samplers'][c['sampler']]; t = acc(j, bn, smp['input']).ravel(); v = acc(j, bn, smp['output'])
	chan.setdefault(c['target']['node'], {})[c['target']['path']] = (t, v.reshape(len(t), -1))
def sample(tt):
	over = {}
	for nd, paths in chan.items():
		d = {}
		for pth, (t, v) in paths.items():
			k = np.searchsorted(t, tt); k = min(max(k, 1), len(t) - 1); f = np.clip((tt - t[k-1]) / max(t[k] - t[k-1], 1e-9), 0, 1)
			x = v[k-1] * (1 - f) + v[k] * f
			if pth == 'rotation': x = x / np.linalg.norm(x)
			d[pth] = x
		over[nd] = d
	G = [None] * N
	def g(i):
		if G[i] is None: G[i] = local(nodes[i], over.get(i, {})) if par[i] < 0 else g(par[i]) @ local(nodes[i], over.get(i, {}))
		return G[i]
	return {nodes[i].get('name', str(i)): g(i) for i in range(N)}
L = float(max(t.max() for p in chan.values() for (t, v) in p.values()))
