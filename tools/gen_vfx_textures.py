"""Genera las texturas anime (estilo cel-shading con contorno oscuro) para los efectos de armas.

Uso (desde la raíz del repo):
    pip install numpy pillow scipy
    python tools/gen_vfx_textures.py assets/vfx frost
    python tools/gen_vfx_textures.py assets/vfx frost flame,smoke   (solo algunas)

Cada estilo es una paleta (PALETTES); las formas son las mismas. Para un arma nueva con otro
color: agregá una paleta, generá, importá los PNG en Studio (Asset Manager › Import) y poné los
IDs en src/shared/FxStyles.lua.
"""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage

rng = np.random.default_rng(7)

PALETTES = {
    "frost": {
        "outline": (8, 22, 58),
        "deep": (18, 70, 170),
        "body": (40, 140, 255),
        "mid": (110, 215, 255),
        "core": (236, 252, 255),
        "smoke_fill": (14, 40, 92),
        "smoke_hi": (44, 104, 190),
        "smoke_line": (4, 10, 28),
    },
    # Hoja Infernal: fuego rojo y naranja con centro amarillo claro
    "inferno": {
        "outline": (52, 6, 4),
        "deep": (170, 22, 10),
        "body": (240, 80, 20),
        "mid": (255, 170, 40),
        "core": (255, 248, 214),
        "smoke_fill": (48, 18, 14),
        "smoke_hi": (110, 44, 26),
        "smoke_line": (16, 4, 2),
    },
}


def periodic_noise(h, w, scales=((48, 1.0), (16, 0.5), (6, 0.25)), seed=None):
    r = np.random.default_rng(seed)
    out = np.zeros((h, w))
    for s, a in scales:
        n = ndimage.gaussian_filter(r.standard_normal((h, w)), s, mode="wrap")
        n = (n - n.mean()) / (n.std() + 1e-9)
        out += a * n
    out = (out - out.min()) / (out.max() - out.min())
    return out


def rgba(mask_layers, size):
    """mask_layers: lista de (mask bool/float, color) de abajo hacia arriba."""
    img = np.zeros((size[0], size[1], 4), dtype=np.float64)
    for m, c in mask_layers:
        m = m.astype(np.float64)
        for k in range(3):
            img[..., k] = img[..., k] * (1 - m) + c[k] / 255.0 * m
        img[..., 3] = np.maximum(img[..., 3], m)
    return img


def to_image(arr, out_size=None):
    im = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
    if out_size:
        im = im.resize(out_size, Image.LANCZOS)
    return im


def bands(field, thresh, outline_px, levels, pal_keys, pal):
    """Cel shading: adentro si field>thresh; contorno de outline_px; bandas internas por nivel."""
    inside = field > thresh
    inner = ndimage.binary_erosion(inside, iterations=outline_px) if outline_px > 0 else inside
    layers = [(inside, pal["outline"])]
    layers.append((inner, pal[pal_keys[0]]))
    for lv, key in zip(levels, pal_keys[1:]):
        layers.append((inner & (field > thresh + lv), pal[key]))
    return layers


# ---------------------------------------------------------------- llama (flipbook 4x4)
def keep_big(mask, min_frac=0.02):
    lab, n = ndimage.label(mask)
    if n == 0:
        return mask
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    keep = np.zeros(n + 1, bool)
    keep[1:] = sizes >= max(sizes.max() * min_frac, 30)
    return keep[lab]


