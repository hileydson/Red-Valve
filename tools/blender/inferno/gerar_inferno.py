# -*- coding: utf-8 -*-
"""Modela o INFERNO — o mapa de passagem — e exporta pro Godot.

    blender --background --factory-startup \\
        --python tools/blender/inferno/gerar_inferno.py

Saidas:
    red-valve/assets/3d_model/stages/inferno/inferno.glb
    red-valve/assets/3d_model/stages/inferno/inferno_pontos.json

Depois: `tools/godot/inferno/gerar_cena_inferno.py` e `--headless --import`.

==============================================================================
O LUGAR

Um pedaco do inferno que LIGA dois mapas: entra-se por um portao ao sul e
sai-se por um portal ao norte. O caminho e' LINEAR mas largo e longo — perto
de um quilometro, com subidas e descidas leves (nunca mais de 6%) — e passa
por oito areas, cada uma com uma silhueta propria pra o jogador se achar:

   S  1 PORTAO DAS CINZAS     o jogador chega por aqui (entrada)
   |  2 PLANICIE DAS CINZAS   aberta, colunas de basalto, geiseres de fogo
   |  3 PONTE DO RIO DE LAVA  o unico jeito de cruzar o rio
   |  4 CAMPO DOS COLOSSOS    costelas e cranio de bichos do tamanho de predio
   |  5 FLORESTA DE ESPINHOS  espinhos de obsidiana e gaiolas penduradas
   |  6 CATEDRAL AFUNDADA     uma catedral inteira engolida de lado
   |  7 A CRISTA             trilha estreita com lava dos dois lados
   N  8 O PORTAL              a saida pro proximo mapa

Em volta de tudo, um MAR DE LAVA. Dos lados do caminho, ora penhasco, ora a
beira que despenca na lava — e o muro invisivel acompanha a borda inteira.
Longe: vulcoes, cachoeiras de lava e SOMBRAS gigantes de pe' na lava (essas
saem como objetos soltos, com pivo no pe', pro `inferno.gd` balancar).

==============================================================================
COMO O CHAO E' FEITO

Uma linha de centro (Catmull-Rom pelos pontos de controle) com meia-largura e
altura por ponto. A altura de qualquer (x, z) sai do ponto da linha mais
perto: dentro da largura e' o caminho (ondulacao de meio metro); fora, mistura
"penhasco" e "beira de lava" conforme o lado. Chao, colisao e navmesh usam a
MESMA funcao — ninguem anda acima nem abaixo do que ve'.
"""

import math
import os
import sys

# o .pyc da base (e o do gerador da arena 2, versionado) nao pode nascer
# antes de a base desligar o bytecode: desliga aqui, antes de importar
sys.dont_write_bytecode = True
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "cenarios"))

from base import (Cena, assentar, caixa, caixa_girada, chao_sob,  # noqa: E402
                  chao_visivel, chapa_aberta, chapa_grossa, cilindro,
                  corrente_vertical, cruz, domo, entulho, espinho,
                  estender_ate_o_chao, hexaedro, lerp, muro_invisivel,
                  navmesh_grade, pilar_composto, raiz_no_chao, ruido2,
                  silhueta_gotica, suave, tentaculo, tubo, tubo_redondo)

LAVA = -14.0          # nivel do mar de lava
PASSO = 4.0           # chao visivel e colisao
PASSO_NAV = 2.5
SETOR = 64.0

# (x, z, meia-largura, altura, tipo_esq, tipo_dir)   tipo: 0 penhasco, 1 lava
CONTROLE = [
    (0.0, 470.0, 14.0, 0.0, 0.0, 0.0),
    (0.0, 440.0, 16.0, 0.0, 0.0, 0.0),
    (0.0, 400.0, 26.0, 0.0, 0.0, 0.2),
    (24.0, 340.0, 40.0, -2.0, 0.9, 0.0),
    (-8.0, 272.0, 46.0, -3.5, 1.0, 0.3),
    (-38.0, 222.0, 24.0, -4.5, 1.0, 1.0),
    (-40.0, 175.0, 7.0, -5.0, 1.0, 1.0),     # a ponte
    (-30.0, 128.0, 26.0, -3.0, 0.0, 0.6),
    (8.0, 72.0, 44.0, 0.0, 0.0, 0.0),
    (36.0, 14.0, 38.0, 2.5, 0.2, 0.0),
    (26.0, -46.0, 34.0, 4.5, 1.0, 0.0),
    (-12.0, -104.0, 40.0, 4.0, 0.6, 0.4),
    (-38.0, -162.0, 44.0, 2.0, 0.0, 0.0),
    (-18.0, -222.0, 28.0, 0.0, 0.4, 0.9),
    (14.0, -270.0, 12.0, -1.0, 1.0, 1.0),    # a crista
    (28.0, -318.0, 12.0, -1.0, 1.0, 1.0),
    (10.0, -368.0, 32.0, 1.0, 0.3, 0.3),
    (0.0, -418.0, 28.0, 2.0, 0.0, 0.0),
    (0.0, -448.0, 18.0, 2.0, 0.0, 0.0),
    (0.0, -470.0, 14.0, 2.0, 0.0, 0.0),
]
Z_INICIO = 446.0       # muro atras do portao de entrada
Z_FIM = -452.0         # muro atras do portal
# o anel de chegada fica na frente do portao (fechado, de fundo); o jogador
# nasce no pe' da rampa dele
ANEL_ENTRADA = 424.0
SPAWN = (0.0, 0.3, 393.0)
PONTE = (-40.0, 175.0)
RIO_W = 12.0
PONTE_COMP = 26.0      # meia-extensao do tabuleiro ao longo do caminho
PONTE_W = 7.0


def catmull(pts, passo=2.0):
    """Polilinha densa (a cada ~`passo` m) por Catmull-Rom; interpola tambem
    as colunas extras (largura, altura, tipos)."""
    out = []
    n = len(pts)
    for i in range(n - 1):
        p0 = pts[max(i - 1, 0)]
        p1 = pts[i]
        p2 = pts[i + 1]
        p3 = pts[min(i + 2, n - 1)]
        d = math.hypot(p2[0] - p1[0], p2[1] - p1[1])
        k = max(2, int(d / passo))
        for j in range(k):
            t = j / k
            t2, t3 = t * t, t * t * t
            row = []
            for c in range(len(p1)):
                if c < 2:
                    v = 0.5 * ((2 * p1[c]) + (-p0[c] + p2[c]) * t
                               + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2
                               + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3)
                else:
                    # largura, altura e tipo: suave, sem passar do intervalo
                    v = lerp(p1[c], p2[c], t * t * (3 - 2 * t))
                row.append(v)
            out.append(tuple(row))
    out.append(tuple(pts[-1]))
    return out


class Linha:
    """A linha de centro com busca rapida do ponto mais perto."""

    def __init__(self):
        self.p = catmull(CONTROLE)
        self.s = [0.0]
        for i in range(1, len(self.p)):
            self.s.append(self.s[-1] + math.hypot(self.p[i][0] - self.p[i - 1][0],
                                                  self.p[i][1] - self.p[i - 1][1]))
        self.t = []
        for i in range(len(self.p)):
            a = self.p[max(i - 1, 0)]
            b = self.p[min(i + 1, len(self.p) - 1)]
            dx, dz = b[0] - a[0], b[1] - a[1]
            d = math.hypot(dx, dz) or 1.0
            self.t.append((dx / d, dz / d))
        # grade grossa: indice mais perto, pintada a partir de cada ponto
        self.cel = 10.0
        self.grade = {}
        alcance = 260.0
        r = int(alcance / self.cel) + 1
        for i, q in enumerate(self.p):
            if i % 3:
                continue
            ci, cj = int(math.floor(q[0] / self.cel)), int(math.floor(q[1] / self.cel))
            for di in range(-r, r + 1):
                for dj in range(-r, r + 1):
                    cx_, cz_ = (ci + di + 0.5) * self.cel, (cj + dj + 0.5) * self.cel
                    d2 = (cx_ - q[0]) ** 2 + (cz_ - q[1]) ** 2
                    if d2 > alcance * alcance:
                        continue
                    k = (ci + di, cj + dj)
                    old = self.grade.get(k)
                    if old is None or d2 < old[0]:
                        self.grade[k] = (d2, i)
        self._memo = {}

    def perto(self, x, z):
        """(indice, lateral com sinal, distancia) do ponto mais perto."""
        chave = (round(x, 2), round(z, 2))
        r = self._memo.get(chave)
        if r is not None:
            return r
        g = self.grade.get((int(math.floor(x / self.cel)), int(math.floor(z / self.cel))))
        if g is None:
            r = (None, 1e9, 1e9)
            self._memo[chave] = r
            return r
        i0 = g[1]
        melhor, md = i0, 1e18
        for i in range(max(0, i0 - 14), min(len(self.p), i0 + 15)):
            d2 = (x - self.p[i][0]) ** 2 + (z - self.p[i][1]) ** 2
            if d2 < md:
                melhor, md = i, d2
        tx, tz = self.t[melhor]
        px, pz = x - self.p[melhor][0], z - self.p[melhor][1]
        lateral = tx * pz - tz * px     # >0 = esquerda de quem anda
        r = (melhor, lateral, math.sqrt(md))
        self._memo[chave] = r
        return r

    def em_z(self, z):
        """Indice do ponto da linha mais perto de um Z."""
        return min(range(len(self.p)), key=lambda i: abs(self.p[i][1] - z))


