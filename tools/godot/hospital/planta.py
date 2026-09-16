"""A planta do hospital: os dois andares desenhados no caderno, em numeros.

Este modulo NAO escreve nada. Ele so' descreve o predio — onde cada sala
comeca e acaba, onde tem porta, onde tem janela — e o gerador
(`gerar_cena_hospital.py`) transforma isso em geometria, luz e navmesh.

==============================================================================
O SISTEMA DE COORDENADAS

    X = largura   (esquerda -> direita, como no papel)
    Y = ALTURA
    Z = profundidade (topo do papel -> base do papel)

Os dois mapas do caderno estao desenhados de pe, com a legenda virada de lado.
Lidos na vertical, o mapa do PRIMEIRO ANDAR tem a ENTRADA na borda esquerda
(oeste) e o ELEVADOR saindo da borda direita (leste), e o do SEGUNDO ANDAR tem
o elevador no MESMO lugar — o poco e' um so' e atravessa os dois andares.

==============================================================================
POR QUE TUDO E' DESCRITO COMO "INTERIOR DE SALA" + "MURO"

A tentacao e' descrever cada sala como um retangulo e deixar o gerador criar as
quatro paredes dela. Isso da' parede dupla em todo lugar onde duas salas se
encostam — e parede dupla e' z-fighting garantido.

Entao aqui cada sala guarda so' o seu VAO INTERNO (o chao que da' pra pisar), e
as paredes sao uma lista PROPRIA de muros, cada um com os vaos (porta, janela,
passagem) recortados nele. Um muro entre duas salas e' escrito uma vez so'.

==============================================================================
AS MEDIDAS, E POR QUE SAO GRANDES

A casa do Jimmy tem pe-direito de 3,1 m e porta de 1,5 m. Funciona, mas fica
apertado: a capsula do jogador tem 1,35 m de diametro (raio 0,674) e a camera
e' de terceira pessoa, entao ele precisa de MUITO mais folga do que parece no
papel. Aqui:

    corredor  5,00 m     (cabem tres pessoas de frente, ou uma maca girando)
    porta     2,20 m     (porta dupla de hospital, macas passam)
    pe-direito 3,60 m    (camera nao encosta no teto em corredor nenhum)
    quarto    ~10 x 10 m (o menor quarto tem 9,6 m de lado)

E' de proposito que quase nao existe sala pequena: o pedido foi "quartos
grandes", e num predio de terror o espaco vazio vale mais do que o espaco
cheio.
"""

# ==========================================================================
# MEDIDAS BASE
# ==========================================================================

PAREDE = 0.35          # espessura de todo muro interno e externo
PE = 3.60              # pe-direito de cada andar
LAJE = 0.60            # espessura da laje entre o 1o e o 2o andar

ANDAR_1 = 0.0          # cota do piso do terreo
ANDAR_2 = PE + LAJE    # 4.20 — cota do piso do segundo andar

PORTA_L = 2.20         # vao de porta comum
PORTA_H = 2.60         # altura de qualquer vao de porta
PORTA_DUPLA_L = 2.80   # vao das portas de duas folhas (entrada, cirurgia)

JANELA_Y0 = 1.10       # peitoril
JANELA_Y1 = 2.85
JANELA_L = 2.40

# ==========================================================================
# O PREDIO
# ==========================================================================

# Terreo: 56 x 68 m. Segundo andar: 56 x 64,4 m — ele e' MENOR de proposito,
# como no desenho (o mapa do 2o andar tem aquele recorte em "[").
PREDIO_X0, PREDIO_X1 = 0.0, 56.0
A1_Z0, A1_Z1 = 0.0, 68.0
A2_Z0, A2_Z1 = 0.0, 64.40

# O poco do elevador fica FORA do volume, encostado na fachada leste — e' assim
# que ele esta desenhado nos dois mapas (uma caixinha saindo da borda direita).
POCO_X0, POCO_X1 = 56.0, 62.0
POCO_Z0, POCO_Z1 = 28.60, 34.60
POCO_PORTA_C = 31.60          # centro do vao, igual nos dois andares
POCO_PORTA_L = 2.20
CABINE_X0, CABINE_X1 = POCO_X0 + PAREDE, POCO_X1 - PAREDE
CABINE_Z0, CABINE_Z1 = POCO_Z0 + PAREDE, POCO_Z1 - PAREDE


