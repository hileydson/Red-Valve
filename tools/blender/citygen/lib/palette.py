"""Carrega city_data/palette.json e converte sRGB -> linear."""
import json
import os

_HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(_HERE, "city_data", "palette.json")

FAMILIES = ("surfaces", "ground", "nature", "atmosphere")


def srgb_to_linear(c):
    c = max(0.0, min(1.0, c))
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_linear(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1.0)


def load():
    with open(PATH, "r", encoding="utf-8") as fh:
        return json.load(fh)


def flat(include_atmosphere=False):
    """{nome: {hex, rough, metal, uso, family}} para todas as famílias."""
    data, out = load(), {}
    for fam in FAMILIES:
        if fam == "atmosphere" and not include_atmosphere:
            continue
        for name, e in data.get(fam, {}).items():
            d = dict(e)
            d["family"] = fam
            out[name] = d
    return out
