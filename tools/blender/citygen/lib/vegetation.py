"""Etapa 07 — kit de vegetacao e pontos de espalhamento.

O Blender NAO assa a floresta: entrega o *kit* de arvores mais um
`scatter.json` com as transformacoes. Quem instancia e o Godot, via
MultiMeshInstance3D (1 draw call por especie, memoria minima).

Trocar por outra arvore depois e so apontar o `mesh` do MultiMesh para
outra malha — inclusive as BIRCH/SPRUCE que ja existem no projeto.
"""
import json
import math
import os
import random

from . import util, layout, materials as M

COL = "07_VEGETATION"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "out")


def _ring(cx, cy, cz, r, n, ph=0.0):
    return [(cx + r * math.cos(2 * math.pi * i / n + ph),
             cy + r * math.sin(2 * math.pi * i / n + ph), cz) for i in range(n)]


def _cone(verts, faces, cx, cy, z0, r, h, n=6, ph=0.0):
    i0 = len(verts)
    verts.extend(_ring(cx, cy, z0, r, n, ph))
    verts.append((cx, cy, z0 + h))
    for i in range(n):
        faces.append((i0 + i, i0 + (i + 1) % n, i0 + n))
    faces.append(tuple(range(i0 + n - 1, i0 - 1, -1)))


def _drum(verts, faces, cx, cy, z0, r0, r1, h, n=6, ph=0.0):
    i0 = len(verts)
    verts.extend(_ring(cx, cy, z0, r0, n, ph))
    verts.extend(_ring(cx, cy, z0 + h, r1, n, ph))
    for i in range(n):
        j = (i + 1) % n
        faces.append((i0 + i, i0 + j, i0 + n + j, i0 + n + i))
    faces.append(tuple(range(i0 + n - 1, i0 - 1, -1)))
    faces.append(tuple(range(i0 + n, i0 + 2 * n)))


def _kit_arvore(col, nome, tronco_h, tronco_r, camadas, mat_copa, mat_tronco):
    """Arvore de baixa contagem: tronco + camadas de copa."""
    v, f = [], []
    _drum(v, f, 0, 0, 0, tronco_r, tronco_r * 0.72, tronco_h, n=5)
    for (z, r, h, n) in camadas:
        _cone(v, f, 0, 0, z, r, h, n=n, ph=z * 0.7)
    ob = util._mk(nome, v, f, col, mat_copa)
    # tronco e copa no mesmo objeto: material unico, mas o tronco fica escuro
    # o suficiente na paleta de copa para nao incomodar num proxy de floresta
    return ob


def _kit_folhosa(col, nome, tronco_h, tronco_r, camadas, mat_copa):
    """Copa arredondada: tambores sobrepostos, silhueta irregular."""
    v, f = [], []
    _drum(v, f, 0, 0, 0, tronco_r, tronco_r * 0.70, tronco_h, n=5)
    for (z, r0, r1, h, n, dx) in camadas:
        _drum(v, f, dx, 0, z, r0, r1, h, n=n, ph=z * 0.9)
    return util._mk(nome, v, f, col, mat_copa)


def build_kit(col):
    """Cinco especies. Contagem baixa de proposito: sao instanciadas aos milhares."""
    feitos = {}
    feitos["TREE_forest"] = _kit_arvore(
        col, "TREE_forest", 7.0, 0.36,
        [(5.5, 3.4, 7.0, 6), (9.0, 2.6, 6.0, 6), (12.5, 1.7, 5.0, 5)],
        M.get("canopy_forest"), M.get("wood_dark"))
    # folhosa: quebra a fileira de cones identicos no horizonte
    feitos["TREE_forest_broad"] = _kit_folhosa(
        col, "TREE_forest_broad", 6.0, 0.40,
        [(4.6, 2.4, 4.4, 3.4, 7, 0.0), (7.4, 4.4, 3.8, 3.2, 7, 0.5),
         (10.2, 3.6, 1.4, 2.6, 6, -0.4)],
        M.get("canopy_forest_dark"))
    feitos["TREE_urban"] = _kit_arvore(
        col, "TREE_urban", 2.8, 0.30,
        [(2.4, 3.9, 3.6, 7), (4.2, 3.2, 3.0, 6)],
        M.get("canopy_urban"), M.get("wood_dark"))
    feitos["TREE_cypress"] = _kit_arvore(
        col, "TREE_cypress", 1.2, 0.22,
        [(0.9, 1.25, 7.2, 6)],
        M.get("cypress_dark"), M.get("wood_dark"))
    v, f = [], []
    _cone(v, f, 0, 0, 0, 0.85, 1.25, n=6)
    feitos["BUSH"] = util._mk("BUSH", v, f, col, M.get("canopy_urban"))
    v, f = [], []
    _cone(v, f, 0, 0, 0, 0.45, 0.60, n=5)
    feitos["WEED"] = util._mk("WEED", v, f, col, M.get("grass_dry"))
    feitos.update(_kit_lod(col))
    return feitos