def _sala(ident, chave, tipo, x0, x1, z0, z1, andar, **extra):
    d = {"ident": ident, "chave": chave, "tipo": tipo, "andar": andar,
         "x0": x0, "x1": x1, "z0": z0, "z1": z1}
    d.update(extra)
    return d


def _area(ident, tipo, x0, x1, z0, z1, andar, **extra):
    """Espaco de circulacao: corredor, hall, saguao. Nao tem porta."""
    d = {"ident": ident, "chave": None, "tipo": tipo, "andar": andar,
         "x0": x0, "x1": x1, "z0": z0, "z1": z1, "circulacao": True}
    d.update(extra)
    return d


# --------------------------------------------------------------------------
# PRIMEIRO ANDAR
#
# Faixas em Z, de cima pra baixo no papel:
#
#   0.35 .. 10.00   ala A — 5 quartos/salas, portas pro corredor norte
#  10.35 .. 15.35   CORREDOR NORTE
#  15.70 .. 25.35   ala B — cirurgia, UTI, quartos + a passagem pro hall
#  25.70 .. 42.65   HALL PRINCIPAL (oeste) + pronto-socorro (leste)
#  43.00 .. 52.65   ala C — refeitorio, necroterio, quartos
#  53.00 .. 58.00   CORREDOR SUL
#  58.35 .. 67.65   ala D — farmacia, esterilizacao, casa de maquinas
#
# e o CORREDOR LESTE (x 50.65..55.65) costurando norte e sul pela direita,
# que e' onde o elevador abre.
# --------------------------------------------------------------------------

ANDAR1_SALAS = [
    # --- ala A (norte) — portas na parede sul, janelas na fachada norte
    _sala("quarto_101", "HOSP_SALA_101", "quarto", 0.35, 11.00, 0.35, 10.00, 1),
    _sala("quarto_102", "HOSP_SALA_102", "quarto", 11.35, 22.00, 0.35, 10.00, 1),
    _sala("quarto_103", "HOSP_SALA_103", "quarto", 22.35, 33.00, 0.35, 10.00, 1),
    _sala("radiologia", "HOSP_SALA_RAIOX", "exame", 33.35, 44.00, 0.35, 10.00, 1),
    _sala("laboratorio", "HOSP_SALA_LAB", "laboratorio", 44.35, 55.65, 0.35, 10.00, 1),

    # --- ala B — portas na parede norte
    _sala("quarto_104", "HOSP_SALA_104", "quarto", 0.35, 10.00, 15.70, 25.35, 1),
    _sala("quarto_105", "HOSP_SALA_105", "quarto", 10.35, 20.00, 15.70, 25.35, 1),
    _sala("centro_cirurgico", "HOSP_SALA_CIRURGIA", "cirurgia", 25.35, 35.00, 15.70, 25.35, 1),
    _sala("uti", "HOSP_SALA_UTI", "uti", 35.35, 50.30, 15.70, 25.35, 1),

    # --- faixa do hall — o pronto-socorro divide a faixa com o hall
    _sala("pronto_socorro", "HOSP_SALA_PS", "emergencia", 30.35, 50.30, 25.70, 35.65, 1),

    # --- ala C — portas na parede sul
    _sala("quarto_106", "HOSP_SALA_106", "quarto", 0.35, 10.00, 43.00, 52.65, 1),
    _sala("quarto_107", "HOSP_SALA_107", "quarto", 10.35, 20.00, 43.00, 52.65, 1),
    _sala("refeitorio", "HOSP_SALA_REFEITORIO", "refeitorio", 25.35, 36.00, 43.00, 52.65, 1),
    _sala("necroterio", "HOSP_SALA_NECROTERIO", "necroterio", 36.35, 50.30, 43.00, 52.65, 1),

    # --- ala D (sul) — portas na parede norte, janelas na fachada sul
    _sala("quarto_108", "HOSP_SALA_108", "quarto", 0.35, 11.00, 58.35, 67.65, 1),
    _sala("quarto_109", "HOSP_SALA_109", "quarto", 11.35, 22.00, 58.35, 67.65, 1),
    _sala("farmacia", "HOSP_SALA_FARMACIA", "farmacia", 22.35, 33.00, 58.35, 67.65, 1),
    _sala("esterilizacao", "HOSP_SALA_ESTERIL", "esterilizacao", 33.35, 44.00, 58.35, 67.65, 1),
    _sala("casa_maquinas", "HOSP_SALA_MAQUINAS", "maquinas", 44.35, 55.65, 58.35, 67.65, 1),
]

