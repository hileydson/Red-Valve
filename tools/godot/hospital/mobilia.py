"""A mobilia do hospital: o que tem dentro de cada sala e onde.

==============================================================================
DUAS ESPECIES DE MOVEL

1. CAIXARIA (`caixas`) — cama, balcao, mesa cirurgica, gaveta de necroterio.
   Sao montados aqui, em caixas, e o gerador cospe uma BoxMesh por peca.
   Movel de hospital e' quase todo ortogonal, entao caixa resolve, e resolver
   em caixa da' controle total: da' pra encostar a cabeceira na parede com
   precisao de centimetro, que e' o que faz o quarto parecer quarto.

2. MODELO (`modelo`) — os .gltf do Poly Haven. Entram onde caixa nao convence:
   cadeira, cadeira de rodas, muleta, microscopio, gerador.

==============================================================================
A REGRA DE OURO: NADA NO MEIO DO CAMINHO

O pedido foi explicito — "nao deixe obstaculos no meio dos caminhos". Entao
TODO movel nasce encostado numa parede, com `recuo` medido a partir dela, e o
miolo de cada comodo fica vazio. As tres excecoes sao de proposito e ficam em
sala grande: a mesa cirurgica (no centro da cirurgia, que e' onde ela vive), o
balcao redondo do hall (que e' o circulo desenhado no mapa) e as mesas do
refeitorio.

Quem avanca pro meio declara `bloqueia`, e o navmesh fura a grade ali — assim o
inimigo desvia da cama em vez de atravessar.

==============================================================================
COMO O MOVEL SABE PRA QUE LADO OLHAR

`parede` e' "n", "s", "l" ou "o". Dai sai o giro: o movel sempre nasce olhando
PRA DENTRO do comodo, de costas pra parede. Um modelo do Poly Haven ainda pode
chegar virado do jeito dele — por isso existe `giro_extra` na tabela MODELOS,
afinado modelo a modelo.
"""

import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import planta as P

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
DIR_MODELOS = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "polyhaven")

# Giro de cada parede pra que o movel fique de costas pra ela. O eixo "pra
# frente" do movel montado aqui e' o +Z local.
GIRO_PAREDE = {"n": 0.0, "s": math.pi, "l": -math.pi * 0.5, "o": math.pi * 0.5}


# ==========================================================================
# CATALOGO DE MODELOS
#
# `giro_extra` corrige a pose de fabrica do .gltf (cada autor modelou olhando
# pra um lado). `y` e' o quanto subir/descer: quase todos ja' vem com a base em
# 0, os que nao vem levam um empurrao.
# ==========================================================================

MODELOS = {
    "wheelchair_01": {"escala": 1.0, "giro_extra": math.pi},
    "vintage_crutches_01": {"escala": 1.0, "giro_extra": 0.0},
    "medical_box": {"escala": 1.0, "giro_extra": 0.0},
    "metal_office_desk": {"escala": 1.0, "giro_extra": math.pi},
    "metal_stool_01": {"escala": 1.0, "giro_extra": 0.0},
    "drawer_cabinet": {"escala": 1.0, "giro_extra": 0.0},
    "steel_frame_shelves_02": {"escala": 1.0, "giro_extra": 0.0},
    "worn_metal_rack": {"escala": 1.0, "giro_extra": 0.0},
    "korean_fire_extinguisher_01": {"escala": 1.0, "giro_extra": 0.0},
    "fire_alarm": {"escala": 1.0, "giro_extra": 0.0},
    "WetFloorSign_01": {"escala": 1.0, "giro_extra": 0.0},
    "industrial_storage_cart": {"escala": 1.0, "giro_extra": 0.0},
    "tool_cart": {"escala": 1.0, "giro_extra": 0.0},
    "plastic_monobloc_chair_01": {"escala": 1.0, "giro_extra": 0.0},
    "SchoolChair_01": {"escala": 1.0, "giro_extra": 0.0},
    "security_camera_01": {"escala": 1.0, "giro_extra": 0.0},
    "industrial_microscope": {"escala": 1.0, "giro_extra": 0.0},
    "chemistry_set": {"escala": 1.0, "giro_extra": 0.0},
    "bunsen_burner": {"escala": 1.0, "giro_extra": 0.0},
    "power_box_01": {"escala": 1.0, "giro_extra": 0.0},
    "utility_box_01": {"escala": 1.0, "giro_extra": 0.0},
    "modular_pipes": {"escala": 1.0, "giro_extra": 0.0},
    "modular_airduct_rectangular_01": {"escala": 1.0, "giro_extra": 0.0},
    "portable_generator": {"escala": 1.0, "giro_extra": 0.0},
    "plastic_crate_01": {"escala": 1.0, "giro_extra": 0.0},
    "plastic_crate_02": {"escala": 1.0, "giro_extra": 0.0},
    "industrial_pastic_container": {"escala": 1.0, "giro_extra": 0.0},
    "trashbag": {"escala": 1.0, "giro_extra": 0.0},
    "clipboard": {"escala": 1.0, "giro_extra": 0.0},
    "office_notepads": {"escala": 1.0, "giro_extra": 0.0},
    "stationery_supplies": {"escala": 1.0, "giro_extra": 0.0},
    "binder_notebook": {"escala": 1.0, "giro_extra": 0.0},
    "wall_clock": {"escala": 1.0, "giro_extra": 0.0},
    "plastic_broom": {"escala": 1.0, "giro_extra": 0.0},
    "television_02": {"escala": 1.0, "giro_extra": 0.0},
    "metal_toolbox": {"escala": 1.0, "giro_extra": 0.0},
    "industrial_caged_sconce": {"escala": 1.0, "giro_extra": 0.0},
    "cardboard_box_01": {"escala": 1.0, "giro_extra": 0.0},
    # contentor industrial de 1,75 m — e' lixeira de servico, nao cesto
    "metal_trash_can": {"escala": 1.0, "giro_extra": 0.0},
}

# Moveis pequenos e soltos: em vez da caixa estatica de `bloqueia`, ganham
# RigidBody3D e reagem a ser esbarrado ou chutado. Fora daqui fica tudo que e'
# grande, fixo na parede ou pesado demais pra fazer sentido rolando pelo
# corredor (maca, prancheta, extintor, contentor industrial).
FISICOS = {
    "plastic_monobloc_chair_01", "SchoolChair_01",
    "plastic_crate_01", "plastic_crate_02",
    "trashbag", "cardboard_box_01",
}

_aabb_cache = {}