def _kit_lod(col):
    """Silhuetas de longe. A mata do anel externo ocupa poucos pixels na tela:
    o que sobrevive a essa distancia e o contorno, nao o tronco nem as camadas
    de copa. Uma arvore de floresta cai de 44 para 6 triangulos, a folhosa de
    84 para 12 — e as duas juntas sao 10.772 das 14.513 plantas do mapa."""
    feitos = {}

    # conica: um unico cone do chao ao topo, mesma altura e raio maximo da
    # LOD0 para que a troca nao mude a silhueta contra o ceu.
    v, f = [], []
    _cone(v, f, 0, 0, 0.0, 3.4, 17.5, n=4)
    feitos["TREE_forest_LOD"] = util._mk(
        "TREE_forest_LOD", v, f, col, M.get("canopy_forest"))

    # folhosa: tambor unico cobrindo as tres camadas, com um toco de tronco.
    v, f = [], []
    _drum(v, f, 0, 0, 0.0, 0.40, 0.34, 4.6, n=3)
    _drum(v, f, 0, 0, 4.6, 3.6, 2.2, 8.2, n=4)
    feitos["TREE_forest_broad_LOD"] = util._mk(
        "TREE_forest_broad_LOD", v, f, col, M.get("canopy_forest_dark"))

    v, f = [], []
    _cone(v, f, 0, 0, 0, 0.85, 1.25, n=3)
    feitos["BUSH_LOD"] = util._mk("BUSH_LOD", v, f, col, M.get("canopy_urban"))
    return feitos


# ------------------------------------------------------------ espalhamento
def extensao_construida(data, folga=26.0):
    """Bounding box do que existe de fato — quadras e marcos — nao o retangulo
    nominal dos limites. Usar `bounds` deixava ~100 m de terra nua entre a
    ultima casa e a mata."""
    xs, ys = [], []
    for b in data["blocks"]:
        for x, y in b["poly"]:
            xs.append(float(x)); ys.append(float(y))
    for e in data["landmarks"].values():
        cx, cy = e["center"]
        if e.get("type") == "circle":
            r = e["radius"]
            xs += [cx - r, cx + r]; ys += [cy - r, cy + r]
        else:
            w, d = e.get("size", (20, 20))
            xs += [cx - w / 2, cx + w / 2]; ys += [cy - d / 2, cy + d / 2]
    for r in data["roads"]:
        if r["class"] in ("avenida", "principal"):
            for x, y in r["points"]:
                xs.append(x); ys.append(y)
    return {"min": [min(xs) - folga, min(ys) - folga],
            "max": [max(xs) + folga, max(ys) + folga]}


def _fora_da_cidade(px, py, b, margem):
    return not (b["min"][0] - margem < px < b["max"][0] + margem
                and b["min"][1] - margem < py < b["max"][1] + margem)


def _dist_estrada(px, py, grid, cell):
    ci, cj = int(math.floor(px / cell)), int(math.floor(py / cell))
    melhor = 1e9
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            for ox, oy in grid.get((ci + di, cj + dj), ()):
                d = (ox - px) ** 2 + (oy - py) ** 2
                if d < melhor:
                    melhor = d
    return math.sqrt(melhor)


