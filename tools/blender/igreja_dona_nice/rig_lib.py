# -*- coding: utf-8 -*-
"""Rig humanoide para as malhas de scan da cena da igreja (Jonny, Dona Nice
monstro, Dona Nice monstro fase 2).

Roda DENTRO do Blender (importado pelos scripts `montar_*.py`).

O ESQUELETO
-----------
Mesma hierarquia e mesmos nomes do rig que ja' existia na Dona Nice normal
(`Red-Valve-Blender/dona_nice/dona_nice.blend`): root, hips, spine, chest,
upper_chest, neck, head, shoulder/upper_arm/forearm/hand/fingers/thumb e
thigh/shin/foot/toe, com sufixo .L/.R. Os quatro personagens da cena falam a
mesma lingua, entao uma pose escrita pra um vale pros outros.

AS ARTICULACOES NAO SAO ADIVINHADAS
-----------------------------------
Cada `montar_*.py` passa um dicionario de pontos medidos na malha (fatias da
malha + render ortografico com grade, coordenadas do .glb importado: Z pra
cima, frente no -Y, +X e' a ESQUERDA do personagem). Daqui sai o esqueleto
exatamente em cima da carne.

OS PESOS
--------
Malha de scan nao e' fechada (cabelo solto, roupa em casca, pedaco solto) e o
"Automatic Weights" do Blender (bone heat) falha nelas em silencio — sobra
vertice sem peso nenhum, que fica parado no lugar quando o corpo anda. Por
isso o peso e' calculado num PROXY: uma copia remalhada por voxel (fechada e
manifold por construcao), onde o bone heat funciona; e depois TRANSFERIDO pra
malha de verdade pelo vertice mais proximo da superficie do proxy.

O ROLL DOS OSSOS
----------------
Todo osso tem o Z local virado pra FRENTE do personagem (-Y), menos pe' e
dedo do pe', que apontam pra frente e tem o Z pra CIMA. Consequencia, que os
scripts de pose usam: girar em +X local dobra o osso pra frente — tronco
inclina, coxa sobe, pescoco abaixa a cabeca.
"""

import bpy
import bmesh
from mathutils import Vector

# Ossos que deformam (os outros sao so' de controle).
NAO_DEFORMA = {"root"}


def limpar_cena():
    bpy.ops.wm.read_homefile(use_empty=True)
    cena = bpy.context.scene
    cena.render.fps = 30
    cena.unit_settings.system = 'METRIC'
    return cena


def importar_malha(caminho):
    """Importa o .glb e devolve a malha (juntando todas, se vier mais de uma)."""
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=caminho)
    novos = [o for o in bpy.data.objects if o not in antes]
    malhas = [o for o in novos if o.type == 'MESH']
    for o in novos:
        if o.type != 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action='DESELECT')
    for m in malhas:
        m.select_set(True)
    bpy.context.view_layer.objects.active = malhas[0]
    if len(malhas) > 1:
        bpy.ops.object.join()
    malha = bpy.context.view_layer.objects.active
    malha.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return malha


def decimar(malha, alvo_tris):
    """Reduz a malha a ~alvo_tris triangulos (Collapse: e' carne, nao movel)."""
    tris = sum(len(p.vertices) - 2 for p in malha.data.polygons)
    if tris <= alvo_tris:
        return tris
    mod = malha.modifiers.new("decimar", 'DECIMATE')
    mod.decimate_type = 'COLLAPSE'
    mod.ratio = alvo_tris / tris
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = malha
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return sum(len(p.vertices) - 2 for p in malha.data.polygons)


def normalizar_escala(malha, altura_m, pontos):
    """Escala a malha pra `altura_m` metros e poe a sola do pe' em z = 0.

    Os `pontos` (medidos no .glb original) sao convertidos junto e devolvidos.
    """
    zs = [v.co.z for v in malha.data.vertices]
    z0, z1 = min(zs), max(zs)
    s = altura_m / (z1 - z0)
    for v in malha.data.vertices:
        v.co = Vector((v.co.x * s, v.co.y * s, (v.co.z - z0) * s))
    malha.data.update()

    def conv(p):
        return Vector((p[0] * s, p[1] * s, (p[2] - z0) * s))

    novos = {}
    for k, v in pontos.items():
        if isinstance(v, (list, tuple)) and v and isinstance(v[0], (list, tuple)):
            novos[k] = [conv(p) for p in v]
        else:
            novos[k] = conv(v)
    return novos, s


