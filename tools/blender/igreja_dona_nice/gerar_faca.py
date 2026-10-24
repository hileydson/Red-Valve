# -*- coding: utf-8 -*-
"""A faca da Dona Nice: lamina larga e velha, cabo de madeira amarrado.

    blender -b --factory-startup -P tools/blender/igreja_dona_nice/gerar_faca.py

Salva red-valve/assets/3d_model/npc/igreja/faca_ritual.glb

Convencao (Blender, Z cima): a origem e' o PONTO DE PEGADA (meio do cabo); a
lamina sobe pelo +Z, o fio fica no -Y. Exporta com export_yup=True, entao no
Godot a lamina aponta pro +Y local e o fio pro +Z — a cena pendura a faca
num pivo dentro da mao, girado no editor.

Tres materiais com nome fixo (o Godot pode trocar um por um):
  lamina  aco escovado, gasto
  cabo    madeira escura
  sangue  uma casca fina por cima de 2/3 da lamina, vermelho escuro molhado
"""

import math
import os

import bmesh
import bpy

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
SAIDA = os.path.join(RAIZ, "red-valve/assets/3d_model/npc/igreja/faca_ritual.glb")

COMP_LAMINA = 0.22
LARG_LAMINA = 0.042
ESP_LAMINA = 0.0045
COMP_CABO = 0.115


def material(nome, cor, metal, rug):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*cor, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rug
    return m


def perfil_lamina(n=18, t0=0.0):
    """Contorno da lamina no plano YZ: costas retas (+Y), fio curvo (-Y)
    subindo pra ponta. `t0` corta a base (a casca de sangue comeca no meio).
    Devolve lista de (y, z)."""
    pts = []
    for i in range(n + 1):
        t = t0 + (1 - t0) * i / n
        z = 0.02 + t * COMP_LAMINA
        # largura cai devagar e fecha na ponta (barriga curva)
        larg = LARG_LAMINA * (1.0 - t ** 2.6)
        pts.append((-larg + 0.006, z))
    pts.append((0.006, 0.02 + COMP_LAMINA))
    for i in range(n, -1, -1):
        t = t0 + (1 - t0) * i / n
        z = 0.02 + t * COMP_LAMINA
        pts.append((0.006 - 0.002 * t, z))
    return pts


def lamina(t0=0.0):
    bm = bmesh.new()
    contorno = perfil_lamina(t0=t0)
    frente = [bm.verts.new((ESP_LAMINA * 0.5, y, z)) for (y, z) in contorno]
    tras = [bm.verts.new((-ESP_LAMINA * 0.5, y, z)) for (y, z) in contorno]
    # o fio: os vertices do lado -Y vao pro meio da espessura (chanfro)
    meio = len(contorno) // 2
    for v in frente[:meio] + tras[:meio]:
        v.co.x *= 0.15
    bm.faces.new(frente)
    bm.faces.new(list(reversed(tras)))
    k = len(contorno)
    for i in range(k):
        a, b = i, (i + 1) % k
        bm.faces.new((frente[a], frente[b], tras[b], tras[a]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def caixa(bm, centro, tam):
    r = bmesh.ops.create_cube(bm, size=1.0)
    for v in r["verts"]:
        v.co = (v.co.x * tam[0] + centro[0], v.co.y * tam[1] + centro[1],
                v.co.z * tam[2] + centro[2])
    return r["verts"]


def objeto(nome, bm, mat):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def main():
    bpy.ops.wm.read_homefile(use_empty=True)
    m_lam = material("lamina", (0.55, 0.55, 0.56), 0.95, 0.38)
    m_cab = material("cabo", (0.10, 0.06, 0.035), 0.0, 0.75)
    m_san = material("sangue", (0.16, 0.0, 0.005), 0.0, 0.12)

    o_lam = objeto("lamina", lamina(), m_lam)

    # guarda + cabo (cilindro de 12 lados) + amarracao (anel)
    bm = bmesh.new()
    caixa(bm, (0, -0.012, 0.012), (0.014, 0.062, 0.016))
    cil = bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.0135,
                                radius2=0.0125, depth=COMP_CABO)
    for v in cil["verts"]:
        v.co.z += -COMP_CABO * 0.5 + 0.004
        v.co.y -= 0.012
    for i in range(4):
        anel = bmesh.ops.create_cone(bm, cap_ends=False, segments=12,
                                     radius1=0.0148, radius2=0.0148, depth=0.006)
        for v in anel["verts"]:
            v.co.z += -0.018 - i * 0.008
            v.co.y -= 0.012
    o_cab = objeto("cabo", bm, m_cab)
    for p in o_cab.data.polygons:
        p.use_smooth = True

    # sangue: copia da lamina, inflada um fio, so' da metade pra ponta
    bm = lamina(t0=0.33)
    for v in bm.verts:
        v.co.x *= 1.25
        v.co.y *= 1.02
    o_san = objeto("sangue", bm, m_san)

    # a ponta da lamina, de onde pinga o sangue (o Godot pendura as gotas aqui)
    ponta = bpy.data.objects.new("ponta", None)
    bpy.context.scene.collection.objects.link(ponta)
    ponta.location = (0, 0.004, 0.02 + COMP_LAMINA - 0.004)

    raiz = bpy.data.objects.new("faca_ritual", None)
    bpy.context.scene.collection.objects.link(raiz)
    for o in (o_lam, o_cab, o_san, ponta):
        o.parent = raiz

    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=SAIDA, export_format='GLB',
                              use_selection=True, export_yup=True)
    print("== exportado", SAIDA)


main()
