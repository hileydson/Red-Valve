"""Gera layout.json — a fonte de verdade da cidade.

Coordenadas locais em metros, origem no centro da Praça do Obelisco,
+X = leste, +Y = norte (convenção da planta, docs/plano-cidade-blender.md §2).

Os blocos vêm das mesmas coordenadas do diagrama da planta publicada:
  wx = sx - 400 ; wy = 200 - sy
"""
import json, math, os

# ----------------------------------------------------------------- util
def catmull(pts, n=8):
    """Amostra uma Catmull-Rom pelos pontos de controle -> polilinha suave."""
    if len(pts) < 3:
        return [tuple(map(float, p)) for p in pts]
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(len(P) - 3):
        p0, p1, p2, p3 = P[i], P[i+1], P[i+2], P[i+3]
        for s in range(n):
            t = s / float(n); t2, t3 = t*t, t*t*t
            out.append((
                0.5*((2*p1[0]) + (-p0[0]+p2[0])*t + (2*p0[0]-5*p1[0]+4*p2[0]-p3[0])*t2 + (-p0[0]+3*p1[0]-3*p2[0]+p3[0])*t3),
                0.5*((2*p1[1]) + (-p0[1]+p2[1])*t + (2*p0[1]-5*p1[1]+4*p2[1]-p3[1])*t2 + (-p0[1]+3*p1[1]-3*p2[1]+p3[1])*t3)))
    out.append(tuple(map(float, pts[-1])))
    return [(round(x, 2), round(y, 2)) for x, y in out]


def blk(sx, sy, w, h, rot):
    """Retângulo de quadra vindo das coordenadas do diagrama da planta."""
    cx, cy = sx + w/2.0, sy + h/2.0
    wx, wy = cx - 400.0, 200.0 - cy
    return {"center": [round(wx, 1), round(wy, 1)],
            "size": [float(w), float(h)], "rotation": float(-rot)}



def seg_isect(a, b, c, d):
    """Intersecao de dois segmentos, ou None."""
    x1,y1 = a; x2,y2 = b; x3,y3 = c; x4,y4 = d
    den = (x1-x2)*(y3-y4) - (y1-y2)*(x3-x4)
    if abs(den) < 1e-9:
        return None
    t = ((x1-x3)*(y3-y4) - (y1-y3)*(x3-x4)) / den
    u = ((x1-x3)*(y1-y2) - (y1-y3)*(x1-x2)) / den
    if 0.0 <= t <= 1.0 and 0.0 <= u <= 1.0:
        return (x1 + t*(x2-x1), y1 + t*(y2-y1))
    return None


def poly_isect(p1, p2):
    """Primeira intersecao entre duas polilinhas."""
    for a, b in zip(p1, p1[1:]):
        for c, d in zip(p2, p2[1:]):
            r = seg_isect(a, b, c, d)
            if r:
                return r
    return None


def sinuous(x0, x1, y, amp, phase, n=9, vertical=False):
    """Rua levemente sinuosa entre dois extremos."""
    pts = []
    for k in range(n):
        t = k / float(n - 1)
        a = x0 + (x1 - x0) * t
        off = amp * math.sin(t * math.pi * 1.7 + phase)
        pts.append((y + off, a) if vertical else (a, y + off))
    return pts


def pt_in_poly(pt, poly):
    x, y = pt; inside = False
    n = len(poly); j = n - 1
    for i in range(n):
        xi, yi = poly[i]; xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj-xi)*(y-yi)/((yj-yi) or 1e-9) + xi:
            inside = not inside
        j = i
    return inside


def inset_quad(q, d):
    """Encolhe um quadrilatero em direcao ao centroide."""
    cx = sum(p[0] for p in q) / 4.0
    cy = sum(p[1] for p in q) / 4.0
    out = []
    for x, y in q:
        vx, vy = cx - x, cy - y
        L = math.hypot(vx, vy) or 1.0
        f = min(d / L, 0.42)
        out.append((round(x + vx*f, 1), round(y + vy*f, 1)))
    return out