def aabb(nome):
    """(min, max) do .gltf, lido direto dos accessors — sem abrir o Blender."""
    if nome in _aabb_cache:
        return _aabb_cache[nome]
    pasta = os.path.join(DIR_MODELOS, nome)
    arquivo = None
    for f in sorted(os.listdir(pasta)):
        if f.endswith(".gltf"):
            arquivo = os.path.join(pasta, f)
            break
    j = json.load(open(arquivo))
    mn = [1e9] * 3
    mx = [-1e9] * 3
    for malha in j.get("meshes", []):
        for prim in malha.get("primitives", []):
            acc = j["accessors"][prim["attributes"]["POSITION"]]
            for i in range(3):
                mn[i] = min(mn[i], acc["min"][i])
                mx[i] = max(mx[i], acc["max"][i])
    _aabb_cache[nome] = (mn, mx)
    return _aabb_cache[nome]


def caminho(nome):
    pasta = os.path.join(DIR_MODELOS, nome)
    for f in sorted(os.listdir(pasta)):
        if f.endswith(".gltf"):
            return "res://assets/3d_model/polyhaven/%s/%s" % (nome, f)
    return None


# ==========================================================================
# MOVEIS DE CAIXA
#
# Cada construtor devolve [(dx, dy, dz, sx, sy, sz, material), ...] em torno de
# uma origem no CHAO, com a frente do movel apontando pro +Z local.
# ==========================================================================

def cama_hospital(lencol="mat_lencol"):
    """Cama de hospital: cabeceira no -Z, pes no +Z, 0,95 x 2,05 m."""
    p = []
    # estrado e colchao
    p.append((0, 0.62, 0.0, 0.92, 0.10, 2.00, "mat_metal_claro"))
    p.append((0, 0.73, 0.02, 0.86, 0.14, 1.92, "mat_colchao"))
    p.append((0, 0.81, -0.62, 0.80, 0.06, 0.62, lencol))      # travesseiro/lencol
    p.append((0, 0.83, 0.34, 0.84, 0.04, 1.10, lencol))       # lencol dobrado
    # cabeceira e pezeira
    p.append((0, 0.55, -1.06, 0.98, 0.95, 0.08, "mat_metal_claro"))
    p.append((0, 0.45, 1.06, 0.98, 0.70, 0.08, "mat_metal_claro"))
    # grades laterais
    for lado in (-1, 1):
        p.append((lado * 0.48, 0.95, -0.20, 0.05, 0.05, 1.10, "mat_inox"))
        p.append((lado * 0.48, 0.80, -0.20, 0.04, 0.26, 0.04, "mat_inox"))
        p.append((lado * 0.48, 0.80, 0.34, 0.04, 0.26, 0.04, "mat_inox"))
    # pes com rodizio
    for ex in (-0.40, 0.40):
        for ez in (-0.88, 0.88):
            p.append((ex, 0.29, ez, 0.07, 0.58, 0.07, "mat_inox"))
            p.append((ex, 0.05, ez, 0.12, 0.10, 0.12, "mat_borracha"))
    return p


def maca():
    """Maca de corredor: mais estreita e mais alta que a cama."""
    p = []
    p.append((0, 0.76, 0.0, 0.76, 0.09, 1.90, "mat_inox"))
    p.append((0, 0.85, 0.0, 0.70, 0.10, 1.82, "mat_colchao"))
    p.append((0, 0.92, -0.60, 0.64, 0.05, 0.50, "mat_lencol"))
    for ex in (-0.32, 0.32):
        for ez in (-0.80, 0.80):
            p.append((ex, 0.38, ez, 0.05, 0.76, 0.05, "mat_inox"))
            p.append((ex, 0.06, ez, 0.13, 0.12, 0.13, "mat_borracha"))
    p.append((0, 1.00, -1.00, 0.72, 0.42, 0.05, "mat_inox"))
    return p


def criado_mudo():
    return [(0, 0.32, 0, 0.48, 0.64, 0.46, "mat_metal_claro"),
            (0, 0.66, 0, 0.52, 0.04, 0.50, "mat_inox"),
            (0, 0.42, 0.24, 0.40, 0.03, 0.02, "mat_inox")]


def suporte_soro():
    """Suporte de soro com a bolsa pendurada."""
    return [(0, 0.03, 0, 0.42, 0.06, 0.42, "mat_inox"),
            (0, 0.90, 0, 0.045, 1.80, 0.045, "mat_inox"),
            (0, 1.78, 0, 0.30, 0.04, 0.04, "mat_inox"),
            (0.13, 1.60, 0, 0.16, 0.30, 0.07, "mat_soro")]


def balcao(largura, profundidade=0.70, altura=1.05):
    """Balcao de atendimento: corpo + tampo com beiral."""
    return [(0, altura * 0.5 - 0.04, 0, largura, altura - 0.08, profundidade, "mat_balcao"),
            (0, altura - 0.03, 0.04, largura + 0.10, 0.07, profundidade + 0.16, "mat_tampo"),
            (0, 0.06, 0, largura - 0.06, 0.12, profundidade - 0.10, "mat_metal_escuro")]


def bancada(largura, profundidade=0.66, altura=0.92):
    """Bancada de laboratorio/copa, com armario embaixo."""
    return [(0, altura - 0.03, 0, largura, 0.06, profundidade, "mat_tampo"),
            (0, (altura - 0.06) * 0.5 + 0.08, -0.03, largura - 0.06,
             altura - 0.20, profundidade - 0.08, "mat_balcao"),
            (0, 0.06, -0.03, largura - 0.12, 0.12, profundidade - 0.16, "mat_metal_escuro")]


def pia_inox(largura=1.40):
    p = bancada(largura, 0.62, 0.92)
    p.append((0, 0.86, 0.02, largura - 0.50, 0.10, 0.44, "mat_inox"))
    p.append((0, 1.14, -0.22, 0.05, 0.36, 0.05, "mat_inox"))
    p.append((0, 1.30, -0.13, 0.05, 0.05, 0.22, "mat_inox"))
    return p


def armario(largura=1.10, altura=1.90, profundidade=0.46):
    p = [(0, altura * 0.5, 0, largura, altura, profundidade, "mat_metal_claro")]
    p.append((0, altura * 0.5, profundidade * 0.5 + 0.01, largura - 0.08,
              altura - 0.10, 0.02, "mat_vidro_fosco"))
    p.append((0, altura * 0.5, profundidade * 0.5 + 0.03, 0.04, 0.24, 0.03, "mat_inox"))
    return p


def prateleira(largura=1.60, altura=2.10, profundidade=0.50, andares=5):
    p = []
    for lado in (-1, 1):
        for fundo in (-1, 1):
            p.append((lado * (largura * 0.5 - 0.03), altura * 0.5,
                      fundo * (profundidade * 0.5 - 0.03),
                      0.05, altura, 0.05, "mat_metal_escuro"))
    for i in range(andares):
        y = 0.16 + i * (altura - 0.24) / max(andares - 1, 1)
        p.append((0, y, 0, largura - 0.04, 0.04, profundidade - 0.04, "mat_metal_claro"))
    return p


