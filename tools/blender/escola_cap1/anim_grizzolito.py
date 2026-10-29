# -*- coding: utf-8 -*-
"""Clipes do Grizzolito (as tres formas usam a mesma lista).

  parado       guarda de briga, respirando (laco) — captura Idle_11
  andar        laco — captura Walking
  correr       laco — captura Running
  soco         jab de esquerda + direto de direita (0,85 s). Os golpes
               acertam em SOCO_ACERTOS (s) — o Godot le' de la'
  chute        chute frontal: o joelho sobe, a perna estica e volta (0,95 s).
               Acerta em CHUTE_ACERTO (s)
  voadora      agacha, salta com a perna direita esticada e cai (1,35 s).
               O deslocamento pra frente e' do no' no Godot; aqui so' sobe
  dano         o tranco de um golpe — comeco do Mummy_Stagger
  morrer       cai de joelhos e tomba de cara no chao (2,3 s) — as poses do
               monstro da igreja (`anim_monstro.py`)
  transformar  as maos na cabeca, o corpo se contorcendo — Headache_Relief
  rugido       pisao no chao, gritando — Angry_Ground_Stomp_2

Mesma convencao da igreja: D(esquerda, frente, cima) no espaco do personagem,
e chave ".L" espelhada sozinha pro ".R".
"""

import anim_comum as A
import anim_monstro as AM
from anim_comum import D

# Instantes em que o soco e o chute acertam (s). Copiados no `grizzolito.gd`.
SOCO_ACERTOS = (0.16, 0.50)
CHUTE_ACERTO = 0.42


def DR(fora, frente, cima):
    return D(-fora, frente, cima)


GUARDA = {
    "spine": (0, 0.15, 1), "chest": (0, 0.12, 1), "upper_chest": (0, 0.08, 1),
    "neck": (0, 0.20, 1), "head": (0, 0.10, 1),
    "upper_arm.L": (0.35, 0.35, -0.85), "forearm.L": (-0.15, 0.60, 0.75),
    "hand.L": (-0.10, 0.40, 0.90), "fingers.L": (-0.2, 0.6, 0.4),
    "thigh.L": (0.12, 0.15, -1), "shin.L": (0.02, -0.10, -1),
    "foot.L": (0.1, 1, -0.55), "toe.L": (0.1, 1, 0),
    "thigh.R": DR(0.12, -0.15, -1), "shin.R": DR(0.02, -0.25, -1),
    "foot.R": DR(0.1, 1, -0.55), "toe.R": DR(0.1, 1, 0),
}

JAB = dict(GUARDA)
JAB.update({
    "upper_arm.L": (0.05, 1, 0.05), "forearm.L": (0.0, 1, 0.05),
    "hand.L": (0.0, 1, 0.0), "fingers.L": (0.0, 1, -0.1),
    "chest": (0.05, 0.2, 1),
})

DIRETO = dict(GUARDA)
DIRETO.update({
    "upper_arm.R": DR(0.0, 1, 0.05), "forearm.R": DR(0.0, 1, 0.05),
    "hand.R": DR(0.0, 1, 0.0), "fingers.R": DR(0.0, 1, -0.1),
    "chest": (-0.05, 0.25, 1), "spine": (0, 0.25, 1),
    "thigh.R": DR(0.12, -0.35, -1),
})

CAMARA = dict(GUARDA)
CAMARA.update({
    "spine": (0, -0.05, 1), "chest": (0, 0.0, 1),
    "thigh.R": DR(0.05, 1, 0.1), "shin.R": DR(0.0, -0.3, -1),
    "foot.R": DR(0.0, 1, -0.3), "toe.R": DR(0.0, 1, 0.0),
    "thigh.L": (0.08, -0.05, -1), "shin.L": (0.0, -0.12, -1),
})

ESTICADO = dict(CAMARA)
ESTICADO.update({
    "spine": (0, -0.25, 1), "chest": (0, -0.2, 1), "upper_chest": (0, -0.1, 1),
    "thigh.R": DR(0.05, 1, 0.25), "shin.R": DR(0.0, 1, 0.2),
    "foot.R": DR(0.0, 0.4, 1), "toe.R": DR(0.0, 0.2, 1),
})

AGACHADO = dict(GUARDA)
AGACHADO.update({
    "spine": (0, 0.45, 1), "chest": (0, 0.35, 1),
    "thigh.L": (0.12, 0.75, -0.65), "shin.L": (0.02, -0.55, -0.85),
    "thigh.R": DR(0.12, 0.55, -0.80), "shin.R": DR(0.02, -0.65, -0.75),
    "upper_arm.L": (0.3, -0.5, -0.8), "upper_arm.R": DR(0.3, -0.5, -0.8),
    "forearm.L": (0.1, -0.2, -1), "forearm.R": DR(0.1, -0.2, -1),
})

