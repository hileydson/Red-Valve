# -*- coding: utf-8 -*-
"""Clipes do Capitulo 5 (o resgate do Jimmy e o fim do jogo).

JIMMY (rig do `montar_jimmy.py`, mesmos nomes de osso da igreja):

  parado          (laco de 4 s) de pe', respirando
  andar           (laco) seguindo o Maycow — captura Walking
  andar_devagar   (laco) o passo lento ate' a maca do Jonny — captura Casual_Walk
  correr          (laco) alcancando o Maycow — captura Running
  jaula_sacudir   (laco de 2,4 s) as duas maos na grade, sacudindo o corpo
                  pra frente e pra tras
  jaula_bater     (laco de 2,4 s) a mao esquerda na grade e a direita
                  socando a barra duas vezes
  jaula_gritar    (laco de 3 s) a esquerda na grade e o braco direito pra fora
                  das barras, acenando; a cabeca jogada pra tras, gritando
  abraco          (laco de 3 s) abracado ao Maycow (da mesma altura): o
                  braco esquerdo por cima do ombro dele, o direito pela
                  cintura, a cabeca de lado, os ombros soluçando
  ouvindo         (laco) ouvindo o Maycow contar — captura Listening_Gesture
  falando         (laco) perguntando, gesticulando — captura Talk_Passionately
  mao_na_cabeca   a mao na testa, o baque do que ouviu — captura Headache_Relief
  abraco_jonny    (laco de 3 s) curvado sobre o Jonny sentado na maca, os
                  dois bracos em volta dos ombros dele, a cabeca encostada
                  na dele, chorando

JONNY (o rig da igreja, `jonny.blend`):

  sentado_maca    (laco de 4 s) sentado na beira da maca, as pernas penduradas,
                  as maos no tampo, a cabeca baixa
  abraco_sentado  (laco de 3 s) ainda sentado, curvado pra frente, os bracos
                  em volta do Jimmy, o rosto no peito dele, soluçando

MAYCOW PARASITA (`maycow_lopes.glb`, o da arena):

  abraco          (laco de 3 s) o mesmo abraco do Jimmy, do outro lado
  arrancar_porta  agarra as barras da porta da jaula, puxa com o corpo todo
                  e arranca (o tranco e' aos 1,8 s)

Toda pose e' escrita por DIRECAO de osso (D(esquerda, frente, cima), no
espaco do personagem — ver `anim_comum.py`). Os extras dos lacos sao somas de
senos de ciclos inteiros do periodo (zero em t=0): o ultimo quadro e' igual
ao primeiro. As ferramentas de chao e de extra sao as do Capitulo 4
(`anim_capitulo_4.py`).

O abraco: os dois ficam com as COLUNAS a ~0,30 m uma da outra, de frente. O
de cada um tem o braco esquerdo por cima e o direito por baixo — de frente,
o esquerdo de um passa sobre o direito do outro, entao a mesma pose serve
pros dois.
"""

import math

import anim_comum as A
import anim_capitulo_4 as C4
from anim_comum import D
from mathutils import Vector

TAU = math.tau


def DR(fora, frente, cima):
    return D(-fora, frente, cima)


def _acao(acoes, nome):
    if nome in acoes:
        return acoes[nome]
    for k, a in acoes.items():
        if k.split(".")[0] == nome:
            return a
    raise KeyError(nome)


# ==============================================================================
# AS POSES
# ==============================================================================

EM_PE = {
    "spine": (0, 0.03, 1), "chest": (0, 0.04, 1), "upper_chest": (0, 0.03, 1),
    "neck": (0, 0.18, 1), "head": (0, 0.06, 1),
    "upper_arm.L": (0.18, 0.03, -1), "forearm.L": (0.06, 0.18, -1),
    "hand.L": (0.02, 0.16, -1), "fingers.L": (0.0, 0.25, -1),
    "thigh.L": (0.04, 0.02, -1), "shin.L": (0, -0.03, -1),
    "foot.L": (0, 1, -0.45), "toe.L": (0, 1, -0.05),
}

