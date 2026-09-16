"""A paleta do hospital — um lugar so' pra mexer em cor e textura.

As texturas sao as do Poly Haven (CC0) que `tools/polyhaven/baixar.py` trouxe
pra `assets/images/textures/polyhaven/`. O sufixo e' o padrao que o projeto ja'
usa: `_diff`, `_arm` (oclusao/rugosidade/metalico) e `_nor_gl`.

`uv_escala` e' quantos METROS cabem numa repeticao da textura. E' o numero que
mais engana: azulejo de hospital tem uns 20 cm, entao uma foto de azulejo do
Poly Haven (que ja' mostra varias pastilhas) quer uv_escala perto de 1,5 — com
4 ou 5 o azulejo vira mosaico de piscina.
"""

from gltf import Material

# ==========================================================================
# ESTRUTURA
# ==========================================================================

ESTRUTURA = [
    # --- pisos
    #
    # Granilite (terrazzo) no corredor porque e' literalmente o piso de
    # hospital publico. A primeira versao usava `dirty_tiles`, que no arquivo
    # do Poly Haven e' ladrilho VERMELHO de cozinha — dava ao corredor uma cor
    # quente, acolhedora, exatamente o contrario do que esta cena quer. O tom
    # frio vem do `albedo_color`, que puxa o bege do arquivo pro cinza-esverdeado.
    Material("piso_corredor", (0.52, 0.56, 0.53), 0.0, 1.0,
             textura="terrazzo_tiles", uv_escala=2.0),
    # Quarto e sala: vinilico quadriculado, o outro classico institucional.
    Material("piso_sala", (0.60, 0.62, 0.58), 0.0, 1.0,
             textura="floor_tiles_06", uv_escala=2.4),
    Material("piso_hall", (0.58, 0.60, 0.58), 0.05, 1.0,
             textura="terrazzo_tiles", uv_escala=3.2),
    # Area suja (necroterio, esterilizacao, casa de maquinas): ladrilho
    # encardido de verdade, com as manchas pretas ja' na textura.
    Material("piso_servico", (0.54, 0.56, 0.54), 0.0, 1.0,
             textura="worn_tile_floor", uv_escala=2.2),
    Material("piso_concreto", (0.46, 0.46, 0.45), 0.0, 1.0,
             textura="concrete_floor_worn_001", uv_escala=3.2),

    # --- paredes: embaixo o azulejo (dado), em cima o reboco
    #
    # O dado usa `interior_tiles`, que e' claro. A primeira versao usava
    # `square_tiles` — pastilha MARROM — multiplicada por 0,54 pra puxar pro
    # verde. So' que multiplicar so' escurece: o resultado nao ficou verde,
    # ficou PRETO, e a metade de baixo de todo corredor sumia numa faixa sem
    # detalhe nenhum, bem na altura do olho da camera.
    #
    # Com uma textura clara por baixo, o mesmo multiplicador vira tom de
    # verdade: 0,84 da' o verde-agua de enfermaria, 0,62 da' o verde fechado
    # das salas molhadas.
    Material("parede_dado", (0.78, 0.86, 0.82), 0.0, 1.0,
             textura="interior_tiles", uv_escala=1.6),
    Material("parede_dado_verde", (0.50, 0.70, 0.62), 0.0, 1.0,
             textura="interior_tiles", uv_escala=1.6),
    Material("parede_alta", (0.74, 0.74, 0.70), 0.0, 1.0,
             textura="white_rough_plaster", uv_escala=2.6),
    Material("parede_alta_suja", (0.62, 0.58, 0.44), 0.0, 1.0,
             textura="yellow_plaster", uv_escala=2.6),
    Material("parede_azulejo", (0.84, 0.90, 0.88), 0.0, 1.0,
             textura="interior_tiles", uv_escala=1.7),

    # --- teto
    Material("teto", (0.76, 0.76, 0.73), 0.0, 1.0,
             textura="ceiling_interior", uv_escala=1.8),
    Material("teto_concreto", (0.44, 0.44, 0.43), 0.0, 1.0,
             textura="plastered_wall_04", uv_escala=3.0),

    # --- elevador e esquadria
    Material("poco_concreto", (0.38, 0.38, 0.38), 0.0, 1.0,
             textura="concrete_floor_worn_001", uv_escala=2.6),
    Material("cabine_parede", (0.52, 0.50, 0.47), 0.55, 0.62,
             textura="rusty_metal_02", uv_escala=1.8),
    Material("cabine_piso", (0.50, 0.50, 0.50), 0.75, 0.52,
             textura="metal_plate", uv_escala=1.6),
    Material("esquadria", (0.30, 0.31, 0.30), 0.35, 0.55),
    # O friso que fecha o dado por cima. Existe por leitura, nao por realismo:
    # sem ele o azulejo e o reboco se encontram num degrade e a parede perde a
    # horizontal — com ele o corredor ganha uma linha de fuga, que e' o que
    # deixa o comprimento do predio visivel.
    Material("friso", (0.26, 0.30, 0.28), 0.10, 0.60),
    Material("peitoril", (0.66, 0.66, 0.63), 0.0, 0.85),
    Material("vidro", (0.44, 0.50, 0.54), 0.0, 0.12, alpha=0.30,
             dupla_face=True),
    Material("porta_folha", (0.54, 0.57, 0.53), 0.10, 0.62),
    Material("porta_metal", (0.56, 0.58, 0.58), 0.70, 0.45,
             textura="rusty_metal_02", uv_escala=1.6),
]

