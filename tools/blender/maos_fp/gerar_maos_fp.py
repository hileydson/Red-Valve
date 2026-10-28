# -*- coding: utf-8 -*-
"""Anima a mao de `maos_e_armas/mao_rig_new.blend` para as cenas de primeira
pessoa do jogo e exporta o .glb que o Godot consome.

ATENCAO: OS CLIPES DAQUI NAO SAO MAIS O QUE O JOGO TOCA
-------------------------------------------------------
As animacoes foram copiadas pra `maos_fp_clipes.tres` (um arquivo de verdade,
que o AnimationPlayer do editor deixa editar) e e' de la' que as cenas leem.
Rodar este gerador troca a MALHA, o ESQUELETO e o osso `arma` — e nao troca a
animacao que o jogador ve'. Pra isso, depois de gerar:

    Godot_v4.6.1 --headless --path red-valve \
        res://tools/maos_fp/extrair_clipes.tscn

que reescreve o .tres a partir do .glb, apagando o que tiver sido mexido a mao
no editor. Ver `tools/blender/maos_fp/README.md`.

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
ESTICA = 2.05

# O ESTICA E' ASSADO NO DESCANSO, E NAO APLICADO NA POSE. A diferenca importa.
#
# A primeira versao esticava por ESCALA DE OSSO (`pb_ante.scale.y`). No Blender
# isso funciona: o `mao` tem `inherit_scale='NONE'` e o depsgraph resolve. Mas
# o glTF NAO TEM esse conceito. O exportador amostra a matriz de mundo, calcula
# a local como `pai^-1 @ filho` — que fica CISALHADA, porque a escala do pai
# esta' num eixo e o filho esta' girado em relacao a ele — e decompoe isso em
# posicao/rotacao/escala, jogando o cisalhamento fora.
#
# Medido: no Blender a mao vai do pulso a' base da falange do meio em 0,097 m;
# no Godot, 0,192. A MAO INTEIRA CHEGAVA ~1,8 VEZES MAIOR NO JOGO, e com escala
# diferente a cada pose. O antebraco chegava exato (0,4648 nos dois), o que faz
# o erro passar despercebido: quem olha o braco nao ve' nada errado.
#
# Assando no descanso (`assar_estica_no_descanso`) nao ha' escala em osso
# nenhum: a pose so' gira e translada, o glTF guarda isso sem perda, e a mao
# chega do tamanho em que foi desenhada.

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


def assar_estica_no_descanso(mesh_obj, arm_obj):
    """Estica o antebraco NO DESCANSO: osso e carne, sem escala de pose.

    O antebraco do rig e' um toco de 15 cm — com ele o cotovelo fica sempre
    dentro do quadro e vira uma bola de carne pendurada no meio da tela. Ele
    precisa de uns 32 cm pra sair por baixo, como em todo jogo de primeira
    pessoa.

    A conta e' a mesma que a escala de osso fazia, so' que gravada na malha e
    no osso: cada vertice anda ao longo do eixo do osso por
    `comp * (ESTICA - 1) * (t - 1)`, onde `t` e' 0 na cabeca e 1 na CAUDA. O
    deslocamento e' zero na cauda e cresce pra tras — ou seja, o pulso nao sai
    do lugar e o cotovelo e' que se afasta. O raio nao muda em lugar nenhum:
    o braco fica mais comprido, nao mais grosso.

    Vertices depois da cauda (a mao) ficam parados na marra: `t` entra
    limitado a 1.

    Roda DEPOIS de `engrossar_antebraco`, que mede o perfil no osso original.
    """
    osso = arm_obj.data.bones["antebraco"]
    cabeca = Vector(osso.head_local)
    cauda = Vector(osso.tail_local)
    eixo = (cauda - cabeca).normalized()
    comp = osso.length
    estica = comp * (ESTICA - 1.0)

    grupo = mesh_obj.vertex_groups.get("antebraco")
    if grupo is None:
        return 0
    idx_grupo = grupo.index

    mexidos = 0
    for v in mesh_obj.data.vertices:
        peso = 0.0
        for g in v.groups:
            if g.group == idx_grupo:
                peso = g.weight
        if peso <= 0.001:
            continue
        t = min((Vector(v.co) - cabeca).dot(eixo) / comp, 1.0)
        # PESADO PELO PESO DO VERTICE, e nao aplicado inteiro. E' o que a
        # escala de osso fazia: o skinning linear mistura
        # `w * (osso esticado) + (1-w) * (resto)`, entao o deslocamento e'
        # `w * estica`. Aplicando inteiro, a carne com peso parcial na fronteira
        # (o pulso) se separa da vizinha e a malha RASGA — apareceu na previa
        # como uma borda serrilhada no fim do antebraco.
        v.co = Vector(v.co) + eixo * (estica * (t - 1.0) * peso)
        mexidos += 1
    mesh_obj.data.update()

    # E o OSSO: a cauda fica onde esta' (e' o pulso, e o `mao` esta' preso
    # nela); quem anda pra tras e' a cabeca.
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_obj.data.edit_bones["antebraco"]
    eb.head = cauda - eixo * comp * ESTICA
    bpy.ops.object.mode_set(mode='OBJECT')
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
    # Nesta ordem: o `engrossar` mede o perfil no osso ORIGINAL, e o `assar`
    # muda o osso. Invertido, o perfil sairia medido num braco que ja' e' o
    # dobro do comprimento e a correcao de raio cairia no lugar errado.
    assar_estica_no_descanso(copia, arm)
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


## Nome do osso SOLTO que carrega a arma. Ver `criar_osso_da_arma`.
NOME_OSSO_ARMA = "arma"


def criar_osso_da_arma(arm):
    """Um osso sem PAI, so' pra pendurar a arma nele.

    POR QUE NAO PENDURAR NO OSSO `mao`, QUE E' ONDE A ARMA ESTA'
    ------------------------------------------------------------
    Porque o `antebraco` e' ESTICADO por escala de osso (`ESTICA`), e escala
    nao-uniforme num pai ENVENENA todos os filhos.

    No Blender isso nao aparece: o `mao` tem `inherit_scale='NONE'` e o
    depsgraph resolve certo. Mas o glTF nao tem esse conceito. O exportador
    amostra a matriz de mundo, calcula a local como
    `pai_mundo^-1 @ filho_mundo` — que fica CISALHADA, porque a escala do pai
    esta' num eixo e o filho esta' girado em relacao a ele — e entao decompoe
    isso em posicao/rotacao/escala, jogando o cisalhamento fora.

    O estrago e' invisivel na malha (a pele acompanha o erro) e fatal pra
    qualquer coisa PENDURADA no osso: medido no Godot, a pose global do `mao`
    chegava com escala (1,30 / 1,93 / 1,37) em vez de (1/1/1), e pior, com
    numeros DIFERENTES a cada pose. Uma arma presa ali nao fica rigida: ela
    escorrega da mao conforme o punho gira. Foi exatamente o que aconteceu — o
    cabo ficava a 21 cm do punho no meio da troca de arma.

    Um osso de raiz nao tem pai, nao tem escala e nao tem esse problema: a
    pose dele E' o quadro da arma, e chega no Godot intacta.
    """
    bpy.context.view_layer.objects.active = arm
    if NOME_OSSO_ARMA in arm.data.bones:
        return
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones.new(NOME_OSSO_ARMA)
    eb.head = (0.0, 0.0, 0.0)
    eb.tail = (0.0, 1.0, 0.0)
    eb.roll = 0.0
    eb.parent = None
    # `use_deform` porque o export vai com "Deform Bones Only" (e' o que deixa
    # os cinco `ik_*` de fora). Osso de deformacao sem peso nenhum nao deforma
    # nada — so' viaja junto.
    eb.use_deform = True
    bpy.ops.object.mode_set(mode='OBJECT')


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
    #
    # `cru` PULA os dois. Quem segura uma arma de duas maos nao pode passar por
    # aqui: o punho esquerdo vai no fore-end, que esta' a meio metro do olho, e
    # o teto de 0,28 arrancaria a mao do cano. O teto existe para as poses de
    # mao VAZIA, onde a profundidade e' enquadramento; com arma ela e'
    # geometria, e quem manda e' a arma.
    if pose.get("cru", False):
        metros = Vector(pose["pulso"])
    else:
        metros = Vector(pose["pulso"]) - Vector((0.0, RECUO_DAS_MAOS, 0.0))
        metros.y = _profundidade(metros.y)
    pulso = _m(metros) * Vector((s, 1.0, 1.0))
    dedos = Vector(pose["dedos"]) * Vector((s, 1.0, 1.0))
    palma = Vector(pose["palma"]) * Vector((s, 1.0, 1.0))
    dedos.normalize()
    palma.normalize()

    ombro = _m(pose.get("ombro", OMBRO)) * Vector((s, 1.0, 1.0))
    dir_antebraco = (pulso - ombro).normalized()
    # `comp_antebraco` JA' VEM ESTICADO: o esticao mora no descanso (ver
    # `assar_estica_no_descanso`). Nao ha' escala de osso em lugar nenhum
    # deste arquivo, e e' de proposito.
    cotovelo = pulso - dir_antebraco * comp_antebraco

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
    bpy.context.view_layer.update()

    pb_mao = arm.pose.bones["mao"]
    pb_mao.matrix = _matriz(pulso, dedos, palma)
    bpy.context.view_layer.update()

    # O osso solto da arma, se esta pose tiver arma. Fora das poses de arma
    # ele volta pro descanso — e' um osso sem uso nos clipes de mao vazia.
    pb_arma = arm.pose.bones.get(NOME_OSSO_ARMA)
    if pb_arma is not None:
        quadro = pose.get("arma_quadro")
        pb_arma.matrix = Matrix.Identity(4) if quadro is None \
            else quadro_do_osso(quadro)
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
    # Duas poses de arma sempre sao as duas `cru`; misturar uma crua com uma
    # normal nao acontece, e se acontecer vale a de origem.
    out["cru"] = a.get("cru", False) or b.get("cru", False)
    if "ombro" in a or "ombro" in b:
        out["ombro"] = a.get("ombro", b.get("ombro"))
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
# AS ARMAS NA MAO
# ----------------------------------------------------------------------------
#
# AQUI A ARMA VEM PRIMEIRO. E' o contrario da terceira pessoa.
#
# No Maycow normal (`player_shotgun_hold.gd`) a mao tem lugar e a arma e'
# pousada nela: o que importa la' e' o corpo, e uma arma fora da mao denuncia
# na hora. Em primeira pessoa nao ha' corpo nenhum — o que o jogador ve' e' a
# ARMA, e o enquadramento dela na tela e' o assunto. Entao aqui se diz onde a
# arma esta' e pra onde ela aponta, e as duas maos sao DERIVADAS dela.
#
# A consequencia pratica e' boa: como as duas maos saem da mesma matriz da
# arma, elas nunca se soltam dela, em nenhum quadro de nenhuma animacao. E o
# Godot nem precisa saber desses numeros: la' a arma e' pendurada no osso
# `mao` da direita por um BoneAttachment3D, e o deslocamento constante que faz
# ela cair na mao e' MEDIDO aqui e impresso no fim (ver `offset_no_osso`).
#
# ESPACO DO MODELO
# ----------------
# Como o .glb chega ao Blender (que desfaz o Y-up do gltf):
#
#     -X = pra onde o cano aponta      +Z = o topo da arma      +-Y = os lados
#
# No Godot esse mesmo modelo tem topo +Y e lados +-Z. Os numeros da cacadeira
# sao os MESMOS de `player_shotgun_hold.gd` com Y e Z trocados — mexeu la',
# muda aqui.

ARMAS = {
    "pistola": {
        # 1,92 unidade de ponta a ponta; 0,115 devolve 22 cm de pistola.
        "escala": 0.145,
        # Onde o punho fecha: o meio do cabo, logo abaixo do ferrolho.
        "cabo": Vector((0.60, 0.0, -0.28)),
        # O furo do cano. Fica ALTO no modelo (z 0,50), nao na linha do cabo.
        "boca": Vector((-0.95, 0.0, 0.50)),
        # Pra onde os dedos da mao que segura apontam. Quem fecha a mao num
        # cabo de pistola poe os nos dos dedos na FRENTE do cabo, entao o
        # caminho pulso -> nos corre quase paralelo ao cano, caindo um pouco.
        "eixo_cabo": Vector((-0.92, 0.0, -0.39)),
        # Pistola e' de uma mao so'.
        "apoio": None,
    },
    "shotgun": {
        # 1,913 unidade; 0,335 devolve os mesmos 64 cm da terceira pessoa.
        "escala": 0.300,
        "cabo": Vector((0.50, 0.0, -0.03)),
        "boca": Vector((-0.93, 0.0, -0.01)),
        "eixo_cabo": Vector((-0.88, 0.0, -0.47)),
        # Onde a mao ESQUERDA fecha: em cima do bloco dos canos.
        #
        # Bem mais PERTO da culatra que o ponto da terceira pessoa (-0,35).
        # Em primeira pessoa o cano corre quase na direcao do olho, entao os
        # 17 cm de cano que sobravam na frente da mao viravam um toco de 90
        # pixels na tela — a arma nao lia como cacadeira. Recuando a mao, o
        # cano aparece, e de quebra o braco esquerdo estica menos.
        "apoio": Vector((-0.12, 0.0, 0.15)),
        # O pino da dobradica e a culatra, pra recarga.
        "charneira": Vector((-0.030, 0.0, 0.057)),
        "camara": Vector((-0.030, 0.0, 0.127)),
    },
}


def quadro_arma(arma, cabo, frente, rolagem=0.0):
    """Matriz MODELO -> CAMERA (metros) de uma arma posta na tela.

    `cabo` e' onde o punho da arma fica, em metros no espaco da camera;
    `frente` e' pra onde o cano aponta; `rolagem` tomba a arma em volta do
    proprio cano (positivo = o topo cai pra direita).
    """
    d = Vector(frente).normalized()
    cima = Vector((0.0, 0.0, 1.0))
    lado = d.cross(cima)
    if lado.length < 1e-4:
        lado = Vector((1.0, 0.0, 0.0))
    lado.normalize()
    cima = lado.cross(d).normalized()
    if rolagem:
        giro = Matrix.Rotation(rolagem, 4, d)
        cima = (giro @ cima).normalized()
    # O modelo tem o cano no -X e o topo no +Z; o +Y sai do produto vetorial
    # pra base ficar destra, que e' o que o Blender espera.
    ex = -d
    ez = cima
    ey = ez.cross(ex).normalized()
    e = ARMAS[arma]["escala"]
    base = Matrix((
        (ex.x * e, ey.x * e, ez.x * e),
        (ex.y * e, ey.y * e, ez.y * e),
        (ex.z * e, ey.z * e, ez.z * e),
    )).to_4x4()
    base.translation = Vector(cabo) - (base.to_3x3() @ ARMAS[arma]["cabo"])
    return base


def quadro_do_osso(quadro):
    """Quadro da arma (modelo -> camera, em metros) -> matriz do osso `arma`.

    Duas mudancas: o osso vive nas unidades do rig (metros x UNI) e NAO leva
    escala nenhuma. A escala do modelo fica pro Godot — um osso com escala
    devolveria o mesmo problema que este osso existe pra evitar.
    """
    base = quadro.to_3x3()
    escala = base.col[0].length
    m = (base * (1.0 / escala)).to_4x4()
    m.translation = _m(quadro.translation)
    return m


def ponto_arma(quadro, p):
    """Ponto do modelo -> ponto em metros no espaco da camera."""
    return quadro @ Vector(p)


def direcao_arma(quadro, v):
    """Direcao do modelo -> direcao (unitaria) no espaco da camera."""
    return (quadro.to_3x3() @ Vector(v)).normalized()


# Quanto o PULSO fica atras dos nos dos dedos, em metros. A mao tem 0,19 m do
# pulso a' ponta do indicador; o ponto onde ela fecha em volta de um cabo cai
# mais ou menos no meio da palma.
RECUO_DO_PUNHO = 0.072

# Punho fechado em volta de um cabo. O indicador fica MENOS fechado que os
# outros: ele esta' no gatilho, nao no cabo.
GARRA = {
    "indicador": (0.72, 0.82, 0.38),
    "medio": (0.98, 1.24, 0.82),
    "anelar": (1.00, 1.26, 0.84),
    "mindinho": (1.02, 1.28, 0.82),
    "polegar": (0.52, 0.58, 0.46),
}
GARRA_ABRE = {"indicador": -0.12, "medio": -0.02, "anelar": 0.05,
              "mindinho": 0.12, "polegar": -0.30}

# Mao de apoio em volta de um cano: fecha inteira, inclusive o indicador.
ABRACO = {
    "indicador": (0.96, 1.20, 0.80),
    "medio": (1.00, 1.24, 0.84),
    "anelar": (1.02, 1.26, 0.84),
    "mindinho": (1.04, 1.28, 0.82),
    "polegar": (0.44, 0.40, 0.30),
}
ABRACO_ABRE = {"indicador": -0.10, "medio": 0.0, "anelar": 0.06,
               "mindinho": 0.14, "polegar": -0.24}


# ----------------------------------------------------------------------------
# ONDE CADA ARMA FICA NA TELA
# ----------------------------------------------------------------------------
#
# Estes sao os numeros de ENQUADRAMENTO, e sao eles que se mexe quando a arma
# "esta' feia na tela". Tudo o mais (as duas maos, os dedos, o antebraco) sai
# daqui por conta propria.
#
# A camera do jogo tem 75 graus na VERTICAL e a tela e' 16:9, entao a meia-tela
# a um metro de distancia mede 0,767 de altura e 1,364 de largura. E' com isso
# que se le' uma posicao: (x / y) / 1,364 e' a fracao da meia-tela na
# horizontal, (z / y) / 0,767 na vertical.
#
# A coronha e' o que aperta. Ela sai 15 cm ATRAS do punho, e com a arma
# apontada reto pra frente isso poe a madeira a 15 cm do olho, ocupando meia
# tela. Por isso as duas armas apontam pra ESQUERDA dele: assim a coronha sai
# de quadro pelo canto de baixo, que e' o que todo jogo de tiro faz.

CABO_PISTOLA = Vector((0.165, 0.265, -0.140))
FRENTE_PISTOLA = Vector((-0.42, 0.870, 0.26))
ROLAGEM_PISTOLA = math.radians(-8.0)

CABO_SHOTGUN = Vector((0.170, 0.262, -0.155))
FRENTE_SHOTGUN = Vector((-0.55, 0.780, 0.30))
ROLAGEM_SHOTGUN = math.radians(-14.0)


def pegada_base(arma):
    """Onde a arma fica parada: (cabo, frente, rolagem).

    E' a pose de referencia da pegada — a que o `offset_no_osso` usa pra medir
    onde a arma cai em relacao ao osso da mao.
    """
    if arma == "pistola":
        return CABO_PISTOLA, FRENTE_PISTOLA, ROLAGEM_PISTOLA
    return CABO_SHOTGUN, FRENTE_SHOTGUN, ROLAGEM_SHOTGUN


def _espelhar(v, espelhado):
    """A pose da mao direita e' escrita com o X negado.

    `aplicar_pose(espelhado=True)` nega o X de tudo. Como aqui os pontos saem
    de uma matriz no espaco REAL da camera, eles tem de ser pre-negados pra
    chegar de volta onde foram calculados.
    """
    return (-v.x, v.y, v.z) if espelhado else (v.x, v.y, v.z)


## A ANCORA do braco desce e recua nas poses de arma.
##
## O `OMBRO` normal fica 20 cm atras do olho e 62 abaixo. Com a arma na mao o
## pulso sobe pro meio da tela, e a reta ombro -> pulso passa RASPANDO a
## camera: o cotovelo caia a 7 milimetros da lente, e o que aparecia era a
## ponta oca do antebraco ocupando um quarto da tela — um tubo branco
## atravessado no quadro, que nem parecia braco.
##
## Baixar e recuar a ancora nao muda a mao de lugar (quem manda nela e' a
## arma): muda so' por ONDE o antebraco entra no quadro. Com esta, o cotovelo
## sai por baixo ou fica atras do olho, que e' o certo.
OMBRO_ARMA = Vector((-0.30, -0.42, -0.78))

## Quanto o osso do pulso fica pro LADO do que a mao segura.
##
## E' o numero que faltava na primeira versao e que fazia a arma parecer
## enfiada DENTRO da mao: o cabo nao corre pelo eixo do osso, ele encosta na
## PALMA, meia mao pro lado. Sem este desvio a arma atravessava os dedos.
DESVIO_DA_PALMA = 0.036


def mao_na_arma(quadro, ponto, eixo, palma_modelo, espelhado,
                curl=None, abrir=None, recuo=RECUO_DO_PUNHO, torcao=0.0,
                desvio=DESVIO_DA_PALMA):
    """Pose de uma mao fechada num ponto da arma.

    `ponto` e `eixo` sao do MODELO: onde a mao fecha e pra onde os dedos
    apontam a partir do pulso. `palma_modelo` e' pra onde a palma olha, e o
    pulso recua tambem pelo AVESSO dela — e' o que poe o cabo na palma em vez
    de dentro do osso.
    """
    p = ponto_arma(quadro, ponto)
    dedos = direcao_arma(quadro, eixo)
    palma = direcao_arma(quadro, palma_modelo)
    pulso = p - dedos * recuo - palma * desvio
    return {
        "arma_quadro": quadro,
        "pulso": _espelhar(pulso, espelhado),
        "dedos": _espelhar(dedos, espelhado),
        "palma": _espelhar(palma, espelhado),
        "curl": dict(curl if curl is not None else GARRA),
        "abrir": dict(abrir if abrir is not None else GARRA_ABRE),
        "torcao": torcao,
        "ombro": OMBRO_ARMA,
        # Arma na mao nao passa pelo teto de profundidade: ver `aplicar_pose`.
        "cru": True,
    }


def pose_de_arma(arma, lado, cabo, frente, rolagem=0.0, solta=None):
    """A pose das DUAS maos para uma arma posta na tela.

    `lado` 0 = esquerda, 1 = direita. `solta` substitui a pose da mao esquerda
    quando ela nao esta' na arma (recarga, troca) — recebe o quadro da arma e
    devolve uma pose.
    """
    quadro = quadro_arma(arma, cabo, frente, rolagem)
    espelhado = (lado == 1)
    if lado == 1:
        # A direita e' a que segura. Palma virada pro lado de dentro da arma.
        return mao_na_arma(quadro, ARMAS[arma]["cabo"], ARMAS[arma]["eixo_cabo"],
                           (0.0, -1.0, 0.0), espelhado)
    if solta is not None:
        return solta(quadro)
    apoio = ARMAS[arma]["apoio"]
    if apoio is None:
        # Arma de uma mao: a esquerda fica solta, fora do caminho.
        return _desloca(RELAXADA, (0.10, -0.02, -0.06))
    # Mao de apoio: vem por baixo do cano, dedos subindo e passando por cima.
    return mao_na_arma(quadro, apoio, (-0.15, 0.25, 0.96), (0.0, 0.96, -0.25),
                       espelhado, ABRACO, ABRACO_ABRE)


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


# ----------------------------------------------------------------------------
# as animacoes DE ARMA
# ----------------------------------------------------------------------------
#
# Todas saem do mesmo lugar: uma lista de (quadro, cabo, frente, rolagem) diz
# onde a ARMA esta' em cada chave, e as duas maos caem nela sozinhas. Nao ha'
# uma unica pose de mao escrita a mao neste bloco — se a arma se mexe, as maos
# se mexem junto, e nao ha' como uma descolar da outra.
#
# A mao ESQUERDA e' a excecao, e so' na recarga: la' ela larga a arma, e por
# isso ganha poses proprias (`_cinto`, `_no_cartucho`).


def _girar(frente, cima_graus, lado_graus=0.0):
    """Aponta o cano `cima_graus` pra cima e `lado_graus` pra esquerda dele."""
    d = Vector(frente).normalized()
    lado = d.cross(Vector((0.0, 0.0, 1.0)))
    if lado.length < 1e-4:
        lado = Vector((1.0, 0.0, 0.0))
    lado.normalize()
    d = (Matrix.Rotation(math.radians(cima_graus), 4, lado) @ d)
    d = (Matrix.Rotation(math.radians(lado_graus), 4, Vector((0.0, 0.0, 1.0))) @ d)
    return d.normalized()


def _arma_em(arma, lado, chaves):
    """[(quadro, cabo, frente, rolagem)] -> [(quadro, pose)] da mao do `lado`."""
    return [(q, pose_de_arma(arma, lado, cabo, frente, rolagem))
            for q, cabo, frente, rolagem in chaves]


def _respirar(cabo, frente, fase, forca=1.0):
    """Sobe-e-desce de quem esta' parado com a arma na mao.

    Os tres eixos usam SENO, e nao seno e cosseno: com fase 0 o desvio tem de
    dar zero. O quadro 1 do `<arma>_idle` e' a pose CANONICA da pegada, e e'
    dela que o Godot mede onde a arma cai em relacao ao osso da mao
    (`maos_fp_armas.gd`). Um cosseno aqui punha 3 mm de respiracao nessa
    medida, e a arma ficava 3 mm fora da mao pra sempre.
    """
    d = Vector((
        math.sin(fase) * 0.004,
        math.sin(fase * 0.8) * 0.003,
        math.sin(fase * 2.0) * 0.006,
    )) * forca
    return Vector(cabo) + d, _girar(frente, math.sin(fase * 1.3) * 0.7 * forca)


## A esquerda some de quadro nas animacoes de pistola: quem cuida dela ali e'
## a OUTRA copia do rig (a "mao magica"), que tem vida propria. Ver o
## cabecalho do maos_fp_armas.gd no Godot.
def _esquerda_fora(lado, quadros):
    return [(q, GUARDADA) for q in quadros]


def anim_pistola_idle(lado=0):
    """61 quadros em laco: pistola na mao, so' a respiracao."""
    if lado == 0:
        return _esquerda_fora(lado, (1, 31, 61))
    chaves = []
    for i in range(0, 7):
        q = 1 + i * 10
        fase = (i % 6) / 6.0 * math.tau
        cabo, frente = _respirar(CABO_PISTOLA, FRENTE_PISTOLA, fase)
        chaves.append((q, cabo, frente, ROLAGEM_PISTOLA))
    return _arma_em("pistola", lado, chaves)


