"""Etapa 03 — quadras, muros e divisas.

O que fecha o corredor da rua. Cada quadra ganha um **patamar** (cota media
dos cantos); o muro nasce no terreno e termina no patamar + altura, entao em
declive ele cresce sozinho — o efeito de arrimo aparece por construcao, sem
geometria especial.
"""
import math
import random

from . import util, layout, materials as M

COL = "03_BLOCKS"
ESP = 0.20          # espessura do muro
H_MURO = (1.80, 2.20)
PASSO = 0.5         # estacao ao longo do muro
TILE = 2.0

MUROS = ("wall_whitewash", "wall_render_raw", "wall_brick")


def _n1(t, seed):
    i = math.floor(t); f = t - i
    f = f * f * (3.0 - 2.0 * f)

    def h(k):
        n = (int(k) * 374761393 + seed * 668265263) & 0xFFFFFFFF
        n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((n ^ (n >> 16)) & 0xFFFFFFFF) / 4294967295.0
    return h(i) * (1 - f) + h(i + 1) * f


def _strip(name, rows, col, mat, uv):
    n = len(rows[0])
    verts, faces = [], []
    for r in rows:
        verts.extend(r)
    for i in range(len(rows) - 1):
        for j in range(n - 1):
            a = i * n + j
            faces.append((a, a + 1, a + n + 1, a + n))
    ob = util._mk(name, verts, faces, col, mat)
    uvl = ob.data.uv_layers.new(name="UVMap")
    for loop in ob.data.loops:
        uvl.data[loop.index].uv = uv[loop.vertex_index]
    return ob


def build_muro(col, name, a, b, hs, plat, mat, rng, seed):
    """Muro de alvenaria com topo quebrado, do terreno ate o patamar+altura."""
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    if L < 1.0:
        return 0
    nseg = max(2, int(L / PASSO))
    dx, dy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    nx, ny = -dy * ESP / 2.0, dx * ESP / 2.0
    h_nom = rng.uniform(*H_MURO)

    rows, uv = [], []
    for i in range(nseg + 1):
        t = i / float(nseg)
        s = L * t
        x, y = a[0] + dx * s, a[1] + dy * s
        base = hs.at(x, y) - 0.06
        top = plat + h_nom + (_n1(s / 3.1, seed) - 0.5) * 0.22
        if _n1(s / 7.3, seed + 41) > 0.80:          # pedaco faltando no topo
            top -= 0.30 + 0.35 * _n1(s / 2.0, seed + 5)
        top = max(top, base + 0.35)
        rows.append([(x + nx, y + ny, base), (x + nx, y + ny, top),
                     (x - nx, y - ny, top), (x - nx, y - ny, base)])
        for v in (0.0, (top - base) / TILE, (top - base) / TILE, 0.0):
            uv.append((s / TILE, v))
    _strip(name, rows, col, M.get(mat), uv)
    return 1


def build_cerca_madeira(col, name, a, b, hs, plat, rng, i0):
    """Cerca de tabua: mourao a cada 2 m e travessas."""
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    if L < 1.0:
        return 0
    dx, dy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    n = 0
    mat = M.get("wood_aged")
    for s in [k * 2.0 for k in range(int(L / 2.0) + 1)]:
        x, y = a[0] + dx * s, a[1] + dy * s
        util.box("%s_p%02d" % (name, n), 0.11, 0.11, 1.55 + rng.uniform(-0.1, 0.1),
                 col, mat, loc=(x, y, hs.at(x, y)),
                 rot=(0, 0, math.atan2(dy, dx) + rng.uniform(-0.05, 0.05)))
        n += 1
    for hz in (0.55, 1.15):
        mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
        util.box("%s_t%.0f" % (name, hz * 10), L, 0.06, 0.16, col, mat,
                 loc=(mx, my, hs.at(mx, my) + hz),
                 rot=(0, 0, math.atan2(dy, dx)))
        n += 1
    return n


def build_portao(col, name, a, b, hs, plat, rng):
    """Portao de chapa ondulada, um pouco mais baixo que o muro."""
    mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    util.box(name, min(L, 3.2), 0.08, 1.95 + rng.uniform(-0.12, 0.12), col,
             M.get("roof_metal_rust"), loc=(mx, my, hs.at(mx, my)),
             rot=(0, 0, ang + rng.uniform(-0.03, 0.03)))
    return 1


