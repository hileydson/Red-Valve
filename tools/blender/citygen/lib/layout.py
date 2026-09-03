"""Carrega city_data/layout.json e converte entre coordenadas locais e do Godot."""
import json
import math
import os

_HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(_HERE, "city_data", "layout.json")

_cache = None


def load(force=False):
    global _cache
    if _cache is None or force:
        with open(PATH, "r", encoding="utf-8") as fh:
            _cache = json.load(fh)
    return _cache


def to_godot(px, py):
    """(local X leste, local Y norte) -> (Godot X, Godot Z)."""
    w = load()["world"]
    return w["origin_x"] + px, w["origin_z"] - py


def from_godot(gx, gz):
    w = load()["world"]
    return gx - w["origin_x"], w["origin_z"] - gz


# ----------------------------------------------------- folga ate a pista
_GRADE_CELL = 16.0


def grade_vias(data, cell=_GRADE_CELL):
    """Amostra as vias numa grade espacial: (celula) -> [(x, y, meia_largura)].

    Serve para perguntar rapido "isto esta em cima do asfalto?" sem varrer
    as 30 vias inteiras a cada teste.
    """
    grid = {}
    for r in data["roads"]:
        hw = r["width"] / 2.0
        pts = r["points"]
        for k in range(len(pts) - 1):
            a, b = pts[k], pts[k + 1]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            n = max(1, int(L / 3.0))
            for i in range(n + 1):
                t = i / float(n)
                x = a[0] + (b[0] - a[0]) * t
                y = a[1] + (b[1] - a[1]) * t
                grid.setdefault((int(x // cell), int(y // cell)), []).append(
                    (x, y, hw))
    return grid


def folga_via(grid, x, y, cell=_GRADE_CELL):
    """Distancia ate a borda da pista mais proxima. Negativo = dentro dela."""
    ci, cj = int(x // cell), int(y // cell)
    melhor = 1e9
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            for ox, oy, hw in grid.get((ci + di, cj + dj), ()):
                d = math.hypot(ox - x, oy - y) - hw
                if d < melhor:
                    melhor = d
    return melhor
