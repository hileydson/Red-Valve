# -*- coding: utf-8 -*-
"""Modela o INFERNO 4 — O MORRO DO MIRANTE — e exporta pro Godot.

    blender --background --factory-startup \\
        --python tools/blender/inferno_4/gerar_inferno_4.py

Saidas:
    red-valve/assets/3d_model/stages/inferno_4/inferno_4.glb
    red-valve/assets/3d_model/stages/inferno_4/inferno_4_pontos.json

Depois: `tools/godot/inferno_4/gerar_cena_inferno_4.py`,
`tools/godot/inferno/make_mapa_inferno.py inferno_4` e `--headless --import`.

==============================================================================
O LUGAR

A porta da catedral do inferno 3 da' na mesma cidade de pedra preta, na mesma
noite e na mesma nevoa — so' que agora o caminho SOBE um morro e DESCE do
outro lado. Mapa menor (~600 m), de sul a norte:

   S  1 O ANEL               por onde se chega (volta pra catedral do 3); o
   |                         altar da lanterna, pra quem ainda nao a tem
   |  2 A LADEIRA            rua estreita entre casas, ja' subindo
   |  3 A SUBIDA             escadaria colada no morro: muro de arrimo de um
   |                         lado, o abismo do outro
   |  4 O CEMITERIO DA ENCOSTA  patamar de tumulos no meio da subida
   |  5 O MIRANTE            o topo: a capela do sino e a beira de onde se ve'
   |                         o GRANDE INFERNO — a cutscene comeca aqui
   |  6 A DESCIDA            escadas descendo a face norte, forcas com gaiola
   N  7 O FOSSO              largo plano na beira da cratera (o espaco do mini
                             chefe) e o anel do portal, ainda sem destino

O GRANDE INFERNO nao se anda: e' a vista. Uma cratera de mais de 3 km em
volta do morro, o fundo engolido pela nevoa baixa, e de dentro dela sobem
torres, igrejas em cima de mesas de rocha, agulhas de pedra, aquedutos, uma
catedral colossal de mais de 500 m com a rosacea acesa e gigantes de sombra
entre os predios. Janelas acesas pontilham tudo: e' o que da' a escala de
longe. As gargulas do ceu e o bando sobre a cratera sao soltos pela cena.

==============================================================================
COMO O CHAO E' FEITO

A mesma linha de centro do inferno 3, com mais um par de pesos por ponto: a
ENCOSTA — o morro subindo do lado de fora do caminho, plano ate' o muro de
arrimo e depois em rampa ate' o cume. Longe da linha tudo despenca pro fundo
da cratera (`FUNDO`), que a nevoa baixa esconde: o chao que se anda e' uma
ilha no meio da vista.

As pecas sao as do inferno 3 (casa, caixao, lampiao, enlutado, grade, anel,
altar da lanterna, chapas de zinco) e as do cemiterio. O gerador do 3 e'
carregado DE NOVO, com outro nome, e os nomes que ele le' do proprio modulo
(LINHA, altura, S_FIM...) apontam pra daqui — o modulo de verdade fica
intacto (o baker do minimapa importa os dois na mesma execucao).
"""

import importlib.util
import math
import os
import random
import sys

# o .pyc da base nao pode nascer antes de ela desligar o bytecode
sys.dont_write_bytecode = True
AQUI = os.path.dirname(os.path.abspath(__file__))
for _pasta in ("cemiterio", "inferno_2", "inferno", "cenarios"):
    sys.path.insert(0, os.path.join(AQUI, os.pardir, _pasta))

from base import (assentar, caixa, caixa_girada, chao_sob, chao_visivel,  # noqa: E402
                  chapa_aberta, chapa_grossa, cilindro, corrente_vertical, espinho,
                  estender_ate_o_chao, hexaedro, lerp, navmesh_grade, ruido2,
                  silhueta_gotica, suave, tubo_redondo)
from gerar_inferno import _figura  # noqa: E402
import gerar_inferno_2 as inf2  # noqa: E402
import gerar_cemiterio as cem  # noqa: E402


def _gerador_do_inferno_3():
    caminho = os.path.join(AQUI, os.pardir, "inferno_3", "gerar_inferno_3.py")
    spec = importlib.util.spec_from_file_location("inferno_3_do_inferno_4", caminho)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


inf3 = _gerador_do_inferno_3()
moldura, bloco, prisma_tri = inf3.moldura, inf3.bloco, inf3.prisma_tri
telhado_duas_aguas, ponto_linha = inf3.telhado_duas_aguas, inf3.ponto_linha

FUNDO = -150.0         # o fundo da cratera (a nevoa baixa engole tudo abaixo de ~-4)
PASSO = 4.0            # chao visivel
PASSO_COL = 2.0        # colisao do chao
PASSO_NAV = 2.5
SETOR = 48.0           # cota de 8 omni por malha
SETOR_VISTA = 400.0
CUME = 46.0            # ate' onde a encosta sobe
ARRIMO = 4.5           # da beira do caminho ate' a cara do muro de arrimo
# do mirante pro coracao do grande inferno (x, z): noroeste
VISTA_DIR = (-0.722, -0.692)

