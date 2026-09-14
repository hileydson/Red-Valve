"""Monta a cena do interior da igreja (.tscn) a partir do modelo e dos pontos.

    python3 tools/godot/igreja/gerar_cena_igreja.py

Le':   red-valve/assets/3d_model/stages/igreja/igreja_pontos.json
Salva: red-valve/scenes/stages/igreja/igreja_interior.tscn

O .tscn resultante e' um arquivo NORMAL do Godot: pode abrir, mexer e salvar
pelo editor. Rodar este script de novo SOBRESCREVE — ele existe pra quando a
planta mudar no Blender (o rombo anda, uma janela nasce) e as luzes precisarem
acompanhar sem ninguem recolocar spot por spot na mao.

==============================================================================
AS LUZES, QUE SAO O ASSUNTO PRINCIPAL

Um interior gotico e' um exercicio de escuridao com furos. A regra aqui:

  - Uma luz FORTE so': o feixe que desce pelo rombo da abobada. E' ela que diz
    onde e' o meio da igreja e por onde se entra na parte arruinada.
  - Os vitrais nao ganham lampada, ganham EMISSAO no material. Vinte janelas
    com spot seria uma luz por janela que o renderer ia descartar em silencio
    (limite de 8 omni + 8 spot POR MALHA) — e ainda custaria caro. So' cinco
    janelas escolhidas tem feixe de verdade.
  - O calor vem das tochas: omni curta (range 9) pra nao vazar pro setor
    vizinho e estourar o limite, com `metadata/piscar` — o mesmo truque de
    lampada nervosa que a casa do Jimmy usa.
  - Sombra ligada em quatro luzes no maximo. Sombra de omni custa seis faces
    de cubemap; numa nave com 40 mil triangulos isso aparece no frame.

A nevoa volumetrica do WorldEnvironment nao e' enfeite: sem ela o feixe do
rombo e' so' uma mancha clara no chao, e com ela vira a coluna de luz que faz
a cena.
"""

import json
import math
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
BASE = os.path.join(RAIZ, "red-valve")
PONTOS = os.path.join(BASE, "assets", "3d_model", "stages", "igreja",
                      "igreja_pontos.json")
SAIDA = os.path.join(BASE, "scenes", "stages", "igreja", "igreja_interior.tscn")

EXTERNOS = [
    ("PackedScene", "res://assets/3d_model/stages/igreja/igreja_interior.glb", "1_modelo"),
    ("PackedScene", "res://scenes/player/player.tscn", "2_player"),
    ("PackedScene", "res://scenes/configs/pause.tscn", "3_pause"),
    ("PackedScene", "res://scenes/configs/fade.tscn", "4_fade"),
    ("Script", "res://scripts/stages/igreja/igreja_interior.gd", "5_script"),
    ("Script", "res://scripts/stages/igreja/igreja_materiais.gd", "6_materiais"),
    ("AudioStream", "res://assets/sounds/episodios/ambiente_noise_sublime.mp3", "7_ambiente"),
    ("PackedScene", "res://assets/3d_model/player/lanterna/lanterna.glb", "8_lanterna"),
    # O minimapa: a igreja tem planta propria (nao e' a da cidade), desenhada
    # por `make_mapa_igreja.py`. Ele tambem e' quem diz a' aba MAPA do menu
    # qual mapa mostrar enquanto o jogador esta' aqui dentro.
    ("PackedScene", "res://scenes/ui/minimap_igreja.tscn", "9_minimapa"),
]

