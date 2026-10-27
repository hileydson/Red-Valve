# -*- coding: utf-8 -*-
"""Modela o CEMITERIO da cidade — arena de chefe — e exporta pro Godot.

    blender --background --factory-startup \\
        --python tools/blender/cemiterio/gerar_cemiterio.py

Saidas:
    red-valve/assets/3d_model/stages/cemiterio/cemiterio.glb
    red-valve/assets/3d_model/stages/cemiterio/cemiterio_pontos.json

Depois: `tools/godot/cemiterio/gerar_cena_cemiterio.py` e `--headless --import`.

==============================================================================
O LUGAR

O cemiterio velho de Red Valve, murado, numa noite de nevoa fechada (Silent
Hill): a nevoa e' que desenha o mundo, e o que passa de 35 m vira vulto. A
planta e' de arena: o MEIO e' aberto pro chefe, o resto e' tumulo — cobertura,
corredor e esconderijo.

                         N (-Z)
                 [ CAPELA DOS OSSOS ]
        mausoleu      tumulos      mausoleu
     tumulos   ( PRACA DOS ANJOS )   tumulos
        mausoleu      tumulos      mausoleu
                      avenida
                    [ PORTAO ]   <- o jogador entra aqui
                         S (+Z)

  - Muro de pedra de 3,4 m com grade de lancas em cima, em volta de tudo
    (116 x 124 m). Quem segura o jogador e' o muro invisivel logo dentro.
  - Praca dos Anjos: circulo de 21 m de raio, LIMPO, com oito anjos partidos
    em volta olhando pro centro. E' o ringue.
  - Uma avenida do portao ate' a praca, duas travessas pros lados e uma
    ronda colada no muro: da' pra correr a volta inteira.
  - Campos de tumulo em fileiras com corredor a cada tres — lapide, cruz,
    cruz celta, obelisco, sarcofago, tumulo raso, anjo; uns tortos, uns
    caidos, algumas covas ABERTAS soltando nevoa.
  - O Lovecraft vem por baixo: tentaculos saindo de tres covas, carne
    estourando o telhado da capela, sigilos acesos em algumas lapides.
"""

import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "cenarios"))

from base import (Cena, caixa, caixa_girada, chao_grade, cilindro, colisao_grade,  # noqa: E402
                  coluneta, cruz, domo, entulho, espinho, hexaedro, lerp,
                  marcadores_em_volta, muro_invisivel, navmesh_grade, ruido2,
                  silhueta_gotica, suave, tentaculo, tubo, tubo_redondo)

MX, MZ = 58.0, 62.0          # face interna do muro
LIM_X, LIM_Z = 56.9, 60.9    # muro invisivel
R_PRACA = 21.0
AV_W = 3.6                   # meia-largura da avenida
TRAV_W = 2.6                 # meia-largura das travessas
RONDA = 3.4                  # largura da ronda colada no muro
CAPELA_Z = -46.0
SPAWN = (0.0, 0.3, 55.0)
PASSO = 1.0                  # navmesh
PASSO_CHAO = 2.0             # chao visivel e colisao (a ondulacao e' suave)
SETOR = 30.0


def no_caminho(x, z):
    """Caminho pavimentado: avenida, travessas, praca e a ronda."""
    if x * x + z * z <= (R_PRACA + 1.5) ** 2:
        return True
    if abs(x) <= AV_W and z >= 0:
        return True
    if abs(z) <= TRAV_W and abs(x) <= MX:
        return True
    if abs(x) <= AV_W and CAPELA_Z + 6.0 <= z <= 0:
        return True
    if abs(x) >= MX - RONDA or abs(z) >= MZ - RONDA:
        return True
    return False


def altura(x, z):
    """Terra que ondula de leve; plana no caminho (sem degrau na borda)."""
    if abs(x) > MX + 0.5 or abs(z) > MZ + 0.5:
        # fora do muro: sobe devagar e vira morro na nevoa
        d = max(abs(x) - MX, abs(z) - MZ)
        return 0.5 * ruido2(x, z, 3.0) + d * 0.08 + max(0.0, d - 40.0) * 0.25
    h = 0.32 * ruido2(x * 1.3, z * 1.3, 1.0) + 0.12 * ruido2(x * 3.1, z * 2.7, 4.0)
    # afunda pra zero perto do caminho, sem quina
    dist = _dist_caminho(x, z)
    return h * suave(dist / 3.0)


def _dist_caminho(x, z):
    d = 99.0
    d = min(d, math.hypot(x, z) - (R_PRACA + 1.5))
    if z >= 0:
        d = min(d, abs(x) - AV_W)
    d = min(d, abs(z) - TRAV_W)
    if CAPELA_Z + 6.0 <= z <= 0:
        d = min(d, abs(x) - AV_W)
    d = min(d, (MX - RONDA) - abs(x), (MZ - RONDA) - abs(z))
    return max(d, 0.0)


