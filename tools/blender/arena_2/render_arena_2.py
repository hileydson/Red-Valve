"""Confere a arena 2 gerada: importa o .glb e renderiza algumas vistas.

    blender --background --factory-startup \\
        --python tools/blender/arena_2/render_arena_2.py -- [saida_dir]

E' so' ferramenta de olho — nada daqui entra no jogo. Usa Workbench de
proposito: renderiza em segundos, sem GPU, e mostra FORMA (que e' o que se
quer conferir) em vez de material.

Convencao: o .glb sai com `export_yup=False` (coordenadas do jogo, Y pra cima)
e o importador do Blender SEMPRE converte Y-up -> Z-up. Um ponto (x, y, z) do
jogo aparece no Blender em (x, -z, y) — e' o que `jogo()` faz.
"""

import os
import sys

import bpy
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
GLB = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "stages",
                   "battlefield_2", "arena_2.glb")


def jogo(x, y, z):
    return Vector((x, -z, y))


VISTAS = [
    # (nome, olho, alvo, lente)   — olho/alvo em coordenadas do JOGO
    ("01_da_brecha_pra_fachada", (0.0, 1.75, 33.0), (0.0, 12.0, -30.0), 24),
    ("02_do_adro_pra_brecha", (0.0, 3.4, -2.0), (0.0, 8.0, 42.0), 22),
    ("03_planta", (0.0, 95.0, 6.0), (0.0, 0.0, 0.0), 32),
    ("04_muralha_de_carne", (-14.0, 2.0, 14.0), (-32.0, 8.0, 32.0), 26),
    ("05_torre_caida", (31.0, 7.0, -3.0), (19.0, 2.0, -20.0), 26),
    ("06_contrafortes", (-8.0, 2.0, -6.0), (-38.0, 10.0, 2.0), 24),
    ("07_costelas", (-10.0, 2.0, -10.0), (-30.0, 12.0, -30.0), 24),
    ("08_a_boca", (0.0, 5.0, 13.0), (0.0, 0.5, 0.0), 30),
    ("09_torre_em_pe", (8.0, 2.0, 6.0), (38.0, 16.0, 2.0), 22),
    ("10_arcada", (10.0, 2.0, 8.0), (30.0, 6.0, 30.0), 26),
    ("11_de_cima_lateral", (52.0, 40.0, 58.0), (0.0, 4.0, 0.0), 30),
    ("12_olhando_o_arco", (16.0, 1.75, 16.0), (-12.0, 26.0, -12.0), 20),
]


def preparar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    for ob in bpy.data.objects:
        if ob.name.startswith("CL_"):
            ob.hide_render = True
    cena = bpy.context.scene
    cena.render.engine = "BLENDER_WORKBENCH"
    cena.render.resolution_x = 1000
    cena.render.resolution_y = 600
    cena.render.film_transparent = False
    sh = cena.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_shadows = True


def render(nome, olho, alvo, lente, saida):
    cam_data = bpy.data.cameras.new(nome)
    cam_data.lens = lente
    cam_data.clip_end = 900
    cam = bpy.data.objects.new(nome, cam_data)
    bpy.context.scene.collection.objects.link(cam)
    p = jogo(*olho)
    a = jogo(*alvo)
    cam.location = p
    cam.rotation_euler = (a - p).normalized().to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    bpy.context.scene.render.filepath = os.path.join(saida, nome + ".png")
    bpy.ops.render.render(write_still=True)
    print("   ", bpy.context.scene.render.filepath)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    saida = args[0] if args else "/tmp/arena_2"
    os.makedirs(saida, exist_ok=True)
    preparar()
    for (nome, olho, alvo, lente) in VISTAS:
        render(nome, olho, alvo, lente, saida)


if __name__ == "__main__":
    main()
