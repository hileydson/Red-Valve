"""Monta o hospital POR FORA: a casca que entra no mapa da cidade.

    python3 tools/godot/hospital/gerar_cena_exterior.py

Sai:
    red-valve/assets/3d_model/stages/hospital/hospital_exterior.gltf (+ .bin)
    red-valve/scenes/stages/hospital/hospital_exterior.tscn

A cena resultante e' uma instancia so': da' pra arrastar, girar e subir/descer
pelo editor sem quebrar nada. Quem consome ela e' a `stage_1`, que a encaixa em
cima do `Marker3D` chamado `hospital_local`.

O que e' fachada mora em `exterior.py` (medidas, estado das janelas, o
letreiro). Aqui fica so' a emissao: caixa, colisao, luz e o texto do .tscn.

Regenerar SOBRESCREVE o .tscn — mexer no predio pelo editor se perde, igual ao
interior. O que NAO se perde e' a posicao: ela mora na `stage_1`, nao aqui.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import exterior as E
import gerar_cena_hospital as G
import gltf
import materiais as M
import planta as P

RAIZ = G.RAIZ
BASE = G.BASE
DIR_MODELO = G.DIR_MODELO
SAIDA_CENA = os.path.join(BASE, "scenes", "stages", "hospital",
                          "hospital_exterior.tscn")
RES_MODELO = G.RES_MODELO

SETOR = 16.0


class Fachada(G.Setores):
    """O mesmo fatiador do interior, com nome de objeto proprio.

    Fatiar importa aqui pelo mesmo motivo de la' dentro: uma fachada de 68 m
    numa malha so' entra INTEIRA no alcance de qualquer poste da cidade, e o
    renderer mobile descarta luz calado depois da oitava.
    """

    def _objeto(self, andar, i, j):
        chave = (i, j)
        if chave not in self.objetos:
            self.objetos[chave] = self.cena.objeto("ext_%02d_%02d" % (i, j))
        return self.objetos[chave]


# ==========================================================================
# A CASCA
# ==========================================================================

def _buracos_da_fachada(lado, andar):
    """Os vaos desta fachada, em coordenadas de muro (corrida, altura)."""
    buracos = []
    for (l, _plano, a, b, y0, y1) in E.janelas():
        if l == lado and P.cota(andar) <= y0 < P.cota(andar) + P.PE + 0.5:
            buracos.append((a, b, y0, y1))
    if lado == "o" and andar == 1:
        buracos.append((E.ENTRADA_Z0, E.ENTRADA_Z1, 0.0, E.ENTRADA_TOPO))
    return buracos


def _corrida(lado, andar, avanco):
    """De onde ate' onde esta fachada corre.

    As fachadas norte e sul param na espessura da casca; as de leste e oeste
    correm inteiras e FICAM COM OS CANTOS. Se as quatro corressem inteiras, a
    ponta da fachada norte terminaria no mesmo plano em que a fachada oeste
    comeca — duas faces coplanares, brigando por profundidade bem na quina do
    predio, que e' a parte mais visivel dele.
    """
    fundo = E.Z1 if andar == 1 else E.Z2
    if lado in ("n", "s"):
        return E.ESP, E.X1 - E.ESP
    return -avanco, fundo + avanco


def emitir_casca(fac):
    colisoes = []
    # faixas: (y0, y1, material, avanco, andares em que existem)
    faixas = [
        (E.Y_BASE, "fac_embasamento", E.AVANCO_BASE, 1),
        (E.Y_CORPO1, "fac_reboco", 0.0, 1),
        (E.Y_CINTA, "fac_concreto", E.AVANCO_CINTA, 1),
        (E.Y_CORPO2, "fac_reboco_sujo", 0.0, 2),
        (E.Y_COROA, "fac_concreto", E.AVANCO_CINTA, 2),
    ]
    for ((y0, y1), mat, avanco, andar) in faixas:
        for lado in ("o", "l", "n", "s"):
            a, b = _corrida(lado, andar, avanco)
            plano = E._plano(lado, andar)
            E.faixa(fac, lado, plano, a, b, y0, y1, mat,
                    _buracos_da_fachada(lado, andar), avanco=avanco)

    # --- platibanda: a mureta que esconde o telhado
    for lado in ("o", "l", "n", "s"):
        a, b = _corrida(lado, 2, 0.0)
        if lado in ("n", "s"):
            a, b = 0.30, E.X1 - 0.30
        plano = E._plano(lado, 2)
        E.caixa_fachada(fac, lado, plano, a, b,
                        E.Y_PLATIBANDA[0], E.Y_PLATIBANDA[1],
                        "fac_reboco_sujo", esp=0.30)
        E.caixa_fachada(fac, lado, plano, a, b, E.Y_PLATIBANDA[1],
                        E.Y_PLATIBANDA[1] + 0.16, "fac_concreto",
                        esp=0.30, avanco=0.10)

    # --- pilastras: o ritmo vertical.
    # Elas caem em cima das divisorias de ala do interior (11,175 / 22,175 /
    # 33,175 / 44,175 e as paredes de corredor), entao a fachada CONTA o que
    # tem dentro — e' o que separa um predio de uma caixa com janela.
    topo = E.Y_COROA[1]
    for x in (11.175, 22.175, 33.175, 44.175):
        # Norte: o pano e' o mesmo nos dois andares, entao a pilastra sobe
        # inteira. Sul: o segundo andar recua 3,60 m, e uma pilastra que
        # subisse inteira ficava PENDURADA NO AR sobre o telhado baixo, sem
        # parede atras. Aqui ela para na platibanda baixa e RECOMECA la' atras,
        # no plano do segundo andar.
        fac.caixa(0, "fac_concreto", x - 0.45, x + 0.45, E.CHAO, topo,
                  *_faixa_z("n", 2), 2.2)
        fac.caixa(0, "fac_concreto", x - 0.45, x + 0.45, E.CHAO,
                  E.Y_PLATIBANDA_BAIXA[1], *_faixa_z("s", 1), 2.2)
        fac.caixa(0, "fac_concreto", x - 0.45, x + 0.45, P.ANDAR_2, topo,
                  *_faixa_z("s", 2), 2.2)
    for z in (10.175, 25.700, 42.650, 53.000):
        for lado in ("o", "l"):
            fac.caixa(0, "fac_concreto", *_faixa_x(lado), E.CHAO, topo,
                      z - 0.45, z + 0.45, 2.2)

    colisoes.append((E.X0, E.X1, E.CHAO - 1.20, P.ANDAR_2, 0.0, E.Z1))
    colisoes.append((E.X0, E.X1, P.ANDAR_2, E.Y_PLATIBANDA[1] + 0.20,
                     0.0, E.Z2))
    return colisoes


def _faixa_z(lado, andar):
    plano = E._plano(lado, andar)
    return (plano, plano + 0.34) if lado == "n" else (plano - 0.34, plano)


def _faixa_x(lado):
    plano = E._plano(lado, 1)
    return (plano - 0.34, plano) if lado == "l" else (plano, plano + 0.34)


# ==========================================================================
# JANELAS
# ==========================================================================

def emitir_janelas(fac):
    contagem = {}
    for (i, (lado, plano, a, b, y0, y1)) in enumerate(E.janelas()):
        estado = E.ESTADO_JANELA[i % len(E.ESTADO_JANELA)]
        contagem[estado] = contagem.get(estado, 0) + 1
        _janela(fac, lado, plano, a, b, y0, y1, estado)
    return contagem


def _janela(fac, lado, plano, a, b, y0, y1, estado):
    cx = E.caixa_fachada

    # O fundo preto. A casca e' oca: sem ele, o vao de janela vira um furo por
    # onde se ve o predio vazio por dentro.
    cx(fac, lado, plano, a, b, y0, y1, "fac_escuro",
       esp=E.ESP, avanco=-(E.ESP - 0.08), uv=1.0)

    if estado == "tapada":
        # Tabua pregada por fora — a janela que alguem fechou com pressa.
        alt = (y1 - y0) / 3.4
        for k in range(3):
            yy = y0 + 0.12 + k * (alt * 1.1)
            cx(fac, lado, plano, a - 0.10, b + 0.10, yy, yy + alt,
               "fac_tabua", esp=0.07, avanco=0.05, uv=1.2)
    elif estado != "quebrada":
        mat = "fac_vidro_aceso" if estado == "acesa" else "fac_vidro"
        cx(fac, lado, plano, a + 0.06, b - 0.06, y0 + 0.06, y1 - 0.06,
           mat, esp=0.06, avanco=-0.10, uv=1.6)

    # caixilho: duas travessas e dois montantes, rentes ao pano
    cx(fac, lado, plano, a, b, y0, y0 + 0.08, "fac_esquadria", esp=0.14, uv=1.0)
    cx(fac, lado, plano, a, b, y1 - 0.08, y1, "fac_esquadria", esp=0.14, uv=1.0)
    for c in (a, b - 0.08):
        cx(fac, lado, plano, c, c + 0.08, y0, y1, "fac_esquadria",
           esp=0.14, uv=1.0)
    # montante central, se a janela for larga
    if b - a > 2.6:
        meio = (a + b) * 0.5
        cx(fac, lado, plano, meio - 0.05, meio + 0.05, y0, y1,
           "fac_esquadria", esp=0.12, uv=1.0)

    # peitoril e verga: o par de sombras que destaca a janela do pano
    cx(fac, lado, plano, a - 0.14, b + 0.14, y0 - 0.12, y0,
       "fac_concreto", esp=0.20, avanco=0.14, uv=1.4)
    cx(fac, lado, plano, a - 0.14, b + 0.14, y1, y1 + 0.10,
       "fac_concreto", esp=0.20, avanco=0.10, uv=1.4)


# ==========================================================================
# A ENTRADA
# ==========================================================================

def emitir_entrada(fac):
    """A caixa de vidro da entrada, com a porta dupla no meio."""
    cx = E.caixa_fachada
    z0, z1 = E.ENTRADA_Z0, E.ENTRADA_Z1
    topo = E.ENTRADA_TOPO

    # fundo preto do vao inteiro (o hall de verdade esta' na outra cena)
    cx(fac, "o", 0.0, z0, z1, E.CHAO, topo, "fac_escuro",
       esp=E.ESP, avanco=-(E.ESP - 0.10), uv=1.0)
    # pano de vidro
    cx(fac, "o", 0.0, z0, z1, 0.0, topo, "fac_vidro",
       esp=0.08, avanco=-0.16, uv=2.0)
    # soleira
    cx(fac, "o", 0.0, z0 - 0.2, z1 + 0.2, E.CHAO, 0.02, "fac_concreto",
       esp=0.40, avanco=0.16, uv=1.6)

    # montantes do caixilho, de 1,35 em 1,35, pulando o vao da porta
    z = z0
    while z < z1 - 0.05:
        if not (E.PORTA_Z0 - 0.12 < z < E.PORTA_Z1 + 0.12):
            cx(fac, "o", 0.0, z, z + 0.10, 0.0, topo, "fac_esquadria",
               esp=0.22, avanco=0.06, uv=1.0)
        z += 1.35
    for c in (z0, z1 - 0.12):
        cx(fac, "o", 0.0, c, c + 0.12, 0.0, topo, "fac_esquadria",
           esp=0.26, avanco=0.08, uv=1.0)
    cx(fac, "o", 0.0, z0, z1, topo - 0.14, topo, "fac_esquadria",
       esp=0.26, avanco=0.08, uv=1.0)
    # bandeira sobre a porta
    cx(fac, "o", 0.0, E.PORTA_Z0, E.PORTA_Z1, E.PORTA_TOPO,
       E.PORTA_TOPO + 0.14, "fac_esquadria", esp=0.26, avanco=0.08, uv=1.0)

    # as duas folhas, com barra antipanico
    for (fa, fb) in ((E.PORTA_Z0, E.ENTRADA_Z - 0.03),
                     (E.ENTRADA_Z + 0.03, E.PORTA_Z1)):
        cx(fac, "o", 0.0, fa, fb, 0.04, E.PORTA_TOPO - 0.04, "fac_vidro",
           esp=0.07, avanco=-0.12, uv=1.6)
        for yy in (0.04, E.PORTA_TOPO - 0.16):
            cx(fac, "o", 0.0, fa, fb, yy, yy + 0.12, "fac_esquadria",
               esp=0.14, avanco=-0.04, uv=1.0)
        for c in (fa, fb - 0.09):
            cx(fac, "o", 0.0, c, c + 0.09, 0.04, E.PORTA_TOPO - 0.04,
               "fac_esquadria", esp=0.14, avanco=-0.04, uv=1.0)
        cx(fac, "o", 0.0, fa + 0.10, fb - 0.10, 1.02, 1.12, "fac_metal",
           esp=0.08, avanco=-0.24, uv=0.6)


def emitir_terraco(fac):
    """O tablado coberto da entrada: piso, degraus, pilares e marquise."""
    colisoes = []
    x0, x1 = E.TERRACO_X0, E.TERRACO_X1
    z0, z1 = E.TERRACO_Z0, E.TERRACO_Z1

    fac.caixa(0, "fac_calcada", x0, x1, -0.22, 0.0, z0, z1, 3.0)
    colisoes.append((x0, x1, E.CHAO - 1.0, 0.0, z0, z1))

    for k in range(1, E.DEGRAUS + 1):
        dx1 = x0 - E.DEGRAU_P * (k - 1)
        dx0 = x0 - E.DEGRAU_P * k
        y = -E.DEGRAU_H * k
        fac.caixa(0, "fac_calcada", dx0, dx1, y - 0.22, y, z0 + 3.0, z1 - 3.0,
                  2.0)
        colisoes.append((dx0, dx1, E.CHAO - 1.0, y, z0 + 3.0, z1 - 3.0))

    # pilares
    for z in (z0 + 2.0, 29.60, 38.80, z1 - 2.0):
        fac.caixa(0, "fac_concreto", x0 + 0.7, x0 + 1.5, 0.0, E.MARQUISE[0],
                  z - 0.40, z + 0.40, 2.0)
        colisoes.append((x0 + 0.7, x0 + 1.5, 0.0, E.MARQUISE[0],
                         z - 0.40, z + 0.40))

    # marquise + a viga de borda que lhe da' espessura
    fac.caixa(0, "fac_laje", x0 - 0.30, 0.0, E.MARQUISE[0], E.MARQUISE[1],
              z0, z1, 3.2)
    fac.caixa(0, "fac_concreto", x0 - 0.42, x0 - 0.30, E.MARQUISE[0] - 0.22,
              E.MARQUISE[1], z0, z1, 2.0)
    for z in (z0, z1 - 0.12):
        fac.caixa(0, "fac_concreto", x0 - 0.42, 0.0, E.MARQUISE[0] - 0.22,
                  E.MARQUISE[1], z, z + 0.12, 2.0)
    # A marquise NAO entra na colisao de proposito.
    #
    # Ela esta' a 3,90 m: ninguem alcanca. Mas o `_pousar_no_chao` do stage_1
    # acha o chao com um raio DE CIMA PRA BAIXO, e com colisao aqui o primeiro
    # que ele encontrava era a laje da marquise — o jogador saia do hospital
    # em pe' EM CIMA do toldo, cinco metros no ar, olhando a cidade de la'.
    return colisoes


# ==========================================================================
# LETREIRO E CRUZ
# ==========================================================================

def emitir_letreiro(fac):
    largura = (len(E.PALAVRA) * E.LETRA_L
               + (len(E.PALAVRA) - 1) * E.LETRA_VAO)
    z = E.ENTRADA_Z - largura * 0.5
    for (i, letra) in enumerate(E.PALAVRA):
        mat = "fac_letra_morta" if i in E.LETRAS_MORTAS else "fac_letra_acesa"
        for (a0, a1, b0, b1) in E.TRACOS[letra]:
            fac.caixa(0, mat,
                      -0.30, -0.04,
                      E.LETRA_Y + b0 * E.LETRA_H, E.LETRA_Y + b1 * E.LETRA_H,
                      z + a0 * E.LETRA_L, z + a1 * E.LETRA_L, 0.8)
        z += E.LETRA_L + E.LETRA_VAO


def _cruz(fac, eixo, plano, c, y, tam, fora):
    """Uma cruz vermelha num painel escuro. `fora` = +1 se cresce pro +eixo."""
    braco = tam * 0.30
    p0 = plano + 0.02 * fora
    p1 = plano + 0.10 * fora
    p2 = plano + 0.26 * fora
    def caixa(mat, ca, cb, ya, yb, qa, qb):
        if eixo == "x":
            fac.caixa(0, mat, min(qa, qb), max(qa, qb), ya, yb, ca, cb, 1.0)
        else:
            fac.caixa(0, mat, ca, cb, ya, yb, min(qa, qb), max(qa, qb), 1.0)
    caixa("fac_esquadria", c - tam * 0.5, c + tam * 0.5,
          y - tam * 0.5, y + tam * 0.5, p0, p1)
    caixa("fac_cruz", c - braco * 0.5, c + braco * 0.5,
          y - tam * 0.40, y + tam * 0.40, p1, p2)
    caixa("fac_cruz", c - tam * 0.40, c + tam * 0.40,
          y - braco * 0.5, y + braco * 0.5, p1, p2)


def emitir_bandeira(fac):
    """A placa perpendicular a' fachada, ao lado da entrada.

    Perpendicular de proposito: quem vem pela rua ve o predio de lado, e um
    letreiro chapado na parede so' existe pra quem ja' chegou.
    """
    z = 27.00
    fac.caixa(0, "fac_metal", -2.70, -0.10, 4.70, 7.10, z, z + 0.14, 1.2)
    fac.caixa(0, "fac_metal", -0.30, -0.05, 6.90, 7.10, z - 0.10, z + 0.24, 0.8)
    fac.caixa(0, "fac_metal", -0.30, -0.05, 4.70, 4.90, z - 0.10, z + 0.24, 0.8)
    for (lado, base) in ((+1.0, z + 0.14), (-1.0, z)):
        braco = 0.62
        fac.caixa(0, "fac_cruz", -1.72, -1.10, 5.28, 6.52,
                  min(base, base + 0.10 * lado), max(base, base + 0.10 * lado),
                  1.0)
        fac.caixa(0, "fac_cruz", -2.02, -0.80, 5.59, 6.21,
                  min(base, base + 0.10 * lado), max(base, base + 0.10 * lado),
                  1.0)
        del braco


# ==========================================================================
# TORRE DO ELEVADOR, CHAMINE, TELHADO
# ==========================================================================

def emitir_torre(fac):
    x0, x1 = E.TORRE_X0, E.TORRE_X1
    z0, z1 = E.TORRE_Z0, E.TORRE_Z1
    fac.caixa(0, "fac_concreto", x0, x1, E.CHAO, E.TORRE_TOPO - 0.40,
              z0, z1, 2.8)
    # coroamento da casa de maquinas
    fac.caixa(0, "fac_concreto", x0, x1 + 0.16, E.TORRE_TOPO - 0.40,
              E.TORRE_TOPO, z0 - 0.16, z1 + 0.16, 2.2)
    # cintas horizontais, uma por andar: sem elas a torre e' um bloco liso de
    # 12 m e o olho nao consegue medir a altura dela
    for y in (P.PE, P.ANDAR_2 + P.PE):
        fac.caixa(0, "fac_laje", x0, x1 + 0.10, y, y + 0.30,
                  z0 - 0.10, z1 + 0.10, 2.0)
    # escada de gato na face sul
    for k in range(int((E.TORRE_TOPO - 1.0) / 0.55)):
        y = 1.0 + k * 0.55
        fac.caixa(0, "fac_metal", x1 - 1.60, x1 - 0.70, y, y + 0.07,
                  z1, z1 + 0.16, 0.6)
    for x in (x1 - 1.62, x1 - 0.75):
        fac.caixa(0, "fac_metal", x, x + 0.09, 1.0, E.TORRE_TOPO,
                  z1, z1 + 0.20, 0.8)
    _cruz(fac, "x", x1, (z0 + z1) * 0.5, 8.40, 3.80, +1.0)
    return [(x0, x1 + 0.2, E.CHAO - 1.20, E.TORRE_TOPO, z0 - 0.2, z1 + 0.2)]


def emitir_chamine(fac):
    x0, x1 = E.CHAMINE_X0, E.CHAMINE_X1
    z0, z1 = E.CHAMINE_Z0, E.CHAMINE_Z1
    fac.caixa(0, "fac_tijolo", x0, x1, E.CHAO, E.CHAMINE_TOPO - 0.60,
              z0, z1, 2.0)
    fac.caixa(0, "fac_tijolo", x0 - 0.18, x1 + 0.18, E.CHAMINE_TOPO - 0.60,
              E.CHAMINE_TOPO, z0 - 0.18, z1 + 0.18, 1.6)
    for y in (4.20, 8.40, 12.60):
        fac.caixa(0, "fac_concreto", x0 - 0.10, x1 + 0.10, y, y + 0.22,
                  z0 - 0.10, z1 + 0.10, 1.4)
    return [(x0 - 0.2, x1 + 0.2, E.CHAO - 1.20, E.CHAMINE_TOPO,
             E.Z1, z1 + 0.2)]


def emitir_telhado(fac):
    """As duas lajes de cobertura e o que mora em cima delas."""
    laje = E.Y_COROA[0]
    fac.caixa(0, "fac_laje", E.X0, E.X1, laje, laje + 0.30, 0.0, E.Z2, 3.6)
    # a cobertura mais baixa: o trecho que so' tem terreo
    fac.caixa(0, "fac_laje", E.X0, E.X1, E.Y_LAJE_BAIXA[0],
              E.Y_LAJE_BAIXA[1], E.Z2, E.Z1, 3.6)
    for (lado, a, b) in (("s", 0.30, E.X1 - 0.30), ("o", E.Z2, E.Z1),
                         ("l", E.Z2, E.Z1)):
        plano = E.Z1 if lado == "s" else E._plano(lado, 1)
        E.caixa_fachada(fac, lado, plano, a, b, E.Y_PLATIBANDA_BAIXA[0],
                        E.Y_PLATIBANDA_BAIXA[1], "fac_reboco_sujo", esp=0.30)
        E.caixa_fachada(fac, lado, plano, a, b, E.Y_PLATIBANDA_BAIXA[1],
                        E.Y_PLATIBANDA_BAIXA[1] + 0.14, "fac_concreto",
                        esp=0.30, avanco=0.10)

    topo = laje + 0.30
    # caixa d'agua sobre pernas: e' ela que da' silhueta ao predio de longe
    for (x, z) in ((8.0, 9.2), (13.4, 9.2), (8.0, 14.6), (13.4, 14.6)):
        fac.caixa(0, "fac_metal", x - 0.22, x + 0.22, topo, topo + 2.10,
                  z - 0.22, z + 0.22, 0.9)
    fac.caixa(0, "fac_metal", 7.2, 14.2, topo + 2.10, topo + 5.20,
              8.4, 15.4, 2.2)
    fac.caixa(0, "fac_concreto", 7.0, 14.4, topo + 5.20, topo + 5.44,
              8.2, 15.6, 2.0)
    # casa de maquinas / exaustores
    for (x, z, lx, lz, h) in ((24.0, 12.0, 5.0, 4.0, 1.8),
                              (31.0, 44.0, 6.2, 5.0, 2.3),
                              (44.0, 22.0, 4.0, 4.0, 1.5)):
        fac.caixa(0, "fac_reboco_sujo", x, x + lx, topo, topo + h,
                  z, z + lz, 2.2)
        fac.caixa(0, "fac_concreto", x - 0.14, x + lx + 0.14, topo + h,
                  topo + h + 0.20, z - 0.14, z + lz + 0.14, 1.8)
    for (x, z, h) in ((20.0, 30.0, 2.6), (36.0, 18.0, 3.4), (48.0, 50.0, 2.2),
                      (18.0, 52.0, 2.9), (40.0, 58.0, 2.4)):
        fac.caixa(0, "fac_metal", x - 0.30, x + 0.30, topo, topo + h,
                  z - 0.30, z + 0.30, 0.9)
        fac.caixa(0, "fac_metal", x - 0.46, x + 0.46, topo + h,
                  topo + h + 0.26, z - 0.46, z + 0.46, 0.8)
    # antenas
    for (x, z, h) in ((4.0, 56.0, 6.4), (52.0, 6.0, 5.2)):
        fac.caixa(0, "fac_metal", x - 0.09, x + 0.09,
                  E.Y_PLATIBANDA[1], E.Y_PLATIBANDA[1] + h, z - 0.09, z + 0.09,
                  0.6)


def emitir_escada_incendio(fac):
    """Escada de incendio na fachada norte. Nao da' pra subir — e' silhueta."""
    x0, x1 = 18.20, 21.40
    z0, z1 = -1.90, 0.20
    for y in (P.ANDAR_2, P.ANDAR_2 + P.PE):
        fac.caixa(0, "fac_metal", x0, x1, y - 0.10, y, z0, z1, 1.2)
        for (a, b) in ((z0, z0 + 0.07), ):
            fac.caixa(0, "fac_metal", x0, x1, y, y + 1.05, a, b, 0.8)
        for x in (x0, x1 - 0.07):
            fac.caixa(0, "fac_metal", x, x + 0.07, y, y + 1.05, z0, z1, 0.8)
        fac.caixa(0, "fac_metal", x0, x1, y + 0.98, y + 1.05, z0, z1 - 0.9, 0.8)
    for x in (x0 + 1.05, x0 + 1.95):
        fac.caixa(0, "fac_metal", x, x + 0.08, E.CHAO + 1.2,
                  P.ANDAR_2 + P.PE, z0 + 0.25, z0 + 0.35, 0.8)
    k = 0
    while E.CHAO + 1.4 + k * 0.42 < P.ANDAR_2 + P.PE - 0.2:
        y = E.CHAO + 1.4 + k * 0.42
        fac.caixa(0, "fac_metal", x0 + 1.05, x0 + 2.03, y, y + 0.06,
                  z0 + 0.25, z0 + 0.35, 0.5)
        k += 1


# ==========================================================================
# CALCADA
# ==========================================================================

def emitir_calcada(fac):
    colisoes = []
    y0, y1 = E.CALCADA_Y
    l = E.CALCADA_L
    faixas = [
        (E.X0 - l, E.X1 + l, -l, 0.0),
        (E.X0 - l, E.X1 + l, E.Z1, E.Z1 + l),
        (E.X0 - l, E.X0, 0.0, E.Z1),
        (E.X1, E.X1 + l, 0.0, E.TORRE_Z0),
        (E.X1, E.TORRE_X1 + l, E.TORRE_Z0, E.TORRE_Z1),
        (E.X1, E.X1 + l, E.TORRE_Z1, E.Z1),
        E.PATIO,
    ]
    for (x0, x1, z0, z1) in faixas:
        fac.caixa(0, "fac_calcada", x0, x1, y0, y1, z0, z1, 3.0)
        colisoes.append((x0, x1, y0, y1, z0, z1))
    return colisoes


# ==========================================================================
# MONTAGEM
# ==========================================================================

def montar():
    cena = gltf.Cena("../../../images/textures/polyhaven")
    M.registrar(cena, [M.EXTERIOR])
    fac = Fachada(cena, SETOR)
    colisoes = []
    colisoes += emitir_casca(fac)
    contagem = emitir_janelas(fac)
    emitir_entrada(fac)
    colisoes += emitir_terraco(fac)
    emitir_letreiro(fac)
    emitir_bandeira(fac)
    colisoes += emitir_torre(fac)
    colisoes += emitir_chamine(fac)
    emitir_telhado(fac)
    emitir_escada_incendio(fac)
    colisoes += emitir_calcada(fac)
    return cena, colisoes, contagem


# ==========================================================================
# LUZ
#
# Quatro, e nem uma a mais. Fachada e' lugar de luz emissiva (janela acesa,
# letra acesa), nao de luz de verdade: o predio divide o orcamento de 8 por
# malha com os postes da cidade, e quem perde a disputa some sem avisar.
# ==========================================================================

LUZES = [
    ("marquise_n", (-4.20, E.MARQUISE[0] - 0.25, 29.20),
     (0.62, 0.74, 0.64), 2.4, 9.0),
    ("marquise_s", (-4.20, E.MARQUISE[0] - 0.25, 39.20),
     (0.62, 0.74, 0.64), 2.4, 9.0),
    ("letreiro", (-1.40, E.LETRA_Y + E.LETRA_H * 0.5, E.ENTRADA_Z),
     (0.46, 0.76, 0.54), 3.4, 15.0),
    ("cruz_torre", (E.TORRE_X1 + 1.20, 8.40, (E.TORRE_Z0 + E.TORRE_Z1) * 0.5),
     (0.82, 0.10, 0.07), 2.6, 7.5),
]


# ==========================================================================
# O .tscn
# ==========================================================================

def escrever_cena(colisoes):
    dx = -E.ORIGEM[0]
    dy = -E.ORIGEM[1]
    dz = -E.ORIGEM[2]

    externos = [("PackedScene", RES_MODELO + "/hospital_exterior.gltf", "e0")]
    sub = []
    formas = {}

    def forma(lx, ly, lz):
        chave = (round(lx, 3), round(ly, 3), round(lz, 3))
        if chave not in formas:
            ident = "f%d" % len(formas)
            formas[chave] = ident
            sub.append((ident, "BoxShape3D", ["size = %s" % G.v3(chave)]))
        return formas[chave]

    linhas = []

    def no(nome, tipo=None, pai=None, instancia=None, props_=()):
        cab = '[node name="%s"' % nome
        if tipo:
            cab += ' type="%s"' % tipo
        if pai:
            cab += ' parent="%s"' % pai
        if instancia:
            cab += ' instance=ExtResource("%s")' % instancia
        linhas.append(cab + "]")
        for (chave, valor) in props_:
            linhas.append("%s = %s" % (chave, valor))
        linhas.append("")

    no("hospital_exterior", tipo="Node3D")
    # Tudo o que e' predio vive DENTRO deste no', deslocado. Assim o (0,0,0) da
    # cena e' o pe da escada da entrada, e nao o canto do terreno.
    no("predio", tipo="Node3D", pai=".",
       props_=[("transform", G.transform_pos((dx, dy, dz)))])
    no("estrutura", pai="predio", instancia="e0")

    no("colisao", tipo="StaticBody3D", pai="predio",
       props_=[("collision_layer", "2"), ("collision_mask", "0")])
    for (i, (x0, x1, y0, y1, z0, z1)) in enumerate(colisoes):
        ident = forma(x1 - x0, y1 - y0, z1 - z0)
        no("c%d" % i, tipo="CollisionShape3D", pai="predio/colisao",
           props_=[("transform", G.transform_pos(
               ((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5))),
               ("shape", 'SubResource("%s")' % ident)])

    no("luzes", tipo="Node3D", pai="predio")
    for (nome, pos, c, energia, alcance) in LUZES:
        no(nome, tipo="OmniLight3D", pai="predio/luzes", props_=[
            ("transform", G.transform_pos(pos)),
            ("light_color", G.cor(list(c) + [1.0])),
            ("light_energy", "%.3f" % energia),
            ("light_specular", "0.15"),
            ("shadow_enabled", "false"),
            ("omni_range", "%.3f" % alcance),
            ("omni_attenuation", "1.35"),
        ])

    # O ponto pra onde o jogador volta quando sai do hospital: em cima do
    # tablado, tres metros e meio a' frente da porta, ja' de costas pra ela.
    saida = (-3.50 + dx, 0.0 + dy + 0.15, E.ENTRADA_Z + dz)
    no("ponto_de_saida", tipo="Marker3D", pai=".",
       props_=[("transform", G.transform_pos(saida, math.pi * 0.5))])

    # A area do prompt cobre a escada, o tablado inteiro e a soleira: quem
    # sobe os degraus ja' le' "Entrar no hospital?" e continua lendo ate' a
    # porta. Alta o bastante (5 m) pra nao errar o jogador por desnivel do
    # terreno, do mesmo jeito que a area da igreja.
    #
    # E LARGA: 20 m em Z. A primeira versao tinha 10 e cobria so' o eixo da
    # porta — o tablado tem 25 m de frente, e quem subia a escada por uma das
    # pontas chegava na soleira sem prompt nenhum, como se a porta nao
    # existisse. Numa entrada desse tamanho a area tem de ser do tamanho da
    # entrada, nao do tamanho da porta.
    ident = forma(21.0, 5.0, 20.0)
    no("area_entrada", tipo="Area3D", pai=".",
       props_=[("transform", G.transform_pos((4.5, 1.80, 0.0))),
               ("collision_layer", "0"), ("collision_mask", "1"),
               ("monitorable", "false")])
    no("forma", tipo="CollisionShape3D", pai="area_entrada",
       props_=[("shape", 'SubResource("%s")' % ident)])

    cab = ['[gd_scene load_steps=%d format=3]' % (len(externos) + len(sub) + 1),
           ""]
    for (tipo, caminho, ident) in externos:
        cab.append('[ext_resource type="%s" path="%s" id="%s"]'
                   % (tipo, caminho, ident))
    cab.append("")
    for (ident, tipo, props_) in sub:
        cab.append('[sub_resource type="%s" id="%s"]' % (tipo, ident))
        cab.extend(props_)
        cab.append("")

    os.makedirs(os.path.dirname(SAIDA_CENA), exist_ok=True)
    with open(SAIDA_CENA, "w") as fp:
        fp.write("\n".join(cab + linhas).rstrip() + "\n")
    return len(formas)


# ==========================================================================
# A SILHUETA PARA O MAPA DA CIDADE
#
# O predio nao sai do gerador da cidade: e' cena a parte, encaixada a mao na
# `stage_1`. Entao o mapa do menu nao tem como saber que ele existe — a menos
# que alguem conte. E' o que este arquivo faz.
# ==========================================================================

SAIDA_MAPA = os.path.join(DIR_MODELO, "hospital_mapa.json")


def escrever_mapa():
    """A planta baixa grosseira do predio, pro mapa da cidade desenhar.

    Quem le' e' `tools/blender/citygen/textures/make_minimap.py`. Sai daqui, e
    nao digitado la', porque a fachada e' GERADA: mudar a medida do predio tem
    que mudar o retangulo do mapa junto, senao o mapa passa a mentir sem que
    ninguem perceba.

    Retangulos em coordenadas LOCAIS DA CENA — a origem e' o pe' da escada da
    entrada —, no formato (x0, z0, x1, z1). Quem os leva pro mundo e' o
    make_minimap, que tira posicao e giro da instancia direto da `stage_1`:
    assim, girar o predio no editor gira a silhueta no mapa junto.
    """
    dx = -E.ORIGEM[0]
    dz = -E.ORIGEM[2]

    def r(x0, z0, x1, z1):
        return [round(x0 + dx, 2), round(z0 + dz, 2),
                round(x1 + dx, 2), round(z1 + dz, 2)]

    dados = {
        "nota": "silhueta do hospital para o mapa da cidade; gerado por "
                "tools/godot/hospital/gerar_cena_exterior.py",
        "porta": [0.0, 0.0],
        "lote": [
            r(E.X0 - E.CALCADA_L, -E.CALCADA_L,
              E.X1 + E.CALCADA_L, E.Z1 + E.CALCADA_L),
            r(E.PATIO[0], E.PATIO[2], E.PATIO[1], E.PATIO[3]),
        ],
        # O tablado da entrada sai a parte do predio de proposito: ele nao e'
        # massa construida, e' laje descoberta com toldo em cima. Desenhado
        # junto virava um bloco preso ao predio por uma linha preta.
        "tablado": [r(E.PE_DA_ESCADA, E.TERRACO_Z0, E.TERRACO_X1,
                      E.TERRACO_Z1)],
        "predio": [
            r(E.X0, 0.0, E.X1, E.Z1),
            r(E.TORRE_X0, E.TORRE_Z0, E.TORRE_X1, E.TORRE_Z1),
        ],
    }
    with open(SAIDA_MAPA, "w", encoding="utf-8") as f:
        json.dump(dados, f, indent=1)
    return dados


def gerar():
    print("== fachada ==")
    cena, colisoes, contagem = montar()
    os.makedirs(DIR_MODELO, exist_ok=True)
    tris = cena.salvar(os.path.join(DIR_MODELO, "hospital_exterior.gltf"))
    vivos = [o for o in cena.objetos if not o.vazio()]
    print("  %d objetos de setor, %d triangulos" % (len(vivos), tris))
    print("  %d janelas (%s)"
          % (len(E.janelas()),
             ", ".join("%s %d" % (k, v) for (k, v) in sorted(contagem.items()))))
    print("  %d caixas de colisao, %d luzes" % (len(colisoes), len(LUZES)))
    formas = escrever_cena(colisoes)
    print("  %d formas distintas" % formas)
    print("  gravado: %s" % SAIDA_CENA)
    mapa = escrever_mapa()
    print("  %d retangulos de silhueta pro mapa da cidade"
          % sum(len(mapa[k]) for k in ("lote", "tablado", "predio")))
    print("  gravado: %s" % SAIDA_MAPA)
    print("  (o mapa da cidade so' muda depois de rodar"
          " tools/blender/citygen/textures/make_minimap.py)")


if __name__ == "__main__":
    gerar()
