"""A paleta da escola, a do porao e a da fachada — um lugar so' pra cor e textura.

As texturas sao as do Poly Haven (CC0) que `tools/polyhaven/baixar.py` trouxe
pra `assets/images/textures/polyhaven/`. O sufixo e' o padrao do projeto:
`_diff`, `_arm` (oclusao/rugosidade/metalico) e `_nor_gl`.

`uv_escala` e' quantos METROS cabem numa repeticao da textura.

==============================================================================
DUAS PALETAS, E POR QUE ELAS SAO OPOSTAS

A ESCOLA e' um predio publico dos anos 70 apodrecendo: reboco claro, azulejo
ate' a cintura, piso frio. Cor dessaturada, quase tudo cinza-esverdeado, e a
unica cor forte e' a pichacao. A leitura vem do CONTRASTE entre o piso claro e
a parede escura, que e' o que faz um corredor de 70 m ter fundo.

O PORAO e' o contrario em tudo. La' nao existe material fabricado: e' terra,
raiz, tabua podre e o fio que alguem puxou. Tudo marrom, tudo rugoso, quase
nenhum brilho. A regra la' e' que a cor NAO carrega leitura nenhuma — quem
carrega e' a lanterna do jogador, e por isso os tons sao proximos de proposito:
sem a luz dele, o tunel tem de ser uma massa so'.
"""

import os
import sys

# O escritor de glTF e' o mesmo do hospital. Importado, e nao copiado: e' um
# escritor de arquivo generico (caixa -> .gltf), nao tem nada de hospital
# dentro dele, e duas copias divergiriam na primeira correcao. A pasta entra
# no FIM do sys.path pra `planta` continuar sendo a desta pasta aqui.
sys.path.append(os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), "hospital"))

from gltf import Material  # noqa: E402

# ==========================================================================
# ESTRUTURA DA ESCOLA
# ==========================================================================

