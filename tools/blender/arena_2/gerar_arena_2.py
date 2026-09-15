# -*- coding: utf-8 -*-
"""Modela a ARENA 2 — o Adro Partido — e exporta pro Godot.

Rodar em background (nao mexe no .blend que voce tem aberto, nao precisa do
addon MCP):

    blender --background --factory-startup \\
        --python tools/blender/arena_2/gerar_arena_2.py

Saidas:
    red-valve/assets/3d_model/stages/battlefield_2/arena_2.glb
    red-valve/assets/3d_model/stages/battlefield_2/arena_2_pontos.json

==============================================================================
POR QUE ESTE ARQUIVO EXISTE

A arena 1 (`battlefield_1.tscn`) e' uma plataforma de 20 m flutuando no vazio:
quatro cantos de pedra, grama e ceu. Ela funciona porque a briga do prologo e'
curta e fechada. A arena 2 e' o oposto e de proposito: e' NO CHAO, e' grande,
e' aberta, e da' pra correr em volta das coisas — o desenho e o de arena de
Doom, onde o cenario e' o terceiro lutador.

==============================================================================
A PLANTA (metros; o jogador tem ~1,8 m e corre a 4,8 m/s)

                          N (-Z)
                    [4] FACHADA + ROSACEA
          [5] COSTELAS                 [3] TORRE CAIDA
    W (-X) [6] CONTRAFORTES  o  [2] TORRE EM PE  (+X) E
          [7] MURALHA DE CARNE       [1] ARCADA QUEBRADA
                    [0] BRECHA (entrada do jogador)
                          S (+Z)

  - Praca octogonal de pedra partida, raio 40 (80 m de ponta a ponta).
  - No meio, o ADRO: plataforma octogonal raio 10, 1,6 m acima da praca,
    com quatro rampas nos eixos. Em cima dela a BOCA — o buraco de carne por
    onde a coisa subiu — fechada por uma GRELHA de ferro no nivel do piso.
    E' o unico ponto alto do mapa e o centro da briga, e por isso se anda em
    cima dele: o preco de ficar ali e' o jato de fogo que sobe pelas barras
    de vez em quando (quem dispara isso e' o `battlefield_2.gd`).
  - A praca de pedra vai ate' o raio 46 — PASSANDO POR BAIXO da ruina. O muro
    invisivel que segura o jogador esta' antes, no 41, entao nao ha' beirada
    nem queda: onde a lajota acaba, o jogador ja' nao chega.
  - Anel de ruina no raio 42: oito modulos diferentes, um por lado do
    octogono. Cada um e' uma silhueta distinta pro jogador se localizar sem
    bussola — e' assim que arena de tiro resolve orientacao.
  - Fora disso: terreiro de cinza ate' o raio 140 e uma linha de horizonte de
    cidade morta, so' silhueta, pra o ceu nao encostar no chao.

==============================================================================
O QUE TORNA O LUGAR GOTICO E LOVECRAFT AO MESMO TEMPO

O gotico entra pela ARQUITETURA (ogiva, rosacea, contraforte, pilar composto)
e o Lovecraft entra POR BAIXO dela: a carne nao esta' pousada no cenario, ela
ARROMBOU o cenario. Tentaculo sai de fissura, nao do chao liso; costela nasce
onde a nave caiu; a muralha oeste esta' sendo digerida. Se a carne fosse so'
enfeite vermelho espalhado por igual, viraria decoracao de halloween.

O fogo e a brasa nas fissuras sao o unico vermelho CLARO da paleta, e por isso
sao a leitura de "por onde da' pra andar": fissura brilha, caminho e' escuro.

==============================================================================
COMO ISTO CHEGA NO GODOT

  - Um .glb, varios objetos, um por (setor x material). A divisao por setor
    NAO e' estetica: o renderer "mobile" do projeto so' aceita 8 luzes omni +
    8 spot POR MALHA, e aqui tem tambor de fogo e monolito espalhados. Uma
    malha unica de "toda a pedra" perderia luz sem avisar.
  - Material aqui e' so' MARCACAO (`MI_pedra`, `MI_carne`...). Quem pinta e' o
    `arena_2_materiais.gd` da cena, com .tres triplanar — igual a' igreja.
  - Colisao e' UM objeto separado, `CL_arena_2-colonly`: o importador do Godot
    vira StaticBody3D invisivel com trimesh. Ela e' LISA (caixas, prismas e
    rampas) porque colisao fiel a escombro e' o caminho curto pro jogador
    enganchar em quina de pedra. A layer dela e' corrigida pra 2 no
    `battlefield_2.gd` — o player tem `collision_mask = 2`.
  - O navmesh sai daqui pronto, em `arena_2_pontos.json`, e nao do bake do
    editor: e' uma grade de 2,5 m com buraco onde tem escombro e degrau. O
    bake do editor nao sobrevive a uma regeracao do modelo.

Convencao de eixos: X = largura, Y = ALTURA, Z = profundidade (Y-up, como o
JOGO, nao como o Blender). E' de proposito e casa com `export_yup=False`.
"""

import json
import math
import os
import random
import sys

import bpy

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "igreja"))

from geo import (Malhas, arco_perfil, arquivolta, caixa, caixa_girada,      # noqa: E402
                 cilindro, coluneta, domo, entulho, faixa_sobre_arco,
                 hexaedro, mapa_girado, painel, pilar_composto, tubo)

DESTINO = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "stages",
                       "battlefield_2")

# --------------------------------------------------------------------------
# medidas

R_PRACA = 40.0        # raio util da praca (onde se coloca escombro e prop)
R_PISO = 46.0         # ate' onde a LAJOTA e a colisao do chao vao de verdade
R_ANEL = 42.0         # face INTERNA do anel de ruina (apotema do octogono)
R_LIMITE = 41.0       # muro invisivel que fecha a arena
R_PLAT = 10.0         # raio do adro central
R_BOCA = 5.0          # raio da tigela de carne no meio do adro
H_PLAT = 1.6          # altura do adro
R_RAMPA = 18.0        # onde a rampa encosta no chao
W_RAMPA = 10.0        # largura da rampa

# A BORDA REAL DO ADRO — e' a apotema do prisma de COLISAO (R_PLAT + 0,9), nao
# a do octogono de desenho. A rampa tem de subir ate' aqui, e nao ate' a
# apotema de R_PLAT: parando antes, ela encosta 15 cm ABAIXO do tampo e sobra
# um degrau escondido dentro da parede do adro. Colisao de caixa nao sobe
# degrau: o jogador chegava no fim da rampa, travava e so' passava pulando.
AP_ADRO = (R_PLAT + 0.9) * math.cos(math.pi / 8)
AP_LINGUETA = AP_ADRO - 0.6   # quanto o tablado entra POR BAIXO da coroa
R_CAMPO = 140.0       # ate' onde vai o terreiro de cinza

PASSO_PISO = 2.0      # lajota da praca
PASSO_NAV = 2.0       # celula do navmesh
PASSO_COL = 2.5       # celula da COLISAO do chao

# Fundo da fissura, e o quanto a calcada AFUNDA em volta dela.
#
# Era -1,05 sem afundamento nenhum: a fenda era um degrau reto de um metro no
# meio do chao, a colisao passava lisa por cima e o jogador andava um metro
# ACIMA do que via — e todo prop que caisse ali ficava boiando. Agora a lajota
# cede em volta da rachadura (`FENDA_CEDE`, suave, e a colisao segue junto,
# porque as duas saem de `_altura_piso`) e so' o miolo da fenda fica abaixo.
# O que sobra de desnivel nao chega a um palmo.
Y_FENDA = -0.55

# A RONDA — o corredor que da' a volta na arena.
#
# Nao adianta a praca ser grande se, correndo pela beirada, o caminho fecha
# atras de um monte de pedra a cada vinte metros. Todo escombro SORTEADO tem
# de deixar, no azimute dele, pelo menos LARG_RONDA metros de folga radial
# em algum ponto da faixa entre RONDA_R0 e RONDA_R1. E' o que garante que
# existe volta completa, sem eu ter de desenhar a pista na mao.
FENDA_CEDE = 0.24     # quanto a calcada cede de cada lado da rachadura
FENDA_BEIRA = 1.9     # ate' onde vai esse afundamento, alem da meia largura

RONDA_R0 = 19.0
RONDA_R1 = 38.0
LARG_RONDA = 3.6

# Parkour: o degrau que o jogador vence de um pulo.
#
# `JUMP_VELOCITY` do player.gd e' 4,5 e a gravidade e' 9,8 — pulo de 1,03 m.
# Cada lance sobe DEGRAU_PARKOUR, com folga de 20 cm pra ninguem ficar
# raspando na quina.
DEGRAU_PARKOUR = 0.8

LADO_U = R_ANEL * math.tan(math.pi / 8) + 1.0   # meia-largura de um modulo

# cor de marcacao — o material de verdade e' o .tres da cena
MATERIAIS = {
    "pedra": (0.42, 0.40, 0.36),
    "pedra_esc": (0.20, 0.19, 0.18),
    "queimado": (0.09, 0.085, 0.08),
    "terra": (0.20, 0.16, 0.13),
    "metal": (0.26, 0.19, 0.14),
    "madeira": (0.19, 0.14, 0.10),
    "carne": (0.30, 0.05, 0.07),
    "osso": (0.70, 0.66, 0.56),
    "brasa": (1.00, 0.28, 0.06),
    "sigilo": (0.95, 0.10, 0.06),
    "silhueta": (0.05, 0.05, 0.07),
}


# --------------------------------------------------------------------------
# geometria que a igreja nao tinha


def oct_pontos(r, fase=math.pi / 8):
    """Octogono com os LADOS virados pros eixos (vertice a 22,5 graus)."""
    return [(r * math.sin(fase + k * math.pi / 4),
             r * math.cos(fase + k * math.pi / 4)) for k in range(8)]


def dentro_oct(x, z, r, fase=math.pi / 8):
    a = r * math.cos(math.pi / 8)
    for k in range(8):
        ang = fase + math.pi / 8 + k * math.pi / 4
        if x * math.sin(ang) + z * math.cos(ang) > a:
            return False
    return True


def raio_oct(ang, r, fase=math.pi / 8):
    """Distancia do centro ate' a borda do octogono, na direcao `ang`."""
    a = (ang - fase) % (math.pi / 4) - math.pi / 8
    return r * math.cos(math.pi / 8) / math.cos(a)


def _coroa_solida(r_int_f, r_ext_f, y, n, esp):
    """Anel entre dois contornos, como SOLIDO fino de vertices compartilhados.

    As duas coisas aqui sao de vida ou morte e foram aprendidas na marra:

    1. SOLIDO, nao chapa. O `normals_make_consistent` do Blender decide o
       "fora" de cada pedaco por raio, e numa chapa plana a decisao e' cara ou
       coroa. O tampo do adro saia com um terco dos quadrilateros virado pra
       baixo: em jogo, cunhas PRETAS no meio do adro, que o jogador leu (com
       razao) como buraco no chao — e a mesma coroa e' a colisao do tampo,
       entao ele ainda afundava e enganchava nessas cunhas.
    2. VERTICES COMPARTILHADOS. Antes cada quadrilatero trazia os quatro
       vertices dele, e o anel eram 48 PEDACOS SOLTOS — cada um sorteava a
       propria orientacao. Compartilhando, o anel e' uma peca so'.
    """
    verts, faces = [], []
    for (rf, yy) in ((r_int_f, y), (r_ext_f, y),
                     (r_int_f, y - esp), (r_ext_f, y - esp)):
        for k in range(n):
            a = 2 * math.pi * k / n
            r = rf(a)
            verts.append((r * math.sin(a), yy, r * math.cos(a)))

    def q(anel, k):
        return anel * n + (k % n)

    for k in range(n):
        j = k + 1
        faces.append([q(0, k), q(1, k), q(1, j), q(0, j)])   # tampo (pra cima)
        faces.append([q(2, j), q(3, j), q(3, k), q(2, k)])   # fundo
        faces.append([q(1, k), q(3, k), q(3, j), q(1, j)])   # costado de fora
        faces.append([q(2, k), q(0, k), q(0, j), q(2, j)])   # costado de dentro
    return verts, faces


def coroa_oct(r_int, r_ext, y, n=48, esp=0.18):
    """Tampo do adro: circulo por dentro (o furo da Boca), octogono por fora."""
    return _coroa_solida(lambda a: r_int, lambda a: raio_oct(a, r_ext),
                         y, n, esp)


def coroa_oct2(r_int, r_ext, y, n=48, esp=0.16):
    """Piso de um degrau do plinto: octogono dos dois lados."""
    return _coroa_solida(lambda a: raio_oct(a, r_int),
                         lambda a: raio_oct(a, r_ext), y, n, esp)


def chapa_grossa(celulas, passo, altura, esp):
    """Laje FECHADA cujo tampo segue `altura(x, z)` numa grade.

    O fundo e' paralelo, `esp` abaixo, e a borda serrilhada e' fechada por
    parede. Fechada NAO e' capricho: o `normals_make_consistent` do Blender
    decide o "fora" de cada pedaco por raio, e numa chapa ABERTA de 90 m a
    decisao sai a sorte — metade das vezes o chao do jogo nasceria virado pra
    baixo e o jogador atravessaria a praca inteira em queda livre.
    """
    cima, baixo = {}, {}
    verts, faces = [], []
    dentro = set(celulas)

    def vid(tab, i, j, dy):
        if (i, j) not in tab:
            x, z = i * passo, j * passo
            tab[(i, j)] = len(verts)
            verts.append((x, altura(x, z) + dy, z))
        return tab[(i, j)]

    for (i, j) in celulas:
        a, b = vid(cima, i, j, 0.0), vid(cima, i, j + 1, 0.0)
        c, d = vid(cima, i + 1, j + 1, 0.0), vid(cima, i + 1, j, 0.0)
        faces.append([a, b, c, d])
        a2, b2 = vid(baixo, i, j, -esp), vid(baixo, i, j + 1, -esp)
        c2, d2 = vid(baixo, i + 1, j + 1, -esp), vid(baixo, i + 1, j, -esp)
        faces.append([d2, c2, b2, a2])
        for (di, dj, p, q, p2, q2) in ((-1, 0, a, b, a2, b2),
                                       (0, 1, b, c, b2, c2),
                                       (1, 0, c, d, c2, d2),
                                       (0, -1, d, a, d2, a2)):
            if (i + di, j + dj) not in dentro:
                faces.append([p, q, q2, p2])
    return verts, faces


def casca_aneis(aneis, esp, n=20):
    """Solido FECHADO de uma superficie de revolucao dada por (raio, altura).

    A tigela da Boca precisa disso pra colisao: uma chapa aberta so' colide de
    um lado no `ConcavePolygonShape3D`, e o jogador atravessaria a superficie
    por baixo."""
    verts, faces = [], []
    m = len(aneis)
    for lado, dy in ((0, 0.0), (1, -esp)):
        for (r, y) in aneis:
            for k in range(n):
                a = 2 * math.pi * k / n
                verts.append((r * math.sin(a), y + dy, r * math.cos(a)))
    off = m * n
    for i in range(m - 1):
        for k in range(n):
            j = (k + 1) % n
            faces.append([i * n + k, i * n + j, (i + 1) * n + j, (i + 1) * n + k])
            faces.append([off + (i + 1) * n + k, off + (i + 1) * n + j,
                          off + i * n + j, off + i * n + k])
    for k in range(n):        # bordas de fora e de dentro
        j = (k + 1) % n
        faces.append([k, off + k, off + j, j])
        b = (m - 1) * n
        faces.append([b + j, off + b + j, off + b + k, b + k])
    return verts, faces


