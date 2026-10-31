# -*- coding: utf-8 -*-
"""Clipes das cutscenes do fim do Capitulo 4 e do comeco do Capitulo 5.

MAYCOW NORMAL (o duble da igreja e o modelo do jogador — mesmo rig Meshy):

  deitado_gemendo    de costas no pentagrama da igreja, onde o Jonny ficou: a
                     mao direita apertando a barriga, a esquerda largada no
                     chao, o joelho direito em pe', o peito arfando sem ritmo
                     e a cabeca rolando devagar de um lado pro outro (laco)
  deitado_ritual     o mesmo chao, os bracos abertos, a cabeca jogada pra tras
                     e o corpo dando trancos — o flash da Dona Nice em cima
                     dele com a faca (laco)
  balancar_cabeca    ergue um pouco a cabeca e balanca, "nao, nao": volta pra
                     realidade. Comeca e termina na pose do deitado_gemendo
  levantar_devagar   do chao ate' em pe': apoia nos cotovelos, senta, ajoelha
                     com a mao na barriga e levanta curvado

MAYCOW PARASITA (o de primeira pessoa, `maycow_lopes.glb`), na arena 2:

  ajoelhar_cansado   em pe', exausto da luta, e cai de joelhos (os dois)
  ajoelhado_ofegante de joelhos, curvado, respirando pesado (laco)
  agonia_fogo        de joelhos no fogo: o tronco arqueia pra tras, a cabeca
                     grita pro alto, o braco esquerdo se contorce e a mao
                     direita segura o amuleto na frente do peito (laco)
  queimando_final    da agonia ao fim: tomba pra frente, ainda de joelhos, a
                     mao do amuleto estendida e baixa

Toda pose e' escrita por DIRECAO de osso (D(esquerda, frente, cima), no
espaco do personagem — ver anim_comum.py). O chao e' medido NA MALHA
(`assentar_na_malha`): deitado, quem encosta no chao sao as costas e a
cabeca, e a distancia osso->pele muda de lugar pra lugar; a conta pelos ossos
(`Rig.assentar`) deixava o corpo afundado ou flutuando.

Os extras de cada clipe (respiracao, tremor) sao somas de senos SEM fase:
valem zero em t=0. E' o que garante que o primeiro quadro de um clipe e' a
pose-base dele — o `balancar_cabeca` e o `levantar_devagar` partem
exatamente do `deitado_gemendo` em t=0, o `ajoelhado_ofegante` emenda no fim
do `ajoelhar_cansado` e o `queimando_final` no comeco da `agonia_fogo`. Nos
lacos as frequencias sao ciclos inteiros do periodo: o ultimo quadro e' igual
ao primeiro.
"""

import math
import random

import bpy
import numpy as np
from mathutils import Vector

import anim_comum as A
from anim_comum import D

TAU = math.tau


def DR(fora, frente, cima):
    return D(-fora, frente, cima)


# ==============================================================================
# O CHAO MEDIDO NA MALHA
# ==============================================================================

def malha_do_rig(rig):
    for o in rig.arm.children:
        if o.type == 'MESH' and o.name.startswith("char1"):
            return o
    for o in rig.arm.children:
        if o.type == 'MESH':
            return o
    return None


def mascara_sem(malha, grupos):
    """Vertices cujo osso de MAIOR peso nao esta' em `grupos`.

    O parasita veste um sobretudo comprido pesado nas coxas e no quadril: de
    joelhos, a barra dele balanca pra baixo do joelho e era ELA que encostava
    no chao — os joelhos ficavam 30 cm no ar. O chao dele se mede sem o
    casaco (a barra entra no piso, que a esconde)."""
    nomes = {g.index: g.name for g in malha.vertex_groups}
    fora = []
    for v in malha.data.vertices:
        if not v.groups:
            fora.append(False)
            continue
        g = max(v.groups, key=lambda x: x.weight)
        fora.append(nomes.get(g.group, "") in grupos)
    return ~np.array(fora, dtype=bool)


