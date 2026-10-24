# -*- coding: utf-8 -*-
"""Clipes da Dona Nice MONSTRO FASE 2 (a gigante que flutua).

  surgir     sai encolhida e se abre: bracos, cabeca, tentaculos (o
             crescimento de tamanho e' do Godot, no no')
  flutuar    pairando (laco): bracos balancam devagar, dedos abrem e
             fecham, tentaculos ondulam cada um na sua fase
  cuspir     recolhe a cabeca e cospe pra frente
  investida  inclina o corpo e joga os bracos pra tras (vem pra cima dele)
  tapa       ergue o braco direito e bate de cima pra baixo
  dano       o tranco do tiro
  morrer     convulsiona e desaba, tentaculos murchos

A pose de repouso dela JA' e' a pose de ameaca (bracos estendidos pra frente),
entao quase tudo aqui e' o repouso mais movimento.
"""

import math

import anim_comum as A
from anim_comum import D

TENTACULOS = 6


def DR(fora, frente, cima):
    return D(-fora, frente, cima)


def ondular(rig, q, t, amplitude=14.0, velocidade=1.0):
    for i in range(1, TENTACULOS + 1):
        fase = i * 1.37
        for k in (1, 2, 3):
            n = "tentaculo_%d_%d" % (i, k)
            if n not in rig.arm.data.bones:
                continue
            a = amplitude * k * 0.7 * math.sin(t * 2.1 * velocidade + fase - k * 0.9)
            b = amplitude * 0.6 * k * 0.7 * math.cos(t * 1.6 * velocidade + fase * 1.3 - k * 0.7)
            A.girar(rig, q, n, A.em_torno((1, 0, 0), a))
            A.girar(rig, q, n, A.em_torno((0, 1, 0), b))


def respirar(rig, q, t):
    A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 2.5 * math.sin(t * math.tau / 3.2)))
    A.girar(rig, q, "head", A.em_torno((0, 1, 0), 6 * math.sin(t * math.tau / 5.0)))
    A.girar(rig, q, "head", A.em_torno((1, 0, 0), 4 * math.sin(t * math.tau / 3.7)))


ENCOLHIDA = {
    "spine": (0, 0.7, 0.7), "chest": (0, 0.9, 0.4), "upper_chest": (0, 1, 0.1),
    "neck": (0, 1, -0.3), "head": (0, 0.6, -0.8),
    "upper_arm.L": (-0.2, 0.8, -0.6), "forearm.L": (-0.7, 0.2, 0.6),
    "hand.L": (-0.6, -0.2, 0.7),
}
ABERTA = {
    "spine": (0, -0.1, 1), "chest": (0, -0.25, 1), "upper_chest": (0, -0.3, 1),
    "neck": (0, -0.1, 1), "head": (0, -0.5, 1),
    "upper_arm.L": (1, 0.1, 0.45), "forearm.L": (1, 0.3, 0.6),
    "hand.L": (0.7, 0.5, 0.6), "fingers.L": (0.5, 0.8, 0.4),
}
CUSPIR_ATRAS = {
    "chest": (0, -0.2, 1), "upper_chest": (0, -0.3, 1), "neck": (0, -0.5, 1),
    "head": (0, -0.8, 1),
}
CUSPIR_FRENTE = {
    "spine": (0, 0.3, 1), "chest": (0, 0.5, 1), "upper_chest": (0, 0.7, 1),
    "neck": (0, 1, 0.5), "head": (0, 1, 0.2),
}
INVESTIDA = {
    "spine": (0, 0.6, 1), "chest": (0, 0.8, 1), "upper_chest": (0, 0.9, 1),
    "neck": (0, 0.8, 1), "head": (0, 0.6, 1),
    "upper_arm.L": (0.5, -0.8, -0.4), "forearm.L": (0.3, -1, -0.2),
    "hand.L": (0.2, -1, 0.0),
}
TAPA_ALTO = {
    "upper_chest": (0.0, -0.15, 1), "chest": (0.1, -0.1, 1),
    "upper_arm.R": DR(0.3, -0.1, 1), "forearm.R": DR(0.1, -0.4, 1),
    "hand.R": DR(0.0, -0.6, 0.8),
}
TAPA_BAIXO = {
    "spine": (0, 0.5, 1), "chest": (0, 0.6, 1), "upper_chest": (0.0, 0.7, 1),
    "upper_arm.R": DR(0.15, 1, -0.6), "forearm.R": DR(0.0, 0.7, -1),
    "hand.R": DR(0.0, 0.3, -1), "fingers.R": DR(0, 0.6, -1),
}
DESABADA = {
    "spine": (0, 0.9, 0.4), "chest": (0, 1, 0.1), "upper_chest": (0, 1, -0.2),
    "neck": (0.2, 1, -0.6), "head": (0.3, 0.5, -1),
    "upper_arm.L": (0.3, 0.3, -1), "forearm.L": (0.1, 0.2, -1),
    "hand.L": (0, 0.2, -1),
}


