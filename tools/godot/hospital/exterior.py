"""O hospital visto de FORA: a casca que vai para o mapa da cidade.

Este modulo so' descreve e desenha a fachada. Quem escreve arquivo e'
`gerar_cena_exterior.py`.

==============================================================================
POR QUE UMA CASCA, E NAO O PREDIO DE VERDADE

O interior do hospital tem 37 mil triangulos, 156 luzes e 569 moveis. Botar
aquilo dentro da `stage_1`, que ja' carrega a cidade inteira, seria pagar o
predio todo em todo quadro de jogo pra ver uma fachada de longe.

Entao o que vai pra rua e' uma CASCA: as quatro fachadas, o telhado, a torre do
elevador e a marquise da entrada. Oca por dentro, fechada por colisao. Entrar
no hospital e' trocar de cena, igual a' igreja e a' casa do Jimmy — ninguem
atravessa a casca, entao ninguem ve que ela e' oca.

Duas consequencias que valem a pena saber:

  - toda janela precisa de um PAINEL PRETO atras do vidro. Sem ele da' pra
    espiar o vazio pelo proprio buraco da janela.
  - a porta da entrada e' de VIDRO ESCURO, opaco. Vidro transparente ali
    mostraria o interior que nao existe.

==============================================================================
DE ONDE SAEM OS NUMEROS

Todos de `planta.py` — e' a mesma planta do interior. A fachada norte tem
janela exatamente onde o quarto 101 tem janela, o segundo andar e' 3,6 m mais
curto em Z porque a planta dele e' mais curta, e a torre do elevador sai da
fachada leste porque o poco sai de la' no desenho do caderno.

Isso importa: o jogador ve a fachada da rua e depois ve as mesmas janelas de
dentro. Se nao baterem, o predio deixa de ser um lugar e vira cenario.

==============================================================================
A ORIGEM DA CENA

O (0,0,0) da cena de fora NAO e' o canto do predio: e' o PE DA ESCADA da
entrada, no nivel da calcada. E' esse ponto que vai em cima do `hospital_local`
na stage_1.

Assim o marcador vira ao mesmo tempo "onde o predio fica" e "onde o jogador
pisa", e girar a instancia no editor gira o predio EM TORNO da entrada — a
porta continua no mesmo lugar, que e' justamente o que se quer ajustar quando
se esta' encaixando um predio de 56 x 68 m numa rua pronta.
"""

import math

import planta as P

# ==========================================================================
# MEDIDAS
# ==========================================================================

X0, X1 = P.PREDIO_X0, P.PREDIO_X1      # 0 .. 56
Z1 = P.A1_Z1                            # 68.00 — profundidade do terreo
Z2 = P.A2_Z1                            # 64.40 — o 2o andar e' mais curto

ESP = 0.45              # espessura da casca
CHAO = -0.60            # cota do terreno em volta (o piso do terreo e' 0)

# As faixas horizontais da fachada, de baixo pra cima.
Y_BASE = (CHAO, 0.30)               # embasamento
Y_CORPO1 = (0.30, P.PE)             # pano do terreo
Y_CINTA = (P.PE, P.ANDAR_2)         # cinta da laje, avancada
Y_CORPO2 = (P.ANDAR_2, P.ANDAR_2 + P.PE)
Y_COROA = (P.ANDAR_2 + P.PE, P.ANDAR_2 + P.PE + 0.45)
Y_PLATIBANDA = (Y_COROA[1], Y_COROA[1] + 1.10)
# telhado do trecho que so' tem terreo (z 64,40 .. 68)
Y_LAJE_BAIXA = (P.ANDAR_2, P.ANDAR_2 + 0.30)
Y_PLATIBANDA_BAIXA = (Y_LAJE_BAIXA[1], Y_LAJE_BAIXA[1] + 0.90)

AVANCO_CINTA = 0.14     # quanto a cinta e a coroa saem do pano
AVANCO_BASE = 0.16

# --- entrada principal -----------------------------------------------------
# O vao envidracado da entrada, na fachada oeste. Ele NAO e' o vao de porta da
# planta (2,80 m): e' a caixa de vidro inteira em volta dele, que e' o que da'
# escala de hospital publico a uma parede de 68 m.
ENTRADA_Z = 34.20
ENTRADA_Z0, ENTRADA_Z1 = 30.20, 38.30
ENTRADA_TOPO = 3.30
PORTA_Z0, PORTA_Z1 = ENTRADA_Z - 1.40, ENTRADA_Z + 1.40
PORTA_TOPO = P.PORTA_H