def anim_pistola_tiro(lado=0):
    """15 quadros, uma vez: o coice.

    Sobe rapido e volta devagar — coice que sobe e desce no mesmo tempo nao
    le' como coice, le' como tremor.
    """
    if lado == 0:
        return _esquerda_fora(lado, (1, 15))
    recuo = -Vector(FRENTE_PISTOLA).normalized() * 0.022
    chaves = [
        (1, CABO_PISTOLA, FRENTE_PISTOLA, ROLAGEM_PISTOLA),
        (3, Vector(CABO_PISTOLA) + recuo, _girar(FRENTE_PISTOLA, 11.0),
         ROLAGEM_PISTOLA - math.radians(4.0)),
        (6, Vector(CABO_PISTOLA) + recuo * 0.5, _girar(FRENTE_PISTOLA, 6.0),
         ROLAGEM_PISTOLA - math.radians(2.0)),
        (10, Vector(CABO_PISTOLA) + recuo * 0.15, _girar(FRENTE_PISTOLA, 2.0),
         ROLAGEM_PISTOLA),
        (15, CABO_PISTOLA, FRENTE_PISTOLA, ROLAGEM_PISTOLA),
    ]
    return _arma_em("pistola", lado, chaves)


def anim_shotgun_idle(lado=0):
    """61 quadros em laco: cacadeira nas duas maos, parada."""
    chaves = []
    for i in range(0, 7):
        q = 1 + i * 10
        fase = (i % 6) / 6.0 * math.tau
        cabo, frente = _respirar(CABO_SHOTGUN, FRENTE_SHOTGUN, fase, 1.2)
        chaves.append((q, cabo, frente, ROLAGEM_SHOTGUN))
    return _arma_em("shotgun", lado, chaves)