ANDAR1_AREAS = [
    _area("corredor_norte", "corredor", 0.35, 50.65, 10.35, 15.35, 1),
    _area("corredor_sul", "corredor", 0.35, 50.65, 53.00, 58.00, 1),
    _area("corredor_leste", "corredor", 50.65, 55.65, 10.35, 58.00, 1),
    _area("corredor_central", "corredor", 30.35, 50.65, 36.00, 42.65, 1),
    _area("passagem_norte", "corredor", 20.35, 25.00, 15.70, 25.35, 1),
    _area("passagem_sul", "corredor", 20.35, 25.00, 43.00, 52.65, 1),
    _area("hall_principal", "hall", 0.35, 30.00, 25.70, 42.65, 1),
]

# --------------------------------------------------------------------------
# SEGUNDO ANDAR
#
#   0.35 .. 12.05   arquivo medico (oeste) + SAGUAO NORTE aberto (leste)
#  12.40 .. 18.00   CORREDOR NORTE
#  18.35 .. 28.00   ala M1 — tres quartos, portas ao sul
#  28.35 .. 33.60   CORREDOR CENTRAL  <- e' aqui que o elevador abre
#  33.95 .. 43.60   ala M2 — psiquiatria e terapia, portas ao norte
#  43.95 .. 53.65   SAGUAO SUL aberto
#  54.00 .. 64.05   ala B — quatro salas, portas ao norte
#
# O saguao norte e o corredor norte sao UM espaco so' a leste do arquivo: e'
# aquele vazio grande do desenho, e e' o unico lugar do predio de onde se ve
# o andar inteiro de uma vez.
# --------------------------------------------------------------------------

ANDAR2_SALAS = [
    _sala("arquivo_medico", "HOSP_SALA_ARQUIVO", "arquivo", 0.35, 16.00, 0.35, 12.05, 2),

    _sala("quarto_201", "HOSP_SALA_201", "quarto", 0.35, 12.80, 18.35, 28.00, 2),
    _sala("quarto_202", "HOSP_SALA_202", "quarto", 13.15, 25.60, 18.35, 28.00, 2),
    _sala("quarto_203", "HOSP_SALA_203", "quarto", 25.95, 38.00, 18.35, 28.00, 2),

    _sala("psiquiatria", "HOSP_SALA_PSIQ", "psiquiatria", 0.35, 16.00, 33.95, 43.60, 2),
    _sala("terapia", "HOSP_SALA_TERAPIA", "terapia", 16.35, 32.00, 33.95, 43.60, 2),

    _sala("quarto_204", "HOSP_SALA_204", "quarto", 0.35, 11.00, 54.00, 64.05, 2),
    _sala("quarto_205", "HOSP_SALA_205", "quarto", 11.35, 22.00, 54.00, 64.05, 2),
    _sala("centro_cirurgico_2", "HOSP_SALA_CIRURGIA2", "cirurgia", 22.35, 33.00, 54.00, 64.05, 2),
    _sala("observacao", "HOSP_SALA_OBSERVACAO", "observacao", 33.35, 44.00, 54.00, 64.05, 2),
]

ANDAR2_AREAS = [
    _area("saguao_norte", "saguao", 16.35, 55.65, 0.35, 12.40, 2),
    _area("corredor2_norte", "corredor", 0.35, 55.65, 12.40, 18.00, 2),
    _area("corredor2_central", "corredor", 0.35, 55.65, 28.35, 33.60, 2),
    _area("saguao_sul", "saguao", 0.35, 55.65, 43.95, 53.65, 2),
    # os tres pedacos abertos a leste das alas: e' o que faz a "galeria" do
    # lado direito do mapa 2 ser continua de cima a baixo
    _area("galeria_m1", "saguao", 38.35, 55.65, 18.00, 28.35, 2),
    _area("galeria_m2", "saguao", 32.35, 55.65, 33.60, 43.95, 2),
    _area("galeria_sul", "saguao", 44.35, 55.65, 53.65, 64.05, 2),
]