# As duas maos na grade, um palmo acima do ombro e 36 cm na frente dele: o
# cotovelo cai pra fora e pra baixo (contas do braco de 29 + 20 cm do Jimmy).
BRACO_NA_GRADE = {
    "upper_arm.L": (0.115, 0.259, -0.058), "forearm.L": (-0.085, 0.101, 0.151),
    "hand.L": (0.0, 0.15, 1), "fingers.L": (-0.1, 1, -0.2),
}
NA_GRADE = dict(EM_PE)
NA_GRADE.update(BRACO_NA_GRADE)
NA_GRADE.update({
    "spine": (0, 0.12, 1), "chest": (0, 0.15, 1), "upper_chest": (0, 0.12, 1),
    "neck": (0, 0.28, 1), "head": (0, 0.14, 1),
    # o pe' direito um passo atras: e' dele que vem a forca de sacudir
    "thigh.R": DR(0.04, -0.10, -1), "shin.R": DR(0.0, -0.20, -1),
    "thigh.L": (0.05, 0.08, -1), "shin.L": (0.0, -0.02, -1),
})

# o punho direito erguido pra bater (a esquerda continua na grade)
PUNHO_ERGUIDO = dict(NA_GRADE)
PUNHO_ERGUIDO.update({
    "upper_arm.R": DR(0.22, 0.55, 0.55), "forearm.R": DR(-0.05, 0.10, 1),
    "hand.R": DR(0.0, 0.0, 1), "fingers.R": DR(0.0, 0.7, 0.6),
    "chest": (0, 0.05, 1), "neck": (0, 0.2, 1),
})
# o punho na barra
PUNHO_NA_BARRA = dict(NA_GRADE)
PUNHO_NA_BARRA.update({
    "upper_arm.R": DR(0.12, 0.30, -0.02), "forearm.R": DR(-0.08, 0.75, 0.30),
    "hand.R": DR(-0.05, 0.9, 0.1), "fingers.R": DR(0.0, 0.5, -0.8),
    "chest": (0, 0.22, 1), "neck": (0, 0.36, 1),
})

# a esquerda na grade e o braco direito pra fora das barras, a mao aberta
GRITANDO = dict(NA_GRADE)
GRITANDO.update({
    "upper_arm.R": DR(0.18, 1, 0.30), "forearm.R": DR(0.10, 1, 0.55),
    "hand.R": DR(0.0, 0.5, 1), "fingers.R": DR(0.0, 0.4, 1),
    "neck": (0, -0.05, 1), "head": (0, -0.35, 1),
    "upper_chest": (0, 0.0, 1),
})

# Abraco de igual pra igual: o cotovelo sai pro lado do outro e o antebraco
# passa por tras das costas dele. O esquerdo por cima, o direito por baixo.
ABRACO = dict(EM_PE)
ABRACO.update({
    "spine": (0, 0.06, 1), "chest": (0, 0.10, 1), "upper_chest": (0, 0.10, 1),
    "neck": (0.30, 0.22, 1), "head": (0.22, 0.10, 1),
    "upper_arm.L": (0.42, 1.0, 0.28), "forearm.L": (-0.62, 0.78, 0.10),
    "hand.L": (-0.85, 0.05, -0.05), "fingers.L": (-0.6, -0.45, -0.2),
    "upper_arm.R": DR(0.45, 1.0, -0.15), "forearm.R": DR(-0.62, 0.78, -0.02),
    "hand.R": DR(-0.85, 0.05, 0.0), "fingers.R": DR(-0.6, -0.45, -0.15),
})
# a cabeca deita pro lado esquerdo dele (por cima do ombro direito do outro)
# e o rosto vira pra fora
GIRO_ABRACO = {"head": 0.55}

# Curvado sobre o Jonny sentado: os dois bracos em volta dos ombros dele, a
# cabeca encostada na dele.
ABRACO_JONNY = dict(EM_PE)
ABRACO_JONNY.update({
    "spine": (0, 0.18, 1), "chest": (0, 0.26, 1), "upper_chest": (0, 0.22, 1),
    "neck": (0, 0.55, 1), "head": (0, 0.45, 1),
    "upper_arm.L": (0.42, 0.88, 0.02), "forearm.L": (-0.75, 0.62, 0.0),
    "hand.L": (-0.6, -0.35, -0.15), "fingers.L": (-0.35, -0.55, -0.3),
    # os joelhos um pouco dobrados: ele desce pra altura do menino
    "thigh.L": (0.06, 0.12, -1), "shin.L": (0.0, -0.10, -1),
})
GIRO_ABRACO_JONNY = {"head": 0.35}

