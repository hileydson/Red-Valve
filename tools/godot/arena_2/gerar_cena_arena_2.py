# -*- coding: utf-8 -*-
"""Monta a cena da ARENA 2 (.tscn) a partir do modelo e dos pontos.

    python3 tools/godot/arena_2/gerar_cena_arena_2.py

Le':   red-valve/assets/3d_model/stages/battlefield_2/arena_2_pontos.json
Salva: red-valve/scenes/stages/battlefield/battlefield_2.tscn

O .tscn resultante e' um arquivo NORMAL do Godot: pode abrir, mexer e salvar
pelo editor. Rodar este script de novo SOBRESCREVE — ele existe pra quando a
planta mudar no Blender (uma fogueira anda, um escombro nasce) e as luzes,
os props e o navmesh precisarem acompanhar sem ninguem recolocar na mao.

==============================================================================
AS LUZES, QUE SAO O ASSUNTO PRINCIPAL

Arena a ceu aberto de 80 m, a noite, com o sol encostado no horizonte. A regra:

  - Duas DIRECIONAIS resolvem o volume: um "sol" vermelho baixo vindo do
    nordeste, com sombra, e uma contraluz fria e fraca do lado oposto, SEM
    sombra. Sem a contraluz, metade de cada coluna fica preta e o jogador
    perde a leitura de profundidade num campo desse tamanho.
  - Oito OMNI, uma por fogueira, e mais uma na Boca. Nove no total, e isso
    NAO e' folga a toa: o renderer "mobile" so' aceita 8 omni por MALHA, e
    por isso o piso e o escombro da praca sao quebrados em quadrante la' no
    gerador do Blender — cada malha enxerga tres ou quatro destas.
  - Sigilo de monolito e fissura de brasa NAO ganham lampada: sao emissao no
    material, com glow ligado no Environment. Vinte pontos de luz de verdade
    estourariam a cota sem nenhum ganho.
  - `metadata/piscar` diz ao `battlefield_2.gd` como a luz se mexe:
    "fogueira" treme ao acaso, "pulso" respira devagar (so' a Boca).

O renderer mobile ignora EM SILENCIO ssao, ssil e volumetric_fog. A nevoa
aqui e' a de profundidade (`fog_enabled`), que funciona, mais as particulas
de nevoa que o proprio player carrega (`GlobalEvents.set_high_nevoa()`).
"""

import json
import math
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
BASE = os.path.join(RAIZ, "red-valve")
PONTOS = os.path.join(BASE, "assets", "3d_model", "stages", "battlefield_2",
                      "arena_2_pontos.json")
SAIDA = os.path.join(BASE, "scenes", "stages", "battlefield", "battlefield_2.tscn")

PH = "res://assets/3d_model/polyhaven"

EXTERNOS = [
    ("PackedScene", "res://assets/3d_model/stages/battlefield_2/arena_2.glb", "1_modelo"),
    ("PackedScene", "res://scenes/player/player.tscn", "2_player"),
    ("PackedScene", "res://scenes/configs/pause.tscn", "3_pause"),
    ("PackedScene", "res://scenes/configs/fade.tscn", "4_fade"),
    ("Script", "res://scripts/stages/battlefield/battlefield_2.gd", "5_script"),
    ("Script", "res://scripts/stages/battlefield/arena_2_materiais.gd", "6_materiais"),
    ("AudioStream", "res://assets/sounds/episodios/ambient_noise_slow.mp3", "7_ambiente"),
    ("AudioStream", "res://assets/sounds/common/fire_cracling.mp3", "8_fogo_som"),
    ("AudioStream", "res://assets/sounds/common/explosao.mp3", "9_estouro"),
]

