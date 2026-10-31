# -*- coding: utf-8 -*-
"""Os clipes da Drizzi Wisny HUMANA.

  conversando   (laco de 6 s) a fala do hospital, de costas pra camera
  parada        (laco de 4 s) de pe', respirando — de costas na porta da
                capela do cemiterio, antes de notar o Maycow
  andar         (laco) indo atras do Maycow enquanto acusa — captura Walking
  acusando      (laco) de pe', falando com raiva, o braco direito apontando
                e abrindo — captura Talk_Passionately
  pegar_areia   curva pro chao e pega um punhado de terra (2,2 s)
  comer         de pe', a mao direita vai a' boca e ela mastiga (2,4 s)
  ajoelhar      cai de joelhos (1,0 s), sentada nos calcanhares
  comendo_terra (laco de 1,2 s) de joelhos, curvada sobre o chao, as maos
                alternando do chao pra boca
  gritando      (laco de 2 s) de joelhos, arqueada pra tras, os bracos
                abertos, tremendo
  caida         (laco de 4 s) deitada de costas, fraca, respirando — o fim
                da luta do cemiterio, nos bracos do Maycow

O `conversando` (hospital) e' de costas pra camera: o que tem de ler e' o
braco direito explicando, os ombros e a cabeca.

Tudo e' giro de MUNDO sobre o repouso do scan (o braco em A): eixo X = da
direita pra esquerda dela, Y = da frente (-) pra tras (+), Z = pra cima.
Giro negativo em X leva braco e cabeca pra FRENTE. As poses escritas a mao
usam `anim_comum.D(esquerda, frente, cima)`, e a chave ".L" e' espelhada
sozinha pro ".R".
"""

import math

import anim_comum as A
from anim_comum import D
from mathutils import Vector

DURACAO = 6.0
W = math.tau / DURACAO


def _s(t, voltas, fase=0.0):
    return math.sin(t * W * voltas + fase)


def DR(fora, frente, cima):
    return D(-fora, frente, cima)


EM_PE = {
    "spine": (0, 0.04, 1), "chest": (0, 0.06, 1), "upper_chest": (0, 0.05, 1),
    "neck": (0, 0.20, 1), "head": (0, 0.08, 1),
    "upper_arm.L": (0.20, 0.02, -1), "forearm.L": (0.06, 0.22, -1),
    "hand.L": (0.03, 0.20, -1), "fingers.L": (0.0, 0.3, -1),
    "thigh.L": (0.04, 0.02, -1), "shin.L": (0, -0.04, -1),
    "foot.L": (0, 1, -0.45), "toe.L": (0, 1, -0.05),
}

# sentada nos calcanhares, peito do pe' no chao (a mesma perna da Dona Nice
# ajoelhada no altar), o tronco caido pra frente sobre a terra
AJOELHADA = {
    "spine": (0, 0.50, 1), "chest": (0, 0.75, 1), "upper_chest": (0, 0.85, 1),
    "neck": (0, 1.0, 0.55), "head": (0, 1.0, 0.25),
    "upper_arm.L": (0.25, 0.65, -0.75), "forearm.L": (0.05, 0.55, -0.85),
    "hand.L": (0.0, 0.6, -0.8), "fingers.L": (0, 0.4, -1),
    "thigh.L": (0.12, 0.55, -0.83), "shin.L": (0.02, -1, -0.04),
    "foot.L": (0, -1, -0.12), "toe.L": (0, -1, 0.0),
}

# curvada pro chao, os joelhos dobrados, a mao direita na terra
CURVADA = dict(EM_PE)
CURVADA.update({
    "spine": (0, 1, 0.50), "chest": (0, 1, 0.30), "upper_chest": (0, 1, 0.15),
    "neck": (0, 1, 0.05), "head": (0, 0.8, -0.2),
    "upper_arm.R": DR(0.10, 0.20, -1), "forearm.R": DR(0.0, 0.15, -1),
    "hand.R": DR(0.0, 0.25, -1), "fingers.R": DR(0.0, 0.3, -1),
    "upper_arm.L": (0.15, 0.20, -1), "forearm.L": (0.05, 0.30, -1),
    "thigh.L": (0.05, 0.75, -0.80), "shin.L": (0, -0.45, -1),
})
# de pe', o punho de terra subindo na frente do peito
PUNHO = dict(EM_PE)
PUNHO.update({
    "spine": (0, 0.15, 1), "chest": (0, 0.20, 1), "neck": (0, 0.45, 1), "head": (0, 0.40, 1),
    "upper_arm.R": DR(0.10, 0.55, -0.80), "forearm.R": DR(-0.30, 0.85, 0.30),
    "hand.R": DR(-0.20, 0.80, 0.30), "fingers.R": DR(-0.3, 0.3, -0.5),
})
# de pe', a mao direita na boca
NA_BOCA = dict(EM_PE)
NA_BOCA.update({
    "neck": (0, 0.35, 1), "head": (0, 0.25, 1),
    "upper_arm.R": DR(0.10, 0.45, -0.85), "forearm.R": DR(-0.55, 0.45, 0.75),
    "hand.R": DR(-0.50, 0.20, 0.85), "fingers.R": DR(-0.5, 0.0, 0.85),
})