LINHA = None
RIO = [(-420.0, 205.0), (-260.0, 190.0), (-140.0, 168.0), (-80.0, 178.0), (-40.0, 175.0),
       (0.0, 172.0), (70.0, 186.0), (170.0, 160.0), (300.0, 182.0), (420.0, 170.0)]


def dist_rio(x, z):
    melhor = 1e9
    for i in range(len(RIO) - 1):
        ax, az = RIO[i]
        bx, bz = RIO[i + 1]
        dx, dz = bx - ax, bz - az
        dd = dx * dx + dz * dz
        t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / dd))
        melhor = min(melhor, math.hypot(x - ax - dx * t, z - az - dz * t))
    return melhor


def altura(x, z):
    i, lat, _d = LINHA.perto(x, z)
    if i is None:
        return LAVA - 6.0 + 30.0 * max(0.0, ruido2(x * 0.01, z * 0.01, 5.0))
    q = LINHA.p[i]
    w, y0, te, td = q[2], q[3], q[4], q[5]
    perto_ponte = math.hypot(x - PONTE[0], z - PONTE[1]) < 34.0
    amp = 0.0 if perto_ponte else 1.0
    n = (0.35 * ruido2(x * 0.9, z * 0.9, 1.0) + 0.45 * ruido2(x * 0.25, z * 0.25, 2.0)) * amp
    al = abs(lat)
    if al <= w:
        h = y0 + n
    else:
        fora = al - w
        tipo = te if lat > 0 else td
        rug = 3.5 * ruido2(x * 0.15, z * 0.15, 7.0) + 1.5 * ruido2(x * 0.5, z * 0.5, 3.0)
        penhasco = y0 + n + fora * 1.5 + max(0.0, fora - 6.0) * 1.6 + rug * min(fora / 8.0, 1.0)
        penhasco = min(penhasco, y0 + 46.0 + rug * 3.0)
        cai = min(fora / 7.0, 1.0)
        beira = lerp(y0 + n, LAVA - 4.0 + rug * 0.3, suave(cai))
        if fora > 80.0:
            beira += (fora - 80.0) * 0.45 + rug * 2.0
        h = lerp(penhasco, beira, tipo)
    dr = dist_rio(x, z)
    if dr < RIO_W + 10.0:
        h = lerp(LAVA - 5.0, h, suave((dr - RIO_W) / 10.0))
    return h


def no_caminho(x, z, folga=0.0):
    i, lat, _d = LINHA.perto(x, z)
    if i is None:
        return False
    q = LINHA.p[i]
    if not (Z_FIM + 1.0 < z < Z_INICIO - 1.0):
        return False
    return abs(lat) <= q[2] - folga


def na_ponte(x, z):
    """Tabuleiro da ponte: retangulo ao longo do caminho no rio."""
    i, lat, _d = LINHA.perto(x, z)
    if i is None:
        return False
    return abs(lat) <= PONTE_W and abs(z - PONTE[1]) <= PONTE_COMP


def y_ponte(z):
    t = 1.0 - min(abs(z - PONTE[1]) / PONTE_COMP, 1.0)
    i = LINHA.em_z(PONTE[1] + PONTE_COMP)
    j = LINHA.em_z(PONTE[1] - PONTE_COMP)
    base = lerp(LINHA.p[j][3], LINHA.p[i][3], (z - (PONTE[1] - PONTE_COMP)) / (2 * PONTE_COMP))
    return base + 1.4 * math.sin(t * math.pi / 2)


def _sem_chao(xc, zc):
    """A celula de chao com centro (xc, zc) fica de fora: longe demais da
    linha ou toda embaixo da lava (ali o que se ve' e' o mar)."""
    k, lat, d = LINHA.perto(xc, zc)
    if k is None or abs(lat) > LINHA.p[k][2] + 120.0:
        return True
    return altura(xc, zc) < LAVA - 3.0 and abs(lat) > LINHA.p[k][2] + 2.0


def altura_nav(x, z):
    if na_ponte(x, z):
        return y_ponte(z)
    return altura(x, z)