# --------------------------------------------------------------------------
# A LANTERNA LARGADA NO CHÃO
#
# É o objeto que o jogador vem buscar aqui, então ela tem de ser a primeira
# coisa que se vê ao entrar: fica acesa, caída NO CORREDOR CENTRAL, alguns
# passos adiante do portal, com o facho varrendo a nave rumo ao altar. A luz
# dela é forte de propósito — é isca.
#
# No corredor e não entre os bancos: a 3,4 m do eixo ela caía dentro de uma
# fileira, e a única coisa que dava para ver era o brilho vazando por baixo do
# assento.
#
# O modelo tem a LENTE apontando para -X local (conferido renderizando o .glb),
# e 1,9 unidade de comprimento; daí o giro de 90° (lente para +Z, na direção do
# altar) e a escala de 0,16, que deixa a lanterna com uns 30 cm de verdade.
LANTERNA_POS = (1.15, 0.05, 8.2)
LANTERNA_ESCALA = 0.16
LANTERNA_GIRO = math.pi * 0.5

# --------------------------------------------------------------------------
# O ITEM SECRETO
#
# Marcador vazio, sem nada dentro ainda: o item que vai nascer aqui e' assunto
# de outro dia. O que ja' existe hoje e' a INTERROGACAO no mapa em cima dele
# (`make_mapa_igreja.py` le' esta posicao daqui), e por isso ele precisa estar
# no gerador: colocado so' pelo editor, a proxima regeracao da cena o apagaria
# e o mapa apontaria para um marcador que nao existe mais.
#
# O lugar e' de proposito o canto mais dificil da igreja: galeria SUL, junto a'
# fachada. A escada de pedra sobe pela galeria NORTE, entao chegar ate' aqui
# obriga a subir de um lado, atravessar pela passarela de tabuas no meio da
# nave (Z=22) e voltar 16 m pelo outro lado.
ITEM_SECRETO_POS = (10.8866, 10.0872, 5.7526)


def vetor(v):
    return "Vector3(%s)" % ", ".join("%.4f" % c for c in v)


def cor(c):
    return "Color(%s)" % ", ".join("%.4f" % x for x in c)


def _norm(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return [c / n for c in v]


def _cruz(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0]]


def transform_olhando(pos, direcao):
    """Transform3D com o -Z do no' apontando pra `direcao` (as luzes do Godot
    iluminam pro proprio -Z)."""
    z = [-c for c in _norm(direcao)]
    cima = (0.0, 0.0, 1.0) if abs(z[1]) > 0.985 else (0.0, 1.0, 0.0)
    x = _norm(_cruz(cima, z))
    y = _cruz(z, x)
    nums = x + y + z + list(pos)
    return "Transform3D(%s)" % ", ".join("%.5f" % n for n in nums)


def transform_posto(pos, giro_y=0.0, tombo_z=0.0, escala=1.0):
    """Transform3D de um objeto largado: gira em Y, tomba em Z, escala igual.

    A ordem é Ry * Rz — primeiro o objeto aponta para onde tem de apontar,
    depois cai de lado. Invertida, o tombo giraria junto com a mira.
    """
    c, sn = math.cos(giro_y), math.sin(giro_y)
    ct, st = math.cos(tombo_z), math.sin(tombo_z)
    e = escala
    col_x = (e * c * ct, e * st, -e * sn * ct)
    col_y = (-e * c * st, e * ct, e * sn * st)
    col_z = (e * sn, 0.0, e * c)
    nums = list(col_x) + list(col_y) + list(col_z) + list(pos)
    return "Transform3D(%s)" % ", ".join("%.5f" % n for n in nums)


def transform_pos(pos, giro_y=0.0):
    c, s = math.cos(giro_y), math.sin(giro_y)
    nums = [c, 0, -s, 0, 1, 0, s, 0, c] + list(pos)
    return "Transform3D(%s)" % ", ".join("%.5f" % n for n in nums)


# --------------------------------------------------------------------------
# luzes