# a mao direita na boca, a esquerda cavando
COMENDO_D = dict(AJOELHADA)
COMENDO_D.update({
    "upper_arm.R": DR(0.10, 0.35, -0.95), "forearm.R": DR(-0.50, 0.60, 0.65),
    "hand.R": DR(-0.55, 0.45, 0.70), "fingers.R": DR(-0.6, 0.3, 0.7),
    "upper_arm.L": (0.20, 0.85, -0.55), "forearm.L": (0.05, 0.45, -0.9),
    "hand.L": (0.0, 0.5, -0.85),
    "head": (0, 0.9, 0.45),
})
COMENDO_E = dict(AJOELHADA)
COMENDO_E.update({
    "upper_arm.L": (0.10, 0.35, -0.95), "forearm.L": (-0.50, 0.60, 0.65),
    "hand.L": (-0.55, 0.45, 0.70), "fingers.L": (-0.6, 0.3, 0.7),
    "upper_arm.R": DR(0.20, 0.85, -0.55), "forearm.R": DR(0.05, 0.45, -0.9),
    "hand.R": DR(0.0, 0.5, -0.85),
    "head": (0, 0.9, 0.45),
})

GRITANDO = dict(AJOELHADA)
GRITANDO.update({
    "spine": (0, -0.15, 1), "chest": (0, -0.30, 1), "upper_chest": (0, -0.40, 1),
    "neck": (0, -0.45, 1), "head": (0, -0.80, 0.6),
    "upper_arm.L": (0.85, 0.15, 0.45), "forearm.L": (0.55, 0.25, 0.80),
    "hand.L": (0.45, 0.25, 0.85), "fingers.L": (0.4, 0.3, 0.85),
})

# deitada de costas: a cabeca fica pra TRAS do quadril (o "frente" do corpo
# de pe' vira o alto), as pernas pra frente com os joelhos um pouco erguidos
CAIDA = {
    "hips": (0, -1, 0.04),
    "spine": (0, -1, 0.06), "chest": (0, -1, 0.14), "upper_chest": (0, -1, 0.22),
    "neck": (0.05, -1, 0.45), "head": (0.12, -0.85, 0.55),
    "upper_arm.L": (0.40, 1, -0.30), "forearm.L": (0.25, 1, -0.05),
    "hand.L": (0.15, 1, -0.25), "fingers.L": (0.1, 1, -0.3),
    "upper_arm.R": DR(0.55, 0.6, -0.55), "forearm.R": DR(0.45, 0.8, 0.05),
    "hand.R": DR(0.3, 1, -0.2), "fingers.R": DR(0.2, 1, -0.3),
    "thigh.L": (0.06, 1, 0.30), "shin.L": (0.03, 1, -0.30),
    "foot.L": (0, 0.35, 1), "toe.L": (0, 0.1, 1),
}
DEITADA = ("hips", "spine", "chest", "upper_chest", "neck", "head",
           "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R",
           "hand.R", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R",
           "foot.R")
APOIO_JOELHO = ("shin.L", "shin.R", "foot.L", "foot.R", "toe.L", "toe.R")


def _acao(acoes, nome):
    if nome in acoes:
        return acoes[nome]
    for k, a in acoes.items():
        if k.split(".")[0] == nome:
            return a
    raise KeyError(nome)