def build_lote(col, name, poly, plat, mat, hs):
    """Patamar do lote mais a **saia** que desce ate o terreno.

    Sem a saia a laje do lote flutua e a borda aparece como corte seco contra
    o terreno; com ela o patamar vira aterro, que e o que existe de verdade.
    """
    verts = [(x, y, plat) for x, y in poly]
    ob = util._mk(name, verts, [tuple(range(len(poly)))], col, M.get(mat))
    util.faces_up(ob)

    rows = []
    n = len(poly)
    for k in range(n + 1):
        x, y = poly[k % n]
        z = min(hs.at(x, y) - 0.10, plat - 0.02)
        rows.append([(x, y, plat), (x, y, z)])
    _strip(name + "_saia", rows, col, M.get("dirt_road"),
           [(0.0, 0.0)] * (len(rows) * 2))
    return ob


def build_mato(col, name, poly, plat, rng, n=14):
    """Moitas de mato para terreno baldio."""
    feitos = 0
    for k in range(n):
        i = rng.randrange(len(poly))
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % len(poly)]
        cx = sum(p[0] for p in poly) / len(poly)
        cy = sum(p[1] for p in poly) / len(poly)
        t, u = rng.random(), rng.random() * 0.8
        px = x0 + (x1 - x0) * t
        py = y0 + (y1 - y0) * t
        x = px + (cx - px) * u
        y = py + (cy - py) * u
        s = rng.uniform(0.5, 1.4)
        util.box("%s_%02d" % (name, k), s, s * 0.8, rng.uniform(0.4, 1.1), col,
                 M.get("grass_dry"), loc=(x, y, plat), rot=(0, 0, rng.uniform(0, 3)))
        feitos += 1
    return feitos


def build(parent, hs):
    col = util.reset_collection(COL, parent)
    data = layout.load()
    rng = random.Random(777)
    n_muro = n_cerca = n_port = n_lote = n_mato = 0

    for bi, b in enumerate(data["blocks"]):
        poly = [(float(x), float(y)) for x, y in b["poly"]]
        # cota MAXIMA dos cantos: o patamar nunca fica abaixo do terreno
        plat = max(hs.at(x, y) for x, y in poly) + 0.12
        baldio = rng.random() < 0.18

        n_lote += 1
        build_lote(col, "SM_lot_%s" % b["id"], poly, plat,
                   "grass_dry" if baldio else "dirt_road", hs)
        if baldio:
            n_mato += build_mato(col, "SM_mato_%s" % b["id"], poly, plat, rng)

        # material do muro por trecho: paredes reais nao trocam a cada metro
        mat_atual = rng.choice(MUROS)
        for e in range(len(poly)):
            a, bb = poly[e], poly[(e + 1) % len(poly)]
            L = math.hypot(bb[0] - a[0], bb[1] - a[1])
            nsub = max(1, int(L / 7.0))
            for k in range(nsub):
                t0, t1 = k / float(nsub), (k + 1) / float(nsub)
                p0 = (a[0] + (bb[0] - a[0]) * t0, a[1] + (bb[1] - a[1]) * t0)
                p1 = (a[0] + (bb[0] - a[0]) * t1, a[1] + (bb[1] - a[1]) * t1)
                nome = "SM_div_%s_%d_%d" % (b["id"], e, k)
                r = rng.random()
                if baldio and r < 0.55:
                    continue                       # baldio: divisa incompleta
                if rng.random() < 0.22:
                    mat_atual = rng.choice(MUROS)
                if r < 0.10:
                    n_port += build_portao(col, nome, p0, p1, hs, plat, rng)
                elif r < 0.26:
                    n_cerca += build_cerca_madeira(col, nome, p0, p1, hs, plat, rng, k)
                else:
                    n_muro += build_muro(col, nome, p0, p1, hs, plat,
                                         mat_atual, rng, bi * 17 + e * 3 + k)
    return {"muros": n_muro, "cercas": n_cerca, "portoes": n_port,
            "lotes": n_lote, "mato": n_mato, "objetos": len(col.objects)}
