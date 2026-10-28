# -*- coding: utf-8 -*-
"""Modela o INFERNO 2 — O FUNIL — e exporta pro Godot.

    blender --background --factory-startup \\
        --python tools/blender/inferno_2/gerar_inferno_2.py

Saidas:
    red-valve/assets/3d_model/stages/inferno_2/inferno_2.glb
    red-valve/assets/3d_model/stages/inferno_2/inferno_2_pontos.json

Depois: `tools/godot/inferno_2/gerar_cena_inferno_2.py` e `--headless --import`.

==============================================================================
O LUGAR

A continuacao do inferno: o portal do fim do primeiro mapa cospe o jogador
num esporao de rocha do LADO DE FORA de uma cratera gigante. Dentro dela, um
POCO sem fundo e um caminho que DESCE em espiral pelas paredes, em terracos —
os circulos do inferno. Mesma logica do primeiro (linha de centro com largura,
altura e tipo de borda por ponto; caminho linear, largo e longo, subidas e
descidas leves), mas o caminho e' outro: em vez de ir em frente, ele da' uma
volta e tres quartos no poco, e de cada terraco se ve o de baixo.

   1 A CHEGADA          esporao sobre o mar de lava, o anel por onde se chega
   2 A FENDA            garganta estreita que corta a borda da cratera
   3 O MIRANTE          primeiro circulo, largo: o funil inteiro la' embaixo
   4 A CASCATA          um rio de lava que desce o funil cruzando o caminho
   5 A FORJA            bigornas, caldeiroes e geiseres
   6 OS ENFORCADOS      arcos de osso com ganchos e gaiolas sobre o abismo
   7 A GARGANTA         segundo circulo, estreito, a cascata outra vez
   8 A PONTE            ponte de correntes sobre o abismo
   9 A AGULHA           a torre no meio do poco; a saida e' a BOCA aberta
                        na base dela

==============================================================================
COMO O CHAO E' FEITO

Igual ao do primeiro (ver gerar_inferno.py), com tres coisas novas:
  - TERRACO: o lado de dentro da primeira volta despenca LOGO na beira do
    caminho, ate' o `fundo` — a altura da volta de baixo no mesmo angulo; o
    lado de fora da volta de baixo e' uma laje plana na altura dela ate' o pe'
    desse penhasco. As duas contas se encontram na mesma altura. (Ao contrario
    — laje plana em cima — a laje escondia o circulo de baixo: de 1,7 m de
    olho nao se ve' nada abaixo da borda de uma laje de 10 m.)
  - CRATERA: toda parede e' cortada pela borda da cratera
    (`crista`), que do lado de fora desce ate' o mar de lava;
  - dois niveis de lava: o MAR (fora da cratera) e o fundo do POCO.
A busca do ponto mais perto guarda candidatos de varias voltas por celula —
com uma so' semente, o meio do vao entre duas voltas sairia com a volta errada.
"""

import math
import os
import sys

# o .pyc da base (e o do gerador da arena 2, versionado) nao pode nascer
# antes de a base desligar o bytecode: desliga aqui, antes de importar
sys.dont_write_bytecode = True
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "cenarios"))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "inferno"))

from base import (Cena, assentar, caixa, caixa_girada, chao_sob,  # noqa: E402
                  chao_visivel, chapa_aberta, chapa_grossa, cilindro,
                  corrente_vertical, entulho, espinho, estender_ate_o_chao,
                  hexaedro, lerp, muro_invisivel, navmesh_grade, pilar_composto,
                  raiz_no_chao, ruido2, silhueta_gotica, suave, tentaculo, tubo,
                  tubo_redondo)
from gerar_inferno import _figura, catmull  # noqa: E402

LAVA_MAR = -14.0      # o mar de fora da cratera
LAVA_POCO = -64.0     # o fundo do poco
PASSO = 4.0           # chao visivel
PASSO_COL = 2.0       # colisao do chao
PASSO_NAV = 2.5
SETOR = 64.0

# a espiral: raio, altura e voltas
R0, R1 = 150.0, 70.0
VOLTAS = 1.75
TH_FIM = 2.0 * math.pi * VOLTAS
Y0, Y1 = 30.0, -8.0
# a cratera
R_CRISTA = 184.0
Y_CRISTA = 60.0
# janelas na borda: (angulo, meia-abertura) onde a crista desce abaixo do
# caminho e se ve o mar de lava do lado de fora
JANELAS = ((2.75, 0.2), (5.2, 0.24))
# a cascata: um rio que desce o funil pelo raio deste angulo
TH_RIO = 2.0
RIO_W = 5.5
PONTE_W = 6.0
# a parte da primeira volta que ja' nao tem a segunda embaixo (abre pro poco)
TH_ABRE = TH_FIM - 2.0 * math.pi
ILHA_R = 28.0
AGULHA_R = 9.0


def r_espiral(th):
    return R0 + (R1 - R0) * th / TH_FIM


def y_espiral(th):
    """Desce de Y0 a Y1 com uma ondulacao que encolhe com o raio (no raio
    pequeno a mesma ondulacao viraria rampa forte)."""
    k = r_espiral(th) / R0
    return lerp(Y0, Y1, th / TH_FIM) + (0.7 * math.sin(th * 2.1) + 0.3 * math.sin(th * 4.7 + 1.0)) * k


def p_espiral(th):
    r = r_espiral(th)
    return r * math.sin(th), r * math.cos(th)


def _tabela(th, tab):
    """Interpolacao linear numa tabela [(th, valor)]."""
    if th <= tab[0][0]:
        return tab[0][1]
    for (a, va), (b, vb) in zip(tab, tab[1:]):
        if th <= b:
            return lerp(va, vb, (th - a) / (b - a))
    return tab[-1][1]


LARGURAS = [(0.0, 12.0), (0.3, 15.0), (1.5, 15.0), (1.75, 12.0), (2.3, 12.0), (2.6, 17.0),
            (4.1, 17.0), (4.4, 12.0), (6.0, 12.0), (6.4, 11.0), (7.8, 11.0), (8.6, 9.5),
            (10.1, 9.5), (10.5, 8.0), (TH_FIM, 7.0)]
TH_TRAVESSIAS = (TH_RIO, TH_RIO + 2.0 * math.pi)
PONTE_RIO_COMP = 11.0


def w_espiral(th):
    w = _tabela(th, LARGURAS)
    for tr in TH_TRAVESSIAS:
        # a pista afunila ate' a largura da ponte
        d = abs(th - tr) * r_espiral(th)
        if d < PONTE_RIO_COMP + 3.0:
            w = PONTE_W
        elif d < PONTE_RIO_COMP + 18.0:
            w = lerp(PONTE_W, w, suave((d - PONTE_RIO_COMP - 3.0) / 15.0))
    return w


def montar_controle():
    """Pontos de controle (x, z, w, y, abre_a, abre_b, terr_a, fundo_a,
    fundo_b). Lado A = lateral > 0 = (-tz, tx): na espiral e' o lado de FORA.
    `abre` 0 = parede subindo, 1 = beira despencando ate' o `fundo` (lava ou
    a volta de baixo); `terr_a` 1 = laje plana na altura do caminho."""
    c = []
    mar, poco = LAVA_MAR - 4.0, LAVA_POCO - 4.0
    # esporao e fenda, descendo o eixo +Z
    for z, w, y, abre in ((276.0, 16.0, 34.0, 1.0), (262.0, 16.0, 34.0, 1.0), (244.0, 15.0, 33.6, 1.0),
                          (226.0, 12.0, 33.0, 0.7), (208.0, 9.0, 32.6, 0.0), (190.0, 9.0, 31.8, 0.0),
                          (174.0, 10.0, 31.0, 0.0)):
        c.append((0.0, z, w, y, abre, abre, 0.0, mar, mar))
    th_fim = TH_FIM - 0.3
    ths = []
    th = 0.12
    while th < th_fim - 0.05:
        ths.append(th)
        th += 20.0 / r_espiral(th)
    ths.append(th_fim)
    for th in ths:
        x, z = p_espiral(th)
        if th >= 2.0 * math.pi:
            # segunda volta: laje do lado de fora, poco do lado de dentro
            c.append((x, z, w_espiral(th), y_espiral(th), 0.0, 1.0, 1.0, mar, poco))
        else:
            # primeira volta: a parede da cratera por fora e, por dentro, o
            # penhasco ate' a segunda volta — que acaba em TH_ABRE; dali pra
            # frente ele cai direto no poco
            t = suave((th - (TH_ABRE - 0.12)) / 0.24)
            fundo = lerp(y_espiral(th + 2.0 * math.pi), poco, t)
            c.append((x, z, w_espiral(th), y_espiral(th), 0.0, 1.0, 0.0, mar, fundo))
    # fim da segunda volta: um ARCO tangente a' espiral e ao eixo -X vira o
    # caminho pro centro. Raio de 16 m: curva mais fechada que o afastamento
    # do muro invisivel dobra o muro de dentro sobre si mesmo, e o canto vira
    # um bolso fechado no meio do caminho.
    ex, ez = p_espiral(th_fim)
    hx, hz = math.cos(th_fim), -math.sin(th_fim)
    raio = -ez / (1.0 - hx)            # o centro cai em (x_fim, -raio)
    cx_, cz_ = ex + hz * raio, ez - hx * raio
    a0 = math.atan2(ez - cz_, ex - cx_)
    if a0 < math.pi / 2:
        a0 += 2.0 * math.pi            # gira no sentido horario ate' 90 graus
    y_fim = y_espiral(TH_FIM)
    for k, w in ((1, 6.8), (2, 6.4), (3, 6.1), (4, PONTE_W)):
        a = lerp(a0, math.pi / 2, k / 4.0)
        c.append((cx_ + raio * math.cos(a), cz_ + raio * math.sin(a), w, lerp(y_espiral(th_fim), y_fim, k / 4.0),
                  0.5 + 0.125 * k, 1.0, max(0.0, 1.0 - 0.33 * k), poco, poco))
    # a pista chega na ponte com a largura do tabuleiro e so' alarga depois
    # da cabeceira da ilha: mais larga que ele, o vao do lado seria buraco pro
    # abismo dentro do muro invisivel
    for x, w, y in ((cx_ + 8.0, PONTE_W, y_fim + 0.1), (-38.0, PONTE_W, y_fim + 0.4), (-30.0, PONTE_W, y_fim + 0.6),
                    (-22.0, 18.0, y_fim + 0.8), (-12.0, 24.0, y_fim + 1.0), (-4.0, 26.0, y_fim + 1.2),
                    (0.0, 26.0, y_fim + 1.2)):
        c.append((x, 0.0, w, y, 1.0, 1.0, 0.0, poco, poco))
    return c


