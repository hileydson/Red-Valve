"""O plano de luz da escola e o do porao.

Os dois moram no mesmo arquivo porque sao o mesmo assunto visto do avesso, e
comparar um com o outro e' o que explica os dois.

==============================================================================
A ESCOLA: MAL ILUMINADA, QUE E' PIOR QUE ESCURA

Escola abandonada com a energia meio viva. A regra e' LUZ DESIGUAL:

  - Corredor tem luminaria a cada 8 m, mas uma em cada tres esta' queimada.
    Sobram pocas de luz separadas por trechos pretos, e o jogador tem de
    atravessar o preto sabendo que a proxima poca esta' la'.
  - Sala de aula nasce APAGADA. So' algumas tem lampada viva, e sao sempre as
    mesmas — servem de referencia pra quem esta' se perdendo.
  - O PATIO nao tem lampada de teto nenhuma (ele nao tem teto): a luz dele e'
    a lua, que entra pela abertura, mais dois refletores de quadra, um deles
    morto. E' o unico lugar da escola com luz que vem de cima do mundo, e essa
    diferenca e' o que faz o patio parecer "fora".

==============================================================================
O PORAO: ESCURO DE VERDADE, E ESSA E' A DIFERENCA

Aqui a regra se inverte. O pedido foi explicito: o porao e' mais escuro, e tem
de ser a LANTERNA que resolve. Entao:

  - As lampadas sao POUCAS e FRACAS, e a maior parte esta' morta. Elas nao
    iluminam o caminho: elas MARCAM o caminho. Ver a proxima lampada a 20 m no
    escuro e' a unica orientacao que o jogador tem la' dentro.
  - Nenhuma tem sombra e nenhuma tem preenchimento de parede (a omni de apoio
    que a escola usa). Parede preta aqui e' o efeito, nao o defeito.
  - A luz ambiente da cena e' ~4x menor que a da escola (ver
    `gerar_cena_porao.py`). E' ela, e nao as lampadas, quem decide se o jogador
    precisa da lanterna — lampada e' pontual e nao muda o piso do escuro.

==============================================================================
O LIMITE DE 8 LUZES

O projeto roda no renderer `mobile`, que aceita 8 omni + 8 spot POR MALHA e
descarta o resto SEM AVISAR — o sintoma e' a lampada que apaga sozinha quando
voce anda pra tras. Duas defesas, as mesmas do hospital: alcance curto, e o
gerador partindo a malha ate' cada pedaco ver 8 ou menos.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import planta as P
import porao as PO

# Cores. A fluorescente velha nao e' branca: ela puxa pro verde, e e' esse
# verde que faz pele de personagem parecer doente.
FLUOR = (0.74, 0.86, 0.78, 1.0)
FLUOR_FRIA = (0.80, 0.88, 1.00, 1.0)
EMERGENCIA = (1.00, 0.16, 0.12, 1.0)
LUAR = (0.46, 0.56, 0.86, 1.0)
QUENTE = (1.00, 0.62, 0.28, 1.0)
VERDE_DOENTE = (0.44, 0.78, 0.56, 1.0)
# A lampada incandescente puxada no fio, la' embaixo. Bem mais quente que
# qualquer luz da escola: e' a unica coisa do porao que nao e' terra.
BULBO = (1.00, 0.70, 0.36, 1.0)

PASSO_CORREDOR = 8.0
ALTURA_LUMINARIA = 0.22

# Os mesmos numeros do hospital, e pelos mesmos motivos (ver o cabecalho de
# `tools/godot/hospital/luzes.py`): alcance que morre logo abaixo do piso pra
# a caixa de culling nao dobrar de largura, e cone estreito pra sobrar preto
# entre uma poca e outra.
ALCANCE_CORREDOR = 4.7
ALCANCE_SALA = 4.5
ANGULO_TETO = 32.0
QUEDA_TETO = 0.45


def _luz(nome, tipo, pos, cor, energia, alcance, **extra):
    d = {"nome": nome, "tipo": tipo, "pos": pos, "cor": cor,
         "energia": energia, "alcance": alcance, "piscar": None,
         "sombra": False, "fog": 1.0, "mira": None, "angulo": 45.0,
         "luminaria": None}
    d.update(extra)
    return d


# ==========================================================================
# ESCOLA
# ==========================================================================

def _pontos_do_corredor(e):
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


# Quais luminarias de corredor estao vivas. Sequencia FIXA (e nao `randf`)
# porque o corredor tem de ser IGUAL toda vez que o jogador voltar nele: um
# trecho preto que muda de lugar entre uma passada e outra tira dele a unica
# coisa que tinha pra se orientar aqui dentro.
#   0 = queimada de vez   1 = viva   2 = viva mas tremendo   3 = estourando
ESTADO_CORREDOR = [1, 0, 2, 1, 1, 0, 3, 1, 2, 0, 1, 1, 0, 2, 1, 3, 1, 0]


def luzes_de_corredor(e, contador):
    saida = []
    y = P.cota() + P.PE - ALTURA_LUMINARIA
    pontos, eixo = _pontos_do_corredor(e)
    for (x, z) in pontos:
        estado = ESTADO_CORREDOR[contador[0] % len(ESTADO_CORREDOR)]
        contador[0] += 1
        luminaria = {"pos": (x, y + 0.06, z), "eixo": eixo,
                     "acesa": estado != 0, "comprimento": 2.4}
        if estado == 0:
            # Queimada: a luminaria continua la' (e' o objeto que faz o
            # corredor parecer corredor), so' nao tem luz nenhuma nela.
            saida.append({"so_luminaria": luminaria})
            continue
        piscar = {1: None, 2: "nervoso", 3: "quebrado"}[estado]
        energia = {1: 3.2, 2: 2.8, 3: 4.0}[estado]
        saida.append(_luz("fluor_%s_%d" % (e["ident"], len(saida)),
                          "SpotLight3D", (x, y - 0.10, z), FLUOR,
                          energia, ALCANCE_CORREDOR, piscar=piscar, fog=1.1,
                          mira=(0.0, -1.0, 0.0), angulo=ANGULO_TETO,
                          sombra=(estado == 1 and len(saida) % 6 == 0),
                          luminaria=luminaria))
    return saida


# (energia, cor, alcance, piscar, quantas, fog) — energia 0 = sala apagada,
# que e' o caso da maioria das salas de aula, de proposito.
RECEITA = {
    "sala_aula": (0.0, FLUOR, ALCANCE_SALA, None, 2, 1.0),
    "secretaria": (2.4, FLUOR, ALCANCE_SALA, "nervoso", 2, 1.2),
    "refeitorio": (2.2, FLUOR, 5.0, "nervoso", 3, 1.2),
    "biblioteca": (1.8, QUENTE, ALCANCE_SALA, "quebrado", 2, 1.4),
    "laboratorio": (2.5, VERDE_DOENTE, ALCANCE_SALA, "nervoso", 2, 1.5),
    "almoxarifado": (1.6, QUENTE, 4.2, "quebrado", 1, 1.4),
    "deposito": (1.8, QUENTE, 4.4, "quebrado", 1, 1.5),
}

# As poucas salas de aula acesas. Sao as que ficam de frente pro corredor mais
# usado: servem de referencia visual pra quem esta' se perdendo.
SALAS_ACESAS = {"sala_102": 2.2, "sala_104": 1.9, "sala_106": 2.4}
SALAS_PISCANDO = {"sala_104": "quebrado", "sala_106": "nervoso"}


def luzes_de_sala(s):
    receita = RECEITA.get(s["tipo"])
    if receita is None:
        return []
    energia, cor, alcance, piscar, quantas, fog = receita
    if s["tipo"] == "sala_aula":
        energia = SALAS_ACESAS.get(s["ident"], 0.0)
        piscar = SALAS_PISCANDO.get(s["ident"])
        if energia <= 0.0:
            y = P.cota() + P.PE - ALTURA_LUMINARIA + 0.06
            return [{"so_luminaria": {
                "pos": (s["x0"] + (s["x1"] - s["x0"]) * t,
                        y, (s["z0"] + s["z1"]) * 0.5),
                "eixo": "x", "acesa": False, "comprimento": 2.4}}
                for t in (0.33, 0.67)]

    y = P.cota() + P.PE - ALTURA_LUMINARIA
    larg_x = s["x1"] - s["x0"]
    larg_z = s["z1"] - s["z0"]
    eixo = "x" if larg_x >= larg_z else "z"
    saida = []
    for i in range(quantas):
        t = (i + 1.0) / (quantas + 1.0)
        if eixo == "x":
            x, z = s["x0"] + larg_x * t, (s["z0"] + s["z1"]) * 0.5
        else:
            x, z = (s["x0"] + s["x1"]) * 0.5, s["z0"] + larg_z * t
        luminaria = {"pos": (x, y + 0.06, z), "eixo": eixo, "acesa": True,
                     "comprimento": 2.4}
        saida.append(_luz("luz_%s_%d" % (s["ident"], i), "SpotLight3D",
                          (x, y - 0.10, z), cor, energia, alcance,
                          piscar=piscar, fog=fog, luminaria=luminaria,
                          mira=(0.0, -1.0, 0.0), angulo=ANGULO_TETO,
                          sombra=False))
    return saida


# --------------------------------------------------------------------------
# o patio
#
# Ele nao tem teto, entao nao tem luminaria de teto. O que existe la' sao dois
# refletores de quadra em poste — e um deles esta' morto, que e' o que deixa
# metade da quadra no escuro e da' ao lugar o ar de "ninguem cuida disto".
# --------------------------------------------------------------------------

REFLETORES = [
    # (x, z, viva) — nas duas pontas da quadra, virados pro centro dela
    (8.00, 29.00, True),
    (39.00, 29.00, False),
]
REFLETOR_H = 6.40


def luzes_do_patio():
    patio = P.por_ident("patio")
    cx, cz = P.centro(patio)
    saida = []
    for (i, (x, z, viva)) in enumerate(REFLETORES):
        luminaria = {"pos": (x, REFLETOR_H, z), "eixo": "x", "acesa": viva,
                     "comprimento": 1.2, "refletor": True,
                     "giro": math.atan2(cx - x, cz - z)}
        if not viva:
            saida.append({"so_luminaria": luminaria})
            continue
        # Alcance longo e cone largo: e' refletor, nao luminaria de forro. Ele
        # e' a unica luz artificial de um espaco de 45 x 36 m.
        saida.append(_luz("refletor_%d" % i, "SpotLight3D",
                          (x, REFLETOR_H - 0.25, z), FLUOR_FRIA, 4.6, 26.0,
                          mira=(cx - x, -REFLETOR_H * 0.75, cz - z),
                          angulo=40.0, sombra=True, fog=1.6,
                          piscar="nervoso", luminaria=luminaria))
    return saida


# --------------------------------------------------------------------------
# luar pelas janelas
#
# Cada feixe e' um spot POR FORA da parede, atravessando o vao. E' a parede que
# recorta o feixe, entao estes precisam de sombra — e' a sombra que desenha o
# retangulo de luz no chao. Sao caros, entao sao POUCOS e escolhidos: so' os
# janelao (2,75 m ou mais), e so' um a cada dois.
# --------------------------------------------------------------------------

def luzes_de_janela():
    saida = []
    n = 0
    meio_x = (P.PREDIO_X0 + P.PREDIO_X1) * 0.5
    meio_z = (P.PREDIO_Z0 + P.PREDIO_Z1) * 0.5
    for m in P.muros():
        if m["tipo"] != "externa":
            continue
        for v in m["vaos"]:
            if v["tipo"] != "janela" or v["l"] < 2.75:
                continue
            n += 1
            if n % 2 == 0:
                continue
            y = P.cota() + (v["y0"] + v["y1"]) * 0.5 + 0.7
            if m["eixo"] == "x":
                lado = -1.0 if m["coord"] < meio_z else 1.0
                pos = (v["c"], y, m["coord"] + lado * 3.2)
                mira = (0.0, -0.55, -lado)
            else:
                lado = -1.0 if m["coord"] < meio_x else 1.0
                pos = (m["coord"] + lado * 3.2, y, v["c"])
                mira = (-lado, -0.55, 0.0)
            saida.append(_luz("luar_%d" % n, "SpotLight3D", pos, LUAR,
                              5.2, 11.0, mira=mira, angulo=32.0, sombra=True,
                              fog=2.8))
    return saida


# --------------------------------------------------------------------------
# emergencia: so' onde faz sentido
# --------------------------------------------------------------------------

def luzes_de_emergencia():
    alvos = [
        (2.60, 12.85),                              # ponta oeste do corredor N
        (73.00, 12.85),                             # quina nordeste
        (73.00, 54.50),                             # quina sudeste
        (P.GRADE_X - 3.00, 54.50),                  # em cima da grade
        (P.GRADE_X + 3.00, 54.50),
        (2.60, 54.50),                              # ponta oeste do corredor S
        (67.00, 59.50),                             # dentro do deposito
    ]
    saida = []
    for (i, (x, z)) in enumerate(alvos):
        y = P.cota() + P.PE - 0.55
        saida.append(_luz("emergencia_%d" % i, "OmniLight3D", (x, y, z),
                          EMERGENCIA, 1.5, 4.2, piscar="nervoso", fog=2.0,
                          luminaria={"pos": (x, y, z), "eixo": "x",
                                     "acesa": True, "comprimento": 0.5,
                                     "vermelha": True}))
    return saida


# --------------------------------------------------------------------------
# A OMNI DE ACOMPANHAMENTO
#
# O cone de 32 graus resolve a poca no chao e resolve o orcamento de luz, mas
# nao ilumina PAREDE nenhuma: saindo do teto a 3,28 m e abrindo 32 graus, ele
# so' alcancaria a parede lateral do corredor 4 m abaixo do proprio piso.
#
# A correcao e' uma omni curta a MEIA ALTURA (1,60 m), e nao no teto: dali a
# esfera pega a parede inteira, rodape incluido, sem crescer a caixa de
# culling. Fisicamente nao ha' lampada nenhuma a 1,60 m no meio do corredor —
# isto e' o que a luz refletida pelo piso faria. Por isso ela e' fraca e nao
# projeta sombra. (A conta completa esta' no `luzes.py` do hospital.)
# --------------------------------------------------------------------------

OMNI_ALCANCE = 3.0
OMNI_ALTURA = 1.60
OMNI_FRACAO = 0.55


def _acompanhar(luz):
    if luz["tipo"] != "SpotLight3D" or luz["mira"][1] > -0.9:
        return None
    piso = luz["pos"][1] - (P.PE - ALTURA_LUMINARIA - 0.10)
    pos = (luz["pos"][0], piso + OMNI_ALTURA, luz["pos"][2])
    return _luz(luz["nome"] + "_ambiente", "OmniLight3D", pos,
                luz["cor"], luz["energia"] * OMNI_FRACAO, OMNI_ALCANCE,
                piscar=luz["piscar"], fog=luz["fog"] * 0.4)


def montar():
    """Todas as luzes fixas da escola."""
    todas = []
    contador = [0]
    for e in P.areas():
        if e["tipo"] == "corredor":
            todas.extend(luzes_de_corredor(e, contador))
    todas.extend(luzes_do_patio())
    for s in P.salas():
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


# ==========================================================================
# PORAO
# ==========================================================================

# Onde tem lampada, em fracao do caminho (0 = boca de entrada, 1 = boca de
# saida), e em que estado. Espalhadas a mao e nao a cada N metros: o que faz o
# tunel dar medo e' o INTERVALO desigual entre uma e a outra. Duas perto uma da
# outra e depois trinta metros de nada vale mais que doze bem distribuidas.
#   0 = morta   1 = acesa   2 = tremendo   3 = estourando
LAMPADAS_PORAO = [
    (0.02, 1), (0.06, 2), (0.12, 0), (0.17, 1), (0.24, 0), (0.28, 3),
    (0.34, 1), (0.40, 0), (0.44, 2), (0.52, 1), (0.58, 0), (0.63, 1),
    (0.70, 3), (0.76, 0), (0.81, 2), (0.88, 1), (0.94, 0), (0.98, 1),
]
# Mais tres no teto da camara grande — e' o unico lugar do porao com altura
# suficiente pra a lampada ficar acima da cabeca e iluminar chao.
LAMPADAS_CAMARA = [(0.32, 0.35, 1), (0.62, 0.40, 0), (0.48, 0.72, 2)]

BULBO_ALTURA = 0.55        # quanto o fio desce do teto
ALCANCE_BULBO = 5.0


def _ponto_no_caminho(t):
    """(x, z) na fracao `t` do comprimento da polilinha principal."""
    trechos = []
    total = 0.0
    for k in range(len(PO.CAMINHO) - 1):
        ax, az, _ = PO.CAMINHO[k]
        bx, bz, _ = PO.CAMINHO[k + 1]
        comp = math.hypot(bx - ax, bz - az)
        trechos.append((total, comp, ax, az, bx, bz))
        total += comp
    alvo = t * total
    for (inicio, comp, ax, az, bx, bz) in trechos:
        if alvo <= inicio + comp or (inicio, comp) == trechos[-1][:2]:
            f = (alvo - inicio) / comp if comp > 1e-6 else 0.0
            f = max(0.0, min(1.0, f))
            return (ax + (bx - ax) * f, az + (bz - az) * f)
    return (PO.CAMINHO[-1][0], PO.CAMINHO[-1][1])


def montar_porao():
    """As lampadas do tunel. Poucas, fracas, e a maioria morta."""
    todas = []
    pontos = [(_ponto_no_caminho(t), estado)
              for (t, estado) in LAMPADAS_PORAO]
    x0, z0, x1, z1 = PO.CAMARA
    for (fx, fz, estado) in LAMPADAS_CAMARA:
        pontos.append(((x0 + (x1 - x0) * fx, z0 + (z1 - z0) * fz), estado))

    for (i, ((x, z), estado)) in enumerate(pontos):
        teto = PO.teto_da_celula(int(x // PO.CELULA), int(z // PO.CELULA))
        y = teto - BULBO_ALTURA
        luminaria = {"pos": (x, teto, z), "acesa": estado != 0,
                     "queda": BULBO_ALTURA}
        if estado == 0:
            todas.append({"so_luminaria": luminaria})
            continue
        piscar = {1: None, 2: "nervoso", 3: "quebrado"}[estado]
        # Energia baixa de proposito. 1,6 numa omni de alcance 5 acende um
        # circulo de uns 4 m e para ali: o resto do tunel continua sendo
        # trabalho da lanterna, que foi o pedido.
        energia = {1: 1.6, 2: 1.3, 3: 2.1}[estado]
        todas.append(_luz("bulbo_%d" % i, "OmniLight3D", (x, y, z), BULBO,
                          energia, ALCANCE_BULBO, piscar=piscar, fog=1.8,
                          sombra=False, luminaria=luminaria))
    return todas


# ==========================================================================

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
    for nome, tudo in (("escola", montar()), ("porao", montar_porao())):
        luzes = so_luzes(tudo)
        print("%s: %d luzes (omni %d, spot %d), %d luminarias, %d com sombra"
              % (nome, len(luzes),
                 sum(1 for l in luzes if l["tipo"] == "OmniLight3D"),
                 sum(1 for l in luzes if l["tipo"] == "SpotLight3D"),
                 len(luminarias(tudo)),
                 sum(1 for l in luzes if l["sombra"])))
