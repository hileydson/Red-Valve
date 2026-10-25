# -*- coding: utf-8 -*-
"""Clipes do Jonny.

  caido_agonia     de costas no chao da igreja, a mao direita apertando a
                   barriga, peito arfando curto, cabeca rolando (laco)
  sendo_erguido    do chao pro colo (toca junto com o `pegar_jonny` do Maycow)
  no_colo          mole nos bracos do Maycow: cabeca pendendo pra tras,
                   pernas dobradas sobre o braco dele (laco)
  sendo_largado    do colo pro chao (junto com o `largar_jonny`)
  deitado          no chao, respirando fraco (o peito sobe e desce, laco)

Deitado de costas, o "frente" do corpo vira CIMA: a coluna aponta pra tras do
personagem (D(0,-1,..)) e as pernas pra frente dele.
"""

import math

import anim_comum as A
from anim_comum import D


def DR(fora, frente, cima):
    return D(-fora, frente, cima)


DE_COSTAS = {
    "spine": (0, -1, 0.03), "chest": (0, -1, 0.02), "upper_chest": (0, -1, 0.0),
    "neck": (0, -1, -0.05), "head": (0.25, -1, 0.15),
    "upper_arm.L": (0.35, 0.95, -0.05), "forearm.L": (0.2, 1, 0.0),
    "hand.L": (0.12, 1, -0.05), "fingers.L": (0.1, 1, -0.1),
    # a direita na barriga
    "upper_arm.R": DR(0.25, 0.8, 0.4), "forearm.R": DR(-0.85, 0.3, 0.3),
    "hand.R": DR(-0.9, 0.35, -0.1),
    "thigh.L": (0.1, 1, 0.0), "shin.L": (0.03, 1, -0.02),
    "foot.L": (0.08, 0.3, 1), "toe.L": (0.05, 0.2, 1),
    # o joelho direito dobrado, pe' no chao
    "thigh.R": DR(0.08, 0.7, 0.7), "shin.R": DR(0.02, 0.7, -0.7),
    "foot.R": DR(0.0, 1, -0.1), "toe.R": DR(0, 1, 0),
}

NO_COLO = {
    "spine": (0, -1, 0.5), "chest": (0, -1, 0.55), "upper_chest": (0, -1, 0.45),
    "neck": (0, -1, -0.1), "head": (0.1, -0.6, -0.8),
    "upper_arm.L": (0.15, 0.1, -1), "forearm.L": (0.05, 0.15, -1),
    "hand.L": (0.02, 0.1, -1), "fingers.L": (0, 0.1, -1),
    "upper_arm.R": DR(0.2, 0.6, 0.5), "forearm.R": DR(-0.8, 0.35, 0.3),
    "hand.R": DR(-0.9, 0.3, -0.2),
    "thigh.L": (0.08, 1, 0.35), "shin.L": (0.0, 0.55, -0.85),
    "foot.L": (0.0, 0.3, -0.95), "toe.L": (0, 0.6, -0.8),
}

# o quadril dele fica na origem do no' (o Godot pendura o no' nos bracos do
# Maycow); no chao, a origem continua no chao
ORIGEM_COLO = (0.0, 0.0)


def clipes(rig, fontes):
    q_ch = rig.pose(DE_COSTAS)
    todos = tuple(DE_COSTAS.keys())
    p_ch = rig.assentar(q_ch, apoios=todos, folga=0.08)
    q_colo = rig.pose(NO_COLO)
    p_colo = A.Vector((0.0, 0.0, 0.0))
    meio = A.mistura(q_ch, q_colo, 0.5)
    p_meio = p_ch.lerp(A.Vector((0, 0, 0.5)), 0.5)

    def agonia(t, q, pos):
        # respiracao curta e rapida, com engasgo a cada ~4 s
        r = math.sin(t * math.tau / 0.9)
        eng = math.exp(-(((t % 4.2) - 3.1) / 0.18) ** 2)
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 2.2 * r + 6 * eng))
        A.girar(rig, q, "head", A.em_torno((0, 1, 0), 14 * math.sin(t * math.tau / 5.0)))
        A.girar(rig, q, "neck", A.em_torno((0, 0, 1), 4 * eng))
        # a mao esquerda tenta subir e cai
        sobe = max(0.0, math.sin(t * math.tau / 5.0 - 1.0)) ** 3
        A.girar(rig, q, "upper_arm.L", A.em_torno((0, 1, 0), -20 * sobe))
        A.girar(rig, q, "forearm.L", A.em_torno((0, 1, 0), -25 * sobe))
        A.tremor(rig, q, ["hand.L", "fingers.L", "hand.R"], 3.0, 71, t, freq=11)
        A.girar(rig, q, "thigh.R", A.em_torno((0, 1, 0), 5 * math.sin(t * 1.3)))
        return pos + A.Vector((0, 0, 0.005 * r))

    A.sequencia(rig, "caido_agonia", [(0.0, q_ch, p_ch), (8.4, q_ch, p_ch)],
                laco=True, passo=3, extra=agonia)

    def mole(t, q, pos):
        A.girar(rig, q, "head", A.em_torno((0, 1, 0), 9 * math.sin(t * math.tau / 1.1)))
        A.girar(rig, q, "upper_arm.L", A.em_torno((0, 1, 0), 7 * math.sin(t * math.tau / 1.1 + 0.6)))
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 1.5 * math.sin(t * math.tau / 1.6)))
        return pos

    A.sequencia(rig, "no_colo", [(0.0, q_colo, p_colo), (2.2, q_colo, p_colo)],
                laco=True, passo=2, extra=mole)
    # sincronizado com o pegar_jonny (3,3 s): fica no chao ate' 1,7 s
    A.sequencia(rig, "sendo_erguido", [
        (0.0, q_ch, p_ch), (1.7, q_ch, p_ch), (2.3, meio, p_meio),
        (3.3, q_colo, p_colo)], passo=2)
    # sincronizado com o largar_jonny (3,2 s): chega ao chao em 1,6 s
    A.sequencia(rig, "sendo_largado", [
        (0.0, q_colo, p_colo), (1.0, meio, p_meio), (1.6, q_ch, p_ch),
        (3.2, q_ch, p_ch)], passo=2)

    def fraco(t, q, pos):
        # respiracao fraca mas que se VE: a coluna e o peito sobem, o alto do
        # peito devolve o giro (o peito estufa ~1 cm) e o pescoco e os bracos
        # desfazem o resto — a cabeca e as maos ficam no chao. Valores achados
        # por busca (cabeca < 2 mm, maos < 1 cm).
        r = math.sin(t * math.tau / 2.2)
        A.girar(rig, q, "spine", A.em_torno((1, 0, 0), 1.4 * r))
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 2.8 * r))
        A.girar(rig, q, "upper_chest", A.em_torno((1, 0, 0), -8.4 * r))
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 4.2 * r))
        A.girar(rig, q, "upper_arm.L", A.em_torno((1, 0, 0), 4.2 * r))
        A.girar(rig, q, "upper_arm.R", A.em_torno((1, 0, 0), 4.2 * r))
        return pos
    A.sequencia(rig, "deitado", [(0.0, q_ch, p_ch), (4.4, q_ch, p_ch)],
                laco=True, passo=1, extra=fraco)
