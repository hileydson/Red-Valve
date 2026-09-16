"""O plano de luz do hospital.

==============================================================================
A IDEIA

Hospital abandonado nao e' escuro: e' MAL iluminado, que e' pior. A diferenca
importa pro clima. Escuro puro some com a arquitetura toda e vira corredor
generico; mal iluminado deixa o predio visivel o bastante pra voce reparar que
ele e' grande demais, e escuro o bastante pra voce nao saber o que tem no fim
do corredor.

Entao a regra aqui nao e' "pouca luz", e' LUZ DESIGUAL:

  - Corredor tem lampada a cada 8 m, mas UMA EM CADA TRES esta' queimada. O
    resultado sao pocas de luz separadas por trechos pretos — e o jogador tem
    que atravessar o preto sabendo que a proxima poca esta' la'.
  - Quarto nasce APAGADO por padrao. So' alguns tem lampada viva. E' pra isso
    que serve a lanterna que ele pegou na igreja.
  - Emergencia e cirurgia tem luz FORTE e fria: sao as unicas salas onde ainda
    tem energia de verdade, e o contraste com o corredor e' o susto.
  - Luz vermelha de emergencia fica so' onde faz sentido (elevador, fim de
    corredor, necroterio). Vermelho em tudo vira discoteca.

==============================================================================
O LIMITE DE 8 LUZES

O projeto roda no renderer `mobile`, que aceita 8 omni + 8 spot POR MALHA e
descarta o resto SEM AVISAR — o sintoma e' a lampada que apaga sozinha quando
voce anda pra tras. Duas defesas:

  1. `omni_range` curto (6 a 9 m). Lampada de corredor nao tem por que alcancar
     o corredor vizinho.
  2. O gerador PARTE as malhas grandes ate' cada pedaco ver 8 luzes ou menos
     (ver `dividir_ate_caber` em gerar_cena_hospital.py). Este modulo so'
     precisa entregar posicao e alcance certos pra essa conta fechar.

Alem disso quase toda luz tem `distance_fade`: num predio de 56 x 68 m o
jogador nunca ve duas alas ao mesmo tempo, entao lampada a 25 m pode sumir.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import planta as P

# Cores. A fluorescente velha nao e' branca: ela puxa pro verde, e e' esse
# verde que faz pele de personagem parecer doente.
FLUOR = (0.74, 0.86, 0.78, 1.0)
FLUOR_FRIA = (0.80, 0.88, 1.00, 1.0)
EMERGENCIA = (1.00, 0.16, 0.12, 1.0)
CIRURGICA = (0.92, 0.97, 1.00, 1.0)
LUAR = (0.46, 0.56, 0.86, 1.0)
QUENTE = (1.00, 0.62, 0.28, 1.0)
VERDE_DOENTE = (0.44, 0.78, 0.56, 1.0)

PASSO_CORREDOR = 8.0     # metros entre luminarias de corredor
ALTURA_LUMINARIA = 0.22  # quanto a luminaria desce do teto

# ==============================================================================
# POR QUE LAMPADA DE TETO E' SPOT, E NAO OMNI
#
# Omni no teto parece a escolha obvia — e' o que uma lampada e'. So' que luz sem
# sombra ATRAVESSA parede no Godot, e omni de alcance 8 no meio de um quarto de
# 10 m chega no corredor do outro lado com folga. O resultado eram duas coisas
# ruins de uma vez: vazamento visivel (corredor "apagado" recebendo luz de um
# quarto fechado) e estouro do limite de 8 luzes por malha do renderer mobile,
# porque toda malha vizinha contava aquelas lampadas.
#
# Spot apontado pra baixo resolve os dois: o cone morre no chao do proprio
# comodo, e spot e omni tem ORCAMENTOS SEPARADOS (8 de cada), entao passar a
# iluminacao geral pros spots ainda libera os omni pra luz de emergencia.
#
# De quebra, cone de teto e' exatamente o desenho de luz que se quer aqui:
# pocas separadas por trechos pretos, em vez de um banho parelho.
# ==============================================================================
# O alcance nao passa muito do CHAO de proposito. Cone de teto com alcance 8
# so' termina 4,5 m abaixo do piso, e e' LA' que ele esta' mais largo — a caixa
# de culling que o Godot monta sai com o dobro da largura da poca de luz que se
# ve no chao. Cortando o alcance logo abaixo do piso, a poca fica igual e a
# caixa encolhe pela metade: e' a diferenca entre 14 e 6 spots por malha.
ALCANCE_CORREDOR = 4.8
ALCANCE_SALA = 4.6
# 46 graus, e nao os 60 e tantos de uma luminaria real: do teto a 3,4 m isso
# da' uma poca de ~7 m de diametro, que com luminaria a cada 8 m deixa um
# trecho escuro ENTRE as pocas. Cone largo iluminava o corredor inteiro por
# igual e matava o efeito — alem de fazer cada malha ver luz demais.
# 32 graus. A poca no chao fica com uns 4,2 m — e' o tamanho de uma luminaria
# de verdade vista de longe, e e' o maior cone que ainda deixa a malha ver 8
# spots ou menos. Mais aberto que isso e o corredor inteiro acende por igual.
ANGULO_TETO = 32.0
# Expoente da queda. O padrao (1.0) faz o chao receber so' 30% da energia,
# porque ele esta' a 3,4 m de uma luz que morre em 4,8 — e compensar isso na
# ENERGIA estourava tudo que passasse perto da lampada (a parede a 1 m recebia
# 4x o que o chao recebia, e virava um borrao branco).
#
# Com 0.45 a curva fica quase reta: o chao recebe 59% e a parede colada recebe
# 90%. Ou seja, a mesma poca de luz, sem o estouro — a energia volta a ser um
# numero honesto.
QUEDA_TETO = 0.45


def _luz(nome, tipo, pos, cor, energia, alcance, **extra):
    d = {"nome": nome, "tipo": tipo, "pos": pos, "cor": cor,
         "energia": energia, "alcance": alcance, "piscar": None,
         "sombra": False, "fog": 1.0, "mira": None, "angulo": 45.0,
         "luminaria": None}
    d.update(extra)
    return d


# --------------------------------------------------------------------------
# luminarias de corredor
# --------------------------------------------------------------------------

def _pontos_do_corredor(e):
    """Pontos igualmente espacados no eixo longo do corredor."""
    larg_x = e["x1"] - e["x0"]
    larg_z = e["z1"] - e["z0"]
    if larg_x >= larg_z:
        n = max(int(larg_x / PASSO_CORREDOR), 1)
        passo = larg_x / n
        cz = (e["z0"] + e["z1"]) * 0.5
        return [(e["x0"] + passo * (i + 0.5), cz) for i in range(n)], "x"
    n = max(int(larg_z / PASSO_CORREDOR), 1)
    passo = larg_z / n
    cx = (e["x0"] + e["x1"]) * 0.5
    return [(cx, e["z0"] + passo * (i + 0.5)) for i in range(n)], "z"


# Quais luminarias de corredor estao vivas. E' uma sequencia fixa (e nao
# `randf`) porque o corredor tem de ser IGUAL toda vez que o jogador voltar
# nele: um trecho preto que muda de lugar entre uma passada e outra tira do
# jogador a unica coisa que ele tinha pra se orientar aqui dentro.
#   0 = queimada de vez   1 = viva   2 = viva mas tremendo   3 = estourando
ESTADO_CORREDOR = [1, 2, 0, 1, 3, 1, 0, 2, 1, 0, 1, 2, 1, 0, 3, 1]


def luzes_de_corredor(e, andar, contador):
    saida = []
    y = P.cota(andar) + P.PE - ALTURA_LUMINARIA
    pontos, eixo = _pontos_do_corredor(e)
    for (x, z) in pontos:
        estado = ESTADO_CORREDOR[contador[0] % len(ESTADO_CORREDOR)]
        contador[0] += 1
        nome = "fluor_%s_%d" % (e["ident"], len(saida))
        luminaria = {"pos": (x, y + 0.06, z), "eixo": eixo,
                     "acesa": estado != 0, "comprimento": 2.4}
        if estado == 0:
            # Queimada: a luminaria continua la' (e' o objeto que faz o
            # corredor parecer corredor), so' nao tem luz nenhuma nela.
            saida.append({"so_luminaria": luminaria})
            continue
        piscar = {1: None, 2: "nervoso", 3: "quebrado"}[estado]
        energia = {1: 3.4, 2: 3.0, 3: 4.2}[estado]
        saida.append(_luz(nome, "SpotLight3D", (x, y - 0.10, z), FLUOR,
                          energia, ALCANCE_CORREDOR, piscar=piscar, fog=1.1,
                          mira=(0.0, -1.0, 0.0), angulo=ANGULO_TETO,
                          sombra=(estado == 1 and len(saida) % 6 == 0),
                          luminaria=luminaria))
    return saida


# --------------------------------------------------------------------------
# luz de sala, por tipo
#
# (energia, cor, alcance, piscar, quantas, fog) — energia 0 = sala apagada,
# que e' o caso da maioria dos quartos de proposito.
# --------------------------------------------------------------------------

RECEITA = {
    "quarto": (0.0, FLUOR, ALCANCE_SALA, None, 1, 1.0),
    "exame": (3.0, FLUOR_FRIA, ALCANCE_SALA, "nervoso", 1, 1.2),
    "laboratorio": (2.7, VERDE_DOENTE, ALCANCE_SALA, "nervoso", 2, 1.4),
    "cirurgia": (6.7, CIRURGICA, 5.4, None, 1, 1.6),
    "uti": (2.6, FLUOR_FRIA, ALCANCE_SALA, "quebrado", 2, 1.3),
    "emergencia": (3.4, FLUOR, 5.2, None, 2, 1.2),
    "refeitorio": (2.2, QUENTE, ALCANCE_SALA, "nervoso", 2, 1.1),
    "necroterio": (2.7, VERDE_DOENTE, ALCANCE_SALA, "quebrado", 2, 1.5),
    "farmacia": (2.4, FLUOR, ALCANCE_SALA, None, 1, 1.0),
    "esterilizacao": (2.2, FLUOR_FRIA, ALCANCE_SALA, "nervoso", 1, 1.2),
    "maquinas": (2.9, QUENTE, ALCANCE_SALA, "quebrado", 2, 1.6),
    "arquivo": (1.6, QUENTE, 4.6, "quebrado", 1, 1.3),
    "psiquiatria": (1.8, FLUOR, ALCANCE_SALA, "quebrado", 2, 1.5),
    "terapia": (2.1, FLUOR, ALCANCE_SALA, "nervoso", 1, 1.2),
    "observacao": (2.2, FLUOR_FRIA, ALCANCE_SALA, "nervoso", 1, 1.2),
    "hall": (3.0, FLUOR, 5.4, None, 4, 1.2),
    "saguao": (2.6, FLUOR, 5.2, "nervoso", 3, 1.2),
}

# Os poucos quartos que ficam acesos. Sao os que ficam de frente pro corredor
# mais usado — servem de referencia visual pra quem esta' se perdendo.
QUARTOS_ACESOS = {"quarto_102": 2.4, "quarto_105": 2.0, "quarto_107": 2.5,
                  "quarto_202": 2.2, "quarto_204": 1.7}
QUARTOS_PISCANDO = {"quarto_105": "quebrado", "quarto_204": "nervoso",
                    "quarto_107": "nervoso"}


def luzes_de_sala(s):
    receita = RECEITA.get(s["tipo"])
    if receita is None:
        return []
    energia, cor, alcance, piscar, quantas, fog = receita
    if s["tipo"] == "quarto":
        energia = QUARTOS_ACESOS.get(s["ident"], 0.0)
        piscar = QUARTOS_PISCANDO.get(s["ident"])
        if energia <= 0.0:
            return [{"so_luminaria": {"pos": (
                (s["x0"] + s["x1"]) * 0.5,
                P.cota(s["andar"]) + P.PE - ALTURA_LUMINARIA + 0.06,
                (s["z0"] + s["z1"]) * 0.5),
                "eixo": "x", "acesa": False, "comprimento": 1.8}}]

    y = P.cota(s["andar"]) + P.PE - ALTURA_LUMINARIA
    larg_x = s["x1"] - s["x0"]
    larg_z = s["z1"] - s["z0"]
    eixo = "x" if larg_x >= larg_z else "z"
    saida = []
    for i in range(quantas):
        t = (i + 1.0) / (quantas + 1.0)
        if eixo == "x":
            x = s["x0"] + larg_x * t
            z = (s["z0"] + s["z1"]) * 0.5
        else:
            x = (s["x0"] + s["x1"]) * 0.5
            z = s["z0"] + larg_z * t
        luminaria = {"pos": (x, y + 0.06, z), "eixo": eixo, "acesa": True,
                     "comprimento": 2.4 if s["tipo"] != "quarto" else 1.8}
        saida.append(_luz("luz_%s_%d" % (s["ident"], i), "SpotLight3D",
                          (x, y - 0.10, z), cor, energia, alcance,
                          piscar=piscar, fog=fog, luminaria=luminaria,
                          mira=(0.0, -1.0, 0.0),
                          angulo=50.0 if s["tipo"] == "cirurgia" else ANGULO_TETO,
                          sombra=(s["tipo"] == "cirurgia" and i == 0)))
    return saida


# --------------------------------------------------------------------------
# luar pelas janelas
#
# Cada feixe e' um spot POR FORA da parede, atravessando o vao. E' a parede que
# recorta o feixe, entao estes precisam de sombra — e' a sombra que desenha o
# retangulo de luz no chao. Sao caros, entao sao POUCOS e escolhidos: so' os
# janelao (os vaos de 2,8 m ou mais), que e' onde o efeito aparece.
# --------------------------------------------------------------------------

def luzes_de_janela():
    saida = []
    n = 0
    for m in P.muros():
        if m["tipo"] != "externa":
            continue
        for v in m["vaos"]:
            if v["tipo"] != "janela" or v["l"] < 2.75:
                continue
            # Feixe de janela e' spot com SOMBRA (e' a sombra que recorta o
            # retangulo de luz no chao), e sombra de spot e' cara. Entao so'
            # um a cada dois janelao ganha feixe — o resto fica com a emissao
            # do proprio vidro.
            n += 1
            if n % 2 == 0:
                continue
            y = P.cota(m["andar"]) + (v["y0"] + v["y1"]) * 0.5 + 0.7
            if m["eixo"] == "x":
                lado = -1.0 if m["coord"] < 30.0 else 1.0
                pos = (v["c"], y, m["coord"] + lado * 3.2)
                mira = (0.0, -0.55, -lado)
            else:
                lado = -1.0 if m["coord"] < 28.0 else 1.0
                pos = (m["coord"] + lado * 3.2, y, v["c"])
                mira = (-lado, -0.55, 0.0)
            saida.append(_luz("luar_%d" % n, "SpotLight3D", pos, LUAR,
                              5.5, 11.0, mira=mira, angulo=32.0, sombra=True,
                              fog=2.8))
    return saida


# --------------------------------------------------------------------------
# emergencia: so' nos lugares que justificam
# --------------------------------------------------------------------------

def luzes_de_emergencia():
    saida = []
    alvos = [
        # (x, z, andar) — as duas portas do elevador e as pontas dos corredores
        (P.PREDIO_X1 - 1.0, P.POCO_PORTA_C - 2.0, 1),
        (P.PREDIO_X1 - 1.0, P.POCO_PORTA_C - 2.0, 2),
        (2.4, 12.85, 1), (2.4, 55.50, 1),
        (43.20, 47.80, 1),      # em cima da porta do necroterio
        (2.4, 15.20, 2), (2.4, 48.80, 2),
        (53.00, 63.00, 2),
    ]
    for i, (x, z, andar) in enumerate(alvos):
        y = P.cota(andar) + P.PE - 0.55
        saida.append(_luz("emergencia_%d" % i, "OmniLight3D", (x, y, z),
                          EMERGENCIA, 1.6, 4.5, piscar="nervoso", fog=2.0,
                          luminaria={"pos": (x, y, z), "eixo": "x",
                                     "acesa": True, "comprimento": 0.5,
                                     "vermelha": True}))
    return saida


# --------------------------------------------------------------------------
# a cabine do elevador (a luz anda junto com ela, entao sai a' parte)
# --------------------------------------------------------------------------

def luz_da_cabine():
    return _luz("luz_cabine", "OmniLight3D", (0.0, P.PE - 0.45, 0.0),
                FLUOR, 3.0, 5.0, piscar="nervoso", fog=1.4)


# --------------------------------------------------------------------------

# ==============================================================================
# A OMNI DE ACOMPANHAMENTO
#
# O cone de 32 graus resolve a poca no chao e resolve o orcamento de luz, mas
# ele tem um efeito colateral que so' aparece andando pelo corredor: a parede
# NAO RECEBE LUZ NENHUMA. Um cone que sai do teto a 3,28 m e abre 32 graus so'
# alcancaria a parede lateral (2,5 m fora do eixo) a 4 m ABAIXO da lampada —
# ou seja, embaixo do chao. O resultado era um corredor com o piso iluminado e
# as paredes pretas da cintura pra baixo.
#
# A correcao e' uma omni curta — mas NAO no teto, e sim a MEIA ALTURA.
#
# No teto ela nao resolvia: uma esfera de raio 3 saindo de 3,28 m encontra a
# parede lateral (2,5 m fora do eixo) num circulo de apenas 1,66 m de raio, ou
# seja, ela ilumina a parede de 1,62 m PRA CIMA. O dado, que vai ate' 1,35 m,
# continuava preto — exatamente a faixa na altura do olho da camera.
#
# Descendo a mesma esfera pra 1,60 m, o circulo na parede passa a ir de 0 a
# 3,26 m: a parede inteira, o rodape e ainda sobra pro teto. A caixa de culling
# nao mudou de tamanho, entao o orcamento de luz por malha continua o mesmo.
#
# Fisicamente nao ha' lampada nenhuma a 1,60 m do chao no meio do corredor —
# isto e' luz de preenchimento, o que a luz refletida pelo piso faria. Por isso
# ela nao projeta sombra e e' fraca.
# 3,4 m: o suficiente pra alcancar a parede lateral do corredor na altura do
# olho (3,0 m em diagonal) e nao muito mais. Em 4,0 a caixa de culling dela
# ficava com 8 m de lado e obrigava o gerador a picar a estrutura em setores
# de 6 m — 279 malhas no lugar de 134, pelo mesmo efeito.
OMNI_ALCANCE = 3.0
OMNI_ALTURA = 1.60      # altura do preenchimento, medida do piso
OMNI_FRACAO = 0.55      # da energia do spot que a acompanha


def _acompanhar(luz):
    """Omni curta no mesmo ponto do spot de teto, so' pra lavar as paredes."""
    if luz["tipo"] != "SpotLight3D" or luz["mira"][1] > -0.9:
        return None
    # O piso do andar sai da propria altura do spot, que e' sempre montado em
    # `cota + PE - ALTURA_LUMINARIA - 0.10`.
    piso = luz["pos"][1] - (P.PE - ALTURA_LUMINARIA - 0.10)
    pos = (luz["pos"][0], piso + OMNI_ALTURA, luz["pos"][2])
    return _luz(luz["nome"] + "_ambiente", "OmniLight3D", pos,
                luz["cor"], luz["energia"] * OMNI_FRACAO, OMNI_ALCANCE,
                piscar=luz["piscar"], fog=luz["fog"] * 0.4)


