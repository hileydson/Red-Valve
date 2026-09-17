# -*- coding: utf-8 -*-
"""Anima a mao de `maos_e_armas/mao_rig_new.blend` para as cenas de primeira
pessoa do jogo e exporta o .glb que o Godot consome.

CONVENCAO DE ESPACO
-------------------
As poses sao escritas no espaco da CAMERA, em METROS, com o olho na origem:

    +X direita     +Y para dentro da tela     +Z para cima

Isso e' o espaco do Blender (Z pra cima), entao o export sai com o
`export_yup` PADRAO (True) e chega no Godot ja' convertido: +X direita,
+Y cima, -Z para frente — exatamente o espaco local de uma Camera3D.
(Nao confundir com os geradores de malha em tools/blender/, que autoram
direto na convencao do jogo e por isso exportam com export_yup=False.)

O rig tem 1,121 unidade Blender do pulso a' ponta do indicador; uma mao de
verdade tem ~0,19 m. Dai ESCALA_GODOT = 0,17 no no' que segura o esqueleto, e
aqui tudo e' escrito em metros e multiplicado por UNI.

AS DUAS MAOS
------------
O .blend tem so' a mao ESQUERDA (a colecao `left_hand` estava certa). A direita
e' gerada AQUI: uma copia do rig e da malha, espelhada de verdade em X, e vai
junto no mesmo .glb. As duas tocam a MESMA animacao do Godot, cada uma com as
proprias curvas.

Espelhar no Godot com `scale.x = -1` num no' pai NAO funciona: a base fica com
determinante negativo, o motor le' isso como escala uniforme NEGATIVA
(`get_scale()` devolve -0,17 nos tres eixos), perde a reflexao ao montar a
matriz de normais, e a mao direita renderiza escura, com as normais para
dentro — com `cull_mode` ligado ou desligado, testado nos dois. Malha
espelhada de verdade resolve, e de quebra deixa cada mao com curva propria,
que e' o que tira o ar de carimbo simetrico.

FK, NAO IK
----------
O rig tem IK nos cinco dedos (ver memoria do projeto). Constraint de IK nao
exporta em glTF, entao aqui as constraints sao MUDAS enquanto as poses sao
escritas e cada acao guarda `influence = 0` — assim a acao tambem toca certo
dentro do Blender, com as constraints religadas.

Dobra de dedo e' rotacao LOCAL em X positivo; Z e' abertura lateral; Y e' o
eixo longitudinal do osso (torcao) e nao se mexe.

Rodar dentro do Blender com o mao_rig_new.blend aberto.
"""

import bpy
import math
import os
from mathutils import Vector, Matrix

# ----------------------------------------------------------------------------
# constantes
# ----------------------------------------------------------------------------

UNI = 5.882  # unidades Blender por metro (1 / 0.17)
FPS = 30

DEDOS = ("indicador", "medio", "anelar", "mindinho", "polegar")
FALANGES = (1, 2, 3)

# De onde o antebraco "vem": um ponto atras e abaixo do olho, no ombro
# esquerdo. Ancorar assim e' o que faz o braco parecer sair do corpo em vez de
# flutuar.
OMBRO = Vector((-0.26, -0.20, -0.62))

# O osso `antebraco` do rig tem 0,155 m (e' um toco de pulso, nao um antebraco).
# Com esse tamanho o cotovelo cai SEMPRE dentro do quadro e a previa vira uma
# bola de carne pendurada no meio da tela. Esticado ~2x ele sai pela borda de
# baixo, que e' o que todo jogo em primeira pessoa faz.
#
# Para o estica nao inflar a mao junto, `mao` fica com inherit_scale='NONE'
# (ver `preparar`); os dedos continuam herdando de `mao`, que nunca escala.
ESTICA = 2.05

# Quanto TODAS as maos recuam em relacao a' pose escrita (metros, no eixo de
# profundidade da camera; positivo = mais perto do olho).
#
# O antebraco tem comprimento FIXO (`comp` x `ESTICA`, 0,318 m): o que muda com
# a profundidade do pulso nao e' o tamanho do braco, e' o quanto dele aparece.
# Com o pulso longe, a mao fica pequena e o antebraco atravessa a tela inteira
# — le' como braco comprido demais. Recuar um tico aproxima a mao, encurta o
# antebraco na tela e nao mexe em pose nenhuma.
RECUO_DAS_MAOS = 0.075

# Teto de profundidade do pulso (metros, mesmo eixo do recuo).
#
# `EMPURRA` punha o pulso a 0,50 m e o pico do arremesso a 0,55: o antebraco
# vira uma VARA comprida atravessando a tela ate' uma mao pequena la' na
# frente. Nao e' o braco que cresce (ele tem tamanho fixo) — e' o pulso indo
# longe demais, o que espicha o antebraco na tela e encolhe a mao.
#
# Com teto 0,32 os extremos ainda paravam em ~0,30 e ESSES momentos curtos
# continuavam esticando; 0,28 leva os dois para ~0,277 sem mexer nas poses de
# perto (a `DEFESA` nao se move nem um milimetro).
#
# O teto NAO e' corte seco: acima de `PROF_JOELHO` a profundidade continua
# crescendo, cada vez menos, e nunca passa de `PROF_TETO`. Com clamp duro o
# movimento travaria — o `agarrado`, por exemplo, vai e volta entre DEFESA e
# EMPURRA, e a metade de ida ficaria congelada no teto.
PROF_JOELHO = 0.20
PROF_TETO = 0.28


def _profundidade(y):
    """Comprime a profundidade do pulso contra PROF_TETO, sem travar."""
    if y <= PROF_JOELHO:
        return y
    faixa = PROF_TETO - PROF_JOELHO
    return PROF_JOELHO + faixa * (1.0 - math.exp(-(y - PROF_JOELHO) / faixa))