def mesa_cirurgica():
    """A mesa que fica no MEIO da sala — a unica ilha da cirurgia."""
    p = [(0, 0.10, 0, 0.80, 0.20, 0.90, "mat_inox"),
         (0, 0.48, 0, 0.26, 0.76, 0.26, "mat_inox"),
         (0, 0.90, 0, 0.66, 0.10, 1.96, "mat_inox"),
         (0, 0.98, -0.10, 0.60, 0.08, 1.60, "mat_couro_verde"),
         (0, 0.99, -0.86, 0.46, 0.07, 0.34, "mat_couro_verde")]
    for lado in (-1, 1):
        p.append((lado * 0.44, 0.86, 0.66, 0.22, 0.05, 0.42, "mat_inox"))
    return p


def foco_cirurgico():
    """Cupula do foco cirurgico, pendurada. Origem no TETO."""
    p = [(0, -0.20, 0, 0.10, 0.40, 0.10, "mat_inox"),
         (0, -0.52, 0, 1.10, 0.26, 1.10, "mat_metal_claro"),
         (0, -0.66, 0, 0.92, 0.06, 0.92, "mat_lampada")]
    return p


def gavetas_necroterio(colunas=5, linhas=3):
    """A parede de gavetas. Origem no chao, portas olhando pro +Z."""
    p = []
    larg = colunas * 0.82
    alt = linhas * 0.62 + 0.30
    p.append((0, alt * 0.5, -0.90, larg + 0.10, alt, 1.80, "mat_inox"))
    for c in range(colunas):
        for l in range(linhas):
            x = (c - (colunas - 1) * 0.5) * 0.82
            y = 0.30 + l * 0.62 + 0.28
            p.append((x, y, 0.01, 0.74, 0.54, 0.05, "mat_gaveta"))
            p.append((x, y + 0.14, 0.05, 0.22, 0.05, 0.06, "mat_inox"))
    return p


def mesa_autopsia():
    p = [(0, 0.04, 0, 0.70, 0.08, 0.80, "mat_inox"),
         (0, 0.42, 0, 0.18, 0.76, 0.18, "mat_inox"),
         (0, 0.86, 0, 0.84, 0.10, 2.10, "mat_inox"),
         (0, 0.92, 0, 0.70, 0.03, 1.94, "mat_inox_escovado")]
    return p


def autoclave():
    p = [(0, 0.95, 0, 1.00, 1.90, 0.90, "mat_metal_claro"),
         (0, 1.05, 0.46, 0.72, 0.72, 0.06, "mat_inox"),
         (0, 1.05, 0.50, 0.46, 0.46, 0.03, "mat_vidro_fosco"),
         (0.42, 1.05, 0.50, 0.06, 0.20, 0.06, "mat_inox"),
         (0, 1.86, 0.44, 0.84, 0.16, 0.06, "mat_painel")]
    return p


def maquina_raio_x():
    p = [(0, 0.08, 0, 1.20, 0.16, 2.30, "mat_metal_escuro"),
         (0, 0.72, 0, 0.90, 1.12, 2.10, "mat_metal_claro"),
         (0, 1.34, 0, 0.80, 0.14, 1.90, "mat_inox"),
         (0, 2.30, -0.60, 0.16, 1.80, 0.16, "mat_metal_escuro"),
         (0, 2.90, 0.10, 0.20, 0.16, 1.40, "mat_metal_escuro"),
         (0, 2.56, 0.60, 0.46, 0.50, 0.46, "mat_metal_claro")]
    return p


def biombo(largura=1.90, altura=2.05):
    """Biombo/cortina de box. Tres folhas levemente em leque."""
    p = [(0, altura + 0.05, 0, largura + 0.20, 0.05, 0.05, "mat_inox")]
    n = 3
    for i in range(n):
        x = (i - (n - 1) * 0.5) * (largura / n)
        p.append((x, altura * 0.5 + 0.10, (i % 2) * 0.06,
                  largura / n - 0.02, altura - 0.20, 0.03, "mat_cortina"))
    return p


def cortina_janela(largura=1.30, altura=1.80):
    return [(0, altura * 0.5, 0, largura, altura, 0.05, "mat_cortina")]


def monitor_parede():
    return [(0, 0, 0, 0.44, 0.34, 0.12, "mat_metal_escuro"),
            (0, 0, 0.07, 0.38, 0.26, 0.02, "mat_tela")]


def placa_seta(comprimento=1.60):
    """Placa de sinalizacao pendurada. Sem texto: a diretriz do projeto manda
    todo texto ir pro CSV, e texto assado em geometria nao tem traducao. Entao
    ela e' SETA — que se le igual nas duas linguas."""
    p = [(0, -0.12, 0, 0.04, 0.24, 0.04, "mat_inox"),
         (0, -0.40, 0, comprimento, 0.34, 0.05, "mat_placa")]
    p.append((comprimento * 0.5 - 0.10, -0.40, 0.04, 0.22, 0.22, 0.02, "mat_seta"))
    return p


def extintor_suporte():
    return [(0, 0, 0, 0.22, 0.46, 0.10, "mat_metal_escuro")]


def bebedouro():
    return [(0, 0.55, 0, 0.42, 1.10, 0.36, "mat_metal_claro"),
            (0, 1.12, 0, 0.46, 0.06, 0.40, "mat_inox"),
            (0, 1.22, -0.08, 0.06, 0.16, 0.06, "mat_inox")]


def mesa_refeitorio(largura=1.80):
    return [(0, 0.74, 0, largura, 0.06, 0.86, "mat_formica"),
            (0, 0.37, 0, 0.10, 0.68, 0.10, "mat_metal_escuro"),
            (0, 0.03, 0, largura - 0.50, 0.06, 0.60, "mat_metal_escuro")]


# O balcao de recepcao do hall, em numeros. Mora aqui fora porque o gerador da
# cena precisa dos MESMOS valores pra pousar a pistola e a municao em cima do
# tampo (ver `_emitir_itens_do_balcao`): chutar 3,20 la' tambem significaria que
# mexer no raio daqui largaria os dois itens flutuando no ar.
RECEPCAO_RAIO = 3.20
RECEPCAO_ALTURA = 1.10
## Altura da FACE DE CIMA do tampo, medido do piso. O tampo e' uma caixa de 8 cm
## centrada em `altura - 0.02`, entao o topo dela fica 2 cm acima da altura.
RECEPCAO_TOPO = RECEPCAO_ALTURA + 0.02


def balcao_redondo(raio=3.20, segmentos=16, altura=1.10):
    """O circulo do HALL PRINCIPAL — e' ele que esta' desenhado no mapa.

    Nao e' um cilindro: sao 16 caixas em leque. Sai mais barato que malha
    redonda de verdade e, com o tampo por cima, ninguem percebe a diferenca a
    1,70 m do chao.
    """
    p = []
    lado = 2.0 * math.pi * raio / segmentos * 1.06
    for i in range(segmentos):
        ang = 2.0 * math.pi * i / segmentos
        # caixa ja' posicionada em coordenadas locais (o gerador nao gira peca
        # individual, entao a rotacao vai na propria caixa)
        p.append({"pos": (math.sin(ang) * raio, altura * 0.5 - 0.05,
                          math.cos(ang) * raio),
                  "tam": (lado, altura - 0.10, 0.55),
                  "giro": ang, "mat": "mat_balcao"})
        p.append({"pos": (math.sin(ang) * raio, altura - 0.02,
                          math.cos(ang) * raio),
                  "tam": (lado, 0.08, 0.86), "giro": ang, "mat": "mat_tampo"})
    return p


