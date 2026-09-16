"""A planta da escola: o mapa do caderno, em numeros.

Este modulo NAO escreve nada. Ele so' descreve o predio — onde cada sala
comeca e acaba, onde tem porta, onde tem janela, onde esta' a grade e onde
estao os dois buracos — e `gerar_cena_escola.py` transforma isso em geometria,
luz, colisao e navmesh.

==============================================================================
O SISTEMA DE COORDENADAS

    X = largura   (oeste -> leste)
    Y = ALTURA
    Z = profundidade (norte -> sul)

O desenho do caderno esta' de lado; lido de pe', a ENTRADA fica a OESTE (e' por
onde se chega da cidade), o BURACO DE ENTRADA no canto sudeste e o BURACO DE
SAIDA no canto sudoeste.

==============================================================================
A FORMA DA ESCOLA, E POR QUE ELA E' ASSIM

A escola e' um quadrilatero de 76 x 68 m com um PATIO DESCOBERTO dentro —
a "area de lazer" do desenho. O predio e' o anel em volta dele:

       +-----------------------------------------------------+
       |  101 | 102 | 103 | 104 |        SECRETARIA           |
       |------------------------------------------+----------|
       |          CORREDOR NORTE                   |          |
       |----------------------------+--------------|          |
       |                            |  REFEITORIO  | CORREDOR |
       |     PATIO / AREA DE LAZER  |--------------|  LESTE   |
       |     (quadra + bancos)      | BIBL. | LAB. |          |
       |----------------------------+--------------+----------|
       |          CORREDOR SUL        [GRADE]                  |
       |-----------------------------------------------------|
       | ALMOX. | 105 | 106 | 107 |        DEPOSITO           |
       +-----------------------------------------------------+
         ^buraco de saida                       buraco de entrada^

O caminho que o jogador faz nasce dessa forma, e e' ele que manda na planta:

  1. chega da cidade pelo PORTAO DA RUA e cai no PATIO;
  2. do patio entra no predio pela PORTA PRINCIPAL (corredor norte);
  3. anda o corredor norte -> corredor leste -> corredor sul e trombra na
     GRADE, no meio do corredor sul;
  4. do lado de ca' da grade fica o DEPOSITO, e no fundo dele o BURACO;
  5. o buraco leva ao porao (outra cena) e devolve ele no ALMOXARIFADO, que
     esta' do outro lado da grade;
  6. dali ele alcanca o resto do predio e o PORTAO DO PATIO, que so' abre por
     dentro — e' o atalho de volta pra area de lazer.

E' de proposito que o anel NAO fecha: o corredor norte morre na fachada oeste
e o patio so' se liga ao corredor sul pelo portao trancado. Se o anel fechasse,
dava pra contornar a grade pelo outro lado e o porao viraria enfeite.

==============================================================================
POR QUE TUDO E' "INTERIOR DE SALA" + "MURO"

Mesma regra do hospital: cada sala guarda so' o VAO INTERNO (o chao pisavel), e
as paredes sao uma lista PROPRIA de muros com os vaos recortados nelas. Um muro
entre duas salas e' escrito uma vez so'. Descrever sala como retangulo fechado
daria parede dupla em toda divisa — e parede dupla e' z-fighting garantido.

==============================================================================
AS MEDIDAS

    corredor   5,00 m    (o mesmo do hospital: a camera de 3a pessoa precisa)
    porta      2,00 m
    pe-direito 3,50 m
    sala       ~14 x 9,6 m

Sala de aula de verdade tem 7 x 7. Aqui ela e' quase o dobro, pelo mesmo motivo
do hospital: com camera de terceira pessoa e um jogador de 1,35 m de diametro,
sala pequena vira briga com a camera. E numa escola vazia o espaco a mais e' o
proprio clima.
"""

# ==========================================================================
# MEDIDAS BASE
# ==========================================================================

PAREDE = 0.35          # espessura de todo muro interno e externo
PE = 3.50              # pe-direito

ANDAR_1 = 0.0          # a escola tem um andar so'

PORTA_L = 2.00
PORTA_H = 2.40
PORTA_DUPLA_L = 2.60

JANELA_Y0 = 1.05       # peitoril
JANELA_Y1 = 2.80
JANELA_L = 2.60

# O buraco na parede: a passagem pro porao. Baixo de proposito — e' um rombo
# cavado, nao uma porta. 1,70 m de altura obriga a abaixar a cabeca, e e' isso
# que faz a coisa parecer um buraco.
BURACO_L = 1.90
BURACO_H = 1.75