# --- perfil do antebraco (ver `engrossar_antebraco`) ---
# `t` = posicao ao longo do osso `antebraco`: 0 no cotovelo, 1 no PULSO.
T_MIN = -0.30      # onde a carne do toco comeca, atras da cabeca do osso
T_PICO = 0.15      # onde o toco que vem no rig e' mais grosso
T_SOME = 1.28      # onde a correcao ja' morreu, dentro da mao
GANHO_COTOVELO = 1.15  # raio na ponta de tras, em fracao do pico
# O pulso e' o que o rig mais erra: chega a 0,67 do pico enquanto a base da
# palma, logo adiante, esta' em 0,83. Ou seja, o ponto mais fino da peca inteira
# fica ANTES da mao — e' o palito que se via na tela.
#
# O teto e' a propria palma: passar dela poe o antebraco PARA FORA do contorno
# da mao e o encontro vira um degrau (testado com 0,90, aparece de longe).
# 0,80 fica logo abaixo da base da palma: o pulso continua sendo a cintura do
# braco, so' que agora e' uma cintura e nao uma ponta.
GANHO_PULSO = 0.80

NOME_ARM_DIR = "Armature_dir"
NOME_MESH_DIR = "mao_dir"
NOME_MESH_ESQ = "mao_esq"

SAIDA_GLB = "red-valve/assets/3d_model/player/hands/maos_fp/maos_fp.glb"


def _m(v):
    """Metros -> unidades do rig."""
    return Vector(v) * UNI


# ----------------------------------------------------------------------------
# rig
# ----------------------------------------------------------------------------

def preparar(arm):
    """Silencia o IK, zera a pose e devolve o comprimento do antebraco."""
    bpy.context.view_layer.objects.active = arm
    if bpy.context.object.mode != 'POSE':
        bpy.ops.object.mode_set(mode='POSE')
    arm.data.bones["mao"].inherit_scale = 'NONE'
    for pb in arm.pose.bones:
        for c in pb.constraints:
            c.mute = True
        pb.rotation_mode = 'XYZ'
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)
    bpy.context.view_layer.update()
    return arm.data.bones["antebraco"].length


def engrossar_antebraco(mesh_obj, arm_obj):
    """Da' cara de antebraco ao toco do rig.

    `t` e' a posicao ao longo do osso `antebraco`: 0 na cabeca (cotovelo), 1 na
    cauda (PULSO). A carne comeca antes de 0 e a mao comeca depois de 1.

    O toco que vem no rig e' um cone dos dois lados: o raio medio sobe ate 0,221
    perto do cotovelo (t ~ 0,15) e cai SEM PARAR ate 0,150 no pulso (t ~ 0,95) —
    enquanto a mao logo adiante tem 0,21. Ou seja, o pulso e' o ponto mais fino
    da peca inteira, com a mao ficando mais grossa depois dele.

    Sozinho isso ja' apareceria; com o ESTICA de ~2x, que alonga o osso sem
    mexer em raio nenhum, o cone fica DUAS VEZES mais comprido com a mesma
    espessura e vira um espeto que termina num alfinete bem na hora de encontrar
    a mao. Era o que se via na tela: braco afinando ate o pulso e a mao colada
    num palito.

    Aqui o perfil INTEIRO e' retomado, e nao so' a ponta de tras: o cotovelo vai
    para `GANHO_COTOVELO` vezes o pico e o pulso para `GANHO_PULSO` vezes o
    pico, com o raio caminhando em linha entre os dois — que e' o que um
    antebraco de verdade faz (engrossa na direcao do cotovelo, afina de LEVE no
    pulso, nunca vira ponta).

    Duas regras que seguram o resto da malha:

    - a correcao morre em `T_SOME`, ja' dentro da mao, e nao encosta nos dedos;
    - ela nunca ENCOLHE nada (`fator` abaixo de 1 e' descartado). O servico e'
      levar o pulso ate quase o raio da mao para os dois se encontrarem sem
      degrau, e nao remodelar a mao.

    Roda em COPIAS (`mao_esq`, `mao_dir`): o `Mesh0` do usuario nunca sai daqui
    com a geometria mexida.
    """
    osso = arm_obj.data.bones["antebraco"]
    cabeca = Vector(osso.head_local)
    eixo = (Vector(osso.tail_local) - cabeca).normalized()
    comp = osso.length

    grupo = mesh_obj.vertex_groups.get("antebraco")
    if grupo is None:
        return 0
    idx_grupo = grupo.index
    # Os dedos ficam de fora na marra: parte da base do polegar cai dentro da
    # faixa de t que vai ser mexida, e engrossar dedo nao e' o assunto aqui.
    idx_dedos = set()
    for dedo in DEDOS:
        for falange in FALANGES:
            g = mesh_obj.vertex_groups.get("%s_%d" % (dedo, falange))
            if g is not None:
                idx_dedos.add(g.index)

    # --- perfil medido: raio medio por faixa de t ---
    FAIXAS = 22
    soma = [0.0] * FAIXAS
    conta = [0] * FAIXAS
    alvos = []
    for v in mesh_obj.data.vertices:
        e_dedo = False
        peso = 0.0
        for g in v.groups:
            if g.group in idx_dedos and g.weight > 0.0:
                e_dedo = True
            if g.group == idx_grupo:
                peso = g.weight
        d = Vector(v.co) - cabeca
        t = d.dot(eixo) / comp
        if t >= T_SOME:
            continue
        radial = d - eixo * d.dot(eixo)
        # O perfil so' e' MEDIDO na faixa das faixas, e so' com carne de
        # ANTEBRACO: passando do pulso a media vira a MAO, que e' mais grossa, e
        # tomar isso como referencia faria a correcao desistir bem no ponto que
        # ela existe para consertar. Ja' quem cai ANTES de T_MIN (a pontinha de
        # tras) entra na correcao do mesmo jeito e le' a primeira faixa, que e'
        # o que `raio_do_perfil` devolve la' — cortar esses vertices deixaria um
        # degrau justamente na ponta.
        if T_MIN <= t and peso > 0.001:
            i = int((t - T_MIN) / (T_SOME - T_MIN) * FAIXAS)
            soma[i] += radial.length
            conta[i] += 1
        if not e_dedo:
            alvos.append((v, t, radial))

    perfil = []
    for i in range(FAIXAS):
        t_meio = T_MIN + (i + 0.5) * (T_SOME - T_MIN) / FAIXAS
        perfil.append((t_meio, soma[i] / conta[i] if conta[i] else 0.0))

    # A media de cada faixa BALANCA: o toco nao e' um cilindro e cada faixa tem
    # umas cem posicoes. Dividir pelo valor cru transforma esse balanco em ONDA
    # no contorno do braco — de longe parecem aneis de gordura. Tres passadas de
    # media com as vizinhas tiram o tremor e deixam a curva que interessa.
    for _ in range(3):
        perfil = [(perfil[i][0],
                   (perfil[max(i - 1, 0)][1] + 2.0 * perfil[i][1]
                    + perfil[min(i + 1, FAIXAS - 1)][1]) / 4.0)
                  for i in range(FAIXAS)]

    def raio_do_perfil(t):
        """Raio medio naquele t, interpolado entre as faixas."""
        if t <= perfil[0][0]:
            return perfil[0][1]
        if t >= perfil[-1][0]:
            return perfil[-1][1]
        for i in range(len(perfil) - 1):
            a, b = perfil[i], perfil[i + 1]
            if a[0] <= t <= b[0]:
                k = (t - a[0]) / (b[0] - a[0]) if b[0] > a[0] else 0.0
                return a[1] * (1.0 - k) + b[1] * k
        return perfil[-1][1]

    # O pico e' o ponto mais grosso do ANTEBRACO (t ate' o pulso); tudo se mede
    # a partir dele.
    grossos = [r for t, r in perfil if t <= 1.0 and r > 0.0]
    pico = max(grossos) if grossos else 0.22

    def alvo_do_perfil(t):
        if t <= T_PICO:
            k = min(1.0, (T_PICO - t) / (T_PICO - T_MIN))
            return pico * (1.0 + (GANHO_COTOVELO - 1.0) * k)
        k = min(1.0, (t - T_PICO) / (1.0 - T_PICO))
        return pico * (1.0 + (GANHO_PULSO - 1.0) * k)

    def influencia(t):
        """1 ate' o pulso, caindo a zero dentro da mao.

        A queda e' em S (`smoothstep`) e nao em linha: uma reta chega em t = 1
        com derivada quebrada e deixa uma aresta dura contornando o pulso.
        """
        if t <= 1.0:
            return 1.0
        k = (t - 1.0) / (T_SOME - 1.0)
        if k >= 1.0:
            return 0.0
        return 1.0 - k * k * (3.0 - 2.0 * k)

    mexidos = 0
    for v, t, radial in alvos:
        inf = influencia(t)
        if inf <= 0.0:
            continue
        atual = radial.length
        medio = raio_do_perfil(t)
        if atual < 1e-5 or medio < 1e-5:
            continue
        fator = 1.0 + (alvo_do_perfil(t) / medio - 1.0) * inf
        if fator <= 1.0:
            continue
        v.co = Vector(v.co) + radial.normalized() * (atual * (fator - 1.0))
        mexidos += 1

    mesh_obj.data.update()
    return mexidos