def clipes(rig, fontes):
    _conversando(rig)

    ml, a_ml = fontes["maycow_lopes"]

    q_pe = rig.pose(EM_PE)
    p_pe = rig.assentar(q_pe)

    def respira(t, q, pos):
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 1.6 * math.sin(t * math.tau / 4.0)))
        A.girar(rig, q, "head", A.em_torno((0, 0, 1), 3.0 * math.sin(t * math.tau / 4.0 + 0.6)))
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 1.5 * math.sin(t * math.tau / 2.0)))
        return pos
    A.sequencia(rig, "parada", [(0.0, q_pe, p_pe), (4.0, q_pe, p_pe)],
                laco=True, passo=2, extra=respira)

    A.retarget(rig, ml, _acao(a_ml, "Walking"), "andar", laco=True, velocidade=0.85)
    A.retarget(rig, ml, _acao(a_ml, "Talk_Passionately"), "acusando", laco=True)
    q_cur = rig.pose(CURVADA)
    p_cur = rig.assentar(q_cur)
    q_pun = rig.pose(PUNHO)
    p_pun = rig.assentar(q_pun)

    def agarra(t, q, pos):
        if 0.8 < t < 1.3:
            A.tremor(rig, q, ["hand.R", "fingers.R"], 6.0, 11, t, freq=16)
        return pos
    A.sequencia(rig, "pegar_areia", [
        (0.0, q_pe, p_pe), (0.8, q_cur, p_cur), (1.3, q_cur, p_cur),
        (2.2, q_pun, p_pun)], passo=1, extra=agarra)

    q_boca = rig.pose(NA_BOCA)
    p_boca = rig.assentar(q_boca)

    def engole(t, q, pos):
        if 0.7 < t < 1.8:
            f = (t * 3.0) % 1.0
            A.girar(rig, q, "neck", A.em_torno((1, 0, 0), -10 * math.exp(-((f - 0.3) / 0.12) ** 2)))
            A.tremor(rig, q, ["hand.R", "head"], 2.5, 13, t, freq=12)
        return pos
    A.sequencia(rig, "comer", [
        (0.0, q_pun, p_pun), (0.7, q_boca, p_boca), (1.8, q_boca, p_boca),
        (2.4, q_pun, p_pun)], passo=1, extra=engole)

    q_ajo = rig.pose(AJOELHADA)
    p_ajo = rig.assentar(q_ajo, apoios=APOIO_JOELHO, folga=0.06)
    meio = A.mistura(q_pe, q_ajo, 0.5)
    p_meio = rig.assentar(meio)
    A.sequencia(rig, "ajoelhar", [
        (0.0, q_pe, p_pe), (0.45, meio, p_meio), (0.85, q_ajo, p_ajo - Vector((0, 0, 0.03))),
        (1.0, q_ajo, p_ajo)], passo=1)

    q_cd = rig.pose(COMENDO_D)
    p_cd = rig.assentar(q_cd, apoios=APOIO_JOELHO, folga=0.06)
    q_ce = rig.pose(COMENDO_E)
    p_ce = rig.assentar(q_ce, apoios=APOIO_JOELHO, folga=0.06)

    def mastiga(t, q, pos):
        # a cabeca da' trancos de quem engole a forca, o corpo treme
        f = (t * 2.5) % 1.0
        tranco = math.exp(-((f - 0.3) / 0.1) ** 2)
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), -14 * tranco))
        A.girar(rig, q, "head", A.em_torno((0, 0, 1), 8 * math.sin(t * 7.0)))
        A.tremor(rig, q, ["chest", "hand.L", "hand.R"], 3.0, 17, t, freq=14)
        return pos
    A.sequencia(rig, "comendo_terra", [
        (0.0, q_cd, p_cd), (0.6, q_ce, p_ce), (1.2, q_cd, p_cd)],
        laco=True, passo=1, extra=mastiga)

    q_gr = rig.pose(GRITANDO)
    p_gr = rig.assentar(q_gr, apoios=APOIO_JOELHO, folga=0.06)

    def treme(t, q, pos):
        A.tremor(rig, q, ["spine", "chest", "neck", "head"], 4.0, 23, t, freq=15)
        A.tremor(rig, q, ["upper_arm.L", "upper_arm.R", "hand.L", "hand.R"], 6.0, 29, t, freq=18)
        return pos
    A.sequencia(rig, "gritando", [(0.0, q_gr, p_gr), (2.0, q_gr, p_gr)],
                laco=True, passo=1, extra=treme)

    q_ca = rig.pose(CAIDA)
    p_ca = rig.assentar(q_ca, apoios=DEITADA, folga=0.08)

    def fraca(t, q, pos):
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 2.0 * math.sin(t * math.tau / 2.0)))
        A.girar(rig, q, "head", A.em_torno((0, 1, 0), 4.0 * math.sin(t * math.tau / 4.0 + 0.4)))
        return pos
    A.sequencia(rig, "caida", [(0.0, q_ca, p_ca), (4.0, q_ca, p_ca)],
                laco=True, passo=2, extra=fraca)


def _conversando(rig):
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
