"""Etapa 04 — casas PROXY. Descartaveis por projeto.

O que importa aqui e **massa e ritmo de telhado**, nao detalhe: cada casa e
um volume mais um telhado com a inclinacao certa do seu tipo. Toda casa deixa
um Empty `EMP_house_*` na origem da testada para voce trocar depois.
"""
import json
import math
import random

from . import util, layout, materials as M

COL = "04_PROXY_BUILD"
TILE = 2.5

# Vagas reservadas para asset do usuario: a casa proxy nao e construida ali,
# e a vaga (posicao, angulo, tamanho) volta no resultado para o Godot
# encaixar o modelo exatamente onde a casa estaria.
# Coordenadas em MUNDO LOCAL do Godot (x, z), raio em metros.
RESERVADOS = [
    ("oficina_jimmy", 48.0, 196.0, 13.0),
    ("casa_nice",     59.5, 188.1,  2.5),
    ("casa_maycow",    5.6,  76.5,  2.0),
]

PAREDES = ("wall_whitewash", "wall_render_raw", "wall_brick",
           "wall_whitewash_hi", "paint_shop_ochre")
TELHAS = ("roof_tile_faded", "roof_tile_warm", "roof_tile_bleached")
METAIS = ("roof_metal_rust", "roof_metal_zinc")

# tipo -> (pavimentos, inclinacao, beiral, material de telhado, peso)
TIPOS = (
    ("terrea_colonial",  1, 0.30, 0.60, "telha",  30),
    ("terrea_metalica",  1, 0.15, 0.35, "metal",  22),
    ("terrea_platibanda", 1, 0.12, 0.05, "metal", 14),
    ("sobrado",          2, 0.30, 0.55, "telha",  16),
    ("sobrado_comercial", 2, 0.25, 0.40, "telha",  10),
    ("ruina",            1, 0.00, 0.00, "nenhum",  8),
)
PE_DIREITO = (2.80, 2.60)

# Folga minima entre a testada da casa e a borda do asfalto. O degrau da
# porta avanca 0,56 m alem da parede, e ainda tem meio-fio e calcada: com
# menos que isto o degrau e o peitoril aparecem *em cima* da pista, que era
# de onde vinham as lajes cinzas soltas no asfalto.
MARGEM_VIA = 1.60

# Se nenhuma casa cair no raio nominal de uma vaga reservada, ela fica com a
# vizinha mais próxima até esta distância.
RAIO_SOCORRO = 15.0


def _pick(rng):
    tot = sum(t[5] for t in TIPOS)
    r = rng.random() * tot
    for t in TIPOS:
        r -= t[5]
        if r <= 0:
            return t
    return TIPOS[0]


def _quad(verts, faces, a, b, c, d):
    n = len(verts)
    verts.extend([a, b, c, d])
    faces.append((n, n + 1, n + 2, n + 3))


def _tri(verts, faces, a, b, c):
    n = len(verts)
    verts.extend([a, b, c])
    faces.append((n, n + 1, n + 2))


def _place(x, y, ang, lx, ly, lz):
    """Local (lx frente/fundo, ly transversal, lz altura) -> mundo."""
    ca, sa = math.cos(ang), math.sin(ang)
    return (x + lx * ca - ly * sa, y + lx * sa + ly * ca, lz)


def _caixa_local(col, name, x, y, ang, cx, cy, cz, sx, sy, sz, mat):
    """Caixa no espaco da casa: cx ao longo da profundidade, cy da testada."""
    p = _place(x, y, ang, cx, cy, cz)
    return util.box(name, sx, sy, sz, col, mat, loc=p, rot=(0, 0, ang), base=False)


def _face_abertura(lado, hw, hd, pos, larg, fora, esp):
    """Caixa colada na face da parede.

    `fora` e o quanto ela avanca para FORA da face; `esp` a espessura. A
    versao anterior centrava a caixa 6 cm para DENTRO do volume: como a casa
    e um bloco solido, e nao uma casca, o vao ficava inteiramente engolido
    pela parede e nao aparecia nada — nem porta, nem janela.
    """
    if lado == "frente":
        return (-hd - fora + esp / 2.0, pos, esp, larg)
    if lado == "esq":
        return (pos, -hw - fora + esp / 2.0, larg, esp)
    return (pos, hw + fora - esp / 2.0, larg, esp)