ESTRUTURA = [
    # --- pisos
    # Granilite no corredor: e' literalmente o piso de escola publica.
    Material("piso_corredor", (0.54, 0.57, 0.54), 0.0, 1.0,
             textura="terrazzo_tiles", uv_escala=2.2),
    # Sala de aula: taco de madeira encardido. E' o que separa, num olhar, a
    # sala do corredor — e o unico material quente do predio inteiro.
    Material("piso_sala", (0.46, 0.38, 0.30), 0.0, 0.98,
             textura="plank_flooring_03", uv_escala=2.6),
    Material("piso_frio", (0.56, 0.58, 0.56), 0.0, 1.0,
             textura="tiled_floor_001", uv_escala=2.0),
    Material("piso_servico", (0.50, 0.50, 0.48), 0.0, 1.0,
             textura="worn_tile_floor", uv_escala=2.2),
    Material("piso_concreto", (0.46, 0.46, 0.45), 0.0, 1.0,
             textura="concrete_floor_worn_001", uv_escala=3.2),

    # --- o patio, que e' o unico chao descoberto
    # Cimento queimado com mato nas juntas. O piso do patio e' escuro de
    # proposito: a quadra pintada em cima dele so' aparece por contraste.
    Material("piso_patio", (0.40, 0.41, 0.38), 0.0, 1.0,
             textura="concrete_floor_worn_001", uv_escala=4.0),
    Material("piso_quadra", (0.33, 0.37, 0.35), 0.0, 0.96,
             textura="asphalt_02", uv_escala=4.5),
    # A tinta da quadra. Sem textura: e' tinta chapada, e um pouco de emissao
    # e' o que faz a linha continuar legivel na luz fraca da noite.
    Material("linha_quadra", (0.72, 0.70, 0.62), 0.0, 0.75,
             emissivo=(0.05, 0.05, 0.045)),
    Material("mato", (0.26, 0.31, 0.21), 0.0, 1.0,
             textura="aerial_grass_rock", uv_escala=2.4),

    # --- paredes: embaixo o azulejo (dado), em cima o reboco
    Material("parede_dado", (0.66, 0.72, 0.68), 0.0, 1.0,
             textura="interior_tiles", uv_escala=1.6),
    Material("parede_dado_azul", (0.44, 0.58, 0.66), 0.0, 1.0,
             textura="interior_tiles", uv_escala=1.6),
    Material("parede_alta", (0.72, 0.71, 0.66), 0.0, 1.0,
             textura="white_rough_plaster", uv_escala=2.6),
    Material("parede_alta_suja", (0.60, 0.55, 0.40), 0.0, 1.0,
             textura="yellow_plaster", uv_escala=2.6),
    Material("parede_azulejo", (0.78, 0.84, 0.82), 0.0, 1.0,
             textura="interior_tiles", uv_escala=1.7),
    # A parede vista DO PATIO: sem azulejo, so' reboco batido de chuva.
    Material("parede_patio", (0.50, 0.49, 0.44), 0.0, 0.96,
             textura="grey_plaster_02", uv_escala=3.0),
    Material("parede_tijolo", (0.36, 0.28, 0.24), 0.0, 0.96,
             textura="brick_wall_02", uv_escala=2.0),

    # --- teto
    Material("teto", (0.70, 0.70, 0.67), 0.0, 1.0,
             textura="ceiling_interior", uv_escala=1.8),
    Material("teto_concreto", (0.42, 0.42, 0.41), 0.0, 1.0,
             textura="plastered_wall_04", uv_escala=3.0),

    # --- esquadria, vidro, porta
    Material("esquadria", (0.28, 0.29, 0.28), 0.35, 0.55),
    # O friso que fecha o dado. Existe por leitura: sem ele o azulejo e o
    # reboco se encontram num degrade e o corredor perde a linha de fuga —
    # que e' justamente o que deixa o comprimento do predio visivel.
    Material("friso", (0.20, 0.30, 0.30), 0.10, 0.60),
    Material("peitoril", (0.62, 0.62, 0.59), 0.0, 0.85),
    Material("vidro", (0.42, 0.48, 0.52), 0.0, 0.12, alpha=0.30,
             dupla_face=True),
    # Vidro quebrado: o que sobrou no caixilho. Opaco e' errado, mas
    # transparente demais some — 0,18 deixa o caco visivel na luz rasante.
    Material("vidro_caco", (0.50, 0.56, 0.58), 0.20, 0.20, alpha=0.18,
             dupla_face=True),
    Material("porta_folha", (0.40, 0.33, 0.25), 0.0, 0.72,
             textura="weathered_brown_planks", uv_escala=1.1),
    Material("porta_metal", (0.50, 0.50, 0.48), 0.65, 0.48,
             textura="rusty_metal_02", uv_escala=1.6),
    # A grade do corredor e o portao do patio: chapa e barra de ferro velha.
    Material("ferro", (0.42, 0.36, 0.30), 0.70, 0.55,
             textura="rusty_metal_02", uv_escala=1.4),
    Material("ferro_grade", (0.46, 0.38, 0.31), 0.60, 0.62,
             textura="rusty_metal_grid", uv_escala=1.6, dupla_face=True),
    # A terra que aparece por dentro do buraco na parede.
    Material("terra_buraco", (0.34, 0.26, 0.18), 0.0, 1.0,
             textura="brown_mud_02", uv_escala=2.0),
    Material("escuro", (0.015, 0.015, 0.02), 0.0, 0.95),
]

# ==========================================================================
# MOVEIS DA ESCOLA
#
# Sem textura de proposito: carteira escolar e' formica e tubo pintado, o que
# e' cor + rugosidade, nao foto. Sai mais barato e fica mais limpo.
# ==========================================================================

MOVEIS = [
    Material("mat_metal_claro", (0.56, 0.58, 0.55), 0.35, 0.55),
    Material("mat_metal_escuro", (0.19, 0.20, 0.22), 0.50, 0.60),
    Material("mat_inox", (0.68, 0.70, 0.72), 0.88, 0.34),
    Material("mat_madeira", (0.44, 0.33, 0.21), 0.0, 0.74),
    Material("mat_madeira_clara", (0.60, 0.48, 0.32), 0.0, 0.72),
    Material("mat_formica", (0.62, 0.58, 0.48), 0.0, 0.58),
    # Verde de quadro-negro. A escola inteira gira em torno dele: e' a unica
    # coisa que toda sala de aula tem e que nenhum outro comodo tem.
    Material("mat_lousa", (0.07, 0.15, 0.11), 0.05, 0.42),
    Material("mat_giz", (0.82, 0.83, 0.80), 0.0, 0.92),
    Material("mat_borracha", (0.09, 0.09, 0.10), 0.0, 0.92),
    Material("mat_plastico_azul", (0.16, 0.26, 0.38), 0.0, 0.62),
    Material("mat_plastico_verde", (0.18, 0.30, 0.22), 0.0, 0.62),
    Material("mat_papel", (0.66, 0.62, 0.52), 0.0, 0.94),
    Material("mat_tela", (0.03, 0.04, 0.05), 0.0, 0.25),
    Material("mat_placa", (0.58, 0.60, 0.58), 0.0, 0.58),
    Material("mat_seta", (0.08, 0.32, 0.20), 0.0, 0.50,
             emissivo=(0.05, 0.42, 0.22)),
    Material("mat_rede", (0.58, 0.58, 0.54), 0.0, 0.90, dupla_face=True),
    Material("mat_trave", (0.70, 0.70, 0.66), 0.10, 0.52),
]