# ==========================================================================
# O PREDIO
# ==========================================================================

PREDIO_X0, PREDIO_X1 = 0.0, 76.0
PREDIO_Z0, PREDIO_Z1 = 0.0, 68.0

# O patio nao tem teto, e as paredes que dao pra ele sao a fachada INTERNA do
# predio: elas sobem alem do pe-direito e viram platibanda.
PATIO_MURO_ALTO = PE + 1.30

# --------------------------------------------------------------------------
# A GRADE
#
# Atravessa o corredor sul de parede a parede. Nao e' um vao num muro: e' um
# objeto no meio do corredor, e por isso mora aqui como constante em vez de
# entrar na lista de muros.
# --------------------------------------------------------------------------
# Alinhada com o eixo do muro que separa a sala 107 do deposito. Podia ser
# qualquer X, e e' este por duas razoes: encostada num muro a grade parece
# soldada no predio, e nao largada no meio do nada; e ela fica a dez metros da
# porta do deposito, que e' onde esta' o buraco. Longe demais, o jogador nao
# liga uma coisa na outra — ele so' acha que o mapa acabou.
GRADE_X = 58.175                # onde ela cruza o corredor
GRADE_Z0, GRADE_Z1 = 52.00, 57.00
GRADE_ESP = 0.16

# --------------------------------------------------------------------------
# OS DOIS BURACOS
#
# `lado` e' a fachada em que o rombo esta', e serve pro gerador saber pra onde
# cavar o nicho de terra que aparece atras dele.
# --------------------------------------------------------------------------
BURACO_ENTRADA = {"ident": "buraco_entrada", "sala": "deposito",
                  "lado": "s", "x": 67.00, "z": PREDIO_Z1}
BURACO_SAIDA = {"ident": "buraco_saida", "sala": "almoxarifado",
                "lado": "o", "x": PREDIO_X0, "z": 62.50}


def _sala(ident, chave, tipo, x0, x1, z0, z1, **extra):
    d = {"ident": ident, "chave": chave, "tipo": tipo, "andar": 1,
         "x0": x0, "x1": x1, "z0": z0, "z1": z1}
    d.update(extra)
    return d


def _area(ident, tipo, x0, x1, z0, z1, chave=None, **extra):
    """Espaco de circulacao: corredor e o patio. Nao recebe porta propria."""
    d = {"ident": ident, "chave": chave, "tipo": tipo, "andar": 1,
         "x0": x0, "x1": x1, "z0": z0, "z1": z1, "circulacao": True}
    d.update(extra)
    return d


# --------------------------------------------------------------------------
# SALAS
#
# Faixas em Z, de norte pra sul:
#
#   0.35 .. 10.00   ala NORTE — 4 salas de aula + secretaria
#  10.35 .. 15.35   CORREDOR NORTE
#  15.70 .. 51.65   faixa do meio: PATIO (oeste) + refeitorio/biblioteca/lab
#  52.00 .. 57.00   CORREDOR SUL   <- a grade cruza aqui
#  57.35 .. 67.65   ala SUL — almoxarifado + 3 salas + deposito
#
# e o CORREDOR LESTE (x 70.65..75.65) costurando norte e sul pela direita.
# --------------------------------------------------------------------------

SALAS = [
    # --- ala norte: portas na parede sul, janelas na fachada norte
    _sala("sala_101", "ESC_SALA_101", "sala_aula", 0.35, 15.00, 0.35, 10.00),
    _sala("sala_102", "ESC_SALA_102", "sala_aula", 15.35, 30.00, 0.35, 10.00),
    _sala("sala_103", "ESC_SALA_103", "sala_aula", 30.35, 45.00, 0.35, 10.00),
    _sala("sala_104", "ESC_SALA_104", "sala_aula", 45.35, 60.00, 0.35, 10.00),
    _sala("secretaria", "ESC_SALA_SECRETARIA", "secretaria",
          60.35, 75.65, 0.35, 10.00),

    # --- faixa do meio, a leste do patio
    _sala("refeitorio", "ESC_SALA_REFEITORIO", "refeitorio",
          46.35, 70.30, 15.70, 32.00),
    _sala("biblioteca", "ESC_SALA_BIBLIOTECA", "biblioteca",
          46.35, 58.00, 32.35, 51.65),
    _sala("laboratorio", "ESC_SALA_LABORATORIO", "laboratorio",
          58.35, 70.30, 32.35, 51.65),

    # --- ala sul: portas na parede norte, janelas na fachada sul
    _sala("almoxarifado", "ESC_SALA_ALMOXARIFADO", "almoxarifado",
          0.35, 12.00, 57.35, 67.65),
    _sala("sala_105", "ESC_SALA_105", "sala_aula", 12.35, 27.00, 57.35, 67.65),
    _sala("sala_106", "ESC_SALA_106", "sala_aula", 27.35, 42.00, 57.35, 67.65),
    _sala("sala_107", "ESC_SALA_107", "sala_aula", 42.35, 58.00, 57.35, 67.65),
    _sala("deposito", "ESC_SALA_DEPOSITO", "deposito",
          58.35, 75.65, 57.35, 67.65),
]

