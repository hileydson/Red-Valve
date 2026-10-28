# -*- coding: utf-8 -*-
"""A Dona Nice NORMAL (antes de virar monstro), pronta pra cena da igreja.

    blender -b --factory-startup -P tools/blender/igreja_dona_nice/montar_dona_nice.py

Le':   Red-Valve-Blender/dona_nice/dona_nice.blend        (o rig que ja' existia:
       38 ossos, boca, lingua, dentes e palpebras — NAO e' alterado)
Salva: Red-Valve-Blender/dona_nice/dona_nice_cena.blend   (copia de trabalho)

Tres coisas mudam na copia:

- a malha do corpo cai de 232 mil para ~70 mil triangulos. O scan bruto e'
  pesado demais pro renderer mobile, e ela aparece em plano medio — o rosto
  em close e' o que mais pede detalhe, e e' a regiao das pecas separadas
  (dentes, lingua, palpebras), que nao sao decimadas;
- escala real: 1,58 m, sola do pe' em z = 0 (o .blend original esta' em
  unidade normalizada, 1,9 de altura, com o chao em z = -0,951);
- luzes e camera de previa saem.

As acoes que ja' existiam (idle_breathing, talk_loop) continuam; a parte de
LOCALIZACAO delas e' escalada junto, senao a boca abriria 1,2 vez mais.
"""

import os
import sys
import bpy
from mathutils import Matrix

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
BLENDS = os.path.join(os.path.dirname(RAIZ), "Red-Valve-Blender")
FONTE = os.path.join(BLENDS, "dona_nice", "dona_nice.blend")
SAIDA = os.path.join(BLENDS, "dona_nice", "dona_nice_cena.blend")

ALTURA = 1.58
TRIS_CORPO = 70000


def main():
    bpy.ops.wm.open_mainfile(filepath=FONTE)
    cena = bpy.context.scene
    cena.render.fps = 30
    for o in list(bpy.data.objects):
        if o.type in ('LIGHT', 'CAMERA'):
            bpy.data.objects.remove(o, do_unlink=True)

    arm = bpy.data.objects["dona_nice_rig"]
    corpo = bpy.data.objects["mesh_node"]

    # --- decimar o corpo ANTES da armadura (o Decimate preserva os grupos)
    bpy.context.view_layer.objects.active = corpo
    tris = sum(len(p.vertices) - 2 for p in corpo.data.polygons)
    dec = corpo.modifiers.new("decimar", 'DECIMATE')
    dec.ratio = TRIS_CORPO / tris
    dec.use_collapse_triangulate = True
    while corpo.modifiers[0] != dec:
        bpy.ops.object.modifier_move_up(modifier=dec.name)
    bpy.ops.object.modifier_apply(modifier=dec.name)
    print("  corpo: %d -> %d tris" % (tris, sum(len(p.vertices) - 2
                                               for p in corpo.data.polygons)))

    # --- escala real, pe' no chao
    zs = [(corpo.matrix_world @ v.co).z for v in corpo.data.vertices]
    z0, z1 = min(zs), max(zs)
    s = ALTURA / (z1 - z0)
    xf = Matrix.Scale(s, 4) @ Matrix.Translation((0, 0, -z0))
    arm.matrix_world = xf @ arm.matrix_world
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    for filho in arm.children:
        filho.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for acao in bpy.data.actions:
        for camada in acao.layers:
            for faixa in camada.strips:
                for slot in acao.slots:
                    cb = faixa.channelbag(slot)
                    if cb is None:
                        continue
                    for fc in cb.fcurves:
                        if fc.data_path.endswith(".location"):
                            for k in fc.keyframe_points:
                                k.co.y *= s
                                k.handle_left.y *= s
                                k.handle_right.y *= s
    print("  escala %.4f" % s)
    bpy.ops.wm.save_as_mainfile(filepath=SAIDA)
    print("== salvo", SAIDA)


main()
