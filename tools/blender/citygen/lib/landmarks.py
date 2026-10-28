"""Etapa 05 — marcos da cidade.

Igreja e cemiterio sao PROXY (voce troca depois). Praca do obelisco e
estacao de tratamento sao ACABAMENTO: entram prontas para o jogo.
"""
import math
import random

from . import util, layout, materials as M

COL = "05_LANDMARKS"
TILE = 2.5


def _ring(cx, cy, cz, r, n, phase=0.0):
    return [(cx + r * math.cos(2 * math.pi * i / n + phase),
             cy + r * math.sin(2 * math.pi * i / n + phase), cz) for i in range(n)]


def _tube_faces(nrings, n, cap_top=False, cap_bot=False):
    f = []
    for k in range(nrings - 1):
        a, b = k * n, (k + 1) * n
        for i in range(n):
            j = (i + 1) % n
            f.append((a + i, a + j, b + j, b + i))
    if cap_bot:
        f.append(tuple(range(n - 1, -1, -1)))
    if cap_top:
        f.append(tuple(range((nrings - 1) * n, nrings * n)))
    return f


def taper(name, r0, r1, h, col, mat, loc, n=8, phase=0.0, rot=(0, 0, 0)):
    v = _ring(0, 0, 0, r0, n, phase) + _ring(0, 0, h, r1, n, phase)
    return util._mk(name, v, _tube_faces(2, n, True, True), col, mat, loc, rot)


def pyramid(name, r, h, col, mat, loc, n=8, phase=0.0):
    v = _ring(0, 0, 0, r, n, phase) + [(0.0, 0.0, h)]
    f = [(i, (i + 1) % n, n) for i in range(n)]
    f.append(tuple(range(n - 1, -1, -1)))
    return util._mk(name, v, f, col, mat, loc)


def disc(name, r, col, mat, loc, n=32):
    v = _ring(0, 0, 0, r, n)
    return util._mk(name, v, [tuple(range(n))], col, mat, loc)


def anel(name, r0, r1, h, col, mat, loc, n=32):
    """Anel (rosca) — usado no bordo do canteiro e nas paredes dos tanques."""
    v = _ring(0, 0, 0, r0, n) + _ring(0, 0, 0, r1, n) + \
        _ring(0, 0, h, r1, n) + _ring(0, 0, h, r0, n)
    f = []
    for k in range(3):
        a, b = k * n, (k + 1) * n
        for i in range(n):
            j = (i + 1) % n
            f.append((a + i, a + j, b + j, b + i))
    a, b = 3 * n, 0
    for i in range(n):
        j = (i + 1) % n
        f.append((a + i, a + j, b + j, b + i))
    return util._mk(name, v, f, col, mat, loc)