class Cemiterio(Cena):

    def __init__(self):
        super().__init__("cem", 1313)
        self.pontos = {
            "player": list(SPAWN),
            "chefe": [0.0, 0.2, -10.0],
            "lanternas": [],
            "velas": [],
            "covas": [],
            "sigilos": [],
            "inimigos": [],
            "olhos": [],
            "navmesh": {"v": [], "p": []},
        }
        self.ocupado = []      # (x, z, raio) pra nada nascer em cima de nada

    def livre(self, x, z, r):
        for ox, oz, orr in self.ocupado:
            if (x - ox) ** 2 + (z - oz) ** 2 < (r + orr) ** 2:
                return False
        return True

    def ocupar(self, x, z, r, bloqueia=True):
        self.ocupado.append((x, z, r))
        if bloqueia:
            self.bloquear(x, z, r)

    # ------------------------------------------------------------------
    def montar(self):
        self.chao()
        self.muro()
        self.portao()
        self.capela()
        self.praca()
        self.mausoleus()
        self.arvores()
        self.lampioes()
        self.tumulos()
        self.horror()
        self.longe()
        muro_invisivel(self, [(LIM_X, LIM_Z), (-LIM_X, LIM_Z), (-LIM_X, -LIM_Z), (LIM_X, -LIM_Z)],
                       y0=-3.0, y1=14.0)
        self.pontos["navmesh"] = navmesh_grade(
            self, -LIM_X, LIM_X, -LIM_Z, LIM_Z, PASSO, altura,
            lambda x, z: abs(x) < LIM_X - 0.8 and abs(z) < LIM_Z - 0.8,
            max_desnivel=0.5, folga=0.55)
        self.pontos["inimigos"] = marcadores_em_volta(self.pontos["navmesh"], (0.0, 0.0), 16.0, 10)

    # ------------------------------------------------------------------
    def chao(self):
        def classe(xc, zc):
            if abs(xc) > 150 or abs(zc) > 150:
                return None
            dentro = abs(xc) < MX and abs(zc) < MZ
            if dentro and no_caminho(xc, zc):
                if xc * xc + zc * zc <= (R_PRACA + 1.5) ** 2:
                    return "lajota"
                return "caminho"
            n = ruido2(xc * 0.7, zc * 0.7, 9.0)
            return "grama" if n > 0.15 else "terra"

        # dentro do muro, celula de 1 m; fora, 4 m (ninguem pisa la'). As duas
        # grades encostam em x=+-60 e z=+-64 (multiplos de 4): sem fresta e
        # sem sobreposicao (sobreposicao = z-fight na terra colada no muro)
        grupos = chao_grade(self, -MX - 2, MX + 2, -MZ - 2, MZ + 2, PASSO_CHAO, altura,
                            classe, SETOR, "chao", esp=0.6, aberta=True)
        celulas = set()
        for cel in grupos.values():
            celulas.update(cel)
        colisao_grade(self, celulas, PASSO_CHAO, altura, esp=1.5)

        def classe_fora(xc, zc):
            if abs(xc) < MX + 2 and abs(zc) < MZ + 2:
                return None
            return "terra" if ruido2(xc, zc, 2.0) > 0 else "grama"
        chao_grade(self, -152, 152, -152, 152, 4.0, altura, classe_fora, 76.0, "fora", aberta=True)

    # ------------------------------------------------------------------
    def muro(self):
        rnd = self.rnd
        lados = [((-MX, -MZ), (MX, -MZ)), ((MX, -MZ), (MX, MZ)),
                 ((MX, MZ), (-MX, MZ)), ((-MX, MZ), (-MX, -MZ))]
        for li, (a, b) in enumerate(lados):
            comp = math.hypot(b[0] - a[0], b[1] - a[1])
            dx, dz = (b[0] - a[0]) / comp, (b[1] - a[1]) / comp
            nx, nz = -dz, dx   # normal pra dentro
            n = int(comp / 7.0)
            for k in range(n):
                t0, t1 = k / n, (k + 1) / n
                p0 = (lerp(a[0], b[0], t0), lerp(a[1], b[1], t0))
                p1 = (lerp(a[0], b[0], t1), lerp(a[1], b[1], t1))
                mx_, mz_ = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
                # portao no meio do muro sul
                if li == 2 and abs(mx_) < 6.0:
                    continue
                setor = self.setor_grade("muro", mx_, mz_, SETOR)
                caido = rnd.random() < 0.12
                h = rnd.uniform(1.0, 2.0) if caido else 3.4
                ox, oz = -nx * 0.35, -nz * 0.35    # o muro fica pra FORA da linha
                q = [(p0[0] + ox + nx * 0.35, p0[1] + oz + nz * 0.35),
                     (p1[0] + ox + nx * 0.35, p1[1] + oz + nz * 0.35),
                     (p1[0] + ox - nx * 0.35, p1[1] + oz - nz * 0.35),
                     (p0[0] + ox - nx * 0.35, p0[1] + oz - nz * 0.35)]
                y0 = -0.8
                self.m.add_pecas(setor, "muro", [hexaedro([(q[0][0], y0, q[0][1]), (q[1][0], y0, q[1][1]),
                                                          (q[2][0], y0, q[2][1]), (q[3][0], y0, q[3][1]),
                                                          (q[0][0], h, q[0][1]), (q[1][0], h, q[1][1]),
                                                          (q[2][0], h, q[2][1]), (q[3][0], h, q[3][1])])])
                self.col.append(hexaedro([(q[0][0], y0, q[0][1]), (q[1][0], y0, q[1][1]),
                                          (q[2][0], y0, q[2][1]), (q[3][0], y0, q[3][1]),
                                          (q[0][0], h, q[0][1]), (q[1][0], h, q[1][1]),
                                          (q[2][0], h, q[2][1]), (q[3][0], h, q[3][1])]))
                if caido:
                    self.m.add_pecas(setor, "muro", entulho(mx_ + nx * 1.4, mz_ + nz * 1.4, 1.6, 6, rnd,
                                                            tamanho=(0.3, 0.8)))
                else:
                    # capa do muro + grade de lancas
                    self.m.add_pecas(setor, "pedra_esc", [caixa_girada(mx_ + ox, h + 0.08, mz_ + oz,
                                                                       7.05, 0.16, 0.95,
                                                                       math.atan2(dx, dz) + math.pi / 2)])
                    barras = []
                    nb = int(7.0 / 0.6)
                    for j in range(nb):
                        tb = (j + 0.5) / nb
                        bx = lerp(p0[0], p1[0], tb) + ox
                        bz = lerp(p0[1], p1[1], tb) + oz
                        alt = 1.1 + (0.25 if j % 4 == 0 else 0.0)
                        barras.append(caixa((bx - 0.025, h + 0.16, bz - 0.025),
                                            (bx + 0.025, h + 0.16 + alt, bz + 0.025)))
                        barras.append(espinho((bx, h + 0.16 + alt, bz), (bx, h + 0.36 + alt, bz), 0.06, n=4))
                    barras.append(tubo([(p0[0] + ox, h + 1.05, p0[1] + oz), (p1[0] + ox, h + 1.05, p1[1] + oz)],
                                       0.05, 0.06))
                    self.m.add_pecas(setor, "metal", barras)
                # pilar no comeco de cada lance
                px, pz = p0[0] + ox, p0[1] + oz
                self.m.add_pecas(setor, "muro", [caixa((px - 0.6, -0.8, pz - 0.6), (px + 0.6, 4.1, pz + 0.6))])
                self.m.add_pecas(setor, "pedra_esc", [caixa((px - 0.72, 4.1, pz - 0.72), (px + 0.72, 4.35, pz + 0.72)),
                                                       espinho((px, 4.35, pz), (px, 5.2, pz), 0.55, n=4)])
                self.col.append(caixa((px - 0.6, -0.8, pz - 0.6), (px + 0.6, 4.1, pz + 0.6)))

    def portao(self):
        z = MZ + 0.35
        for s in (-1, 1):
            x = s * 5.2
            self.m.add_pecas("portao", "muro", [caixa((x - 1.1, -0.5, z - 1.1), (x + 1.1, 5.4, z + 1.1))])
            self.m.add_pecas("portao", "pedra_esc", [caixa((x - 1.3, 5.4, z - 1.3), (x + 1.3, 5.8, z + 1.3))])
            self.anjo(x, 5.8, z, 2.6, math.pi, "portao", partido=False)
            self.col.append(caixa((x - 1.1, -0.5, z - 1.1), (x + 1.1, 5.4, z + 1.1)))
        # o vao entre o pilar do portao e o primeiro lance do muro
        for s in (-1, 1):
            self.m.add_pecas("portao", "muro", [caixa((min(s * 6.2, s * 7.4), -0.8, z - 0.35),
                                                      (max(s * 6.2, s * 7.4), 3.4, z + 0.35))])
            self.col.append(caixa((min(s * 6.2, s * 7.4), -0.8, z - 0.35), (max(s * 6.2, s * 7.4), 3.4, z + 0.35)))
        # portao de ferro FECHADO atras do jogador (uma folha entreaberta)
        barras = []
        for s in (-1, 1):
            giro = 0.0 if s < 0 else 0.35
            hx = s * 4.1
            for j in range(10):
                d = (j + 0.5) * 0.4
                bx = hx - s * d * math.cos(giro)
                bz = z - d * math.sin(giro) * s
                topo = 3.6 + 0.6 * math.sin(math.pi * (j + 0.5) / 10)
                barras.append(caixa((bx - 0.035, 0.0, bz - 0.035), (bx + 0.035, topo, bz + 0.035)))
                barras.append(espinho((bx, topo, bz), (bx, topo + 0.3, bz), 0.08, n=4))
            for yy in (0.4, 1.8, 3.2):
                barras.append(tubo([(hx, yy, z), (hx - s * 4.0 * math.cos(giro), yy, z - 4.0 * math.sin(giro) * s)],
                                   0.06, 0.08))
        self.m.add_pecas("portao", "metal", barras)
        self.col.append(caixa((-4.2, 0.0, z - 0.3), (4.2, 4.5, z + 0.3)))

    # ------------------------------------------------------------------
    def anjo(self, x, y, z, alt, giro, setor, partido=True, asas=True):
        """Anjo de pedra de tunica longa, maos juntas, asas meio abertas.
        `partido`: sem cabeca e com uma asa quebrada."""
        rnd = self.rnd
        ca, sa = math.cos(giro), math.sin(giro)

        def P(lx, ly, lz):
            return (x + lx * ca + lz * sa, y + ly, z - lx * sa + lz * ca)

        h = alt
        pecas = [cilindro(x, z, h * 0.17, y, y + h * 0.6, n=10, raio_topo=h * 0.1),
                 cilindro(x, z, h * 0.1, y + h * 0.6, y + h * 0.8, n=10, raio_topo=h * 0.12)]
        if not partido:
            pecas.append(cilindro(*P(0, 0, 0.0)[::2], h * 0.075, y + h * 0.8, y + h * 0.95, n=8,
                                  raio_topo=h * 0.06))
        for s in (-1, 1):
            om = P(s * h * 0.11, h * 0.76, 0.0)
            mao = P(s * h * 0.02, h * 0.62, h * 0.12)
            pecas.append(tubo_redondo([om, P(s * h * 0.13, h * 0.66, h * 0.06), mao],
                                      [h * 0.035, h * 0.032, h * 0.03], n=6))
        if asas:
            for s in (-1, 1):
                if partido and s > 0:
                    continue
                raiz = P(s * h * 0.06, h * 0.74, -h * 0.08)
                ponta = P(s * h * 0.42, h * 1.05, -h * 0.28)
                baixo = P(s * h * 0.3, h * 0.3, -h * 0.22)
                esp = h * 0.03
                v = [raiz, ponta, baixo]
                v2 = [(p[0] - sa * esp * s, p[1], p[2] - ca * esp * s) for p in v]
                pecas.append((v + v2, [[0, 1, 2], [5, 4, 3], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]]))
        self.m.add_pecas(setor, "lapide_clara", pecas)
        _ = rnd

    def praca(self):
        rnd = self.rnd
        # oito anjos partidos em volta, olhando pro centro
        for k in range(8):
            a = 2 * math.pi * k / 8 + math.pi / 8
            r = R_PRACA + 2.6
            x, z = r * math.sin(a), r * math.cos(a)
            if abs(x) < AV_W + 1.5 or abs(z) < TRAV_W + 1.5:
                continue
            y = altura(x, z)
            setor = self.setor_grade("praca", x, z, SETOR)
            giro = math.atan2(-x, -z)
            self.m.add_pecas(setor, "lapide", [caixa_girada(x, y + 0.6, z, 1.8, 1.4, 1.8, giro),
                                                caixa_girada(x, y + 1.35, z, 1.5, 0.12, 1.5, giro)])
            self.anjo(x, y + 1.4, z, 3.0, giro, setor, partido=(k % 3 != 0))
            self.col.append(caixa_girada(x, y + 1.0, z, 1.8, 2.0, 1.8, giro))
            self.ocupar(x, z, 1.6)
            # velas no pe' do pedestal
            for v in range(5):
                va = giro + rnd.uniform(-1.2, 1.2)
                vx, vz = x + math.sin(va) * 1.25, z + math.cos(va) * 1.25
                hv = rnd.uniform(0.12, 0.35)
                self.m.add_pecas(setor, "vela", [cilindro(vx, vz, 0.045, y, y + hv, n=6)])
                self.m.add_pecas(setor, "chama", [cilindro(vx, vz, 0.02, y + hv, y + hv + 0.06, n=4,
                                                           raio_topo=0.002)])
            self.pontos["velas"].append([round(x * 0.93, 2), round(y + 0.5, 2), round(z * 0.93, 2)])
        # desenho gravado no chao da praca: aneis e uma cruz invertida de lajota escura
        pecas = []
        for r, n in ((R_PRACA - 0.6, 84), (12.0, 56), (4.0, 24)):
            for k in range(n):
                a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
                pecas.append(_fita((r * math.sin(a0), 0.0, r * math.cos(a0)),
                                   (r * math.sin(a1), 0.0, r * math.cos(a1)), 0.35, 0.025))
        for a in (0.0, math.pi / 2, math.pi, -math.pi / 2):
            pecas.append(_fita((4.0 * math.sin(a), 0.0, 4.0 * math.cos(a)),
                               (12.0 * math.sin(a), 0.0, 12.0 * math.cos(a)), 0.35, 0.025))
        self.m.add_pecas("praca_desenho", "pedra_esc", pecas)
        # o sigilo do meio, apagado (acende quando o chefe vier)
        sig = []
        for k in range(7):
            a = 2 * math.pi * k / 7
            sig.append(_fita((3.4 * math.sin(a), 0.0, 3.4 * math.cos(a)),
                             (3.4 * math.sin(a + 2 * math.pi * 3 / 7), 0.0, 3.4 * math.cos(a + 2 * math.pi * 3 / 7)),
                             0.12, 0.03))
        self.m.add_pecas("praca_sigilo", "sigilo_praca", sig)

    def capela(self):
        """A capela dos ossos, fundo norte. Fachada gotica com rosacea
        apagada (brilho de brasa la' dentro) e carne estourando o telhado."""
        rnd = self.rnd
        z0 = CAPELA_Z
        w, prof, h = 11.0, 14.0, 9.0
        zf = z0            # face da fachada
        zb = z0 - prof
        setor = "capela"
        self.m.add_pecas(setor, "muro", [caixa((-w, -0.5, zb), (w, h, zf))])
        # telhado de duas aguas (dois prismas)
        for s in (-1, 1):
            self.m.add_pecas(setor, "telhado", [hexaedro([
                (0.0, h + 6.5, zb - 0.6), (s * (w + 0.8), h - 0.4, zb - 0.6),
                (s * (w + 0.8), h - 0.4, zf + 0.6), (0.0, h + 6.5, zf + 0.6),
                (0.0, h + 6.9, zb - 0.6), (s * (w + 0.8), h, zb - 0.6),
                (s * (w + 0.8), h, zf + 0.6), (0.0, h + 6.9, zf + 0.6)])])
        # frontao triangular
        self.m.add_pecas(setor, "muro", [hexaedro([
            (-w, h, zf), (w, h, zf), (w, h, zf - 0.6), (-w, h, zf - 0.6),
            (-0.05, h + 6.6, zf), (0.05, h + 6.6, zf), (0.05, h + 6.6, zf - 0.6), (-0.05, h + 6.6, zf - 0.6)])])
        # torres
        for s in (-1, 1):
            tx = s * (w + 1.8)
            self.m.add_pecas(setor, "muro", [caixa((tx - 2.2, -0.5, zf - 4.4), (tx + 2.2, 17.0, zf + 0.2))])
            self.m.add_pecas(setor, "telhado", [espinho((tx, 17.0, zf - 2.1), (tx, 26.0, zf - 2.1), 2.7, n=4)])
            self.m.add_pecas(setor, "pedra_esc", [caixa((tx - 2.4, 16.6, zf - 4.6), (tx + 2.4, 17.2, zf + 0.4))])
            for cx_ in (-2.2, 2.2):
                self.m.add_pecas(setor, "pedra_esc", [espinho((tx + cx_, 17.2, zf + 0.2),
                                                              (tx + cx_, 19.2, zf + 0.2), 0.3, n=4)])
            self.col.append(caixa((tx - 2.2, -0.5, zf - 4.4), (tx + 2.2, 17.0, zf + 0.2)))
        # portal: arquivolta escura + porta
        pts = []
        for i in range(15):
            t = i / 14.0
            u = abs(2 * t - 1)
            pts.append((lerp(-2.6, 2.6, t), 0.0 + 3.6 + 2.2 * (1 - u ** 1.8) ** 0.75, zf + 0.25))
        pts.insert(0, (-2.6, 0.0, zf + 0.25))
        pts.append((2.6, 0.0, zf + 0.25))
        self.m.add_pecas(setor, "pedra_esc", [tubo_redondo(pts, [0.42] * len(pts), n=6)])
        self.m.add_pecas(setor, "porta", [caixa((-2.3, 0.0, zf - 0.05), (2.3, 5.4, zf + 0.12))])
        # rosacea
        rc = (0.0, h + 1.6, zf + 0.18)
        anel = [(rc[0] + 2.6 * math.sin(2 * math.pi * k / 24), rc[1] + 2.6 * math.cos(2 * math.pi * k / 24), rc[2])
                for k in range(25)]
        self.m.add_pecas(setor, "pedra_esc", [tubo_redondo(anel, [0.28] * 25, n=6)])
        self.m.add_pecas(setor, "vitral", [cilindro(0.0, 0.0, 2.45, -0.04, 0.04, n=20)])
        self._girar_ultimo(setor, "vitral", rc)
        raios = []
        for k in range(8):
            a = 2 * math.pi * k / 8
            raios.append(tubo_redondo([rc, (rc[0] + 2.5 * math.sin(a), rc[1] + 2.5 * math.cos(a), rc[2] + 0.05)],
                                      [0.1, 0.1], n=4))
        self.m.add_pecas(setor, "pedra_esc", raios)
        # escadaria rasa na frente (colisao de rampa)
        for i in range(4):
            zz = zf + 0.6 + (3 - i) * 0.7
            self.m.add_pecas(setor, "lapide", [caixa((-6.0, -0.4, zz - 0.35), (6.0, 0.15 * (i + 1), zz + 0.35))])
        self.col.append(hexaedro([(-6.0, -0.4, zf + 3.6), (6.0, -0.4, zf + 3.6), (6.0, -0.4, zf), (-6.0, -0.4, zf),
                                  (-6.0, 0.0, zf + 3.6), (6.0, 0.0, zf + 3.6), (6.0, 0.6, zf), (-6.0, 0.6, zf)]))
        self.col.append(caixa((-w, -0.5, zb), (w, h, zf)))
        self.ocupar(0.0, zf - prof / 2, 14.0, bloqueia=False)
        self.bloquear_linha(-w, zf - 1.0, w, zf - 1.0, 1.2)
        # carne estourando o telhado + tentaculos pela lateral
        for k in range(9):
            bx = rnd.uniform(-w * 0.8, w * 0.8)
            bz = rnd.uniform(zb + 2, zf - 2)
            by = h + 6.5 * (1 - abs(bx) / (w + 0.8)) - 0.3
            r = rnd.uniform(1.2, 2.6)
            self.m.add_pecas(setor, "carne", [cilindro(bx, bz, r, by - r * 0.3, by + r * 0.5, n=9,
                                                       raio_topo=r * 0.45)], suave=True)
        for a, comp in ((0.4, 9.0), (2.4, 11.0), (4.0, 8.0)):
            bx = w * 0.6 * math.cos(a)
            tentaculo(self, setor, "carne", (bx, h + 3.0, zf - prof * 0.5 + math.sin(a) * 4),
                      (math.cos(a) * 0.6, 1.0, math.sin(a) * 0.4), comp, 0.85, curva=1.1, fase=a,
                      ventosas="osso")
        self.pontos["vitral"] = list(rc)

    def _girar_ultimo(self, setor, mat, centro):
        """Deita no plano XY o cilindro que acabou de entrar (vira disco de
        frente pra +Z) e leva pro centro dado."""
        g = self.m.grupos[(setor, mat)]
        for i in range(len(g["v"])):
            x, y, z = g["v"][i]
            g["v"][i] = (centro[0] + x, centro[1] + z, centro[2] + y)
        # o giro troca a mao das faces: inverte a ordem pra a normal sair certa
        g["f"] = [list(reversed(f)) for f in g["f"]]

    # ------------------------------------------------------------------
    def mausoleus(self):
        rnd = self.rnd
        for i, (x, z, giro) in enumerate(((-38.0, -34.0, 0.0), (38.0, -34.0, 0.0), (-40.0, 30.0, math.pi),
                                          (40.0, 30.0, math.pi), (-22.0, 44.0, math.pi / 2),
                                          (24.0, -48.0, -math.pi / 2), (-24.0, -48.0, math.pi / 2))):
            self.mausoleu(x, z, giro, "mausoleu_%d" % i, ruina=(i % 3 == 2))
            self.ocupar(x, z, 5.6)
        _ = rnd

    def mausoleu(self, x, z, giro, setor, ruina=False):
        rnd = self.rnd
        y = altura(x, z)
        ca, sa = math.cos(giro), math.sin(giro)

        def P(lx, ly, lz):
            return (x + lx * ca + lz * sa, y + ly, z - lx * sa + lz * ca)

        w, prof, h = 2.6, 3.4, 3.6
        pecas, esc, telha = [], [], []
        pecas.append(caixa_girada(x, y + 0.2, z, 2 * w + 1.0, 0.6, 2 * prof + 1.6, giro))
        pecas.append(caixa_girada(*P(0, 0.5 + h / 2, -0.4), 2 * w, h, 2 * prof - 0.8, giro))
        # colunas na frente
        for s in (-1, 1):
            cx_, _, cz_ = P(s * (w - 0.35), 0, prof - 0.2)
            pecas.extend(coluneta(cx_, cz_, y + 0.5, y + 0.5 + h, raio=0.26, n=8))
        # porta escura
        esc.append(caixa_girada(*P(0, 0.5 + 1.25, prof - 0.78), 1.4, 2.5, 0.08, giro))
        # telhado
        if not ruina:
            for s in (-1, 1):
                a0 = P(0, h + 2.1, -prof - 0.2)
                a1 = P(0, h + 2.1, prof + 0.3)
                b0 = P(s * (w + 0.4), h + 0.35, -prof - 0.2)
                b1 = P(s * (w + 0.4), h + 0.35, prof + 0.3)
                telha.append(hexaedro([b0, b1, a1, a0,
                                       (b0[0], b0[1] + 0.25, b0[2]), (b1[0], b1[1] + 0.25, b1[2]),
                                       (a1[0], a1[1] + 0.25, a1[2]), (a0[0], a0[1] + 0.25, a0[2])]))
            topo = P(0, h + 2.35, prof + 0.1)
            pecas.extend(cruz(topo[0], topo[1], topo[2], alt=1.4, larg=0.16, giro=giro))
        else:
            pecas.extend(entulho(*P(0, 0, prof + 1.6)[::2], 1.6, 8, rnd, y=y, tamanho=(0.3, 0.9)))
            telha.append(caixa_girada(*P(0.8, h + 0.4, -0.5), 2 * w + 0.6, 0.25, 3.0, giro, 0.25))
        self.m.add_pecas(setor, "lapide", pecas)
        self.m.add_pecas(setor, "porta", esc)
        self.m.add_pecas(setor, "telhado", telha)
        self.col.append(caixa_girada(x, y + 1.5, z, 2 * w + 1.0, 3.6, 2 * prof + 1.6, giro))

    def arvores(self):
        rnd = self.rnd
        feitas = 0
        tentativas = 0
        while feitas < 13 and tentativas < 400:
            tentativas += 1
            x = rnd.uniform(-MX + 4, MX - 4)
            z = rnd.uniform(-MZ + 4, MZ - 4)
            if no_caminho(x, z) or not self.livre(x, z, 3.0) or math.hypot(x, z) < R_PRACA + 5:
                continue
            self.arvore(x, z)
            self.ocupar(x, z, 0.9)
            feitas += 1

    def arvore(self, x, z):
        rnd = self.rnd
        y = altura(x, z) - 0.3
        setor = self.setor_grade("arvore", x, z, SETOR)
        alt = rnd.uniform(6.0, 10.0)
        pts, raios = [], []
        ang = rnd.uniform(0, math.pi * 2)
        px, pz = x, z
        for i in range(7):
            t = i / 6.0
            px += math.cos(ang + t * 2.0) * rnd.uniform(0.0, 0.5)
            pz += math.sin(ang + t * 2.0) * rnd.uniform(0.0, 0.5)
            pts.append((px, y + alt * t, pz))
            raios.append(lerp(0.45, 0.08, t))
        pecas = [tubo_redondo(pts, raios, n=7)]

        def galho(p, direcao, comp, raio, nivel):
            if nivel > 2 or comp < 0.6:
                return
            dx, dy, dz = direcao
            q = [p]
            cur = p
            for j in range(3):
                cur = (cur[0] + dx * comp / 3 + rnd.uniform(-0.25, 0.25),
                       cur[1] + dy * comp / 3 + rnd.uniform(-0.15, 0.2),
                       cur[2] + dz * comp / 3 + rnd.uniform(-0.25, 0.25))
                q.append(cur)
            pecas.append(tubo_redondo(q, [raio, raio * 0.8, raio * 0.5, 0.025], n=5))
            for _k in range(2 if nivel < 2 else 1):
                a = rnd.uniform(0, 2 * math.pi)
                galho(q[2], (math.cos(a) * 0.8, rnd.uniform(0.2, 0.7), math.sin(a) * 0.8),
                      comp * 0.6, raio * 0.55, nivel + 1)

        for k in range(rnd.randint(4, 6)):
            i = rnd.randint(3, 5)
            a = rnd.uniform(0, 2 * math.pi)
            galho(pts[i], (math.cos(a), rnd.uniform(0.1, 0.6), math.sin(a)), rnd.uniform(2.0, 4.0),
                  raios[i] * 0.7, 0)
        self.m.add_pecas(setor, "tronco", pecas)
        self.col.append(cilindro(x, z, 0.45, y, y + 4.0, n=6))

    def lampioes(self):
        """Postes de ferro com lanterna: avenida e volta da praca. So' alguns
        acendem de verdade (luz omni); o resto e' brilho no vidro."""
        lugares = []
        for z in (52.0, 42.0, 32.0):
            lugares.append((-(AV_W + 0.8), z))
            lugares.append((AV_W + 0.8, z))
        for k in range(4):
            a = 2 * math.pi * k / 4 + math.pi / 4
            lugares.append(((R_PRACA + 1.0) * math.sin(a) * 0.75, (R_PRACA + 1.0) * math.cos(a) * 0.75 + 0.0))
        for i, (x, z) in enumerate(lugares):
            if math.hypot(x, z) < R_PRACA + 3 and i >= 6:
                # na praca o poste fica na borda, nao no meio do ringue
                r = R_PRACA + 0.4
                a = math.atan2(x, z)
                x, z = r * math.sin(a), r * math.cos(a)
            y = altura(x, z)
            setor = self.setor_grade("lampiao", x, z, SETOR)
            lado = 1 if x < 0 else -1
            pecas = [cilindro(x, z, 0.22, y, y + 0.4, n=8), cilindro(x, z, 0.07, y + 0.4, y + 3.6, n=6),
                     tubo([(x, y + 3.5, z), (x + lado * 0.7, y + 3.6, z)], 0.06, 0.06),
                     caixa((x + lado * 0.7 - 0.22, y + 3.45, z - 0.22), (x + lado * 0.7 + 0.22, y + 3.5, z + 0.22)),
                     caixa((x + lado * 0.7 - 0.25, y + 2.95, z - 0.25), (x + lado * 0.7 + 0.25, y + 3.0, z + 0.25))]
            self.m.add_pecas(setor, "metal", pecas)
            self.m.add_pecas(setor, "luz", [caixa((x + lado * 0.7 - 0.18, y + 3.0, z - 0.18),
                                                  (x + lado * 0.7 + 0.18, y + 3.45, z + 0.18))])
            self.pontos["lanternas"].append([round(x + lado * 0.7, 2), round(y + 3.2, 2), round(z, 2)])
            self.col.append(cilindro(x, z, 0.2, y, y + 3.0, n=6))
            self.ocupar(x, z, 0.5)

    # ------------------------------------------------------------------
    def tumulos(self):
        """Fileiras nos quatro campos. A cada tres fileiras, um corredor."""
        rnd = self.rnd
        n = 0
        dz_fila = 4.3
        dx_col = 3.3
        for qx in (-1, 1):
            for qz in (-1, 1):
                fila = 0
                z = qz * (TRAV_W + 3.2)
                while abs(z) < MZ - RONDA - 1.5:
                    if fila % 3 == 2:
                        z += qz * 2.4     # corredor
                        fila += 1
                        continue
                    x = qx * (AV_W + 2.6)
                    while abs(x) < MX - RONDA - 1.2:
                        jx = x + rnd.uniform(-0.35, 0.35)
                        jz = z + rnd.uniform(-0.3, 0.3)
                        if (math.hypot(jx, jz) > R_PRACA + 4.0 and not no_caminho(jx, jz)
                                and self.livre(jx, jz, 1.5) and rnd.random() > 0.08):
                            self.tumulo(jx, jz, n)
                            n += 1
                        x += qx * dx_col
                    z += qz * dz_fila
                    fila += 1
        self.pontos["n_tumulos"] = n

    def tumulo(self, x, z, n):
        rnd = self.rnd
        y = altura(x, z)
        setor = self.setor_grade("tumulos", x, z, SETOR)
        giro = rnd.uniform(-0.12, 0.12) + (math.pi if z < 0 else 0.0)
        incl = rnd.uniform(-0.16, 0.16) if rnd.random() < 0.45 else 0.0
        ca, sa = math.cos(giro), math.sin(giro)

        def P(lx, lz):
            return x + lx * ca + lz * sa, z - lx * sa + lz * ca

        tipo = rnd.random()
        mat = "lapide" if rnd.random() < 0.7 else "lapide_clara"
        pecas = []
        # a cabeceira fica na ponta "de tras" (lz = -0.9); o corpo em volta
        hx, hz = P(0.0, -0.95)
        if tipo < 0.30:
            # lapide arredondada
            hl = rnd.uniform(0.8, 1.3)
            pecas.append(caixa_girada(hx, y + hl * 0.4 - 0.2, hz, 0.75, hl * 0.8 + 0.4, 0.17, giro, incl))
            topo = (hx, y + hl * 0.8 - 0.2, hz)
            dxs, dzs = sa * 0.085, ca * 0.085
            pecas.append(tubo_redondo([(topo[0] - dxs, topo[1], topo[2] - dzs),
                                       (topo[0] + dxs, topo[1], topo[2] + dzs)], [0.375, 0.375], n=10))
            pecas.append(caixa_girada(x, y + 0.05, z, 0.95, 0.24, 1.9, giro))
            col = (0.9, 2.2)
        elif tipo < 0.48:
            pecas.extend(cruz(hx, y - 0.2, hz, alt=rnd.uniform(1.4, 2.0), larg=0.16, giro=giro, inclina=incl))
            pecas.append(caixa_girada(x, y + 0.05, z, 0.9, 0.22, 1.9, giro))
            col = (0.8, 2.0)
        elif tipo < 0.58:
            # cruz celta
            alt = rnd.uniform(1.7, 2.3)
            pecas.extend(cruz(hx, y - 0.2, hz, alt=alt, larg=0.2, giro=giro, inclina=incl))
            c = (hx, y - 0.2 + alt * 0.72, hz)
            anel = []
            for k in range(13):
                a = 2 * math.pi * k / 12
                lx = 0.36 * math.cos(a)
                anel.append((c[0] + lx * ca, c[1] + 0.36 * math.sin(a), c[2] - lx * sa))
            pecas.append(tubo_redondo(anel, [0.06] * 13, n=5))
            col = (0.8, 0.8)
        elif tipo < 0.66:
            # obelisco
            alt = rnd.uniform(2.2, 3.6)
            pecas.append(caixa_girada(x, y + 0.25, z, 1.1, 0.9, 1.1, giro))
            pecas.append(cilindro(x, z, 0.42, y + 0.7, y + alt, n=4, fase=giro + math.pi / 4, raio_topo=0.24))
            pecas.append(espinho((x, y + alt, z), (x, y + alt + 0.5, z), 0.34, n=4))
            col = (1.1, 1.1)
        elif tipo < 0.80:
            # tumulo raso com tampa e uma lapidezinha
            pecas.append(caixa_girada(x, y + 0.2, z, 1.0, 0.6, 2.1, giro))
            pecas.append(caixa_girada(x, y + 0.55, z, 1.15, 0.12, 2.25, giro + rnd.uniform(-0.06, 0.06)))
            pecas.append(caixa_girada(hx, y + 0.6, hz, 0.7, 0.9, 0.14, giro, incl))
            col = (1.15, 2.3)
        elif tipo < 0.88:
            # sarcofago
            pecas.append(caixa_girada(x, y + 0.4, z, 1.15, 1.0, 2.3, giro))
            pecas.append(caixa_girada(x, y + 0.98, z, 1.3, 0.2, 2.45, giro))
            pecas.append(caixa_girada(x, y + 1.15, z, 0.9, 0.18, 2.0, giro))
            col = (1.3, 2.45)
        elif tipo < 0.94:
            # lapide tombada no chao
            px_, pz_ = P(0.0, -0.4)
            pecas.append(caixa_girada(px_, y + 0.1, pz_, 0.75, 0.16, 1.2, giro + rnd.uniform(-0.5, 0.5), 0.0))
            pecas.append(caixa_girada(hx, y + 0.12, hz, 0.75, 0.35, 0.17, giro))
            col = (0.0, 0.0)
        else:
            # anjinho em pedestal
            pecas.append(caixa_girada(x, y + 0.45, z, 0.9, 0.9, 0.9, giro))
            self.anjo(x, y + 0.9, z, 1.6, giro + math.pi, setor, partido=rnd.random() < 0.5)
            col = (0.9, 0.9)
        # sigilo aceso em poucas lapides
        if rnd.random() < 0.035 and tipo < 0.3:
            fx, fz = P(0.0, -0.84)
            self.m.add_pecas(setor, "sigilo", [caixa_girada(fx, y + 0.5, fz, 0.42, 0.42, 0.02, giro + math.pi / 4, incl)])
            self.pontos["sigilos"].append([round(fx, 2), round(y + 0.5, 2), round(fz, 2)])
        self.m.add_pecas(setor, mat, pecas)
        if col[0] > 0:
            self.col.append(caixa_girada(x, y + 0.5, z, col[0], 1.6, col[1], giro))
            self.bloquear(x, z, max(col) * 0.55)
        self.ocupar(x, z, 0.9, bloqueia=False)
        # cova aberta em algumas
        if rnd.random() < 0.035 and len(self.pontos["covas"]) < 7:
            self._cova(x + ca * 1.6, z - sa * 1.6, giro, setor)

    def _cova(self, x, z, giro, setor):
        y = altura(x, z)
        self.m.add_pecas(setor, "buraco", [caixa_girada(x, y + 0.01, z, 0.95, 0.04, 1.95, giro)])
        bx, bz = x + math.cos(giro) * 1.2, z - math.sin(giro) * 1.2
        self.m.add_pecas(setor, "terra_solta", [domo(bx, bz, 0.9, 0.55, n=9, aneis=2)])
        self._levantar(setor, "terra_solta", y)
        self.col.append(caixa_girada(x, y + 0.4, z, 1.1, 0.8, 2.1, giro))
        self.bloquear(x, z, 1.2)
        self.pontos["covas"].append([round(x, 2), round(y, 2), round(z, 2)])

    def _levantar(self, setor, mat, dy):
        g = self.m.grupos[(setor, mat)]
        marca = g.setdefault("_marca", 0)
        for i in range(marca, len(g["v"])):
            vx, vy, vz = g["v"][i]
            g["v"][i] = (vx, vy + dy, vz)
        g["_marca"] = len(g["v"])

    def horror(self):
        """Tentaculos saindo de tres covas no meio dos tumulos."""
        rnd = self.rnd
        feitos = 0
        for (x, z) in ((-30.0, 14.0), (33.0, -16.0), (-14.0, -32.0)):
            # acha um canto livre perto
            for _t in range(40):
                px, pz = x + rnd.uniform(-4, 4), z + rnd.uniform(-4, 4)
                if self.livre(px, pz, 1.8) and not no_caminho(px, pz):
                    break
            y = altura(px, pz)
            setor = self.setor_grade("horror", px, pz, SETOR)
            self.m.add_pecas(setor, "buraco", [cilindro(px, pz, 1.3, y - 0.05, y + 0.02, n=10)])
            self.m.add_pecas(setor, "terra_solta", entulho(px, pz, 1.8, 9, rnd, y=y, tamanho=(0.25, 0.6)))
            for k in range(3):
                a = rnd.uniform(0, 2 * math.pi)
                tentaculo(self, setor, "carne", (px + math.cos(a) * 0.5, y - 0.4, pz + math.sin(a) * 0.5),
                          (math.cos(a) * 0.35, 1.0, math.sin(a) * 0.35), rnd.uniform(3.5, 6.5), 0.32,
                          curva=1.0, fase=a, n=12, lados=7, ventosas="osso")
            self.col.append(cilindro(px, pz, 1.2, y - 0.2, y + 3.0, n=8))
            self.ocupar(px, pz, 1.8)
            self.pontos["covas"].append([round(px, 2), round(y, 2), round(pz, 2)])
            feitos += 1

    def longe(self):
        """A cidade sumindo na nevoa: casas, a torre da igreja, mata morta e
        uma coisa enorme la' atras."""
        rnd = self.rnd
        for k in range(70):
            a = rnd.uniform(0, 2 * math.pi)
            r = rnd.uniform(78.0, 150.0)
            x, z = r * math.sin(a), r * math.cos(a)
            y = altura(x, z) - 0.5
            larg = rnd.uniform(5.0, 10.0)
            alt = rnd.uniform(4.0, 9.0)
            giro = rnd.uniform(0, math.pi)
            self.m.add_pecas("longe", "silhueta", [caixa_girada(x, y + alt / 2, z, larg, alt, larg * 1.3, giro)])
            ca, sa = math.cos(giro), math.sin(giro)
            for s in (-1, 1):
                self.m.add_pecas("longe", "silhueta", [caixa_girada(x + ca * s * larg * 0.22, y + alt + larg * 0.18,
                                                                    z - sa * s * larg * 0.22, larg * 0.62, larg * 0.08,
                                                                    larg * 1.35, giro, 0.0)])
        silhueta_gotica(self, "longe", "silhueta", -30.0, -135.0, 14.0, 18.0, rnd, giro=0.3)
        self._levantar("longe", "silhueta", 0.0)
        # mata morta: espinhos finos
        for k in range(160):
            a = rnd.uniform(0, 2 * math.pi)
            r = rnd.uniform(66.0, 120.0)
            x, z = r * math.sin(a), r * math.cos(a)
            y = altura(x, z)
            alt = rnd.uniform(7.0, 16.0)
            self.m.add_pecas("mata", "silhueta", [espinho((x, y - 0.5, z),
                                                          (x + rnd.uniform(-1, 1), y + alt, z + rnd.uniform(-1, 1)),
                                                          rnd.uniform(0.25, 0.55), n=4)])
        # a coisa enorme na nevoa
        for (x, z, alt) in ((95.0, -160.0, 110.0), (-140.0, -70.0, 80.0)):
            tentaculo(self, "colosso", "silhueta", (x, -20.0, z), (0.05, 1.0, 0.1), alt, alt * 0.06,
                      curva=1.3, fase=x * 0.1, n=16, lados=8)