# --------------------------------------------------------------------------
# OS PROPS DO POLY HAVEN
#
# (caminho, altura_do_pivo, caixa_de_colisao ou None)
#
# `altura_do_pivo` corrige quem foi modelado com a origem no MEIO em vez de na
# base — e' o caso do PNEU (origem no eixo) e da FOGUEIRA DE PEDRA.
#
# Os numeros aqui sao MEDIDOS, nao chutados: importei cada .gltf no Blender e
# li o Y minimo da malha. O carro, o arbusto e a escada estavam sendo
# levantados 30, 29 e 110 cm sem precisar — todos os tres ja' vem com a base
# no zero — e por isso flutuavam. O tronco morto tem uma raiz fina que desce
# a -0,33, mas o corpo dele comeca no zero: levantar pela raiz punha o tronco
# inteiro no ar, entao ele entra com pivo zero e a raiz enterra.
#
# A escolha do modelo e' orcamento de triangulo, nao gosto: varios props do
# Poly Haven passam de 20 mil triangulos POR PECA (o poste modular tem 200
# mil, a cerca de alambrado 89 mil) e a arena inteira tem 35 mil. Os que
# entraram aqui custam de 800 a 12 mil.
PROPS = {
    "carro": (PH + "/covered_car/covered_car_1k.gltf", -0.02, (1.80, 1.45, 4.40)),
    "barreira": (PH + "/concrete_road_barrier/concrete_road_barrier_1k.gltf", 0.01,
                 (1.55, 0.82, 0.62)),
    # tambor de MADEIRA: o `barrel_03` e o `Barrel_02` do Poly Haven sao
    # tambores plasticos AZUIS, e azul e' a unica cor que nao existe em
    # lugar nenhum desta arena — de longe eles pulavam da tela
    "tambor": (PH + "/wine_barrel_01/wine_barrel_01_1k.gltf", 0.0,
               (0.74, 0.87, 0.74)),
    "caixa": (PH + "/wooden_crate_02/wooden_crate_02_1k.gltf", 0.01, None),
    "pneu": (PH + "/old_tyre/old_tyre_1k.gltf", 0.30, None),
    "gerador": (PH + "/utility_box_02/utility_box_02_1k.gltf", 0.0, (0.92, 1.12, 0.43)),
    "arbusto": (PH + "/shrub_02/shrub_02_1k.gltf", -0.05, None),
    "tronco": (PH + "/dead_tree_trunk_02/dead_tree_trunk_02_1k.gltf", -0.04,
               (4.00, 0.75, 1.00)),
    "entulho_saco": (PH + "/cement_bag/cement_bag_1k.gltf", 0.0, None),
    "escada": (PH + "/wooden_ladder/wooden_ladder_1k.gltf", -0.01, None),
    "hidrante": (PH + "/fire_hydrant/fire_hydrant_1k.gltf", 0.0, None),
    # os dois que marcam fogueira
    # o "barrel stove" e' literalmente um tambor virado fogareiro; custa
    # 9 mil triangulos, e por isso so' metade das fogueiras usa ele
    "fogo_tambor": (PH + "/barrel_stove/barrel_stove_1k.gltf", 0.0, (0.60, 0.86, 0.60)),
    "fogo_pedra": (PH + "/stone_fire_pit/stone_fire_pit_1k.gltf", 0.19, None),
}


# --------------------------------------------------------------------------
# escrita de .tscn
#
# ATENCAO A' CONVENCAO: os 9 primeiros numeros de `Transform3D(...)` num .tscn
# sao a Basis POR LINHAS. Um no' com rotacao Y de `g` tem, em linhas,
# (cos, 0, sin / 0, 1, 0 / -sin, 0, cos) — e o +Z local dele aponta pra
# (sin g, cos g). E' a mesma convencao que o gerador do Blender usa nos giros,
# entao os angulos do JSON entram aqui diretos, sem inverter sinal.


def cor(c):
    return "Color(%s)" % ", ".join("%.4f" % x for x in c)


def transform(pos, giro_y=0.0, escala=1.0):
    c, s = math.cos(giro_y) * escala, math.sin(giro_y) * escala
    nums = [c, 0.0, s, 0.0, escala, 0.0, -s, 0.0, c] + list(pos)
    return "Transform3D(%s)" % ", ".join("%.5f" % n for n in nums)


def _norm(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return [c / n for c in v]


def _cruz(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0]]


def transform_olhando(pos, direcao):
    """Transform3D com o -Z do no' apontando pra `direcao` (Light3D do Godot
    ilumina na direcao do proprio -Z)."""
    z = [-c for c in _norm(direcao)]
    cima = (0.0, 0.0, 1.0) if abs(z[1]) > 0.985 else (0.0, 1.0, 0.0)
    x = _norm(_cruz(cima, z))
    y = _cruz(z, x)
    nums = [x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2]] + list(pos)
    return "Transform3D(%s)" % ", ".join("%.5f" % n for n in nums)


# --------------------------------------------------------------------------
# sub-recursos