NO_AR = {
    "spine": (0, -0.30, 1), "chest": (0, -0.25, 1), "upper_chest": (0, -0.15, 1),
    "neck": (0, 0.35, 1), "head": (0, 0.30, 1),
    # a perna direita e' a lanca: reta pra frente
    "thigh.R": DR(0.05, 1, 0.12), "shin.R": DR(0.0, 1, 0.08),
    "foot.R": DR(0.0, 0.3, 1), "toe.R": DR(0.0, 0.2, 1),
    # a esquerda encolhida embaixo do corpo
    "thigh.L": (0.10, 0.70, -0.35), "shin.L": (0.02, -0.80, -0.55),
    "foot.L": (0.05, 0.6, -0.8), "toe.L": (0.05, 1, 0),
    # bracos abertos pra tras, equilibrando
    "upper_arm.L": (0.8, -0.4, 0.2), "forearm.L": (0.7, -0.3, 0.5),
    "upper_arm.R": DR(0.8, -0.4, 0.2), "forearm.R": DR(0.7, -0.3, 0.5),
}

TODOS_APOIOS = ("toe.L", "toe.R", "foot.L", "foot.R")


def _acao(acoes, nome):
    if nome in acoes:
        return acoes[nome]
    for k, a in acoes.items():
        if k.split(".")[0] == nome:
            return a
    raise KeyError(nome)


def clipes(rig, fontes, lento=1.0):
    """`lento` < 1 deixa os monstros mais pesados (so' andar/parado/rugido)."""
    ml, a_ml = fontes["maycow_lopes"]
    zb, a_zb = fontes["zombie"]

    A.retarget(rig, ml, _acao(a_ml, "Idle_11"), "parado", laco=True, velocidade=lento)
    A.retarget(rig, ml, _acao(a_ml, "Walking"), "andar", laco=True, velocidade=lento)
    A.retarget(rig, ml, _acao(a_ml, "Running"), "correr", laco=True)
    A.retarget(rig, ml, _acao(a_ml, "Headache_Relief"), "transformar")
    A.retarget(rig, ml, _acao(a_ml, "Angry_Ground_Stomp_2"), "rugido", velocidade=lento)
    A.retarget(rig, zb, _acao(a_zb, "Mummy_Stagger"), "dano", ini=0, fim=26)

    q_g = rig.pose(GUARDA)
    p_g = rig.assentar(q_g, apoios=TODOS_APOIOS)
    q_j = rig.pose(JAB)
    p_j = rig.assentar(q_j, apoios=TODOS_APOIOS)
    q_d = rig.pose(DIRETO)
    p_d = rig.assentar(q_d, apoios=TODOS_APOIOS)

    def gira_tronco(t, q, pos):
        # o tronco acompanha cada golpe: jab gira pra direita, direto pra
        # esquerda (rz positivo = vira pra ESQUERDA dele)
        if t < 0.30:
            g = -18.0 * max(0.0, 1.0 - abs(t - SOCO_ACERTOS[0]) / 0.16)
        else:
            g = 28.0 * max(0.0, 1.0 - abs(t - SOCO_ACERTOS[1]) / 0.20)
        A.girar(rig, q, "spine", A.rz(g * 0.5))
        A.girar(rig, q, "upper_chest", A.rz(g * 0.5))
        return pos
    A.sequencia(rig, "soco", [
        (0.0, q_g, p_g), (SOCO_ACERTOS[0], q_j, p_j), (0.32, q_g, p_g),
        (SOCO_ACERTOS[1], q_d, p_d), (0.85, q_g, p_g)], passo=1, extra=gira_tronco)

    # o chute: a perna de apoio fica no chao (assentar so' por ela)
    apoio = ("toe.L", "foot.L")
    q_c = rig.pose(CAMARA)
    p_c = rig.assentar(q_c, apoios=apoio)
    q_e = rig.pose(ESTICADO)
    p_e = rig.assentar(q_e, apoios=apoio)
    A.sequencia(rig, "chute", [
        (0.0, q_g, p_g), (0.22, q_c, p_c), (CHUTE_ACERTO, q_e, p_e),
        (0.62, q_c, p_c), (0.95, q_g, p_g)], passo=1)

    # a morte: de joelhos e de cara no chao (as poses da monstro da igreja)
    q_joe = rig.pose(AM.JOELHOS)
    p_joe = rig.assentar(q_joe, apoios=AM.DN.APOIO_JOELHO, folga=0.07)
    q_morta = rig.pose(AM.MORTA)
    p_morta = rig.assentar(q_morta, xy=(0.0, -0.75), apoios=AM.DEITADO, folga=0.11)
    meio = A.mistura(q_joe, q_morta, 0.45)
    p_meio = rig.assentar(meio, xy=(0.0, -0.35), apoios=AM.DEITADO, folga=0.25)
    A.sequencia(rig, "morrer", [
        (0.0, q_g, p_g), (0.75, q_joe, p_joe), (1.45, meio, p_meio),
        (1.9, q_morta, p_morta), (2.1, q_morta, p_morta + A.Vector((0, 0, 0.04))),
        (2.3, q_morta, p_morta)], passo=1)

    q_a = rig.pose(AGACHADO)
    p_a = rig.assentar(q_a, apoios=TODOS_APOIOS, folga=0.04)
    q_ar = rig.pose(NO_AR)
    p_ar = rig.assentar(q_ar, apoios=("foot.L", "toe.L"), folga=0.75)
    p_ar_alto = p_ar + A.Vector((0, 0, 0.25))
    A.sequencia(rig, "voadora", [
        (0.0, q_g, p_g), (0.25, q_a, p_a), (0.45, q_ar, p_ar_alto),
        (0.80, q_ar, p_ar), (1.0, q_a, p_a), (1.35, q_g, p_g)], passo=1)
