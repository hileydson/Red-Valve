"""A mobilia da escola e o entulho do porao: o que tem em cada lugar, e onde.

==============================================================================
DUAS ESPECIES DE MOVEL

1. CAIXARIA (`caixas`) — carteira, lousa, armario de aco, mesa do refeitorio,
   a trave da quadra. Montados aqui, em caixas. Movel de escola e' quase todo
   ortogonal, e resolver em caixa da' controle de centimetro pra encostar a
   coisa na parede — que e' o que faz a sala parecer sala.

2. MODELO (`modelo`) — os .gltf do Poly Haven (CC0). Entram onde caixa nao
   convence: cadeira, estante, engradado, mato, barril.

==============================================================================
A REGRA DE OURO: NADA NO MEIO DO CAMINHO

Foi pedido de novo nesta escola, com todas as letras: "lembre de sempre ter
espaco para o player andar... nada de ter coisa sem sentido atrapalhando vagar
pelo cenario". Entao:

  - TODO movel de corredor nasce encostado numa parede, com `recuo` medido a
    partir dela. O miolo do corredor e' sagrado, de ponta a ponta.
  - O PATIO e' o caso mais delicado, porque e' o maior espaco da cena e nao tem
    parede no meio: la' so' existem a quadra (que e' PINTURA no chao, nao
    obstaculo), as duas traves (nas pontas, fora do caminho) e os bancos, todos
    encostados nos muros. O centro do patio fica vazio de proposito.
  - As excecoes ficam so' em sala grande e sao tres: as carteiras da sala de
    aula (que sao a sala de aula), as mesas do refeitorio e as estantes da
    biblioteca. As tres declaram `bloqueia`, e o navmesh fura a grade ali.

==============================================================================
COMO O MOVEL SABE PRA QUE LADO OLHAR

`parede` e' "n", "s", "l" ou "o", e dai sai o giro: o movel nasce olhando PRA
DENTRO do comodo, de costas pra parede. Um modelo do Poly Haven ainda pode
chegar virado do jeito dele — por isso existe `giro_extra` na tabela MODELOS.
"""

import json
import math
import struct
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import planta as P
import porao as PO

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
DIR_MODELOS = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "polyhaven")

# Giro de cada parede pra que o movel fique de costas pra ela. O eixo "pra
# frente" do movel montado aqui e' o +Z local.
GIRO_PAREDE = {"n": 0.0, "s": math.pi, "l": -math.pi * 0.5, "o": math.pi * 0.5}


# ==========================================================================
# CATALOGO DE MODELOS
# ==========================================================================

MODELOS = {
    # sala de aula / secretaria / biblioteca
    "SchoolChair_01": {"escala": 1.0, "giro_extra": 0.0},
    "plastic_monobloc_chair_01": {"escala": 1.0, "giro_extra": 0.0},
    "painted_wooden_chair_01": {"escala": 1.0, "giro_extra": 0.0},
    "metal_office_desk": {"escala": 1.0, "giro_extra": math.pi},
    "drawer_cabinet": {"escala": 1.0, "giro_extra": 0.0},
    "wooden_bookshelf_worn": {"escala": 1.0, "giro_extra": 0.0},
    "painted_wooden_shelves": {"escala": 1.0, "giro_extra": 0.0},
    "book_encyclopedia_set_01": {"escala": 1.0, "giro_extra": 0.0},
    "binder_notebook": {"escala": 1.0, "giro_extra": 0.0},
    "office_notepads": {"escala": 1.0, "giro_extra": 0.0},
    "stationery_supplies": {"escala": 1.0, "giro_extra": 0.0},
    "clipboard": {"escala": 1.0, "giro_extra": 0.0},
    "wall_clock": {"escala": 1.0, "giro_extra": 0.0},
    "television_02": {"escala": 1.0, "giro_extra": 0.0},
    "round_wooden_table_01": {"escala": 1.0, "giro_extra": 0.0},
    "wooden_stool_01": {"escala": 1.0, "giro_extra": 0.0},
    # laboratorio
    "industrial_microscope": {"escala": 1.0, "giro_extra": 0.0},
    "chemistry_set": {"escala": 1.0, "giro_extra": 0.0},
    "bunsen_burner": {"escala": 1.0, "giro_extra": 0.0},
    # steel_frame_shelves_01 NAO entra: o .gltf dele e' um arquivo MODULAR, com
    # varias variantes da estante lado a lado no mesmo arquivo. A caixa dele
    # tem 11 x 21 x 5 m, e instanciado uma vez ele atravessa tres comodos.
    # Quem confere isso e' `conferir_modelos()`, aqui embaixo.
    "steel_frame_shelves_02": {"escala": 1.0, "giro_extra": 0.0},
    "worn_metal_rack": {"escala": 1.0, "giro_extra": 0.0},
    # corredor e servico
    "korean_fire_extinguisher_01": {"escala": 1.0, "giro_extra": 0.0},
    "fire_alarm": {"escala": 1.0, "giro_extra": 0.0},
    "security_camera_01": {"escala": 1.0, "giro_extra": 0.0},
    "WetFloorSign_01": {"escala": 1.0, "giro_extra": 0.0},
    "plastic_broom": {"escala": 1.0, "giro_extra": 0.0},
    "metal_trash_can": {"escala": 1.0, "giro_extra": 0.0},
    "trashbag": {"escala": 1.0, "giro_extra": 0.0},
    "plastic_crate_01": {"escala": 1.0, "giro_extra": 0.0},
    "plastic_crate_02": {"escala": 1.0, "giro_extra": 0.0},
    "plastic_crate_03": {"escala": 1.0, "giro_extra": 0.0},
    "cardboard_box_01": {"escala": 1.0, "giro_extra": 0.0},
    "wooden_crate_01": {"escala": 1.0, "giro_extra": 0.0},
    "wooden_crate_02": {"escala": 1.0, "giro_extra": 0.0},
    "industrial_storage_cart": {"escala": 1.0, "giro_extra": 0.0},
    "hand_truck": {"escala": 1.0, "giro_extra": 0.0},
    "spray_paint_bottles_02": {"escala": 1.0, "giro_extra": 0.0},
    "utility_box_01": {"escala": 1.0, "giro_extra": 0.0},
    "power_box_01": {"escala": 1.0, "giro_extra": 0.0},
    "cement_bag": {"escala": 1.0, "giro_extra": 0.0},
    "ladder_sectioned_01": {"escala": 1.0, "giro_extra": 0.0},
    "wooden_ladder": {"escala": 1.0, "giro_extra": 0.0},
    # patio
    "painted_wooden_bench": {"escala": 1.0, "giro_extra": 0.0},
    "dirty_football": {"escala": 1.0, "giro_extra": 0.0},
    "old_tyre": {"escala": 1.0, "giro_extra": 0.0},
    "shrub_02": {"escala": 1.0, "giro_extra": 0.0},
    "shrub_03": {"escala": 1.0, "giro_extra": 0.0},
    "shrub_04": {"escala": 1.0, "giro_extra": 0.0},
    "weed_plant_02": {"escala": 1.0, "giro_extra": 0.0},
    "nettle_plant": {"escala": 1.0, "giro_extra": 0.0},
    "planter_box_02": {"escala": 1.0, "giro_extra": 0.0},
    "concrete_road_barrier": {"escala": 1.0, "giro_extra": 0.0},
    "tree_stump_01": {"escala": 1.0, "giro_extra": 0.0},
    "dead_tree_trunk_02": {"escala": 1.0, "giro_extra": 0.0},
    # porao
    "Barrel_02": {"escala": 1.0, "giro_extra": 0.0},
    "barrel_03": {"escala": 1.0, "giro_extra": 0.0},
    "metal_jerrycan": {"escala": 1.0, "giro_extra": 0.0},
    "wooden_bucket_01": {"escala": 1.0, "giro_extra": 0.0},
    "dry_branches_medium_01": {"escala": 1.0, "giro_extra": 0.0},
    "wicker_basket_01": {"escala": 1.0, "giro_extra": 0.0},
    "vintage_oil_lamp": {"escala": 1.0, "giro_extra": 0.0},
    "vintage_suitcase": {"escala": 1.0, "giro_extra": 0.0},
    "plastic_bottle_gallon": {"escala": 1.0, "giro_extra": 0.0},
    "propane_tank": {"escala": 1.0, "giro_extra": 0.0},
    # a carteira de verdade (o par do SchoolChair_01) e o resto da camada de
    # detalhe — ver `detalhes.py`
    "SchoolDesk_01": {"escala": 1.0, "giro_extra": 0.0},
    # As versoes LEVES da carteira e da cadeira (1.300 e 900 triangulos,
    # contra 5.072 e 4.162 do original). Sao ~170 de cada na escola, e cada
    # luar de sala com sombra as desenha de novo: com as originais a vista do
    # corredor passava de 1,2 milhao de primitivas. Feitas no Blender por
    # decimacao (Dissolve + Collapse na carteira, so' Collapse na cadeira de
    # plastico), conferindo a caixa delimitadora contra a original.
    "SchoolDesk_01_leve": {"escala": 1.0, "giro_extra": 0.0},
    "SchoolChair_01_leve": {"escala": 1.0, "giro_extra": 0.0},
    "standing_chalkboard_01": {"escala": 1.0, "giro_extra": 0.0},
    "ceiling_fan": {"escala": 1.0, "giro_extra": 0.0},
    "Television_01": {"escala": 1.0, "giro_extra": 0.0},
    "Megaphone_01": {"escala": 1.0, "giro_extra": 0.0},
    "vintage_stapler": {"escala": 1.0, "giro_extra": 0.0},
    "cassette_player": {"escala": 1.0, "giro_extra": 0.0},
    "filmstrip_projector_8mm": {"escala": 1.0, "giro_extra": 0.0},
    "projector_screen": {"escala": 1.0, "giro_extra": 0.0},
    "desk_lamp_arm_01": {"escala": 1.0, "giro_extra": 0.0},
    "vintage_microscope": {"escala": 1.0, "giro_extra": 0.0},
    "magnifying_glass_01": {"escala": 1.0, "giro_extra": 0.0},
    "plastic_jerrycan": {"escala": 1.0, "giro_extra": 0.0},
    "mousetrap": {"escala": 1.0, "giro_extra": 0.0},
    "picke_dirty_01": {"escala": 1.0, "giro_extra": 0.0},
    "rubber_duck_toy": {"escala": 1.0, "giro_extra": 0.0},
    "alarm_clock_01": {"escala": 1.0, "giro_extra": 0.0},
    "baseball_bat": {"escala": 1.0, "giro_extra": 0.0},
    "plunger": {"escala": 1.0, "giro_extra": 0.0},
    "drain_cleaner": {"escala": 1.0, "giro_extra": 0.0},
    "bleach_bottle": {"escala": 1.0, "giro_extra": 0.0},
    "multi_cleaner_5_litre": {"escala": 1.0, "giro_extra": 0.0},
    "can_rusted": {"escala": 1.0, "giro_extra": 0.0},
    "cigarette_pack": {"escala": 1.0, "giro_extra": 0.0},
    "russian_food_cans_01": {"escala": 1.0, "giro_extra": 0.0},
    "dustpan": {"escala": 1.0, "giro_extra": 0.0},
    "wooden_broom": {"escala": 1.0, "giro_extra": 0.0},
    "fancy_picture_frame_01": {"escala": 1.0, "giro_extra": 0.0},
    "hanging_picture_frame_01": {"escala": 1.0, "giro_extra": 0.0},
}