def limpar_temporarios():
    """Tira da cena as copias de export da rodada anterior.

    Sem varrer tambem os datablocks ORFAOS, a malha nova nasce como
    "mao_dir.001" e o nome do no' no .glb muda a cada reexport.
    """
    for nome in (NOME_ARM_DIR, NOME_MESH_DIR, NOME_MESH_ESQ):
        antigo = bpy.data.objects.get(nome)
        if antigo:
            bpy.data.objects.remove(antigo, do_unlink=True)
    for colecao in (bpy.data.meshes, bpy.data.armatures):
        for dado in list(colecao):
            if dado.users == 0 and dado.name.startswith(
                    (NOME_MESH_DIR, NOME_MESH_ESQ, NOME_ARM_DIR)):
                colecao.remove(dado)


def criar_mao_esquerda(arm, mesh):
    """Copia da malha original, presa ao rig original, com o antebraco grosso.

    E' uma COPIA de proposito: o `Mesh0` do usuario nao pode sair daqui com a
    geometria mexida. O rig, esse sim, e' o original — as acoes da mao esquerda
    sao escritas nele, e assim continuam disponiveis no .blend.
    """
    colecao = mesh.users_collection[0] if mesh.users_collection else bpy.context.scene.collection
    copia = mesh.copy()
    copia.data = mesh.data.copy()
    copia.name = NOME_MESH_ESQ
    copia.data.name = NOME_MESH_ESQ
    colecao.objects.link(copia)
    copia.parent = arm
    copia.matrix_parent_inverse = arm.matrix_world.inverted()
    for mod in copia.modifiers:
        if mod.type == 'ARMATURE':
            mod.object = arm
    engrossar_antebraco(copia, arm)
    return copia


