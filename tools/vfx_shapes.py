"""Formas propias de cada estilo (no solo otra paleta). Las usa gen_vfx_textures.py.

  · inferno: fuego salvaje y pesado. Llamas de varias lenguas, humo negro con brasas, tajo con
    lenguas de fuego en el borde, muro de fuego, anillo con picos, grietas de lava, explosión
    irregular y estela de cometa.
  · crimson: energía afilada y limpia. Espinas que suben y se quiebran, jirones de niebla,
    tajo finísimo con núcleo negro, hélice de dos cintas, anillo roto en esquirlas, sigilo
    geométrico con espinas, estrella de 6 agujas y aguja.
Mismo tamaño y uso que las de siempre (ver gen_vfx_textures.py), así los efectos las ubican igual.
"""
import numpy as np
from scipy import ndimage

from gen_vfx_textures import periodic_noise, rgba, to_image, bands, keep_big


def _grid(H, W):
    yy, xx = np.mgrid[0:H, 0:W]
    return yy, xx


# =============================================================== INFERNO
def inferno_flame(pal, frame=512, grid=4, out=1024):
    H = W = frame
    yy, xx = _grid(H, W)
    y = 1 - yy / (H - 1)
    x = (xx / (W - 1)) * 2 - 1
    tall = periodic_noise(H * 3, W, scales=((22, 1.0), (8, 0.6), (3, 0.25)), seed=21)
    sheet = np.zeros((H * grid, W * grid, 4))
    tongues = [(-0.38, 0.55, 0.0), (0.0, 0.95, 1.3), (0.36, 0.7, 2.4), (-0.15, 0.75, 3.1), (0.2, 0.5, 4.2)]
    n_frames = grid * grid
    for f in range(n_frames):
        t = f / (n_frames - 1)
        grow = min(1.0, 0.45 + t * 2.2)
        field = np.full((H, W), -1.0)
        for cx, h, ph in tongues:
            hh = h * grow
            ys = (y - 0.05) / hh
            sway = 0.12 * np.sin(ys * 7 + t * 9 + ph) * np.clip(ys, 0, 1)
            w = 0.32 * np.clip(1 - ys, 0, 1) ** 0.7 * np.clip(ys * 4, 0, 1) ** 0.4 + 0.02
            tongue = 1 - np.abs(x - cx - sway) / (w + 1e-3)
            tongue = np.where((ys < 0) | (ys > 1.05), -1, tongue)
            field = np.maximum(field, tongue)
        n = np.roll(tall, int(t * H * 1.8), axis=0)[H:2 * H]
        field = field + (n - 0.5) * 1.3 * (0.2 + np.clip(y, 0, 1))
        thresh = 0.1 + 0.85 * max(0.0, (t - 0.5) / 0.5) ** 1.2
        inside = keep_big(field > thresh, 0.01)
        field = np.where(inside, field, -1)
        layers = bands(field, thresh, outline_px=9, levels=(0.15, 0.38, 0.62), pal_keys=("deep", "body", "mid", "core"), pal=pal)
        # brasas sueltas arriba
        rng = np.random.default_rng(100 + f)
        embers = np.zeros((H, W), bool)
        for _ in range(10):
            ex, ey = rng.uniform(-0.6, 0.6), rng.uniform(0.55, 0.95)
            r = rng.uniform(0.012, 0.025)
            embers |= ((x - ex) ** 2 + (y - ey) ** 2) < r * r
        layers.append((embers, pal["mid"]))
        img = rgba(layers, (H, W))
        r_, c_ = divmod(f, grid)
        sheet[r_ * H:(r_ + 1) * H, c_ * W:(c_ + 1) * W] = img
    return to_image(sheet, (out, out))