def prisma_oct(r_baixo, y0, r_cima, y1, fase=math.pi / 8, tampa=True):
    """Prisma octogonal (tronco, se os raios diferem). Fechado em cima."""
    b = oct_pontos(r_baixo, fase)
    c = oct_pontos(r_cima, fase)
    v = [(p[0], y0, p[1]) for p in b] + [(p[0], y1, p[1]) for p in c]
    faces = []
    for k in range(8):
        j = (k + 1) % 8
        faces.append([k, j, 8 + j, 8 + k])
    faces.append(list(range(7, -1, -1)))
    if tampa:
        faces.append(list(range(8, 16)))
    return v, faces


def parede_reta(p0, p1, y0, y1, esp):
    """Muro entre dois pontos do chao, com espessura pros dois lados."""
    dx, dz = p1[0] - p0[0], p1[1] - p0[1]
    d = math.hypot(dx, dz) or 1.0
    nx, nz = -dz / d * esp / 2.0, dx / d * esp / 2.0
    a = (p0[0] + nx, p0[1] + nz)
    b = (p1[0] + nx, p1[1] + nz)
    c = (p1[0] - nx, p1[1] - nz)
    e = (p0[0] - nx, p0[1] - nz)
    return hexaedro([(a[0], y0, a[1]), (b[0], y0, b[1]),
                     (c[0], y0, c[1]), (e[0], y0, e[1]),
                     (a[0], y1, a[1]), (b[0], y1, b[1]),
                     (c[0], y1, c[1]), (e[0], y1, e[1])])


def _base_perp(eixo):
    """Dois vetores unitarios perpendiculares ao eixo dado."""
    ex, ey, ez = eixo
    d = math.sqrt(ex * ex + ey * ey + ez * ez) or 1.0
    ex, ey, ez = ex / d, ey / d, ez / d
    ref = (0.0, 1.0, 0.0) if abs(ey) < 0.9 else (1.0, 0.0, 0.0)
    ux = ey * ref[2] - ez * ref[1]
    uy = ez * ref[0] - ex * ref[2]
    uz = ex * ref[1] - ey * ref[0]
    d = math.sqrt(ux * ux + uy * uy + uz * uz) or 1.0
    ux, uy, uz = ux / d, uy / d, uz / d
    vx = ey * uz - ez * uy
    vy = ez * ux - ex * uz
    vz = ex * uy - ey * ux
    return (ux, uy, uz), (vx, vy, vz)


def tubo_redondo(pontos, raios, n=8, fechar=True):
    """Tubo de secao CIRCULAR e raio variavel ao longo de uma polilinha.

    O `tubo` da igreja tem secao retangular sempre com o alto em Y — serve pra
    nervura e viga, nao pra tentaculo, que sobe, dobra e desce. Este aqui usa
    o quadro perpendicular ao proprio caminho, entao a secao acompanha a curva
    em qualquer direcao.
    """
    verts, faces = [], []
    m = len(pontos)
    for i, p in enumerate(pontos):
        if i == 0:
            eixo = [pontos[1][k] - p[k] for k in range(3)]
        elif i == m - 1:
            eixo = [p[k] - pontos[-2][k] for k in range(3)]
        else:
            eixo = [pontos[i + 1][k] - pontos[i - 1][k] for k in range(3)]
        u, v = _base_perp(eixo)
        r = raios[i]
        for j in range(n):
            a = 2 * math.pi * j / n
            ca, sa = math.cos(a) * r, math.sin(a) * r
            verts.append((p[0] + u[0] * ca + v[0] * sa,
                          p[1] + u[1] * ca + v[1] * sa,
                          p[2] + u[2] * ca + v[2] * sa))
    for i in range(m - 1):
        a0, b0 = i * n, (i + 1) * n
        for j in range(n):
            k = (j + 1) % n
            faces.append([a0 + j, a0 + k, b0 + k, b0 + j])
    if fechar:
        faces.append(list(range(n - 1, -1, -1)))
        o = (m - 1) * n
        faces.append(list(range(o, o + n)))
    return verts, faces


def espinho(base, ponta, raio, n=6):
    """Cone de base a ponta em qualquer direcao (dente, estalagmite, vergalho)."""
    eixo = [ponta[k] - base[k] for k in range(3)]
    u, v = _base_perp(eixo)
    verts = []
    for j in range(n):
        a = 2 * math.pi * j / n
        ca, sa = math.cos(a) * raio, math.sin(a) * raio
        verts.append((base[0] + u[0] * ca + v[0] * sa,
                      base[1] + u[1] * ca + v[1] * sa,
                      base[2] + u[2] * ca + v[2] * sa))
    verts.append(tuple(ponta))
    faces = [[j, (j + 1) % n, n] for j in range(n)]
    faces.append(list(range(n - 1, -1, -1)))
    return verts, faces


def arco_pontos(p0, p1, altura, n=12, torcao=0.0):
    """Polilinha de arco entre dois pontos do chao, com uma torcida lateral."""
    pts = []
    dx, dz = p1[0] - p0[0], p1[2] - p0[2]
    d = math.hypot(dx, dz) or 1.0
    nx, nz = -dz / d, dx / d
    for i in range(n + 1):
        t = i / n
        s = math.sin(math.pi * t)
        lado = torcao * math.sin(math.pi * t) * math.sin(2 * math.pi * t)
        pts.append((p0[0] + dx * t + nx * lado,
                    p0[1] + (p1[1] - p0[1]) * t + altura * s,
                    p0[2] + dz * t + nz * lado))
    return pts


def dist_polilinha(x, z, linha):
    melhor = 1e9
    for i in range(len(linha) - 1):
        ax, az = linha[i]
        bx, bz = linha[i + 1]
        dx, dz = bx - ax, bz - az
        dd = dx * dx + dz * dz
        t = 0.0 if dd == 0 else max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / dd))
        px, pz = ax + dx * t, az + dz * t
        melhor = min(melhor, math.hypot(x - px, z - pz))
    return melhor


# --------------------------------------------------------------------------
# a arena