def criar_mao_direita(arm, mesh_esq):
    """Copia o rig e a malha da mao ESQUERDA DE EXPORT e espelha os dois em X.

    Recebe `mesh_esq` (a copia ja' com o antebraco engrossado), e nao a malha
    original: assim o engrossamento e' feito UMA vez e as duas maos saem
    iguaizinhas. Engrossar depois de espelhar tambem nao daria certo — a conta
    usa o eixo do osso do rig original, que ja' nao vale na malha espelhada.

    A malha e' espelhada aplicando `scale.x = -1` no objeto: o
    `transform_apply` do Blender ja' inverte o winding e as normais custom
    junto, coisa que mexer em `vertex.co` na mao nao faz.

    Os ossos NAO podem ser espelhados negando head/tail e chutando o roll: o
    roll define para onde aponta o eixo Z do osso, e e' no eixo do osso que a
    carne esta amarrada. Aqui cada osso recebe a MATRIZ inteira, montada a
    partir da matriz do original com X negado em todos os eixos — e com
    `X = Y x Z` para a base continuar destra, como o Blender exige.

    Essa troca de sinal em X e' exatamente o que `aplicar_pose(espelhado=True)`
    desfaz do outro lado: as duas coisas foram derivadas juntas e so' funcionam
    em par.
    """
    bpy.ops.object.mode_set(mode='OBJECT')
    colecao = arm.users_collection[0] if arm.users_collection else bpy.context.scene.collection

    arm_dir = arm.copy()
    arm_dir.data = arm.data.copy()
    arm_dir.name = NOME_ARM_DIR
    arm_dir.data.name = NOME_ARM_DIR
    arm_dir.animation_data_clear()
    colecao.objects.link(arm_dir)

    mesh_dir = mesh_esq.copy()
    mesh_dir.data = mesh_esq.data.copy()
    mesh_dir.name = NOME_MESH_DIR
    mesh_dir.data.name = NOME_MESH_DIR
    colecao.objects.link(mesh_dir)
    mesh_dir.parent = arm_dir
    mesh_dir.matrix_parent_inverse = arm_dir.matrix_world.inverted()
    for mod in mesh_dir.modifiers:
        if mod.type == 'ARMATURE':
            mod.object = arm_dir

    # --- malha ---
    bpy.ops.object.select_all(action='DESELECT')
    mesh_dir.select_set(True)
    bpy.context.view_layer.objects.active = mesh_dir
    mesh_dir.scale.x = -1.0
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # --- ossos ---
    guardado = {}
    for osso in arm.data.bones:
        m = osso.matrix_local
        guardado[osso.name] = (
            Vector(m.col[1][:3]),   # Y: eixo longitudinal
            Vector(m.col[2][:3]),   # Z: costas do osso (onde o roll manda)
            Vector(m.col[3][:3]),   # cabeca
            osso.length,
        )

    bpy.context.view_layer.objects.active = arm_dir
    bpy.ops.object.mode_set(mode='EDIT')
    troca = Vector((-1.0, 1.0, 1.0))
    for eb in arm_dir.data.edit_bones:
        eixo_y, eixo_z, cabeca, comp = guardado[eb.name]
        y = Vector(eixo_y) * troca
        z = Vector(eixo_z) * troca
        y.normalize()
        z = (z - y * z.dot(y)).normalized()
        x = y.cross(z)
        h = Vector(cabeca) * troca
        eb.matrix = Matrix((
            (x.x, y.x, z.x, h.x),
            (x.y, y.y, z.y, h.y),
            (x.z, y.z, z.z, h.z),
            (0.0, 0.0, 0.0, 1.0),
        ))
        eb.length = comp
    bpy.ops.object.mode_set(mode='OBJECT')

    return arm_dir, mesh_dir


def _matriz(origem, eixo_y, eixo_z):
    """Matriz de osso a partir de (cabeca, longitudinal, "costas" do osso).

    Convencao do Blender: X = Y x Z. `eixo_z` e' so' uma referencia — sai
    reortogonalizado contra `eixo_y`.
    """
    y = Vector(eixo_y).normalized()
    z = Vector(eixo_z)
    z = (z - y * z.dot(y)).normalized()
    x = y.cross(z)
    return Matrix((
        (x.x, y.x, z.x, origem.x),
        (x.y, y.y, z.y, origem.y),
        (x.z, y.z, z.z, origem.z),
        (0.0, 0.0, 0.0, 1.0),
    ))


def aplicar_pose(arm, pose, comp_antebraco, espelhado=False):
    """Escreve uma pose inteira no rig.

    `pose` e' um dicionario com:
      pulso   (x, y, z) em metros, no espaco da camera
      dedos   direcao para onde os dedos apontam
      palma   direcao para onde a palma olha
      curl    {dedo: (a1, a2, a3)} em radianos, positivo = fecha
      abrir   {dedo: z} abertura lateral da falange 1
      torcao  giro extra do antebraco em torno do proprio eixo (rad)

    `espelhado=True` nega o X de tudo. Serve para escrever uma acao pensando
    na mao DIREITA sabendo que ela vai ser vista atraves de um no' com
    scale.x = -1: a reflexao do no' desfaz essa negacao e a mao chega onde foi
    pedida. Ver o cabecalho.
    """
    s = -1.0 if espelhado else 1.0
    # Recuo e teto entram ANTES de virar unidade do rig: a pose e' escrita em
    # metros, e os dois sao em metros.
    metros = Vector(pose["pulso"]) - Vector((0.0, RECUO_DAS_MAOS, 0.0))
    metros.y = _profundidade(metros.y)
    pulso = _m(metros) * Vector((s, 1.0, 1.0))
    dedos = Vector(pose["dedos"]) * Vector((s, 1.0, 1.0))
    palma = Vector(pose["palma"]) * Vector((s, 1.0, 1.0))
    dedos.normalize()
    palma.normalize()

    estica = pose.get("estica", ESTICA)
    ombro = _m(OMBRO) * Vector((s, 1.0, 1.0))
    dir_antebraco = (pulso - ombro).normalized()
    cotovelo = pulso - dir_antebraco * comp_antebraco * estica

    # A rolagem do antebraco tem de SEGUIR a da mao, nunca ser a oposta.
    #
    # `_matriz` recebe o eixo Z LOCAL do osso, e neste rig o Z do `antebraco` e
    # o da `mao` estao ALINHADOS no descanso (a rolagem relativa entre os dois
    # e' de -0,5 grau). Passar `-palma` aqui — que parece certo em portugues,
    # "as costas do antebraco acompanham as costas da mao" — torcia o antebraco
    # 180 graus em relacao a' mao. A pele do pulso, presa aos dois, colapsava
    # num PONTO: o raio medio caia de 0,186 para 0,018, contra 0,152 com os
    # dois alinhados. E' o "papel de bala" classico de skinning linear, e era
    # ELE o pulso fino que aparecia no jogo — nao a malha.
    costas = palma
    torcao = pose.get("torcao", 0.0)
    if torcao:
        costas = Matrix.Rotation(torcao * s, 4, dir_antebraco) @ costas

    pb_ante = arm.pose.bones["antebraco"]
    pb_ante.matrix = _matriz(cotovelo, dir_antebraco, costas)
    # Depois da matriz, nunca antes: o setter de `matrix` reescreve a escala.
    pb_ante.scale = (1.0, estica, 1.0)
    bpy.context.view_layer.update()

    pb_mao = arm.pose.bones["mao"]
    pb_mao.matrix = _matriz(pulso, dedos, palma)
    bpy.context.view_layer.update()

    curl = pose.get("curl", {})
    abrir = pose.get("abrir", {})
    for dedo in DEDOS:
        angulos = curl.get(dedo, (0.0, 0.0, 0.0))
        lateral = abrir.get(dedo, 0.0)
        for i in FALANGES:
            pb = arm.pose.bones["%s_%d" % (dedo, i)]
            pb.rotation_euler = (angulos[i - 1], 0.0, lateral if i == 1 else 0.0)
    bpy.context.view_layer.update()


