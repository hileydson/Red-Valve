# -*- coding: utf-8 -*-
"""Clipes da Dona Nice MONSTRO (fase 1).

  convulsao     a transformacao — identica a' da Dona Nice normal (o Godot
                toca as duas juntas e dissolve uma na outra)
  rugido        fim da transformacao: arqueia pra tras, abre os bracos, e
                desce pra postura de caca
  parado        respirando curvada (laco) — captura Idle
  andar         o andar cambaleante e LENTO dela (laco) — Unsteady_Walk a 0,7
  agarrar       a investida quando o Maycow chega perto — captura Attack
  mordendo      agarrada nele, mordendo e babando (laco)
  dano          o tranco de cada tiro — comeco do Mummy_Stagger
  morrer        a fase 1 acaba: cai de joelhos e treme (vira a fase 2 no Godot)
  cair_morta    a morte de verdade: de joelhos pra cara no chao
  morta         caida, parada (pro corpo que fica na igreja nas outras visitas)
"""

import math

import anim_comum as A
import anim_dona_nice as DN
from anim_comum import D


def DR(fora, frente, cima):
    return D(-fora, frente, cima)


CURVADA = {
    "spine": (0, 0.30, 1), "chest": (0, 0.35, 1), "upper_chest": (0, 0.30, 1),
    "neck": (0, 0.65, 1), "head": (0, 0.30, 1),
    "upper_arm.L": (0.35, 0.25, -1), "forearm.L": (0.15, 0.6, -0.8),
    "hand.L": (0.05, 0.7, -0.7),
    "thigh.L": (0.08, 0.15, -1), "shin.L": (0, -0.15, -1),
    "foot.L": (0, 1, -0.55), "toe.L": (0, 1, 0),
}

ARQUEADA = {
    "spine": (0, -0.25, 1), "chest": (0, -0.45, 1), "upper_chest": (0, -0.55, 1),
    "neck": (0, -0.3, 1), "head": (0, -0.6, 1),
    "upper_arm.L": (1, -0.35, 0.1), "forearm.L": (1, -0.1, 0.45),
    "hand.L": (0.8, 0.2, 0.6), "fingers.L": (0.5, 0.5, 0.7),
    "thigh.L": (0.15, 0.0, -1), "shin.L": (0.05, -0.1, -1),
    "foot.L": (0.1, 1, -0.55), "toe.L": (0.1, 1, 0),
}

CACA = {
    "spine": (0, 0.55, 1), "chest": (0, 0.6, 1), "upper_chest": (0, 0.45, 1),
    "neck": (0, 0.2, 1), "head": (0, 0.35, 1),
    "upper_arm.L": (0.6, 0.6, -0.5), "forearm.L": (0.3, 1, -0.2),
    "hand.L": (0.1, 1, -0.4), "fingers.L": (0, 0.8, -0.6),
    "thigh.L": (0.2, 0.45, -1), "shin.L": (0.05, -0.5, -1),
    "foot.L": (0.1, 1, -0.55), "toe.L": (0.1, 1, 0),
}

AGARRANDO = {
    "spine": (0, 0.35, 1), "chest": (0, 0.45, 1), "upper_chest": (0, 0.45, 1),
    "neck": (0, 0.55, 1), "head": (0, 0.45, 1),
    "upper_arm.L": (0.25, 1, -0.2), "forearm.L": (-0.55, 0.8, 0.15),
    "hand.L": (-0.7, 0.6, 0.2), "fingers.L": (-0.8, 0.4, 0),
    "thigh.L": (0.12, 0.2, -1), "shin.L": (0, -0.2, -1),
    "foot.L": (0.05, 1, -0.55), "toe.L": (0.05, 1, 0),
}

JOELHOS = dict(DN.AFUNDADA)
JOELHOS.update({
    "spine": (0, 0.2, 1), "chest": (0, 0.1, 1), "upper_chest": (0, -0.1, 1),
    "neck": (0, -0.3, 1), "head": (0, -0.7, 1),
    "upper_arm.L": (0.4, 0.0, -1), "forearm.L": (0.2, 0.2, -1),
    "hand.L": (0.1, 0.2, -1), "fingers.L": (0, 0.3, -1),
})
JOELHOS.pop("upper_arm.R", None)
JOELHOS.pop("forearm.R", None)
JOELHOS.pop("hand.R", None)
JOELHOS.pop("fingers.R", None)