# ==========================================================================
# OS MUROS
#
# muro(eixo, coord, a, b, vaos) — `eixo` e' a direcao em que a parede CORRE:
#
#   "x": corre em X, plano no meio em z = coord, de x=a ate' x=b
#   "z": corre em Z, plano no meio em x = coord, de z=a ate' z=b
#
# `coord` e' sempre o CENTRO da parede, e ela nasce com PAREDE de espessura
# (0,175 pra cada lado). Os vaos sao recortes: {"c": centro, "l": largura,
# "y0","y1": faixa de altura, "tipo": porta|janela|passagem}.
# ==========================================================================


def muro(eixo, coord, a, b, vaos=(), andar=1, tipo="interna", esp=PAREDE):
    return {"eixo": eixo, "coord": coord, "a": a, "b": b, "vaos": list(vaos),
            "andar": andar, "tipo": tipo, "esp": esp}


def porta(c, l=PORTA_L, sala=None, ident=None, dupla=False, trancada=False):
    return {"c": c, "l": PORTA_DUPLA_L if dupla else l, "y0": 0.0, "y1": PORTA_H,
            "tipo": "porta", "sala": sala, "ident": ident, "dupla": dupla,
            "trancada": trancada}


def janela(c, l=JANELA_L, y0=JANELA_Y0, y1=JANELA_Y1):
    return {"c": c, "l": l, "y0": y0, "y1": y1, "tipo": "janela"}


def passagem(c, l, y1=PORTA_H + 0.45):
    return {"c": c, "l": l, "y0": 0.0, "y1": y1, "tipo": "passagem"}


def _janelas(a, b, quantas, l=JANELA_L, y0=JANELA_Y0, y1=JANELA_Y1):
    """Distribui `quantas` janelas iguais no trecho [a, b]."""
    passo = (b - a) / (quantas + 1.0)
    return [janela(a + passo * (i + 1), l, y0, y1) for i in range(quantas)]


# --------------------------------------------------------------------------
# muros do PRIMEIRO ANDAR
# --------------------------------------------------------------------------