def anim_shotgun_tiro(lado=0):
    """21 quadros, uma vez: o coice de doze."""
    recuo = -Vector(FRENTE_SHOTGUN).normalized() * 0.045
    chaves = [
        (1, CABO_SHOTGUN, FRENTE_SHOTGUN, ROLAGEM_SHOTGUN),
        (4, Vector(CABO_SHOTGUN) + recuo, _girar(FRENTE_SHOTGUN, 17.0, -3.0),
         ROLAGEM_SHOTGUN - math.radians(7.0)),
        (8, Vector(CABO_SHOTGUN) + recuo * 0.55, _girar(FRENTE_SHOTGUN, 10.0),
         ROLAGEM_SHOTGUN - math.radians(3.0)),
        (14, Vector(CABO_SHOTGUN) + recuo * 0.18, _girar(FRENTE_SHOTGUN, 3.0),
         ROLAGEM_SHOTGUN),
        (21, CABO_SHOTGUN, FRENTE_SHOTGUN, ROLAGEM_SHOTGUN),
    ]
    return _arma_em("shotgun", lado, chaves)


# ---------------------------------------------------------------- a recarga
#
# A LINHA DO TEMPO E' A MESMA DA TERCEIRA PESSOA. Os numeros abaixo sao copia
# dos M_* de `player_shotgun_hold.gd` e dos MOMENTO_* de `player_combat.gd`:
# o gesto e' o mesmo e os sons sao os mesmos, entao os tres arquivos tem de
# concordar. Mexeu num, mexe nos tres.
#
# 3,6 s a 30 quadros = 108 quadros. O clipe e' autorado com esse tamanho e o
# Godot toca ele na velocidade 1.

