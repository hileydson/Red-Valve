# -*- coding: utf-8 -*-
"""Clipes da Dona Nice NORMAL (possuida, antes de virar monstro).

A historia da cena, do lado dela:

  ajoelhada_sussurro  ajoelhada de COSTAS pra porta, sobre o Jonny, faca na
                      mao direita, balancando e sussurrando (laco)
  levantar            levanta devagar: apoia uma perna, empurra, fica de pe'
                      curvada
  girar_cabeca        so' a cabeca gira 180 graus, aos trancos, ate' encarar
                      o Maycow na porta — o corpo continua de costas
  olhando_parada      parada assim, com tiques (laco) — o impasse
  virar_corpo         o corpo gira pra alcancar a cabeca, que fica parada no
                      mundo
  convulsao           o comeco da transformacao (captura Hit_Reaction_with_Bow
                      + tremor). A monstro tem um clipe IDENTICO com o mesmo
                      nome: o Godot toca os dois juntos e dissolve uma na outra

Direcoes: ver anim_comum.D (esquerda, frente, cima). Ela e' de costas pra
porta, entao "frente" dela aqui e' o altar.
"""

import math

import anim_comum as A
from anim_comum import D

# lado direito dado explicito: D com a lateral ja' trocada (pra fora = -)


def DR(fora, frente, cima):
    return D(-fora, frente, cima)


ROSTO = ("jaw", "tongue", "lip_", "cheek", "eyelid")

EM_PE = {
    "spine": (0, 0.12, 1), "chest": (0, 0.18, 1), "upper_chest": (0, 0.15, 1),
    "neck": (0, 0.30, 1), "head": (0, 0.12, 1),
    "upper_arm.L": (0.22, 0.05, -1), "forearm.L": (0.08, 0.30, -1),
    "hand.L": (0.03, 0.25, -1), "fingers.L": (0.0, 0.45, -1),
    "upper_arm.R": DR(0.20, 0.10, -1), "forearm.R": DR(0.05, 0.55, -0.85),
    "hand.R": DR(0.0, 0.60, -0.80), "fingers.R": DR(0.0, 0.2, -1),
    "thigh.L": (0.05, 0.03, -1), "shin.L": (0, -0.04, -1),
    "foot.L": (0, 1, -0.55), "toe.L": (0, 1, -0.05),
}

AJOELHADA = {
    "spine": (0, 0.35, 1), "chest": (0, 0.50, 1), "upper_chest": (0, 0.45, 1),
    "neck": (0, 0.85, 1), "head": (0, 0.80, 1),
    # a direita segura a faca erguida, lamina pra baixo, sobre o peito dele
    "upper_arm.R": DR(0.18, 0.50, -0.85), "forearm.R": DR(-0.20, 0.85, -0.15),
    "hand.R": DR(-0.05, 0.85, -0.45), "fingers.R": DR(-0.30, 0.75, -0.55),
    # a esquerda pousada no corpo dele
    "upper_arm.L": (0.15, 0.55, -0.80), "forearm.L": (-0.05, 0.80, -0.60),
    "hand.L": (0.0, 0.45, -0.90), "fingers.L": (0, 0.3, -1),
    # sentada sobre os calcanhares, peito do pe' no chao
    "thigh.L": (0.12, 0.55, -0.83), "shin.L": (0.02, -1, -0.04),
    "foot.L": (0, -1, -0.12), "toe.L": (0, -1, 0.0),
}

AFUNDADA = dict(AJOELHADA)
AFUNDADA.update({
    "spine": (0, 0.55, 1), "chest": (0, 0.75, 1), "upper_chest": (0, 0.70, 1),
    "neck": (0, 1.1, 0.8), "head": (0, 1.0, 0.6),
    "upper_arm.L": (0.20, 0.75, -0.65), "forearm.L": (0.0, 0.5, -0.9),
    "hand.L": (0, 0.6, -0.8),
})