MORTA = {
    "spine": (0, 1, 0.04), "chest": (0, 1, 0.02), "upper_chest": (0, 1, 0.0),
    "neck": (0.15, 1, -0.05), "head": (0.35, 1, -0.05),
    "upper_arm.L": (0.35, 1, 0.0), "forearm.L": (0.1, 1, 0.0),
    "hand.L": (0.0, 1, -0.1), "fingers.L": (0, 1, -0.15),
    "upper_arm.R": DR(0.45, -0.6, -0.05), "forearm.R": DR(0.1, -1, -0.02),
    "hand.R": DR(0, -1, -0.15),
    "thigh.L": (0.12, -1, -0.03), "shin.L": (0.05, -1, 0.15),
    "foot.L": (0.0, -0.4, -0.9), "toe.L": (0, -0.3, -1),
    "thigh.R": DR(0.05, -1, -0.03), "shin.R": DR(0.0, -1, -0.05),
    "foot.R": DR(0.2, -0.3, -0.9), "toe.R": DR(0.2, -0.2, -1),
}

DEITADO = ("spine", "chest", "upper_chest", "neck", "head", "upper_arm.L",
           "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R",
           "thigh.L", "shin.L", "foot.L", "toe.L", "thigh.R", "shin.R",
           "foot.R", "toe.R")


def clipes(rig, fontes):
    zumbi, acoes_z = fontes["zombie"]
    anti, acoes_a = fontes["anti_lopes"]

    DN.convulsao(rig, fontes)

    q_curv = rig.pose(CURVADA)
    p_curv = rig.assentar(q_curv)
    q_arq = rig.pose(ARQUEADA)
    p_arq = rig.assentar(q_arq)
    q_caca = rig.pose(CACA)
    p_caca = rig.assentar(q_caca)

    def treme(t, q, pos):
        A.tremor(rig, q, ["chest", "neck", "head", "hand.L", "hand.R"], 3.5, 41, t, freq=15)
        return pos
    A.sequencia(rig, "rugido", [
        (0.0, q_curv, p_curv), (0.8, q_arq, p_arq), (2.0, q_arq, p_arq),
        (2.9, q_caca, p_caca)], passo=2, extra=treme)

    A.retarget(rig, zumbi, acoes_z["Idle"], "parado", laco=True, velocidade=0.6)
    A.retarget(rig, zumbi, acoes_z["Unsteady_Walk"], "andar", laco=True, velocidade=0.7)
    A.retarget(rig, anti, acoes_a["Attack"], "agarrar", ini=0, fim=48)

    q_agr = rig.pose(AGARRANDO)
    p_agr = rig.assentar(q_agr)

    def morde(t, q, pos):
        # duas mordidas por segundo, com tranco de cabeca e de ombro
        f = (t * 2.0) % 1.0
        golpe = math.exp(-((f - 0.25) / 0.08) ** 2)
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 18 * golpe))
        A.girar(rig, q, "head", A.em_torno((0, 0, 1), 12 * math.sin(t * 9)))
        A.girar(rig, q, "upper_chest", A.em_torno((1, 0, 0), 6 * golpe))
        A.tremor(rig, q, ["hand.L", "hand.R", "fingers.L", "fingers.R"], 4.0, 47, t, freq=13)
        return pos
    A.sequencia(rig, "mordendo", [(0.0, q_agr, p_agr), (2.0, q_agr, p_agr)],
                laco=True, passo=1, extra=morde)

    A.retarget(rig, zumbi, acoes_z["Mummy_Stagger"], "dano", ini=0, fim=26)

    q_joe = rig.pose(JOELHOS)
    p_joe = rig.assentar(q_joe, apoios=DN.APOIO_JOELHO, folga=0.07)

    def convulsiona(t, q, pos):
        f = min(1.0, t / 1.2)
        A.tremor(rig, q, ["spine", "chest", "neck", "head"], 7 * f, 53, t, freq=14)
        A.tremor(rig, q, ["upper_arm.L", "upper_arm.R", "hand.L", "hand.R"], 10 * f, 59, t, freq=18)
        return pos
    A.sequencia(rig, "morrer", [
        (0.0, q_curv, p_curv), (0.5, q_arq, p_arq), (1.4, q_joe, p_joe),
        (4.0, q_joe, p_joe)], passo=1, extra=convulsiona)

    q_morta = rig.pose(MORTA)
    p_morta = rig.assentar(q_morta, xy=(0.0, -0.75), apoios=DEITADO, folga=0.11)
    meio = A.mistura(q_joe, q_morta, 0.45)
    p_meio = rig.assentar(meio, xy=(0.0, -0.35), apoios=DEITADO, folga=0.25)
    A.sequencia(rig, "cair_morta", [
        (0.0, q_joe, p_joe), (0.7, meio, p_meio), (1.15, q_morta, p_morta),
        (1.35, q_morta, p_morta + A.Vector((0, 0, 0.04))),  # quica
        (1.6, q_morta, p_morta)], passo=1)
    A.sequencia(rig, "morta", [(0.0, q_morta, p_morta), (1.0, q_morta, p_morta)],
                laco=True, passo=30)
