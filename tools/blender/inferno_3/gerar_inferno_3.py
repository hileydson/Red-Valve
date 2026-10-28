# -*- coding: utf-8 -*-
"""Modela o INFERNO 3 — A CIDADE DOS ENLUTADOS — e exporta pro Godot.

    blender --background --factory-startup \\
        --python tools/blender/inferno_3/gerar_inferno_3.py

Saidas:
    red-valve/assets/3d_model/stages/inferno_3/inferno_3.glb
    red-valve/assets/3d_model/stages/inferno_3/inferno_3_pontos.json

Depois: `tools/godot/inferno_3/gerar_cena_inferno_3.py`,
`tools/godot/inferno/make_mapa_inferno.py` e `--headless --import`.

==============================================================================
O LUGAR

O anel do fim do inferno 2 nao cospe o jogador em mais fogo: cospe numa
CIDADE. Uma cidade gotica de pedra preta, de ruas de paralelepipedo, casas
altas de empena aguda e torrinhas, sob um ceu quase preto com uma lua palida —
e uma nevoa que apaga tudo a 40 m (o terror de cidade vitoriana somado a'
nevoa de Silent Hill). Aqui quem anda e' o Maycow NORMAL, e quem mostra o
caminho e' a LANTERNA: os lampioes sao poucos e fracos, e a nevoa e' escura.

Mesma logica dos dois primeiros: uma linha de centro com largura, altura e o
tipo de cada beira por ponto; caminho linear de ~900 m do anel de chegada (sul)
a' porta da catedral (norte), passando por oito areas:

   S  1 O ADRO DO ANEL       o anel por onde se chega, na beira do abismo; a
   |                         lanterna acesa num altar (se ainda nao foi pega)
   |  2 A RUA DOS CAIXOES    rua estreita entre fachadas, caixoes encostados
   |  3 A PRACA DA FOGUEIRA  praca larga com uma fogueira de gente no meio
   |  4 A PONTE DOS LAMENTOS ponte de pedra sobre o abismo de nevoa, com
   |                         estatuas encapuzadas no parapeito
   |  5 O CEMITERIO          tumulos, mausoleus e arvores secas dos dois lados
   |  6 O BECO DAS GAIOLAS   viela com gaiolas penduradas entre as fachadas
   |  7 A ESCADARIA          a subida pra catedral, com o abismo de um lado
   N  8 O ADRO DA CATEDRAL   a praca e a catedral; a saida e' a porta dela

==============================================================================
COMO O CHAO E' FEITO

A linha de centro e' a do inferno 2 (`Linha`, com a ponta redonda e a altura
alisada). Fora do caminho, cada lado mistura tres terrenos pelos pesos do ponto:
  - CASARIO (o padrao): calcada plana — as casas sao geometria por cima dela;
  - ABISMO: despenca ate' o fundo, a 60 m, que a nevoa baixa engole;
  - CAMPO: terra ondulada (o cemiterio).
Na ponte o chao do caminho cai pro fundo; quem segura o jogador e' a colisao
na altura do tabuleiro (`altura_col`), e o navmesh anda nela (`altura_nav`).

As pecas do cemiterio (tumulo, mausoleu, arvore seca, anjo) sao as do
`gerar_cemiterio.py`; o anel de chegada e as gaiolas sao os do inferno 2.
"""

import math
import os
import sys

# o .pyc da base nao pode nascer antes de ela desligar o bytecode
sys.dont_write_bytecode = True
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "cenarios"))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "inferno"))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "inferno_2"))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "cemiterio"))

from base import (Cena, assentar, caixa, caixa_girada, chao_sob,  # noqa: E402
                  chao_visivel, chapa_aberta, chapa_grossa, cilindro, corrente_vertical,
                  entulho, espinho, estender_ate_o_chao, hexaedro, lerp, muro_invisivel,
                  navmesh_grade, pilar_composto, ruido2, silhueta_gotica, suave, tubo,
                  tubo_redondo)
from geo import arquivolta  # noqa: E402
from gerar_inferno import _figura  # noqa: E402
import gerar_inferno_2 as inf2  # noqa: E402
import gerar_cemiterio as cem  # noqa: E402

FUNDO = -60.0          # o fundo do abismo (a nevoa baixa esconde)
PASSO = 4.0            # chao visivel
PASSO_COL = 2.0        # colisao do chao
PASSO_NAV = 2.5
# o chao do caminho segue plano ate' aqui alem da beira (a balaustrada fica a
# 0,9, o muro invisivel acaba a 1,3) e so' dali o abismo despenca
BEIRA = 1.6
SETOR = 48.0           # cota de 8 omni por malha: setor menor que nos infernos

# (x, z, meia-largura, altura, abismo_a, abismo_b, campo_a, campo_b)
# lado "a" = lateral positiva = (-tz, tx): o LESTE de quem anda pro norte
CONTROLE = [
    (0.0, 478.0, 14.0, 0.0, 1.0, 0.0, 0.0, 0.0),
    (0.0, 450.0, 16.0, 0.0, 1.0, 0.0, 0.0, 0.0),     # 1 o adro do anel
    (-2.0, 418.0, 13.0, 0.3, 0.8, 0.0, 0.0, 0.0),
    (-8.0, 384.0, 7.0, 1.0, 0.0, 0.0, 0.0, 0.0),     # 2 a rua dos caixoes
    (4.0, 344.0, 7.0, 1.8, 0.0, 0.0, 0.0, 0.0),
    (-5.0, 302.0, 8.0, 2.5, 0.0, 0.0, 0.0, 0.0),
    (0.0, 262.0, 24.0, 3.0, 0.0, 0.0, 0.0, 0.0),     # 3 a praca da fogueira
    (5.0, 228.0, 26.0, 3.0, 0.0, 0.0, 0.0, 0.0),
    (4.0, 196.0, 10.0, 3.0, 0.5, 0.5, 0.0, 0.0),
    (0.0, 170.0, 6.0, 3.2, 1.0, 1.0, 0.0, 0.0),      # 4 a ponte dos lamentos
    (-8.0, 112.0, 6.0, 3.8, 1.0, 1.0, 0.0, 0.0),
    (-6.0, 56.0, 6.0, 3.2, 1.0, 1.0, 0.0, 0.0),
    (0.0, 30.0, 10.0, 3.0, 0.5, 0.5, 0.4, 0.4),
    (9.0, -6.0, 10.0, 3.6, 0.0, 0.0, 1.0, 1.0),      # 5 o cemiterio
    (-5.0, -50.0, 10.0, 4.8, 0.0, 0.0, 1.0, 1.0),
    (3.0, -92.0, 8.0, 5.4, 0.0, 0.0, 0.5, 0.5),
    (0.0, -122.0, 6.0, 6.0, 0.0, 0.0, 0.0, 0.0),     # 6 o beco das gaiolas
    (-9.0, -158.0, 6.0, 6.0, 0.0, 0.0, 0.0, 0.0),
    (-4.0, -188.0, 9.0, 6.8, 0.8, 0.0, 0.0, 0.0),
    (3.0, -228.0, 9.0, 14.5, 1.0, 0.0, 0.0, 0.0),    # 7 a escadaria
    (5.0, -262.0, 10.0, 21.5, 0.8, 0.0, 0.0, 0.0),
    (0.0, -292.0, 26.0, 22.0, 0.4, 0.4, 0.0, 0.0),   # 8 o adro da catedral
    (0.0, -330.0, 28.0, 22.0, 0.0, 0.0, 0.0, 0.0),
    (0.0, -352.0, 22.0, 22.0, 0.0, 0.0, 0.0, 0.0),
]

LINHA = None
S_INICIO = 0.0
S_FIM = 0.0
PONTE = (0.0, 0.0)       # (s0, s1) do tabuleiro sobre o abismo
ESCADA = (0.0, 0.0)      # (s0, s1) dos degraus


def ponto_linha(s, metros=0.0):
    """(x, z, indice) na distancia `s`, `metros` pro lado — INTERPOLADO entre
    os pontos da linha (o mais perto so' andaria de 2 em 2 m, e duas pecas
    vizinhas cairiam no mesmo lugar)."""
    i = LINHA.em_s(s)
    j = max(i - 1, 0)
    ds = LINHA.s[i] - LINHA.s[j]
    t = (s - LINHA.s[j]) / ds if ds > 1e-6 else 0.0
    t = min(1.0, max(0.0, t))
    a, b = LINHA.p[j], LINHA.p[i]
    ta, tb = LINHA.t[j], LINHA.t[i]
    x, z = lerp(a[0], b[0], t), lerp(a[1], b[1], t)
    tx, tz = lerp(ta[0], tb[0], t), lerp(ta[1], tb[1], t)
    n = math.hypot(tx, tz) or 1.0
    return x - tz / n * metros, z + tx / n * metros, i


def na_ponte_s(s):
    return PONTE[0] <= s <= PONTE[1]


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
        return FUNDO + 8.0 * max(0.0, ruido2(x * 0.01, z * 0.01, 5.0))
    q = LINHA.p[i]
    w, y0 = q[2], q[3]
    al = abs(lat)
    lado_a = lat > 0
    ab = q[4] if lado_a else q[5]
    cp = q[6] if lado_a else q[7]
    # paralelepipedo: quase plano (o ruido e' so' pra luz da lanterna correr)
    n = 0.08 * ruido2(x * 0.7, z * 0.7, 1.0)
    rug = 2.5 * ruido2(x * 0.15, z * 0.15, 7.0) + 1.0 * ruido2(x * 0.5, z * 0.5, 3.0)
    if al <= w:
        if na_ponte_s(LINHA.s[i]):
            return FUNDO + rug
        return y0 + n
    fora = al - w
    casario = y0 + 0.15 + n + max(0.0, fora - 30.0) * 0.25
    campo = (y0 + 0.1 + 0.6 * ruido2(x * 0.08, z * 0.08, 3.0) * min(1.0, fora / 6.0)
             + max(0.0, fora - 34.0) * 0.4)
    cai = suave(min(fora / 9.0, 1.0))
    abismo = lerp(y0 + n, FUNDO + rug, cai) + rug * 0.6 * math.sin(math.pi * cai)
    h = lerp(casario, campo, cp)
    return lerp(h, abismo, ab)