# ==========================================================================
# LUMINARIAS
# ==========================================================================

LUMINARIAS = [
    Material("lum_corpo", (0.58, 0.59, 0.57), 0.40, 0.55),
    Material("lum_tubo_aceso", (0.88, 0.93, 0.88), 0.0, 0.25,
             emissivo=(0.70, 0.86, 0.74)),
    Material("lum_tubo_morto", (0.40, 0.42, 0.40), 0.0, 0.45),
    Material("lum_vermelha", (0.58, 0.10, 0.08), 0.0, 0.40,
             emissivo=(0.88, 0.10, 0.06)),
    # A lampada pelada do porao. Emissao morna e fraca: ela nao ilumina o
    # tunel, ela so' diz onde ela esta'.
    Material("lum_bulbo", (0.92, 0.80, 0.56), 0.0, 0.22,
             emissivo=(1.00, 0.62, 0.26)),
    Material("lum_bulbo_morto", (0.34, 0.31, 0.26), 0.0, 0.50),
    Material("lum_fio", (0.10, 0.09, 0.08), 0.0, 0.80),
]

# ==========================================================================
# O PORAO
#
# Uma paleta de cinco materiais, e nao vinte. Um tunel cavado na mao nao tem
# vinte materiais — tem terra, terra mais seca, pedra, tabua e ferrugem. A
# variacao que se ve la' dentro vem da FORMA (a parede e' irregular) e da luz,
# nao da cor.
# ==========================================================================

PORAO = [
    Material("po_terra", (0.40, 0.31, 0.22), 0.0, 1.0,
             textura="brown_mud_02", uv_escala=2.6),
    # O chao e' mais seco e mais claro que a parede: e' onde pisaram. Sem essa
    # separacao o tunel vira um tubo de cor unica e o jogador perde o horizonte.
    Material("po_chao", (0.46, 0.38, 0.28), 0.0, 1.0,
             textura="mud_cracked_dry_03", uv_escala=3.0),
    Material("po_teto", (0.30, 0.24, 0.18), 0.0, 1.0,
             textura="brown_mud_02", uv_escala=3.4),
    Material("po_pedra", (0.42, 0.40, 0.37), 0.0, 0.98,
             textura="rock_wall_08", uv_escala=2.4),
    Material("po_cascalho", (0.44, 0.39, 0.32), 0.0, 1.0,
             textura="rocky_trail_02", uv_escala=2.8),
    Material("po_tabua", (0.34, 0.26, 0.18), 0.0, 0.94,
             textura="weathered_brown_planks", uv_escala=1.1),
    Material("po_ferro", (0.36, 0.30, 0.25), 0.60, 0.68,
             textura="rusty_metal_02", uv_escala=1.6),
    Material("po_raiz", (0.22, 0.18, 0.12), 0.0, 0.96),
    Material("po_escuro", (0.010, 0.010, 0.012), 0.0, 0.95),
]


# ==========================================================================
# FACHADA — o predio visto de fora, ja' na cidade
#
# A regra aqui e' o CONTRARIO da de dentro. No interior a cor vem quase toda do
# multiplicador, porque a luz e' artificial e controlada; na rua quem manda e'
# o sol e a chuva da stage_1, e material claro demais vira um bloco branco
# chapado no meio de uma cidade cinza. Entao o reboco ja' sai escuro, e o que
# separa um plano do outro e' a TEXTURA (reboco liso x concreto x tijolo), nao
# o brilho.
# ==========================================================================

