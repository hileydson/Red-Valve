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
    # O antigo `WEED` era um cone de 5 lados com 60 cm: de perto lia como um
    # triangulo de plastico espetado na grama, e havia 438 deles espalhados
    # por toda a cidade. A grama ja esta na textura do terreno; tufo de mato
    # so vale a pena com cartao de folhagem, que e outra conversa.
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

    # n=5 e nao n=3: com tres lados o arbusto vira um triangulo chapado
    # quando visto de frente, que e exatamente o defeito que eu queria evitar.
    v, f = [], []
    _cone(v, f, 0, 0, 0, 0.85, 1.25, n=5)
    feitos["BUSH_LOD"] = util._mk("BUSH_LOD", v, f, col, M.get("canopy_urban"))
    return feitos


# ------------------------------------------------------------ clareiras
# Retangulos onde NAO se planta, em MUNDO LOCAL do Godot (x0, z0, x1, z1) — o
# mesmo sistema das vagas de `houses.py`.
#
# Existem porque ha' predio encaixado a mao na stage_1 DEPOIS desta cidade. A
# escola foi parar na faixa de mata a leste: sem isto nascem 25 arvores e 5
# arbustos dentro do lote dela, atravessando o telhado e o patio.
#
# O corte e' feito no FIM de `scatter()`, e nao dentro do laco, de proposito:
# assim o sorteio continua consumindo o `rng` na mesma ordem e abrir uma
# clareira nao move uma arvore que seja no resto do mapa.
CLAREIRAS = [
    ("escola", 242.9, -157.5, 333.9, -77.5),
]


# ------------------------------------------------------------ mata do sul
# O terreno da stage_1 tem duas fileiras de regioes a mais ao SUL da area
# importada (Z do Godot de 0 a 512): e' onde fica o comeco do prologo (a casa
# do Maycow, os postes do caminho). O anel acima so' cobre a area importada,
# entao as laterais dessa faixa ficavam de terra nua. Aqui elas viram mata,
# com a mesma borda irregular e a mesma densidade crescente do anel, deixando
# livre a faixa jogavel do meio (onde passa o navmesh do prologo).
#
# Sorteio PROPRIO (SEMENTE_SUL): somar esta mata nao move nenhuma planta do
# resto do mapa. Coordenadas em MUNDO do Godot; o terreno ali e' plano em
# y = 0 (o heightfield do Blender nao vai ate' la' e extrapolaria).
SEMENTE_SUL = 90211
SUL_Z = (0.5, 512.0)
SUL_X = (0.0, 1280.0)
# a faixa jogavel do prologo (navmesh de x 256 a 768) com folga
SUL_LIVRE_X = (240.0, 785.0)
# e o FUNDO dela, atras da casa do Maycow: depois das paredes de bloqueio do
# prologo (z ~482) o terreno acaba em 512, e sem mata ali a faixa abria pro
# vazio. Ninguem chega la' andando.
SUL_FUNDO_Z = 490.0


def _mata_sul(pts, w, b, margem_interna):
    rng = random.Random(SEMENTE_SUL)
    ox, oz = w["origin_x"], w["origin_z"]
    passo = 7.0
    n_i = int((SUL_X[1] - SUL_X[0]) / passo)
    n_j = int((SUL_Z[1] - SUL_Z[0]) / passo)
    for j in range(n_j):
        for i in range(n_i):
            gx = SUL_X[0] + (i + rng.random()) * passo
            gz = SUL_Z[0] + (j + rng.random()) * passo
            lx, ly = gx - ox, oz - gz
            if not _fora_da_cidade(lx, ly, b, margem_interna):
                continue
            d = max(SUL_LIVRE_X[0] - gx, 0.0, gx - SUL_LIVRE_X[1])
            ruido = 12.0 * math.sin(gz * 0.023 + 0.8) * math.cos(gx * 0.019 - 1.1)
            limiar = 14.0 + ruido
            fundo = gz - SUL_FUNDO_Z - 3.0 * math.sin(gx * 0.05)
            if d < limiar and fundo < 0.0:
                continue
            dens = 1.0 if fundo >= 0.0 else min(1.0, (d - limiar) / 55.0)
            if rng.random() > dens * 0.82:
                continue
            especie = "TREE_forest" if rng.random() < 0.46 else "TREE_forest_broad"
            pts[especie].append(
                (round(lx, 2), 0.0, round(-ly, 2),
                 round(rng.uniform(0, 6.283), 3), round(rng.uniform(0.78, 1.40), 3)))
            if rng.random() < 0.30:
                bx, bz = gx + rng.uniform(-3, 3), gz + rng.uniform(-3, 3)
                # fora do terreno ele ficaria pendurado no vazio
                if SUL_Z[0] <= bz <= SUL_Z[1] and SUL_X[0] <= bx <= SUL_X[1]:
                    pts["BUSH"].append(
                        (round(bx - ox, 2), 0.0, round(bz - oz, 2),
                         round(rng.uniform(0, 6.283), 3), round(rng.uniform(0.7, 1.5), 3)))


# ------------------------------------------------------------ mata do meio
# O MEIO da faixa sul (SUL_LIVRE_X) tambem vira mata, entre os pinheiros
# grandes do prologo — so' que abrindo clareira em volta do que e' pisavel ou
# esta' em pe' ali: o navmesh da stage_1, a casa do Maycow, os postes, a faixa
# de grama e os proprios pinheiros (`city_data/area_prologo.json`, tirado da
# cena por `extrair_area_prologo.py`). A mata engrossa com a distancia a isso.
#
# Sorteio PROPRIO (SEMENTE_MEIO): nao mexe na mata das laterais.
SEMENTE_MEIO = 90212
AREA_PROLOGO = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                            "city_data", "area_prologo.json")
MEIO_FOLGA = 6.0       # nada a menos disto do navmesh / das pecas
MEIO_RAMPA = 30.0      # ate' a mata fechar


