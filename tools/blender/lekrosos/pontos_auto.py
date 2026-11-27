# -*- coding: utf-8 -*-
"""Pontos do esqueleto de um lekroso, MEDIDOS NA MALHA (sem render, sem mao).

Os lekrosos vem todos do mesmo gerador de scan: ~1,89 m, centrados na origem,
Z pra cima, frente no -Y, +X e' a ESQUERDA do personagem, de pe' com os
bracos caidos ao lado do corpo. Isso deixa medir o esqueleto por FATIAS
horizontais da malha:

  - as alturas saem de proporcoes (as do Lekroso 1, medido a mao);
  - a coluna e a cabeca ficam no meio (frente/tras) da faixa central da fatia;
  - braco, mao, perna e pe' sao o AGLOMERADO de vertices daquele lado da
    fatia: o braco e' o grupo mais de fora, separado do tronco por um vao;
  - a ponta dos dedos e' o ponto mais baixo do braco; a ponta do pe', o mais
    a frente da sola.

Validado contra o Lekroso 1 (pontos medidos a mao em render com grade de
5 cm): ver `comparar()` e o README do construir.sh.

Usado pelo `montar_lekroso.py` quando o lekroso nao tem pontos escritos a
mao em PERSONAGENS. Devolve no espaco do .glb importado (antes de
`normalizar_escala`), so' o lado .L — o .R sai espelhado.
"""

import numpy as np

# Alturas como fracao da altura total, do chao (0) ao topo da cabeca (1).
# Medidas no Lekroso 1 (z do .glb de -0,951 a 0,940).
FRAC = {
    "hips": 0.482, "spine": 0.556, "chest": 0.641, "upper_chest": 0.725,
    "neck": 0.831, "head": 0.884,
    "upper_arm": 0.789, "shoulder": 0.805,
    "forearm": 0.625, "hand": 0.503, "fingers_tip": 0.397,
    "thigh": 0.461, "shin": 0.260, "foot": 0.048, "toe": 0.016, "toe_tip": 0.006,
}


def _fatia(v, z, banda):
    return v[np.abs(v[:, 2] - z) < banda]


def _meio_y(f, meia_largura):
    """Meio entre a frente e as costas da faixa central (|x| pequeno)."""
    c = f[np.abs(f[:, 0]) < meia_largura]
    if len(c) < 8:
        c = f
    return 0.5 * (np.percentile(c[:, 1], 3) + np.percentile(c[:, 1], 97))


def _aglomerados(xs, vao):
    """Grupos de valores ordenados separados por vaos maiores que `vao`."""
    xs = np.sort(xs)
    if len(xs) == 0:
        return []
    cortes = np.where(np.diff(xs) > vao)[0]
    grupos, ini = [], 0
    for c in cortes:
        grupos.append((xs[ini], xs[c]))
        ini = c + 1
    grupos.append((xs[ini], xs[-1]))
    return grupos


def _grupo_de_fora(f, vao, minimo):
    """Os vertices do aglomerado mais de fora (x positivo = esquerda)."""
    lado = f[f[:, 0] > minimo]
    if len(lado) < 6:
        return None
    grupos = _aglomerados(lado[:, 0], vao)
    a, b = grupos[-1]
    g = lado[(lado[:, 0] >= a) & (lado[:, 0] <= b)]
    return g if len(g) >= 6 else None


def _centro(g):
    """Meio da caixa do aglomerado (x e y): a mediana puxa pro lado que tem
    mais vertice (a dobra da calca, o punho da manga)."""
    return np.array([0.5 * (g[:, 0].min() + g[:, 0].max()), 0.5 * (g[:, 1].min() + g[:, 1].max())])


def _grupo_de_dentro(f, vao):
    """A perna: o aglomerado de x > 0 mais perto do meio (a mao, que pende
    na altura da coxa, e' o de fora)."""
    lado = f[f[:, 0] > 0.0]
    if len(lado) < 6:
        return None
    a, b = _aglomerados(lado[:, 0], vao)[0]
    g = lado[(lado[:, 0] >= a) & (lado[:, 0] <= b)]
    return g if len(g) >= 6 else None


