# -*- coding: utf-8 -*-
"""Modela a ARENA 3 — o Trono do Abismo — e exporta pro Godot.

    blender --background --factory-startup \\
        --python tools/blender/arena_3/gerar_arena_3.py

Saidas:
    red-valve/assets/3d_model/stages/battlefield_3/arena_3.glb
    red-valve/assets/3d_model/stages/battlefield_3/arena_3_pontos.json

Depois rode `tools/godot/arena_3/gerar_cena_arena_3.py` e reimporte com o
binario 4.6 (`--headless --import`): rodar a cena NAO reimporta o .glb.

==============================================================================
O LUGAR

A luta do ultimo chefe. A arena 1 e' uma plataforma no vazio, a 2 e' uma
praca no chao; a 3 junta as duas coisas e cresce: uma PRACA CIRCULAR de
105 m no topo de uma agulha de rocha, cercada de ABISMO, com o TRONO no
fundo — visivel ja' da ponte por onde o jogador chega.

                         N (-Z)
                  [halo]  TRONO  [halo]
          estatua    escadaria    estatua
      pilar                             pilar
    pilar        circulo de sigilo        pilar
      pilar                             pilar
                   portao + PONTE
                         S (+Z)   <- o jogador nasce na ponte

  - Praca de raio 52 com balaustrada quebrada na borda. Quem segura o
    jogador e' o muro invisivel no 52,6; a balaustrada e' cenario.
  - O trono fica num zigurate de tres patamares (2, 4 e 6 m) ao norte, com
    uma ESCADARIA de 14 m de largura — e' a unica subida (colisao de rampa,
    26 graus; degrau de verdade o CharacterBody3D nao sobe).
  - Atras do trono, um HALO de osso de 26 m na vertical, com espinhos e um
    anel de sigilo aceso: e' a silhueta que se ve' de longe ao chegar.
  - Catorze pilares compostos em volta (12 a 30 m), alguns ligados por
    ogivas, outros partidos: catedral sem teto, ceu aberto.

==============================================================================
"A ARENA NAO ACABA ALI"

O jogador nao sai, mas tudo em volta diz que o mundo continua:
  - pontes quebradas saindo pro leste, pro oeste e pro norte, morrendo na
    nevoa; a propria ponte de entrada continua atras dele, aos pedacos;
  - ilhas flutuantes com ruina, a 110-190 m;
  - uma cidade gotica inteira de silhuetas no horizonte (200-330 m);
  - colossos encapuzados de 120-200 m, tentaculos saindo do abismo e
    correntes que sobem pro ceu a partir do halo;
  - la' embaixo, a 90 m, o brilho de um mar de brasa.
"""

import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "cenarios"))

from base import (Cena, caixa, caixa_girada, centros_navmesh, chao_grade,  # noqa: E402
                  cilindro, colisao_grade, cruz, domo, entulho, espinho,
                  hexaedro, lerp, marcadores_em_volta, muro_invisivel,
                  navmesh_grade, pilar_composto, silhueta_gotica, tentaculo,
                  tubo, tubo_redondo)

# --------------------------------------------------------------------------
# medidas

R_PRACA = 52.0         # raio util
R_LIMITE = 52.6        # muro invisivel
R_BALAUSTRE = 53.4     # balaustrada (cenario)
R_PISO = 56.0          # ate' onde vai a laje (passa por baixo da balaustrada)
R_PILARES = 44.0
R_SIGILO = 15.0

PONTE_W = 6.0          # meia-largura da ponte
PONTE_Z0 = 50.0
PONTE_Z1 = 92.0
PONTE_FIM = 90.4       # muro invisivel atravessado na ponte
SPAWN = (0.0, 0.3, 84.0)

# zigurate do trono
ZIG_W = (20.0, 18.0, 16.0)          # meia-largura de cada patamar
ZIG_FRENTE = (-30.0, -33.0, -36.0)  # face sul de cada patamar
ZIG_FUNDO = -52.0
ZIG_H = (2.0, 4.0, 6.0)
ESC_W = 7.0            # meia-largura da escadaria
ESC_Z0 = -24.0         # pe' da escada (y = 0)
ESC_Z1 = -36.0         # topo (y = 6)
TRONO = (0.0, 6.0, -45.0)
HALO_C = (0.0, 21.0, -49.6)
HALO_R = 13.0

PASSO = 2.0
SETOR = 26.0

MATERIAIS = ("pedra", "pedra_esc", "osso", "carne", "metal", "brasa", "sigilo",
             "silhueta", "rocha", "abismo")


def dentro_limite(x, z, folga=0.0):
    """O poligono do muro invisivel: circulo + corredor da ponte."""
    if x * x + z * z <= (R_LIMITE - folga) ** 2:
        return True
    return abs(x) <= PONTE_W - 0.4 - folga and 0.0 < z <= PONTE_FIM - folga


def na_escada(x, z):
    return abs(x) <= ESC_W and ESC_Z1 <= z <= ESC_Z0


def no_topo(x, z):
    return abs(x) <= ZIG_W[2] and ZIG_FUNDO + 2.0 <= z <= ZIG_FRENTE[2]


def altura(x, z):
    if na_escada(x, z):
        return ZIG_H[2] * (ESC_Z0 - z) / (ESC_Z0 - ESC_Z1)
    if no_topo(x, z):
        return ZIG_H[2]
    return 0.0


def no_zigurate(x, z):
    """Pegada dos patamares que NAO sao caminho (os flancos)."""
    for k in range(3):
        if abs(x) <= ZIG_W[k] and ZIG_FUNDO <= z <= ZIG_FRENTE[k]:
            return True
    return False


def ogiva_pontos(p0, p1, altura_arco, n=10):
    """Polilinha de arco OGIVAL entre dois pontos: dois arcos que se cruzam
    na ponta, como a janela de catedral."""
    pts = []
    for i in range(n + 1):
        t = i / n
        # meia-ogiva: seno esticado com bico no meio
        s = 1.0 - abs(1.0 - 2.0 * t)
        y = altura_arco * (1.0 - (1.0 - s) ** 1.7)
        pts.append((lerp(p0[0], p1[0], t), lerp(p0[1], p1[1], t) + y,
                    lerp(p0[2], p1[2], t)))
    return pts