# Massa (kg) dos FISICOS que nao sao leves como cadeira (o padrao e' 5).
MASSAS = {"SchoolDesk_01": 12.0, "SchoolDesk_01_leve": 12.0}

# Moveis pequenos e soltos: em vez da caixa estatica de `bloqueia`, ganham
# RigidBody3D e reagem a ser esbarrado ou chutado. O entulho do porao tem
# lista propria abaixo, pois troncos continuam fixos no solo.
FISICOS = {
    "SchoolChair_01", "SchoolChair_01_leve", "plastic_monobloc_chair_01",
    # as carteiras tambem (2026-10-29): no meio da sala, empurram igual cadeira
    "SchoolDesk_01", "SchoolDesk_01_leve",
    "painted_wooden_chair_01",
    "wooden_stool_01", "trashbag", "cardboard_box_01",
    "plastic_crate_01", "plastic_crate_02", "plastic_crate_03",
    "dirty_football",
    # o lixo miudo do chao: lata, garrafa, galao. Chutar uma lata vazia num
    # corredor escuro e' metade do clima da escola.
    "can_rusted", "bleach_bottle", "russian_food_cans_01", "plastic_jerrycan",
    "cigarette_pack", "multi_cleaner_5_litre", "drain_cleaner", "dustpan",
    "WetFloorSign_01", "cement_bag", "hand_truck",
    "korean_fire_extinguisher_01", "plastic_broom", "old_tyre",
    "baseball_bat", "plunger", "wooden_broom", "mousetrap", "picke_dirty_01",
}

_aabb_cache = {}


def _pasta(nome):
    """A pasta do modelo — a versao `<nome>_leve` quando ela existe.

    As `_leve` sao decimacoes feitas no Blender dos modelos pesados demais pra
    repetir (moita de 50 mil triangulos x 22 no patio, ventilador de 16 mil x
    14 no teto). Trocar aqui, e nao receita a receita, faz a escola inteira
    usar a leve sem ninguem lembrar de trocar o nome.
    """
    leve = os.path.join(DIR_MODELOS, nome + "_leve")
    if not nome.endswith("_leve") and os.path.isdir(leve):
        return nome + "_leve"
    return nome


def _matriz_do_no(no):
    """Matriz 4x4 (linhas) do no' glTF: `matrix` (colunas) ou T * R * S."""
    if "matrix" in no:
        m = no["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    x, y, z, w = no.get("rotation", [0.0, 0.0, 0.0, 1.0])
    sx, sy, sz = no.get("scale", [1.0, 1.0, 1.0])
    tx, ty, tz = no.get("translation", [0.0, 0.0, 0.0])
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[0][0] * sx, r[0][1] * sy, r[0][2] * sz, tx],
            [r[1][0] * sx, r[1][1] * sy, r[1][2] * sz, ty],
            [r[2][0] * sx, r[2][1] * sy, r[2][2] * sz, tz],
            [0.0, 0.0, 0.0, 1.0]]


def _vezes(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)]
            for i in range(4)]


def _vertices(j, acc, pasta):
    """As posicoes (float32 VEC3) de um accessor, lidas do .bin."""
    vista = j["bufferViews"][acc["bufferView"]]
    buf = j["buffers"][vista["buffer"]]
    with open(os.path.join(pasta, buf["uri"]), "rb") as f:
        f.seek(vista.get("byteOffset", 0) + acc.get("byteOffset", 0))
        passo = vista.get("byteStride", 12)
        dados = f.read(passo * (acc["count"] - 1) + 12)
    return [struct.unpack_from("<3f", dados, i * passo)
            for i in range(acc["count"])]


def aabb(nome):
    """(min, max) do .gltf, lido direto dos accessors — sem abrir o Blender.

    Os accessors guardam o vertice no espaco da MALHA; o Godot importa com a
    transformacao dos nos aplicada. A lixeira de metal vem girada ~105 graus
    dentro do arquivo: lida crua, a "base" dava 1,05 m abaixo da origem e ela
    subia isso, flutuando no corredor. Entao cada no' leva a caixa da malha
    dele (os 8 cantos) pelo caminho de matrizes ate' a raiz da cena."""
    if nome in _aabb_cache:
        return _aabb_cache[nome]
    pasta = os.path.join(DIR_MODELOS, _pasta(nome))
    arquivo = None
    for f in sorted(os.listdir(pasta)):
        if f.endswith(".gltf"):
            arquivo = os.path.join(pasta, f)
            break
    j = json.load(open(arquivo))
    mn = [1e9] * 3
    mx = [-1e9] * 3

    def descer(indice, pai):
        no = j["nodes"][indice]
        m = _vezes(pai, _matriz_do_no(no))
        if "mesh" in no:
            # sem giro "torto" os 8 cantos bastam; girado, a caixa dos cantos
            # incha (a lixeira dava 2 m de largura) e e' preciso ler os vertices
            reto = all(sum(1 for c in range(3) if abs(m[k][c]) > 1e-6) == 1
                       for k in range(3))
            for prim in j["meshes"][no["mesh"]].get("primitives", []):
                acc = j["accessors"][prim["attributes"]["POSITION"]]
                if reto:
                    pontos = [(cx, cy, cz)
                              for cx in (acc["min"][0], acc["max"][0])
                              for cy in (acc["min"][1], acc["max"][1])
                              for cz in (acc["min"][2], acc["max"][2])]
                else:
                    pontos = _vertices(j, acc, os.path.dirname(arquivo))
                for (cx, cy, cz) in pontos:
                    for k in range(3):
                        v = (m[k][0] * cx + m[k][1] * cy
                             + m[k][2] * cz + m[k][3])
                        mn[k] = min(mn[k], v)
                        mx[k] = max(mx[k], v)
        for filho in no.get("children", []):
            descer(filho, m)

    identidade = [[1.0 if i == k else 0.0 for k in range(4)] for i in range(4)]
    for raiz in j["scenes"][j.get("scene", 0)]["nodes"]:
        descer(raiz, identidade)
    _aabb_cache[nome] = (mn, mx)
    return _aabb_cache[nome]


