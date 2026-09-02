"""Etapa 01 — malha esquemática para conferência da planta.

Não é geometria final: é o traçado projetado no terreno derivado, para você
aprovar a implantação antes da Etapa 02 gastar esforço em acabamento.
"""
import math

import numpy as np

from . import util, layout, materials as M

COL = "01_TERRAIN"
COL_CTX = "03_BLOCKS"

_ROAD_MAT = {"avenida": "cobble_base", "principal": "cobble_base",
             "radial": "cobble_polish", "secundaria": "dirt_road",
             "travessa": "dirt_road", "beco": "gutter_grime"}


class Height(object):
    """Amostrador bilinear do campo de altura, em coordenadas locais."""

    def __init__(self, h, world):
        self.h = h
        self.H, self.W = h.shape
        self.cx0, self.cz0 = world["import_corner"]
        self.ox, self.oz = world["origin_x"], world["origin_z"]

    def at(self, px, py):
        ci = (self.ox + px) - self.cx0
        cj = (self.oz - py) - self.cz0
        ci = min(max(ci, 0.0), self.W - 1.001)
        cj = min(max(cj, 0.0), self.H - 1.001)
        i0, j0 = int(ci), int(cj)
        fi, fj = ci - i0, cj - j0
        a = self.h[j0, i0] * (1 - fi) + self.h[j0, i0 + 1] * fi
        b = self.h[j0 + 1, i0] * (1 - fi) + self.h[j0 + 1, i0 + 1] * fi
        return float(a * (1 - fj) + b * fj)


def build_terrain_mesh(col, h, world, step=4):
    """Malha de pré-visualização do terreno (subamostrada)."""
    H, W = h.shape
    ii = list(range(0, W, step))
    jj = list(range(0, H, step))
    cx0, cz0 = world["import_corner"]
    ox, oz = world["origin_x"], world["origin_z"]
    verts, faces = [], []
    for j in jj:
        for i in ii:
            px = (cx0 + i) - ox
            py = oz - (cz0 + j)
            verts.append((px, py, float(h[j, i])))
    nx = len(ii)
    for r in range(len(jj) - 1):
        for c in range(nx - 1):
            a = r * nx + c
            faces.append((a, a + 1, a + nx + 1, a + nx))
    me = util._mk("SM_terrain_preview", verts, faces, col, M.get("grass_dry"))
    return me, len(verts), len(faces)


def build_roads(col, hs):
    data = layout.load()
    made = 0
    for road in data["roads"]:
        pts = road["points"]
        half = road["width"] / 2.0
        verts, faces = [], []
        for k, (x, y) in enumerate(pts):
            if k == 0:
                dx, dy = pts[1][0] - x, pts[1][1] - y
            elif k == len(pts) - 1:
                dx, dy = x - pts[-2][0], y - pts[-2][1]
            else:
                dx, dy = pts[k + 1][0] - pts[k - 1][0], pts[k + 1][1] - pts[k - 1][1]
            n = math.hypot(dx, dy) or 1.0
            nx_, ny_ = -dy / n * half, dx / n * half
            z = hs.at(x, y) + 0.06
            verts.append((x + nx_, y + ny_, z))
            verts.append((x - nx_, y - ny_, z))
        for k in range(len(pts) - 1):
            a = k * 2
            faces.append((a, a + 2, a + 3, a + 1))
        util._mk("SM_sch_road_" + road["id"], verts, faces, col,
                 M.get(_ROAD_MAT.get(road["class"], "dirt_road")))
        made += 1
    return made


def build_blocks(col, hs):
    """Quadras vêm como polígono derivado das interseções da malha viária."""
    data = layout.load()
    for b in data["blocks"]:
        corners = [(float(x), float(y)) for x, y in b["poly"]]
        z = max(hs.at(x, y) for x, y in corners) + 0.30
        util._mk("SM_sch_block_" + b["id"],
                 [(x, y, z) for x, y in corners],
                 [tuple(range(len(corners)))], col, M.get("wall_render_raw"))
    return len(data["blocks"])


def build_landmarks(col, hs):
    data = layout.load()
    L = data["landmarks"]
    n = 0
    pr = L["praca_obelisco"]
    cx, cy = pr["center"]
    z = hs.at(cx, cy) + 0.2
    for name, r, mat in (("praca", pr["radius"], "cobble_polish"),
                         ("ilha", pr["island_radius"], "grass_dry")):
        v, f = [], []
        for k in range(28):
            a = 2 * math.pi * k / 28
            v.append((cx + r * math.cos(a), cy + r * math.sin(a), z + (0.05 if name == "ilha" else 0)))
        f.append(tuple(range(28)))
        util._mk("SM_sch_" + name, v, f, col, M.get(mat)); n += 1

    for key, mat in (("igreja_matriz", "wall_stone_church"),
                     ("cemiterio", "wall_stone_cemetery"),
                     ("ete", "sidewalk_concrete")):
        e = L[key]
        cx, cy = e["center"]; sx, sy = e["size"]
        a = math.radians(e.get("rotation", 0.0))
        ca, sa = math.cos(a), math.sin(a)
        corners = []
        for ox, oy in ((-sx/2, -sy/2), (sx/2, -sy/2), (sx/2, sy/2), (-sx/2, sy/2)):
            corners.append((cx + ox*ca - oy*sa, cy + ox*sa + oy*ca))
        z = max(hs.at(x, y) for x, y in corners) + 0.5
        util._mk("SM_sch_" + key, [(x, y, z) for x, y in corners],
                 [(0, 1, 2, 3)], col, M.get(mat)); n += 1
    return n


def build(parent, h):
    world = layout.load()["world"]
    hs = Height(h, world)
    ct = util.reset_collection(COL, parent)
    cr = util.reset_collection(COL_CTX, parent)
    _, nv, nf = build_terrain_mesh(ct, h, world)
    nb = build_blocks(cr, hs)
    nl = build_landmarks(cr, hs)
    return {"terreno_verts": nv, "terreno_faces": nf,
            "quadras": nb, "marcos": nl}


def build_terrain_only(parent, h):
    """So a malha de pre-visualizacao do terreno — 03_BLOCKS pertence a walls.py."""
    world = layout.load()["world"]
    ct = util.reset_collection(COL, parent)
    _, nv, nf = build_terrain_mesh(ct, h, world)
    return {"terreno_verts": nv, "terreno_faces": nf}