class Arena3(Cena):

    def __init__(self):
        super().__init__("ar3", 20261026)
        self.pontos = {
            "player": list(SPAWN),
            "trono": [TRONO[0], TRONO[1] + 1.2, TRONO[2]],
            "chefe": [0.0, ZIG_H[2] + 0.2, -39.0],
            "halo": list(HALO_C),
            "braseiros": [],
            "pousos": [],
            "inimigos": [],
            "chuva_fogo": {"centro": [0.0, 0.0, 6.0], "raio": 44.0},
            "redemoinhos": [],
            "navmesh": {"v": [], "p": []},
        }

    # ------------------------------------------------------------------
    def montar(self):
        self.piso()
        self.sigilo()
        self.rachaduras()
        self.zigurate()
        self.trono()
        self.halo()
        self.estatuas()
        self.pilares()
        self.balaustrada()
        self.penhasco()
        self.portao()
        self.ponte()
        self.cobertura()
        self.longe()
        self.cercadura()
        self.pontos["navmesh"] = navmesh_grade(
            self, -R_LIMITE, R_LIMITE, -R_LIMITE, PONTE_FIM, PASSO, altura,
            # a escadaria sobe 1 m a cada celula de 2 m (26 graus): limite menor
            # que isso deixa o patamar do trono como ilha e ele e' descartado
            self._caminhavel, max_desnivel=1.25)
        self.pontos["inimigos"] = marcadores_em_volta(
            self.pontos["navmesh"], (0.0, 4.0), 27.0, 12)
        self._redemoinhos()

    def _caminhavel(self, x, z):
        if not dentro_limite(x, z, 0.8):
            return False
        if na_escada(x, z) or no_topo(x, z):
            return not (abs(x - TRONO[0]) < 5.0 and abs(z - TRONO[2]) < 4.0)
        return not no_zigurate(x, z)

    # ------------------------------------------------------------------
    # chao
    def piso(self):
        def classe(xc, zc):
            r = math.hypot(xc, zc)
            na_ponte = abs(xc) <= PONTE_W and 0.0 < zc <= PONTE_Z1
            if r > R_PISO and not na_ponte:
                return None
            if na_ponte and r > R_PISO - 2.0:
                return "pedra"
            if r < R_SIGILO + 1.0:
                return "pedra_esc"
            # anel de lajota clara em volta do sigilo e na borda; o resto, a
            # pedra comum — e' o desenho que se le' de cima
            if R_SIGILO + 1.0 <= r < R_SIGILO + 4.0 or R_PISO - 5.0 < r:
                return "osso"
            return "pedra"

        grupos = chao_grade(self, -R_PISO - 2, R_PISO + 2, -R_PISO - 2, PONTE_Z1 + 2,
                            PASSO, lambda x, z: 0.0, classe, SETOR, "praca", esp=0.8)
        celulas = set()
        for cel in grupos.values():
            celulas.update(cel)
        colisao_grade(self, celulas, PASSO, lambda x, z: 0.0, esp=2.0)
        # o fundo do abismo, so' pra nada cair pro infinito
        self.col.append(caixa((-400.0, -122.0, -400.0), (400.0, -118.0, 400.0)))

    def sigilo(self):
        """O circulo de sigilo no meio da praca. Fita fina de emissao no
        chao (3 cm), sem colisao: e' desenho, nao degrau."""
        pecas = []
        for r, larg, n in ((R_SIGILO, 0.32, 96), (R_SIGILO - 1.4, 0.18, 88),
                           (8.0, 0.24, 56), (3.2, 0.2, 28)):
            for k in range(n):
                if r > 10 and k % 11 == 5:
                    continue    # o anel e' quebrado: falha a cada tanto
                a0 = 2 * math.pi * k / n
                a1 = 2 * math.pi * (k + 1) / n
                p0 = (r * math.sin(a0), 0.0, r * math.cos(a0))
                p1 = (r * math.sin(a1), 0.0, r * math.cos(a1))
                pecas.append(_fita(p0, p1, larg, 0.03))
        # raios e glifos entre os aneis
        for k in range(9):
            a = 2 * math.pi * k / 9 + 0.2
            p0 = (8.3 * math.sin(a), 0.0, 8.3 * math.cos(a))
            p1 = ((R_SIGILO - 1.7) * math.sin(a), 0.0, (R_SIGILO - 1.7) * math.cos(a))
            pecas.append(_fita(p0, p1, 0.2, 0.03))
            # glifo: tres tracos tortos
            gx, gz = (R_SIGILO - 0.7) * math.sin(a + 0.35), (R_SIGILO - 0.7) * math.cos(a + 0.35)
            for g in range(3):
                ang = a + g * 1.1
                pecas.append(caixa_girada(gx + 0.25 * math.cos(ang), 0.015, gz + 0.25 * math.sin(ang),
                                          0.9, 0.03, 0.12, ang))
        # o "olho" no centro
        pecas.append(cilindro(0.0, 0.0, 1.1, 0.0, 0.035, n=20))
        self.m.add_pecas("sigilo", "sigilo", pecas)

    def rachaduras(self):
        """Fendas acesas no piso, saindo do trono pra praca toda."""
        rnd = self.rnd
        pecas = []
        for k in range(11):
            a = math.pi + rnd.uniform(-1.4, 1.4)
            r = rnd.uniform(17.0, 22.0)
            x, z = r * math.sin(a), r * math.cos(a)
            ang = math.atan2(-z, -x) + rnd.uniform(-0.8, 0.8)
            for s in range(rnd.randint(5, 9)):
                comp = rnd.uniform(1.2, 2.8)
                nx, nz = x + math.cos(ang) * comp, z + math.sin(ang) * comp
                if math.hypot(nx, nz) > R_PRACA - 3 or no_zigurate(nx, nz):
                    break
                pecas.append(_fita((x, 0.0, z), (nx, 0.0, nz), rnd.uniform(0.08, 0.22), 0.02))
                x, z = nx, nz
                ang += rnd.uniform(-0.7, 0.7)
        self.m.add_pecas("fendas", "brasa", pecas)

    # ------------------------------------------------------------------
    # o trono
    def zigurate(self):
        pecas, col = [], []
        for k in range(3):
            y0 = 0.0 if k == 0 else ZIG_H[k - 1] - 0.08
            # corpo do patamar termina 8 cm ANTES do tampo e a capa de cima e'
            # que chega no plano (licao do z-fight da arena 2)
            p0 = (-ZIG_W[k], y0, ZIG_FUNDO)
            p1 = (ZIG_W[k], ZIG_H[k] - 0.12, ZIG_FRENTE[k])
            pecas.append(caixa(p0, p1))
            col.append(caixa((-ZIG_W[k], 0.0, ZIG_FUNDO), (ZIG_W[k], ZIG_H[k], ZIG_FRENTE[k])))
            self.m.add_pecas("zigurate", "pedra_esc", [caixa(
                (-ZIG_W[k] - 0.15, ZIG_H[k] - 0.12, ZIG_FUNDO - 0.15),
                (ZIG_W[k] + 0.15, ZIG_H[k], ZIG_FRENTE[k] + 0.15))])
            # nichos com caveira de pedra na face sul de cada patamar
            for s in (-1, 1):
                for n in range(3):
                    nx = s * (ESC_W + 2.0 + n * 3.6)
                    if abs(nx) > ZIG_W[k] - 1.0:
                        continue
                    yc = (y0 + ZIG_H[k]) / 2.0
                    self.m.add_pecas("zigurate", "osso", [
                        cilindro(nx, ZIG_FRENTE[k] + 0.1, 0.42, yc - 0.3, yc + 0.25, n=8),
                        caixa((nx - 0.25, yc - 0.55, ZIG_FRENTE[k] - 0.05),
                              (nx + 0.25, yc - 0.3, ZIG_FRENTE[k] + 0.35))])
        self.m.add_pecas("zigurate", "pedra", pecas)
        self.col.extend(col)

        # escadaria: degrau de verdade no desenho, rampa na colisao
        n = 20
        degraus = []
        for i in range(n):
            za = ESC_Z0 - (ESC_Z0 - ESC_Z1) * i / n
            zb = ESC_Z0 - (ESC_Z0 - ESC_Z1) * (i + 1) / n
            ya = ZIG_H[2] * (i + 1) / n
            degraus.append(caixa((-ESC_W, 0.0, zb), (ESC_W, ya - 0.04, za)))
            degraus.append(caixa((-ESC_W, ya - 0.04, zb - 0.02), (ESC_W, ya, za + 0.04)))
        self.m.add_pecas("escada", "pedra", degraus)
        # guarda-corpo: duas muretas inclinadas com pinaculo no pe'
        for s in (-1, 1):
            x0, x1 = s * ESC_W, s * (ESC_W + 0.9)
            xa, xb = min(x0, x1), max(x0, x1)
            self.m.add_pecas("escada", "pedra_esc", [hexaedro([
                (xa, 0.0, ESC_Z0 + 1.5), (xb, 0.0, ESC_Z0 + 1.5),
                (xb, 0.0, ESC_Z1), (xa, 0.0, ESC_Z1),
                (xa, 1.4, ESC_Z0 + 1.5), (xb, 1.4, ESC_Z0 + 1.5),
                (xb, ZIG_H[2] + 1.2, ESC_Z1), (xa, ZIG_H[2] + 1.2, ESC_Z1)])])
            px = s * (ESC_W + 0.45)
            self.m.add_pecas("escada", "pedra_esc", [
                caixa((px - 0.8, 0.0, ESC_Z0 + 0.7), (px + 0.8, 3.2, ESC_Z0 + 2.3)),
                espinho((px, 3.2, ESC_Z0 + 1.5), (px, 6.4, ESC_Z0 + 1.5), 0.8, n=4)])
            self.col.append(caixa((min(x0, x1), 0.0, ESC_Z1), (max(x0, x1), ZIG_H[2] + 1.2, ESC_Z0 + 2.3)))
        # rampa de colisao (prisma fechado), com lingueta que entra no topo
        self.col.append(hexaedro([
            (-ESC_W, -0.5, ESC_Z0 + 0.4), (ESC_W, -0.5, ESC_Z0 + 0.4),
            (ESC_W, -0.5, ESC_Z1 - 1.0), (-ESC_W, -0.5, ESC_Z1 - 1.0),
            (-ESC_W, 0.0, ESC_Z0 + 0.4), (ESC_W, 0.0, ESC_Z0 + 0.4),
            (ESC_W, ZIG_H[2], ESC_Z1 - 1.0), (-ESC_W, ZIG_H[2], ESC_Z1 - 1.0)]))
        self.col.append(caixa((-ESC_W, -0.5, ESC_Z1 - 1.0), (ESC_W, ZIG_H[2], ESC_Z1)))

        # braseiros: dois no pe' da escada, dois na frente do topo
        for p in ((-ESC_W - 3.5, 0.0, ESC_Z0 + 1.0), (ESC_W + 3.5, 0.0, ESC_Z0 + 1.0),
                  (-ZIG_W[2] + 3.0, ZIG_H[2], ZIG_FRENTE[2] - 1.6),
                  (ZIG_W[2] - 3.0, ZIG_H[2], ZIG_FRENTE[2] - 1.6)):
            self.braseiro(*p)

    def braseiro(self, x, y, z, setor="braseiros"):
        pecas = []
        for k in range(3):
            a = 2 * math.pi * k / 3 + 0.3
            pecas.append(tubo([(x + 0.9 * math.cos(a), y, z + 0.9 * math.sin(a)),
                               (x + 0.35 * math.cos(a), y + 1.3, z + 0.35 * math.sin(a))],
                              0.12, 0.12))
        pecas.append(cilindro(x, z, 0.55, y + 1.15, y + 1.55, n=10, raio_topo=1.05))
        self.m.add_pecas(setor, "metal", pecas)
        self.m.add_pecas(setor, "brasa", [cilindro(x, z, 0.85, y + 1.45, y + 1.6, n=10, raio_topo=0.7)])
        self.col.append(cilindro(x, z, 0.75, y, y + 1.6, n=8))
        self.bloquear(x, z, 1.1)
        self.pontos["braseiros"].append([x, y + 1.7, z])

    def trono(self):
        x, y, z = TRONO
        pecas_esc, pecas_osso, pecas_metal = [], [], []
        # plinto em dois degraus
        pecas_esc.append(caixa((x - 5.0, y, z - 3.6), (x + 5.0, y + 0.6, z + 3.6)))
        pecas_esc.append(caixa((x - 4.0, y + 0.6, z - 3.0), (x + 4.0, y + 1.2, z + 2.6)))
        y1 = y + 1.2
        # assento
        pecas_esc.append(caixa((x - 2.6, y1, z - 1.6), (x + 2.6, y1 + 2.4, z + 1.8)))
        pecas_osso.append(caixa((x - 2.4, y1 + 2.4, z - 1.4), (x + 2.4, y1 + 2.7, z + 1.9)))
        # bracos com caveira na ponta
        for s in (-1, 1):
            bx = x + s * 2.9
            pecas_esc.append(caixa((bx - 0.55, y1, z - 1.5), (bx + 0.55, y1 + 3.6, z + 2.0)))
            pecas_osso.append(cilindro(bx, z + 1.9, 0.62, y1 + 3.3, y1 + 4.3, n=10, raio_topo=0.45))
            pecas_osso.append(caixa((bx - 0.35, y1 + 3.0, z + 1.9), (bx + 0.35, y1 + 3.35, z + 2.45)))
            # chifres que saem do braco
            pecas_osso.append(espinho((bx, y1 + 4.0, z + 1.8), (bx + s * 1.6, y1 + 6.4, z + 2.8), 0.28))
        # encosto: laje alta terminando em ogiva, com dois pinaculos
        topo = y1 + 15.5
        pecas_esc.append(caixa((x - 2.7, y1, z - 2.4), (x + 2.7, topo - 3.0, z - 1.3)))
        for i in range(8):
            t0, t1 = i / 8.0, (i + 1) / 8.0
            w0 = 2.7 * (1.0 - t0 ** 1.4)
            w1 = 2.7 * (1.0 - t1 ** 1.4)
            ya, yb = topo - 3.0 + 3.0 * t0, topo - 3.0 + 3.0 * t1 + 0.02
            pecas_esc.append(hexaedro([(x - w0, ya, z - 2.4), (x + w0, ya, z - 2.4),
                                       (x + w0, ya, z - 1.3), (x - w0, ya, z - 1.3),
                                       (x - w1, yb, z - 2.4), (x + w1, yb, z - 2.4),
                                       (x + w1, yb, z - 1.3), (x - w1, yb, z - 1.3)]))
        pecas_osso.append(espinho((x, topo - 0.2, z - 1.85), (x, topo + 5.0, z - 1.85), 0.5, n=6))
        for s in (-1, 1):
            px = x + s * 3.4
            pecas_esc.append(caixa((px - 0.6, y1, z - 2.6), (px + 0.6, y1 + 11.0, z - 1.4)))
            pecas_esc.append(caixa((px - 0.8, y1 + 11.0, z - 2.8), (px + 0.8, y1 + 11.5, z - 1.2)))
            pecas_osso.append(espinho((px, y1 + 11.5, z - 2.0), (px, y1 + 16.5, z - 2.0), 0.6, n=4))
            for k in range(3):
                pecas_osso.append(espinho((px + s * 0.6, y1 + 3.0 + k * 3.0, z - 2.0),
                                          (px + s * 2.6, y1 + 4.4 + k * 3.0, z - 2.0), 0.22, n=4))
        # janela de sigilo no encosto (emissao, vista de longe)
        sig = []
        for i in range(10):
            t0, t1 = i / 10.0, (i + 1) / 10.0
            w0 = 1.1 * (1.0 - t0 ** 1.6)
            w1 = 1.1 * (1.0 - t1 ** 1.6)
            ya, yb = y1 + 5.0 + 6.0 * t0, y1 + 5.0 + 6.0 * t1 + 0.01
            sig.append(hexaedro([(x - w0, ya, z - 1.32), (x + w0, ya, z - 1.32),
                                 (x + w0, ya, z - 1.22), (x - w0, ya, z - 1.22),
                                 (x - w1, yb, z - 1.32), (x + w1, yb, z - 1.32),
                                 (x + w1, yb, z - 1.22), (x - w1, yb, z - 1.22)]))
        self.m.add_pecas("trono", "pedra_esc", pecas_esc)
        self.m.add_pecas("trono", "osso", pecas_osso)
        self.m.add_pecas("trono", "sigilo", sig)
        # tapete de carne escorrendo do assento pelos degraus do plinto
        self.m.add_pecas("trono", "carne", [
            caixa((x - 1.5, y + 0.01, z + 1.8), (x + 1.5, y + 0.07, z + 3.62)),
            caixa((x - 1.5, y + 0.6, z + 1.8), (x + 1.5, y + 0.66, z + 2.62))])
        # velas em volta do plinto
        velas = []
        for k in range(26):
            a = math.pi * k / 25.0
            vx, vz = x + 5.6 * math.cos(a), z + 4.2 * math.sin(a) * 0.9 + 0.6
            h = 0.25 + 0.6 * ((k * 7) % 5) / 5.0
            velas.append(cilindro(vx, vz, 0.09, y, y + h, n=6))
        self.m.add_pecas("trono", "osso", velas)
        self.col.append(caixa((x - 5.0, y, z - 3.6), (x + 5.0, y + 1.2, z + 3.6)))
        self.col.append(caixa((x - 3.5, y + 1.2, z - 2.6), (x + 3.5, y + 6.0, z + 2.0)))

    def halo(self):
        cx, cy, cz = HALO_C
        n = 48
        anel = []
        for k in range(n + 1):
            a = 2 * math.pi * k / n
            anel.append((cx + HALO_R * math.sin(a), cy + HALO_R * math.cos(a), cz))
        self.m.add_pecas("halo", "osso", [tubo_redondo(anel, [1.0] * len(anel), n=8, fechar=True)],
                         suave=True)
        anel2 = [(cx + (HALO_R - 1.9) * math.sin(2 * math.pi * k / n), cy + (HALO_R - 1.9) * math.cos(2 * math.pi * k / n), cz + 0.3)
                 for k in range(n + 1)]
        self.m.add_pecas("halo", "sigilo", [tubo_redondo(anel2, [0.22] * len(anel2), n=6)])
        espinhos = []
        for k in range(36):
            a = 2 * math.pi * k / 36
            longo = 9.0 if k % 2 == 0 else 4.5
            if k % 6 == 3:
                longo = 13.0
            b = (cx + (HALO_R + 0.6) * math.sin(a), cy + (HALO_R + 0.6) * math.cos(a), cz)
            p = (cx + (HALO_R + longo) * math.sin(a + 0.04), cy + (HALO_R + longo) * math.cos(a + 0.04),
                 cz - 0.5)
            espinhos.append(espinho(b, p, 0.55 if longo > 5 else 0.35, n=5))
        # raios internos: costelas que vao do anel ate' o encosto
        for k in range(12):
            a = 2 * math.pi * k / 12 + 0.13
            p0 = (cx + (HALO_R - 0.5) * math.sin(a), cy + (HALO_R - 0.5) * math.cos(a), cz)
            p1 = (cx + 3.0 * math.sin(a), cy + 3.0 * math.cos(a), cz + 1.4)
            espinhos.append(tubo_redondo([p0, ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, cz - 0.6), p1],
                                         [0.32, 0.26, 0.18], n=6))
        self.m.add_pecas("halo", "osso", espinhos)
        # correntes que sobem do halo pro ceu
        for s in (-1, 1):
            p0 = (cx + s * 9.0, cy + 9.5, cz)
            p1 = (cx + s * 70.0, 240.0, cz - 120.0)
            elos = []
            for i in range(60):
                t = i / 60.0
                px = lerp(p0[0], p1[0], t)
                py = lerp(p0[1], p1[1], t) - math.sin(math.pi * t) * 18.0
                pz = lerp(p0[2], p1[2], t)
                if i % 2 == 0:
                    elos.append(caixa_girada(px, py, pz, 0.9, 2.2, 0.32, 0.4 * s, 0.6))
                else:
                    elos.append(caixa_girada(px, py, pz, 0.32, 2.2, 0.9, 0.4 * s, 0.6))
            self.m.add_pecas("correntes", "metal", elos)
        # o halo e' preso ao fundo do patamar por dois mastros
        for s in (-1, 1):
            self.m.add_pecas("halo", "pedra_esc", [
                caixa((cx + s * 8.0 - 0.8, ZIG_H[2], cz - 1.0), (cx + s * 8.0 + 0.8, cy - 8.0, cz + 1.0))])
            self.col.append(caixa((cx + s * 8.0 - 0.8, ZIG_H[2], cz - 1.0), (cx + s * 8.0 + 0.8, cy - 8.0, cz + 1.0)))

    def estatuas(self):
        """Os dois colossos encapuzados que guardam o trono."""
        for s in (-1, 1):
            x, z = s * 27.0, -40.0
            self.estatua(x, 0.0, z, 26.0, math.atan2(-x, 12.0 - z), "estatua_%s" % ("w" if s < 0 else "e"),
                         lanterna=(s > 0))
            self.col.append(caixa((x - 3.2, 0.0, z - 3.2), (x + 3.2, 3.0, z + 3.2)))
            self.col.append(cilindro(x, z, 2.6, 3.0, 20.0, n=10))
            self.bloquear(x, z, 4.2)

    def estatua(self, x, y, z, alt, giro, setor, lanterna=False, mat="pedra", base=True):
        """Figura encapuzada: tunica em cone, capuz pontudo caido pra frente,
        bracos segurando uma espada fincada (ou uma lanterna)."""
        ca, sa = math.cos(giro), math.sin(giro)

        def P(lx, ly, lz):
            # local: +Z = frente da estatua
            return (x + lx * ca + lz * sa, y + ly, z - lx * sa + lz * ca)

        pecas, escuro, metal, luz = [], [], [], []
        h = alt
        if base:
            pecas.append(caixa_girada(x, y + 1.5, z, 6.4, 3.0, 6.4, giro))
            pecas.append(caixa_girada(x, y + 3.2, z, 5.4, 0.4, 5.4, giro))
            y0 = 3.4
        else:
            y0 = 0.0
        r0 = h * 0.16
        pecas.append(cilindro(x, z, r0, y + y0, y + y0 + h * 0.55, n=14, raio_topo=r0 * 0.62))
        pecas.append(cilindro(x, z, r0 * 0.62, y + y0 + h * 0.55, y + y0 + h * 0.74, n=12,
                              raio_topo=r0 * 0.78))
        # ombros
        pecas.append(caixa_girada(*P(0.0, y0 + h * 0.76, 0.0), h * 0.34, h * 0.06, h * 0.16, giro))
        # capuz: cone torto pra frente
        hc = P(0.0, y0 + h * 0.80, h * 0.02)
        tip = P(0.0, y0 + h * 1.0, h * 0.09)
        pecas.append(tubo_redondo([hc, P(0.0, y0 + h * 0.9, h * 0.06), tip],
                                  [h * 0.1, h * 0.075, 0.05], n=10))
        escuro.append(caixa_girada(*P(0.0, y0 + h * 0.86, h * 0.085), h * 0.1, h * 0.09, h * 0.03, giro))
        # bracos dobrados na frente
        for s in (-1, 1):
            om = P(s * h * 0.15, y0 + h * 0.75, 0.0)
            co = P(s * h * 0.17, y0 + h * 0.6, h * 0.08)
            mao = P(s * h * 0.03, y0 + h * 0.55, h * 0.17)
            pecas.append(tubo_redondo([om, co, mao], [h * 0.05, h * 0.045, h * 0.035], n=8))
        if lanterna:
            # mao direita estendida segurando uma lanterna acesa
            om = P(h * 0.15, y0 + h * 0.75, 0.0)
            mao = P(h * 0.3, y0 + h * 0.62, h * 0.24)
            pecas.append(tubo_redondo([om, mao], [h * 0.05, h * 0.035], n=8))
            lx, ly, lz = mao
            metal.append(tubo([(lx, ly, lz), (lx, ly - h * 0.08, lz)], 0.18, 0.18))
            metal.append(caixa((lx - 0.9, ly - h * 0.08 - 2.0, lz - 0.9), (lx + 0.9, ly - h * 0.08 - 1.8, lz + 0.9)))
            metal.append(caixa((lx - 0.9, ly - h * 0.08 - 0.2, lz - 0.9), (lx + 0.9, ly - h * 0.08, lz + 0.9)))
            luz.append(caixa((lx - 0.7, ly - h * 0.08 - 1.8, lz - 0.7), (lx + 0.7, ly - h * 0.08 - 0.2, lz + 0.7)))
            self.pontos.setdefault("lanternas", []).append([lx, ly - h * 0.08 - 1.0, lz])
        else:
            # espada fincada: lamina da mao ao pedestal — ou ate' o CHAO, quando
            # ela cai na frente dele (o colosso de 26 m: a ponta ficava 1,45 m
            # no ar, 2 m a frente do pedestal)
            mx, my, mz = P(0.0, y0 + h * 0.56, h * 0.2)
            fundo = y + y0 - h * 0.05 if (not base or h * 0.2 < 3.2) else y - 0.3
            metal.append(caixa_girada(mx, (fundo + my) / 2.0, mz, h * 0.035,
                                      my - fundo, h * 0.012, giro))
            metal.append(caixa_girada(mx, my + h * 0.02, mz, h * 0.16, h * 0.02, h * 0.03, giro))
            metal.append(caixa_girada(mx, my + h * 0.07, mz, h * 0.025, h * 0.08, h * 0.025, giro))
        self.m.add_pecas(setor, mat, pecas, suave=False)
        self.m.add_pecas(setor, "pedra_esc", escuro)
        if metal:
            self.m.add_pecas(setor, "metal", metal)
        if luz:
            self.m.add_pecas(setor, "sigilo", luz)

    # ------------------------------------------------------------------
    # o anel de pilares
    def pilares(self):
        rnd = self.rnd
        angs = []
        for k in range(18):
            a = 2 * math.pi * k / 18 + math.pi / 18
            # nem na frente do portao, nem atras do zigurate
            if abs(math.atan2(math.sin(a), math.cos(a))) < 0.32:
                continue
            if abs(math.atan2(math.sin(a - math.pi), math.cos(a - math.pi))) < 0.62:
                continue
            angs.append(a)
        topos = []
        for i, a in enumerate(angs):
            x, z = R_PILARES * math.sin(a), R_PILARES * math.cos(a)
            inteiro = (i % 3 != 1)
            h = rnd.uniform(24.0, 30.0) if inteiro else rnd.uniform(11.0, 17.0)
            setor = "pilar_%d" % i
            base = [caixa((x - 2.0, 0.0, z - 2.0), (x + 2.0, 1.6, z + 2.0)),
                    caixa((x - 1.75, 1.6, z - 1.75), (x + 1.75, 2.2, z + 1.75))]
            self.m.add_pecas(setor, "pedra_esc", base)
            self.m.add_pecas(setor, "pedra", pilar_composto(x, z, 2.2, h, r_nucleo=1.05,
                                                            r_colunete=0.36)[0])
            if inteiro:
                self.m.add_pecas(setor, "pedra_esc", [
                    caixa((x - 1.9, h, z - 1.9), (x + 1.9, h + 0.9, z + 1.9)),
                    caixa((x - 1.6, h + 0.9, z - 1.6), (x + 1.6, h + 1.3, z + 1.6))])
                topo = h + 1.3
                # pinaculo de canto (deixa o meio livre pra gargula pousar)
                for cx_, cz_ in ((-1.3, -1.3), (1.3, 1.3)):
                    self.m.add_pecas(setor, "pedra_esc", [espinho((x + cx_, topo, z + cz_),
                                                                  (x + cx_, topo + 3.4, z + cz_), 0.32, n=4)])
                self.pontos["pousos"].append([round(x, 2), round(topo, 2), round(z, 2)])
            else:
                # partido: topo serrilhado e tambor caido no pe'
                for k in range(5):
                    self.m.add_pecas(setor, "pedra", [caixa_girada(
                        x + rnd.uniform(-0.8, 0.8), h + rnd.uniform(0.0, 1.4), z + rnd.uniform(-0.8, 0.8),
                        rnd.uniform(0.6, 1.2), rnd.uniform(0.6, 1.8), rnd.uniform(0.6, 1.2),
                        rnd.uniform(0, 3), rnd.uniform(-0.3, 0.3), rnd, 0.3)])
                topo = h + 1.0
                self.pontos["pousos"].append([round(x, 2), round(h + 0.2, 2), round(z, 2)])
                ang = a + math.pi + rnd.uniform(-0.6, 0.6)
                dx, dz = math.sin(ang), math.cos(ang)
                p0 = (x + dx * 3.0, 1.0, z + dz * 3.0)
                p1 = (x + dx * 9.5, 1.0, z + dz * 9.5)
                self.m.add_pecas(setor, "pedra", [tubo_redondo([p0, p1], [1.0, 1.0], n=10)])
                self.m.add_pecas(setor, "pedra", entulho(x + dx * 2.5, z + dz * 2.5, 2.2, 7, rnd,
                                                         tamanho=(0.4, 1.0)))
                self.col.append(tubo_redondo([p0, p1], [1.0, 1.0], n=8))
                self.bloquear_linha(p0[0], p0[2], p1[0], p1[2], 1.2)
            topos.append((x, z, topo, inteiro))
            self.col.append(cilindro(x, z, 2.0, 0.0, 14.0, n=8))
            self.bloquear(x, z, 2.3)
        # ogivas ligando pilares inteiros vizinhos
        for i in range(len(topos)):
            a, b = topos[i], topos[(i + 1) % len(topos)]
            if not (a[3] and b[3]):
                continue
            if math.hypot(a[0] - b[0], a[1] - b[1]) > 20.0:
                continue
            y = min(a[2], b[2]) - 6.0
            pts = ogiva_pontos((a[0], y, a[1]), (b[0], y, b[1]), 6.5, n=12)
            self.m.add_pecas("ogivas", "pedra", [tubo(pts, 1.1, 1.3)])

    def balaustrada(self):
        """Mureta baixa na borda, quebrada em varios pontos. Cenario: quem
        segura e' o muro invisivel."""
        rnd = self.rnd
        n = 120
        for k in range(n):
            a0 = 2 * math.pi * k / n
            a1 = 2 * math.pi * (k + 1) / n
            am = (a0 + a1) / 2
            x0, z0 = R_BALAUSTRE * math.sin(a0), R_BALAUSTRE * math.cos(a0)
            x1, z1 = R_BALAUSTRE * math.sin(a1), R_BALAUSTRE * math.cos(a1)
            xm, zm = (x0 + x1) / 2, (z0 + z1) / 2
            if abs(xm) < PONTE_W + 2.5 and zm > 0:
                continue
            if no_zigurate(xm, zm) or no_zigurate(xm * 0.97, zm * 0.97):
                continue
            setor = "borda_%d" % int(am / (math.pi / 4))
            if k % 4 == 0:
                self.m.add_pecas(setor, "pedra_esc", [
                    caixa_girada(xm, 0.75, zm, 0.8, 1.5, 0.8, am),
                    espinho((xm, 1.5, zm), (xm, 2.6, zm), 0.36, n=4)])
            if rnd.random() < 0.16:
                # pedaco caido pra dentro
                self.m.add_pecas(setor, "pedra", [caixa_girada(
                    xm * 0.97, 0.25, zm * 0.97, 2.2, 0.5, 0.4, am + rnd.uniform(-0.5, 0.5),
                    rnd.uniform(-0.2, 0.2), rnd, 0.2)])
                continue
            alt = 1.05 if rnd.random() > 0.2 else rnd.uniform(0.35, 0.8)
            self.m.add_pecas(setor, "pedra", [hexaedro([
                (x0 * 0.997, 0.0, z0 * 0.997), (x1 * 0.997, 0.0, z1 * 0.997),
                (x1 * 1.003, 0.0, z1 * 1.003), (x0 * 1.003, 0.0, z0 * 1.003),
                (x0 * 0.997, alt, z0 * 0.997), (x1 * 0.997, alt, z1 * 0.997),
                (x1 * 1.003, alt, z1 * 1.003), (x0 * 1.003, alt, z0 * 1.003)])])

    def penhasco(self):
        """A beira de rocha que despenca pro abismo. Visto de dentro da
        praca e' o recorte serrilhado do chao contra o vazio."""
        rnd = self.rnd
        n = 70
        for k in range(n):
            a = 2 * math.pi * k / n + rnd.uniform(-0.03, 0.03)
            if abs(math.sin(a) * R_PISO) < PONTE_W + 1.5 and math.cos(a) > 0:
                continue
            setor = "penhasco_%d" % int(a / (math.pi / 3))
            for camada in range(3):
                r = R_PISO + 0.5 + camada * 2.5 + rnd.uniform(-1.0, 1.0)
                x, z = r * math.sin(a), r * math.cos(a)
                s = rnd.uniform(4.0, 7.5) + camada * 2.0
                alt = s * rnd.uniform(1.6, 3.2)
                # o topo da primeira camada fica ABAIXO do piso (um ou outro
                # dente aparece, longe da ponte): pedra alta na beira virava
                # uma cerca de piramides pretas tampando o abismo
                topo = -0.6 - camada * 12.0 - rnd.uniform(0.0, 4.0)
                if camada == 0 and rnd.random() < 0.18 and math.cos(a) < 0.6:
                    topo = rnd.uniform(0.4, 2.2)
                self.m.add_pecas(setor, "rocha", [caixa_girada(
                    x, topo - alt / 2.0, z, s, alt, s * rnd.uniform(0.8, 1.4),
                    a + rnd.uniform(-0.4, 0.4), rnd.uniform(-0.12, 0.12), rnd, 0.35)])
        # a agulha de rocha que segura tudo, descendo pro brilho
        self.m.add_pecas("agulha", "rocha", [cilindro(0.0, 0.0, R_PISO + 1.0, -70.0, -2.5, n=28,
                                                      raio_topo=R_PISO + 0.5),
                                             cilindro(0.0, 0.0, 28.0, -150.0, -70.0, n=20,
                                                      raio_topo=R_PISO + 1.0)])

    def portao(self):
        z = R_BALAUSTRE - 0.5
        for s in (-1, 1):
            x = s * (PONTE_W + 2.8)
            setor = "portao"
            self.m.add_pecas(setor, "pedra", [
                caixa((x - 2.6, 0.0, z - 2.6), (x + 2.6, 18.0, z + 2.6)),
                caixa((x - 3.0, 18.0, z - 3.0), (x + 3.0, 19.0, z + 3.0))])
            self.m.add_pecas(setor, "pedra_esc", [
                espinho((x, 19.0, z), (x, 31.0, z), 2.4, n=4),
                caixa((x - 3.0, 0.0, z - 3.0), (x + 3.0, 1.2, z + 3.0))])
            for cx_ in (-2.6, 2.6):
                self.m.add_pecas(setor, "pedra_esc", [espinho((x + cx_, 19.0, z - 2.6),
                                                              (x + cx_, 23.0, z - 2.6), 0.4, n=4)])
            self.col.append(caixa((x - 2.6, 0.0, z - 2.6), (x + 2.6, 18.0, z + 2.6)))
            self.braseiro(x - s * 3.6, 0.0, z - 4.2, setor="portao")
        # secao redonda: o `tubo` da igreja deita a secao em Y e degenera no
        # trecho vertical da ombreira
        pts = _ogiva_vertical(-(PONTE_W + 0.4), PONTE_W + 0.4, 11.0, 17.0, z, n=14)
        self.m.add_pecas("portao", "pedra_esc", [tubo_redondo(pts, [0.95] * len(pts), n=8)])
        # grade levantada: as pontas das barras aparecem por baixo da ogiva
        barras = []
        for i in range(9):
            bx = -PONTE_W + 0.6 + i * (2 * PONTE_W - 1.2) / 8
            barras.append(caixa((bx - 0.09, 9.6, z - 0.12), (bx + 0.09, 13.5, z + 0.12)))
            barras.append(espinho((bx, 9.6, z), (bx, 8.9, z), 0.1, n=4))
        barras.append(caixa((-PONTE_W, 12.4, z - 0.12), (PONTE_W, 12.6, z + 0.12)))
        self.m.add_pecas("portao", "metal", barras)

    def ponte(self):
        """A ponte da chegada. Continua ATRAS do jogador aos pedacos — e' a
        primeira coisa que diz que o mundo nao acaba aqui."""
        rnd = self.rnd
        self.m.add_pecas("ponte", "pedra", [caixa((-PONTE_W, -2.6, R_PISO - 1.0), (PONTE_W, -0.05, PONTE_Z1))])
        for s in (-1, 1):
            x = s * (PONTE_W + 0.15)
            self.m.add_pecas("ponte", "pedra_esc", [caixa((x - 0.35, -2.6, R_PISO - 1.0), (x + 0.35, 1.0, PONTE_Z1))])
            for k in range(8):
                zz = R_PISO + 2.0 + k * 5.0
                self.m.add_pecas("ponte", "pedra_esc", [caixa((x - 0.55, 0.0, zz - 0.55), (x + 0.55, 1.8, zz + 0.55)),
                                                         espinho((x, 1.8, zz), (x, 2.8, zz), 0.4, n=4)])
        # arcos por baixo descendo pro abismo
        for zz in (62.0, 76.0, 90.0):
            self.m.add_pecas("ponte", "rocha", [cilindro(0.0, zz, 3.2, -95.0, -2.6, n=10, raio_topo=2.4)])
        # o resto da ponte, quebrado, sumindo na nevoa
        z = PONTE_Z1 + 2.5
        y = -0.4
        incl = 0.0
        for k in range(6):
            comp = rnd.uniform(6.0, 13.0)
            incl += rnd.uniform(-0.05, 0.08)
            self.m.add_pecas("ponte_longe", "pedra", [caixa_girada(
                rnd.uniform(-0.6, 0.6), y - 1.3, z + comp / 2, 2 * PONTE_W, 2.6, comp,
                rnd.uniform(-0.04, 0.04), incl)])
            self.m.add_pecas("ponte_longe", "rocha", [cilindro(0.0, z + comp / 2, 2.6, -95.0, y - 2.6, n=8, raio_topo=2.0)])
            z += comp + rnd.uniform(3.0, 9.0)
            y -= rnd.uniform(0.5, 3.0)

    def cobertura(self):
        """Pouca coisa na praca, de proposito: a luta e' contra o chefe e o
        miolo (raio 18) fica limpo. O que tem serve de cobertura contra a
        chuva de fogo e quebra a linha de visao do chefe."""
        rnd = self.rnd
        lugares = []
        for k in range(16):
            a = 2 * math.pi * k / 16 + rnd.uniform(-0.12, 0.12)
            r = rnd.uniform(24.0, 36.0)
            x, z = r * math.sin(a), r * math.cos(a)
            if abs(x) < 9 and z > 0:          # corredor da ponte ao sigilo
                continue
            if no_zigurate(x, z) or (abs(x) < 12 and z < -16):
                continue
            if self.bloqueado(x, z, 3.0):
                continue
            lugares.append((x, z, a))
        for i, (x, z, a) in enumerate(lugares):
            setor = self.setor_grade("cobertura", x, z, SETOR)
            tipo = i % 4
            giro = a + rnd.uniform(-0.6, 0.6)
            if tipo == 0:
                # sarcofago com tampa deslocada
                self.m.add_pecas(setor, "pedra_esc", [caixa_girada(x, 0.55, z, 1.6, 1.1, 3.2, giro)])
                self.m.add_pecas(setor, "pedra", [caixa_girada(x + 0.3, 1.2, z + 0.2, 1.8, 0.22, 3.4,
                                                               giro + 0.25, 0.04)])
                self.col.append(caixa_girada(x, 0.6, z, 1.7, 1.2, 3.3, giro))
                self.bloquear(x, z, 1.9)
            elif tipo == 1:
                # estatua menor, decapitada
                self.estatua(x, 0.0, z, 7.0, giro, setor, base=True)
                self.col.append(caixa_girada(x, 1.5, z, 6.4, 3.0, 6.4, giro))
                self.col.append(cilindro(x, z, 1.0, 3.0, 8.0, n=8))
                self.bloquear(x, z, 3.6)
            elif tipo == 2:
                # monte de escombro
                self.m.add_pecas(setor, "pedra", entulho(x, z, 2.6, 14, rnd, tamanho=(0.5, 1.4),
                                                         altura_pilha=1.2))
                self.col.append(domo(x, z, 2.9, 1.4))
                self.bloquear(x, z, 2.8)
            else:
                # tambor de pilar e um cruzeiro tombado
                self.m.add_pecas(setor, "pedra", [cilindro(x, z, 1.25, 0.0, 1.6, n=12)])
                self.m.add_pecas(setor, "pedra_esc", cruz(x + 1.6, 0.0, z, alt=3.6, larg=0.4,
                                                          giro=giro, inclina=0.35))
                self.col.append(cilindro(x, z, 1.25, 0.0, 1.6, n=8))
                self.bloquear(x, z, 1.6)
        # tentaculos que sobem do abismo e passam por cima da balaustrada
        for a, comp in ((1.15, 30.0), (2.05, 26.0), (4.25, 34.0), (5.15, 28.0)):
            bx, bz = (R_PISO + 6.0) * math.sin(a), (R_PISO + 6.0) * math.cos(a)
            tentaculo(self, "tentaculos", "carne", (bx, -14.0, bz),
                      (-math.sin(a) * 0.35, 1.0, -math.cos(a) * 0.35), comp, 2.3,
                      curva=0.9, fase=a, ventosas="osso")

    # ------------------------------------------------------------------
    # o que fica longe
    def longe(self):
        rnd = self.rnd
        # pontes quebradas pro leste, oeste e norte
        for a in (math.pi / 2, -math.pi / 2, math.pi + 0.35):
            dx, dz = math.sin(a), math.cos(a)
            r = R_PISO + 2.0
            y = -1.5
            for k in range(7):
                comp = rnd.uniform(7.0, 15.0)
                cx_, cz_ = (r + comp / 2) * dx, (r + comp / 2) * dz
                self.m.add_pecas("pontes_longe", "pedra", [caixa_girada(
                    cx_, y - 1.2, cz_, 9.0, 2.4, comp, a, rnd.uniform(-0.05, 0.05))])
                self.m.add_pecas("pontes_longe", "rocha", [cilindro(cx_, cz_, 2.4, -100.0, y - 2.4,
                                                                   n=8, raio_topo=1.9)])
                r += comp + (rnd.uniform(4.0, 12.0) if k > 1 else 0.6)
                y -= rnd.uniform(0.0, 2.5)
        # ilhas flutuantes com ruina
        # poucas, pequenas e LONGE: nove ilhas grandes a 110 m viravam um teto
        # de estalactites cobrindo metade do ceu
        for k in range(6):
            a = 2 * math.pi * k / 6 + 0.5 + rnd.uniform(-0.25, 0.25)
            r = rnd.uniform(150.0, 240.0)
            x, z = r * math.sin(a), r * math.cos(a)
            y = rnd.uniform(-35.0, 12.0)
            larg = rnd.uniform(9.0, 18.0)
            setor = "ilhas"
            self.m.add_pecas(setor, "rocha", [cilindro(x, z, larg * 0.5, y - larg * 0.25, y, n=9,
                                                       raio_topo=larg * 0.55),
                                              espinho((x, y - larg * 0.25, z),
                                                      (x + rnd.uniform(-3, 3), y - larg * 1.1, z), larg * 0.45, n=7)])
            silhueta_gotica(self, setor, "pedra_esc", x, z, larg * 0.35, rnd.uniform(6.0, 12.0), rnd,
                            giro=rnd.uniform(0, math.pi))
            # a silhueta nasce no y=0: levanta pra ilha
            self._levantar_ultimas(setor, "pedra_esc", y)
        # cidade gotica no horizonte
        for k in range(64):
            a = 2 * math.pi * k / 64 + rnd.uniform(-0.03, 0.03)
            r = rnd.uniform(205.0, 330.0)
            x, z = r * math.sin(a), r * math.cos(a)
            alt = rnd.uniform(14.0, 46.0) * (1.0 + (r - 205.0) / 260.0)
            silhueta_gotica(self, "horizonte", "silhueta", x, z, rnd.uniform(8.0, 20.0), alt, rnd,
                            giro=rnd.uniform(0, math.pi))
            self._levantar_ultimas("horizonte", "silhueta", rnd.uniform(-30.0, -5.0))
        # massa de rocha embaixo da cidade (senao ela flutua no nada)
        for k in range(24):
            a = 2 * math.pi * k / 24
            r = 265.0
            x, z = r * math.sin(a), r * math.cos(a)
            self.m.add_pecas("horizonte", "silhueta", [cilindro(x, z, 48.0, -140.0, -20.0, n=7,
                                                                raio_topo=40.0)])
        # colossos encapuzados
        for a, r, alt in ((2.7, 300.0, 170.0), (-2.5, 330.0, 200.0), (0.9, 360.0, 150.0),
                          (-1.05, 280.0, 130.0)):
            x, z = r * math.sin(a), r * math.cos(a)
            self.estatua(x, -60.0, z, alt, math.atan2(-x, -z), "colossos", lanterna=(a > 2.0),
                         mat="silhueta", base=False)
        # tentaculos colossais saindo do abismo
        for a, r, alt in ((0.45, 120.0, 95.0), (1.9, 150.0, 120.0), (3.5, 135.0, 80.0),
                          (4.6, 160.0, 130.0), (5.6, 115.0, 70.0)):
            x, z = r * math.sin(a), r * math.cos(a)
            tentaculo(self, "tentaculos_longe", "carne", (x, -90.0, z), (0.1, 1.0, -0.05),
                      alt + 90.0, alt * 0.09, curva=1.2, fase=a, n=16, lados=8)
        # o mar de brasa la' embaixo
        anel = []
        for k in range(32):
            a = 2 * math.pi * k / 32
            anel.append((520.0 * math.sin(a), 520.0 * math.cos(a)))
        v = [(0.0, -115.0, 0.0)] + [(p[0], -115.0, p[1]) for p in anel]
        f = [[0, 1 + k, 1 + (k + 1) % 32] for k in range(32)]   # normal pra cima
        self.m.add("abismo", "abismo", v, f)

    def _levantar_ultimas(self, setor, mat, dy):
        """A silhueta_gotica nasce no chao (y=0); sobe/desce o que acabou de
        entrar nesse grupo."""
        g = self.m.grupos[(setor, mat)]
        marca = g.setdefault("_marca", 0)
        for i in range(marca, len(g["v"])):
            x, y, z = g["v"][i]
            g["v"][i] = (x, y + dy, z)
        g["_marca"] = len(g["v"])

    def cercadura(self):
        pts = [(PONTE_W - 0.4, PONTE_FIM), (PONTE_W - 0.4, R_LIMITE * 0.995)]
        a0 = math.asin((PONTE_W - 0.4) / R_LIMITE)
        n = 72
        for k in range(n + 1):
            a = a0 + (2 * math.pi - 2 * a0) * k / n
            pts.append((R_LIMITE * math.sin(a), R_LIMITE * math.cos(a)))
        pts.append((-(PONTE_W - 0.4), R_LIMITE * 0.995))
        pts.append((-(PONTE_W - 0.4), PONTE_FIM))
        muro_invisivel(self, pts, y0=-3.0, y1=30.0, esp=1.2, fechar=True)

    def _redemoinhos(self):
        """Onde os redemoinhos de poeira comecam a andar."""
        for a, r in ((0.8, 30.0), (2.6, 34.0), (4.3, 28.0)):
            self.pontos["redemoinhos"].append([round(r * math.sin(a), 2), 0.0, round(r * math.cos(a), 2)])