def flame_flipbook(pal, frame=512, grid=4, out=1024):
    H = W = frame
    tall = periodic_noise(H * 3, W, scales=((34, 1.0), (12, 0.55), (5, 0.2)), seed=1)
    sheet = np.zeros((H * grid, W * grid, 4))
    yy, xx = np.mgrid[0:H, 0:W]
    y = 1 - yy / (H - 1)
    x = (xx / (W - 1)) * 2 - 1
    n_frames = grid * grid
    for f in range(n_frames):
        t = f / (n_frames - 1)
        grow = min(1.0, 0.5 + t * 2.0)
        # la llama vive entre y=0.08 y y=0.95; panza redonda abajo
        ys = (y - 0.08) / (0.87 * grow)
        belly = np.sqrt(np.clip(1 - ((ys - 0.28) / 0.33) ** 2, 0, 1))
        upper = np.clip(1 - (ys - 0.28) / 0.72, 0, 1) ** 0.8
        width = 0.8 * np.where(ys < 0.28, belly, upper)
        sway = 0.14 * np.sin(ys * 6 + t * 7) * np.clip(ys, 0, 1)
        base = 1 - np.abs(x - sway) / (width + 1e-3)
        n = np.roll(tall, int(t * H * 1.4), axis=0)[H:2 * H]
        field = base + (n - 0.5) * 1.1 * (0.25 + np.clip(ys, 0, 1.2))
        field = np.where((ys < -0.05) | (ys > 1.15), -1, field)
        thresh = 0.12 + 0.8 * max(0.0, (t - 0.45) / 0.55) ** 1.3
        inside = keep_big(field > thresh)
        field = np.where(inside, field, -1)
        layers = bands(field, thresh, outline_px=11, levels=(0.18, 0.4, 0.66), pal_keys=("deep", "body", "mid", "core"), pal=pal)
        img = rgba(layers, (H, W))
        r, c = divmod(f, grid)
        sheet[r * H:(r + 1) * H, c * W:(c + 1) * W] = img
    return to_image(sheet, (out, out))


# ---------------------------------------------------------------- humo (flipbook 4x4)
def smoke_flipbook(pal, frame=512, grid=4, out=1024):
    H = W = frame
    yy, xx = np.mgrid[0:H, 0:W]
    x = xx / (W - 1) * 2 - 1
    y = yy / (H - 1) * 2 - 1
    r = np.random.default_rng(3)
    blobs = [(r.uniform(-0.3, 0.3), r.uniform(-0.25, 0.25), r.uniform(0.3, 0.45)) for _ in range(7)]
    holes = periodic_noise(H, W, scales=((30, 1.0), (10, 0.5)), seed=4)
    sheet = np.zeros((H * grid, W * grid, 4))
    n_frames = grid * grid
    for f in range(n_frames):
        t = f / (n_frames - 1)
        expand = 0.75 + 0.55 * (1 - (1 - t) ** 2)
        field = np.zeros((H, W))
        for bx, by, br in blobs:
            d = np.sqrt((x - bx * expand * 1.4) ** 2 + (y - by * expand * 1.4) ** 2)
            field = np.maximum(field, 1 - d / (br * expand))
        erosion = 0.0 + 0.85 * max(0.0, (t - 0.3) / 0.7) ** 1.2
        field = field - (holes * erosion)
        inside = field > 0.02
        inner = ndimage.binary_erosion(inside, iterations=9)
        # luz de arriba-izquierda
        hi = inner & ~ndimage.shift(inside, (26, 20), order=0, mode="constant", cval=0)
        hi = ndimage.binary_opening(hi, iterations=3) | (inner & ~ndimage.shift(inside, (18, 14), order=0, mode="constant", cval=0) & False)
        img = rgba([(inside, pal["smoke_line"]), (inner, pal["smoke_fill"]), (hi, pal["smoke_hi"])], (H, W))
        rr, cc = divmod(f, grid)
        sheet[rr * H:(rr + 1) * H, cc * W:(cc + 1) * W] = img
    return to_image(sheet, (out, out))


