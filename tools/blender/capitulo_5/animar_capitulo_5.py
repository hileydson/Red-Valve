# -*- coding: utf-8 -*-
"""Grava os clipes do Capitulo 5 e exporta os .glb do jogo.

    blender -b Red-Valve-Blender/jimmy/jimmy.blend \\
        -P tools/blender/capitulo_5/animar_capitulo_5.py -- jimmy
    blender -b Red-Valve-Blender/jonny/jonny.blend \\
        -P tools/blender/capitulo_5/animar_capitulo_5.py -- jonny
    blender -b --factory-startup \\
        -P tools/blender/capitulo_5/animar_capitulo_5.py -- parasita

`jimmy`: o rig do `montar_jimmy.py`. Grava as acoes NO .blend e exporta
malha + esqueleto + clipes:
    red-valve/assets/3d_model/npc/capitulo_5/jimmy.glb
`jonny`: o rig da igreja. O .blend NAO e' salvo; sai SO' o esqueleto com os
clipes novos (somados no Godot ao AnimationPlayer do ator, como os da escola):
    red-valve/assets/3d_model/npc/capitulo_5/jonny_clipes.glb
`parasita`: o Maycow da arena, importado do proprio `maycow_lopes.glb` num
Blender vazio. Sai so' o esqueleto:
    red-valve/assets/3d_model/npc/capitulo_5/maycow_parasita_clipes.glb

`--previa <pasta> [--quadros clipe:q,q ...]` no lugar de exportar: fotografa
cada clipe (lado, cima, tres-quartos e frente, com o chao em z=0).

Os clipes estao descritos no topo de `anim_capitulo_5.py`. Quem chama em ordem
e importa: `construir.sh` (mesma pasta).
"""

import os
import sys

sys.dont_write_bytecode = True

import bpy  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.path.insert(1, os.path.join(os.path.dirname(AQUI), "igreja_dona_nice"))
sys.path.insert(2, os.path.join(os.path.dirname(AQUI), "capitulo_4"))
import anim_comum as A  # noqa: E402
import retarget_lib as RT  # noqa: E402
import anim_maycow  # noqa: E402
import anim_capitulo_5 as M  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
MODELOS = os.path.join(RAIZ, "red-valve/assets/3d_model")
SAIDA = os.path.join(MODELOS, "npc/capitulo_5")
PARASITA = os.path.join(MODELOS, "player/Maycow Lopes/maycow_lopes.glb")
FONTE_CAPTURA = os.path.join(MODELOS, "player/Maycow Lopes/maycow_lopes.glb")


def armadura():
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            return o
    return None


def deformacao(arm, ligada):
    """Liga/desliga a armadura nas malhas (gravar com a malha deformando junto
    reavalia a pele inteira a cada quadro; a pose so' precisa dos ossos)."""
    for m in arm.children_recursive:
        if m.type != 'MESH':
            continue
        for mod in m.modifiers:
            if mod.type == 'ARMATURE':
                mod.show_viewport = ligada


def _ancora_de_pele(arm, osso):
    """Um triangulo minusculo preso ao quadril: sem malha com pele o glTF
    exporta os ossos como nos comuns e o Godot nao monta o Skeleton3D."""
    dados = bpy.data.meshes.new("ancora")
    dados.from_pydata([(0, 0, 0), (0.001, 0, 0), (0, 0.001, 0)], [], [(0, 1, 2)])
    obj = bpy.data.objects.new("ancora", dados)
    bpy.context.scene.collection.objects.link(obj)
    grupo = obj.vertex_groups.new(name=osso)
    grupo.add([0, 1, 2], 1.0, 'REPLACE')
    obj.parent = arm
    mod = obj.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    return obj


def _abrir_parasita():
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.context.scene.render.fps = A.FPS
    bpy.ops.import_scene.gltf(filepath=PARASITA)
    arm = armadura()
    if arm.animation_data:
        arm.animation_data.action = None
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    return arm


def _fonte_de_captura():
    return RT.importar_fonte(FONTE_CAPTURA)


def _descartar_fonte(fonte):
    arm, acoes = fonte
    for filho in list(arm.children):
        bpy.data.objects.remove(filho, do_unlink=True)
    bpy.data.objects.remove(arm, do_unlink=True)
    for a in acoes.values():
        if a.name in bpy.data.actions and not a.use_fake_user:
            bpy.data.actions.remove(a)
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)


def _zerar_pose(arm):
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)


def _exportar(objs, destino, aplicar=False):
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=destino, export_format='GLB', use_selection=True,
        export_yup=True, export_apply=aplicar,
        export_animations=True, export_animation_mode='ACTIONS',
        export_force_sampling=True, export_skins=True, export_def_bones=False,
        export_reset_pose_bones=True, export_image_format='AUTO')
    print("== exportado", destino)


