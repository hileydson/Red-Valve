"""A escola vista de FORA: a casca que vai para a cidade.

Este modulo so' descreve a fachada. Quem escreve arquivo e'
`gerar_cena_exterior.py`.

==============================================================================
POR QUE UMA CASCA, E NAO O PREDIO DE VERDADE

O interior da escola tem 18 mil triangulos de estrutura, 76 luzes, 374 moveis e
137 rabiscos. Botar aquilo dentro da `stage_1`, que ja' carrega a cidade
inteira, seria pagar o predio todo em todo quadro de jogo pra ver uma fachada
de longe.

Entao o que vai pra rua e' uma CASCA: as quatro fachadas, o telhado e o muro do
patio. Entrar na escola e' trocar de cena, igual a' igreja, a' casa do Jimmy e
ao hospital.

Duas consequencias que valem saber:

  - toda janela precisa de um PAINEL PRETO atras do vidro. Sem ele da' pra
    espiar o vazio pelo proprio buraco da janela.
  - o portao da rua e' de CHAPA cega. Portao vazado ali mostraria que o patio
    do outro lado nao existe.

==============================================================================
O PATIO NA CASCA

O patio e' o unico pedaco do interior que aparece de fora, e ele aparece de
propósito: ele fica SEM TELHADO na casca tambem, com o piso de cimento e a
mancha da quadra desenhados nele.

Custa uma duzia de caixas e resolve um problema real: a escola tem 76 x 68 m e
o muro do patio tem 4,80 m. De cima de qualquer coisa — e a cidade tem morro —
da' pra olhar por cima dele. Com o telhado fechado, o jogador veria um bloco
macico onde a planta do menu mostra uma quadra.

==============================================================================
A ORIGEM DA CENA

O (0,0,0) da cena de fora NAO e' o canto do terreno: e' a CALCADA DIANTE DO
PORTAO DA RUA. E' esse ponto que vai em cima do marcador na stage_1.

Assim o marcador vira ao mesmo tempo "onde a escola fica" e "onde o jogador
pisa", e girar a instancia no editor gira o predio EM TORNO do portao — a
entrada continua no mesmo lugar, que e' justamente o que se quer ajustar quando
se esta' encaixando 76 x 68 m numa rua pronta.
"""

import planta as P

# ==========================================================================
# MEDIDAS
# ==========================================================================

X0, X1 = P.PREDIO_X0, P.PREDIO_X1        # 0 .. 76
Z0, Z1 = P.PREDIO_Z0, P.PREDIO_Z1        # 0 .. 68

ESP = 0.45              # espessura da casca
CHAO = -0.60            # cota do terreno em volta (o piso interno e' 0)

# As faixas horizontais da fachada, de baixo pra cima.
Y_BASE = (CHAO, 0.35)                    # embasamento
Y_CORPO = (0.35, P.PE)                   # o pano unico do terreo
Y_COROA = (P.PE, P.PE + 0.40)            # a cinta de concreto
Y_PLATIBANDA = (Y_COROA[1], P.PATIO_MURO_ALTO)
Y_TELHADO = (Y_COROA[1], Y_COROA[1] + 0.35)

AVANCO_CINTA = 0.14
AVANCO_BASE = 0.16

# --- o portao da rua -------------------------------------------------------
# O vao de chapa da entrada, na fachada oeste. Ele NAO e' o vao de porta da
# planta (2,60 m): e' o portal inteiro em volta dele, que e' o que da' escala
# de escola publica a um muro de 68 m.
PORTAO_Z = 33.00
PORTAO_Z0, PORTAO_Z1 = 29.40, 36.60
PORTAO_TOPO = 4.20
FOLHA_Z0, FOLHA_Z1 = PORTAO_Z - 1.30, PORTAO_Z + 1.30
FOLHA_TOPO = P.PORTA_H + 0.20

# --- o patio, que fica descoberto na casca tambem --------------------------
PATIO = P.por_ident("patio")
QUADRA = (10.0, 20.0, 36.0, 36.0)        # o mesmo retangulo de `mobilia.py`

# --- a calcada -------------------------------------------------------------
# Nao e' uma laje unica cobrindo o terreno: sao faixas em volta do predio mais
# o recuo do portao. Uma laje de 90 x 80 m plana ia brigar com o relevo do
# Terrain3D da cidade em algum canto, e o canto errado vira degrau invisivel.
CALCADA_L = 4.00
CALCADA_Y = (CHAO - 0.70, CHAO)
RECUO_PORTAO = (-7.00, 0.0, PORTAO_Z0 - 3.0, PORTAO_Z1 + 3.0)

# Origem da cena: 2 m adiante do portao, no eixo dele.
ORIGEM = (-2.00, CHAO, PORTAO_Z)


# ==========================================================================
# ESTADO DAS JANELAS
#
# Fixo, e nao sorteado, pelo mesmo motivo das lampadas do corredor la' dentro:
# se mudar a cada geracao, a fachada "pisca" entre uma build e outra e ninguem
# consegue comparar duas capturas de tela.
#
# A escola tem MAIS janela quebrada que o hospital, e isso e' o desenho do
# lugar: o hospital fechou, a escola foi abandonada e depois apedrejada.
# ==========================================================================

