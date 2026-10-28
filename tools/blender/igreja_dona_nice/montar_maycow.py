# -*- coding: utf-8 -*-
"""O Maycow normal das cutscenes da igreja: uma COPIA do modelo do jogo.

    blender -b --factory-startup -P tools/blender/igreja_dona_nice/montar_maycow.py

Le':   red-valve/assets/3d_model/player/Maycow Lopes/maycow_normal/maycow_normal_rigged.glb
Salva: Red-Valve-Blender/maycow_cenas/maycow_cenas.blend

O .glb do jogo NAO e' tocado: o player.tscn referencia osso por NUMERO e o
punho fechado foi enxertado nele byte a byte (ver gerar_punho_maycow.py). Os
clipes novos (esticar a mao, sacar a arma, carregar o Jonny) saem num .glb
proprio, `npc/igreja/maycow.glb`, com o MESMO esqueleto (24 ossos Meshy, em
centimetros) — por isso os clipes dele tambem servem no Maycow do jogo.
"""

import os
import bpy

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
FONTE = os.path.join(RAIZ, "red-valve/assets/3d_model/player/Maycow Lopes/"
                     "maycow_normal/maycow_normal_rigged.glb")
SAIDA = os.path.join(os.path.dirname(RAIZ), "Red-Valve-Blender/maycow_cenas/maycow_cenas.blend")

bpy.ops.wm.read_homefile(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=FONTE)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
for o in bpy.data.objects:
    print("OBJ", o.name, o.type, o.parent.name if o.parent else None)
    if o.type == 'ARMATURE' and o.animation_data:
        o.animation_data.action = None
os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=SAIDA)
print("== salvo", SAIDA)