# ----------------------------------------------------------------- vias
RAW_ROADS = [
 ("av_padre_gabriel", "Av. Padre Gabriel de Melo", "avenida", 10.0, True,
  [(-260,-245), (-150,-238), (-20,-250), (100,-238), (210,-215)]),
 ("r_padre_gabriel", "R. Padre Gabriel de Melo", "principal", 8.5, True,
  [(110,-238), (170,-216), (216,-188), (250,-160)]),
 ("r_margarida", "R. Margarida Maria Alves", "principal", 8.0, True,
  [(-320,25), (-245,-8), (-165,-40), (-85,-70), (10,-110)]),
 ("r_eustaquia", "R. Eustáquia Portela", "principal", 8.5, True,
  [(60,75), (78,18), (106,-32), (142,-98), (185,-175)]),
 ("r_terra_velha", "R. Terra Velha", "secundaria", 6.0, True,
  [(-330,90), (-320,28), (-331,-32), (-314,-92), (-300,-140)]),
 ("r_obelisco", "R. do Obelisco", "radial", 7.0, True,
  [(0,19), (3,62), (-3,104), (0,140)]),
 ("r_pobre", "R. do Pobre", "secundaria", 4.5, True,
  [(20,-190), (39,-219), (55,-250)]),
 ("tv_bica", "Tv. da Bica", "travessa", 3.5, True,
  [(-95,-52), (-70,-105), (-52,-160)]),
 ("beco_esgoto", "Beco do Esgoto", "beco", 2.8, True,
  [(-150,-196), (-152,-215), (-148,-232)]),
 ("eixo_comercial", "R. do Comércio", "principal", 7.5, True,
  [(30,-40), (72,-84), (114,-130), (150,-175)]),
 # braços radiais da praça
 ("radial_leste", "", "radial", 7.0, False, [(19,1), (44,6), (62,12)]),
 ("radial_oeste", "", "radial", 7.0, False, [(-19,2), (-48,10), (-66,14)]),
 ("radial_sudoeste", "", "radial", 6.5, False, [(-14,-13), (-42,-38), (-62,-58)]),
 ("radial_sudeste", "", "radial", 6.5, False, [(14,-13), (26,-30), (32,-42)]),
 # malha do miolo — gera as quadras por intersecao (ver GRID abaixo)
]

roads = []
for rid, name, cls, w, named, pts in RAW_ROADS:
    roads.append({"id": rid, "name": name, "class": cls, "width": w,
                  "named": named, "points": catmull(pts)})

# ------------------------------------------------- malha do miolo e quadras
# Ruas levemente sinuosas: como elas curvam, as celulas entre elas saem
# irregulares por construcao — e o tecido deixa de parecer loteamento.
# 8 x 8 linhas cobrindo quase todo o nucleo: a malha antiga so ocupava 43%
# da area util, deixando terra nua entre a cidade e a mata.
H_LINES = [("g_h0", 130, 5.0, 5.5, 2.8), ("g_h1",  76, 5.5, 6.0, 0.4),
           ("g_h2",  22, 5.5, 7.0, 1.9), ("g_h3", -32, 5.5, 5.5, 3.1),
           ("g_h4", -86, 5.0, 6.5, 0.9), ("g_h5",-140, 5.0, 5.0, 2.4),
           ("g_h6",-194, 5.0, 5.5, 1.2), ("g_h7",-246, 4.5, 4.5, 3.6)]
V_LINES = [("g_v0",-152, 5.0, 7.0, 1.1), ("g_v1", -96, 4.5, 5.5, 2.7),
           ("g_v2", -40, 4.5, 6.5, 0.6), ("g_v3",  16, 4.5, 5.5, 3.3),
           ("g_v4",  72, 4.5, 5.0, 1.6), ("g_v5", 128, 4.5, 6.0, 2.2),
           ("g_v6", 184, 4.0, 4.5, 0.8), ("g_v7", 236, 4.0, 5.0, 2.0)]

grid_h, grid_v = [], []
for rid, y, w, amp, ph in H_LINES:
    pts = sinuous(-178, 262, y, amp, ph)
    grid_h.append((rid, w, pts))
    roads.append({"id": rid, "name": "", "class": "secundaria", "width": w,
                  "named": False, "points": catmull(pts, 5)})
for rid, x, w, amp, ph in V_LINES:
    pts = sinuous(152, -268, x, amp, ph, vertical=True)
    grid_v.append((rid, w, pts))
    roads.append({"id": rid, "name": "", "class": "secundaria", "width": w,
                  "named": False, "points": catmull(pts, 5)})

# nos da malha
NODE = {}
for hi, (hid, hw, hp) in enumerate(grid_h):
    for vi, (vid, vw, vp) in enumerate(grid_v):
        r = poly_isect(hp, vp)
        if r:
            NODE[(hi, vi)] = r

# zonas ocupadas por marcos — celulas que caem nelas sao descartadas
KEEP_OUT = [((0, 0), 34), ((-72, 34), 30), ((-233, 1), 90), ((-150, -230), 55)]

COMERCIAL = [(66, -78), (100, -116), (132, -152)]

blocks = []
for hi in range(len(grid_h) - 1):
    for vi in range(len(grid_v) - 1):
        q = [NODE.get((hi, vi)), NODE.get((hi, vi + 1)),
             NODE.get((hi + 1, vi + 1)), NODE.get((hi + 1, vi))]
        if any(p is None for p in q):
            continue
        cx = sum(p[0] for p in q) / 4.0
        cy = sum(p[1] for p in q) / 4.0
        if any(math.hypot(cx - kx, cy - ky) < kr for (kx, ky), kr in KEEP_OUT):
            continue
        # so descarta se o eixo principal BISSECTA a celula (passa perto do centro);
        # se apenas raspa um canto, a quadra sobrevive — via antiga cortando a malha
        rad = max(math.hypot(px - cx, py - cy) for px, py in q)
        cut = False
        for r in roads:
            if r["class"] not in ("principal", "avenida"):
                continue
            if any(math.hypot(px - cx, py - cy) < rad * 0.34 for px, py in r["points"]):
                cut = True; break
        if cut:
            continue
        # nao colidir com as quadras do eixo comercial
        if any(math.hypot(cx - mx, cy - my) < 42 for mx, my in COMERCIAL):
            continue
        inset = (grid_h[hi][1] + grid_v[vi][1]) / 2.0 + 1.6
        blocks.append({"id": "q%02d" % len(blocks), "poly": inset_quad(q, inset)})