def caminho(nome):
    nome = _pasta(nome)
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

def carteira():
    """Carteira escolar de tampo inclinado, com a cadeira presa nela.

    Cadeira presa e nao solta: solta, ela precisaria de uma segunda peca e de
    um segundo giro por carteira, e trinta carteiras viram sessenta nos. Presa,
    a fileira inteira e' UMA geometria repetida — e e' assim que carteira de
    escola publica e' de verdade.
    """
    p = []
    # tampo (levemente inclinado e' caixa demais; aqui e' plano, com borda)
    p.append((0.0, 0.73, -0.02, 0.62, 0.035, 0.46, "mat_formica"))
    p.append((0.0, 0.70, -0.24, 0.62, 0.05, 0.04, "mat_madeira"))
    # prateleira de livro embaixo do tampo
    p.append((0.0, 0.56, -0.04, 0.54, 0.02, 0.36, "mat_madeira_clara"))
    for ex in (-0.27, 0.27):
        p.append((ex, 0.37, -0.02, 0.035, 0.72, 0.035, "mat_metal_claro"))
        p.append((ex, 0.02, -0.02, 0.05, 0.04, 0.42, "mat_metal_escuro"))
    # assento e encosto
    p.append((0.0, 0.45, 0.30, 0.42, 0.04, 0.38, "mat_madeira_clara"))
    p.append((0.0, 0.66, 0.48, 0.42, 0.28, 0.035, "mat_madeira_clara"))
    for ex in (-0.19, 0.19):
        p.append((ex, 0.23, 0.32, 0.03, 0.44, 0.03, "mat_metal_claro"))
    return p


def mesa_professor():
    return [(0.0, 0.74, 0.0, 1.40, 0.06, 0.70, "mat_madeira"),
            (0.0, 0.36, -0.28, 1.34, 0.70, 0.10, "mat_madeira"),
            (-0.52, 0.36, 0.0, 0.34, 0.70, 0.64, "mat_madeira"),
            (0.62, 0.36, 0.0, 0.06, 0.70, 0.64, "mat_madeira")]


def lousa(largura=4.20, altura=1.25):
    """O quadro-negro. Pendurado: quem chama passa `dy`.

    E' a unica coisa que toda sala de aula tem e que nenhum outro comodo tem —
    e' por ele que o jogador sabe, de relance pela porta, o que aquela sala e'.
    """
    p = [(0.0, 0.0, 0.0, largura, altura, 0.06, "mat_lousa"),
         (0.0, 0.0, -0.04, largura + 0.12, altura + 0.12, 0.05, "mat_madeira"),
         (0.0, -altura * 0.5 - 0.06, 0.06, largura, 0.05, 0.10, "mat_madeira")]
    # restos de giz na calha e um risco no canto
    p.append((-largura * 0.5 + 0.30, -altura * 0.5 - 0.02, 0.08,
              0.10, 0.03, 0.03, "mat_giz"))
    return p


def armario_aco(largura=0.92, altura=1.98, portas=2):
    p = [(0.0, altura * 0.5, 0.0, largura, altura, 0.46, "mat_metal_claro")]
    for i in range(portas):
        t = (i + 0.5) / portas - 0.5
        p.append((t * largura, altura * 0.5, 0.24,
                  largura / portas - 0.04, altura - 0.08, 0.02,
                  "mat_metal_escuro"))
        p.append((t * largura + largura / portas * 0.32, altura * 0.5, 0.27,
                  0.04, 0.16, 0.04, "mat_inox"))
    return p


def estante(largura=1.80, altura=2.10, profundidade=0.42, andares=5):
    p = []
    for lado in (-1, 1):
        for fundo in (-1, 1):
            p.append((lado * (largura * 0.5 - 0.03), altura * 0.5,
                      fundo * (profundidade * 0.5 - 0.03),
                      0.05, altura, 0.05, "mat_metal_escuro"))
    for i in range(andares):
        y = 0.16 + i * (altura - 0.24) / max(andares - 1, 1)
        p.append((0.0, y, 0.0, largura - 0.04, 0.035, profundidade - 0.04,
                  "mat_metal_claro"))
    return p


def estante_com_livros(variante, largura=2.60, altura=2.10, profundidade=0.48,
                       andares=5):
    """A estante de aco da biblioteca, cheia — e com os buracos de quem levou.

    Tres variantes (pela semente) e nao uma por estante: cada estante distinta
    vira um .gltf proprio, e trinta mil lombadas diferentes nao compram nada
    que tres nao comprem. Os livros entram nas DUAS faces, porque a estante
    fica no meio da sala e e' vista dos dois corredores.
    """
    import detalhes as DET
    d = random.Random("estante/%d" % (variante % 3))
    p = estante(largura, altura, profundidade, andares)
    for i in range(andares - 1):
        y = 0.16 + i * (altura - 0.24) / max(andares - 1, 1) + 0.018
        for lado in (-1, 1):
            for q in DET.livros_na_prateleira(d, largura - 0.06, y, profundidade * 0.5,
                                              0.82 if i < 3 else 0.55):
                p.append((q[0], q[1], lado * profundidade * 0.25, q[3], q[4], q[5],
                          q[6]))
    return p


def bancada(largura, profundidade=0.66, altura=0.90):
    return [(0.0, altura - 0.03, 0.0, largura, 0.06, profundidade, "mat_formica"),
            (0.0, (altura - 0.06) * 0.5 + 0.08, -0.03, largura - 0.06,
             altura - 0.20, profundidade - 0.08, "mat_madeira"),
            (0.0, 0.06, -0.03, largura - 0.12, 0.12, profundidade - 0.16,
             "mat_metal_escuro")]


def pia_bancada(largura=1.60):
    p = bancada(largura, 0.62, 0.90)
    p.append((0.0, 0.84, 0.02, largura - 0.55, 0.10, 0.42, "mat_inox"))
    p.append((0.0, 1.12, -0.22, 0.05, 0.36, 0.05, "mat_inox"))
    return p


def mesa_refeitorio(largura=2.60):
    """Mesa de refeitorio com os dois bancos presos — o modelo escolar."""
    p = [(0.0, 0.74, 0.0, largura, 0.06, 0.78, "mat_formica")]
    for ex in (-largura * 0.5 + 0.22, largura * 0.5 - 0.22):
        p.append((ex, 0.37, 0.0, 0.08, 0.72, 0.60, "mat_metal_claro"))
    for dz in (-0.62, 0.62):
        p.append((0.0, 0.45, dz, largura - 0.20, 0.05, 0.30, "mat_madeira_clara"))
        for ex in (-largura * 0.5 + 0.30, largura * 0.5 - 0.30):
            p.append((ex, 0.22, dz, 0.06, 0.44, 0.06, "mat_metal_claro"))
    return p


def balcao(largura, profundidade=0.70, altura=1.05):
    return [(0.0, altura * 0.5 - 0.04, 0.0, largura, altura - 0.08,
             profundidade, "mat_madeira"),
            (0.0, altura - 0.03, 0.04, largura + 0.10, 0.07,
             profundidade + 0.16, "mat_formica"),
            (0.0, 0.06, 0.0, largura - 0.06, 0.12, profundidade - 0.10,
             "mat_metal_escuro")]


def mural(largura=2.40, altura=1.10):
    """Mural de cortica do corredor, com papel velho pregado."""
    p = [(0.0, 0.0, 0.0, largura, altura, 0.05, "mat_madeira"),
         (0.0, 0.0, 0.03, largura - 0.10, altura - 0.10, 0.02, "mat_formica")]
    for (t, h) in ((-0.30, 0.34), (0.05, 0.26), (0.32, 0.30)):
        p.append((t * largura, 0.06, 0.05, 0.24, h, 0.006, "mat_papel"))
    return p


