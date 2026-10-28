# -*- coding: utf-8 -*-
"""Modela as duas seringas do jogo (sangue e magia) do zero e exporta os .glb.

    blender -b -P tools/blender/seringa/gerar_seringa.py
    /home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64 --headless --path red-valve --import

POR QUE ISTO EXISTE
-------------------
A seringa de antes era o "syringe" CC0 do OpenGameArt repintado: embolo de
secao quadrada, aba chata de caixa, cilindro de 8 lados e o liquido parando no
meio do tubo. O usuario achou "quadrada e feia". Esta e' uma seringa de 5 ml de
verdade, feita quase toda no torno (perfil girado em volta do eixo):

    pressor do polegar -> haste em cruz -> aba dos dedos -> tubo transparente
    com a escala impressa (0,2 ml, numeros de 1 a 5) -> rolha de borracha com
    os dois aneis -> liquido ate' o bico -> canhao colorido -> agulha com o
    bisel cortado em plano.

As duas saem do MESMO desenho; so' muda a cor do liquido e do canhao (rosa no
sangue, violeta na magia — as cores de canhao de verdade das agulhas 18G e
24G, que ajudam a separar as duas no inventario).

CONVENCAO
---------
Autorado em milimetros no espaco do Blender (X = comprimento, agulha pro +X,
Z pra cima) e exportado com o `export_yup` PADRAO (True). No fim tudo e'
escalado pra 14 cm (o tamanho da seringa antiga: a mesa da Dona Nice, a igreja
e o gerador de icones ja' estao acertados pra ele), centrado no X e assentado
com o ponto mais baixo em y = 0 do jogo.

Os materiais saem do Blender so' pra previa: depois do export o JSON do .glb e'
reescrito com os valores exatos (`MATERIAIS`), porque o exportador decide
alphaMode/doubleSided por regras que mudam de versao pra versao.
"""

import json
import math
import os
import struct

import bmesh
import bpy
from mathutils import Matrix, Vector

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJETO = os.path.normpath(os.path.join(AQUI, "..", "..", "..", "red-valve"))
OBJETOS = os.path.join(PROJETO, "assets", "3d_model", "objects")

COMPRIMENTO_FINAL = 0.14  # metros
LADOS = 48                # do torno

# ----------------------------------------------------------------- medidas (mm)
R_TUBO = 6.6          # raio externo do tubo
R_TUBO_IN = 5.9       # raio interno
X_TUBO_TRAS = 0.0     # boca do tubo, colada na aba
X_TUBO_FRENTE = 61.0  # onde o tubo comeca a fechar no bico
X_ZERO = 60.6         # linha do zero da escala
MM_POR_ML = 1000.0 / (math.pi * R_TUBO_IN ** 2)
X_ROLHA = 16.0        # traseira da rolha (o embolo esta' meio puxado: ~4 ml)
X_PRESSOR = -44.0     # frente do pressor do polegar


# ============================================================ utilidades

def limpar_cena():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for b in list(coll):
            coll.remove(b)


def novo_material(nome, cor, alpha=1.0, metal=0.0, rugos=0.5):
    m = bpy.data.materials.new(nome)
    m.use_backface_culling = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (cor[0], cor[1], cor[2], 1.0)
    bsdf.inputs["Alpha"].default_value = alpha
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rugos
    return m


def objeto_de(bm, nome, materiais, angulo_quina=40.0):
    """bmesh -> objeto, com sombreado suave e quina viva acima do angulo."""
    limite = math.radians(angulo_quina)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > limite:
            e.smooth = False
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    for m in materiais:
        me.materials.append(m)
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def torno(bm, perfil, lados=LADOS, mat=0):
    """Gira um perfil fechado [(x, r), ...] em volta do eixo X. Ponto com r = 0
    vira um vertice so' (o leque fecha a ponta)."""
    aneis = []
    for x, r in perfil:
        if r < 1e-6:
            v = bm.verts.new((x, 0.0, 0.0))
            aneis.append([v] * lados)
        else:
            aneis.append([bm.verts.new((x, r * math.cos(2 * math.pi * i / lados),
                                        r * math.sin(2 * math.pi * i / lados)))
                          for i in range(lados)])
    faces = []
    m = len(aneis)
    for a in range(m):
        A, B = aneis[a], aneis[(a + 1) % m]
        for i in range(lados):
            j = (i + 1) % lados
            unicos = []
            for v in (A[i], A[j], B[j], B[i]):
                if v not in unicos:
                    unicos.append(v)
            if len(unicos) >= 3:
                f = bm.faces.new(unicos)
                f.material_index = mat
                faces.append(f)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return faces