def inferno_smoke(pal, frame=512, grid=4, out=1024):
    H = W = frame
    yy, xx = _grid(H, W)
    x = xx / (W - 1) * 2 - 1
    y = yy / (H - 1) * 2 - 1
    r = np.random.default_rng(23)
    blobs = [(r.uniform(-0.35, 0.35), r.uniform(-0.1, 0.35), r.uniform(0.28, 0.42)) for _ in range(9)]
    holes = periodic_noise(H, W, scales=((22, 1.0), (7, 0.5)), seed=24)
    sheet = np.zeros((H * grid, W * grid, 4))
    for f in range(grid * grid):
        t = f / (grid * grid - 1)
        rise = -0.5 * t
        expand = 0.7 + 0.6 * (1 - (1 - t) ** 2)
        field = np.zeros((H, W))
        for bx, by, br in blobs:
            d = np.sqrt((x - bx * expand * 1.3) ** 2 + (y - (by + rise) * expand) ** 2)
            field = np.maximum(field, 1 - d / (br * expand))
        field -= holes * (0.9 * max(0.0, (t - 0.25) / 0.75) ** 1.1)
        inside = field > 0.02
        inner = ndimage.binary_erosion(inside, iterations=8)
        # luz naranja de abajo (el fuego ilumina el humo desde abajo)
        under = inner & ~ndimage.shift(inside, (-24, 0), order=0, mode="constant", cval=0)
        img = rgba([(inside, pal["smoke_line"]), (inner, pal["smoke_fill"]), (under, pal["smoke_hi"]), (ndimage.binary_erosion(under, iterations=4), pal["deep"])], (H, W))
        rr, cc = divmod(f, grid)
        sheet[rr * H:(rr + 1) * H, cc * W:(cc + 1) * W] = img
    return to_image(sheet, (out, out))


def inferno_slash(pal, W=2048, H=512, out=(1024, 256)):
    yy, xx = _grid(H, W)
    u = xx / (W - 1)
    v = yy / (H - 1) * 2 - 1
    taper = np.clip(np.sin(np.pi * u), 0, 1) ** 0.5
    # cuerpo grueso abajo y lenguas de fuego que saltan del borde de arriba
    tongues = periodic_noise(1, W, scales=((18, 1.0), (6, 0.5)), seed=25)[0]
    top = (0.35 + 0.65 * tongues)[None, :] * taper
    bot = -0.55 * taper
    body = np.where(v < 0, 1 - v / (bot - 1e-3), 1 - v / (top + 1e-3))
    turb = periodic_noise(H, W, scales=((40, 1.0), (14, 0.4)), seed=26)
    field = body + (turb - 0.5) * 0.3
    layers = bands(field, 0.0, outline_px=8, levels=(0.2, 0.45, 0.7), pal_keys=("deep", "body", "mid", "core"), pal=pal)
    return to_image(rgba(layers, (H, W)), out)


def inferno_swirl(pal, W=2048, H=512, out=(1024, 256)):
    # muro de fuego: lenguas verticales que se repiten a lo largo (columna / tornado)
    yy, xx = _grid(H, W)
    u = xx / (W - 1)
    v = 1 - yy / (H - 1)
    hgt = periodic_noise(1, W, scales=((14, 1.0), (5, 0.6)), seed=27)[0]
    hgt = 0.35 + 0.6 * hgt
    field = 1 - v / (hgt[None, :] + 1e-3)
    turb = periodic_noise(H, W, scales=((5, 1.0), (2, 0.5)), seed=28)
    field = field + (turb - 0.5) * 0.6
    layers = bands(field, 0.0, outline_px=8, levels=(0.2, 0.45, 0.7), pal_keys=("deep", "body", "mid", "core"), pal=pal)
    return to_image(rgba(layers, (H, W)), out)


def inferno_ring(pal, S=1024, out=512):
    yy, xx = _grid(S, S)
    x = xx / (S - 1) * 2 - 1
    y = yy / (S - 1) * 2 - 1
    d = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    n = periodic_noise(1, 720, scales=((4, 1.0), (2, 0.5)), seed=29)[0]
    idx = ((ang + np.pi) / (2 * np.pi) * 719).astype(int)
    outer = 0.7 + 0.28 * n[idx] ** 1.5  # picos de fuego hacia afuera
    inner = 0.62
    field = np.minimum((d - inner) / 0.06, (outer - d) / 0.06)
    layers = bands(field, 0.0, outline_px=7, levels=(0.6, 1.4, 2.4), pal_keys=("deep", "body", "mid", "core"), pal=pal)
    return to_image(rgba(layers, (S, S)), (out, out))