def bebedouro():
    return [(0.0, 0.52, 0.0, 0.46, 1.04, 0.36, "mat_metal_claro"),
            (0.0, 1.06, 0.02, 0.50, 0.05, 0.40, "mat_inox"),
            (0.0, 1.16, -0.06, 0.04, 0.16, 0.04, "mat_inox")]


# Onde o NOME da ala e' escrito na placa pendurada (relativo ao forro). Quem
# escreve e' `gerar_cena_escola._placas`, dos dois lados.
PLACA_TEXTO_Y = -0.27


def placa_seta(comprimento=1.60):
    """Placa pendurada no forro: o nome da ala em cima, a faixa verde embaixo,
    nas duas faces (ela e' vista chegando e voltando)."""
    return [(0.0, -0.32, 0.0, comprimento, 0.44, 0.03, "mat_placa"),
            (0.0, -0.475, 0.0, comprimento - 0.24, 0.07, 0.042, "mat_seta"),
            (-comprimento * 0.38, -0.05, 0.0, 0.03, 0.10, 0.03, "mat_metal_escuro"),
            (comprimento * 0.38, -0.05, 0.0, 0.03, 0.10, 0.03, "mat_metal_escuro")]


def extintor_suporte():
    return [(0.0, 0.0, 0.0, 0.30, 0.04, 0.16, "mat_metal_escuro")]


# --------------------------------------------------------------------------
# a quadra
# --------------------------------------------------------------------------

def trave(vao=3.00, altura=2.00):
    """Trave de futsal, montada em torno do MEIO da linha de fundo.

    Sem rede fechada: rede de verdade e' malha, e malha em caixa vira uma
    chapa. Aqui ela e' sugerida por dois panos verticais nas laterais, que e'
    o que se ve de longe de qualquer jeito.
    """
    t = 0.09
    p = [(0.0, altura, 0.0, vao + t, t, t, "mat_trave")]
    for ex in (-vao * 0.5, vao * 0.5):
        p.append((ex, altura * 0.5, 0.0, t, altura, t, "mat_trave"))
        p.append((ex, altura * 0.5, 0.45, 0.015, altura, 0.90, "mat_rede"))
    p.append((0.0, altura - 0.02, 0.45, vao, 0.015, 0.90, "mat_rede"))
    return p


def banco_concreto(largura=1.90):
    """Banco de concreto do patio. Baixo e sem encosto — o de escola."""
    return [(0.0, 0.42, 0.0, largura, 0.10, 0.46, "mat_formica"),
            (-largura * 0.5 + 0.22, 0.19, 0.0, 0.14, 0.38, 0.40, "mat_placa"),
            (largura * 0.5 - 0.22, 0.19, 0.0, 0.14, 0.38, 0.40, "mat_placa")]


# ==========================================================================
# COLOCACAO
# ==========================================================================

def _lugar_na_parede(s, parede, t, recuo):
    x0, x1, z0, z1 = s["x0"], s["x1"], s["z0"], s["z1"]
    if parede == "n":
        return (x0 + (x1 - x0) * t, z0 + recuo)
    if parede == "s":
        return (x0 + (x1 - x0) * t, z1 - recuo)
    if parede == "o":
        return (x0 + recuo, z0 + (z1 - z0) * t)
    return (x1 - recuo, z0 + (z1 - z0) * t)


def _prop(tipo, sala, x, z, giro, **extra):
    d = {"tipo": tipo, "sala": sala["ident"], "x": x,
         "y": P.cota(), "z": z, "giro": giro, "bloqueia": None}
    d.update(extra)
    # `bloqueia` chega em medidas LOCAIS do movel (largura x profundidade).
    # Girado 90 graus, largura vira profundidade — e e' a pegada em
    # coordenadas de MUNDO que o navmesh precisa furar.
    if d.get("bloqueia"):
        lx, lz = d["bloqueia"]
        if abs(math.cos(giro)) < 0.5:
            d["bloqueia"] = (lz, lx)
    # Item da lista FISICOS: a caixa de colisao sai direto do AABB do .gltf, ja'
    # no tamanho e centro certos. Ganha corpo fisico PROPRIO, entao a caixa
    # estatica de `bloqueia` fica sem sentido aqui (os dois no mesmo lugar so'
    # travariam um no outro).
    if d.get("modelo") in FISICOS:
        mn, mx = aabb(d["modelo"])
        esc = d.get("escala", 1.0)
        d["fisico"] = True
        d["fisico_caixa"] = tuple((mx[k] - mn[k]) * esc for k in range(3))
        d["fisico_centro"] = tuple((mn[k] + mx[k]) * 0.5 * esc for k in range(3))
        d["dy"] = max(d.get("dy", 0.0), -mn[1] * esc)
        d["bloqueia"] = None
        if d.get("modelo") in MASSAS:
            d["massa"] = MASSAS[d["modelo"]]
    return d


def _topo(nome_modelo):
    """Altura do tampo do modelo, ja' assentado no chao (ver `apoio`)."""
    mn, mx = aabb(nome_modelo)
    esc = MODELOS[nome_modelo]["escala"]
    return (mx[1] - mn[1]) * esc


def caixas_na_parede(s, pecas, parede, t, recuo, nome, bloqueia=None, dy=0.0):
    x, z = _lugar_na_parede(s, parede, t, recuo)
    return _prop("caixas", s, x, z, GIRO_PAREDE[parede], pecas=pecas,
                 nome=nome, bloqueia=bloqueia, dy=dy, na_parede=parede)


def apoio(nome_modelo, escala=1.0):
    """Quanto levantar o modelo pra a BASE dele ficar em y = 0.

    Nem todo .gltf do Poly Haven vem com a origem no chao: o contentor de lixo
    tem a origem 1,05 m acima da base e a escada 1,10 m. Posto em y = 0 do
    jeito que vem, metade da peca fica enterrada no piso. Como isto e' uma
    propriedade do ARQUIVO, e nao da receita, ele sai lido do proprio .gltf em
    vez de digitado peca a peca.

    So' LEVANTA, nunca abaixa: modelo com a base acima da origem esta' assim de
    proposito (a luminaria de teto, por exemplo).
    """
    mn, _mx = aabb(nome_modelo)
    return max(0.0, -mn[1]) * escala


def modelo_na_parede(s, nome_modelo, parede, t, recuo, nome, bloqueia=None,
                     dy=0.0, escala=None, giro_extra=None):
    x, z = _lugar_na_parede(s, parede, t, recuo)
    info = MODELOS[nome_modelo]
    giro = GIRO_PAREDE[parede] + (info["giro_extra"] if giro_extra is None
                                  else giro_extra)
    esc = info["escala"] if escala is None else escala
    return _prop("modelo", s, x, z, giro, modelo=nome_modelo, nome=nome,
                 bloqueia=bloqueia, na_parede=parede, dy=dy + apoio(nome_modelo, esc),
                 escala=esc)


def caixas_solto(s, pecas, x, z, giro, nome, bloqueia=None, dy=0.0):
    return _prop("caixas", s, x, z, giro, pecas=pecas, nome=nome,
                 bloqueia=bloqueia, dy=dy)


def modelo_solto(s, nome_modelo, x, z, giro, nome, bloqueia=None, dy=0.0,
                 escala=None):
    info = MODELOS[nome_modelo]
    esc = info["escala"] if escala is None else escala
    return _prop("modelo", s, x, z, giro + info["giro_extra"],
                 modelo=nome_modelo, nome=nome, bloqueia=bloqueia,
                 dy=dy + apoio(nome_modelo, esc), escala=esc)


def _dado(s):
    """Semente derivada do nome: duas salas nao ficam identicas, mas a MESMA
    sala fica igual toda vez que o gerador roda — senao o jogador perde a
    referencia visual a cada build."""
    return random.Random("escola/" + s["ident"])


_CACHE_PORTAS = None


def _portas():
    global _CACHE_PORTAS
    if _CACHE_PORTAS is None:
        pts = []
        for m in P.muros():
            for v in m["vaos"]:
                if v["tipo"] not in ("porta", "passagem", "buraco"):
                    continue
                if m["eixo"] == "x":
                    pts.append((v["c"], m["coord"], v["l"]))
                else:
                    pts.append((m["coord"], v["c"], v["l"]))
        _CACHE_PORTAS = pts
    return _CACHE_PORTAS