AVANCO = {
    "spine": (0, 0.45, 1), "chest": (0, 0.40, 1), "upper_chest": (0, 0.30, 1),
    "neck": (0, 0.50, 1), "head": (0, 0.40, 1),
    "upper_arm.R": DR(0.20, 0.30, -0.9), "forearm.R": DR(0.0, 0.60, -0.8),
    "hand.R": DR(0, 0.70, -0.7),
    "upper_arm.L": (0.10, 0.60, -0.80), "forearm.L": (-0.20, 0.80, -0.40),
    "hand.L": (0, 0.6, -0.8),
    # joelho direito em cima, pe' plantado; esquerdo ainda no chao
    "thigh.R": DR(0.08, 1, -0.15), "shin.R": DR(0, -0.10, -1),
    "foot.R": DR(0, 1, -0.5), "toe.R": DR(0, 1, 0),
    "thigh.L": (0.05, -0.10, -1), "shin.L": (0, -1, -0.04),
    "foot.L": (0, -1, -0.12), "toe.L": (0, -1, 0.0),
}

EMPURRANDO = dict(EM_PE)
EMPURRANDO.update({
    "spine": (0, 0.6, 1), "chest": (0, 0.45, 1), "upper_chest": (0, 0.3, 1),
    "neck": (0, 0.45, 1),
    "thigh.R": DR(0.06, 0.55, -0.85), "shin.R": DR(0, -0.15, -1),
    "thigh.L": (0.05, 0.10, -1), "shin.L": (0, -0.45, -0.9),
    "foot.L": (0, 0.6, -0.8),
    "upper_arm.L": (0.1, 0.5, -0.85), "forearm.L": (-0.1, 0.6, -0.8),
})

APOIO_JOELHO = ("shin.L", "shin.R", "foot.L", "foot.R", "toe.L", "toe.R")


def _pose(rig, d):
    return rig.pose(dict(d))