# ----------------------------------------------------------------------------
# acoes
# ----------------------------------------------------------------------------

def nova_acao(arm, nome):
    if arm.animation_data is None:
        arm.animation_data_create()
    antiga = bpy.data.actions.get(nome)
    if antiga:
        bpy.data.actions.remove(antiga)
    acao = bpy.data.actions.new(nome)
    acao.use_fake_user = True  # acao sem dono some ao salvar (Blender 5.x)
    arm.animation_data.action = acao
    return acao


def gravar(arm, quadro):
    """Insere chave em TODOS os ossos de deformacao.

    Sempre todos, nunca so' o que mudou: uma pose que so' chaveia parte do rig
    deixa o resto interpolando de uma pose anterior qualquer e o resultado e'
    mao torta em quadros do meio, sem erro nenhum aparecer.
    """
    for pb in arm.pose.bones:
        if not pb.bone.use_deform:
            continue
        if not pb.bone.use_connect:
            pb.keyframe_insert("location", frame=quadro)
        pb.keyframe_insert("rotation_euler", frame=quadro)
        if pb.name == "antebraco":
            pb.keyframe_insert("scale", frame=quadro)


def zerar_ik_na_acao(arm, quadro):
    for pb in arm.pose.bones:
        for c in pb.constraints:
            if c.type != 'IK':
                continue
            c.influence = 0.0
            caminho = 'pose.bones["%s"].constraints["%s"].influence' % (pb.name, c.name)
            arm.keyframe_insert(caminho, frame=quadro)


def montar_acao(arm, nome, quadros, comp_antebraco, espelhado=False):
    """quadros = [(numero_do_quadro, pose), ...]"""
    acao = nova_acao(arm, nome)
    for numero, pose in quadros:
        aplicar_pose(arm, pose, comp_antebraco, espelhado)
        gravar(arm, numero)
    zerar_ik_na_acao(arm, quadros[0][0])
    acao.use_frame_range = True
    acao.frame_start = quadros[0][0]
    acao.frame_end = quadros[-1][0]
    return acao


# ----------------------------------------------------------------------------
# vocabulario de poses
# ----------------------------------------------------------------------------

def _mistura(a, b, t):
    """Interpola duas poses. Vetores por componente, angulos por escalar."""
    out = {}
    for chave in ("pulso", "dedos", "palma"):
        va, vb = Vector(a[chave]), Vector(b[chave])
        out[chave] = tuple(va.lerp(vb, t))
    out["torcao"] = a.get("torcao", 0.0) * (1.0 - t) + b.get("torcao", 0.0) * t
    out["estica"] = a.get("estica", ESTICA) * (1.0 - t) + b.get("estica", ESTICA) * t
    for chave in ("curl", "abrir"):
        da, db = a.get(chave, {}), b.get(chave, {})
        junto = {}
        for dedo in DEDOS:
            pa = da.get(dedo, (0.0, 0.0, 0.0) if chave == "curl" else 0.0)
            pb_ = db.get(dedo, (0.0, 0.0, 0.0) if chave == "curl" else 0.0)
            if chave == "curl":
                junto[dedo] = tuple(pa[i] * (1.0 - t) + pb_[i] * t for i in range(3))
            else:
                junto[dedo] = pa * (1.0 - t) + pb_ * t
        out[chave] = junto
    return out


def _desloca(pose, d=(0.0, 0.0, 0.0), dedos=None, palma=None, curl_mult=None):
    """Copia a pose com o pulso deslocado (metros) e ajustes pontuais."""
    out = dict(pose)
    out["pulso"] = tuple(Vector(pose["pulso"]) + Vector(d))
    if dedos is not None:
        out["dedos"] = dedos
    if palma is not None:
        out["palma"] = palma
    if curl_mult is not None:
        out["curl"] = {k: tuple(a * curl_mult for a in v)
                       for k, v in pose.get("curl", {}).items()}
    return out


# Mao solta, caida na frente do corpo.
RELAXADA = {
    "pulso": (-0.17, 0.40, -0.33),
    "dedos": (0.12, 0.88, 0.46),
    "palma": (0.90, -0.10, 0.42),
    "curl": {"indicador": (0.34, 0.60, 0.42), "medio": (0.38, 0.66, 0.46),
             "anelar": (0.40, 0.68, 0.46), "mindinho": (0.42, 0.70, 0.44),
             "polegar": (0.26, 0.30, 0.22)},
    "abrir": {"indicador": -0.05, "medio": 0.0, "anelar": 0.04, "mindinho": 0.10,
              "polegar": 0.0},
}

# Palma virada para a frente, dedos abertos: se proteger.
DEFESA = {
    "pulso": (-0.150, 0.295, -0.060),
    "dedos": (0.20, 0.26, 0.94),
    "palma": (0.16, 0.95, -0.28),
    "curl": {"indicador": (0.26, 0.28, 0.14), "medio": (0.26, 0.28, 0.14),
             "anelar": (0.28, 0.30, 0.16), "mindinho": (0.30, 0.32, 0.18),
             "polegar": (0.16, 0.14, 0.10)},
    "abrir": {"indicador": -0.20, "medio": -0.05, "anelar": 0.09, "mindinho": 0.22,
              "polegar": -0.22},
}