def livre_de_porta(x, z, folga=2.1):
    """Movel nao pode nascer em frente a porta nenhuma — nem em frente aos
    buracos, que sao a coisa mais importante desta escola de se achar."""
    for (px, pz, l) in _portas():
        if abs(x - px) < l * 0.5 + folga and abs(z - pz) < folga + 0.8:
            return False
    return True


def livre_da_grade(x, z, folga=2.6):
    """E nem colado na grade: o jogador precisa chegar nela e ver que nao
    passa, sem um armario no meio sugerindo que o caminho e' outro."""
    return not (abs(x - P.GRADE_X) < folga
                and P.GRADE_Z0 - 1.0 <= z <= P.GRADE_Z1 + 1.0)


def _por(s, lista):
    return [p for p in lista
            if p is not None and livre_de_porta(p["x"], p["z"])
            and livre_da_grade(p["x"], p["z"])
            and not (p.get("na_parede") and _parede_falta(s, p))]


# ==========================================================================
# O QUE VAI EM CADA COMODO
# ==========================================================================

def _sala_aula(s, d):
    """Sala de aula: lousa numa ponta, fileiras de carteira, corredor no meio.

    As fileiras deixam um vao central livre de proposito — e' por ele que o
    jogador atravessa a sala sem esbarrar em nada.
    """
    itens = []
    largo = (s["x1"] - s["x0"]) >= (s["z1"] - s["z0"])
    # a lousa vai na parede CURTA oposta a' porta; as fileiras olham pra ela
    parede_lousa = "o" if largo else "n"
    itens.append(caixas_na_parede(s, lousa(), parede_lousa, 0.5, 0.10,
                                  "lousa", dy=1.55))
    itens.append(caixas_na_parede(s, mesa_professor(), parede_lousa, 0.5, 1.30,
                                  "mesa_prof", bloqueia=(1.5, 0.8)))
    itens.append(modelo_na_parede(s, "SchoolChair_01_leve", parede_lousa, 0.5, 2.15,
                                  "cadeira_prof", giro_extra=math.pi))

    # as carteiras: colunas ao longo do eixo longo, deixando um vao no meio.
    #
    # Carteira e cadeira sao os dois modelos do Poly Haven (SchoolDesk_01 +
    # SchoolChair_01), e nao mais a caixaria: de perto, a carteira de caixa era
    # o que mais denunciava a escola como cenario. Os dois nascem olhando pro
    # +Z local (o aluno olha a lousa); a cadeira fica 0,62 m ATRAS da carteira,
    # longe o bastante pra o corpo fisico dela nao nascer dentro da caixa de
    # colisao da carteira — encostados, os dois se empurravam no primeiro
    # quadro e a cadeira voava.
    x0, x1, z0, z1 = s["x0"] + 1.6, s["x1"] - 1.4, s["z0"] + 1.4, s["z1"] - 1.4
    if largo:
        colunas = [z0 + (z1 - z0) * f for f in (0.14, 0.34, 0.66, 0.86)]
        fileiras = [x0 + i * 1.55 for i in range(int((x1 - x0) / 1.55))]
        giro = -math.pi * 0.5 if parede_lousa == "o" else math.pi * 0.5
    else:
        colunas = [x0 + (x1 - x0) * f for f in (0.14, 0.34, 0.66, 0.86)]
        fileiras = [z0 + i * 1.55 for i in range(int((z1 - z0) / 1.55))]
        giro = 0.0
    n = 0
    for c in colunas:
        for f in fileiras:
            x, z = (f, c) if largo else (c, f)
            n += 1
            # uma carteira em cada sete sumiu — sala vazia com tudo alinhado
            # parece cenario, nao lugar abandonado
            if d.random() < 0.14:
                continue
            g = giro + (d.uniform(-0.45, 0.45) if d.random() < 0.3 else 0.0)
            itens.append(modelo_solto(s, "SchoolDesk_01_leve", x, z, g,
                                      "carteira_%d" % n, bloqueia=(0.62, 0.48)))
            sorte = d.random()
            if sorte < 0.12:
                continue                     # a cadeira foi parar em outro lugar
            gc = g + (d.uniform(-0.9, 0.9) if sorte < 0.35 else d.uniform(-0.1, 0.1))
            recuo = 0.62 + (d.uniform(0.1, 0.5) if sorte < 0.35 else 0.0)
            cx = x - math.sin(g) * recuo
            cz = z - math.cos(g) * recuo
            cadeira = modelo_solto(s, "SchoolChair_01_leve", cx, cz, gc,
                                   "cadeira_%d" % n)
            if sorte > 0.88:
                # tombada de costas: o corpo fisico assenta sozinho no chao
                cadeira["incl"] = -math.pi * 0.5
                cadeira["dy"] = cadeira.get("dy", 0.0) + 0.36
            itens.append(cadeira)

    itens.append(modelo_na_parede(s, "wall_clock", parede_lousa, 0.14, 0.12,
                                  "relogio", dy=2.60))
    lado = "s" if largo else "l"
    itens.append(caixas_na_parede(s, armario_aco(), lado, 0.10, 0.30,
                                  "armario", bloqueia=(1.0, 0.6)))
    # (o lixo da sala e' o cesto pequeno de `detalhes.py`: o metal_trash_can e'
    # um PAR de latoes de rua de 1,30 m, que dentro da sala de aula nao cabe)
    return itens


def _secretaria(s, d):
    itens = [
        caixas_na_parede(s, balcao(3.60), "s", 0.32, 1.40, "balcao",
                         bloqueia=(3.8, 1.0)),
        modelo_na_parede(s, "metal_office_desk", "n", 0.26, 1.30, "mesa_1",
                         bloqueia=(1.7, 1.0)),
        modelo_na_parede(s, "metal_office_desk", "n", 0.56, 1.30, "mesa_2",
                         bloqueia=(1.7, 1.0)),
        modelo_na_parede(s, "SchoolChair_01_leve", "n", 0.26, 2.30, "cadeira_1",
                         giro_extra=math.pi),
        modelo_na_parede(s, "SchoolChair_01_leve", "n", 0.56, 2.30, "cadeira_2",
                         giro_extra=math.pi),
        modelo_na_parede(s, "drawer_cabinet", "l", 0.30, 0.42, "gaveteiro_1"),
        modelo_na_parede(s, "drawer_cabinet", "l", 0.55, 0.42, "gaveteiro_2"),
        caixas_na_parede(s, estante(1.8, 2.1, 0.42, 5), "o", 0.35, 0.30,
                         "arquivo_1", bloqueia=(1.9, 0.5)),
        caixas_na_parede(s, estante(1.8, 2.1, 0.42, 5), "o", 0.65, 0.30,
                         "arquivo_2", bloqueia=(1.9, 0.5)),
        modelo_na_parede(s, "office_notepads", "n", 0.26, 1.30, "papel",
                         dy=0.76),
        modelo_na_parede(s, "wall_clock", "n", 0.80, 0.12, "relogio", dy=2.60),
        # a TV de tubo em cima do 2o gaveteiro (pendurada a 1,10 m na parede
        # ela flutuava: aparelho de tubo nao tem suporte de parede)
        modelo_na_parede(s, "television_02", "l", 0.55, 0.42, "tv",
                         dy=_topo("drawer_cabinet")),
    ]
    return itens


def _refeitorio(s, d):
    itens = [
        caixas_na_parede(s, balcao(5.20), "s", 0.50, 1.20, "balcao",
                         bloqueia=(5.4, 1.1)),
        caixas_na_parede(s, pia_bancada(2.20), "l", 0.22, 0.45, "pia",
                         bloqueia=(2.3, 0.7)),
        caixas_na_parede(s, bancada(3.00), "l", 0.62, 0.45, "bancada",
                         bloqueia=(3.1, 0.7)),
        modelo_na_parede(s, "worn_metal_rack", "s", 0.86, 0.45, "prateleira"),
        modelo_na_parede(s, "metal_trash_can", "o", 0.86, 0.60, "lixo",
                         bloqueia=(0.6, 0.6)),
    ]
    # as mesas: duas fileiras no miolo, com passagem larga entre elas
    cx = (s["x0"] + s["x1"]) * 0.5
    for i, dz in enumerate((-3.6, 0.0, 3.6)):
        for j, dx in enumerate((-6.5, 0.0, 6.5)):
            itens.append(caixas_solto(s, mesa_refeitorio(), cx + dx,
                                      (s["z0"] + s["z1"]) * 0.5 + dz - 1.0,
                                      0.0, "mesa_%d_%d" % (i, j),
                                      bloqueia=(2.8, 1.6)))
    return itens