EXTERIOR = [
    Material("fac_embasamento", (0.33, 0.33, 0.32), 0.0, 0.95,
             textura="concrete_floor_worn_001", uv_escala=2.4),
    Material("fac_calcada", (0.34, 0.34, 0.33), 0.0, 0.96,
             textura="concrete_floor_worn_001", uv_escala=3.0),
    Material("fac_laje", (0.32, 0.32, 0.31), 0.0, 0.94,
             textura="concrete_floor_worn_001", uv_escala=3.4),
    # Os dois panos de parede: o limpo e o que ja' escorreu.
    Material("fac_reboco", (0.47, 0.46, 0.41), 0.0, 0.92,
             textura="grey_plaster_02", uv_escala=3.0),
    Material("fac_reboco_sujo", (0.42, 0.37, 0.27), 0.0, 0.94,
             textura="yellow_plaster", uv_escala=3.0),
    Material("fac_concreto", (0.39, 0.39, 0.38), 0.0, 0.88,
             textura="brushed_concrete_03", uv_escala=2.6),
    Material("fac_tijolo", (0.35, 0.26, 0.22), 0.0, 0.95,
             textura="brick_wall_02", uv_escala=1.8),
    Material("fac_metal", (0.40, 0.36, 0.32), 0.60, 0.62,
             textura="rusty_metal_02", uv_escala=2.0),
    Material("fac_tabua", (0.35, 0.29, 0.23), 0.0, 0.92,
             textura="weathered_brown_planks", uv_escala=1.2),
    Material("fac_esquadria", (0.22, 0.23, 0.23), 0.40, 0.55),
    # O fundo do vao. A casca e' OCA (ninguem entra por ela: entrar e' trocar
    # de cena), entao toda janela precisa de um painel preto atras do vidro,
    # senao da' pra ver o predio por dentro, vazio, pelo proprio buraco.
    Material("fac_escuro", (0.015, 0.015, 0.02), 0.0, 0.95),
    Material("fac_vidro", (0.09, 0.12, 0.13), 0.30, 0.18),
    # A janela "acesa" e' emissiva, e nao uma luz de verdade: luz custa lugar
    # no orcamento de 8 por malha do renderer mobile, e os postes da cidade ja'
    # consomem esse orcamento perto do predio.
    Material("fac_vidro_aceso", (0.20, 0.24, 0.18), 0.0, 0.30,
             emissivo=(0.18, 0.23, 0.15)),
    # A quebrada e' quase o painel preto: o caco que sobrou no caixilho so'
    # aparece na luz rasante, e e' isso mesmo que se ve de uma escola apedrejada.
    Material("fac_vidro_quebrado", (0.05, 0.06, 0.07), 0.25, 0.30),
    Material("fac_letra_acesa", (0.60, 0.70, 0.62), 0.0, 0.35,
             emissivo=(0.66, 1.05, 0.76)),
    Material("fac_letra_morta", (0.16, 0.17, 0.16), 0.10, 0.60),
    # A terra revirada saindo dos dois rombos.
    Material("fac_terra", (0.36, 0.28, 0.19), 0.0, 1.0,
             textura="brown_mud_02", uv_escala=2.2),
    Material("fac_quadra", (0.31, 0.35, 0.33), 0.0, 0.96,
             textura="asphalt_02", uv_escala=4.5),
    Material("fac_linha", (0.66, 0.65, 0.58), 0.0, 0.78),
]


def registrar(cena, grupos):
    for grupo in grupos:
        for m in grupo:
            cena.material(m)


# --------------------------------------------------------------------------
# quem usa o que
# --------------------------------------------------------------------------

def piso_de(tipo):
    if tipo == "patio":
        return "piso_patio"
    if tipo == "corredor":
        return "piso_corredor"
    if tipo in ("sala_aula", "biblioteca", "secretaria"):
        return "piso_sala"
    if tipo in ("almoxarifado", "deposito"):
        return "piso_servico"
    return "piso_frio"


# Salas azulejadas ate' o teto: as molhadas e as que se lavam com mangueira.
AZULEJADAS = {"refeitorio", "laboratorio"}

# Alas que ja' apodreceram: reboco amarelado no lugar do branco.
SUJAS = {"almoxarifado", "deposito", "laboratorio"}


def parede_de(tipo, alta):
    if tipo == "patio":
        return "parede_patio"
    if tipo in AZULEJADAS:
        return "parede_azulejo" if alta else "parede_dado_azul"
    if alta:
        return "parede_alta_suja" if tipo in SUJAS else "parede_alta"
    return "parede_dado"


def teto_de(tipo):
    if tipo in ("almoxarifado", "deposito"):
        return "teto_concreto"
    return "teto"
