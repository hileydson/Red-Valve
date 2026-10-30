# -*- coding: utf-8 -*-
"""O clipe da Drizzi Wisny: `conversando` (laco de 6 s).

Ela fala com o Maycow DE COSTAS pra camera (`scripts/cutscenes/cutscene_drizzi.gd`),
entao o que tem de ler e' o que se ve' por tras: o braco direito (o humano)
explicando — sobe pra frente, abre, o antebraco dobra e a mao gira —, o
esquerdo descansando junto do corpo com um gesto pequeno, os ombros, a cabeca
acenando e inclinando enquanto ela fala, e o peso trocando de leve.

Tudo e' giro de MUNDO sobre o repouso do scan (o braco em A): eixo X = da
direita pra esquerda dela, Y = da frente (-) pra tras (+), Z = pra cima.
Giro negativo em X leva braco e cabeca pra FRENTE. Os senos tem 1, 2 ou 3
voltas em 6 s: o laco fecha sem emenda.
"""

import math

import anim_comum as A
from mathutils import Vector

DURACAO = 6.0
W = math.tau / DURACAO


def _s(t, voltas, fase=0.0):
    return math.sin(t * W * voltas + fase)


def clipes(rig):
    q0 = rig.pose({})
    p0 = rig.quadril_rest()

    def fala(t, q, pos):
        # o corpo: balanco lento e o peito respirando
        A.girar(rig, q, "spine", A.em_torno((0, 1, 0), 3.0 * _s(t, 1)))
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 2.0 * _s(t, 2, 0.4)))
        A.girar(rig, q, "upper_chest", A.rz(4.0 * _s(t, 1, 1.2)))
        # o braco esquerdo: sai da pose A e desce pra junto do corpo (giro
        # positivo em Y abaixa o lado +X), com o antebraco meio dobrado e um
        # gesto pequeno da mao
        A.girar(rig, q, "upper_arm.L", A.em_torno((0, 1, 0), 30.0 + 2.0 * _s(t, 1, 0.8)))
        A.girar(rig, q, "upper_arm.L", A.em_torno((1, 0, 0), -8.0 - 4.0 * _s(t, 1, 2.0)))
        A.girar(rig, q, "forearm.L", A.em_torno((1, 0, 0), -22.0 - 8.0 * _s(t, 2, 1.5)))
        A.girar(rig, q, "hand.L", A.em_torno((1, 0, 0), -6.0 * _s(t, 3, 0.3)))
        # o braco humano explicando: sobe pra frente e abre, o cotovelo dobra
        # e solta, e a mao vira a palma
        A.girar(rig, q, "shoulder.R", A.em_torno((0, 1, 0), 4.0 + 3.0 * _s(t, 2, 0.2)))
        A.girar(rig, q, "upper_arm.R", A.em_torno((1, 0, 0), -32.0 - 14.0 * _s(t, 2, 0.6)))
        A.girar(rig, q, "upper_arm.R", A.em_torno((0, 1, 0), 10.0 + 8.0 * _s(t, 1, 1.0)))
        A.girar(rig, q, "forearm.R", A.em_torno((1, 0, 0), -38.0 - 26.0 * _s(t, 3, 1.1)))
        A.girar(rig, q, "hand.R", A.em_torno((0, 0, 1), 25.0 * _s(t, 3, 2.0)))
        A.girar(rig, q, "hand.R", A.em_torno((1, 0, 0), -12.0 * _s(t, 2, 0.9)))
        # a cabeca: acena, inclina e vira um pouco, como quem fala
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 4.0 + 5.0 * _s(t, 3, 0.5)))
        A.girar(rig, q, "head", A.em_torno((0, 1, 0), 6.0 * _s(t, 1, 0.3)))
        A.girar(rig, q, "head", A.rz(9.0 * _s(t, 1, 2.4)))
        # de pe': so' o peso indo de um lado pro outro
        return pos + Vector((0.008 * _s(t, 1, 0.5), 0.0, 0.004 * _s(t, 2)))

    A.sequencia(rig, "conversando", [(0.0, q0, p0), (DURACAO, q0, p0)],
                laco=True, passo=2, extra=fala)