# Empurrando o inimigo: bracos esticados, dedos em garra.
EMPURRA = {
    "pulso": (-0.185, 0.50, -0.020),
    "dedos": (0.16, 0.62, 0.77),
    "palma": (0.10, 0.90, -0.42),
    "curl": {"indicador": (0.55, 0.85, 0.58), "medio": (0.58, 0.88, 0.60),
             "anelar": (0.58, 0.88, 0.60), "mindinho": (0.60, 0.90, 0.58),
             "polegar": (0.40, 0.45, 0.35)},
    "abrir": {"indicador": -0.16, "medio": -0.04, "anelar": 0.07, "mindinho": 0.16,
              "polegar": -0.14},
}

# Palma apoiada no chao, dedos abertos aguentando o peso.
#
# As maos sao filhas da CAMERA: a posicao delas no espaco da camera E' a
# posicao na TELA, e inclinar a camera para baixo nao traz nenhuma mao de volta
# ao quadro. Quem esta caido de bruços tem as maos uns 48 graus abaixo do
# olhar, fora do quadro de uma camera de 75 graus — entao aqui elas sobem para
# ~33 graus. E' a mesma trapaca que todo jogo em primeira pessoa faz: a camera
# desce, a mao fica visivel, e a leitura continua de "apoiado no chao".
CHAO = {
    "pulso": (-0.175, 0.330, -0.215),
    "dedos": (0.10, 0.96, -0.26),
    "palma": (0.02, -0.24, -0.97),
    "curl": {"indicador": (0.16, 0.12, 0.08), "medio": (0.16, 0.12, 0.08),
             "anelar": (0.18, 0.14, 0.08), "mindinho": (0.20, 0.16, 0.08),
             "polegar": (0.12, 0.10, 0.06)},
    "abrir": {"indicador": -0.26, "medio": -0.07, "anelar": 0.12, "mindinho": 0.28,
              "polegar": -0.30},
}

# Bracos soltos no ar, como quem foi arremessado e nao tem em que se segurar.
VOANDO = {
    "pulso": (-0.205, 0.345, 0.020),
    "dedos": (-0.40, 0.22, 0.89),
    "palma": (0.62, 0.70, 0.35),
    "curl": {"indicador": (0.30, 0.45, 0.30), "medio": (0.32, 0.48, 0.32),
             "anelar": (0.34, 0.50, 0.32), "mindinho": (0.36, 0.52, 0.30),
             "polegar": (0.22, 0.26, 0.18)},
    "abrir": {"indicador": -0.10, "medio": 0.0, "anelar": 0.08, "mindinho": 0.16,
              "polegar": -0.08},
}

# Bem fora de quadro, para as entradas e saidas.
GUARDADA = {
    "pulso": (-0.26, 0.16, -0.66),
    "dedos": (0.18, 0.60, -0.78),
    "palma": (0.92, -0.06, 0.38),
    "curl": {"indicador": (0.45, 0.70, 0.50), "medio": (0.48, 0.74, 0.52),
             "anelar": (0.50, 0.76, 0.52), "mindinho": (0.52, 0.78, 0.50),
             "polegar": (0.30, 0.34, 0.24)},
    "abrir": {},
}


# ----------------------------------------------------------------------------
# tremor deterministico
# ----------------------------------------------------------------------------

def _tremor(semente, escala):
    """Ruido reprodutivel: seno de frequencias irracionais, sem random()."""
    t = float(semente)
    return (
        math.sin(t * 2.399) * escala,
        math.sin(t * 3.673 + 1.7) * escala * 0.7,
        math.sin(t * 5.117 + 0.4) * escala,
    )



# ----------------------------------------------------------------------------
# as animacoes
# ----------------------------------------------------------------------------
#
# Cada fabrica recebe `lado` (0 = esquerda, 1 = direita) e devolve
# [(quadro, pose), ...]. As duas maos NUNCA saem iguais: o `lado` desloca a
# fase do tremor, o instante das batidas e a altura do pulso. E' o que separa
# duas maos de um carimbo espelhado.
#
# A pose da mao direita ainda passa por `aplicar_pose(espelhado=True)`, que
# nega o X — entao aqui tudo continua escrito como se fosse a mao esquerda.


def _fase(lado: int) -> float:
    """Semente do ruido/onda de cada mao."""
    return 0.0 if lado == 0 else 1.73


def _assimetria(lado: int):
    """Deslocamento fixo (metros) que afasta uma mao da outra."""
    return (0.0, 0.0, 0.0) if lado == 0 else (0.012, 0.022, -0.016)


def anim_idle(lado=0):
    """61 quadros em laco: mao parada, so' a respiracao."""
    base = _desloca(RELAXADA, _assimetria(lado))
    quadros = []
    for i in range(0, 7):
        q = 1 + i * 10
        fase = (i % 6) / 6.0 * math.tau + _fase(lado) * 0.6
        quadros.append((q, _desloca(base, (
            math.sin(fase) * 0.006,
            math.cos(fase) * 0.004,
            math.sin(fase * 2.0) * 0.010,
        ))))
    return quadros


def anim_defesa(lado=0):
    """41 quadros em laco: guarda alta, tensa, tremendo."""
    # A mao de tras protege mais o rosto; a da frente fica um pouco mais
    # esticada. Guarda de quem apanha, nao de quem boxeia.
    base = DEFESA if lado == 0 else _desloca(DEFESA, (0.015, 0.05, -0.03))
    quadros = []
    for i in range(0, 11):
        q = 1 + i * 4
        dx, dy, dz = _tremor(i * 1.31 + _fase(lado), 0.009)
        empurrao = math.sin((i % 10) / 10.0 * math.tau + _fase(lado) * 0.5) * 0.014
        quadros.append((q, _desloca(base, (dx, dy + empurrao, dz))))
    return quadros


