"""Etapa 00 — placa de teste.

Não é uma grade de amostras chapadas: é uma **esquina de teste** com as cotas
reais da §3.2 (meio-fio 0,15 m, calçada 1,40 m, pé-direito 2,80 m, poste 8,50 m)
mais uma grade de chips. Assim a Etapa 00 valida paleta E iluminação juntas,
que é o que decide se a cor está certa.
"""
import math
import bpy
from . import util, materials as M
from . import palette

COL = "08_LOOKDEV"


def _m(name):
    return M.get(name)


def build_corner(col):
    # base de contexto
    util.plane("SM_test_ground", 46, 28, col, _m("dirt_road"), loc=(6, -3, -0.02))

    # pista + desgaste
    util.plane("SM_test_street", 14, 8, col, _m("cobble_base"), loc=(0, -4, 0))
    util.plane("SM_test_wheeltrack", 12, 0.9, col, _m("cobble_polish"), loc=(0, -5.5, 0.006))
    util.plane("SM_test_asphalt", 3, 2, col, _m("asphalt_patch"), loc=(-4, -3, 0.008))
    util.plane("SM_test_dirt", 3, 2, col, _m("dirt_road"), loc=(0.5, -3, 0.008))
    util.plane("SM_test_gutter", 14, 0.5, col, _m("gutter_grime"), loc=(0, -0.25, 0.005))

    # seção transversal real
    util.box("SM_test_curb", 14, 0.20, 0.15, col, _m("curb_granite"), loc=(0, 0.10, 0))
    util.box("SM_test_sidewalk", 14, 1.40, 0.15, col, _m("sidewalk_concrete"), loc=(0, 0.90, 0))

    # três paredes com pé-direito 2,80 + platibanda
    walls = (("whitewash", -5, "wall_whitewash", "roof_tile_faded"),
             ("render", -1, "wall_render_raw", "roof_metal_rust"),
             ("brick", 3, "wall_brick", "roof_metal_zinc"))
    for tag, x, wmat, rmat in walls:
        util.box("SM_test_wall_" + tag, 4, 0.30, 3.0, col, _m(wmat), loc=(x, 1.75, 0.15))
        util.box("SM_test_roof_" + tag, 4.2, 2.4, 0.14, col, _m(rmat),
                 loc=(x, 1.15, 3.45), rot=(math.radians(-17), 0, 0), base=False)

    # grama seca atrás
    util.plane("SM_test_grass", 14, 3, col, _m("grass_dry"), loc=(0, 3.6, 0.0))

    # poste 8,50 m com braço 1,60 m e luminária
    util.cyl("SM_test_pole", 0.11, 8.5, col, _m("curb_granite"), loc=(-6.0, -0.65, 0), seg=8)
    util.box("SM_test_pole_arm", 0.08, 1.6, 0.08, col, _m("metal_rust_dark"),
             loc=(-6.0, -1.45, 8.18), rot=(math.radians(-15), 0, 0))
    util.box("SM_test_lamp", 0.70, 0.25, 0.18, col, _m("metal_rust_dark"),
             loc=(-6.0, -2.22, 8.34))

    # copa urbana para checar o verde contra os ocres
    util.cyl("SM_test_tree_trunk", 0.16, 3.0, col, _m("wood_dark"), loc=(9.6, 3.4, 0), seg=6)
    util.box("SM_test_tree_canopy", 3.0, 3.0, 2.4, col, _m("canopy_urban"), loc=(9.6, 3.4, 2.8))


def build_chips(col):
    entries = palette.flat()                      # 30 superfícies (sem atmosfera)
    names = sorted(entries, key=lambda n: (entries[n]["family"], n))
    cols, step, x0, y0 = 6, 1.15, 9.5, -7.0
    for i, name in enumerate(names):
        cx = x0 + (i % cols) * step
        cy = y0 + (i // cols) * step
        util.plane("SM_chip_%02d_%s" % (i, name), 1.0, 1.0, col, _m(name), loc=(cx, cy, 0.012))
    return len(names)


def build_lookdev_light(col):
    """Sol a 22° e céu quente — só para conferir material no Blender.
    O look real é calibrado no Godot (§0.1)."""
    ob = bpy.data.objects.get("SUN_lookdev")
    if ob:
        bpy.data.objects.remove(ob, do_unlink=True)
    # reaproveita o datablock pelo nome: criar sempre geraria SUN_lookdev.001
    lamp = bpy.data.lights.get("SUN_lookdev")
    if lamp is None or lamp.type != "SUN":
        if lamp is not None:
            bpy.data.lights.remove(lamp)
        lamp = bpy.data.lights.new("SUN_lookdev", type="SUN")
    lamp.energy = 4.6
    lamp.angle = math.radians(1.5)
    lamp.color = palette.hex_to_linear("#FFD9A0")[:3]
    ob = bpy.data.objects.new("SUN_lookdev", lamp)
    ob.rotation_euler = (math.radians(68), 0.0, math.radians(-35))
    ob.location = (0, 0, 20)
    col.objects.link(ob)

    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("CityWorld")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if bg:
        bg.inputs["Color"].default_value = palette.hex_to_linear("#4A4438")
        bg.inputs["Strength"].default_value = 1.2
    return ob


def _reuse_camera(name):
    """Reaproveita o datablock pelo nome — criar sempre geraria name.001."""
    cam = bpy.data.cameras.get(name)
    if cam is None:
        cam = bpy.data.cameras.new(name)
    return cam


def _look_at(ob, loc, tgt):
    import mathutils
    loc = mathutils.Vector(loc)
    ob.location = loc
    ob.rotation_euler = (mathutils.Vector(tgt) - loc).to_track_quat('-Z', 'Y').to_euler()


def build_lookdev_cameras(col):
    """Duas câmeras de conferência, reconstruídas a cada run junto com o rig."""
    specs = (
        ("CAM_corner", 40, (-12.0, -19.0, 9.0), (1.5, -0.5, 2.0)),
        ("CAM_chips", 50, (12.9, -13.5, 8.5), (12.9, -4.7, 0.0)),
        ("CAM_eye", 32, (-4.5, -6.0, 1.70), (3.0, 1.6, 1.60)),
    )
    made = []
    for name, lens, loc, tgt in specs:
        cam = _reuse_camera(name)
        cam.lens = lens
        ob = bpy.data.objects.new(name, cam)
        col.objects.link(ob)
        _look_at(ob, loc, tgt)
        made.append(name)
    bpy.context.scene.camera = bpy.data.objects["CAM_corner"]
    return made


def build(parent):
    col = util.reset_collection(COL, parent)
    build_corner(col)
    n = build_chips(col)
    build_lookdev_light(col)
    cams = build_lookdev_cameras(col)
    return {"collection": COL, "cameras": cams, "chips": n, "objects": len(col.objects)}