def caixa(bm, centro, tamanho, giro_x=0.0, mat=0):
    mt = (Matrix.Translation(Vector(centro)) @ Matrix.Rotation(giro_x, 4, "X")
          @ Matrix.Diagonal((tamanho[0], tamanho[1], tamanho[2], 1.0)))
    r = bmesh.ops.create_cube(bm, size=1.0, matrix=mt)
    for v in r["verts"]:
        for f in v.link_faces:
            f.material_index = mat


# ============================================================ as pecas

def peca_tubo(mats, nome_tinto):
    """Tubo transparente: parede com espessura, ombro e o bico luer.

    Na frente do liquido o vidro e' TINTO da cor dele. O Godot mistura o
    transparente em espaco linear: um vidro claro de alpha 0,12 somava ~0,16
    linear de branco sobre um vermelho de verde zero — na tela, +110 de 255 no
    verde, e o sangue virava rosa. Tinto, o brilho do vidro soma cor, nao cinza.
    """
    bm = bmesh.new()
    x_liq = X_ROLHA + 5.6  # onde o liquido encosta na parede
    perfil = [
        (X_TUBO_TRAS, R_TUBO_IN), (X_TUBO_TRAS, R_TUBO), (x_liq, R_TUBO),
        (X_TUBO_FRENTE - 0.5, R_TUBO), (X_TUBO_FRENTE + 1.0, 6.25),
        (X_TUBO_FRENTE + 2.4, 4.6), (X_TUBO_FRENTE + 3.4, 2.7),
        (X_TUBO_FRENTE + 4.0, 2.15), (X_TUBO_FRENTE + 12.0, 1.85),
        (X_TUBO_FRENTE + 12.0, 0.7), (X_TUBO_FRENTE + 3.0, 0.7),
        (X_TUBO_FRENTE + 1.8, 3.0), (X_TUBO_FRENTE + 0.8, 5.0),
        (X_TUBO_FRENTE, R_TUBO_IN), (x_liq, R_TUBO_IN),
    ]
    for f in torno(bm, perfil):
        if f.calc_center_median().x > x_liq:
            f.material_index = 1
    return objeto_de(bm, "tubo", [mats["vidro_seringa"], mats[nome_tinto]])


def _estadio(t, meio, raio):
    """Contorno de estadio (retangulo de pontas redondas) no plano YZ, t em
    [0, 1). Mesmo t em dois raios diferentes cai no mesmo lugar do desenho —
    e' o que deixa arredondar a borda ligando aneis."""
    arco = math.pi * raio
    reta = 2 * meio
    total = 2 * arco + 2 * reta
    s = t * total
    if s < arco:  # ponta do +Y
        a = -math.pi / 2 + s / raio
        return Vector((meio + raio * math.cos(a), raio * math.sin(a)))
    s -= arco
    if s < reta:  # lado de cima
        return Vector((meio - s, raio))
    s -= reta
    if s < arco:  # ponta do -Y
        a = math.pi / 2 + s / raio
        return Vector((-meio + raio * math.cos(a), raio * math.sin(a)))
    s -= arco
    return Vector((-meio + s, -raio))