class Arena:

    def __init__(self, semente=20260915):
        self.m = Malhas()
        self.rnd = random.Random(semente)
        self.col = []          # pecas do CL_arena_2-colonly
        self.bloqueios = []    # (x, z, raio) que o navmesh tem de furar
        self.muros = []        # (x, z, ang, comp, alt) dos muros escalaveis
        self.escaladas = []    # (x, z, dirx, dirz, alto) pra por escada
        self.n_escadarias = 0
        self.contagem = {"monte": 0, "muro": 0, "coluna": 0, "torre_laje": 0}
        self._grade = set()    # bloqueios rasterizados, pro teste da ronda
        self._grade_n = -1
        self.pontos = {
            "player": [0.0, 0.3, 33.0],
            "boca": [0.0, 2.4, 0.0],
            "inimigos": [],
            "fogos": [],
            "sigilos": [],
            "brasas": [],
            "props": [],
            "navmesh": {"v": [], "p": []},
        }
        self.fissuras = self._sortear_fissuras()
        self.celulas_fenda = set()

    # ------------------------------------------------------------------
    # utilidades

    def quadrante(self, x, z, prefixo="campo"):
        """Nome de setor pelo quadrante do ponto.

        Serve pro limite de 8 luzes omni por MALHA do renderer mobile: se todo
        o escombro solto da praca virasse uma malha so', a AABB dela cobriria
        a arena inteira e ela enxergaria as oito fogueiras mais a Boca — nove.
        A nona some sem aviso. Quebrado em quadrante, cada malha ve' tres ou
        quatro luzes e sobra folga.
        """
        return "%s_%s%s" % (prefixo, "n" if z < 0 else "s", "w" if x < 0 else "e")

    def bloquear(self, x, z, raio):
        self.bloqueios.append((x, z, raio))
        self._grade_n = -1

    def bloquear_linha(self, x, z, ang, comp, raio, n=4):
        """Bloqueio de peca COMPRIDA (muro, coluna tombada, torre deitada).

        Um circulo unico de raio meia-peca cobre um muro de 9 m com um disco de
        9 m de diametro e come' o corredor inteiro ao lado dele. Em disco de 1 m
        ao longo do eixo, o navmesh acompanha a forma e sobra caminho dos dois
        lados.
        """
        for i in range(n):
            t = (i / (n - 1.0) - 0.5) * comp
            self.bloquear(x + math.cos(ang) * t, z + math.sin(ang) * t, raio)

    def prop(self, tipo, x, z, giro=None, y=0.0, escala=1.0):
        # SAI DE CIMA DE FISSURA. A colisao do chao e' uma chapa lisa que passa
        # reta por cima da fenda: um prop pousado numa delas fica no nivel da
        # praca, meio metro ACIMA da pedra que se ve' la' dentro — e' o que
        # fazia as arvores parecerem penduradas no ar. O empurrao e' pelo
        # lado (perpendicular ao raio) porque as fissuras correm do centro
        # pra fora: andando pra fora, a peca so' acompanharia a rachadura.
        for _ in range(8):
            if not self._na_fenda(x, z, 0.9):
                break
            d = math.hypot(x, z) or 1.0
            x, z = x - z / d * 0.9, z + x / d * 0.9
        self.pontos["props"].append({
            "tipo": tipo,
            "pos": [round(x, 2), round(y + self._altura_piso(x, z), 2), round(z, 2)],
            "giro": round(self.rnd.uniform(0, 2 * math.pi) if giro is None else giro, 3),
            "escala": round(escala, 3)})

    def _sortear_fissuras(self):
        """As rachaduras que sangram brasa. Todas nascem na BOCA e vao pra
        fora: quem olha o chao ve' de onde a coisa veio."""
        linhas = []
        for k in range(6):
            ang = k * math.pi / 3 + self.rnd.uniform(-0.25, 0.25)
            pts = []
            r = 11.0
            a = ang
            while r < 39.0:
                pts.append((r * math.sin(a), r * math.cos(a)))
                r += self.rnd.uniform(4.0, 7.0)
                a += self.rnd.uniform(-0.22, 0.22)
            linhas.append({"pts": pts, "larg": self.rnd.uniform(1.3, 2.3)})
        return linhas

    def _altura_piso(self, x, z):
        y = 0.07 * math.sin(x * 0.19) * math.cos(z * 0.15)
        y += 0.04 * math.sin((x + z * 0.6) * 0.43)
        for cx, cz, raio, prof in self.crateras:
            d = math.hypot(x - cx, z - cz)
            if d < raio:
                t = 1.0 - (d / raio) ** 2
                y -= prof * t * t
        # a calcada CEDE em volta da rachadura. Sem isso a fenda e' um degrau
        # reto no meio do chao, e como a colisao nao pode descer ali (seria um
        # poco de meio metro no meio da briga) o jogador anda por cima do
        # vazio. Cedendo, o desnivel que sobra e' de um palmo e a pedra
        # inclinada le' como chao rachado, que e' o que ela e'.
        for f in self.fissuras:
            beira = f["larg"] / 2.0 + FENDA_BEIRA
            d = dist_polilinha(x, z, f["pts"])
            if d < beira:
                t = 1.0 - (d / beira) ** 2
                y -= FENDA_CEDE * t * t
        return y

    # ------------------------------------------------------------------

    def montar(self):
        self.crateras = [(-19.0, 14.0, 7.0, 0.55), (23.0, -9.0, 6.0, 0.45),
                         (4.0, 26.0, 5.0, 0.35), (-25.0, -20.0, 8.0, 0.6)]
        self.terreiro()
        self.piso()
        self.adro()
        self.boca()
        self.anel_de_ruina()
        # tentaculo e monolito ANTES do escombro. Eles tem lugar quase fixo; o
        # escombro e' o que e' sorteado, e quem sorteia precisa ja' enxergar
        # tudo que esta' no chao — senao o teste da ronda aprova um corredor
        # que uma peca posterior vem fechar.
        self.tentaculos()
        self.monolitos()
        # ORDEM: muro, torre de laje, escombro solto. Quem precisa de mais
        # espaco escolhe primeiro. Ao contrario, a praca enchia de monte de
        # pedra e nao sobrava vao nem pro muro nem pra torre de laje.
        self.escombro_muros()
        self.parkour_torres()
        self.escombro_solto()
        self.parkour_encostado()
        self.horizonte()
        self.cercadura()
        # o navmesh ANTES dos marcadores: eles sao escolhidos em cima dele
        self.navmesh()
        self.marcadores()

    # ------------------------------------------------------------------
    # chao

    def terreiro(self):
        """Cinza e terra batida em volta da praca, ate' sumir na nevoa.

        Vai num anel radial e nao numa grade: aqui longe ninguem pisa, o que
        importa e' cobrir o vazio com pouco triangulo.
        """
        # comeca DENTRO da praca (raio 30) de proposito: a praca e' um
        # octogono e o terreiro e' um anel redondo. Encostando os dois no
        # mesmo raio sobra uma fresta aberta no meio de cada lado do
        # octogono, por onde se ve' o vazio.
        aneis = [R_PISO - 8.0, R_PISO + 2.0, 54.0, 66.0, 84.0, R_CAMPO * 0.8,
                 R_CAMPO]
        n = 36
        for i in range(len(aneis) - 1):
            r0, r1 = aneis[i], aneis[i + 1]
            for k in range(n):
                a0 = 2 * math.pi * k / n
                a1 = 2 * math.pi * (k + 1) / n
                q = []
                for r, a in ((r0, a0), (r1, a0), (r1, a1), (r0, a1)):
                    x, z = r * math.sin(a), r * math.cos(a)
                    y = -0.8 - (r - R_PRACA) * 0.012
                    if r > 60.0:
                        y += (r - 60.0) * 0.10 * (0.6 + 0.4 * math.sin(a * 3.1))
                    y += 0.5 * math.sin(a * 5.3 + r * 0.05) * max(0.0, min((r - R_PRACA) / 20.0, 1.0))
                    q.append((x, y, z))
                self.m.add("terreiro", "terra", q, [[0, 1, 2, 3]])
        # o chao la' de baixo, so' pra nada cair pro infinito
        self.col.append(caixa((-R_CAMPO, -3.0, -R_CAMPO), (R_CAMPO, -1.0, R_CAMPO)))

    def piso(self):
        """A praca: lajota de 2 m com fissura aberta por onde escapa brasa.

        A grade e' cortada celula a celula pela fissura, entao a borda sai
        RECORTADA no tamanho da lajota — e' assim que pedra de calcada quebra
        de verdade, e sai de graca.
        """
        n = int(R_PISO / PASSO_PISO)
        celulas = []
        for i in range(-n, n):
            for j in range(-n, n):
                xc = (i + 0.5) * PASSO_PISO
                zc = (j + 0.5) * PASSO_PISO
                # ate' R_PISO, e nao ate' R_PRACA: a lajota tem de passar POR
                # BAIXO da ruina. Parando no raio util, sobrava um anel de 4 m
                # entre a borda do chao e o muro invisivel, e o jogador andava
                # ali em cima do terreiro escuro, fora da arena.
                if not dentro_oct(xc, zc, R_PISO):
                    continue
                # So' tira a lajota quando a celula INTEIRA cai por baixo do
                # plinto. Medindo so' o centro, as celulas de quina saiam com
                # a borda de FORA do adro e abriam uma fresta de ate' 1,3 m
                # entre a pedra do adro e a primeira lajota: um anel de vazio
                # em volta do adro inteiro, que e' o que se via de cima.
                meia = PASSO_PISO / 2.0
                if all(dentro_oct(xc + dx, zc + dz, R_PLAT + 2.0)
                       for dx in (-meia, meia) for dz in (-meia, meia)):
                    continue
                fenda = False
                for f in self.fissuras:
                    if dist_polilinha(xc, zc, f["pts"]) < f["larg"] / 2.0:
                        fenda = True
                        break
                if fenda:
                    self.celulas_fenda.add((i, j))
                celulas.append((i, j, xc, zc, fenda))

        for i, j, xc, zc, fenda in celulas:
            x0, x1 = i * PASSO_PISO, (i + 1) * PASSO_PISO
            z0, z1 = j * PASSO_PISO, (j + 1) * PASSO_PISO
            # giro anti-horario visto de cima: a lajota tem de olhar pra
            # CIMA, senao o Godot descarta a face e a praca fica vazada
            cantos = [(x0, z0), (x0, z1), (x1, z1), (x1, z0)]
            setor = "piso_%s%s" % ("n" if zc < 0 else "s", "w" if xc < 0 else "e")
            if fenda:
                # o fundo da fissura, que e' o que brilha
                fundo = [(x, Y_FENDA, z) for x, z in cantos]
                self.m.add(setor, "brasa", fundo, [[0, 1, 2, 3]])
                # parede da fissura so' onde a vizinha NAO e' fissura
                # a aresta d liga cantos[d] a cantos[d+1]; a parede dela
                # e' escrita ao contrario porque quem olha pra ela esta'
                # DENTRO da fissura
                viz = ((-1, 0), (0, 1), (1, 0), (0, -1))
                for d, (di, dj) in enumerate(viz):
                    if (i + di, j + dj) in self.celulas_fenda:
                        continue
                    a = cantos[d]
                    b = cantos[(d + 1) % 4]
                    ya = self._altura_piso(*a)
                    yb = self._altura_piso(*b)
                    self.m.add(setor, "pedra_esc",
                               [(b[0], Y_FENDA, b[1]), (a[0], Y_FENDA, a[1]),
                                (a[0], ya, a[1]), (b[0], yb, b[1])],
                               [[0, 1, 2, 3]])
                continue
            perto_de_fenda = any((i + di, j + dj) in self.celulas_fenda
                                 for di, dj in ((1, 0), (0, 1), (-1, 0), (0, -1),
                                                (1, 1), (-1, -1), (1, -1), (-1, 1)))
            # Variacao do piso: so' entre pedra escura, queimado e TERRA. A
            # pedra clara da parede (T_stone_church) tambem servia de lajota,
            # mas e' quase o dobro mais clara que a escura — espalhada pela
            # praca, cada lajota dessas virava um holofote no chao.
            mat = "queimado" if perto_de_fenda else "pedra_esc"
            if not perto_de_fenda and (i * 7 + j * 13) % 9 == 0:
                mat = "terra"
            q = [(x, self._altura_piso(x, z), z) for x, z in cantos]
            self.m.add(setor, mat, q, [[0, 1, 2, 3]])

        # COLISAO DO CHAO. Era um tampo LISO em y=0,02, e no fundo das
        # crateras o jogador ficava 60 cm ACIMA da pedra que via: de dentro
        # da cratera o chao parecia ter sumido. Agora o tampo acompanha
        # `_altura_piso`, que e' a mesma conta que desenha a lajota — como os
        # cantos sao compartilhados entre celulas vizinhas, a superficie sai
        # CONTINUA e nao ha' quina onde tropecar.
        #
        # A chapa e' de uma face so' (o jogador nunca esta' por baixo dela) e
        # por baixo vai um prisma macico, que e' quem impede qualquer coisa de
        # cair pro infinito se escapar pela borda serrilhada.
        nc = int((R_PISO + PASSO_COL) / PASSO_COL) + 1
        celulas = [(i, j) for i in range(-nc, nc) for j in range(-nc, nc)
                   if dentro_oct((i + 0.5) * PASSO_COL, (j + 0.5) * PASSO_COL,
                                 R_PISO + PASSO_COL)]
        self.col.append(chapa_grossa(celulas, PASSO_COL, self._altura_piso, 1.4))

    # ------------------------------------------------------------------
    # o adro central

    def adro(self):
        """Plataforma octogonal com quatro rampas. E' o ponto alto do mapa."""
        # corpo: prisma com um leve talude, e tres faixas de degrau em volta.
        # SEM tampa: quem fecha o tampo e' a coroa, que tem o furo da Boca.
        # O corpo e' RETO e para exatamente onde para a colisao (R_PLAT+0,9).
        # Com talude, a borda que se VIA ficava 83 cm mais estreita que a que
        # segura o pe', e sobrava uma prateleira invisivel em volta do adro.
        self.m.add_pecas("adro", "pedra", [prisma_oct(R_PLAT + 0.9, -0.4,
                                                      R_PLAT + 0.9, H_PLAT,
                                                      tampa=False)])
        # O PLINTO: tres degraus em volta, cada um com o PISO dele (a coroa)
        # alem da saia. So' com a saia, de cima se enxergava pelo vao entre um
        # degrau e o de dentro — era metade do anel preto em volta do adro.
        #
        # E com COLISAO. Antes eram tres aneis de pedra que o jogador
        # atravessava, e quem o barrava era o muro do corpo, um metro atras.
        plinto = ((2.0, 0.40), (1.6, 0.76), (1.2, 1.12))
        for k, (dr, dy) in enumerate(plinto):
            dr_int = plinto[k + 1][0] if k + 1 < len(plinto) else 0.9
            # o piso do degrau sai 4 cm ALEM da saia e entra 4 cm por baixo
            # do que vem de dentro: encostando certinho, as faces verticais
            # ficavam no mesmo plano e o espelho do degrau piscava
            self.m.add_pecas("adro", "pedra_esc",
                             [prisma_oct(R_PLAT + dr, dy - 0.40,
                                         R_PLAT + dr, dy, tampa=False),
                              coroa_oct2(R_PLAT + dr_int - 0.04,
                                         R_PLAT + dr + 0.04, dy)])
            self.col.append(prisma_oct(R_PLAT + dr, -0.4, R_PLAT + dr, dy))
        # tampo, furado no meio pra Boca — ate' a borda de COLISAO, senao
        # sobra a tal prateleira
        # 4 cm de beiral alem do corpo: rente, as duas faces verticais
        # dividiam o mesmo plano e a borda do adro piscava
        self.m.add_pecas("adro", "pedra",
                         [coroa_oct(R_BOCA, R_PLAT + 0.94, H_PLAT)])
        self.col.append(prisma_oct(R_PLAT + 0.9, -0.4, R_PLAT + 0.9, H_PLAT,
                                   tampa=False))

        # anel de sigilos gravado na borda do tampo: 24 riscos de luz
        for k in range(24):
            a = 2 * math.pi * k / 24
            x, z = 8.9 * math.sin(a), 8.9 * math.cos(a)
            self.m.add_pecas("adro", "sigilo",
                             [caixa_girada(x, H_PLAT + 0.01, z, 0.9, 0.04, 0.22,
                                           a)])
            if k % 6 == 0:
                self.pontos["sigilos"].append([round(x, 2), H_PLAT + 0.3, round(z, 2)])

        # as quatro rampas, nos eixos
        for k in range(4):
            ang = k * math.pi / 2
            ca, sa = math.cos(ang), math.sin(ang)
            def p(u, w, y):
                # u = pra fora do centro, w = lateral
                return (u * sa + w * ca, y, u * ca - w * sa)
            meia = W_RAMPA / 2.0
            # A rampa e' DUAS pecas: o tablado inclinado, que termina exatamente
            # na borda do adro, e uma LINGUETA plana que entra 60 cm por baixo
            # da coroa. Sem a lingueta sobra uma fresta entre as duas — e uma
            # fresta de 25 cm no alto de uma rampa e' onde o jogador trava e
            # so' passa pulando.
            v = [p(AP_ADRO, -meia, H_PLAT), p(AP_ADRO, meia, H_PLAT),
                 p(R_RAMPA, meia, 0.0), p(R_RAMPA, -meia, 0.0)]
            base = [(q[0], -0.4, q[2]) for q in v]
            self.m.add_pecas("adro", "pedra", [hexaedro(base + v)])
            self.col.append(hexaedro(base + v))

            vl = [p(AP_LINGUETA, -meia, H_PLAT), p(AP_LINGUETA, meia, H_PLAT),
                  p(AP_ADRO, meia, H_PLAT), p(AP_ADRO, -meia, H_PLAT)]
            basel = [(q[0], -0.4, q[2]) for q in vl]
            self.col.append(hexaedro(basel + vl))
            # O DESENHO da lingueta fica 2 cm mais baixo que a colisao. Ela
            # mora POR BAIXO do tampo do adro, e as duas no mesmo plano
            # brigavam no z-buffer bem no alto da rampa — que e' justamente
            # por onde o jogador sobe.
            vlv = [(q[0], H_PLAT - 0.02, q[2]) for q in vl]
            self.m.add_pecas("adro", "pedra", [hexaedro(basel + vlv)])
            # murete dos dois lados da rampa, pra ela ler de longe
            for s in (-1, 1):
                a0 = p(AP_LINGUETA, s * meia, 0.0)
                a1 = p(R_RAMPA, s * meia, 0.0)
                murete = hexaedro([(a0[0], -0.3, a0[2]), (a1[0], -0.3, a1[2]),
                                   (a1[0] + s * ca * 0.5, -0.3, a1[2] - s * sa * 0.5),
                                   (a0[0] + s * ca * 0.5, -0.3, a0[2] - s * sa * 0.5),
                                   (a0[0], H_PLAT + 0.45, a0[2]), (a1[0], 0.45, a1[2]),
                                   (a1[0] + s * ca * 0.5, 0.45, a1[2] - s * sa * 0.5),
                                   (a0[0] + s * ca * 0.5, H_PLAT + 0.45, a0[2] - s * sa * 0.5)])
                self.m.add_pecas("adro", "pedra_esc", [murete])
                # com colisao: sem ela o jogador atravessa o murete e cai da
                # rampa pelo lado, e a peca vira enfeite que mente
                self.col.append(murete)

        # colisao do tampo: a MESMA coroa do visual, so' que grossa. O furo
        # do meio e' fechado pela casca da tigela, la' na `boca()`.
        self.col.append(coroa_oct(R_BOCA, R_PLAT + 0.9, H_PLAT, esp=0.6))

        # quatro cotos de pilar no tampo: sobrou isso do cimborio
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            x, z = 7.4 * math.sin(a), 7.4 * math.cos(a)
            alt = self.rnd.uniform(2.2, 4.6)
            pecas, _ = pilar_composto(x, z, H_PLAT, H_PLAT + alt, r_nucleo=0.5,
                                      r_colunete=0.16, n_colunetes=6)
            self.m.add_pecas("adro", "pedra", pecas)
            self.col.append(cilindro(x, z, 1.15, H_PLAT, H_PLAT + alt, n=8))
            self.bloquear(x, z, 1.5)
            self.m.add_pecas("adro", "pedra_esc",
                             self._pedras(x + self.rnd.uniform(-1.5, 1.5), z + self.rnd.uniform(-1.5, 1.5),
                                          1.6, 7, y=H_PLAT, tamanho=(0.3, 0.8)))

    def boca(self):
        """A BOCA: a cratera de carne no meio do adro.

        Uma GRELHA de ferro fecha a cratera no nivel do adro: por cima dela
        se anda e se luta como em qualquer outro pedaco do mapa, e por entre as
        barras se ve' a carne, os dentes e a brasa dois metros abaixo. O meio
        da arena e' o ponto alto do mapa — bloquea-lo seria jogar fora o unico
        lugar que domina os quatro lados.

        O preco de passar por ali esta' no `battlefield_2.gd`: de tempos em
        tempos, sem hora marcada, a coisa embaixo cospe fogo pelas barras.
        """
        aneis = [(R_BOCA, H_PLAT + 0.02), (4.0, H_PLAT - 0.62),
                 (2.9, H_PLAT - 1.26), (1.8, H_PLAT - 1.72),
                 (0.85, H_PLAT - 1.95)]
        n = 20
        for i in range(len(aneis) - 1):
            (r0, y0), (r1, y1) = aneis[i], aneis[i + 1]
            for k in range(n):
                a0 = 2 * math.pi * k / n
                a1 = 2 * math.pi * (k + 1) / n
                j0 = 0.09 * math.sin(a0 * 5) * (i + 1)
                j1 = 0.09 * math.sin(a1 * 5) * (i + 1)
                q = [(r0 * math.sin(a0), y0 + j0, r0 * math.cos(a0)),
                     (r0 * math.sin(a1), y0 + j1, r0 * math.cos(a1)),
                     (r1 * math.sin(a1), y1 + j1, r1 * math.cos(a1)),
                     (r1 * math.sin(a0), y1 + j0, r1 * math.cos(a0))]
                self.m.add("boca", "carne", q, [[0, 1, 2, 3]], suave=True)
        fundo = [(0.85 * math.sin(2 * math.pi * k / n), H_PLAT - 1.97,
                  0.85 * math.cos(2 * math.pi * k / n)) for k in range(n)]
        self.m.add("boca", "brasa", fundo, [list(range(n))])
        self.pontos["brasas"].append([0.0, H_PLAT - 1.5, 0.0])
        self.pontos["boca"] = [0.0, H_PLAT - 1.2, 0.0]
        # de onde o jato de fogo sai: em cima das barras, nao no fundo do poco
        self.pontos["fogareu"] = [0.0, round(H_PLAT + 0.08, 2), 0.0]

        # colisao: a mesma superficie, virada solido. O tampo do adro ja' tem
        # o furo no mesmo raio, entao a casca fecha exatamente o vao.
        self.col.append(casca_aneis(aneis + [(0.05, H_PLAT - 1.97)], 0.5, n=n))
        self.grelha()

        # DENTES POR BAIXO DA GRELHA, apontando pra cima.
        #
        # Eles moravam na borda da cratera, em pe' no caminho de quem atravessa
        # o adro. Com a grelha, aquele anel virou piso — espinho de 2 m ali e'
        # ou tranco de colisao ou peca que o jogador atravessa. Encostados na
        # parede da tigela, com a ponta parando logo abaixo das barras, eles
        # ficam sendo exatamente o que tem de ser: o que se ve' pelo vao.
        for k in range(18):
            a = 2 * math.pi * k / 18 + 0.1
            r = self.rnd.uniform(3.4, 4.3)
            bx, bz = r * math.sin(a), r * math.cos(a)
            by = H_PLAT - 0.62 - (4.0 - r) * 0.58
            alt = self.rnd.uniform(0.5, 1.4)
            px = bx - math.sin(a) * alt * 0.55
            pz = bz - math.cos(a) * alt * 0.55
            self.m.add_pecas("boca", "osso",
                             [espinho((bx, by, bz),
                                      (px, min(by + alt, H_PLAT - 0.22), pz),
                                      self.rnd.uniform(0.14, 0.28))])

        # veias que escorrem da boca pro chao do adro
        for k in range(9):
            a = 2 * math.pi * k / 9 + 0.35
            pts = []
            r = R_BOCA + 0.4
            while r < 10.6:
                pts.append((r * math.sin(a + 0.03 * r), H_PLAT + 0.05 + 0.05 * math.sin(r),
                            r * math.cos(a + 0.03 * r)))
                r += 1.1
            # rasas: o adro agora e' piso de luta inteiro, e veia de 30 cm
            # de raio no meio dele e' tranco no pe' do jogador
            raios = [max(0.04, 0.17 - 0.017 * i) for i in range(len(pts))]
            self.m.add_pecas("boca", "carne", [tubo_redondo(pts, raios, n=6)],
                             suave=True)

    def grelha(self):
        """A grade de ferro que fecha a Boca no nivel do adro.

        Barra chata de verdade (secao deitada, 12 x 8 cm), radial e em aneis,
        com um aro grosso na borda. A colisao NAO acompanha as barras: e' um
        disco liso no nivel do adro. Andar em cima de dezesseis prismas
        separados e' o caminho curto pro personagem tropecar a cada passo.
        """
        yg = H_PLAT + 0.04
        n_aro = 28

        # aro da borda, assentado na coroa do adro
        aro = [(( R_BOCA + 0.12) * math.sin(2 * math.pi * k / n_aro), yg - 0.02,
                (R_BOCA + 0.12) * math.cos(2 * math.pi * k / n_aro))
               for k in range(n_aro + 1)]
        self.m.add_pecas("boca", "metal", [tubo(aro, 0.34, 0.26)])

        # barras radiais
        for k in range(16):
            a = 2 * math.pi * k / 16
            p0 = (0.42 * math.sin(a), yg, 0.42 * math.cos(a))
            p1 = ((R_BOCA + 0.05) * math.sin(a), yg, (R_BOCA + 0.05) * math.cos(a))
            self.m.add_pecas("boca", "metal", [tubo([p0, p1], 0.12, 0.08)])

        # aneis concentricos travando as radiais
        for r in (1.7, 3.0, 4.2):
            anel = [(r * math.sin(2 * math.pi * k / 24), yg,
                     r * math.cos(2 * math.pi * k / 24)) for k in range(25)]
            self.m.add_pecas("boca", "metal", [tubo(anel, 0.10, 0.07)])

        # cubo do meio: e' por ele que o fogo sai
        self.m.add_pecas("boca", "metal",
                         [cilindro(0.0, 0.0, 0.5, yg - 0.09, yg + 0.05, n=12)])

        # colisao: um disco liso, no nivel do piso do adro
        self.col.append(cilindro(0.0, 0.0, R_BOCA + 0.2, H_PLAT - 0.12,
                                 H_PLAT + 0.05, n=16))

    # ------------------------------------------------------------------
    # o anel de ruina: oito modulos, um por lado do octogono
    #
    # Cada modulo trabalha em coordenadas do PROPRIO lado: `u` corre ao longo
    # do muro, `w` e' a espessura (0 = face de dentro, positivo = pra fora) e
    # `y` e' altura. E' o `mapa_girado` da igreja que traduz isso pro mundo —
    # a mesma funcao que monta os panos da abside.

    def _bloco(self, setor, mapa, u0, u1, y0, y1, w0, w1, mat="pedra"):
        self.m.add_pecas(setor, mat, painel(mapa, u0, u1, y0, y1, w0, w1, []))

    def _topo_ruina(self, setor, mapa, u0, u1, y_base, y_max, w0, w1,
                    mat="pedra", passo=1.7):
        """Coroamento quebrado: em vez de o muro terminar reto, ele termina
        numa serra de blocos de altura sorteada. E' o que separa 'muro baixo'
        de 'muro que caiu'."""
        u = u0
        while u < u1 - 0.2:
            du = min(passo * self.rnd.uniform(0.6, 1.5), u1 - u)
            alt = y_base + (y_max - y_base) * (self.rnd.random() ** 1.7)
            if alt > y_base + 0.15:
                ww0 = w0 + self.rnd.uniform(-0.12, 0.12)
                ww1 = w1 + self.rnd.uniform(-0.12, 0.12)
                self._bloco(setor, mapa, u, u + du * 0.94, y_base, alt, ww0, ww1, mat)
            u += du

    def anel_de_ruina(self):
        modulos = [self._brecha, self._arcada, self._torre, self._torre_caida,
                   self._fachada, self._costelas, self._contrafortes, self._carne]
        for k in range(8):
            th = k * math.pi / 4
            px, pz = R_ANEL * math.sin(th), R_ANEL * math.cos(th)
            modulos[k]("anel_%d" % k, mapa_girado(px, pz, -th), th, px, pz)

    # ---- 0 (S): a brecha por onde o jogador entra ---------------------

    def _brecha(self, setor, mapa, th, px, pz):
        for s in (-1, 1):
            self._bloco(setor, mapa, s * 6.5, s * (LADO_U + 1), 0.0, 11.0, 0.0, 2.6)
            self._topo_ruina(setor, mapa, min(s * 6.5, s * (LADO_U + 1)),
                             max(s * 6.5, s * (LADO_U + 1)), 11.0, 15.5, 0.1, 2.5)
            # pilastra do portao, partida em altura diferente de cada lado
            alt = 13.5 if s < 0 else 9.0
            self._bloco(setor, mapa, s * 4.6, s * 7.2, 0.0, alt, -0.9, 3.4)
            self._topo_ruina(setor, mapa, min(s * 4.6, s * 7.2), max(s * 4.6, s * 7.2),
                             alt, alt + 2.6, -0.8, 3.3, "pedra_esc", passo=1.1)

        # a rampa de escombro que desce da brecha pra dentro da praca
        for i in range(7):
            u = self.rnd.uniform(-4.2, 4.2)
            w = self.rnd.uniform(-5.0, 1.5)
            p = mapa(u, 0.0, w)
            self.m.add_pecas(setor, "pedra_esc",
                             self._pedras(p[0], p[2], 2.4, 9, tamanho=(0.5, 1.5),
                                     altura_pilha=1.1))
        p = mapa(0.0, 0.0, -1.5)
        self._monte(setor, p[0], p[2], 6.5, 1.6)

        # grade de vergalhao tombada na entrada — a porta que nao segurou
        base = mapa(-3.0, 0.0, -3.2)
        for i in range(11):
            t = i / 10.0
            a = mapa(-3.4 + t * 7.0, 0.25, -3.6)
            b = mapa(-2.6 + t * 7.0, 2.6, -7.4)
            self.m.add_pecas(setor, "metal", [tubo_redondo([a, b], [0.07, 0.07], n=5)])
        for i in range(3):
            a = mapa(-3.6, 0.9 + i * 0.75, -4.8 - i * 1.2)
            b = mapa(4.0, 0.9 + i * 0.75, -4.8 - i * 1.2)
            self.m.add_pecas(setor, "metal", [tubo_redondo([a, b], [0.09, 0.09], n=5)])
        self.bloquear(base[0], base[2], 4.5)

        for s in (-1, 1):
            p = mapa(s * 9.0, 0.0, -2.0)
            self.prop("barreira", p[0], p[2], giro=th + math.pi / 2)
            p = mapa(s * 12.0, 0.0, -1.0)
            self.prop("barreira", p[0], p[2], giro=th + 0.3)
        p = mapa(6.0, 0.0, -4.5)
        self.pontos["fogos"].append([round(p[0], 2), 0.0, round(p[2], 2)])

    # ---- 1 (SE): arcada meio derrubada --------------------------------

    def _arcada(self, setor, mapa, th, px, pz):
        self._bloco(setor, mapa, -LADO_U - 1, LADO_U + 1, 0.0, 9.0, 1.8, 3.6)
        self._topo_ruina(setor, mapa, -LADO_U - 1, LADO_U + 1, 9.0, 13.0, 1.8, 3.6)

        vaos = []
        vivos = (0, 1, 3, 5)
        for k in range(6):
            uc = -14.0 + k * 5.6
            if k in vivos:
                vaos.append({"u": uc, "larg": 4.2, "peitoril": 0.0,
                             "arranque": 5.2, "flecha": 3.4})
            else:
                # arco que morreu: so' o arranque de cada lado, no ar
                self._bloco(setor, mapa, uc - 2.4, uc - 1.4, 5.2, 7.4, -0.5, 1.9,
                            "pedra_esc")
                p = mapa(uc, 0.0, 0.4)
                self.m.add_pecas(setor, "pedra_esc",
                                 self._pedras(p[0], p[2], 3.0, 14,
                                         tamanho=(0.45, 1.5), altura_pilha=1.6))
                self._monte(setor, p[0], p[2], 3.4, 1.8)
                self.bloquear(p[0], p[2], 3.0)
        self.m.add_pecas(setor, "pedra",
                         painel(mapa, -LADO_U - 1, LADO_U + 1, 0.0, 12.0, -0.5, 1.9, vaos))
        for v in vaos:
            self.m.add_pecas(setor, "pedra",
                             arquivolta(v["u"], v["larg"] + 0.7, v["arranque"],
                                        v["flecha"] + 0.35, 0.4, -0.75, 2.15, mapa))
        self._topo_ruina(setor, mapa, -LADO_U - 1, LADO_U + 1, 12.0, 15.0, -0.5, 1.9)

        # os pilares da arcada, ja' dentro da praca
        for k in range(7):
            uc = -16.8 + k * 5.6
            p = mapa(uc, 0.0, 0.7)
            if k == 2:
                continue
            alt = 5.2 if k not in (4,) else 3.1
            pecas, _ = pilar_composto(p[0], p[2], 0.0, alt, r_nucleo=0.55,
                                      r_colunete=0.18, n_colunetes=6)
            self.m.add_pecas(setor, "pedra", pecas)
            self.col.append(cilindro(p[0], p[2], 1.2, -0.5, alt, n=8))
            self.bloquear(p[0], p[2], 1.4)
        p = mapa(-8.0, 0.0, -3.0)
        self.prop("carro", p[0], p[2], giro=th + 0.4)
        self.bloquear(p[0], p[2], 2.6)
        p = mapa(9.5, 0.0, -2.4)
        self.pontos["fogos"].append([round(p[0], 2), 0.0, round(p[2], 2)])

    # ---- 2 (E): a torre que ficou de pe' ------------------------------

    def _torre(self, setor, mapa, th, px, pz):
        self._bloco(setor, mapa, -LADO_U - 1, -5.0, 0.0, 10.0, 0.0, 2.6)
        self._topo_ruina(setor, mapa, -LADO_U - 1, -5.0, 10.0, 14.0, 0.0, 2.6)
        self._bloco(setor, mapa, 5.0, LADO_U + 1, 0.0, 8.0, 0.0, 2.6)
        self._topo_ruina(setor, mapa, 5.0, LADO_U + 1, 8.0, 12.5, 0.0, 2.6)

        # a torre: pilha de faixas, cada uma deslocada — e' assim que ela
        # ganha a inclinacao sem eu ter de girar nada.
        faixas = 15
        alt_f = 2.1
        for i in range(faixas):
            y0 = i * alt_f
            y1 = y0 + alt_f
            desl = 0.055 * i * i * 0.12
            recuo = 0.10 * i
            u0, u1 = -5.4 + recuo * 0.25, 5.4 - recuo * 0.25
            w0, w1 = -1.2 + desl, 5.6 + desl
            if i >= faixas - 3:
                # o coroamento ja' esta' comido
                self._topo_ruina(setor, mapa, u0, u1, y0, y1 + 1.2, w0, w1,
                                 "pedra_esc", passo=1.3)
                continue
            if i in (10, 11):
                # o campanario: quatro lancetas altas
                vaos = [{"u": -2.6, "larg": 1.9, "peitoril": y0, "arranque": y0 + 1.5,
                         "flecha": 1.3},
                        {"u": 2.6, "larg": 1.9, "peitoril": y0, "arranque": y0 + 1.5,
                         "flecha": 1.3}]
                self.m.add_pecas(setor, "pedra",
                                 painel(mapa, u0, u1, y0, y1, w0, w1, vaos))
                continue
            if i == 6:
                vaos = [{"u": 0.0, "larg": 1.6, "peitoril": y0 + 0.4,
                         "arranque": y0 + 1.4, "flecha": 1.0}]
                self.m.add_pecas(setor, "pedra",
                                 painel(mapa, u0, u1, y0, y1, w0, w1, vaos))
                continue
            self._bloco(setor, mapa, u0, u1, y0, y1, w0, w1)
            if i % 3 == 0:
                self._bloco(setor, mapa, u0 - 0.35, u1 + 0.35, y1 - 0.4, y1,
                            w0 - 0.35, w1 + 0.35, "pedra_esc")
        # colisao da torre: uma caixa so', reta
        p = mapa(0.0, 0.0, 2.2)
        self.col.append(caixa_girada(p[0], 15.0, p[2], 11.5, 32.0, 7.0, th))
        self.bloquear(p[0], p[2], 7.0)
        p = mapa(-2.0, 0.0, -3.6)
        self.m.add_pecas(setor, "pedra_esc",
                         self._pedras(p[0], p[2], 4.5, 22, tamanho=(0.5, 1.8),
                                 altura_pilha=2.0))
        self._monte(setor, p[0], p[2], 5.0, 2.2, n=12)
        self.bloquear(p[0], p[2], 4.2)

    # ---- 3 (NE): a torre que caiu pra dentro da arena -----------------

    def _torre_caida(self, setor, mapa, th, px, pz):
        self._bloco(setor, mapa, -LADO_U - 1, LADO_U + 1, 0.0, 7.0, 0.0, 2.8)
        self._topo_ruina(setor, mapa, -LADO_U - 1, LADO_U + 1, 7.0, 11.0, 0.0, 2.8)
        # o coto de onde ela se soltou
        self._bloco(setor, mapa, -4.5, 4.5, 0.0, 9.5, -0.6, 5.0)
        self._topo_ruina(setor, mapa, -4.5, 4.5, 9.5, 12.5, -0.6, 5.0, "pedra_esc",
                         passo=1.2)

        # deitada, apontando pro centro da praca, em tres pedacos.
        #
        # O giro e' `th + pi`: e' o que poe o Z LOCAL da caixa na direcao do
        # centro da arena. Com `-th` (o giro de muro) as secoes saiam
        # atravessadas, e a torre caida virava tres caixotes soltos no chao.
        dirx, dirz = -math.sin(th), -math.cos(th)
        perpx, perpz = -dirz, dirx
        # OS VAOS ENTRE AS SECOES sao 3,5 m, e nao 1,3 m. Deitada, a torre
        # atravessa o quadrante inteiro e era a unica direcao da arena em que
        # nao dava pra dar a volta: virava um muro de 24 m. Com vao de 3,5 m
        # da' pra passar ENTRE os pedacos, e com a escadaria do `parkour` da'
        # pra subir e correr POR CIMA dela.
        secoes = [(2.0, 9.5, 5.0), (13.0, 18.0, 4.6), (21.5, 25.5, 4.0)]
        for i, (d0, d1, lado) in enumerate(secoes):
            desvio = (i - 1) * 1.7
            comp = d1 - d0
            dm = (d0 + d1) / 2.0
            cx = px + dirx * dm + perpx * desvio
            cz = pz + dirz * dm + perpz * desvio
            cy = lado / 2 - 1.7
            g = th + math.pi + self.rnd.uniform(-0.10, 0.10)
            self.m.add_pecas(setor, "pedra",
                             [caixa_girada(cx, cy, cz, lado, lado, comp, g)])
            self.col.append(caixa_girada(cx, cy, cz, lado, lado, comp, g))
            for t in (0.12, 0.5, 0.88):
                ex = px + dirx * (d0 + comp * t) + perpx * desvio
                ez = pz + dirz * (d0 + comp * t) + perpz * desvio
                self.m.add_pecas(setor, "pedra_esc",
                                 [caixa_girada(ex, cy, ez, lado + 0.5, lado + 0.5,
                                               0.55, g)])
            # as frestas do campanario, agora viradas pro ceu
            for t in (0.3, 0.68):
                for sgn in (-1, 1):
                    wx = px + dirx * (d0 + comp * t) + perpx * (desvio + sgn * lado * 0.24)
                    wz = pz + dirz * (d0 + comp * t) + perpz * (desvio + sgn * lado * 0.24)
                    self.m.add_pecas(setor, "pedra_esc",
                                     [caixa_girada(wx, cy + lado / 2 - 0.04, wz,
                                                   0.55, 0.28, 1.6, g)])
            # bloqueio mais justo (0,6 em vez de 0,7 do lado) pro navmesh
            # tambem achar os vaos novos entre as secoes
            for t in (0.25, 0.5, 0.75):
                self.bloquear(px + dirx * (d0 + comp * t) + perpx * desvio,
                              pz + dirz * (d0 + comp * t) + perpz * desvio,
                              lado * 0.6)
            self.m.add_pecas(setor, "pedra_esc",
                             self._pedras(cx + perpx * lado, cz + perpz * lado, 3.0, 10,
                                          tamanho=(0.4, 1.2)))

        # a ponta arrebentou: sobrou a casca, e da' pra ver os pisos caidos
        # la' dentro. E' o unico lugar da arena que mostra a torre POR DENTRO.
        lado = secoes[-1][2]
        dpf = secoes[-1][1] + 2.4
        g = th + math.pi
        fx = px + dirx * dpf + perpx * 1.7
        fz = pz + dirz * dpf + perpz * 1.7
        cy = lado / 2 - 1.7
        for sgn in (-1, 1):
            self.m.add_pecas(setor, "pedra",
                             [caixa_girada(fx + perpx * sgn * (lado / 2 - 0.3), cy,
                                           fz + perpz * sgn * (lado / 2 - 0.3),
                                           0.6, lado * self.rnd.uniform(0.55, 0.95),
                                           4.6, g)])
        self.m.add_pecas(setor, "pedra",
                         [caixa_girada(fx, cy - lado / 2 + 0.3, fz, lado, 0.6, 4.6, g)])
        for k in range(2):
            self.m.add_pecas(setor, "pedra_esc",
                             [caixa_girada(fx + perpx * 0.5 * k, cy - 0.5 + k * 1.3,
                                           fz + perpz * 0.5 * k, lado * 0.8, 0.35,
                                           2.6, g, self.rnd.uniform(-0.45, 0.45))])
        self.col.append(caixa_girada(fx, cy, fz, lado, lado, 4.6, g))
        self.bloquear(fx, fz, lado * 0.8)
        # a ponta da torre e' o alto mais facil da arena (2,3 m): marca ela
        # pro `parkour` encostar uma escadaria, vinda do centro da praca
        self.escaladas.append((fx, fz, perpx, perpz, cy + lado / 2.0))
        self.m.add_pecas(setor, "pedra_esc",
                         self._pedras(fx + dirx * 3.0, fz + dirz * 3.0, 4.0, 14,
                                 tamanho=(0.4, 1.4), altura_pilha=1.2))

        p = (px + dirx * 16.0, pz + dirz * 16.0)
        self.pontos["fogos"].append([round(p[0], 2), 0.0, round(p[1], 2)])
        self.prop("pneu", px + dirx * 9.0 + 3.0, pz + dirz * 9.0)
        self.prop("tambor", px + dirx * 20.0, pz + dirz * 20.0 + 2.5)

    # ---- 4 (N): a fachada com a rosacea ------------------------------
    #
    # E' a peca que o jogador ve' de frente ao nascer na brecha, do outro lado
    # da praca. Tudo aqui foi dimensionado pra ela LER a 80 m: vao central de
    # 8 m, rosacea de 9 m de diametro, e as duas torres de canto em alturas
    # diferentes pra silhueta nao ficar simetrica.

    def _rosacea(self, setor, mapa, uc, yc, raio, w0, w1, colunas=18):
        """Janela circular: o macico da parede e' fechado COLUNA A COLUNA em
        volta do circulo, entao o furo sai redondo de verdade sem booleano."""
        for i in range(colunas):
            u0 = uc - raio + 2 * raio * i / colunas
            u1 = uc - raio + 2 * raio * (i + 1) / colunas
            um = (u0 + u1) / 2 - uc
            h = math.sqrt(max(raio * raio - um * um, 0.0))
            if yc - raio < yc - h:
                self._bloco(setor, mapa, u0, u1, yc - raio, yc - h, w0, w1)
            if yc + h < yc + raio:
                self._bloco(setor, mapa, u0, u1, yc + h, yc + raio, w0, w1)
        # aro e rendilhado
        n = 30
        for k in range(n):
            a0 = 2 * math.pi * k / n
            a1 = 2 * math.pi * (k + 1) / n
            for rr, esp in ((raio, 0.55), (raio * 0.42, 0.3)):
                p0 = (uc + rr * math.cos(a0), yc + rr * math.sin(a0))
                p1 = (uc + rr * math.cos(a1), yc + rr * math.sin(a1))
                v = [mapa(p0[0], p0[1] - esp / 2, w0 - 0.2), mapa(p1[0], p1[1] - esp / 2, w0 - 0.2),
                     mapa(p1[0], p1[1] - esp / 2, w1 + 0.2), mapa(p0[0], p0[1] - esp / 2, w1 + 0.2),
                     mapa(p0[0], p0[1] + esp / 2, w0 - 0.2), mapa(p1[0], p1[1] + esp / 2, w0 - 0.2),
                     mapa(p1[0], p1[1] + esp / 2, w1 + 0.2), mapa(p0[0], p0[1] + esp / 2, w1 + 0.2)]
                self.m.add_pecas(setor, "pedra", [hexaedro(v)])
        for k in range(12):
            a = 2 * math.pi * k / 12
            if k in (3, 4):
                continue          # dois raios ja' se foram
            p0 = (uc + raio * 0.42 * math.cos(a), yc + raio * 0.42 * math.sin(a))
            p1 = (uc + raio * math.cos(a), yc + raio * math.sin(a))
            v = [mapa(p0[0], p0[1], w0), mapa(p1[0], p1[1], w0),
                 mapa(p1[0], p1[1], w1), mapa(p0[0], p0[1], w1),
                 mapa(p0[0] + 0.22, p0[1] + 0.22, w0), mapa(p1[0] + 0.22, p1[1] + 0.22, w0),
                 mapa(p1[0] + 0.22, p1[1] + 0.22, w1), mapa(p0[0] + 0.22, p0[1] + 0.22, w1)]
            self.m.add_pecas(setor, "pedra", [hexaedro(v)])

    def _fachada(self, setor, mapa, th, px, pz):
        w0, w1 = 0.0, 3.2
        portal = {"u": 0.0, "larg": 8.0, "peitoril": 0.0, "arranque": 7.5,
                  "flecha": 6.0}
        lancetas = [{"u": s * 10.5, "larg": 3.0, "peitoril": 4.0,
                     "arranque": 9.0, "flecha": 2.4} for s in (-1, 1)]
        self.m.add_pecas(setor, "pedra",
                         painel(mapa, -LADO_U - 1, LADO_U + 1, 0.0, 15.5, w0, w1,
                                [portal] + lancetas))
        self.m.add_pecas(setor, "pedra",
                         arquivolta(0.0, 9.2, 7.5, 6.6, 0.55, w0 - 0.35, w1 + 0.35, mapa))
        for v in lancetas:
            self.m.add_pecas(setor, "pedra",
                             arquivolta(v["u"], v["larg"] + 0.6, v["arranque"],
                                        v["flecha"] + 0.3, 0.35, w0 - 0.25, w1 + 0.25, mapa))
        # faixa da rosacea
        self._bloco(setor, mapa, -LADO_U - 1, -5.4, 15.5, 25.0, w0, w1)
        self._bloco(setor, mapa, 5.4, LADO_U + 1, 15.5, 25.0, w0, w1)
        self._rosacea(setor, mapa, 0.0, 20.2, 4.6, w0, w1)
        self._bloco(setor, mapa, -5.4, 5.4, 24.8, 26.2, w0 - 0.4, w1 + 0.4, "pedra_esc")
        self._topo_ruina(setor, mapa, -LADO_U - 1, LADO_U + 1, 25.0, 29.5, w0, w1)

        # torres de canto, alturas diferentes de proposito
        for s, alt in ((-1, 34.0), (1, 24.0)):
            u = s * 15.0
            for i in range(int(alt / 2.2)):
                y0 = i * 2.2
                self._bloco(setor, mapa, u - 3.0, u + 3.0, y0, y0 + 2.2,
                            w0 - 1.2, w1 + 1.2)
                if i % 4 == 3:
                    self._bloco(setor, mapa, u - 3.4, u + 3.4, y0 + 1.8, y0 + 2.2,
                                w0 - 1.6, w1 + 1.6, "pedra_esc")
            self._topo_ruina(setor, mapa, u - 3.0, u + 3.0, alt, alt + 4.5,
                             w0 - 1.2, w1 + 1.2, "pedra_esc", passo=1.2)
            # a caixa segue o MESMO w das faixas desenhadas (w0-1,2 a w1+1,2):
            # com 7 m centrados em w=1,0 ela entrava 1,3 m a mais na praca que
            # a pedra, e ali era parede invisivel
            p = mapa(u, 0.0, (w0 - 1.2 + w1 + 1.2) / 2.0)
            self.col.append(caixa_girada(p[0], alt / 2, p[2], 6.2, alt,
                                         w1 - w0 + 2.6, -th))

        # o que caiu da fachada esta' no chao, embaixo dela
        for i in range(5):
            p = mapa(self.rnd.uniform(-13, 13), 0.0, self.rnd.uniform(-6.5, -1.0))
            self.m.add_pecas(setor, "pedra_esc",
                             self._pedras(p[0], p[2], 3.2, 13,
                                     tamanho=(0.5, 1.7), altura_pilha=1.4))
            self._monte(setor, p[0], p[2], 3.6, 1.5)
            self.bloquear(p[0], p[2], 3.0)
        p = mapa(0.0, 0.0, -8.0)
        self.pontos["fogos"].append([round(p[0], 2), 0.0, round(p[2], 2)])

    # ---- 5 (NW): a colunata de costelas -------------------------------

    def _costelas(self, setor, mapa, th, px, pz):
        self._bloco(setor, mapa, -LADO_U - 1, LADO_U + 1, 0.0, 6.0, 0.0, 2.4)
        self._topo_ruina(setor, mapa, -LADO_U - 1, LADO_U + 1, 6.0, 10.0, 0.0, 2.4)

        # sete costelas fincadas no chao, em fila, cada uma mais baixa
        for k in range(7):
            u = -13.5 + k * 4.5
            # arco BAIXO e GROSSO. Alto e fino (era 16 m com 0,55 de raio)
            # vira bengala: parece cajado de plastico espetado na praca, nao
            # costela de bicho de 60 m.
            alt = 11.0 - abs(k - 2) * 1.1 + self.rnd.uniform(-0.8, 0.8)
            a = mapa(u - 0.8, -1.2, -0.5)
            b = mapa(u + 2.4, -1.2, -16.0 - k * 0.7)
            pts = arco_pontos(a, b, alt, n=14, torcao=0.9)
            raios = [0.90 - 0.48 * (i / 14.0) for i in range(15)]
            self.m.add_pecas(setor, "osso", [tubo_redondo(pts, raios, n=8)],
                             suave=True)
            # quem barra o jogador e' o PE' da costela, nao a curva la' em cima
            for i in (1, 12):
                pe = pts[i]
                # cilindro da grossura do osso, e nao uma caixa de 6 m: a
                # caixa subia 5 m acima do chao com tubo nenhum em volta, e
                # virava parede invisivel no meio da passagem
                self.col.append(cilindro(pe[0], pe[2], 0.9, -0.6,
                                         min(max(pe[1], 0.0) + 1.4, 2.4), n=8))
                self.bloquear(pe[0], pe[2], 1.2)
            # vertebra solta ao pe' da costela
            p = mapa(u + self.rnd.uniform(-1.5, 1.5), 0.0, -3.0)
            self.m.add_pecas(setor, "osso",
                             [cilindro(p[0], p[2], 0.7, 0.0, 0.5, n=7),
                              cilindro(p[0], p[2], 0.35, 0.5, 1.1, n=7)])
        # a coisa tambem deixou carne aqui: musculo esticado entre duas costelas
        for k in (1, 4):
            u = -13.5 + k * 4.5
            a = mapa(u, 7.0, -4.0)
            b = mapa(u + 4.5, 6.0, -5.5)
            self.m.add_pecas(setor, "carne",
                             [tubo_redondo([a, ((a[0] + b[0]) / 2, 5.2, (a[2] + b[2]) / 2), b],
                                           [0.30, 0.45, 0.30], n=6)], suave=True)
        p = mapa(6.0, 0.0, -6.0)
        self.pontos["fogos"].append([round(p[0], 2), 0.0, round(p[2], 2)])

    # ---- 6 (W): clerestorio e contrafortes virados pra dentro ---------

    def _contrafortes(self, setor, mapa, th, px, pz):
        w0, w1 = 0.0, 2.6
        vaos = [{"u": -12.0 + k * 6.0, "larg": 2.6, "peitoril": 6.5,
                 "arranque": 10.0, "flecha": 2.2} for k in range(5)]
        self.m.add_pecas(setor, "pedra",
                         painel(mapa, -LADO_U - 1, LADO_U + 1, 0.0, 17.0, w0, w1, vaos))
        for v in vaos:
            self.m.add_pecas(setor, "pedra",
                             arquivolta(v["u"], v["larg"] + 0.5, v["arranque"],
                                        v["flecha"] + 0.25, 0.3, w0 - 0.22, w1 + 0.22, mapa))
        self._topo_ruina(setor, mapa, -LADO_U - 1, LADO_U + 1, 17.0, 21.0, w0, w1)

        # o arcobotante entra na PRACA: e' pilar pra correr em volta, nao
        # enfeite de fundo. Por isso a pilastra fica em w = -7,5.
        for k in range(5):
            u = -12.0 + k * 6.0
            if k == 3:
                continue     # este ja' desabou; o entulho conta a historia
            alt_pil = 5.0 + (k % 2) * 0.8
            pb = mapa(u, 0.0, -7.5)
            # o fuste para 6 cm antes do capitel: rente, as duas faces de
            # cima ficavam no mesmo plano e a pedra piscava
            self.m.add_pecas(setor, "pedra",
                             [caixa((pb[0] - 1.1, -0.4, pb[2] - 1.1),
                                    (pb[0] + 1.1, alt_pil - 0.06, pb[2] + 1.1))])
            self.m.add_pecas(setor, "pedra_esc",
                             [caixa((pb[0] - 1.4, alt_pil - 0.35, pb[2] - 1.4),
                                    (pb[0] + 1.4, alt_pil, pb[2] + 1.4))])
            # pinaculo em cima da pilastra
            self.m.add_pecas(setor, "pedra",
                             [espinho((pb[0], alt_pil, pb[2]),
                                      (pb[0], alt_pil + 2.6, pb[2]), 0.55, n=4)])
            self.col.append(caixa((pb[0] - 1.3, -0.5, pb[2] - 1.3),
                                  (pb[0] + 1.3, alt_pil, pb[2] + 1.3)))
            self.bloquear(pb[0], pb[2], 1.9)
            # o arco que vai da pilastra ate' o muro alto
            pa = mapa(u, 12.5, -0.2)
            pts = arco_pontos((pb[0], alt_pil, pb[2]), pa, 2.6, n=9)
            self.m.add_pecas(setor, "pedra", [tubo(pts, 0.8, 0.9)])
            self.m.add_pecas(setor, "pedra_esc", [tubo(pts, 0.45, 1.6)])
        p = mapa(6.0, 0.0, -7.5)
        self.m.add_pecas(setor, "pedra_esc",
                         self._pedras(p[0], p[2], 4.0, 18, tamanho=(0.5, 1.6),
                                 altura_pilha=1.8))
        self._monte(setor, p[0], p[2], 4.4, 2.0)
        self.bloquear(p[0], p[2], 3.8)
        p = mapa(-16.0, 0.0, -4.0)
        self.prop("tronco", p[0], p[2], giro=th)
        p = mapa(13.0, 0.0, -5.0)
        self.pontos["fogos"].append([round(p[0], 2), 0.0, round(p[2], 2)])

    # ---- 7 (SW): a muralha sendo digerida -----------------------------

    def _bolha(self, cx, cy, cz, raio, achatar=1.0, nseg=12, nanel=7, ruido=0.18):
        """Massa organica fechada. O ruido e' por VERTICE e deterministico no
        angulo, senao dois aneis vizinhos nao fecham e aparece costura."""
        verts = []
        for i in range(nanel + 1):
            fi = math.pi * i / nanel
            for j in range(nseg):
                te = 2 * math.pi * j / nseg
                r = raio * (1.0 + ruido * math.sin(fi * 3.1 + te * 2.3)
                            + ruido * 0.6 * math.cos(te * 4.7 - fi * 1.7))
                verts.append((cx + r * math.sin(fi) * math.cos(te),
                              cy + r * math.cos(fi) * achatar,
                              cz + r * math.sin(fi) * math.sin(te)))
        faces = []
        for i in range(nanel):
            for j in range(nseg):
                k = (j + 1) % nseg
                faces.append([i * nseg + j, i * nseg + k,
                              (i + 1) * nseg + k, (i + 1) * nseg + j])
        return verts, faces

    def _carne(self, setor, mapa, th, px, pz):
        self._bloco(setor, mapa, -LADO_U - 1, LADO_U + 1, 0.0, 12.0, 0.0, 2.6)
        self._topo_ruina(setor, mapa, -LADO_U - 1, LADO_U + 1, 12.0, 16.0, 0.0, 2.6)
        # dois pilares sobreviveram, e e' neles que o bicho se enrolou
        for u in (-7.0, 6.0):
            p = mapa(u, 0.0, -4.0)
            pecas, _ = pilar_composto(p[0], p[2], 0.0, 11.0, r_nucleo=0.75,
                                      r_colunete=0.22, n_colunetes=8)
            self.m.add_pecas(setor, "pedra", pecas)
            self.col.append(cilindro(p[0], p[2], 1.5, -0.5, 11.0, n=8))
            self.bloquear(p[0], p[2], 1.8)
            # o tentaculo que sobe girando no fuste
            pts, raios = [], []
            for i in range(19):
                t = i / 18.0
                a = t * 4.2 * math.pi
                r = 1.35 - 0.25 * t
                pts.append((p[0] + r * math.cos(a), 0.2 + t * 10.6,
                            p[2] + r * math.sin(a)))
                raios.append(0.42 - 0.24 * t)
            self.m.add_pecas(setor, "carne", [tubo_redondo(pts, raios, n=7)],
                             suave=True)

        # a massa: MUITAS bolhas medias encostadas, e nao tres grandes. Tres
        # esferas lisas de 8 m leem como balao de festa; oito de 3 a 5 m com
        # ruido alto leem como tumor.
        carocos = [(-13.0, -1.0, 4.2), (-9.0, -4.0, 5.0), (-4.5, -1.5, 3.6),
                   (-1.0, -5.0, 5.4), (2.5, -2.0, 4.0), (6.5, -4.5, 4.6),
                   (10.5, -1.5, 3.4), (0.0, -9.0, 3.8)]
        for i, (u, w, r) in enumerate(carocos):
            p = mapa(u, 0.0, w)
            self.m.add_pecas(setor, "carne",
                             [self._bolha(p[0], r * 0.30, p[2], r, achatar=0.72,
                                          nseg=14, nanel=8, ruido=0.30)],
                             suave=True)
            # 0,78 e nao 0,95: a bolha tem ruido de 30% no raio, e um domo do
            # tamanho nominal saia pra fora dela nos pontos em que a casca
            # encolhe — colisao sem nada por cima
            self.col.append(domo(p[0], p[2], r * 0.78, r * 0.70, n=12))
            self.bloquear(p[0], p[2], r * 0.85)
            # bolsas que brilham: na SUPERFICIE da massa, senao ficam
            # engolidas por dentro e nao se ve' luz nenhuma
            for k in range(2):
                a = self.rnd.uniform(0, 2 * math.pi)
                d = r * 0.95
                bx = p[0] + d * math.cos(a)
                bz = p[2] + d * math.sin(a)
                by = r * 0.44
                self.m.add_pecas(setor, "sigilo",
                                 [self._bolha(bx, by, bz, self.rnd.uniform(0.45, 0.85),
                                              nseg=8, nanel=5, ruido=0.28)],
                                 suave=True)
                if k == 0 and i % 3 == 0:
                    self.pontos["brasas"].append([round(bx, 2), round(by, 2), round(bz, 2)])
        # costelas rasgando a massa por dentro
        for k in range(5):
            u = -12.0 + k * 6.0
            a = mapa(u, 0.0, -1.0)
            b = mapa(u + 3.0, 0.0, -9.0)
            pts = arco_pontos(a, b, 7.5 + self.rnd.uniform(-1.5, 2.0), n=10, torcao=1.0)
            raios = [0.34 - 0.2 * abs(i / 10.0 - 0.5) for i in range(11)]
            self.m.add_pecas(setor, "osso", [tubo_redondo(pts, raios, n=6)], suave=True)

    # ------------------------------------------------------------------
    # o que fica solto no meio da praca
    #
    # Regra do lugar: o meio da arena e' ABERTO (e' onde a briga acontece), e
    # a cobertura fica no anel entre o adro e a ruina — raio 20 a 36. Encher o
    # centro de pedra transforma luta em labirinto.

    def _na_fenda(self, x, z, folga=0.0):
        for f in self.fissuras:
            if dist_polilinha(x, z, f["pts"]) < f["larg"] / 2.0 + folga:
                return True
        return False

    def _refazer_grade(self):
        """Rasteriza os bloqueios num quadriculado de 1 m.

        O teste da ronda roda dezenas de vezes por peca sorteada; medindo
        contra a lista de bloqueios crua sao milhoes de raizes quadradas e o
        gerador passa de meio minuto. No quadriculado e' uma busca em `set`.
        """
        self._grade = set()
        for bx, bz, br in self.bloqueios:
            for i in range(int(math.floor(bx - br)), int(math.ceil(bx + br)) + 1):
                for j in range(int(math.floor(bz - br)), int(math.ceil(bz + br)) + 1):
                    if math.hypot(i + 0.5 - bx, j + 0.5 - bz) < br + 0.5:
                        self._grade.add((i, j))
        self._grade_n = len(self.bloqueios)

    def _ronda_ok(self, x, z, folga):
        """A VOLTA na arena.

        Pedido do jogador, e com razao: correndo pela beirada o caminho fechava
        atras de um monte de pedra a cada vinte metros. Nenhuma peca sorteada
        entra se, no azimute dela, estreitar o trecho radial livre entre
        RONDA_R0 e RONDA_R1 abaixo de LARG_RONDA. Testo tres azimutes (o da
        peca e cinco graus pros lados) porque o corredor tem de ser CONTINUO,
        e nao um buraco de agulha num angulo so'.

        A conta e' ANTES x DEPOIS, e nao um minimo absoluto. Onde a ruina ja'
        fecha a faixa por conta propria — o quadrante da torre caida fecha —
        exigir 3,6 m livres proibiria QUALQUER peca ali, e o quadrante inteiro
        sairia pelado. O que se cobra da peca nova e' nao PIORAR o que existe.
        """
        if self._grade_n != len(self.bloqueios):
            self._refazer_grade()
        ang = math.atan2(x, z)
        for da in (-0.10, 0.0, 0.10):
            a = ang + da
            sa, ca = math.sin(a), math.cos(a)
            antes = depois = c_antes = c_depois = 0.0
            r = RONDA_R0
            while r <= RONDA_R1:
                px, pz = r * sa, r * ca
                if (int(math.floor(px)), int(math.floor(pz))) in self._grade:
                    c_antes = c_depois = 0.0
                else:
                    c_antes += 0.5
                    antes = max(antes, c_antes)
                    if math.hypot(px - x, pz - z) < folga:
                        c_depois = 0.0
                    else:
                        c_depois += 0.5
                        depois = max(depois, c_depois)
                r += 0.5
            if depois < min(LARG_RONDA, antes):
                return False
        return True

    def _livre(self, x, z, folga):
        if dentro_oct(x, z, R_PLAT + 9.0):
            return False
        if not dentro_oct(x, z, R_PRACA - 3.0):
            return False
        # nada com o CENTRO em cima de fissura: a peca tapa a brasa, que e'
        # a unica luz que sobe do chao, e fica meio palmo acima do fundo da
        # fenda. Margem curta de proposito — com meia folga de sobra, as seis
        # fissuras comiam 40% dos sorteios e a praca saia sem cobertura.
        if self._na_fenda(x, z, min(folga * 0.25, 0.8)):
            return False
        # O corredor das rampas cresce com a FOLGA da peca. Medir so' o centro
        # deixava um tronco de 4 m nascer com o centro fora do corredor e o
        # corpo dentro dele — na pratica, um degrau de 1 m no meio da subida.
        if abs(x) < W_RAMPA / 2 + 2.5 + folga and abs(z) < R_RAMPA + 2.0 + folga:
            return False
        if abs(z) < W_RAMPA / 2 + 2.5 + folga and abs(x) < R_RAMPA + 2.0 + folga:
            return False
        # O CORREDOR DE ENTRADA fica limpo: uma faixa de 14 m da brecha ate' o
        # adro. Nao e' generosidade com o jogador, e' a APRESENTACAO — e' por
        # esta linha que ele ve' a fachada e a Boca de uma vez so' ao entrar.
        # Com escombro no meio, a primeira coisa que a arena mostra e' um muro
        # de tres metros a dez passos da porta.
        if dist_polilinha(x, z, [(self.pontos["player"][0], self.pontos["player"][2]),
                                 (0.0, 0.0)]) < 7.0:
            return False
        for bx, bz, br in self.bloqueios:
            if math.hypot(x - bx, z - bz) < br + folga:
                return False
        if folga >= 2.0 and not self._ronda_ok(x, z, folga):
            return False
        return True

    def _sortear_lugar(self, folga, r0=19.0, r1=35.0, tentativas=220):
        for _ in range(tentativas):
            a = self.rnd.uniform(0, 2 * math.pi)
            r = self.rnd.uniform(r0, r1)
            x, z = r * math.sin(a), r * math.cos(a)
            if self._livre(x, z, folga):
                return x, z
        return None

    def escombro_muros(self):
        """Os pedacos de parede em pe': a cobertura ALTA, que quebra linha de
        tiro de quem esta' de pe'.

        E' a PRIMEIRA coisa posta na praca, antes ate' das torres de laje do
        parkour: e' a peca que mais precisa de espaco (9 m de muro com 5 m de
        folga em volta) e a que mais muda a briga. Sorteada por ultimo, ela
        simplesmente nao cabia em lugar nenhum e a praca saia sem cobertura.
        """
        # pedacos de parede em pe': cobertura ALTA, quebra linha de tiro
        for _ in range(7):
            lug = self._sortear_lugar(5.0)
            if not lug:
                continue
            x, z = lug
            ang = self.rnd.uniform(0, math.pi)
            comp = self.rnd.uniform(5.0, 9.0)
            # MURO ESCALAVEL: um em cada dois nasce baixo (3 m), GROSSO (1,8 m
            # em vez de 0,9) e sem serra no meio do coroamento. E' o alvo das
            # escadarias do `parkour`: um muro de 90 cm de espessura com serra
            # de 1,8 m em cima nao e' lugar de ficar em pe' — o jogador chega
            # la' e o coroamento atravessa o corpo dele.
            escalavel = len(self.muros) < 4 and self.rnd.random() < 0.65
            alt = self.rnd.uniform(2.85, 3.15) if escalavel else self.rnd.uniform(2.6, 4.6)
            esp = 0.9 if escalavel else 0.45
            p0 = (x - math.cos(ang) * comp / 2, z - math.sin(ang) * comp / 2)
            p1 = (x + math.cos(ang) * comp / 2, z + math.sin(ang) * comp / 2)
            mapa = mapa_girado(x, z, ang)
            self._bloco(self.quadrante(x, z), mapa, -comp / 2, comp / 2, -1.0, alt, -esp, esp)
            if escalavel:
                # serra so' nas pontas: o miolo fica liso, que e' o patamar
                for lado in (-1, 1):
                    self._topo_ruina(self.quadrante(x, z), mapa,
                                     min(lado * comp / 2, lado * comp / 6),
                                     max(lado * comp / 2, lado * comp / 6),
                                     alt, alt + 1.4, -esp, esp, "pedra_esc", passo=1.1)
                # parapeito de 35 cm no miolo: da' cobertura a quem sobe e
                # marca de longe que ali em cima se fica em pe'
                self._bloco(self.quadrante(x, z), mapa, -comp / 6, comp / 6,
                            alt, alt + 0.35, -esp, -esp + 0.35, "pedra_esc")
                self.muros.append((x, z, ang, comp, alt))
            else:
                self._topo_ruina(self.quadrante(x, z), mapa, -comp / 2, comp / 2, alt, alt + 1.8,
                                 -0.45, 0.45, "pedra_esc", passo=1.1)
            if not escalavel and self.rnd.random() < 0.6:
                # cotovelo: vira e faz um L, que e' cobertura de verdade
                mapa2 = mapa_girado(p1[0], p1[1], ang + math.pi / 2)
                c2 = self.rnd.uniform(3.0, 5.0)
                self._bloco(self.quadrante(x, z), mapa2, 0.0, c2, -0.4, alt * 0.8, -0.45, 0.45)
                self.col.append(parede_reta(p1, (p1[0] - math.sin(ang) * c2,
                                                 p1[1] + math.cos(ang) * c2),
                                            -0.5, alt * 0.8, 1.0))
            self.col.append(parede_reta(p0, p1, -1.1, alt, esp * 2.0))
            self.bloquear_linha(x, z, ang, comp, esp + 0.65,
                                n=max(3, int(comp / 2.2)))
            # teto de 8 fogueiras na arena inteira: cada uma e' uma OmniLight,
            # e o renderer mobile descarta em silencio a nona que encostar na
            # mesma malha. Oito espalhadas nunca chegam perto disso.
            # teto de SETE aqui: com as cinco dos modulos da ruina dava
            # nove omni na arena, e as malhas grandes (terreiro, bicho,
            # horizonte) tem AABB que pega todas elas de uma vez
            if self.rnd.random() < 0.5 and len(self.pontos["fogos"]) < 7:
                self.pontos["fogos"].append([round(p0[0], 2), 0.0, round(p0[1], 2)])
            self.contagem["muro"] += 1

    def escombro_solto(self):
        """Monte de pedra, coluna tombada e sucata — o que enche o resto."""
        # montes de pedra: cobertura baixa, da' pra ver por cima
        for _ in range(9):
            lug = self._sortear_lugar(3.6)
            if not lug:
                continue
            x, z = lug
            raio = self.rnd.uniform(2.6, 4.2)
            # `y` pelo piso do lugar: a praca tem cratera de ate' 60 cm, e
            # pedra empilhada no zero absoluto fica pendurada acima dela
            self.m.add_pecas(self.quadrante(x, z), "pedra_esc",
                             self._pedras(x, z, raio, int(raio * 5),
                                          y=self._altura_piso(x, z),
                                          tamanho=(0.45, 1.5),
                                          altura_pilha=raio * 0.45))
            self._monte(self.quadrante(x, z), x, z, raio + 0.4, raio * 0.5)
            # o monte e' RAMPA, nao muro: da' pra subir nele. Bloqueia so' o
            # miolo, que e' onde ele fica alto demais pro passo do inimigo.
            self.bloquear(x, z, raio * 0.6)
            self.contagem["monte"] += 1

        # colunas tombadas, deitadas no chao
        for _ in range(4):
            lug = self._sortear_lugar(3.2)
            if not lug:
                continue
            x, z = lug
            ang = self.rnd.uniform(0, math.pi)
            comp = self.rnd.uniform(7.0, 11.0)
            # o fuste inteiro, e nao so' tres tambores soltos: a colisao e'
            # uma caixa continua de ponta a ponta, e nos vaos entre os
            # tambores o jogador subia num cano que nao estava la'
            self.m.add_pecas(self.quadrante(x, z), "pedra",
                             [caixa_girada(x, self._altura_piso(x, z) + 0.5, z,
                                           1.05, 1.05, comp, ang + math.pi / 2)])
            for i in range(3):
                t = (i - 1) * comp / 3.2
                cx = x + math.cos(ang) * t
                cz = z + math.sin(ang) * t
                # o `y` sai do piso do lugar: deitada no zero absoluto, a
                # coluna boiava meio metro quando caia dentro de cratera
                cy = self._altura_piso(cx, cz) + 0.55
                self.m.add_pecas(self.quadrante(x, z), "pedra",
                                 [caixa_girada(cx, cy, cz, 1.1, 1.1, comp / 3.4,
                                               ang + math.pi / 2 + self.rnd.uniform(-0.1, 0.1))])
                self.m.add_pecas(self.quadrante(x, z), "pedra_esc",
                                 [caixa_girada(cx, cy, cz, 1.35, 1.35, 0.3,
                                               ang + math.pi / 2)])
            self.col.append(caixa_girada(x, self._altura_piso(x, z) + 0.5, z,
                                         1.15, 1.1, comp, ang + math.pi / 2))
            self.bloquear_linha(x, z, ang, comp, 0.9, n=max(3, int(comp / 2.4)))
            self.contagem["coluna"] += 1

        # Sucata: o que sobrou de quem tentou se defender aqui.
        #
        # A conta de quantos de cada um nao e' estetica, e' orcamento de
        # triangulo: os modelos do Poly Haven tem de 1 a 13 mil triangulos
        # CADA UM, e o carro sozinho custa o dobro de uma parede inteira da
        # arena. Por isso carro sao dois, e tambor sao seis.
        sucata = (("carro", 2.6, 2), ("barreira", 1.6, 4), ("tambor", 0.8, 6),
                  ("caixa", 0.8, 4), ("pneu", 0.7, 3), ("gerador", 1.1, 2),
                  ("arbusto", 1.4, 3), ("tronco", 1.2, 3),
                  ("entulho_saco", 0.7, 5), ("escada", 0.9, 1),
                  ("hidrante", 0.6, 2))
        for tipo, folga, quantos in sucata:
            for _ in range(quantos):
                lug = self._sortear_lugar(folga + 1.5, r0=15.0, r1=37.0)
                if not lug:
                    continue
                x, z = lug
                self.prop(tipo, x, z)
                if folga > 1.2:
                    self.bloquear(x, z, folga)

    # ------------------------------------------------------------------
    # PARKOUR
    #
    # Pedido do jogador, e ele tem razao: uma arena de Doom em que o unico
    # lugar alto e' o adro e' uma arena plana. A regra aqui e' uma so' —
    # cada lance sobe DEGRAU_PARKOUR (80 cm) contra um pulo de 1,03 m, e TODA
    # laje nasce ENTERRADA no piso daquele ponto. Laje comecando no zero
    # absoluto boia em cima de cratera, e peca boiando foi a reclamacao.

    def _pedras(self, cx, cz, raio, quantos, **kw):
        """`entulho` com um desencontro de altura POR PEDRA.

        Duas pedras do mesmo tamanho caem quase na mesma altura, e os topos
        delas acabam dividindo o mesmo plano: e' o mesmo z-fight das lajes,
        so' que espalhado pelo escombro — a textura pisca conforme o jogador
        anda. Tres centimetros de diferenca resolvem e ninguem ve'. O
        desencontro sai da POSICAO, e nao do sorteio, para nao mexer no
        stream do `random` e mudar o cenario inteiro de lugar.
        """
        saida = []
        for k, (verts, faces) in enumerate(
                entulho(cx, cz, raio, quantos, self.rnd, **kw)):
            dy = 0.028 * math.sin(cx * 5.1 + cz * 3.3 + k * 2.399)
            saida.append(([(a, b + dy, c) for (a, b, c) in verts], faces))
        return saida

    def _monte(self, setor, x, z, raio, altura, n=10):
        """O monte de entulho: a CASCA lisa e a colisao, de uma vez so'.

        A colisao de pilha de pedra sempre foi um `domo` liso (colisao pedra a
        pedra e' um campo de quinas onde o jogador enrosca). O que faltava era
        a casca DO DESENHO por baixo das pedras soltas: com so' dez ou vinte
        pedras espalhadas num monte de 4 m de raio, metade do domo nao tem
        nada por cima, e o jogador sobe dois metros pisando no ar entre as
        pedras. Isso e' colisao sem desenho — e e' o que ele via.
        """
        self.m.add_pecas(setor, "pedra_esc",
                         [domo(x, z, raio - 0.3, altura - 0.12, n=n)])
        self.col.append(domo(x, z, raio, altura, n=n))

    def _lance(self, x, z, giro, topo, larg=3.0, prof=2.2):
        """Uma laje de cantaria caida: do chao ate' `topo`. E' onde se pisa."""
        # 1,5 cm de desencontro, tirado da posicao (nao do sorteio, pra nao
        # mexer no resto do cenario): a laje cai em cima de escombro e de
        # bolha de carne, e altura redonda demais faz duas superficies
        # diferentes dividirem o mesmo plano — e' ai' que a textura pisca
        topo += 0.015 * math.sin(x * 3.7 + z * 2.3)
        y0 = self._altura_piso(x, z) - 0.4
        setor = self.quadrante(x, z, "degrau")
        # O CORPO PARA 8 CM ANTES DO TOPO. A capa e' quem fecha em cima, e as
        # duas faces no MESMO plano brigavam no z-buffer: a textura da laje
        # piscava conforme o jogador andava. Terminando o corpo por dentro da
        # capa, so' uma superficie chega ao plano do topo.
        self.m.add_pecas(setor, "pedra",
                         [caixa_girada(x, (y0 + topo - 0.08) / 2.0, z, larg,
                                       topo - 0.08 - y0, prof, giro)])
        # a colisao vai ate' o topo de verdade, que e' onde se pisa
        self.col.append(caixa_girada(x, (y0 + topo) / 2.0, z, larg,
                                     topo - y0, prof, giro))
        # capa escura: sem ela a laje le' como caixote de madeira; com ela
        # le' como bloco de cantaria que caiu da ruina
        self.m.add_pecas(setor, "pedra_esc",
                         [caixa_girada(x, topo - 0.11, z, larg + 0.3, 0.22,
                                       prof + 0.3, giro)])
        self.bloquear(x, z, max(larg, prof) * 0.55)

    def parkour_torres(self):
        """UMA TORRE DE LAJE POR OITAVO DE ARENA.

        Roda ANTES do escombro sorteado, e nao depois: com a praca ja' cheia
        nao sobra vao de 3 m em lugar nenhum, e as oito torres viravam zero.
        Postas primeiro, elas ficam espalhadas de verdade e o escombro se
        arruma em volta — quem corre a volta da arena acha onde subir a cada
        trinta passos.

        Quatro lances de 80 cm chegam a 3,20 m: mais alto que qualquer muro de
        escombro, e de la' se ve' o adro inteiro por cima da cobertura.
        """
        for k in range(8):
            base, a = None, 0.0
            for _ in range(40):
                a = ((k + 0.5) * math.pi / 4
                     + self.rnd.uniform(-math.pi / 9, math.pi / 9))
                r = self.rnd.uniform(23.0, 32.0)
                bx, bz = r * math.sin(a), r * math.cos(a)
                if self._livre(bx, bz, 3.0):
                    base = (bx, bz)
                    break
            if base is None:
                continue
            postos = []
            for i in range(4):
                cx = base[0] + math.sin(a) * i * 2.0
                cz = base[1] + math.cos(a) * i * 2.0
                if not dentro_oct(cx, cz, R_LIMITE - 1.0):
                    break
                if any(math.hypot(cx - bx, cz - bz) < br + 1.9
                       for bx, bz, br in self.bloqueios):
                    break
                postos.append((cx, cz))
            if len(postos) < 3:
                continue
            self.n_escadarias += 1
            self.contagem["torre_laje"] += 1
            for i, (cx, cz) in enumerate(postos):
                topo = self._altura_piso(cx, cz) + DEGRAU_PARKOUR * (i + 1)
                ultimo = i == len(postos) - 1
                self._lance(cx, cz, a, topo,
                            larg=4.2 if ultimo else 3.2,
                            prof=3.4 if ultimo else 2.2)

    def parkour_encostado(self):
        """Escadaria encostada no que JA' esta' no chao.

        Estas nao disputam espaco com nada: sao lajes que tocam a peca que vao
        escalar. Por isso rodam no fim, quando o muro de escombro ja' existe.
        """
        # 1. nos muros escalaveis: tres lances (0,8 / 1,6 / 2,4) e o ultimo
        #    pulo de 60 cm pro alto do muro, a 3 m
        for (mx, mz, mang, comp, alt) in self.muros:
            for lado in self.rnd.sample([1, -1], 2):
                # a normal do muro: o eixo dele e' (cos ang, sin ang)
                nx, nz = -math.sin(mang) * lado, math.cos(mang) * lado
                postos = []
                for i in range(3):
                    d = 1.5 + (2 - i) * 1.9
                    cx = mx + nx * d + math.cos(mang) * self.rnd.uniform(-1.2, 1.2)
                    cz = mz + nz * d + math.sin(mang) * self.rnd.uniform(-1.2, 1.2)
                    if not dentro_oct(cx, cz, R_LIMITE - 1.0):
                        postos = []
                        break
                    postos.append((cx, cz))
                if not postos:
                    continue
                self.n_escadarias += 1
                for i, (cx, cz) in enumerate(postos):
                    self._lance(cx, cz, -mang,
                                self._altura_piso(cx, cz) + DEGRAU_PARKOUR * (i + 1),
                                larg=3.0, prof=2.2)
                break

        # 2. na ponta da torre caida: a subida pro unico caminho ALTO que
        #    atravessa a arena inteira — de cima dela da' pra correr ate' a
        #    ruina sem pisar no chao
        for (ex, ez, px, pz, topo) in self.escaladas:
            # SOBE PELO LADO DA TORRE, nao pela ponta. Pela ponta a escadaria
            # avancava seis metros na direcao do centro e as duas ultimas
            # lajes caiam DENTRO do adro — uma delas aparecia tres centimetros
            # acima do tampo, brigando com a pedra dele.
            lado = 1.0
            if not self._livre(ex + px * 4.0, ez + pz * 4.0, 2.2):
                lado = -1.0
            a = math.atan2(-px * lado, -pz * lado)
            self.n_escadarias += 1
            n = max(2, int(round((topo - 0.15) / DEGRAU_PARKOUR)))
            for i in range(n):
                d = (n - i) * 1.9
                cx = ex + px * lado * d
                cz = ez + pz * lado * d
                if dentro_oct(cx, cz, R_PLAT + 4.0):
                    continue
                self._lance(cx, cz, a,
                            self._altura_piso(cx, cz) + DEGRAU_PARKOUR * (i + 1),
                            larg=3.4, prof=2.2)

    # ------------------------------------------------------------------

    def tentaculos(self):
        """O bicho por cima e por baixo da praca.

        Um tentaculo GRANDE atravessa a arena de ponta a ponta pelo alto: e' o
        que da' escala pro lugar e some no teto de nevoa. Os outros saem de
        fissura e voltam pra fissura — nunca do chao liso, senao viram
        cogumelo de plastico plantado na pedra.
        """
        a0 = 5 * math.pi / 4      # muralha de carne (SW)
        a1 = math.pi / 4          # torre caida (NE)
        # os pes caem FORA da praca (raio 47), nas ruinas. Dentro do campo
        # eles viravam duas colunas de 5 m no meio da briga e tapavam a
        # fachada logo do ponto onde o jogador nasce.
        p0 = (47.0 * math.sin(a0), -4.0, 47.0 * math.cos(a0))
        p1 = (47.0 * math.sin(a1), -4.0, 47.0 * math.cos(a1))
        for lado, torc in ((0, 7.0), (1, -6.0)):
            pts = arco_pontos(p0, p1, 33.0 + lado * 2.5, n=22, torcao=torc)
            raios = [1.9 - 1.15 * abs(i / 22.0 - 0.5) * 1.6 for i in range(23)]
            self.m.add_pecas("bicho", "carne", [tubo_redondo(pts, raios, n=10)],
                             suave=True)
        # correntes penduradas no arco: o povo tentou amarrar a coisa
        for k in range(6):
            t = 0.22 + k * 0.11
            pts = arco_pontos(p0, p1, 33.0, n=22)
            i = int(t * 22)
            p = pts[i]
            queda = self.rnd.uniform(6.0, 14.0)
            self.m.add_pecas("bicho", "metal",
                             [tubo_redondo([(p[0], p[1] - 1.5, p[2]),
                                            (p[0] + 0.6, p[1] - 1.5 - queda, p[2] - 0.4)],
                                           [0.12, 0.12], n=5)])

        # os que saem das fissuras
        for f in self.fissuras[:4]:
            pts_f = f["pts"]
            i = min(2, len(pts_f) - 2)
            # nao no corredor de entrada: um tentaculo de 10 m plantado ali
            # tapa a fachada logo no primeiro passo do jogador
            if dist_polilinha(pts_f[i][0], pts_f[i][1],
                              [(self.pontos["player"][0], self.pontos["player"][2]),
                               (0.0, 0.0)]) < 9.0:
                i = max(0, i - 2) if i >= 2 else min(i + 2, len(pts_f) - 2)
                if dist_polilinha(pts_f[i][0], pts_f[i][1],
                                  [(self.pontos["player"][0], self.pontos["player"][2]),
                                   (0.0, 0.0)]) < 9.0:
                    continue
            a = (pts_f[i][0], -1.2, pts_f[i][1])
            b = (pts_f[i + 1][0], -1.2, pts_f[i + 1][1])
            alt = self.rnd.uniform(5.0, 11.0)
            pts = arco_pontos(a, b, alt, n=12, torcao=self.rnd.uniform(-2.5, 2.5))
            raios = [0.95 - 0.55 * abs(i / 12.0 - 0.5) * 1.5 for i in range(13)]
            self.m.add_pecas("bicho", "carne", [tubo_redondo(pts, raios, n=8)],
                             suave=True)
            # A COLISAO VAI NOS PES DO ARCO, nao no meio dele.
            #
            # Estava em `pts[6]`, que e' o alto da curva — de 5 a 11 m no ar.
            # O que isso punha no chao era um bloco de 2,2 x 2,2 x 3 m
            # INVISIVEL, no meio da praca, embaixo de um tentaculo que passa
            # la' em cima. O jogador batia numa parede que nao existe. Nos
            # pes, a colisao tem a grossura do tubo que se ve', e por baixo
            # do arco da' pra correr, que e' o que ele parece prometer.
            for ip in (1, len(pts) - 2):
                pe = pts[ip]
                self.col.append(cilindro(pe[0], pe[2], 0.8, -0.6,
                                         min(pe[1] + 0.6, 2.2), n=8))
                self.bloquear(pe[0], pe[2], 1.3)
            meio = pts[6]
            self.pontos["brasas"].append([round(meio[0], 2), 0.6, round(meio[2], 2)])

    def monolitos(self):
        """Seis pedras fincadas em volta do adro, com sigilo aceso.

        Elas sao o relogio do lugar: e' por elas que o jogador conta quantas
        voltas ja' deu na arena. Por isso ficam num raio so' e igualmente
        espacadas — a unica coisa regular do cenario inteiro.
        """
        for k in range(6):
            a = math.pi / 6 + k * math.pi / 3
            x, z = 25.0 * math.sin(a), 25.0 * math.cos(a)
            if not self._livre(x, z, 2.0):
                x, z = 27.5 * math.sin(a + 0.22), 27.5 * math.cos(a + 0.22)
            alt = self.rnd.uniform(5.5, 8.5)
            giro = a + self.rnd.uniform(-0.25, 0.25)
            incl = self.rnd.uniform(-0.10, 0.10)
            self.m.add_pecas(self.quadrante(x, z, "monolito"), "pedra",
                             [caixa_girada(x, alt / 2 - 0.4, z, 1.9, alt, 1.1, giro, incl)])
            self.m.add_pecas(self.quadrante(x, z, "monolito"), "pedra_esc",
                             [caixa_girada(x, alt - 0.35, z, 2.3, 0.5, 1.5, giro, incl)])
            # o sigilo gravado, virado pro centro da arena
            for i in range(4):
                y = 1.2 + i * (alt - 2.4) / 4.0
                larg = self.rnd.uniform(0.5, 1.2)
                self.m.add_pecas(self.quadrante(x, z, "monolito"), "sigilo",
                                 [caixa_girada(x - math.sin(a) * 0.60,
                                               y, z - math.cos(a) * 0.60,
                                               larg, 0.11, 0.12, giro, incl)])
            # o MESMO centro e a MESMA inclinacao do desenho: reta e 40 cm
            # mais alta, a caixa de colisao sobrava pra fora da pedra e o
            # jogador esbarrava no ar ao lado do monolito
            self.col.append(caixa_girada(x, alt / 2 - 0.4, z, 2.0, alt, 1.2,
                                         giro, incl))
            self.bloquear(x, z, 1.6)
            self.pontos["sigilos"].append([round(x - math.sin(a) * 1.1, 2), alt * 0.6,
                                           round(z - math.cos(a) * 1.1, 2)])
            self.m.add_pecas(self.quadrante(x, z, "monolito"), "pedra_esc",
                             self._pedras(x, z, 2.2, 6, tamanho=(0.3, 0.8)))

    def horizonte(self):
        """Cidade morta na linha do horizonte: so' silhueta, sem detalhe.

        Ela existe por um motivo so' — sem nada la' fora, o ceu encosta no
        chao no raio 140 e a arena vira uma maquete em cima de uma mesa.
        """
        self.rnd.seed(77123)
        for k in range(46):
            a = 2 * math.pi * k / 46 + self.rnd.uniform(-0.05, 0.05)
            r = self.rnd.uniform(78.0, 132.0)
            x, z = r * math.sin(a), r * math.cos(a)
            alt = self.rnd.uniform(9.0, 52.0) * (1.0 + (r - 78.0) / 120.0)
            larg = self.rnd.uniform(5.0, 15.0)
            self.m.add_pecas("horizonte", "silhueta",
                             [caixa_girada(x, alt / 2 - 2.0, z, larg, alt,
                                           larg * self.rnd.uniform(0.6, 1.4),
                                           self.rnd.uniform(0, math.pi),
                                           self.rnd.uniform(-0.09, 0.09))])
            if self.rnd.random() < 0.28:
                self.m.add_pecas("horizonte", "silhueta",
                                 [espinho((x, alt - 2.0, z),
                                          (x + self.rnd.uniform(-4, 4), alt + self.rnd.uniform(6, 22),
                                           z + self.rnd.uniform(-4, 4)),
                                          larg * 0.3, n=4)])
        # tres tentaculos colossais ao longe, a coisa inteira
        for a, r, alt in ((0.7, 150.0, 90.0), (3.0, 175.0, 120.0), (4.6, 160.0, 70.0)):
            x, z = r * math.sin(a), r * math.cos(a)
            pts, raios = [], []
            for i in range(11):
                t = i / 10.0
                pts.append((x + math.sin(t * 3.0) * alt * 0.13,
                            -5.0 + alt * t,
                            z + math.cos(t * 2.0) * alt * 0.10))
                raios.append(alt * 0.075 * (1.0 - t * 0.78))
            self.m.add_pecas("horizonte", "silhueta",
                             [tubo_redondo(pts, raios, n=8)], suave=True)

    def cercadura(self):
        """Muro invisivel no raio 41. A ruina e' cenario; quem segura o jogador
        e' esta caixa lisa, sem quina pra ele escalar sem querer."""
        for k in range(8):
            th = k * math.pi / 4
            mapa = mapa_girado(R_LIMITE * math.sin(th), R_LIMITE * math.cos(th), -th)
            lado = R_LIMITE * math.tan(math.pi / 8) + 2.0
            self.col.append(painel(mapa, -lado, lado, -2.0, 18.0, 0.0, 1.2, [])[0])

    def marcadores(self):
        """Onde os inimigos vao nascer quando a briga vier pra ca'.

        Os doze pontos nao sao sorteados no chao e sim escolhidos ENTRE AS
        CELULAS DO NAVMESH, pela mais perto de cada uma das doze direcoes em
        volta do adro. Escolhido no chao, um marcador cai atras de escombro
        com frequencia, e o inimigo que nasce fora do navmesh nunca acha o
        caminho — fica raspando na pedra a briga inteira.
        """
        nav = self.pontos["navmesh"]
        centros = []
        for poly in nav["p"]:
            n = float(len(poly))
            cx = sum(nav["v"][k][0] for k in poly) / n
            cy = sum(nav["v"][k][1] for k in poly) / n
            cz = sum(nav["v"][k][2] for k in poly) / n
            centros.append((cx, cy, cz))
        usados = set()
        for k in range(12):
            a = 2 * math.pi * k / 12 + 0.26
            ax, az = 25.0 * math.sin(a), 25.0 * math.cos(a)
            melhor, melhor_d = None, 1e9
            for i, c in enumerate(centros):
                if i in usados:
                    continue
                d = math.hypot(c[0] - ax, c[2] - az)
                if d < melhor_d:
                    melhor, melhor_d = i, d
            if melhor is None:
                continue
            usados.add(melhor)
            c = centros[melhor]
            self.pontos["inimigos"].append([round(c[0], 2), round(c[1] + 0.1, 2),
                                            round(c[2], 2)])

    # ------------------------------------------------------------------
    # navmesh

    def _altura_nav(self, x, z):
        # o adro do navmesh vai ate' a borda de COLISAO (AP_ADRO), que e' onde
        # a rampa encosta — medir pela apotema de R_PLAT abria um degrau de
        # 1,6 m entre o tampo e o pe' da rampa e o navmesh se partia ali
        if dentro_oct(x, z, R_PLAT + 2.0):
            return H_PLAT
        for k in range(4):
            ang = k * math.pi / 2
            sa, ca = math.sin(ang), math.cos(ang)
            u = x * sa + z * ca
            w = x * ca - z * sa
            if abs(w) <= W_RAMPA / 2.0 and AP_ADRO <= u <= R_RAMPA:
                t = (R_RAMPA - u) / (R_RAMPA - AP_ADRO)
                return H_PLAT * t
        # o mesmo chao da colisao, cratera inclusive: com 0,0 fixo o caminho
        # do inimigo passava meio metro acima do piso no fundo das crateras
        return self._altura_piso(x, z)

    def navmesh(self):
        """Grade de 2,5 m com buraco onde tem escombro, degrau ou fissura larga.

        Sai daqui e nao do bake do editor de proposito: o modelo e' REGERADO
        por script, e um navmesh assado no editor nao sobrevive a isso. Como
        os vertices sao compartilhados entre celulas vizinhas, o Godot casa as
        bordas sozinho e a malha fica conexa.
        """
        n = int(R_LIMITE / math.cos(math.pi / 8) / PASSO_NAV) + 1
        indice = {}
        verts, polys = [], []

        def vid(i, j):
            if (i, j) not in indice:
                x, z = i * PASSO_NAV, j * PASSO_NAV
                indice[(i, j)] = len(verts)
                verts.append([round(x, 3), round(self._altura_nav(x, z), 3), round(z, 3)])
            return indice[(i, j)]

        for i in range(-n, n):
            for j in range(-n, n):
                xc = (i + 0.5) * PASSO_NAV
                zc = (j + 0.5) * PASSO_NAV
                # o navmesh vai ate' quase o muro invisivel: a faixa entre a
                # praca util e o muro e' espaco de briga como qualquer outro,
                # e inimigo encurralado ali tem de saber voltar.
                if not dentro_oct(xc, zc, R_LIMITE / math.cos(math.pi / 8) - 1.5):
                    continue
                bloqueada = False
                for bx, bz, br in self.bloqueios:
                    if math.hypot(xc - bx, zc - bz) < br + 0.45:
                        bloqueada = True
                        break
                if bloqueada:
                    continue
                alturas = [self._altura_nav(a * PASSO_NAV, b * PASSO_NAV)
                           for a, b in ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))]
                if max(alturas) - min(alturas) > 0.55:
                    continue
                polys.append([vid(i, j), vid(i + 1, j), vid(i + 1, j + 1), vid(i, j + 1)])

        polys = self._maior_ilha(polys)
        # reindexa: sobram vertices orfaos depois de jogar ilha fora
        usados = {}
        novos = []
        limpos = []
        for poly in polys:
            saida = []
            for k in poly:
                if k not in usados:
                    usados[k] = len(novos)
                    novos.append(verts[k])
                saida.append(usados[k])
            limpos.append(saida)
        self.pontos["navmesh"] = {"v": novos, "p": limpos}

    @staticmethod
    def _maior_ilha(polys):
        """Descarta os pedacos de navmesh que nao se ligam ao resto.

        Um monte de escombro no meio da praca deixa atras de si um bolsao de
        duas ou tres celulas cercado por bloqueio. O `map_get_closest_point`
        do Godot nao sabe que aquilo e' ilha: ele devolve o ponto mais perto
        seja qual for, e o inimigo que nascer ali fica batendo na parede pro
        resto da briga. Fora todos, fica so' o continente.
        """
        vizinhos = {}
        for pi, poly in enumerate(polys):
            for k in range(len(poly)):
                a, b = poly[k], poly[(k + 1) % len(poly)]
                vizinhos.setdefault((min(a, b), max(a, b)), []).append(pi)
        pai = list(range(len(polys)))

        def acha(x):
            while pai[x] != x:
                pai[x] = pai[pai[x]]
                x = pai[x]
            return x

        for lista in vizinhos.values():
            if len(lista) == 2:
                a, b = acha(lista[0]), acha(lista[1])
                if a != b:
                    pai[a] = b
        contagem = {}
        for i in range(len(polys)):
            r = acha(i)
            contagem[r] = contagem.get(r, 0) + 1
        if not contagem:
            return polys
        maior = max(contagem, key=lambda k: contagem[k])
        return [p for i, p in enumerate(polys) if acha(i) == maior]


