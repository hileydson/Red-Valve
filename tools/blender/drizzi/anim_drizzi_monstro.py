# -*- coding: utf-8 -*-
"""Os clipes da Drizzi Wisny MONSTRO (a chefe do cemiterio, Capitulo 3).

Ela nao tem pernas: flutua (o Godot sobe e desce o corpo inteiro), e os
ossos de perna ficam dentro do cacho de tripas e tentaculos sem que nenhum
clipe mexa neles. O braco DIREITO e' o humano; o ESQUERDO e' a garra do
parasita, pesada, pendurada.

  flutuar       (laco de 4 s) parada no ar, a garra balancando devagar
  jogar_poeira  a mao direita entra na BOCA (cheia da terra que ela comeu),
                volta pra tras do ombro e arremessa (2,2 s). A terra sai da
                mao em LANCA_POEIRA (s) — copiado no `drizzi_monstro.gd`
  pegar_orgao   a mao desce ate' as tripas expostas embaixo da barriga, cava,
                arranca um orgao, segura ele na frente do peito (pingando) e
                arremessa (3,6 s). Na mao de PEGA_ORGAO a LANCA_ORGAO
  cair          despenca pro chao, os bracos abrindo (0,7 s) — o Godot baixa
                o corpo
  cavar         (laco de 1,2 s) caida de cara na terra, a garra cavando e a
                mao direita levando terra a' boca — o Godot afunda o corpo
  surgir        sai da terra com os bracos pra cima e assenta no ar (2,0 s)
  gritar        arqueada pra tras, os bracos abertos, tremendo (2,4 s)
  dano          o tranco de um tiro (0,5 s)
  derrotada     tomba pra frente sem forca, os bracos largados (2,0 s)

Direcoes: `anim_comum.D(esquerda, frente, cima)`; o lado direito vem escrito
com DR (lateral trocada). As direcoes sairam das cabecas dos ossos medidas no
`montar_drizzi.py` antigo (o rig deste .blend).
"""

import math

import anim_comum as A
from anim_comum import D
from mathutils import Vector

# Instantes (s) copiados no `drizzi_monstro.gd`.
LANCA_POEIRA = 1.55
PEGA_ORGAO = 1.35
LANCA_ORGAO = 3.15


def DR(fora, frente, cima):
    return D(-fora, frente, cima)


FLUTUA = {
    "spine": (0, 0.05, 1), "chest": (0, 0.08, 1), "upper_chest": (0, 0.05, 1),
    "neck": (0.05, 0.30, 1), "head": (0.0, 0.15, 1),
    "upper_arm.R": DR(0.55, 0.25, -0.80), "forearm.R": DR(0.25, 0.45, -0.85),
    "hand.R": DR(0.15, 0.40, -0.90), "fingers.R": DR(0.1, 0.4, -0.9),
    "upper_arm.L": (0.60, 0.15, -0.75), "forearm.L": (0.15, 0.35, -0.95),
    "hand.L": (0.05, 0.40, -0.90), "fingers.L": (0.05, 0.45, -0.9),
}

# a mao direita dentro da boca
NA_BOCA = dict(FLUTUA)
NA_BOCA.update({
    "neck": (0.05, 0.20, 1), "head": (0.0, -0.05, 1),
    "upper_arm.R": DR(-0.17, 0.32, -0.02), "forearm.R": DR(-0.17, -0.09, 0.30),
    "hand.R": DR(-0.2, -0.3, 0.5), "fingers.R": DR(-0.2, -0.35, 0.45),
})

# o braco armado atras do ombro
ARMANDO = dict(FLUTUA)
ARMANDO.update({
    "spine": (0, -0.08, 1), "chest": (0, -0.12, 1), "upper_chest": (0, -0.10, 1),
    "upper_arm.R": DR(0.55, -0.45, 0.65), "forearm.R": DR(0.20, -0.45, 0.85),
    "hand.R": DR(0.1, -0.5, 0.85), "fingers.R": DR(0.1, -0.5, 0.85),
})

# o arremesso: o braco reto pra frente
LANCOU = dict(FLUTUA)
LANCOU.update({
    "spine": (0, 0.25, 1), "chest": (0, 0.35, 1), "upper_chest": (0, 0.30, 1),
    "neck": (0, 0.45, 1),
    "upper_arm.R": DR(0.12, 1, 0.08), "forearm.R": DR(0.05, 1, 0.0),
    "hand.R": DR(0.0, 1, -0.12), "fingers.R": DR(0.0, 1, -0.2),
})

# curvada sobre a propria barriga, a mao cavando nas tripas de baixo
NAS_TRIPAS = dict(FLUTUA)
NAS_TRIPAS.update({
    "spine": (0, 0.45, 1), "chest": (0, 0.60, 1), "upper_chest": (0, 0.55, 1),
    "neck": (0, 0.80, 1), "head": (0, 0.75, 0.6),
    # o braco desce por fora da barriga e a mao entra por baixo dela
    "upper_arm.R": DR(0.15, 0.35, -0.95), "forearm.R": DR(-0.05, 0.55, -0.85),
    "hand.R": DR(-0.15, 0.05, -1), "fingers.R": DR(-0.2, -0.1, -1),
})