def _abertura(col, name, x, y, ang, lado, pos, z0, larg, alt, hw, hd, mats):
    """Vao escuro saliente, com verga em cima e peitoril embaixo.

    `lado`: 'frente' | 'esq' | 'dir'. Nao abre buraco de verdade na malha —
    o vao e um painel escuro 2 cm a frente da parede, e a verga e o peitoril,
    que avancam mais que ele, dao a sombra que le como profundidade. Sao 36
    triangulos por janela, contra centenas de um boolean.

    Ja errei isto duas vezes: primeiro afundando o painel 6 cm DENTRO do
    volume solido da casa, onde ele sumia por completo; depois envolvendo-o
    num requadro solido, que o tapava pela frente. O painel tem de ser a
    peca mais externa da abertura.
    """
    n = 0
    cx, cy, sx, sy = _face_abertura(lado, hw, hd, pos, larg, 0.02, 0.10)
    _caixa_local(col, name + "_vao", x, y, ang, cx, cy, z0 + alt / 2.0,
                 sx, sy, alt, mats["vao"])
    n += 1
    # verga
    cx, cy, sx, sy = _face_abertura(lado, hw, hd, pos, larg + 0.24, 0.07, 0.17)
    _caixa_local(col, name + "_verga", x, y, ang, cx, cy, z0 + alt + 0.06,
                 sx, sy, 0.12, mats["peitoril"])
    n += 1
    # peitoril: so em janela (porta comeca no chao)
    if z0 > 0.35:
        cx, cy, sx, sy = _face_abertura(lado, hw, hd, pos, larg + 0.24,
                                        0.09, 0.20)
        _caixa_local(col, name + "_peit", x, y, ang, cx, cy, z0 - 0.05,
                     sx, sy, 0.10, mats["peitoril"])
        n += 1
    return n