def painel_elevador():
    p = [(0, 0, 0, 0.26, 0.70, 0.05, "mat_inox")]
    for i in range(2):
        p.append((0, 0.14 - i * 0.28, 0.035, 0.11, 0.11, 0.02, "mat_botao"))
    return p


# ==========================================================================
# POSICIONAMENTO
# ==========================================================================

def _lugar_na_parede(s, parede, t, recuo):
    """Ponto a `recuo` metros da parede, na fracao `t` (0..1) do comprimento."""
    x0, x1, z0, z1 = s["x0"], s["x1"], s["z0"], s["z1"]
    if parede == "n":
        return (x0 + (x1 - x0) * t, z0 + recuo)
    if parede == "s":
        return (x0 + (x1 - x0) * t, z1 - recuo)
    if parede == "o":
        return (x0 + recuo, z0 + (z1 - z0) * t)
    return (x1 - recuo, z0 + (z1 - z0) * t)


def _prop(tipo, sala, x, z, giro, **extra):
    d = {"tipo": tipo, "sala": sala["ident"], "andar": sala["andar"],
         "x": x, "y": P.cota(sala["andar"]), "z": z, "giro": giro,
         "bloqueia": None}
    d.update(extra)
    # `bloqueia` chega em medidas LOCAIS do movel (largura x profundidade).
    # Girado 90 graus, largura vira profundidade — e e' a pegada em coordenadas
    # do MUNDO que o navmesh precisa furar.
    if d.get("bloqueia"):
        lx, lz = d["bloqueia"]
        if abs(math.cos(giro)) < 0.5:
            d["bloqueia"] = (lz, lx)
    # Item da lista FISICOS: a caixa de colisao sai direto do AABB do .gltf, ja'
    # no tamanho e centro certos — sem precisar chutar medida a mao pra cada
    # cadeira. Ganha corpo fisico PROPRIO, entao a caixa estatica de `bloqueia`
    # fica sem sentido aqui (os dois no mesmo lugar so' travariam um no outro).
    if d.get("modelo") in FISICOS:
        mn, mx = aabb(d["modelo"])
        esc = d.get("escala", 1.0)
        d["fisico"] = True
        d["fisico_caixa"] = tuple((mx[k] - mn[k]) * esc for k in range(3))
        d["fisico_centro"] = tuple((mn[k] + mx[k]) * 0.5 * esc for k in range(3))
        d["bloqueia"] = None
    return d


def caixas_na_parede(s, pecas, parede, t, recuo, nome, bloqueia=None, dy=0.0):
    x, z = _lugar_na_parede(s, parede, t, recuo)
    return _prop("caixas", s, x, z, GIRO_PAREDE[parede], pecas=pecas,
                 nome=nome, bloqueia=bloqueia, dy=dy)


def modelo_na_parede(s, nome_modelo, parede, t, recuo, nome, bloqueia=None,
                     dy=0.0, escala=None, giro_extra=None):
    x, z = _lugar_na_parede(s, parede, t, recuo)
    info = MODELOS[nome_modelo]
    giro = GIRO_PAREDE[parede] + (info["giro_extra"] if giro_extra is None
                                  else giro_extra)
    return _prop("modelo", s, x, z, giro, modelo=nome_modelo, nome=nome,
                 bloqueia=bloqueia, dy=dy,
                 escala=info["escala"] if escala is None else escala)


def caixas_solto(s, pecas, x, z, giro, nome, bloqueia=None, dy=0.0):
    return _prop("caixas", s, x, z, giro, pecas=pecas, nome=nome,
                 bloqueia=bloqueia, dy=dy)


def modelo_solto(s, nome_modelo, x, z, giro, nome, bloqueia=None, dy=0.0,
                 escala=None):
    info = MODELOS[nome_modelo]
    return _prop("modelo", s, x, z, giro + info["giro_extra"],
                 modelo=nome_modelo, nome=nome, bloqueia=bloqueia, dy=dy,
                 escala=info["escala"] if escala is None else escala)


# ==========================================================================
# O QUE VAI EM CADA SALA
#
# Um receituario por TIPO de sala. Cada funcao recebe o comodo e devolve a
# lista de moveis dele. O sorteio usa semente derivada do nome da sala: dois
# quartos nao ficam identicos, mas o MESMO quarto fica igual toda vez que o
# gerador roda — senao o jogador perdia a referencia visual a cada build.
# ==========================================================================

def _dado(s):
    return random.Random("hospital/" + s["ident"])


def _portas_do_andar(andar):
    pts = []
    for m in P.muros(andar):
        for v in m["vaos"]:
            if v["tipo"] not in ("porta", "passagem"):
                continue
            if m["eixo"] == "x":
                pts.append((v["c"], m["coord"], v["l"]))
            else:
                pts.append((m["coord"], v["c"], v["l"]))
    return pts


_CACHE_PORTAS = {}


def livre_de_porta(x, z, andar, folga=2.1):
    """Movel nao pode nascer em frente a porta nenhuma."""
    if andar not in _CACHE_PORTAS:
        _CACHE_PORTAS[andar] = _portas_do_andar(andar)
    for (px, pz, l) in _CACHE_PORTAS[andar]:
        if abs(x - px) < l * 0.5 + folga and abs(z - pz) < folga + 0.8:
            return False
    return True


def _por(s, lista):
    """Filtra o que caiu em frente a uma porta."""
    return [p for p in lista
            if p is not None and livre_de_porta(p["x"], p["z"], p["andar"])]


# --------------------------------------------------------------------------