AREAS = [
    # Os tres corredores encostam uns nos outros em X (e nao se sobrepoem):
    # e' assim que `navmesh.costuras()` costura as quinas sozinho.
    _area("corredor_norte", "corredor", 0.35, 70.65, 10.35, 15.35),
    _area("corredor_sul", "corredor", 0.35, 70.65, 52.00, 57.00),
    _area("corredor_leste", "corredor", 70.65, 75.65, 10.35, 57.00),
    # O patio e' o unico espaco DESCOBERTO da cena. Ele tem `chave` porque
    # e' o lugar que o mapa mais precisa nomear: e' onde o jogador nasce.
    _area("patio", "patio", 0.35, 46.00, 15.70, 51.65,
          chave="ESC_AREA_LAZER", descoberto=True),
]


# ==========================================================================
# OS MUROS
#
# muro(eixo, coord, a, b, vaos) — `eixo` e' a direcao em que a parede CORRE:
#
#   "x": corre em X, plano no meio em z = coord, de x=a ate' x=b
#   "z": corre em Z, plano no meio em x = coord, de z=a ate' z=b
#
# `coord` e' sempre o CENTRO da parede. Os vaos sao recortes:
# {"c": centro, "l": largura, "y0","y1", "tipo": porta|janela|passagem|buraco}.
# ==========================================================================


def muro(eixo, coord, a, b, vaos=(), tipo="interna", esp=PAREDE, alto=None):
    return {"eixo": eixo, "coord": coord, "a": a, "b": b, "vaos": list(vaos),
            "andar": 1, "tipo": tipo, "esp": esp,
            "alto": PE if alto is None else alto}


def porta(c, l=PORTA_L, sala=None, ident=None, dupla=False, trancada=False,
          saida=False, portao=False):
    """`saida`  = acionar leva PRA FORA DA ESCOLA (volta pra cidade).

    `portao` = o portao do patio. Ele e' a unica porta da escola com dois
    comportamentos diferentes conforme o lado: pelo corredor ele destranca
    (e fica destrancado); pelo patio, enquanto isso nao aconteceu, ele so'
    diz que esta' trancado por dentro.
    """
    return {"c": c, "l": PORTA_DUPLA_L if dupla else l, "y0": 0.0,
            "y1": PORTA_H, "tipo": "porta", "sala": sala, "ident": ident,
            "dupla": dupla, "trancada": trancada, "saida": saida,
            "portao": portao}


def janela(c, l=JANELA_L, y0=JANELA_Y0, y1=JANELA_Y1, quebrada=False):
    return {"c": c, "l": l, "y0": y0, "y1": y1, "tipo": "janela",
            "quebrada": quebrada}


def passagem(c, l, y1=PORTA_H + 0.45):
    return {"c": c, "l": l, "y0": 0.0, "y1": y1, "tipo": "passagem"}


def buraco(c, ident, l=BURACO_L, h=BURACO_H):
    """O rombo na parede. Vao como qualquer outro, pra parede ser recortada
    pelo mesmo caminho — o que muda e' quem o gerador poe atras dele."""
    return {"c": c, "l": l, "y0": 0.0, "y1": h, "tipo": "buraco",
            "ident": ident}


def _janelas(a, b, quantas, l=JANELA_L, y0=JANELA_Y0, y1=JANELA_Y1,
             quebradas=()):
    """Distribui `quantas` janelas iguais no trecho [a, b].

    `quebradas` e' o indice das que estao sem vidro. Fixo, e nao sorteado: a
    fachada tem de ser a mesma toda vez que o jogador voltar, senao ele perde
    a unica referencia que tinha pra se localizar de longe.
    """
    passo = (b - a) / (quantas + 1.0)
    return [janela(a + passo * (i + 1), l, y0, y1, i in quebradas)
            for i in range(quantas)]


# --------------------------------------------------------------------------
# muros
# --------------------------------------------------------------------------