# (x, z, meia-largura, altura, abismo_a, abismo_b, campo_a, campo_b,
#  encosta_a, encosta_b) — lado "a" = lateral positiva = o LESTE de quem sobe
CONTROLE = [
    (40.0, 200.0, 14.0, 0.0, 0.0, 0.7, 0.0, 0.0, 0.0, 0.0),
    (40.0, 176.0, 15.0, 0.0, 0.0, 0.8, 0.0, 0.0, 0.0, 0.0),     # 1 o anel
    (34.0, 150.0, 9.0, 0.6, 0.0, 0.3, 0.0, 0.0, 0.0, 0.0),
    (30.0, 124.0, 7.0, 2.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),      # 2 a ladeira
    (36.0, 96.0, 7.0, 5.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
    (28.0, 70.0, 6.5, 9.5, 0.0, 0.9, 0.0, 0.0, 1.0, 0.0),       # 3 a subida
    (32.0, 44.0, 6.5, 16.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0),
    (24.0, 18.0, 9.0, 20.5, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0),      # 4 o cemiterio da encosta
    (18.0, -8.0, 10.0, 21.5, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0),
    (24.0, -34.0, 6.5, 27.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0),
    (14.0, -60.0, 6.5, 35.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0),
    (6.0, -84.0, 8.0, 41.5, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0),
    (0.0, -108.0, 20.0, 44.0, 0.4, 1.0, 0.0, 0.0, 0.3, 0.0),    # 5 o mirante
    (4.0, -134.0, 22.0, 44.0, 0.5, 1.0, 0.0, 0.0, 0.3, 0.0),
    (16.0, -156.0, 12.0, 43.0, 0.2, 1.0, 0.0, 0.0, 0.8, 0.0),
    (26.0, -178.0, 7.0, 38.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0),    # 6 a descida
    (20.0, -202.0, 7.0, 31.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0),
    (28.0, -226.0, 7.5, 23.5, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0),
    (24.0, -250.0, 9.0, 16.5, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0),
    (28.0, -272.0, 14.0, 14.5, 0.0, 1.0, 0.0, 0.0, 0.6, 0.0),
    (30.0, -296.0, 28.0, 14.0, 0.2, 1.0, 0.0, 0.0, 0.6, 0.0),   # 7 o fosso
    (30.0, -324.0, 30.0, 14.0, 0.3, 1.0, 0.0, 0.0, 0.5, 0.0),
    (30.0, -352.0, 24.0, 14.0, 0.8, 1.0, 0.0, 0.0, 0.0, 0.0),
    (30.0, -372.0, 18.0, 14.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0),
]

LINHA = None
S_INICIO = 0.0
S_FIM = 0.0
S_LADEIRA = (0.0, 0.0)
S_CEMITERIO = (0.0, 0.0)
S_MIRANTE = 0.0
S_FOSSO = (0.0, 0.0)
ESCADAS = []
# o inferno 3 tem ponte e escadaria; aqui nao: as funcoes dele leem estes
PONTE = (-1e9, -1e9)
ESCADA = (-1e9, -1e9)


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
    rug = 9.0 * ruido2(x * 0.02, z * 0.02, 7.0) + 2.5 * ruido2(x * 0.2, z * 0.2, 3.0)
    if i is None:
        return FUNDO + rug
    q = LINHA.p[i]
    w, y0 = q[2], q[3]
    al = abs(lat)
    lado_a = lat > 0
    ab = q[4] if lado_a else q[5]
    cp = q[6] if lado_a else q[7]
    en = q[8] if lado_a else q[9]
    n = 0.08 * ruido2(x * 0.7, z * 0.7, 1.0)
    if al <= w:
        return y0 + n
    fora = al - w
    casario = y0 + 0.15 + n
    campo = y0 + 0.1 + 0.6 * ruido2(x * 0.08, z * 0.08, 3.0) * min(1.0, fora / 6.0)
    # a encosta: plana ate' o muro de arrimo, um degrau da altura do muro
    # logo atras dele, e dali a rampa do morro ate' o cume
    e = y0 + 0.15 + 3.3 * suave((fora - ARRIMO) / 4.0) + max(0.0, fora - ARRIMO - 4.0) * 0.6
    encosta = min(e + 1.2 * ruido2(x * 0.09, z * 0.09, 2.0) * suave((fora - ARRIMO) / 8.0), max(CUME, y0 + 3.5))
    h = lerp(casario, campo, cp)
    h = lerp(h, encosta, en)
    # longe da linha o morro acaba: tudo despenca pro fundo da cratera
    h = lerp(h, FUNDO + rug, suave((fora - 55.0) / 22.0))
    cai = suave(min(fora / 9.0, 1.0))
    abismo = lerp(y0 + n, FUNDO + rug, cai) + rug * 0.6 * math.sin(math.pi * cai)
    return lerp(h, abismo, ab)


def altura_vista(x, z):
    """O fundo da cratera da vista: sempre entre FUNDO - 8 e FUNDO (as pecas
    da vista nascem a FUNDO - 14, enterradas nele)."""
    return FUNDO - 4.0 + 4.0 * ruido2(x * 0.005, z * 0.005, 11.0)


def altura_col(x, z):
    """A colisao: o caminho segue plano 3 m alem da beira (ver a do inferno 3)."""
    i, lat, _d = LINHA.perto(x, z)
    if i is None:
        return altura(x, z)
    q = LINHA.p[i]
    if abs(lat) > q[2] + 3.0:
        return altura(x, z)
    return max(altura(x, z), q[3] - (0.05 if abs(lat) <= q[2] + inf3.BEIRA else 0.4))


def altura_nav(x, z):
    return altura(x, z)


def no_caminho(x, z, folga=0.0):
    i, lat, _d = LINHA.perto(x, z)
    if i is None:
        return False
    if not (S_INICIO + 1.0 < LINHA.s[i] < S_FIM - 1.0):
        return False
    return abs(lat) <= LINHA.p[i][2] - folga


def caminhavel(x, z):
    """A CELULA INTEIRA do navmesh (2,5 m) dentro do caminho, 1,1 m antes da
    beira. Testando so' o centro, a borda dela entrava meio metro no muro
    invisivel e quem segue o caminho mais curto raspava a quina onde a pista
    estreita (medido no inferno 3, na cabeceira da ponte)."""
    m = PASSO_NAV / 2.0
    return all(no_caminho(x + a, z + b, 1.1) for a in (-m, m) for b in (-m, m))


def _sem_chao(xc, zc):
    """Celula de chao que fica de fora: alem do despenhadeiro (a 77 m da beira
    o morro ja' chegou ao fundo), o resto e' a vista."""
    k, lat, d = LINHA.perto(xc, zc)
    return k is None or abs(lat) > LINHA.p[k][2] + 80.0


def _apontar_o_inferno_3():
    """As pecas do inferno 3 (e as do cemiterio) leem estes nomes do modulo
    delas: aponta pra daqui."""
    for nome in ("LINHA", "S_INICIO", "S_FIM", "PONTE", "ESCADA", "FUNDO", "SETOR",
                 "altura", "altura_col", "altura_nav", "no_caminho", "caminhavel", "_sem_chao"):
        setattr(inf3, nome, globals()[nome])
    cem.altura = altura
    cem.SETOR = SETOR


class Inferno4(inf3.Inferno3):

    def __init__(self):
        super().__init__()
        self.prefixo = "inf4"
        self.rnd = random.Random(4404)
        self.pontos.update({
            "piras": [],
            "sino": [0.0, 0.0, 0.0],
            "vista_alvo": [0.0, 0.0, 0.0],
            "vista_fogos": [],
            "vista_bando": [0.0, 0.0, 0.0, 0.0],
            "mirante": [0.0, 0.0, 0.0],
            "beira_mirante": [],
            "gatilho": [0.0, 0.0, 0.0, 0.0, 0.0],
            "nevoa_z": [0.0, 0.0, 0.0, 0.0],
            "mini_boss": [0.0, 0.0, 0.0, 0.0],
            "portal_saida": [0.0, 0.0, 0.0],
        })

    def encosta(self, i, sg):
        q = LINHA.p[i]
        return q[8] if sg > 0 else q[9]

    def pira(self, x, z, y, setor):
        """Braseiro de pedra com a bacia acesa (a omni e o fogo sao da cena)."""
        b0 = self.pe(x, z, 1.2) - 0.3
        self.m.add_pecas(setor, "pedra_clara", [cilindro(x, z, 0.8, b0, y + 1.2, n=8, raio_topo=0.6),
                                                cilindro(x, z, 0.95, y + 1.2, y + 1.6, n=10, raio_topo=1.15)])
        self.m.add_pecas(setor, "brasa", [cilindro(x, z, 0.92, y + 1.5, y + 1.64, n=10)])
        self.col.append(cilindro(x, z, 0.95, b0, y + 1.65, n=8))
        self.ocupar(x, z, 1.4)
        self.pontos["piras"].append([round(x, 2), round(y + 1.65, 2), round(z, 2)])

    # ------------------------------------------------------------------
    def montar(self):
        self.chao()
        self.chegada()
        self.casario()
        self.casario_de_tras()
        self.balaustradas()
        self.ladeira()
        self.arrimos()
        self.escadas()
        self.cemiterio_encosta()
        self.mirante()
        self.descida()
        self.fosso()
        self.lampioes()
        self.vista()
        self.cercadura()
        xs = [q[0] for q in LINHA.p]
        zs = [q[1] for q in LINHA.p]
        self.pontos["navmesh"] = navmesh_grade(
            self, min(xs) - 40.0, max(xs) + 40.0, min(zs) - 40.0, max(zs) + 40.0, PASSO_NAV,
            altura_nav, caminhavel,
            # as escadas chegam a ~38% no meio do lance: celula de 2,5 m em
            # diagonal sobe ~1,4 m. Folga de 1 m: a capsula do Maycow normal
            # tem 1,35 m de largura
            max_desnivel=1.8, folga=1.0, desnivel_bloco=2.0)
        self._marcadores()

    # ------------------------------------------------------------------
    def chao(self):
        """Chao visivel (so' o tampo) ate' o pe' do despenhadeiro; colisao
        fechada so' no caminho e numa faixa em volta."""
        visiveis = {}
        colisao = set()
        xs = [q[0] for q in LINHA.p]
        zs = [q[1] for q in LINHA.p]
        i0, i1 = int(math.floor((min(xs) - 120.0) / PASSO)), int(math.ceil((max(xs) + 120.0) / PASSO))
        j0, j1 = int(math.floor((min(zs) - 120.0) / PASSO)), int(math.ceil((max(zs) + 120.0) / PASSO))
        for i in range(i0, i1):
            for j in range(j0, j1):
                xc, zc = (i + 0.5) * PASSO, (j + 0.5) * PASSO
                if _sem_chao(xc, zc):
                    continue
                k, lat, d = LINHA.perto(xc, zc)
                q = LINHA.p[k]
                w = q[2]
                sg = 1 if lat > 0 else -1
                ab, cp = self.pesos(k, sg)
                en = self.encosta(k, sg)
                fora = abs(lat) - w
                no_cam = fora <= 0.5 and S_INICIO - 6 < LINHA.s[k] < S_FIM + 6
                if no_cam:
                    if cp > 0.6:
                        mat = "cascalho"
                    elif LINHA.s[k] > S_FOSSO[0] - 10.0:
                        mat = "calcada"
                    else:
                        mat = "paralelepipedo" if ruido2(xc * 0.2, zc * 0.2, 4.0) > -0.3 else "paralelepipedo_gasto"
                elif ab > 0.5 or fora > 52.0:
                    mat = "rocha"
                elif en > 0.5:
                    mat = "terra" if ruido2(xc * 0.05, zc * 0.05, 9.0) > -0.35 else "rocha"
                elif cp > 0.5:
                    mat = "terra"
                else:
                    mat = "calcada"
                setor = self.setor_grade("chao", xc, zc, SETOR)
                visiveis.setdefault((setor, mat), []).append((i, j))
                if fora <= 8.0 and S_INICIO - 8 < LINHA.s[k] < S_FIM + 8:
                    for a in (0, 1):
                        for b in (0, 1):
                            colisao.add((2 * i + a, 2 * j + b))
        malhas = []
        for (setor, mat), cel in visiveis.items():
            # a beira do abismo: a mesma do inferno 3 (le' LINHA/altura daqui)
            v, f = chapa_aberta(cel, PASSO, altura, inf3.vertice_chao)
            self.m.add(setor, mat, v, f)
            malhas.append((v, f))
        self.medir_chao(malhas)
        v, f = chapa_grossa(list(colisao), PASSO_COL, altura_col, 3.0)
        self.col.append((v, f))

    # ------------------------------------------------------------------
    def casario(self):
        """As fachadas so' na ladeira (e no lado de casas do adro do anel)."""
        rnd = self.rnd
        n = 0
        for sg in (1, -1):
            s = 32.0
            while s < S_LADEIRA[1]:
                L = rnd.uniform(7.0, 12.0)
                sm = s + L / 2.0
                i = LINHA.em_s(sm)
                ab, cp = self.pesos(i, sg)
                if ab > 0.35 or cp > 0.35 or self.encosta(i, sg) > 0.35:
                    s += L * 0.5
                    continue
                self.casa(i, sg, L, n)
                n += 1
                s += L + rnd.uniform(0.0, 0.6)
        self.pontos["n_casas"] = n

    def casario_de_tras(self):
        """A cidade que continua atras das casas da ladeira, na nevoa."""
        rnd = self.rnd
        feitas = 0
        tent = 0
        while feitas < 14 and tent < 600:
            tent += 1
            s = rnd.uniform(20.0, S_LADEIRA[1] + 10.0)
            i = LINHA.em_s(s)
            sg = rnd.choice((-1, 1))
            ab, cp = self.pesos(i, sg)
            if ab > 0.3 or cp > 0.3 or self.encosta(i, sg) > 0.3:
                continue
            x, z, _ = ponto_linha(s, sg * (LINHA.p[i][2] + rnd.uniform(22.0, 44.0)))
            kk, lat, _d = LINHA.perto(x, z)
            if kk is None or abs(lat) < LINHA.p[kk][2] + 18.0 or not self.livre(x, z, 9.0):
                continue
            larg = rnd.uniform(8.0, 14.0)
            if self.pe(x, z, larg * 1.7) < altura(x, z) - 3.0:
                continue          # na quina do despenhadeiro, nao
            alt = rnd.uniform(14.0, 30.0)
            g = self.m.grupos.get(("horizonte", "silhueta"))
            v0 = len(g["v"]) if g else 0
            silhueta_gotica(self, "horizonte", "silhueta", x, z, larg, alt, rnd, giro=math.atan2(*LINHA.t[i]))
            g = self.m.grupos[("horizonte", "silhueta")]
            b = self.pe(x, z, larg * 1.7) - 1.0
            g["v"][v0:] = [(vx, vy + b - (40.0 if vy < 0.01 else 0.0), vz) for vx, vy, vz in g["v"][v0:]]
            self.ocupar(x, z, larg * 0.7, bloqueia=False)
            feitas += 1

    # ------------------------------------------------------------------
    def ladeira(self):
        """A rua que sobe: caixoes largados, uma carruagem no comeco (onde
        ainda e' plano), chapas encostadas nas casas e sangue."""
        rnd = self.rnd
        s0, s1 = S_LADEIRA
        for k in range(7):
            s = rnd.uniform(s0 + 6.0, s1 - 4.0)
            lado = rnd.choice((-1, 1)) * rnd.uniform(0.58, 0.78)
            x, y, z, i = self.ponto(s, lado)
            if not self.livre(x, z, 2.5):
                continue
            tx, tz = LINHA.t[i]
            self.caixao_deitado(x, z, math.atan2(tx, tz) + rnd.uniform(-0.8, 0.8),
                                self.setor_grade("rua", x, z, SETOR), aberto=rnd.random() < 0.4)
        x, y, z, i = self.ponto(48.0, -0.55)
        tx, tz = LINHA.t[i]
        self.carruagem(x, z, math.atan2(tx, tz) + rnd.uniform(-0.3, 0.3), quebrada=True)
        for k in range(4):
            s = rnd.uniform(s0, s1)
            sg = rnd.choice((-1, 1))
            x, y, z, i = self.ponto_m(s, sg * (LINHA.p[LINHA.em_s(s)][2] - 0.3))
            if self.livre(x, z, 1.8):
                self.barricada(x, z, i, sg)
        for k in range(5):
            s = rnd.uniform(s0, s1)
            x, y, z, i = self.ponto(s, rnd.uniform(-0.6, 0.6))
            self.m.add_pecas(self.setor_grade("rua", x, z, SETOR), "sangue",
                             [cilindro(x, z, rnd.uniform(0.7, 1.6), y - 0.05, y + 0.035, n=9, fase=rnd.uniform(0, 1))])
        self.area("area_2_ladeira", (s0 + s1) / 2.0)

    # ------------------------------------------------------------------
    def arrimos(self):
        """O muro de arrimo onde a beira e' ENCOSTA: segura o morro, com
        contraforte a cada 9 m e cimalha. E' grosso pra tras (o degrau da
        encosta encosta nele) e tem colisao — a camera nao entra no morro."""
        for sg in (1, -1):
            s = S_INICIO
            k = 0
            while s < S_FIM:
                i = LINHA.em_s(s)
                j = LINHA.em_s(s + 3.0)
                if self.encosta(i, sg) < 0.5 or self.encosta(j, sg) < 0.5:
                    s += 3.0
                    continue
                qa, qb = LINHA.p[i], LINHA.p[j]
                ta, tb = LINHA.t[i], LINHA.t[j]

                def L(q, t_, off, y):
                    return (q[0] - t_[1] * off * sg, y, q[1] + t_[0] * off * sg)

                ya, yb = qa[3], qb[3]
                a0, a1 = qa[2] + ARRIMO - 0.3, qa[2] + ARRIMO + 3.0
                b0, b1 = qb[2] + ARRIMO - 0.3, qb[2] + ARRIMO + 3.0
                muro = hexaedro([L(qa, ta, a0, ya - 1.2), L(qa, ta, a1, ya - 1.2), L(qb, tb, b1, yb - 1.2),
                                 L(qb, tb, b0, yb - 1.2), L(qa, ta, a0, ya + 3.6), L(qa, ta, a1, ya + 3.6),
                                 L(qb, tb, b1, yb + 3.6), L(qb, tb, b0, yb + 3.6)])
                cima = hexaedro([L(qa, ta, a0 - 0.2, ya + 3.6), L(qa, ta, a0 + 0.9, ya + 3.6),
                                 L(qb, tb, b0 + 0.9, yb + 3.6), L(qb, tb, b0 - 0.2, yb + 3.6),
                                 L(qa, ta, a0 - 0.2, ya + 3.85), L(qa, ta, a0 + 0.9, ya + 3.85),
                                 L(qb, tb, b0 + 0.9, yb + 3.85), L(qb, tb, b0 - 0.2, yb + 3.85)])
                setor = self.setor_grade("arrimo", *L(qa, ta, a0, 0.0)[::2], SETOR)
                self.m.add_pecas(setor, "fachada_pedra", [muro])
                self.m.add_pecas(setor, "pedra_clara", [cima])
                self.col.append(muro)
                if k % 3 == 0:
                    c = L(qa, ta, a0 - 0.35, 0.0)
                    self.m.add_pecas(setor, "pedra_clara",
                                     self.firmar([caixa_girada(c[0], ya + 1.6, c[2], 1.0, 4.4, 0.8,
                                                               math.atan2(*ta))], 0.3)
                                     + [espinho((c[0], ya + 3.8, c[2]), (c[0], ya + 5.2, c[2]), 0.42, n=4)])
                s += 3.0
                k += 1

    # ------------------------------------------------------------------
    def escadas(self):
        """Degraus de pedra nos trechos ingremes (a colisao e' a rampa por
        baixo deles) e um enlutado no meio de cada lance, do lado do abismo."""
        for n, (s0, s1) in enumerate(ESCADAS):
            s = s0
            degraus = []
            while s < s1:
                i = LINHA.em_s(s)
                q = LINHA.p[i]
                tx, tz = LINHA.t[i]
                P = moldura(q[0], 0.0, q[1], tx, tz, -tz, tx)
                w = q[2] + 0.05
                degraus.append(bloco(P, -0.42, 0.42, q[3] - 1.2, q[3] + 0.06, -w, w))
                s += 0.8
            self.m.add_pecas("escada_%d" % n, "degrau", self.firmar(degraus, 0.3))
            sm = (s0 + s1) / 2.0
            i = LINHA.em_s(sm)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            x, z = q[0] + tz * (q[2] - 1.2), q[1] - tx * (q[2] - 1.2)
            setor = self.setor_grade("escadaria", x, z, SETOR)
            self.m.add_pecas(setor, "pedra_clara", self.firmar([caixa_girada(x, q[3] + 0.5, z, 1.3, 1.6, 1.3,
                                                                               math.atan2(tx, tz))]))
            self.col.append(caixa_girada(x, q[3] + 0.5, z, 1.3, 2.4, 1.3, math.atan2(tx, tz)))
            self.ocupar(x, z, 1.2)
            self.enlutado(x, q[3] + 1.3, z, 3.0, math.atan2(-tz, tx), setor)
        self.area("area_3_subida", (ESCADAS[0][0] + ESCADAS[0][1]) / 2.0)

    # ------------------------------------------------------------------
    def cemiterio_encosta(self):
        """O patamar do meio da subida: tumulos no campo do lado do morro,
        um mausoleu, arvores secas, a grade de lancas e dois anjos."""
        rnd = self.rnd
        s0, s1 = S_CEMITERIO
        n = 0
        sg = 1
        s = s0
        while s < s1:
            i = LINHA.em_s(s)
            _ab, cp = self.pesos(i, sg)
            if cp < 0.5:
                s += 3.0
                continue
            w = LINHA.p[i][2]
            lat = w + 3.0
            while lat < w + 15.0:
                x, z, _ = ponto_linha(s + rnd.uniform(-0.4, 0.4), sg * (lat + rnd.uniform(-0.3, 0.3)))
                plano = self.pe(x, z, 1.3) > altura(x, z) - 0.35
                if self.livre(x, z, 1.5) and rnd.random() > 0.15 and plano:
                    self.tumulo(x, z, n)
                    n += 1
                lat += 3.5
            s += 4.6
        for k in range(5):
            s = rnd.uniform(s0, s1)
            i = LINHA.em_s(s)
            x, z, _ = ponto_linha(s, sg * (LINHA.p[i][2] + rnd.uniform(9.0, 17.0)))
            if not self.livre(x, z, 4.5) or self.pe(x, z, 4.5) < altura(x, z) - 0.8:
                continue
            tx, tz = LINHA.t[i]
            if k == 1:
                giro = math.atan2(tz * sg, -tx * sg)
                self.mausoleu(x, z, giro, self.setor_grade("mausoleus", x, z, SETOR), ruina=True)
                self.ocupar(x, z, 4.5, bloqueia=False)
                c, s_ = math.cos(giro), math.sin(giro)
                self.bloco_no_mapa([(x + c * 3.1 + s_ * 4.2, 0, z - s_ * 3.1 + c * 4.2),
                                    (x - c * 3.1 + s_ * 4.2, 0, z + s_ * 3.1 + c * 4.2),
                                    (x - c * 3.1 - s_ * 4.2, 0, z + s_ * 3.1 - c * 4.2),
                                    (x + c * 3.1 - s_ * 4.2, 0, z - s_ * 3.1 - c * 4.2)])
            else:
                self.arvore(x, z)
                self.ocupar(x, z, 1.2, bloqueia=False)
        s = s0 + 4.0
        while s < s1 - 4.0:
            i = LINHA.em_s(s)
            if self.pesos(i, sg)[1] < 0.6 or rnd.random() < 0.15:
                s += 2.6
                continue
            self.grade(s, s + 2.6, sg)
            s += 2.6
        for s_ in (s0 + 2.0, s1 - 2.0):
            x, z, i = ponto_linha(s_, sg * (LINHA.p[LINHA.em_s(s_)][2] + 1.2))
            y = self.pe(x, z, 0.8)
            tx, tz = LINHA.t[i]
            setor = self.setor_grade("anjos", x, z, SETOR)
            self.m.add_pecas(setor, "lapide", self.firmar([caixa_girada(x, y + 0.6, z, 1.2, 1.2, 1.2, math.atan2(tx, tz))]))
            self.anjo(x, y + 1.2, z, 2.8, math.atan2(tz * sg, -tx * sg), setor, partido=s_ > s0 + 3.0)
        self.pontos["n_tumulos"] = n
        self.area("area_4_cemiterio", (s0 + s1) / 2.0)

    # ------------------------------------------------------------------
    def mirante(self):
        """O topo: a capela do sino do lado de dentro, e na beira do abismo
        um enlutado enorme olhando a vista entre duas piras. A cutscene
        dispara na faixa `gatilho`, logo que se pisa no patamar."""
        s_m = S_MIRANTE
        i = LINHA.em_s(s_m)
        q = LINHA.p[i]
        tx, tz = LINHA.t[i]
        yc = q[3]
        self.capela(s_m + 2.0, q[2] - 9.0)
        # o enlutado da beira: de costas pro caminho, olhando o grande inferno
        # (na ponta norte da beira, pra nao tapar a vista de quem chega)
        x, z, _ = ponto_linha(s_m + 17.0, -(LINHA.p[LINHA.em_s(s_m + 17.0)][2] - 1.6))
        setor = self.setor_grade("mirante", x, z, SETOR)
        self.m.add_pecas(setor, "pedra_clara", self.firmar([caixa_girada(x, yc + 0.7, z, 1.8, 2.0, 1.8,
                                                                           math.atan2(tx, tz))]))
        self.enlutado(x, yc + 1.7, z, 5.2, math.atan2(VISTA_DIR[0], VISTA_DIR[1]), setor)
        self.col.append(caixa_girada(x, yc + 1.5, z, 1.8, 3.6, 1.8, math.atan2(tx, tz)))
        self.ocupar(x, z, 1.6)
        for ds in (-6.0, 13.0):
            px, pz, _ = ponto_linha(s_m + ds, -(q[2] - 1.6))
            self.pira(px, pz, yc, self.setor_grade("mirante", px, pz, SETOR))
        # arvores secas nas pontas do patamar
        for ds, lado in ((-14.0, 0.75), (20.0, 0.62)):
            ax, az, _ = ponto_linha(s_m + ds, LINHA.p[LINHA.em_s(s_m + ds)][2] * lado)
            if self.livre(ax, az, 2.0):
                self.arvore(ax, az)
                self.col.append(cilindro(ax, az, 0.45, altura(ax, az) - 1.0, altura(ax, az) + 3.0, n=6))
                self.ocupar(ax, az, 1.5)
        # a beira de onde se olha (o Maycow da cutscene para 3,5 m antes dela)
        self.pontos["beira_mirante"] = []
        for ds in (-18.0, 26.0):
            bi = LINHA.em_s(s_m + ds)
            bx, bz, _ = ponto_linha(s_m + ds, -(LINHA.p[bi][2] + 0.5))
            self.pontos["beira_mirante"].append([round(bx, 2), round(bz, 2)])
        mx, mz, _ = ponto_linha(s_m + 4.0, -(q[2] - 4.0))
        self.pontos["mirante"] = [round(mx, 2), round(yc, 2), round(mz, 2)]
        # a faixa do gatilho atravessa o patamar inteiro logo na chegada
        sg_ = S_MIRANTE - 20.0
        gi = LINHA.em_s(sg_)
        gx, gz, _ = ponto_linha(sg_)
        self.pontos["gatilho"] = [round(gx, 2), round(LINHA.p[gi][3], 2), round(gz, 2),
                                  round(math.atan2(*LINHA.t[gi]), 4), round(2.0 * LINHA.p[gi][2] + 4.0, 2)]
        self.area("area_5_mirante", s_m)

    def capela(self, s, lado):
        """A capela do sino: nave curta de pedra com contrafortes, o telhado
        meio caido, a porta pro caminho e a torre do sino na ponta norte."""
        rnd = self.rnd
        i = LINHA.em_s(s)
        tx, tz = LINHA.t[i]
        cx, cz, _ = ponto_linha(s, lado)
        yc = LINHA.p[i][3]
        # u ao longo do caminho, v pra fora (leste), y absoluto
        P = moldura(cx, 0.0, cz, tx, tz, -tz, tx)
        setor = "capela"
        base = self.pe(cx, cz, 9.0) - 0.8
        pedra = [bloco(P, -7.0, 7.0, base, yc + 7.5, -4.5, 4.5)]
        Q = moldura(*P(0.0, 0.0, 0.0), -tz, tx, tx, tz)
        # empenas nas duas pontas (frente e fundo), na moldura girada
        pedra.append(prisma_tri(Q, (-4.5, yc + 7.5), (4.5, yc + 7.5), (0.0, yc + 11.5), -7.0, -6.4))
        pedra.append(prisma_tri(Q, (-4.5, yc + 7.5), (4.5, yc + 7.5), (0.0, yc + 11.5), 6.4, 7.0))
        telha = telhado_duas_aguas(Q, -4.9, 4.9, yc + 7.3, yc + 11.7, -7.2, 1.5, esp=0.3)
        # a outra metade do telhado caiu: so' as tercas peladas
        madeira = []
        for u in (2.8, 4.6, 6.4):
            madeira.append(bloco(P, u - 0.12, u + 0.12, yc + 7.4, yc + 7.7, -4.6, 4.6))
        madeira.append(bloco(P, 1.5, 7.0, yc + 11.3, yc + 11.6, -0.15, 0.15))
        claro = []
        for u in (-5.0, -1.7, 1.7, 5.0):
            for v in (-4.5, 4.5):
                c = P(u, 0.0, v + (0.45 if v > 0 else -0.45))
                claro.extend(self.firmar([caixa_girada(c[0], (base + yc + 6.0) / 2.0, c[2], 0.9, yc + 6.0 - base, 0.9,
                                                       math.atan2(tx, tz))], 0.3))
                claro.append(espinho((c[0], yc + 5.9, c[2]), (c[0], yc + 8.2, c[2]), 0.5, n=4))
        escuro = []
        for u in (-3.3, 0.0, 3.3):
            escuro.append(bloco(P, u - 0.45, u + 0.45, yc + 2.8, yc + 6.0, -4.62, -4.48))
            escuro.append(bloco(P, u - 0.45, u + 0.45, yc + 2.8, yc + 6.0, 4.48, 4.62))
        # a porta, de frente pro caminho
        porta = [bloco(P, -1.0, 1.0, yc, yc + 3.4, -4.62, -4.48)]
        claro.append(bloco(P, -1.4, 1.4, yc, yc + 3.8, -4.75, -4.5))
        claro.append(self.firmar([bloco(P, -1.8, 1.8, yc - 0.6, yc + 0.18, -5.6, -4.5)], 0.3)[0])
        # a torre do sino na ponta norte
        t0, t1 = 7.0, 11.4
        pedra.append(bloco(P, t0, t1, base, yc + 14.0, -2.2, 2.2))
        claro.append(bloco(P, t0 - 0.2, t1 + 0.2, yc + 14.0, yc + 14.4, -2.4, 2.4))
        for uu in (t0, t1 - 0.8):
            for vv in (-2.2, 1.4):
                pedra.append(bloco(P, uu, uu + 0.8, yc + 14.4, yc + 19.0, vv, vv + 0.8))
        claro.append(bloco(P, t0 - 0.3, t1 + 0.3, yc + 19.0, yc + 19.6, -2.5, 2.5))
        topo = P((t0 + t1) / 2.0, 0.0, 0.0)
        telha.append(espinho((topo[0], yc + 19.5, topo[2]), (topo[0], yc + 30.0, topo[2]), 3.2, n=4))
        # o sino, pendurado de uma travessa apoiada em duas vigas que passam
        # pelos pilares dos cantos
        for vv in (-1.8, 1.8):
            madeira.append(bloco(P, t0, t1, yc + 18.6, yc + 18.9, vv - 0.15, vv + 0.15))
        madeira.append(bloco(P, (t0 + t1) / 2.0 - 0.15, (t0 + t1) / 2.0 + 0.15, yc + 18.3, yc + 18.6, -1.95, 1.95))
        bx, _, bz = topo
        ferro = corrente_vertical(bx, bz, yc + 18.3, yc + 17.9, larg=0.08)
        ferro.append(cilindro(bx, bz, 0.95, yc + 16.2, yc + 16.5, n=12, raio_topo=0.85))
        ferro.append(cilindro(bx, bz, 0.85, yc + 16.5, yc + 17.95, n=12, raio_topo=0.4))
        self.m.add_pecas(setor, "fachada_pedra", pedra)
        self.m.add_pecas(setor, "pedra_clara", claro)
        self.m.add_pecas(setor, "telhado", telha)
        self.m.add_pecas(setor, "madeira", madeira)
        self.m.add_pecas(setor, "escuro", escuro)
        self.m.add_pecas(setor, "porta", porta)
        self.m.add_pecas(setor, "ferro", ferro)
        self.pontos["sino"] = [round(bx, 2), round(yc + 17.0, 2), round(bz, 2)]
        self.col.append(bloco(P, -7.4, 11.6, base, yc + 12.0, -5.0, 5.0))
        self.col.append(bloco(P, -1.8, 1.8, yc - 0.6, yc + 0.18, -5.6, -4.5))
        self.bloco_no_mapa([P(-7.0, 0, -4.5), P(t1, 0, -4.5), P(t1, 0, 4.5), P(-7.0, 0, 4.5)])
        c = P(2.0, 0.0, 0.0)
        self.ocupar(c[0], c[2], 9.5)
        self.bloquear_linha(*P(-7.0, 0.0, 0.0)[::2], *P(t1, 0.0, 0.0)[::2], 5.2)
        _ = rnd

    # ------------------------------------------------------------------
    def descida(self):
        """A face norte: forcas de ferro com gaiola do lado do morro, um
        enlutado por lance (vem de `escadas`), e o resto e' a vista."""
        rnd = self.rnd
        s0 = S_MIRANTE + 40.0
        s1 = S_FOSSO[0] - 6.0
        s = s0
        k = 0
        while s < s1:
            i = LINHA.em_s(s)
            if self.encosta(i, 1) > 0.6:
                self.forca(s, 1, corpo=k % 2 == 0)
                k += 1
            s += rnd.uniform(26.0, 34.0)
        self.area("area_6_descida", (s0 + s1) / 2.0)

    def forca(self, s, sg, corpo=True):
        """Poste de ferro na faixa ao pe' do muro de arrimo, com um braco por
        cima da beira do caminho e a gaiola pendurada nele."""
        i = LINHA.em_s(s)
        q = LINHA.p[i]
        x, z, _ = ponto_linha(s, sg * (q[2] + 2.6))
        hx, hz, _ = ponto_linha(s, sg * (q[2] + 0.4))
        y = self.pe(x, z, 0.4)
        setor = self.setor_grade("forcas", x, z, SETOR)
        topo = q[3] + 6.4
        ferro = self.firmar([cilindro(x, z, 0.22, y - 0.4, y + 0.6, n=6, raio_topo=0.16)], 0.3)
        ferro.append(cilindro(x, z, 0.1, y + 0.5, topo + 0.3, n=6))
        ferro.append(tubo_redondo([(x, topo, z), (hx, topo, hz)], [0.08, 0.08], n=5))
        ferro.append(tubo_redondo([(x, topo - 1.4, z), ((x + hx) / 2.0, topo - 0.05, (z + hz) / 2.0)], [0.05, 0.05], n=4))
        self.m.add_pecas(setor, "ferro", ferro)
        self.gaiola(hx, topo - 4.4, hz, topo, setor, corpo=corpo)
        self.ocupar(x, z, 0.8, bloqueia=False)

    # ------------------------------------------------------------------
    def fosso(self):
        """O largo do fim: chao de laje, um selo vermelho apagado no meio (o
        lugar do mini chefe), colunata quebrada contra o morro, quatro piras
        e o anel do portal na ponta — sem destino por enquanto."""
        rnd = self.rnd
        s0, s1 = S_FOSSO
        sc = (s0 + s1) / 2.0
        cx, cy, cz, ic = self.ponto(sc)
        yc = LINHA.p[ic][3]
        self.pontos["mini_boss"] = [round(cx, 2), round(yc, 2), round(cz, 2), 20.0]
        # o selo: dois aneis e uma estrela, rentes ao chao
        selo = []
        for r, n in ((12.0, 90), (9.0, 70)):
            for k in range(n):
                a = 2 * math.pi * (k + 0.5) / n
                x, z = cx + r * math.cos(a), cz + r * math.sin(a)
                selo.append(caixa_girada(x, self.chao_v(x, z) + 0.02, z, 0.32, 0.12, 2 * math.pi * r / n + 0.05, -a))
        pontas = [(cx + 9.0 * math.cos(math.pi / 2 + 2 * math.pi * k / 5), cz + 9.0 * math.sin(math.pi / 2 + 2 * math.pi * k / 5))
                  for k in range(5)]
        for k in range(5):
            a, b = pontas[k], pontas[(k + 2) % 5]
            d = math.hypot(b[0] - a[0], b[1] - a[1])
            m = int(d / 0.9)
            for j in range(m):
                t = (j + 0.5) / m
                x, z = lerp(a[0], b[0], t), lerp(a[1], b[1], t)
                selo.append(caixa_girada(x, self.chao_v(x, z) + 0.02, z, 0.28, 0.12, d / m + 0.04,
                                         math.atan2(b[0] - a[0], b[1] - a[1])))
        self.m.add_pecas("fosso_selo", "sigilo", selo)
        # a colunata quebrada contra o morro (lado leste)
        s = s0 + 4.0
        k = 0
        while s < s1:
            i = LINHA.em_s(s)
            q = LINHA.p[i]
            x, z, _ = ponto_linha(s, q[2] - 1.8)
            y = self.pe(x, z, 1.2)
            setor = self.setor_grade("fosso", x, z, SETOR)
            alt = 7.5 if k % 3 != 1 else rnd.uniform(2.2, 4.0)
            self.m.add_pecas(setor, "pedra_clara",
                             self.firmar([caixa((x - 0.75, y - 0.3, z - 0.75), (x + 0.75, y + 0.6, z + 0.75))], 0.3)
                             + [cilindro(x, z, 0.55, y + 0.6, y + alt, n=10)])
            if alt > 7.0:
                self.m.add_pecas(setor, "pedra_clara", [caixa((x - 0.8, y + alt, z - 0.8), (x + 0.8, y + alt + 0.6, z + 0.8))])
            else:
                # o tambor que caiu, deitado no chao do lado
                dx, dz = rnd.uniform(-1, 1), rnd.uniform(-1, 1)
                d = math.hypot(dx, dz) or 1.0
                fx, fz = x - 2.2, z + 0.3
                self.m.add_pecas(setor, "pedra_clara", assentar(
                    [tubo_redondo([(fx - dx / d * 1.1, self.pe(fx, fz, 1.0) + 0.5, fz - dz / d * 1.1),
                                   (fx + dx / d * 1.1, self.pe(fx, fz, 1.0) + 0.5, fz + dz / d * 1.1)], [0.55, 0.55], n=10)],
                    self.chao_v, 0.12))
                self.col.append(cilindro(fx, fz, 1.0, self.pe(fx, fz, 1.0) - 0.5, self.pe(fx, fz, 1.0) + 0.9, n=8))
                self.ocupar(fx, fz, 1.4)
            self.col.append(cilindro(x, z, 0.8, y - 0.5, y + alt, n=8))
            self.ocupar(x, z, 1.3)
            s += 9.0
            k += 1
        # quatro piras nos cantos do largo
        for ss, lado in ((s0 + 4.0, -0.82), (s0 + 4.0, 0.7), (s1 - 6.0, -0.82), (s1 - 6.0, 0.7)):
            x, y, z, i = self.ponto(ss, lado)
            self.pira(x, z, LINHA.p[i][3], self.setor_grade("fosso", x, z, SETOR))
        # dois enlutados na entrada do largo
        for sg in (-1, 1):
            i = LINHA.em_s(s0 - 4.0)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            x, z, _ = ponto_linha(s0 - 4.0, sg * (q[2] - 1.0))
            setor = self.setor_grade("fosso", x, z, SETOR)
            self.m.add_pecas(setor, "pedra_clara", self.firmar([caixa_girada(x, q[3] + 0.5, z, 1.3, 1.6, 1.3,
                                                                               math.atan2(tx, tz))]))
            self.col.append(caixa_girada(x, q[3] + 0.5, z, 1.3, 2.4, 1.3, math.atan2(tx, tz)))
            self.ocupar(x, z, 1.2)
            self.enlutado(x, q[3] + 1.3, z, 3.4, math.atan2(-tx, -tz) + 0.0, setor)
        # o anel do portal: o mesmo da chegada, virado pro largo
        sa = LINHA.s[-1] - 14.0
        x, y, z, i = self.ponto(sa)
        y = LINHA.p[i][3]
        tx, tz = LINHA.t[i]
        giro = math.atan2(-tx, -tz)
        yc_anel = self.anel_portal(x, y, z, giro, "portal")
        self.pontos["portal_saida"] = [round(x, 2), round(yc_anel, 2), round(z, 2), round(tx, 3), round(tz, 3)]
        self.pontos["saida"] = [round(x, 2), round(y + 1.2, 2), round(z, 2), round(tx, 3), round(tz, 3)]
        self.area("area_7_fosso", sc)

    # ------------------------------------------------------------------
    # O GRANDE INFERNO
    # ------------------------------------------------------------------
    def longe_do_morro(self, x, z, margem):
        k, lat, _d = LINHA.perto(x, z)
        return k is None or abs(lat) > LINHA.p[k][2] + 90.0 + margem

    def janelas(self, setor, x, z, giro, meia, y0, y1, n, d, sx, sz, vitral=0.15, faces_k=(0, 1, 2, 3)):
        """Janelas acesas nas faces que olham o mirante (as outras nao se veem).
        O tamanho cresce com a distancia: a 1 km uma janela de 1 m some."""
        rnd = self.rnd
        larg = min(8.0, max(1.5, 0.005 * d))
        faces = []
        for k in faces_k:
            g = giro + k * math.pi / 2.0
            nx, nz = math.sin(g), math.cos(g)
            if nx * (sx - x) + nz * (sz - z) > 0.0:
                faces.append(g)
        if not faces or y1 - y0 < larg * 3.0:
            return
        acesas, vermelhas = [], []
        for _k in range(n):
            g = rnd.choice(faces)
            nx, nz = math.sin(g), math.cos(g)
            ux, uz = math.cos(g), -math.sin(g)
            u = rnd.uniform(-meia * 0.7, meia * 0.7)
            y = rnd.uniform(y0 + larg, y1 - larg * 2.0)
            wx, wz = x + nx * (meia + 0.15) + ux * u, z + nz * (meia + 0.15) + uz * u
            (vermelhas if rnd.random() < vitral else acesas).append(
                caixa_girada(wx, y, wz, larg, larg * 2.0, 0.5, g))
        if acesas:
            self.m.add_pecas(setor, "vista_janela", acesas)
        if vermelhas:
            self.m.add_pecas(setor, "vista_vitral", vermelhas)

    def torre_longe(self, x, z, base, topo, larg, giro, d, sx, sz, fogo=None):
        """Torre gotica de vista: fuste, um recuo com pinaculos nos cantos,
        lanterna octogonal e agulha. `topo` e' a ponta da agulha. `fogo`:
        True acende braseiros no parapeito do recuo e devolve onde; None
        sorteia (sem particula)."""
        rnd = self.rnd
        setor = self.setor_grade("vista", x, z, SETOR_VISTA)
        y_agulha = topo - larg * 1.9
        y_lant = y_agulha - larg * 0.55
        y_recuo = y_lant - larg * 0.9
        pedra = [caixa_girada(x, (base + y_recuo) / 2.0, z, larg, y_recuo - base, larg, giro),
                 caixa_girada(x, y_recuo + 0.2, z, larg * 1.12, 0.4 + larg * 0.05, larg * 1.12, giro),
                 caixa_girada(x, (y_recuo + y_lant) / 2.0, z, larg * 0.72, y_lant - y_recuo, larg * 0.72, giro),
                 cilindro(x, z, larg * 0.3, y_lant, y_agulha + 0.2, n=8, fase=giro)]
        telha = [espinho((x, y_agulha, z), (x, topo, z), larg * 0.34, n=8)]
        ca, sa = math.cos(giro), math.sin(giro)
        for cu, cv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            px = x + (cu * ca + cv * sa) * larg * 0.46
            pz = z + (-cu * sa + cv * ca) * larg * 0.46
            telha.append(espinho((px, y_recuo, pz), (px, y_recuo + larg * 1.3, pz), larg * 0.09, n=4))
        self.m.add_pecas(setor, "vista_pedra", pedra)
        self.m.add_pecas(setor, "vista_telhado", telha)
        self.janelas(setor, x, z, giro, larg / 2.0, max(base, -12.0), y_recuo - 2.0, rnd.randint(4, 12), d, sx, sz)
        if fogo is None:
            fogo = rnd.random() < 0.18
        if fogo:
            brasa = []
            for k in range(4):
                g = giro + k * math.pi / 2.0
                bx, bz = x + math.sin(g) * larg * 0.43, z + math.cos(g) * larg * 0.43
                brasa.append(caixa_girada(bx, y_recuo + 0.4 + larg * 0.05, bz, larg * 0.12, larg * 0.08, larg * 0.12, g))
            self.m.add_pecas(setor, "vista_brasa", brasa)
        return y_recuo + 0.4 + larg * 0.09

    def igreja_longe(self, x, z, base, larg, alt, giro, d, sx, sz):
        rnd = self.rnd
        setor = self.setor_grade("vista", x, z, SETOR_VISTA)
        g = self.m.grupos.get((setor, "vista_pedra"))
        v0 = len(g["v"]) if g else 0
        silhueta_gotica(self, setor, "vista_pedra", x, z, larg, alt, rnd, giro=giro)
        g = self.m.grupos[(setor, "vista_pedra")]
        g["v"][v0:] = [(vx, vy + base - (20.0 if vy < 0.01 else 0.0), vz) for vx, vy, vz in g["v"][v0:]]
        # so' nas faces de lado: a funda (frente e fundo) tem outra medida
        self.janelas(setor, x, z, giro, larg / 2.0, max(base, -12.0), base + alt - 2.0, rnd.randint(3, 8), d, sx, sz,
                     faces_k=(1, 3))

    def mesa(self, x, z, raio, topo):
        """Mesa de rocha subindo do fundo da cratera: a cidade de cima dela."""
        rnd = self.rnd
        setor = self.setor_grade("vista", x, z, SETOR_VISTA)
        pecas = [cilindro(x, z, raio * 1.25, FUNDO - 20.0, topo - (topo - FUNDO) * 0.55, n=9, fase=rnd.uniform(0, 1),
                          raio_topo=raio * 1.05),
                 cilindro(x, z, raio * 1.05, topo - (topo - FUNDO) * 0.55, topo, n=9, fase=rnd.uniform(0, 1),
                          raio_topo=raio)]
        for _k in range(3):
            a = rnd.uniform(0, 2 * math.pi)
            r = raio * rnd.uniform(0.7, 1.0)
            px, pz = x + math.cos(a) * r, z + math.sin(a) * r
            pecas.append(espinho((px, FUNDO - 14.0, pz), (px, topo - rnd.uniform(5.0, 30.0), pz), raio * 0.35, n=5))
        self.m.add_pecas(setor, "vista_rocha", pecas)

    def aqueduto(self, a, b, y, sx, sz):
        """Arcos de pedra de uma mesa a outra: pilares ate' o fundo e o
        tabuleiro em cima."""
        setor = self.setor_grade("vista", (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0, SETOR_VISTA)
        d = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(2, int(d / 42.0))
        giro = math.atan2(b[0] - a[0], b[1] - a[1])
        pedra = []
        for k in range(n + 1):
            t = k / n
            px, pz = lerp(a[0], b[0], t), lerp(a[1], b[1], t)
            pedra.append(caixa_girada(px, (FUNDO - 14.0 + y - 1.0) / 2.0, pz, 9.0, y - 1.0 - FUNDO + 14.0, 7.0, giro))
            if k < n:
                qx, qz = lerp(a[0], b[0], (k + 1) / n), lerp(a[1], b[1], (k + 1) / n)
                arco = []
                for j in range(13):
                    tt = j / 12.0
                    ax_, az_ = lerp(px, qx, tt), lerp(pz, qz, tt)
                    arco.append((ax_, y - 2.0 - 0.42 * (d / n) * (1.0 - math.sin(math.pi * tt) ** 0.6), az_))
                pedra.append(tubo_redondo(arco, [2.6] * len(arco), n=6))
        pedra.append(caixa_girada((a[0] + b[0]) / 2.0, y, (a[1] + b[1]) / 2.0, 10.0, 2.2, d + 9.0, giro))
        self.m.add_pecas(setor, "vista_pedra", pedra)
        _ = (sx, sz)

    def catedral_colossal(self, cx, cz, sx, sz):
        """A catedral do inferno 3 cinco vezes maior, de frente pro mirante,
        em cima da maior mesa. A rosacea acesa e' o alvo da cutscene."""
        K = 5.0
        dx, dz = cx - sx, cz - sz
        dd = math.hypot(dx, dz)
        dx, dz = dx / dd, dz / dd
        yb = -92.0
        self.mesa(cx + dx * 150.0, cz + dz * 150.0, 230.0, yb)
        # u = de lado, v = pra dentro (de costas pro mirante), y = altura
        P = moldura(cx, 0.0, cz, -dz, dx, dx, dz)
        setor = "vista_catedral"
        y0 = yb - 6.0
        pedra = [bloco(P, -15 * K, 15 * K, y0, yb + 34 * K, 0.0, 3.2 * K),
                 bloco(P, -14 * K, 14 * K, y0, yb + 30 * K, 3.2 * K, 72 * K),
                 prisma_tri(P, (-15 * K, yb + 34 * K), (15 * K, yb + 34 * K), (0.0, yb + 47 * K), 0.0, 3.2 * K)]
        telha = telhado_duas_aguas(P, -14.8 * K, 14.8 * K, yb + 29.6 * K, yb + 44 * K, 3 * K, 72 * K, esp=0.5 * K)
        janela, vitral = [], []
        for s in (-1, 1):
            u0, u1 = sorted((s * 15 * K, s * 25 * K))
            pedra.append(bloco(P, u0, u1, y0, yb + 62 * K, -1 * K, 9 * K))
            tc = P(s * 20 * K, 0.0, 4 * K)
            pedra.append(cilindro(tc[0], tc[2], 4.6 * K, yb + 62 * K, yb + 72 * K, n=8, fase=math.pi / 8))
            telha.append(espinho((tc[0], yb + 71.5 * K, tc[2]), (tc[0], yb + 104 * K, tc[2]), 4.4 * K, n=8))
            for cu in (u0, u1):
                for cv in (-1 * K, 9 * K):
                    pc = P(cu, 0.0, cv)
                    telha.append(espinho((pc[0], yb + 61.5 * K, pc[2]), (pc[0], yb + 72 * K, pc[2]), 0.9 * K, n=4))
            for k in range(4):
                uu = s * 20 * K
                yy = yb + 20 * K + k * 10.5 * K
                (vitral if k % 2 else janela).append(bloco(P, uu - 1.1 * K, uu + 1.1 * K, yy, yy + 6 * K,
                                                           -1.12 * K, -0.95 * K))
        # contrafortes voadores ao longo da nave
        v = 12 * K
        while v < 68 * K:
            for s in (-1, 1):
                pu = s * 22 * K
                pedra.append(bloco(P, pu - 1.2 * K, pu + 1.2 * K, y0, yb + 25 * K, v - 1.0 * K, v + 1.0 * K))
                pc = P(pu, 0.0, v)
                telha.append(espinho((pc[0], yb + 25 * K, pc[2]), (pc[0], yb + 33 * K, pc[2]), 1.1 * K, n=4))
                a_ = P(pu - s * 1.2 * K, 0.0, v)
                b_ = P(s * 14 * K, 0.0, v)
                pedra.append(hexaedro([(a_[0], yb + 21 * K, a_[2]), (b_[0], yb + 25.5 * K, b_[2]),
                                       (b_[0] + dx * 0.8 * K, yb + 25.5 * K, b_[2] + dz * 0.8 * K),
                                       (a_[0] + dx * 0.8 * K, yb + 21 * K, a_[2] + dz * 0.8 * K),
                                       (a_[0], yb + 23 * K, a_[2]), (b_[0], yb + 27.5 * K, b_[2]),
                                       (b_[0] + dx * 0.8 * K, yb + 27.5 * K, b_[2] + dz * 0.8 * K),
                                       (a_[0] + dx * 0.8 * K, yb + 23 * K, a_[2] + dz * 0.8 * K)]))
                ua, ub = sorted((s * 13.9 * K, s * 14.1 * K))
                janela.append(bloco(P, ua, ub, yb + 16 * K, yb + 24 * K, v + 3.5 * K, v + 5.0 * K))
            v += 9 * K
        # a agulha do cruzeiro
        fc = P(0.0, 0.0, 50 * K)
        telha.append(espinho((fc[0], yb + 43 * K, fc[2]), (fc[0], yb + 92 * K, fc[2]), 2.6 * K, n=8))
        # a rosacea
        rc = P(0.0, yb + 22.5 * K, -0.3 * K)
        ux, uz = -dz, dx
        anel = [(rc[0] + 6.2 * K * math.cos(2 * math.pi * k / 32) * ux, rc[1] + 6.2 * K * math.sin(2 * math.pi * k / 32),
                 rc[2] + 6.2 * K * math.cos(2 * math.pi * k / 32) * uz) for k in range(33)]
        pedra.append(tubo_redondo(anel, [0.6 * K] * 33, n=6))
        for k in range(12):
            a = 2 * math.pi * k / 12
            pedra.append(tubo_redondo([rc, (rc[0] + 5.8 * K * math.cos(a) * ux, rc[1] + 5.8 * K * math.sin(a),
                                            rc[2] + 5.8 * K * math.cos(a) * uz)], [0.22 * K, 0.18 * K], n=4))
        for k in range(24):
            a0, a1 = 2 * math.pi * k / 24, 2 * math.pi * (k + 1) / 24
            p0 = (rc[0] + 5.9 * K * math.cos(a0) * ux, rc[1] + 5.9 * K * math.sin(a0), rc[2] + 5.9 * K * math.cos(a0) * uz)
            p1 = (rc[0] + 5.9 * K * math.cos(a1) * ux, rc[1] + 5.9 * K * math.sin(a1), rc[2] + 5.9 * K * math.cos(a1) * uz)
            fd = (dx * 0.15 * K, 0.0, dz * 0.15 * K)
            vitral.append(hexaedro([rc, p0, p1, rc,
                                    tuple(c + e for c, e in zip(rc, fd)), tuple(c + e for c, e in zip(p0, fd)),
                                    tuple(c + e for c, e in zip(p1, fd)), tuple(c + e for c, e in zip(rc, fd))]))
        self.m.add_pecas(setor, "vista_pedra", pedra)
        self.m.add_pecas(setor, "vista_telhado", telha)
        self.m.add_pecas(setor, "vista_janela", janela)
        self.m.add_pecas(setor, "vista_vitral", vitral)
        self.pontos["vista_alvo"] = [round(rc[0], 1), round(rc[1], 1), round(rc[2], 1)]
        self.ocupar(cx + dx * 150.0, cz + dz * 150.0, 300.0, bloqueia=False)

    def vista(self):
        """O grande inferno em volta do morro (ver o cabecalho)."""
        rnd = self.rnd
        sx, sy, sz, _i = self.ponto(S_MIRANTE)
        vx, vz = VISTA_DIR
        a0 = math.atan2(vz, vx)
        # 0) o fundo da cratera. Ninguem o ve' (a nevoa baixa e' opaca muito
        # antes dele), mas sem chao tudo da vista nasceria no vazio
        passo = 100.0
        raio = 1900.0
        cel = []
        for i in range(int(math.floor((sx - raio) / passo)), int(math.ceil((sx + raio) / passo))):
            for j in range(int(math.floor((sz - raio) / passo)), int(math.ceil((sz + raio) / passo))):
                if math.hypot((i + 0.5) * passo - sx, (j + 0.5) * passo - sz) < raio:
                    cel.append((i, j))
        v, f = chapa_aberta(cel, passo, altura_vista)
        self.m.add("chao_vista", "vista_rocha", v, f)
        # 1) a catedral colossal, a ~800 m na direcao da vista
        self.catedral_colossal(sx + vx * 800.0, sz + vz * 800.0, sx, sz)

        def sorteia(d_min, d_max, foco=0.75, abertura=1.8):
            a = a0 + rnd.uniform(-abertura, abertura) if rnd.random() < foco else rnd.uniform(-math.pi, math.pi)
            d = d_min + (d_max - d_min) * rnd.random() ** 0.85
            return sx + math.cos(a) * d, sz + math.sin(a) * d, d

        # 2) mesas de rocha com a cidade em cima
        mesas = []
        tent = 0
        while len(mesas) < 15 and tent < 3000:
            tent += 1
            x, z, d = sorteia(260.0, 1500.0)
            raio = rnd.uniform(28.0, 75.0) * (0.8 + d / 1500.0)
            if not self.longe_do_morro(x, z, raio) or not self.livre(x, z, raio + 30.0):
                continue
            topo = rnd.uniform(-38.0, 6.0) + d * 0.012
            self.mesa(x, z, raio, topo)
            self.ocupar(x, z, raio + 10.0, bloqueia=False)
            mesas.append((x, z, raio, topo, d))
            for _k in range(rnd.randint(3, 6)):
                a = rnd.uniform(0, 2 * math.pi)
                r = raio * rnd.uniform(0.0, 0.7)
                bx, bz = x + math.cos(a) * r, z + math.sin(a) * r
                giro = math.atan2(sx - bx, sz - bz) + rnd.uniform(-0.6, 0.6)
                if rnd.random() < 0.55:
                    self.igreja_longe(bx, bz, topo, rnd.uniform(14.0, 26.0) * (0.8 + d / 2000.0),
                                      rnd.uniform(26.0, 46.0) * (0.8 + d / 2000.0), giro, d, sx, sz)
                else:
                    larg = rnd.uniform(9.0, 16.0) * (0.8 + d / 2000.0)
                    self.torre_longe(bx, bz, topo - 2.0, topo + rnd.uniform(60.0, 130.0) * (0.8 + d / 2000.0), larg,
                                     giro, d, sx, sz)
        # 3) torres soltas subindo do fundo
        feitas = 0
        tent = 0
        while feitas < 44 and tent < 4000:
            tent += 1
            x, z, d = sorteia(200.0, 1550.0)
            larg = rnd.uniform(12.0, 26.0) * (0.75 + d / 1600.0)
            if not self.longe_do_morro(x, z, larg) or not self.livre(x, z, larg * 1.6):
                continue
            topo = lerp(40.0, 200.0, (d - 200.0) / 1350.0) * rnd.uniform(0.7, 1.3)
            fogo = d < 900.0 and len(self.pontos["vista_fogos"]) < 6 and rnd.random() < 0.35
            yf = self.torre_longe(x, z, FUNDO - 14.0, topo, larg, math.atan2(sx - x, sz - z) + rnd.uniform(-0.5, 0.5),
                                  d, sx, sz, fogo=fogo or None)
            self.ocupar(x, z, larg * 1.3, bloqueia=False)
            if fogo:
                self.pontos["vista_fogos"].append([round(x, 1), round(yf, 1), round(z, 1), round(larg / 14.0, 2)])
            feitas += 1
        # 4) agulhas de rocha
        feitas = 0
        tent = 0
        while feitas < 18 and tent < 2000:
            tent += 1
            x, z, d = sorteia(220.0, 1400.0, foco=0.6)
            raio = rnd.uniform(10.0, 24.0)
            if not self.longe_do_morro(x, z, raio) or not self.livre(x, z, raio * 1.5):
                continue
            setor = self.setor_grade("vista", x, z, SETOR_VISTA)
            topo = rnd.uniform(10.0, 120.0) + d * 0.04
            pecas = [espinho((x, FUNDO - 14.0, z), (x + rnd.uniform(-8, 8), topo, z + rnd.uniform(-8, 8)), raio, n=6)]
            for _k in range(2):
                a = rnd.uniform(0, 2 * math.pi)
                px, pz = x + math.cos(a) * raio * 0.9, z + math.sin(a) * raio * 0.9
                pecas.append(espinho((px, FUNDO - 14.0, pz), (px, lerp(FUNDO, topo, rnd.uniform(0.5, 0.8)), pz),
                                     raio * 0.5, n=5))
            self.m.add_pecas(setor, "vista_rocha", pecas)
            self.ocupar(x, z, raio * 1.2, bloqueia=False)
            feitas += 1
        # 5) aquedutos ligando mesas vizinhas
        ligados = 0
        for k, a in enumerate(mesas):
            if ligados >= 4:
                break
            for b in mesas[k + 1:]:
                d = math.hypot(b[0] - a[0], b[1] - a[1])
                if 120.0 < d - a[2] - b[2] < 380.0:
                    ax, az = a[0] + (b[0] - a[0]) / d * a[2] * 0.85, a[1] + (b[1] - a[1]) / d * a[2] * 0.85
                    bx, bz = b[0] - (b[0] - a[0]) / d * b[2] * 0.85, b[1] - (b[1] - a[1]) / d * b[2] * 0.85
                    self.aqueduto((ax, az), (bx, bz), min(a[3], b[3]) - 3.0, sx, sz)
                    ligados += 1
                    break
        # 6) os gigantes de sombra, de pe' entre os predios
        feitas = 0
        tent = 0
        while feitas < 7 and tent < 2000:
            tent += 1
            x, z, d = sorteia(330.0, 700.0, foco=0.85, abertura=1.4)
            if not self.longe_do_morro(x, z, 40.0) or not self.livre(x, z, 30.0):
                continue
            alt = rnd.uniform(210.0, 320.0)
            v, f = _figura(alt, rnd, feitas % 3)
            self.soltos.append(("SOMBRA_%d" % feitas, "sombra", (v, f), (x, FUNDO - 4.0, z)))
            self.ocupar(x, z, 26.0, bloqueia=False)
            feitas += 1
        # o bando de gargulas da cratera voa em volta do centro da vista
        self.pontos["vista_bando"] = [round(sx + vx * 520.0, 1), 10.0, round(sz + vz * 520.0, 1), 560.0]
        self.pontos["n_mesas"] = len(mesas)


def main():
    global LINHA, S_INICIO, S_FIM, S_LADEIRA, S_CEMITERIO, S_MIRANTE, S_FOSSO, ESCADAS
    LINHA = inf2.Linha(CONTROLE)
    S_INICIO = 6.0
    S_FIM = LINHA.s[-1] - 6.0

    def s_em(x, z):
        return LINHA.s[LINHA.em_xz(x, z)]

    S_LADEIRA = (s_em(34.0, 146.0), s_em(30.0, 72.0))
    S_CEMITERIO = (s_em(26.0, 24.0), s_em(20.0, -16.0))
    S_MIRANTE = s_em(2.0, -122.0)
    S_FOSSO = (s_em(28.0, -280.0), LINHA.s[-1] - 40.0)
    ESCADAS = [(s_em(28.0, 66.0), s_em(26.0, 26.0)),
               (s_em(22.0, -30.0), s_em(6.0, -82.0)),
               (s_em(26.0, -176.0), s_em(26.0, -256.0))]
    _apontar_o_inferno_3()
    inf4 = Inferno4()
    inf4.montar()
    # a nevoa abre na subida final e fecha um pouco na descida (ver inferno_4.gd)
    inf4.pontos["nevoa_z"] = [round(LINHA.p[LINHA.em_s(ESCADAS[1][0])][1], 1),
                              round(LINHA.p[LINHA.em_s(S_MIRANTE - 22.0)][1], 1),
                              round(LINHA.p[LINHA.em_s(S_MIRANTE + 40.0)][1], 1),
                              round(LINHA.p[LINHA.em_s(S_FOSSO[0])][1], 1)]
    print("  linha: %d pontos, %.0f m (mirante %.0f, fosso %.0f-%.0f)" % (
        len(LINHA.p), LINHA.s[-1], S_MIRANTE, S_FOSSO[0], S_FOSSO[1]))
    inf4.exportar("inferno_4", "inferno_4", abertos=("chao_",))
    nav = inf4.pontos["navmesh"]
    print("  navmesh: %d vertices, %d poligonos" % (len(nav["v"]), len(nav["p"])))
    print("  casas=%d tumulos=%d lampioes=%d inimigos=%d mesas=%d sombras=%d" % (
        inf4.pontos["n_casas"], inf4.pontos["n_tumulos"], len(inf4.pontos["lampioes"]),
        len(inf4.pontos["inimigos"]), inf4.pontos["n_mesas"], len(inf4.soltos)))


if __name__ == "__main__":
    main()