class Inferno(Cena):

    def __init__(self):
        super().__init__("inf", 666)
        self.pontos = {
            "player": list(SPAWN),
            "entrada": [0.0, 0.0, ANEL_ENTRADA],
            "saida": [0.0, 2.0, -432.0],
            "areas": {},
            "braseiros": [],
            "geiseres": [],
            "lavas_som": [],
            "inimigos": [],
            "navmesh": {"v": [], "p": []},
        }
        self.ocupado = []

    def livre(self, x, z, r):
        for ox, oz, orr in self.ocupado:
            if (x - ox) ** 2 + (z - oz) ** 2 < (r + orr) ** 2:
                return False
        return True

    def ocupar(self, x, z, r, bloqueia=True):
        self.ocupado.append((x, z, r))
        if bloqueia:
            self.bloquear(x, z, r)

    @staticmethod
    def chao_v(x, z):
        """O chao que se ve': a grade de `PASSO` m (nao a `altura` exata) e,
        onde o `chao` nem desenha a celula, a lava."""
        if _sem_chao((math.floor(x / PASSO) + 0.5) * PASSO, (math.floor(z / PASSO) + 0.5) * PASSO):
            return LAVA - 0.5
        return chao_visivel(altura, PASSO, x, z)

    def pe(self, x, z, r):
        return chao_sob(self.chao_v, x, z, r)

    def firmar(self, pecas, folga=0.5):
        return estender_ate_o_chao(pecas, self.chao_v, folga)

    def ponto(self, z, lado=0.0):
        """Ponto do caminho perto de Z, deslocado `lado` (fracao da largura,
        -1 = beira esquerda, +1 = direita)."""
        i = LINHA.em_z(z)
        q = LINHA.p[i]
        tx, tz = LINHA.t[i]
        # esquerda de quem anda = (-tz, tx) ... no mesmo sinal do `lateral`
        lx, lz = -tz, tx
        x = q[0] + lx * q[2] * lado
        zz = q[1] + lz * q[2] * lado
        return x, altura(x, zz), zz, i

    # ------------------------------------------------------------------
    def montar(self):
        self.chao()
        self.mar_de_lava()
        self.rio()
        self.ponte()
        self.portao()
        self.planicie()
        self.colossos()
        self.espinhos()
        self.catedral()
        self.crista()
        self.portal()
        self.portal_entrada()
        self.braseiros()
        self.cachoeiras()
        self.longe()
        self.sombras()
        self.cercadura()
        self.pontos["navmesh"] = navmesh_grade(
            self, -200.0, 200.0, Z_FIM, Z_INICIO, PASSO_NAV, altura_nav,
            lambda x, z: no_caminho(x, z, 1.0) or na_ponte(x, z) and abs(LINHA.perto(x, z)[1]) < PONTE_W - 1.0,
            max_desnivel=0.7, folga=0.6)
        self._marcadores()

    # ------------------------------------------------------------------
    def chao(self):
        """Chao visivel (aberto, so' o tampo) ate' 110 m da linha; colisao
        fechada so' no caminho e numa faixa em volta."""
        visiveis = {}
        colisao = set()
        x0, x1, z0, z1 = -300.0, 300.0, -560.0, 560.0
        for i in range(int(x0 / PASSO), int(x1 / PASSO)):
            for j in range(int(z0 / PASSO), int(z1 / PASSO)):
                xc, zc = (i + 0.5) * PASSO, (j + 0.5) * PASSO
                if _sem_chao(xc, zc):
                    continue
                k, lat, d = LINHA.perto(xc, zc)
                w = LINHA.p[k][2]
                if abs(lat) <= w + 0.5 and Z_FIM - 6 < zc < Z_INICIO + 6:
                    mat = "cinza" if ruido2(xc * 0.3, zc * 0.3, 4.0) > -0.1 else "basalto"
                elif abs(lat) <= w + 10.0:
                    mat = "basalto"
                else:
                    mat = "rocha"
                setor = self.setor_grade("chao", xc, zc, SETOR)
                visiveis.setdefault((setor, mat), []).append((i, j))
                if abs(lat) <= w + 6.0 and Z_FIM - 8 < zc < Z_INICIO + 8:
                    colisao.add((i, j))
        for (setor, mat), cel in visiveis.items():
            v, f = chapa_aberta(cel, PASSO, altura)
            self.m.add(setor, mat, v, f)
        v, f = chapa_grossa(list(colisao), PASSO, altura, 3.0)
        self.col.append((v, f))
        # pedra solta pela beira do caminho, pra quebrar a grade
        rnd = self.rnd
        for k in range(0, len(LINHA.p), 3):
            q = LINHA.p[k]
            tx, tz = LINHA.t[k]
            for lado in (-1, 1):
                if rnd.random() < 0.5:
                    continue
                off = q[2] + rnd.uniform(1.5, 7.0)
                x = q[0] - tz * off * lado
                z = q[1] + tx * off * lado
                if not (Z_FIM < z < Z_INICIO):
                    continue
                y = altura(x, z)
                if y < LAVA:
                    continue
                s = rnd.uniform(1.5, 5.0)
                setor = self.setor_grade("pedras", x, z, SETOR)
                pedra = caixa_girada(x, y + s * 0.2, z, s, s * rnd.uniform(0.6, 1.4),
                                     s * rnd.uniform(0.7, 1.3), rnd.uniform(0, 3),
                                     rnd.uniform(-0.3, 0.3), rnd, 0.35)
                if self.pe(x, z, s * 0.7) < LAVA + 1.0:
                    continue          # na margem da lava o chao ali nem e' desenhado
                self.m.add_pecas(setor, "rocha", assentar([pedra], self.chao_v))

    def mar_de_lava(self):
        """O mar: um disco enorme no nivel da lava. Aberto, normal pra cima."""
        n = 40
        v = [(0.0, LAVA, 0.0)]
        for k in range(n):
            a = 2 * math.pi * k / n
            v.append((1400.0 * math.sin(a), LAVA, 1400.0 * math.cos(a)))
        f = [[0, 1 + k, 1 + (k + 1) % n] for k in range(n)]
        self.m.add("lava_mar", "lava", v, f)

    def rio(self):
        """O rio que corre por baixo da ponte: faixa com UV ao longo do rio,
        um palmo acima do mar, pro shader fazer a lava ESCORRER."""
        pts = []
        for i in range(len(RIO) - 1):
            ax, az = RIO[i]
            bx, bz = RIO[i + 1]
            d = math.hypot(bx - ax, bz - az)
            k = max(2, int(d / 6.0))
            for j in range(k):
                t = j / k
                pts.append((lerp(ax, bx, t), lerp(az, bz, t)))
        pts.append(RIO[-1])
        verts, faces, uvs = [], [], []
        acc = 0.0
        for i, (x, z) in enumerate(pts):
            a = pts[max(i - 1, 0)]
            b = pts[min(i + 1, len(pts) - 1)]
            dx, dz = b[0] - a[0], b[1] - a[1]
            d = math.hypot(dx, dz) or 1.0
            nx, nz = -dz / d, dx / d
            if i:
                acc += math.hypot(x - pts[i - 1][0], z - pts[i - 1][1])
            verts.append((x + nx * (RIO_W + 3), LAVA + 0.25, z + nz * (RIO_W + 3)))
            verts.append((x - nx * (RIO_W + 3), LAVA + 0.25, z - nz * (RIO_W + 3)))
            if i:
                b0 = (i - 1) * 2
                # normal pra cima: (esq, dir) do anterior e do atual
                faces.append([b0, b0 + 2, b0 + 3, b0 + 1])
                v0 = (acc - math.hypot(x - pts[i - 1][0], z - pts[i - 1][1])) / 30.0
                v1 = acc / 30.0
                uvs.append([(0.0, v0), (0.0, v1), (1.0, v1), (1.0, v0)])
        # confere a orientacao: a primeira face tem de apontar pra +Y
        a, b, c = verts[faces[0][0]], verts[faces[0][1]], verts[faces[0][2]]
        ny = (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2])
        if ny < 0:
            faces = [list(reversed(f)) for f in faces]
            uvs = [list(reversed(u)) for u in uvs]
        self.m.add("lava_rio", "lava_corre", verts, faces, uvs=uvs)
        self.pontos["lavas_som"].append([PONTE[0] + 14.0, LAVA + 1.0, PONTE[1]])
        self.pontos["lavas_som"].append([PONTE[0] - 18.0, LAVA + 1.0, PONTE[1] + 2.0])

    def cachoeira(self, x, z, topo, giro, larg, setor="cachoeiras"):
        """Cortina de lava caindo de um penhasco ate' o mar. UV.v desce."""
        ca, sa = math.cos(giro), math.sin(giro)
        verts, faces, uvs = [], [], []
        n = 8
        for k in range(n + 1):
            t = k / n
            y = lerp(topo, LAVA, t)
            # a cortina descola da parede e abre um pouco embaixo
            off = 1.2 + 5.0 * t * t
            ww = larg * (1.0 + 0.4 * t)
            cx_, cz_ = x + sa * off, z + ca * off
            verts.append((cx_ - ca * ww / 2, y, cz_ + sa * ww / 2))
            verts.append((cx_ + ca * ww / 2, y, cz_ - sa * ww / 2))
            if k:
                b0 = (k - 1) * 2
                faces.append([b0, b0 + 1, b0 + 3, b0 + 2])
                uvs.append([(0.0, (k - 1) / n * 3), (1.0, (k - 1) / n * 3), (1.0, k / n * 3), (0.0, k / n * 3)])
        self.m.add(setor, "lava_cai", verts, faces, uvs=uvs)
        self.pontos["lavas_som"].append([round(x + sa * 4, 2), round((topo + LAVA) / 2, 2), round(z + ca * 4, 2)])

    def cachoeiras(self):
        """Cachoeiras de lava SO' do lado da lava: do outro lado do lago, onde a
        margem volta a subir, despencando de frente pro caminho. No lado do
        penhasco a cortina cairia em cima da trilha."""
        feitas = 0
        for z in (330.0, 286.0, 214.0, 160.0, 118.0, -96.0, -236.0, -262.0, -300.0, -330.0):
            i = LINHA.em_z(z)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            for lado, tipo in ((1, q[4]), (-1, q[5])):
                if tipo < 0.7:
                    continue
                # esquerda de quem anda = (-tz, tx)
                lx, lz = -tz * lado, tx * lado
                achou = None
                for fora in range(86, 150, 4):
                    d = q[2] + fora
                    x, zz = q[0] + lx * d, q[1] + lz * d
                    h = altura(x, zz)
                    if h > LAVA + 9.0:
                        achou = (x, zz, h)
                        break
                if achou is None:
                    continue
                x, zz, h = achou
                giro = math.atan2(-lx, -lz)      # a cortina avanca pro caminho
                self.cachoeira(x, zz, h - 0.5, giro, self.rnd.uniform(8.0, 15.0))
                feitas += 1
        self.pontos["n_cachoeiras"] = feitas

    # ------------------------------------------------------------------
    def ponte(self):
        """Ponte de pedra em arco sobre o rio. Tabuleiro com colisao em
        rampa suave; a colisao ENTRA 2 m por baixo do chao nas cabeceiras."""
        z0, z1 = PONTE[1] + PONTE_COMP + 2.0, PONTE[1] - PONTE_COMP - 2.0
        n = 18
        pecas, col = [], []
        for k in range(n):
            za = lerp(z0, z1, k / n)
            zb = lerp(z0, z1, (k + 1) / n)
            ia, ib = LINHA.em_z(za), LINHA.em_z(zb)
            xa, xb = LINHA.p[ia][0], LINHA.p[ib][0]
            ya, yb = y_ponte(za), y_ponte(zb)
            if abs(za - PONTE[1]) > PONTE_COMP:
                ya = altura(xa, za)
            if abs(zb - PONTE[1]) > PONTE_COMP:
                yb = altura(xb, zb)
            w = PONTE_W + 0.6
            topo = hexaedro([(xa - w, ya - 1.6, za), (xa + w, ya - 1.6, za), (xb + w, yb - 1.6, zb), (xb - w, yb - 1.6, zb),
                             (xa - w, ya, za), (xa + w, ya, za), (xb + w, yb, zb), (xb - w, yb, zb)])
            pecas.append(topo)
            col.append(topo)
            for s in (-1, 1):
                xm = (xa + xb) / 2 + s * (w + 0.35)
                pecas.append(hexaedro([(xa + s * w, ya - 1.6, za), (xa + s * (w + 0.7), ya - 1.6, za),
                                       (xb + s * (w + 0.7), yb - 1.6, zb), (xb + s * w, yb - 1.6, zb),
                                       (xa + s * w, ya + 1.1, za), (xa + s * (w + 0.7), ya + 1.1, za),
                                       (xb + s * (w + 0.7), yb + 1.1, zb), (xb + s * w, yb + 1.1, zb)]))
                if k % 3 == 0:
                    ym = (ya + yb) / 2
                    pecas.append(caixa((xm - 0.55, ym, (za + zb) / 2 - 0.55), (xm + 0.55, ym + 2.2, (za + zb) / 2 + 0.55)))
                    pecas.append(espinho((xm, ym + 2.2, (za + zb) / 2), (xm, ym + 3.6, (za + zb) / 2), 0.45, n=4))
        self.m.add_pecas("ponte", "pedra", pecas)
        self.col.extend(col)
        # pilares em arco descendo pra lava
        for zz in (PONTE[1] - 16.0, PONTE[1], PONTE[1] + 16.0):
            i = LINHA.em_z(zz)
            x = LINHA.p[i][0]
            self.m.add_pecas("ponte", "pedra", [cilindro(x, zz, 3.4, LAVA - 4.0, y_ponte(zz) - 1.6, n=10,
                                                          raio_topo=2.6)])
        # estatuas de guardioes nas cabeceiras
        for zz in (z0 + 1.5, z1 - 1.5):
            i = LINHA.em_z(zz)
            x = LINHA.p[i][0]
            for s in (-1, 1):
                gx = x + s * (PONTE_W + 3.5)
                gy = altura(gx, zz)
                # olhando pro caminho: +Z local vira (sen g, cos g)
                self.guardiao(gx, gy, zz, 9.0, math.pi / 2 if s < 0 else -math.pi / 2, "ponte")
        self.pontos["areas"]["area_3_ponte"] = [PONTE[0], y_ponte(PONTE[1]) + 0.2, PONTE[1]]

    def guardiao(self, x, y, z, alt, giro, setor):
        """Estatua de demonio de pe', chifres e asas fechadas."""
        ca, sa = math.cos(giro), math.sin(giro)

        def P(lx, ly, lz):
            return (x + lx * ca + lz * sa, y + ly, z - lx * sa + lz * ca)

        h = alt
        # o pedestal desce ate' o chao que se ve' (na cabeceira ele cai pro rio)
        pecas = self.firmar([caixa_girada(x, y + 0.6, z, 3.0, 1.2, 3.0, giro)])
        pecas += [cilindro(x, z, h * 0.12, y + 1.2, y + 1.2 + h * 0.5, n=8, raio_topo=h * 0.09),
                  cilindro(x, z, h * 0.09, y + 1.2 + h * 0.5, y + 1.2 + h * 0.72, n=8, raio_topo=h * 0.13)]
        cab = P(0, 1.2 + h * 0.8, h * 0.02)
        # a cabeca nasce no alto do tronco (antes ficava 18 cm acima dele)
        pecas.append(cilindro(cab[0], cab[2], h * 0.07, y + 1.2 + h * 0.7, cab[1] + h * 0.06, n=8))
        for s in (-1, 1):
            pecas.append(espinho(P(s * h * 0.05, 1.2 + h * 0.84, 0), P(s * h * 0.16, 1.2 + h * 1.0, -h * 0.08),
                                 h * 0.025, n=5))
            pecas.append(espinho(P(s * h * 0.12, 1.2 + h * 0.72, -h * 0.06), P(s * h * 0.22, 1.2 + h * 0.15, -h * 0.12),
                                 h * 0.08, n=4))
        self.m.add_pecas(setor, "obsidiana", pecas)
        self.col.append(caixa_girada(x, y + 2.0, z, 3.0, 4.0, 3.0, giro))
        self.ocupar(x, z, 2.2)

    # ------------------------------------------------------------------
    def portao(self):
        """O portao por onde se chega. Duas torres e um arco, fechado atras."""
        z = 446.0
        y = altura(0.0, z - 4)
        for s in (-1, 1):
            x = s * 13.0
            self.m.add_pecas("portao", "obsidiana", [caixa((x - 3.5, y - 2, z - 3.5), (x + 3.5, y + 26.0, z + 3.5)),
                                                    espinho((x, y + 26.0, z), (x, y + 40.0, z), 3.6, n=4)])
            for k in range(4):
                a = k * math.pi / 2 + math.pi / 4
                self.m.add_pecas("portao", "osso", [espinho((x + 3.5 * math.cos(a), y + 20.0, z + 3.5 * math.sin(a)),
                                                            (x + 7.0 * math.cos(a), y + 25.0, z + 7.0 * math.sin(a)),
                                                            0.5, n=4)])
            self.col.append(caixa((x - 3.5, y - 2, z - 3.5), (x + 3.5, y + 26.0, z + 3.5)))
        pts = []
        for i in range(17):
            t = i / 16.0
            u = abs(2 * t - 1)
            pts.append((lerp(-9.5, 9.5, t), y + 15.0 + 7.0 * (1 - u ** 1.8) ** 0.7, z))
        self.m.add_pecas("portao", "obsidiana", [tubo_redondo(pts, [1.3] * len(pts), n=8)])
        # a porta: duas folhas de ferro FECHADAS (o caminho de volta)
        self.m.add_pecas("portao", "metal", [caixa((-9.5, y - 1.0, z - 0.4), (0.0, y + 16.0, z + 0.4)),
                                             caixa((0.0, y - 1.0, z - 0.25), (9.5, y + 16.0, z + 0.55))])
        rebites = []
        for xx in range(-9, 10, 3):
            # cada rebite nasce na face da SUA folha (a da direita e' 15 cm mais funda)
            zf = z - 0.4 if xx + 0.5 < 0.0 else z - 0.25
            for yy in range(1, 16, 3):
                rebites.append(espinho((xx + 0.5, y + yy, zf), (xx + 0.5, y + yy, zf - 0.7), 0.22, n=4))
        self.m.add_pecas("portao", "metal", rebites)
        self.m.add_pecas("portao", "brasa", [caixa((-0.3, y - 1.0, z - 0.5), (0.3, y + 16.0, z - 0.42))])
        self.pontos["areas"]["area_1_portao"] = [0.0, altura(0.0, 420.0), 420.0]

    def planicie(self):
        """Colunas de basalto em cacho e geiseres de fogo."""
        rnd = self.rnd
        for k in range(26):
            z = rnd.uniform(240.0, 395.0)
            x, y, zz, i = self.ponto(z, rnd.uniform(-0.85, 0.85))
            if not self.livre(x, zz, 4.5):
                continue
            setor = self.setor_grade("basalto", x, zz, SETOR)
            pecas = []
            for c in range(rnd.randint(4, 9)):
                a = rnd.uniform(0, 2 * math.pi)
                r = rnd.uniform(0.0, 2.2)
                cx_, cz_ = x + math.cos(a) * r, zz + math.sin(a) * r
                h = rnd.uniform(2.0, 9.0)
                pecas.append(cilindro(cx_, cz_, rnd.uniform(0.55, 0.9), y - 1.0, y + h, n=6, fase=rnd.uniform(0, 1)))
            self.m.add_pecas(setor, "basalto_col", pecas)
            self.col.append(cilindro(x, zz, 2.8, y - 1.0, y + 6.0, n=8))
            self.ocupar(x, zz, 3.2)
        # geiseres: boca de rocha com fissura acesa (o script dispara o fogo)
        for z in (380.0, 352.0, 318.0, 296.0, 262.0, 244.0):
            for _t in range(10):
                x, y, zz, i = self.ponto(z + rnd.uniform(-6, 6), rnd.uniform(-0.6, 0.6))
                if self.livre(x, zz, 3.5):
                    break
            self.geiser(x, y, zz)
        self.pontos["areas"]["area_2_planicie"] = list(self.ponto(320.0)[:3])

    def geiser(self, x, y, z):
        setor = self.setor_grade("geiser", x, z, SETOR)
        self.m.add_pecas(setor, "basalto", [cilindro(x, z, 2.2, y - 0.6, y + 0.5, n=9, raio_topo=1.3)])
        self.m.add_pecas(setor, "brasa", [cilindro(x, z, 1.15, y + 0.3, y + 0.55, n=9, raio_topo=0.9)])
        self.col.append(cilindro(x, z, 2.0, y - 0.6, y + 0.5, n=8))
        self.ocupar(x, z, 2.4)
        self.pontos["geiseres"].append([round(x, 2), round(y + 0.55, 2), round(z, 2)])

    # ------------------------------------------------------------------
    def costela(self, base, topo, ponta, raio, setor):
        pts = [base, topo, ponta]
        dense = []
        for k in range(9):
            t = k / 8.0
            # bezier quadratica
            x = (1 - t) ** 2 * base[0] + 2 * (1 - t) * t * topo[0] + t * t * ponta[0]
            y = (1 - t) ** 2 * base[1] + 2 * (1 - t) * t * topo[1] + t * t * ponta[1]
            z = (1 - t) ** 2 * base[2] + 2 * (1 - t) * t * topo[2] + t * t * ponta[2]
            dense.append((x, y, z))
        raios = [raio * (1.0 - 0.6 * k / 8.0) for k in range(9)]
        self.m.add_pecas(setor, "osso", [tubo_redondo(dense, raios, n=7)], suave=True)
        _ = pts

    def colossos(self):
        """Esqueletos gigantes: uma caixa toracica que o caminho atravessa por
        baixo, um cranio meio enterrado e espinhas dorsais."""
        rnd = self.rnd
        # caixa toracica atravessando o caminho
        for zc, escala in ((96.0, 1.0), (30.0, 0.8)):
            i = LINHA.em_z(zc)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            lx, lz = -tz, tx
            w = q[2] * 0.95
            setor = "colosso_%d" % int(zc)
            y = q[3]
            # a espinha corre ao longo do caminho, alta
            espinha = []
            for k in range(-6, 7):
                px, pz = q[0] + tx * k * 5.0, q[1] + tz * k * 5.0
                espinha.append((px + lx * 2.0, y + 30.0 * escala - abs(k) * 0.6, pz + lz * 2.0))
            self.m.add_pecas(setor, "osso", [tubo_redondo(espinha, [2.2 * escala] * len(espinha), n=8)], suave=True)
            for k in range(-6, 7, 2):
                px, pz = espinha[k + 6][0], espinha[k + 6][2]
                py = espinha[k + 6][1]
                self.m.add_pecas(setor, "osso", [cilindro(px, pz, 3.0 * escala, py - 1.6, py + 1.6, n=8)])
                for s in (-1, 1):
                    # a costela desce em arco e crava no chao fora do caminho
                    bx, bz = px + lx * s * (w + 6.0), pz + lz * s * (w + 6.0)
                    by = altura(bx, bz)
                    self.costela((px, py, pz), (px + lx * s * (w + 2.0), py + 4.0 * escala, pz + lz * s * (w + 2.0)),
                                 (bx, by - 2.0, bz), 1.4 * escala, setor)
        # cranio colossal meio enterrado a beira do caminho
        x, y, z, i = self.ponto(62.0, -1.25)
        setor = "cranio"
        r = 16.0
        # no meio da encosta a frente dele ficava 15 m no ar, por cima do
        # caminho: desce ate' o chao mais baixo do pe' (o resto entra no morro)
        y = min(y, self.pe(x, z, r) + 4.0)
        self.m.add_pecas(setor, "osso", [cilindro(x, z, r, y - 6.0, y + r * 0.8, n=14, raio_topo=r * 0.55),
                                         domo(x, z, r * 0.56, 5.0, n=14, aneis=3)], suave=True)
        self._levantar_ultimo(setor, "osso", y + r * 0.8, ultimos=1)
        for s in (-1, 1):
            # orbitas escuras viradas pro caminho
            tx, tz = LINHA.t[i]
            ox, oz = x + (-tz) * r * 0.75 + tx * s * 4.5, z + tx * r * 0.75 + tz * s * 4.5
            self.m.add_pecas(setor, "escuro", [cilindro(ox, oz, 2.6, y + r * 0.35, y + r * 0.55, n=10)])
        for k in range(7):
            a = rnd.uniform(-0.6, 0.6)
            tx, tz = LINHA.t[i]
            bx = x + (-tz) * r * 0.85 + tx * k * 2.6 - tx * 8
            bz = z + tx * r * 0.85 + tz * k * 2.6 - tz * 8
            # a raiz do dente entra no osso: na altura dele (y + 2) o tronco de
            # cone ja' afinou pra menos que os 0,85 r de onde o dente saia
            rr = r - r * 0.45 * 8.0 / (r * 0.8 + 6.0) - 0.6
            dd = math.hypot(bx - x, bz - z)
            if dd > rr:
                bx, bz = x + (bx - x) * rr / dd, z + (bz - z) * rr / dd
            self.m.add_pecas(setor, "osso", [espinho((bx, y + 2.0, bz), (bx + (-tz) * 3.0, y - 1.0, bz + tx * 3.0 + a), 0.7, n=5)])
        self.col.append(cilindro(x, z, r, y - 6.0, y + 12.0, n=12))
        self.ocupar(x, z, r + 1.0)
        # ossos soltos pelo campo
        for k in range(40):
            z = rnd.uniform(-10.0, 140.0)
            x, y, zz, i = self.ponto(z, rnd.uniform(-0.9, 0.9))
            if not self.livre(x, zz, 2.0):
                continue
            setor = self.setor_grade("ossos", x, zz, SETOR)
            a = rnd.uniform(0, math.pi)
            comp = rnd.uniform(3.0, 9.0)
            p0 = (x - math.cos(a) * comp / 2, y + 0.3, zz - math.sin(a) * comp / 2)
            p1 = (x + math.cos(a) * comp / 2, y + rnd.uniform(0.3, 2.5), zz + math.sin(a) * comp / 2)
            # os dois nos do osso descem ate' o chao: a ponta levantada fica
            # escorada no proprio no, nao no ar
            self.m.add_pecas(setor, "osso", [tubo_redondo([p0, p1], [0.45, 0.35], n=6)]
                             + self.firmar([cilindro(p0[0], p0[2], 0.7, y - 0.2, y + 0.9, n=6),
                                            cilindro(p1[0], p1[2], 0.6, p1[1] - 0.6, p1[1] + 0.5, n=6)], 0.3))
            if comp > 5.0:
                self.col.append(tubo_redondo([p0, p1], [0.6, 0.6], n=6))
                self.bloquear_linha(p0[0], p0[2], p1[0], p1[2], 0.8)
            self.ocupar(x, zz, 1.0, bloqueia=False)
        self.pontos["areas"]["area_4_colossos"] = list(self.ponto(70.0)[:3])

    def _levantar_ultimo(self, setor, mat, y, ultimos=1):
        """O `domo` nasce no y=0: sobe os vertices dele (os ultimos que
        entraram no grupo)."""
        g = self.m.grupos[(setor, mat)]
        n_dom = 1 + 3 * 14 + 1
        for i in range(len(g["v"]) - n_dom, len(g["v"])):
            vx, vy, vz = g["v"][i]
            g["v"][i] = (vx, vy + y, vz)
        _ = ultimos

    def espinhos(self):
        """Espinhos de obsidiana de ate' 25 m, tortos, e gaiolas penduradas."""
        rnd = self.rnd
        feitos = 0
        for k in range(120):
            z = rnd.uniform(-118.0, 8.0)
            lado = rnd.choice((-1, 1)) * rnd.uniform(0.35, 1.25)
            x, y, zz, i = self.ponto(z, lado)
            dentro = abs(lado) <= 1.0
            if not self.livre(x, zz, 2.5 if dentro else 1.0):
                continue
            if y < LAVA + 1:
                continue
            setor = self.setor_grade("espinhos", x, zz, SETOR)
            alt = rnd.uniform(5.0, 12.0) if dentro else rnd.uniform(12.0, 26.0)
            r = alt * rnd.uniform(0.06, 0.1)
            ponta = (x + rnd.uniform(-alt * 0.25, alt * 0.25), y + alt, zz + rnd.uniform(-alt * 0.25, alt * 0.25))
            # fora do caminho ele nasce na beira: o pe' desce ate' o chao que
            # se ve' (a grade grossa passa metros abaixo da `altura` ali)
            yb = min(y, self.pe(x, zz, r)) - 1.0
            self.m.add_pecas(setor, "obsidiana", [espinho((x, yb, zz), ponta, r, n=5)])
            # galhos-espinho (no eixo do espinho, que agora sai de mais baixo)
            for g in range(rnd.randint(0, 3)):
                t = rnd.uniform(0.3, 0.7)
                b = (lerp(x, ponta[0], t), lerp(yb + 1.0, ponta[1], t), lerp(zz, ponta[2], t))
                a = rnd.uniform(0, 2 * math.pi)
                self.m.add_pecas(setor, "obsidiana", [espinho(b, (b[0] + math.cos(a) * alt * 0.25, b[1] + alt * 0.15,
                                                                  b[2] + math.sin(a) * alt * 0.25), r * 0.4, n=4)])
            if dentro:
                self.col.append(cilindro(x, zz, r * 1.1 + 0.2, y - 1.0, y + 4.0, n=6))
                self.ocupar(x, zz, r + 1.2)
            else:
                self.ocupar(x, zz, r + 0.5, bloqueia=False)
            feitos += 1
        # traves com gaiolas penduradas por corrente
        for z in (-14.0, -42.0, -70.0, -96.0):
            x, y, zz, i = self.ponto(z, 0.0)
            tx, tz = LINHA.t[i]
            lx, lz = -tz, tx
            w = LINHA.p[i][2] + 4.0
            setor = self.setor_grade("gaiolas", x, zz, SETOR)
            a = (x + lx * w, zz + lz * w)
            b = (x - lx * w, zz - lz * w)
            ya, yb = altura(*a), altura(*b)
            topo = max(ya, yb, y) + 14.0
            self.m.add_pecas(setor, "obsidiana", [espinho((a[0], min(ya, self.pe(a[0], a[1], 1.4)) - 1, a[1]),
                                                          (a[0], topo + 3, a[1]), 1.4, n=5),
                                                  espinho((b[0], min(yb, self.pe(b[0], b[1], 1.4)) - 1, b[1]),
                                                          (b[0], topo + 3, b[1]), 1.4, n=5),
                                                  tubo([(a[0], topo, a[1]), (b[0], topo, b[1])], 0.8, 1.0)])
            for c in range(3):
                t = (c + 1) / 4.0 + rnd.uniform(-0.05, 0.05)
                gx, gz = lerp(a[0], b[0], t), lerp(a[1], b[1], t)
                gy = topo - rnd.uniform(5.0, 9.0)
                pecas = corrente_vertical(gx, gz, topo, gy + 2.2)
                for bb in range(8):
                    an = 2 * math.pi * bb / 8
                    pecas.append(caixa((gx + math.cos(an) * 0.7 - 0.04, gy, gz + math.sin(an) * 0.7 - 0.04),
                                       (gx + math.cos(an) * 0.7 + 0.04, gy + 2.2, gz + math.sin(an) * 0.7 + 0.04)))
                pecas.append(cilindro(gx, gz, 0.8, gy - 0.1, gy + 0.05, n=8))
                pecas.append(cilindro(gx, gz, 0.8, gy + 2.15, gy + 2.3, n=8, raio_topo=0.4))
                self.m.add_pecas(setor, "metal", pecas)
                # um corpo encolhido dentro de algumas
                if c != 1:
                    self.m.add_pecas(setor, "carne_seca", [cilindro(gx, gz, 0.35, gy + 0.05, gy + 1.1, n=6, raio_topo=0.2)])
            self.col.append(cilindro(a[0], a[1], 1.6, ya - 1, ya + 6, n=6))
            self.col.append(cilindro(b[0], b[1], 1.6, yb - 1, yb + 6, n=6))
        self.pontos["areas"]["area_5_espinhos"] = list(self.ponto(-50.0)[:3])

    def catedral(self):
        """Uma catedral gotica engolida de lado, nave inclinada e torre
        partida, com tentaculo saindo pela rosacea. Nao se entra: e' o
        marco da area."""
        # DENTRO do caminho, no lado direito da parte mais larga: o jogador
        # passa rente a' nave (fora do caminho ela ficaria em cima do penhasco)
        x, y, z, i = self.ponto(-168.0, -0.66)
        tx, tz = LINHA.t[i]
        giro = math.atan2(tx, tz)
        setor = "catedral"
        ca, sa = math.cos(giro), math.sin(giro)

        def P(lx, ly, lz):
            return (x + lx * ca + lz * sa, y + ly, z - lx * sa + lz * ca)

        inc = 0.16   # afundada e torta
        w, comp, h = 14.0, 60.0, 26.0
        pecas = []
        for k in range(6):
            lz0 = -comp / 2 + k * comp / 6
            afunda = -6.0 - k * 1.6
            for s in (-1, 1):
                cx_, cy_, cz_ = P(s * w, afunda + h / 2, lz0 + comp / 12)
                pecas.append(caixa_girada(cx_, cy_, cz_, 2.2, h, comp / 6 - 0.4, giro, inc * s * 0.4))
                # contraforte
                bx, by, bz = P(s * (w + 3.5), afunda + h * 0.35, lz0 + comp / 12)
                pecas.append(caixa_girada(bx, by, bz, 3.0, h * 0.7, 2.0, giro, 0.0))
                # janela ogival acesa
                jx, jy, jz = P(s * (w - 1.2), afunda + h * 0.55, lz0 + comp / 12)
                self.m.add_pecas(setor, "vitral", [caixa_girada(jx, jy, jz, 0.3, h * 0.4, comp / 6 * 0.4, giro, 0.0)])
        # telhado partido: cada metade tomba pro comprido da nave e a ponta
        # baixa deita no alto da parede (antes ficava 1 a 4 m acima dela)
        telhado = []
        for k in range(4):
            lz0 = -comp / 2 + k * comp / 5
            for s in (-1, 1):
                lz_baixa = lz0 + comp / 10 + (comp / 10 - 0.5) * s
                kp = min(5, max(0, int((lz_baixa + comp / 2) // (comp / 6))))
                topo_parede = -6.0 - kp * 1.6 + h - 0.3
                meio = (comp / 10 - 0.5) * math.sin(0.5) + 0.4 * math.cos(0.5)
                cx_, cy_, cz_ = P(s * w * 0.5, topo_parede - 0.6 + meio, lz0 + comp / 10)
                telhado.append(caixa_girada(cx_, cy_, cz_, w * 1.2, 0.8, comp / 5 - 1.0, giro + s * 0.02, s * 0.5))
        # fachada com rosacea e torre partida
        fx, fy, fz = P(0, -4.0 + h / 2, comp / 2)
        pecas.append(caixa_girada(fx, fy, fz, 2 * w + 2.0, h + 4.0, 2.4, giro, -0.05))
        rc = P(0, -4.0 + h * 0.7, comp / 2 + 1.3)
        anel = [(rc[0] + 6.0 * math.cos(2 * math.pi * k / 24) * ca, rc[1] + 6.0 * math.sin(2 * math.pi * k / 24),
                 rc[2] - 6.0 * math.cos(2 * math.pi * k / 24) * sa) for k in range(25)]
        self.m.add_pecas(setor, "pedra", [tubo_redondo(anel, [0.6] * 25, n=6)])
        disco = []
        for k in range(16):
            a0, a1 = 2 * math.pi * k / 16, 2 * math.pi * (k + 1) / 16
            p0 = (rc[0] + 5.6 * math.cos(a0) * ca, rc[1] + 5.6 * math.sin(a0), rc[2] - 5.6 * math.cos(a0) * sa)
            p1 = (rc[0] + 5.6 * math.cos(a1) * ca, rc[1] + 5.6 * math.sin(a1), rc[2] - 5.6 * math.cos(a1) * sa)
            disco.append(hexaedro([rc, p0, p1, rc,
                                   (rc[0] + sa * 0.2, rc[1], rc[2] + ca * 0.2), (p0[0] + sa * 0.2, p0[1], p0[2] + ca * 0.2),
                                   (p1[0] + sa * 0.2, p1[1], p1[2] + ca * 0.2), (rc[0] + sa * 0.2, rc[1], rc[2] + ca * 0.2)]))
        self.m.add_pecas(setor, "vitral", disco)
        for s in (-1, 1):
            tx_, ty_, tz_ = P(s * (w + 2.0), -6.0 + 22.0, comp / 2 - 3.0)
            pecas.append(caixa_girada(tx_, ty_, tz_, 7.0, 44.0, 7.0, giro, 0.08 * s))
            if s > 0:
                pecas.append(espinho(P(s * (w + 2.0) + 2.0, 38.0, comp / 2 - 3.0), P(s * (w + 2.0) + 7.0, 62.0, comp / 2 - 6.0),
                                     4.6, n=4))
            else:
                self.m.add_pecas(setor, "pedra", assentar(entulho(*P(s * (w + 8.0), 0, comp / 2 + 6.0)[::2], 6.0, 18,
                                                                  self.rnd, y=y, tamanho=(1.0, 3.0)), self.chao_v))
        # a ponta da nave sai da beira do caminho: paredes, contrafortes,
        # fachada e torres descem ate' o chao que se ve' (a agulha partida,
        # que comeca la' em cima, fica como esta')
        baixas = [pc for pc in pecas if min(q[1] for q in pc[0]) < y + 1.0]
        altas = [pc for pc in pecas if min(q[1] for q in pc[0]) >= y + 1.0]
        self.m.add_pecas(setor, "pedra", self.firmar(baixas, 1.0) + altas + telhado)
        # tentaculos atravessando o telhado e a rosacea. Os do telhado
        # nasciam no ar, dentro da nave: recuam pelo proprio eixo ate' a raiz
        # entrar no chao, e crescem o mesmo tanto
        for k, (lx, lz, comp_t) in enumerate(((0.0, comp / 2 + 2.0, 26.0), (-6.0, 0.0, 34.0), (7.0, -18.0, 30.0))):
            b = P(lx, h * 0.5 if k == 0 else h * 0.75, lz)
            d = (sa * 0.6, 0.9, ca * 0.6) if k == 0 else (math.sin(k) * 0.4, 1.0, math.cos(k) * 0.4)
            if k > 0:
                b, comp_t = raiz_no_chao(b, d, comp_t, self.chao_v, raio=2.2)
            tentaculo(self, setor, "carne", b, d, comp_t, 2.2, curva=1.0, fase=k * 1.7, ventosas="osso")
        self.col.append(caixa_girada(x, y + 10.0, z, 2 * w + 10.0, 40.0, comp + 6.0, giro))
        self.ocupar(x, z, comp / 2 + 6.0, bloqueia=False)
        self.pontos["areas"]["area_6_catedral"] = list(self.ponto(-160.0)[:3])

    def crista(self):
        """A trilha estreita entre duas lavas: pilares quebrados de borda e
        geiseres."""
        rnd = self.rnd
        for z in range(-232, -340, -9):
            for s in (-1, 1):
                if rnd.random() < 0.35:
                    continue
                x, y, zz, i = self.ponto(z + rnd.uniform(-3, 3), s * 1.15)
                if y < LAVA:
                    y = LAVA
                setor = self.setor_grade("crista", x, zz, SETOR)
                h = rnd.uniform(2.0, 9.0)
                pilar = pilar_composto(x, zz, y - 2.0, y + h, r_nucleo=0.6, r_colunete=0.2)[0]
                # na beira da lava o chao despenca: o plinto desce ate' ele
                self.m.add_pecas(setor, "pedra", self.firmar(pilar[:1]) + pilar[1:])
        for z in (-246.0, -282.0, -308.0):
            for _t in range(10):
                x, y, zz, i = self.ponto(z + rnd.uniform(-4, 4), rnd.uniform(-0.5, 0.5))
                if self.livre(x, zz, 3.0):
                    break
            self.geiser(x, y, zz)
        self.pontos["areas"]["area_7_crista"] = list(self.ponto(-290.0)[:3])

    def portal(self):
        """A saida: anel de osso e obsidiana de 26 m em cima de uma escadaria
        rasa. O redemoinho de dentro e' do Godot (shader)."""
        x, z = 0.0, -432.0
        y, yc = self._anel(x, z, 1.0, "portal")
        self.pontos["portal"] = [x, yc, z]
        self.pontos["saida"] = [x, y + 1.2, z]
        self.pontos["areas"]["area_8_portal"] = [x, y + 1.2, z + 18.0]

    def portal_entrada(self):
        """O anel por onde se CHEGA: o mesmo da saida, na frente do portao
        fechado, de costas pra ele (a rampa desce pro norte, pro caminho)."""
        x, z = 0.0, ANEL_ENTRADA
        y, yc = self._anel(x, z, -1.0, "portal_entrada")
        self.pontos["portal_entrada"] = [x, yc, z]
        self.pontos["entrada"] = [x, y + 1.2, z]

    def _anel(self, x, z, f, setor):
        """Anel de 26 m em cima de uma plataforma rasa; `f` = +1 se a rampa
        (o lado de onde se chega) fica pro +z, -1 se fica pro -z. Devolve a
        altura do chao e a do centro do anel."""
        y = altura(x, z)
        r = 13.0
        # plataforma (rampa suave na colisao)
        self.m.add_pecas(setor, "obsidiana", [cilindro(x, z, 18.0, y - 2.0, y + 0.6, n=24, raio_topo=17.0),
                                             cilindro(x, z, 14.0, y + 0.6, y + 1.2, n=24, raio_topo=13.5)])
        # colisao: UM tronco de cone (lado a 39 graus, da' pra subir) em vez
        # dos dois patamares do desenho — patamar de 60 cm e' degrau, e o
        # CharacterBody3D nao sobe degrau
        self.col.append(cilindro(x, z, 18.5, y - 2.0, y + 1.2, n=20, raio_topo=14.0))
        # rampa de acesso pela frente, mais comprida que a escadaria do desenho
        # pra nao sobrar quina
        self.col.append(hexaedro([(x - 8, y - 1.0, z + 26.0 * f), (x + 8, y - 1.0, z + 26.0 * f),
                                  (x + 8, y - 1.0, z + 8.0 * f), (x - 8, y - 1.0, z + 8.0 * f),
                                  (x - 8, y, z + 26.0 * f), (x + 8, y, z + 26.0 * f),
                                  (x + 8, y + 1.2, z + 8.0 * f), (x - 8, y + 1.2, z + 8.0 * f)]))
        degraus = []
        for k in range(6):
            zz = z + (23.0 - k * 2.0) * f
            degraus.append(caixa((x - 8, y - 1.0, zz - 1.0), (x + 8, y + 0.2 * (k + 1), zz + 1.0)))
        self.m.add_pecas(setor, "obsidiana", degraus)
        yc = y + 1.2 + r + 1.0
        anel = [(x + r * math.sin(2 * math.pi * k / 48), yc + r * math.cos(2 * math.pi * k / 48), z) for k in range(49)]
        self.m.add_pecas(setor, "obsidiana", [tubo_redondo(anel, [1.5] * 49, n=10)], suave=True)
        anel2 = [(x + (r - 1.6) * math.sin(2 * math.pi * k / 48), yc + (r - 1.6) * math.cos(2 * math.pi * k / 48),
                  z + 0.4 * f) for k in range(49)]
        self.m.add_pecas(setor, "brasa", [tubo_redondo(anel2, [0.35] * 49, n=6)])
        esp = []
        for k in range(30):
            a = 2 * math.pi * k / 30
            comp = 8.0 if k % 2 == 0 else 4.0
            esp.append(espinho((x + (r + 1.0) * math.sin(a), yc + (r + 1.0) * math.cos(a), z),
                               (x + (r + comp) * math.sin(a), yc + (r + comp) * math.cos(a), z - 1.0 * f), 0.6, n=5))
        self.m.add_pecas(setor, "osso", esp)
        for s in (-1, 1):
            # o pilar passa da beira do patamar de cima: nasce no de baixo
            self.m.add_pecas(setor, "obsidiana", [caixa((x + s * (r + 1.0) - 1.5, y + 0.6, z - 1.5),
                                                        (x + s * (r + 1.0) + 1.5, yc, z + 1.5))])
            self.col.append(caixa((x + s * (r + 1.0) - 1.5, y + 1.2, z - 1.5), (x + s * (r + 1.0) + 1.5, yc, z + 1.5)))
        return y, yc

    def braseiros(self):
        """Pira de pedra com fogo marcando o caminho a cada ~70 m: a luz que
        guia no escuro, e o unico jeito de saber de longe pra onde se vai."""
        s = 0.0
        prox = 30.0
        for k in range(1, len(LINHA.p)):
            s += math.hypot(LINHA.p[k][0] - LINHA.p[k - 1][0], LINHA.p[k][1] - LINHA.p[k - 1][1])
            if s < prox:
                continue
            prox += 70.0
            q = LINHA.p[k]
            if not (Z_FIM + 30 < q[1] < Z_INICIO - 30):
                continue
            if abs(q[1] - PONTE[1]) < PONTE_COMP + 6:
                continue
            for lado in ((-0.82,) if k % 2 else (0.82,)):
                x, y, z, i = self.ponto(q[1], lado)
                if not self.livre(x, z, 2.0):
                    x, y, z, i = self.ponto(q[1], -lado)
                setor = self.setor_grade("piras", x, z, SETOR)
                self.m.add_pecas(setor, "obsidiana", self.firmar([cilindro(x, z, 1.1, y - 0.5, y + 1.5, n=6, raio_topo=0.8)])
                                 + [cilindro(x, z, 1.25, y + 1.5, y + 1.9, n=8, raio_topo=1.4)])
                self.m.add_pecas(setor, "brasa", [cilindro(x, z, 1.15, y + 1.8, y + 1.95, n=8)])
                for c in range(4):
                    a = c * math.pi / 2 + 0.4
                    self.m.add_pecas(setor, "osso", [espinho((x + math.cos(a) * 1.2, y + 1.6, z + math.sin(a) * 1.2),
                                                             (x + math.cos(a) * 1.9, y + 3.0, z + math.sin(a) * 1.9),
                                                             0.18, n=4)])
                self.col.append(cilindro(x, z, 1.2, y - 0.5, y + 1.9, n=6))
                self.ocupar(x, z, 1.6)
                self.pontos["braseiros"].append([round(x, 2), round(y + 2.0, 2), round(z, 2)])

    # ------------------------------------------------------------------
    def longe(self):
        rnd = self.rnd
        # vulcoes com cratera acesa
        for (x, z, r, h) in ((-420.0, 120.0, 180.0, 230.0), (460.0, -60.0, 220.0, 280.0),
                             (-380.0, -420.0, 160.0, 200.0), (380.0, 380.0, 150.0, 170.0),
                             (60.0, -820.0, 260.0, 320.0)):
            self.m.add_pecas("vulcoes", "rocha_longe", [cilindro(x, z, r, LAVA - 10.0, h, n=16, raio_topo=r * 0.18)])
            self.m.add_pecas("vulcoes", "lava_brilho", [cilindro(x, z, r * 0.17, h - 0.5, h + 1.5, n=16, raio_topo=r * 0.14)])
            self.pontos.setdefault("vulcoes", []).append([x, h + 2.0, z])
        # ilhas de rocha e espinhos no mar de lava
        for k in range(70):
            a = rnd.uniform(0, 2 * math.pi)
            x = rnd.uniform(-520.0, 520.0)
            z = rnd.uniform(-700.0, 700.0)
            kk, lat, d = LINHA.perto(x, z)
            if kk is not None and abs(lat) < LINHA.p[kk][2] + 110.0:
                continue
            h = rnd.uniform(10.0, 60.0)
            self.m.add_pecas("ilhas", "rocha_longe", [espinho((x, LAVA - 4.0, z), (x + rnd.uniform(-10, 10), LAVA + h, z + rnd.uniform(-10, 10)),
                                                              rnd.uniform(6.0, 18.0), n=6)])
            _ = a
        # ruinas e torres no horizonte
        for k in range(30):
            a = rnd.uniform(0, 2 * math.pi)
            r = rnd.uniform(380.0, 700.0)
            x, z = r * math.sin(a), r * math.cos(a) * 1.3
            silhueta_gotica(self, "horizonte", "silhueta", x, z, rnd.uniform(12.0, 30.0), rnd.uniform(30.0, 80.0), rnd,
                            giro=rnd.uniform(0, math.pi))
        g = self.m.grupos[("horizonte", "silhueta")]
        g["v"] = [(vx, vy + LAVA - 2.0, vz) for vx, vy, vz in g["v"]]

    def sombras(self):
        """As SOMBRAS: figuras de 40 a 160 m de pe' no mar de lava, longe do
        caminho. Cada uma e' um objeto solto com o pivo no pe' — o
        `inferno.gd` as balanca e faz andar devagar."""
        rnd = self.rnd
        feitas = 0
        tent = 0
        while feitas < 14 and tent < 400:
            tent += 1
            z = rnd.uniform(-420.0, 420.0)
            i = LINHA.em_z(z)
            q = LINHA.p[i]
            lado = rnd.choice((-1, 1))
            dist = q[2] + rnd.uniform(110.0, 230.0)
            tx, tz = LINHA.t[i]
            x = q[0] - tz * dist * lado
            zz = q[1] + tx * dist * lado
            # so' em cima da lava (no penhasco ela ficaria enterrada na rocha)
            if altura(x, zz) > LAVA + 2.0:
                continue
            alt = rnd.uniform(60.0, 170.0)
            v, f = _figura(alt, rnd, feitas % 3)
            self.soltos.append(("SOMBRA_%d" % feitas, "sombra", (v, f), (x, LAVA - 1.0, zz)))
            feitas += 1

    def cercadura(self):
        """Muro invisivel dos dois lados do caminho inteiro + tampa nas pontas.
        Vertice que cair DENTRO do caminho de outro trecho (curva fechada) e'
        descartado, senao o muro cortaria a trilha."""
        for lado in (-1, 1):
            pts = []
            for k in range(0, len(LINHA.p), 2):
                q = LINHA.p[k]
                if not (Z_FIM - 1 <= q[1] <= Z_INICIO + 1):
                    continue
                tx, tz = LINHA.t[k]
                off = q[2] + 0.5
                x = q[0] - tz * off * lado
                z = q[1] + tx * off * lado
                kk, lat, d = LINHA.perto(x, z)
                if kk is not None and abs(lat) < LINHA.p[kk][2] - 0.5:
                    continue
                pts.append((x, z))
            muro_invisivel(self, pts, y0=-30.0, y1=60.0, esp=1.6, fechar=False)
            if lado == -1:
                esq = pts
            else:
                dirr = pts
        # tampas
        for zt in (Z_INICIO, Z_FIM):
            i = LINHA.em_z(zt)
            q = LINHA.p[i]
            self.col.append(caixa((q[0] - q[2] - 3, -30.0, zt - 0.8), (q[0] + q[2] + 3, 60.0, zt + 0.8)))
        _ = (esq, dirr)

    def _marcadores(self):
        nav = self.pontos["navmesh"]
        centros = []
        for poly in nav["p"]:
            n = float(len(poly))
            centros.append((sum(nav["v"][k][0] for k in poly) / n, sum(nav["v"][k][1] for k in poly) / n,
                            sum(nav["v"][k][2] for k in poly) / n))
        usados = set()
        for z in range(380, -400, -48):
            for lado in (-0.4, 0.4):
                x, y, zz, i = self.ponto(float(z), lado)
                melhor, md = None, 1e18
                for k, c in enumerate(centros):
                    if k in usados:
                        continue
                    d = (c[0] - x) ** 2 + (c[2] - zz) ** 2
                    if d < md:
                        melhor, md = k, d
                if melhor is not None and md < 100.0:
                    usados.add(melhor)
                    c = centros[melhor]
                    self.pontos["inimigos"].append([round(c[0], 2), round(c[1] + 0.1, 2), round(c[2], 2)])


def _figura(alt, rnd, tipo):
    """Figura alta e magra em coordenada LOCAL (pe' no zero). Tres tipos:
    0 = gente esticada, 1 = com galhada, 2 = curvada com tentaculos."""
    pecas = []
    h = alt
    larg = h * rnd.uniform(0.05, 0.08)
    curva = 0.12 if tipo == 2 else 0.02
    pernas = []
    for s in (-1, 1):
        pernas.append([(s * larg * 0.6, 0.0, 0.0), (s * larg * 0.55, h * 0.25, h * 0.01), (s * larg * 0.4, h * 0.48, 0.0)])
    for p in pernas:
        pecas.append(tubo_redondo(p, [larg * 0.32, larg * 0.28, larg * 0.36], n=6))
    tronco = [(0.0, h * 0.46, 0.0), (0.0, h * 0.62, h * curva * 0.4), (0.0, h * 0.8, h * curva)]
    pecas.append(tubo_redondo(tronco, [larg * 0.75, larg * 0.7, larg * 0.85], n=7))
    cab = (0.0, h * 0.86, h * curva * 1.4)
    pecas.append(tubo_redondo([(0.0, h * 0.8, h * curva), cab, (0.0, h * 0.93, h * curva * 1.6)],
                              [larg * 0.3, larg * 0.45, larg * 0.2], n=6))
    for s in (-1, 1):
        braco = [(s * larg * 0.8, h * 0.78, h * curva), (s * larg * 1.4, h * 0.6, h * curva * 1.5),
                 (s * larg * 1.6, h * 0.38, h * curva * 2.0), (s * larg * 1.5, h * 0.22, h * curva * 2.4)]
        pecas.append(tubo_redondo(braco, [larg * 0.25, larg * 0.22, larg * 0.18, larg * 0.08], n=5))
        if tipo == 1:
            base = (s * larg * 0.3, h * 0.92, h * curva * 1.5)
            for g in range(3):
                pecas.append(espinho(base, (s * larg * (1.4 + g), h * (1.0 + g * 0.05), h * curva * 1.5 - g * larg),
                                     larg * 0.08, n=4))
    if tipo == 2:
        for k in range(4):
            a = k * 1.6
            pts = [(0.0, h * 0.8, h * curva)]
            for j in range(1, 6):
                t = j / 5.0
                pts.append((math.sin(a) * larg * 2.5 * t, h * (0.8 - 0.25 * t) + math.sin(t * 3 + a) * larg,
                            h * curva + math.cos(a) * larg * 2.5 * t))
            pecas.append(tubo_redondo(pts, [larg * 0.2 * (1 - j / 6.0) + 0.05 for j in range(6)], n=5))
    v, f = [], []
    for pv, pf in pecas:
        b = len(v)
        v.extend(pv)
        f.extend([[k + b for k in face] for face in pf])
    return v, f


def main():
    global LINHA
    LINHA = Linha()
    inf = Inferno()
    inf.montar()
    print("  linha: %d pontos, %.0f m" % (len(LINHA.p), LINHA.s[-1]))
    inf.exportar("inferno", "inferno", abertos=("chao_", "lava_mar", "lava_rio", "cachoeiras"))
    nav = inf.pontos["navmesh"]
    print("  navmesh: %d vertices, %d poligonos" % (len(nav["v"]), len(nav["p"])))
    print("  braseiros=%d geiseres=%d inimigos=%d sombras=%d" % (
        len(inf.pontos["braseiros"]), len(inf.pontos["geiseres"]), len(inf.pontos["inimigos"]), len(inf.soltos)))


if __name__ == "__main__":
    main()