def clipes(rig, fontes):
    base = rig.pose({})
    p_base = rig.quadril_rest()

    def com(d):
        return rig.pose(d)

    def vivo(t, q, pos):
        ondular(rig, q, t)
        respirar(rig, q, t)
        return pos

    # flutuar (laco de 6 s: multiplo dos periodos de respiracao)
    def pairar(t, q, pos):
        vivo(t, q, pos)
        for lado, s in (("L", 1), ("R", -1)):
            A.girar(rig, q, "upper_arm." + lado,
                    A.em_torno((1, 0, 0), 7 * math.sin(t * math.tau / 3.0 + s)))
            A.girar(rig, q, "forearm." + lado,
                    A.em_torno((0, 0, 1), 6 * s * math.sin(t * math.tau / 2.0)))
            A.girar(rig, q, "fingers." + lado,
                    A.em_torno((1, 0, 0), 18 * math.sin(t * math.tau / 1.5 + s)))
        return pos
    A.sequencia(rig, "flutuar", [(0.0, base, p_base), (6.0, base, p_base)],
                laco=True, passo=2, extra=pairar)

    A.sequencia(rig, "surgir", [
        (0.0, com(ENCOLHIDA), p_base), (1.2, com(ENCOLHIDA), p_base),
        (2.2, com(ABERTA), p_base), (2.9, base, p_base)], passo=2, extra=vivo)

    A.sequencia(rig, "cuspir", [
        (0.0, base, p_base), (0.5, com(CUSPIR_ATRAS), p_base),
        (0.7, com(CUSPIR_FRENTE), p_base), (1.4, base, p_base)], passo=1, extra=vivo)

    A.sequencia(rig, "investida", [
        (0.0, base, p_base), (0.6, com(INVESTIDA), p_base),
        (1.0, com(INVESTIDA), p_base)], passo=1, extra=vivo)

    A.sequencia(rig, "tapa", [
        (0.0, base, p_base), (0.7, com(TAPA_ALTO), p_base),
        (0.85, com(TAPA_ALTO), p_base), (1.05, com(TAPA_BAIXO), p_base),
        (1.6, com(TAPA_BAIXO), p_base), (2.2, base, p_base)], passo=1, extra=vivo)

    def tranco(t, q, pos):
        vivo(t, q, pos)
        f = math.exp(-((t - 0.12) / 0.1) ** 2)
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), -12 * f))
        A.girar(rig, q, "head", A.em_torno((1, 0, 0), -20 * f))
        return pos
    A.sequencia(rig, "dano", [(0.0, base, p_base), (0.6, base, p_base)],
                passo=1, extra=tranco)

    def agonia(t, q, pos):
        ondular(rig, q, t, amplitude=14.0 * max(0.0, 1 - t / 3.0), velocidade=2.5)
        f = min(1.0, t / 0.8) * max(0.0, 1 - (t - 2.2) / 0.8)
        A.tremor(rig, q, ["spine", "chest", "neck", "head", "upper_arm.L",
                          "upper_arm.R", "hand.L", "hand.R"], 9 * f, 61, t, freq=16)
        return pos
    A.sequencia(rig, "morrer", [
        (0.0, base, p_base), (0.4, com(ABERTA), p_base),
        (1.8, com(ABERTA), p_base), (3.0, com(DESABADA), p_base)],
        passo=1, extra=agonia)
