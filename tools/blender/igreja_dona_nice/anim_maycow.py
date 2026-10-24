# -*- coding: utf-8 -*-
"""Clipes do Maycow normal na cena da igreja e na corrida pro hospital.

  andar_lento          entra na igreja devagar (o Walking dele a 55%) (laco)
  esticar_mao          para e estica a mao direita pra frente, olhando fixo
  mao_esticada         segura o gesto, tremendo (laco)
  sacar_arma           a mao vai ao quadril e sobe com a pistola; a esquerda
                       encontra a direita na frente — mira de duas maos
  mirando              segurando a mira, respirando (laco)
  pegar_jonny          ajoelha, passa os bracos por baixo dele e levanta
  parado_carregando    em pe' com o Jonny no colo (laco)
  andar_carregando     andando com ele (laco)
  correr_carregando    correndo com ele (laco)
  largar_jonny         o contrario do pegar: ajoelha e pousa ele no chao

Esqueleto Meshy (Hips, Spine02, LeftArm...), em centimetros. `PAPEIS` traduz
os nomes de papel usados nas poses (os mesmos dos outros personagens).

Os bracos de "carregando" sao uma pose PRESA AO PEITO: a cada quadro da
captura (andar/correr) o braco e' reescrito na pose do colo, girado junto com
o peito daquele quadro. As pernas e o tronco continuam sendo captura.
"""

import math

import anim_comum as A
import retarget_lib as RT
from anim_comum import D

PAPEIS = {
    "hips": "Hips", "spine": "Spine02", "chest": "Spine01",
    "upper_chest": "Spine", "neck": "neck", "head": "Head",
}
for _l, _m in (("L", "Left"), ("R", "Right")):
    PAPEIS.update({
        "shoulder." + _l: _m + "Shoulder", "upper_arm." + _l: _m + "Arm",
        "forearm." + _l: _m + "ForeArm", "hand." + _l: _m + "Hand",
        "thigh." + _l: _m + "UpLeg", "shin." + _l: _m + "Leg",
        "foot." + _l: _m + "Foot", "toe." + _l: _m + "ToeBase",
    })

BRACOS = ["shoulder.L", "upper_arm.L", "forearm.L", "hand.L",
          "shoulder.R", "upper_arm.R", "forearm.R", "hand.R"]


def DR(fora, frente, cima):
    return D(-fora, frente, cima)


def rig(arm, fontes):
    return A.Rig(arm, fontes["maycow_lopes"][0], mapa=RT.MAPA_MESHY, nomes=PAPEIS)


EM_PE = {
    "spine": (0, 0.03, 1), "chest": (0, 0.02, 1), "upper_chest": (0, 0.0, 1),
    "neck": (0, 0.12, 1), "head": (0, 0.05, 1),
    "upper_arm.L": (0.18, 0.02, -1), "forearm.L": (0.06, 0.18, -1),
    "hand.L": (0.03, 0.15, -1),
    "thigh.L": (0.06, 0.0, -1), "shin.L": (0, -0.03, -1),
    "foot.L": (0.05, 1, -0.55), "toe.L": (0.05, 1, -0.05),
}

MAO_ESTICADA = dict(EM_PE)
MAO_ESTICADA.update({
    "chest": (0, 0.06, 1), "neck": (0, 0.2, 1), "head": (0, 0.1, 1),
    "upper_arm.R": DR(0.05, 1, 0.12), "forearm.R": DR(-0.02, 1, 0.12),
    "hand.R": DR(0.0, 1, 0.25),
})

MAO_NO_QUADRIL = dict(EM_PE)
MAO_NO_QUADRIL.update({
    "upper_arm.R": DR(0.3, -0.25, -1), "forearm.R": DR(0.05, 0.6, -0.8),
    "hand.R": DR(0.0, 0.4, -0.9),
})

MIRANDO = dict(EM_PE)
MIRANDO.update({
    "spine": (0, 0.06, 1), "chest": (0, 0.05, 1), "upper_chest": (0, 0.03, 1),
    "neck": (0, 0.3, 1), "head": (0, 0.2, 1),
    "upper_arm.R": DR(-0.22, 0.97, 0.05), "forearm.R": DR(-0.12, 1, 0.07),
    "hand.R": DR(-0.05, 1, 0.05),
    "upper_arm.L": (-0.35, 0.92, -0.05), "forearm.L": (-0.55, 0.82, 0.06),
    "hand.L": (-0.4, 0.9, 0.05),
    "thigh.L": (0.08, 0.05, -1), "thigh.R": DR(0.08, -0.05, -1),
})

# os bracos do colo: antebracos quase horizontais, na altura da barriga
COLO = {
    "upper_arm.L": (0.18, 0.5, -0.82), "forearm.L": (-0.35, 0.92, 0.12),
    "hand.L": (-0.55, 0.8, 0.05),
    "spine": (0, -0.06, 1), "chest": (0, -0.08, 1), "upper_chest": (0, -0.04, 1),
    "neck": (0, 0.25, 1), "head": (0, 0.35, 1),
}

