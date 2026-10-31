# -*- coding: utf-8 -*-
"""Grava os clipes do fim do Capitulo 4 / comeco do 5 e exporta os .glb.

    blender -b Red-Valve-Blender/maycow_cenas/maycow_cenas.blend \\
        -P tools/blender/capitulo_4/animar_capitulo_4.py -- normal
    blender -b --factory-startup \\
        -P tools/blender/capitulo_4/animar_capitulo_4.py -- parasita

`normal`: o Maycow normal (o rig Meshy do `maycow_cenas.blend`, o mesmo do
duble da igreja e do modelo do jogador). O .blend NAO e' salvo: as acoes da
igreja que moram nele continuam como estao.
`parasita`: o Maycow de primeira pessoa, importado do proprio
`player/Maycow Lopes/maycow_lopes.glb` num Blender vazio.

Sai SO' o esqueleto (com um triangulo de pele, ver `_ancora_de_pele`) e os
clipes novos:
    red-valve/assets/3d_model/npc/capitulo_4/maycow_normal_clipes.glb
    red-valve/assets/3d_model/npc/capitulo_4/maycow_parasita_clipes.glb
As trilhas saem como "Armature/Skeleton3D:<osso>", as mesmas do
`maycow_clipes.tres` da igreja: no Godot a biblioteca e' somada ao
AnimationPlayer do ator (ver `capitulo_1_escola._ator`).

`--previa <pasta> [--quadros clipe:q,q ...]` no lugar de exportar: fotografa
cada clipe (lado, cima, tres-quartos e frente,
com o chao em z=0) em alguns quadros e mede o ponto mais baixo da pele.

Quem chama em ordem e importa: `construir.sh` (mesma pasta).
"""

import os
import sys

sys.dont_write_bytecode = True

import bpy  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.path.insert(1, os.path.join(os.path.dirname(AQUI), "igreja_dona_nice"))
import anim_comum as A  # noqa: E402
import retarget_lib as RT  # noqa: E402
import anim_maycow  # noqa: E402
import anim_capitulo_4 as M  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
MODELOS = os.path.join(RAIZ, "red-valve/assets/3d_model")
SAIDA = os.path.join(MODELOS, "npc/capitulo_4")
PARASITA = os.path.join(MODELOS, "player/Maycow Lopes/maycow_lopes.glb")


def armadura():
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            return o
    return None


def _ancora_de_pele(arm):
    """Um triangulo minusculo preso ao quadril.

    Sem nenhuma malha com pele, o glTF exporta os ossos como nos comuns e o
    Godot importa uma arvore de Node3D em vez de um Skeleton3D — as trilhas
    nao bateriam com as do ator ("Armature/Skeleton3D:Hips")."""
    dados = bpy.data.meshes.new("ancora")
    dados.from_pydata([(0, 0, 0), (0.001, 0, 0), (0, 0.001, 0)], [], [(0, 1, 2)])
    obj = bpy.data.objects.new("ancora", dados)
    bpy.context.scene.collection.objects.link(obj)
    grupo = obj.vertex_groups.new(name="Hips")
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
    # os clipes de captura do .glb nao vao junto
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    return arm


def _exportar(arm, novas, destino):
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
    # so' os clipes desta rodada (as acoes da igreja saem da memoria; o
    # .blend nao e' salvo)
    for a in list(bpy.data.actions):
        if a not in novas:
            bpy.data.actions.remove(a)
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


# ------------------------------------------------------------------ previa
def _previa(arm, novas, pasta, pedidos, mascara=None):
    """Lado, cima e tres-quartos de alguns quadros de cada clipe, com o chao
    (uma laje fina, z<=0) e a medida do ponto mais baixo da pele.
    `pedidos`: {clipe: [quadros]} — sem o clipe, cinco quadros espalhados;
    com pedidos, so' os clipes pedidos."""
    from mathutils import Vector
    os.makedirs(pasta, exist_ok=True)
    cena = bpy.context.scene
    for o in cena.objects:
        if o.type == 'MESH' and o.parent != arm:
            o.hide_render = True
    malha = M.malha_do_rig(type("R", (), {"arm": arm})())
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
    cena.render.resolution_x = 560
    cena.render.resolution_y = 560
    cam = bpy.data.objects.new("cam_previa", bpy.data.cameras.new("cam_previa"))
    cena.collection.objects.link(cam)
    cena.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 2.3
    arm.animation_data_create()
    vistas = (("lado", Vector((1, 0, 0))), ("cima", Vector((0.0, 0.001, 1))),
              ("tres", Vector((0.75, -0.75, 0.35)).normalized()),
              ("frente", Vector((0, -1, 0.05)).normalized()))
    for acao in novas:
        if pedidos and acao.name not in pedidos:
            continue
        arm.animation_data.action = acao
        if acao.slots:
            arm.animation_data.action_slot = acao.slots[0]
        f0, f1 = (int(x) for x in acao.frame_range)
        quadros = pedidos.get(acao.name) or sorted({f0, f0 + (f1 - f0) // 4, (f0 + f1) // 2,
                                                    f0 + 3 * (f1 - f0) // 4, f1})
        for f in quadros:
            cena.frame_set(f)
            z = M.z_minimo(malha, mascara)
            print("CHAO %s q%03d z_min=%+.3f" % (acao.name, f, z))
            alvo = Vector((0, 0, 0.55))
            for nome, d in vistas:
                cam.location = alvo + d * 10
                cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
                cena.render.filepath = os.path.join(
                    pasta, "%s_%03d_%s.png" % (acao.name, f, nome))
                bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    nome = argv[0]
    pasta_previa = argv[argv.index("--previa") + 1] if "--previa" in argv else None
    # --quadros levantar_devagar:0,60,120 agonia_fogo:0,12 ...
    pedidos = {}
    if "--quadros" in argv:
        for item in argv[argv.index("--quadros") + 1:]:
            clipe, qs = item.split(":")
            pedidos[clipe] = [int(x) for x in qs.split(",")]
    if nome == "parasita":
        arm = _abrir_parasita()
    elif nome == "normal":
        arm = armadura()
    else:
        raise SystemExit("personagem desconhecido: " + nome)
    bpy.context.scene.render.fps = A.FPS
    antes = set(bpy.data.actions)
    rig = A.Rig(arm, None, mapa=RT.MAPA_MESHY, nomes=anim_maycow.PAPEIS)
    if nome == "normal":
        info = M.clipes_normal(rig)
    else:
        info = M.clipes_parasita(rig)
    novas = [a for a in bpy.data.actions if a not in antes]
    for a in novas:
        a.use_fake_user = True
    print("CLIPES", sorted("%s(%.2fs)" % (a.name, (a.frame_range[1] - a.frame_range[0]) / A.FPS)
                           for a in novas))
    if nome == "normal":
        print("INFO tempos do levantar_devagar", info["tempos_levantar"])
    if pasta_previa:
        _previa(arm, novas, pasta_previa, pedidos, getattr(rig, "mascara_chao", None))
        return
    _exportar(arm, novas, os.path.join(SAIDA, "maycow_%s_clipes.glb" % nome))


main()