def anim_agarrado(lado=0):
    """49 quadros em laco: se debatendo nas maos do inimigo."""
    quadros = []
    for i in range(0, 13):
        q = 1 + i * 4
        t = ((i % 12) / 12.0 + (0.0 if lado == 0 else 0.28)) % 1.0
        # vai e volta entre a guarda e o empurrao, com solavanco
        onda = (1.0 - math.cos(t * math.tau)) * 0.5
        base = _mistura(DEFESA, EMPURRA, onda)
        dx, dy, dz = _tremor(i * 2.17 + _fase(lado), 0.016)
        quadros.append((q, _desloca(base, (dx, dy, dz))))
    return quadros


def anim_mordida(lado=0):
    """43 quadros, uma vez: a mordida chega, as maos sao jogadas para fora.

    A VOLTA E' LONGA DE PROPOSITO. A palma de `DEFESA` aponta para a frente e a
    de `RELAXADA` aponta para dentro: sao ~94 graus de diferenca, e o antebraco
    acompanha a palma (ver `costas` em `aplicar_pose`). Na primeira versao essa
    supinacao inteira cabia em 11 quadros no fim da animacao — 15 a 18 graus de
    giro de antebraco POR QUADRO, com a mao quase parada no lugar. Na tela isso
    nao le' como "se recompor": le' como parafuso, e era o "dedos se torcendo no
    finalzinho".

    Agora ela e' espalhada em 16 quadros com chaves intermediarias E a animacao
    para na METADE do caminho para `RELAXADA`. A outra metade fica por conta da
    mistura para `idle`, que o `_ramo_mordida` pede longa (0,55 s): mistura de
    animacao no Godot interpola em linha reta, sem o ease-in/ease-out da curva
    de Bezier que concentrava o giro no meio do trecho. Dividir assim derruba o
    pico de ~17 para ~6 graus por quadro sem encurtar o movimento.
    """
    sacode = _desloca(DEFESA, (-0.05, -0.07, -0.05), curl_mult=1.6)
    # Uma mao e' jogada para cima e para fora, a outra para baixo: as duas indo
    # para o mesmo lado ficaria com cara de animacao unica espelhada.
    if lado == 0:
        aberta = _desloca(DEFESA, (-0.12, -0.02, 0.06),
                          dedos=(-0.35, 0.30, 0.89), palma=(0.55, 0.78, -0.30))
    else:
        aberta = _desloca(DEFESA, (-0.09, -0.05, -0.10),
                          dedos=(-0.20, 0.42, -0.88), palma=(0.62, 0.72, 0.31))
    atraso = 0 if lado == 0 else 2
    return [
        (1, DEFESA),
        (3 + atraso, _desloca(DEFESA, (0.0, 0.03, 0.01))),
        (6 + atraso, sacode),
        (10 + atraso, aberta),
        (14 + atraso, _desloca(aberta, (0.02, 0.05, -0.03))),
        (20 + atraso, _mistura(aberta, DEFESA, 0.55)),
        (27, _mistura(aberta, DEFESA, 0.85)),
        (33, _mistura(DEFESA, RELAXADA, 0.20)),
        (38, _mistura(DEFESA, RELAXADA, 0.38)),
        (43, _mistura(DEFESA, RELAXADA, 0.50)),
    ]


def anim_arremesso(lado=0):
    """25 quadros, uma vez: levantado do chao, bracos perdem o apoio."""
    alto = _desloca(EMPURRA, (-0.06, -0.16, 0.22),
                    dedos=(-0.10, 0.10, 0.99), palma=(0.60, 0.72, -0.12))
    atraso = 0 if lado == 0 else 2
    return [
        (1, EMPURRA),
        (4, _desloca(EMPURRA, (0.0, 0.05, 0.03))),
        (9 + atraso, alto),
        (14 + atraso, _desloca(alto, (-0.08, -0.10, 0.06))),
        (19, _mistura(alto, VOANDO, 0.6)),
        (25, _desloca(VOANDO, _assimetria(lado))),
    ]


def anim_queda(lado=0):
    """37 quadros em laco: no ar, bracos rodando sem apoio."""
    base = _desloca(VOANDO, _assimetria(lado))
    quadros = []
    for i in range(0, 10):
        q = 1 + i * 4
        t = (i % 9) / 9.0 * math.tau + _fase(lado)
        quadros.append((q, _desloca(base, (
            math.sin(t) * 0.05,
            math.cos(t) * 0.06,
            math.sin(t * 1.5 + 0.8) * 0.07,
        ))))
    return quadros


def anim_chao(lado=0):
    """25 quadros, uma vez: as palmas batem no chao e absorvem o tranco.

    As duas maos NAO batem no mesmo quadro: quem cai de frente poe uma mao e
    depois a outra, e sao esses dois quadros de diferenca que fazem a batida
    soar como uma queda em vez de um carimbo.
    """
    atraso = 0 if lado == 0 else 3
    antes = _desloca(CHAO, (-0.04, -0.10, 0.26), curl_mult=0.6)
    batida = _desloca(CHAO, (0.0, 0.0, -0.018), curl_mult=0.5)
    pousada = _desloca(CHAO, _assimetria(lado))
    return [
        (1, antes),
        (4, _desloca(antes, (0.0, 0.06, -0.12))),
        (7 + atraso, batida),
        (9 + atraso, _desloca(pousada, (0.0, -0.01, 0.014))),
        (13 + atraso, pousada),
        (17 + atraso, _desloca(pousada, (0.004, 0.006, -0.006))),
        (25, pousada),
    ]