def _quarto(s, d):
    """Quarto de internacao: camas nas duas laterais, corredor central livre."""
    itens = []
    fundo = s["z1"] - s["z0"]
    largo = s["x1"] - s["x0"]
    # Qual par de paredes recebe as camas: sempre as duas MAIS COMPRIDAS, pra
    # cabeceira ficar no lado maior e o vao livre no meio ser o mais longo.
    lados = ("o", "l") if fundo >= largo else ("n", "s")
    quantas = 3 if max(fundo, largo) > 9.5 else 2
    for lado in lados:
        for i in range(quantas):
            t = (i + 1.0) / (quantas + 1.0)
            itens.append(caixas_na_parede(
                s, cama_hospital("mat_lencol" if d.random() > 0.3 else "mat_lencol_sujo"),
                lado, t, 1.20, "cama_%s_%d" % (lado, i), bloqueia=(1.1, 2.3)))
            itens.append(caixas_na_parede(
                s, criado_mudo(), lado, t + 0.5 / (quantas + 1.0), 0.45,
                "criado_%s_%d" % (lado, i), bloqueia=(0.6, 0.6)))
            if d.random() < 0.55:
                itens.append(caixas_na_parede(
                    s, suporte_soro(), lado, t - 0.42 / (quantas + 1.0), 0.70,
                    "soro_%s_%d" % (lado, i)))
            if d.random() < 0.4:
                itens.append(caixas_na_parede(
                    s, monitor_parede(), lado, t - 0.2 / (quantas + 1.0), 0.14,
                    "monitor_%s_%d" % (lado, i), dy=1.70))
        if d.random() < 0.6:
            itens.append(caixas_na_parede(s, biombo(), lado, 0.5, 1.60,
                                          "biombo_" + lado, bloqueia=(2.1, 0.4)))
    # o resto encosta nas paredes curtas
    curtas = ("n", "s") if lados[0] == "o" else ("o", "l")
    itens.append(caixas_na_parede(s, armario(), curtas[0], 0.22, 0.30,
                                  "armario", bloqueia=(1.2, 0.6)))
    itens.append(modelo_na_parede(s, "drawer_cabinet", curtas[1], 0.78, 0.32,
                                  "gaveteiro", bloqueia=(1.2, 0.6)))
    if d.random() < 0.5:
        itens.append(modelo_na_parede(s, "wheelchair_01", curtas[1], 0.25, 0.85,
                                      "cadeira_rodas", bloqueia=(0.9, 1.2)))
    if d.random() < 0.4:
        itens.append(modelo_na_parede(s, "vintage_crutches_01", curtas[0], 0.7,
                                      0.28, "muletas"))
    if d.random() < 0.5:
        itens.append(modelo_na_parede(s, "metal_stool_01", curtas[0], 0.5, 1.1,
                                      "banqueta"))
    return itens


def _exame(s, d):
    itens = [caixas_solto(s, maquina_raio_x(),
                          (s["x0"] + s["x1"]) * 0.5, s["z0"] + 3.2, 0.0,
                          "raio_x", bloqueia=(1.6, 2.8))]
    itens.append(caixas_na_parede(s, bancada(2.6), "s", 0.28, 0.42, "bancada",
                                  bloqueia=(2.7, 0.8)))
    itens.append(caixas_na_parede(s, armario(), "s", 0.72, 0.30, "armario",
                                  bloqueia=(1.2, 0.6)))
    itens.append(modelo_na_parede(s, "metal_stool_01", "s", 0.36, 1.10, "banqueta"))
    itens.append(caixas_na_parede(s, monitor_parede(), "s", 0.22, 0.16,
                                  "monitor", dy=1.55))
    itens.append(modelo_na_parede(s, "medical_box", "s", 0.30, 0.50, "caixa_med",
                                  dy=0.92))
    itens.append(caixas_na_parede(s, pia_inox(), "o", 0.72, 0.40, "pia",
                                  bloqueia=(0.8, 1.5)))
    return itens


def _laboratorio(s, d):
    itens = []
    for lado, t0 in (("n", 0.30), ("s", 0.32)):
        itens.append(caixas_na_parede(s, bancada(4.4), lado, t0, 0.42,
                                      "bancada_" + lado, bloqueia=(4.5, 0.8)))
    itens.append(caixas_na_parede(s, pia_inox(1.8), "o", 0.5, 0.42, "pia",
                                  bloqueia=(0.8, 1.9)))
    itens.append(caixas_na_parede(s, prateleira(), "l", 0.3, 0.32, "prateleira",
                                  bloqueia=(0.6, 1.7)))
    itens.append(caixas_na_parede(s, prateleira(), "l", 0.68, 0.32, "prateleira_2",
                                  bloqueia=(0.6, 1.7)))
    itens.append(modelo_na_parede(s, "industrial_microscope", "n", 0.22, 0.45,
                                  "microscopio", dy=0.92))
    itens.append(modelo_na_parede(s, "chemistry_set", "n", 0.38, 0.45,
                                  "vidraria", dy=0.92))
    itens.append(modelo_na_parede(s, "bunsen_burner", "s", 0.26, 0.45,
                                  "bico", dy=0.92))
    for i, t in enumerate((0.22, 0.36, 0.52)):
        itens.append(modelo_na_parede(s, "metal_stool_01", "n", t, 1.15,
                                      "banqueta_%d" % i))
    return itens


def _cirurgia(s, d):
    cx, cz = P.centro(s)
    itens = [caixas_solto(s, mesa_cirurgica(), cx, cz, 0.0, "mesa_cirurgica",
                          bloqueia=(1.2, 2.3))]
    itens.append(_prop("caixas", s, cx, cz, 0.0, pecas=foco_cirurgico(),
                       nome="foco", dy=P.PE, bloqueia=None))
    for lado in ("n", "s"):
        itens.append(caixas_na_parede(s, bancada(3.0), lado, 0.72, 0.42,
                                      "bancada_" + lado, bloqueia=(3.1, 0.8)))
        itens.append(caixas_na_parede(s, armario(), lado, 0.26, 0.30,
                                      "armario_" + lado, bloqueia=(1.2, 0.6)))
    itens.append(caixas_na_parede(s, pia_inox(1.9), "o", 0.62, 0.42, "pia",
                                  bloqueia=(0.8, 2.0)))
    itens.append(modelo_na_parede(s, "industrial_storage_cart", "l", 0.30, 0.95,
                                  "carro", bloqueia=(1.2, 1.7)))
    itens.append(caixas_na_parede(s, suporte_soro(), "l", 0.62, 0.70, "soro"))
    itens.append(caixas_na_parede(s, monitor_parede(), "n", 0.50, 0.16,
                                  "monitor", dy=1.75))
    return itens


def _uti(s, d):
    itens = []
    for i in range(4):
        t = (i + 0.5) / 4.0
        itens.append(caixas_na_parede(s, cama_hospital(), "n", t, 1.22,
                                      "leito_%d" % i, bloqueia=(1.1, 2.3)))
        itens.append(caixas_na_parede(s, suporte_soro(), "n", t + 0.07, 0.65,
                                      "soro_%d" % i))
        itens.append(caixas_na_parede(s, monitor_parede(), "n", t - 0.05, 0.16,
                                      "monitor_%d" % i, dy=1.80))
        if i < 3:
            itens.append(caixas_na_parede(s, biombo(2.2), "n", (i + 1.0) / 4.0,
                                          1.60, "biombo_%d" % i,
                                          bloqueia=(2.4, 0.4)))
    itens.append(caixas_na_parede(s, balcao(3.4), "s", 0.5, 0.55, "posto",
                                  bloqueia=(3.6, 0.9)))
    itens.append(modelo_na_parede(s, "metal_stool_01", "s", 0.44, 1.35, "banqueta"))
    itens.append(caixas_na_parede(s, armario(), "l", 0.30, 0.30, "armario",
                                  bloqueia=(1.2, 0.6)))
    return itens