# --------------------------------------------------------------------------
# Blender
#
# Malhas ABERTAS (chao, terreiro, tigela da boca) nao passam pelo
# `normals_make_consistent`: ele decide o "fora" por raio, e numa chapa aberta
# de 80 m a decisao sai aleatoria e metade do piso fica invisivel. Nessas o
# giro das faces ja' e' escrito na mao, virado pra cima.

ABERTOS = ("terreiro", "boca")


def e_aberto(setor):
    return setor.startswith("piso_") or setor in ABERTOS


def limpar_cena():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(nome):
    mat = bpy.data.materials.get("MI_" + nome)
    if mat:
        return mat
    mat = bpy.data.materials.new("MI_" + nome)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    cor = MATERIAIS.get(nome, (0.5, 0.5, 0.5))
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (cor[0], cor[1], cor[2], 1.0)
        bsdf.inputs["Roughness"].default_value = 0.92
        if nome in ("brasa", "sigilo"):
            bsdf.inputs["Emission Color"].default_value = (cor[0], cor[1], cor[2], 1.0)
            bsdf.inputs["Emission Strength"].default_value = 3.0
    return mat


def criar_objeto(nome, dados, mat_nome, escala_uv=0.25):
    me = bpy.data.meshes.new(nome)
    me.from_pydata(dados["v"], [], dados["f"])
    me.validate(verbose=False)
    me.update()

    uvl = me.uv_layers.new(name="UVMap")
    for poly, uv_manual in zip(me.polygons, dados["uv"]):
        if uv_manual:
            for k, li in enumerate(poly.loop_indices):
                uvl.data[li].uv = uv_manual[k % len(uv_manual)]
            continue
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            p = me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                u, v = p[2], p[1]
            elif ax == 1:
                u, v = p[0], p[2]
            else:
                u, v = p[0], p[1]
            uvl.data[li].uv = (u * escala_uv, v * escala_uv)

    for poly, suave in zip(me.polygons, dados["s"]):
        poly.use_smooth = bool(suave)

    ob = bpy.data.objects.new(nome, me)
    ob.data.materials.append(material(mat_nome))
    bpy.context.scene.collection.objects.link(ob)
    return ob