QUADROS_RECARGA = 108

R_ABRE_INICIO = 0.08
R_ABRE_FIM = 0.20
R_VIRA_INICIO = 0.22
R_VIRA_FIM = 0.30
R_DESVIRA_INICIO = 0.34
R_DESVIRA_FIM = 0.42
R_LARGA = 0.42
R_BALA1_PEGA = 0.48
R_BALA1_ENTRA = 0.60
R_BALA2_PEGA = 0.72
R_BALA2_ENTRA = 0.84
R_VOLTA = 0.90
R_FECHA_INICIO = 0.90
R_FECHA_FIM = 0.97

## Quanto a arma abre, em graus. O mesmo `ABERTURA` de
## `player_shotgun_hold.gd`: abaixo de 25 o cartucho nao passa pela culatra.
ABERTURA_SHOTGUN = 32.0


def abertura_da_recarga(quadro):
    """Quanto a dobra esta' aberta no quadro `quadro` do clipe de recarga.

    A dobra NAO vai no .glb: ela e' um no' da arma, e a arma nao faz parte do
    rig das maos. Quem abre e' o `maos_fp_armas.gd` no Godot, com esta MESMA
    conta — aqui ela existe pra previa mostrar a verdade.
    """
    r = float(quadro) / QUADROS_RECARGA
    if r <= R_ABRE_INICIO or r >= R_FECHA_FIM:
        return 0.0
    if r < R_ABRE_FIM:
        t = (r - R_ABRE_INICIO) / (R_ABRE_FIM - R_ABRE_INICIO)
        return ABERTURA_SHOTGUN * (t * t * (3.0 - 2.0 * t))
    if r <= R_FECHA_INICIO:
        return ABERTURA_SHOTGUN
    t = (r - R_FECHA_INICIO) / (R_FECHA_FIM - R_FECHA_INICIO)
    return ABERTURA_SHOTGUN * (1.0 - t * t * (3.0 - 2.0 * t))