def inferno_circle(pal, S=2048, out=1024):
    # cráter de lava: grietas radiales y anillo de roca agrietada (no es un sello mágico)
    yy, xx = _grid(S, S)
    x = xx / (S - 1) * 2 - 1
    y = yy / (S - 1) * 2 - 1
    d = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    rng = np.random.default_rng(30)
    pts = rng.uniform(-1, 1, (90, 2))
    from scipy.spatial import cKDTree
    tree = cKDTree(pts)
    sample = np.stack([x.ravel(), y.ravel()], 1)
    dist, _ = tree.query(sample, k=2)
    edge = (dist[:, 1] - dist[:, 0]).reshape(S, S)
    cracks = (edge < 0.018) & (d < 0.95)
    rays = np.zeros((S, S), bool)
    for k in range(9):
        a0 = k * 2 * np.pi / 9 + rng.uniform(-0.2, 0.2)
        wob = 0.05 * np.sin(d * 18 + k)
        rays |= (np.abs(((ang - a0 - wob + np.pi) % (2 * np.pi)) - np.pi) < 0.035 * (1.1 - d)) & (d < 0.95)
    lines = cracks | rays
    lines &= d > 0.12
    core = d < 0.18
    glow = ndimage.gaussian_filter((lines | core).astype(float), 10)
    glow = glow / glow.max()
    thick = ndimage.binary_dilation(lines, iterations=4)
    fade = np.clip((1 - d) * 3, 0, 1)
    img = rgba([(np.clip(glow * 1.5, 0, 1) * 0.75 * fade, pal["deep"]), (thick & (fade > 0), pal["outline"]), (lines, pal["body"]),
                (ndimage.binary_erosion(lines, iterations=2), pal["mid"]), (core, pal["mid"]), (d < 0.1, pal["core"])], (S, S))
    return to_image(img, (out, out))


def inferno_star(pal, S=512, out=256):
    # explosión irregular de 8 picos de distinto largo
    yy, xx = _grid(S, S)
    x = xx / (S - 1) * 2 - 1
    y = yy / (S - 1) * 2 - 1
    d = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    rng = np.random.default_rng(31)
    lens = rng.uniform(0.55, 0.98, 8)
    k = (ang + np.pi) / (2 * np.pi) * 8
    i0 = np.floor(k).astype(int) % 8
    frac = k - np.floor(k)
    tip = np.where(frac < 0.5, lens[i0], lens[(i0 + 1) % 8])
    spike = 0.3 + (tip - 0.3) * (1 - np.abs(frac - 0.5) * 2) ** 2.5
    spike = np.maximum(spike, 0.32)
    field = 1 - d / spike
    layers = bands(field, 0.0, outline_px=6, levels=(0.25, 0.5, 0.75), pal_keys=("deep", "body", "mid", "core"), pal=pal)
    return to_image(rgba(layers, (S, S)), (out, out))


def inferno_speedline(pal, W=512, H=128, out=(256, 64)):
    # cometa: cabeza redonda a la derecha y cola de fuego que se deshilacha
    yy, xx = _grid(H, W)
    u = xx / (W - 1)
    v = yy / (H - 1) * 2 - 1
    tail = periodic_noise(H, W, scales=((3, 1.0),), seed=32)
    width = 0.15 + 0.75 * u ** 1.5
    head = np.sqrt(((u - 0.88) / 0.12) ** 2 + (v / 0.85) ** 2)
    field = np.maximum(1 - np.abs(v) / (width + 1e-3) + (tail - 0.5) * 0.7 * (1 - u), 1 - head)
    layers = bands(field, 0.0, outline_px=5, levels=(0.3, 0.6), pal_keys=("body", "mid", "core"), pal=pal)
    return to_image(rgba(layers, (H, W)), out)


# =============================================================== CRIMSON
def crimson_flame(pal, frame=512, grid=4, out=1024):
    # espinas de energía que suben y se quiebran en esquirlas (nada de llama redonda)
    H = W = frame
    yy, xx = _grid(H, W)
    y = 1 - yy / (H - 1)
    x = (xx / (W - 1)) * 2 - 1
    spikes = [(-0.45, 0.55, 0.13), (-0.2, 0.85, 0.16), (0.04, 1.0, 0.2), (0.27, 0.75, 0.15), (0.48, 0.5, 0.12)]
    sheet = np.zeros((H * grid, W * grid, 4))
    for f in range(grid * grid):
        t = f / (grid * grid - 1)
        grow = min(1.0, t * 3.0)
        field = np.full((H, W), -1.0)
        for i, (cx, h, w) in enumerate(spikes):
            lean = (cx * 0.25)
            hh = h * grow
            ys = (y - 0.05) / max(hh, 1e-3)
            xc = cx + lean * ys
            width = w * np.clip(1 - ys, 0, 1)  # triángulo: punta afilada
            spike = 1 - np.abs(x - xc) / (width + 1e-3)
            spike = np.where((ys < 0) | (ys > 1), -1, spike)
            field = np.maximum(field, spike)
        # al final se quiebran: cortes horizontales que crecen
        if t > 0.5:
            breaks = np.abs(np.sin(y * 34 + x * 9)) < (t - 0.5) * 1.6
            field = np.where(breaks, -1, field)
        alive = 1.0 if t < 0.85 else (1 - (t - 0.85) / 0.15)
        layers = bands(field, 0.0 + (1 - alive) * 0.6, outline_px=7, levels=(0.3, 0.6), pal_keys=("deep", "body", "core"), pal=pal)
        img = rgba(layers, (H, W))
        r_, c_ = divmod(f, grid)
        sheet[r_ * H:(r_ + 1) * H, c_ * W:(c_ + 1) * W] = img
    return to_image(sheet, (out, out))