def vertice_chao(i, j):
    """Canto (i, j) da grade do chao visivel. A grade tem `PASSO` m e a beira
    do abismo nao cai em cima dela: um canto logo alem da beira ja' despencou
    metros, e o tampo reto ate' ele passava por baixo de onde o jogador pisa
    (andava-se no ar, rente a balaustrada). Os cantos de fora do caminho ate'
    um `PASSO` alem da beira vem pra linha dela, na altura do caminho: o
    penhasco comeca ali, liso, e todo triangulo que tem chao pisavel fica com
    os cantos no plano do caminho. A `altura` nao muda (o que se assenta e o
    que se sorteia pelo mapa continua igual). Onde o caminho alarga a beira
    nao e' paralela a linha: o passo pela normal erra, entao repete."""
    x, z = i * PASSO, j * PASSO
    k, lat, _d = LINHA.perto(x, z)
    if k is not None and not na_ponte_s(LINHA.s[k]):
        q = LINHA.p[k]
        sg = 1 if lat > 0 else -1
        fora = abs(lat) - q[2]
        if (q[4] if sg > 0 else q[5]) > 0.005 and 0.0 < fora <= BEIRA + PASSO:
            for _t in range(6):
                tx, tz = LINHA.t[k]
                d = BEIRA - 0.05 - fora
                if abs(d) < 0.02:
                    break
                x, z = x - tz * sg * d, z + tx * sg * d
                k2, lat2, _d2 = LINHA.perto(x, z)
                if k2 is None:
                    break
                k, fora = k2, abs(lat2) - LINHA.p[k2][2]
            # a altura do caminho logo dentro da beira, pela normal
            tx, tz = LINHA.t[k]
            d = -(fora + 0.1)
            return (x, altura(x - tz * sg * d, z + tx * sg * d), z)
    y = altura(x, z)
    # onde a largura muda depressa (o largo do fim do inferno 4) o ponto mais
    # perto da linha pode ser um trecho estreito: o canto parece longe da
    # beira e despenca, colado em chao que se pisa. Fica na altura desse chao
    # (a mais baixa em volta: na escada o vizinho de cima esta' um degrau acima).
    k, lat, _d = LINHA.perto(x, z)
    if k is None or abs(lat) <= LINHA.p[k][2]:
        return (x, y, z)
    perto = []
    for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
        px, pz = x + a * PASSO * 0.7, z + b * PASSO * 0.7
        kp, latp, _dp = LINHA.perto(px, pz)
        if kp is not None and not na_ponte_s(LINHA.s[kp]) and abs(latp) <= LINHA.p[kp][2]:
            perto.append(altura(px, pz))
    if perto and y < min(perto) - 1.0:
        y = min(perto) - 0.05
    return (x, y, z)


def altura_col(x, z):
    """A colisao: o caminho segue plano 3 m alem da beira (a grade dela tem 2 m:
    um canto que ja' despencou entortava o chao ate' dentro do caminho), e na
    ponte vira o tabuleiro (o chao de baixo e' o fundo do abismo)."""
    i, lat, _d = LINHA.perto(x, z)
    if i is None:
        return altura(x, z)
    q = LINHA.p[i]
    if abs(lat) > q[2] + 3.0:
        return altura(x, z)
    if na_ponte_s(LINHA.s[i]):
        return q[3]
    # ate' a beira o chao visivel e' o do caminho (`vertice_chao`)
    return max(altura(x, z), q[3] - (0.05 if abs(lat) <= q[2] + BEIRA else 0.4))


def altura_nav(x, z):
    i, lat, _d = LINHA.perto(x, z)
    if i is not None and na_ponte_s(LINHA.s[i]):
        return LINHA.p[i][3]
    return altura(x, z)


def no_caminho(x, z, folga=0.0):
    i, lat, _d = LINHA.perto(x, z)
    if i is None:
        return False
    if not (S_INICIO + 1.0 < LINHA.s[i] < S_FIM - 1.0):
        return False
    return abs(lat) <= LINHA.p[i][2] - folga


def caminhavel(x, z):
    return no_caminho(x, z, 1.0)


def _sem_chao(xc, zc):
    """Celula de chao que fica de fora: longe demais da linha. A nevoa fecha
    a uns 40 m — a 90 m da beira so' se veria o chao por baixo dela."""
    k, lat, d = LINHA.perto(xc, zc)
    return k is None or abs(lat) > LINHA.p[k][2] + 90.0


# --------------------------------------------------------------------------
# geometria em moldura local (u ao longo, y pra cima, v pro lado)


def moldura(ox, oy, oz, ux, uz, vx, vz):
    def P(u, y, v):
        return (ox + ux * u + vx * v, oy + y, oz + uz * u + vz * v)
    return P


def bloco(P, u0, u1, y0, y1, v0, v1):
    return hexaedro([P(u0, y0, v0), P(u1, y0, v0), P(u1, y0, v1), P(u0, y0, v1),
                     P(u0, y1, v0), P(u1, y1, v0), P(u1, y1, v1), P(u0, y1, v1)])


def prisma_tri(P, a, b, c, v0, v1):
    """Triangulo no plano (u, y) extrudado de v0 a v1 (empena, frontao)."""
    v = [P(a[0], a[1], v0), P(b[0], b[1], v0), P(c[0], c[1], v0),
         P(a[0], a[1], v1), P(b[0], b[1], v1), P(c[0], c[1], v1)]
    return v, [[0, 1, 2], [5, 4, 3], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]]


def prancha(P, a, b, larg, v0, v1):
    """Tabua no plano (u, y) de `a` a `b` (porta pregada)."""
    du, dy = b[0] - a[0], b[1] - a[1]
    d = math.hypot(du, dy) or 1.0
    nu, ny = -dy / d * larg / 2.0, du / d * larg / 2.0
    pts = [(a[0] + nu, a[1] + ny), (b[0] + nu, b[1] + ny), (b[0] - nu, b[1] - ny), (a[0] - nu, a[1] - ny)]
    return hexaedro([P(p[0], p[1], v0) for p in pts] + [P(p[0], p[1], v1) for p in pts])


def telhado_duas_aguas(P, u0, u1, y_beiral, y_cume, v0, v1, esp=0.3):
    """Duas aguas com o cume ao longo de v (a empena olha pra v0)."""
    um = (u0 + u1) / 2.0
    pecas = []
    for ua in (u0, u1):
        base = [P(ua, y_beiral, v0), P(um, y_cume, v0), P(um, y_cume, v1), P(ua, y_beiral, v1)]
        topo = [(p[0], p[1] + esp, p[2]) for p in base]
        pecas.append(hexaedro(base + topo))
    return pecas


def caixao_local(h=0.5):
    """Caixao de seis lados: pe' em z=0, cabeca em z=2, tampa em y=h."""
    contorno = [(-0.27, 0.0), (0.27, 0.0), (0.40, 1.42), (0.32, 2.0), (-0.32, 2.0), (-0.40, 1.42)]
    v = [(x, 0.0, z) for x, z in contorno] + [(x, h, z) for x, z in contorno]
    f = [list(range(5, -1, -1)), list(range(6, 12))]
    for k in range(6):
        j = (k + 1) % 6
        f.append([k, j, 6 + j, 6 + k])
    return v, f


def pose(v, incl, giro, pos):
    """Inclina no plano YZ, gira em Y e leva pra `pos`."""
    ci, si = math.cos(incl), math.sin(incl)
    ca, sa = math.cos(giro), math.sin(giro)
    out = []
    for x, y, z in v:
        y2 = y * ci - z * si
        z2 = y * si + z * ci
        out.append((pos[0] + x * ca + z2 * sa, pos[1] + y2, pos[2] - x * sa + z2 * ca))
    return out