# ------------------------------------------------------------------ previa
def _previa(arm, novas, pasta, pedidos):
    from mathutils import Vector
    os.makedirs(pasta, exist_ok=True)
    cena = bpy.context.scene
    deformacao(arm, True)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.02))
    chao = bpy.context.active_object
    chao.name = "chao_previa"
    chao.scale = (4.0, 4.0, 0.04)
    mat = bpy.data.materials.new("chao_previa")
    mat.diffuse_color = (0.2, 0.45, 0.25, 1)
    chao.data.materials.append(mat)
    w = bpy.data.worlds.new("w_previa")
    cena.world = w
    w.color = (0.55, 0.55, 0.6)
    cena.render.engine = 'BLENDER_WORKBENCH'
    cena.display.shading.light = 'STUDIO'
    cena.display.shading.color_type = 'MATERIAL'
    cena.render.resolution_x = 480
    cena.render.resolution_y = 480
    cam = bpy.data.objects.new("cam_previa", bpy.data.cameras.new("cam_previa"))
    cena.collection.objects.link(cam)
    cena.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 2.3
    arm.animation_data_create()
    vistas = (("lado", Vector((1, 0, 0))), ("tres", Vector((0.75, -0.75, 0.35)).normalized()),
              ("frente", Vector((0, -1, 0.05)).normalized()))
    for acao in novas:
        if pedidos and acao.name not in pedidos:
            continue
        arm.animation_data.action = acao
        if acao.slots:
            arm.animation_data.action_slot = acao.slots[0]
        f0, f1 = (int(x) for x in acao.frame_range)
        quadros = pedidos.get(acao.name) or sorted({f0, (f0 + f1) // 2})
        for f in quadros:
            cena.frame_set(f)
            alvo = Vector((0, 0, 0.9))
            for nome, d in vistas:
                cam.location = alvo + d * 10
                cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
                cena.render.filepath = os.path.join(pasta, "%s_%03d_%s.png" % (acao.name, f, nome))
                bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    nome = argv[0]
    pasta_previa = argv[argv.index("--previa") + 1] if "--previa" in argv else None
    pedidos = {}
    if "--quadros" in argv:
        for item in argv[argv.index("--quadros") + 1:]:
            clipe, qs = item.split(":")
            pedidos[clipe] = [int(x) for x in qs.split(",")]
    bpy.context.scene.render.fps = A.FPS

    if nome == "parasita":
        arm = _abrir_parasita()
    else:
        arm = armadura()
    antes = set(bpy.data.actions)
    if nome == "jimmy":
        # as acoes antigas do Jimmy saem: o .blend guarda so' as desta rodada
        for a in list(bpy.data.actions):
            bpy.data.actions.remove(a)
        antes = set()
    deformacao(arm, False)
    fonte = None
    if nome == "jimmy":
        fonte = _fonte_de_captura()
        rig = A.Rig(arm, fonte[0])
        M.clipes_jimmy(rig, {"maycow_lopes": fonte})
    elif nome == "jonny":
        rig = A.Rig(arm)
        M.clipes_jonny(rig)
    elif nome == "parasita":
        rig = A.Rig(arm, None, mapa=RT.MAPA_MESHY, nomes=anim_maycow.PAPEIS)
        M.clipes_parasita(rig)
    else:
        raise SystemExit("personagem desconhecido: " + nome)

    novas = [a for a in bpy.data.actions if a not in antes and (fonte is None or a not in fonte[1].values())]
    for a in novas:
        a.use_fake_user = True
    if fonte:
        _descartar_fonte(fonte)
    novas = [a for a in novas if a.name in bpy.data.actions]
    print("CLIPES", sorted("%s(%.2fs)" % (a.name, (a.frame_range[1] - a.frame_range[0]) / A.FPS)
                           for a in novas))
    if pasta_previa:
        _previa(arm, novas, pasta_previa, pedidos)
        return

    _zerar_pose(arm)
    if nome == "jimmy":
        for a in list(bpy.data.actions):
            if a not in novas:
                bpy.data.actions.remove(a)
        deformacao(arm, True)
        bpy.ops.wm.save_mainfile()
        deformacao(arm, False)
        malhas = [o for o in arm.children_recursive if o.type == 'MESH']
        _exportar([arm] + malhas, os.path.join(SAIDA, "jimmy.glb"))
        return
    # so' os clipes desta rodada (as acoes da igreja saem da memoria; o
    # .blend nao e' salvo)
    for a in list(bpy.data.actions):
        if a not in novas:
            bpy.data.actions.remove(a)
    osso = "hips" if "hips" in arm.data.bones else "Hips"
    destino = os.path.join(SAIDA, "%s_clipes.glb" % ("jonny" if nome == "jonny" else "maycow_parasita"))
    _exportar([arm, _ancora_de_pele(arm, osso)], destino)


main()