ESTADO_JANELA = [
    "escura", "quebrada", "escura", "tapada", "escura", "quebrada",
    "escura", "escura", "acesa", "quebrada", "escura", "tapada",
    "quebrada", "escura", "escura", "acesa", "tapada", "quebrada",
]

# O letreiro sobre o portao. Uma letra queimada — e a que falta deixa
# "E COLA" no muro, que e' de graca e e' exatamente o tom da cena.
PALAVRA = "ESCOLA"
LETRAS_MORTAS = {1}

# Cada letra num quadrado 0..1, como uma lista de retangulos (x0, x1, y0, y1).
# Fonte de bloco desenhada na mao: 19 caixas pra palavra inteira, o que e'
# menos do que uma unica letra em curva custaria.
TRACOS = {
    "E": [(0.00, 0.22, 0.00, 1.00), (0.22, 1.00, 0.82, 1.00),
          (0.22, 0.86, 0.41, 0.59), (0.22, 1.00, 0.00, 0.18)],
    "S": [(0.00, 1.00, 0.82, 1.00), (0.00, 0.22, 0.50, 0.82),
          (0.00, 1.00, 0.41, 0.59), (0.78, 1.00, 0.18, 0.50),
          (0.00, 1.00, 0.00, 0.18)],
    "C": [(0.00, 0.22, 0.00, 1.00), (0.22, 1.00, 0.82, 1.00),
          (0.22, 1.00, 0.00, 0.18)],
    "O": [(0.00, 0.22, 0.00, 1.00), (0.78, 1.00, 0.00, 1.00),
          (0.22, 0.78, 0.82, 1.00), (0.22, 0.78, 0.00, 0.18)],
    "L": [(0.00, 0.22, 0.18, 1.00), (0.00, 1.00, 0.00, 0.18)],
    "A": [(0.00, 0.22, 0.00, 0.82), (0.78, 1.00, 0.00, 0.82),
          (0.22, 0.78, 0.82, 1.00), (0.22, 0.78, 0.41, 0.59)],
}
LETRA_L = 1.10
LETRA_H = 1.05
LETRA_VAO = 0.36
LETRA_Y = 4.95


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
        fac.caixa(mat, a, b, y0, y1, lo, hi, uv)
    else:
        fac.caixa(mat, lo, hi, y0, y1, a, b, uv)


def pedacos(a, b, y0, y1, buracos):
    """Fatia a faixa [a,b] x [y0,y1] nos pedacos CHEIOS em volta dos buracos.

    Mesma regra do interior: parede com vao e' um monte de caixa em volta do
    buraco, nunca um retangulo furado. Furo booleano daria normal invertida em
    algum canto, e o canto errado de uma fachada de 76 m aparece de longe.
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
# AS JANELAS E OS BURACOS DA PLANTA
# ==========================================================================

def _lado_do_muro(m):
    if m["eixo"] == "x":
        return "n" if m["coord"] < (Z0 + Z1) * 0.5 else "s"
    return "o" if m["coord"] < (X0 + X1) * 0.5 else "l"


def _plano(lado):
    return {"n": Z0, "s": Z1, "o": X0, "l": X1}[lado]


def janelas():
    """Todas as janelas das quatro fachadas.

    Devolve (lado, plano, a, b, y0, y1, quebrada) em coordenadas absolutas.
    Ordem estavel: e' ela que faz o padrao de janela acesa/tapada ser sempre o
    mesmo de uma geracao pra outra.
    """
    saida = []
    for m in P.muros():
        if m["tipo"] != "externa":
            continue
        lado = _lado_do_muro(m)
        plano = _plano(lado)
        for v in m["vaos"]:
            if v["tipo"] != "janela":
                continue
            saida.append((lado, plano, v["c"] - v["l"] * 0.5,
                          v["c"] + v["l"] * 0.5, v["y0"], v["y1"],
                          bool(v.get("quebrada"))))
    saida.sort(key=lambda j: (j[0], j[4], j[2]))
    return saida


def buracos():
    """Os dois rombos, vistos de fora. (lado, plano, a, b, y0, y1).

    Eles aparecem na casca DE PROPOSITO, apesar de nao levarem a lugar nenhum
    aqui: e' o unico jeito de a fachada da rua concordar com a planta do menu,
    que ja' desenha os dois. Um rombo tapado por fora e aberto por dentro e' o
    tipo de discordancia que so' aparece depois de alguem rodar o mapa inteiro.
    """
    saida = []
    for m in P.muros():
        for v in m["vaos"]:
            if v["tipo"] != "buraco":
                continue
            lado = _lado_do_muro(m)
            saida.append((lado, _plano(lado), v["c"] - v["l"] * 0.5,
                          v["c"] + v["l"] * 0.5, v["y0"], v["y1"]))
    return saida