def scatter(hs, rng):
    data = layout.load()
    w = data["world"]
    b = extensao_construida(data)
    margem_interna = float(data["bounds"].get("forest_inner_margin", 18.0))
    cx0, cz0 = w["import_corner"]
    W, H = w["import_size"]
    ox, oz = w["origin_x"], w["origin_z"]

    # grade das vias, para nao plantar arvore em cima da rua
    cell = 24.0
    grid = {}
    for r in data["roads"]:
        for x, y in r["points"]:
            grid.setdefault((int(math.floor(x / cell)), int(math.floor(y / cell))),
                            []).append((x, y))

    pts = {"TREE_forest": [], "TREE_forest_broad": [], "TREE_urban": [],
           "TREE_cypress": [], "BUSH": [], "WEED": []}

    # ---- anel de mata: borda interna irregular, densidade crescente ----
    passo = 7.0
    px = cx0 - ox
    n_i = int(W / passo)
    n_j = int(H / passo)
    for j in range(n_j):
        for i in range(n_i):
            gx = cx0 + (i + rng.random()) * passo
            gz = cz0 + (j + rng.random()) * passo
            lx, ly = gx - ox, oz - gz
            if not _fora_da_cidade(lx, ly, b, margem_interna):
                continue
            # borda irregular: distancia ao retangulo da cidade + ruido
            dx = max(b["min"][0] - lx, 0.0, lx - b["max"][0])
            dy = max(b["min"][1] - ly, 0.0, ly - b["max"][1])
            d = math.hypot(dx, dy)
            ruido = 20.0 * math.sin(lx * 0.021 + 1.3) * math.cos(ly * 0.017 - 0.4)
            limiar = 12.0 + ruido
            if d < limiar:
                continue
            dens = min(1.0, (d - limiar) / 55.0)
            if rng.random() > dens * 0.82:
                continue
            especie = "TREE_forest" if rng.random() < 0.46 else "TREE_forest_broad"
            pts[especie].append(
                (round(lx, 2), round(hs.at(lx, ly), 2), round(-ly, 2),
                 round(rng.uniform(0, 6.283), 3), round(rng.uniform(0.78, 1.40), 3)))
            if rng.random() < 0.30:
                bx, by = lx + rng.uniform(-3, 3), ly + rng.uniform(-3, 3)
                pts["BUSH"].append(
                    (round(bx, 2), round(hs.at(bx, by), 2), round(-by, 2),
                     round(rng.uniform(0, 6.283), 3), round(rng.uniform(0.7, 1.5), 3)))

    # ---- arvores urbanas: praca, lotes baldios e beira de via ----
    L = data["landmarks"]
    pcx, pcy = L["praca_obelisco"]["center"]
    for k in range(9):
        a = 2 * math.pi * k / 9 + 0.7
        r = L["praca_obelisco"]["island_radius"] - 3.2
        lx, ly = pcx + math.cos(a) * r, pcy + math.sin(a) * r
        pts["TREE_urban"].append((round(lx, 2), round(hs.at(lx, ly) + 0.3, 2),
                                  round(-ly, 2), round(rng.uniform(0, 6.283), 3),
                                  round(rng.uniform(0.85, 1.2), 3)))

    for blk in data["blocks"]:
        poly = [(float(x), float(y)) for x, y in blk["poly"]]
        bcx = sum(p[0] for p in poly) / len(poly)
        bcy = sum(p[1] for p in poly) / len(poly)
        for k in range(rng.randint(0, 3)):
            lx = bcx + rng.uniform(-14, 14)
            ly = bcy + rng.uniform(-14, 14)
            pts["TREE_urban"].append((round(lx, 2), round(hs.at(lx, ly), 2),
                                      round(-ly, 2), round(rng.uniform(0, 6.283), 3),
                                      round(rng.uniform(0.7, 1.15), 3)))
        for k in range(rng.randint(4, 10)):
            i = rng.randrange(len(poly))
            x0, y0 = poly[i]
            x1, y1 = poly[(i + 1) % len(poly)]
            t = rng.random()
            lx = x0 + (x1 - x0) * t + rng.uniform(-1.0, 1.0)
            ly = y0 + (y1 - y0) * t + rng.uniform(-1.0, 1.0)
            pts["WEED"].append((round(lx, 2), round(hs.at(lx, ly), 2), round(-ly, 2),
                                round(rng.uniform(0, 6.283), 3),
                                round(rng.uniform(0.6, 1.4), 3)))

    # ---- ciprestes no cemiterio ----
    cem = L["cemiterio"]
    ccx, ccy = cem["center"]; cw, cd = cem["size"]
    for k in range(16):
        lx = ccx + rng.uniform(-cw / 2 + 5, cw / 2 - 5)
        ly = ccy + rng.uniform(-cd / 2 + 5, cd / 2 - 5)
        pts["TREE_cypress"].append((round(lx, 2), round(hs.at(lx, ly), 2),
                                    round(-ly, 2), round(rng.uniform(0, 6.283), 3),
                                    round(rng.uniform(0.8, 1.3), 3)))

    # ---- mato ao longo das vias, fora da pista ----
    for r in data["roads"]:
        hw = r["width"] / 2.0
        for k in range(0, len(r["points"]), 3):
            lx, ly = r["points"][k]
            for lado in (-1, 1):
                if rng.random() > 0.35:
                    continue
                off = hw + rng.uniform(1.8, 4.5)
                ang = rng.uniform(0, 6.283)
                wx = lx + math.cos(ang) * off
                wy = ly + math.sin(ang) * off
                if _dist_estrada(wx, wy, grid, cell) < hw + 1.2:
                    continue
                pts["WEED"].append((round(wx, 2), round(hs.at(wx, wy), 2),
                                    round(-wy, 2), round(rng.uniform(0, 6.283), 3),
                                    round(rng.uniform(0.5, 1.2), 3)))
    return pts


def build(parent, hs):
    col = util.reset_collection(COL, parent)
    rng = random.Random(90210)
    kit = build_kit(col)
    pts = scatter(hs, rng)

    os.makedirs(OUT, exist_ok=True)
    caminho = os.path.join(OUT, "scatter.json")
    with open(caminho, "w", encoding="utf-8") as fh:
        json.dump({"nota": "posicoes LOCAIS da cidade (x, y, z, rot_y, escala); o no City aplica o deslocamento para o mundo",
                   "especies": {k: v for k, v in pts.items()}}, fh)
    return {"kit": sorted(kit), "pontos": {k: len(v) for k, v in pts.items()},
            "total": sum(len(v) for v in pts.values()), "json": caminho}