def peca_aba(mats):
    """Aba dos dedos: placa de estadio com o furo do tubo e a borda boleada."""
    bm = bmesh.new()
    n = 72
    meio, raio, quebra = 8.0, 7.4, 0.5
    x_frente, x_tras = X_TUBO_TRAS + 0.2, X_TUBO_TRAS - 1.8
    ts = [i / n for i in range(n)]
    camadas = [  # (x, encolhe a borda)
        (x_frente, quebra), (x_frente - 0.4, 0.0),
        (x_tras + 0.4, 0.0), (x_tras, quebra),
    ]
    aneis = []
    for x, d in camadas:
        aneis.append([bm.verts.new((x, p.x, p.y))
                      for p in (_estadio(t, meio, raio - d) for t in ts)])
    furo = []
    for x in (x_frente, x_tras):
        anel = []
        for t in ts:
            p = _estadio(t, meio, raio)
            a = math.atan2(p.y, p.x)
            anel.append(bm.verts.new((x, R_TUBO_IN * math.cos(a), R_TUBO_IN * math.sin(a))))
        furo.append(anel)
    faces = []
    for i in range(n):
        j = (i + 1) % n
        for a in range(3):  # borda boleada
            A, B = aneis[a], aneis[a + 1]
            faces.append(bm.faces.new((A[i], A[j], B[j], B[i])))
        faces.append(bm.faces.new((furo[0][i], furo[0][j], aneis[0][j], aneis[0][i])))
        faces.append(bm.faces.new((aneis[3][i], aneis[3][j], furo[1][j], furo[1][i])))
        faces.append(bm.faces.new((furo[1][i], furo[1][j], furo[0][j], furo[0][i])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return objeto_de(bm, "aba", [mats["aba_seringa"]], angulo_quina=60.0)


def peca_embolo(mats):
    """Haste em cruz, pressor do polegar e o disco que encosta na rolha."""
    bm = bmesh.new()
    # pressor do polegar, levemente abaulado no meio
    torno(bm, [(X_PRESSOR - 2.0, 0.0), (X_PRESSOR - 2.2, 4.0), (X_PRESSOR - 2.0, 6.9),
               (X_PRESSOR - 1.6, 7.4), (X_PRESSOR - 0.4, 7.4), (X_PRESSOR, 6.9),
               (X_PRESSOR, 0.0)])
    # disco da frente (empurra a rolha)
    torno(bm, [(X_ROLHA - 1.6, 0.0), (X_ROLHA - 1.6, 5.1), (X_ROLHA - 1.2, 5.4),
               (X_ROLHA, 5.4), (X_ROLHA, 0.0)])
    # um disco de reforco no meio da haste, como nas de verdade
    xm = X_PRESSOR + 10.0
    torno(bm, [(xm, 0.0), (xm, 4.9), (xm + 1.0, 4.9), (xm + 1.0, 0.0)])
    # haste em cruz
    comp = (X_ROLHA - 1.6) - X_PRESSOR
    cx = X_PRESSOR + comp / 2
    # em X (45 graus): deitada na mesa ou no icone as duas aletas aparecem, e
    # ela le como haste em cruz e nao como um cilindro macico
    for g in (math.pi / 4, 3 * math.pi / 4):
        caixa(bm, (cx, 0.0, 0.0), (comp, 9.4, 1.1), giro_x=g)
    return objeto_de(bm, "embolo", [mats["plastico_embolo"]])


def peca_rolha(mats):
    """Rolha de borracha preta com os dois aneis de vedacao e a ponta conica."""
    bm = bmesh.new()
    s = X_ROLHA
    torno(bm, [(s, 0.0), (s, 5.2), (s + 0.4, 5.85), (s + 1.7, 5.85), (s + 2.1, 5.35),
               (s + 3.0, 5.35), (s + 3.4, 5.85), (s + 4.7, 5.85), (s + 5.1, 5.5),
               (s + 6.6, 2.4), (s + 7.0, 0.0)])
    return objeto_de(bm, "rolha", [mats["borracha"]], angulo_quina=35.0)


def peca_liquido(mats, nome_mat):
    """Do cone da rolha ate' a ponta do bico, sem bolha."""
    bm = bmesh.new()
    s = X_ROLHA
    torno(bm, [(s + 7.05, 0.0), (s + 6.65, 2.4), (s + 5.15, 5.55), (s + 5.6, 5.82),
               (X_TUBO_FRENTE, 5.82), (X_TUBO_FRENTE + 0.8, 4.95),
               (X_TUBO_FRENTE + 1.8, 2.95), (X_TUBO_FRENTE + 3.0, 0.62),
               (X_TUBO_FRENTE + 11.9, 0.62), (X_TUBO_FRENTE + 11.9, 0.0)])
    return objeto_de(bm, "liquido", [mats[nome_mat]], angulo_quina=50.0)


def peca_canhao(mats, nome_mat):
    """Canhao da agulha: encaixa no bico, afina ate' a agulha e tem 4 aletas."""
    bm = bmesh.new()
    x0 = X_TUBO_FRENTE + 6.0
    torno(bm, [(x0, 0.0), (x0, 3.5), (x0 + 0.6, 3.85), (x0 + 7.0, 3.1),
               (x0 + 9.0, 2.4), (x0 + 12.5, 1.15), (x0 + 13.2, 0.75),
               (x0 + 13.2, 0.0)], lados=32)
    # cada caixa atravessa o eixo e da' duas aletas opostas
    for k in range(2):
        caixa(bm, (x0 + 3.4, 0.0, 0.0), (5.0, 0.7, 8.6), giro_x=k * math.pi / 2 + math.pi / 4)
    return objeto_de(bm, "canhao", [mats[nome_mat]])


def peca_agulha(mats):
    """Agulha 21G (0,8 mm) de 1 polegada, com o bisel cortado num plano."""
    bm = bmesh.new()
    r, lados = 0.41, 12
    x0 = X_TUBO_FRENTE + 17.0
    x_fim, bisel = x0 + 25.4, 2.6
    tras, frente = [], []
    for i in range(lados):
        a = 2 * math.pi * i / lados
        y, z = r * math.cos(a), r * math.sin(a)
        tras.append(bm.verts.new((x0, y, z)))
        # o plano do bisel: a ponta embaixo, o corte olhando pra cima
        frente.append(bm.verts.new((x_fim - bisel * (1.0 + z / r) / 2.0, y, z)))
    faces = [bm.faces.new(tras), bm.faces.new(frente)]
    for i in range(lados):
        j = (i + 1) % lados
        faces.append(bm.faces.new((tras[i], tras[j], frente[j], frente[i])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return objeto_de(bm, "agulha", [mats["agulha"]], angulo_quina=30.0)


def peca_escala(mats):
    """Escala impressa por fora do tubo: risco a cada 0,2 ml, risco longo e
    numero a cada 1 ml. Fica no quarto de cima voltado pra frente (+Z do jogo),
    que e' o lado que a camera do icone e o jogador olhando a mesa enxergam."""
    bm = bmesh.new()
    r = R_TUBO + 0.03
    a0 = math.radians(100.0)
    for k in range(26):
        xc = X_ZERO - k * 0.2 * MM_POR_ML
        longo = k % 5 == 0
        largura = 0.42 if longo else 0.3
        a1 = a0 + math.radians(52.0 if longo else 26.0)
        passos = 10 if longo else 5
        fileira0, fileira1 = [], []
        for p in range(passos + 1):
            a = a0 + (a1 - a0) * p / passos
            y, z = r * math.cos(a), r * math.sin(a)
            fileira0.append(bm.verts.new((xc - largura / 2, y, z)))
            fileira1.append(bm.verts.new((xc + largura / 2, y, z)))
        for p in range(passos):
            # ordem que deixa a normal pra fora do tubo
            bm.faces.new((fileira0[p], fileira0[p + 1], fileira1[p + 1], fileira1[p]))
    me_tmp = bpy.data.meshes.new("escala_tmp")
    bm.to_mesh(me_tmp)
    bm.free()

    # numeros 1..5 logo abaixo da ponta do risco longo, de pe' com a seringa
    # DEITADA e a agulha pra direita — que e' como ela aparece na mesa e no
    # icone. (De pe' pra agulha pra cima, como em algumas de verdade, eles
    # deitados viravam garrancho: o 3 parecia um "w".)
    bm = bmesh.new()
    bm.from_mesh(me_tmp)
    bpy.data.meshes.remove(me_tmp)
    a_num = a0 + math.radians(66.0)
    n = Vector((0.0, math.cos(a_num), math.sin(a_num)))
    t = Vector((0.0, -math.sin(a_num), math.cos(a_num)))
    eixo = Vector((1.0, 0.0, 0.0))
    for ml in range(1, 6):
        cu = bpy.data.curves.new("num%d" % ml, "FONT")
        cu.body = str(ml)
        cu.size = 2.3
        cu.align_x = "CENTER"
        cu.align_y = "CENTER"
        ob = bpy.data.objects.new("num%d" % ml, cu)
        bpy.context.scene.collection.objects.link(ob)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        xc = X_ZERO - ml * MM_POR_ML
        centro = Vector((xc, 0.0, 0.0)) + n * (r + 0.01)
        mt = Matrix((
            (eixo.x, -t.x, n.x, centro.x),
            (eixo.y, -t.y, n.y, centro.y),
            (eixo.z, -t.z, n.z, centro.z),
            (0.0, 0.0, 0.0, 1.0),
        ))
        me.transform(mt)
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.curves.remove(cu)
    # o texto do Blender vem com as duas faces; so' a de fora fica
    morta = []
    for f in bm.faces:
        f.normal_update()
        meio = f.calc_center_median()
        radial = Vector((0.0, meio.y, meio.z)).normalized()
        if f.normal.dot(radial) < 0.0:
            morta.append(f)
    bmesh.ops.delete(bm, geom=morta, context="FACES")
    for f in bm.faces:
        f.material_index = 0
    return objeto_de(bm, "escala", [mats["escala"]], angulo_quina=1.0)


# ============================================================ montagem e export

# Valores finais no .glb (ver o docstring). As cores do liquido sao as que o
# usuario ja' aprovou na seringa anterior. O vidro e' quase invisivel e fosco de
# proposito: qualquer brilho ou opacidade a mais nele desbota o liquido (com
# alpha 0,2 e rugosidade 0,25 o sangue saia rosa).
MATERIAIS = {
    "vidro_seringa": {"alphaMode": "BLEND", "doubleSided": False,
                      "pbrMetallicRoughness": {"baseColorFactor": [0.62, 0.68, 0.74, 0.12],
                                               "metallicFactor": 0.0, "roughnessFactor": 0.45}},
    "aba_seringa": {"alphaMode": "BLEND", "doubleSided": False,
                    "pbrMetallicRoughness": {"baseColorFactor": [0.8, 0.84, 0.88, 0.5],
                                             "metallicFactor": 0.0, "roughnessFactor": 0.3}},
    "plastico_embolo": {"doubleSided": False,
                        "pbrMetallicRoughness": {"baseColorFactor": [0.9, 0.9, 0.88, 1.0],
                                                 "metallicFactor": 0.0, "roughnessFactor": 0.45}},
    "borracha": {"doubleSided": False,
                 "pbrMetallicRoughness": {"baseColorFactor": [0.03, 0.03, 0.035, 1.0],
                                          "metallicFactor": 0.0, "roughnessFactor": 0.75}},
    "escala": {"doubleSided": False,
               "pbrMetallicRoughness": {"baseColorFactor": [0.02, 0.02, 0.025, 1.0],
                                        "metallicFactor": 0.0, "roughnessFactor": 0.6}},
    "agulha": {"doubleSided": False,
               "pbrMetallicRoughness": {"baseColorFactor": [0.78, 0.79, 0.81, 1.0],
                                        "metallicFactor": 0.75, "roughnessFactor": 0.28}},
    "adrenalina": {"doubleSided": False, "emissiveFactor": [0.18, 0.0, 0.0],
                   "pbrMetallicRoughness": {"baseColorFactor": [0.8, 0.0, 0.02, 1.0],
                                            "metallicFactor": 0.0, "roughnessFactor": 0.6}},
    "magia": {"doubleSided": False, "emissiveFactor": [0.06, 0.0, 0.26],
              "pbrMetallicRoughness": {"baseColorFactor": [0.26, 0.02, 0.9, 1.0],
                                       "metallicFactor": 0.0, "roughnessFactor": 0.6}},
    "canhao_rosa": {"alphaMode": "BLEND", "doubleSided": False,
                    "pbrMetallicRoughness": {"baseColorFactor": [0.95, 0.42, 0.55, 0.85],
                                             "metallicFactor": 0.0, "roughnessFactor": 0.35}},
    "canhao_violeta": {"alphaMode": "BLEND", "doubleSided": False,
                       "pbrMetallicRoughness": {"baseColorFactor": [0.58, 0.36, 0.95, 0.85],
                                                "metallicFactor": 0.0, "roughnessFactor": 0.35}},
    # o vidro na frente do liquido (ver `peca_tubo`)
    "vidro_adrenalina": {"alphaMode": "BLEND", "doubleSided": False,
                         "pbrMetallicRoughness": {"baseColorFactor": [0.7, 0.02, 0.05, 0.12],
                                                  "metallicFactor": 0.0, "roughnessFactor": 0.45}},
    "vidro_magia": {"alphaMode": "BLEND", "doubleSided": False,
                    "pbrMetallicRoughness": {"baseColorFactor": [0.3, 0.04, 0.85, 0.12],
                                             "metallicFactor": 0.0, "roughnessFactor": 0.45}},
}

VARIANTES = [
    # (nome do arquivo, material do liquido, material do canhao)
    ("seringa_adrenalina", "adrenalina", "canhao_rosa"),
    ("seringa_magia", "magia", "canhao_violeta"),
]


def criar_materiais():
    mats = {}
    for nome, dados in MATERIAIS.items():
        pbr = dados["pbrMetallicRoughness"]
        c = pbr["baseColorFactor"]
        mats[nome] = novo_material(nome, c[:3], c[3], pbr["metallicFactor"], pbr["roughnessFactor"])
    return mats


def montar(nome, liquido, canhao, mats):
    pecas = [peca_tubo(mats, "vidro_" + liquido), peca_aba(mats), peca_embolo(mats), peca_rolha(mats),
             peca_liquido(mats, liquido), peca_canhao(mats, canhao), peca_agulha(mats),
             peca_escala(mats)]
    bpy.ops.object.select_all(action="DESELECT")
    for ob in pecas:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = pecas[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = nome
    ob.data.name = nome

    # 14 cm de ponta a ponta, centrado no X, com o ponto mais baixo no chao
    me = ob.data
    xs = [v.co.x for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    k = COMPRIMENTO_FINAL / (max(xs) - min(xs))
    meio = (max(xs) + min(xs)) / 2
    me.transform(Matrix.Diagonal((k, k, k, 1.0)) @ Matrix.Translation((-meio, 0.0, -min(zs))))
    me.update()
    return ob


def exportar(ob, caminho):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_texcoords=False,
                              export_materials="EXPORT", export_animations=False)
    _reescrever_materiais(caminho)


def _reescrever_materiais(caminho):
    with open(caminho, "rb") as f:
        dados = f.read()
    tam_json = struct.unpack("<I", dados[12:16])[0]
    js = json.loads(dados[20:20 + tam_json])
    resto = dados[20 + tam_json:]
    for m in js.get("materials", []):
        novo = MATERIAIS.get(m["name"])
        if novo is None:
            continue
        nome = m["name"]
        m.clear()
        m["name"] = nome
        m.update(json.loads(json.dumps(novo)))
    bruto = json.dumps(js, separators=(",", ":")).encode("utf-8")
    bruto += b" " * ((4 - len(bruto) % 4) % 4)
    corpo = struct.pack("<II", len(bruto), 0x4E4F534A) + bruto + resto
    with open(caminho, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + len(corpo)) + corpo)


def main():
    for nome, liquido, canhao in VARIANTES:
        limpar_cena()
        mats = criar_materiais()
        ob = montar(nome, liquido, canhao, mats)
        caminho = os.path.join(OBJETOS, nome, nome + ".glb")
        exportar(ob, caminho)
        print("seringa: %s (%d vertices, %d faces)" % (caminho, len(ob.data.vertices), len(ob.data.polygons)))


main()