def montar_luzes(pontos):
    """(nome, tipo, transform, propriedades, metadados)"""
    luzes = []
    buraco = pontos["buraco_teto"]
    z_rombo = buraco[2]

    # --- o feixe do rombo: a unica luz grande da igreja
    luzes.append(("feixe_rombo", "SpotLight3D",
                  transform_olhando((0.6, buraco[1] + 1.5, z_rombo - 0.6),
                                    (0.04, -1.0, 0.10)),
                  {"light_color": cor((0.74, 0.82, 0.98, 1)),
                   "light_energy": 26.0,
                   "light_indirect_energy": 1.6,
                   "light_volumetric_fog_energy": 3.2,
                   "shadow_enabled": "true",
                   "shadow_bias": 0.06,
                   "distance_fade_enabled": "false",
                   "spot_range": 36.0, "spot_angle": 33.0,
                   "spot_angle_attenuation": 0.6,
                   "spot_attenuation": 0.9}, {}))
    # Segunda luz no MESMO buraco, logo ABAIXO da abobada e sem sombra. A de
    # cima projeta o recorte do rombo (e' ela que desenha a mancha no chao);
    # esta garante a coluna de luz descendo, que a de cima perde quase toda
    # entre as franjas de abobada que sobraram e as tercas caidas por cima do
    # vao. Duas luzes pro mesmo efeito porque uma faz o desenho e a outra faz o
    # volume.
    luzes.append(("feixe_rombo_interno", "SpotLight3D",
                  transform_olhando((0.2, buraco[1] - 1.8, z_rombo),
                                    (0.02, -1.0, 0.04)),
                  {"light_color": cor((0.70, 0.79, 0.96, 1)),
                   "light_energy": 9.0,
                   "light_volumetric_fog_energy": 4.0,
                   "shadow_enabled": "false",
                   "spot_range": 28.0, "spot_angle": 22.0,
                   "spot_angle_attenuation": 1.4}, {}))
    luzes.append(("rebote_rombo", "OmniLight3D",
                  transform_pos((0.0, 2.2, z_rombo)),
                  {"light_color": cor((0.62, 0.70, 0.92, 1)),
                   "light_energy": 4.0, "omni_range": 11.0,
                   "light_volumetric_fog_energy": 0.4}, {}))

    # --- feixes de janela escolhidos a dedo (ver cabecalho)
    escolhidas = [
        # (tipo alvo, z alvo, lado, energia, cor, sombra, angulo, alcance)
        ("baixa", 8.5, -1, 9.0, (0.58, 0.66, 0.92, 1), "true", 34.0, 24.0),
        ("baixa", 22.5, 1, 8.0, (0.55, 0.62, 0.88, 1), "true", 34.0, 24.0),
        ("galeria", 29.5, 1, 7.0, (0.60, 0.66, 0.90, 1), "false", 32.0, 22.0),
    ]
    for janela in pontos["janelas"]:
        for (tipo, z, lado, energia, c, sombra, ang, alc) in escolhidas:
            if janela["tipo"] != tipo or abs(janela["pos"][2] - z) > 0.3:
                continue
            if (janela["pos"][0] < 0) != (lado < 0):
                continue
            # A luz fica do lado de FORA da parede, nao no vao. Posta no vao
            # (que foi a primeira tentativa) ela ficava a 40 cm da jamba e
            # queimava a moldura inteira de branco, sem desenhar nada no chao.
            # Aqui ela atravessa o buraco da janela e e' a PAREDE que recorta o
            # feixe — por isso estas precisam de sombra: e' a sombra que
            # desenha o retangulo de luz no piso.
            fora = [lado * 16.0, janela["pos"][1] + 2.2, janela["pos"][2]]
            direcao = [-lado, -0.55, 0.0]
            nome = "feixe_%s_%d" % (tipo, int(z))
            luzes.append((nome, "SpotLight3D",
                          transform_olhando(fora, direcao),
                          {"light_color": cor(c), "light_energy": energia,
                           "light_volumetric_fog_energy": 2.4,
                           "shadow_enabled": sombra, "shadow_bias": 0.04,
                           "shadow_normal_bias": 1.2,
                           "spot_range": alc, "spot_angle": ang,
                           "spot_angle_attenuation": 0.8}, {}))

    # --- rosacea da fachada: entra por cima das costas de quem chega
    luzes.append(("feixe_rosacea", "SpotLight3D",
                  transform_olhando((0.0, 15.0, 1.2), (0.0, -0.62, 1.0)),
                  {"light_color": cor((0.95, 0.62, 0.40, 1)),
                   "light_energy": 9.0, "light_volumetric_fog_energy": 2.6,
                   "shadow_enabled": "false",
                   "spot_range": 30.0, "spot_angle": 34.0,
                   "spot_angle_attenuation": 0.7}, {}))

    # --- abside: contraluz dourado atras do altar
    luzes.append(("feixe_abside", "SpotLight3D",
                  transform_olhando((0.0, 8.6, 46.4), (0.0, -0.5, -1.0)),
                  {"light_color": cor((1.0, 0.84, 0.55, 1)),
                   "light_energy": 6.0, "light_volumetric_fog_energy": 2.2,
                   "shadow_enabled": "true", "shadow_bias": 0.05,
                   "spot_range": 22.0, "spot_angle": 38.0}, {}))

    # --- tochas de parede: o unico calor do lugar
    for i, p in enumerate(pontos["tochas"]):
        luzes.append(("tocha_%d" % i, "OmniLight3D", transform_pos(p),
                      {"light_color": cor((1.0, 0.52, 0.20, 1)),
                       "light_energy": 6.8, "omni_range": 5.5,
                       "light_volumetric_fog_energy": 1.1,
                       "shadow_enabled": "true" if i == 0 else "false"},
                      {"piscar": "nervoso" if i % 3 else "quebrado"}))

    # --- candelabros pendurados
    for i, p in enumerate(pontos["candelabros"]):
        luzes.append(("candelabro_%d" % i, "OmniLight3D",
                      transform_pos((p[0], p[1] + 0.25, p[2])),
                      {"light_color": cor((1.0, 0.62, 0.28, 1)),
                       "light_energy": 4.0, "omni_range": 6.0,
                       "light_volumetric_fog_energy": 0.9},
                      {"piscar": "nervoso"}))

    # --- velas do altar
    for i, p in enumerate(pontos["velas"]):
        luzes.append(("vela_%d" % i, "OmniLight3D", transform_pos(p),
                      {"light_color": cor((1.0, 0.68, 0.32, 1)),
                       "light_energy": 1.8, "omni_range": 4.0},
                      {"piscar": "nervoso"}))
    return luzes