# --- Jonny ---
SENTADO = {
    "spine": (0, 0.10, 1), "chest": (0, 0.14, 1), "upper_chest": (0, 0.12, 1),
    "neck": (0, 0.38, 1), "head": (0, 0.30, 1),
    "upper_arm.L": (0.30, 0.06, -1), "forearm.L": (0.12, 0.45, -0.9),
    "hand.L": (0.05, 0.55, -0.85), "fingers.L": (0.0, 0.65, -0.75),
    "thigh.L": (0.14, 1, -0.04), "shin.L": (0.02, 0.18, -1),
    "foot.L": (0, 1, -0.55), "toe.L": (0, 1, -0.1),
}
APOIO_SENTADO = ("thigh.L", "thigh.R")
ABRACO_SENTADO = dict(SENTADO)
ABRACO_SENTADO.update({
    "spine": (0, 0.30, 1), "chest": (0, 0.30, 1), "upper_chest": (0, 0.20, 1),
    "neck": (0, 0.25, 1), "head": (0, 0.12, 1),
    "upper_arm.L": (0.50, 0.85, 0.10), "forearm.L": (-0.55, 0.82, 0.05),
    "hand.L": (-0.65, -0.15, -0.05), "fingers.L": (-0.4, -0.5, -0.2),
    "thigh.L": (0.30, 1, -0.02),
})
GIRO_ABRACO_SENTADO = {"head": 0.5}

# --- parasita ---
# agarrado nas barras da porta, por fora (a mesma conta do braco na grade,
# na altura do peito)
NAS_BARRAS = dict(EM_PE)
NAS_BARRAS.update({
    "upper_arm.L": (0.10, 0.62, -0.25), "forearm.L": (-0.08, 0.85, 0.10),
    "hand.L": (0.0, 0.3, 1),
    "spine": (0, 0.10, 1), "chest": (0, 0.12, 1),
})
PUXANDO = dict(NAS_BARRAS)
PUXANDO.update({
    "spine": (0, -0.38, 1), "chest": (0, -0.22, 1), "upper_chest": (0, -0.08, 1),
    "neck": (0, 0.25, 1), "head": (0, 0.25, 1),
    "upper_arm.L": (0.10, 0.92, -0.10), "forearm.L": (-0.06, 1, 0.05),
    "thigh.L": (0.08, 0.30, -1), "shin.L": (0.0, -0.05, -1),
    "thigh.R": DR(0.06, -0.30, -1), "shin.R": DR(0.0, -0.45, -1),
})
ARRANCOU = dict(PUXANDO)
ARRANCOU.update({
    "spine": (0, -0.12, 1), "chest": (0, -0.05, 1),
    "upper_arm.L": (0.55, 0.30, -0.70), "forearm.L": (0.40, 0.60, -0.30),
    "upper_arm.R": DR(0.70, -0.20, -0.55), "forearm.R": DR(0.55, 0.10, -0.80),
    "neck": (0, 0.10, 1), "head": (0, 0.05, 1),
})


def _giros(rig, d):
    """Torcao (rad) em torno do proprio eixo, pros nomes deste rig."""
    return {rig.n(k): v for k, v in d.items()}


# ==============================================================================
# JIMMY
# ==============================================================================