def crimson_smoke(pal, frame=512, grid=4, out=1024):
    # jirones finos de niebla que se enroscan y se disuelven
    H = W = frame
    yy, xx = _grid(H, W)
    x = xx / (W - 1) * 2 - 1
    y = yy / (H - 1) * 2 - 1
    sheet = np.zeros((H * grid, W * grid, 4))
    for f in range(grid * grid):
        t = f / (grid * grid - 1)
        field = np.full((H, W), -1.0)
        for k in range(4):
            a0 = k * np.pi / 2 + t * 2.5
            rr = np.sqrt(x * x + y * y)
            aa = np.arctan2(y, x)
            target = 0.2 + 0.11 * ((aa - a0) % (2 * np.pi)) * (0.7 + 0.5 * t)
            band = 1 - np.abs(rr - target) / (0.11 * (1 - 0.5 * t) + 0.02)
            seg = ((aa - a0) % (2 * np.pi)) < (1.2 + 3 * t)
            field = np.maximum(field, np.where(seg, band, -1))
        thresh = max(0.0, (t - 0.55) / 0.45) * 0.9
        layers = [(field > thresh, pal["smoke_line"]), (ndimage.binary_erosion(field > thresh, iterations=4), pal["smoke_fill"]),
                  (ndimage.binary_erosion(field > thresh + 0.4, iterations=2), pal["smoke_hi"])]
        img = rgba(layers, (H, W))
        rr_, cc = divmod(f, grid)
        sheet[rr_ * H:(rr_ + 1) * H, cc * W:(cc + 1) * W] = img
    return to_image(sheet, (out, out))


def crimson_slash(pal, W=2048, H=512, out=(1024, 256)):
    # filo finísimo: núcleo negro, borde rojo intenso, y cortes finos que lo acompañan
    yy, xx = _grid(H, W)
    u = xx / (W - 1)
    v = yy / (H - 1) * 2 - 1
    taper = np.clip(np.sin(np.pi * u ** 0.8), 0, 1) ** 1.4
    main = 1 - np.abs(v - 0.1) / (0.32 * taper + 1e-3)
    side = np.full((H, W), -1.0)
    for off, length, w in ((-0.55, 0.6, 0.06), (0.62, 0.45, 0.05), (-0.8, 0.35, 0.04)):
        lt = np.clip(np.sin(np.pi * np.clip((u - (1 - length) / 2) / length, 0, 1)), 0, 1)
        side = np.maximum(side, 1 - np.abs(v - off) / (w * lt + 1e-3))
    field = np.maximum(main, side)
    inside = field > 0
    rim = inside & ~ndimage.binary_erosion(inside, iterations=10)
    center = main > 0.55
    img = rgba([(inside, pal["outline"]), (ndimage.binary_erosion(inside, iterations=3), pal["body"]),
                (ndimage.binary_erosion(inside, iterations=7), pal["mid"]), (center, pal["outline"]),
                (main > 0.8, pal["deep"])], (H, W))
    return to_image(img, out)


def crimson_swirl(pal, W=2048, H=512, out=(1024, 256)):
    # dos cintas finas en hélice (se cruzan) en vez de una franja turbulenta
    yy, xx = _grid(H, W)
    u = xx / (W - 1)
    v = yy / (H - 1) * 2 - 1
    field = np.full((H, W), -1.0)
    for ph in (0, np.pi):
        c = 0.7 * np.sin(u * 2 * np.pi * 3 + ph)
        field = np.maximum(field, 1 - np.abs(v - c) / 0.12)
    layers = bands(field, 0.0, outline_px=6, levels=(0.35, 0.7), pal_keys=("deep", "body", "core"), pal=pal)
    return to_image(rgba(layers, (H, W)), out)


