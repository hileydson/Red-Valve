# -*- coding: utf-8 -*-
"""Fotografa um personagem rigado, numa pose de teste ou num quadro de acao.

    blender -b <arquivo.blend> -P tools/blender/igreja_dona_nice/previa.py -- \\
        <saida_sem_extensao> [acao:quadro ...]

Sem acao, aplica a POSE DE TESTE (abaixo) — e' a que denuncia peso ruim:
braco a' frente (axila e ombro), cotovelo e joelho dobrados (vinco), tronco
inclinado e cabeca virada (pescoco). Com `acao:quadro`, fotografa aquele
quadro daquela acao, uma imagem por pedido.

Saem tres vistas por imagem (frente, lado, tres-quartos) lado a lado.
"""

import bpy
import math
import os
import sys
from mathutils import Vector, Euler

POSE_TESTE = {
    "upper_arm.L": (1.1, 0.0, 0.0),
    "forearm.L": (0.9, 0.0, 0.0),
    "upper_arm.R": (-0.3, 0.0, 0.6),
    "thigh.L": (0.9, 0.0, 0.0),
    "shin.L": (-1.3, 0.0, 0.0),
    "spine": (0.25, 0.0, 0.0),
    "chest": (0.15, 0.0, 0.0),
    "head": (0.0, 0.7, 0.0),
}


def _armadura():
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            return o
    return None


def _luzes_e_camera(cena, centro, tamanho):
    w = bpy.data.worlds.new("w_previa")
    cena.world = w
    w.color = (0.42, 0.42, 0.45)
    cam = bpy.data.objects.new("cam_previa", bpy.data.cameras.new("cam_previa"))
    cena.collection.objects.link(cam)
    cena.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = tamanho * 1.15
    for (e, r) in ((3.0, (0.8, 0.2, 0.6)), (1.4, (-0.6, 0.0, -2.5))):
        luz = bpy.data.objects.new("sol", bpy.data.lights.new("sol", 'SUN'))
        cena.collection.objects.link(luz)
        luz.data.energy = e
        luz.rotation_euler = r
    return cam


def fotografar(saida, rotulo):
    cena = bpy.context.scene
    cena.render.engine = 'BLENDER_EEVEE'
    cena.render.resolution_x = 700
    cena.render.resolution_y = 700
    bpy.context.view_layer.update()
    malhas = [o for o in cena.objects if o.type == 'MESH' and o.visible_get()]
    dg = bpy.context.evaluated_depsgraph_get()
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in malhas:
        ev = o.evaluated_get(dg)
        for c in ev.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
    centro = (mn + mx) * 0.5
    tamanho = max(mx - mn)
    cam = bpy.data.objects.get("cam_previa") or _luzes_e_camera(cena, centro, tamanho)
    cam.data.ortho_scale = tamanho * 1.15
    partes = []
    for (nome, d) in (("frente", Vector((0, -1, 0))), ("lado", Vector((1, 0, 0))),
                      ("tres", Vector((0.7, -0.7, 0.25)).normalized())):
        cam.location = centro + d * 10
        cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        arq = "%s_%s_%s.png" % (saida, rotulo, nome)
        cena.render.filepath = arq
        bpy.ops.render.render(write_still=True)
        partes.append(arq)
    print("PREVIA", " ".join(partes))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    saida = argv[0] if argv else "/tmp/previa"
    pedidos = argv[1:]
    arm = _armadura()
    if not pedidos:
        if arm.animation_data:
            arm.animation_data.action = None
        for pb in arm.pose.bones:
            pb.rotation_mode = 'XYZ'
            pb.rotation_euler = Euler(POSE_TESTE.get(pb.name, (0, 0, 0)), 'XYZ')
        fotografar(saida, "teste")
        return
    for pedido in pedidos:
        nome, quadro = pedido.split(":")
        acao = bpy.data.actions[nome]
        arm.animation_data_create()
        arm.animation_data.action = acao
        if acao.slots:
            arm.animation_data.action_slot = acao.slots[0]
        bpy.context.scene.frame_set(int(quadro))
        fotografar(saida, "%s_%s" % (nome, quadro))


main()
