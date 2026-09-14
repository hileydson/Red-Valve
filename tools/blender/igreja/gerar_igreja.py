"""Modela o INTERIOR da igreja da cidade e exporta pro Godot.

Rodar em background (nao mexe no .blend que voce tem aberto, nao precisa do
addon MCP):

    blender --background --factory-startup \\
        --python tools/blender/igreja/gerar_igreja.py

Saidas:
    red-valve/assets/3d_model/stages/igreja/igreja_interior.glb
    red-valve/assets/3d_model/stages/igreja/igreja_pontos.json

==============================================================================
POR QUE ESTE ARQUIVO EXISTE

A igreja da cidade e' um scan de 39 MB com UMA malha e nenhum interior: por
fora ela e' um marco da praca, por dentro nao existe. Como a casa do Jimmy e a
casa do Maycow, o interior e' uma CENA SEPARADA — o mapa carrega o interior ao
atravessar o portal e devolve o jogador na soleira na volta. Isso tambem
libera a planta: por dentro ela e' uma catedral de tres naves, e por fora
continua a igrejinha de vila. Ninguem compara, e todo jogo faz isso.

==============================================================================
A PLANTA (tudo em metros, jogador tem ~1,8 m)

   Z=0  portal oeste            Z=33  arco triunfal      Z=41  fundo da abside
   |                              |                        |
   +------ nave central ----------+--- coro ---+- abside --+
   largura 13,1 livre                elevado 0,9

   naves laterais dos dois lados (5,15 m), galerias EM CIMA delas (Y=9,9),
   abobadas de cruzaria em tudo, clerestorio a 16 m, chave da nave a 26 m.

   2o ANDAR = as duas galerias. Sobe-se por:
     - escada reta de pedra, dois lances, na nave lateral NORTE (X<0);
     - escada em caracol em volta de um poste, na nave lateral SUL (X>0).
   Atravessa-se de um lado pro outro por:
     - passarela de tabuas no meio da nave (Z=22), improvisada;
     - jube' de pedra sobre o arco triunfal (Z=33), com o meio desabado e
       remendado com tabuas.
   O circuito fecha: sobe norte, cruza, desce sul.

==============================================================================
O ESTADO DA IGREJA

Arruinada, e arruinada com CAUSA — nada de dano decorativo espalhado por igual:

  - Um pedaco da abobada da nave CAIU (baia Z 12-19). E' o buraco por onde
    entra a unica luz forte do lugar, e a pilha de pedra embaixo dele e' a
    mesma pedra que falta la' em cima.
  - A abobada da nave lateral norte tambem foi embora, e e' exatamente por
    isso que a escada de pedra cabe ali subindo dois andares no vao.
  - O pilar da arcada sul em Z=19 partiu na altura do peito; o arco que ele
    segurava morreu no ar. O fuste dele esta' caido no chao ao lado, em tres
    pedacos.
  - Vitral: as janelas baixas, que da' pra alcancar, estao arrombadas
    (textura `_roto`); as altas continuam inteiras.
  - Bancos: as primeiras fileiras ainda em ordem, as do meio empurradas,
    viradas e quebradas na direcao do buraco — como se algo tivesse passado
    por ali.

==============================================================================
COMO ISTO CHEGA NO GODOT

  - Um .glb, varios objetos, um por (setor da nave x material). A divisao por
    setor NAO e' estetica: o Godot so' aceita 8 luzes omni + 8 spot por MALHA,
    e aqui tem vela, tocha e feixe de janela a cada poucos metros.
  - Materiais aqui sao so' marcacao (`MI_pedra`, `MI_madeira`...). Quem manda
    e' o `material_override` da cena, com textura triplanar — por isso
    nenhuma peca leva UV desdobrado a mao.
  - A colisao e' UM objeto separado, `CL_igreja-colonly`: o importador do
    Godot transforma o sufixo em StaticBody3D invisivel com trimesh. Ele e'
    LISO (caixas e rampas, sem degrau nem coluneta) porque colisao fiel a
    geometria bonita e' o caminho curto pro jogador enganchar em quina de
    escada. A layer dele e' corrigida pra 2 no `igreja_interior.gd` — o
    player do projeto tem `collision_mask = 2` e atravessaria a layer 1.
"""

import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import geo  # noqa: E402
from geo import (Malhas, abobada_cruzaria, arco_perfil, arquivolta, banco,  # noqa: E402
                 domo,
                 caixa, caixa_girada, candelabro, cilindro, coluneta, corrente,
                 cruz, entulho, escada_caracol, escada_reta, faixa_sobre_arco,
                 hexaedro, mapa_girado, mapa_x, mapa_z, nervura_diagonal,
                 painel, parapeito_rendilhado, pilar_composto, semicupula,
                 tubo, viga_caida)

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
DESTINO = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "stages", "igreja")

# --------------------------------------------------------------------------
# PLANTA

EIXO = 7.0            # |X| do eixo da arcada
ARC_W0, ARC_W1 = -0.45, 0.45   # espessura do muro da arcada, em torno do eixo
PAR_INT = 12.6        # face interna da parede lateral
PAR_EXT = 14.0
Z_OESTE = 0.0         # face interna da fachada
Z_OESTE_EXT = -1.7
PILAR_Z = [5.0, 12.0, 19.0, 26.0, 33.0]
BAIAS = [(0.0, 5.0), (5.0, 12.0), (12.0, 19.0), (19.0, 26.0), (26.0, 33.0)]
Z_CRUZ = 33.0         # arco triunfal
Z_CORO = 41.0         # fim do coro / arranque da abside
ABS_R = 8.4           # raio da abside (centro em Z_CORO)
CORO_Y = 0.9          # quanto o coro e' mais alto que a nave

Y_ARC_ARR = 6.3       # arranque do arco da arcada
ARC_FLECHA = 2.6      # -> apice 8.9
Y_GAL = 9.9           # piso da galeria (topo da laje)
GAL_LAJE = 0.35
Y_PARAPEITO = 10.95
Y_TRIF = 14.2         # topo da arcada do triforio
Y_GAL_TETO = 14.9
Y_CLER0, Y_CLER1 = 15.2, 21.4   # faixa do clerestorio
Y_NAVE_ARR = 21.6     # arranque da abobada da nave
NAVE_FLECHA = 4.6     # -> chave 26.2
Y_LAT_ARR = 6.0       # arranque da abobada das naves laterais
LAT_FLECHA = 2.7      # -> chave 8.7

NAVE_X = EIXO + ARC_W0   # 6.55 - face interna da arcada
LAT_X0 = EIXO + ARC_W1   # 7.45 - comeco da nave lateral

# --- 2o andar / circulacao
ESC_X0, ESC_X1 = -PAR_INT, -PAR_INT + 2.5   # escada reta encostada na parede norte
ESC_Z0, ESC_Z1 = 2.2, 9.2                   # lance 1
ESC_PAT_Z = 11.2                            # fim do patamar
ESC_Z2 = 17.6                               # fim do lance 2
# Encostada na parede e mais estreita do que a primeira versao: com raio 2,05
# e centro em x=10,4 ela deixava 65 cm de piso entre o poco e o parapeito da
# galeria, o que e' menos que a largura do jogador — andar pela galeria sul
# significava cair no poco.
CARACOL = (10.9, 28.6)                      # poste da escada em caracol (x, z)
CARACOL_R = 1.7
# Tres voltas exatas: com 2,5 voltas a boca de baixo e a de cima ficavam em
# lados opostos, e a de cima saia encostada na parede. Multiplo de 360 faz
# entrada e saida apontarem ambas pra dentro da nave (-X).
CARACOL_GIRO = 1080.0
POCO_X = CARACOL[0] - CARACOL_R - 0.25     # borda interna do poco (piso ate' aqui)
# ...e a laje encosta na ponta do degrau, pra nao sobrar fresta entre as duas.
POCO_Z0 = CARACOL[1] - CARACOL_R - 0.45
POCO_Z1 = CARACOL[1] + CARACOL_R + 0.45
POCO_SAIDA = 1.15                          # meia-largura da boca, no lado -X
PASSARELA_Z = 22.0    # passarela de tabuas no meio da nave
PASSARELA_BOCA = 1.6  # meia-largura do vao aberto no parapeito, dos dois lados
JUBE_Z0, JUBE_Z1 = 31.6, 34.6   # jube' de pedra sobre o arco triunfal

BAIA_ROMPIDA = 2      # indice da baia cuja abobada da nave caiu (12-19)

SEMENTE = 20260913