# --- marquise e escada -----------------------------------------------------
TERRACO_X0, TERRACO_X1 = -10.00, 0.0
TERRACO_Z0, TERRACO_Z1 = 22.00, 47.00
MARQUISE = (3.90, 4.35)
DEGRAUS = 3                  # 3 espelhos de 0,20 + o piso do terraco
DEGRAU_H = 0.20
DEGRAU_P = 0.55
PE_DA_ESCADA = TERRACO_X0 - DEGRAU_P * DEGRAUS    # -11.65

# Origem da cena: 1,35 m adiante do ultimo degrau, no eixo da porta.
ORIGEM = (PE_DA_ESCADA - 1.35, CHAO, ENTRADA_Z)

# --- torre do elevador -----------------------------------------------------
# O X0 nao e' o do poco (56,0): a torre MORDE a fachada em 10 cm. Encostada
# exatamente no plano da fachada, a face oeste dela ficaria coplanar com a face
# leste do predio, e duas faces coplanares brigam por profundidade — o defeito
# aparece piscando a 40 m de distancia, que e' de onde se olha um predio.
TORRE_X0, TORRE_X1 = P.POCO_X0 - ESP - 0.10, P.POCO_X1
TORRE_Z0, TORRE_Z1 = P.POCO_Z0, P.POCO_Z1
TORRE_TOPO = 11.90          # passa da platibanda: casa de maquinas em cima

# --- chamine da casa de maquinas -------------------------------------------
CHAMINE_X0, CHAMINE_X1 = 49.60, 52.00
CHAMINE_Z0, CHAMINE_Z1 = Z1 - 0.50, Z1 + 2.40   # morde a fachada, ver a torre
CHAMINE_TOPO = 16.40

# --- calcada ---------------------------------------------------------------
# Nao e' uma laje unica cobrindo o terreno todo: sao faixas em volta do predio
# mais o patio da entrada. Uma laje de 80 x 80 m plana ia brigar com o relevo
# do Terrain3D da cidade em algum canto, e o canto errado vira degrau invisivel.
CALCADA_L = 4.50                       # largura da faixa em volta do predio
CALCADA_Y = (CHAO - 0.70, CHAO)
PATIO = (ORIGEM[0] - 4.0, 0.0, TERRACO_Z0 - 4.0, TERRACO_Z1 + 4.0)


# ==========================================================================
# ESTADO DAS JANELAS
#
# Fixo, e nao sorteado, pelo mesmo motivo das lampadas do corredor la' dentro:
# se mudar a cada geracao, a fachada "pisca" entre uma build e outra e ninguem
# consegue comparar duas capturas de tela.
# ==========================================================================

ESTADO_JANELA = [
    "escura", "escura", "acesa", "escura", "tapada", "escura",
    "escura", "acesa", "escura", "quebrada", "escura", "escura",
    "acesa", "escura", "tapada", "escura", "escura", "quebrada",
]

# O letreiro. Duas letras queimadas — e as que sobram deixam SPIT no meio da
# palavra, que e' de graca e e' exatamente o tom da cena.
PALAVRA = "HOSPITAL"
LETRAS_MORTAS = {1, 6}          # o "O" e o "A"

# Cada letra num quadrado 0..1, como uma lista de retangulos (x0, x1, y0, y1).
# Fonte de bloco desenhada na mao: 25 caixas pra palavra inteira, o que e'
# menos do que uma unica letra em curva custaria.
TRACOS = {
    "H": [(0.00, 0.22, 0.00, 1.00), (0.78, 1.00, 0.00, 1.00),
          (0.22, 0.78, 0.41, 0.59)],
    "O": [(0.00, 0.22, 0.00, 1.00), (0.78, 1.00, 0.00, 1.00),
          (0.22, 0.78, 0.82, 1.00), (0.22, 0.78, 0.00, 0.18)],
    "S": [(0.00, 1.00, 0.82, 1.00), (0.00, 0.22, 0.50, 0.82),
          (0.00, 1.00, 0.41, 0.59), (0.78, 1.00, 0.18, 0.50),
          (0.00, 1.00, 0.00, 0.18)],
    "P": [(0.00, 0.22, 0.00, 1.00), (0.22, 1.00, 0.82, 1.00),
          (0.78, 1.00, 0.50, 0.82), (0.22, 1.00, 0.41, 0.59)],
    "I": [(0.39, 0.61, 0.00, 1.00)],
    "T": [(0.00, 1.00, 0.82, 1.00), (0.39, 0.61, 0.00, 0.82)],
    "A": [(0.00, 0.22, 0.00, 0.82), (0.78, 1.00, 0.00, 0.82),
          (0.22, 0.78, 0.82, 1.00), (0.22, 0.78, 0.41, 0.59)],
    "L": [(0.00, 0.22, 0.18, 1.00), (0.00, 1.00, 0.00, 0.18)],
}
LETRA_L = 1.60
LETRA_H = 1.50
LETRA_VAO = 0.52
LETRA_Y = 4.62