def z_minimo(malha, mascara=None):
    """Menor z (m, mundo) da malha deformada pela pose atual (so' dos
    vertices da `mascara`, se houver)."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = malha.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    m = np.array(malha.matrix_world)
    w = co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]
    if mascara is not None and len(mascara) == len(w):
        w = w[mascara]
    return float(w[:, 2].min())


def assentar_na_malha(rig, q, xy=(0.0, 0.0), folga=0.0):
    """Posicao do quadril (m) que poe o ponto mais baixo da PELE em z=folga."""
    if rig.arm.animation_data:
        rig.arm.animation_data.action = None
    pos = rig.assentar(q, xy=xy)
    malha = malha_do_rig(rig)
    if malha is None:
        return pos
    for _ in range(2):
        rig.aplicar(q, pos)
        pos.z -= z_minimo(malha, getattr(rig, "mascara_chao", None)) - folga
    rig.aplicar(q, pos)
    return pos


def sequencia_no_chao(rig, nome, chaves, laco=False, passo=1, extra=None, folga=0.0):
    """O `A.sequencia`, mas com o ponto mais baixo da PELE posto no chao em
    TODO quadro gravado.

    Entre duas poses-chave assentadas a interpolacao afunda ou flutua (no meio
    do caminho de sentado pra ajoelhado o joelho passava 30 cm por dentro do
    piso). Aqui cada quadro e' calculado inteiro primeiro (sem acao ativa: com
    ela o depsgraph reescreveria a pose pelas curvas) e so' depois gravado."""
    if rig.arm.animation_data:
        rig.arm.animation_data.action = None
    malha = malha_do_rig(rig)
    fim = chaves[-1][0]
    total = int(round(fim * A.FPS))
    quadros = list(range(0, total + 1, passo))
    if quadros[-1] != total:
        quadros.append(total)
    poses = []
    for f in quadros:
        t = f / A.FPS
        for i in range(len(chaves) - 1):
            if chaves[i][0] <= t <= chaves[i + 1][0]:
                a, b = chaves[i], chaves[i + 1]
                break
        else:
            a = b = chaves[-1]
        u = 0.0 if b[0] == a[0] else (t - a[0]) / (b[0] - a[0])
        q = A.mistura(a[1], b[1], u)
        pos = a[2].lerp(b[2], A.RT.suave(u))
        if extra:
            pos = extra(t, q, pos) or pos
        pos = pos.copy()
        if malha is not None:
            rig.aplicar(q, pos)
            pos.z -= z_minimo(malha, getattr(rig, "mascara_chao", None)) - folga
        poses.append((f, q, pos))
    A.nova_acao(rig, nome)
    for f, q, pos in poses:
        rig.chave(q, pos, f)
    acao = rig.arm.animation_data.action
    acao["laco"] = bool(laco)
    return acao


# ==============================================================================
# EXTRAS QUE VALEM ZERO EM t=0
# ==============================================================================

def onda(t, periodo, ciclos):
    """Seno de `ciclos` voltas por `periodo` (zero em t=0 e em t=periodo)."""
    return math.sin(TAU * ciclos * t / periodo)


def tremor_laco(rig, q, papeis, graus, semente, t, periodo, ciclos=(11, 29)):
    """Tremor nervoso que fecha o laco: cada osso num eixo sorteado, com dois
    senos de frequencia inteira no periodo (e zero em t=0)."""
    for i, papel in enumerate(papeis):
        rnd = random.Random(semente * 131 + i)
        eixo = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
        c1 = ciclos[0] + rnd.randint(0, 3)
        c2 = ciclos[1] + rnd.randint(0, 5)
        a = graus * (0.6 * onda(t, periodo, c1) + 0.4 * onda(t, periodo, c2))
        A.girar(rig, q, papel, A.em_torno(eixo, a))


def pulso(t, centro, largura, periodo=None):
    """Sino estreito em `centro` (com volta, se houver periodo)."""
    d = t - centro
    if periodo:
        d = (d + periodo * 0.5) % periodo - periodo * 0.5
    return math.exp(-(d / largura) ** 2)


def envelope(t, fim, subida=0.35, descida=0.35):
    """0 nas pontas, 1 no meio — extras de clipe que tem de comecar e
    terminar na pose-base."""
    if t <= 0.0 or t >= fim:
        return 0.0
    a = min(1.0, t / subida)
    b = min(1.0, (fim - t) / descida)
    return A.RT.suave(min(a, b))


# ==============================================================================
# MAYCOW NORMAL
# ==============================================================================