MATERIAIS = {
    "pedra": (0.52, 0.50, 0.46),
    "pedra_esc": (0.30, 0.29, 0.28),
    "madeira": (0.20, 0.13, 0.08),
    "vitral": (0.30, 0.12, 0.10),
    "metal": (0.12, 0.11, 0.11),
    "ouro": (0.44, 0.33, 0.10),
    "pano": (0.22, 0.10, 0.10),
}


# Fronteiras das fatias em que a igreja e' cortada, uma por baia da nave.
# Isto e' medida de RENDERER, nao de arquitetura: o projeto roda no
# `rendering_method="mobile"`, que aceita 8 omni + 8 spot POR MALHA e descarta
# o resto em silencio. Com quatro fatias grandes, a do meio era alcancada por
# catorze luzes e perdia metade sem avisar; com fatias de sete metros e alcance
# curto nas tochas, nenhuma malha passa do limite.
SETORES = [(5.0, "a"), (12.0, "b"), (19.0, "c"), (26.0, "d"), (33.0, "e")]


def setor(z):
    """Fatia da nave a que uma peca pertence (limita luzes por malha)."""
    for limite, nome in SETORES:
        if z < limite:
            return nome
    return "f"


# --------------------------------------------------------------------------
# montagem

class Igreja:
    def __init__(self):
        self.m = Malhas()
        self.col = []          # pecas do objeto de colisao
        self.rnd = random.Random(SEMENTE)
        self.pontos = {"janelas": [], "velas": [], "candelabros": [],
                       "tochas": [], "escombros": []}

    # -- atalhos ----------------------------------------------------------
    def por(self, material, pecas, z_ref=None, suave=False, uvs=None):
        if not isinstance(pecas, list):
            pecas = [pecas]
        for p in pecas:
            verts, faces = p
            z = z_ref
            if z is None:
                z = sum(v[2] for v in verts) / max(len(verts), 1)
            self.m.add(setor(z), material, verts, faces, uvs=uvs, suave=suave)

    def colide(self, pecas):
        if not isinstance(pecas, list):
            pecas = [pecas]
        self.col.extend(pecas)

    def solido(self, material, pecas, **kw):
        """Peca que existe pros olhos E pro corpo."""
        self.por(material, pecas, **kw)
        self.colide(pecas)

    # -- chao -------------------------------------------------------------
    def piso(self):
        rnd = self.rnd
        # lajeado da nave e das laterais, em placas com desnivel de milimetros
        z = Z_OESTE - 1.0
        while z < Z_CRUZ + 1.2:
            passo_z = rnd.uniform(1.6, 2.4)
            x = -PAR_INT
            while x < PAR_INT:
                passo_x = rnd.uniform(1.6, 2.4)
                x1 = min(x + passo_x, PAR_INT)
                z1 = min(z + passo_z, Z_CRUZ + 1.2)
                topo = rnd.uniform(-0.025, 0.02)
                self.por("pedra_esc", [caixa((x, -0.5, z), (x1, topo, z1))],
                         z_ref=(z + z1) / 2)
                x = x1
            z = z + passo_z
        # colisao do chao: uma laje lisa so'
        self.colide([caixa((-PAR_INT, -0.5, Z_OESTE_EXT), (PAR_INT, 0.0, Z_CRUZ + 1.2))])

        # Coro elevado + os tres degraus que sobem ate' o altar.
        #
        # Os degraus sao SO' VISUAIS. Quem carrega o jogador e' uma rampa lisa
        # invisivel por cima deles: `CharacterBody3D` nao tem step-up, e degrau
        # de 30 cm em quina viva simplesmente barra o corpo — era por isso que
        # nao dava pra subir no altar.
        self.solido("pedra_esc", [caixa((-NAVE_X, -0.5, Z_CRUZ + 1.2),
                                        (NAVE_X, CORO_Y, Z_CORO + 0.4))])
        z_deg0 = Z_CRUZ + 0.2
        for k in range(3):
            y = CORO_Y * (k + 1) / 3.0
            z0 = z_deg0 + 0.34 * k
            self.por("pedra_esc", [caixa((-NAVE_X - 1.2, -0.3, z0),
                                         (NAVE_X + 1.2, y, z0 + 0.34))],
                     z_ref=z0)
        z_deg1 = z_deg0 + 0.34 * 3
        self.colide([hexaedro([
            (-NAVE_X - 1.2, -0.3, z_deg0 - 0.5), (NAVE_X + 1.2, -0.3, z_deg0 - 0.5),
            (NAVE_X + 1.2, -0.3, Z_CRUZ + 1.3), (-NAVE_X - 1.2, -0.3, Z_CRUZ + 1.3),
            (-NAVE_X - 1.2, 0.0, z_deg0 - 0.5), (NAVE_X + 1.2, 0.0, z_deg0 - 0.5),
            (NAVE_X + 1.2, CORO_Y, Z_CRUZ + 1.3), (-NAVE_X - 1.2, CORO_Y, Z_CRUZ + 1.3)])])
        # piso da abside (poligono aproximado por lajes radiais)
        for k in range(9):
            a0 = -math.pi / 2 + math.pi * k / 9
            a1 = -math.pi / 2 + math.pi * (k + 1) / 9
            v = [(ABS_R * math.sin(a0) * 0.02, -0.5, Z_CORO),
                 (ABS_R * math.sin(a0), -0.5, Z_CORO + ABS_R * math.cos(a0)),
                 (ABS_R * math.sin(a1), -0.5, Z_CORO + ABS_R * math.cos(a1)),
                 (ABS_R * math.sin(a1) * 0.02, -0.5, Z_CORO)]
            v += [(p[0], CORO_Y, p[2]) for p in v]
            self.solido("pedra_esc", [hexaedro(v)], z_ref=Z_CORO + 2)

    # -- arcadas, pilares, triforio, clerestorio --------------------------
    def arcadas(self):
        for lado in (-1, 1):
            eixo = lado * EIXO
            mp = mapa_x(eixo)
            for cz in PILAR_Z:
                quebrado = (lado > 0 and abs(cz - 19.0) < 0.1)
                y_topo = 3.1 if quebrado else Y_ARC_ARR
                pecas, _ = pilar_composto(eixo, cz, 0.0, y_topo)
                self.por("pedra", pecas, z_ref=cz)
                self.colide([caixa((eixo - 1.05, 0.0, cz - 1.05),
                                   (eixo + 1.05, y_topo, cz + 1.05))])
                if quebrado:
                    # o topo do fuste virou tres tocos no chao da nave
                    for k, (dx, dz, giro) in enumerate(
                            ((-2.3, 0.6, 0.4), (-3.6, -0.9, 1.2), (-1.4, -2.1, 2.5))):
                        self.solido("pedra", [caixa_girada(
                            eixo + dx * lado, 0.62, cz + dz, 1.3, 1.24, 1.5,
                            giro, 1.4, self.rnd, 0.12)], z_ref=cz)

            # muro da arcada: vaos do chao ao arco entre pilar e pilar
            vaos = []
            for i in range(len(PILAR_Z) - 1):
                za, zb = PILAR_Z[i], PILAR_Z[i + 1]
                vaos.append({"u": (za + zb) / 2.0, "larg": (zb - za) - 1.7,
                             "peitoril": 0.0, "arranque": Y_ARC_ARR,
                             "flecha": ARC_FLECHA})
            # meia baia junto ao portal
            vaos.insert(0, {"u": (Z_OESTE + PILAR_Z[0]) / 2.0,
                            "larg": PILAR_Z[0] - Z_OESTE - 1.7,
                            "peitoril": 0.0, "arranque": Y_ARC_ARR,
                            "flecha": ARC_FLECHA})
            for p in painel(mp, Z_OESTE - 0.2, Z_CRUZ, 0.0, Y_GAL - GAL_LAJE,
                            ARC_W0, ARC_W1, vaos):
                self.por("pedra", p, z_ref=sum(v[2] for v in p[0]) / 8)
            # arquivoltas (o aro de pedra que acompanha cada arco)
            for vao in vaos:
                self.por("pedra", arquivolta(vao["u"], vao["larg"] + 0.3, Y_ARC_ARR,
                                             ARC_FLECHA + 0.15, 0.28,
                                             ARC_W0 - 0.12, ARC_W1 + 0.12, mp),
                         z_ref=vao["u"])
            # colisao do muro: so' os cheios entre vaos
            for i, cz in enumerate([Z_OESTE - 0.2] + PILAR_Z):
                pass
            self.colide([caixa((eixo + ARC_W0, 0.0, Z_OESTE - 0.2),
                               (eixo + ARC_W1, Y_GAL - GAL_LAJE, Z_OESTE + 1.0))])

            # laje da galeria + parapeito + triforio + clerestorio
            self.galeria(lado)

    def galeria(self, lado):
        eixo = lado * EIXO
        mp = mapa_x(eixo)
        rnd = self.rnd
        x0, x1 = (LAT_X0, PAR_INT) if lado > 0 else (-PAR_INT, -LAT_X0)

        # --- laje. A norte tem o poco da escada; a sul, o furo do caracol.
        trechos = [(Z_OESTE, Z_CRUZ + 1.6)]
        if lado < 0:
            trechos = [(ESC_Z2, Z_CRUZ + 1.6)]      # antes disso: vao aberto
        for (za, zb) in trechos:
            if lado > 0:
                # Poco da escada em caracol. O furo e' o MENOR possivel: antes
                # ele comia quase toda a largura da galeria e sobrava uma
                # passagem de meio metro na beirada — quem andasse pela galeria
                # sul caia no vazio sem encostar em nada. Agora sobra 1,65 m de
                # piso do lado de dentro, e o poco e' cercado (ver cercar_poco).
                zc0, zc1 = POCO_Z0, POCO_Z1
                self.laje_galeria(x0, x1, za, zc0)
                self.laje_galeria(x0, POCO_X, zc0, zc1)
                self.laje_galeria(x0, x1, zc1, zb)
                self.cercar_poco()
            else:
                self.laje_galeria(x0, x1, za, zb)

        # --- parapeito na borda interna (sobre a arcada), COM A BOCA DA
        # PASSARELA ABERTA. O parapeito corria inteiro e tapava justamente o
        # ponto onde a passarela de tabuas encosta: dava pra ver a travessia e
        # nao dava pra usar. Aqui ele e' cortado em dois trechos, com o vao da
        # passarela no meio — no visual E na colisao.
        za = ESC_Z2 if lado < 0 else Z_OESTE + 0.4
        zb = Z_CRUZ - 1.0
        boca0 = PASSARELA_Z - PASSARELA_BOCA
        boca1 = PASSARELA_Z + PASSARELA_BOCA
        for (ta, tb) in ((za, boca0), (boca1, zb)):
            if tb - ta < 0.6:
                continue
            self.por("pedra", parapeito_rendilhado(mp, ta, tb, Y_GAL,
                                                   Y_PARAPEITO, ARC_W0,
                                                   ARC_W1 * 0.2, rnd=rnd,
                                                   falhas=0.14), z_ref=(ta + tb) / 2)
            self.colide([caixa((eixo + ARC_W0, Y_GAL, ta),
                               (eixo + ARC_W1 * 0.2, Y_PARAPEITO, tb))])

        # --- triforio: arcada vazada entre a galeria e a nave
        vaos_trif = []
        for (za, zb) in BAIAS:
            meio = (za + zb) / 2.0
            larg = (zb - za) / 2.0 - 0.45
            for s in (-1, 1):
                vaos_trif.append({"u": meio + s * (zb - za) / 4.0, "larg": larg,
                                  "peitoril": 0.0, "arranque": Y_TRIF - 1.15,
                                  "flecha": larg * 0.85})
        for p in painel(mp, Z_OESTE - 0.2, Z_CRUZ, Y_PARAPEITO, Y_TRIF,
                        ARC_W0, ARC_W1, vaos_trif):
            self.por("pedra", p, z_ref=sum(v[2] for v in p[0]) / 8)
        for v in vaos_trif:   # coluneta no meio de cada vao
            self.por("pedra", coluneta(eixo, v["u"], Y_PARAPEITO,
                                       Y_TRIF - 1.15 + 0.1, 0.13), z_ref=v["u"])

        # --- parede cega + clerestorio
        for p in painel(mp, Z_OESTE - 0.2, Z_CRUZ, Y_TRIF, Y_CLER0,
                        ARC_W0, ARC_W1, []):
            self.por("pedra", p, z_ref=16)
        vaos_cler = []
        for (za, zb) in BAIAS:
            if zb - za < 6.0:
                continue
            meio = (za + zb) / 2.0
            for s in (-1, 1):
                vaos_cler.append({"u": meio + s * 1.35, "larg": 1.7,
                                  "peitoril": 0.55, "arranque": 3.7,
                                  "flecha": 1.6})
        for v in vaos_cler:
            v["peitoril"] += Y_CLER0
            v["arranque"] += Y_CLER0
        for p in painel(mp, Z_OESTE - 0.2, Z_CRUZ, Y_CLER0, Y_NAVE_ARR,
                        ARC_W0, ARC_W1, vaos_cler):
            self.por("pedra", p, z_ref=sum(v[2] for v in p[0]) / 8)
        for v in vaos_cler:
            self.vitral(mapa_x(eixo), v, "lanceta", ARC_W1 * 0.4, lado)

    def cercar_poco(self) -> None:
        """Guarda-corpo em volta do poco do caracol, com a boca da saida aberta.

        Sem isto o poco e' um alcapao de 4 m no meio do caminho da galeria sul.
        A abertura fica exatamente onde a helice desemboca (lado -X), que e'
        por onde o jogador sai — o resto e' fechado.
        """
        rnd = self.rnd
        x1 = PAR_INT
        cz = CARACOL[1]
        # bordas em Z (topo e fundo do poco), atravessando a largura toda
        for z in (POCO_Z0, POCO_Z1):
            mpz = mapa_z(z)
            self.por("pedra", parapeito_rendilhado(mpz, POCO_X, x1, Y_GAL,
                                                   Y_PARAPEITO, -0.12, 0.12,
                                                   rnd=rnd, falhas=0.1), z_ref=z)
            self.colide([caixa((POCO_X, Y_GAL, z - 0.12),
                               (x1, Y_PARAPEITO, z + 0.12))])
        # borda interna, menos a boca por onde se sai da escada
        mpx = mapa_x(POCO_X)
        for (za, zb) in ((POCO_Z0, cz - POCO_SAIDA), (cz + POCO_SAIDA, POCO_Z1)):
            if zb - za < 0.3:
                continue
            self.por("pedra", parapeito_rendilhado(mpx, za, zb, Y_GAL,
                                                   Y_PARAPEITO, -0.12, 0.12,
                                                   rnd=rnd, falhas=0.1),
                     z_ref=(za + zb) / 2)
            self.colide([caixa((POCO_X - 0.12, Y_GAL, za),
                               (POCO_X + 0.12, Y_PARAPEITO, zb))])

    def laje_galeria(self, x0, x1, z0, z1):
        if z1 - z0 < 0.4:
            return
        self.solido("pedra", [caixa((x0, Y_GAL - GAL_LAJE, z0), (x1, Y_GAL, z1))],
                    z_ref=(z0 + z1) / 2)

    # -- paredes laterais -------------------------------------------------
    def paredes_laterais(self):
        for lado in (-1, 1):
            xi = lado * PAR_INT
            xe = lado * PAR_EXT
            mp = mapa_x(xi)
            w0, w1 = (0.0, PAR_EXT - PAR_INT) if lado > 0 else (PAR_INT - PAR_EXT, 0.0)

            # termeo: uma lanceta larga por baia
            vaos = []
            for (za, zb) in BAIAS:
                if zb - za < 6.0:
                    continue
                vaos.append({"u": (za + zb) / 2.0, "larg": 2.4, "peitoril": 1.7,
                             "arranque": 3.6, "flecha": 1.94})
            for p in painel(mp, Z_OESTE_EXT, Z_CRUZ + 1.6, 0.0, Y_GAL,
                            w0, w1, vaos):
                self.por("pedra", p, z_ref=sum(v[2] for v in p[0]) / 8)
            self.colide([caixa((min(xi, xe), 0.0, Z_OESTE_EXT),
                               (max(xi, xe), Y_GAL_TETO, Z_CRUZ + 1.6))])
            for v in vaos:
                self.vitral(mp, v, "larga", w1 * 0.5 if lado > 0 else w0 * 0.5,
                            lado, roto=True)
                self.pontos["janelas"].append(
                    {"pos": [xi - lado * 0.4, v["peitoril"] + 1.9, v["u"]],
                     "dir": [-lado, -0.25, 0.0], "tipo": "baixa"})

            # galeria: lancetas esbeltas
            vaos_g = []
            for (za, zb) in BAIAS:
                if zb - za < 6.0:
                    continue
                vaos_g.append({"u": (za + zb) / 2.0, "larg": 1.5,
                               "peitoril": 10.8, "arranque": 13.45, "flecha": 1.35})
            for p in painel(mp, Z_OESTE_EXT, Z_CRUZ + 1.6, Y_GAL, Y_GAL_TETO + 0.6,
                            w0, w1, vaos_g):
                self.por("pedra", p, z_ref=sum(v[2] for v in p[0]) / 8)
            for v in vaos_g:
                self.vitral(mp, v, "lanceta", w1 * 0.5 if lado > 0 else w0 * 0.5, lado)
                self.pontos["janelas"].append(
                    {"pos": [xi - lado * 0.4, 12.6, v["u"]],
                     "dir": [-lado, -0.3, 0.0], "tipo": "galeria"})

    # -- fachada oeste ----------------------------------------------------
    def fachada(self):
        mp = mapa_z(Z_OESTE)
        w0, w1 = Z_OESTE_EXT - Z_OESTE, 0.0
        vaos = [{"u": 0.0, "larg": 3.8, "peitoril": 0.0, "arranque": 4.4,
                 "flecha": 2.9}]
        for s in (-1, 1):
            vaos.append({"u": s * 9.9, "larg": 2.2, "peitoril": 2.0,
                         "arranque": 3.9, "flecha": 1.76})
        for p in painel(mp, -PAR_EXT, PAR_EXT, 0.0, 11.6, w0, w1, vaos):
            self.por("pedra", p, z_ref=1.0)
        self.por("pedra", arquivolta(0.0, 4.3, 4.4, 3.1, 0.35, w0 - 0.2, w1, mp),
                 z_ref=1.0)
        for s in (-1, 1):
            self.vitral(mp, vaos[1 if s < 0 else 2], "larga", w0 * 0.5, 1,
                        roto=True, eixo_z=True)

        # rosacea: aro de pedra, raios e o vitral redondo
        cy, r = 15.4, 3.5
        self.roseta(cy, r, w0, w1)
        # macico em volta da rosacea ate' a cumeeira
        for (a, b) in ((-PAR_EXT, -r - 1.3), (r + 1.3, PAR_EXT)):
            self.por("pedra", [geo._caixa_mapa(mp, a, b, 11.6, 24.0, w0, w1)], z_ref=1)
        self.por("pedra", [geo._caixa_mapa(mp, -r - 1.3, r + 1.3, 11.6, cy - r - 0.9,
                                           w0, w1)], z_ref=1)
        self.por("pedra", [geo._caixa_mapa(mp, -r - 1.3, r + 1.3, cy + r + 0.9, 24.0,
                                           w0, w1)], z_ref=1)
        self.colide([caixa((-PAR_EXT, 0.0, Z_OESTE_EXT), (PAR_EXT, 24.0, Z_OESTE))])

        # portal: as duas folhas arrancadas, uma pendurada e uma no chao
        self.solido("madeira", [caixa_girada(-1.3, 1.75, 0.35, 1.75, 3.5, 0.16,
                                             0.0, 0.0)], z_ref=0.4)
        self.por("madeira", [caixa_girada(2.6, 0.09, 2.4, 1.8, 0.16, 3.4, 0.6, 0.0)],
                 z_ref=2.4)
        for k in range(3):
            self.por("metal", [caixa((-2.1, 0.6 + k * 1.2, 0.28),
                                     (-0.45, 0.78 + k * 1.2, 0.44))], z_ref=0.4)

    def roseta(self, cy, r, w0, w1):
        mp = mapa_z(Z_OESTE)
        n = 16
        # aro externo
        for k in range(n):
            a0 = 2 * math.pi * k / n
            a1 = 2 * math.pi * (k + 1) / n
            v = []
            for (rr, a) in ((r, a0), (r, a1), (r + 0.55, a1), (r + 0.55, a0)):
                v.append((rr * math.cos(a), cy + rr * math.sin(a), Z_OESTE + w0))
            v2 = [(p[0], p[1], Z_OESTE + w1) for p in v]
            self.por("pedra", [hexaedro(v + v2)], z_ref=1.0)
        # raios
        for k in range(8):
            a = math.pi * k / 8
            self.por("pedra", [caixa_girada(r * 0.0, cy, Z_OESTE + (w0 + w1) / 2,
                                            r * 2.0, 0.22, abs(w1 - w0) * 0.55,
                                            0.0, a)], z_ref=1.0)
        # o vidro
        quad = [(-r, cy - r, Z_OESTE + w1 * 0.5 + w0 * 0.5),
                (r, cy - r, Z_OESTE + w1 * 0.5 + w0 * 0.5),
                (r, cy + r, Z_OESTE + w1 * 0.5 + w0 * 0.5),
                (-r, cy + r, Z_OESTE + w1 * 0.5 + w0 * 0.5)]
        self.m.add("a", "vitral_rosacea", quad, [[0, 1, 2, 3]],
                   uvs=[[(0, 1), (1, 1), (1, 0), (0, 0)]])

    # -- vitrais ----------------------------------------------------------
    def vitral(self, mapa, vao, tipo, w, lado, roto=False, eixo_z=False):
        """Um quad com a textura do vitral. O contorno ogival vem do alfa da
        textura — modelar o recorte em malha seria 200 triangulos por janela
        pra ganhar nada."""
        u0 = vao["u"] - vao["larg"] / 2.0
        u1 = vao["u"] + vao["larg"] / 2.0
        y0 = vao["peitoril"]
        y1 = vao["arranque"] + vao["flecha"]
        p = [mapa(u0, y0, w), mapa(u1, y0, w), mapa(u1, y1, w), mapa(u0, y1, w)]
        uv = [(0, 1), (1, 1), (1, 0), (0, 0)]
        nome = "vitral_" + tipo + ("_roto" if roto else "")
        self.m.add(setor(p[0][2]), nome, p, [[0, 1, 2, 3]], uvs=[uv])

    # -- abobadas ---------------------------------------------------------
    def abobadas(self):
        # nave central
        for i, (za, zb) in enumerate(BAIAS):
            if zb - za < 6.0:
                continue
            rompida = (i == BAIA_ROMPIDA)
            if not rompida:
                self.por("pedra", [abobada_cruzaria(-NAVE_X, NAVE_X, za, zb,
                                                    Y_NAVE_ARR, NAVE_FLECHA, 0.34, 9)],
                         z_ref=(za + zb) / 2, suave=True)
            else:
                # sobram as quatro franjas coladas nos arcos; o miolo virou a
                # pilha la' embaixo. Cada franja continua na curva original —
                # e' o que faz o rombo parecer arrancado e nao desenhado.
                meio = (za + 1.8, zb - 2.2)
                fatias = [
                    dict(recorte_z=(za, za + 1.8)),
                    dict(recorte_z=(zb - 2.2, zb)),
                    dict(recorte_z=meio, recorte_x=(-NAVE_X, -NAVE_X + 2.2)),
                    dict(recorte_z=meio, recorte_x=(NAVE_X - 2.6, NAVE_X)),
                ]
                for corte in fatias:
                    self.por("pedra", [abobada_cruzaria(-NAVE_X, NAVE_X, za, zb,
                                                        Y_NAVE_ARR, NAVE_FLECHA,
                                                        0.34, 9, **corte)],
                             z_ref=(za + zb) / 2, suave=True)
                self.telhado_rompido(za, zb)
            self.nervuras(-NAVE_X, NAVE_X, za, zb, Y_NAVE_ARR, NAVE_FLECHA,
                          rompida)
            # arcos transversais (formeiros) sobre os pilares
            mp = mapa_z(zb)
            self.por("pedra", arquivolta(0.0, 2 * NAVE_X, Y_NAVE_ARR, NAVE_FLECHA,
                                         0.45, -0.32, 0.32, mp), z_ref=zb)

        # naves laterais: a norte perdeu duas baias (e' onde a escada sobe)
        for lado in (-1, 1):
            x0 = LAT_X0 if lado > 0 else -PAR_INT
            x1 = PAR_INT if lado > 0 else -LAT_X0
            for i, (za, zb) in enumerate(BAIAS):
                if zb - za < 6.0:
                    continue
                if lado < 0 and i in (1, 2):
                    continue
                if lado > 0 and i == 4:
                    continue     # furo do caracol
                self.por("pedra", [abobada_cruzaria(x0, x1, za, zb, Y_LAT_ARR,
                                                    LAT_FLECHA, 0.3, 7)],
                         z_ref=(za + zb) / 2, suave=True)
                self.nervuras(x0, x1, za, zb, Y_LAT_ARR, LAT_FLECHA, False, 0.24)

        # teto das galerias (chapado, com nervura simples)
        for lado in (-1, 1):
            x0 = LAT_X0 if lado > 0 else -PAR_INT
            x1 = PAR_INT if lado > 0 else -LAT_X0
            for i, (za, zb) in enumerate(BAIAS):
                if zb - za < 6.0:
                    continue
                if lado < 0 and i == 1:
                    continue
                self.por("pedra", [abobada_cruzaria(x0, x1, za, zb,
                                                    Y_GAL_TETO - 2.1, 2.1, 0.3, 6)],
                         z_ref=(za + zb) / 2, suave=True)

    def telhado_rompido(self, za, zb):
        """O que restou da estrutura de telhado por cima do rombo.

        Sem isto o buraco vira um retangulo de ceu limpo no alto da nave e
        entrega que a igreja nao tem telhado nenhum modelado: duas tercas
        partidas e um caibro atravessado bastam pra leitura ficar certa, e
        ainda recortam o feixe de luz que desce por ali.
        """
        y = Y_NAVE_ARR + NAVE_FLECHA
        rnd = self.rnd
        for (x0, x1, dz, dy) in ((-NAVE_X, 2.1, 1.4, 0.9), (-1.4, NAVE_X, 4.6, 0.5),
                                 (-3.0, 3.4, 6.4, 1.3)):
            self.por("madeira", [tubo([(x0, y + dy + rnd.uniform(0, 0.4), za + dz),
                                       (x1, y + dy * 0.4, za + dz + rnd.uniform(-0.6, 0.6))],
                                      0.3, 0.34)], z_ref=za + dz)
        for k in range(4):
            z = za + 1.0 + k * 1.7
            self.por("madeira", [tubo([(-NAVE_X + 0.4, y + 1.5, z),
                                       (-NAVE_X + 2.6 + k * 0.8, y + 0.3, z)],
                                      0.18, 0.2)], z_ref=z)

    def nervuras(self, x0, x1, z0, z1, y_arr, flecha, rompida, larg=0.32):
        flechad = flecha + 0.12
        if not rompida:
            self.por("pedra", [nervura_diagonal(x0, x1, z0, z1, y_arr, flechad, larg, larg)],
                     z_ref=(z0 + z1) / 2)
            self.por("pedra", [nervura_diagonal(x0, x1, z1, z0, y_arr, flechad, larg, larg)],
                     z_ref=(z0 + z1) / 2)
            return
        # nervura partida: sobe do arranque e morre no ar
        for (ax, az, bx, bz) in ((x0, z0, x1, z1), (x1, z0, x0, z1)):
            pontos = []
            diag = math.hypot(bx - ax, bz - az)
            perfil = arco_perfil(diag, flechad, 10)
            corte = self.rnd.choice((3, 4))
            for i in range(corte + 1):
                t = i / 10.0
                pontos.append((ax + (bx - ax) * t, y_arr + perfil[i][1],
                               az + (bz - az) * t))
            self.por("pedra", [tubo(pontos, larg, larg)], z_ref=(z0 + z1) / 2)
            pontos = []
            for i in range(10 - corte, 11):
                t = i / 10.0
                pontos.append((ax + (bx - ax) * t, y_arr + perfil[i][1],
                               az + (bz - az) * t))
            self.por("pedra", [tubo(pontos, larg, larg)], z_ref=(z0 + z1) / 2)

    # -- coro, arco triunfal, abside --------------------------------------
    def coro_e_abside(self):
        # arco triunfal: muro cheio com um vao ogival enorme
        mp = mapa_z(Z_CRUZ)
        vao = {"u": 0.0, "larg": 2 * NAVE_X - 0.6, "peitoril": 0.0,
               "arranque": 12.0, "flecha": 6.4}
        for p in painel(mp, -PAR_INT, PAR_INT, 0.0, Y_NAVE_ARR + 4.0,
                        -0.75, 0.75, [vao]):
            self.por("pedra", p, z_ref=Z_CRUZ)
        self.por("pedra", arquivolta(0.0, 2 * NAVE_X - 0.3, 12.0, 6.6, 0.4,
                                     -0.95, 0.95, mp), z_ref=Z_CRUZ)
        self.colide([caixa((-PAR_INT, 0.0, Z_CRUZ - 0.75), (-NAVE_X, Y_GAL, Z_CRUZ + 0.75)),
                     caixa((NAVE_X, 0.0, Z_CRUZ - 0.75), (PAR_INT, Y_GAL, Z_CRUZ + 0.75))])

        # muros do coro
        for lado in (-1, 1):
            x = lado * NAVE_X
            mpx = mapa_x(x)
            vaos = [{"u": (Z_CRUZ + Z_CORO) / 2.0, "larg": 3.0, "peitoril": 2.6,
                     "arranque": 5.4, "flecha": 1.9}]
            for p in painel(mpx, Z_CRUZ, Z_CORO + 0.4, 0.0, 18.0,
                            0.0, lado * 1.1, vaos):
                self.por("pedra", p, z_ref=Z_CORO - 3)
            self.colide([caixa((x, 0.0, Z_CRUZ), (x + lado * 1.1, 18.0, Z_CORO + 0.4))])
            self.por("pedra", [abobada_cruzaria(-NAVE_X, NAVE_X, Z_CRUZ, Z_CORO,
                                                16.0, 4.4, 0.34, 9)],
                     z_ref=Z_CORO - 3, suave=True) if lado < 0 else None

        # abside: panos poligonais com lancetas altas + meia cupula
        n = 5
        for k in range(n):
            a0 = -math.pi / 2 + math.pi * k / n
            a1 = -math.pi / 2 + math.pi * (k + 1) / n
            am = (a0 + a1) / 2.0
            larg = 2 * ABS_R * math.sin((a1 - a0) / 2.0)
            ox = ABS_R * math.sin(am)
            oz = Z_CORO + ABS_R * math.cos(am)
            mpa = mapa_girado(ox, oz, am + math.pi / 2)
            vao = {"u": 0.0, "larg": larg * 0.52, "peitoril": CORO_Y + 2.2,
                   "arranque": CORO_Y + 6.0, "flecha": larg * 0.3}
            for p in painel(mpa, -larg / 2, larg / 2, 0.0, 16.0, 0.0, 1.2, [vao]):
                self.por("pedra", p, z_ref=oz)
            self.vitral(mpa, vao, "larga", 0.5, 1)
            self.pontos["janelas"].append(
                {"pos": [ox * 0.82, CORO_Y + 5.0, oz - math.cos(am) * 1.2],
                 "dir": [-math.sin(am), -0.35, -math.cos(am)], "tipo": "abside"})
            self.colide([hexaedro([
                mpa(-larg / 2, 0.0, 0.0), mpa(larg / 2, 0.0, 0.0),
                mpa(larg / 2, 0.0, 1.2), mpa(-larg / 2, 0.0, 1.2),
                mpa(-larg / 2, 16.0, 0.0), mpa(larg / 2, 16.0, 0.0),
                mpa(larg / 2, 16.0, 1.2), mpa(-larg / 2, 16.0, 1.2)])])
        self.por("pedra", [semicupula(0.0, Z_CORO, ABS_R, 16.0, 4.2, 0.34, 10, 6)],
                 z_ref=Z_CORO + 3, suave=True)

        self.altar()

    def altar(self):
        z = Z_CORO + 1.6
        # mesa rachada em duas metades, uma escorregada
        self.solido("pedra", [caixa((-1.9, CORO_Y, z - 0.9), (-0.1, CORO_Y + 1.05, z + 0.9))],
                    z_ref=z)
        self.solido("pedra", [caixa_girada(1.05, CORO_Y + 0.5, z + 0.1, 1.8, 1.0, 1.8,
                                           0.12)], z_ref=z)
        self.por("pedra_esc", [caixa((-2.3, CORO_Y, z - 1.3), (2.3, CORO_Y + 0.18, z + 1.3))],
                 z_ref=z)
        # retabulo arruinado atras
        self.solido("madeira", [caixa((-2.6, CORO_Y, z + 2.4), (2.6, CORO_Y + 4.2, z + 2.8))],
                    z_ref=z + 2.6)
        for k in range(5):
            x = -2.0 + k
            self.por("ouro", [caixa((x - 0.28, CORO_Y + 1.0, z + 2.2),
                                    (x + 0.28, CORO_Y + 3.4, z + 2.45))], z_ref=z + 2.3)
        # cruz tombada no chao do coro
        self.por("ouro", cruz(0.8, CORO_Y + 0.12, z - 3.4, 2.6, 0.2, 0.9, math.pi / 2 * 0.96),
                 z_ref=z - 3.4)
        # castical caido + velas
        for k, (dx, dz) in enumerate(((-2.8, -0.4), (2.9, 0.7), (-3.2, 2.2))):
            self.por("metal", [cilindro(dx, z + dz, 0.16, CORO_Y, CORO_Y + 0.9, 6)],
                     z_ref=z)
            self.pontos["velas"].append([dx, CORO_Y + 1.05, z + dz])

    # -- segundo andar: escadas e passarelas -------------------------------
    def circulacao(self):
        rnd = self.rnd
        # ---- escada reta de pedra, dois lances, nave lateral norte
        pecas, rampa = escada_reta(ESC_X0 + 0.25, ESC_X1, ESC_Z0, ESC_Z1,
                                   0.0, 5.2, 20)
        self.por("pedra", pecas, z_ref=(ESC_Z0 + ESC_Z1) / 2)
        self.colide([rampa])
        self.solido("pedra", [caixa((ESC_X0 + 0.25, 4.9, ESC_Z1),
                                    (ESC_X1, 5.2, ESC_PAT_Z))], z_ref=ESC_Z1)
        pecas, rampa = escada_reta(ESC_X0 + 0.25, ESC_X1, ESC_PAT_Z, ESC_Z2,
                                   5.2, Y_GAL, 18)
        self.por("pedra", pecas, z_ref=(ESC_PAT_Z + ESC_Z2) / 2)
        self.colide([rampa])
        # muro de apoio da escada (por baixo, pra nao flutuar)
        self.por("pedra", [caixa((ESC_X0 + 0.25, -0.4, ESC_Z0), (ESC_X1, 0.2, ESC_Z2))],
                 z_ref=8)
        # parapeito do lado aberto
        mpe = mapa_x(ESC_X1)
        for (za, zb, ya, yb) in ((ESC_Z0, ESC_Z1, 0.0, 5.2),
                                 (ESC_Z1, ESC_PAT_Z, 5.2, 5.2),   # o patamar
                                 (ESC_PAT_Z, ESC_Z2, 5.2, Y_GAL)):
            n = 9
            for k in range(n):
                t0, t1 = k / n, (k + 1) / n
                z0 = za + (zb - za) * t0
                z1 = za + (zb - za) * t1
                y0 = ya + (yb - ya) * t0
                y1 = ya + (yb - ya) * t1
                if rnd.random() < 0.18:
                    continue   # trecho arrebentado
                self.por("pedra", [hexaedro([
                    (ESC_X1 - 0.16, y0 + 0.5, z0), (ESC_X1, y0 + 0.5, z0),
                    (ESC_X1, y0 + 0.5, z1), (ESC_X1 - 0.16, y0 + 0.5, z1),
                    (ESC_X1 - 0.16, y0 + 1.45, z0), (ESC_X1, y0 + 1.45, z0),
                    (ESC_X1, y1 + 1.45, z1), (ESC_X1 - 0.16, y1 + 1.45, z1)])],
                    z_ref=z0)
        self.colide([hexaedro([
            (ESC_X1 - 0.2, 0.0, ESC_Z0), (ESC_X1, 0.0, ESC_Z0),
            (ESC_X1, 0.0, ESC_Z2), (ESC_X1 - 0.2, 0.0, ESC_Z2),
            (ESC_X1 - 0.2, 1.5, ESC_Z0), (ESC_X1, 1.5, ESC_Z0),
            (ESC_X1, Y_GAL + 1.1, ESC_Z2), (ESC_X1 - 0.2, Y_GAL + 1.1, ESC_Z2)])])

        # Boca do poço, no alto: da galeria norte, o vão por onde a escada sobe
        # fica logo ATRÁS de quem acaba de chegar. Um passo pra trás e a queda é
        # de 10 m. Cerca a boca toda menos a largura da escada, que é por onde
        # se entra e se sai.
        mpp = mapa_z(ESC_Z2 - 0.15)
        # a faixa da escada (de ESC_X0 a ESC_X1) fica ABERTA: é a porta.
        self.por("pedra", parapeito_rendilhado(mpp, ESC_X1, -LAT_X0, Y_GAL,
                                               Y_PARAPEITO, -0.12, 0.12,
                                               rnd=rnd, falhas=0.08),
                 z_ref=ESC_Z2)
        self.colide([caixa((ESC_X1, Y_GAL, ESC_Z2 - 0.27),
                           (-LAT_X0, Y_PARAPEITO, ESC_Z2 - 0.03))])

        # ---- escada em caracol, nave lateral sul
        cx, cz = CARACOL
        self.solido("pedra", [cilindro(cx, cz, 0.42, 0.0, Y_GAL + 1.2, 8)], z_ref=cz)
        pecas, rampas = escada_caracol(cx, cz, 0.40, CARACOL_R, 0.0, Y_GAL,
                                       44, math.radians(CARACOL_GIRO), fase=math.pi)
        self.por("pedra", pecas, z_ref=cz)
        self.colide(rampas)
        # corrimao de ferro acompanhando a helice
        pts = []
        for k in range(45):
            a = math.pi + math.radians(CARACOL_GIRO) * k / 44.0
            pts.append((cx + CARACOL_R * 0.94 * math.cos(a), Y_GAL * k / 44.0 + 1.0,
                        cz + CARACOL_R * 0.94 * math.sin(a)))
        self.por("metal", [tubo(pts, 0.07, 0.07)], z_ref=cz)

        # ---- passarela de tabuas no meio da nave (Z=22)
        z0, z1 = PASSARELA_Z - 0.95, PASSARELA_Z + 0.95
        for s in (-1, 1):   # duas vigas mestras
            self.solido("madeira", [caixa((-NAVE_X - 0.9, Y_GAL - 0.34, PASSARELA_Z + s * 0.72),
                                          (NAVE_X + 0.9, Y_GAL - 0.06,
                                           PASSARELA_Z + s * 0.72 + 0.22))],
                        z_ref=PASSARELA_Z)
        x = -NAVE_X - 0.9
        while x < NAVE_X + 0.75:
            larg = rnd.uniform(0.3, 0.45)
            folga = rnd.uniform(0.01, 0.06)
            self.por("madeira", [caixa_girada(x + larg / 2, Y_GAL - 0.03,
                                              PASSARELA_Z + rnd.uniform(-0.04, 0.04),
                                              larg, 0.07, 1.9 + rnd.uniform(-0.1, 0.1),
                                              rnd.uniform(-0.02, 0.02))],
                     z_ref=PASSARELA_Z)
            x += larg + folga
        self.colide([caixa((-NAVE_X - 0.9, Y_GAL - 0.12, z0), (NAVE_X + 0.9, Y_GAL, z1))])
        # cordas nas laterais, presas em ganchos
        for s in (-1, 1):
            self.por("metal", [tubo([(-NAVE_X - 0.8, Y_GAL + 0.95, PASSARELA_Z + s * 0.95),
                                     (0.0, Y_GAL + 0.72, PASSARELA_Z + s * 0.95),
                                     (NAVE_X + 0.8, Y_GAL + 0.95, PASSARELA_Z + s * 0.95)],
                                    0.05, 0.05)], z_ref=PASSARELA_Z)

        # ---- jube' de pedra sobre o arco triunfal (Z=33)
        for (xa, xb) in ((-PAR_INT, -2.2), (2.2, PAR_INT)):
            self.solido("pedra", [caixa((xa, Y_GAL - GAL_LAJE, JUBE_Z0),
                                        (xb, Y_GAL, JUBE_Z1))], z_ref=Z_CRUZ)
        # o meio desabou: tabuas grossas atravessando o rombo
        for k in range(6):
            x = -2.4 + k * 0.82
            self.por("madeira", [caixa_girada(x, Y_GAL - 0.05, (JUBE_Z0 + JUBE_Z1) / 2,
                                              0.72, 0.12, 3.1 + rnd.uniform(-0.2, 0.2),
                                              rnd.uniform(-0.03, 0.03))], z_ref=Z_CRUZ)
        self.colide([caixa((-2.5, Y_GAL - 0.14, JUBE_Z0 + 0.1),
                           (2.5, Y_GAL, JUBE_Z1 - 0.1))])
        # Parapeitos do jube', SO' no trecho que atravessa a nave (|x| < 7,45).
        #
        # Antes eles corriam de parede a parede, inclusive nas duas pontas onde
        # o jube' encosta nas galerias — e essas pontas sao justamente por onde
        # se entra nele. O guarda-corpo fechava a unica porta: dava pra ver a
        # travessia do outro lado e nao dava pra pisar nela. Agora as pontas
        # ficam abertas (ali nao ha' queda: e' piso de galeria dos dois lados)
        # e o parapeito existe onde existe o vazio, sobre o arco triunfal.
        for s in (-1, 1):
            mpj = mapa_z(JUBE_Z0 - 0.12 if s < 0 else JUBE_Z1 + 0.12)
            for (xa, xb) in ((-LAT_X0, -2.6), (2.6, LAT_X0)):
                self.por("pedra", parapeito_rendilhado(mpj, xa, xb, Y_GAL,
                                                       Y_PARAPEITO, -0.14, 0.14,
                                                       rnd=rnd, falhas=0.2),
                         z_ref=Z_CRUZ)
            zc0 = JUBE_Z0 - 0.26 if s < 0 else JUBE_Z1
            for (xa, xb) in ((-LAT_X0, -2.6), (2.6, LAT_X0)):
                self.colide([caixa((xa, Y_GAL, zc0), (xb, Y_PARAPEITO, zc0 + 0.26))])
        # pedaco do parapeito caido la' embaixo
        # (encostado no pilar, fora do corredor: no meio da nave virava um
        # tropeco de 90 cm bem na linha de quem anda em direcao ao altar)
        self.solido("pedra", [caixa_girada(5.6, 0.45, Z_CRUZ - 2.6, 2.6, 0.9, 0.4,
                                           0.3, 0.15, rnd, 0.06)], z_ref=Z_CRUZ - 2.6)

    # -- ruina, mobilia, atmosfera ----------------------------------------
    def ruina(self):
        rnd = self.rnd
        za, zb = BAIAS[BAIA_ROMPIDA]
        cz = (za + zb) / 2.0

        # A pedra que caiu da abobada foi EMPURRADA PROS CANTOS. A pilha
        # ficava no meio da nave, debaixo do rombo, o que e' o realista — e
        # era um tropeco permanente bem no caminho de quem entra e quer chegar
        # ao altar. Ficou assim: o corredor central limpo, com cacos rasos que
        # nao barram ninguem, e as montanhas de pedra encostadas nos pilares e
        # nas paredes, onde ninguem precisa passar. Continua lendo como
        # "isto desabou daqui de cima", sem ser um muro.
        for (px, pz, raio, n, alto) in (
                (-9.8, cz - 2.0, 3.0, 34, 1.5),
                (9.9, cz + 1.5, 3.1, 34, 1.5),
                (-5.6, cz + 4.4, 2.0, 16, 0.9),
                (5.4, cz - 4.6, 2.1, 16, 0.9)):
            self.por("pedra", entulho(px, pz, raio, n, rnd, tamanho=(0.4, 1.2),
                                      altura_pilha=alto), z_ref=pz)
            self.colide([domo(px, pz, raio + 0.4, alto * 0.9, 12)])
        # o que sobrou no meio: caco raso, so' pra sujar o chao
        self.por("pedra_esc", entulho(0.0, cz, 6.4, 55, rnd, tamanho=(0.14, 0.42)),
                 z_ref=cz)
        self.pontos["escombros"].append([0.0, 0.6, cz])
        # vigas do telhado que vieram junto
        # As tercas caidas encostam nas pilhas dos cantos, e nao atravessam o
        # corredor: viga no meio do caminho e' a mesma armadilha da pilha.
        for (x0, y0, z0, x1, y1, z1) in (
                (-12.0, 3.2, cz - 3.4, -5.6, 0.5, cz - 0.4),
                (12.1, 2.9, cz + 3.0, 6.0, 0.45, cz + 0.2),
                (-11.4, 0.5, cz + 4.6, -6.2, 0.4, cz + 5.6)):
            self.solido("madeira", [viga_caida(x0, y0, z0, x1, y1, z1, 0.32, 0.38)],
                        z_ref=cz)

        # abobada da lateral norte caida
        self.por("pedra", entulho(-9.6, 13.5, 3.0, 34, rnd, tamanho=(0.3, 0.95),
                                  altura_pilha=0.9), z_ref=13.5)
        self.colide([domo(-9.6, 13.5, 3.3, 0.8, 10)])

        # entulho espalhado pelo resto, mais fino
        for _ in range(90):
            x = rnd.uniform(-PAR_INT + 1.0, PAR_INT - 1.0)
            z = rnd.uniform(Z_OESTE + 1.0, Z_CORO)
            # corredor central sempre limpo, em toda a nave
            if abs(x) < 3.2:
                continue
            if abs(x) < 7.6 and abs(z - cz) < 6.0:
                continue
            s = rnd.uniform(0.15, 0.45)
            self.por("pedra_esc", [caixa_girada(x, s * 0.3, z, s, s * 0.6, s * 1.1,
                                                rnd.uniform(0, 3.14),
                                                rnd.uniform(-0.3, 0.3), rnd, 0.35)],
                     z_ref=z)

        # cacos de vitral no chao, embaixo das janelas baixas
        for j in self.pontos["janelas"]:
            if j["tipo"] != "baixa":
                continue
            jx, _, jz = j["pos"]
            for _ in range(7):
                x = jx + rnd.uniform(-0.2, 1.8) * (1 if jx < 0 else -1)
                z = jz + rnd.uniform(-1.4, 1.4)
                self.m.add(setor(z), "vidro", *caixa_girada(
                    x, 0.02, z, rnd.uniform(0.12, 0.3), 0.02,
                    rnd.uniform(0.12, 0.3), rnd.uniform(0, 3.14)))

        # bancos: em ordem na frente, revirados perto do buraco
        z = 5.0
        fila = 0
        while z < 30.0:
            if abs(z - cz) < 3.6:
                z += 1.55
                fila += 1
                continue
            for s in (-1, 1):
                caos = max(0.0, 1.0 - abs(z - cz) / 11.0)
                giro = rnd.uniform(-0.5, 0.5) * caos
                dx = rnd.uniform(-1.2, 1.2) * caos
                tombado = rnd.random() < caos * 0.55
                self.por("madeira", banco(s * 4.05 + dx, z + rnd.uniform(-0.3, 0.3) * caos,
                                          4.6, 0.62, giro, tombado, 0.3, rnd),
                         z_ref=z)
            z += 1.55
            fila += 1

        # confessionario destruido na lateral sul
        self.solido("madeira", [caixa((9.4, 0.0, 14.2), (11.9, 2.9, 16.4))], z_ref=15)
        self.por("madeira", [caixa_girada(9.0, 0.12, 13.2, 1.2, 0.14, 2.2, 0.7)], z_ref=13)
        self.por("madeira", [caixa((10.2, 2.9, 14.4), (11.6, 3.3, 16.2))], z_ref=15)

        # pia batismal quebrada, perto da entrada
        self.solido("pedra", [cilindro(9.6, 3.4, 0.55, 0.0, 0.9, 8, raio_topo=0.42)],
                    z_ref=3.4)
        self.por("pedra", [cilindro(9.6, 3.4, 1.05, 0.9, 1.35, 8, raio_topo=0.95)],
                 z_ref=3.4)
        self.por("pedra", [caixa_girada(8.2, 0.2, 4.6, 1.1, 0.35, 1.0, 0.8, 0.5, rnd, 0.2)],
                 z_ref=4.6)

        # pulpito de pedra preso no pilar norte de Z=19
        self.solido("pedra", [cilindro(-6.0, 19.0, 1.25, 2.6, 3.9, 7),
                              cilindro(-6.0, 19.0, 0.45, 0.0, 2.6, 7)], z_ref=19)
        self.por("pedra", [cilindro(-6.0, 19.0, 1.35, 3.75, 3.95, 7)], z_ref=19)

        # candelabros: dois pendurados, um caido na nave
        for (cx, cz2, y) in ((0.0, 8.0, 13.4), (0.0, 28.0, 13.0)):
            self.por("metal", candelabro(cx, y, cz2, 1.25, 8), z_ref=cz2)
            self.por("metal", [corrente(cx, cz2, y, Y_NAVE_ARR + 3.4)], z_ref=cz2)
            self.pontos["candelabros"].append([cx, y, cz2])
        self.por("metal", candelabro(-3.4, 0.5, 25.4, 1.25, 8, caido=True, giro=0.6),
                 z_ref=25.4)
        self.por("metal", [corrente(-3.4, 25.4, 1.0, Y_NAVE_ARR + 2.0)], z_ref=25.4)

        # Tochas nas paredes: os pontos quentes do lugar. ALTERNADAS de lado, e
        # nao em pares: par de tochas na mesma baia dobra a conta de luzes que
        # alcanca aquela fatia da nave, e o renderer mobile corta em oito.
        # Alternando, a nave fica iluminada em ziguezague — que ainda por cima
        # fica melhor do que corredor simetrico.
        for i, z in enumerate((7.0, 12.0, 17.0, 22.0, 27.0, 31.0)):
            s = -1 if i % 2 == 0 else 1
            x = s * (PAR_INT - 0.35)
            self.por("metal", [tubo([(x, 2.4, z), (x - s * 0.55, 2.9, z)], 0.1, 0.1)],
                     z_ref=z)
            self.pontos["tochas"].append([x - s * 0.62, 3.0, z])

        # Tochas TAMBEM nas galerias. Isto nao e' enfeite: o 2o andar, so' com
        # a luz que sobe da nave, ficava preto o bastante pra nao dar pra ver
        # onde acaba o piso — e ali se anda a 10 m de altura, ao lado de um
        # parapeito com falhas.
        for (lado, z) in ((-1, 20.5), (1, 10.0), (1, 29.0)):
            x = lado * (PAR_INT - 0.35)
            self.por("metal", [tubo([(x, Y_GAL + 2.2, z),
                                     (x - lado * 0.55, Y_GAL + 2.7, z)], 0.1, 0.1)],
                     z_ref=z)
            self.pontos["tochas"].append([x - lado * 0.62, Y_GAL + 2.8, z])

        # cadeiral do coro: duas fileiras encostadas nos muros, arrebentadas
        for lado in (-1, 1):
            x = lado * (NAVE_X - 1.5)
            z = Z_CRUZ + 2.4
            while z < Z_CORO - 1.0:
                if rnd.random() < 0.25:
                    z += 1.5
                    continue
                self.por("madeira", [
                    caixa_girada(x, CORO_Y + 0.5, z, 1.3, 0.09, 1.4,
                                 rnd.uniform(-0.1, 0.1)),
                    caixa_girada(x + lado * 0.62, CORO_Y + 1.05, z, 0.1, 1.5, 1.4,
                                 rnd.uniform(-0.1, 0.1))], z_ref=z)
                z += 1.5

        # detrito fino em cima das galerias — 2o andar tambem levou poeira
        for _ in range(46):
            lado = rnd.choice((-1, 1))
            x = lado * rnd.uniform(LAT_X0 + 0.4, PAR_INT - 0.4)
            z = rnd.uniform(ESC_Z2 if lado < 0 else 4.0, Z_CRUZ - 1.5)
            s2 = rnd.uniform(0.12, 0.34)
            self.por("pedra_esc", [caixa_girada(x, Y_GAL + s2 * 0.3, z, s2,
                                                s2 * 0.55, s2 * 1.05,
                                                rnd.uniform(0, 3.14),
                                                rnd.uniform(-0.25, 0.25), rnd, 0.35)],
                     z_ref=z)

        # panos rasgados pendurados na galeria (dao movimento e escala)
        for (x, z, larg) in ((-9.0, 20.0, 1.6), (9.4, 12.0, 1.4), (9.0, 30.0, 1.8)):
            self.por("pano", [caixa_girada(x, Y_GAL - 1.6, z, larg, 3.0, 0.05,
                                           rnd.uniform(-0.3, 0.3))], z_ref=z)

    # -- objeto de colisao -------------------------------------------------
    def fechar_colisao(self):
        verts, faces = [], []
        for (v, f) in self.col:
            base = len(verts)
            verts.extend(v)
            faces.extend([[i + base for i in face] for face in f])
        return verts, faces

    def montar(self):
        self.piso()
        self.arcadas()
        self.paredes_laterais()
        self.fachada()
        self.abobadas()
        self.coro_e_abside()
        self.circulacao()
        self.ruina()
        self.pontos["spawn"] = [0.0, 0.05, 3.2]
        self.pontos["porta"] = [0.0, 0.0, 1.4]
        self.pontos["buraco_teto"] = [0.0, Y_NAVE_ARR + NAVE_FLECHA,
                                      sum(BAIAS[BAIA_ROMPIDA]) / 2.0]
        # A segunda metade deste bloco (de "lat_x" pra baixo) existe para o
        # desenhista da PLANTA BAIXA, `tools/godot/igreja/make_mapa_igreja.py`:
        # ele desenha o mapa do menu a partir daqui em vez de repetir os
        # numeros, entao mover um pilar no Blender move o pilar no mapa.
        self.pontos["planta"] = {
            "nave_x": NAVE_X, "parede_x": PAR_INT, "z_portal": Z_OESTE,
            "z_cruz": Z_CRUZ, "z_coro": Z_CORO, "y_galeria": Y_GAL,
            "y_chave": Y_NAVE_ARR + NAVE_FLECHA,
            "escada_topo": [(ESC_X0 + ESC_X1) / 2, Y_GAL, ESC_Z2],
            "caracol": [CARACOL[0], 0.0, CARACOL[1]],
            "passarela": [0.0, Y_GAL, PASSARELA_Z],
            "jube": [0.0, Y_GAL, (JUBE_Z0 + JUBE_Z1) / 2],

            "lat_x": LAT_X0, "eixo_x": EIXO, "parede_ext": PAR_EXT,
            "z_portal_ext": Z_OESTE_EXT, "abside_r": ABS_R, "coro_y": CORO_Y,
            "pilar_z": list(PILAR_Z), "baias": [list(b) for b in BAIAS],
            "baia_rompida": BAIA_ROMPIDA,
            "escada": [ESC_X0, ESC_X1, ESC_Z0, ESC_Z1, ESC_PAT_Z, ESC_Z2],
            "caracol_r": CARACOL_R,
            "poco": [POCO_X, POCO_Z0, POCO_Z1, POCO_SAIDA],
            "passarela_boca": PASSARELA_BOCA,
            "jube_z": [JUBE_Z0, JUBE_Z1],
        }