# --------------------------------------------------------------------------
# a cena


# Fatias de Z usadas pelo gerador do Blender (ver SETORES em gerar_igreja.py).
# Repetidas aqui de proposito: e' o que permite conferir, SEM abrir o Godot,
# se alguma malha ficou com mais luzes do que o renderer mobile aceita.
FATIAS = [("a", -2.0, 5.0), ("b", 5.0, 12.0), ("c", 12.0, 19.0),
          ("d", 19.0, 26.0), ("e", 26.0, 33.0), ("f", 33.0, 49.0)]
LIMITE_MOBILE = 8


def _alcanca(pos, alcance, z0, z1):
    """A esfera de influencia da luz toca a fatia da nave?"""
    dx = max(abs(pos[0]) - 14.0, 0.0)
    dy = max(pos[1] - 27.0, 0.0) if pos[1] > 27.0 else max(-pos[1], 0.0)
    dz = 0.0
    if pos[2] < z0:
        dz = z0 - pos[2]
    elif pos[2] > z1:
        dz = pos[2] - z1
    return (dx * dx + dy * dy + dz * dz) <= alcance * alcance


def conferir_limite(luzes):
    """Avisa se alguma fatia recebe mais luz do que o renderer aguenta.

    O `rendering_method="mobile"` do projeto corta em 8 omni + 8 spot POR
    MALHA e NAO avisa: a luz simplesmente para de existir naquele objeto,
    normalmente a que esta' mais longe, o que produz aquele bug de "a tocha
    some quando eu ando pra tras". Melhor descobrir aqui.
    """
    problemas = []
    for (nome, z0, z1) in FATIAS:
        conta = {"OmniLight3D": 0, "SpotLight3D": 0}
        for (_, tipo, xform, props, _m) in luzes:
            pos = [float(v) for v in xform[len("Transform3D("):-1].split(",")[9:12]]
            alcance = float(props.get("omni_range", props.get("spot_range", 10.0)))
            if _alcanca(pos, alcance, z0, z1):
                conta[tipo] += 1
        marca = ""
        if conta["OmniLight3D"] > LIMITE_MOBILE or conta["SpotLight3D"] > LIMITE_MOBILE:
            marca = "  <== ACIMA DO LIMITE"
            problemas.append(nome)
        print("  fatia %s (z %5.1f..%5.1f): %d omni, %d spot%s"
              % (nome, z0, z1, conta["OmniLight3D"], conta["SpotLight3D"], marca))
    return problemas