# ---------------------------------------------------------------- tajo (para Beam; U = largo, V = ancho)
def slash(pal, W=2048, H=512, out=(1024, 256)):
    yy, xx = np.mgrid[0:H, 0:W]
    u = xx / (W - 1)
    v = yy / (H - 1) * 2 - 1  # -1..1 a lo ancho
    taper = np.clip(np.sin(np.pi * u), 0, 1) ** 0.6
    streak = periodic_noise(H, W, scales=((2, 1.0),), seed=5)
    streak = ndimage.gaussian_filter(streak, (1, 60), mode="wrap")
    streak = (streak - streak.min()) / (streak.max() - streak.min())
    a = np.abs(v) / (taper * 0.95 + 1e-3)
    field = 1 - a + (streak - 0.5) * 0.35
    layers = bands(field, 0.0, outline_px=12, levels=(0.25, 0.5, 0.72), pal_keys=("deep", "body", "mid", "core"), pal=pal)
    return to_image(rgba(layers, (H, W)), out)


# ---------------------------------------------------------------- remolino (Beam en Wrap, se repite a lo largo)
def swirl(pal, W=2048, H=512, out=(1024, 256)):
    yy, xx = np.mgrid[0:H, 0:W]
    v = yy / (H - 1) * 2 - 1
    s = periodic_noise(H, W, scales=((3, 1.0),), seed=6)
    s = ndimage.gaussian_filter(s, (2, 90), mode="wrap")
    s = (s - s.min()) / (s.max() - s.min())
    edge = periodic_noise(1, W, scales=((40, 1.0), (12, 0.4)), seed=8)[0]
    edge2 = periodic_noise(1, W, scales=((40, 1.0), (12, 0.4)), seed=9)[0]
    top = 0.55 + 0.4 * edge
    bot = -0.55 - 0.4 * edge2
    inside = (v < top[None, :]) & (v > bot[None, :])
    field = np.where(inside, 1.0, 0.0)
    inner = ndimage.binary_erosion(inside, iterations=8)
    dark = inner
    streak_cyan = inner & (s > 0.6)
    streak_white = inner & (s > 0.8)
    layers = [(inside, pal["outline"]), (dark, pal["smoke_fill"]), (inner & (s > 0.45), pal["deep"]), (streak_cyan, pal["mid"]), (streak_white, pal["core"])]
    return to_image(rgba(layers, (H, W)), out)


# ---------------------------------------------------------------- anillo de onda expansiva
def ring(pal, S=1024, out=512):
    yy, xx = np.mgrid[0:S, 0:S]
    x = xx / (S - 1) * 2 - 1
    y = yy / (S - 1) * 2 - 1
    d = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    n = periodic_noise(1, 720, scales=((10, 1.0), (3, 0.4)), seed=10)[0]
    idx = ((ang + np.pi) / (2 * np.pi) * 719).astype(int)
    thick = 0.07 + 0.08 * n[idx]
    field = 1 - np.abs(d - 0.86) / thick
    layers = bands(field, 0.0, outline_px=8, levels=(0.3, 0.6), pal_keys=("body", "mid", "core"), pal=pal)
    return to_image(rgba(layers, (S, S)), (out, out))