def _osso(arm, nome, cabeca, cauda, pai=None, conectado=False, rolo_cima=False):
    eb = arm.edit_bones.new(nome)
    eb.head = cabeca
    eb.tail = cauda
    if pai:
        eb.parent = arm.edit_bones[pai]
        eb.use_connect = conectado
    eb.align_roll(Vector((0, 0, 1)) if rolo_cima else Vector((0, -1, 0)))
    eb.use_deform = nome not in NAO_DEFORMA
    return eb


def criar_esqueleto(nome, p, cadeias_extra=()):
    """Monta a armadura a partir dos pontos `p` (ja' em metros).

    Chaves esperadas (lado .L; o .R vem com chave propria `<osso>.R`):
      hips, spine, chest, upper_chest, neck, head, head_top,
      shoulder.L, upper_arm.L, forearm.L, hand.L, fingers_tip.L,
      thumb.L, thumb_tip.L, thigh.L, shin.L, foot.L, toe.L, toe_tip.L
    `cadeias_extra`: [(prefixo, osso_pai, [pontos...])] — tentaculos etc.
    """
    dados = bpy.data.armatures.new(nome)
    obj = bpy.data.objects.new(nome, dados)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    dados.display_type = 'STICK'
    obj.show_in_front = True
    bpy.ops.object.mode_set(mode='EDIT')
    a = dados

    chao = Vector((p["hips"].x, p["hips"].y, 0.0))
    _osso(a, "root", chao, chao + Vector((0, 0.10, 0)), rolo_cima=True)
    _osso(a, "hips", p["hips"], p["spine"], "root")
    _osso(a, "spine", p["spine"], p["chest"], "hips", True)
    _osso(a, "chest", p["chest"], p["upper_chest"], "spine", True)
    _osso(a, "upper_chest", p["upper_chest"], p["neck"], "chest", True)
    _osso(a, "neck", p["neck"], p["head"], "upper_chest", True)
    _osso(a, "head", p["head"], p["head_top"], "neck", True)

    for lado in ("L", "R"):
        def q(k):
            return p[k + "." + lado]
        _osso(a, "shoulder." + lado, q("shoulder"), q("upper_arm"), "upper_chest")
        _osso(a, "upper_arm." + lado, q("upper_arm"), q("forearm"),
              "shoulder." + lado, True)
        _osso(a, "forearm." + lado, q("forearm"), q("hand"), "upper_arm." + lado, True)
        mao = q("hand") + (q("fingers_tip") - q("hand")) * 0.45
        _osso(a, "hand." + lado, q("hand"), mao, "forearm." + lado, True)
        _osso(a, "fingers." + lado, mao, q("fingers_tip"), "hand." + lado, True)
        _osso(a, "thumb." + lado, q("thumb"), q("thumb_tip"), "hand." + lado)
        _osso(a, "thigh." + lado, q("thigh"), q("shin"), "hips")
        _osso(a, "shin." + lado, q("shin"), q("foot"), "thigh." + lado, True)
        _osso(a, "foot." + lado, q("foot"), q("toe"), "shin." + lado, True,
              rolo_cima=True)
        _osso(a, "toe." + lado, q("toe"), q("toe_tip"), "foot." + lado, True,
              rolo_cima=True)

    for (prefixo, pai, pts) in cadeias_extra:
        anterior = pai
        for i in range(len(pts) - 1):
            n = "%s_%d" % (prefixo, i + 1)
            _osso(a, n, pts[i], pts[i + 1], anterior, i > 0)
            anterior = n

    bpy.ops.object.mode_set(mode='OBJECT')
    return obj