# ------------------------------------------------------------------ igreja
def build_igreja(col, e, hs):
    cx, cy = e["center"]
    w, d = e["size"]
    ang = math.radians(e.get("rotation", 0.0))
    z = hs.at(cx, cy)
    ca, sa = math.cos(ang), math.sin(ang)

    def P(lx, ly, lz):
        return (cx + lx * ca - ly * sa, cy + lx * sa + ly * ca, lz)

    n = 0
    # adro elevado com tres degraus
    for k in range(3):
        h = e["adro_h"] * (k + 1) / 3.0
        util.box("SM_igreja_degrau%d" % k, w + 7.0 - k * 1.6, d + 5.0 - k * 1.6, h,
                 col, M.get("sidewalk_concrete"), loc=(cx, cy, z), rot=(0, 0, ang))
        n += 1
    base = z + e["adro_h"]

    # nave
    hp = 11.0
    util.box("SM_igreja_nave", w, d, hp, col, M.get("wall_stone_church"),
             loc=(cx, cy, base), rot=(0, 0, ang))
    n += 1
    # telhado de duas aguas em ardosia
    rise = e["ridge_h"] - hp
    ex = 0.7
    v, f = [], []
    eave = [P(sx * (d / 2 + ex), sy * (w / 2 + ex), base + hp)
            for sx, sy in ((-1, -1), (-1, 1), (1, 1), (1, -1))]
    ridge = [P(0.0, sy * (w / 2 + ex), base + hp + rise) for sy in (-1, 1)]
    for tri in ((eave[0], eave[1], ridge[1], ridge[0]),
                (ridge[0], ridge[1], eave[2], eave[3])):
        i0 = len(v); v.extend(tri); f.append((i0, i0 + 1, i0 + 2, i0 + 3))
    for tri in ((eave[0], ridge[0], eave[3]), (eave[1], eave[2], ridge[1])):
        i0 = len(v); v.extend(tri); f.append((i0, i0 + 1, i0 + 2))
    ob = util._mk("SM_igreja_telhado", v, f, col, M.get("roof_slate_blue"))
    uvl = ob.data.uv_layers.new(name="UVMap")
    for lp in ob.data.loops:
        p = ob.data.vertices[lp.vertex_index].co
        uvl.data[lp.index].uv = (math.hypot(p.x - cx, p.y - cy) / TILE,
                                 (p.z - base) / TILE)
    n += 1

    # torre na fachada + coruchéu octogonal
    tw = 5.6
    tx, ty, _ = P(-d / 2 - tw / 2 + 0.6, 0.0, 0.0)
    corpo = 22.0
    util.box("SM_igreja_torre", tw, tw, corpo, col, M.get("wall_stone_church"),
             loc=(tx, ty, base), rot=(0, 0, ang))
    n += 1
    util.box("SM_igreja_cornija", tw + 0.7, tw + 0.7, 0.6, col,
             M.get("wall_stone_church"), loc=(tx, ty, base + corpo), rot=(0, 0, ang))
    n += 1
    pyramid("SM_igreja_corucheu", tw * 0.72, e["tower_h"] - corpo - 0.6, col,
            M.get("roof_slate_blue"), (tx, ty, base + corpo + 0.6), n=8,
            phase=math.pi / 8)
    n += 1
    util.box("SM_igreja_cruz_v", 0.14, 0.14, 2.0, col, M.get("metal_rust_dark"),
             loc=(tx, ty, base + e["tower_h"] - 0.6))
    util.box("SM_igreja_cruz_h", 0.9, 0.12, 0.12, col, M.get("metal_rust_dark"),
             loc=(tx, ty, base + e["tower_h"] + 0.75), rot=(0, 0, ang))
    n += 2
    return n


# --------------------------------------------------------------- cemiterio
def build_cemiterio(col, e, hs, rng):
    cx, cy = e["center"]
    w, d = e["size"]
    z = hs.at(cx, cy)
    n = 0
    # muro de perimetro
    hw, hd = w / 2.0, d / 2.0
    cantos = [(cx - hw, cy - hd), (cx + hw, cy - hd), (cx + hw, cy + hd), (cx - hw, cy + hd)]
    for i in range(4):
        a, b = cantos[i], cantos[(i + 1) % 4]
        mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        util.box("SM_cem_muro%d" % i, L, 0.35, 2.2, col,
                 M.get("wall_stone_cemetery"), loc=(mx, my, hs.at(mx, my) - 0.1),
                 rot=(0, 0, math.atan2(b[1] - a[1], b[0] - a[0])))
        n += 1
    # chao de saibro
    util.box("SM_cem_chao", w - 0.7, d - 0.7, 0.10, col, M.get("dirt_road"),
             loc=(cx, cy, z))
    n += 1

    # capela com campanario
    c = e["chapel"]
    ccx, ccy = c["center"]; cw, cd = c["size"]
    cz = hs.at(ccx, ccy)
    util.box("SM_cem_capela", cw, cd, 8.5, col, M.get("wall_stone_cemetery"),
             loc=(ccx, ccy, cz))
    pyramid("SM_cem_capela_teto", max(cw, cd) * 0.62, 3.4, col,
            M.get("roof_slate_blue"), (ccx, ccy, cz + 8.5), n=4, phase=math.pi / 4)
    util.box("SM_cem_campanario", 2.4, 2.4, 5.0, col, M.get("wall_stone_cemetery"),
             loc=(ccx - cw / 2 + 1.6, ccy, cz + 8.5))
    pyramid("SM_cem_camp_teto", 1.9, 2.2, col, M.get("roof_slate_blue"),
            (ccx - cw / 2 + 1.6, ccy, cz + 13.5), n=4, phase=math.pi / 4)
    n += 4

    # mausoleu com frontao
    m = e["mausoleu"]
    mcx, mcy = m["center"]; mw, md = m["size"]
    mz = hs.at(mcx, mcy)
    util.box("SM_cem_mausoleu", mw, md, 7.0, col, M.get("wall_stone_cemetery"),
             loc=(mcx, mcy, mz))
    taper("SM_cem_cupula", max(mw, md) * 0.30, max(mw, md) * 0.10, 3.2, col,
          M.get("roof_slate_blue"), (mcx, mcy, mz + 7.0), n=12)
    n += 2

    # ciprestes e tumulos
    for k in range(14):
        x = cx + rng.uniform(-hw + 4, hw - 4)
        y = cy + rng.uniform(-hd + 4, hd - 4)
        if abs(x - ccx) < cw and abs(y - ccy) < cd:
            continue
        if rng.random() < 0.45:
            taper("SM_cem_cipreste%02d" % k, 1.5, 0.25, rng.uniform(6.0, 9.0), col,
                  M.get("cypress_dark"), (x, y, hs.at(x, y)), n=6)
        else:
            util.box("SM_cem_tumulo%02d" % k, rng.uniform(0.9, 1.6),
                     rng.uniform(1.8, 2.4), rng.uniform(0.5, 1.4), col,
                     M.get("wall_stone_cemetery"), loc=(x, y, hs.at(x, y)),
                     rot=(0, 0, rng.uniform(0, 3)))
        n += 1
    return n