# De costas no chao. Deitado, o "frente" do corpo vira CIMA: a coluna aponta
# pra tras do personagem (D(0,-1,..)) e as pernas pra frente dele. O quadril
# tambem deita (sem isso a bacia ficava em pe' e a pele da cintura dobrava).
DEITADO = {
    "hips": (0, -1, 0.0),
    "spine": (0, -1, 0.04), "chest": (0, -1, 0.03), "upper_chest": (0, -1, 0.0),
    "neck": (0, -1, 0.12), "head": (0.22, -1, 0.02),
    # a esquerda largada no chao, aberta um pouco do corpo
    "upper_arm.L": (0.42, 0.9, -0.12), "forearm.L": (0.3, 0.95, -0.08),
    "hand.L": (0.25, 1, -0.12),
    # a direita apertando a barriga
    "upper_arm.R": DR(0.3, 0.72, 0.42), "forearm.R": DR(-0.8, 0.45, 0.18),
    "hand.R": DR(-0.9, 0.35, -0.2),
    "thigh.L": (0.12, 1, 0.0), "shin.L": (0.03, 1, -0.02),
    "foot.L": (0.12, 0.35, 1), "toe.L": (0.1, 0.3, 1),
    # o joelho direito dobrado, o pe' no chao
    "thigh.R": DR(0.1, 0.62, 0.78), "shin.R": DR(0.04, 0.72, -0.7),
    "foot.R": DR(0.02, 1, -0.12), "toe.R": DR(0, 1, 0),
}

# O flash do ritual: os bracos abertos no chao, a cabeca jogada pra tras.
RITUAL = dict(DEITADO)
RITUAL.update({
    "neck": (0, -1, -0.05), "head": (0.05, -0.85, -0.55),
    "upper_arm.L": (1, 0.12, -0.12), "forearm.L": (1, 0.2, -0.06),
    "hand.L": (1, 0.25, -0.12),
    "upper_arm.R": DR(1, 0.05, -0.12), "forearm.R": DR(1, -0.1, -0.06),
    "hand.R": DR(1, -0.15, -0.12),
    "thigh.R": DR(0.14, 1, 0.0), "shin.R": DR(0.04, 1, -0.02),
    "foot.R": DR(0.14, 0.35, 1), "toe.R": DR(0.1, 0.3, 1),
})

# Apoiado nos cotovelos: o tronco sobe ~35 graus, os antebracos no chao.
COTOVELOS = dict(DEITADO)
COTOVELOS.update({
    "spine": (0, -1, 0.55), "chest": (0, -1, 0.65), "upper_chest": (0, -1, 0.7),
    "neck": (0, -0.2, 1), "head": (0, 0.35, 1),
    "upper_arm.L": (0.25, -0.55, -0.8), "forearm.L": (0.18, 1, -0.15),
    "hand.L": (0.12, 1, -0.2),
    "upper_arm.R": DR(0.25, -0.55, -0.8), "forearm.R": DR(0.18, 1, -0.15),
    "hand.R": DR(0.12, 1, -0.2),
})

# Sentado: o tronco quase em pe', as maos no chao atras, o joelho direito em
# pe' e a perna esquerda esticada.
SENTADO = dict(DEITADO)
SENTADO.update({
    "hips": (0, -0.55, 1), "spine": (0, -0.3, 1), "chest": (0, -0.2, 1),
    "upper_chest": (0, -0.1, 1), "neck": (0, 0.2, 1), "head": (0, 0.45, 1),
    "upper_arm.L": (0.35, -0.55, -0.75), "forearm.L": (0.3, -0.5, -0.8),
    "hand.L": (0.3, -0.4, -0.85),
    "upper_arm.R": DR(0.35, -0.55, -0.75), "forearm.R": DR(0.3, -0.5, -0.8),
    "hand.R": DR(0.3, -0.4, -0.85),
    "thigh.L": (0.12, 1, 0.05), "shin.L": (0.03, 1, -0.05),
    "foot.L": (0.12, 0.35, 1), "toe.L": (0.1, 0.3, 1),
    "thigh.R": DR(0.1, 0.6, 0.8), "shin.R": DR(0.04, 0.6, -0.8),
    "foot.R": DR(0.02, 1, -0.15), "toe.R": DR(0, 1, 0),
})