def _q(fracao):
    """Fracao do gesto -> quadro do clipe."""
    return max(1, int(round(fracao * QUADROS_RECARGA)))


## Pra onde a arma vai enquanto e' recarregada: mais pro meio da tela, com a
## culatra virada pro olho. Em terceira pessoa ela vai PRA FRENTE pelo mesmo
## motivo que aqui ela vem pro meio — a culatra tem de estar onde os olhos
## alcancam.
CABO_RECARGA = Vector((0.080, 0.360, -0.090))
FRENTE_RECARGA = Vector((-0.62, 0.62, -0.48))
ROLAGEM_RECARGA = math.radians(-52.0)
## E o quanto ela tomba a MAIS pra despejar as capsulas.
ROLAGEM_EJETA = math.radians(-118.0)


## Onde a mao esquerda fica quando esta' no cinto, buscando cartucho: fora de
## quadro pelo canto de baixo, do lado dela.
CINTO = {
    "pulso": (-0.195, 0.235, -0.330),
    "dedos": (0.18, 0.80, -0.57),
    "palma": (0.88, -0.02, 0.47),
    "curl": {"indicador": (0.70, 0.95, 0.72), "medio": (0.74, 1.00, 0.76),
             "anelar": (0.72, 0.98, 0.74), "mindinho": (0.70, 0.96, 0.70),
             "polegar": (0.48, 0.52, 0.40)},
    "abrir": {"indicador": -0.08, "medio": 0.0, "anelar": 0.06,
              "mindinho": 0.14, "polegar": -0.18},
    "cru": True,
    "ombro": OMBRO_ARMA,
}