class Inferno3(Cena):

    # pecas emprestadas (as funcoes leem `altura`/`SETOR` do modulo de origem,
    # que `main` aponta pra daqui)
    tumulo = cem.Cemiterio.tumulo
    anjo = cem.Cemiterio.anjo
    mausoleu = cem.Cemiterio.mausoleu
    arvore = cem.Cemiterio.arvore
    _cova = cem.Cemiterio._cova
    _levantar = cem.Cemiterio._levantar
    gaiola = inf2.Inferno2.gaiola
    anel_portal = inf2.Inferno2.anel_portal

    def __init__(self):
        super().__init__("inf3", 668)
        self.pontos = {
            "player": [0.0, 0.0, 0.0],
            "entrada": [0.0, 0.0, 0.0],
            "saida": [0.0, 0.0, 0.0],
            "areas": {},
            "lampioes": [],
            "fogueira": [0.0, 0.0, 0.0],
            "velas": [],
            "sigilos": [],
            "covas": [],
            "inimigos": [],
            "mapa_blocos": [],
            "navmesh": {"v": [], "p": []},
        }
        self.ocupado = []
        # as fachadas de rua: (moldura, u0, u1, lado da rua, u dos caixoes)
        self.fachadas = []

    def livre(self, x, z, r):
        for ox, oz, orr in self.ocupado:
            if (x - ox) ** 2 + (z - oz) ** 2 < (r + orr) ** 2:
                return False
        return True

    def ocupar(self, x, z, r, bloqueia=True):
        self.ocupado.append((x, z, r))
        if bloqueia:
            self.bloquear(x, z, r)

    def chao_v(self, x, z):
        """O chao que se ve' (a grade de `PASSO` m), nao a `altura` exata. Na
        beira do abismo os cantos da grade sao puxados pra linha da beira
        (`vertice_chao`) e a conta da grade regular erra: vale o mais baixo
        entre ela e a malha de chao de verdade, medida por raio."""
        h = chao_visivel(altura, PASSO, x, z)
        arv = getattr(self, "_arv_chao", None)
        if arv is not None:
            from mathutils import Vector
            hit = arv.ray_cast(Vector((x, 2000.0, z)), Vector((0.0, -1.0, 0.0)), 4000.0)[0]
            if hit is not None:
                h = min(h, hit.y)
        return h

    def medir_chao(self, malhas):
        """Guarda a malha do chao visivel (lista de (v, f)) pro `chao_v`. Fora
        do Blender (o baker do minimapa) nao ha' `mathutils` nem precisa."""
        try:
            from mathutils.bvhtree import BVHTree
        except ImportError:
            return
        vv, ff = [], []
        for v, f in malhas:
            b = len(vv)
            vv.extend(v)
            ff.extend([[k + b for k in fa] for fa in f])
        self._arv_chao = BVHTree.FromPolygons(vv, ff)

    def pe(self, x, z, r):
        return chao_sob(self.chao_v, x, z, r)

    def firmar(self, pecas, folga=0.5):
        return estender_ate_o_chao(pecas, self.chao_v, folga)

    def ponto(self, s, lado=0.0):
        """Ponto do caminho em `s`, `lado` = fracao da meia-largura (+ = leste)."""
        x, zz, i = ponto_linha(s, LINHA.p[LINHA.em_s(s)][2] * lado)
        return x, altura(x, zz), zz, i

    def ponto_m(self, s, metros):
        x, z, i = ponto_linha(s, metros)
        return x, altura(x, z), z, i

    def area(self, nome, s):
        x, y, z, i = self.ponto(s)
        if na_ponte_s(s):
            y = LINHA.p[i][3]
        self.pontos["areas"][nome] = [round(x, 2), round(y, 2), round(z, 2)]

    def pesos(self, i, sg):
        q = LINHA.p[i]
        ab = q[4] if sg > 0 else q[5]
        cp = q[6] if sg > 0 else q[7]
        return ab, cp

    def bloco_no_mapa(self, cantos):
        self.pontos["mapa_blocos"].append([[round(c[0], 1), round(c[2], 1)] for c in cantos])

    # ------------------------------------------------------------------
    def montar(self):
        self.chao()
        self.chegada()
        self.casario()
        self.balaustradas()
        self.rua_dos_caixoes()
        self.praca()
        self.ponte()
        self.cemiterio()
        self.beco()
        self.escadaria()
        self.catedral()
        self.lampioes()
        self.longe()
        self.sombras()
        self.cercadura()
        self.pontos["navmesh"] = navmesh_grade(
            self, -110.0, 110.0, -370.0, 490.0, PASSO_NAV, altura_nav, caminhavel,
            # a escadaria sobe ~25%: celula de 2,5 m em diagonal passa de 1 m
            # folga de 1 m: a capsula do Maycow normal tem 1,35 m de largura
            max_desnivel=1.3, folga=1.0, desnivel_bloco=1.6)
        self._marcadores()

    # ------------------------------------------------------------------
    def chao(self):
        """Chao visivel (so' o tampo) ate' 150 m da linha; colisao fechada so'
        no caminho e numa faixa em volta."""
        visiveis = {}
        colisao = set()
        for i in range(int(-260 / PASSO), int(260 / PASSO)):
            for j in range(int(-520 / PASSO), int(640 / PASSO)):
                xc, zc = (i + 0.5) * PASSO, (j + 0.5) * PASSO
                if _sem_chao(xc, zc):
                    continue
                k, lat, d = LINHA.perto(xc, zc)
                q = LINHA.p[k]
                w = q[2]
                ab, cp = self.pesos(k, 1 if lat > 0 else -1)
                no_cam = abs(lat) <= w + 0.5 and S_INICIO - 6 < LINHA.s[k] < S_FIM + 6
                if no_cam:
                    if cp > 0.6:
                        mat = "cascalho"
                    else:
                        mat = "paralelepipedo" if ruido2(xc * 0.2, zc * 0.2, 4.0) > -0.3 else "paralelepipedo_gasto"
                elif ab > 0.5:
                    mat = "rocha"
                elif cp > 0.5:
                    mat = "terra"
                else:
                    mat = "calcada"
                setor = self.setor_grade("chao", xc, zc, SETOR)
                visiveis.setdefault((setor, mat), []).append((i, j))
                if abs(lat) <= w + 8.0 and S_INICIO - 8 < LINHA.s[k] < S_FIM + 8:
                    for a in (0, 1):
                        for b in (0, 1):
                            colisao.add((2 * i + a, 2 * j + b))
        malhas = []
        for (setor, mat), cel in visiveis.items():
            v, f = chapa_aberta(cel, PASSO, altura, vertice_chao)
            self.m.add(setor, mat, v, f)
            malhas.append((v, f))
        self.medir_chao(malhas)
        v, f = chapa_grossa(list(colisao), PASSO_COL, altura_col, 3.0)
        self.col.append((v, f))

    # ------------------------------------------------------------------
    def chegada(self):
        """O anel por onde se chega, e o altar com a lanterna."""
        x, y, z, i = self.ponto(14.0)
        y = LINHA.p[i][3]
        yc = self.anel_portal(x, y, z, math.pi, "chegada")
        self.pontos["portal_chegada"] = [round(x, 2), round(yc, 2), round(z, 2)]
        self.pontos["entrada"] = [round(x, 2), round(y + 1.2, 2), round(z, 2)]
        px, py, pz, _ = self.ponto(40.0)
        self.pontos["player"] = [round(px, 2), round(LINHA.p[LINHA.em_s(40.0)][3] + 0.3, 2), round(pz, 2)]
        # o altar: a lanterna fica acesa em cima, com o facho pro caminho
        s_alt = 36.0
        ax, ay, az, ia = self.ponto_m(s_alt, -(LINHA.p[LINHA.em_s(s_alt)][2] - 2.2))
        tx, tz = LINHA.t[ia]
        giro = math.atan2(tx, tz)
        setor = "chegada"
        P = moldura(ax, 0.0, az, tx, tz, -tz, tx)
        base = self.pe(ax, az, 1.4) - 0.3
        self.m.add_pecas(setor, "pedra_clara", [bloco(P, -1.1, 1.1, base, ay + 0.25, -0.7, 0.7),
                                               bloco(P, -0.8, 0.8, ay + 0.25, ay + 1.0, -0.45, 0.45),
                                               bloco(P, -1.0, 1.0, ay + 1.0, ay + 1.12, -0.6, 0.6)])
        self.m.add_pecas(setor, "vela", [cilindro(*P(-0.75, 0, -0.4)[::2], 0.05, ay + 1.12, ay + 1.32, n=6),
                                         cilindro(*P(0.8, 0, 0.35)[::2], 0.05, ay + 1.12, ay + 1.26, n=6)])
        self.col.append(bloco(P, -1.1, 1.1, ay - 0.5, ay + 1.1, -0.7, 0.7))
        self.ocupar(ax, az, 1.6)
        # o facho aponta pro meio do caminho, de onde o jogador vem
        fx, fz = -tz, tx
        self.pontos["lanterna"] = [round(ax, 2), round(ay + 1.12, 2), round(az, 2), round(fx, 3), round(fz, 3)]
        self.pontos["velas"].append([round(P(-0.75, 0, -0.4)[0], 2), round(ay + 1.4, 2), round(P(-0.75, 0, -0.4)[2], 2)])
        self.area("area_1_chegada", 46.0)

    # ------------------------------------------------------------------
    def casario(self):
        """As fachadas: uma casa atras da outra onde a beira e' CASARIO, de
        frente pra rua, a 1,2 m da beira (o muro invisivel fica a 0,5 m)."""
        rnd = self.rnd
        n = 0
        for sg in (1, -1):
            s = S_INICIO + 4.0
            while s < S_FIM + 8.0:
                L = rnd.uniform(7.0, 12.0)
                sm = s + L / 2.0
                i = LINHA.em_s(sm)
                ab, cp = self.pesos(i, sg)
                if ab > 0.35 or cp > 0.35 or na_ponte_s(sm) or ESCADA[0] - 4 < sm < ESCADA[1] + 4 and sg > 0:
                    s += L * 0.5
                    continue
                if sm > S_FIM - 30.0:
                    break          # o fim e' a catedral
                self.casa(i, sg, L, n)
                n += 1
                s += L + rnd.uniform(0.0, 0.6)
        self.pontos["n_casas"] = n

    def casa(self, i, sg, L, n):
        rnd = self.rnd
        q = LINHA.p[i]
        tx, tz = LINHA.t[i]
        ox, oz = -tz * sg, tx * sg              # pra fora da rua
        d0 = q[2] + 1.2
        fx, fz = q[0] + ox * d0, q[1] + oz * d0
        yr = q[3]
        D = rnd.uniform(9.0, 14.0)
        alto = 1.0 + (0.4 if LINHA.s[i] > S_FIM - 140 else 0.0)
        H = yr + rnd.uniform(10.0, 19.0) * alto
        P = moldura(fx, 0.0, fz, tx, tz, ox, oz)
        setor = self.setor_grade("casas", fx, fz, SETOR)
        mat = rnd.choice(("fachada_pedra", "fachada_pedra", "fachada_tijolo", "fachada_reboco"))
        u0, u1 = -L / 2.0, L / 2.0
        corpo = self.firmar([bloco(P, u0, u1, yr - 0.5, H, 0.0, D)], 0.8)
        self.m.add_pecas(setor, mat, corpo)
        self.bloco_no_mapa([P(u0, 0, 0), P(u1, 0, 0), P(u1, 0, D), P(u0, 0, D)])
        claro = []
        # embasamento e cornijas por andar
        claro.extend(self.firmar([bloco(P, u0 - 0.05, u1 + 0.05, yr - 0.4, yr + 0.7, -0.18, 0.0)], 0.6))
        andar = 3.4
        y = yr + andar
        while y < H - 1.5:
            claro.append(bloco(P, u0 - 0.15, u1 + 0.15, y - 0.12, y + 0.06, -0.28, 0.0))
            y += andar
        claro.append(bloco(P, u0 - 0.35, u1 + 0.35, H - 0.25, H + 0.05, -0.45, D + 0.3))
        # janelas: a moldura de pedra e o vidro um palmo a' frente dela
        vidros, acesos = [], []
        nb = max(1, int((L - 1.0) / 2.9))
        k = 1
        while yr + andar * k + 2.4 < H - 0.6:
            ys = yr + andar * k + 0.55
            for j in range(nb):
                u = u0 + (j + 0.5) * L / nb
                claro.append(bloco(P, u - 0.6, u + 0.6, ys - 0.14, ys + 2.3, -0.1, 0.02))
                vidro = bloco(P, u - 0.42, u + 0.42, ys, ys + 1.98, -0.14, -0.04)
                (acesos if rnd.random() < 0.07 else vidros).append(vidro)
            k += 1
        # o terreo: porta no meio, pregada em algumas
        porta = [bloco(P, -0.8, 0.8, yr + 0.15, yr + 2.9, -0.12, 0.02)]
        claro.append(bloco(P, -1.05, 1.05, yr + 0.15, yr + 3.15, -0.08, 0.04))
        claro.append(prisma_tri(P, (-1.05, yr + 3.15), (1.05, yr + 3.15), (0.0, yr + 4.0), -0.08, 0.04))
        degrau = self.firmar([bloco(P, -1.25, 1.25, yr - 0.2, yr + 0.15, -0.55, 0.0)], 0.3)
        tabuas = []
        if rnd.random() < 0.35:
            for a, b in (((-0.85, yr + 0.5), (0.85, yr + 2.4)), ((-0.85, yr + 2.4), (0.85, yr + 0.5)),
                         ((-0.9, yr + 1.5), (0.9, yr + 1.4))):
                tabuas.append(prancha(P, a, b, 0.24, -0.2, -0.13))
        # telhado: empena aguda de frente pra rua (ou cume ao longo dela)
        telha = []
        if rnd.random() < 0.7:
            R = L * rnd.uniform(0.75, 1.0)
            telha.extend(telhado_duas_aguas(P, u0 - 0.45, u1 + 0.45, H - 0.1, H + R, -0.45, D + 0.3))
            claro.append(prisma_tri(P, (u0, H), (u1, H), (0.0, H + R - 0.2), 0.0, 0.5))
            claro.append(prisma_tri(P, (u0, H), (u1, H), (0.0, H + R - 0.2), D - 0.5, D))
            # pinaculo na ponta da empena
            topo = P(0.0, H + R + 0.2, -0.2)
            self.m.add_pecas(setor, "telhado", [espinho((topo[0], topo[1] - 0.6, topo[2]),
                                                       (topo[0], topo[1] + 2.4, topo[2]), 0.22, n=4)])
            # mansarda: uma janelinha no telhado
            if L > 9.0 and rnd.random() < 0.5:
                claro.append(bloco(P, -0.7, 0.7, H, H + 1.8, 0.3, 1.6))
                vidros.append(bloco(P, -0.45, 0.45, H + 0.2, H + 1.5, 0.22, 0.4))
        else:
            # cume ao longo da rua: as aguas caem pra frente e pros fundos
            R = D * 0.5
            Q = moldura(*P(0.0, 0.0, D / 2.0), ox, oz, tx, tz)
            telha.extend(telhado_duas_aguas(Q, -D / 2.0 - 0.45, D / 2.0 + 0.45, H - 0.1, H + R, u0 - 0.3, u1 + 0.3))
            claro.append(prisma_tri(Q, (-D / 2.0, H), (D / 2.0, H), (0.0, H + R - 0.2), u0, u0 + 0.5))
            claro.append(prisma_tri(Q, (-D / 2.0, H), (D / 2.0, H), (0.0, H + R - 0.2), u1 - 0.5, u1))
        # chamine
        if rnd.random() < 0.45:
            uc = rnd.uniform(u0 + 1.2, u1 - 1.2)
            claro.append(bloco(P, uc - 0.5, uc + 0.5, H - 1.0, H + L * 0.9 + 1.0, D * 0.55, D * 0.55 + 0.9))
        # torreao numa quina: sai da parede no meio da fachada, com misula
        if rnd.random() < 0.28:
            uc = u0 + 0.6 if rnd.random() < 0.5 else u1 - 0.6
            cx_, _, cz_ = P(uc, 0, 0.6)
            y0t = yr + (H - yr) * 0.45
            self.m.add_pecas(setor, mat, [cilindro(cx_, cz_, 1.35, y0t, H + 2.5, n=8)])
            self.m.add_pecas(setor, "telhado", [espinho((cx_, H + 2.4, cz_), (cx_, H + 9.0, cz_), 1.7, n=8)])
            claro.append(espinho((cx_, y0t + 0.1, cz_), (cx_, y0t - 2.4, cz_), 1.3, n=8))
            for kk in range(4):
                a = kk * math.pi / 2 + 0.4
                vidros.append(caixa_girada(cx_ + math.cos(a) * 1.3, y0t + 3.2, cz_ + math.sin(a) * 1.3, 0.55, 1.6, 0.55,
                                           -a))
        # sacada de ferro no segundo andar
        if rnd.random() < 0.18 and H - yr > 9.0:
            yb = yr + andar * 2 + 0.05
            ferro = [bloco(P, -1.5, 1.5, yb - 0.16, yb, -1.15, 0.0),
                     bloco(P, -1.5, 1.5, yb + 0.95, yb + 1.04, -1.15, -1.05)]
            for kk in range(7):
                u = -1.45 + kk * 2.9 / 6.0
                ferro.append(bloco(P, u - 0.03, u + 0.03, yb, yb + 0.96, -1.13, -1.07))
            for u in (-1.2, 1.2):
                ferro.append(prisma_tri(P, (u - 0.08, yb - 0.16), (u + 0.08, yb - 0.16), (u, yb - 0.9),
                                        -1.0, 0.0))
            self.m.add_pecas(setor, "ferro", ferro)
        self.m.add_pecas(setor, "pedra_clara", claro + degrau)
        self.m.add_pecas(setor, "janela", vidros)
        if acesos:
            self.m.add_pecas(setor, "janela_acesa", acesos)
        self.m.add_pecas(setor, "porta", porta)
        if tabuas:
            self.m.add_pecas(setor, "madeira", tabuas)
        self.m.add_pecas(setor, "telhado", telha)
        # caixoes encostados na fachada (mais na rua dos caixoes)
        s = LINHA.s[i]
        chance = 0.7 if 60.0 < s < 220.0 else 0.18
        caixoes = []
        if rnd.random() < chance:
            for _k in range(rnd.randint(1, 3)):
                caixoes.append(rnd.uniform(u0 + 1.5, u1 - 1.5))
                self.caixao_encostado(P, caixoes[-1], yr, setor, d0, (ox, oz))
        self.fachadas.append((P, u0, u1, sg, yr, s, caixoes))

    def caixao_encostado(self, P, u, yr, setor, d0, o):
        """Caixao em pe' com a cabeca apoiada na fachada."""
        rnd = self.rnd
        v, f = caixao_local(0.5)
        lean = rnd.uniform(0.16, 0.3)
        base = P(u, 0.0, -0.75)
        giro = math.atan2(o[0], o[1])
        vv = pose(v, -(math.pi / 2.0) + lean, giro, (base[0], self.pe(base[0], base[2], 0.6) + 0.3, base[2]))
        # encosta: a ponta mais pra fora toca a parede; o pe' toca o chao
        ex = max(p[0] * o[0] + p[2] * o[1] for p in vv)
        alvo = (P(0, 0, 0.04)[0] * o[0] + P(0, 0, 0.04)[2] * o[1])
        dv = alvo - ex
        vv = [(p[0] + o[0] * dv, p[1], p[2] + o[1] * dv) for p in vv]
        self.m.add_pecas(setor, "madeira", assentar([(vv, f)], self.chao_v, 0.05))
        _ = (yr, d0)

    def caixao_deitado(self, x, z, giro, setor, aberto=False):
        v, f = caixao_local(0.5)
        # assenta no chao mais baixo debaixo dele (o resto fica um dedo enterrado)
        y = self.pe(x, z, 1.1) - 0.02
        ca, sa = math.cos(giro), math.sin(giro)
        # o caixao local tem o pe' na origem: centra
        vv = pose(v, 0.0, giro, (x - sa * 1.0, y, z - ca * 1.0))
        pecas = [(vv, f)]
        if aberto:
            # a tampa caida no chao, do lado
            lx, lz = ca * 0.9, -sa * 0.9
            yt = self.pe(x + lx, z + lz, 1.1) - 0.02
            pecas.append((pose(caixao_local(0.08)[0], 0.0, giro + 0.2, (x + lx - sa * 1.0, yt, z + lz - ca * 1.0)),
                          caixao_local(0.08)[1]))
            self.m.add_pecas(setor, "escuro", [caixa_girada(x, y + 0.5, z, 0.6, 0.04, 1.6, giro)])
        self.m.add_pecas(setor, "madeira", pecas)
        # sem colisao: sao muitos, e o jogador topava neles a cada passo. O
        # navmesh continua desviando (o inimigo contorna, nao atravessa).
        self.ocupar(x, z, 1.3, bloqueia=False)
        self.bloquear_linha(x - sa * 0.8, z - ca * 0.8, x + sa * 0.8, z + ca * 0.8, 0.55)

    # ------------------------------------------------------------------
    def balaustradas(self):
        """Balaustrada de pedra onde a beira e' ABISMO (fora a ponte, que tem
        parapeito proprio): balaustre a cada 2,4 m, corrimao entre dois, um
        trecho quebrado aqui e ali. O pe' de cada um desce ate' o chao."""
        rnd = self.rnd
        for sg in (1, -1):
            s = S_INICIO + 2.0
            ultimo = None
            while s < S_FIM:
                i = LINHA.em_s(s)
                ab, _cp = self.pesos(i, sg)
                if ab < 0.55 or na_ponte_s(s) or rnd.random() < 0.08:
                    ultimo = None
                    s += 2.4
                    continue
                x, z, _ = ponto_linha(s, sg * (LINHA.p[i][2] + 0.9))
                y = LINHA.p[i][3]
                setor = self.setor_grade("balaustre", x, z, SETOR)
                self.m.add_pecas(setor, "pedra_clara", self.firmar([cilindro(x, z, 0.24, y - 0.3, y + 1.0, n=6,
                                                                              raio_topo=0.18)])
                                 + [caixa_girada(x, y + 1.06, z, 0.5, 0.14, 0.5, 0.0)])
                if ultimo is not None:
                    a, b = ultimo, (x, y + 1.06, z)
                    self.m.add_pecas(setor, "pedra_clara", [tubo([(a[0], a[1], a[2]), (b[0], b[1], b[2])], 0.3, 0.16)])
                ultimo = (x, y + 1.06, z)
                s += 2.4

    # ------------------------------------------------------------------
    def rua_dos_caixoes(self):
        """Caixoes largados na rua, carruagens abandonadas, chapas de zinco
        encostadas nas fachadas e sangue no chao."""
        rnd = self.rnd
        s0, s1 = 60.0, LINHA.s[LINHA.em_xz(-5.0, 302.0)]
        for k in range(9):
            s = rnd.uniform(s0, s1)
            # rua de 14 m: o caixao fica a mais de 3,8 m do meio, sobra a faixa
            lado = rnd.choice((-1, 1)) * rnd.uniform(0.58, 0.78)
            x, y, z, i = self.ponto(s, lado)
            if not self.livre(x, z, 2.5):
                continue
            tx, tz = LINHA.t[i]
            self.caixao_deitado(x, z, math.atan2(tx, tz) + rnd.uniform(-0.8, 0.8),
                                self.setor_grade("rua", x, z, SETOR), aberto=rnd.random() < 0.4)
        for s, lado in ((s0 + 40.0, 0.64), (s1 - 30.0, -0.64)):
            x, y, z, i = self.ponto(s, lado)
            tx, tz = LINHA.t[i]
            self.carruagem(x, z, math.atan2(tx, tz) + rnd.uniform(-0.3, 0.3), quebrada=lado < 0)
        # chapas de zinco enferrujado encostadas nas casas
        for k in range(5):
            s = rnd.uniform(s0, s1)
            sg = rnd.choice((-1, 1))
            x, y, z, i = self.ponto_m(s, sg * (LINHA.p[LINHA.em_s(s)][2] - 0.3))
            if not self.livre(x, z, 1.8):
                continue
            self.barricada(x, z, i, sg)
        # sangue
        for k in range(6):
            s = rnd.uniform(s0, s1 + 100.0)
            x, y, z, i = self.ponto(s, rnd.uniform(-0.6, 0.6))
            setor = self.setor_grade("rua", x, z, SETOR)
            self.m.add_pecas(setor, "sangue", [cilindro(x, z, rnd.uniform(0.7, 1.6), y - 0.05, y + 0.035, n=9,
                                                        fase=rnd.uniform(0, 1))])
        self.area("area_2_rua", (s0 + s1) / 2.0)

    def carruagem(self, x, z, giro, quebrada=False):
        rnd = self.rnd
        y = self.pe(x, z, 2.2)
        tx, tz = math.sin(giro), math.cos(giro)
        P = moldura(x, y, z, tx, tz, tz, -tx)
        setor = self.setor_grade("rua", x, z, SETOR)
        madeira = [bloco(P, -1.9, 1.9, 0.78, 2.7, -0.95, 0.95),
                   bloco(P, -2.1, 2.1, 2.7, 2.9, -1.1, 1.1),
                   bloco(P, -1.4, 1.4, 2.9, 3.15, -0.8, 0.8)]
        escuro = [bloco(P, -0.5, 0.5, 1.4, 2.3, -1.0, -0.9), bloco(P, -0.5, 0.5, 1.4, 2.3, 0.9, 1.0)]
        ferro = []
        rodas = ((-1.3, -1.05), (1.3, -1.05), (-1.3, 1.05), (1.3, 1.05))
        for k, (u, v) in enumerate(rodas):
            if quebrada and k == 3:
                # a roda que soltou, deitada no chao do lado
                c = P(u + 0.6, 0.0, v + 1.6)
                anel = [(c[0] + 0.72 * math.cos(2 * math.pi * a / 16), c[1] + 0.07,
                         c[2] + 0.72 * math.sin(2 * math.pi * a / 16)) for a in range(17)]
                # assenta: em rua que desce, o chao do lado e' mais baixo
                ferro.extend(assentar([tubo_redondo(anel, [0.07] * 17, n=5)], self.chao_v, 0.03))
                # o eixo daquele lado desce ate' o chao: a carruagem ajoelha
                madeira.append(bloco(P, u - 0.2, u + 0.2, -0.1, 0.85, v - 0.2, v + 0.2))
                continue
            anel = [P(u + 0.75 * math.cos(2 * math.pi * a / 16), 0.75 + 0.75 * math.sin(2 * math.pi * a / 16), v)
                    for a in range(17)]
            ferro.append(tubo_redondo(anel, [0.065] * 17, n=5))
            for a in range(6):
                ang = 2 * math.pi * a / 6
                ferro.append(tubo_redondo([P(u, 0.75, v), P(u + 0.72 * math.cos(ang), 0.75 + 0.72 * math.sin(ang), v)],
                                          [0.035, 0.035], n=4))
        for u in (-1.3, 1.3):
            ferro.append(tubo_redondo([P(u, 0.75, -1.12), P(u, 0.75, 1.12)], [0.07, 0.07], n=5))
        # varais de puxar, com a ponta no chao
        for v in (-0.6, 0.6):
            madeira.append(tubo_redondo([P(1.9, 1.0, v), P(4.6, -0.06, v)], [0.07, 0.06], n=5))
        self.m.add_pecas(setor, "madeira", madeira)
        self.m.add_pecas(setor, "escuro", escuro)
        self.m.add_pecas(setor, "ferro", ferro)
        self.col.append(caixa_girada(x, y + 1.5, z, 2.4, 3.0, 4.6, giro))
        self.ocupar(x, z, 3.0, bloqueia=False)
        self.bloquear_linha(x - tx * 2.2, z - tz * 2.2, x + tx * 2.2, z + tz * 2.2, 1.3)
        _ = rnd

    def barricada(self, x, z, i, sg):
        """Tres chapas de zinco ENCOSTADAS na fachada mais perto de (x, z),
        o pe' no chao e a ponta de cima apoiada na parede. Antes eram uma
        cerca de pe' no meio da calcada, a 1,5 m da casa, sem apoio nenhum —
        nao se entendia o que eram. Ficam fora do muro invisivel: sem colisao."""
        rnd = self.rnd
        # o sorteio vem antes de tudo e e' sempre o mesmo: o resto do mapa nao muda
        sorteio = [(rnd.uniform(-0.2, 0.2), rnd.uniform(0, 0.2), rnd.uniform(0, 0.4)) for _k in range(3)]
        melhor, md = None, 1e18
        for fach in self.fachadas:
            P, u0, u1, lado = fach[:4]
            if lado != sg:
                continue
            c = P(0.0, 0.0, 0.0)
            d = (c[0] - x) ** 2 + (c[2] - z) ** 2
            if d < md:
                melhor, md = fach, d
        if melhor is None:
            return
        P, u0, u1, _lado, yr, _s, caixoes = melhor
        o, eu = P(0.0, 0.0, 0.0), P(1.0, 0.0, 0.0)
        u_alvo = (x - o[0]) * (eu[0] - o[0]) + (z - o[2]) * (eu[2] - o[2])
        if md > ((u1 - u0) / 2.0 + 3.0) ** 2:
            return
        # longe dos caixoes que ja' estao encostados nessa fachada
        candidatos = [min(max(u_alvo, u0 + 2.1), u1 - 2.1), u0 + 2.1, u1 - 2.1]
        uc = None
        for u in candidatos:
            if u0 + 2.0 <= u <= u1 - 2.0 and all(abs(u - c) > 2.6 for c in caixoes):
                uc = u
                break
        if uc is None:
            return
        setor = self.setor_grade("rua", *P(uc, 0.0, -0.5)[::2], SETOR)
        chapa = []
        esp = 0.05
        for k, (jit, dy0, dy1) in enumerate(sorteio):
            u = uc - 1.2 + k * 1.2 + jit
            ua, ub = u - 0.75, u + 0.75
            vb, vt = -0.72 - 0.06 * k, -0.2 - 0.06 * k
            pb = P(u, 0.0, vb)
            yb = self.pe(pb[0], pb[2], 0.8) - 0.04 + dy0 * 0.2
            yt = yr + 1.9 + dy1
            chapa.append(hexaedro([P(ua, yb, vb - esp), P(ub, yb, vb - esp), P(ub, yb, vb), P(ua, yb, vb),
                                   P(ua, yt, vt - esp), P(ub, yt, vt - esp), P(ub, yt, vt), P(ua, yt, vt)]))
        self.m.add_pecas(setor, "chapa", chapa)
        c = P(uc, 0.0, -0.45)
        self.ocupar(c[0], c[2], 2.0, bloqueia=False)
        _ = i

    # ------------------------------------------------------------------
    def praca(self):
        """A praca da fogueira: uma estaca com um corpo amarrado no meio de
        uma pilha de lenha, caixoes em volta, lampioes."""
        rnd = self.rnd
        sp = LINHA.s[LINHA.em_xz(2.0, 246.0)]
        x, y, z, i = self.ponto(sp)
        setor = "fogueira"
        tx, tz = LINHA.t[i]
        giro = math.atan2(tx, tz)
        P = moldura(x, 0.0, z, tx, tz, -tz, tx)
        base = self.pe(x, z, 4.0)
        pedras = []
        for k in range(14):
            a = 2 * math.pi * k / 14
            pedras.append(caixa_girada(x + 3.6 * math.cos(a), base + 0.2, z + 3.6 * math.sin(a), 0.9, 0.6, 0.7,
                                       a + rnd.uniform(-0.3, 0.3), rnd.uniform(-0.2, 0.2), rnd, 0.3))
        self.m.add_pecas(setor, "pedra_clara", assentar(pedras, self.chao_v, 0.12))
        lenha = []
        for k in range(26):
            a = 2 * math.pi * k / 26 + rnd.uniform(-0.1, 0.1)
            r0 = rnd.uniform(2.4, 3.2)
            p0 = (x + r0 * math.cos(a), base - 0.1, z + r0 * math.sin(a))
            p1 = (x + 0.35 * math.cos(a), base + rnd.uniform(1.8, 2.8), z + 0.35 * math.sin(a))
            lenha.append(tubo_redondo([p0, p1], [0.17, 0.13], n=5))
        estaca = [bloco(P, -0.28, 0.28, base - 1.0, base + 8.5, -0.28, 0.28),
                  bloco(P, -2.1, 2.1, base + 6.4, base + 6.85, -0.22, 0.22)]
        self.m.add_pecas(setor, "carvao", lenha)
        self.m.add_pecas(setor, "madeira_queimada", estaca)
        # o corpo amarrado, de bracos abertos na trave
        corpo = [tubo_redondo([P(0, base + 3.4, -0.45), P(0, base + 4.6, -0.5), P(0, base + 6.0, -0.48)],
                              [0.26, 0.24, 0.27], n=7),
                 tubo_redondo([P(0, base + 6.0, -0.5), P(0, base + 6.55, -0.62), P(0.05, base + 7.0, -0.55)],
                              [0.1, 0.19, 0.12], n=6)]
        for s in (-1, 1):
            corpo.append(tubo_redondo([P(s * 0.25, base + 5.9, -0.48), P(s * 1.0, base + 6.55, -0.38),
                                       P(s * 1.85, base + 6.75, -0.3)], [0.1, 0.09, 0.07], n=5))
            corpo.append(tubo_redondo([P(s * 0.15, base + 3.5, -0.45), P(s * 0.22, base + 2.4, -0.5),
                                       P(s * 0.2, base + 1.4, -0.42)], [0.12, 0.1, 0.08], n=5))
        self.m.add_pecas(setor, "carne_seca", corpo)
        # cordas
        corda = [bloco(P, -0.33, 0.33, base + 4.4, base + 4.55, -0.72, 0.33),
                 bloco(P, -0.33, 0.33, base + 3.3, base + 3.45, -0.7, 0.33)]
        self.m.add_pecas(setor, "corda", corda)
        self.col.append(cilindro(x, z, 3.4, base - 0.5, base + 3.0, n=10))
        self.ocupar(x, z, 4.6)
        self.pontos["fogueira"] = [round(x, 2), round(base + 0.6, 2), round(z, 2)]
        self.bloco_no_mapa([(x + 3.6 * math.cos(a), 0, z + 3.6 * math.sin(a)) for a in (0.0, 1.57, 3.14, 4.71)])
        # caixoes em roda, uns abertos
        feitos = 0
        for k in range(30):
            a = rnd.uniform(0, 2 * math.pi)
            r = rnd.uniform(7.0, 16.0)
            cx_, cz_ = x + r * math.cos(a), z + r * math.sin(a)
            if not no_caminho(cx_, cz_, 2.0) or not self.livre(cx_, cz_, 1.6):
                continue
            self.caixao_deitado(cx_, cz_, a + math.pi / 2 + rnd.uniform(-0.3, 0.3), self.setor_grade("praca", cx_, cz_, SETOR),
                                aberto=rnd.random() < 0.5)
            feitos += 1
            if feitos >= 9:
                break
        # um poco (cisterna) de pedra num canto
        wx, wy, wz, _ = self.ponto(sp + 18.0, 0.55)
        if self.livre(wx, wz, 2.5):
            b = self.pe(wx, wz, 1.6)
            self.m.add_pecas(self.setor_grade("praca", wx, wz, SETOR), "pedra_clara",
                             [cilindro(wx, wz, 1.5, b - 0.4, wy + 0.9, n=12), cilindro(wx, wz, 1.6, wy + 0.9, wy + 1.05, n=12)])
            self.m.add_pecas(self.setor_grade("praca", wx, wz, SETOR), "escuro", [cilindro(wx, wz, 1.15, wy + 0.9, wy + 1.07, n=12)])
            for s in (-1, 1):
                self.m.add_pecas(self.setor_grade("praca", wx, wz, SETOR), "ferro",
                                 [caixa(((wx + s * 1.3) - 0.07, wy + 0.9, wz - 0.07), ((wx + s * 1.3) + 0.07, wy + 3.0, wz + 0.07))])
            self.m.add_pecas(self.setor_grade("praca", wx, wz, SETOR), "ferro",
                             [tubo_redondo([(wx - 1.38, wy + 3.0, wz), (wx + 1.38, wy + 3.0, wz)], [0.07, 0.07], n=5)])
            self.col.append(cilindro(wx, wz, 1.6, wy - 0.5, wy + 1.1, n=10))
            self.ocupar(wx, wz, 2.0)
        self.area("area_3_praca", sp)
        _ = giro

    # ------------------------------------------------------------------
    def ponte(self):
        """A ponte dos lamentos: tabuleiro de pedra, parapeito cheio, pilares
        e arcos descendo pro abismo, e estatuas encapuzadas no parapeito."""
        rnd = self.rnd
        s0, s1 = PONTE[0] - 7.0, PONTE[1] + 7.0
        n = max(8, int((s1 - s0) / 2.5))
        W = 7.5        # meia-largura do tabuleiro (a colisao vai ate' w + 1,2)
        pecas, parapeito = [], []
        for k in range(n):
            sa_, sb_ = lerp(s0, s1, k / n), lerp(s0, s1, (k + 1) / n)
            ia, ib = LINHA.em_s(sa_), LINHA.em_s(sb_)
            qa, qb = LINHA.p[ia], LINHA.p[ib]
            ta, tb = LINHA.t[ia], LINHA.t[ib]
            ya, yb = qa[3], qb[3]

            def L(q, t_, off, y):
                return (q[0] - t_[1] * off, y, q[1] + t_[0] * off)

            pecas.append(hexaedro([L(qa, ta, -W, ya - 1.6), L(qa, ta, W, ya - 1.6), L(qb, tb, W, yb - 1.6),
                                   L(qb, tb, -W, yb - 1.6), L(qa, ta, -W, ya), L(qa, ta, W, ya), L(qb, tb, W, yb),
                                   L(qb, tb, -W, yb)]))
            for sg in (-1, 1):
                o0, o1 = sg * W, sg * (W + 0.75)
                parapeito.append(hexaedro([L(qa, ta, o0, ya - 1.6), L(qa, ta, o1, ya - 1.6), L(qb, tb, o1, yb - 1.6),
                                           L(qb, tb, o0, yb - 1.6), L(qa, ta, o0, ya + 1.05), L(qa, ta, o1, ya + 1.05),
                                           L(qb, tb, o1, yb + 1.05), L(qb, tb, o0, yb + 1.05)]))
                parapeito.append(hexaedro([L(qa, ta, o0 - sg * 0.1, ya + 1.05), L(qa, ta, o1 + sg * 0.1, ya + 1.05),
                                           L(qb, tb, o1 + sg * 0.1, yb + 1.05), L(qb, tb, o0 - sg * 0.1, yb + 1.05),
                                           L(qa, ta, o0 - sg * 0.1, ya + 1.25), L(qa, ta, o1 + sg * 0.1, ya + 1.25),
                                           L(qb, tb, o1 + sg * 0.1, yb + 1.25), L(qb, tb, o0 - sg * 0.1, yb + 1.25)]))
        self.m.add_pecas("ponte", "pedra_ponte", pecas)
        self.m.add_pecas("ponte", "pedra_clara", parapeito)
        # pilares a cada ~26 m e os arcos entre eles
        pil = []
        s = PONTE[0] + 4.0
        while s < PONTE[1] - 2.0:
            pil.append(s)
            s += 26.0
        pil.append(PONTE[1] - 2.0)
        for a_, b_ in zip(pil, pil[1:] + [None]):
            i = LINHA.em_s(a_)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            giro = math.atan2(tx, tz)
            fundo = self.pe(q[0], q[1], 6.0) - 2.0
            self.m.add_pecas("ponte_pilares", "pedra_ponte",
                             [caixa_girada(q[0], (fundo + q[3] - 1.6) / 2.0, q[1], 2 * W + 1.6, q[3] - 1.6 - fundo, 4.0, giro)])
            # contraforte em ponta de cada lado do pilar
            for sg in (-1, 1):
                cx_, cz_ = q[0] - tz * sg * (W + 1.4), q[1] + tx * sg * (W + 1.4)
                self.m.add_pecas("ponte_pilares", "pedra_ponte",
                                 [caixa_girada(cx_, (fundo + q[3] - 3.0) / 2.0, cz_, 1.6, q[3] - 3.0 - fundo, 3.0, giro)])
                self.m.add_pecas("ponte_pilares", "pedra_ponte",
                                 [espinho((cx_, q[3] - 3.1, cz_), (cx_, q[3] + 2.6, cz_), 0.9, n=4)])
            if b_ is None or b_ - a_ < 10.0:
                continue
            ib = LINHA.em_s(b_)
            qb = LINHA.p[ib]
            arco = []
            for k in range(15):
                t = k / 14.0
                sx = lerp(a_ + 2.0, b_ - 2.0, t)
                x_, z_, ii = ponto_linha(sx)
                yy = LINHA.p[ii][3] - 1.6 - 11.0 * (1.0 - math.sin(math.pi * t) ** 0.55)
                arco.append((x_, yy, z_))
            self.m.add_pecas("ponte_pilares", "pedra_ponte", [tubo(arco, 2 * W, 1.6)])
            # o enchimento entre o arco e o tabuleiro (os triangulos de cada lado)
            for k in range(14):
                t = (k + 0.5) / 14.0
                sx = lerp(a_ + 2.0, b_ - 2.0, t)
                x_, z_, ii = ponto_linha(sx)
                yy = LINHA.p[ii][3] - 1.6 - 11.0 * (1.0 - math.sin(math.pi * t) ** 0.55)
                tx2, tz2 = LINHA.t[ii]
                if LINHA.p[ii][3] - 1.6 - yy > 0.4:
                    self.m.add_pecas("ponte_pilares", "pedra_ponte",
                                     [caixa_girada(x_, (yy + LINHA.p[ii][3] - 1.4) / 2.0, z_, 2 * W, LINHA.p[ii][3] - 1.4 - yy,
                                                   (b_ - a_ - 4.0) / 14.0 + 0.3, math.atan2(tx2, tz2))])
        # estatuas encapuzadas em pedestais no parapeito, olhando pra rua
        s = PONTE[0] + 10.0
        k = 0
        while s < PONTE[1] - 6.0:
            i = LINHA.em_s(s)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            for sg in (-1, 1):
                if (k + (sg > 0)) % 2:
                    continue
                cx_, cz_ = q[0] - tz * sg * (W + 0.38), q[1] + tx * sg * (W + 0.38)
                self.m.add_pecas("ponte_estatuas", "pedra_clara", [caixa_girada(cx_, q[3] + 1.6, cz_, 1.0, 0.9, 1.0,
                                                                              math.atan2(tx, tz))])
                self.enlutado(cx_, q[3] + 2.05, cz_, 2.6, math.atan2(tz * sg, -tx * sg), "ponte_estatuas")
            s += 14.0
            k += 1
        self.area("area_4_ponte", (PONTE[0] + PONTE[1]) / 2.0)

    def enlutado(self, x, y, z, h, giro, setor):
        """Estatua de um enlutado: tunica ate' o chao, capuz em ponta, rosto
        vazio e as maos juntas no peito. `giro`: o +Z local e' a frente."""
        ca, sa = math.cos(giro), math.sin(giro)

        def P(lx, ly, lz):
            return (x + lx * ca + lz * sa, y + ly, z - lx * sa + lz * ca)

        pecas = [cilindro(x, z, h * 0.17, y, y + h * 0.62, n=9, raio_topo=h * 0.1),
                 cilindro(x, z, h * 0.105, y + h * 0.6, y + h * 0.78, n=9, raio_topo=h * 0.085)]
        cab = P(0, h * 0.8, h * 0.035)
        pecas.append(espinho((cab[0], y + h * 0.72, cab[2]), P(0, h * 1.02, -h * 0.07), h * 0.09, n=7))
        for s in (-1, 1):
            pecas.append(tubo_redondo([P(s * h * 0.09, h * 0.74, 0.0), P(s * h * 0.07, h * 0.6, h * 0.08),
                                       P(s * h * 0.01, h * 0.62, h * 0.1)], [h * 0.04, h * 0.036, h * 0.03], n=5))
        self.m.add_pecas(setor, "pedra_clara", pecas)
        rosto = P(0, h * 0.84, h * 0.085)
        self.m.add_pecas(setor, "escuro", [caixa_girada(rosto[0], rosto[1], rosto[2], h * 0.08, h * 0.1, h * 0.04, giro)])

    # ------------------------------------------------------------------
    def cemiterio(self):
        """Tumulos em fileiras dos dois lados (as pecas do cemiterio da cidade),
        mausoleus, arvores secas, anjos, e a grade de lancas na beira."""
        rnd = self.rnd
        s0 = LINHA.s[LINHA.em_xz(0.0, 30.0)]
        s1 = LINHA.s[LINHA.em_xz(3.0, -92.0)]
        n = 0
        for sg in (1, -1):
            s = s0
            while s < s1:
                i = LINHA.em_s(s)
                _ab, cp = self.pesos(i, sg)
                if cp < 0.5:
                    s += 3.0
                    continue
                w = LINHA.p[i][2]
                lat = w + 3.0
                while lat < w + 16.0:
                    x, z, _ = ponto_linha(s + rnd.uniform(-0.4, 0.4), sg * (lat + rnd.uniform(-0.3, 0.3)))
                    plano = self.pe(x, z, 1.3) > altura(x, z) - 0.35 and self.pesos(i, sg)[0] < 0.15
                    if self.livre(x, z, 1.5) and rnd.random() > 0.12 and plano:
                        self.tumulo(x, z, n)
                        n += 1
                    lat += 3.5
                s += 4.6
        # mausoleus e arvores mais pra dentro do campo
        for k in range(10):
            s = rnd.uniform(s0, s1)
            sg = rnd.choice((-1, 1))
            i = LINHA.em_s(s)
            ab, cp = self.pesos(i, sg)
            if cp < 0.6 or ab > 0.1:
                continue          # na cabeceira da ponte o chao ainda cai pro abismo
            x, z, _ = ponto_linha(s, sg * (LINHA.p[i][2] + rnd.uniform(9.0, 18.0)))
            if not self.livre(x, z, 5.0) or self.pe(x, z, 5.0) < altura(x, z) - 0.8:
                continue          # mausoleu e arvore so' em chao plano
            tx, tz = LINHA.t[i]
            if k % 2:
                self.mausoleu(x, z, math.atan2(tz * sg, -tx * sg), self.setor_grade("mausoleus", x, z, SETOR), ruina=k % 4 == 1)
                self.ocupar(x, z, 4.5, bloqueia=False)
                c, s_ = math.cos(math.atan2(tz * sg, -tx * sg)), math.sin(math.atan2(tz * sg, -tx * sg))
                self.bloco_no_mapa([(x + c * 3.1 + s_ * 4.2, 0, z - s_ * 3.1 + c * 4.2),
                                    (x - c * 3.1 + s_ * 4.2, 0, z + s_ * 3.1 + c * 4.2),
                                    (x - c * 3.1 - s_ * 4.2, 0, z + s_ * 3.1 - c * 4.2),
                                    (x + c * 3.1 - s_ * 4.2, 0, z - s_ * 3.1 - c * 4.2)])
            else:
                self.arvore(x, z)
                self.ocupar(x, z, 1.2, bloqueia=False)
        # arvores secas na beira do caminho, que a lanterna pega de raspao
        for k in range(8):
            s = rnd.uniform(s0, s1)
            sg = rnd.choice((-1, 1))
            i = LINHA.em_s(s)
            x, z, _ = ponto_linha(s, sg * (LINHA.p[i][2] + 1.6))
            if self.livre(x, z, 2.0) and self.pesos(i, sg)[0] < 0.1:
                self.arvore(x, z)
                self.ocupar(x, z, 1.2, bloqueia=False)
        # grade de lancas na beira do caminho, com portoes abertos
        for sg in (1, -1):
            s = s0 + 4.0
            while s < s1 - 4.0:
                i = LINHA.em_s(s)
                if self.pesos(i, sg)[1] < 0.6 or rnd.random() < 0.15:
                    s += 2.6
                    continue
                self.grade(s, s + 2.6, sg)
                s += 2.6
        # anjos de vigia na entrada do cemiterio
        for sg in (1, -1):
            x, z, i = ponto_linha(s0 + 6.0, sg * (LINHA.p[LINHA.em_s(s0 + 6.0)][2] + 1.2))
            y = self.pe(x, z, 0.8)
            tx, tz = LINHA.t[i]
            setor = self.setor_grade("anjos", x, z, SETOR)
            self.m.add_pecas(setor, "lapide", self.firmar([caixa_girada(x, y + 0.6, z, 1.2, 1.2, 1.2, math.atan2(tx, tz))]))
            self.anjo(x, y + 1.2, z, 2.8, math.atan2(tz * sg, -tx * sg), setor, partido=sg > 0)
        self.pontos["n_tumulos"] = n
        self.area("area_5_cemiterio", (s0 + s1) / 2.0)

    def grade(self, sa, sb, sg):
        """Um vao de grade de ferro de lancas entre dois pilaretes de pedra."""
        ia, ib = LINHA.em_s(sa), LINHA.em_s(sb)
        xa, za, _ = ponto_linha(sa, sg * (LINHA.p[ia][2] + 0.9))
        xb, zb, _ = ponto_linha(sb, sg * (LINHA.p[ib][2] + 0.9))
        ya, yb = self.pe(xa, za, 0.4), self.pe(xb, zb, 0.4)
        y = min(ya, yb)
        setor = self.setor_grade("grade", xa, za, SETOR)
        self.m.add_pecas(setor, "lapide", self.firmar([caixa((xa - 0.25, y - 0.2, za - 0.25), (xa + 0.25, y + 2.1, za + 0.25))]))
        ferro = [tubo_redondo([(xa, y + 0.35, za), (xb, y + 0.35, zb)], [0.04, 0.04], n=4),
                 tubo_redondo([(xa, y + 1.75, za), (xb, y + 1.75, zb)], [0.04, 0.04], n=4)]
        for k in range(1, 6):
            t = k / 6.0
            bx, bz = lerp(xa, xb, t), lerp(za, zb, t)
            yb_ = self.pe(bx, bz, 0.05)
            ferro.append(tubo_redondo([(bx, yb_ - 0.15, bz), (bx, y + 2.0, bz)], [0.025, 0.025], n=4))
            ferro.append(espinho((bx, y + 1.98, bz), (bx, y + 2.25, bz), 0.06, n=4))
        self.m.add_pecas(setor, "ferro", ferro)

    # ------------------------------------------------------------------
    def beco(self):
        """O beco das gaiolas: correntes de fachada a fachada com gaiolas
        penduradas por cima da cabeca."""
        rnd = self.rnd
        s0 = LINHA.s[LINHA.em_xz(0.0, -122.0)]
        s1 = LINHA.s[LINHA.em_xz(-9.0, -158.0)]
        s = s0 - 6.0
        while s < s1 + 8.0:
            i = LINHA.em_s(s)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            lx, lz = -tz, tx
            d = q[2] + 1.15        # a face da fachada (as casas ficam a 1,2 m)
            a = (q[0] + lx * d, q[1] + lz * d)
            b = (q[0] - lx * d, q[1] - lz * d)
            topo = q[3] + rnd.uniform(8.0, 9.5)
            setor = "beco"
            pts = []
            for k in range(11):
                t = k / 10.0
                pts.append((lerp(a[0], b[0], t), topo - 1.6 * math.sin(t * math.pi), lerp(a[1], b[1], t)))
            # a ponta entra na parede: uma argola chumbada de cada lado
            self.m.add_pecas(setor, "ferro", [tubo_redondo(pts, [0.12] * len(pts), n=5),
                                              caixa((a[0] - 0.25, topo - 0.25, a[1] - 0.25), (a[0] + 0.25, topo + 0.25, a[1] + 0.25)),
                                              caixa((b[0] - 0.25, topo - 0.25, b[1] - 0.25), (b[0] + 0.25, topo + 0.25, b[1] + 0.25))])
            t = rnd.uniform(0.35, 0.65)
            gx, gz = lerp(a[0], b[0], t), lerp(a[1], b[1], t)
            gtopo = topo - 1.6 * math.sin(t * math.pi)
            self.gaiola(gx, gtopo - rnd.uniform(3.0, 4.2), gz, gtopo, setor, corpo=rnd.random() < 0.6)
            s += rnd.uniform(7.0, 10.0)
        self.area("area_6_beco", (s0 + s1) / 2.0)

    # ------------------------------------------------------------------
    def escadaria(self):
        """Degraus de pedra subindo pra catedral (a colisao e' a rampa por
        baixo deles), estatuas nos patamares do lado do abismo."""
        rnd = self.rnd
        s0, s1 = ESCADA
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
        # o pe' de cada degrau desce ate' o chao (na beira o abismo ja' comeca)
        self.m.add_pecas("escadaria", "degrau", self.firmar(degraus, 0.3))
        for k, s in enumerate((s0 + 12.0, s0 + 34.0, s0 + 56.0)):
            if s > s1:
                break
            i = LINHA.em_s(s)
            q = LINHA.p[i]
            tx, tz = LINHA.t[i]
            x, z = q[0] - tz * (q[2] + 1.6), q[1] + tx * (q[2] + 1.6)
            y = q[3]
            setor = self.setor_grade("escadaria", x, z, SETOR)
            self.m.add_pecas(setor, "pedra_clara", self.firmar([caixa_girada(x, y + 0.5, z, 1.3, 1.6, 1.3, math.atan2(tx, tz))]))
            self.enlutado(x, y + 1.3, z, 3.0, math.atan2(tz, -tx), setor)
        self.area("area_7_escadaria", (s0 + s1) / 2.0)
        _ = rnd

    # ------------------------------------------------------------------
    def catedral(self):
        """A catedral no fim: fachada com tres portais, rosacea acesa, duas
        torres com agulha e a nave atras. A porta do meio e' a saida."""
        rnd = self.rnd
        i = len(LINHA.p) - 1
        q = LINHA.p[i]
        tx, tz = LINHA.t[i]
        yc = q[3]
        fx, fz = q[0] + tx * 4.0, q[1] + tz * 4.0
        # u = de lado (leste-oeste), v = pra dentro da catedral, y = altura
        P = moldura(fx, 0.0, fz, -tz, tx, tx, tz)
        setor = "catedral"
        base = self.pe(fx, fz, 18.0) - 2.0
        pedra = []
        # a fachada e a nave
        pedra.append(bloco(P, -15.0, 15.0, base, yc + 34.0, 0.0, 3.2))
        pedra.append(bloco(P, -14.0, 14.0, base, yc + 30.0, 3.2, 72.0))
        pedra.append(prisma_tri(P, (-15.0, yc + 34.0), (15.0, yc + 34.0), (0.0, yc + 47.0), 0.0, 3.2))
        telha = telhado_duas_aguas(P, -14.8, 14.8, yc + 29.6, yc + 44.0, 3.0, 72.0, esp=0.5)
        # torres
        for s in (-1, 1):
            u0, u1 = sorted((s * 15.0, s * 25.0))
            pedra.append(bloco(P, u0, u1, base, yc + 62.0, -1.0, 9.0))
            cx_, _, cz_ = P(s * 20.0, 0.0, 4.0)
            pedra.append(cilindro(cx_, cz_, 4.6, yc + 62.0, yc + 72.0, n=8, fase=math.pi / 8))
            telha.append(espinho((cx_, yc + 71.5, cz_), (cx_, yc + 104.0, cz_), 4.4, n=8))
            for cu in (u0, u1):
                for cv in (-1.0, 9.0):
                    pc = P(cu, 0.0, cv)
                    pedra.append(espinho((pc[0], yc + 61.5, pc[2]), (pc[0], yc + 70.0, pc[2]), 0.9, n=4))
            # janelas lancetas escuras nas torres
            for k in range(3):
                uu = s * 20.0
                yy = yc + 22.0 + k * 13.0
                self.m.add_pecas(setor, "escuro", [bloco(P, uu - 1.0, uu + 1.0, yy, yy + 7.0, -1.12, -0.95)])
        # contrafortes da fachada
        for u in (-15.0, -8.5, 8.5, 15.0):
            pedra.extend(self.firmar([bloco(P, u - 0.9, u + 0.9, base, yc + 26.0, -2.6, 0.2)], 0.5))
            pc = P(u, 0.0, -1.2)
            pedra.append(espinho((pc[0], yc + 25.8, pc[2]), (pc[0], yc + 32.0, pc[2]), 0.85, n=4))
        # duas piras de ferro nos lados da escadaria: acendem os portais (sem
        # elas a fachada e' um muro preto e o redemoinho da porta fica no ar)
        self.pontos["piras_catedral"] = []
        for s in (-1, 1):
            pc = P(s * 11.6, 0.0, -4.0)
            b0 = self.pe(pc[0], pc[2], 1.2) - 0.3
            pedra.append(cilindro(pc[0], pc[2], 1.0, b0, yc + 1.4, n=8, raio_topo=0.75))
            pedra.append(cilindro(pc[0], pc[2], 1.15, yc + 1.4, yc + 1.85, n=10, raio_topo=1.35))
            self.m.add_pecas(setor, "brasa", [cilindro(pc[0], pc[2], 1.1, yc + 1.75, yc + 1.9, n=10)])
            self.col.append(cilindro(pc[0], pc[2], 1.1, b0, yc + 1.9, n=8))
            self.ocupar(pc[0], pc[2], 1.5)
            self.pontos["piras_catedral"].append([round(pc[0], 2), round(yc + 1.9, 2), round(pc[2], 2)])
        # escadaria da porta
        degraus = []
        for k in range(6):
            degraus.append(bloco(P, -10.0, 10.0, base, yc + 0.25 * (k + 1), -9.0 + k * 1.4, 0.2))
        # os tres portais: aro ogival em camadas e o vao escuro
        escuro = []
        for uc, vao, alt in ((0.0, 7.0, 9.0), (-11.75, 3.6, 6.0), (11.75, 3.6, 6.0)):
            y0 = yc + 1.5
            mapa = (lambda u, y, w: P(u, y, -w))
            for kk in range(3):
                pedra.extend(arquivolta(uc, vao + 1.2 * kk, y0 + alt, vao * 0.85 + 0.6 * kk, 0.55, 0.0, 0.4 + 0.35 * kk, mapa))
                for s in (-1, 1):
                    jx = uc + s * (vao / 2.0 + 0.6 * kk + 0.3)
                    pedra.append(bloco(P, jx - 0.32, jx + 0.32, y0, y0 + alt, -0.4 - 0.35 * kk, 0.0))
            escuro.append(bloco(P, uc - vao / 2.0, uc + vao / 2.0, y0, y0 + alt + vao * 0.55, -0.05, 0.08))
        # rosacea
        rc = P(0.0, yc + 22.5, -0.3)
        anel = []
        for k in range(33):
            a = 2 * math.pi * k / 32
            anel.append((rc[0] + 6.2 * math.cos(a) * (-tz), rc[1] + 6.2 * math.sin(a), rc[2] + 6.2 * math.cos(a) * tx))
        pedra.append(tubo_redondo(anel, [0.6] * 33, n=6))
        for k in range(12):
            a = 2 * math.pi * k / 12
            pedra.append(tubo_redondo([rc, (rc[0] + 5.8 * math.cos(a) * (-tz), rc[1] + 5.8 * math.sin(a),
                                            rc[2] + 5.8 * math.cos(a) * tx)], [0.22, 0.18], n=4))
        vitral = []
        for k in range(24):
            a0, a1 = 2 * math.pi * k / 24, 2 * math.pi * (k + 1) / 24
            p0 = (rc[0] + 5.9 * math.cos(a0) * (-tz), rc[1] + 5.9 * math.sin(a0), rc[2] + 5.9 * math.cos(a0) * tx)
            p1 = (rc[0] + 5.9 * math.cos(a1) * (-tz), rc[1] + 5.9 * math.sin(a1), rc[2] + 5.9 * math.cos(a1) * tx)
            dentro = (tx * 0.15, 0.0, tz * 0.15)
            vitral.append(hexaedro([rc, p0, p1, rc,
                                    tuple(c + d for c, d in zip(rc, dentro)), tuple(c + d for c, d in zip(p0, dentro)),
                                    tuple(c + d for c, d in zip(p1, dentro)), tuple(c + d for c, d in zip(rc, dentro))]))
        # galeria de estatuas acima dos portais
        for k in range(7):
            uu = -9.0 + k * 3.0
            sp = P(uu, yc + 15.0, -0.9)
            pedra.append(bloco(P, uu - 0.9, uu + 0.9, yc + 14.6, yc + 15.0, -1.6, 0.0))
            self.enlutado(sp[0], yc + 15.0, sp[2], 3.2, math.atan2(-tx, -tz), setor)
        self.m.add_pecas(setor, "pedra_catedral", pedra + degraus)
        self.m.add_pecas(setor, "telhado", telha)
        self.m.add_pecas(setor, "escuro", escuro)
        self.m.add_pecas(setor, "vitral", vitral)
        self.bloco_no_mapa([P(-25.0, 0, -2.6), P(25.0, 0, -2.6), P(25.0, 0, 9.0), P(14.0, 0, 9.0), P(14.0, 0, 72.0),
                            P(-14.0, 0, 72.0), P(-14.0, 0, 9.0), P(-25.0, 0, 9.0)])
        self.col.append(bloco(P, -26.0, 26.0, base, yc + 60.0, -2.4, 72.0))
        porta = P(0.0, yc + 1.5 + 9.0 * 0.6, 0.0)
        self.pontos["porta"] = [round(porta[0], 2), round(porta[1], 2), round(porta[2], 2), round(tx, 3), round(tz, 3)]
        self.pontos["rosacea"] = [round(rc[0] - tx * 3.0, 2), round(rc[1], 2), round(rc[2] - tz * 3.0, 2)]
        sino = P(-20.0, yc + 58.0, 4.0)
        self.pontos["sino"] = [round(sino[0], 2), round(sino[1], 2), round(sino[2], 2)]
        # a saida: o jogador chega no pe' da escadaria da porta
        sx, sz = q[0] - tx * 8.0, q[1] - tz * 8.0
        self.pontos["saida"] = [round(sx, 2), round(yc + 0.1, 2), round(sz, 2), round(tx, 3), round(tz, 3)]
        self.area("area_8_catedral", LINHA.s[-1] - 30.0)
        _ = rnd

    # ------------------------------------------------------------------
    def lampioes(self):
        """Postes de ferro com lanterna a gas, a cada ~34 m, alternando os
        lados. Um em cada tres esta' apagado (vidro escuro)."""
        rnd = self.rnd
        s = S_INICIO + 26.0
        k = 0
        while s < S_FIM - 10.0:
            i = LINHA.em_s(s)
            q = LINHA.p[i]
            sg = 1 if k % 2 else -1
            ab, cp = self.pesos(i, sg)
            if na_ponte_s(s):
                off = sg * (q[2] + 1.875)
                x, z, _ = ponto_linha(s, off)
                y = q[3] + 1.25
            else:
                off = sg * (q[2] + 0.75)
                x, z, _ = ponto_linha(s, off)
                y = None
            if self.livre(x, z, 0.8):
                aceso = rnd.random() < 0.68 or k < 2
                self.lampiao(x, z, y, q, i, sg, aceso)
            s += rnd.uniform(28.0, 38.0)
            k += 1

    def lampiao(self, x, z, y, q, i, sg, aceso):
        setor = self.setor_grade("lampioes", x, z, SETOR)
        if y is None:
            y = self.pe(x, z, 0.3)
            base = [cilindro(x, z, 0.24, y - 0.4, y + 0.55, n=8, raio_topo=0.16)]
            base = self.firmar(base, 0.3)
        else:
            base = [cilindro(x, z, 0.24, y - 0.1, y + 0.55, n=8, raio_topo=0.16)]
        tx, tz = LINHA.t[i]
        dx, dz = tz * sg, -tx * sg          # o braco aponta pra rua
        ferro = base + [cilindro(x, z, 0.075, y + 0.5, y + 3.9, n=6),
                        cilindro(x, z, 0.13, y + 3.85, y + 4.0, n=6)]
        hx, hz = x + dx * 0.55, z + dz * 0.55
        ferro.append(tubo_redondo([(x, y + 3.92, z), (x + dx * 0.3, y + 4.05, z + dz * 0.3), (hx, y + 3.95, hz)],
                                  [0.04, 0.04, 0.04], n=4))
        ferro.extend(corrente_vertical(hx, hz, y + 3.95, y + 3.62, larg=0.07))
        ferro.append(caixa((hx - 0.2, y + 3.56, hz - 0.2), (hx + 0.2, y + 3.64, hz + 0.2)))
        ferro.append(caixa((hx - 0.2, y + 2.98, hz - 0.2), (hx + 0.2, y + 3.04, hz + 0.2)))
        ferro.append(espinho((hx, y + 3.62, hz), (hx, y + 3.95, hz), 0.24, n=4))
        for cx_, cz_ in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            ferro.append(caixa((hx + cx_ * 0.17 - 0.02, y + 3.03, hz + cz_ * 0.17 - 0.02),
                               (hx + cx_ * 0.17 + 0.02, y + 3.57, hz + cz_ * 0.17 + 0.02)))
        self.m.add_pecas(setor, "ferro", ferro)
        self.m.add_pecas(setor, "vidro_lampiao" if aceso else "vidro_apagado",
                         [caixa((hx - 0.15, y + 3.04, hz - 0.15), (hx + 0.15, y + 3.56, hz + 0.15))])
        self.pontos["lampioes"].append([round(hx, 2), round(y + 3.3, 2), round(hz, 2), 1 if aceso else 0])
        self.ocupar(x, z, 0.6, bloqueia=False)
        _ = q

    # ------------------------------------------------------------------
    def longe(self):
        """A cidade que continua na nevoa: torres e igrejas atras das casas e
        do outro lado do abismo, todas nascendo la' de baixo."""
        rnd = self.rnd
        feitas = 0
        tent = 0
        while feitas < 46 and tent < 2000:
            tent += 1
            s = rnd.uniform(S_INICIO, S_FIM + 40.0)
            i = LINHA.em_s(s)
            q = LINHA.p[i]
            sg = rnd.choice((-1, 1))
            dist = q[2] + rnd.uniform(26.0, 80.0)
            x, z, _ = ponto_linha(s, sg * dist)
            kk, lat, _d = LINHA.perto(x, z)
            if kk is None or abs(lat) < LINHA.p[kk][2] + 22.0:
                continue
            if not self.livre(x, z, 12.0):
                continue
            larg = rnd.uniform(8.0, 18.0)
            alt = rnd.uniform(18.0, 46.0)
            giro = math.atan2(*LINHA.t[i])
            v0 = len(self.m.grupos.get(("horizonte", "silhueta"), {"v": []})["v"])
            silhueta_gotica(self, "horizonte", "silhueta", x, z, larg, alt, rnd, giro=giro)
            g = self.m.grupos[("horizonte", "silhueta")]
            b = self.pe(x, z, larg * 1.7) - 1.0
            # o pe' de cada peca (corpo e torres) afunda mais 15 m: na quina do
            # abismo a torre do lado ficava com a base no ar
            g["v"][v0:] = [(vx, vy + b - (15.0 if vy < 0.01 else 0.0), vz) for vx, vy, vz in g["v"][v0:]]
            self.ocupar(x, z, larg * 0.7, bloqueia=False)
            feitas += 1

    def sombras(self):
        """Gigantes magros de pe' no fundo do abismo, olhando a cidade."""
        rnd = self.rnd
        feitas = 0
        tent = 0
        while feitas < 9 and tent < 600:
            tent += 1
            s = rnd.uniform(S_INICIO, S_FIM)
            i = LINHA.em_s(s)
            sg = rnd.choice((-1, 1))
            if self.pesos(i, sg)[0] < 0.7:
                continue
            x, z, _ = ponto_linha(s, sg * (LINHA.p[i][2] + rnd.uniform(60.0, 150.0)))
            if altura(x, z) > FUNDO + 12.0:
                continue
            alt = rnd.uniform(55.0, 110.0)
            v, f = _figura(alt, rnd, feitas % 3)
            self.soltos.append(("SOMBRA_%d" % feitas, "sombra", (v, f), (x, self.pe(x, z, 4.0) - 1.0, z)))
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
            muro_invisivel(self, pts, y0=FUNDO - 10.0, y1=60.0, esp=1.6, fechar=False)
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
        while s < S_FIM - 40.0:
            for lado in (-0.4, 0.4):
                x, y, zz, i = self.ponto(s, lado)
                if na_ponte_s(s):
                    y = LINHA.p[i][3]
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
            s += 48.0