# quadras do eixo comercial (fora da malha ortogonal)
for i, (cx, cy) in enumerate(COMERCIAL):
    a = 37
    r = math.radians(a); ca, sa = math.cos(r), math.sin(r)
    q = []
    for ox, oy in ((-24,-16), (24,-16), (24,16), (-24,16)):
        q.append((round(cx + ox*ca - oy*sa, 1), round(cy + ox*sa + oy*ca, 1)))
    blocks.append({"id": "qc%d" % i, "poly": q})

# ----------------------------------------------------------------- marcos
landmarks = {
 "praca_obelisco": {"type": "circle", "center": [0, 0], "radius": 19.0,
                    "island_radius": 11.0, "obelisk_h": 9.5, "base_h": 2.4},
 "igreja_matriz":  {"type": "rect", "center": [-72, 34], "size": [13, 32],
                    "rotation": 34.0, "tower_h": 31.0, "ridge_h": 16.0, "adro_h": 0.9},
 "cemiterio":      {"type": "compound", "center": [-233, 1], "size": [134, 106],
                    "chapel": {"center": [-258, 19], "size": [44, 30]},
                    "mausoleu": {"center": [-209, -24], "size": [38, 28]}},
 "ete":            {"type": "rect", "center": [-150, -230], "size": [72, 56],
                    "tanks": [{"center": [-165, -220], "radius": 8.5},
                              {"center": [-136, -222], "radius": 7.0}]},
}

# ----------------------------------------------------------------- terreno
terrain = {
 "note": "as ruas geram o terreno; estes sao os controles da forma base",
 "base_plane": {"h0": 8.0, "slope_north": 0.022, "slope_east": -0.012},
 "features": [
   {"kind": "raise", "center": [-150, 10],  "radius": 185, "amount": 3.2,
    "note": "patamar da igreja e do cemiterio"},
   {"kind": "lower", "center": [-150, -230], "radius": 80,  "amount": 2.6,
    "note": "cota baixa da ETE"},
   {"kind": "raise", "center": [0, 0],      "radius": 55,  "amount": 1.1,
    "note": "leve elevacao da praca"},
 ],
 "noise": {"amplitude": 2.1, "wavelength": 130.0, "octaves": 4, "seed": 4271},
 # janela longa = a rua segura a rampa por ~120 m e corta o relevo,
 # em vez de acompanhar cada ondulacao (corte e aterro de verdade)
 "road_grading": {"shoulder": 9.0, "smooth_window": 61},
}

# ----------------------------------------------------------------- limites
bounds = {"min": [-340, -280], "max": [260, 140],
          "forest_inner_margin": 18.0, "forest_radius": 900.0}

anchors = {
 "EMP_jimmy_house":  [48, -196],
 "EMP_ete_entrance": [-150, -198],
 "EMP_valve_door_01": [-168, -206], "EMP_valve_door_02": [-140, -244],
 "EMP_valve_door_03": [96, -118],   "EMP_valve_door_04": [186, -214],
}

# O terreno cobre bem mais que a cidade: o anel de mata precisa de chao.
# Z fica sempre <= 0 para NAO sobrescrever as 4 regioes originais do stage_1,
# que ocupam Z 0..512.
_REG = [[rx, ry] for ry in (-3, -2, -1) for rx in range(5)]
world = {
 "note": "colocacao no Godot: X = origin_x + px ; Z = origin_z - py",
 "origin_x": 640.0, "origin_z": -280.0,
 "region_size": 256, "vertex_spacing": 1.0,
 "regions": _REG,
 "import_corner": [0.0, -768.0], "import_size": [1280, 768],
}

data = {"_meta": {"unit": "meters", "origin": "Praca do Obelisco",
                  "axes": "+X leste, +Y norte", "gerado_por": "city_data/make_layout.py"},
        "world": world, "bounds": bounds, "terrain": terrain,
        "roads": roads, "blocks": blocks, "landmarks": landmarks, "anchors": anchors}

here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "layout.json"), "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=1, ensure_ascii=False)

print("layout.json: %d vias (%d nomeadas), %d quadras, %d marcos, %d ancoras" % (
    len(roads), sum(1 for r in roads if r["named"]), len(blocks), len(landmarks), len(anchors)))
print("pontos de polilinha no total:", sum(len(r["points"]) for r in roads))