def _biblioteca(s, d):
    """Biblioteca: estantes paralelas, com os corredores entre elas livres."""
    itens = []
    z = s["z0"] + 2.6
    n = 0
    while z < s["z1"] - 2.4:
        for lado, t in (("o", 0.28), ("l", 0.72)):
            x, _z = _lugar_na_parede(s, lado, 0.5, 0.0)
            px = s["x0"] + (s["x1"] - s["x0"]) * t
            n += 1
            itens.append(caixas_solto(s, estante_com_livros(n), px, z,
                                      math.pi * 0.5, "estante_%d" % n,
                                      bloqueia=(0.6, 2.7)))
        z += 3.4
    itens.append(modelo_na_parede(s, "wooden_bookshelf_worn", "n", 0.30, 0.40,
                                  "armario_livros"))
    itens.append(modelo_na_parede(s, "round_wooden_table_01", "n", 0.70, 2.20,
                                  "mesa_leitura", bloqueia=(1.3, 1.3)))
    for t in (0.62, 0.78):
        itens.append(modelo_na_parede(s, "wooden_stool_01", "n", t, 1.30,
                                      "banquinho_%d" % int(t * 100)))
    itens.append(modelo_na_parede(s, "book_encyclopedia_set_01", "s", 0.30,
                                  0.55, "livros_chao"))
    return itens


def _laboratorio(s, d):
    itens = [
        caixas_na_parede(s, pia_bancada(2.40), "o", 0.22, 0.45, "pia",
                         bloqueia=(0.8, 2.5)),
        caixas_na_parede(s, bancada(4.00), "o", 0.66, 0.45, "bancada_o",
                         bloqueia=(0.8, 4.1)),
        caixas_na_parede(s, bancada(4.00), "l", 0.40, 0.45, "bancada_l",
                         bloqueia=(0.8, 4.1)),
        caixas_na_parede(s, lousa(3.0, 1.1), "n", 0.5, 0.10, "lousa", dy=1.55),
        modelo_na_parede(s, "steel_frame_shelves_02", "s", 0.30, 0.45,
                         "prateleira_1"),
        modelo_na_parede(s, "worn_metal_rack", "s", 0.70, 0.45,
                         "prateleira_2"),
        modelo_na_parede(s, "industrial_microscope", "o", 0.66, 0.60,
                         "microscopio", dy=0.90),
        modelo_na_parede(s, "chemistry_set", "l", 0.40, 0.60, "quimica",
                         dy=0.90),
        modelo_na_parede(s, "bunsen_burner", "l", 0.52, 0.60, "bico",
                         dy=0.90),
    ]
    # duas bancadas de ilha, no eixo longo, com folga dos dois lados
    cx = (s["x0"] + s["x1"]) * 0.5
    for i, f in enumerate((0.34, 0.62)):
        z = s["z0"] + (s["z1"] - s["z0"]) * f
        itens.append(caixas_solto(s, bancada(5.00, 1.10, 0.90), cx, z,
                                  math.pi * 0.5, "ilha_%d" % i,
                                  bloqueia=(1.2, 5.1)))
    return itens


def _servico(s, d):
    """Almoxarifado e deposito: prateleira na parede, engradado no chao.

    Os dois sao as salas dos BURACOS, e por isso sao os dois comodos em que
    mais importa manter o chao limpo: o jogador tem de ver o rombo da porta.
    `livre_de_porta` ja' conta o buraco como porta, entao isso sai sozinho.
    """
    itens = []
    modelos_caixa = ("plastic_crate_01", "plastic_crate_02", "plastic_crate_03",
                     "cardboard_box_01", "wooden_crate_01", "wooden_crate_02")
    for i, t in enumerate((0.16, 0.38, 0.60, 0.82)):
        itens.append(caixas_na_parede(s, estante(2.00, 2.10, 0.48, 4), "s", t,
                                      0.36, "prateleira_%d" % i,
                                      bloqueia=(2.1, 0.6)))
    for i, t in enumerate((0.22, 0.48, 0.74)):
        itens.append(modelo_na_parede(s, modelos_caixa[i % len(modelos_caixa)],
                                      "n", t, 0.70, "caixa_%d" % i,
                                      bloqueia=(0.8, 0.8)))
    # as altas vao EMPILHADAS nas de baixo (mesmo t, no tampo delas): com t
    # proprio e dy fixo de 0,45 a primeira nascia no ar e despencava
    for i, t in enumerate((0.22, 0.48)):
        itens.append(modelo_na_parede(s, modelos_caixa[(i + 3) % 6], "n", t,
                                      0.70, "caixa_alta_%d" % i,
                                      dy=_topo(modelos_caixa[i % len(modelos_caixa)])))
    itens.append(modelo_na_parede(s, "hand_truck", "o", 0.30, 0.55, "carrinho",
                                  bloqueia=(0.8, 0.8)))
    itens.append(modelo_na_parede(s, "plastic_broom", "o", 0.60, 0.30,
                                  "vassoura"))
    itens.append(modelo_na_parede(s, "cement_bag", "l", 0.24, 0.60, "cimento"))
    itens.append(modelo_na_parede(s, "wooden_ladder", "l", 0.60, 0.35,
                                  "escada"))
    itens.append(modelo_na_parede(s, "power_box_01", "l", 0.85, 0.16,
                                  "quadro_luz", dy=1.50))
    itens.append(modelo_na_parede(s, "trashbag", "o", 0.86, 0.60, "saco"))
    return itens


def _corredor(s, d):
    """Corredor: so' o que fica RENTE a parede. O miolo e' sagrado."""
    itens = []
    largo = (s["x1"] - s["x0"]) >= (s["z1"] - s["z0"])
    lados = ("n", "s") if largo else ("o", "l")
    comprimento = max(s["x1"] - s["x0"], s["z1"] - s["z0"])
    quantos = max(int(comprimento / 9.0), 1)

    for k in range(quantos):
        t = (k + 0.5) / quantos
        lado = lados[k % 2]
        outro = lados[(k + 1) % 2]
        # o armario de aco: o objeto que define corredor de escola
        x, z = _lugar_na_parede(s, lado, t, 0.32)
        if livre_de_porta(x, z, 2.4) and livre_da_grade(x, z):
            itens.append(caixas_na_parede(s, armario_aco(2.70, 1.98, 6), lado,
                                          t, 0.32, "armarios_%d" % k,
                                          bloqueia=(2.8, 0.6)))
        # recuo 0,03: o fundo do mural (5 cm) encosta na parede — com 0,10 ele
        # ficava 7 cm no ar (2026-10-29)
        itens.append(caixas_na_parede(s, mural(), outro, min(t + 0.04, 0.95),
                                      0.03, "mural_%d" % k, dy=1.70))
        itens.append(caixas_na_parede(s, extintor_suporte(), outro,
                                      max(t - 0.05, 0.04), 0.16,
                                      "sup_extintor_%d" % k, dy=1.30))
        itens.append(modelo_na_parede(s, "korean_fire_extinguisher_01", outro,
                                      max(t - 0.05, 0.04), 0.34,
                                      "extintor_%d" % k))
        itens.append(modelo_na_parede(s, "fire_alarm", lado,
                                      min(t + 0.07, 0.96), 0.16,
                                      "alarme_%d" % k, dy=1.85))
        if k % 2 == 0:
            itens.append(caixas_na_parede(s, bebedouro(), outro,
                                          max(t - 0.10, 0.05), 0.32,
                                          "bebedouro_%d" % k,
                                          bloqueia=(0.5, 0.5)))
        if k % 3 == 1:
            # o modelo sao DUAS latas com as tampas: 1,8 m ao longo da parede
            itens.append(modelo_na_parede(s, "metal_trash_can", lado,
                                          min(t + 0.11, 0.95), 0.45,
                                          "lixo_%d" % k, bloqueia=(1.9, 0.6)))
        if k % 3 == 2:
            itens.append(modelo_na_parede(s, "SchoolChair_01_leve", outro,
                                          min(t + 0.10, 0.95), 0.60,
                                          "cadeira_%d" % k))
        if k % 4 == 3:
            itens.append(modelo_na_parede(s, "WetFloorSign_01", lado, t, 1.10,
                                          "placa_piso_%d" % k))
        if k % 5 == 1:
            itens.append(modelo_na_parede(s, "trashbag", outro, t, 0.50,
                                          "saco_%d" % k))

    for t in (0.10, 0.90):
        cxx = (s["x0"] + s["x1"]) * 0.5
        czz = (s["z0"] + s["z1"]) * 0.5
        if largo:
            x, z, giro = s["x0"] + (s["x1"] - s["x0"]) * t, czz, 0.0
        else:
            x, z, giro = cxx, s["z0"] + (s["z1"] - s["z0"]) * t, math.pi * 0.5
        itens.append(_prop("caixas", s, x, z, giro, pecas=placa_seta(1.7),
                           nome="placa_%d" % int(t * 100), dy=P.PE))

    for t, lado in ((0.05, lados[0]), (0.95, lados[1])):
        itens.append(modelo_na_parede(s, "security_camera_01", lado, t, 0.30,
                                      "camera_%d" % int(t * 100), dy=3.00))
    itens = [p for p in itens if p is None or not _parede_falta(s, p)]
    return _sem_sobrepor(itens)