def sub_recursos(pontos):
    """(id, tipo, [linhas]) na ordem em que entram no arquivo."""
    s = []

    # --- ceu: nem noite fechada nem dia. O sol esta' MORRENDO no horizonte, e
    # e' o que justifica a sombra comprida e o vermelho em tudo.
    s.append(("ceu_mat", "ProceduralSkyMaterial", [
        "sky_top_color = " + cor((0.035, 0.030, 0.045, 1)),
        "sky_horizon_color = " + cor((0.20, 0.068, 0.045, 1)),
        "sky_curve = 0.1",
        "sky_energy_multiplier = 0.85",
        "ground_bottom_color = " + cor((0.018, 0.014, 0.018, 1)),
        "ground_horizon_color = " + cor((0.17, 0.06, 0.04, 1)),
        "ground_curve = 0.04",
        "sun_angle_max = 13.0",
        "sun_curve = 0.08",
    ]))
    s.append(("ceu", "Sky", ["sky_material = SubResource(\"ceu_mat\")"]))

    # --- ambiente. NAO tem ssao/ssil/volumetric_fog: o renderer "mobile" do
    # projeto ignora os tres em silencio. O que da' atmosfera aqui e' a nevoa
    # de profundidade mais o glow em cima da emissao das brasas.
    s.append(("ambiente", "Environment", [
        "background_mode = 2",
        "sky = SubResource(\"ceu\")",
        "background_energy_multiplier = 1.0",
        "ambient_light_source = 3",
        "ambient_light_color = " + cor((0.40, 0.33, 0.35, 1)),
        "ambient_light_sky_contribution = 0.15",
        "ambient_light_energy = 2.15",
        "reflected_light_source = 2",
        "tonemap_mode = 3",
        "tonemap_exposure = 1.12",
        "tonemap_white = 6.0",
        "glow_enabled = true",
        "glow_intensity = 0.75",
        "glow_strength = 1.0",
        "glow_bloom = 0.16",
        "glow_blend_mode = 0",
        "glow_hdr_threshold = 0.96",
        "fog_enabled = true",
        "fog_mode = 0",
        "fog_light_color = " + cor((0.20, 0.09, 0.08, 1)),
        "fog_light_energy = 0.5",
        "fog_sun_scatter = 0.3",
        "fog_density = 0.0075",
        "fog_sky_affect = 0.18",
        "fog_height = 5.0",
        "fog_height_density = 0.02",
        "adjustment_enabled = true",
        "adjustment_contrast = 1.1",
        "adjustment_saturation = 0.92",
    ]))

    # --- o pontinho macio que serve de textura pra toda particula
    s.append(("grad_ponto", "Gradient", [
        "offsets = PackedFloat32Array(0, 0.45, 1)",
        "colors = PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0.55, 1, 1, 1, 0)",
    ]))
    s.append(("tex_ponto", "GradientTexture2D", [
        "gradient = SubResource(\"grad_ponto\")",
        "width = 64", "height = 64",
        "fill = 1",
        "fill_from = Vector2(0.5, 0.5)",
        "fill_to = Vector2(1, 0.5)",
    ]))
    s.append(("grad_fogo", "Gradient", [
        "offsets = PackedFloat32Array(0, 0.25, 0.65, 1)",
        "colors = PackedColorArray(1, 0.95, 0.6, 1, 1, 0.5, 0.12, 1, "
        "0.6, 0.11, 0.03, 0.75, 0.15, 0.03, 0.02, 0)",
    ]))
    s.append(("tex_fogo", "GradientTexture1D",
              ["gradient = SubResource(\"grad_fogo\")", "width = 64"]))
    s.append(("grad_fagulha", "Gradient", [
        "offsets = PackedFloat32Array(0, 0.3, 1)",
        "colors = PackedColorArray(1, 0.72, 0.3, 0.9, 1, 0.35, 0.08, 0.7, "
        "0.5, 0.08, 0.02, 0)",
    ]))
    s.append(("tex_fagulha", "GradientTexture1D",
              ["gradient = SubResource(\"grad_fagulha\")", "width = 64"]))
    s.append(("grad_cinza", "Gradient", [
        "offsets = PackedFloat32Array(0, 0.4, 1)",
        "colors = PackedColorArray(0.55, 0.5, 0.48, 0, 0.5, 0.45, 0.43, 0.32, "
        "0.4, 0.36, 0.35, 0)",
    ]))
    s.append(("tex_cinza", "GradientTexture1D",
              ["gradient = SubResource(\"grad_cinza\")", "width = 64"]))

    # `billboard_keep_scale` NAO e' detalhe: sem ele o billboard joga fora a
    # escala da particula e `scale_min/scale_max` viram enfeite no inspetor —
    # tudo sai do mesmo tamanho.
    for ident, blend, extra in (("mat_aditivo", 1, []), ("mat_cinza", 0, [])):
        s.append((ident, "StandardMaterial3D", [
            "transparency = 1",
            "blend_mode = %d" % blend,
            "shading_mode = 0",
            "vertex_color_use_as_albedo = true",
            "albedo_texture = SubResource(\"tex_ponto\")",
            "billboard_mode = 1",
            "billboard_keep_scale = true",
            "disable_receive_shadows = true",
        ] + extra))

    s.append(("quad_fogo", "QuadMesh", [
        "material = SubResource(\"mat_aditivo\")", "size = Vector2(0.5, 0.75)"]))
    s.append(("quad_fagulha", "QuadMesh", [
        "material = SubResource(\"mat_aditivo\")", "size = Vector2(0.11, 0.11)"]))
    s.append(("quad_cinza", "QuadMesh", [
        "material = SubResource(\"mat_cinza\")", "size = Vector2(0.09, 0.09)"]))

    s.append(("proc_fogo", "ParticleProcessMaterial", [
        "emission_shape = 1",
        "emission_sphere_radius = 0.22",
        "direction = Vector3(0, 1, 0)",
        "spread = 14.0",
        "initial_velocity_min = 0.7",
        "initial_velocity_max = 1.7",
        "gravity = Vector3(0, 1.1, 0)",
        "damping_min = 0.6",
        "damping_max = 1.4",
        "scale_min = 0.35",
        "scale_max = 1.0",
        "color_ramp = SubResource(\"tex_fogo\")",
        "turbulence_enabled = true",
        "turbulence_noise_strength = 0.55",
        "turbulence_noise_scale = 2.2",
    ]))
    # as fagulhas nascem numa caixa que cobre a praca inteira e SOBEM: e' o
    # que faz o ar da arena parecer quente sem custar luz nenhuma
    s.append(("proc_fagulha", "ParticleProcessMaterial", [
        "emission_shape = 3",
        "emission_box_extents = Vector3(38, 5, 38)",
        "direction = Vector3(0, 1, 0)",
        "spread = 30.0",
        "initial_velocity_min = 0.4",
        "initial_velocity_max = 1.6",
        "gravity = Vector3(0.35, 0.55, -0.2)",
        "scale_min = 0.5",
        "scale_max = 1.6",
        "color_ramp = SubResource(\"tex_fagulha\")",
        "turbulence_enabled = true",
        "turbulence_noise_strength = 0.9",
        "turbulence_noise_scale = 1.4",
    ]))
    s.append(("proc_cinza", "ParticleProcessMaterial", [
        "emission_shape = 3",
        "emission_box_extents = Vector3(42, 1, 42)",
        "direction = Vector3(0.2, -1, 0)",
        "spread = 12.0",
        "initial_velocity_min = 0.5",
        "initial_velocity_max = 1.2",
        "gravity = Vector3(0.5, -0.8, 0.2)",
        "scale_min = 0.6",
        "scale_max = 1.8",
        "color_ramp = SubResource(\"tex_cinza\")",
        "turbulence_enabled = true",
        "turbulence_noise_strength = 0.6",
        "turbulence_noise_scale = 1.1",
    ]))

    # Gradiente PROPRIO do jato, com alfa baixo. O do braseiro comeca quase
    # branco, e numa coluna densa como esta o aditivo empilha dez quads no
    # mesmo pixel e o fogo vira uma bola branca sem forma.
    s.append(("grad_jato", "Gradient", [
        "offsets = PackedFloat32Array(0, 0.22, 0.62, 1)",
        "colors = PackedColorArray(1, 0.86, 0.46, 0.42, 1, 0.47, 0.12, 0.42, "
        "0.68, 0.14, 0.03, 0.26, 0.18, 0.03, 0.01, 0)",
    ]))
    s.append(("tex_jato", "GradientTexture1D",
              ["gradient = SubResource(\"grad_jato\")", "width = 64"]))
    # `billboard_mode = 3` e' BILLBOARD_PARTICLES: o quad se alinha com a
    # VELOCIDADE da particula, entao cada uma vira um risco esticado no
    # sentido em que sobe. Com o billboard comum (1) o jato fica uma pilha de
    # bolinhas redondas.
    s.append(("mat_jato", "StandardMaterial3D", [
        "transparency = 1",
        "blend_mode = 1",
        "shading_mode = 0",
        "vertex_color_use_as_albedo = true",
        "albedo_texture = SubResource(\"tex_ponto\")",
        "billboard_mode = 3",
        "billboard_keep_scale = true",
        "disable_receive_shadows = true",
    ]))
    s.append(("quad_jato", "QuadMesh", [
        "material = SubResource(\"mat_jato\")", "size = Vector2(0.8, 2.3)"]))
    # --- O FOGAREU DA BOCA
    #
    # Jato vertical que sobe pelas barras da grelha. A velocidade inicial e a
    # gravidade estao casadas pra coluna morrer por volta dos 12 m (v^2/2g):
    # mais alto que isso ela vira um risco no ceu e perde a leitura de "coisa
    # que sobe do chao"; mais baixo, quem esta' do outro lado da arena nem ve'
    # que aconteceu.
    s.append(("proc_jato", "ParticleProcessMaterial", [
        "emission_shape = 3",
        "emission_box_extents = Vector3(1.15, 0.1, 1.15)",
        "direction = Vector3(0, 1, 0)",
        "spread = 7.0",
        "initial_velocity_min = 9.5",
        "initial_velocity_max = 16.0",
        "gravity = Vector3(0, -5.0, 0)",
        "damping_min = 0.1",
        "damping_max = 0.6",
        "scale_min = 0.6",
        "scale_max = 1.7",
        "color_ramp = SubResource(\"tex_jato\")",
        "turbulence_enabled = true",
        "turbulence_noise_strength = 0.7",
        "turbulence_noise_scale = 1.6",
    ]))
    # o aviso: brasa saindo pelas frestas um segundo antes. E' a unica chance
    # que o jogador tem de sair de cima, entao ela sobe devagar e e' visivel.
    s.append(("proc_aviso", "ParticleProcessMaterial", [
        "emission_shape = 3",
        "emission_box_extents = Vector3(1.6, 0.05, 1.6)",
        "direction = Vector3(0, 1, 0)",
        "spread = 22.0",
        "initial_velocity_min = 1.4",
        "initial_velocity_max = 4.0",
        "gravity = Vector3(0, -1.2, 0)",
        "scale_min = 0.6",
        "scale_max = 1.6",
        "color_ramp = SubResource(\"tex_fagulha\")",
    ]))
    s.append(("cil_fogareu", "CylinderShape3D", ["height = 10.0", "radius = 4.6"]))

    # --- navmesh pronto do gerador do Blender (ver o cabecalho de la')
    nav = pontos["navmesh"]
    verts = []
    for v in nav["v"]:
        verts.extend("%g" % c for c in v)
    polis = ", ".join("PackedInt32Array(%s)" % ", ".join(str(i) for i in p)
                      for p in nav["p"])
    s.append(("navmesh", "NavigationMesh", [
        "vertices = PackedVector3Array(%s)" % ", ".join(verts),
        "polygons = [%s]" % polis,
    ]))

    # --- caixas de colisao dos props (uma por TIPO, compartilhada)
    for tipo, (_, _, caixa) in sorted(PROPS.items()):
        if caixa:
            s.append(("cx_" + tipo, "BoxShape3D",
                      ["size = Vector3(%.2f, %.2f, %.2f)" % caixa]))
    return s