def clipes_jimmy(rig, fontes):
    ml, a_ml = fontes["maycow_lopes"]
    A.retarget(rig, ml, _acao(a_ml, "Walking"), "andar", laco=True)
    A.retarget(rig, ml, _acao(a_ml, "Casual_Walk"), "andar_devagar", laco=True, velocidade=0.8)
    A.retarget(rig, ml, _acao(a_ml, "Running"), "correr", laco=True)
    A.retarget(rig, ml, _acao(a_ml, "Listening_Gesture"), "ouvindo", laco=True)
    A.retarget(rig, ml, _acao(a_ml, "Talk_Passionately"), "falando", laco=True)
    A.retarget(rig, ml, _acao(a_ml, "Headache_Relief"), "mao_na_cabeca")

    # --- parado: 4 s, de pe' respirando (o Idle_11 da captura poe as maos na
    # cabeca)
    q_pe = rig.pose(EM_PE)
    p_pe = rig.assentar(q_pe)

    def respira(t, q, pos):
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 1.8 * C4.onda(t, 4.0, 1)))
        A.girar(rig, q, "head", A.em_torno((0, 0, 1), 3.0 * C4.onda(t, 4.0, 1)))
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 1.5 * C4.onda(t, 4.0, 2)))
        return pos + Vector((0.006 * C4.onda(t, 4.0, 1), 0.0, 0.0))

    A.sequencia(rig, "parado", [(0.0, q_pe, p_pe), (4.0, q_pe, p_pe)],
                laco=True, passo=2, extra=respira)

    q_gr = rig.pose(NA_GRADE)
    p_gr = rig.assentar(q_gr)

    # --- jaula_sacudir: 2,4 s, quatro trancos (o corpo vai e volta, os
    # bracos puxam e empurram a grade)
    P = 2.4

    def sacode(t, q, pos):
        r = C4.onda(t, P, 4)
        A.girar(rig, q, "spine", A.em_torno((1, 0, 0), 6 * r))
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 4 * r))
        A.girar(rig, q, "upper_arm.L", A.em_torno((1, 0, 0), -7 * r))
        A.girar(rig, q, "upper_arm.R", A.em_torno((1, 0, 0), -7 * r))
        A.girar(rig, q, "forearm.L", A.em_torno((1, 0, 0), 6 * r))
        A.girar(rig, q, "forearm.R", A.em_torno((1, 0, 0), 6 * r))
        A.girar(rig, q, "head", A.em_torno((0, 0, 1), 10 * C4.onda(t, P, 1)))
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), -5 * C4.onda(t, P, 2)))
        C4.tremor_laco(rig, q, ["chest", "head", "hand.L", "hand.R"], 2.0, 71, t, P)
        # o quadril vai e volta junto (o -Y e' a frente dele)
        return pos + Vector((0.0, -0.035 * r, -0.01 * abs(r)))

    A.sequencia(rig, "jaula_sacudir", [(0.0, q_gr, p_gr), (P, q_gr, p_gr)],
                laco=True, passo=1, extra=sacode)

    # --- jaula_bater: 2,4 s, o punho sobe e bate duas vezes na barra
    q_pe = rig.pose(PUNHO_ERGUIDO)
    p_pe = rig.assentar(q_pe)
    q_pb = rig.pose(PUNHO_NA_BARRA)
    p_pb = rig.assentar(q_pb)

    def bate(t, q, pos):
        for centro in (0.62, 1.12):
            A.girar(rig, q, "head", A.em_torno((1, 0, 0), -8 * C4.pulso(t, centro, 0.06)))
        C4.tremor_laco(rig, q, ["chest", "neck", "head", "hand.L"], 2.5, 73, t, P)
        return pos

    A.sequencia(rig, "jaula_bater", [
        (0.0, q_gr, p_gr), (0.35, q_pe, p_pe), (0.6, q_pb, p_pb), (0.85, q_pe, p_pe),
        (1.1, q_pb, p_pb), (1.6, q_pb, p_pb), (P, q_gr, p_gr)], passo=1, extra=bate)

    # --- jaula_gritar: 3 s, o braco pra fora acenando, a cabeca pra tras
    q_gt = rig.pose(GRITANDO)
    p_gt = rig.assentar(q_gt)
    P3 = 3.0

    def grita(t, q, pos):
        A.girar(rig, q, "forearm.R", A.em_torno((0, 1, 0), 28 * C4.onda(t, P3, 3)))
        A.girar(rig, q, "upper_arm.R", A.em_torno((0, 0, 1), 12 * C4.onda(t, P3, 3)))
        A.girar(rig, q, "hand.R", A.em_torno((0, 1, 0), 20 * C4.onda(t, P3, 6)))
        r = C4.onda(t, P3, 2)
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), -5 * r))
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 6 * r))
        A.girar(rig, q, "head", A.em_torno((0, 0, 1), 12 * C4.onda(t, P3, 1)))
        C4.tremor_laco(rig, q, ["head", "upper_chest"], 2.0, 79, t, P3)
        return pos

    A.sequencia(rig, "jaula_gritar", [(0.0, q_gt, p_gt), (P3, q_gt, p_gt)],
                laco=True, passo=1, extra=grita)

    _abraco(rig, "abraco", ABRACO, GIRO_ABRACO, soluco=1.0)
    _abraco(rig, "abraco_jonny", ABRACO_JONNY, GIRO_ABRACO_JONNY, soluco=1.6)