def _emergencia(s, d):
    itens = []
    itens.append(caixas_na_parede(s, balcao(4.0), "n", 0.22, 0.60, "triagem",
                                  bloqueia=(4.2, 0.9)))
    for i in range(4):
        t = 0.42 + i * 0.145
        itens.append(caixas_na_parede(s, maca(), "n", t, 1.15, "maca_%d" % i,
                                      bloqueia=(1.0, 2.2)))
        itens.append(caixas_na_parede(s, biombo(2.0), "n", t + 0.07, 1.55,
                                      "biombo_%d" % i, bloqueia=(2.2, 0.4)))
    for i in range(6):
        itens.append(modelo_na_parede(s, "plastic_monobloc_chair_01", "s",
                                      0.16 + i * 0.075, 0.70, "cadeira_%d" % i))
    itens.append(modelo_na_parede(s, "wheelchair_01", "s", 0.72, 0.85,
                                  "cadeira_rodas", bloqueia=(0.9, 1.2)))
    itens.append(caixas_na_parede(s, bebedouro(), "s", 0.84, 0.35, "bebedouro",
                                  bloqueia=(0.5, 0.5)))
    itens.append(modelo_na_parede(s, "industrial_storage_cart", "l", 0.72, 0.95,
                                  "carro", bloqueia=(1.2, 1.7)))
    return itens


def _refeitorio(s, d):
    itens = [caixas_na_parede(s, balcao(5.0), "n", 0.42, 0.60, "balcao_servico",
                              bloqueia=(5.2, 0.9))]
    itens.append(caixas_na_parede(s, pia_inox(2.0), "n", 0.80, 0.42, "pia",
                                  bloqueia=(2.1, 0.8)))
    # mesas em duas fileiras, com corredor de 2,6 m no meio
    cx, cz = P.centro(s)
    for i in range(3):
        for j in (-1, 1):
            x = cx + (i - 1) * 3.0
            z = cz + j * 1.9
            itens.append(caixas_solto(s, mesa_refeitorio(), x, z, 0.0,
                                      "mesa_%d_%d" % (i, j),
                                      bloqueia=(2.0, 1.0)))
            for k in (-1, 1):
                itens.append(modelo_solto(s, "SchoolChair_01", x + k * 0.55,
                                          z + j * 0.85,
                                          0.0 if j < 0 else math.pi,
                                          "cadeira_%d_%d_%d" % (i, j, k)))
    itens.append(modelo_na_parede(s, "metal_trash_can", "s", 0.86, 0.60,
                                  "lixo", bloqueia=(1.4, 0.7)))
    return itens


def _necroterio(s, d):
    itens = [caixas_na_parede(s, gavetas_necroterio(5, 3), "n", 0.42, 1.90,
                              "gavetas", bloqueia=(4.3, 2.0))]
    cx, cz = P.centro(s)
    for i in (-1, 1):
        itens.append(caixas_solto(s, mesa_autopsia(), cx + i * 2.2, cz + 1.4,
                                  0.0, "mesa_autopsia_%d" % i,
                                  bloqueia=(1.1, 2.4)))
    itens.append(caixas_na_parede(s, pia_inox(2.0), "s", 0.22, 0.42, "pia",
                                  bloqueia=(2.1, 0.8)))
    itens.append(caixas_na_parede(s, bancada(2.4), "s", 0.62, 0.42, "bancada",
                                  bloqueia=(2.5, 0.8)))
    itens.append(caixas_na_parede(s, prateleira(1.4, 2.0, 0.45, 4), "l", 0.30,
                                  0.30, "prateleira", bloqueia=(0.5, 1.5)))
    itens.append(modelo_na_parede(s, "industrial_storage_cart", "o", 0.30, 0.95,
                                  "carro", bloqueia=(1.2, 1.7)))
    itens.append(caixas_na_parede(s, maca(), "o", 0.70, 1.10, "maca",
                                  bloqueia=(1.0, 2.2)))
    return itens


def _farmacia(s, d):
    itens = [caixas_na_parede(s, balcao(3.2), "n", 0.30, 0.60, "balcao",
                              bloqueia=(3.4, 0.9))]
    for i, t in enumerate((0.20, 0.40, 0.60, 0.80)):
        itens.append(caixas_na_parede(s, prateleira(1.8, 2.20, 0.50, 5), "s", t,
                                      0.32, "prateleira_s_%d" % i,
                                      bloqueia=(1.9, 0.6)))
    for i, t in enumerate((0.30, 0.62)):
        itens.append(modelo_na_parede(s, "steel_frame_shelves_02", "l", t, 0.36,
                                      "estante_%d" % i, bloqueia=(0.6, 0.7)))
    itens.append(modelo_na_parede(s, "plastic_crate_01", "o", 0.30, 0.45, "caixa_1"))
    itens.append(modelo_na_parede(s, "plastic_crate_02", "o", 0.42, 0.45, "caixa_2"))
    itens.append(modelo_na_parede(s, "medical_box", "n", 0.36, 0.60, "caixa_med",
                                  dy=1.06))
    return itens


def _esterilizacao(s, d):
    itens = []
    for i, t in enumerate((0.24, 0.44, 0.64)):
        itens.append(caixas_na_parede(s, autoclave(), "s", t, 0.55,
                                      "autoclave_%d" % i, bloqueia=(1.1, 1.1)))
    itens.append(caixas_na_parede(s, bancada(4.0), "n", 0.34, 0.42, "bancada",
                                  bloqueia=(4.1, 0.8)))
    itens.append(caixas_na_parede(s, pia_inox(1.8), "n", 0.72, 0.42, "pia",
                                  bloqueia=(1.9, 0.8)))
    for i, t in enumerate((0.30, 0.66)):
        itens.append(modelo_na_parede(s, "worn_metal_rack", "l", t, 0.42,
                                      "carrinho_%d" % i, bloqueia=(1.0, 0.7)))
    itens.append(modelo_na_parede(s, "industrial_pastic_container", "o", 0.32,
                                  0.50, "container"))
    return itens


def _maquinas(s, d):
    itens = [modelo_na_parede(s, "portable_generator", "s", 0.28, 0.85,
                              "gerador", bloqueia=(1.0, 0.8))]
    itens.append(modelo_na_parede(s, "modular_pipes", "s", 0.62, 0.40, "canos"))
    itens.append(modelo_na_parede(s, "modular_airduct_rectangular_01", "l", 0.30,
                                  1.10, "duto", dy=2.10))
    for i, t in enumerate((0.22, 0.40, 0.58)):
        itens.append(modelo_na_parede(s, "power_box_01", "n", t, 0.24,
                                      "quadro_%d" % i, dy=1.45))
    itens.append(modelo_na_parede(s, "utility_box_01", "n", 0.74, 0.28, "caixa_forca"))
    itens.append(modelo_na_parede(s, "tool_cart", "o", 0.34, 0.75, "carro_ferramenta",
                                  bloqueia=(1.3, 0.9)))
    itens.append(modelo_na_parede(s, "metal_toolbox", "o", 0.62, 0.40, "caixa_ferramenta"))
    itens.append(caixas_na_parede(s, prateleira(1.6, 2.1, 0.5, 4), "o", 0.80,
                                  0.32, "prateleira", bloqueia=(0.6, 1.7)))
    itens.append(modelo_na_parede(s, "trashbag", "s", 0.86, 0.55, "saco"))
    return itens


