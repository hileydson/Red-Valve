"""Etapa 06 — postes, fiação, placas e mobiliário.

A fiação é o que vende a estética da referência: três cabos por vão com
**flecha calculada** (ponto baixo a 6,0 m), não linhas retas. O feixe de
telecom recebe flecha maior e desalinho lateral, para não ficar paralelo.
"""
import json
import math
import os
import random

import mathutils

from . import util, layout, materials as M

COL = "06_STREET_FURN"

VAO = 32.0          # espaçamento entre postes
H_POSTE = 8.5
H_ARM = 8.25          # quase no topo do poste (8,50)
ARM_LEN = 0.80          # 1,60 e 1,15 ainda deixavam vao visivel
ARM_RISE = math.radians(15.0)
FLECHA_MIN = 6.0    # ponto mais baixo do cabo
TILT = math.radians(3.0)

CLASSES_COM_POSTE = ("avenida", "principal", "radial", "secundaria")


# ------------------------------------------------------------- primitivas
def _ring(cx, cy, cz, r, n, seed_rot=0.0):
    return [(cx + r * math.cos(2 * math.pi * i / n + seed_rot),
             cy + r * math.sin(2 * math.pi * i / n + seed_rot), cz)
            for i in range(n)]


def _tube_faces(rings, n, cap=False):
    f = []
    for k in range(len(rings) - 1):
        a, b = k * n, (k + 1) * n
        for i in range(n):
            j = (i + 1) % n
            f.append((a + i, a + j, b + j, b + i))
    if cap:
        f.append(tuple(range(n - 1, -1, -1)))
        f.append(tuple(range(len(rings) * n - n, len(rings) * n)))
    return f


def taper(name, r0, r1, h, col, mat, loc, rot, n=8):
    v = _ring(0, 0, 0, r0, n) + _ring(0, 0, h, r1, n)
    return util._mk(name, v, _tube_faces([0, 1], n, cap=True), col, mat, loc, rot)


def tube_path(name, pts, r, col, mat, n=6, loc=(0, 0, 0)):
    """Tubo seguindo uma polilinha 3D — usado nos cabos e no braço."""
    rings, verts = [], []
    for k, p in enumerate(pts):
        if k == 0:
            d = mathutils.Vector(pts[1]) - mathutils.Vector(p)
        elif k == len(pts) - 1:
            d = mathutils.Vector(p) - mathutils.Vector(pts[-2])
        else:
            d = mathutils.Vector(pts[k + 1]) - mathutils.Vector(pts[k - 1])
        d.normalize()
        up = mathutils.Vector((0, 0, 1))
        if abs(d.dot(up)) > 0.95:
            up = mathutils.Vector((1, 0, 0))
        s = d.cross(up).normalized()
        t = s.cross(d).normalized()
        base = mathutils.Vector(p)
        for i in range(n):
            a = 2 * math.pi * i / n
            verts.append(tuple(base + s * (r * math.cos(a)) + t * (r * math.sin(a))))
        rings.append(k)
    return util._mk(name, verts, _tube_faces(rings, n), col, mat, loc)


# ------------------------------------------------------------- colocação
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
    return out


def _poles_for_road(road, hs, rng):
    """Postes de um lado só, com inclinação aleatória de ±3°."""
    lado = 1 if (hash(road["id"]) & 1) else -1
    hw = road["width"] / 2.0
    off = hw + 0.75
    pts = _resample(road["points"], VAO)
    saida = []
    for k, (x, y) in enumerate(pts):
        if k == 0:
            dx, dy = pts[1][0] - x, pts[1][1] - y
        elif k == len(pts) - 1:
            dx, dy = x - pts[-2][0], y - pts[-2][1]
        else:
            dx, dy = pts[k + 1][0] - pts[k - 1][0], pts[k + 1][1] - pts[k - 1][1]
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L * lado, dx / L * lado
        px, py = x + nx * off, y + ny * off
        rx = rng.uniform(-TILT, TILT)
        ry = rng.uniform(-TILT, TILT)
        # o braço aponta para a pista (sentido -normal)
        ang = math.atan2(-ny, -nx)
        saida.append(dict(x=px, y=py, z=hs.at(px, py), rx=rx, ry=ry, ang=ang,
                          idx=k, road=road["id"]))
    return saida


def _world(p, local):
    """Ponto local do poste -> mundo, respeitando a inclinação."""
    R = mathutils.Euler((p["rx"], p["ry"], 0.0), "XYZ").to_matrix()
    v = R @ mathutils.Vector(local)
    return (p["x"] + v.x, p["y"] + v.y, p["z"] + v.z)