# --------------------------------------------------------------------------
# conferencia


def conferir_ordem(linhas):
    """Recusa o arquivo se algum SubResource for citado antes de existir.

    O parser de .tscn do Godot le' de cima pra baixo e NAO resolve referencia
    pra frente: um `SubResource("x")` acima do `[sub_resource id="x"]` derruba
    a CENA INTEIRA com um "Parse Error" apontando a linha da referencia, e nao
    a da declaracao. Aqui isso ja' aconteceu ao inserir o material do jato no
    lugar errado da lista — e o sintoma no jogo foi o executavel abrir e ficar
    pendurado, sem cena e sem janela de erro. Barato conferir, caro descobrir.
    """
    declarados = set()
    for i, linha in enumerate(linhas, 1):
        if linha.startswith("[sub_resource "):
            ident = linha.split('id="', 1)[1].split('"', 1)[0]
            declarados.add(ident)
            continue
        pos = 0
        while True:
            pos = linha.find('SubResource("', pos)
            if pos < 0:
                break
            pos += len('SubResource("')
            ident = linha[pos:linha.index('"', pos)]
            if ident not in declarados:
                raise SystemExit(
                    "linha %d: SubResource(\"%s\") citado antes de ser "
                    "declarado — mova o sub-recurso para cima" % (i, ident))