def montar():
    """Todas as luzes fixas do predio."""
    todas = []
    contador = [0]
    for andar in (1, 2):
        for e in P.areas(andar):
            if e["tipo"] == "corredor":
                todas.extend(luzes_de_corredor(e, andar, contador))
            else:
                todas.extend(luzes_de_sala(e))
        for s in P.salas(andar):
            todas.extend(luzes_de_sala(s))
    todas.extend(luzes_de_janela())
    todas.extend(luzes_de_emergencia())

    acompanhantes = []
    for luz in todas:
        if "so_luminaria" in luz:
            continue
        companheira = _acompanhar(luz)
        if companheira:
            acompanhantes.append(companheira)
    todas.extend(acompanhantes)
    return todas


def so_luzes(todas):
    return [l for l in todas if "so_luminaria" not in l]


def luminarias(todas):
    saida = []
    for l in todas:
        if "so_luminaria" in l:
            saida.append(l["so_luminaria"])
        elif l.get("luminaria"):
            saida.append(l["luminaria"])
    return saida


if __name__ == "__main__":
    tudo = montar()
    luzes = so_luzes(tudo)
    print("luzes: %d  (omni %d, spot %d)" % (
        len(luzes),
        sum(1 for l in luzes if l["tipo"] == "OmniLight3D"),
        sum(1 for l in luzes if l["tipo"] == "SpotLight3D")))
    print("luminarias: %d" % len(luminarias(tudo)))
    print("com sombra: %d" % sum(1 for l in luzes if l["sombra"]))
