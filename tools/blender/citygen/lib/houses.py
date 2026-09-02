"""Etapa 04 — casas PROXY. Descartaveis por projeto.

O que importa aqui e **massa e ritmo de telhado**, nao detalhe: cada casa e
um volume mais um telhado com a inclinacao certa do seu tipo. Toda casa deixa
um Empty `EMP_house_*` na origem da testada para voce trocar depois.
"""
import math
import random

from . import util, layout, materials as M

COL = "04_PROXY_BUILD"
TILE = 2.5

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


def build_casa(col, name, x, y, ang, larg, prof, tipo, rng, z0):
    """`ang` aponta da testada para dentro do lote."""
    nome, pav, incl, beiral, teto, _ = tipo
    h = PE_DIREITO[0] + (PE_DIREITO[1] if pav == 2 else 0.0)
    if nome == "ruina":
        h *= rng.uniform(0.45, 0.75)

    mat_par = M.get(rng.choice(PAREDES) if nome != "sobrado_comercial"
                    else rng.choice(("paint_shop_red", "paint_shop_ochre",
                                     "wall_whitewash")))
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

    if teto == "nenhum":                      # ruina: caibros expostos
        for k in range(4):
            t = -hw + (k + 1) * (larg / 5.0)
            a = _place(x, y, ang, -hd, t, z0 + h)
            b = _place(x, y, ang, hd, t, z0 + h + rng.uniform(0.1, 0.5))
            util.box("%s_caibro%d" % (name, k), 0.10, 0.10,
                     math.hypot(b[0] - a[0], b[1] - a[1]), col, M.get("wood_dark"),
                     loc=a, rot=(math.radians(88), 0, ang))
            n += 1
        return n, h

    # ---- telhado de duas aguas, cumeeira paralela a testada ----
    mat_teto = M.get(rng.choice(TELHAS if teto == "telha" else METAIS))
    e = beiral
    rise = (hd + e) * incl
    v, f = [], []
    eave = [_place(x, y, ang, sx * (hd + e), sy * (hw + e), z0 + h)
            for sx, sy in ((-1, -1), (-1, 1), (1, 1), (1, -1))]
    ridge = [_place(x, y, ang, 0.0, sy * (hw + e), z0 + h + rise)
             for sy in (-1, 1)]
    _quad(v, f, eave[0], eave[1], ridge[1], ridge[0])       # agua da frente
    _quad(v, f, ridge[0], ridge[1], eave[2], eave[3])       # agua dos fundos
    _tri(v, f, eave[0], ridge[0], eave[3])                  # oitao
    _tri(v, f, eave[1], eave[2], ridge[1])
    rob = util._mk(name + "_teto", v, f, col, mat_teto)
    uvl = rob.data.uv_layers.new(name="UVMap")
    for loop in rob.data.loops:
        p = rob.data.vertices[loop.vertex_index].co
        uvl.data[loop.index].uv = (math.hypot(p.x - x, p.y - y) / TILE,
                                   (p.z - z0 - h) / TILE + 0.5)
    n += 1

    if nome == "terrea_platibanda":           # platibanda escondendo o telhado
        for i in range(4):
            j = (i + 1) % 4
            a, b = top[i], top[j]
            mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            util.box("%s_plat%d" % (name, i), L, 0.14, 0.55, col, mat_par,
                     loc=(mx, my, z0 + h),
                     rot=(0, 0, math.atan2(b[1] - a[1], b[0] - a[0])))
            n += 1

    if nome == "sobrado_comercial":           # toldo sobre a loja
        a = _place(x, y, ang, -hd - 0.9, 0.0, z0 + 2.55)
        util.box("%s_toldo" % name, larg * 0.8, 1.8, 0.10, col,
                 M.get("paint_shop_red"), loc=a, rot=(math.radians(-8), 0, ang))
        n += 1

    # ---- extras caracteristicos ----
    if rng.random() < 0.35:                   # caixa d'agua
        a = _place(x, y, ang, rng.uniform(-0.3, 0.3) * hd, rng.uniform(-0.5, 0.5) * hw,
                   z0 + h + rise * 0.5)
        util.box("%s_caixa" % name, 1.0, 1.0, 0.85, col, M.get("roof_metal_zinc"),
                 loc=a, rot=(0, 0, rng.uniform(0, 3)))
        n += 1
    if rng.random() < 0.28:                   # antena
        a = _place(x, y, ang, 0.2 * hd, 0.4 * hw, z0 + h + rise)
        util.box("%s_antena" % name, 0.05, 0.05, rng.uniform(1.2, 2.0), col,
                 M.get("metal_rust_dark"), loc=a)
        n += 1

    # Empty de verdade: exporta como no glTF (Node3D no Godot), nao como malha
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
    col = util.reset_collection(COL, parent)
    data = layout.load()
    rng = random.Random(31415)
    casas = objs = 0
    # caixas para o oclusor do Godot: occlusion_culling esta ligado no projeto
    # e nao existe oclusor nenhum, entao hoje e custo puro sem beneficio.
    volumes = []

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
                nome = "SM_house_%s_%d_%02d" % (b["id"], e, casas)
                k, alt = build_casa(col, nome, hx, hy, ang, larg, prof, tipo,
                                    rng, plat)
                volumes.append({"x": round(hx, 2), "y": round(plat, 2),
                                "z": round(-hy, 2), "rot": round(-ang, 4),
                                "w": round(larg, 2), "d": round(prof, 2),
                                "h": round(alt, 2)})
                objs += k
                casas += 1
                s += larg + rng.uniform(0.3, 1.8)
    import json, os
    saida = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                         "out", "houses.json")
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    with open(saida, "w", encoding="utf-8") as fh:
        json.dump({"nota": "caixas em coordenadas LOCAIS do Godot para gerar "
                           "ArrayOccluder3D (x, y do piso, z, rot em Y, w, d, h)",
                   "casas": volumes}, fh)
    return {"casas": casas, "objetos": len(col.objects), "pecas": objs,
            "volumes_json": saida}