def _mao_na_camara(quadro, recuo_extra=0.0):
    """A esquerda encostando o cartucho na boca da camara."""
    camara = Vector(ARMAS["shotgun"]["camara"])
    # O cartucho entra pela culatra, entao a mao vem de TRAS dela, ao longo do
    # cano, e nao de cima.
    fora = direcao_arma(quadro, (1.0, 0.0, 0.0))
    ponto = ponto_arma(quadro, camara) + fora * (0.030 + recuo_extra)
    dedos = direcao_arma(quadro, (-0.92, 0.0, -0.39))
    palma = direcao_arma(quadro, (0.0, 1.0, 0.0))
    pulso = ponto - dedos * 0.070 - palma * 0.030
    return {
        "arma_quadro": quadro,
        "pulso": tuple(pulso), "dedos": tuple(dedos), "palma": tuple(palma),
        # Dedos quase fechados: ela esta' segurando um cartucho entre o polegar
        # e o indicador, nao agarrando a arma.
        "curl": {"indicador": (0.62, 0.72, 0.58), "medio": (0.86, 1.10, 0.74),
                 "anelar": (0.92, 1.14, 0.78), "mindinho": (0.96, 1.18, 0.76),
                 "polegar": (0.40, 0.56, 0.52)},
        "abrir": {"indicador": -0.14, "medio": -0.02, "anelar": 0.06,
                  "mindinho": 0.14, "polegar": -0.26},
        "cru": True,
        "ombro": OMBRO_ARMA,
    }