# ------------------------------------------------------------------- praca
def build_praca(col, e, hs, rng):
    cx, cy = e["center"]
    R, Ri = e["radius"], e["island_radius"]
    z = hs.at(cx, cy)
    n = 0
    # calcamento da rotatoria (anel) e bordo do canteiro
    anel("SM_praca_pav", Ri, R, 0.06, col, M.get("cobble_base"), (cx, cy, z))
    anel("SM_praca_bordo", Ri - 0.25, Ri, 0.30, col, M.get("curb_granite"),
         (cx, cy, z))
    disc("SM_praca_ilha", Ri - 0.25, col, M.get("grass_dry"), (cx, cy, z + 0.28))
    n += 3

    # obelisco: base escalonada + fuste piramidal
    bh = e["base_h"]
    for k in range(3):
        s = 5.0 - k * 1.1
        util.box("SM_obelisco_base%d" % k, s, s, bh / 3.0, col,
                 M.get("wall_stone_church"), loc=(cx, cy, z + 0.28 + k * bh / 3.0))
        n += 1
    taper("SM_obelisco_fuste", 1.30, 0.42, e["obelisk_h"] * 0.92, col,
          M.get("wall_stone_church"), (cx, cy, z + 0.28 + bh), n=4,
          phase=math.pi / 4)
    pyramid("SM_obelisco_ponta", 0.42, e["obelisk_h"] * 0.14, col,
            M.get("wall_stone_church"),
            (cx, cy, z + 0.28 + bh + e["obelisk_h"] * 0.92), n=4, phase=math.pi / 4)
    n += 2

    # bancos e arbustos ao redor do canteiro
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.4
        bx, by = cx + math.cos(a) * (Ri - 2.4), cy + math.sin(a) * (Ri - 2.4)
        util.box("SM_praca_banco%d" % k, 1.9, 0.45, 0.45, col, M.get("wood_aged"),
                 loc=(bx, by, z + 0.28), rot=(0, 0, a + math.pi / 2))
        hx, hy = cx + math.cos(a + 0.4) * (Ri - 5.5), cy + math.sin(a + 0.4) * (Ri - 5.5)
        util.box("SM_praca_arbusto%d" % k, rng.uniform(1.2, 2.0),
                 rng.uniform(1.2, 2.0), rng.uniform(0.6, 1.1), col,
                 M.get("canopy_urban"), loc=(hx, hy, z + 0.28),
                 rot=(0, 0, rng.uniform(0, 3)))
        n += 2
    return n