def build_casa(col, name, x, y, ang, larg, prof, tipo, rng, z0):
    """`ang` aponta da testada para dentro do lote."""
    nome, pav, incl, beiral, teto, _ = tipo
    h = PE_DIREITO[0] + (PE_DIREITO[1] if pav == 2 else 0.0)
    if nome == "ruina":
        h *= rng.uniform(0.45, 0.75)

    mat_par = M.get(rng.choice(PAREDES) if nome != "sobrado_comercial"
                    else rng.choice(("paint_shop_red", "paint_shop_ochre",
                                     "wall_whitewash")))
    mats = {"vao": M.get("vao_escuro"), "peitoril": M.get("sidewalk_concrete"),
            "barra": M.get("barra_pintada"), "madeira": M.get("wood_aged"),
            "metal": M.get("metal_rust_dark")}
    hw, hd = larg / 2.0, prof / 2.0

    # ---- caixa das paredes ----
    v, f = [], []
    c = [_place(x, y, ang, sx * hd, sy * hw, 0.0)
         for sx, sy in ((-1, -1), (-1, 1), (1, 1), (1, -1))]
    top = [(p[0], p[1], z0 + h) for p in c]
    bot = [(p[0], p[1], z0) for p in c]
    for i in range(4):
        j = (i + 1) % 4
        _quad(v, f, bot[i], bot[j], top[j], top[i])
    _quad(v, f, top[3], top[2], top[1], top[0])
    ob = util._mk(name, v, f, col, mat_par)
    uvl = ob.data.uv_layers.new(name="UVMap")
    for loop in ob.data.loops:
        p = ob.data.vertices[loop.vertex_index].co
        uvl.data[loop.index].uv = (math.hypot(p.x - x, p.y - y) / TILE,
                                   (p.z - z0) / TILE)
    n = 1

    if nome == "ruina":
        for k in range(4):
            t = -hw + (k + 1) * (larg / 5.0)
            a = _place(x, y, ang, -hd, t, z0 + h)
            b = _place(x, y, ang, hd, t, z0 + h + rng.uniform(0.1, 0.5))
            util.box("%s_caibro%d" % (name, k), 0.10, 0.10,
                     math.hypot(b[0] - a[0], b[1] - a[1]), col, M.get("wood_dark"),
                     loc=a, rot=(math.radians(88), 0, ang))
            n += 1
        return n, h

    # ---- embasamento e barra pintada ----
    if rng.random() < 0.65:
        _caixa_local(col, name + "_base", x, y, ang, 0, 0, z0 + 0.18,
                     prof + 0.16, larg + 0.16, 0.36, mats["barra"])
        n += 1
    if rng.random() < 0.45:
        alt_b = rng.uniform(0.9, 1.4)
        _caixa_local(col, name + "_barra", x, y, ang, 0, 0, z0 + alt_b / 2.0,
                     prof + 0.05, larg + 0.05, alt_b, mats["barra"])
        n += 1

    # ---- porta na testada, com degrau ----
    porta_y = rng.uniform(-hw * 0.55, hw * 0.55)
    n += _abertura(col, name + "_porta", x, y, ang, "frente", porta_y, z0 + 0.02,
                   rng.uniform(0.85, 1.05), 2.10, hw, hd, mats)
    _caixa_local(col, name + "_degrau", x, y, ang, -hd - 0.28, porta_y,
                 z0 + 0.08, 0.55, 1.35, 0.16, mats["peitoril"])
    n += 1

    # ---- janelas: testada recebe mais, laterais menos, fundo nenhuma ----
    def livre(p, larg_j):
        return abs(p - porta_y) > (larg_j / 2.0 + 0.75)

    for k in range(rng.randint(1, 2 if larg < 8.0 else 3)):
        lj = rng.uniform(1.0, 1.5)
        for _ in range(8):
            py_ = rng.uniform(-hw + lj / 2 + 0.4, hw - lj / 2 - 0.4)
            if livre(py_, lj):
                n += _abertura(col, "%s_jf%d" % (name, k), x, y, ang, "frente",
                               py_, z0 + 1.05, lj, 1.25, hw, hd, mats)
                break
    for lado in ("esq", "dir"):
        if rng.random() < 0.55:
            lj = rng.uniform(0.9, 1.3)
            px_ = rng.uniform(-hd + lj, hd - lj)
            n += _abertura(col, "%s_j%s" % (name, lado), x, y, ang, lado,
                           px_, z0 + 1.05, lj, 1.20, hw, hd, mats)

    # segundo pavimento
    if pav == 2:
        for k in range(rng.randint(1, 3)):
            lj = rng.uniform(0.9, 1.3)
            py_ = rng.uniform(-hw + lj, hw - lj)
            n += _abertura(col, "%s_j2_%d" % (name, k), x, y, ang, "frente",
                           py_, z0 + PE_DIREITO[0] + 0.95, lj, 1.15, hw, hd, mats)

    # ---- telhado de duas aguas ----
    mat_teto = M.get(rng.choice(TELHAS if teto == "telha" else METAIS))
    e = beiral
    rise = (hd + e) * incl
    v, f = [], []
    eave = [_place(x, y, ang, sx * (hd + e), sy * (hw + e), z0 + h)
            for sx, sy in ((-1, -1), (-1, 1), (1, 1), (1, -1))]
    ridge = [_place(x, y, ang, 0.0, sy * (hw + e), z0 + h + rise)
             for sy in (-1, 1)]
    _quad(v, f, eave[0], eave[1], ridge[1], ridge[0])
    _quad(v, f, ridge[0], ridge[1], eave[2], eave[3])
    _tri(v, f, eave[0], ridge[0], eave[3])
    _tri(v, f, eave[1], eave[2], ridge[1])
    rob = util._mk(name + "_teto", v, f, col, mat_teto)
    util.faces_up(rob)
    uvl = rob.data.uv_layers.new(name="UVMap")
    for loop in rob.data.loops:
        p = rob.data.vertices[loop.vertex_index].co
        uvl.data[loop.index].uv = (math.hypot(p.x - x, p.y - y) / TILE,
                                   (p.z - z0 - h) / TILE + 0.5)
    n += 1

    # cumeeira
    _caixa_local(col, name + "_cumeeira", x, y, ang, 0, 0,
                 z0 + h + rise + 0.06, 0.34, larg + 2 * e, 0.16, mat_teto)
    n += 1
    # testeira e calha nos dois beirais
    for s_ in (-1, 1):
        _caixa_local(col, name + "_testeira%d" % (s_ + 1), x, y, ang,
                     s_ * (hd + e), 0, z0 + h - 0.09, 0.07, larg + 2 * e,
                     0.22, mats["madeira"])
        _caixa_local(col, name + "_calha%d" % (s_ + 1), x, y, ang,
                     s_ * (hd + e + 0.07), 0, z0 + h - 0.14, 0.11, larg + 2 * e,
                     0.11, mats["metal"])
        n += 2
    # condutor vertical num canto
    _caixa_local(col, name + "_condutor", x, y, ang, -hd - 0.07,
                 (hw - 0.2) * rng.choice((-1, 1)), z0 + h / 2.0,
                 0.09, 0.09, h, mats["metal"])
    n += 1

    if nome == "terrea_platibanda":
        for i in range(4):
            j = (i + 1) % 4
            a, b = top[i], top[j]
            mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            util.box("%s_plat%d" % (name, i), L, 0.14, 0.62, col, mat_par,
                     loc=(mx, my, z0 + h),
                     rot=(0, 0, math.atan2(b[1] - a[1], b[0] - a[0])))
            n += 1

    if nome == "sobrado_comercial":
        a = _place(x, y, ang, -hd - 0.9, 0.0, z0 + 2.55)
        util.box("%s_toldo" % name, larg * 0.8, 1.8, 0.10, col,
                 M.get("paint_shop_red"), loc=a, rot=(math.radians(-8), 0, ang))
        # letreiro sobre a loja
        _caixa_local(col, name + "_letreiro", x, y, ang, -hd - 0.06, 0,
                     z0 + 3.05, 0.10, larg * 0.75, 0.55, mats["madeira"])
        n += 2

    # ---- extras caracteristicos ----
    if rng.random() < 0.35:
        a = _place(x, y, ang, rng.uniform(-0.3, 0.3) * hd,
                   rng.uniform(-0.5, 0.5) * hw, z0 + h + rise * 0.5)
        util.box("%s_caixa" % name, 1.0, 1.0, 0.85, col, M.get("roof_metal_zinc"),
                 loc=a, rot=(0, 0, rng.uniform(0, 3)))
        n += 1
    if rng.random() < 0.28:
        a = _place(x, y, ang, 0.2 * hd, 0.4 * hw, z0 + h + rise)
        util.box("%s_antena" % name, 0.05, 0.05, rng.uniform(1.2, 2.0), col,
                 mats["metal"], loc=a)
        n += 1

    import bpy
    emp = bpy.data.objects.new("EMP_house_" + name.replace("SM_house_", ""), None)
    emp.empty_display_type = "PLAIN_AXES"
    emp.empty_display_size = 0.6
    emp.location = _place(x, y, ang, -hd, 0, z0)
    emp.rotation_euler = (0.0, 0.0, ang)
    emp["citygen_tipo"] = nome
    emp["citygen_largura"] = larg
    emp["citygen_profundidade"] = prof
    col.objects.link(emp)
    return n, h + rise