def medir(verts):
    """`verts`: array (n, 3) do .glb importado. Devolve {osso: (x, y, z)}."""
    v = np.asarray(verts, dtype=float)
    z0, z1 = v[:, 2].min(), v[:, 2].max()
    H = z1 - z0
    banda = 0.012 * H
    vao = 0.012 * H

    def Z(nome):
        return z0 + FRAC[nome] * H

    p = {}
    # ---- coluna e cabeca: no meio da faixa central
    for nome in ("hips", "spine", "chest", "upper_chest", "neck", "head"):
        z = Z(nome)
        p[nome] = (0.0, _meio_y(_fatia(v, z, banda), 0.06 * H), z)
    # o pescoco nao e' medido: a barba e a gola enganam a fatia. Fica a 30%
    # do peito pra cabeca, como no Lekroso 1.
    uc, cb = p["upper_chest"], p["head"]
    p["neck"] = (0.0, uc[1] + 0.3 * (cb[1] - uc[1]), Z("neck"))
    topo = v[v[:, 2] > z1 - 0.03 * H]
    p["head_top"] = (0.0, 0.5 * (topo[:, 1].min() + topo[:, 1].max()), z1)

    # ---- perna esquerda: o lado x > 0 abaixo da virilha
    def perna(z):
        return _grupo_de_dentro(_fatia(v, z, banda), vao)

    joelho = perna(Z("shin"))
    # o tornozelo fica em cima do calcanhar: mede um palmo acima da sola,
    # onde a fatia ainda e' so' a canela (embaixo ja' entra o peito do pe')
    tornoz = perna(z0 + 0.075 * H)
    coxa = perna(z0 + 0.40 * H)
    cj, ct, cc = _centro(joelho), _centro(tornoz), _centro(coxa)
    p["thigh.L"] = (cc[0], cc[1], Z("thigh"))
    p["shin.L"] = (cj[0], cj[1], Z("shin"))
    p["foot.L"] = (ct[0], ct[1], Z("foot"))
    sola = v[(v[:, 2] < z0 + 0.03 * H) & (v[:, 0] > 0.0)]
    i = np.argmin(sola[:, 1])
    ponta = sola[i]
    # o dedao fica a ~60% do tornozelo ate' a ponta
    p["toe_tip.L"] = (ponta[0], ponta[1], Z("toe_tip"))
    p["toe.L"] = (ct[0] + 0.6 * (ponta[0] - ct[0]), ct[1] + 0.6 * (ponta[1] - ct[1]), Z("toe"))

    # ---- braco esquerdo: o aglomerado mais de fora de cada fatia
    meio_tronco = 0.06 * H

    grossura = 0.05 * H  # um braco tem ~9 cm de grossura

    def braco_em(z):
        g = _grupo_de_fora(_fatia(v, z, banda), vao, meio_tronco)
        if g is None:
            return None
        # colado no tronco (sem vao): fica so' com a parte de fora
        borda = g[:, 0].max()
        if borda - g[:, 0].min() > 1.6 * grossura:
            g = g[g[:, 0] > borda - grossura]
        return g

    # Desce pelo braco ate' a ponta dos dedos, fatia por fatia, seguindo o
    # aglomerado de fora enquanto ele continua no mesmo lugar: quando a mao
    # acaba, o "de fora" vira a coxa, e o centro pula. Braco comprido (mao no
    # meio da coxa) ou curto, tanto faz.
    z_ombro = Z("upper_arm")
    z = Z("forearm")
    g = braco_em(z)
    if g is None:
        raise RuntimeError("braco colado no corpo: escreva os pontos a mao em PERSONAGENS")
    ant = _centro(g)
    fundo = g[np.argmin(g[:, 2])]
    passo = 0.5 * banda
    while z > z0 + 0.2 * H:
        z -= passo
        g = braco_em(z)
        if g is None:
            break
        c = _centro(g)
        if abs(c[0] - ant[0]) > 0.02 * H or abs(c[1] - ant[1]) > 0.03 * H:
            break
        ant = c
        baixo = g[np.argmin(g[:, 2])]
        if baixo[2] < fundo[2]:
            fundo = baixo
    # cotovelo e pulso pela proporcao do braco do Lekroso 1 (ombro -> ponta)
    queda = z_ombro - fundo[2]
    cotov = braco_em(z_ombro - 0.42 * queda)
    pulso = braco_em(z_ombro - 0.73 * queda)
    if cotov is None or pulso is None:
        raise RuntimeError("braco colado no corpo: escreva os pontos a mao em PERSONAGENS")
    ce, cp = _centro(cotov), _centro(pulso)
    p["forearm.L"] = (ce[0], ce[1], z_ombro - 0.42 * queda)
    p["hand.L"] = (cp[0], cp[1], z_ombro - 0.73 * queda)
    p["fingers_tip.L"] = (fundo[0], fundo[1], fundo[2])
    # o ombro: o x do cotovelo puxado pra dentro, na altura do braco
    alto = _fatia(v, Z("upper_arm"), banda)
    alto = alto[alto[:, 0] > 0.0]
    borda = np.percentile(alto[:, 0], 98)
    ombro_x = max(borda - 0.5 * grossura, 0.08 * H)
    # Frente/tras do ombro: NAO se mede na altura dele (o cabelo comprido
    # cai por cima e por tras e engana qualquer fatia ali). A junta fica na
    # profundidade do peito, puxada um quarto pro lado do cotovelo (no
    # Lekroso 1 isso cai a 0,5 cm do medido a mao).
    uc_y = p["upper_chest"][1]
    ombro_y = uc_y + 0.25 * (ce[1] - uc_y)
    p["upper_arm.L"] = (ombro_x, ombro_y, Z("upper_arm"))
    p["shoulder.L"] = (0.026 * H, p["upper_chest"][1], Z("shoulder"))
    # o polegar: pela linha pulso -> ponta, um pouco pra frente
    m = np.array(p["hand.L"])
    t = np.array(p["fingers_tip.L"])
    frente = np.array([-0.01, -0.03, 0.0]) * H / 1.89
    p["thumb.L"] = tuple(m + 0.22 * (t - m) + frente)
    p["thumb_tip.L"] = tuple(m + 0.55 * (t - m) + 1.8 * frente)
    return {k: tuple(float(c) for c in val) for k, val in p.items()}


def comparar(medido, auto):
    """Diferenca em cm, osso a osso (so' os que existem nos dois)."""
    linhas = []
    for k in sorted(medido):
        if k in auto:
            d = np.linalg.norm(np.array(medido[k]) - np.array(auto[k])) * 100.0
            linhas.append((k, d))
    return linhas
