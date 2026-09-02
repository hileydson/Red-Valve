"""Etapa 01 — o terreno é DERIVADO das ruas (§0.2 do plano).

Forma base (plano inclinado + feições suaves + ruído) e, por cima, as vias
nivelam o corredor: cada célula dentro de largura/2 assenta exatamente na cota
da rua, com ombro em smoothstep até voltar ao terreno natural.
"""
import math
import os
import struct

import numpy as np

from . import layout

_HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(_HERE, "out")


# ---------------------------------------------------------------- ruido
def _hash2(ix, iy, seed):
    """Hash inteiro -> [0,1). Deterministico, sem dependencia externa."""
    u = np.uint64
    n = (ix.astype(u) * u(374761393) + iy.astype(u) * u(668265263)
         + u(seed) * u(2246822519)) & u(0xFFFFFFFF)
    n = ((n ^ (n >> u(13))) * u(1274126177)) & u(0xFFFFFFFF)
    n = (n ^ (n >> u(16))) & u(0xFFFFFFFF)
    return n.astype(np.float64) / 4294967295.0


def _value_noise(PX, PY, cell, seed):
    gx, gy = PX / cell, PY / cell
    ix, iy = np.floor(gx).astype(np.int64), np.floor(gy).astype(np.int64)
    fx, fy = gx - ix, gy - iy
    u = fx * fx * (3.0 - 2.0 * fx)
    v = fy * fy * (3.0 - 2.0 * fy)
    a = _hash2(ix, iy, seed)
    b = _hash2(ix + 1, iy, seed)
    c = _hash2(ix, iy + 1, seed)
    d = _hash2(ix + 1, iy + 1, seed)
    return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v


def fbm(PX, PY, cell, octaves=4, seed=1337):
    """fBm em [-1,1]. Razao de oitava nao-binaria evita alinhamento de grade."""
    total = np.zeros(np.broadcast(PX, PY).shape, dtype=np.float64)
    amp, norm, c = 1.0, 0.0, float(cell)
    for o in range(octaves):
        total += amp * (_value_noise(PX, PY, c, seed + o * 977) - 0.5) * 2.0
        norm += amp
        amp *= 0.5
        c *= 0.47
    return total / norm


def _smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _resample(points, step=2.0):
    """Redistribui a polilinha em passos ~constantes."""
    out = [tuple(points[0])]
    carry = 0.0
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        seg = math.hypot(x1 - x0, y1 - y0)
        if seg < 1e-6:
            continue
        d = step - carry
        while d < seg:
            t = d / seg
            out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
            d += step
        carry = seg - (d - step)
    out.append(tuple(points[-1]))
    return out


def _moving_average(vals, window):
    if window <= 1 or len(vals) < 3:
        return vals
    k = min(window, len(vals) | 1)
    pad = k // 2
    ext = np.concatenate([np.full(pad, vals[0]), vals, np.full(pad, vals[-1])])
    ker = np.ones(k) / float(k)
    return np.convolve(ext, ker, mode="valid")


def base_field(PX, PY, cfg):
    bp = cfg["base_plane"]
    h = bp["h0"] + bp["slope_north"] * PY + bp["slope_east"] * PX
    for f in cfg["features"]:
        cx, cy = f["center"]
        d = np.hypot(PX - cx, PY - cy)
        w = _smoothstep(1.0 - d / float(f["radius"]))
        h = h + (f["amount"] if f["kind"] == "raise" else -f["amount"]) * w
    n = cfg["noise"]
    h = h + n["amplitude"] * fbm(PX, PY, float(n["wavelength"]),
                                 octaves=int(n.get("octaves", 4)),
                                 seed=int(n.get("seed", 1337)))
    return h


def build_heightfield():
    data = layout.load()
    w = data["world"]
    cfg = data["terrain"]
    W, H = w["import_size"]
    cx0, cz0 = w["import_corner"]

    # grade de amostragem em coordenadas locais da cidade
    i = np.arange(W, dtype=np.float64)
    j = np.arange(H, dtype=np.float64)
    GX = cx0 + i[None, :]                       # Godot X
    GZ = cz0 + j[:, None]                       # Godot Z
    PX = GX - w["origin_x"]
    PY = w["origin_z"] - GZ
    PX, PY = np.broadcast_arrays(PX, PY)

    h = base_field(PX, PY, cfg)

    # ---- nivelamento pelas vias ----
    rg = cfg["road_grading"]
    shoulder = float(rg["shoulder"])
    wsum = np.zeros((H, W))
    hsum = np.zeros((H, W))
    auth = np.zeros((H, W))

    for road in data["roads"]:
        pts = _resample(road["points"], 2.0)
        ax = np.array([p[0] for p in pts])
        ay = np.array([p[1] for p in pts])
        hz = base_field(ax, ay, cfg)
        hz = _moving_average(hz, int(rg["smooth_window"]))
        half = road["width"] / 2.0
        reach = half + shoulder

        for k in range(len(pts)):
            gx = w["origin_x"] + ax[k]
            gz = w["origin_z"] - ay[k]
            ci = gx - cx0
            cj = gz - cz0
            i0 = max(0, int(ci - reach)); i1 = min(W, int(ci + reach) + 2)
            j0 = max(0, int(cj - reach)); j1 = min(H, int(cj + reach) + 2)
            if i0 >= i1 or j0 >= j1:
                continue
            sub_i = np.arange(i0, i1)[None, :]
            sub_j = np.arange(j0, j1)[:, None]
            d = np.hypot(sub_i - ci, sub_j - cj)
            f = _smoothstep((reach - d) / shoulder)
            np.maximum(auth[j0:j1, i0:i1], f, out=auth[j0:j1, i0:i1])
            wsum[j0:j1, i0:i1] += f
            hsum[j0:j1, i0:i1] += f * hz[k]

    road_h = np.where(wsum > 1e-9, hsum / np.maximum(wsum, 1e-9), h)
    h = h * (1.0 - auth) + road_h * auth
    return h, (W, H)


def write_raw(h, path=None):
    """float32 cru, little-endian, row-major — lido pelo @tool no Godot."""
    path = path or os.path.join(OUT, "city_height.f32")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    a = np.ascontiguousarray(h.astype("<f4"))
    with open(path, "wb") as fh:
        fh.write(a.tobytes())
    return {"path": path, "bytes": a.nbytes,
            "min": float(h.min()), "max": float(h.max()),
            "relevo": round(float(h.max() - h.min()), 2)}