def crimson_ring(pal, S=1024, out=512):
    # anillo roto en esquirlas con huecos
    yy, xx = _grid(S, S)
    x = xx / (S - 1) * 2 - 1
    y = yy / (S - 1) * 2 - 1
    d = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    k = (ang + np.pi) / (2 * np.pi) * 14
    frac = k - np.floor(k)
    shard = (frac > 0.08) & (frac < 0.92)
    # cada esquirla es un rombo afilado
    width = 0.07 * (1 - np.abs(frac - 0.5) * 2) ** 0.6
    field = np.where(shard, 1 - np.abs(d - 0.84) / (width + 1e-3), -1)
    layers = bands(field, 0.0, outline_px=5, levels=(0.4, 0.75), pal_keys=("body", "mid", "core"), pal=pal)
    return to_image(rgba(layers, (S, S)), (out, out))


def crimson_circle(pal, S=2048, out=1024):
    # sigilo geométrico: hexágonos y triángulos con espinas hacia afuera
    yy, xx = _grid(S, S)
    x = xx / (S - 1) * 2 - 1
    y = yy / (S - 1) * 2 - 1
    d = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    px = 2 / S
    lines = np.zeros((S, S), bool)

    def poly(n, r, rot, w):
        a = (ang - rot) % (2 * np.pi / n) - np.pi / n
        rr = r * np.cos(np.pi / n) / np.cos(a)
        return np.abs(d - rr) < w * px

    lines |= np.abs(d - 0.95) < 7 * px
    lines |= poly(6, 0.88, 0, 8)
    lines |= poly(6, 0.62, np.pi / 6, 6)
    lines |= poly(3, 0.6, np.pi / 2, 6) | poly(3, 0.6, -np.pi / 2, 6)
    lines |= np.abs(d - 0.22) < 6 * px
    # espinas que salen del hexágono exterior
    k = (ang / (2 * np.pi) * 24) % 1
    lines |= (np.abs(k - 0.5) < 0.12 * (1 - (d - 0.88) / 0.1)) & (d > 0.88) & (d < 0.98)
    # rayos cortos entre hexágonos
    k6 = (ang / (2 * np.pi) * 12) % 1
    lines |= (np.abs(k6 - 0.5) < 0.01 / np.maximum(d, 0.1)) & (d > 0.64) & (d < 0.86)
    glow = ndimage.gaussian_filter(lines.astype(float), 5)
    glow = glow / glow.max()
    thick = ndimage.binary_dilation(lines, iterations=4)
    img = rgba([(np.clip(glow * 1.4, 0, 1) * 0.6, pal["deep"]), (thick, pal["outline"]), (lines, pal["body"]),
                (ndimage.binary_erosion(lines, iterations=2), pal["mid"])], (S, S))
    return to_image(img, (out, out))


def crimson_star(pal, S=512, out=256):
    # 6 agujas largas y finas con un rombo al centro
    yy, xx = _grid(S, S)
    x = xx / (S - 1) * 2 - 1
    y = yy / (S - 1) * 2 - 1
    d = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    a = (ang % (np.pi / 3)) - np.pi / 6
    needle = 1 - np.abs(a) / (0.09 * np.clip(1 - d, 0, 1) ** 1.5 + 1e-3)
    needle = np.where(d < 0.98, needle, -1)
    diamond = 1 - (np.abs(x) + np.abs(y)) / 0.25
    field = np.maximum(needle, diamond)
    layers = bands(field, 0.0, outline_px=5, levels=(0.35, 0.7), pal_keys=("body", "mid", "core"), pal=pal)
    return to_image(rgba(layers, (S, S)), (out, out))


def crimson_speedline(pal, W=512, H=128, out=(256, 64)):
    # aguja recta y fina, con punta a la derecha
    yy, xx = _grid(H, W)
    u = xx / (W - 1)
    v = yy / (H - 1) * 2 - 1
    width = 0.5 * np.clip(u / 0.8, 0, 1) * np.clip((1 - u) / 0.2, 0, 1)
    field = 1 - np.abs(v) / (width + 1e-3)
    layers = bands(field, 0.0, outline_px=4, levels=(0.4,), pal_keys=("body", "core"), pal=pal)
    return to_image(rgba(layers, (H, W)), out)


SHAPES = {
    "inferno": {
        "flame": inferno_flame, "smoke": inferno_smoke, "slash": inferno_slash, "swirl": inferno_swirl,
        "ring": inferno_ring, "circle": inferno_circle, "star": inferno_star, "speedline": inferno_speedline,
    },
    "crimson": {
        "flame": crimson_flame, "smoke": crimson_smoke, "slash": crimson_slash, "swirl": crimson_swirl,
        "ring": crimson_ring, "circle": crimson_circle, "star": crimson_star, "speedline": crimson_speedline,
    },
}
