"""Etapa 02 — sistema viário com seção transversal real.

Pista com abaulamento de 2%, meio-fio com quebras, calçada que some em trechos,
sarjeta e trilha de roda em vertex color, becos degradando para terra batida.

Convenções:
  UV : U = deslocamento lateral / TILE ; V = distância percorrida / TILE
       (textura tileável de 4 m — a mesma que a Etapa 02 vai assar)
  COR: vertex color usada como *tint* de albedo (mobile-safe, sem shader
       custom): escurece na sarjeta, clareia na trilha de roda.
"""
import math

import numpy as np

from . import util, layout, materials as M

COL = "02_ROADS"
TILE = 4.0

# por classe: material, meio-fio, largura da calçada, deslocamento em Z
CLASS = {
    "avenida":    dict(mat="cobble_base", curb=True,  walk=1.8, z=0.030, worn=0.55),
    "principal":  dict(mat="cobble_base", curb=True,  walk=1.4, z=0.024, worn=0.70),
    "radial":     dict(mat="cobble_base", curb=True,  walk=1.2, z=0.018, worn=0.60),
    "secundaria": dict(mat="cobble_base", curb=True,  walk=1.0, z=0.012, worn=0.85),
    "travessa":   dict(mat="dirt_road",   curb=False, walk=0.0, z=0.006, worn=1.0),
    "beco":       dict(mat="dirt_road",   curb=False, walk=0.0, z=0.000, worn=1.0),
}

GUTTER = (0.42, 0.39, 0.33)      # tint da sarjeta
TRACK = (1.0, 0.99, 0.96)        # tint da trilha polida
BASE = (0.82, 0.81, 0.78)        # tint padrão da pista
WALK = (0.90, 0.89, 0.86)


def _n1(t, seed):
    """Ruído 1-D suave e determinístico ao longo da via."""
    i = math.floor(t)
    f = t - i
    f = f * f * (3.0 - 2.0 * f)

    def h(k):
        n = (int(k) * 374761393 + seed * 668265263) & 0xFFFFFFFF
        n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((n ^ (n >> 16)) & 0xFFFFFFFF) / 4294967295.0
    return h(i) * (1 - f) + h(i + 1) * f


def _resample(points, step):
    out, carry = [tuple(points[0])], 0.0
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


class Neighbors(object):
    """Grade espacial dos eixos, para detectar proximidade de cruzamento."""

    CELL = 18.0

    def __init__(self, roads):
        self.g = {}
        for r in roads:
            for x, y in _resample(r["points"], 4.0):
                key = (int(math.floor(x / self.CELL)), int(math.floor(y / self.CELL)))
                self.g.setdefault(key, []).append((r["id"], x, y))

    def near_other(self, rid, x, y, radius):
        ci, cj = int(math.floor(x / self.CELL)), int(math.floor(y / self.CELL))
        r2 = radius * radius
        for di in (-1, 0, 1):
            for dj in (-1, 0, 1):
                for oid, ox, oy in self.g.get((ci + di, cj + dj), ()):
                    if oid == rid:
                        continue
                    if (ox - x) ** 2 + (oy - y) ** 2 < r2:
                        return True
        return False


def _strip(name, rows, col, mat, uv, cols):
    """Constrói uma faixa a partir de linhas de N vértices."""
    n = len(rows[0])
    verts, faces = [], []
    for row in rows:
        verts.extend(row)
    for i in range(len(rows) - 1):
        for j in range(n - 1):
            a = i * n + j
            faces.append((a, a + 1, a + n + 1, a + n))
    ob = util._mk(name, verts, faces, col, mat)
    util.faces_up(ob)
    me = ob.data
    uvl = me.uv_layers.new(name="UVMap")
    cl = me.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="CORNER")
    for loop in me.loops:
        uvl.data[loop.index].uv = uv[loop.vertex_index]
        c = cols[loop.vertex_index]
        cl.data[loop.index].color = (c[0], c[1], c[2], 1.0)
    return ob


