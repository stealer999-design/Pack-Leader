# Usage: python3 scripts/tools/sandstone_textures.py textures/dungeon/sandstone
# Paints seamless sandstone textures (color, normal (OpenGL), roughness) for the desert vault.
import numpy as np, sys
from PIL import Image
N = 1024
rng = np.random.default_rng(7)
out = sys.argv[1]

def fnoise(beta, seed):
    """Periodic 1/f^beta noise in [0,1]."""
    r = np.random.default_rng(seed)
    f = np.fft.fftfreq(N)
    fx, fy = np.meshgrid(f, f)
    amp = 1.0 / np.maximum(np.sqrt(fx**2 + fy**2), 1.0 / N) ** beta
    spec = amp * np.exp(2j * np.pi * r.random((N, N)))
    n = np.real(np.fft.ifft2(spec))
    return (n - n.min()) / (n.max() - n.min())

def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)

def save(name, col, height, rough):
    Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(f"{out}/{name}_color.png")
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 6.0
    gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 6.0
    nrm = np.dstack([-gx, gy, np.ones_like(gx)])  # OpenGL: green up
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8)).save(f"{out}/{name}_normal.png")
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8)).save(f"{out}/{name}_roughness.png")

y, x = np.mgrid[0:N, 0:N].astype(float)
grain = fnoise(0.6, 1)
cloud = fnoise(2.0, 2)
fine = fnoise(1.2, 3)
chip = fnoise(1.4, 4)
base = np.array([0.80, 0.64, 0.43])

# --- Walls: staggered blocks, 4 rows of 2 per tile ---------------------------------
rows, per = 4, 2
bh, bw = N / rows, N / per
row = np.floor(y / bh)
xs = (x + (row % 2) * bw * 0.5) % N
col_i = np.floor(xs / bw)
ly, lx = y - row * bh, xs - col_i * bw
edge = np.minimum(np.minimum(ly, bh - ly), np.minimum(lx, bw - lx))  # px to the block's edge
mortar = 6.0
block_id = (row * per + col_i).astype(int)
tone = rng.uniform(-0.07, 0.07, rows * per)[block_id]
hue = rng.uniform(-0.03, 0.03, rows * per)[block_id]
warp = fnoise(1.8, 5)
layers = np.sin((y + warp * 160 + block_id * 37) * 0.06) * 0.5 + 0.5  # sediment streaks, wandering
pores = (fnoise(0.3, 6) > 0.86).astype(float)  # tiny dark pores
chipped = edge < mortar + 4 + chip * 26 * (chip > 0.55)
face = smooth(mortar, mortar + 14, edge) * (1 - 0.5 * chipped)
height = face * 0.8 + grain * 0.1 + layers * 0.03 - chipped * 0.12 - pores * 0.05
shade = 1 + tone + (layers - 0.5) * 0.05 + (grain - 0.5) * 0.16 + (cloud - 0.5) * 0.16 - pores * 0.12
col = base[None, None, :] * shade[..., None] + np.array([hue, hue * 0.4, -hue])[..., None].transpose(1, 2, 0) if False else base[None, None, :] * shade[..., None]
col[..., 0] += hue; col[..., 2] -= hue
dark = np.array([0.55, 0.45, 0.32]) * (0.85 + fine * 0.3)[..., None]
m = (1 - smooth(mortar - 2, mortar + 3, edge))[..., None]
col = col * (1 - m) + dark * m
col *= (1 - 0.07 * chipped)[..., None]
rough = 0.82 + grain * 0.1 + m[..., 0] * 0.08
save("wall", col, height, rough)

# --- Pillars: stacked drums with vertical fluting ------------------------------------
drums = 6
dh = N / drums
drow = np.floor(y / dh)
dly = y - drow * dh
dedge = np.minimum(dly, dh - dly)
flute = np.cos(x / N * 2 * np.pi * 8) * 0.5 + 0.5  # 8 flutes per tile
dtone = rng.uniform(-0.06, 0.06, drums)[drow.astype(int)]
dface = smooth(4, 12, dedge)
height = dface * (0.55 + flute * 0.35) + grain * 0.08
shade = 1 + dtone + (flute - 0.5) * 0.16 + (grain - 0.5) * 0.16 + (cloud - 0.5) * 0.12 - pores * 0.1
col = np.array([0.83, 0.68, 0.47])[None, None, :] * shade[..., None]
m = (1 - smooth(2, 7, dedge))[..., None]
col = col * (1 - m) + np.array([0.52, 0.42, 0.3])[None, None, :] * m
rough = 0.8 + grain * 0.1
save("pillar", col, height, rough)
print("ok")