# ==========================================================================
# FERRAMENTAS DE FACHADA
#
# `lado` e' sempre visto de fora: "n" olha pro -Z, "s" pro +Z, "o" pro -X,
# "l" pro +X. `coord` e' o plano EXTERNO, e a casca cresce pra dentro.
# ==========================================================================

DENTRO = {"n": +1.0, "s": -1.0, "o": +1.0, "l": -1.0}
CORRE_EM_X = {"n": True, "s": True, "o": False, "l": False}


def caixa_fachada(fac, lado, coord, a, b, y0, y1, mat,
                  esp=ESP, avanco=0.0, uv=2.6):
    """Uma caixa colada na fachada, de `a` a `b` ao longo do muro.

    `avanco` faz a peca sair pra FORA do plano (cinta, peitoril, moldura).
    """
    if y1 - y0 < 1e-4 or b - a < 1e-4:
        return
    d = DENTRO[lado]
    c0, c1 = coord - avanco * d, coord + esp * d
    lo, hi = min(c0, c1), max(c0, c1)
    if CORRE_EM_X[lado]:
        fac.caixa(0, mat, a, b, y0, y1, lo, hi, uv)
    else:
        fac.caixa(0, mat, lo, hi, y0, y1, a, b, uv)


def pedacos(a, b, y0, y1, buracos):
    """Fatia a faixa [a,b] x [y0,y1] nos pedacos CHEIOS em volta dos buracos.

    Mesma regra do interior (`pedacos_do_muro`): parede com vao e' um monte de
    caixa em volta do buraco, nunca um retangulo furado. Furo booleano daria
    normal invertida em algum canto, e o canto errado de uma fachada de 68 m
    aparece de longe.
    """
    saida = []
    corrente = a
    for (h0, h1, hy0, hy1) in sorted(buracos):
        if h1 <= a + 1e-4 or h0 >= b - 1e-4:
            continue
        if hy1 <= y0 + 1e-4 or hy0 >= y1 - 1e-4:
            continue              # o buraco nem passa por esta faixa
        h0, h1 = max(h0, a), min(h1, b)
        if h1 <= corrente + 1e-4:
            continue
        if h0 > corrente + 1e-4:
            saida.append((corrente, h0, y0, y1))
        hy0, hy1 = max(hy0, y0), min(hy1, y1)
        if hy0 > y0 + 1e-4:
            saida.append((h0, h1, y0, hy0))
        if hy1 < y1 - 1e-4:
            saida.append((h0, h1, hy1, y1))
        corrente = max(corrente, h1)
    if corrente < b - 1e-4:
        saida.append((corrente, b, y0, y1))
    return saida


def faixa(fac, lado, coord, a, b, y0, y1, mat, buracos=(), **kw):
    for (pa, pb, py0, py1) in pedacos(a, b, y0, y1, buracos):
        caixa_fachada(fac, lado, coord, pa, pb, py0, py1, mat, **kw)


# ==========================================================================
# AS JANELAS DA PLANTA
# ==========================================================================

def _lado_do_muro(m):
    """Qual fachada este muro externo e'."""
    if m["eixo"] == "x":
        return "n" if m["coord"] < 30.0 else "s"
    return "o" if m["coord"] < 28.0 else "l"


def _plano(lado, andar):
    if lado == "n":
        return 0.0
    if lado == "s":
        return Z1 if andar == 1 else Z2
    if lado == "o":
        return 0.0
    return X1


def janelas():
    """Todas as janelas das quatro fachadas, nos dois andares.

    Devolve (lado, plano, a, b, y0, y1) em coordenadas absolutas — ja' com a
    cota do andar somada, que e' o que o emissor quer.
    """
    saida = []
    for m in P.muros():
        if m["tipo"] != "externa":
            continue
        lado = _lado_do_muro(m)
        plano = _plano(lado, m["andar"])
        base = P.cota(m["andar"])
        for v in m["vaos"]:
            if v["tipo"] != "janela":
                continue
            saida.append((lado, plano,
                          v["c"] - v["l"] * 0.5, v["c"] + v["l"] * 0.5,
                          base + v["y0"], base + v["y1"]))
    # Ordem estavel: e' ela que faz o padrao de janela acesa/tapada ser sempre
    # o mesmo de uma geracao pra outra.
    saida.sort(key=lambda j: (j[0], j[4], j[2]))
    return saida