def muros_andar_1():
    m = []
    Z_NORTE = 0.175
    Z_SUL = A1_Z1 - 0.175
    X_OESTE = 0.175
    X_LESTE = PREDIO_X1 - 0.175

    # ---- fachadas
    # norte: janelas dos quartos 101-103 e das salas de exame
    m.append(muro("x", Z_NORTE, 0.0, PREDIO_X1, tipo="externa", vaos=(
        _janelas(0.35, 11.00, 2) + _janelas(11.35, 22.00, 2)
        + _janelas(22.35, 33.00, 2) + _janelas(33.35, 44.00, 1)
        + _janelas(44.35, 55.65, 2))))
    # sul
    m.append(muro("x", Z_SUL, 0.0, PREDIO_X1, tipo="externa", vaos=(
        _janelas(0.35, 11.00, 2) + _janelas(11.35, 22.00, 2)
        + _janelas(22.35, 33.00, 1) + _janelas(33.35, 44.00, 1))))
    # oeste: a ENTRADA do hospital, porta dupla, mais os janelao do hall
    m.append(muro("z", X_OESTE, 0.0, A1_Z1, tipo="externa", vaos=[
        janela(5.2, 2.0), janela(12.85, 2.4),
        janela(20.5, 2.0),
        # o janelao do hall: vai quase do chao ao teto, dos dois lados da porta
        janela(28.5, 3.2, 0.9, 3.05), janela(40.0, 3.2, 0.9, 3.05),
        # A porta da rua fica TRANCADA. O hospital ainda nao esta ligado ao
        # mapa da cidade, e uma porta que abrisse daqui jogaria o jogador num
        # lugar sem chao. Trancada, ela tambem diz a coisa certa: quem entrou
        # nao sai por onde entrou.
        porta(34.20, sala="hall_principal", ident="entrada_principal",
              dupla=True, trancada=True),
        janela(47.8, 2.4), janela(62.9, 2.0),
    ]))
    # leste: o vao do elevador mais janelas altas no corredor leste
    m.append(muro("z", X_LESTE, 0.0, A1_Z1, tipo="externa", vaos=[
        janela(5.2, 2.0),
        janela(18.0, 2.0), janela(24.0, 2.0),
        passagem(POCO_PORTA_C, POCO_PORTA_L, PORTA_H),
        janela(40.0, 2.0), janela(48.0, 2.0),
        janela(63.0, 2.0),
    ]))

    # ---- ala A / corredor norte (portas na parede sul da ala A)
    m.append(muro("x", 10.175, 0.0, PREDIO_X1, vaos=[
        porta(5.60, sala="quarto_101", ident="p_101"),
        porta(16.60, sala="quarto_102", ident="p_102"),
        porta(27.60, sala="quarto_103", ident="p_103"),
        porta(38.60, sala="radiologia", ident="p_raiox"),
        porta(50.00, sala="laboratorio", ident="p_lab"),
    ]))
    # divisorias da ala A
    for x in (11.175, 22.175, 33.175, 44.175):
        m.append(muro("z", x, 0.0, 10.35))

    # ---- corredor norte / ala B (portas na parede norte da ala B)
    m.append(muro("x", 15.525, 0.0, PREDIO_X1, vaos=[
        porta(5.20, sala="quarto_104", ident="p_104"),
        porta(15.20, sala="quarto_105", ident="p_105"),
        passagem(22.675, 4.65),
        porta(30.20, sala="centro_cirurgico", ident="p_cirurgia", dupla=True),
        porta(42.80, sala="uti", ident="p_uti", dupla=True),
    ]))
    # divisorias da ala B
    for x in (10.175, 20.175, 25.175, 35.175, 50.475):
        m.append(muro("z", x, 15.35, 25.70))

    # ---- ala B / faixa do hall
    m.append(muro("x", 25.525, 0.0, 50.65, vaos=[passagem(22.675, 4.65)]))

    # ---- hall x pronto-socorro (a parede que separa o hall da ala leste)
    m.append(muro("z", 30.175, 25.35, 43.00, vaos=[
        passagem(39.325, 6.65, PE - 0.35),
    ]))
    # pronto-socorro: porta dupla pro corredor central e porta pro leste
    m.append(muro("x", 35.825, 30.00, 50.65, vaos=[
        porta(40.30, sala="pronto_socorro", ident="p_ps", dupla=True),
    ]))
    m.append(muro("z", 50.475, 25.35, 36.00, vaos=[
        porta(30.60, sala="pronto_socorro", ident="p_ps_leste"),
    ]))

    # ---- faixa do hall / ala C
    m.append(muro("x", 42.825, 0.0, 50.65, vaos=[passagem(22.675, 4.65)]))
    # divisorias da ala C
    for x in (10.175, 20.175, 25.175, 36.175, 50.475):
        m.append(muro("z", x, 42.65, 53.00))

    # ---- ala C / corredor sul (portas na parede sul da ala C)
    m.append(muro("x", 52.825, 0.0, PREDIO_X1, vaos=[
        porta(5.20, sala="quarto_106", ident="p_106"),
        porta(15.20, sala="quarto_107", ident="p_107"),
        porta(30.60, sala="refeitorio", ident="p_refeitorio", dupla=True),
        porta(43.30, sala="necroterio", ident="p_necroterio", dupla=True),
    ]))

    # ---- corredor sul / ala D (portas na parede norte da ala D)
    m.append(muro("x", 58.175, 0.0, PREDIO_X1, vaos=[
        porta(5.60, sala="quarto_108", ident="p_108"),
        porta(16.60, sala="quarto_109", ident="p_109"),
        porta(27.60, sala="farmacia", ident="p_farmacia"),
        porta(38.60, sala="esterilizacao", ident="p_esteril"),
        porta(50.00, sala="casa_maquinas", ident="p_maquinas"),
    ]))
    # divisorias da ala D
    for x in (11.175, 22.175, 33.175, 44.175):
        m.append(muro("z", x, 58.00, A1_Z1))

    # ---- corredor leste: a parede que o separa das alas B e C ja' foi feita
    # (x=50.475). Falta so' fechar o trecho do refeitorio/necroterio, que e'
    # o mesmo muro — ja' emitido acima.

    return m


# --------------------------------------------------------------------------
# muros do SEGUNDO ANDAR
# --------------------------------------------------------------------------