AJOELHADO = {
    "spine": (0, 0.45, 1), "chest": (0, 0.55, 1), "upper_chest": (0, 0.5, 1),
    "neck": (0, 0.8, 1), "head": (0, 0.9, 1),
    "upper_arm.L": (0.18, 0.75, -0.7), "forearm.L": (-0.15, 0.85, -0.5),
    "hand.L": (-0.25, 0.8, -0.5),
    # joelho direito no chao, esquerdo em cima
    "thigh.L": (0.1, 1, -0.2), "shin.L": (0, -0.1, -1),
    "foot.L": (0.05, 1, -0.5), "toe.L": (0.05, 1, 0),
    "thigh.R": DR(0.06, -0.05, -1), "shin.R": DR(0, -1, -0.04),
    "foot.R": DR(0, -1, -0.12), "toe.R": DR(0, -1, 0.0),
}
AJOELHADO_COLO = dict(AJOELHADO)
AJOELHADO_COLO.update({
    "spine": (0, 0.25, 1), "chest": (0, 0.2, 1), "upper_chest": (0, 0.15, 1),
    "upper_arm.L": (0.18, 0.55, -0.8), "forearm.L": (-0.35, 0.9, 0.05),
    "hand.L": (-0.55, 0.8, 0.0),
})

APOIO = ("shin.L", "shin.R", "foot.L", "foot.R", "toe.L", "toe.R")


def _bracos_presos(rig, q_colo):
    """Pose do colo relativa ao peito (Spine), pra colar por cima da captura."""
    peito = rig.n("upper_chest")
    rel = {}
    for papel in BRACOS:
        n = rig.n(papel)
        rel[n] = q_colo[peito].inverted() @ q_colo[n]
    return peito, rel


def clipes(rig, fontes):
    fonte, acoes = fontes["maycow_lopes"]
    alvo = rig.alvo

    q_pe = rig.pose(EM_PE)
    p_pe = rig.assentar(q_pe)
    q_mao = rig.pose(MAO_ESTICADA)
    q_qua = rig.pose(MAO_NO_QUADRIL)
    q_mir = rig.pose(MIRANDO)
    p_mir = rig.assentar(q_mir)

    # --- andar lento: o Walking dele, mais devagar
    A.retarget(rig, fonte, acoes["Walking"], "andar_lento", laco=True, velocidade=0.55)

    def respira(t, q, pos):
        A.girar(rig, q, "chest", A.em_torno((1, 0, 0), 1.5 * math.sin(t * math.tau / 3.4)))
        return pos

    def treme_mao(t, q, pos):
        respira(t, q, pos)
        A.tremor(rig, q, ["hand.R", "forearm.R"], 1.6, 5, t, freq=8.0)
        return pos

    A.sequencia(rig, "esticar_mao", [
        (0.0, q_pe, p_pe), (0.5, q_pe, p_pe), (2.0, q_mao, p_pe), (2.6, q_mao, p_pe)],
        passo=2, extra=treme_mao)
    A.sequencia(rig, "mao_esticada", [(0.0, q_mao, p_pe), (3.4, q_mao, p_pe)],
                laco=True, passo=3, extra=treme_mao)

    A.sequencia(rig, "sacar_arma", [
        (0.0, q_mao, p_pe), (0.45, q_qua, p_pe), (0.6, q_qua, p_pe),
        (1.25, q_mir, p_mir), (1.5, q_mir, p_mir)], passo=1, extra=respira)

    def mira_viva(t, q, pos):
        respira(t, q, pos)
        A.girar(rig, q, "upper_chest", A.em_torno((0, 0, 1), 0.8 * math.sin(t * 1.3)))
        A.tremor(rig, q, ["hand.R", "hand.L"], 0.6, 9, t, freq=6.0)
        return pos
    A.sequencia(rig, "mirando", [(0.0, q_mir, p_mir), (3.4, q_mir, p_mir)],
                laco=True, passo=3, extra=mira_viva)

    # --- carregar o Jonny ---------------------------------------------------
    colo_d = dict(EM_PE)
    colo_d.update(COLO)
    q_colo = rig.pose(colo_d)
    p_colo = rig.assentar(q_colo)
    q_ajo = rig.pose(AJOELHADO)
    p_ajo = rig.assentar(q_ajo, apoios=APOIO, folga=0.06)
    q_ajc = rig.pose(AJOELHADO_COLO)
    p_ajc = rig.assentar(q_ajc, apoios=APOIO, folga=0.06)

    A.sequencia(rig, "pegar_jonny", [
        (0.0, q_pe, p_pe), (1.1, q_ajo, p_ajo), (1.7, q_ajo, p_ajo),
        (2.1, q_ajc, p_ajc), (3.3, q_colo, p_colo)], passo=2, extra=respira)
    A.sequencia(rig, "largar_jonny", [
        (0.0, q_colo, p_colo), (1.2, q_ajc, p_ajc), (1.6, q_ajo, p_ajo),
        (2.2, q_ajo, p_ajo), (3.2, q_pe, p_pe)], passo=2, extra=respira)
    A.sequencia(rig, "parado_carregando", [(0.0, q_colo, p_colo), (3.4, q_colo, p_colo)],
                laco=True, passo=3, extra=respira)

    peito, rel = _bracos_presos(rig, q_colo)
    cab_colo = {n: q_colo[rig.n(n)] for n in ("neck", "head")}

    def com_colo(t, q, pos):
        for n, r in rel.items():
            q[n] = q[peito] @ r
        # cabeca baixa, olhando pro menino e pro caminho
        A.girar(rig, q, "neck", A.em_torno((1, 0, 0), 12))
        return pos

    A.retarget(rig, fonte, acoes["Walking"], "andar_carregando", laco=True,
               velocidade=0.85, ajustes=com_colo)
    A.retarget(rig, fonte, acoes["Running"], "correr_carregando", laco=True,
               ajustes=com_colo)