def _arquivo(s, d):
    """Estantes em FILEIRAS, com corredor de 2,2 m entre elas."""
    itens = []
    x0, x1 = s["x0"], s["x1"]
    z0, z1 = s["z0"], s["z1"]
    fila = 0
    z = z0 + 2.6
    while z < z1 - 2.2:
        n = int((x1 - x0 - 4.0) / 1.9)
        for i in range(n):
            x = x0 + 2.4 + i * 1.9
            itens.append(caixas_solto(s, prateleira(1.8, 2.20, 0.55, 5), x, z,
                                      math.pi * 0.5, "estante_%d_%d" % (fila, i),
                                      bloqueia=(1.9, 0.7)))
        z += 2.9
        fila += 1
    itens.append(modelo_na_parede(s, "metal_office_desk", "s", 0.76, 0.75,
                                  "mesa", bloqueia=(2.1, 1.0)))
    itens.append(modelo_na_parede(s, "metal_stool_01", "s", 0.76, 1.70, "banqueta"))
    itens.append(modelo_na_parede(s, "binder_notebook", "s", 0.72, 0.75,
                                  "pasta", dy=0.79))
    itens.append(modelo_na_parede(s, "cardboard_box_01", "o", 0.30, 0.45, "caixa"))
    return itens


def _psiquiatria(s, d):
    itens = []
    for i in range(3):
        t = (i + 0.5) / 3.0
        itens.append(caixas_na_parede(s, cama_hospital("mat_lencol_sujo"), "n",
                                      t, 1.22, "leito_%d" % i,
                                      bloqueia=(1.1, 2.3)))
        itens.append(caixas_na_parede(s, biombo(2.0), "n", t + 0.16, 1.55,
                                      "biombo_%d" % i, bloqueia=(2.2, 0.4)))
    itens.append(caixas_na_parede(s, armario(), "s", 0.26, 0.30, "armario",
                                  bloqueia=(1.2, 0.6)))
    itens.append(modelo_na_parede(s, "SchoolChair_01", "s", 0.55, 0.85, "cadeira"))
    itens.append(modelo_na_parede(s, "metal_stool_01", "l", 0.40, 0.80, "banqueta"))
    itens.append(modelo_na_parede(s, "wheelchair_01", "o", 0.72, 0.90,
                                  "cadeira_rodas", bloqueia=(0.9, 1.2)))
    return itens


def _terapia(s, d):
    cx, cz = P.centro(s)
    itens = []
    for i in range(7):
        ang = 2.0 * math.pi * i / 7.0
        itens.append(modelo_solto(s, "SchoolChair_01",
                                  cx + math.sin(ang) * 2.3,
                                  cz + math.cos(ang) * 2.3,
                                  ang + math.pi, "cadeira_%d" % i))
    itens.append(modelo_na_parede(s, "metal_office_desk", "n", 0.74, 0.75,
                                  "mesa", bloqueia=(2.1, 1.0)))
    itens.append(caixas_na_parede(s, prateleira(1.6, 2.0, 0.45, 4), "o", 0.34,
                                  0.30, "prateleira", bloqueia=(0.5, 1.7)))
    itens.append(modelo_na_parede(s, "television_02", "s", 0.30, 0.45, "tv",
                                  dy=0.90))
    itens.append(caixas_na_parede(s, bancada(1.6), "s", 0.30, 0.42, "bancada",
                                  bloqueia=(1.7, 0.8)))
    return itens


def _observacao(s, d):
    itens = []
    for i in range(3):
        t = (i + 0.5) / 3.0
        itens.append(caixas_na_parede(s, cama_hospital(), "s", t, 1.22,
                                      "leito_%d" % i, bloqueia=(1.1, 2.3)))
        itens.append(caixas_na_parede(s, monitor_parede(), "s", t - 0.06, 0.16,
                                      "monitor_%d" % i, dy=1.80))
        itens.append(caixas_na_parede(s, suporte_soro(), "s", t + 0.08, 0.68,
                                      "soro_%d" % i))
    itens.append(caixas_na_parede(s, balcao(2.6), "n", 0.72, 0.55, "posto",
                                  bloqueia=(2.8, 0.9)))
    itens.append(modelo_na_parede(s, "drawer_cabinet", "o", 0.40, 0.32,
                                  "gaveteiro", bloqueia=(1.2, 0.6)))
    return itens


def _hall(s, d):
    """O hall principal. O CIRCULO do mapa e' o balcao de recepcao."""
    cx, cz = P.centro(s)
    itens = [_prop("caixas_livres", s, cx, cz, 0.0,
                   pecas=balcao_redondo(RECEPCAO_RAIO, 16, RECEPCAO_ALTURA),
                   nome="recepcao", bloqueia=(7.4, 7.4))]
    # fileiras de cadeira de espera, todas encostadas — meio do hall livre
    for i in range(9):
        itens.append(modelo_na_parede(s, "plastic_monobloc_chair_01", "n",
                                      0.10 + i * 0.05, 0.75, "espera_n_%d" % i))
        itens.append(modelo_na_parede(s, "plastic_monobloc_chair_01", "s",
                                      0.10 + i * 0.05, 0.75, "espera_s_%d" % i))
    for i in range(6):
        itens.append(modelo_na_parede(s, "plastic_monobloc_chair_01", "o",
                                      0.18 + i * 0.06, 0.75, "espera_o_%d" % i))
    itens.append(caixas_na_parede(s, bebedouro(), "n", 0.62, 0.35, "bebedouro",
                                  bloqueia=(0.5, 0.5)))
    itens.append(modelo_na_parede(s, "wheelchair_01", "s", 0.66, 0.95,
                                  "cadeira_rodas", bloqueia=(0.9, 1.2)))
    itens.append(modelo_na_parede(s, "wheelchair_01", "n", 0.72, 0.95,
                                  "cadeira_rodas_2", bloqueia=(0.9, 1.2)))
    itens.append(modelo_na_parede(s, "television_02", "s", 0.34, 0.30, "tv",
                                  dy=2.10))
    itens.append(modelo_na_parede(s, "wall_clock", "n", 0.40, 0.22, "relogio",
                                  dy=2.60))
    itens.append(modelo_na_parede(s, "industrial_storage_cart", "l", 0.20, 0.95,
                                  "carro", bloqueia=(1.2, 1.7)))
    itens.append(modelo_na_parede(s, "metal_office_desk", "l", 0.78, 0.80,
                                  "mesa_seguranca", bloqueia=(2.1, 1.0)))
    # setas penduradas apontando pros dois lados do predio
    for t, comp in ((0.30, 2.0), (0.70, 2.0)):
        x, z = _lugar_na_parede(s, "l", t, 2.6)
        itens.append(_prop("caixas", s, x, z, math.pi * 0.5,
                           pecas=placa_seta(comp), nome="placa_%d" % int(t * 10),
                           dy=P.PE))
    return itens


