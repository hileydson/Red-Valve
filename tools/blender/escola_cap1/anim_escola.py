# -*- coding: utf-8 -*-
"""Clipes NOVOS da Dona Nice e do Jonny para a quadra da escola (Capitulo 1).

Os rigs sao os da igreja (`Red-Valve-Blender/dona_nice/dona_nice_cena.blend` e
`jonny/jonny.blend`) e as poses usam as mesmas ferramentas de la'. A diferenca
e' o destino: estes clipes saem num .glb SO' DE ESQUELETO
(`assets/3d_model/npc/escola/<nome>_escola_clipes.glb`) e o Godot os soma ao
AnimationPlayer do ator da igreja como a biblioteca "escola". Os .blend e a
biblioteca da igreja nao sao tocados.

Dona Nice (o Jonny vai do lado ESQUERDO dela, de mao dada):
  andar_de_mao   anda segurando a mao dele com a esquerda (laco)
  parada_de_mao  em pe, de mao dada (laco)
  olhar_tras     para e olha pra tras por cima do ombro direito (1,2 s)
  mao_pro_ceu    ainda virada, ergue a direita pro ceu (1,6 s)
  mao_no_ceu     segura a mao erguida, tremendo (laco)

Jonny (a mao DIREITA dele na esquerda dela):
  andar_de_mao   laco
  parado_de_mao  laco
"""

import math

import anim_comum as A
from anim_comum import D


def DR(fora, frente, cima):
    return D(-fora, frente, cima)


def _acao(acoes, nome):
    if nome in acoes:
        return acoes[nome]
    for k, a in acoes.items():
        if k.split(".")[0] == nome:
            return a
    raise KeyError(nome)


# --- Dona Nice ---------------------------------------------------------------
NICE_PE = {
    "spine": (0, 0.06, 1), "chest": (0, 0.08, 1), "upper_chest": (0, 0.06, 1),
    "neck": (0, 0.18, 1), "head": (0, 0.06, 1),
    "upper_arm.L": (0.35, 0.10, -1), "forearm.L": (0.22, 0.25, -1),
    "hand.L": (0.15, 0.20, -1), "fingers.L": (0.1, 0.3, -1),
    "upper_arm.R": DR(0.18, 0.05, -1), "forearm.R": DR(0.06, 0.20, -1),
    "hand.R": DR(0.02, 0.15, -1), "fingers.R": DR(0.0, 0.2, -1),
    "thigh.L": (0.05, 0.03, -1), "shin.L": (0, -0.04, -1),
    "foot.L": (0, 1, -0.55), "toe.L": (0, 1, -0.05),
}
BRACO_DE_MAO_NICE = ("upper_arm.L", "forearm.L", "hand.L", "fingers.L")

NICE_CEU = {
    "upper_arm.R": DR(0.15, 0.10, 1), "forearm.R": DR(0.05, 0.05, 1),
    "hand.R": DR(0.0, 0.0, 1), "fingers.R": DR(0.0, -0.1, 1),
}

# --- Jonny -------------------------------------------------------------------
JONNY_PE = {
    "spine": (0, 0.05, 1), "chest": (0, 0.05, 1), "upper_chest": (0, 0.05, 1),
    "neck": (0, 0.10, 1), "head": (0, 0.05, 1),
    "upper_arm.L": (0.18, 0.05, -1), "forearm.L": (0.08, 0.15, -1),
    "hand.L": (0.03, 0.15, -1), "fingers.L": (0, 0.2, -1),
    # a direita sobe pra mao dela (ela e' mais alta e fica a' direita dele)
    "upper_arm.R": DR(0.55, 0.05, -0.45), "forearm.R": DR(0.60, 0.08, -0.15),
    "hand.R": DR(0.65, 0.10, -0.05), "fingers.R": DR(0.6, 0.2, -0.2),
    "thigh.L": (0.05, 0.03, -1), "shin.L": (0, -0.04, -1),
    "foot.L": (0, 1, -0.55), "toe.L": (0, 1, -0.05),
}
BRACO_DE_MAO_JONNY = ("upper_arm.R", "forearm.R", "hand.R", "fingers.R")