# ------------------------------------------------------------- construção
def build_pole(col, p, i):
    loc = (p["x"], p["y"], p["z"])
    rot = (p["rx"], p["ry"], 0.0)
    taper("SM_pole_%03d" % i, 0.145, 0.085, H_POSTE, col,
          M.get("curb_granite"), loc, rot)
    taper("SM_pole_collar_%03d" % i, 0.24, 0.20, 0.28, col,
          M.get("wall_render_raw"), loc, rot)

    # braço curvo: sobe 15° e projeta 1,60 m na direcao da pista
    ca, sa = math.cos(p["ang"]), math.sin(p["ang"])
    arm = []
    for t in (0.0, 0.35, 0.7, 1.0):
        L = ARM_LEN * t
        arm.append((ca * L, sa * L, H_ARM + math.sin(ARM_RISE) * L * (0.6 + 0.4 * t)))
    # braco mais grosso: a 4,5 cm ele sumia e a luminaria parecia solta
    ob = tube_path("SM_pole_arm_%03d" % i, arm, 0.065, col,
                   M.get("metal_rust_dark"), n=6)
    ob.location = loc
    ob.rotation_euler = rot

    # luminaria tipo cobra na ponta
    tip = arm[-1]
    # 0.08 em vez de 0.30: a luminaria encosta na ponta do braco
    lamp = util.box("SM_pole_lamp_%03d" % i, 0.70, 0.26, 0.17, col,
                    M.get("metal_rust_dark"),
                    loc=(tip[0] + ca * 0.08, tip[1] + sa * 0.08, tip[2] - 0.10),
                    rot=(0, 0, p["ang"]))
    lamp.parent = None
    # posiciona a luminaria no espaco do poste
    lm = mathutils.Euler(rot, "XYZ").to_matrix()
    lv = lm @ mathutils.Vector(lamp.location)
    lamp.location = (loc[0] + lv.x, loc[1] + lv.y, loc[2] + lv.z)
    lamp.rotation_euler = (rot[0], rot[1], p["ang"])
    return 4


def build_transformer(col, p, i):
    z = H_POSTE - 1.7
    c = _world(p, (0.30, 0.0, z))
    taper("SM_pole_trafo_%03d" % i, 0.30, 0.30, 0.78, col,
          M.get("metal_rust_dark"), c, (p["rx"], p["ry"], 0.0), n=10)
    return 1


def build_guy(col, p, i, rng):
    """Estai ancorado no chao a ~45°."""
    a = _world(p, (0.0, 0.0, H_POSTE - 1.1))
    ang = p["ang"] + math.pi + rng.uniform(-0.5, 0.5)
    d = (H_POSTE - 1.1) * 0.95
    b = (p["x"] + math.cos(ang) * d, p["y"] + math.sin(ang) * d, p["z"])
    tube_path("SM_pole_guy_%03d" % i, [a, b], 0.022, col, M.get("wood_dark"), n=4)
    return 1


def build_cables(col, a, b, i, rng):
    """Tres cabos por vao com flecha real: forca tenso, telecom barrigudo."""
    n = 0
    # (dz do ponto de fixacao, raio, flecha em metros)
    # A flecha e absoluta, NAO derivada do Z do mundo: o Z inclui a cota do
    # terreno, e usa-lo faria a barriga crescer com a altitude do poste.
    espec = ((0.00, 0.030, 0.80),    # forca: triplex, mais tenso
             (-0.16, 0.020, 1.30),   # telecom
             (-0.30, 0.016, 1.70))   # telecom com sobra
    for k, (dz, r, fmul) in enumerate(espec):
        p0 = _world(a, (0.0, 0.0, H_ARM + dz))
        p1 = _world(b, (0.0, 0.0, H_ARM + dz))
        vao = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        flecha = fmul * min(1.0, vao / VAO)   # vao curto, barriga menor
        lat = rng.uniform(-0.10, 0.10) if k else 0.0
        pts = []
        for s in range(9):
            t = s / 8.0
            x = p0[0] + (p1[0] - p0[0]) * t
            y = p0[1] + (p1[1] - p0[1]) * t
            z = p0[2] + (p1[2] - p0[2]) * t - 4.0 * flecha * t * (1 - t)
            pts.append((x + lat * math.sin(t * math.pi),
                        y + lat * math.cos(t * math.pi), z))
        tube_path("SM_cable_%03d_%d" % (i, k), pts, r, col, M.get("wood_dark"), n=4)
        n += 1
    return n