# Ainda sentado, mas com os dois joelhos em pe' e o tronco caido sobre eles:
# a direita abraca a barriga, a esquerda empurra o chao do lado do quadril.
SENTADO_JOELHOS = {
    "hips": (0, -0.2, 1), "spine": (0, 0.35, 1), "chest": (0, 0.5, 1),
    "upper_chest": (0, 0.5, 1), "neck": (0, 0.6, 0.8), "head": (0, 0.6, 0.5),
    "upper_arm.L": (0.35, -0.1, -1), "forearm.L": (0.3, -0.05, -1),
    "hand.L": (0.3, 0.0, -1),
    "upper_arm.R": DR(0.15, 0.1, -1), "forearm.R": DR(-0.85, 0.5, -0.1),
    "hand.R": DR(-0.95, 0.2, 0.0),
    "thigh.L": (0.15, 0.75, 0.65), "shin.L": (0.05, 0.55, -0.85),
    "foot.L": (0.05, 1, -0.2), "toe.L": (0.05, 1, 0),
}

# Agachado pra levantar: o peso ja' em cima dos pes, o tronco caido pra
# frente, a mao esquerda apoiada no chao na frente.
AGACHANDO = {
    "hips": (0, 0.45, 1), "spine": (0, 0.85, 1), "chest": (0, 0.9, 0.9),
    "upper_chest": (0, 0.9, 0.8), "neck": (0, 0.9, 0.5), "head": (0, 0.7, 0.2),
    "upper_arm.L": (0.2, 0.6, -1), "forearm.L": (0.1, 0.4, -1),
    "hand.L": (0.1, 0.5, -1),
    "upper_arm.R": DR(0.15, 0.1, -1), "forearm.R": DR(-0.85, 0.5, -0.1),
    "hand.R": DR(-0.95, 0.2, 0.0),
    "thigh.L": (0.22, 1, 0.25), "shin.L": (0.05, -0.35, -1),
    "foot.L": (0.05, 1, -0.35), "toe.L": (0.05, 1, 0),
    "thigh.R": DR(0.2, 1, 0.15), "shin.R": DR(0.05, -0.3, -1),
    "foot.R": DR(0.05, 1, -0.35), "toe.R": DR(0.05, 1, 0),
}

# Ajoelhado (o joelho direito no chao), o tronco ja' em pe': a direita na
# barriga, a esquerda no joelho da frente.
AJOELHADO = {
    "hips": (0, 0.05, 1), "spine": (0, 0.2, 1), "chest": (0, 0.22, 1),
    "upper_chest": (0, 0.15, 1), "neck": (0, 0.35, 1), "head": (0, 0.45, 1),
    "upper_arm.L": (0.08, 0.8, -1), "forearm.L": (0.0, 0.86, -0.5),
    "hand.L": (0.0, 0.7, -0.7),
    "upper_arm.R": DR(0.15, 0.1, -1), "forearm.R": DR(-0.85, 0.5, -0.1),
    "hand.R": DR(-0.95, 0.2, 0.0),
    "thigh.L": (0.14, 1, 0.12), "shin.L": (0.02, 0.15, -1),
    "foot.L": (0.05, 1, -0.45), "toe.L": (0.05, 1, 0),
    "thigh.R": DR(0.08, 0.05, -1), "shin.R": DR(0.02, -1, -0.05),
    "foot.R": DR(0.0, -1, -0.25), "toe.R": DR(0, -1, 0),
}

# O antebraco esquerdo gira 90 graus no proprio eixo: sem isso a palma ficava
# pra cima, como quem pede alguma coisa, e nao largada em cima do joelho.
GIRO_MAO_NO_JOELHO = {"forearm.L": math.radians(90)}

# Quase em pe', ainda dobrado sobre a barriga.
SUBINDO = {
    "hips": (0, 0.15, 1), "spine": (0, 0.55, 1), "chest": (0, 0.5, 1),
    "upper_chest": (0, 0.4, 1), "neck": (0, 0.5, 1), "head": (0, 0.5, 0.8),
    "upper_arm.L": (0.1, 0.3, -1), "forearm.L": (0.03, 0.5, -1),
    "hand.L": (0.02, 0.5, -1),
    "upper_arm.R": DR(0.15, 0.1, -1), "forearm.R": DR(-0.85, 0.5, -0.1),
    "hand.R": DR(-0.95, 0.2, 0.0),
    "thigh.L": (0.08, 0.6, -0.8), "shin.L": (0.0, -0.25, -1),
    "foot.L": (0.05, 1, -0.5), "toe.L": (0.05, 1, 0),
    "thigh.R": DR(0.08, 0.5, -0.85), "shin.R": DR(0.0, -0.3, -1),
    "foot.R": DR(0.05, 1, -0.5), "toe.R": DR(0.05, 1, 0),
}