def build_road(col, road, hs, nb):
    cfg = CLASS[road["class"]]
    hw = road["width"] / 2.0
    camber = hw * 0.02
    pts = _resample(road["points"], 2.0)
    if len(pts) < 2:
        return 0

    # quadros ao longo do eixo
    st, dist = [], 0.0
    for k, (x, y) in enumerate(pts):
        if k:
            dist += math.hypot(x - pts[k - 1][0], y - pts[k - 1][1])
        if k == 0:
            dx, dy = pts[1][0] - x, pts[1][1] - y
        elif k == len(pts) - 1:
            dx, dy = x - pts[-2][0], y - pts[-2][1]
        else:
            dx, dy = pts[k + 1][0] - pts[k - 1][0], pts[k + 1][1] - pts[k - 1][1]
        L = math.hypot(dx, dy) or 1.0
        st.append(dict(x=x, y=y, nx=-dy / L, ny=dx / L, s=dist,
                       z=hs.at(x, y) + cfg["z"],
                       cross=nb.near_other(road["id"], x, y, hw + 5.0)))

    made = 0
    # ---- pista, com abaulamento ----
    lat = [-hw, -hw * 0.55, -hw * 0.2, 0.0, hw * 0.2, hw * 0.55, hw]
    rows, uv, cols = [], [], []
    for s in st:
        row = []
        for o in lat:
            f = abs(o) / hw
            z = s["z"] + camber * (1.0 - f * f)
            row.append((s["x"] + s["nx"] * o, s["y"] + s["ny"] * o, z))
            uv.append((o / TILE, s["s"] / TILE))
            edge = max(0.0, 1.0 - (hw - abs(o)) / 0.9)          # sarjeta
            trk = max(0.0, 1.0 - abs(abs(o) - hw * 0.45) / 0.8)  # trilha de roda
            trk *= cfg["worn"]
            c = [BASE[i] * (1 - edge) + GUTTER[i] * edge for i in range(3)]
            c = [c[i] * (1 - trk) + TRACK[i] * trk for i in range(3)]
            cols.append(c)
        rows.append(row)
    _strip("SM_road_%s_surface" % road["id"], rows, col, M.get(cfg["mat"]), uv, cols)
    made += 1

    if not cfg["curb"]:
        return made

    # ---- meio-fio e calçada, com quebras e trechos ausentes ----
    for side in (-1, 1):
        seg_curb, seg_walk = [], []
        run_c, run_w = [], []
        for s in st:
            t = s["s"] / 26.0
            tem_curb = (not s["cross"]) and _n1(t, 91 if side < 0 else 137) > 0.24
            tem_walk = tem_curb and _n1(s["s"] / 55.0, 17 if side < 0 else 53) > 0.30
            o0 = side * hw
            if tem_curb:
                a = (s["x"] + s["nx"] * o0, s["y"] + s["ny"] * o0, s["z"])
                b = (s["x"] + s["nx"] * (o0 + side * 0.20),
                     s["y"] + s["ny"] * (o0 + side * 0.20), s["z"] + 0.15)
                run_c.append((a, b, s["s"]))
            elif run_c:
                seg_curb.append(run_c); run_c = []
            if tem_walk:
                w = cfg["walk"]
                p0 = o0 + side * 0.20
                p1 = p0 + side * w
                run_w.append(((s["x"] + s["nx"] * p0, s["y"] + s["ny"] * p0, s["z"] + 0.15),
                              (s["x"] + s["nx"] * p1, s["y"] + s["ny"] * p1, s["z"] + 0.16),
                              s["s"]))
            elif run_w:
                seg_walk.append(run_w); run_w = []
        if run_c:
            seg_curb.append(run_c)
        if run_w:
            seg_walk.append(run_w)

        for idx, run in enumerate(seg_curb):
            if len(run) < 3:
                continue
            rows = [[a, b] for a, b, _ in run]
            uv, cols = [], []
            for _, _, s_ in run:
                for u in (0.0, 0.20 / TILE):
                    uv.append((u, s_ / TILE)); cols.append(BASE)
            _strip("SM_road_%s_curb%s_%02d" % (road["id"], "L" if side < 0 else "R", idx),
                   rows, col, M.get("curb_granite"), uv, cols)
            made += 1
        for idx, run in enumerate(seg_walk):
            if len(run) < 3:
                continue
            rows = [[a, b] for a, b, _ in run]
            uv, cols = [], []
            for _, _, s_ in run:
                for u in (0.0, cfg["walk"] / TILE):
                    uv.append((u, s_ / TILE)); cols.append(WALK)
            _strip("SM_road_%s_walk%s_%02d" % (road["id"], "L" if side < 0 else "R", idx),
                   rows, col, M.get("sidewalk_concrete"), uv, cols)
            made += 1
    return made


def build(parent, hs):
    data = layout.load()
    col = util.reset_collection(COL, parent)
    nb = Neighbors(data["roads"])
    total = 0
    for road in data["roads"]:
        total += build_road(col, road, hs, nb)
    return {"objetos": total, "vias": len(data["roads"])}