# ==========================================================================
# MOVEIS
#
# Sem textura de proposito: movel de hospital e' metal pintado e aco escovado,
# e isso e' cor + rugosidade, nao foto. Sai mais barato e fica mais limpo.
# ==========================================================================

MOVEIS = [
    Material("mat_metal_claro", (0.60, 0.62, 0.59), 0.35, 0.55),
    Material("mat_metal_escuro", (0.20, 0.21, 0.23), 0.50, 0.60),
    Material("mat_inox", (0.70, 0.72, 0.75), 0.90, 0.32),
    Material("mat_inox_escovado", (0.64, 0.66, 0.68), 0.85, 0.46),
    Material("mat_colchao", (0.78, 0.76, 0.68), 0.0, 0.88),
    Material("mat_lencol", (0.84, 0.85, 0.82), 0.0, 0.94),
    Material("mat_lencol_sujo", (0.68, 0.64, 0.52), 0.0, 0.96),
    Material("mat_borracha", (0.09, 0.09, 0.10), 0.0, 0.92),
    Material("mat_soro", (0.82, 0.86, 0.70), 0.0, 0.28),
    Material("mat_balcao", (0.44, 0.44, 0.41), 0.0, 0.72),
    # o tampo verde-escuro e' a cor de laminado de hospital dos anos 70
    Material("mat_tampo", (0.20, 0.30, 0.26), 0.05, 0.50),
    Material("mat_vidro_fosco", (0.66, 0.72, 0.72), 0.10, 0.22, alpha=0.55),
    Material("mat_couro_verde", (0.13, 0.26, 0.22), 0.0, 0.52),
    Material("mat_gaveta", (0.68, 0.70, 0.72), 0.85, 0.36),
    Material("mat_painel", (0.12, 0.13, 0.14), 0.30, 0.48),
    Material("mat_cortina", (0.50, 0.60, 0.53), 0.0, 0.96),
    Material("mat_tela", (0.03, 0.04, 0.05), 0.0, 0.25),
    Material("mat_formica", (0.64, 0.60, 0.52), 0.0, 0.60),
    Material("mat_placa", (0.62, 0.64, 0.62), 0.0, 0.58),
    # seta verde de saida, com um tico de emissao pra se ler no escuro
    Material("mat_seta", (0.08, 0.32, 0.20), 0.0, 0.50,
             emissivo=(0.05, 0.42, 0.22)),
    Material("mat_lampada", (0.92, 0.94, 0.90), 0.0, 0.20,
             emissivo=(0.90, 0.94, 0.98)),
    Material("mat_botao", (0.80, 0.74, 0.40), 0.30, 0.40,
             emissivo=(0.50, 0.42, 0.10)),
]

# ==========================================================================
# LUMINARIAS — malha propria porque a emissao delas e' o que da' a impressao
# de "lampada acesa" mesmo quando a luz de verdade esta' piscando.
# ==========================================================================

LUMINARIAS = [
    Material("lum_corpo", (0.62, 0.63, 0.61), 0.40, 0.55),
    Material("lum_tubo_aceso", (0.90, 0.95, 0.90), 0.0, 0.25,
             emissivo=(0.72, 0.88, 0.76)),
    # O forro da cabine e' um painel de 4 x 4 m. Com a mesma emissao do tubo de
    # 2,4 x 0,24 ele vira um retangulo branco estourado ocupando meia tela —
    # area muito maior pedindo emissao muito menor.
    Material("lum_forro_cabine", (0.82, 0.86, 0.82), 0.0, 0.35,
             emissivo=(0.16, 0.21, 0.17)),
    Material("lum_tubo_morto", (0.42, 0.44, 0.42), 0.0, 0.45),
    Material("lum_vermelha", (0.60, 0.10, 0.08), 0.0, 0.40,
             emissivo=(0.90, 0.10, 0.06)),
]


def registrar(cena, grupos):
    for grupo in grupos:
        for m in grupo:
            cena.material(m)


def piso_de(tipo):
    if tipo in ("corredor",):
        return "piso_corredor"
    if tipo in ("hall", "saguao"):
        return "piso_hall"
    if tipo in ("maquinas", "necroterio", "esterilizacao", "cirurgia"):
        return "piso_servico"
    return "piso_sala"


# Salas que sao azulejadas ate' o teto — as "molhadas" e as que precisam ser
# lavadas com mangueira. E' tambem o que faz cirurgia e necroterio parecerem
# diferentes de quarto assim que a porta abre.
AZULEJADAS = {"cirurgia", "necroterio", "esterilizacao", "laboratorio"}

# Alas que ja' apodreceram: reboco amarelado no lugar do branco.
SUJAS = {"maquinas", "arquivo", "psiquiatria", "necroterio", "refeitorio"}


def parede_de(tipo, alta):
    if tipo in AZULEJADAS:
        return "parede_azulejo" if alta else "parede_dado_verde"
    if alta:
        return "parede_alta_suja" if tipo in SUJAS else "parede_alta"
    return "parede_dado"


def teto_de(tipo):
    if tipo in ("maquinas", "poco"):
        return "teto_concreto"
    return "teto"