# segurando o orgao na frente do peito, olhando pra ele
SEGURANDO = dict(FLUTUA)
SEGURANDO.update({
    "neck": (0, 0.50, 1), "head": (0, 0.45, 0.9),
    "upper_arm.R": DR(0.20, 0.90, -0.25), "forearm.R": DR(-0.20, 0.80, 0.45),
    "hand.R": DR(-0.10, 0.70, 0.55), "fingers.R": DR(-0.1, 0.6, 0.6),
})

CAINDO = dict(FLUTUA)
CAINDO.update({
    "spine": (0, 0.45, 1), "chest": (0, 0.65, 0.85), "upper_chest": (0, 0.6, 0.8),
    "neck": (0, 0.8, 0.6), "head": (0, 0.6, 0.6),
    "upper_arm.R": DR(0.60, 0.60, -0.50), "forearm.R": DR(0.30, 0.70, -0.60),
    "hand.R": DR(0.2, 0.6, -0.75),
    "upper_arm.L": (0.65, 0.65, -0.40), "forearm.L": (0.25, 0.75, -0.6),
    "hand.L": (0.1, 0.7, -0.7),
})

# de cara na terra: a garra cavando, a mao direita no chao
CAVANDO_A = dict(FLUTUA)
CAVANDO_A.update({
    "spine": (0, 0.60, 1), "chest": (0, 0.90, 0.80), "upper_chest": (0, 1, 0.55),
    "neck": (0, 1, 0.25), "head": (0, 1, -0.25),
    "upper_arm.R": DR(0.25, 0.65, -0.75), "forearm.R": DR(0.05, 0.35, -1),
    "hand.R": DR(0.0, 0.5, -0.9),
    "upper_arm.L": (0.35, 0.80, -0.50), "forearm.L": (0.10, 0.55, -0.85),
    "hand.L": (0.0, 0.3, -1),
})
# ...e a mao direita levando a terra a' boca, a garra puxando pra tras
CAVANDO_B = dict(CAVANDO_A)
CAVANDO_B.update({
    "head": (0, 0.9, 0.1),
    "upper_arm.R": DR(-0.10, 0.55, -0.55), "forearm.R": DR(-0.35, 0.10, 0.60),
    "hand.R": DR(-0.3, -0.2, 0.6),
    "upper_arm.L": (0.45, 0.30, -0.85), "forearm.L": (0.15, -0.10, -1),
    "hand.L": (0.05, -0.2, -1),
})

BRACOS_PRA_CIMA = dict(FLUTUA)
BRACOS_PRA_CIMA.update({
    "spine": (0, -0.15, 1), "chest": (0, -0.25, 1), "upper_chest": (0, -0.25, 1),
    "neck": (0, -0.25, 1), "head": (0, -0.45, 1),
    "upper_arm.R": DR(0.40, 0.30, 0.85), "forearm.R": DR(0.20, 0.25, 1),
    "hand.R": DR(0.1, 0.25, 1), "fingers.R": DR(0.1, 0.3, 1),
    "upper_arm.L": (0.45, 0.30, 0.80), "forearm.L": (0.20, 0.35, 0.95),
    "hand.L": (0.10, 0.35, 0.95), "fingers.L": (0.1, 0.4, 0.9),
})

ARQUEADA = dict(FLUTUA)
ARQUEADA.update({
    "spine": (0, -0.25, 1), "chest": (0, -0.40, 1), "upper_chest": (0, -0.45, 1),
    "neck": (0, -0.35, 1), "head": (0, -0.60, 1),
    "upper_arm.R": DR(1, -0.20, 0.30), "forearm.R": DR(0.9, 0.0, 0.5),
    "hand.R": DR(0.8, 0.1, 0.55), "fingers.R": DR(0.7, 0.2, 0.6),
    "upper_arm.L": (1, -0.20, 0.20), "forearm.L": (0.8, 0.10, 0.40),
    "hand.L": (0.6, 0.3, 0.3),
})

TRANCO = dict(FLUTUA)
TRANCO.update({
    "spine": (0, -0.20, 1), "chest": (0, -0.25, 1), "neck": (0, -0.10, 1),
    "head": (0, -0.40, 1),
    "upper_arm.R": DR(0.70, 0.0, -0.6), "upper_arm.L": (0.75, 0.0, -0.6),
})

DERROTADA = dict(FLUTUA)
DERROTADA.update({
    "spine": (0, 0.90, 0.60), "chest": (0, 1, 0.30), "upper_chest": (0, 1, 0.10),
    "neck": (0.10, 1, -0.20), "head": (0.15, 0.80, -0.60),
    "upper_arm.R": DR(0.30, 0.30, -1), "forearm.R": DR(0.10, 0.30, -1),
    "hand.R": DR(0.05, 0.4, -0.9),
    "upper_arm.L": (0.40, 0.40, -0.90), "forearm.L": (0.10, 0.50, -0.85),
    "hand.L": (0.0, 0.6, -0.8),
})