def build_signs(col, poles_by_road, signs, hs):
    """Chapa esmaltada 0,42 x 0,14 m a 2,3 m, com UV na celula do atlas."""
    mat = M.get("sign_plate")
    n = 0
    for rid, plist in poles_by_road.items():
        info = signs["plates"].get(rid)
        if info is None or not plist:
            continue
        u0, v0, du, dv = info["uv"]
        for p in plist[::7]:
            ca, sa = math.cos(p["ang"]), math.sin(p["ang"])
            base = _world(p, (0.0, 0.0, 2.30))
            w, h = 0.42, 0.14
            px, py = -sa, ca                       # ao longo da via
            verts = [
                (base[0] - px * w / 2 + ca * 0.16, base[1] - py * w / 2 + sa * 0.16, base[2] - h / 2),
                (base[0] + px * w / 2 + ca * 0.16, base[1] + py * w / 2 + sa * 0.16, base[2] - h / 2),
                (base[0] + px * w / 2 + ca * 0.16, base[1] + py * w / 2 + sa * 0.16, base[2] + h / 2),
                (base[0] - px * w / 2 + ca * 0.16, base[1] - py * w / 2 + sa * 0.16, base[2] + h / 2)]
            ob = util._mk("SM_sign_%s_%02d" % (rid, n), verts, [(0, 1, 2, 3)], col, mat)
            me = ob.data
            uvl = me.uv_layers.new(name="UVMap")
            uvs = [(u0, v0 + dv), (u0 + du, v0 + dv), (u0 + du, v0), (u0, v0)]
            for loop in me.loops:
                uvl.data[loop.index].uv = uvs[loop.vertex_index]
            n += 1
    return n


def build_debris(col, hs, rng):
    """Tambores, pneus e caixotes junto as quadras."""
    data = layout.load()
    n = 0
    for b in data["blocks"]:
        poly = b["poly"]
        for _ in range(rng.randint(1, 3)):
            i = rng.randrange(len(poly))
            x0, y0 = poly[i]
            x1, y1 = poly[(i + 1) % len(poly)]
            t = rng.uniform(0.15, 0.85)
            x = x0 + (x1 - x0) * t + rng.uniform(-1.2, 1.2)
            y = y0 + (y1 - y0) * t + rng.uniform(-1.2, 1.2)
            z = hs.at(x, y)
            kind = rng.random()
            if kind < 0.35:
                taper("SM_debris_barrel_%03d" % n, 0.28, 0.28, 0.86, col,
                      M.get("metal_rust_dark"), (x, y, z),
                      (rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 0), n=8)
            elif kind < 0.65:
                taper("SM_debris_tire_%03d" % n, 0.33, 0.33, 0.18, col,
                      M.get("wood_dark"), (x, y, z), (0, 0, rng.uniform(0, 3)), n=10)
            else:
                s = rng.uniform(0.4, 0.7)
                util.box("SM_debris_crate_%03d" % n, s, s * 0.8, s * 0.7, col,
                         M.get("wood_aged"), loc=(x, y, z),
                         rot=(0, 0, rng.uniform(0, 3)))
            n += 1
    return n


def build(parent, hs):
    col = util.reset_collection(COL, parent)
    data = layout.load()
    rng = random.Random(20240601)
    # posicao da luminaria de cada poste, para o Godot criar as luzes
    luzes = []

    sp = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                      "city_data", "signs.json")
    signs = {"plates": {}}
    if os.path.exists(sp):
        with open(sp, "r", encoding="utf-8") as fh:
            signs = json.load(fh)

    poles_by_road, total_p, total_c, i = {}, 0, 0, 0
    for road in data["roads"]:
        if road["class"] not in CLASSES_COM_POSTE:
            continue
        plist = _poles_for_road(road, hs, rng)
        poles_by_road[road["id"]] = plist
        for k, p in enumerate(plist):
            build_pole(col, p, i)
            # ponta do braco, em coordenadas LOCAIS do Godot (x, y, -y_blender)
            ca, sa = math.cos(p["ang"]), math.sin(p["ang"])
            tipx = ca * (ARM_LEN + 0.08)
            tipy = sa * (ARM_LEN + 0.08)
            lz = H_ARM + math.sin(ARM_RISE) * ARM_LEN - 0.18
            wx, wy, wz = _world(p, (tipx, tipy, lz))
            luzes.append({"x": round(wx, 2), "y": round(wz, 2), "z": round(-wy, 2),
                          "rot": round(-p["ang"], 4)})
            if i % 6 == 0:
                build_transformer(col, p, i)
            if k == 0 or k == len(plist) - 1:
                build_guy(col, p, i, rng)
            if k + 1 < len(plist):
                total_c += build_cables(col, p, plist[k + 1], i, rng)
            i += 1
            total_p += 1

    n_sign = build_signs(col, poles_by_road, signs, hs)
    n_deb = build_debris(col, hs, rng)
    saida = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                         "out", "poles.json")
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    with open(saida, "w", encoding="utf-8") as fh:
        json.dump({"nota": "luminarias em coordenadas LOCAIS do Godot; "
                           "rot e o giro em Y do braco",
                   "luzes": luzes}, fh)
    return {"postes": total_p, "cabos": total_c, "placas": n_sign,
            "detritos": n_deb, "objetos": len(col.objects), "luzes_json": saida}