def _saguao(s, d):
    itens = []
    largo = s["x1"] - s["x0"] > s["z1"] - s["z0"]
    lados = ("n", "s") if largo else ("o", "l")
    for lado in lados:
        for i in range(7):
            itens.append(modelo_na_parede(s, "plastic_monobloc_chair_01", lado,
                                          0.14 + i * 0.06, 0.75,
                                          "espera_%s_%d" % (lado, i)))
    itens.append(caixas_na_parede(s, bebedouro(), lados[0], 0.72, 0.35,
                                  "bebedouro", bloqueia=(0.5, 0.5)))
    itens.append(modelo_na_parede(s, "metal_trash_can", lados[1], 0.80, 0.70,
                                  "lixo", bloqueia=(1.4, 0.7)))
    if (s["x1"] - s["x0"]) * (s["z1"] - s["z0"]) > 200.0:
        itens.append(caixas_na_parede(s, balcao(3.6), lados[1], 0.30, 0.60,
                                      "posto", bloqueia=(3.8, 0.9)))
        itens.append(modelo_na_parede(s, "metal_stool_01", lados[1], 0.30, 1.40,
                                      "banqueta"))
    return itens


def _corredor(s, d):
    """Corredor: so' o que fica RENTE a parede. O miolo e' sagrado."""
    itens = []
    largo = (s["x1"] - s["x0"]) >= (s["z1"] - s["z0"])
    lados = ("n", "s") if largo else ("o", "l")
    comprimento = max(s["x1"] - s["x0"], s["z1"] - s["z0"])
    quantos = max(int(comprimento / 11.0), 1)

    for k in range(quantos):
        t = (k + 0.5) / quantos
        lado = lados[k % 2]
        # maca encostada, DEITADA ao longo da parede (giro extra de 90 graus)
        x, z = _lugar_na_parede(s, lado, t, 0.62)
        if livre_de_porta(x, z, s["andar"], 2.6):
            itens.append(_prop("caixas", s, x, z,
                               GIRO_PAREDE[lado] + math.pi * 0.5,
                               pecas=maca(), nome="maca_%d" % k,
                               bloqueia=(2.2, 1.0)))
        outro = lados[(k + 1) % 2]
        itens.append(caixas_na_parede(s, extintor_suporte(), outro,
                                      min(t + 0.06, 0.94), 0.16,
                                      "sup_extintor_%d" % k, dy=1.30))
        itens.append(modelo_na_parede(s, "korean_fire_extinguisher_01", outro,
                                      min(t + 0.06, 0.94), 0.34,
                                      "extintor_%d" % k))
        itens.append(modelo_na_parede(s, "fire_alarm", lado, max(t - 0.05, 0.04),
                                      0.16, "alarme_%d" % k, dy=1.75))
        if k % 2 == 0:
            itens.append(caixas_na_parede(s, bebedouro(), outro,
                                          max(t - 0.12, 0.05), 0.35,
                                          "bebedouro_%d" % k, bloqueia=(0.5, 0.5)))
        if k % 3 == 1:
            itens.append(modelo_na_parede(s, "wheelchair_01", lado,
                                          min(t + 0.14, 0.95), 0.85,
                                          "cadeira_rodas_%d" % k,
                                          bloqueia=(0.9, 1.2)))
        if k % 3 == 2:
            itens.append(modelo_na_parede(s, "industrial_storage_cart", outro,
                                          min(t + 0.12, 0.95), 0.95,
                                          "carro_%d" % k, bloqueia=(1.2, 1.7)))
        if k % 4 == 3:
            itens.append(modelo_na_parede(s, "WetFloorSign_01", lado, t, 1.30,
                                          "placa_piso_%d" % k))
        if k % 4 == 1:
            itens.append(modelo_na_parede(s, "trashbag", outro, t, 0.55,
                                          "saco_%d" % k))

    # setas penduradas nas pontas
    for t in (0.12, 0.88):
        cxx = (s["x0"] + s["x1"]) * 0.5
        czz = (s["z0"] + s["z1"]) * 0.5
        if largo:
            x = s["x0"] + (s["x1"] - s["x0"]) * t
            z = czz
            giro = 0.0
        else:
            x = cxx
            z = s["z0"] + (s["z1"] - s["z0"]) * t
            giro = math.pi * 0.5
        itens.append(_prop("caixas", s, x, z, giro, pecas=placa_seta(1.8),
                           nome="placa_%d" % int(t * 100), dy=P.PE))

    # camera nas duas pontas, olhando pro corredor
    for t, lado in ((0.05, lados[0]), (0.95, lados[1])):
        itens.append(modelo_na_parede(s, "security_camera_01", lado, t, 0.30,
                                      "camera_%d" % int(t * 100), dy=3.05))
    return itens


RECEITUARIO = {
    "quarto": _quarto, "exame": _exame, "laboratorio": _laboratorio,
    "cirurgia": _cirurgia, "uti": _uti, "emergencia": _emergencia,
    "refeitorio": _refeitorio, "necroterio": _necroterio,
    "farmacia": _farmacia, "esterilizacao": _esterilizacao,
    "maquinas": _maquinas, "arquivo": _arquivo, "psiquiatria": _psiquiatria,
    "terapia": _terapia, "observacao": _observacao, "hall": _hall,
    "saguao": _saguao, "corredor": _corredor,
}


def mobiliar():
    tudo = []
    for e in P.espacos():
        receita = RECEITUARIO.get(e["tipo"])
        if receita is None:
            continue
        tudo.extend(_por(e, receita(e, _dado(e))))
    return tudo


if __name__ == "__main__":
    props = mobiliar()
    print("moveis: %d" % len(props))
    por_tipo = {}
    for p in props:
        por_tipo[p["tipo"]] = por_tipo.get(p["tipo"], 0) + 1
    print("  por especie: %s" % por_tipo)
    modelos = {}
    for p in props:
        if p["tipo"] == "modelo":
            modelos[p["modelo"]] = modelos.get(p["modelo"], 0) + 1
    print("  modelos usados: %d especies" % len(modelos))
    for k in sorted(modelos, key=lambda k: -modelos[k]):
        print("    %-34s x%d" % (k, modelos[k]))
    caixas = sum(len(p["pecas"]) for p in props if p["tipo"].startswith("caixas"))
    print("  caixas de geometria: %d" % caixas)