def anim_shotgun_recarga(lado=0):
    """108 quadros (3,6 s), uma vez: abre, despeja, dois cartuchos, fecha."""
    # --- onde a ARMA esta' em cada chave -------------------------------------
    base = (CABO_SHOTGUN, FRENTE_SHOTGUN, ROLAGEM_SHOTGUN)
    posto = (CABO_RECARGA, FRENTE_RECARGA, ROLAGEM_RECARGA)
    virado = (CABO_RECARGA, FRENTE_RECARGA, ROLAGEM_EJETA)
    chaves = [
        (1,) + base,
        (_q(R_ABRE_INICIO),) + posto,
        (_q(R_VIRA_INICIO),) + posto,
        (_q(R_VIRA_FIM),) + virado,
        (_q(R_DESVIRA_INICIO),) + virado,
        (_q(R_DESVIRA_FIM),) + posto,
        (_q(R_BALA1_ENTRA),) + posto,
        (_q(R_BALA2_ENTRA),) + posto,
        (_q(R_VOLTA),) + posto,
        (QUADROS_RECARGA,) + base,
    ]

    if lado == 1:
        return _arma_em("shotgun", lado, chaves)

    # --- a mao ESQUERDA, que larga a arma no meio ----------------------------
    #
    # Ate' `R_LARGA` ela esta' no fore-end e acompanha a arma; dai em diante
    # ela e' escrita a parte, e volta pro cano no fim.
    esq = []
    for q, cabo, frente, rolagem in chaves:
        if q <= _q(R_LARGA):
            esq.append((q, pose_de_arma("shotgun", 0, cabo, frente, rolagem)))
    quadro_posto = quadro_arma("shotgun", *posto)
    esq += [
        (_q(R_BALA1_PEGA), CINTO),
        (_q(R_BALA1_ENTRA), _mao_na_camara(quadro_posto)),
        (_q(R_BALA1_ENTRA) + 4, _mao_na_camara(quadro_posto, 0.020)),
        (_q(R_BALA2_PEGA), CINTO),
        (_q(R_BALA2_ENTRA), _mao_na_camara(quadro_posto)),
        (_q(R_BALA2_ENTRA) + 4, _mao_na_camara(quadro_posto, 0.020)),
        (_q(R_VOLTA), pose_de_arma("shotgun", 0, *posto)),
        (QUADROS_RECARGA, pose_de_arma("shotgun", 0, *base)),
    ]
    esq.sort(key=lambda par: par[0])
    # Duas chaves no mesmo quadro fazem o exportador engasgar; a ultima vence.
    limpo = []
    for par in esq:
        if limpo and limpo[-1][0] == par[0]:
            limpo[-1] = par
        else:
            limpo.append(par)
    return limpo


## Onde a arma fica quando ele a ABAIXA pra trocar de arma: fora de quadro
## pelo canto de baixo, cano pro chao.
CABO_ABAIXADA = Vector((0.230, 0.235, -0.400))
FRENTE_ABAIXADA = Vector((-0.30, 0.42, -0.86))


