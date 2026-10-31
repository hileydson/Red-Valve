# -*- coding: utf-8 -*-
"""Grava os clipes da Drizzi e exporta o .glb do jogo.

    blender -b Red-Valve-Blender/drizzi/drizzi.blend -P tools/blender/drizzi/animar_drizzi.py
    blender -b Red-Valve-Blender/drizzi/drizzi_monstro.blend -P tools/blender/drizzi/animar_drizzi.py -- monstro

Sem argumento: a Drizzi HUMANA. Abre o .blend do `montar_drizzi.py`,
(re)cria os clipes (`anim_drizzi.py`; os de captura vem da biblioteca Meshy
do projeto), salva o .blend e exporta malha + esqueleto + clipes:
    red-valve/assets/3d_model/npc/drizzi/drizzi.glb

`monstro`: a Drizzi tomada pelo parasita (o rig antigo, guardado em
`drizzi_monstro.blend`). Clipes de `anim_drizzi_monstro.py`, e a malha sai
decimada (o scan tem 200 mil triangulos) em:
    red-valve/assets/3d_model/npc/drizzi/drizzi_monstro.glb

Quem chama em ordem e importa: `construir.sh` (mesma pasta).
"""

import os
import sys

import bpy

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.path.insert(1, os.path.join(os.path.dirname(AQUI), "igreja_dona_nice"))
import anim_comum as A  # noqa: E402
import retarget_lib as RT  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
MODELOS = os.path.join(RAIZ, "red-valve/assets/3d_model")
DESTINO = os.path.join(MODELOS, "npc/drizzi/drizzi.glb")
DESTINO_MONSTRO = os.path.join(MODELOS, "npc/drizzi/drizzi_monstro.glb")
## O monstro vai pro jogo com isto de triangulos.
TRIS_MONSTRO = 70000

FONTES = {
    "maycow_lopes": "player/Maycow Lopes/maycow_lopes.glb",
}


def armadura():
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            return o
    return None


def carregar_fontes(nomes):
    return {n: RT.importar_fonte(os.path.join(MODELOS, FONTES[n])) for n in nomes}


def descartar_fontes(fontes):
    for arm, acoes in fontes.values():
        for filho in list(arm.children):
            bpy.data.objects.remove(filho, do_unlink=True)
        bpy.data.objects.remove(arm, do_unlink=True)
        for a in acoes.values():
            if a.users == 0 or not a.use_fake_user:
                bpy.data.actions.remove(a)
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)


def decimar(malhas, alvo_tris):
    """Modificador de decimacao (o export aplica; a armadura fica de fora)."""
    for m in malhas:
        if m.modifiers.get("decimar_export"):
            continue
        tris = sum(len(p.vertices) - 2 for p in m.data.polygons)
        if tris <= alvo_tris:
            continue
        mod = m.modifiers.new("decimar_export", 'DECIMATE')
        mod.decimate_type = 'COLLAPSE'
        mod.ratio = alvo_tris / tris
        print("  decimando %s: %d -> ~%d tris" % (m.name, tris, alvo_tris))


def deformacao(arm, ligada):
    """Liga/desliga a armadura nas malhas. Gravando os clipes, cada quadro
    reavalia a cena: com a malha de scan (100 mil vertices) deformando junto,
    o monstro levava mais de 15 minutos. A pose so' precisa dos ossos."""
    for m in arm.children_recursive:
        if m.type != 'MESH':
            continue
        for mod in m.modifiers:
            if mod.type == 'ARMATURE':
                mod.show_viewport = ligada


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    monstro = bool(argv) and argv[0] == "monstro"
    bpy.context.scene.render.fps = A.FPS
    arm = armadura()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    deformacao(arm, False)
    fontes = {}
    if monstro:
        import anim_drizzi_monstro as M
        rig = A.Rig(arm)
        M.clipes(rig)
    else:
        import anim_drizzi as M
        fontes = carregar_fontes(["maycow_lopes"])
        rig = A.Rig(arm, fontes["maycow_lopes"][0])
        M.clipes(rig, fontes)
    # so' os clipes dela ficam (as acoes da captura saem junto com a fonte)
    dela = [a for a in bpy.data.actions if a.use_fake_user]
    if fontes:
        descartar_fontes(fontes)
    for a in list(bpy.data.actions):
        if a not in dela:
            bpy.data.actions.remove(a)
    print("CLIPES", sorted(a.name for a in bpy.data.actions))
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
    deformacao(arm, True)
    bpy.ops.wm.save_mainfile()
    # o export amostra todo quadro de todo clipe: de novo, so' os ossos
    deformacao(arm, False)

    malhas = [o for o in arm.children_recursive if o.type == 'MESH']
    destino = DESTINO_MONSTRO if monstro else DESTINO
    if monstro:
        decimar(malhas, TRIS_MONSTRO)
    objs = [arm] + malhas
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=destino, export_format='GLB', use_selection=True,
        export_yup=True, export_apply=monstro,
        export_animations=True, export_animation_mode='ACTIONS',
        export_force_sampling=True, export_skins=True, export_def_bones=False,
        export_reset_pose_bones=True, export_image_format='AUTO')
    print("== exportado", destino)


main()