def clipes(rig):
    p0 = rig.quadril_rest()
    q_f = rig.pose(FLUTUA)

    def balanca(t, q, pos):
        w = math.tau / 4.0
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 2.5 * math.sin(t * w)))
        A.girar(rig, q, "upper_arm.L", A.em_torno((0, 1, 0), 5.0 * math.sin(t * w + 1.0)))
        A.girar(rig, q, "forearm.L", A.em_torno((1, 0, 0), -6.0 * math.sin(t * w * 2 + 0.3)))
        A.girar(rig, q, "upper_arm.R", A.em_torno((1, 0, 0), -4.0 * math.sin(t * w + 2.0)))
        A.girar(rig, q, "head", A.em_torno((0, 0, 1), 6.0 * math.sin(t * w + 0.5)))
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 3.0 * math.sin(t * w * 2)))
        return pos + Vector((0.0, 0.0, 0.02 * math.sin(t * w)))
    A.sequencia(rig, "flutuar", [(0.0, q_f, p0), (4.0, q_f, p0)],
                laco=True, passo=2, extra=balanca)

    q_boca = rig.pose(NA_BOCA)
    q_arm = rig.pose(ARMANDO)
    q_lan = rig.pose(LANCOU)

    def remexe_boca(t, q, pos):
        # a mao cavucando dentro da boca
        if 0.55 < t < 1.1:
            A.tremor(rig, q, ["hand.R", "forearm.R", "head"], 5.0, 61, t, freq=16)
        return pos
    A.sequencia(rig, "jogar_poeira", [
        (0.0, q_f, p0), (0.55, q_boca, p0), (1.05, q_boca, p0),
        (1.35, q_arm, p0), (LANCA_POEIRA, q_lan, p0), (1.75, q_lan, p0),
        (2.2, q_f, p0)], passo=1, extra=remexe_boca)

    q_tri = rig.pose(NAS_TRIPAS)
    q_seg = rig.pose(SEGURANDO)

    def arranca(t, q, pos):
        if 0.7 < t < PEGA_ORGAO:
            A.tremor(rig, q, ["hand.R", "forearm.R", "spine"], 6.0, 67, t, freq=17)
        elif PEGA_ORGAO < t < 2.85:
            # o orgao tremendo na mao, o braco pesado
            A.tremor(rig, q, ["hand.R", "head"], 3.0, 71, t, freq=11)
        return pos
    A.sequencia(rig, "pegar_orgao", [
        (0.0, q_f, p0), (0.7, q_tri, p0 - Vector((0, 0, 0.04))),
        (PEGA_ORGAO, q_tri, p0 - Vector((0, 0, 0.04))), (1.75, q_seg, p0),
        (2.6, q_seg, p0), (2.95, q_arm, p0), (LANCA_ORGAO, q_lan, p0),
        (3.35, q_lan, p0), (3.6, q_f, p0)], passo=1, extra=arranca)

    q_cai = rig.pose(CAINDO)
    A.sequencia(rig, "cair", [(0.0, q_f, p0), (0.35, q_cai, p0), (0.7, q_cai, p0)], passo=1)

    q_ca = rig.pose(CAVANDO_A)
    q_cb = rig.pose(CAVANDO_B)

    def mastiga(t, q, pos):
        A.tremor(rig, q, ["chest", "neck", "head"], 4.0, 73, t, freq=15)
        return pos
    A.sequencia(rig, "cavar", [(0.0, q_ca, p0), (0.6, q_cb, p0), (1.2, q_ca, p0)],
                laco=True, passo=1, extra=mastiga)

    q_cima = rig.pose(BRACOS_PRA_CIMA)
    A.sequencia(rig, "surgir", [
        (0.0, q_ca, p0), (0.6, q_cima, p0), (1.3, q_cima, p0), (2.0, q_f, p0)], passo=1)

    q_arq = rig.pose(ARQUEADA)

    def treme(t, q, pos):
        f = min(1.0, t / 0.5)
        A.tremor(rig, q, ["chest", "neck", "head", "hand.L", "hand.R"], 4.0 * f, 79, t, freq=16)
        return pos
    A.sequencia(rig, "gritar", [
        (0.0, q_f, p0), (0.5, q_arq, p0), (1.9, q_arq, p0), (2.4, q_f, p0)],
        passo=1, extra=treme)

    q_tr = rig.pose(TRANCO)
    A.sequencia(rig, "dano", [(0.0, q_f, p0), (0.12, q_tr, p0), (0.5, q_f, p0)], passo=1)

    q_der = rig.pose(DERROTADA)
    meio = A.mistura(q_arq, q_der, 0.4)

    def estrebucha(t, q, pos):
        f = max(0.0, 1.0 - t / 1.6)
        A.tremor(rig, q, ["spine", "chest", "neck", "head", "hand.L", "hand.R"], 7.0 * f, 83, t, freq=14)
        return pos
    A.sequencia(rig, "derrotada", [
        (0.0, q_f, p0), (0.4, q_arq, p0), (1.0, meio, p0), (1.6, q_der, p0),
        (2.0, q_der, p0)], passo=1, extra=estrebucha)