# Em pe', curvado, a mao direita na barriga (o fim do clipe: o fade da
# cutscene corta antes, no meio da subida).
EM_PE_FERIDO = {
    "hips": (0, 0.0, 1), "spine": (0, 0.22, 1), "chest": (0, 0.2, 1),
    "upper_chest": (0, 0.12, 1), "neck": (0, 0.3, 1), "head": (0, 0.3, 1),
    "upper_arm.L": (0.16, 0.06, -1), "forearm.L": (0.07, 0.2, -1),
    "hand.L": (0.04, 0.15, -1),
    "upper_arm.R": DR(0.15, 0.05, -1), "forearm.R": DR(-0.85, 0.5, -0.15),
    "hand.R": DR(-0.95, 0.2, 0.0),
    "thigh.L": (0.07, 0.05, -1), "shin.L": (0, -0.04, -1),
    "foot.L": (0.06, 1, -0.55), "toe.L": (0.05, 1, -0.05),
}


def clipes_normal(rig):
    q_ch = rig.pose(DEITADO)
    p_ch = assentar_na_malha(rig, q_ch)

    # --- deitado_gemendo: 6 s, respiracao curta (4 folegos), um engasgo, a
    # cabeca rola uma vez e a mao esquerda tenta subir duas vezes
    P1 = 6.0

    def gemendo(t, q, pos):
        r = onda(t, P1, 4) * 0.75 + onda(t, P1, 8) * 0.25
        eng = pulso(t, 4.1, 0.2, P1)
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 2.6 * r + 5.5 * eng))
        A.girar(rig, q, "upper_chest", A.em_torno((1, 0, 0), -1.2 * r))
        A.girar(rig, q, "neck", A.em_torno((0, 1, 0), 16 * onda(t, P1, 1)))
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 5 * eng))
        sobe = max(0.0, onda(t, P1, 2)) ** 3
        A.girar(rig, q, "upper_arm.L", A.em_torno((0, 1, 0), -14 * sobe))
        A.girar(rig, q, "forearm.L", A.em_torno((0, 1, 0), -22 * sobe))
        A.girar(rig, q, "thigh.R", A.em_torno((0, 1, 0), 5 * onda(t, P1, 1)))
        tremor_laco(rig, q, ["hand.L", "hand.R", "forearm.R"], 2.2, 71, t, P1)
        return pos + Vector((0, 0, 0.004 * r))

    A.sequencia(rig, "deitado_gemendo", [(0.0, q_ch, p_ch), (P1, q_ch, p_ch)],
                laco=True, passo=2, extra=gemendo)

    # --- deitado_ritual: 3 s de trancos (o corpo pulando no chao sob a faca)
    q_ri = rig.pose(RITUAL)
    p_ri = assentar_na_malha(rig, q_ri)
    P2 = 3.0
    TRANCOS = ((0.25, 1.0), (0.95, 0.7), (1.3, 1.0), (2.05, 0.6), (2.5, 0.9))

    def ritual(t, q, pos):
        s = sum(f * pulso(t, c, 0.07, P2) for c, f in TRANCOS)
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 8 * s + 2.0 * onda(t, P2, 4)))
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 7 * s))
        A.girar(rig, q, "neck", A.em_torno((0, 1, 0), 9 * onda(t, P2, 2)))
        A.girar(rig, q, "upper_arm.L", A.em_torno((0, 1, 0), -12 * s))
        A.girar(rig, q, "upper_arm.R", A.em_torno((0, 1, 0), 12 * s))
        A.girar(rig, q, "thigh.L", A.em_torno((1, 0, 0), -6 * s))
        A.girar(rig, q, "thigh.R", A.em_torno((1, 0, 0), -5 * s))
        tremor_laco(rig, q, ["hand.L", "hand.R", "forearm.L", "forearm.R", "head"],
                    3.5, 17, t, P2, ciclos=(9, 23))
        return pos + Vector((0, 0, 0.035 * s))

    A.sequencia(rig, "deitado_ritual", [(0.0, q_ri, p_ri), (P2, q_ri, p_ri)],
                laco=True, passo=1, extra=ritual)

    # --- balancar_cabeca: ergue a cabeca, balanca "nao, nao" e deita de novo
    P3 = 2.2

    def balanca(t, q, pos):
        e = envelope(t, P3, 0.4, 0.45)
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 24 * e))
        A.girar(rig, q, "head", A.em_torno((1, 0, 0), 10 * e))
        A.girar(rig, q, "neck", A.em_torno((0, 1, 0), 24 * e * math.sin(TAU * 1.6 * t)))
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 4 * e))
        return pos

    sequencia_no_chao(rig, "balancar_cabeca", [(0.0, q_ch, p_ch), (P3, q_ch, p_ch)],
                      passo=1, extra=balanca)

    # --- levantar_devagar: 9,8 s (cotovelos 2,0; sentado 4,0; joelhos em pe' 5,5;
    # agachado 6,4; ajoelhado 7,3-7,9; quase em pe' 9,0; em pe' 9,8)
    q_co = rig.pose(COTOVELOS)
    p_co = assentar_na_malha(rig, q_co)
    q_se = rig.pose(SENTADO)
    p_se = assentar_na_malha(rig, q_se, xy=(0.0, -0.05))
    q_sj = rig.pose(SENTADO_JOELHOS)
    p_sj = assentar_na_malha(rig, q_sj, xy=(0.0, -0.1))
    q_ag = rig.pose(AGACHANDO)
    p_ag = assentar_na_malha(rig, q_ag, xy=(0.0, -0.25))
    q_aj = rig.pose(AJOELHADO, GIRO_MAO_NO_JOELHO)
    p_aj = assentar_na_malha(rig, q_aj, xy=(0.0, -0.3))
    q_su = rig.pose(SUBINDO, GIRO_MAO_NO_JOELHO)
    p_su = assentar_na_malha(rig, q_su, xy=(0.0, -0.35))
    q_fi = rig.pose(EM_PE_FERIDO)
    p_fi = assentar_na_malha(rig, q_fi, xy=(0.0, -0.35))

    LEVANTAR = [
        (0.0, q_ch, p_ch), (0.6, q_ch, p_ch),
        (2.0, q_co, p_co), (2.6, q_co, p_co),
        (4.0, q_se, p_se), (4.6, q_se, p_se),
        (5.5, q_sj, p_sj),
        (6.4, q_ag, p_ag),
        (7.3, q_aj, p_aj), (7.9, q_aj, p_aj),
        (9.0, q_su, p_su),
        (9.8, q_fi, p_fi),
    ]
    FIM = LEVANTAR[-1][0]

    def esforco(t, q, pos):
        # a respiracao pesada de quem levanta ferido (zero nas pontas)
        e = envelope(t, FIM, 0.6, 0.5)
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 2.4 * e * math.sin(TAU * t / 1.4)))
        tremor_laco(rig, q, ["hand.L", "forearm.L", "upper_arm.L"], 1.6 * e, 33, t, FIM)
        return pos

    sequencia_no_chao(rig, "levantar_devagar", LEVANTAR, passo=2, extra=esforco)
    return {"deitado": (q_ch, p_ch), "fim_levantar": FIM,
            "tempos_levantar": {k: v for k, v in (
                ("cotovelos", 2.0), ("sentado", 4.0), ("ajoelhado", 7.3),
                ("em_pe", FIM))}}