def _dist_segmento(px, pz, ax, az, bx, bz):
    vx, vz = bx - ax, bz - az
    t = ((px - ax) * vx + (pz - az) * vz) / ((vx * vx + vz * vz) or 1e-9)
    t = max(0.0, min(1.0, t))
    return math.hypot(px - (ax + t * vx), pz - (az + t * vz))


def _dist_triangulo(px, pz, t):
    ax, az, bx, bz, cx, cz = t
    d1 = (px - bx) * (az - bz) - (ax - bx) * (pz - bz)
    d2 = (px - cx) * (bz - cz) - (bx - cx) * (pz - cz)
    d3 = (px - ax) * (cz - az) - (cx - ax) * (pz - az)
    neg = d1 < 0 or d2 < 0 or d3 < 0
    pos = d1 > 0 or d2 > 0 or d3 > 0
    if not (neg and pos):
        return 0.0
    return min(_dist_segmento(px, pz, ax, az, bx, bz),
               _dist_segmento(px, pz, bx, bz, cx, cz),
               _dist_segmento(px, pz, cx, cz, ax, az))


def _mata_meio(pts, w, b, margem_interna):
    if not os.path.exists(AREA_PROLOGO):
        return
    area = json.load(open(AREA_PROLOGO, encoding="utf-8"))
    alcance = MEIO_FOLGA + MEIO_RAMPA
    # grade espacial dos triangulos (celula de 16 m)
    cel = 16.0
    grade = {}
    for t in area["triangulos"]:
        xs, zs = t[0::2], t[1::2]
        for ci in range(int(math.floor((min(xs) - alcance) / cel)), int(math.floor((max(xs) + alcance) / cel)) + 1):
            for cj in range(int(math.floor((min(zs) - alcance) / cel)), int(math.floor((max(zs) + alcance) / cel)) + 1):
                grade.setdefault((ci, cj), []).append(t)

    def distancia(x, z):
        d = alcance
        for t in grade.get((int(math.floor(x / cel)), int(math.floor(z / cel))), ()):
            d = min(d, _dist_triangulo(x, z, t))
            if d <= 0.0:
                return 0.0
        for cx, cz, raio in area["circulos"]:
            d = min(d, max(math.hypot(x - cx, z - cz) - raio, 0.0))
        for x0, z0, x1, z1 in area["retangulos"]:
            d = min(d, math.hypot(max(x0 - x, 0.0, x - x1), max(z0 - z, 0.0, z - z1)))
        return d

    rng = random.Random(SEMENTE_MEIO)
    ox, oz = w["origin_x"], w["origin_z"]
    passo = 7.0
    for j in range(int((SUL_FUNDO_Z - SUL_Z[0]) / passo)):
        for i in range(int((SUL_LIVRE_X[1] - SUL_LIVRE_X[0]) / passo)):
            gx = SUL_LIVRE_X[0] + (i + rng.random()) * passo
            gz = SUL_Z[0] + (j + rng.random()) * passo
            sorte = rng.random()
            especie = "TREE_forest" if rng.random() < 0.46 else "TREE_forest_broad"
            giro, escala = rng.uniform(0, 6.283), rng.uniform(0.78, 1.40)
            arbusto = rng.random() < 0.30
            bx, bz = gx + rng.uniform(-3, 3), gz + rng.uniform(-3, 3)
            bgiro, bescala = rng.uniform(0, 6.283), rng.uniform(0.7, 1.5)
            if not _fora_da_cidade(gx - ox, oz - gz, b, margem_interna):
                continue
            d = distancia(gx, gz)
            if d < MEIO_FOLGA:
                continue
            dens = min(1.0, (d - MEIO_FOLGA) / MEIO_RAMPA)
            if sorte > dens * 0.82:
                continue
            pts[especie].append((round(gx - ox, 2), 0.0, round(gz - oz, 2),
                                 round(giro, 3), round(escala, 3)))
            if arbusto and distancia(bx, bz) >= MEIO_FOLGA:
                pts["BUSH"].append((round(bx - ox, 2), 0.0, round(bz - oz, 2),
                                    round(bgiro, 3), round(bescala, 3)))


def _abrir_clareiras(pts):
    def livre(p):
        for _tag, x0, z0, x1, z1 in CLAREIRAS:
            if x0 <= p[0] <= x1 and z0 <= p[2] <= z1:
                return False
        return True
    return {k: [p for p in v if livre(p)] for k, v in pts.items()}


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
           "TREE_cypress": [], "BUSH": []}

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

    # ---- ciprestes no cemiterio ----
    cem = L["cemiterio"]
    ccx, ccy = cem["center"]; cw, cd = cem["size"]
    for k in range(16):
        lx = ccx + rng.uniform(-cw / 2 + 5, cw / 2 - 5)
        ly = ccy + rng.uniform(-cd / 2 + 5, cd / 2 - 5)
        pts["TREE_cypress"].append((round(lx, 2), round(hs.at(lx, ly), 2),
                                    round(-ly, 2), round(rng.uniform(0, 6.283), 3),
                                    round(rng.uniform(0.8, 1.3), 3)))

    _mata_sul(pts, w, b, margem_interna)
    _mata_meio(pts, w, b, margem_interna)
    return _abrir_clareiras(pts)


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
