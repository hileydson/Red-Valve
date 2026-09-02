"""Carrega city_data/layout.json e converte entre coordenadas locais e do Godot."""
import json
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