def muros_da_escola():
    m = []
    Z_NORTE = 0.175
    Z_SUL = PREDIO_Z1 - 0.175
    X_OESTE = 0.175
    X_LESTE = PREDIO_X1 - 0.175

    # ================= fachadas =================

    # norte: as janelas das quatro salas de aula e da secretaria
    m.append(muro("x", Z_NORTE, 0.0, PREDIO_X1, tipo="externa", alto=PATIO_MURO_ALTO, vaos=(
        _janelas(0.35, 15.00, 3, quebradas=(1,))
        + _janelas(15.35, 30.00, 3)
        + _janelas(30.35, 45.00, 3, quebradas=(0, 2))
        + _janelas(45.35, 60.00, 3)
        + _janelas(60.35, 75.65, 3, quebradas=(2,)))))

    # sul: as janelas da ala sul. O BURACO DE ENTRADA fica aqui, no fundo do
    # deposito — e' o canto sudeste do desenho.
    m.append(muro("x", Z_SUL, 0.0, PREDIO_X1, tipo="externa", alto=PATIO_MURO_ALTO, vaos=(
        _janelas(0.35, 12.00, 2)
        + _janelas(12.35, 27.00, 3, quebradas=(0,))
        + _janelas(27.35, 42.00, 3)
        + _janelas(42.35, 58.00, 3, quebradas=(1, 2))
        + [janela(62.00, 2.2, quebrada=True),
           buraco(BURACO_ENTRADA["x"], "buraco_entrada"),
           janela(72.50, 2.2, quebrada=True)])))

    # oeste: e' a frente da escola pra rua. Ela da' pro PATIO na maior parte,
    # e e' onde esta' o portao da rua — a unica porta que troca de cena.
    m.append(muro("z", X_OESTE, 0.0, PREDIO_Z1, tipo="externa", alto=PATIO_MURO_ALTO, vaos=[
        janela(3.60, 2.2), janela(7.60, 2.2),               # sala 101
        janela(12.85, 2.4),                                  # corredor norte
        # O portao da rua: chapa de ferro no muro do patio.
        porta(33.00, sala="patio", ident="portao_rua", dupla=True, saida=True),
        janela(24.00, 2.0, 1.60, 2.90), janela(43.00, 2.0, 1.60, 2.90),
        janela(54.50, 2.4),                                  # corredor sul
        # O BURACO DE SAIDA, no fundo do almoxarifado (canto sudoeste).
        buraco(BURACO_SAIDA["z"], "buraco_saida"),
        janela(66.00, 2.0, quebrada=True),
    ]))

    # leste: o corredor leste inteiro, com janela alta
    m.append(muro("z", X_LESTE, 0.0, PREDIO_Z1, tipo="externa", alto=PATIO_MURO_ALTO, vaos=[
        janela(4.50, 2.2), janela(8.00, 2.2),                # secretaria
        janela(20.00, 2.8, 1.30, 3.05),
        janela(28.00, 2.8, 1.30, 3.05, quebrada=True),
        janela(36.00, 2.8, 1.30, 3.05),
        janela(44.00, 2.8, 1.30, 3.05),
        janela(52.00, 2.8, 1.30, 3.05, quebrada=True),
        janela(62.00, 2.4), janela(66.00, 2.4),              # deposito
    ]))

    # ================= ala norte / corredor norte =================

    m.append(muro("x", 10.175, 0.0, PREDIO_X1, vaos=[
        porta(7.00, sala="sala_101", ident="p_101"),
        porta(22.00, sala="sala_102", ident="p_102"),
        porta(37.00, sala="sala_103", ident="p_103"),
        porta(52.00, sala="sala_104", ident="p_104"),
        porta(68.00, sala="secretaria", ident="p_secretaria", dupla=True),
    ]))
    for x in (15.175, 30.175, 45.175, 60.175):
        m.append(muro("z", x, 0.0, 10.35))

    # ================= corredor norte / faixa do meio =================
    #
    # O mesmo plano (z = 15,525) e' a parede norte do PATIO a oeste e a do
    # REFEITORIO a leste — mas sao dois muros e nao um, porque a do patio sobe
    # alem do pe-direito: ela e' fachada interna, vista de um lugar sem teto.
    # Cortada no pe-direito, o ceu apareceria por baixo do predio.
    m.append(muro("x", 15.525, 0.0, 46.175, alto=PATIO_MURO_ALTO, vaos=[
        porta(20.00, sala="patio", ident="porta_principal", dupla=True),
    ]))
    m.append(muro("x", 15.525, 46.175, 70.65, vaos=[
        porta(58.00, sala="refeitorio", ident="p_refeitorio", dupla=True),
    ]))

    # ================= o patio =================
    #
    # Parede leste (contra refeitorio e biblioteca). Sem vao nenhum: o patio
    # so' tem tres ligacoes — o portao da rua, a porta principal e o portao
    # trancado do corredor sul — e nenhuma delas e' por aqui.
    m.append(muro("z", 46.175, 15.35, 52.00, alto=PATIO_MURO_ALTO))
    # Parede sul (contra o corredor sul). Aqui esta' o PORTAO que so'
    # destranca por dentro: e' ele que fecha o atalho ate' o jogador voltar
    # do porao.
    m.append(muro("x", 51.825, 0.0, 46.175, alto=PATIO_MURO_ALTO, vaos=[
        porta(20.00, sala="patio", ident="portao_lazer", dupla=True,
              portao=True),
    ]))

    # ================= refeitorio, biblioteca, laboratorio =================

    # refeitorio / biblioteca+laboratorio
    #
    # SEM VAO, e isso e' regra de jogo e nao acaso: a biblioteca abre no
    # corredor sul, do lado de LA' da grade. Uma porta aqui ligaria o
    # refeitorio (lado de ca') ao corredor sul (lado de la') por dentro, e o
    # jogador contornaria a grade sem nunca entrar no porao.
    m.append(muro("x", 32.175, 46.175, 70.65))
    # biblioteca / laboratorio
    m.append(muro("z", 58.175, 32.00, 52.00))
    # a parede que separa a faixa do meio do CORREDOR LESTE
    m.append(muro("z", 70.475, 15.35, 52.00, vaos=[
        porta(24.00, sala="refeitorio", ident="p_refeitorio_leste"),
        porta(42.00, sala="laboratorio", ident="p_laboratorio"),
    ]))
    # biblioteca -> corredor sul
    m.append(muro("x", 51.825, 46.175, 70.65, vaos=[
        porta(52.00, sala="biblioteca", ident="p_biblioteca_sul"),
    ]))

    # ================= corredor sul / ala sul =================

    m.append(muro("x", 57.175, 0.0, PREDIO_X1, vaos=[
        porta(6.00, sala="almoxarifado", ident="p_almoxarifado"),
        porta(19.00, sala="sala_105", ident="p_105"),
        porta(31.00, sala="sala_106", ident="p_106"),
        porta(50.00, sala="sala_107", ident="p_107"),
        porta(67.00, sala="deposito", ident="p_deposito", dupla=True),
    ]))
    for x in (12.175, 27.175, 42.175, 58.175):
        m.append(muro("z", x, 57.00, PREDIO_Z1))

    return m


