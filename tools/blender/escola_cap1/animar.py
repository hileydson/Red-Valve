# -*- coding: utf-8 -*-
"""Gera os clipes do Capitulo 1 (escola) e exporta os .glb do jogo.

    blender -b <arquivo>.blend -P tools/blender/escola_cap1/animar.py -- <nome>

<nome>:
  grizzolito | grizzolito_monstro_1 | grizzolito_monstro_2
      abre Red-Valve-Blender/grizzolito/<nome>.blend, grava as acoes NELE e
      exporta malha + esqueleto + clipes:
      red-valve/assets/3d_model/enemies/anti_lopes_members/grizzolito/<nome>.glb
  dona_nice_escola | jonny_escola
      abre o .blend da IGREJA (dona_nice_cena.blend / jonny.blend), cria os
      clipes novos e exporta SO' o esqueleto com eles:
      red-valve/assets/3d_model/npc/escola/<nome>_clipes.glb
      O .blend NAO e' salvo: a igreja continua exatamente como estava.

Quem chama tudo em ordem e importa: `construir.sh` (mesma pasta).
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
SAIDA_GRIZ = os.path.join(MODELOS, "enemies/anti_lopes_members/grizzolito")
SAIDA_ESCOLA = os.path.join(MODELOS, "npc/escola")

FONTES = {
    "zombie": "enemies/zombie.glb",
    "maycow_lopes": "player/Maycow Lopes/maycow_lopes.glb",
    "anti_lopes": "enemies/the_anti_lopes.glb",
}

# Os monstros sao mais pesados: parado, andar e rugido mais lentos.
LENTO = {"grizzolito": 1.0, "grizzolito_monstro_1": 0.8, "grizzolito_monstro_2": 0.7}


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


def _ancora_de_pele(arm):
    """Um triangulo minusculo preso ao quadril.

    Sem nenhuma malha com pele, o glTF exporta os ossos como nos comuns e o
    Godot importa uma arvore de Node3D em vez de um Skeleton3D — as trilhas
    viram "rig/hips/spine:rotation" e nao batem com as do ator da igreja
    ("rig/Skeleton3D:spine"). O triangulo so' existe pra a pele existir."""
    dados = bpy.data.meshes.new("ancora")
    dados.from_pydata([(0, 0, 0), (0.001, 0, 0), (0, 0.001, 0)], [], [(0, 1, 2)])
    obj = bpy.data.objects.new("ancora", dados)
    bpy.context.scene.collection.objects.link(obj)
    grupo = obj.vertex_groups.new(name="hips")
    grupo.add([0, 1, 2], 1.0, 'REPLACE')
    obj.parent = arm
    mod = obj.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    return obj


def armadura():
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            return o
    return None


def main():
    nome = sys.argv[sys.argv.index("--") + 1]
    bpy.context.scene.render.fps = A.FPS
    arm = armadura()
    antes = set(bpy.data.actions)
    griz = nome.startswith("grizzolito")

    if griz:
        import anim_grizzolito as M
        fontes = carregar_fontes(["maycow_lopes", "zombie", "anti_lopes"])
        rig = A.Rig(arm, fontes["maycow_lopes"][0])
        M.clipes(rig, fontes, LENTO[nome])
    elif nome == "dona_nice_escola":
        import anim_escola as M
        fontes = carregar_fontes(["maycow_lopes"])
        rig = A.Rig(arm, fontes["maycow_lopes"][0])
        M.clipes_dona_nice(rig, fontes)
    elif nome == "jonny_escola":
        import anim_escola as M
        fontes = carregar_fontes(["maycow_lopes"])
        rig = A.Rig(arm, fontes["maycow_lopes"][0])
        M.clipes_jonny(rig, fontes)
    else:
        raise SystemExit("personagem desconhecido: " + nome)

    novas = [a for a in bpy.data.actions if a.use_fake_user and a not in antes]
    descartar_fontes(fontes)
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
    # so' os clipes desta rodada vao pro .glb (as acoes antigas da igreja
    # saem da memoria; o arquivo nao e' salvo nesses casos)
    for a in list(bpy.data.actions):
        if a not in novas:
            bpy.data.actions.remove(a)
    print("CLIPES", sorted(a.name for a in novas))

    if griz:
        bpy.ops.wm.save_mainfile()
        destino = os.path.join(SAIDA_GRIZ, nome + ".glb")
        objs = [arm] + [o for o in arm.children_recursive if o.type == 'MESH']
    else:
        destino = os.path.join(SAIDA_ESCOLA, nome + "_clipes.glb")
        objs = [arm, _ancora_de_pele(arm)]
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=destino, export_format='GLB', use_selection=True,
        export_yup=True, export_animations=True, export_animation_mode='ACTIONS',
        export_force_sampling=True, export_skins=True, export_def_bones=False,
        export_reset_pose_bones=True, export_image_format='AUTO')
    print("== exportado", destino)


main()