def anim_levantar(lado=0):
    """73 quadros, uma vez: empurra o chao, solta e volta para a guarda baixa.

    A CAMERA sobe no Godot; aqui as maos so' fazem o que a mao faz quando o
    corpo sobe — a palma desliza para tras e para baixo em relacao ao olho ate'
    sair do apoio.

    A mao ESQUERDA larga o chao primeiro e a direita fica segurando o peso mais
    tempo, como quem se levanta de verdade.
    """
    atraso = 0 if lado == 0 else 8
    apoio = _desloca(CHAO, _assimetria(lado))
    prensa = _desloca(apoio, (0.012, -0.045, -0.055), curl_mult=1.25)
    solta = _desloca(apoio, (0.02, -0.11, -0.13),
                     dedos=(0.16, 0.86, -0.48), palma=(0.30, -0.35, -0.89))
    sobe = _mistura(solta, RELAXADA, 0.55)
    return [
        (1, apoio),
        (6, _desloca(apoio, (0.0, 0.004, -0.010))),
        (16, prensa),
        (26 + atraso, _desloca(prensa, (0.006, -0.018, -0.022))),
        (36 + atraso, solta),
        (46 + atraso, sobe),
        (58, _mistura(sobe, RELAXADA, 0.7)),
        (65, _desloca(RELAXADA, (0.0, 0.02, 0.012))),
        (73, _desloca(RELAXADA, _assimetria(lado))),
    ]


def anim_guardar(lado=0):
    """17 quadros, uma vez: as maos saem de quadro (volta para 3a pessoa)."""
    atraso = 0 if lado == 0 else 2
    return [
        (1, _desloca(RELAXADA, _assimetria(lado))),
        (6, _desloca(RELAXADA, (0.0, 0.03, 0.02))),
        (15 + atraso, GUARDADA),
        (17 + atraso, GUARDADA),
    ]


def anim_sacar(lado=0):
    """13 quadros, uma vez: as maos entram em quadro (entrada da 1a pessoa)."""
    atraso = 0 if lado == 0 else 2
    return [
        (1, GUARDADA),
        (8, _desloca(RELAXADA, (0.0, 0.03, 0.03))),
        (13 + atraso, _desloca(RELAXADA, _assimetria(lado))),
    ]


ANIMACOES = (
    ("idle", anim_idle),
    ("defesa", anim_defesa),
    ("agarrado", anim_agarrado),
    ("mordida", anim_mordida),
    ("arremesso", anim_arremesso),
    ("queda", anim_queda),
    ("chao", anim_chao),
    ("levantar", anim_levantar),
    ("guardar", anim_guardar),
    ("sacar", anim_sacar),
)


# ----------------------------------------------------------------------------
# export
# ----------------------------------------------------------------------------

def empilhar_nla(arm, acoes_por_faixa):
    """Cada acao numa faixa NLA propria, com o NOME DA FAIXA como chave.

    Duas coisas dependem disto:

    1. O exportador em modo ACTIONS nao enxerga acao nenhuma quando o objeto
       usa a API de slots do Blender 5.x. Em NLA_TRACKS ele pega todas.
    2. O nome que vai virar a animacao no Godot e' o da FAIXA, nao o da acao.
       Como as duas maos tem acoes diferentes (`defesa_esq` e `defesa_dir`) mas
       faixas com o mesmo nome (`defesa`), o exportador junta as duas num unico
       clipe `defesa` que mexe nos dois esqueletos. E' isso que faz uma so'
       chamada de `play("defesa")` no Godot animar as duas maos.
    """
    ad = arm.animation_data
    for faixa in list(ad.nla_tracks):
        ad.nla_tracks.remove(faixa)
    ad.action = None
    for nome_faixa, acao in acoes_por_faixa:
        faixa = ad.nla_tracks.new()
        faixa.name = nome_faixa
        tira = faixa.strips.new(nome_faixa, int(acao.frame_start), acao)
        tira.name = nome_faixa
        faixa.mute = True


def exportar(objetos, caminho):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objetos:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objetos[0]

    kw = dict(
        filepath=caminho,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_materials="EXPORT",
        export_skins=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_def_bones=True,      # deixa os cinco ik_* de fora
        export_force_sampling=True,
        export_bake_animation=True,
        export_optimize_animation_size=False,
        # Com DOIS esqueletos no arquivo, juntar tudo num so' quebraria a mao
        # direita: cada uma tem o proprio.
        export_anim_single_armature=False,
        export_frame_range=False,
        export_nla_strips=True,
    )
    try:
        bpy.ops.export_scene.gltf(**kw)
    except TypeError as erro:
        print("export: assinatura diferente (%s), tentando minimo" % erro)
        bpy.ops.export_scene.gltf(
            filepath=caminho, export_format="GLB", use_selection=True,
            export_yup=True, export_animations=True,
            export_animation_mode="NLA_TRACKS", export_def_bones=True)
    return os.path.getsize(caminho)


def raiz_projeto():
    aqui = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else None
    if aqui:
        return os.path.abspath(os.path.join(aqui, "..", "..", ".."))
    return "/home/dev/Documents/Development/Game Development/Red Valve/Red-Valve"


def main():
    arm = bpy.data.objects["Armature"]
    mesh = bpy.data.objects["Mesh0"]
    bpy.context.scene.render.fps = FPS

    comp = preparar(arm)
    limpar_temporarios()
    mesh_esq = criar_mao_esquerda(arm, mesh)
    arm_dir, mesh_dir = criar_mao_direita(arm, mesh_esq)
    preparar(arm_dir)

    lados = ((arm, "esq", 0, False), (arm_dir, "dir", 1, True))
    por_rig = {arm.name: [], arm_dir.name: []}
    for nome, fabrica in ANIMACOES:
        for rig, sufixo, lado, espelhado in lados:
            acao = montar_acao(rig, "%s_%s" % (nome, sufixo), fabrica(lado),
                               comp, espelhado)
            por_rig[rig.name].append((nome, acao))
        print("acao '%s' pronta (as duas maos)" % nome)

    for rig, _s, _l, _e in lados:
        empilhar_nla(rig, por_rig[rig.name])

    caminho = os.path.join(raiz_projeto(), SAIDA_GLB)
    # O `mesh` original fica de FORA da selecao: quem vai no .glb sao as duas
    # copias com o antebraco corrigido.
    tam = exportar([arm, mesh_esq, arm_dir, mesh_dir], caminho)
    print("glb: %s (%.1f MB)" % (caminho, tam / 1048576.0))
    return {"acoes": [n for n, _f in ANIMACOES], "glb": caminho, "bytes": tam}


if __name__ == "__main__":
    main()