def build(parent, hs):
    """Duas passadas: primeiro decide ONDE, depois constrói.

    A separação existe por causa das vagas reservadas. Quando a reserva era
    resolvida no meio da construção, ela dependia de um sorteio cair dentro
    de um raio de 2,5 m — e bastou eu recuar as casas da pista para a vaga
    da Sra Nice desaparecer. Com a passada de posicionamento isolada, a
    reserva vira "a casa mais próxima deste ponto", que não depende de sorte.
    """
    col = util.reset_collection(COL, parent)
    data = layout.load()
    rng = random.Random(31415)
    vias = layout.grade_vias(data)
    recuadas = empurradas = 0

    # ---------------------------------------------------- passada 1: onde
    cand = []
    for b in data["blocks"]:
        poly = [(float(x), float(y)) for x, y in b["poly"]]
        plat = max(hs.at(x, y) for x, y in poly) + 0.12
        cx = sum(p[0] for p in poly) / len(poly)
        cy = sum(p[1] for p in poly) / len(poly)

        for e in range(len(poly)):
            a, bb = poly[e], poly[(e + 1) % len(poly)]
            L = math.hypot(bb[0] - a[0], bb[1] - a[1])
            if L < 8.0:
                continue
            dx, dy = (bb[0] - a[0]) / L, (bb[1] - a[1]) / L
            # normal apontando para dentro da quadra
            nx, ny = -dy, dx
            if (cx - a[0]) * nx + (cy - a[1]) * ny < 0:
                nx, ny = -nx, -ny
            ang = math.atan2(ny, nx)

            s = rng.uniform(0.5, 2.0)
            while s < L - 6.0:
                larg = rng.uniform(6.0, 10.0)
                if s + larg > L - 1.0:
                    break
                prof = rng.uniform(8.0, 13.0)
                tipo = _pick(rng)
                mid = s + larg / 2.0
                # recuo pequeno: a casa quase encosta na divisa
                rec = rng.uniform(0.4, 1.6)
                hx = a[0] + dx * mid + nx * (prof / 2.0 + rec)
                hy = a[1] + dy * mid + ny * (prof / 2.0 + rec)
                passo = s + larg + rng.uniform(0.3, 1.8)

                # a quadra é desenhada sem consultar as vias, então a divisa
                # às vezes cai dentro do asfalto. Recua a casa até a testada
                # ficar livre; se não houver quadra suficiente, não constrói.
                recuado = 0.0
                while recuado <= 7.0:
                    livre = True
                    for lat in (-larg / 2.0 + 0.3, 0.0, larg / 2.0 - 0.3):
                        fx = hx - nx * (prof / 2.0) + dx * lat
                        fy = hy - ny * (prof / 2.0) + dy * lat
                        if layout.folga_via(vias, fx, fy) < MARGEM_VIA:
                            livre = False
                            break
                    if livre:
                        break
                    hx += nx * 0.5
                    hy += ny * 0.5
                    recuado += 0.5
                s = passo
                if recuado > 7.0:
                    empurradas += 1
                    continue
                if recuado > 0.0:
                    recuadas += 1
                cand.append({"bid": b["id"], "e": e, "x": hx, "y": hy,
                             "ang": ang, "larg": larg, "prof": prof,
                             "tipo": tipo, "plat": plat})

    # ------------------------------------------- reservas: a mais próxima
    vagas = {}
    tomados = set()
    for tag, rx, rz, raio in RESERVADOS:
        dists = sorted(
            ((math.hypot(c["x"] - rx, -c["y"] - rz), i)
             for i, c in enumerate(cand) if i not in tomados))
        escolhidos = [i for d, i in dists if d <= raio]
        if not escolhidos and dists and dists[0][0] <= RAIO_SOCORRO:
            # nenhuma casa caiu no raio nominal: fica com a vizinha mais
            # próxima, para a vaga nunca sumir por causa do sorteio.
            escolhidos = [dists[0][1]]
        for i in escolhidos:
            tomados.add(i)
            c = cand[i]
            vagas.setdefault(tag, []).append(
                {"x": round(c["x"], 2), "y": round(c["plat"], 2),
                 "z": round(-c["y"], 2), "rot": round(-c["ang"], 4),
                 "w": round(c["larg"], 2), "d": round(c["prof"], 2)})

    # ------------------------------------------------- passada 2: construir
    casas = objs = 0
    volumes = []
    for i, c in enumerate(cand):
        if i in tomados:
            continue
        nome = "SM_house_%s_%d_%02d" % (c["bid"], c["e"], casas)
        k, alt = build_casa(col, nome, c["x"], c["y"], c["ang"],
                            c["larg"], c["prof"], c["tipo"], rng, c["plat"])
        volumes.append({"x": round(c["x"], 2), "y": round(c["plat"], 2),
                        "z": round(-c["y"], 2), "rot": round(-c["ang"], 4),
                        "w": round(c["larg"], 2), "d": round(c["prof"], 2),
                        "h": round(alt, 2)})
        objs += k
        casas += 1

    import os
    saida = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                         "out", "houses.json")
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    with open(saida, "w", encoding="utf-8") as fh:
        json.dump({"nota": "caixas em coordenadas LOCAIS do Godot para gerar "
                           "ArrayOccluder3D (x, y do piso, z, rot em Y, w, d, h)",
                   "casas": volumes, "vagas_reservadas": vagas}, fh)
    return {"casas": casas, "objetos": len(col.objects), "pecas": objs,
            "volumes_json": saida, "recuadas_da_via": recuadas,
            "descartadas_na_via": empurradas,
            "vagas": {k: len(v) for k, v in vagas.items()}}
