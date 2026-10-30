# -*- coding: utf-8 -*-
"""Grava o clipe da Drizzi e exporta o .glb do jogo.

    blender -b Red-Valve-Blender/drizzi/drizzi.blend -P tools/blender/drizzi/animar_drizzi.py

Abre o .blend do `montar_drizzi.py`, (re)cria o clipe `conversando`
(`anim_drizzi.py`), salva o .blend e exporta malha + esqueleto + clipe:
    red-valve/assets/3d_model/npc/drizzi/drizzi.glb

Quem chama em ordem e importa: `construir.sh` (mesma pasta).
"""

import os
import sys

import bpy

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.path.insert(1, os.path.join(os.path.dirname(AQUI), "igreja_dona_nice"))
import anim_comum as A  # noqa: E402
import anim_drizzi as M  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
DESTINO = os.path.join(RAIZ, "red-valve/assets/3d_model/npc/drizzi/drizzi.glb")


def armadura():
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            return o
    return None


def main():
    bpy.context.scene.render.fps = A.FPS
    arm = armadura()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    rig = A.Rig(arm)
    M.clipes(rig)
    print("CLIPES", sorted(a.name for a in bpy.data.actions))
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
    bpy.ops.wm.save_mainfile()

    objs = [arm] + [o for o in arm.children_recursive if o.type == 'MESH']
    os.makedirs(os.path.dirname(DESTINO), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=DESTINO, export_format='GLB', use_selection=True,
        export_yup=True, export_animations=True, export_animation_mode='ACTIONS',
        export_force_sampling=True, export_skins=True, export_def_bones=False,
        export_reset_pose_bones=True, export_image_format='AUTO')
    print("== exportado", DESTINO)


main()
