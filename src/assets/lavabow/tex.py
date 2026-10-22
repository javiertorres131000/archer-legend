import numpy as np
from scipy.spatial import cKDTree
from scipy.ndimage import gaussian_filter
from PIL import Image
N = 1024
rng = np.random.default_rng(7)
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
P = np.stack([xx.ravel(), yy.ravel()], 1)
def cracks(cells, jitter=1.0):
    pts = rng.random((cells, 2)) * N
    # repetir en mosaico para que no haya bordes
    tiles = np.concatenate([pts + [dx*N, dy*N] for dx in (-1,0,1) for dy in (-1,0,1)])
    d, _ = cKDTree(tiles).query(P, k=2)
    return (d[:,1] - d[:,0]).reshape(N, N)
big = cracks(70)
small = cracks(380)
# distorsión suave para que las grietas no sean rectas
noise = gaussian_filter(rng.standard_normal((N, N)), 6)
noise /= np.abs(noise).max()
edge_big = np.clip(1 - (big + noise * 3) / 3.2, 0, 1) ** 2.6       # grietas grandes
edge_small = np.clip(1 - (small + noise * 2) / 1.6, 0, 1) ** 3 * 0.35  # grietas finas
crack = np.clip(edge_big + edge_small * (1 - edge_big), 0, 1)
glow = gaussian_filter(crack, 2.5)  # halo alrededor de la grieta
# piedra: casi negra con variación por celda y textura
grain = gaussian_filter(rng.standard_normal((N, N)), 1.2)
cellv = gaussian_filter(rng.standard_normal((N, N)), 25)
base = np.stack([0.11, 0.065, 0.06]) [None,None,:] * (1 + 0.35 * cellv[...,None] + 0.12 * grain[...,None])
hot = np.array([1.0, 0.78, 0.32]); mid = np.array([1.0, 0.33, 0.06]); rim = np.array([0.45, 0.06, 0.02])
c = crack[..., None]; g = glow[..., None]
col = base * (1 - np.clip(g * 1.6, 0, 1)) + rim * np.clip(g * 1.6, 0, 1) * 0.6
col = col * (1 - c) + (mid * (1 - c) + hot * c) * c
col = np.clip(col, 0, 1)
Image.fromarray((col * 255).astype(np.uint8)).save("LavaBow_Color.png")
emit = np.clip(crack * 1.1 + glow * 0.35, 0, 1)
Image.fromarray((emit * 255).astype(np.uint8)).save("LavaBow_Emit.png")
# relieve: grietas hundidas + grano de piedra
h = (1 - gaussian_filter(crack, 1.5)) * 0.8 + grain * 0.03 + cellv * 0.08
gy, gx = np.gradient(h)
s = 7.0
n = np.stack([-gx * s, gy * s, np.ones_like(h)], 2)
n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save("LavaBow_Normal.png")
rough = np.clip(0.85 - 0.5 * glow - 0.05 * grain, 0.25, 1)
Image.fromarray((rough * 255).astype(np.uint8)).save("LavaBow_Rough.png")
print("ok")