def _abraco(rig, nome, pose, giros, soluco=1.0, assentar=None):
    """Um abraco em laco de 3 s: o balanco lento dos dois e os soluços (os
    ombros sobem e a cabeca treme)."""
    q = rig.pose(pose, _giros(rig, giros))
    p = assentar(q) if assentar else rig.assentar(q)
    P = 3.0

    def chora(t, qq, pos):
        A.girar(rig, qq, "spine", A.em_torno((0, 1, 0), 3.0 * C4.onda(t, P, 1)))
        A.girar(rig, qq, "spine", A.rz(2.5 * C4.onda(t, P, 1)))
        # soluço: cinco puxadas curtas de ar, os ombros sobem
        s = 0.0
        for k in range(5):
            s += C4.pulso(t, 0.25 + k * 0.55, 0.09, P)
        A.girar(rig, qq, "upper_chest", A.em_torno((1, 0, 0), -4.0 * soluco * s))
        A.girar(rig, qq, "shoulder.L", A.em_torno((0, 1, 0), -5.0 * soluco * s))
        A.girar(rig, qq, "shoulder.R", A.em_torno((0, 1, 0), 5.0 * soluco * s))
        A.girar(rig, qq, "neck", A.em_torno((1, 0, 0), 3.0 * soluco * s))
        C4.tremor_laco(rig, qq, ["head", "hand.L", "hand.R"], 1.2 * soluco, 83, t, P)
        return pos

    A.sequencia(rig, nome, [(0.0, q, p), (P, q, p)], laco=True, passo=1, extra=chora)


# ==============================================================================
# JONNY
# ==============================================================================

def clipes_jonny(rig):
    q_s = rig.pose(SENTADO)
    p_s = rig.assentar(q_s, apoios=APOIO_SENTADO, folga=0.07)
    P = 4.0

    def respira(t, q, pos):
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 2.0 * C4.onda(t, P, 2)))
        A.girar(rig, q, "head", A.em_torno((0, 0, 1), 4.0 * C4.onda(t, P, 1)))
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 2.5 * C4.onda(t, P, 1)))
        # as pernas penduradas balancam devagar
        A.girar(rig, q, "shin.L", A.em_torno((1, 0, 0), 5.0 * C4.onda(t, P, 1)))
        A.girar(rig, q, "shin.R", A.em_torno((1, 0, 0), -5.0 * C4.onda(t, P, 1)))
        return pos

    A.sequencia(rig, "sentado_maca", [(0.0, q_s, p_s), (P, q_s, p_s)],
                laco=True, passo=2, extra=respira)

    _abraco(rig, "abraco_sentado", ABRACO_SENTADO, GIRO_ABRACO_SENTADO, soluco=1.4,
            assentar=lambda q: rig.assentar(q, apoios=APOIO_SENTADO, folga=0.07))


# ==============================================================================
# MAYCOW PARASITA
# ==============================================================================

def clipes_parasita(rig):
    malha = C4.malha_do_rig(rig)
    if malha is not None:
        rig.mascara_chao = C4.mascara_sem(malha, ("Hips", "LeftUpLeg", "RightUpLeg"))
    _abraco(rig, "abraco", ABRACO, GIRO_ABRACO, soluco=0.6,
            assentar=lambda q: C4.assentar_na_malha(rig, q))

    q_nb = rig.pose(NAS_BARRAS)
    p_nb = C4.assentar_na_malha(rig, q_nb)
    q_pu = rig.pose(PUXANDO)
    p_pu = C4.assentar_na_malha(rig, q_pu, xy=(0.0, 0.10))
    q_ar = rig.pose(ARRANCOU)
    p_ar = C4.assentar_na_malha(rig, q_ar, xy=(0.0, 0.16))
    P = 2.8

    def forca(t, q, pos):
        e = C4.envelope(t, 1.75, 0.5, 0.15)
        C4.tremor_laco(rig, q, ["spine", "chest", "upper_arm.L", "upper_arm.R",
                                "forearm.L", "forearm.R", "neck"], 3.5 * e, 89, t, P)
        tranco = C4.pulso(t, 1.85, 0.08)
        A.girar(rig, q, "spine", A.em_torno((1, 0, 0), 10 * tranco))
        return pos

    C4.sequencia_no_chao(rig, "arrancar_porta", [
        (0.0, q_nb, p_nb), (0.5, q_pu, p_pu), (1.75, q_pu, p_pu),
        (2.0, q_ar, p_ar), (P, q_ar, p_ar)], passo=1, extra=forca)