class Linha:
    """Linha de centro com busca do ponto mais perto. Cada celula da grade
    guarda o melhor ponto de CADA trecho de 60 m que passa por perto: entre
    duas voltas da espiral a semente da celula pode ser da volta errada."""

    def __init__(self, controle):
        self.p = catmull(controle)
        # o `catmull` passa a altura por smoothstep: plana em cada ponto de
        # controle e 1,5x mais inclinada entre eles (a rampa de 5% virava 8%).
        # Media movel de +-10 m devolve a inclinacao de verdade.
        ys = [q[3] for q in self.p]
        self.p = [q[:3] + (sum(ys[max(0, i - 5):i + 6]) / len(ys[max(0, i - 5):i + 6]),) + q[4:]
                  for i, q in enumerate(self.p)]
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
        self.cel = 10.0
        self.grade = {}
        alcance = 230.0
        r = int(alcance / self.cel) + 1
        for i, q in enumerate(self.p):
            if i % 3:
                continue
            trecho = int(self.s[i] / 60.0)
            ci, cj = int(math.floor(q[0] / self.cel)), int(math.floor(q[1] / self.cel))
            for di in range(-r, r + 1):
                for dj in range(-r, r + 1):
                    cx_, cz_ = (ci + di + 0.5) * self.cel, (cj + dj + 0.5) * self.cel
                    d2 = (cx_ - q[0]) ** 2 + (cz_ - q[1]) ** 2
                    if d2 > alcance * alcance:
                        continue
                    cel = self.grade.setdefault((ci + di, cj + dj), {})
                    old = cel.get(trecho)
                    if old is None or d2 < old[0]:
                        cel[trecho] = (d2, i)
        # so' os tres trechos mais perto de cada celula interessam
        for k, cel in self.grade.items():
            self.grade[k] = [i for _d, i in sorted(cel.values())[:3]]
        self._memo = {}

    def perto(self, x, z):
        """(indice, lateral com sinal, distancia) do ponto mais perto."""
        chave = (round(x, 2), round(z, 2))
        r = self._memo.get(chave)
        if r is not None:
            return r
        sementes = self.grade.get((int(math.floor(x / self.cel)), int(math.floor(z / self.cel))))
        if not sementes:
            r = (None, 1e9, 1e9)
            self._memo[chave] = r
            return r
        melhor, md = sementes[0], 1e18
        for i0 in sementes:
            for i in range(max(0, i0 - 14), min(len(self.p), i0 + 15)):
                d2 = (x - self.p[i][0]) ** 2 + (z - self.p[i][1]) ** 2
                if d2 < md:
                    melhor, md = i, d2
        tx, tz = self.t[melhor]
        px, pz = x - self.p[melhor][0], z - self.p[melhor][1]
        lateral = tx * pz - tz * px
        if melhor == 0 or melhor == len(self.p) - 1:
            # alem da ponta a lateral nao para de valer: a ponta e' redonda
            lateral = math.copysign(math.sqrt(md), lateral if lateral else 1.0)
        r = (melhor, lateral, math.sqrt(md))
        self._memo[chave] = r
        return r

    def em_s(self, s):
        """Indice do ponto com a distancia ao longo da linha mais perto de `s`."""
        lo, hi = 0, len(self.s) - 1
        while lo < hi:
            m = (lo + hi) // 2
            if self.s[m] < s:
                lo = m + 1
            else:
                hi = m
        return lo

    def em_xz(self, x, z):
        return min(range(len(self.p)), key=lambda i: (self.p[i][0] - x) ** 2 + (self.p[i][1] - z) ** 2)


LINHA = None
PONTES = []          # dicts: s, comp, w, arco, abismo
RIO = []             # polilinha da cascata (x, z), do alto da cratera pro poco
S_INICIO = 0.0
S_FIM = 0.0


def s_de_th(th):
    x, z = p_espiral(th)
    return LINHA.s[LINHA.em_xz(x, z)]


def angulo(x, z):
    a = math.atan2(x, z)
    return a + 2 * math.pi if a < 0 else a


def crista(x, z):
    """Altura da borda da cratera em (x, z): plato ate' o raio da crista e,
    dali pra fora, a encosta que desce ate' o mar."""
    a = angulo(x, z)
    ca, sa = math.cos(a), math.sin(a)
    yc = Y_CRISTA + 10.0 * ruido2(ca * 2.2, sa * 2.2, 9.0) + 2.0 * ruido2(x * 0.08, z * 0.08, 4.0)
    for ac, hw in JANELAS:
        d = abs((a - ac + math.pi) % (2 * math.pi) - math.pi)
        if d < hw:
            yc = lerp(yc, y_espiral(ac) - 3.0, suave(1.0 - d / hw))
    rc = R_CRISTA + 9.0 * ruido2(ca * 1.6, sa * 1.6, 11.0)
    r = math.hypot(x, z)
    return yc - max(0.0, r - rc) * 1.15


def dist_rio(x, z):
    """A cascata desce por um raio reto: distancia ao segmento das pontas."""
    ax, az = RIO[0]
    bx, bz = RIO[-1]
    dx, dz = bx - ax, bz - az
    dd = dx * dx + dz * dz or 1.0
    t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / dd))
    return math.hypot(x - ax - dx * t, z - az - dz * t)


def ponte_de(i, lat):
    """A ponte em cujo tabuleiro (x, z) esta', ou None."""
    s = LINHA.s[i]
    for p in PONTES:
        if abs(s - p["s"]) <= p["comp"] and abs(lat) <= p["w"]:
            return p
    return None


def perto_de_ponte(i, folga):
    s = LINHA.s[i]
    for p in PONTES:
        if abs(s - p["s"]) <= p["comp"] + folga:
            return p
    return None


def y_ponte(p, s):
    """Tabuleiro: reta entre as cabeceiras com um arco por cima."""
    i0 = LINHA.em_s(p["s"] - p["comp"])
    i1 = LINHA.em_s(p["s"] + p["comp"])
    t = (s - (p["s"] - p["comp"])) / (2 * p["comp"])
    base = lerp(LINHA.p[i0][3], LINHA.p[i1][3], max(0.0, min(1.0, t)))
    meio = 1.0 - min(abs(s - p["s"]) / p["comp"], 1.0)
    return base + p["arco"] * math.sin(meio * math.pi / 2)


_MEMO_ALTURA = {}


def altura(x, z):
    chave = (round(x, 2), round(z, 2))
    h = _MEMO_ALTURA.get(chave)
    if h is None:
        h = _altura(x, z)
        _MEMO_ALTURA[chave] = h
    return h


def _altura(x, z):
    i, lat, _d = LINHA.perto(x, z)
    if i is None:
        return min(LAVA_MAR - 6.0 + 30.0 * max(0.0, ruido2(x * 0.01, z * 0.01, 5.0)), crista(x, z))
    q = LINHA.p[i]
    w, y0 = q[2], q[3]
    amp = 0.0 if perto_de_ponte(i, 12.0) else 1.0
    n = (0.35 * ruido2(x * 0.9, z * 0.9, 1.0) + 0.45 * ruido2(x * 0.25, z * 0.25, 2.0)) * amp
    al = abs(lat)
    lado_a = lat > 0
    dr = dist_rio(x, z) if RIO else 1e9
    canal = 1.0 - suave((dr - RIO_W) / 3.0) if dr < RIO_W + 3.0 else 0.0
    fora = al - w
    if al <= w:
        h = y0 + n
        regiao = "pista"
    else:
        regiao = "parede"
        abre = q[4] if lado_a else q[5]
        fundo = q[7] if lado_a else q[8]
        terr = q[6] if lado_a else 0.0
        rug = 3.5 * ruido2(x * 0.15, z * 0.15, 7.0) + 1.5 * ruido2(x * 0.5, z * 0.5, 3.0)
        parede = y0 + n + fora * 1.5 + max(0.0, fora - 6.0) * 1.6 + rug * min(fora / 8.0, 1.0)
        parede = min(parede, y0 + 46.0 + rug * 3.0, crista(x, z))
        if fora < 5.0:
            regiao = "pe"
        cai = suave(min(fora / 7.0, 1.0))
        # fundo de terraco (a volta de baixo) leva o mesmo ruido do chao dela;
        # fundo de lava some embaixo da lava
        pe_beira = fundo + n if fundo > -15.0 else fundo + rug * 0.3
        beira = lerp(y0 + n, pe_beira, cai) + rug * 0.5 * math.sin(math.pi * cai)
        if -16.0 > fundo > LAVA_POCO - 2.0 and fora > 80.0:
            beira += (fora - 80.0) * 0.45 + rug * 2.0
        h = lerp(parede, beira, abre)
        if abre > 0.5 and fora < 2.5:
            regiao = "beirada"
        if terr > 0.0:
            # laje plana na altura do caminho, ate' o pe' do penhasco de cima
            h = lerp(h, y0 + n - 0.15, terr)
            if terr > 0.5:
                regiao = "terraco"
    # a cascata cava um canal onde o chao e' plano (pista, terraco, pe' de
    # parede e beirada); nas paredes ela so' escorre por cima
    if canal > 0.0 and regiao != "parede":
        h = lerp(h, y0 - 2.4, canal)
    # debaixo da ponte do abismo nao ha' chao
    if al <= w:
        p = perto_de_ponte(i, 0.0)
        if p is not None and p["abismo"]:
            h = LAVA_POCO - 5.0
    return h


def lava_em(x, z):
    """O nivel da lava em (x, z): o poco dentro da cratera, o mar fora."""
    return LAVA_POCO if math.hypot(x, z) < 120.0 else LAVA_MAR


def altura_col(x, z):
    """A colisao: a mesma `altura`, mas o caminho segue plano 1,2 m alem da
    beira. Sem isso o quadrado da grade que pega a borda do penhasco ja'
    desce por DENTRO do caminho e o jogador escorrega pra beira (o muro
    invisivel fica a 0,5 m da borda e segura o resto)."""
    h = altura(x, z)
    i, lat, _d = LINHA.perto(x, z)
    if i is None or abs(lat) > LINHA.p[i][2] + 1.2 or perto_de_ponte(i, 0.0) is not None:
        return h
    return max(h, LINHA.p[i][3] - 0.4)


def no_caminho(x, z, folga=0.0):
    i, lat, _d = LINHA.perto(x, z)
    if i is None:
        return False
    if not (S_INICIO + 1.0 < LINHA.s[i] < S_FIM - 1.0):
        return False
    return abs(lat) <= LINHA.p[i][2] - folga


def na_ponte(x, z):
    i, lat, _d = LINHA.perto(x, z)
    if i is None:
        return None
    return ponte_de(i, lat)


def altura_nav(x, z):
    i, lat, _d = LINHA.perto(x, z)
    if i is not None:
        p = ponte_de(i, lat)
        if p is not None:
            return y_ponte(p, LINHA.s[i])
    return altura(x, z)


def caminhavel(x, z):
    i, lat, _d = LINHA.perto(x, z)
    if i is None:
        return False
    p = ponte_de(i, lat)
    if p is not None:
        return abs(lat) < p["w"] - 1.0
    if perto_de_ponte(i, 0.0) is not None and perto_de_ponte(i, 0.0)["abismo"]:
        return False
    if RIO and dist_rio(x, z) < RIO_W + 1.5:
        return False
    return no_caminho(x, z, 1.5)