def _sem_sobrepor(itens):
    """Tira a peca de chao que bate numa ja' posta (pela pegada `bloqueia`).

    O passo do corredor poe a lixeira de um k e o bebedouro do k seguinte na
    MESMA parede; no corredor leste eles caiam a 47 cm um do outro e o
    bebedouro atravessava as latas (2026-10-29). Fica a que veio primeiro."""
    postos = []
    saida = []
    for p in itens:
        if p is None or not p.get("bloqueia"):
            saida.append(p)
            continue
        lx, lz = p["bloqueia"]
        caixa = (p["x"] - lx * 0.5, p["x"] + lx * 0.5,
                 p["z"] - lz * 0.5, p["z"] + lz * 0.5)
        if any(caixa[0] < o[1] and o[0] < caixa[1] and
               caixa[2] < o[3] and o[2] < caixa[3] for o in postos):
            continue
        postos.append(caixa)
        saida.append(p)
    return saida


# Meia extensao, ao longo da parede, do que o corredor encosta nela.
_MEIA_NA_PAREDE = {"armarios": 1.40, "mural": 1.20, "bebedouro": 0.25}


def _parede_falta(s, p):
    """A peca "na parede" so' existe se a parede existe ali: na esquina de dois
    corredores (e no vao de porta ou janela) ela falta, e o que nascia ali
    ficava no ar ou no meio da passagem — o armario do corredor leste. Procura
    em `P.muros()` a parede da face mais perto da peca, cobrindo a extensao
    dela, sem vao na altura dela.
    """
    nome = p.get("nome", "")
    if nome.startswith(("placa_", "camera_")):
        return False
    meia = next((v for k, v in _MEIA_NA_PAREDE.items() if nome.startswith(k)), 0.3)
    x, z = p["x"], p["z"]
    bordas = {"o": x - s["x0"], "l": s["x1"] - x, "n": z - s["z0"], "s": s["z1"] - z}
    lado = p.get("na_parede") or min(bordas, key=bordas.get)
    if bordas[lado] > 1.0:
        return False                 # longe da parede: ela nao o segura
    face = {"o": s["x0"], "l": s["x1"], "n": s["z0"], "s": s["z1"]}[lado]
    eixo = "x" if lado in ("n", "s") else "z"
    c = x if eixo == "x" else z
    y0 = p.get("y", 0.0) + p.get("dy", 0.0)
    y1 = y0 + _ALTURA_NA_PAREDE.get(nome.split("_")[0], 0.6)
    # pendurada (relogio, extintor, monitor) x de chao ou em cima de movel
    # (armario, maca, a TV no gaveteiro, o microscopio na bancada)
    pendurada = y0 - P.cota() >= 1.0
    cobre = []
    for m in _muros_do_andar(s):
        if m["eixo"] != eixo or abs(m["coord"] - face) > m.get("esp", 0.35) * 0.5 + 0.1:
            continue
        cobre.append((m["a"], m["b"]))
        for v in m["vaos"]:
            if not (v["y0"] < y1 and v["y1"] > y0):
                continue
            if v["tipo"] in ("porta", "passagem", "buraco"):
                # qualquer pedaco na frente de porta a tapa
                if abs(v["c"] - c) < v["l"] * 0.5 + meia:
                    return True
            elif pendurada and abs(v["c"] - c) + meia <= v["l"] * 0.5:
                return True          # inteira em cima de uma janela: no ar
    falta = any(not any(a - 0.05 <= q <= b + 0.05 for (a, b) in cobre)
                for q in (c - meia, c + meia))
    if not falta:
        return False
    if pendurada:
        return True
    # de chao, sem parede atras: so' sai se ali atras se anda (a esquina de
    # dois corredores) — na beira da galeria, ela da' pro vazio e fica
    atras = 0.6
    bx = {"o": s["x0"] - atras, "l": s["x1"] + atras}.get(lado, x)
    bz = {"n": s["z0"] - atras, "s": s["z1"] + atras}.get(lado, z)
    for e in P.espacos():
        if e["ident"] != s["ident"] and e["x0"] <= bx <= e["x1"] and e["z0"] <= bz <= e["z1"]:
            return True
    return False


# Altura (m) que a peca ocupa a partir da base, pra saber se um vao (janela)
# fica atras dela. O padrao e' 0,6.
_ALTURA_NA_PAREDE = {"armarios": 1.98, "mural": 1.10, "bebedouro": 1.2, "maca": 0.9}


def _muros_do_andar(s):
    return P.muros()


# --------------------------------------------------------------------------
# O PATIO — a quadra e os bancos, e mais nada
#
# O pedido foi literal: "crie uma quadra esportiva, e uma area com alguns
# bancos... somente". Entao o patio tem exatamente isso, mais o mato que
# nasceu nas juntas porque a escola esta' abandonada. O centro fica VAZIO.
# --------------------------------------------------------------------------

# A quadra, em coordenadas de mundo. Futsal de escola: 26 x 16 m, eixo longo
# em X, traves nas duas pontas curtas.
QUADRA = (10.0, 20.0, 36.0, 36.0)      # x0, z0, x1, z1
QUADRA_LINHA = 0.10                     # espessura da tinta
QUADRA_TRAVE_VAO = 3.00

# O canto de descanso: os bancos ficam TODOS encostados no muro sul do patio,
# de frente pra quadra. Espalhados pelo meio eles seriam exatamente o "coisa
# sem sentido atrapalhando vagar pelo cenario" que foi pedido pra nao ter.
BANCOS = [
    ("s", 0.22), ("s", 0.34), ("s", 0.46),
    ("o", 0.34), ("o", 0.50), ("o", 0.66),
]


