"""Confere a igreja gerada: importa o .glb e renderiza algumas vistas.

    blender --background --factory-startup \\
        --python tools/blender/igreja/render_igreja.py -- [saida_dir]

E' so' ferramenta de olho — nada daqui entra no jogo. Usa Workbench de
proposito: renderiza em segundos, sem GPU, e mostra FORMA (que e' o que se
quer conferir) em vez de material.

Atencao a' convencao: o .glb sai daqui com `export_yup=False` (coordenadas do
jogo, Y pra cima), e o importador do Blender SEMPRE converte Y-up -> Z-up. Um
ponto (x, y, z) do jogo aparece no Blender em (x, -z, y). As cameras abaixo ja'
levam isso em conta — por isso os Y negativos.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
GLB = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "stages", "igreja",
                   "igreja_interior.glb")


def jogo(x, y, z):
    """Ponto em coordenadas do jogo -> coordenadas do Blender importado."""
    return Vector((x, -z, y))


VISTAS = [
    # (nome, olho, alvo, lente)
    ("01_nave_do_portal", (0.0, 1.75, 2.0), (0.0, 6.0, 30.0), 20),
    ("02_nave_do_coro", (0.0, 2.6, 38.0), (0.0, 8.0, 6.0), 20),
    ("03_lateral_norte", (-10.0, 1.75, 4.0), (-9.0, 6.0, 24.0), 22),
    ("04_galeria_sul", (9.8, 11.6, 27.0), (-2.0, 9.0, 20.0), 24),
    ("05_buraco_e_pilha", (0.0, 1.7, 26.0), (0.0, 24.0, 15.5), 24),
    ("06_jube_e_altar", (0.0, 10.6, 24.0), (0.0, 4.0, 42.0), 26),
    ("07_planta_alta", (0.0, 44.0, 20.0), (0.0, 4.0, 20.0), 30),
    ("08_escada_norte", (-6.0, 6.5, 16.0), (-11.4, 3.0, 5.0), 18),
    ("09_rombo_de_baixo", (0.0, 1.7, 22.0), (0.0, 26.0, 15.5), 16),
    ("10_galeria_norte", (-10.2, 11.4, 18.5), (-9.0, 10.0, 33.0), 20),
]


def preparar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    for ob in bpy.data.objects:
        if ob.name.startswith("CL_"):
            ob.hide_render = True
    cena = bpy.context.scene
    cena.render.engine = "BLENDER_WORKBENCH"
    cena.render.resolution_x = 960
    cena.render.resolution_y = 600
    cena.render.film_transparent = False
    sh = cena.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_shadows = True


CORTES = [
    # (nome, olho, alvo, largura_do_corte, clip_start) — camera ORTOGRAFICA.
    # O `clip_start` e' o truque do corte: tudo que estiver mais perto da
    # camera que essa distancia some, entao a metade da igreja que fica na
    # frente do plano e' fatiada fora e da' pra medir escada, galeria e
    # passarela de lado, como numa secao de projeto.
    ("20_corte_longitudinal", (-30.0, 12.0, 20.0), (10.0, 12.0, 20.0), 52, 18.2),
    ("21_corte_transversal", (0.0, 12.0, -26.0), (0.0, 12.0, 30.0), 30, 40.0),
]


def render_corte(nome, olho, alvo, largura, clip, saida):
    cam_data = bpy.data.cameras.new(nome)
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = largura
    cam_data.clip_start = clip
    cam_data.clip_end = 400
    cam = bpy.data.objects.new(nome, cam_data)
    bpy.context.scene.collection.objects.link(cam)
    p = jogo(*olho)
    a = jogo(*alvo)
    cam.location = p
    cam.rotation_euler = (a - p).normalized().to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    bpy.context.scene.render.filepath = os.path.join(saida, nome + ".png")
    bpy.ops.render.render(write_still=True)


def render(nome, olho, alvo, lente, saida):
    cam_data = bpy.data.cameras.new(nome)
    cam_data.lens = lente
    cam = bpy.data.objects.new(nome, cam_data)
    bpy.context.scene.collection.objects.link(cam)
    p = jogo(*olho)
    a = jogo(*alvo)
    cam.location = p
    d = (a - p).normalized()
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    bpy.context.scene.render.filepath = os.path.join(saida, nome + ".png")
    bpy.ops.render.render(write_still=True)
    print("   ", bpy.context.scene.render.filepath)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    saida = args[0] if args else "/tmp/igreja"
    os.makedirs(saida, exist_ok=True)
    preparar()
    for (nome, olho, alvo, lente) in VISTAS:
        render(nome, olho, alvo, lente, saida)
    for (nome, olho, alvo, largura, clip) in CORTES:
        render_corte(nome, olho, alvo, largura, clip, saida)


if __name__ == "__main__":
    main()