def _troca(arma, lado, guardando):
    """A arma descendo pra fora de quadro, ou subindo de la'."""
    cabo = CABO_PISTOLA if arma == "pistola" else CABO_SHOTGUN
    frente = FRENTE_PISTOLA if arma == "pistola" else FRENTE_SHOTGUN
    rolagem = ROLAGEM_PISTOLA if arma == "pistola" else ROLAGEM_SHOTGUN
    alto = (cabo, frente, rolagem)
    baixo = (CABO_ABAIXADA, FRENTE_ABAIXADA, rolagem - math.radians(18.0))
    if guardando:
        chaves = [(1,) + alto, (5,) + alto, (14,) + baixo, (16,) + baixo]
    else:
        chaves = [(1,) + baixo, (10,) + alto, (14,) + alto]
    return _arma_em(arma, lado, chaves)


def anim_shotgun_guardar(lado=0):
    """16 quadros: a arma desce e sai de quadro. Primeira metade da troca."""
    return _troca("shotgun", lado, True)


def anim_shotgun_sacar(lado=0):
    """14 quadros: a arma sobe pro lugar. Segunda metade da troca."""
    return _troca("shotgun", lado, False)


def anim_pistola_guardar(lado=0):
    if lado == 0:
        return _esquerda_fora(lado, (1, 16))
    return _troca("pistola", lado, True)


def anim_pistola_sacar(lado=0):
    if lado == 0:
        return _esquerda_fora(lado, (1, 14))
    return _troca("pistola", lado, False)


# ---------------------------------------------------------------- a mao magica
#
# Estes quatro nomes NAO sao escolha: sao os estados que a AnimationTree da mao
# esquerda ja' tinha no player.tscn, e que `player_combat.gd` procura por nome
# (`safe_travel(hand_magic_tree, "magic_reload")`). A mao mudou de modelo; o
# vocabulario de quem chama, nao.
#
# Eles so' valem pra copia ESQUERDA do rig — a direita nunca toca estes
# clipes, e por isso a pose dela aqui e' a de fora de quadro.


def _so_esquerda(lado, quadros_poses):
    if lado == 1:
        return [(q, GUARDADA) for q, _p in quadros_poses]
    return quadros_poses


def anim_magic_holding_gun(lado=0):
    """41 quadros em laco: mao esquerda solta, ao lado da arma."""
    base = _desloca(RELAXADA, (0.075, -0.01, -0.035))
    quadros = []
    for i in range(0, 5):
        q = 1 + i * 10
        fase = (i % 4) / 4.0 * math.tau
        quadros.append((q, _desloca(base, (
            math.sin(fase) * 0.005,
            math.cos(fase) * 0.003,
            math.sin(fase * 2.0) * 0.009,
        ))))
    return _so_esquerda(lado, quadros)


def anim_magic_holding_shoot(lado=0):
    """11 quadros: a esquerda se fecha no tranco do tiro."""
    base = _desloca(RELAXADA, (0.075, -0.01, -0.035))
    quadros = [
        (1, base),
        (3, _desloca(base, (0.005, -0.02, -0.022), curl_mult=1.35)),
        (7, _desloca(base, (0.002, -0.01, -0.008), curl_mult=1.12)),
        (11, base),
    ]
    return _so_esquerda(lado, quadros)


def anim_magic_reload(lado=0):
    """31 quadros: desce ao cinto, pega o pente e sobe."""
    base = _desloca(RELAXADA, (0.075, -0.01, -0.035))
    quadros = [
        (1, base),
        (8, CINTO),
        (13, CINTO),
        (22, _desloca(base, (-0.03, 0.03, 0.03), curl_mult=1.25)),
        (31, base),
    ]
    return _so_esquerda(lado, quadros)


def anim_magic_thrown(lado=0):
    """21 quadros: o soco/empurrao da mao esquerda."""
    quadros = [
        (1, _desloca(RELAXADA, (0.075, -0.01, -0.035))),
        (7, EMPURRA),
        (12, EMPURRA),
        (21, _desloca(RELAXADA, (0.075, -0.01, -0.035))),
    ]
    return _so_esquerda(lado, quadros)


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
    # --- de arma (primeira pessoa) ---
    ("pistola_idle", anim_pistola_idle),
    ("pistola_tiro", anim_pistola_tiro),
    ("pistola_guardar", anim_pistola_guardar),
    ("pistola_sacar", anim_pistola_sacar),
    ("shotgun_idle", anim_shotgun_idle),
    ("shotgun_tiro", anim_shotgun_tiro),
    ("shotgun_recarga", anim_shotgun_recarga),
    ("shotgun_guardar", anim_shotgun_guardar),
    ("shotgun_sacar", anim_shotgun_sacar),
    # --- a mao esquerda sozinha (nomes que a AnimationTree ja' procurava) ---
    ("magic_holding_gun", anim_magic_holding_gun),
    ("magic_holding_shoot", anim_magic_holding_shoot),
    ("magic_reload", anim_magic_reload),
    ("magic_thrown", anim_magic_thrown),
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

    preparar(arm)
    limpar_temporarios()
    mesh_esq = criar_mao_esquerda(arm, mesh)
    arm_dir, mesh_dir = criar_mao_direita(arm, mesh_esq)
    # DEPOIS de espelhar: o osso da arma nao tem lado, e passar ele pelo
    # espelhamento so' inventaria um descanso torto.
    criar_osso_da_arma(arm)
    criar_osso_da_arma(arm_dir)
    # O comprimento so' pode ser lido AGORA: o `criar_mao_esquerda` esticou o
    # osso, e e' o valor esticado que poe o cotovelo no lugar.
    comp = preparar(arm)
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
