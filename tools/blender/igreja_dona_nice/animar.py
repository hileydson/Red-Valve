# -*- coding: utf-8 -*-
"""Gera os clipes de um personagem da cena da igreja e exporta o .glb do jogo.

    blender -b Red-Valve-Blender/<pasta>/<arquivo>.blend \\
        -P tools/blender/igreja_dona_nice/animar.py -- <nome>

<nome>: dona_nice | dona_nice_monster | dona_nice_monster_fase_2 | jonny | maycow

Grava as acoes DENTRO do .blend (abra no Blender pra ver/mexer) e exporta
    red-valve/assets/3d_model/npc/igreja/<nome>.glb

DEPOIS, no Godot, os clipes saem do .glb pra uma biblioteca editavel:
    Godot_v4.6.1 --headless --path red-valve res://tools/igreja/extrair_clipes.tscn
A partir dai' a fonte da animacao que o jogo toca e' o .tres (igual as maos de
primeira pessoa) — rodar isto de novo troca o .glb e NAO o .tres.
"""

import os
import sys

import bpy

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import anim_comum as A  # noqa: E402
import retarget_lib as RT  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
MODELOS = os.path.join(RAIZ, "red-valve/assets/3d_model")
SAIDA = os.path.join(MODELOS, "npc/igreja")

FONTES = {
    "zombie": "enemies/zombie.glb",
    "maycow_lopes": "player/Maycow Lopes/maycow_lopes.glb",
    "anti_lopes": "enemies/the_anti_lopes.glb",
    "husker": "enemies/the-cobalt-husker.glb",
    "maycow_normal": "player/Maycow Lopes/maycow_normal/maycow_normal_rigged.glb",
}


def carregar_fontes(nomes):
    out = {}
    for n in nomes:
        out[n] = RT.importar_fonte(os.path.join(MODELOS, FONTES[n]))
    return out


def descartar_fontes(fontes):
    for arm, acoes in fontes.values():
        for filho in list(arm.children):
            bpy.data.objects.remove(filho, do_unlink=True)
        bpy.data.objects.remove(arm, do_unlink=True)
        for a in acoes.values():
            if a.users == 0 or not a.use_fake_user:
                bpy.data.actions.remove(a)
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)


def armadura(nome_preferido=None):
    for o in bpy.data.objects:
        if o.type == 'ARMATURE' and (nome_preferido is None or o.name == nome_preferido):
            return o
    return None


def main():
    nome = sys.argv[sys.argv.index("--") + 1]
    bpy.context.scene.render.fps = A.FPS
    arm = armadura()
    # descarta as acoes de uma rodada anterior (a fonte da verdade e' o script)
    antigas = [a for a in bpy.data.actions if a.get("gerada_por_animar")]

    if nome == "dona_nice":
        import anim_dona_nice as M
        fala = bpy.data.actions.get("talk_loop")
        fontes = carregar_fontes(["maycow_lopes"])
        rig = A.Rig(arm, fontes["maycow_lopes"][0])
        M.clipes(rig, fontes, fala)
    elif nome == "dona_nice_monster":
        import anim_monstro as M
        fontes = carregar_fontes(["maycow_lopes", "zombie", "anti_lopes"])
        rig = A.Rig(arm, fontes["zombie"][0])
        M.clipes(rig, fontes)
    elif nome == "dona_nice_monster_fase_2":
        import anim_fase2 as M
        fontes = carregar_fontes(["husker"])
        rig = A.Rig(arm, fontes["husker"][0])
        M.clipes(rig, fontes)
    elif nome == "jonny":
        import anim_jonny as M
        fontes = {}
        rig = A.Rig(arm)
        M.clipes(rig, fontes)
    elif nome == "maycow":
        import anim_maycow as M
        fontes = carregar_fontes(["maycow_lopes"])
        rig = M.rig(arm, fontes)
        M.clipes(rig, fontes)
    else:
        raise SystemExit("personagem desconhecido: " + nome)

    novas = [a for a in bpy.data.actions if a.use_fake_user and a not in antigas
             and a.name not in ("idle_breathing", "talk_loop")]
    for a in novas:
        a["gerada_por_animar"] = True
    descartar_fontes(fontes)
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)

    # sobra de rodada anterior sai; os dois clipes de rosto do rig original
    # da Dona Nice ficam (o sussurro copia a boca do talk_loop) — o extrator
    # do Godot so' leva os clipes que ele conhece.
    for a in list(bpy.data.actions):
        if a not in novas and a.name not in ("idle_breathing", "talk_loop"):
            bpy.data.actions.remove(a)
    print("CLIPES", sorted(a.name for a in novas))

    bpy.ops.wm.save_mainfile()
    os.makedirs(SAIDA, exist_ok=True)
    objs = [arm] + [o for o in arm.children_recursive if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    destino = os.path.join(SAIDA, nome + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=destino, export_format='GLB', use_selection=True,
        export_yup=True, export_animations=True, export_animation_mode='ACTIONS',
        export_force_sampling=True, export_skins=True, export_def_bones=False,
        export_reset_pose_bones=True, export_image_format='AUTO')
    print("== exportado", destino)


main()