def _prender(rig, fixo, ossos):
    """Ajuste de retarget: estes ossos ficam na pose `fixo` (de mundo)."""
    def ajuste(t, q, pos):
        for o in ossos:
            n = rig.n(o)
            if n in fixo:
                q[n] = fixo[n]
        return pos
    return ajuste


def clipes_dona_nice(rig, fontes):
    ml, a_ml = fontes["maycow_lopes"]
    q_pe = rig.pose(NICE_PE)
    p_pe = rig.assentar(q_pe)

    A.retarget(rig, ml, _acao(a_ml, "Walking"), "andar_de_mao", laco=True,
               velocidade=0.85, ajustes=_prender(rig, q_pe, BRACO_DE_MAO_NICE))

    def respira(t, q, pos):
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 1.2 * math.sin(t * math.tau / 3.5)))
        return pos
    A.sequencia(rig, "parada_de_mao", [(0.0, q_pe, p_pe), (3.5, q_pe, p_pe)],
                laco=True, passo=3, extra=respira)

    # olhar pra tras: o tronco vira pra direita e a cabeca completa o giro
    def vira(t, q, pos, u=None):
        u = min(1.0, t / 1.0) if u is None else u
        s = u * u * (3 - 2 * u)
        A.girar(rig, q, "spine", A.rz(-22 * s))
        A.girar(rig, q, "upper_chest", A.rz(-28 * s))
        A.girar(rig, q, "neck", A.rz(-38 * s))
        A.girar(rig, q, "head", A.rz(-42 * s))
        return pos
    A.sequencia(rig, "olhar_tras", [(0.0, q_pe, p_pe), (1.2, q_pe, p_pe)],
                passo=1, extra=vira)

    q_ceu = dict(q_pe)
    q_ceu.update(rig.pose({**NICE_PE, **NICE_CEU}))
    # mantem o braco de mao dada como estava
    for o in BRACO_DE_MAO_NICE:
        q_ceu[rig.n(o)] = q_pe[rig.n(o)]

    # A cabeca levanta ANTES do giro do tronco: girada por ultimo em torno do
    # X do mundo, ela rolaria de lado em vez de olhar pra cima.
    def sobe(t, q, pos):
        u = min(1.0, t / 1.6)
        A.girar(rig, q, "head", A.em_torno((1, 0, 0), -30 * u * u * (3 - 2 * u)))
        vira(0, q, pos, u=1.0)
        return pos
    A.sequencia(rig, "mao_pro_ceu", [(0.0, q_pe, p_pe), (1.6, q_ceu, p_pe)],
                passo=1, extra=sobe)

    def treme(t, q, pos):
        A.girar(rig, q, "head", A.em_torno((1, 0, 0), -30))
        vira(0, q, pos, u=1.0)
        A.tremor(rig, q, ["upper_arm.R", "forearm.R", "hand.R", "fingers.R"], 2.5, 91, t, freq=14)
        return pos
    A.sequencia(rig, "mao_no_ceu", [(0.0, q_ceu, p_pe), (2.0, q_ceu, p_pe)],
                laco=True, passo=1, extra=treme)


def clipes_jonny(rig, fontes):
    ml, a_ml = fontes["maycow_lopes"]
    q_pe = rig.pose(JONNY_PE)
    p_pe = rig.assentar(q_pe)
    # passada mais curta e mais rapida que a dela (velocidade > 1): a mesma
    # velocidade de chao com perna de menino
    A.retarget(rig, ml, _acao(a_ml, "Walking"), "andar_de_mao", laco=True,
               velocidade=1.05, ajustes=_prender(rig, q_pe, BRACO_DE_MAO_JONNY))

    def respira(t, q, pos):
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 1.0 * math.sin(t * math.tau / 2.8)))
        A.girar(rig, q, "head", A.rz(8 * math.sin(t * math.tau / 5.6)))
        return pos
    A.sequencia(rig, "parado_de_mao", [(0.0, q_pe, p_pe), (5.6, q_pe, p_pe)],
                laco=True, passo=3, extra=respira)