# --------------------------------------------------------------------------
# Blender


def limpar_cena():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(nome):
    mat = bpy.data.materials.get("MI_" + nome)
    if mat:
        return mat
    mat = bpy.data.materials.new("MI_" + nome)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    cor = MATERIAIS.get(nome.split("_")[0] if nome.startswith("vitral") else nome,
                        (0.5, 0.5, 0.5))
    if nome.startswith("vitral") or nome == "vidro":
        cor = (0.35, 0.16, 0.12)
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*cor, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.92
    return mat


def criar_objeto(nome, dados, mat_nome, escala_uv=0.32):
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
        # o exportador muda de assinatura entre versoes; tenta sem os extras
        print("export: assinatura diferente (%s), tentando minimo" % erro)
        bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB",
                                  use_selection=True, export_yup=False)
    return os.path.getsize(caminho)


def main():
    limpar_cena()
    igreja = Igreja()
    igreja.montar()

    criados = []
    for (setor_nome, mat_nome), dados in sorted(igreja.m.grupos.items()):
        if not dados["f"]:
            continue
        nome = "SM_igr_%s_%s" % (setor_nome, mat_nome)
        ob = criar_objeto(nome, dados, mat_nome)
        if mat_nome.startswith("vitral") or mat_nome == "vidro":
            pass   # vidro nao leva recalculo: e' plano de face unica
        else:
            recalcular_normais(ob)
        criados.append((nome, len(dados["f"])))

    # colisao: um objeto so', invisivel no jogo
    v, f = igreja.fechar_colisao()
    dados = {"v": v, "f": f, "uv": [None] * len(f), "s": [False] * len(f)}
    col = criar_objeto("CL_igreja-colonly", dados, "pedra")
    recalcular_normais(col)

    destino = os.path.join(DESTINO, "igreja_interior.glb")
    tam = exportar(destino)

    with open(os.path.join(DESTINO, "igreja_pontos.json"), "w") as fp:
        json.dump(igreja.pontos, fp, indent=1)

    print("\n--- igreja gerada ---")
    for nome, nfaces in criados:
        print("  %-28s %6d faces" % (nome, nfaces))
    print("  %-28s %6d faces  (invisivel)" % ("CL_igreja-colonly", len(f)))
    print("  triangulos visiveis ~%d" % igreja.m.total_tris())
    print("  %s  %.1f MB" % (destino, tam / 1048576.0))
    print("  janelas=%d velas=%d tochas=%d" % (len(igreja.pontos["janelas"]),
                                               len(igreja.pontos["velas"]),
                                               len(igreja.pontos["tochas"])))


if __name__ == "__main__":
    main()