def clipes(rig, fontes, origem_fala):
    q_pe = _pose(rig, EM_PE)
    p_pe = rig.assentar(q_pe)
    q_ajo = _pose(rig, AJOELHADA)
    p_ajo = rig.assentar(q_ajo, apoios=APOIO_JOELHO, folga=0.06)
    q_afu = _pose(rig, AFUNDADA)
    p_afu = rig.assentar(q_afu, apoios=APOIO_JOELHO, folga=0.06)
    q_ava = _pose(rig, AVANCO)
    p_ava = rig.assentar(q_ava, apoios=APOIO_JOELHO, folga=0.06)
    q_emp = _pose(rig, EMPURRANDO)
    p_emp = rig.assentar(q_emp)

    # --- ajoelhada_sussurro (laco de 6 s) ----------------------------------
    def balanco(t, q, pos):
        a = 4.0 * math.sin(t * math.tau / 3.0)          # balanca o tronco
        A.girar(rig, q, "spine", A.em_torno((1, 0, 0), a))
        A.girar(rig, q, "head", A.em_torno((1, 0, 0), 2.5 * math.sin(t * math.tau / 1.5)))
        A.girar(rig, q, "hand.R", A.em_torno((0, 1, 0), 3.0 * math.sin(t * 11.0)))
        A.tremor(rig, q, ["fingers.L", "fingers.R"], 2.0, 7, t)
        return pos
    acao = A.sequencia(rig, "ajoelhada_sussurro",
                       [(0.0, q_ajo, p_ajo), (6.0, q_ajo, p_ajo)],
                       laco=True, passo=3, extra=balanco)
    if origem_fala:
        A.copiar_canais(origem_fala, acao, ROSTO, 6.0 * A.FPS)

    # --- levantar (4,6 s) ----------------------------------------------------
    A.sequencia(rig, "levantar", [
        (0.0, q_ajo, p_ajo),
        (0.9, q_afu, p_afu),       # afunda antes de levantar: pega impulso
        (2.2, q_ava, p_ava),
        (3.4, q_emp, p_emp),
        (4.6, q_pe, p_pe),
    ], passo=2)

    # --- girar_cabeca (3,5 s) -------------------------------------------------
    marcos = [(0.0, 0), (0.5, 12), (0.9, 18), (1.25, 95), (1.5, 90), (1.9, 100),
              (2.4, 172), (2.6, 188), (2.85, 178), (3.5, 180)]

    def angulo(t):
        for i in range(len(marcos) - 1):
            (ta, aa), (tb, ab) = marcos[i], marcos[i + 1]
            if ta <= t <= tb:
                u = (t - ta) / (tb - ta)
                return aa + (ab - aa) * (u * u * (3 - 2 * u))
        return marcos[-1][1]

    def cabeca_vira(t, q, pos):
        g = angulo(t)
        A.girar(rig, q, "neck", A.rz(0.4 * g))
        A.girar(rig, q, "head", A.rz(0.6 * g))
        # inclina de lado enquanto gira — e' o que tira o ar de humano
        incl = 25.0 * min(1.0, g / 180.0)
        A.girar(rig, q, "head", A.em_torno((0, 1, 0), incl))
        A.tremor(rig, q, ["head"], 1.5, 3, t, freq=16.0)
        return pos
    A.sequencia(rig, "girar_cabeca", [(0.0, q_pe, p_pe), (3.5, q_pe, p_pe)],
                passo=1, extra=cabeca_vira)

    # --- olhando_parada (laco 4 s) -------------------------------------------
    def tiques(t, q, pos):
        cabeca_vira(3.5, q, pos)
        A.tremor(rig, q, ["head", "neck"], 2.0, 11, t, freq=7.0)
        A.tremor(rig, q, ["hand.R", "hand.L", "fingers.R", "fingers.L"], 3.0, 13, t)
        A.girar(rig, q, "spine", A.em_torno((1, 0, 0), 1.5 * math.sin(t * math.tau / 4.0)))
        return pos
    A.sequencia(rig, "olhando_parada", [(0.0, q_pe, p_pe), (4.0, q_pe, p_pe)],
                laco=True, passo=2, extra=tiques)

    # --- virar_corpo (1,6 s) -------------------------------------------------
    def corpo_vira(t, q, pos):
        u = min(1.0, t / 1.6)
        th = 180.0 * (u * u * (3 - 2 * u))
        A.girar(rig, q, "hips", A.rz(th))
        resto = 180.0 - th
        A.girar(rig, q, "neck", A.rz(0.4 * resto))
        A.girar(rig, q, "head", A.rz(0.6 * resto))
        A.girar(rig, q, "head", A.em_torno((0, 1, 0), 25.0 * (1 - u)))
        return pos
    A.sequencia(rig, "virar_corpo", [(0.0, q_pe, p_pe), (1.6, q_pe, p_pe)],
                passo=1, extra=corpo_vira)

    # --- convulsao (comeco da transformacao) ---------------------------------
    convulsao(rig, fontes)


def convulsao(rig, fontes):
    """Igual pra Dona Nice e pra monstro: mesma fonte, mesmo tremor, mesma
    semente. O Godot toca as duas ao mesmo tempo e dissolve uma na outra."""
    fonte, acoes = fontes["maycow_lopes"]

    def possessao(t, q, pos):
        s = t / A.FPS
        forca = min(1.0, s / 1.5)
        A.tremor(rig, q, ["spine", "chest", "neck", "head"], 6.0 * forca, 21, s, freq=13.0)
        A.tremor(rig, q, ["upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R"],
                 9.0 * forca, 23, s, freq=17.0)
        A.tremor(rig, q, ["hand.L", "hand.R"], 14.0 * forca, 29, s, freq=21.0)
        return pos
    A.retarget(rig, fonte, acoes["Hit_Reaction_with_Bow"], "convulsao",
               velocidade=0.75, ajustes=possessao)