# ---------------------------------------------------------------- círculo ornamental del piso
def magic_circle(pal, S=2048, out=1024):
    yy, xx = np.mgrid[0:S, 0:S]
    x = xx / (S - 1) * 2 - 1
    y = yy / (S - 1) * 2 - 1
    d = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    lines = np.zeros((S, S), bool)
    px = 2 / S

    def circle(r, w):
        return np.abs(d - r) < w * px

    for r, w in ((0.97, 12), (0.93, 6), (0.80, 9), (0.76, 5), (0.50, 8), (0.46, 5), (0.20, 6)):
        lines |= circle(r, w)
    # marcas entre 0.80 y 0.93
    tick = (np.abs(((ang / (2 * np.pi) * 72) % 1) - 0.5) > 0.45) & (d > 0.80) & (d < 0.93)
    lines |= tick
    # runas: arcos cortos alternados entre 0.5 y 0.76
    seg = (ang / (2 * np.pi) * 24) % 1
    rune_r = 0.63 + 0.07 * np.sign(np.sin(ang * 12))
    lines |= (np.abs(d - rune_r) < 6 * px) & (seg > 0.15) & (seg < 0.85)
    lines |= (np.abs(seg - 0.5) < 0.012 * (0.7 / np.maximum(d, 0.1))) & (d > 0.56) & (d < 0.7)
    # dos cuadrados cruzados (estrella de 8) inscriptos en 0.76
    for rot in (0, np.pi / 4):
        a = ang - rot
        rr = 0.76 * np.cos(np.pi / 4) / np.maximum(np.abs(np.cos((a % (np.pi / 2)) - np.pi / 4)), 1e-3)
        lines |= (np.abs(d - rr) < 6 * px) & (d < 0.77)
    # remolinos tipo nube en 8 puntos del anillo interior
    for k in range(8):
        a0 = k * np.pi / 4 + np.pi / 8
        cx, cy = 0.33 * np.cos(a0), 0.33 * np.sin(a0)
        dd = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
        aa = np.arctan2(y - cy, x - cx)
        spiral = 0.012 * ((aa - a0) % (2 * np.pi)) + 0.02
        lines |= (np.abs(dd - spiral) < 5 * px) & (dd < 0.1)
    glow = ndimage.gaussian_filter(lines.astype(float), 6)
    glow = glow / glow.max()
    thick = ndimage.binary_dilation(lines, iterations=5)
    img = rgba([(np.clip(glow * 1.6, 0, 1) * 0.7, pal["body"]), (thick, pal["outline"]), (lines, pal["mid"]), (ndimage.binary_erosion(lines, iterations=3), pal["core"])], (S, S))
    # ese contorno oscuro pesa demasiado en el piso: más suave
    return to_image(img, (out, out))


# ---------------------------------------------------------------- destello estrella de 4 puntas
def star(pal, S=512, out=256):
    yy, xx = np.mgrid[0:S, 0:S]
    x = xx / (S - 1) * 2 - 1
    y = yy / (S - 1) * 2 - 1
    ax, ay = np.abs(x), np.abs(y)
    field = 1 - (np.sqrt(ax) + np.sqrt(ay)) / 1.0
    glow = np.clip(1 - np.sqrt(x * x + y * y), 0, 1) ** 3
    layers = bands(field, 0.0, outline_px=6, levels=(0.2, 0.4), pal_keys=("body", "mid", "core"), pal=pal)
    img = rgba([(glow * 0.6, pal["body"])] + layers, (S, S))
    return to_image(img, (out, out))


# ---------------------------------------------------------------- línea de velocidad
def speedline(pal, W=512, H=128, out=(256, 64)):
    yy, xx = np.mgrid[0:H, 0:W]
    u = xx / (W - 1)
    v = yy / (H - 1) * 2 - 1
    taper = np.clip(np.sin(np.pi * u ** 0.7), 0, 1)
    field = 1 - np.abs(v) / (taper * 0.9 + 1e-3)
    layers = bands(field, 0.0, outline_px=6, levels=(0.35,), pal_keys=("mid", "core"), pal=pal)
    return to_image(rgba(layers, (H, W)), out)


def main():
    out_dir = sys.argv[1]
    style = sys.argv[2] if len(sys.argv) > 2 else "frost"
    pal = PALETTES[style]
    os.makedirs(out_dir, exist_ok=True)
    jobs = {
        "flame": flame_flipbook, "smoke": smoke_flipbook, "slash": slash, "swirl": swirl,
        "ring": ring, "circle": magic_circle, "star": star, "speedline": speedline,
    }
    only = sys.argv[3].split(",") if len(sys.argv) > 3 else list(jobs)
    for name in only:
        im = jobs[name](pal)
        path = os.path.join(out_dir, f"al_vfx_{style}_{name}.png")
        im.save(path, optimize=True)
        print(path, im.size, os.path.getsize(path) // 1024, "KB")


if __name__ == "__main__":
    main()