# ==============================================================================
# MAYCOW PARASITA
# ==============================================================================

# Em pe', acabado: ombros caidos, a cabeca baixa, os bracos pendurados.
PE_CANSADO = {
    "hips": (0, 0.05, 1), "spine": (0, 0.18, 1), "chest": (0, 0.2, 1),
    "upper_chest": (0, 0.15, 1), "neck": (0, 0.55, 1), "head": (0, 0.5, 0.8),
    "upper_arm.L": (0.14, 0.08, -1), "forearm.L": (0.06, 0.15, -1),
    "hand.L": (0.03, 0.1, -1),
    "thigh.L": (0.09, 0.03, -1), "shin.L": (0, -0.03, -1),
    "foot.L": (0.06, 1, -0.55), "toe.L": (0.05, 1, -0.05),
}

# De joelhos (os dois), sentado nos calcanhares e curvado: as maos nas coxas,
# a cabeca pendendo.
AJOELHADO_DOIS = {
    "hips": (0, 0.35, 1), "spine": (0, 0.6, 1), "chest": (0, 0.65, 1),
    "upper_chest": (0, 0.55, 1), "neck": (0, 0.9, 0.5), "head": (0, 0.6, -0.4),
    "upper_arm.L": (0.16, 0.2, -1), "forearm.L": (0.05, 0.35, -1),
    "hand.L": (0.03, 0.45, -1),
    "thigh.L": (0.12, 0.85, -0.55), "shin.L": (0.04, -1, -0.06),
    "foot.L": (0.02, -1, -0.3), "toe.L": (0.02, -1, -0.05),
}