# --------------------------------------------------------------------- ETE
def build_ete(col, e, hs, rng):
    cx, cy = e["center"]
    w, d = e["size"]
    z = hs.at(cx, cy)
    n = 0
    util.box("SM_ete_piso", w, d, 0.12, col, M.get("sidewalk_concrete"),
             loc=(cx, cy, z))
    n += 1

    for i, t in enumerate(e["tanks"]):
        tx, ty = t["center"]; r = t["radius"]
        tz = hs.at(tx, ty)
        anel("SM_ete_tanque%d" % i, r - 0.35, r, 3.5, col,
             M.get("sidewalk_concrete"), (tx, ty, tz + 0.8))
        disc("SM_ete_agua%d" % i, r - 0.35, col, M.get("gutter_grime"),
             (tx, ty, tz + 3.4))
        anel("SM_ete_saia%d" % i, r - 0.35, r, 0.8, col,
             M.get("sidewalk_concrete"), (tx, ty, tz))
        n += 3
        if i == 0:      # ponte de clarificador no tanque grande
            util.box("SM_ete_ponte", r * 2.1, 0.55, 0.30, col,
                     M.get("metal_rust_dark"), loc=(tx, ty, tz + 4.4),
                     rot=(0, 0, rng.uniform(0, 3)))
            taper("SM_ete_pivo", 0.45, 0.45, 2.0, col, M.get("metal_rust_dark"),
                  (tx, ty, tz + 4.3), n=8)
            n += 2

    # bacias retangulares e deck de madeira
    for k, (ox, oy, bw, bd) in enumerate(((14, 12, 16, 9), (16, -8, 14, 8))):
        bx, by = cx + ox, cy + oy
        util.box("SM_ete_bacia%d" % k, bw, bd, 1.6, col,
                 M.get("sidewalk_concrete"), loc=(bx, by, hs.at(bx, by)))
        util.box("SM_ete_bacia%d_agua" % k, bw - 0.7, bd - 0.7, 0.06, col,
                 M.get("gutter_grime"), loc=(bx, by, hs.at(bx, by) + 1.5))
        n += 2
    dx, dy = cx - 6, cy - 18
    util.box("SM_ete_deck", 22, 2.2, 0.16, col, M.get("wood_aged"),
             loc=(dx, dy, hs.at(dx, dy) + 0.9))
    n += 1

    # tubulacao aparente
    for k in range(5):
        px = cx - w / 2 + 6 + k * 8
        py = cy - d / 2 + 5
        taper("SM_ete_tubo%d" % k, 0.30, 0.30, rng.uniform(7.0, 13.0), col,
              M.get("metal_rust_dark"), (px, py, hs.at(px, py) + 0.9),
              n=8, rot=(math.radians(90), 0, rng.uniform(-0.3, 0.3)))
        n += 1

    # casa de bombas
    ux, uy = cx - w / 2 + 8, cy + d / 2 - 7
    util.box("SM_ete_casa", 7.5, 5.5, 3.0, col, M.get("wall_render_raw"),
             loc=(ux, uy, hs.at(ux, uy)))
    util.box("SM_ete_casa_teto", 8.4, 6.4, 0.18, col, M.get("roof_metal_zinc"),
             loc=(ux, uy, hs.at(ux, uy) + 3.0))
    n += 2

    # cerca de perimetro
    hw, hd = w / 2.0, d / 2.0
    cantos = [(cx - hw, cy - hd), (cx + hw, cy - hd), (cx + hw, cy + hd), (cx - hw, cy + hd)]
    for i in range(4):
        a, b = cantos[i], cantos[(i + 1) % 4]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        for s in [k * 2.5 for k in range(int(L / 2.5) + 1)]:
            px = a[0] + math.cos(ang) * s
            py = a[1] + math.sin(ang) * s
            util.box("SM_ete_poste_%d_%d" % (i, int(s)), 0.10, 0.10, 2.0, col,
                     M.get("metal_rust_dark"), loc=(px, py, hs.at(px, py)))
            n += 1
    return n


def build(parent, hs, pular=()):
    """`pular` lista marcos que serao substituidos por asset do usuario."""
    col = util.reset_collection(COL, parent)
    L = layout.load()["landmarks"]
    rng = random.Random(5150)
    r = {}
    if "igreja" not in pular:
        r["igreja"] = build_igreja(col, L["igreja_matriz"], hs)
    r["cemiterio"] = build_cemiterio(col, L["cemiterio"], hs, rng)
    if "praca" not in pular:
        r["praca"] = build_praca(col, L["praca_obelisco"], hs, rng)
    r["ete"] = build_ete(col, L["ete"], hs, rng)
    r["objetos"] = len(col.objects)
    return r