def main():
    global LINHA, S_INICIO, S_FIM, PONTE, ESCADA
    LINHA = inf2.Linha(CONTROLE)
    S_INICIO = 6.0
    S_FIM = LINHA.s[-1] - 6.0
    PONTE = (LINHA.s[LINHA.em_xz(0.0, 168.0)], LINHA.s[LINHA.em_xz(-6.0, 56.0)])
    ESCADA = (LINHA.s[LINHA.em_xz(-4.0, -190.0)], LINHA.s[LINHA.em_xz(5.0, -260.0)])
    # as pecas do cemiterio e do inferno 2 leem `altura`/`SETOR`/`LINHA` do
    # modulo delas: aponta pra daqui
    cem.altura = altura
    cem.SETOR = SETOR
    inf3 = Inferno3()
    inf3.montar()
    print("  linha: %d pontos, %.0f m (ponte %.0f-%.0f, escada %.0f-%.0f)" % (
        len(LINHA.p), LINHA.s[-1], PONTE[0], PONTE[1], ESCADA[0], ESCADA[1]))
    inf3.exportar("inferno_3", "inferno_3", abertos=("chao_",))
    nav = inf3.pontos["navmesh"]
    print("  navmesh: %d vertices, %d poligonos" % (len(nav["v"]), len(nav["p"])))
    print("  casas=%d tumulos=%d lampioes=%d inimigos=%d sombras=%d" % (
        inf3.pontos["n_casas"], inf3.pontos["n_tumulos"], len(inf3.pontos["lampioes"]),
        len(inf3.pontos["inimigos"]), len(inf3.soltos)))


if __name__ == "__main__":
    main()