def muros_andar_2():
    m = []
    Z_NORTE = 0.175
    Z_SUL = A2_Z1 - 0.175
    X_OESTE = 0.175
    X_LESTE = PREDIO_X1 - 0.175

    # ---- fachadas
    m.append(muro("x", Z_NORTE, 0.0, PREDIO_X1, andar=2, tipo="externa", vaos=(
        _janelas(0.35, 16.00, 2) + _janelas(16.35, 55.65, 5, 2.8, 1.0, 3.05))))
    m.append(muro("x", Z_SUL, 0.0, PREDIO_X1, andar=2, tipo="externa", vaos=(
        _janelas(0.35, 11.00, 2) + _janelas(11.35, 22.00, 2)
        + _janelas(22.35, 33.00, 1) + _janelas(33.35, 44.00, 2)
        + _janelas(44.35, 55.65, 2))))
    m.append(muro("z", X_OESTE, 0.0, A2_Z1, andar=2, tipo="externa", vaos=[
        janela(6.0, 2.4), janela(15.2, 2.4),
        janela(23.0, 2.4), janela(38.5, 2.4),
        janela(48.8, 3.0, 1.0, 3.05), janela(59.0, 2.4),
    ]))
    m.append(muro("z", X_LESTE, 0.0, A2_Z1, andar=2, tipo="externa", vaos=[
        janela(6.0, 2.8, 1.0, 3.05), janela(15.2, 2.8, 1.0, 3.05),
        janela(23.0, 2.4),
        passagem(POCO_PORTA_C, POCO_PORTA_L, PORTA_H),
        janela(39.0, 2.4), janela(48.8, 2.8, 1.0, 3.05), janela(59.0, 2.4),
    ]))

    # ---- arquivo medico: parede leste (contra o saguao) e parede sul
    m.append(muro("z", 16.175, 0.0, 12.40, andar=2, vaos=[
        porta(6.20, sala="arquivo_medico", ident="p_arquivo"),
    ]))
    m.append(muro("x", 12.225, 0.0, 16.35, andar=2))

    # ---- corredor norte / ala M1 (portas na parede sul da M1)
    m.append(muro("x", 18.175, 0.0, 38.35, andar=2))
    for x in (12.975, 25.775, 38.175):
        m.append(muro("z", x, 18.00, 28.35, andar=2))
    m.append(muro("x", 28.175, 0.0, 38.35, andar=2, vaos=[
        porta(6.50, sala="quarto_201", ident="p_201"),
        porta(19.30, sala="quarto_202", ident="p_202"),
        porta(31.90, sala="quarto_203", ident="p_203"),
    ]))

    # ---- corredor central / ala M2 (portas na parede norte da M2)
    m.append(muro("x", 33.775, 0.0, 32.35, andar=2, vaos=[
        porta(8.20, sala="psiquiatria", ident="p_psiq", dupla=True),
        porta(24.20, sala="terapia", ident="p_terapia"),
    ]))
    for x in (16.175, 32.175):
        m.append(muro("z", x, 33.60, 43.95, andar=2))
    m.append(muro("x", 43.775, 0.0, 32.35, andar=2))

    # ---- saguao sul / ala B (portas na parede norte da ala B)
    m.append(muro("x", 53.825, 0.0, 44.35, andar=2, vaos=[
        porta(5.60, sala="quarto_204", ident="p_204"),
        porta(16.60, sala="quarto_205", ident="p_205"),
        porta(27.60, sala="centro_cirurgico_2", ident="p_cirurgia2", dupla=True),
        porta(38.60, sala="observacao", ident="p_observacao"),
    ]))
    for x in (11.175, 22.175, 33.175, 44.175):
        m.append(muro("z", x, 53.65, A2_Z1, andar=2))

    return m


# ==========================================================================
# ATALHOS
# ==========================================================================

def salas(andar=None):
    todas = ANDAR1_SALAS + ANDAR2_SALAS
    return [s for s in todas if andar is None or s["andar"] == andar]


def areas(andar=None):
    todas = ANDAR1_AREAS + ANDAR2_AREAS
    return [a for a in todas if andar is None or a["andar"] == andar]


def espacos(andar=None):
    return salas(andar) + areas(andar)


def muros(andar=None):
    todos = muros_andar_1() + muros_andar_2()
    return [m for m in todos if andar is None or m["andar"] == andar]


def cota(andar):
    return ANDAR_1 if andar == 1 else ANDAR_2


def por_ident(ident):
    for e in espacos():
        if e["ident"] == ident:
            return e
    return None


def centro(e):
    return ((e["x0"] + e["x1"]) * 0.5, (e["z0"] + e["z1"]) * 0.5)