def _fita(p0, p1, larg, alt):
    dx, dz = p1[0] - p0[0], p1[2] - p0[2]
    d = math.hypot(dx, dz) or 1.0
    nx, nz = -dz / d * larg / 2.0, dx / d * larg / 2.0
    ex, ez = dx / d * larg * 0.3, dz / d * larg * 0.3
    a = (p0[0] - ex, p0[2] - ez)
    b = (p1[0] + ex, p1[2] + ez)
    y0, y1 = p0[1], p0[1] + alt
    return hexaedro([(a[0] + nx, y0, a[1] + nz), (b[0] + nx, y0, b[1] + nz),
                     (b[0] - nx, y0, b[1] - nz), (a[0] - nx, y0, a[1] - nz),
                     (a[0] + nx, y1, a[1] + nz), (b[0] + nx, y1, b[1] + nz),
                     (b[0] - nx, y1, b[1] - nz), (a[0] - nx, y1, a[1] - nz)])


def main():
    cem = Cemiterio()
    cem.montar()
    for g in cem.m.grupos.values():
        g.pop("_marca", None)
    cem.exportar("cemiterio", "cemiterio", abertos=("chao_", "fora_"))
    nav = cem.pontos["navmesh"]
    print("  navmesh: %d vertices, %d poligonos" % (len(nav["v"]), len(nav["p"])))
    print("  tumulos=%d covas=%d lanternas=%d sigilos=%d" % (
        cem.pontos["n_tumulos"], len(cem.pontos["covas"]), len(cem.pontos["lanternas"]),
        len(cem.pontos["sigilos"])))


if __name__ == "__main__":
    main()