def _patio(s, d):
    itens = []
    for (i, (lado, t)) in enumerate(BANCOS):
        itens.append(caixas_na_parede(s, banco_concreto(), lado, t, 1.30,
                                      "banco_%d" % i, bloqueia=(2.0, 0.6)))
    # Os dois bancos de madeira do Poly Haven entram como variacao, na sombra
    # do muro norte — banco de concreto em fileira perfeita fica mecanico.
    for (i, t) in enumerate((0.62, 0.74)):
        itens.append(modelo_na_parede(s, "painted_wooden_bench", "n", t, 1.30,
                                      "banco_madeira_%d" % i,
                                      bloqueia=(1.8, 0.7)))

    # traves, no meio de cada linha de fundo
    x0, z0, x1, z1 = QUADRA
    cz = (z0 + z1) * 0.5
    for (i, (x, giro)) in enumerate(((x0 + 0.35, -math.pi * 0.5),
                                     (x1 - 0.35, math.pi * 0.5))):
        itens.append(caixas_solto(s, trave(QUADRA_TRAVE_VAO), x, cz, giro,
                                  "trave_%d" % i, bloqueia=(1.0, 3.4)))

    # a bola parada num canto da quadra, e o mato que tomou as juntas
    itens.append(modelo_solto(s, "dirty_football", x1 - 3.2, z1 - 2.4, 0.0,
                              "bola"))
    matos = ("weed_plant_02", "nettle_plant", "shrub_02", "shrub_03", "shrub_04")
    for i in range(22):
        # so' na FAIXA RENTE AOS MUROS: mato no meio da quadra seria obstaculo
        if i % 2 == 0:
            x = d.uniform(s["x0"] + 0.9, s["x0"] + 3.4) if i % 4 == 0 \
                else d.uniform(s["x1"] - 3.4, s["x1"] - 0.9)
            z = d.uniform(s["z0"] + 1.0, s["z1"] - 1.0)
        else:
            x = d.uniform(s["x0"] + 1.0, s["x1"] - 1.0)
            z = d.uniform(s["z0"] + 0.9, s["z0"] + 3.4) if i % 4 == 1 \
                else d.uniform(s["z1"] - 3.4, s["z1"] - 0.9)
        itens.append(modelo_solto(s, matos[i % len(matos)], x, z,
                                  d.uniform(0.0, 6.28), "mato_%d" % i,
                                  escala=d.uniform(0.7, 1.4)))
    for (i, (x, z)) in enumerate(((s["x1"] - 2.2, s["z0"] + 2.4),
                                  (s["x0"] + 2.6, s["z1"] - 3.0))):
        itens.append(modelo_solto(s, "dead_tree_trunk_02", x, z,
                                  d.uniform(0.0, 6.28), "tronco_%d" % i,
                                  bloqueia=(1.2, 1.2)))
    for (i, (x, z)) in enumerate(((s["x0"] + 2.0, s["z0"] + 6.0),
                                  (s["x1"] - 2.4, s["z1"] - 8.0),
                                  (s["x0"] + 3.0, s["z1"] - 5.0))):
        itens.append(modelo_solto(s, "old_tyre", x, z, d.uniform(0.0, 6.28),
                                  "pneu_%d" % i))
    itens.append(modelo_na_parede(s, "concrete_road_barrier", "o", 0.86, 1.10,
                                  "barreira", bloqueia=(2.2, 0.8)))
    return itens


RECEITUARIO = {
    "sala_aula": _sala_aula, "secretaria": _secretaria,
    "refeitorio": _refeitorio, "biblioteca": _biblioteca,
    "laboratorio": _laboratorio, "almoxarifado": _servico,
    "deposito": _servico, "corredor": _corredor, "patio": _patio,
}


# Maior dimensao aceitavel para um modelo do catalogo, em metros. Acima disso
# quase sempre e' arquivo MODULAR (varias variantes da mesma peca lado a lado
# no mesmo .gltf), e instanciar um desses poe uma peca de dez metros dentro de
# um comodo de quatro — atravessando parede, sem erro nenhum em log.
#
# 4,20 deixa passar o tronco caido do patio (4,05 m), que e' de proposito.
LIMITE_MODELO = 4.20


def conferir_modelos():
    """Modelos grandes demais pra caber onde a receita os poe.

    Custou uma tarde: o `steel_frame_shelves_01` tem 11 x 21 x 5 m no arquivo e
    aparecia como uma laje clara de dez metros atravessando o corredor sul,
    vinda de dentro do laboratorio. De frente nao dava pra ver — so' andando
    rente a' parede.
    """
    problemas = []
    for nome in sorted(MODELOS):
        try:
            mn, mx = aabb(nome)
        except Exception as erro:
            problemas.append("%s: nao consegui ler o .gltf (%s)" % (nome, erro))
            continue
        tam = [mx[k] - mn[k] for k in range(3)]
        if max(tam) > LIMITE_MODELO:
            problemas.append("%s tem %.1f x %.1f x %.1f m — arquivo modular?"
                             % (nome, tam[0], tam[1], tam[2]))
    return problemas


def mobiliar():
    tudo = []
    for e in P.espacos():
        receita = RECEITUARIO.get(e["tipo"])
        if receita is None:
            continue
        tudo.extend(_por(e, receita(e, _dado(e))))
    return tudo


# ==========================================================================
# O PORAO
#
# Nao tem "mobilia" — tem ENTULHO, e ele existe por dois motivos praticos
# antes de estetico:
#
#   1. escala. Um tunel de terra sem nada dentro nao tem tamanho: o jogador
#      nao sabe se a parede esta' a tres metros ou a dez. Um barril encostado
#      nela resolve isso na hora.
#   2. memoria do caminho. Todo trecho ganha um objeto diferente, e e' por eles
#      que o jogador percebe que ja' passou por ali — num tunel de terra, sem
#      isso, toda curva e' a mesma curva.
#
# Tudo nasce ENCOSTADO NA PAREDE, pela mesma regra de cima. Num tunel de 4 m de
# largura, um engradado no meio ja' e' um bloqueio.
# ==========================================================================

ENTULHO_PORAO = ("wooden_crate_01", "wooden_crate_02", "Barrel_02", "barrel_03",
                 "metal_jerrycan", "wooden_bucket_01", "old_tyre",  # os galhos secos tinham um galho solto no ar
                 "wicker_basket_01", "vintage_suitcase", "cement_bag",
                 "plastic_bottle_gallon", "old_tyre", "propane_tank",
                 "tree_stump_01")
FISICOS_PORAO = set(ENTULHO_PORAO) - {"tree_stump_01"}


def mobiliar_porao():
    """Entulho encostado nas paredes do tunel, sorteado com semente fixa."""
    d = random.Random("escola/porao")
    abertas = PO.celulas_abertas()
    # As celulas que encostam em parede — e' nelas, e so' nelas, que pode
    # nascer coisa. As de miolo ficam limpas por construcao.
    borda = [c for c in sorted(abertas)
             if any(v not in abertas for v in
                    ((c[0] + 1, c[1]), (c[0] - 1, c[1]),
                     (c[0], c[1] + 1), (c[0], c[1] - 1)))]
    itens = []
    falso = {"ident": "porao", "andar": 1}
    for (i, celula) in enumerate(borda):
        if d.random() > 0.11:
            continue
        # empurra pro lado da parede que esta' perto, pra nao ficar no eixo
        vizinhos = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        fechados = [v for v in vizinhos
                    if (celula[0] + v[0], celula[1] + v[1]) not in abertas]
        vx, vz = fechados[0]
        x = (celula[0] + 0.5 + vx * 0.24) * PO.CELULA
        z = (celula[1] + 0.5 + vz * 0.24) * PO.CELULA
        nome = ENTULHO_PORAO[i % len(ENTULHO_PORAO)]
        giro = d.uniform(0.0, 6.28)
        esc = d.uniform(0.85, 1.15)
        # peca comprida (a mala tem 1,6 m) vai deitada AO LONGO do muro: no
        # giro sorteado ela entrava na parede e a fisica cuspia ela no tunel
        mn, mx = aabb(nome)
        if (mx[0] - mn[0]) * esc > 1.0:
            giro = (math.pi * 0.5 if vx else 0.0) + (giro - 3.14) * 0.05
        item = {"tipo": "modelo", "sala": "porao", "modelo": nome,
                "nome": "entulho_%d" % i, "x": x, "y": 0.0, "z": z,
                "giro": giro, "escala": esc,
                "bloqueia": (0.9, 0.9), "dy": 0.0}
        if nome in FISICOS_PORAO:
            mn, mx = aabb(nome)
            item["fisico"] = True
            item["fisico_caixa"] = tuple((mx[k] - mn[k]) * esc for k in range(3))
            item["fisico_centro"] = tuple((mn[k] + mx[k]) * 0.5 * esc for k in range(3))
            item["y"] = max(0.0, -mn[1] * esc)
            item["bloqueia"] = None
        itens.append(item)
    return itens


if __name__ == "__main__":
    for erro in conferir_modelos():
        print("  !! " + erro)
    props = mobiliar()
    print("escola: %d moveis" % len(props))
    por_tipo = {}
    for p in props:
        por_tipo[p["tipo"]] = por_tipo.get(p["tipo"], 0) + 1
    print("  por especie: %s" % por_tipo)
    modelos = {}
    for p in props:
        if p["tipo"] == "modelo":
            modelos[p["modelo"]] = modelos.get(p["modelo"], 0) + 1
    print("  %d especies de modelo" % len(modelos))
    caixas = sum(len(p["pecas"]) for p in props if p["tipo"] == "caixas")
    print("  %d caixas de geometria" % caixas)
    print("porao: %d pecas de entulho" % len(mobiliar_porao()))