class Inferno2(Cena):

    def __init__(self):
        super().__init__("inf2", 667)
        self.pontos = {
            "player": [0.0, 0.0, 0.0],
            "entrada": [0.0, 0.0, 0.0],
            "saida": [0.0, 0.0, 0.0],
            "areas": {},
            "braseiros": [],
            "geiseres": [],
            "lavas_som": [],
            "vapores": [],
            "caldeiroes": [],
            "lampioes": [],
            "pousos": [],
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
        xc, zc = (math.floor(x / PASSO) + 0.5) * PASSO, (math.floor(z / PASSO) + 0.5) * PASSO
        if altura(xc, zc) < lava_em(xc, zc) - 3.0:
            return lava_em(xc, zc) - 0.5
        return chao_visivel(altura, PASSO, x, z)

    def pe(self, x, z, r):
        return chao_sob(self.chao_v, x, z, r)

    def firmar(self, pecas, folga=0.5):
        return estender_ate_o_chao(pecas, self.chao_v, folga)

    @staticmethod
    def ate_a_parede(x, y, z, dx, dz, folga=1.0, limite=40.0):
        """Anda de (x, z) na direcao (dx, dz) ate' a parede da cratera passar
        `folga` m acima de `y`: e' ali que a ponta de corrente/rosto entra na
        rocha, em vez de ficar no ar na frente dela."""
        m = 0.0
        while m < limite and altura(x + dx * m, z + dz * m) < y + folga:
            m += 0.5
        return x + dx * m, z + dz * m

    def ponto(self, s, lado=0.0):
        """Ponto do caminho na distancia `s`, deslocado `lado` (fracao da
        largura, +1 = beira de FORA, -1 = beira de dentro)."""
        i = LINHA.em_s(s)
        q = LINHA.p[i]
        tx, tz = LINHA.t[i]
        lx, lz = -tz, tx
        x = q[0] + lx * q[2] * lado
        zz = q[1] + lz * q[2] * lado
        return x, altura(x, zz), zz, i

    def ponto_m(self, s, metros):
        """Como `ponto`, mas o deslocamento em METROS a partir do centro."""
        i = LINHA.em_s(s)
        q = LINHA.p[i]
        tx, tz = LINHA.t[i]
        x = q[0] - tz * metros
        zz = q[1] + tx * metros
        return x, altura(x, zz), zz, i

    def area(self, nome, s):
        self.pontos["areas"][nome] = [round(v, 2) for v in self.ponto(s)[:3]]

    # ------------------------------------------------------------------
    def montar(self):
        self.chao()
        self.lavas()
        self.cascata()
        self.pontes()
        self.chegada()
        self.fenda()
        self.mirante()
        self.forja()
        self.enforcados()
        self.garganta()
        self.agulha()
        self.braseiros()
        self.poco()
        self.longe()
        self.sombras()
        self.cercadura()
        self.pontos["navmesh"] = navmesh_grade(
            self, -230.0, 230.0, -230.0, 290.0, PASSO_NAV, altura_nav, caminhavel,
            max_desnivel=0.7, folga=1.3)
        self._marcadores()

    # ------------------------------------------------------------------
    def chao(self):
        """Chao visivel (so' o tampo) ate' o mar; colisao fechada so' no
        caminho e numa faixa em volta."""
        visiveis = {}
        colisao = set()
        lim = 340.0
        for i in range(int(-lim / PASSO), int(lim / PASSO)):
            for j in range(int(-lim / PASSO), int(lim / PASSO)):
                xc, zc = (i + 0.5) * PASSO, (j + 0.5) * PASSO
                r = math.hypot(xc, zc)
                if r > lim:
                    continue
                k, lat, d = LINHA.perto(xc, zc)
                h = altura(xc, zc)
                lava = lava_em(xc, zc)
                if h < lava - 3.0:
                    continue          # fica todo embaixo da lava
                no_cam = k is not None and abs(lat) <= LINHA.p[k][2] + 0.5 and S_INICIO - 6 < LINHA.s[k] < S_FIM + 6
                if no_cam:
                    mat = "cinza" if ruido2(xc * 0.3, zc * 0.3, 4.0) > -0.1 else "basalto"
                elif k is not None and abs(lat) <= LINHA.p[k][2] + 14.0 and h > LINHA.p[k][3] - 1.5 \
                        and h < LINHA.p[k][3] + 1.5:
                    mat = "basalto"
                elif h < -28.0:
                    mat = "rocha_quente"
                else:
                    mat = "rocha"
                setor = self.setor_grade("chao", xc, zc, SETOR)
                visiveis.setdefault((setor, mat), []).append((i, j))
                if k is not None and abs(lat) <= LINHA.p[k][2] + 8.0 and S_INICIO - 8 < LINHA.s[k] < S_FIM + 8:
                    # a colisao vai na grade de 2 m: as 4 sub-celulas desta
                    for a in (0, 1):
                        for b in (0, 1):
                            colisao.add((2 * i + a, 2 * j + b))
        for (setor, mat), cel in visiveis.items():
            v, f = chapa_aberta(cel, PASSO, altura)
            self.m.add(setor, mat, v, f)
        v, f = chapa_grossa(list(colisao), PASSO_COL, altura_col, 3.0)
        self.col.append((v, f))
        # pedra solta pela beira do caminho, pra quebrar a grade
        rnd = self.rnd
        for k in range(0, len(LINHA.p), 3):
            q = LINHA.p[k]
            if not (S_INICIO + 10 < LINHA.s[k] < S_FIM - 30):
                continue
            if perto_de_ponte(k, 8.0) is not None:
                continue
            tx, tz = LINHA.t[k]
            for lado in (-1, 1):
                if rnd.random() < 0.55:
                    continue
                off = q[2] + rnd.uniform(1.5, 6.0)
                x = q[0] - tz * off * lado
                z = q[1] + tx * off * lado
                y = altura(x, z)
                if y < q[3] - 4.0 or dist_rio(x, z) < RIO_W + 2.0:
                    continue
                s = rnd.uniform(1.2, 4.0)
                setor = self.setor_grade("pedras", x, z, SETOR)
                pedra = caixa_girada(x, y + s * 0.2, z, s, s * rnd.uniform(0.6, 1.4),
                                     s * rnd.uniform(0.7, 1.3), rnd.uniform(0, 3),
                                     rnd.uniform(-0.3, 0.3), rnd, 0.35)
                if self.pe(x, z, s * 0.7) < q[3] - 6.0:
                    continue          # na quina do penhasco ela afundaria inteira
                self.m.add_pecas(setor, "rocha", assentar([pedra], self.chao_v))

    def lavas(self):
        """O mar (anel fora da cratera) e o fundo do poco (disco). Abertos,
        normal pra cima. O mar e' um ANEL porque o poco fica 50 m abaixo dele."""
        n = 48
        v, f = [], []
        r_in, r_out = R_CRISTA - 4.0, 1500.0
        for k in range(n):
            a = 2 * math.pi * k / n
            v.append((r_in * math.sin(a), LAVA_MAR, r_in * math.cos(a)))
            v.append((r_out * math.sin(a), LAVA_MAR, r_out * math.cos(a)))
        for k in range(n):
            a0, b0 = 2 * k, 2 * k + 1
            a1, b1 = 2 * ((k + 1) % n), 2 * ((k + 1) % n) + 1
            f.append([a0, b0, b1, a1])
        self._pra_cima(v, f)
        self.m.add("lava_mar", "lava", v, f)
        v = [(0.0, LAVA_POCO, 0.0)]
        for k in range(n):
            a = 2 * math.pi * k / n
            v.append((125.0 * math.sin(a), LAVA_POCO, 125.0 * math.cos(a)))
        f = [[0, 1 + k, 1 + (k + 1) % n] for k in range(n)]
        self._pra_cima(v, f)
        self.m.add("lava_poco", "lava_funda", v, f)

    @staticmethod
    def _pra_cima(v, f):
        a, b, c = v[f[0][0]], v[f[0][1]], v[f[0][2]]
        ny = (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2])
        if ny < 0:
            for k in range(len(f)):
                f[k] = list(reversed(f[k]))

    def cascata(self):
        """O rio de lava que desce o funil: nasce numa racha alta da parede da
        cratera, corre pelo chao (no canal cavado pela `altura`), despenca de
        terraco em terraco e cai no poco. Uma fita so', deitada no relevo,
        com o V ao longo da correnteza (o shader faz escorrer)."""
        pts = []
        for x, z in RIO:
            pts.append((x, z))
        verts, faces, uvs = [], [], []
        acc = 0.0
        prev_y = None
        vs = []
        for k, (x, z) in enumerate(pts):
            a = pts[max(k - 1, 0)]
            b = pts[min(k + 1, len(pts) - 1)]
            dx, dz = b[0] - a[0], b[1] - a[1]
            d = math.hypot(dx, dz) or 1.0
            nx, nz = -dz / d, dx / d
            y = altura(x, z)
            inclina = 0.0 if prev_y is None else abs(prev_y - y) / 2.0
            prev_y = y
            y += 0.35 + 0.25 * min(inclina, 3.0)
            if k:
                acc += math.hypot(x - pts[k - 1][0], z - pts[k - 1][1]) + abs(inclina) * 2.0
            larg = RIO_W - 0.8
            verts.append((x + nx * larg, y, z + nz * larg))
            verts.append((x - nx * larg, y, z - nz * larg))
            vs.append(acc / 14.0)
            if k:
                b0 = (k - 1) * 2
                faces.append([b0, b0 + 2, b0 + 3, b0 + 1])
                uvs.append([(0.0, vs[-2]), (0.0, vs[-1]), (1.0, vs[-1]), (1.0, vs[-2])])
            if y < LAVA_POCO + 0.5:
                break
        a_, b_, c_ = verts[faces[0][0]], verts[faces[0][1]], verts[faces[0][2]]
        ny = (b_[2] - a_[2]) * (c_[0] - a_[0]) - (b_[0] - a_[0]) * (c_[2] - a_[2])
        if ny < 0:
            faces = [list(reversed(f)) for f in faces]
            uvs = [list(reversed(u)) for u in uvs]
        self.m.add("lava_cascata", "lava_desce", verts, faces, uvs=uvs)
        # a racha de onde ela nasce
        x, z = RIO[0]
        y = altura(x, z)
        self.m.add_pecas("cascata_fonte", "brasa", [caixa_girada(x, y + 4.0, z, RIO_W * 1.6, 9.0, 1.2,
                                                                  math.atan2(x, z))])
        # sons e vapor ao longo dela
        for k in range(0, len(pts), 9):
            x, z = pts[k]
            y = altura(x, z)
            if y < LAVA_POCO + 1:
                break
            self.pontos["lavas_som"].append([round(x, 2), round(y + 1.0, 2), round(z, 2)])
            self.pontos["vapores"].append([round(x, 2), round(y + 0.5, 2), round(z, 2)])

    # ------------------------------------------------------------------
    def pontes(self):
        """Tabuleiros de todas as pontes. Colisao em rampa suave que ENTRA
        2 m por baixo do chao nas cabeceiras."""
        for p in PONTES:
            s0, s1 = p["s"] - p["comp"] - 2.0, p["s"] + p["comp"] + 2.0
            n = max(8, int((s1 - s0) / 2.5))
            pecas, col = [], []
            setor = p["setor"]
            w = p["w"] + 0.6
            # a ponte do abismo e' RETA de cabeceira a cabeceira: seguindo a
            # linha, o primeiro lance saia torto (a linha ainda vem da curva) e
            # abria fresta pro poco
            pa, pb = LINHA.p[LINHA.em_s(s0)], LINHA.p[LINHA.em_s(s1)]
            dx_, dz_ = pb[0] - pa[0], pb[1] - pa[1]
            dd_ = math.hypot(dx_, dz_) or 1.0
            t_reta = (dx_ / dd_, dz_ / dd_)
            for k in range(n):
                sa_ = lerp(s0, s1, k / n)
                sb_ = lerp(s0, s1, (k + 1) / n)
                ia, ib = LINHA.em_s(sa_), LINHA.em_s(sb_)
                qa, qb = LINHA.p[ia], LINHA.p[ib]
                ta, tb = LINHA.t[ia], LINHA.t[ib]
                if p.get("reta"):
                    qa = (lerp(pa[0], pb[0], k / n), lerp(pa[1], pb[1], k / n))
                    qb = (lerp(pa[0], pb[0], (k + 1) / n), lerp(pa[1], pb[1], (k + 1) / n))
                    ta = tb = t_reta
                ya = y_ponte(p, sa_) if abs(sa_ - p["s"]) <= p["comp"] else altura(qa[0], qa[1])
                yb = y_ponte(p, sb_) if abs(sb_ - p["s"]) <= p["comp"] else altura(qb[0], qb[1])
                # lateral = (-tz, tx)

                def L(q, t_, off, y):
                    return (q[0] - t_[1] * off, y, q[1] + t_[0] * off)

                topo = hexaedro([L(qa, ta, -w, ya - 1.6), L(qa, ta, w, ya - 1.6), L(qb, tb, w, yb - 1.6),
                                 L(qb, tb, -w, yb - 1.6), L(qa, ta, -w, ya), L(qa, ta, w, ya), L(qb, tb, w, yb),
                                 L(qb, tb, -w, yb)])
                pecas.append(topo)
                col.append(topo)
                for sg in (-1, 1):
                    o0, o1 = sg * w, sg * (w + 0.7)
                    pecas.append(hexaedro([L(qa, ta, o0, ya - 1.6), L(qa, ta, o1, ya - 1.6), L(qb, tb, o1, yb - 1.6),
                                           L(qb, tb, o0, yb - 1.6), L(qa, ta, o0, ya + 1.1), L(qa, ta, o1, ya + 1.1),
                                           L(qb, tb, o1, yb + 1.1), L(qb, tb, o0, yb + 1.1)]))
                    if k % 3 == 0:
                        m = L(qa, ta, sg * (w + 0.35), ya)
                        pecas.append(caixa((m[0] - 0.5, ya, m[2] - 0.5), (m[0] + 0.5, ya + 1.9, m[2] + 0.5)))
                        pecas.append(espinho((m[0], ya + 1.9, m[2]), (m[0], ya + 3.2, m[2]), 0.4, n=4))
            self.m.add_pecas(setor, p.get("mat", "pedra"), pecas)
            self.col.extend(col)
            if not p["abismo"]:
                # guardioes nas cabeceiras, de frente pro caminho
                for ds in (-p["comp"] - 3.5, p["comp"] + 3.5):
                    i = LINHA.em_s(p["s"] + ds)
                    q = LINHA.p[i]
                    tx, tz = LINHA.t[i]
                    for sg in (-1, 1):
                        gx, gz = q[0] - tz * sg * (p["w"] + 3.2), q[1] + tx * sg * (p["w"] + 3.2)
                        self.guardiao(gx, altura(gx, gz), gz, 8.0, math.atan2(tz * sg, -tx * sg), setor)
        a = PONTES[0]
        x, _y, z, i = self.ponto(a["s"])
        self.pontos["areas"]["area_4_cascata"] = [round(x, 2), round(y_ponte(a, a["s"]), 2), round(z, 2)]

    def guardiao(self, x, y, z, alt, giro, setor):
        """Estatua de demonio de pe' (a mesma do primeiro inferno)."""
        ca, sa = math.cos(giro), math.sin(giro)

        def P(lx, ly, lz):
            return (x + lx * ca + lz * sa, y + ly, z - lx * sa + lz * ca)

        h = alt
        # o pedestal desce ate' o chao que se ve': na cabeceira de dentro ele
        # vira pilar ate' o circulo de baixo (ou ate' o poco)
        pecas = self.firmar([caixa_girada(x, y + 0.6, z, 3.0, 1.2, 3.0, giro)])
        pecas += [cilindro(x, z, h * 0.12, y + 1.2, y + 1.2 + h * 0.5, n=8, raio_topo=h * 0.09),
                  cilindro(x, z, h * 0.09, y + 1.2 + h * 0.5, y + 1.2 + h * 0.72, n=8, raio_topo=h * 0.13)]
        cab = P(0, 1.2 + h * 0.8, h * 0.02)
        # a cabeca nasce no alto do tronco (antes ficava 16 cm acima dele)
        pecas.append(cilindro(cab[0], cab[2], h * 0.07, y + 1.2 + h * 0.7, cab[1] + h * 0.06, n=8))
        for s in (-1, 1):
            pecas.append(espinho(P(s * h * 0.05, 1.2 + h * 0.84, 0), P(s * h * 0.16, 1.2 + h * 1.0, -h * 0.08),
                                 h * 0.025, n=5))
            pecas.append(espinho(P(s * h * 0.12, 1.2 + h * 0.72, -h * 0.06), P(s * h * 0.22, 1.2 + h * 0.15, -h * 0.12),
                                 h * 0.08, n=4))
        self.m.add_pecas(setor, "obsidiana", pecas)
        self.col.append(caixa_girada(x, y + 2.0, z, 3.0, 4.0, 3.0, giro))
        self.ocupar(x, z, 2.2)

    def anel_portal(self, x, y, z, giro, setor):
        """O anel de osso e obsidiana (o mesmo do fim do primeiro inferno),
        em cima de uma plataforma rasa com rampa pelo lado do caminho.
        `giro`: o anel fica no plano perpendicular a (sen g, cos g), que e'
        de onde se chega."""
        r = 13.0
        ca, sa = math.cos(giro), math.sin(giro)

        def P(lx, ly, lz):
            return (x + lx * ca + lz * sa, y + ly, z - lx * sa + lz * ca)

        # a plataforma e' mais larga que a ponta do esporao: desce ate' o chao
        self.m.add_pecas(setor, "obsidiana", self.firmar([cilindro(x, z, 18.0, y - 2.0, y + 0.6, n=24, raio_topo=17.0)])
                         + [cilindro(x, z, 14.0, y + 0.6, y + 1.2, n=24, raio_topo=13.5)])
        self.col.append(cilindro(x, z, 18.5, y - 2.0, y + 1.2, n=20, raio_topo=14.0))
        rampa = [P(-8, -1.0, 26.0), P(8, -1.0, 26.0), P(8, -1.0, 8.0), P(-8, -1.0, 8.0),
                 P(-8, 0.0, 26.0), P(8, 0.0, 26.0), P(8, 1.2, 8.0), P(-8, 1.2, 8.0)]
        self.col.append(hexaedro(rampa))
        degraus = []
        for k in range(6):
            lz = 23.0 - k * 2.0
            degraus.append(caixa_girada(*P(0, -0.5 + 0.1 * (k + 1), lz), 16.0, 1.0 + 0.2 * (k + 1), 2.0, giro))
        self.m.add_pecas(setor, "obsidiana", self.firmar(degraus))
        yc = 1.2 + r + 1.0
        anel = [P(r * math.sin(2 * math.pi * k / 48), yc + r * math.cos(2 * math.pi * k / 48), 0) for k in range(49)]
        self.m.add_pecas(setor, "obsidiana", [tubo_redondo(anel, [1.5] * 49, n=10)], suave=True)
        anel2 = [P((r - 1.6) * math.sin(2 * math.pi * k / 48), yc + (r - 1.6) * math.cos(2 * math.pi * k / 48), 0.4)
                 for k in range(49)]
        self.m.add_pecas(setor, "brasa", [tubo_redondo(anel2, [0.35] * 49, n=6)])
        esp = []
        for k in range(30):
            a = 2 * math.pi * k / 30
            comp = 8.0 if k % 2 == 0 else 4.0
            esp.append(espinho(P((r + 1.0) * math.sin(a), yc + (r + 1.0) * math.cos(a), 0),
                               P((r + comp) * math.sin(a), yc + (r + comp) * math.cos(a), -1.0), 0.6, n=5))
        self.m.add_pecas(setor, "osso", esp)
        for s in (-1, 1):
            # o pilar passa da beira do patamar de cima: nasce no de baixo
            c0 = P(s * (r + 1.0), 0.6 + (yc - 0.6) / 2, 0)
            self.m.add_pecas(setor, "obsidiana", [caixa_girada(c0[0], c0[1], c0[2], 3.0, yc - 0.6, 3.0, giro)])
            c0 = P(s * (r + 1.0), 1.2 + (yc - 1.2) / 2, 0)
            self.col.append(caixa_girada(c0[0], c0[1], c0[2], 3.0, yc - 1.2, 3.0, giro))
        return y + yc

    # ------------------------------------------------------------------
    def chegada(self):
        """O esporao: o anel de chegada na ponta, virado pra cratera."""
        s_portal = 14.0
        x, y, z, i = self.ponto(s_portal)
        y = LINHA.p[i][3]
        # o anel olha pro caminho, que vem do -Z
        yc = self.anel_portal(x, y, z, math.pi, "chegada")
        self.pontos["portal_chegada"] = [round(x, 2), round(yc, 2), round(z, 2)]
        self.pontos["entrada"] = [round(x, 2), round(y + 1.2, 2), round(z, 2)]
        px, py, pz, _ = self.ponto(40.0)
        self.pontos["player"] = [round(px, 2), round(LINHA.p[LINHA.em_s(40.0)][3] + 0.3, 2), round(pz, 2)]
        # pilares quebrados e espinhos pela beira do esporao
        rnd = self.rnd
        for s in range(30, 96, 9):
            for sg in (-1, 1):
                if rnd.random() < 0.35:
                    continue
                x, y, z, i = self.ponto(float(s) + rnd.uniform(-2, 2), sg * 1.12)
                setor = self.setor_grade("esporao", x, z, SETOR)
                # na beira o esporao despenca: plinto e espinho descem ate' o chao
                if rnd.random() < 0.5:
                    pilar = pilar_composto(x, z, y - 2.0, y + rnd.uniform(2.5, 8.0), r_nucleo=0.6, r_colunete=0.2)[0]
                    self.m.add_pecas(setor, "pedra", self.firmar(pilar[:1]) + pilar[1:])
                else:
                    self.m.add_pecas(setor, "obsidiana", self.firmar([espinho((x, y - 1.0, z), (x + rnd.uniform(-2, 2), y + rnd.uniform(5, 12),
                                                                                                 z + rnd.uniform(-2, 2)), 1.0, n=5)]))
        self.area("area_1_chegada", 46.0)

    def fenda(self):
        """A garganta que corta a borda da cratera: rostos gritando
        esculpidos nas paredes, correntes atravessadas com gaiolas e, na boca
        de dentro, presas de osso — entra-se no funil por uma mandibula."""
        rnd = self.rnd
        # rostos nas paredes
        for s, sg in ((112.0, 1), (124.0, -1), (138.0, 1), (150.0, -1)):
            # depois da curva o lado de dentro ja' e' o vao pro circulo de
            # baixo: o rosto vai pra parede que existe
            q = LINHA.p[LINHA.em_s(s)]
            if self.ponto_m(s, sg * (q[2] + 8.0))[1] < q[3] + 8.0:
                sg = -sg
            x, y, z, i = self.ponto_m(s, sg * (LINHA.p[LINHA.em_s(s)][2] + 5.0))
            y = LINHA.p[i][3]
            tx, tz = LINHA.t[i]
            # a cara olha pro meio da fenda
            nx, nz = tz * sg, -tx * sg
            cy = y + rnd.uniform(9.0, 14.0)
            # recua pra dentro da parede ate' ela passar do alto do rosto:
            # na beira da fenda a parede ainda e' baixa e o rosto ficava solto
            x, z = self.ate_a_parede(x, cy + 3.0, z, -nx, -nz, limite=8.0)
            setor = "fenda"
            # e o tronco do rosto desce ate' o chao (o pe' da parede)
            self.m.add_pecas(setor, "pedra", self.firmar([cilindro(x, z, 4.2, cy - 4.5, cy + 4.0, n=10, raio_topo=3.2)], 1.0))
            for e in (-1, 1):
                ox, oz = x + nx * 3.4 + tx * e * 1.6, z + nz * 3.4 + tz * e * 1.6
                self.m.add_pecas(setor, "escuro", [cilindro(ox, oz, 0.9, cy + 0.6, cy + 1.8, n=8)])
            mx, mz = x + nx * 3.6, z + nz * 3.6
            self.m.add_pecas(setor, "brasa", [cilindro(mx, mz, 1.3, cy - 3.2, cy - 0.8, n=8, raio_topo=0.8)])
        # correntes atravessadas com gaiolas
        for s in (104.0, 132.0, 158.0):
            i = LINHA.em_s(s)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            lx, lz = -tz, tx
            w = q[2] + 3.0
            setor = "fenda"
            a = (q[0] + lx * w, q[1] + lz * w)
            b = (q[0] - lx * w, q[1] - lz * w)
            topo = q[3] + 19.0
            # as pontas entram na rocha (a 3 m da beira a parede nem chega aos
            # 19 m); do lado do vao (depois da curva) ela sai de um poste
            pontas = []
            for (px, pz), dx, dz in ((a, lx, lz), (b, -lx, -lz)):
                rx, rz = self.ate_a_parede(px, topo, pz, dx, dz, limite=16.0)
                if altura(rx, rz) >= topo + 1.0:
                    pontas.append((rx, rz))
                    continue
                pontas.append((px, pz))
                self.m.add_pecas(setor, "obsidiana", [espinho((px, self.pe(px, pz, 1.2) - 1.0, pz), (px, topo + 2.5, pz),
                                                              1.2, n=6)])
                self.col.append(cilindro(px, pz, 1.3, altura(px, pz) - 1.0, altura(px, pz) + 4.0, n=6))
            a, b = pontas
            pts = []
            for k in range(11):
                t = k / 10.0
                pts.append((lerp(a[0], b[0], t), topo - 3.0 * math.sin(t * math.pi), lerp(a[1], b[1], t)))
            self.m.add_pecas(setor, "metal", [tubo_redondo(pts, [0.28] * len(pts), n=5)])
            for c in range(2):
                t = 0.35 + 0.3 * c
                gx, gz = lerp(a[0], b[0], t), lerp(a[1], b[1], t)
                gy = topo - 3.0 * math.sin(t * math.pi) - rnd.uniform(4.0, 7.0)
                self.gaiola(gx, gy, gz, topo - 3.0 * math.sin(t * math.pi), setor, corpo=c == 0)
        # a mandibula na boca de dentro
        s = 172.0
        i = LINHA.em_s(s)
        q = LINHA.p[i]
        tx, tz = LINHA.t[i]
        lx, lz = -tz, tx
        setor = "mandibula"
        pecas = []
        for sg in (-1, 1):
            for k in range(5):
                d = q[2] + 1.0
                off = (k - 2) * 2.6
                bx, bz = q[0] + lx * d * sg + tx * off, q[1] + lz * d * sg + tz * off
                by = altura(bx, bz)
                topo = (bx - lx * sg * 4.0, by + 14.0 + rnd.uniform(-2, 3), bz - lz * sg * 4.0)
                pecas.append(espinho((bx, by - 1.0, bz), topo, 1.3, n=6))
                self.col.append(cilindro(bx, bz, 1.4, by - 1.0, by + 4.0, n=6))
        # presas de cima, penduradas num arco
        arco = []
        for k in range(13):
            t = k / 12.0
            d = (q[2] + 2.0) * (2 * t - 1)
            arco.append((q[0] + lx * d, q[3] + 20.0 + 5.0 * math.sin(t * math.pi), q[1] + lz * d))
        # o arco tem pernas: das pontas desce ate' o chao (antes pairava 20 m
        # acima da pista, preso a nada)
        pernas = []
        for p0 in (arco[0], arco[-1]):
            pernas.append([(p0[0], self.pe(p0[0], p0[2], 1.6) - 1.5, p0[2]), (p0[0], lerp(p0[1], q[3], 0.5), p0[2])])
        pecas.append(tubo_redondo(pernas[0] + arco + pernas[1][::-1], [1.9, 1.7] + [1.6] * len(arco) + [1.7, 1.9], n=8))
        for k in range(1, 12):
            p0 = arco[k]
            pecas.append(espinho(p0, (p0[0] + tx * 0.5, p0[1] - rnd.uniform(5.0, 9.0), p0[2] + tz * 0.5), 0.9, n=5))
        self.m.add_pecas(setor, "osso", pecas, suave=False)
        self.area("area_2_fenda", 130.0)

    def gaiola(self, gx, gy, gz, topo, setor, corpo=True):
        pecas = corrente_vertical(gx, gz, topo, gy + 2.2)
        for bb in range(8):
            an = 2 * math.pi * bb / 8
            pecas.append(caixa((gx + math.cos(an) * 0.7 - 0.04, gy, gz + math.sin(an) * 0.7 - 0.04),
                               (gx + math.cos(an) * 0.7 + 0.04, gy + 2.2, gz + math.sin(an) * 0.7 + 0.04)))
        pecas.append(cilindro(gx, gz, 0.8, gy - 0.1, gy + 0.05, n=8))
        pecas.append(cilindro(gx, gz, 0.8, gy + 2.15, gy + 2.3, n=8, raio_topo=0.4))
        self.m.add_pecas(setor, "metal", pecas)
        if corpo:
            self.m.add_pecas(setor, "carne_seca", [cilindro(gx, gz, 0.35, gy + 0.05, gy + 1.1, n=6, raio_topo=0.2)])

    def mirante(self):
        """Primeiro circulo: largo, com a balaustrada quebrada na beira do
        terraco, penitentes ajoelhados olhando o poco e os ACORRENTADOS —
        gigantes presos a' parede da cratera por correntes."""
        rnd = self.rnd
        s0, s1 = s_de_th(0.3), s_de_th(1.6)
        # balaustrada na beira de dentro do terraco (fora do caminho)
        s = s0
        while s < s1:
            x, y, z, i = self.ponto_m(s, -(LINHA.p[LINHA.em_s(s)][2] + 0.9))
            y = LINHA.p[i][3]
            if rnd.random() < 0.8:
                setor = self.setor_grade("balaustre", x, z, SETOR)
                hh = rnd.uniform(0.6, 1.6) if rnd.random() < 0.3 else 1.6
                # fica na quina do penhasco: o pe' do balaustre desce ate' o chao
                self.m.add_pecas(setor, "pedra", self.firmar([cilindro(x, z, 0.35, y - 0.5, y + hh, n=6, raio_topo=0.28)])
                                 + [caixa_girada(x, y + hh + 0.15, z, 1.0, 0.3, 1.0, rnd.uniform(0, 1))])
            s += 3.2
        # penitentes ajoelhados na laje do circulo de baixo, olhando o poco
        # (quem passa no mirante os ve' la' embaixo)
        for k in range(9):
            s = rnd.uniform(s_de_th(0.3 + 2.0 * math.pi), s_de_th(1.6 + 2.0 * math.pi))
            x, y, z, i = self.ponto_m(s, LINHA.p[LINHA.em_s(s)][2] + rnd.uniform(2.5, 8.0))
            setor = self.setor_grade("penitentes", x, z, SETOR)
            ang = angulo(x, z) + math.pi
            fx, fz = math.sin(ang), math.cos(ang)
            self.m.add_pecas(setor, "pedra", [
                cilindro(x, z, 0.9, y - 0.3, y + 0.8, n=8, raio_topo=0.7),
                cilindro(x + fx * 0.3, z + fz * 0.3, 0.55, y + 0.8, y + 2.0, n=8, raio_topo=0.35),
                cilindro(x + fx * 0.7, z + fz * 0.7, 0.35, y + 1.8, y + 2.5, n=8)])
        # os acorrentados na parede de fora
        for th in (0.55, 1.05, 1.45):
            s = s_de_th(th)
            i = LINHA.em_s(s)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            lx, lz = -tz, tx
            d = q[2] + 5.0
            x, z = q[0] + lx * d, q[1] + lz * d
            y = altura(x, z) - 1.5
            alt = rnd.uniform(32.0, 40.0)
            v, f = _figura(alt, rnd, rnd.choice((0, 2)))
            giro = math.atan2(-lx, -lz)
            ca, sa = math.cos(giro), math.sin(giro)
            vv = [(x + vx * ca + vz * sa, y + vy, z - vx * sa + vz * ca) for vx, vy, vz in v]
            self.m.add_pecas("acorrentados", "obsidiana", [(vv, f)])
            # correntes dos pulsos e do pescoco pra parede. A ponta de dentro
            # sai do proprio corpo (o vertice do braco/cabeca naquela altura)
            # e a de fora entra na rocha
            for sg, hy in ((-1, 0.62), (1, 0.62), (0, 0.86)):
                faixa = [p for p in vv if abs(p[1] - (y + alt * hy)) < alt * 0.04]
                if sg:
                    a = max(faixa, key=lambda p: ((p[0] - x) * tx + (p[2] - z) * tz) * sg)
                else:
                    a = tuple(sum(p[c] for p in faixa) / len(faixa) for c in range(3))
                b = (x + lx * 6.0 + tx * sg * alt * 0.35, y + alt * (hy + 0.12), z + lz * 6.0 + tz * sg * alt * 0.35)
                bx, bz = self.ate_a_parede(b[0], b[1], b[2], lx, lz, folga=1.5, limite=14.0)
                b = (bx, min(b[1], altura(bx, bz) - 1.5), bz)
                pts = [(lerp(a[0], b[0], t), lerp(a[1], b[1], t) - 2.0 * math.sin(t * math.pi), lerp(a[2], b[2], t))
                       for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
                self.m.add_pecas("acorrentados", "metal", [tubo_redondo(pts, [0.45] * 5, n=5)])
        self.area("area_3_mirante", s_de_th(0.9))

    def forja(self):
        """A forja dos condenados: bigornas do tamanho de casa, caldeiroes
        de lava, martelos largados, monte de escoria e geiseres no caminho."""
        rnd = self.rnd
        s0, s1 = s_de_th(2.65), s_de_th(4.05)
        # bigornas e caldeiroes, no caminho e na beira
        for k in range(14):
            s = rnd.uniform(s0, s1)
            lado = rnd.choice((-1, 1)) * rnd.uniform(0.45, 0.85)
            x, y, z, i = self.ponto(s, lado)
            if not self.livre(x, z, 4.5):
                continue
            setor = self.setor_grade("forja", x, z, SETOR)
            tx, tz = LINHA.t[i]
            giro = math.atan2(tx, tz) + rnd.uniform(-0.4, 0.4)
            if k % 2 == 0:
                # bigorna: pe', cintura e mesa com chifre
                self.m.add_pecas(setor, "metal", [
                    caixa_girada(x, y + 0.8, z, 4.4, 1.6, 3.2, giro),
                    caixa_girada(x, y + 2.4, z, 2.2, 1.8, 1.8, giro),
                    caixa_girada(x, y + 4.0, z, 6.0, 1.4, 2.6, giro)])
                ca, sa = math.cos(giro), math.sin(giro)
                self.m.add_pecas(setor, "metal", [espinho((x + ca * 3.0, y + 4.1, z - sa * 3.0),
                                                          (x + ca * 6.5, y + 4.4, z - sa * 6.5), 0.9, n=6)])
                self.col.append(caixa_girada(x, y + 2.4, z, 4.8, 4.8, 3.4, giro))
                self.ocupar(x, z, 3.4)
            else:
                # caldeirao com lava fervendo
                r = rnd.uniform(2.4, 3.4)
                self.m.add_pecas(setor, "metal", [cilindro(x, z, r * 0.8, y - 0.3, y + 1.2, n=12, raio_topo=r),
                                                  cilindro(x, z, r, y + 1.2, y + 3.0, n=12, raio_topo=r * 1.05),
                                                  cilindro(x, z, r * 1.12, y + 2.9, y + 3.3, n=12)])
                self.m.add_pecas(setor, "lava_brilho", [cilindro(x, z, r * 0.95, y + 2.6, y + 2.8, n=12)])
                self.col.append(cilindro(x, z, r * 1.1, y - 0.3, y + 3.3, n=10))
                self.ocupar(x, z, r + 0.8)
                self.pontos["vapores"].append([round(x, 2), round(y + 3.0, 2), round(z, 2)])
                self.pontos["caldeiroes"].append([round(x, 2), round(y + 4.2, 2), round(z, 2)])
        # martelos largados e escoria na beira de fora
        for k in range(8):
            s = rnd.uniform(s0, s1)
            x, y, z, i = self.ponto_m(s, LINHA.p[LINHA.em_s(s)][2] + rnd.uniform(1.5, 4.0))
            setor = self.setor_grade("forja", x, z, SETOR)
            if k % 2:
                a = rnd.uniform(0, math.pi)
                c = (math.cos(a), math.sin(a))
                # largado = deitado: o cabo e a cabeca encostam no chao (a
                # cabeca ficava 3 m no ar, sem nada embaixo)
                hx, hz = x + c[0] * 6.5, z + c[1] * 6.5
                yh = self.pe(hx, hz, 1.8) + 0.9
                y0 = self.pe(x - c[0] * 6, z - c[1] * 6, 0.4) + 0.3
                self.m.add_pecas(setor, "osso", [tubo_redondo([(x - c[0] * 6, y0, z - c[1] * 6),
                                                               (x + c[0] * 6, yh, z + c[1] * 6)], [0.4, 0.4], n=6)])
                self.m.add_pecas(setor, "metal", [caixa_girada(hx, yh, hz, 3.6, 2.2, 2.2, a + math.pi / 2, 0.5)])
            else:
                # o monte de escoria: as pedras se empilham num cone dela (sem
                # ele as de cima ficavam no ar) e a brasa fica no cume
                topo = y + 3.3
                fundo = self.pe(x, z, 4.3) - 0.5

                def monte(px, pz, x=x, z=z, topo=topo, fundo=fundo):
                    t = min(1.0, max(0.0, (math.hypot(px - x, pz - z) - 0.5) / 3.8))
                    return max(self.chao_v(px, pz), lerp(topo, fundo, t))
                self.m.add_pecas(setor, "basalto", [cilindro(x, z, 4.3, fundo, topo, n=9, raio_topo=0.5)]
                                 + assentar(entulho(x, z, 4.0, 14, rnd, y=y, tamanho=(0.6, 1.8), altura_pilha=3.0), monte))
                self.m.add_pecas(setor, "brasa", [cilindro(x, z, 0.75, topo - 0.2, topo + 0.12, n=6)])
        # forcas com correntes e ganchos na beira de dentro
        for th in (2.8, 3.25, 3.7):
            s = s_de_th(th)
            x, y, z, i = self.ponto_m(s, -(LINHA.p[LINHA.em_s(s)][2] + 0.8))
            y = LINHA.p[i][3] - 0.5
            setor = self.setor_grade("forja", x, z, SETOR)
            tx, tz = LINHA.t[i]
            topo = y + 16.0
            braco = (x - tz * 7.0, topo, z + tx * 7.0)
            # o poste fica na quina do penhasco: desce ate' o chao
            self.m.add_pecas(setor, "obsidiana", self.firmar([cilindro(x, z, 0.8, y - 1.0, topo + 1.0, n=6)])
                             + [tubo([(x, topo, z), braco], 0.6, 0.6)])
            self.m.add_pecas(setor, "metal", corrente_vertical(braco[0], braco[2], topo, topo - 9.0))
            self.gancho(braco[0], topo - 9.0, braco[2], setor)
            self.col.append(cilindro(x, z, 1.0, y - 1.0, y + 4.0, n=6))
        for th in (2.75, 3.15, 3.55, 3.95):
            for _t in range(12):
                x, y, z, i = self.ponto(s_de_th(th) + rnd.uniform(-8, 8), rnd.uniform(-0.55, 0.55))
                if self.livre(x, z, 3.5):
                    break
            self.geiser(x, y, z)
        self.area("area_5_forja", s_de_th(3.35))

    def gancho(self, x, y, z, setor):
        self.m.add_pecas(setor, "metal", [tubo_redondo([(x, y, z), (x, y - 1.6, z), (x + 0.9, y - 2.6, z),
                                                        (x + 1.7, y - 1.9, z), (x + 1.6, y - 1.2, z)],
                                                       [0.14, 0.14, 0.13, 0.11, 0.05], n=5)])

    def geiser(self, x, y, z):
        setor = self.setor_grade("geiser", x, z, SETOR)
        self.m.add_pecas(setor, "basalto", [cilindro(x, z, 2.2, y - 0.6, y + 0.5, n=9, raio_topo=1.3)])
        self.m.add_pecas(setor, "brasa", [cilindro(x, z, 1.15, y + 0.3, y + 0.55, n=9, raio_topo=0.9)])
        self.col.append(cilindro(x, z, 2.0, y - 0.6, y + 0.5, n=8))
        self.ocupar(x, z, 2.4)
        self.pontos["geiseres"].append([round(x, 2), round(y + 0.55, 2), round(z, 2)])

    def enforcados(self):
        """Traves de osso atravessando o caminho, com ganchos, gaiolas e
        corpos; a trave passa do caminho e sai por cima do vazio, e as gaiolas
        pendem sobre o circulo de baixo ou sobre o poco."""
        rnd = self.rnd
        s0, s1 = s_de_th(4.45), s_de_th(6.15)
        s = s0
        k = 0
        while s < s1:
            i = LINHA.em_s(s)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            lx, lz = -tz, tx
            setor = self.setor_grade("enforcados", q[0], q[1], SETOR)
            # a trave sai em balanco por cima do penhasco de dentro: as gaiolas
            # pendem sobre o circulo de baixo (ou sobre o poco)
            aberto = True
            w = q[2] + 2.5
            a = (q[0] + lx * w, q[1] + lz * w)
            b = (q[0] - lx * (w + (16.0 if aberto else 0.0)), q[1] - lz * (w + (16.0 if aberto else 0.0)))
            ya = altura(*a)
            yb = q[3] if aberto else altura(*b)
            topo = q[3] + 13.0
            pecas = [espinho((a[0], min(ya, self.pe(a[0], a[1], 1.2)) - 1.0, a[1]), (a[0], topo + 2.5, a[1]), 1.2, n=6)]
            if not aberto:
                pecas.append(espinho((b[0], yb - 1.0, b[1]), (b[0], topo + 2.5, b[1]), 1.2, n=6))
            else:
                # a trave sai em balanco do pilar de fora, com um tirante
                pecas.append(tubo_redondo([(a[0], topo + 2.0, a[1]), (q[0], topo + 4.5, q[1])], [0.4, 0.3], n=5))
            pecas.append(tubo_redondo([(a[0], topo, a[1]), (q[0], topo + 1.2, q[1]), (b[0], topo, b[1])],
                                      [0.7, 0.6, 0.5], n=6))
            # a trave e' reta de a ate' o meio da pista e de la' ate' b: e' essa
            # altura (e nao um seno) que as correntes penduradas tem de pegar
            t_meio = w / (2.0 * w + (16.0 if aberto else 0.0))

            def y_trave(t, topo=topo, t_meio=t_meio):
                u = t / t_meio if t < t_meio else (1.0 - t) / (1.0 - t_meio)
                return topo + 1.2 * u - 0.15
            self.m.add_pecas(setor, "osso", pecas, suave=False)
            if k % 2 == 0:
                # lampiao de brasa pendurado no meio da trave, por cima da pista
                ly = topo + 1.2 - 2.6
                self.m.add_pecas(setor, "metal", corrente_vertical(q[0], q[1], topo + 1.2, ly + 0.7, larg=0.12)
                                 + [cilindro(q[0], q[1], 0.42, ly + 0.6, ly + 0.75, n=6)])
                self.m.add_pecas(setor, "brasa", [cilindro(q[0], q[1], 0.32, ly - 0.2, ly + 0.6, n=6, raio_topo=0.22)])
                self.pontos["lampioes"].append([round(q[0], 2), round(ly + 0.2, 2), round(q[1], 2)])
            self.col.append(cilindro(a[0], a[1], 1.3, ya - 1.0, ya + 4.0, n=6))
            if not aberto:
                self.col.append(cilindro(b[0], b[1], 1.3, yb - 1.0, yb + 4.0, n=6))
            # o que pende da trave
            for c in range(4):
                t = 0.15 + 0.7 * c / 3.0 + rnd.uniform(-0.05, 0.05)
                gx, gz = lerp(a[0], b[0], t), lerp(a[1], b[1], t)
                gtopo = y_trave(t)
                if (k + c) % 3 == 0:
                    # tudo pende a mais de 5 m do chao: por cima da cabeca
                    gy = gtopo - rnd.uniform(5.0, 8.0)
                    self.gaiola(gx, gy, gz, gtopo, setor, corpo=rnd.random() < 0.7)
                else:
                    comp = rnd.uniform(3.0, 7.0)
                    self.m.add_pecas(setor, "metal", corrente_vertical(gx, gz, gtopo, gtopo - comp, larg=0.14))
                    self.gancho(gx, gtopo - comp, gz, setor)
                    if rnd.random() < 0.5:
                        # corpo pendurado pelo gancho: a curva de baixo dele
                        # (0,9 m pro lado, 2,6 m abaixo) passa por dentro do peito
                        yg = gtopo - comp - 2.6
                        self.m.add_pecas(setor, "carne_seca", [
                            cilindro(gx + 0.9, gz, 0.3, yg - 2.0, yg + 0.25, n=6, raio_topo=0.24),
                            cilindro(gx + 0.9, gz, 0.2, yg + 0.25, yg + 0.75, n=6)])
            s += rnd.uniform(22.0, 30.0)
            k += 1
        self.area("area_6_enforcados", s_de_th(5.3))

    def garganta(self):
        """Segundo circulo: estreito, apertado entre o abismo e a parede do
        terraco de cima. Colunas de basalto, tentaculos subindo do poco,
        geiseres; a cascata cruza outra vez."""
        rnd = self.rnd
        s0, s1 = s_de_th(6.5), s_de_th(TH_FIM - 0.4)
        for k in range(30):
            s = rnd.uniform(s0, s1)
            if perto_de_ponte(LINHA.em_s(s), 10.0) is not None:
                continue
            x, y, z, i = self.ponto_m(s, LINHA.p[LINHA.em_s(s)][2] + rnd.uniform(0.6, 2.5))
            if not self.livre(x, z, 3.0):
                continue
            setor = self.setor_grade("basalto", x, z, SETOR)
            pecas = []
            for c in range(rnd.randint(3, 7)):
                a = rnd.uniform(0, 2 * math.pi)
                r = rnd.uniform(0.0, 1.8)
                pecas.append(cilindro(x + math.cos(a) * r, z + math.sin(a) * r, rnd.uniform(0.5, 0.85), y - 1.0,
                                      y + rnd.uniform(2.5, 10.0), n=6, fase=rnd.uniform(0, 1)))
            self.m.add_pecas(setor, "basalto_col", pecas)
            self.ocupar(x, z, 2.4, bloqueia=False)
        # espinhos na beirada do abismo
        for k in range(26):
            s = rnd.uniform(s0, s1)
            if perto_de_ponte(LINHA.em_s(s), 10.0) is not None:
                continue
            x, y, z, i = self.ponto_m(s, -(LINHA.p[LINHA.em_s(s)][2] + rnd.uniform(1.0, 3.0)))
            setor = self.setor_grade("beirada", x, z, SETOR)
            yb = LINHA.p[i][3]
            ang = angulo(x, z) + math.pi
            # alem da beira o chao ja' despenca pro poco: o pe' desce ate' ele
            self.m.add_pecas(setor, "obsidiana", [espinho((x, min(yb - 3.0, self.pe(x, z, 0.8) - 1.0), z),
                                                          (x + math.sin(ang) * 3.0, yb + rnd.uniform(3.0, 8.0),
                                                           z + math.cos(ang) * 3.0), 0.8, n=5)])
        # tentaculos saindo da parede do poco
        for k, th in enumerate((6.9, 7.7, 9.0, 9.8)):
            s = s_de_th(th)
            x, y, z, i = self.ponto_m(s, -(LINHA.p[LINHA.em_s(s)][2] + 2.6))
            base = (x, LINHA.p[i][3] - 18.0, z)
            ang = angulo(x, z) + math.pi
            d = (math.sin(ang) * 0.5, 1.0, math.cos(ang) * 0.5)
            # a raiz ficava no ar na frente da parede: recua pelo eixo ate' entrar nela
            base, comp = raiz_no_chao(base, d, rnd.uniform(26.0, 36.0), self.chao_v, raio=2.4)
            tentaculo(self, "tentaculos", "carne", base, d, comp, 2.4, curva=1.0, fase=k * 1.9,
                      ventosas="osso")
        for th in (7.0, 7.6, 9.2, 9.9):
            for _t in range(12):
                x, y, z, i = self.ponto(s_de_th(th) + rnd.uniform(-6, 6), rnd.uniform(-0.45, 0.45))
                if self.livre(x, z, 3.0) and perto_de_ponte(i, 8.0) is None:
                    break
            self.geiser(x, y, z)
        self.area("area_7_garganta", s_de_th(9.4))

    def agulha(self):
        """A torre do meio do poco: sobe do fundo da lava ate' acima da
        cratera, torcida, com veios acesos em espiral e um CORACAO preso no
        meio. A saida e' a boca aberta na base, virada pra ponte. Em volta da
        ilha, dentes."""
        rnd = self.rnd
        setor = "agulha"
        pts, raios = [], []
        perfil = ((LAVA_POCO - 6.0, 17.0), (-30.0, 13.0), (Y1 - 2.0, AGULHA_R + 0.5), (10.0, 8.0), (30.0, 6.6),
                  (55.0, 4.6), (80.0, 2.6), (100.0, 1.2), (112.0, 0.25))
        for k, (yy, rr) in enumerate(perfil):
            tor = 1.4 * math.sin(yy * 0.045)
            pts.append((tor, yy, 1.2 * math.cos(yy * 0.05)))
            raios.append(rr)
        self.m.add_pecas(setor, "obsidiana", [tubo_redondo(pts, raios, n=14)], suave=True)

        def eixo(yy):
            """O centro da torre na altura `yy`: o tubo e' reto entre os pontos
            do perfil (o seno do torcido so' vale NOS pontos)."""
            for k in range(len(pts) - 1):
                if yy <= pts[k + 1][1]:
                    t = max(0.0, (yy - pts[k][1]) / (pts[k + 1][1] - pts[k][1]))
                    return lerp(pts[k][0], pts[k + 1][0], t), lerp(pts[k][2], pts[k + 1][2], t)
            return pts[-1][0], pts[-1][2]
        # veios acesos em espiral
        for v in range(3):
            vp, vr = [], []
            for k in range(41):
                t = k / 40.0
                yy = lerp(-20.0, 104.0, t)
                rr = _tabela(yy, [(p[0], p[1]) for p in perfil]) + 0.15
                a = v * 2.0944 + t * 7.5
                ex, ez = eixo(yy)
                vp.append((rr * math.sin(a) + ex, yy, rr * math.cos(a) + ez))
                vr.append(0.35 * (1.0 - 0.6 * t))
            self.m.add_pecas(setor, "brasa", [tubo_redondo(vp, vr, n=5)])
        # espinhos saindo da torre
        for k in range(46):
            yy = rnd.uniform(4.0, 96.0)
            rr = _tabela(yy, [(p[0], p[1]) for p in perfil])
            a = rnd.uniform(0, 2 * math.pi)
            if abs(((a - 1.5 * math.pi) + math.pi) % (2 * math.pi) - math.pi) < 0.6 and yy < 22.0:
                continue          # nada em cima da boca
            ex, ez = eixo(yy)
            b = (ex + rr * 0.8 * math.sin(a), yy, ez + rr * 0.8 * math.cos(a))
            comp = rnd.uniform(3.0, 9.0) * (1.2 - yy / 120.0)
            p = (b[0] + math.sin(a) * comp, yy + comp * rnd.uniform(0.1, 0.6), b[2] + math.cos(a) * comp)
            self.m.add_pecas(setor, "osso", [espinho(b, p, 0.5 + comp * 0.06, n=5)])
        # o coracao
        cy = 34.0
        cx, cz = -6.8, 0.0
        self.m.add_pecas("coracao", "carne", [tubo_redondo([(cx, cy - 4.2, cz), (cx - 1.2, cy - 1.0, cz), (cx - 1.0, cy + 2.6, cz),
                                                            (cx + 0.2, cy + 4.6, cz)], [1.2, 3.0, 2.6, 0.9], n=10)], suave=True)
        self.m.add_pecas("coracao", "brasa", [tubo_redondo([(cx - 2.6, cy - 1.0, cz - 1.0), (cx - 3.3, cy + 1.5, cz + 0.4),
                                                            (cx - 2.4, cy + 3.0, cz + 1.2)], [0.3, 0.35, 0.2], n=5)])
        for k in range(6):
            a = k * 1.05
            self.m.add_pecas("coracao", "carne", [tubo_redondo([(cx - 1.0, cy + 2.0, cz), (cx - 0.5 + math.cos(a) * 2.0, cy + 5.0 + k * 0.6,
                                                                                       cz + math.sin(a) * 3.0),
                                                                (cx + 1.5 + math.cos(a) * 3.5, cy + 6.0 + k, cz + math.sin(a) * 4.5)],
                                                               [0.7, 0.5, 0.3], n=6)])
        self.pontos["coracao"] = [round(cx - 3.5, 2), cy, cz]
        # a boca na base, virada pro -X (de onde vem a ponte)
        yb = LINHA.p[-1][3]
        bx = -AGULHA_R - 0.8
        arco = []
        for k in range(17):
            t = k / 16.0
            u = 2 * t - 1
            arco.append((bx, yb + 0.5 + 15.0 * (1 - u * u) ** 0.6, u * 5.8))
        self.m.add_pecas("boca", "osso", [tubo_redondo(arco, [1.1] * len(arco), n=8)], suave=True)
        dentes = []
        for k in range(1, 16):
            p0 = arco[k]
            u = 2 * (k / 16.0) - 1
            dentro = (p0[0] - 0.3, p0[1] - 2.6 * (1 - abs(u) * 0.4), p0[2] * 0.75)
            dentes.append(espinho(p0, dentro, 0.45, n=4))
        for sg in (-1, 1):
            for k in range(4):
                zz = sg * (6.4 + k * 1.4)
                dentes.append(espinho((bx + 0.4, yb - 0.5, zz), (bx - 1.2, yb + 5.5 - k, zz * 1.05), 0.8, n=5))
        self.m.add_pecas("boca", "osso", dentes)
        self.m.add_pecas("boca", "escuro", [caixa((bx + 0.3, yb, -5.0), (bx + 0.9, yb + 13.0, 5.0))])
        self.col.append(cilindro(0.0, 0.0, AGULHA_R + 0.3, yb - 6.0, yb + 60.0, n=14))
        self.bloquear(0.0, 0.0, AGULHA_R + 1.0)
        self.pontos["saida"] = [-15.2, round(yb + 0.2, 2), 0.0]
        self.pontos["boca"] = [round(bx - 0.4, 2), round(yb + 7.0, 2), 0.0]
        # dentes em volta da ilha (fora do caminho)
        for k in range(28):
            a = 2 * math.pi * k / 28
            r = ILHA_R + rnd.uniform(0.5, 3.0)
            x, z = r * math.sin(a), r * math.cos(a)
            kk, lat, d = LINHA.perto(x, z)
            if kk is not None and abs(lat) < LINHA.p[kk][2] - 0.5 and LINHA.s[kk] > S_FIM - 60:
                continue
            if abs(z) < PONTE_W + 3.0 and x < 0:
                continue          # a cabeceira da ponte
            y = altura(x, z)
            if y < LAVA_POCO + 2.0:
                y = yb - 1.0
            # o dente que cai fora da ilha sobe la' de baixo, do chao (ou da lava)
            self.m.add_pecas("ilha", "osso", [espinho((x, min(y - 2.0, self.pe(x, z, 1.1) - 1.0), z),
                                                       (x * 1.08, y + rnd.uniform(4.0, 10.0), z * 1.08), 1.1, n=5)])
        self.area("area_9_agulha", S_FIM - 8.0)

    def ponte_abismo(self, p):
        """Torres e correntes da ponte do abismo (o tabuleiro sai em `pontes`)."""
        setor = p["setor"]
        torres = []
        for ds in (-p["comp"] - 1.0, p["comp"] + 1.0):
            i = LINHA.em_s(p["s"] + ds)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            for sg in (-1, 1):
                x, z = q[0] - tz * sg * (p["w"] + 2.4), q[1] + tx * sg * (p["w"] + 2.4)
                y = y_ponte(p, p["s"] + ds * 0.98)
                h = 22.0
                giro = math.atan2(tx, tz)
                # a torre fica fora do tabuleiro, em cima do abismo: desce ate'
                # o chao (ou a lava) la' embaixo. No alto, quatro pontas nos
                # cantos (a do meio pairava 2 m acima) e o meio livre pra gargula
                pecas = self.firmar([caixa_girada(x, y + h / 2 - 2.0, z, 2.6, h + 4.0, 2.6, giro)], 1.0)
                cg, sgr = math.cos(giro), math.sin(giro)
                for cx_, cz_ in ((-0.9, -0.9), (0.9, -0.9), (0.9, 0.9), (-0.9, 0.9)):
                    px, pz = x + cx_ * cg + cz_ * sgr, z - cx_ * sgr + cz_ * cg
                    pecas.append(espinho((px, y + h - 0.3, pz), (px, y + h + 3.2, pz), 0.38, n=4))
                self.m.add_pecas(setor, "obsidiana", pecas)
                self.col.append(caixa_girada(x, y + 4.0, z, 2.6, 12.0, 2.6, giro))
                torres.append((x, y + h, z, sg, ds))
                # o marcador e' onde fica a SOLA da gargula: o topo da torre
                self.pontos["pousos"].append([round(x, 2), round(y + h, 2), round(z, 2)])
        # cabos principais: de torre a torre, caindo em catenaria ate' perto
        # do tabuleiro, e os tirantes verticais
        for sg in (-1, 1):
            a = [t for t in torres if t[3] == sg and t[4] < 0][0]
            b = [t for t in torres if t[3] == sg and t[4] > 0][0]
            cabo = []
            for k in range(21):
                t = k / 20.0
                cabo.append((lerp(a[0], b[0], t), lerp(a[1], b[1], t) - 17.0 * math.sin(t * math.pi), lerp(a[2], b[2], t)))
            self.m.add_pecas(setor, "metal", [tubo_redondo(cabo, [0.45] * len(cabo), n=6)])
            for k in range(2, 19, 2):
                c = cabo[k]
                s = lerp(p["s"] - p["comp"], p["s"] + p["comp"], k / 20.0)
                yd = y_ponte(p, s)
                # tirante: barra redonda (o `tubo` na vertical sai sem espessura)
                self.m.add_pecas(setor, "metal", [tubo_redondo([(c[0], c[1] + 0.2, c[2]), (c[0], yd + 0.9, c[2])],
                                                               [0.1, 0.1], n=5)])
        # correntes penduradas por baixo, sumindo no poco
        rnd = self.rnd
        for k in range(7):
            s = p["s"] + rnd.uniform(-p["comp"] + 3, p["comp"] - 3)
            i = LINHA.em_s(s)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            sg = rnd.choice((-1, 1))
            x, z = q[0] - tz * sg * (p["w"] - 0.5), q[1] + tx * sg * (p["w"] - 0.5)
            y = y_ponte(p, s) - 1.6
            self.m.add_pecas(setor, "metal", corrente_vertical(x, z, y + 0.3, y - rnd.uniform(12.0, 30.0), larg=0.18))
        x, _y, z, i = self.ponto(p["s"])
        self.pontos["areas"]["area_8_ponte"] = [round(x, 2), round(y_ponte(p, p["s"]), 2), round(z, 2)]

    # ------------------------------------------------------------------
    def braseiros(self):
        """Pira com fogo a cada ~75 m: a luz que guia no escuro."""
        s = 0.0
        prox = 60.0
        for k in range(1, len(LINHA.p)):
            s += math.hypot(LINHA.p[k][0] - LINHA.p[k - 1][0], LINHA.p[k][1] - LINHA.p[k - 1][1])
            if s < prox:
                continue
            prox += 75.0
            if not (S_INICIO + 40 < s < S_FIM - 30):
                continue
            if perto_de_ponte(k, 8.0) is not None:
                continue
            for lado in ((-0.82,) if len(self.pontos["braseiros"]) % 2 else (0.82,)):
                x, y, z, i = self.ponto(s, lado)
                if not self.livre(x, z, 2.0):
                    x, y, z, i = self.ponto(s, -lado)
                if not self.livre(x, z, 2.0):
                    continue
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

    def poco(self):
        """Lava jorrando de rachas nas paredes do poco e as MAOS gigantes que
        sobem da lava do fundo (objetos soltos: o script as faz respirar)."""
        rnd = self.rnd
        feitas = 0
        for k in range(12):
            a = 2 * math.pi * k / 12 + rnd.uniform(-0.15, 0.15)
            if abs(((a - TH_RIO) + math.pi) % (2 * math.pi) - math.pi) < 0.3:
                continue
            ca, sa = math.cos(a), math.sin(a)
            topo = None
            for r in range(115, 30, -2):
                x, z = r * sa, r * ca
                h = altura(x, z)
                if h < -22.0:
                    topo = (x, z, h)
                    break
            if topo is None:
                continue
            x, z, h = topo
            giro = math.atan2(-sa, -ca)
            self.cachoeira(x, z, h + 1.0, LAVA_POCO, giro, rnd.uniform(5.0, 11.0))
            feitas += 1
        self.pontos["n_cachoeiras"] = feitas
        for k, (a, r, alt) in enumerate(((0.7, 52.0, 46.0), (2.9, 60.0, 58.0), (5.3, 48.0, 40.0))):
            x, z = r * math.sin(a), r * math.cos(a)
            v, f = _mao(alt, rnd)
            self.soltos.append(("MAO_%d" % k, "carne_seca", (v, f), (x, LAVA_POCO - 2.0, z)))

    def cachoeira(self, x, z, topo, fundo, giro, larg, setor="cachoeiras"):
        """Cortina de lava caindo ate' `fundo`. UV.v desce."""
        ca, sa = math.cos(giro), math.sin(giro)
        verts, faces, uvs = [], [], []
        n = 8
        for k in range(n + 1):
            t = k / n
            y = lerp(topo, fundo, t)
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
        self.pontos["lavas_som"].append([round(x + sa * 4, 2), round((topo + fundo) / 2, 2), round(z + ca * 4, 2)])

    # ------------------------------------------------------------------
    def longe(self):
        rnd = self.rnd
        # vulcoes no mar de fora
        for (x, z, r, h) in ((-520.0, 260.0, 190.0, 240.0), (560.0, -120.0, 230.0, 300.0),
                             (-300.0, -560.0, 170.0, 210.0), (420.0, 480.0, 160.0, 180.0),
                             (60.0, -860.0, 280.0, 340.0), (-700.0, -200.0, 200.0, 260.0)):
            self.m.add_pecas("vulcoes", "rocha_longe", [cilindro(x, z, r, LAVA_MAR - 10.0, h, n=16, raio_topo=r * 0.18)])
            self.m.add_pecas("vulcoes", "lava_brilho", [cilindro(x, z, r * 0.17, h - 0.5, h + 1.5, n=16, raio_topo=r * 0.14)])
            self.pontos.setdefault("vulcoes", []).append([x, h + 2.0, z])
        # ilhas de rocha e espinhos no mar
        for k in range(60):
            a = rnd.uniform(0, 2 * math.pi)
            r = rnd.uniform(300.0, 760.0)
            x, z = r * math.sin(a), r * math.cos(a)
            if abs(x) < 40.0 and z > 240.0:
                continue          # a frente do esporao fica limpa
            h = rnd.uniform(10.0, 60.0)
            self.m.add_pecas("ilhas", "rocha_longe", [espinho((x, LAVA_MAR - 4.0, z),
                                                              (x + rnd.uniform(-10, 10), LAVA_MAR + h, z + rnd.uniform(-10, 10)),
                                                              rnd.uniform(6.0, 18.0), n=6)])
        # ruinas e torres no horizonte
        for k in range(30):
            a = rnd.uniform(0, 2 * math.pi)
            r = rnd.uniform(480.0, 820.0)
            x, z = r * math.sin(a), r * math.cos(a)
            silhueta_gotica(self, "horizonte", "silhueta", x, z, rnd.uniform(12.0, 30.0), rnd.uniform(30.0, 80.0), rnd,
                            giro=rnd.uniform(0, math.pi))
        g = self.m.grupos[("horizonte", "silhueta")]
        g["v"] = [(vx, vy + LAVA_MAR - 2.0, vz) for vx, vy, vz in g["v"]]

    def sombras(self):
        """As SOMBRAS: figuras de 60 a 180 m de pe' no mar de fora, olhando
        pra cratera (objetos soltos com pivo no pe'; o script as balanca)."""
        rnd = self.rnd
        feitas = 0
        tent = 0
        while feitas < 14 and tent < 400:
            tent += 1
            a = rnd.uniform(0, 2 * math.pi)
            r = rnd.uniform(300.0, 470.0)
            x, z = r * math.sin(a), r * math.cos(a)
            if abs(x) < 70.0 and z > 200.0:
                continue
            if altura(x, z) > LAVA_MAR + 2.0:
                continue
            alt = rnd.uniform(70.0, 180.0)
            v, f = _figura(alt, rnd, feitas % 3)
            self.soltos.append(("SOMBRA_%d" % feitas, "sombra", (v, f), (x, LAVA_MAR - 1.0, z)))
            feitas += 1

    def cercadura(self):
        """Muro invisivel dos dois lados do caminho inteiro + tampa nas pontas."""
        for lado in (-1, 1):
            pts = []
            for k in range(0, len(LINHA.p), 2):
                q = LINHA.p[k]
                if not (S_INICIO - 1 <= LINHA.s[k] <= S_FIM + 1):
                    continue
                tx, tz = LINHA.t[k]
                off = q[2] + 0.5
                x = q[0] - tz * off * lado
                z = q[1] + tx * off * lado
                kk, lat, d = LINHA.perto(x, z)
                if kk is not None and abs(lat) < LINHA.p[kk][2] - 0.5:
                    continue
                pts.append((x, z))
            muro_invisivel(self, pts, y0=-80.0, y1=70.0, esp=1.6, fechar=False)
        for st in (S_INICIO, S_FIM):
            i = LINHA.em_s(st)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            self.col.append(caixa_girada(q[0], q[3] + 10.0, q[1], 2 * q[2] + 8.0, 150.0, 1.6, math.atan2(tx, tz)))

    def _marcadores(self):
        nav = self.pontos["navmesh"]
        centros = []
        for poly in nav["p"]:
            n = float(len(poly))
            centros.append((sum(nav["v"][k][0] for k in poly) / n, sum(nav["v"][k][1] for k in poly) / n,
                            sum(nav["v"][k][2] for k in poly) / n))
        usados = set()
        s = S_INICIO + 90.0
        while s < S_FIM - 60.0:
            for lado in (-0.4, 0.4):
                x, y, zz, i = self.ponto(s, lado)
                melhor, md = None, 1e18
                for k, c in enumerate(centros):
                    if k in usados:
                        continue
                    d = (c[0] - x) ** 2 + (c[2] - zz) ** 2
                    if d < md:
                        melhor, md = k, d
                if melhor is not None and md < 100.0 and abs(centros[melhor][1] - y) < 3.0:
                    usados.add(melhor)
                    c = centros[melhor]
                    self.pontos["inimigos"].append([round(c[0], 2), round(c[1] + 0.1, 2), round(c[2], 2)])
            s += 52.0


def _mao(alt, rnd):
    """Mao esquelética gigante subindo da lava, aberta pro ceu, em coordenada
    LOCAL (pulso no zero). Palma e cinco dedos de tres falanges."""
    pecas = []
    h = alt
    pecas.append(tubo_redondo([(0.0, 0.0, 0.0), (0.0, h * 0.45, h * 0.02), (0.0, h * 0.6, 0.0)],
                              [h * 0.07, h * 0.06, h * 0.075], n=8))
    palma = (0.0, h * 0.68, 0.0)
    pecas.append(tubo_redondo([(0.0, h * 0.58, 0.0), palma], [h * 0.09, h * 0.1], n=8))
    for d in range(5):
        a = (d - 2) * 0.32
        polegar = d == 0
        base = (math.sin(a) * h * 0.09 + (h * 0.04 if polegar else 0.0), h * (0.66 if polegar else 0.74),
                (h * 0.05 if polegar else 0.0))
        dirx, diry = math.sin(a) * (1.9 if polegar else 1.0), 1.0
        comp = h * (0.16 if polegar else 0.22 + 0.04 * (1 - abs(d - 2) / 2.0))
        dobra = rnd.uniform(0.15, 0.55)
        pts = [base]
        for j in range(1, 4):
            t = j / 3.0
            pts.append((base[0] + dirx * comp * t * 0.55, base[1] + diry * comp * t, base[2] + comp * dobra * t * t))
        pecas.append(tubo_redondo(pts, [h * 0.03, h * 0.026, h * 0.02, h * 0.008], n=6))
    v, f = [], []
    for pv, pf in pecas:
        b = len(v)
        v.extend(pv)
        f.extend([[k + b for k in face] for face in pf])
    return v, f


def main():
    global LINHA, S_INICIO, S_FIM
    LINHA = Linha(montar_controle())
    S_INICIO = 6.0
    # a tampa do fim fica 4 m antes da boca da agulha: a area da saida
    # (no Godot) pega o jogador antes dele bater nela
    S_FIM = LINHA.s[LINHA.em_xz(-14.0, 0.0)]
    # a cascata: do alto da parede da cratera, pelo raio TH_RIO, ate' o poco
    ca, sa = math.cos(TH_RIO), math.sin(TH_RIO)
    r = R_CRISTA - 6.0
    while r > 34.0:
        RIO.append((r * sa, r * ca))
        r -= 2.0
    # comeca onde a parede ja' desceu uns metros do alto da crista
    while len(RIO) > 2 and altura(*RIO[0]) > crista(*RIO[0]) - 5.0:
        RIO.pop(0)
    for k, th in enumerate(TH_TRAVESSIAS):
        PONTES.append({"s": s_de_th(th), "comp": PONTE_RIO_COMP, "w": PONTE_W, "arco": 0.9, "abismo": False,
                       "setor": "ponte_rio_%d" % k})
    sp = LINHA.s[LINHA.em_xz(-41.0, 0.0)]
    PONTES.append({"s": sp, "comp": 11.0, "w": PONTE_W, "arco": 1.4, "abismo": True, "reta": True,
                   "setor": "ponte_abismo", "mat": "obsidiana"})
    inf = Inferno2()
    inf.montar()
    inf.ponte_abismo(PONTES[-1])
    print("  linha: %d pontos, %.0f m (S_FIM %.0f)" % (len(LINHA.p), LINHA.s[-1], S_FIM))
    inf.exportar("inferno_2", "inferno_2", abertos=("chao_", "lava_mar", "lava_poco", "lava_cascata", "cachoeiras"))
    nav = inf.pontos["navmesh"]
    print("  navmesh: %d vertices, %d poligonos" % (len(nav["v"]), len(nav["p"])))
    print("  braseiros=%d geiseres=%d inimigos=%d sombras/maos=%d cachoeiras=%d" % (
        len(inf.pontos["braseiros"]), len(inf.pontos["geiseres"]), len(inf.pontos["inimigos"]), len(inf.soltos),
        inf.pontos.get("n_cachoeiras", 0)))


if __name__ == "__main__":
    main()