# A agonia: ainda de joelhos, mas erguido (as coxas quase em pe'), o tronco
# arqueado pra tras, a cabeca jogada pro alto. O braco esquerdo sobe torto;
# a mao direita segura o amuleto na frente do peito, o antebraco em pe'.
AGONIA = {
    "hips": (0, -0.05, 1), "spine": (0, -0.2, 1), "chest": (0, -0.38, 1),
    "upper_chest": (0, -0.5, 1), "neck": (0, -0.55, 1), "head": (0, -1, 0.55),
    "upper_arm.L": (0.65, 0.1, 0.75), "forearm.L": (0.35, 0.35, 1),
    "hand.L": (0.25, 0.25, 1),
    "upper_arm.R": DR(0.12, 0.75, -0.55), "forearm.R": DR(-0.3, 0.45, 0.85),
    "hand.R": DR(-0.2, 0.3, 1),
    "thigh.L": (0.14, 0.3, -1), "shin.L": (0.04, -1, -0.06),
    "foot.L": (0.02, -1, -0.3), "toe.L": (0.02, -1, -0.05),
}

# O fim: tombado pra frente, ainda de joelhos, a cabeca caida, o braco
# esquerdo largado no chao e a mao do amuleto estendida e baixa.
TOMBADO = {
    "hips": (0, 0.6, 0.8), "spine": (0, 1, 0.55), "chest": (0, 1, 0.4),
    "upper_chest": (0, 1, 0.3), "neck": (0, 1, 0.0), "head": (0.15, 0.6, -0.8),
    "upper_arm.L": (0.3, 0.2, -1), "forearm.L": (0.2, 0.5, -1),
    "hand.L": (0.15, 0.6, -1),
    "upper_arm.R": DR(0.05, 0.75, -0.65), "forearm.R": DR(-0.05, 1, -0.45),
    "hand.R": DR(-0.05, 1, -0.3),
    "thigh.L": (0.12, 0.75, -0.65), "shin.L": (0.04, -1, -0.06),
    "foot.L": (0.02, -1, -0.3), "toe.L": (0.02, -1, -0.05),
}


# A palma da mao direita (a do amuleto): na agonia o antebraco gira 90 graus
# e a palma fica virada pro rosto dele (sem o giro ela olhava pro lado, de
# faca); tombado, gira 180 e a palma abre pra cima, o amuleto exposto. O
# lado da palma foi medido na malha: os dedos do Meshy curvam pra ela.
GIRO_AGONIA = {"forearm.R": math.radians(90)}
GIRO_TOMBADO = {"forearm.R": math.radians(180)}