# ==========================================================================
# ATALHOS — mesma interface do hospital, pra `navmesh.py` e `make_mapa`
# servirem sem adaptacao
# ==========================================================================

def salas(andar=None):
    return list(SALAS)


def areas(andar=None):
    return list(AREAS)


def espacos(andar=None):
    return salas() + areas()


def muros(andar=None):
    return muros_da_escola()


def cota(andar=1):
    return ANDAR_1


def por_ident(ident):
    for e in espacos():
        if e["ident"] == ident:
            return e
    return None


def centro(e):
    return ((e["x0"] + e["x1"]) * 0.5, (e["z0"] + e["z1"]) * 0.5)


def vao_por_ident(ident):
    """(muro, vao) do vao com este ident, ou (None, None)."""
    for m in muros():
        for v in m["vaos"]:
            if v.get("ident") == ident:
                return m, v
    return None, None


def ponto_do_vao(ident, recuo=1.20):
    """Ponto no chao a `recuo` metros de um vao, do lado de DENTRO do predio.

    Serve pro spawn e pros pontos do mapa. "Dentro" aqui e' o lado em que
    existe algum espaco da planta — quem decide e' a propria lista de salas,
    nao um sinal digitado.
    """
    m, v = vao_por_ident(ident)
    if m is None:
        return None
    for lado in (1.0, -1.0):
        if m["eixo"] == "x":
            x, z = v["c"], m["coord"] + lado * recuo
        else:
            x, z = m["coord"] + lado * recuo, v["c"]
        if espaco_em(x, z):
            return (x, z)
    return None


def espaco_em(x, z):
    for e in espacos():
        if e["x0"] - 0.01 <= x <= e["x1"] + 0.01 and \
                e["z0"] - 0.01 <= z <= e["z1"] + 0.01:
            return e
    return None