def pesar(malha, arm, voxel=0.012):
    """Pesos por proxy de voxel + transferencia (ver cabecalho)."""
    bpy.ops.object.select_all(action='DESELECT')
    proxy = malha.copy()
    proxy.data = malha.data.copy()
    proxy.name = "proxy_pesos"
    bpy.context.scene.collection.objects.link(proxy)
    for m in list(proxy.modifiers):
        proxy.modifiers.remove(m)
    proxy.vertex_groups.clear()
    rem = proxy.modifiers.new("voxel", 'REMESH')
    rem.mode = 'VOXEL'
    rem.voxel_size = voxel
    rem.adaptivity = 0.0
    bpy.context.view_layer.objects.active = proxy
    proxy.select_set(True)
    bpy.ops.object.modifier_apply(modifier=rem.name)
    _so_a_maior_ilha(proxy)

    bpy.ops.object.select_all(action='DESELECT')
    proxy.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    vazios = _vertices_sem_peso(proxy)
    print("  proxy: %d vertices, %d sem peso" % (len(proxy.data.vertices), vazios))

    # transfere pro scan
    malha.vertex_groups.clear()
    for b in arm.data.bones:
        if b.use_deform:
            malha.vertex_groups.new(name=b.name)
    dt = malha.modifiers.new("pesos", 'DATA_TRANSFER')
    dt.object = proxy
    dt.use_vert_data = True
    dt.data_types_verts = {'VGROUP_WEIGHTS'}
    dt.vert_mapping = 'POLYINTERP_NEAREST'
    dt.layers_vgroup_select_src = 'ALL'
    dt.layers_vgroup_select_dst = 'NAME'
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = malha
    malha.select_set(True)
    bpy.ops.object.modifier_apply(modifier=dt.name)

    # 4 influencias no maximo (o que o glTF/Godot leva sem flag extra), somando 1
    bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
    bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL',
                                              lock_active=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    print("  scan: %d vertices sem peso" % _vertices_sem_peso(malha))

    bpy.data.objects.remove(proxy, do_unlink=True)

    malha.parent = arm
    malha.matrix_parent_inverse.identity()
    mod = malha.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm


def _so_a_maior_ilha(obj):
    """Apaga do proxy tudo o que nao for a maior peca conexa.

    O voxel fecha a malha, mas nao junta o que esta' longe: mecha de cabelo,
    tentaculo fino e roupa em casca dupla viram ilhas e cascas INTERNAS. Com
    uma casca dentro da outra o bone heat nao acha solucao e devolve zero pra
    TODOS os vertices (foi o que aconteceu nas duas monstros). As ilhas
    apagadas aqui nao ficam sem peso: na transferencia, o vertice delas pega o
    peso do ponto mais proximo do corpo.
    """
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    visto = set()
    ilhas = []
    for v in bm.verts:
        if v.index in visto:
            continue
        pilha = [v]
        ilha = []
        visto.add(v.index)
        while pilha:
            a = pilha.pop()
            ilha.append(a)
            for e in a.link_edges:
                b = e.other_vert(a)
                if b.index not in visto:
                    visto.add(b.index)
                    pilha.append(b)
        ilhas.append(ilha)
    ilhas.sort(key=len, reverse=True)
    for ilha in ilhas[1:]:
        bmesh.ops.delete(bm, geom=ilha, context='VERTS')
    bm.to_mesh(obj.data)
    bm.free()
    print("  proxy: %d ilhas, ficou a maior" % len(ilhas))


def _vertices_sem_peso(obj):
    n = 0
    for v in obj.data.vertices:
        if not any(g.weight > 1e-4 for g in v.groups):
            n += 1
    return n


def espelhar(p):
    """Completa os pontos .R a partir dos .L (x negado), quando nao vierem."""
    out = dict(p)
    for k, v in p.items():
        if k.endswith(".L"):
            r = k[:-2] + ".R"
            if r not in out:
                out[r] = (-v[0], v[1], v[2])
    return out


def salvar(caminho):
    bpy.ops.wm.save_as_mainfile(filepath=caminho)


def exportar_glb(caminho, objetos):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objetos:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=caminho, export_format='GLB', use_selection=True,
        export_apply=False, export_yup=True, export_animations=True,
        export_animation_mode='ACTIONS', export_force_sampling=True,
        export_optimize_animation_size=False, export_skins=True,
        export_def_bones=False, export_image_format='AUTO')
