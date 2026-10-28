"""Bootstrap chamado pelo MCP. Ver docs/plano-cidade-blender.md §3.4.

    import sys, importlib
    P = r".../tools/blender/citygen"
    if P not in sys.path: sys.path.insert(0, P)
    import run; importlib.reload(run)
    run.phase(0)
"""
import importlib
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import bpy
from lib import util, palette, materials, testplate, export
from lib import layout, terrain, schematic, roads, props, walls, houses, landmarks, vegetation

for _m in (util, palette, materials, layout, terrain, schematic, roads, props, walls, houses, landmarks, vegetation, testplate, export):
    importlib.reload(_m)

ROOT = "CITY"
TREE = ["00_REF", "01_TERRAIN", "02_ROADS", "03_BLOCKS", "04_PROXY_BUILD",
        "05_LANDMARKS", "06_STREET_FURN", "07_VEGETATION", "08_LOOKDEV", "09_EXPORT"]

OUT = os.path.join(_HERE, "out")


def build_tree():
    root = util.get_collection(ROOT)
    for name in TREE:
        util.get_collection(name, root)
    return root


def build_ref_human(root):
    col = util.reset_collection("00_REF", root)
    ob = util.cyl("REF_Human", 0.22, 1.75, col, materials.get("paint_shop_red"),
                  loc=(2.0, -2.2, 0), seg=8)
    ob["citygen_note"] = "referencia de escala 1,75 m - nunca exportar"
    return ob


def phase0():
    util.setup_scene_units()
    root = build_tree()
    mats = materials.build_all()
    build_ref_human(root)
    info = testplate.build(root)
    util.purge_orphans()
    return {
        "phase": 0,
        "collections": [ROOT] + TREE,
        "materials": len(mats),
        "testplate": info,
        "unit": bpy.context.scene.unit_settings.length_unit,
    }


def export_testplate(filename="city_testplate.glb"):
    return export.export_collection(testplate.COL, os.path.join(OUT, filename))


def phase1():
    """Traçado + terreno derivado das ruas. Ver plano §7 Etapa 01."""
    util.setup_scene_units()
    root = build_tree()
    materials.build_all()
    layout.load(force=True)
    h, size = terrain.build_heightfield()
    info = schematic.build(root, h)
    raw = terrain.write_raw(h)
    util.purge_orphans()
    d = layout.load()
    return {"phase": 1, "grade": size, "heightmap": raw, "esquematico": info,
            "vias": len(d["roads"]), "quadras": len(d["blocks"]),
            "regioes_godot": d["world"]["regions"]}


def _build(fases=()):
    """Monta a cidade acumulando as partes pedidas — as fases se somam."""
    util.setup_scene_units()
    root = build_tree()
    _, ntex = materials.build_all_textured()
    layout.load(force=True)
    h, _ = terrain.build_heightfield()
    schematic.build_terrain_only(root, h)
    hs = schematic.Height(h, layout.load()["world"])
    out = {"materiais_texturizados": ntex}
    if "roads" in fases:
        out["vias"] = roads.build(root, hs)
    if "walls" in fases:
        out["divisas"] = walls.build(root, hs)
    if "houses" in fases:
        out["casas"] = houses.build(root, hs)
    if "landmarks" in fases:
        # igreja e praca vem de asset do usuario (city_extra/)
        out["marcos"] = landmarks.build(root, hs, pular=("igreja", "praca"))
    if "vegetation" in fases:
        out["vegetacao"] = vegetation.build(root, hs)
    if "props" in fases:
        out["mobiliario"] = props.build(root, hs)
    util.purge_orphans()
    return out


def phase2():
    """Sistema viário completo. Ver plano §7 Etapa 02."""
    r = _build(fases=("roads",))
    h, _ = terrain.build_heightfield()
    r["heightmap"] = terrain.write_raw(h)
    r["phase"] = 2
    return r


def phase3():
    """Quadras, muros e divisas. Ver plano §7 Etapa 03."""
    return _build(fases=("roads", "walls"))


def phase4():
    """Casas proxy — descartáveis. Ver plano §7 Etapa 04."""
    r = _build(fases=("roads", "walls", "houses"))
    r["phase"] = 4
    return r


def phase5():
    """Igreja e cemitério em proxy; praça e ETE em acabamento. Plano §7 Etapa 05."""
    r = _build(fases=("roads", "walls", "houses", "landmarks"))
    r["phase"] = 5
    return r


def phase7():
    """Vegetação e anel de mata. Ver plano §7 Etapa 07."""
    r = _build(fases=("roads", "walls", "houses", "landmarks", "vegetation"))
    h, _ = terrain.build_heightfield()
    r["heightmap"] = terrain.write_raw(h)
    r["phase"] = 7
    return r


def phase6():
    """Postes, fiação, placas e mobiliário. Ver plano §7 Etapa 06."""
    r = _build(fases=("roads", "walls", "houses", "landmarks", "props"))
    r["phase"] = 6
    return r


def full():
    """Cidade inteira: todas as partes de uma vez, mais o heightmap."""
    r = _build(fases=("roads", "walls", "houses", "landmarks",
                      "vegetation", "props"))
    h, _ = terrain.build_heightfield()
    r["heightmap"] = terrain.write_raw(h)
    r["phase"] = "full"
    return r


_PHASES = {0: phase0, 1: phase1, 2: phase2, 3: phase3,
           4: phase4, 5: phase5, 6: phase6, 7: phase7, 99: full}


def phase(n):
    if n not in _PHASES:
        return {"error": "Etapa %s ainda não implementada. Disponíveis: %s"
                         % (n, sorted(_PHASES))}
    return _PHASES[n]()