def recalcular_normais(ob):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def exportar(caminho):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    kw = dict(filepath=caminho, export_format="GLB", use_selection=True,
              export_apply=True, export_yup=False, export_materials="EXPORT",
              export_normals=True)
    try:
        bpy.ops.export_scene.gltf(**kw)
    except TypeError as erro:
        print("export: assinatura diferente (%s), tentando minimo" % erro)
        bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB",
                                  use_selection=True, export_yup=False)
    return os.path.getsize(caminho)


def juntar(pecas):
    verts, faces = [], []
    for v, f in pecas:
        base = len(verts)
        verts.extend(v)
        for face in f:
            faces.append([k + base for k in face])
    return verts, faces


def main():
    limpar_cena()
    arena = Arena()
    arena.montar()

    criados = []
    for (setor, mat_nome), dados in sorted(arena.m.grupos.items()):
        if not dados["f"]:
            continue
        nome = "SM_ar2_%s_%s" % (setor, mat_nome)
        ob = criar_objeto(nome, dados, mat_nome)
        if not e_aberto(setor):
            recalcular_normais(ob)
        criados.append((nome, len(dados["f"])))

    v, f = juntar(arena.col)
    dados = {"v": v, "f": f, "uv": [None] * len(f), "s": [False] * len(f)}
    recalcular_normais(criar_objeto("CL_arena_2-colonly", dados, "pedra"))

    destino = os.path.join(DESTINO, "arena_2.glb")
    tam = exportar(destino)
    with open(os.path.join(DESTINO, "arena_2_pontos.json"), "w") as fp:
        json.dump(arena.pontos, fp, indent=1)

    print("\n--- arena 2 gerada ---")
    for nome, nfaces in criados:
        print("  %-34s %6d faces" % (nome, nfaces))
    print("  %-34s %6d faces  (invisivel)" % ("CL_arena_2-colonly", len(f)))
    print("  triangulos visiveis ~%d  em %d malhas" % (arena.m.total_tris(),
                                                       len(criados)))
    print("  %s  %.1f MB" % (destino, tam / 1048576.0))
    print("  escombro: %s" % arena.contagem)
    print("  muros escalaveis=%d escadarias=%d bloqueios=%d"
          % (len(arena.muros), arena.n_escadarias, len(arena.bloqueios)))
    print("  fogos=%d sigilos=%d brasas=%d props=%d inimigos=%d" % (
        len(arena.pontos["fogos"]), len(arena.pontos["sigilos"]),
        len(arena.pontos["brasas"]), len(arena.pontos["props"]),
        len(arena.pontos["inimigos"])))
    print("  navmesh: %d vertices, %d poligonos" % (
        len(arena.pontos["navmesh"]["v"]), len(arena.pontos["navmesh"]["p"])))


if __name__ == "__main__":
    main()