def clipes_parasita(rig):
    malha = malha_do_rig(rig)
    if malha is not None:
        rig.mascara_chao = mascara_sem(malha, ("Hips", "LeftUpLeg", "RightUpLeg"))
    q_pe = rig.pose(PE_CANSADO)
    p_pe = assentar_na_malha(rig, q_pe)
    q_aj = rig.pose(AJOELHADO_DOIS)
    p_aj = assentar_na_malha(rig, q_aj, xy=(0.0, 0.12))
    # o meio da queda: os joelhos ja' dobrando, o corpo ainda alto
    q_meio = A.mistura(q_pe, q_aj, 0.45)
    p_meio = p_pe.lerp(p_aj, 0.3)

    # --- ajoelhar_cansado: 3 s. Respira em pe', cai de joelhos com um tranco
    # e assenta. Os extras somem no fim: termina na pose do ofegante.
    P1 = 3.0

    def cansado(t, q, pos):
        e = envelope(t, P1, 0.3, 0.6)
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 5 * e * math.sin(TAU * t / 0.9)))
        impacto = pulso(t, 1.75, 0.09)
        A.girar(rig, q, "spine", A.em_torno((1, 0, 0), -9 * impacto))
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), -12 * impacto))
        return pos

    sequencia_no_chao(rig, "ajoelhar_cansado", [
        (0.0, q_pe, p_pe), (0.9, q_pe, p_pe), (1.35, q_meio, p_meio),
        (1.7, q_aj, p_aj), (P1, q_aj, p_aj)], passo=1, extra=cansado)

    # --- ajoelhado_ofegante: 3 s, quatro folegos fundos (os ombros sobem)
    P2 = 3.0

    def ofegante(t, q, pos):
        r = onda(t, P2, 4)
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), -7 * r))
        A.girar(rig, q, "upper_chest", A.em_torno((1, 0, 0), -3 * r))
        A.girar(rig, q, "shoulder.L", A.em_torno((0, 1, 0), -6 * r))
        A.girar(rig, q, "shoulder.R", A.em_torno((0, 1, 0), 6 * r))
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 4 * onda(t, P2, 4)))
        A.girar(rig, q, "head", A.em_torno((0, 0, 1), 5 * onda(t, P2, 1)))
        return pos

    A.sequencia(rig, "ajoelhado_ofegante", [(0.0, q_aj, p_aj), (P2, q_aj, p_aj)],
                laco=True, passo=1, extra=ofegante)

    # --- agonia_fogo: 2,4 s de tremor violento, o braco esquerdo se torcendo
    q_ag = rig.pose(AGONIA, GIRO_AGONIA)
    p_ag = assentar_na_malha(rig, q_ag, xy=(0.0, 0.05))
    P3 = 2.4

    def agonia(t, q, pos):
        A.girar(rig, q, "spine", A.em_torno((1, 0, 0), 4 * onda(t, P3, 3)))
        A.girar(rig, q, "chest", A.em_torno((0, 1, 0), 6 * onda(t, P3, 2)))
        A.girar(rig, q, "upper_arm.L", A.em_torno((0, 1, 0), 20 * onda(t, P3, 2)))
        A.girar(rig, q, "upper_arm.L", A.em_torno((1, 0, 0), 14 * onda(t, P3, 3)))
        A.girar(rig, q, "forearm.L", A.em_torno((0, 0, 1), 25 * onda(t, P3, 3)))
        A.girar(rig, q, "neck", A.em_torno((0, 0, 1), 12 * onda(t, P3, 2)))
        tremor_laco(rig, q, ["spine", "chest", "neck", "head", "upper_arm.L",
                             "forearm.L", "hand.L", "upper_arm.R", "forearm.R",
                             "thigh.L", "thigh.R"],
                    4.5, 59, t, P3, ciclos=(13, 31))
        return pos

    sequencia_no_chao(rig, "agonia_fogo", [(0.0, q_ag, p_ag), (P3, q_ag, p_ag)],
                      laco=True, passo=1, extra=agonia)

    # --- queimando_final: 4 s, da agonia ao corpo tombado (o tremor morre)
    q_to = rig.pose(TOMBADO, GIRO_TOMBADO)
    p_to = assentar_na_malha(rig, q_to, xy=(0.0, 0.08))
    q_qm = A.mistura(q_ag, q_to, 0.4)
    p_qm = p_ag.lerp(p_to, 0.4)
    P4 = 4.0

    def morrendo(t, q, pos):
        e = max(0.0, 1.0 - t / 2.6) * min(1.0, t / 0.2)
        tremor_laco(rig, q, ["spine", "chest", "neck", "head", "upper_arm.L",
                             "forearm.L", "forearm.R"], 4.0 * e, 61, t, 2.4, ciclos=(13, 31))
        return pos

    sequencia_no_chao(rig, "queimando_final", [
        (0.0, q_ag, p_ag), (0.6, q_ag, p_ag), (2.0, q_qm, p_qm),
        (3.4, q_to, p_to), (P4, q_to, p_to)], passo=1, extra=morrendo)
    return {"agonia": (q_ag, p_ag)}