def gerar():
    with open(PONTOS) as fp:
        pontos = json.load(fp)
    planta = pontos["planta"]
    luzes = montar_luzes(pontos)

    sub = []          # (id, tipo, linhas)
    sub.append(("ceu_mat", "ProceduralSkyMaterial", [
        "sky_top_color = Color(0.10, 0.12, 0.17, 1)",
        "sky_horizon_color = Color(0.26, 0.27, 0.31, 1)",
        "sky_curve = 0.18",
        "ground_bottom_color = Color(0.03, 0.03, 0.035, 1)",
        "ground_horizon_color = Color(0.1, 0.1, 0.12, 1)",
        "sun_angle_max = 3.0",
        "use_debanding = true",
    ]))
    sub.append(("ceu", "Sky", ["sky_material = SubResource(\"ceu_mat\")"]))
    sub.append(("ambiente", "Environment", [
        "background_mode = 2",
        "sky = SubResource(\"ceu\")",
        "background_energy_multiplier = 0.9",
        "ambient_light_source = 3",
        "ambient_light_color = Color(0.30, 0.33, 0.42, 1)",
        "ambient_light_sky_contribution = 0.5",
        "ambient_light_energy = 1.7",
        "reflected_light_source = 2",
        "tonemap_mode = 3",
        "tonemap_exposure = 1.05",
        "tonemap_white = 6.0",
        "ssr_enabled = false",
        "ssao_enabled = true",
        "ssao_radius = 1.8",
        "ssao_intensity = 3.2",
        "ssao_power = 1.6",
        "ssao_light_affect = 0.25",
        "ssil_enabled = true",
        "ssil_intensity = 0.8",
        "sdfgi_enabled = false",
        "glow_enabled = true",
        "glow_intensity = 0.55",
        "glow_strength = 1.05",
        "glow_bloom = 0.12",
        "glow_blend_mode = 1",
        "glow_hdr_threshold = 0.92",
        "fog_enabled = true",
        "fog_light_color = Color(0.20, 0.22, 0.27, 1)",
        "fog_light_energy = 0.8",
        "fog_density = 0.008",
        "fog_sky_affect = 0.2",
        "volumetric_fog_enabled = true",
        "volumetric_fog_density = 0.022",
        "volumetric_fog_albedo = Color(0.72, 0.74, 0.80, 1)",
        "volumetric_fog_emission_energy = 0.05",
        "volumetric_fog_length = 90.0",
        "volumetric_fog_detail_spread = 1.8",
        "volumetric_fog_ambient_inject = 0.4",
        "adjustment_enabled = true",
        "adjustment_brightness = 1.02",
        "adjustment_contrast = 1.08",
        "adjustment_saturation = 0.88",
    ]))
    sub.append(("caixa_porta", "BoxShape3D", ["size = Vector3(6, 3.4, 3.6)"]))
    sub.append(("caixa_lanterna", "BoxShape3D", ["size = Vector3(3.0, 2.6, 3.0)"]))

    # poeira: quadzinho billboard. `billboard_keep_scale` NAO e' opcional —
    # sem ele o billboard descarta a escala e scale_min/max viram enfeite.
    sub.append(("mat_poeira", "StandardMaterial3D", [
        "transparency = 1",
        "blend_mode = 1",
        "shading_mode = 0",
        "vertex_color_use_as_albedo = true",
        "albedo_color = Color(0.74, 0.76, 0.84, 0.16)",
        "billboard_mode = 3",
        "billboard_keep_scale = true",
        "disable_receive_shadows = true",
    ]))
    sub.append(("malha_poeira", "QuadMesh", [
        "material = SubResource(\"mat_poeira\")",
        "size = Vector2(0.03, 0.03)",
    ]))
    sub.append(("proc_poeira_rombo", "ParticleProcessMaterial", [
        "lifetime_randomness = 0.6",
        "emission_shape = 3",
        "emission_box_extents = Vector3(3.4, 10.0, 3.4)",
        "direction = Vector3(0.1, -1, 0.05)",
        "spread = 25.0",
        "initial_velocity_min = 0.12",
        "initial_velocity_max = 0.45",
        "gravity = Vector3(0.05, -0.22, 0)",
        "scale_min = 0.4",
        "scale_max = 1.5",
        "color = Color(1, 1, 1, 0.30)",
        "turbulence_enabled = true",
        "turbulence_noise_strength = 0.22",
        "turbulence_noise_scale = 1.6",
    ]))
    sub.append(("proc_poeira_nave", "ParticleProcessMaterial", [
        "lifetime_randomness = 0.8",
        "emission_shape = 3",
        "emission_box_extents = Vector3(12.0, 6.0, 20.0)",
        "direction = Vector3(0, -1, 0)",
        "spread = 60.0",
        "initial_velocity_min = 0.02",
        "initial_velocity_max = 0.16",
        "gravity = Vector3(0.02, -0.05, 0.01)",
        "scale_min = 0.3",
        "scale_max = 1.4",
        "color = Color(1, 1, 1, 0.16)",
        "turbulence_enabled = true",
        "turbulence_noise_strength = 0.15",
    ]))

    linhas = []
    linhas.append("[gd_scene load_steps=%d format=3]" % (len(EXTERNOS) + len(sub) + 1))
    linhas.append("")
    for tipo, caminho, ident in EXTERNOS:
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
        cab += "]"
        linhas.append(cab)
        for chave, valor in props:
            linhas.append("%s = %s" % (chave, valor))
        for chave, valor in metas:
            linhas.append("metadata/%s = \"%s\"" % (chave, valor))
        linhas.append("")

    no("igreja_interior", tipo="Node3D",
       props=[("script", "ExtResource(\"5_script\")")])
    no("WorldEnvironment", tipo="WorldEnvironment", pai=".",
       props=[("environment", "SubResource(\"ambiente\")")])
    no("modelo", pai=".", instancia="1_modelo",
       props=[("script", "ExtResource(\"6_materiais\")")])

    no("luzes", tipo="Node3D", pai=".")
    for nome, tipo, xform, props, metas in luzes:
        no(nome, tipo=tipo, pai="luzes",
           props=[("transform", xform)] + sorted(props.items()),
           metas=sorted(metas.items()))

    no("poeira", tipo="Node3D", pai=".")
    no("poeira_rombo", tipo="GPUParticles3D", pai="poeira", props=[
        ("transform", transform_pos((0.4, 14.0, pontos["buraco_teto"][2]))),
        ("amount", "150"),
        ("lifetime", "16.0"),
        ("preprocess", "8.0"),
        ("visibility_aabb", "AABB(-6, -14, -6, 12, 28, 12)"),
        ("process_material", "SubResource(\"proc_poeira_rombo\")"),
        ("draw_pass_1", "SubResource(\"malha_poeira\")"),
    ])
    no("poeira_nave", tipo="GPUParticles3D", pai="poeira", props=[
        ("transform", transform_pos((0.0, 7.0, 18.0))),
        ("amount", "160"),
        ("lifetime", "26.0"),
        ("preprocess", "14.0"),
        ("visibility_aabb", "AABB(-14, -8, -22, 28, 16, 44)"),
        ("process_material", "SubResource(\"proc_poeira_nave\")"),
        ("draw_pass_1", "SubResource(\"malha_poeira\")"),
    ])

    # --- a lanterna no chão
    lx, ly, lz = LANTERNA_POS
    no("lanterna_no_chao", tipo="Node3D", pai=".")
    no("modelo", pai="lanterna_no_chao", instancia="8_lanterna", props=[
        ("transform", transform_posto((lx, ly, lz), LANTERNA_GIRO, 0.14,
                                      LANTERNA_ESCALA))])
    # Facho apontado um grau ACIMA da horizontal e sem sombra. Rente ao chão
    # (que é onde a lanterna está, a 7 cm) o cone raspava o piso e o clarão
    # ficava invisível a cinco passos; e com sombra ligada era o próprio corpo
    # da lanterna, encostado na luz, que tapava metade do facho.
    no("facho", tipo="SpotLight3D", pai="lanterna_no_chao", props=[
        ("transform", transform_olhando((lx, ly + 0.03, lz + 0.18), (0.06, 0.055, 1.0))),
        ("light_color", cor((1.0, 0.94, 0.82, 1))),
        ("light_energy", "13.0"),
        ("light_volumetric_fog_energy", "4.0"),
        ("shadow_enabled", "false"),
        ("spot_range", "26.0"),
        ("spot_angle", "30.0"),
        ("spot_angle_attenuation", "0.45"),
    ])
    no("brilho", tipo="OmniLight3D", pai="lanterna_no_chao", props=[
        ("transform", transform_pos((lx, ly + 0.12, lz + 0.10))),
        ("light_color", cor((1.0, 0.9, 0.75, 1))),
        ("light_energy", "3.6"),
        ("omni_range", "6.0"),
    ])
    no("area", tipo="Area3D", pai="lanterna_no_chao", props=[
        ("transform", transform_pos((lx, ly + 1.0, lz))),
        ("collision_layer", "0"),
        ("collision_mask", "1"),
        ("monitorable", "false"),
    ])
    no("CollisionShape3D", tipo="CollisionShape3D", pai="lanterna_no_chao/area",
       props=[("shape", "SubResource(\"caixa_lanterna\")")])

    # --- porta: area de saida + o ponto onde o jogador nasce ao entrar
    no("porta", tipo="Area3D", pai=".", props=[
        ("transform", transform_pos((0.0, 1.7, 2.0))),
        ("collision_layer", "0"),
        ("collision_mask", "1"),
        ("monitorable", "false"),
    ])
    no("CollisionShape3D", tipo="CollisionShape3D", pai="porta", props=[
        ("shape", "SubResource(\"caixa_porta\")")])
    no("ponto_de_entrada", tipo="Marker3D", pai=".", props=[
        ("transform", transform_pos((0.0, 0.15, 5.0), math.pi))])

    no("Player", pai=".", instancia="2_player", props=[
        ("transform", transform_pos((0.0, 0.15, 5.0), math.pi))])

    no("item_secreto", tipo="Marker3D", pai=".", props=[
        ("transform", transform_pos(ITEM_SECRETO_POS))])

    no("ambiente_som", tipo="AudioStreamPlayer", pai=".", props=[
        ("stream", "ExtResource(\"7_ambiente\")"),
        ("volume_db", "-14.0"),
        ("autoplay", "true"),
    ])
    no("fade", pai=".", instancia="4_fade")
    no("pause", pai=".", instancia="3_pause")
    no("minimapa", pai=".", instancia="9_minimapa")

    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    with open(SAIDA, "w") as fp:
        fp.write("\n".join(linhas))
    print("cena:", SAIDA)
    print("  luzes: %d (%d spot, %d omni)"
          % (len(luzes), sum(1 for l in luzes if l[1] == "SpotLight3D"),
             sum(1 for l in luzes if l[1] == "OmniLight3D")))
    print("  planta:", json.dumps(planta))
    problemas = conferir_limite(luzes)
    if problemas:
        print("  ATENCAO: fatias acima do limite do renderer mobile:", problemas)


if __name__ == "__main__":
    gerar()