def _fita(p0, p1, larg, alt):
    """Faixa fina sobre o chao entre dois pontos (sigilo, fenda)."""
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


def _ogiva_vertical(x0, x1, y_arranque, y_ponta, z, n=12):
    """Pontos de uma ogiva no plano XY (porta, portao)."""
    pts = []
    meio = (x0 + x1) / 2.0
    meia = (x1 - x0) / 2.0
    for i in range(n + 1):
        t = i / n
        x = lerp(x0, x1, t)
        u = abs(x - meio) / meia
        y = y_arranque + (y_ponta - y_arranque) * (1.0 - u ** 1.8) ** 0.75
        pts.append((x, y, z))
    pts.insert(0, (x0, 0.0, z))
    pts.append((x1, 0.0, z))
    return pts


def main():
    arena = Arena3()
    arena.montar()
    # os grupos guardam uma "_marca" interna; tira antes do export
    for g in arena.m.grupos.values():
        g.pop("_marca", None)
    arena.exportar("battlefield_3", "arena_3", abertos=("abismo",))
    nav = arena.pontos["navmesh"]
    print("  navmesh: %d vertices, %d poligonos" % (len(nav["v"]), len(nav["p"])))
    print("  braseiros=%d pousos=%d inimigos=%d" % (
        len(arena.pontos["braseiros"]), len(arena.pontos["pousos"]), len(arena.pontos["inimigos"])))
    _ = centros_navmesh


if __name__ == "__main__":
    main()