# --------------------------------------------------------------------------
# a cena


def main():
    with open(PONTOS) as fp:
        pontos = json.load(fp)

    usados = sorted(set(p["tipo"] for p in pontos["props"])
                    | set(["fogo_tambor", "fogo_pedra"]))
    externos = list(EXTERNOS)
    ident_de = {}
    por_caminho = {}
    for i, tipo in enumerate(usados):
        if tipo not in PROPS:
            raise SystemExit("prop sem modelo no mapa PROPS: " + tipo)
        caminho = PROPS[tipo][0]
        # dois tipos podem apontar pro MESMO modelo (o tambor de sucata e o
        # tambor de fogueira). Repetir o caminho em dois ext_resource faz o
        # Godot reclamar de recurso duplicado ao abrir a cena.
        if caminho not in por_caminho:
            por_caminho[caminho] = "p%02d_%s" % (i, tipo)
            externos.append(("PackedScene", caminho, por_caminho[caminho]))
        ident_de[tipo] = por_caminho[caminho]

    sub = sub_recursos(pontos)

    linhas = ["[gd_scene load_steps=%d format=3]" % (len(externos) + len(sub) + 1), ""]
    for tipo, caminho, ident in externos:
        linhas.append("[ext_resource type=\"%s\" path=\"%s\" id=\"%s\"]"
                      % (tipo, caminho, ident))
    linhas.append("")
    for ident, tipo, corpo in sub:
        linhas.append("[sub_resource type=\"%s\" id=\"%s\"]" % (tipo, ident))
        linhas.extend(corpo)
        linhas.append("")

    def no(nome, tipo=None, pai=None, instancia=None, props=(), metas=()):
        cab = "[node name=\"%s\"" % nome
        if tipo:
            cab += " type=\"%s\"" % tipo
        if pai:
            cab += " parent=\"%s\"" % pai
        if instancia:
            cab += " instance=ExtResource(\"%s\")" % instancia
        linhas.append(cab + "]")
        for chave, valor in props:
            linhas.append("%s = %s" % (chave, valor))
        for chave, valor in metas:
            linhas.append("metadata/%s = \"%s\"" % (chave, valor))
        linhas.append("")

    no("battlefield_2", tipo="Node3D", props=[("script", "ExtResource(\"5_script\")")])
    no("WorldEnvironment", tipo="WorldEnvironment", pai=".",
       props=[("environment", "SubResource(\"ambiente\")")])

    # --- as duas direcionais
    #
    # O sol vem de NORDESTE e RASANTE (12 graus). Rasante de propósito: e' o
    # que estica a sombra da fachada por cima da praca inteira e diz de longe
    # onde e' o alto e onde e' o buraco. Sombra ate' 110 m porque a arena tem
    # 80 e a ruina passa disso.
    no("sol", tipo="DirectionalLight3D", pai=".", props=[
        ("transform", transform_olhando((0.0, 30.0, 0.0), (-0.55, -0.50, 0.67))),
        ("light_color", cor((1.0, 0.50, 0.26, 1))),
        ("light_energy", "2.3"),
        ("light_indirect_energy", "1.2"),
        ("light_angular_distance", "1.6"),
        ("light_specular", "0.4"),
        ("shadow_enabled", "true"),
        # Sombra NAO opaca. Com 1.0 o que a ruina tapa fica preto de verdade e
        # o jogador le' aquilo como textura faltando — e, num anel de ruina de
        # 30 m de altura com sol baixo, isso e' metade da praca. Em 0.7 a
        # sombra continua pesada mas a pedra aparece dentro dela.
        ("shadow_opacity", "0.7"),
        ("shadow_bias", "0.06"),
        ("shadow_normal_bias", "1.4"),
        ("directional_shadow_mode", "2"),
        ("directional_shadow_split_1", "0.06"),
        ("directional_shadow_split_2", "0.19"),
        ("directional_shadow_split_3", "0.5"),
        ("directional_shadow_max_distance", "110.0"),
    ])
    # Contraluz fria, fraca e SEM sombra. Numa praca de 80 m com uma luz so',
    # todo o lado sul de cada coluna vira uma mancha preta e o jogador perde a
    # distancia. Esta aqui nao ilumina: ela desenha a borda.
    no("contraluz", tipo="DirectionalLight3D", pai=".", props=[
        ("transform", transform_olhando((0.0, 30.0, 0.0), (0.45, -0.78, -0.44))),
        ("light_color", cor((0.42, 0.52, 0.80, 1))),
        ("light_energy", "0.85"),
        ("light_specular", "0.05"),
        ("shadow_enabled", "false"),
    ])

    no("modelo", pai=".", instancia="1_modelo",
       props=[("script", "ExtResource(\"6_materiais\")")])

    # --- luzes
    no("luzes", tipo="Node3D", pai=".")
    for i, (x, y, z) in enumerate(pontos["fogos"]):
        no("fogueira_%d" % i, tipo="OmniLight3D", pai="luzes", props=[
            ("transform", transform((x, y + 1.05, z))),
            ("light_color", cor((1.0, 0.47, 0.17, 1))),
            ("light_energy", "5.6"),
            ("light_indirect_energy", "1.4"),
            ("light_specular", "0.35"),
            ("shadow_enabled", "true" if i < 2 else "false"),
            ("omni_range", "13.5"),
            ("omni_attenuation", "1.3"),
        ], metas=[("piscar", "fogueira")])
    bx, by, bz = pontos["boca"]
    no("clarao_da_boca", tipo="OmniLight3D", pai="luzes", props=[
        ("transform", transform((bx, by + 0.4, bz))),
        ("light_color", cor((1.0, 0.21, 0.07, 1))),
        ("light_energy", "11.0"),
        ("light_indirect_energy", "2.0"),
        ("shadow_enabled", "false"),
        ("omni_range", "26.0"),
        ("omni_attenuation", "1.6"),
    ], metas=[("piscar", "pulso")])

    # --- as fogueiras: braseiro + chama + estalo
    no("fogo", tipo="Node3D", pai=".")
    for i, (x, y, z) in enumerate(pontos["fogos"]):
        tipo = "fogo_tambor" if i % 2 == 0 else "fogo_pedra"
        _, dy, _ = PROPS[tipo]
        no("braseiro_%d" % i, pai="fogo", instancia=ident_de[tipo],
           props=[("transform", transform((x, y + dy, z), giro_y=i * 0.9))])
        alto = 0.95 if tipo == "fogo_tambor" else 0.15
        no("chama_%d" % i, tipo="GPUParticles3D", pai="fogo", props=[
            ("transform", transform((x, y + alto, z))),
            ("amount", "22"),
            ("lifetime", "1.25"),
            ("preprocess", "1.0"),
            ("randomness", "0.4"),
            ("visibility_aabb", "AABB(-1.2, -0.6, -1.2, 2.4, 4.5, 2.4)"),
            ("process_material", "SubResource(\"proc_fogo\")"),
            ("draw_pass_1", "SubResource(\"quad_fogo\")"),
        ])
        if i % 3 == 0:
            no("estalo_%d" % i, tipo="AudioStreamPlayer3D", pai="fogo", props=[
                ("transform", transform((x, y + 0.6, z))),
                ("stream", "ExtResource(\"8_fogo_som\")"),
                ("volume_db", "-9.0"),
                ("unit_size", "6.0"),
                ("max_distance", "24.0"),
                ("autoplay", "true"),
                ("parameters/looping", "true"),
            ])

    # --- O FOGAREU
    #
    # Fica no meio da grelha que fecha a Boca. Quem liga e desliga isto e' o
    # `battlefield_2.gd`: as particulas nascem apagadas e a Area3D so' cobra
    # dano nos tiques em que o jato esta' de fato subindo.
    fx, fy, fz = pontos.get("fogareu", [0.0, 1.7, 0.0])
    no("fogareu", tipo="Node3D", pai=".", props=[("transform", transform((fx, fy, fz)))])
    no("jato", tipo="GPUParticles3D", pai="fogareu", props=[
        ("emitting", "false"),
        ("amount", "115"),
        ("lifetime", "1.7"),
        ("randomness", "0.35"),
        ("visibility_aabb", "AABB(-5, -1, -5, 10, 18, 10)"),
        ("process_material", "SubResource(\"proc_jato\")"),
        ("draw_pass_1", "SubResource(\"quad_jato\")"),
    ])
    no("aviso", tipo="GPUParticles3D", pai="fogareu", props=[
        ("emitting", "false"),
        ("amount", "55"),
        ("lifetime", "1.3"),
        ("randomness", "0.5"),
        ("visibility_aabb", "AABB(-4, -1, -4, 8, 8, 8)"),
        ("process_material", "SubResource(\"proc_aviso\")"),
        ("draw_pass_1", "SubResource(\"quad_fagulha\")"),
    ])
    # mask 5 = layer 1 (player) + layer 3 (inimigos). Quem estiver em cima da
    # grelha na hora se queima, seja de que lado for.
    no("area", tipo="Area3D", pai="fogareu", props=[
        ("transform", transform((0.0, 5.0, 0.0))),
        ("collision_layer", "0"),
        ("collision_mask", "5"),
        ("monitorable", "false"),
    ])
    no("forma", tipo="CollisionShape3D", pai="fogareu/area",
       props=[("shape", "SubResource(\"cil_fogareu\")")])
    no("estouro", tipo="AudioStreamPlayer3D", pai="fogareu", props=[
        ("stream", "ExtResource(\"9_estouro\")"),
        ("volume_db", "-5.0"),
        ("unit_size", "16.0"),
        ("max_distance", "70.0"),
    ])
    no("chiado", tipo="AudioStreamPlayer3D", pai="fogareu", props=[
        ("stream", "ExtResource(\"8_fogo_som\")"),
        ("volume_db", "-2.0"),
        ("pitch_scale", "0.55"),
        ("unit_size", "12.0"),
        ("max_distance", "45.0"),
    ])

    # --- props
    no("props", tipo="Node3D", pai=".")
    no("colisao_props", tipo="Node3D", pai=".")
    solidos = 0
    for i, p in enumerate(pontos["props"]):
        tipo = p["tipo"]
        caminho, dy, caixa = PROPS[tipo]
        x, y, z = p["pos"]
        giro = p["giro"]
        no("prop_%02d_%s" % (i, tipo), pai="props", instancia=ident_de[tipo],
           props=[("transform", transform((x, y + dy, z), giro, p["escala"]))])
        if not caixa:
            continue
        # A colisao dos props mora FORA da cena instanciada: o .gltf do Poly
        # Haven nao traz corpo nenhum, e pendurar um filho dentro da instancia
        # some se o modelo for reimportado. Layer 2 porque e' a unica que o
        # player enxerga.
        solidos += 1
        no("corpo_%02d" % i, tipo="StaticBody3D", pai="colisao_props", props=[
            ("transform", transform((x, y + caixa[1] / 2.0, z), giro)),
            ("collision_layer", "2"),
            ("collision_mask", "0"),
        ])
        no("forma", tipo="CollisionShape3D", pai="colisao_props/corpo_%02d" % i,
           props=[("shape", "SubResource(\"cx_%s\")" % tipo)])

    # --- ar: fagulha que sobe, cinza que cai
    no("ar", tipo="Node3D", pai=".")
    no("fagulhas", tipo="GPUParticles3D", pai="ar", props=[
        ("transform", transform((0.0, 7.0, 0.0))),
        ("amount", "230"),
        ("lifetime", "11.0"),
        ("preprocess", "8.0"),
        ("randomness", "0.6"),
        ("visibility_aabb", "AABB(-44, -12, -44, 88, 60, 88)"),
        ("process_material", "SubResource(\"proc_fagulha\")"),
        ("draw_pass_1", "SubResource(\"quad_fagulha\")"),
    ])
    no("cinza", tipo="GPUParticles3D", pai="ar", props=[
        ("transform", transform((0.0, 26.0, 0.0))),
        ("amount", "260"),
        ("lifetime", "17.0"),
        ("preprocess", "14.0"),
        ("randomness", "0.5"),
        ("visibility_aabb", "AABB(-46, -34, -46, 92, 46, 92)"),
        ("process_material", "SubResource(\"proc_cinza\")"),
        ("draw_pass_1", "SubResource(\"quad_cinza\")"),
    ])

    # --- navegacao
    #
    # `navigation_layers = 4` nao e' escolha: e' a camada em que os
    # `NavigationAgent3D` dos inimigos deste projeto ja' estao (ver
    # `scenes/enemies/enemy.tscn`). Numa camada diferente, o navmesh existe e
    # nenhum inimigo o enxerga.
    no("navegacao", tipo="NavigationRegion3D", pai=".", props=[
        ("navigation_mesh", "SubResource(\"navmesh\")"),
        ("navigation_layers", "4"),
    ])

    # --- poleiros das gargulas de fogo
    #
    # Sao as duas gargulas da arena 1. La' elas pousam nos quatro rochedos de
    # canto; aqui o poleiro e' o coroamento do anel de ruina, e sao dez pontos
    # em volta da praca inteira. Quem instancia as gargulas e' o
    # `battlefield_2.gd` — estes marcadores so' dizem ONDE da' pra pousar.
    no("pousos", tipo="Node3D", pai=".")
    for i, (x, y, z) in enumerate(pontos.get("pousos", [])):
        no("pouso_%d" % i, tipo="Marker3D", pai="pousos",
           props=[("transform", transform((x, y, z),
                                          giro_y=math.atan2(-x, -z)))])

    # --- marcadores de inimigo (ninguem nasce aqui ainda)
    no("enemies", tipo="Node3D", pai=".")
    for i, (x, y, z) in enumerate(pontos["inimigos"]):
        no("enemy_%d" % (i + 1), tipo="Marker3D", pai="enemies",
           props=[("transform", transform((x, y, z),
                                          giro_y=math.atan2(-x, -z)))])

    no("ambiente_som", tipo="AudioStreamPlayer", pai=".", props=[
        ("stream", "ExtResource(\"7_ambiente\")"),
        ("volume_db", "-11.0"),
        ("autoplay", "true"),
        ("parameters/looping", "true"),
    ])
    no("fade", pai=".", instancia="4_fade")
    no("Pause", pai=".", instancia="3_pause")

    px, _, pz = pontos["player"]
    no("Player", pai=".", instancia="2_player",
       props=[("transform", transform((px, 1.2, pz)))])

    conferir_ordem(linhas)

    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    with open(SAIDA, "w") as fp:
        fp.write("\n".join(linhas).rstrip() + "\n")

    print("--- cena da arena 2 ---")
    print("  %s" % SAIDA)
    print("  externos=%d sub-recursos=%d" % (len(externos), len(sub)))
    print("  fogueiras=%d props=%d (com colisao: %d) inimigos=%d"
          % (len(pontos["fogos"]), len(pontos["props"]), solidos,
             len(pontos["inimigos"])))
    print("  poleiros de gargula=%d" % len(pontos.get("pousos", [])))
    print("  navmesh: %d vertices, %d poligonos"
          % (len(pontos["navmesh"]["v"]), len(pontos["navmesh"]["p"])))
    print("  luzes omni: %d (limite do renderer mobile e' 8 POR MALHA)"
          % (len(pontos["fogos"]) + 1))


if __name__ == "__main__":
    main()
