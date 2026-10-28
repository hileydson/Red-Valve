# -*- coding: utf-8 -*-
"""Monta a cena do INFERNO 3 (inferno_3.tscn) e os materiais dele.

    python3 tools/godot/inferno_3/gerar_cena_inferno_3.py

Le':   red-valve/assets/3d_model/stages/inferno_3/inferno_3_pontos.json
Grava: red-valve/scenes/stages/inferno_3/inferno_3.tscn
       red-valve/assets/3d_model/stages/inferno_3/materiais/*.tres

==============================================================================
A LUZ — ESCURO DE VERDADE, MAS COM FORMA

A cidade e' de noite, com nevoa, e quem anda e' o Maycow NORMAL, com a
lanterna. O escuro tem de pedir a lanterna sem virar tela preta:
  - o ceu e' quase preto, com uma LUA palida grande atras da catedral e
    nuvem escura com a borda acesa por ela; a lua e' a unica direcional
    (fraca, fria, com sombra) — e' o contorno de telhado contra o ceu que
    desenha a cidade de longe;
  - ambiente baixo e frio (0,32) sobre pedra de albedo NORMAL: sem lanterna
    a rua mostra a FORMA das coisas, nao o detalhe. O escuro vem do ambiente,
    nunca da pedra preta — com albedo 0,2 o facho, que bate rasante a 7 m,
    nao devolvia nada e a lanterna parecia desligada (medido no harness);
  - nevoa ESCURA (azul-chumbo) e densa: a 40 m tudo some — e' Silent Hill,
    e e' por ela que a poca de luz do proximo lampiao vira o farol;
  - nevoa baixa grossa abaixo de -4 m: o abismo e' um mar de nevoa;
  - a lente da escola (`escola_lente.gdshader`) com gama < 1: tira as
    sombras do primeiro degrau do filtro PS1 do jogador (32 degraus).
Omni so' nos lampioes acesos (~2 em cada 3), na fogueira, nos dois portais,
na rosacea e nas velas do altar. O chao e' quebrado em setores de 48 m.
"""

import json
import math
import os
import sys

# o .pyc da base nao pode nascer antes de ela desligar o bytecode
sys.dont_write_bytecode = True
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "cenarios"))

import tscn as T  # noqa: E402
from tscn import cor, processo, quad, rampa, transform, transform_olhando  # noqa: E402

PONTOS = os.path.join(T.BASE, "assets/3d_model/stages/inferno_3/inferno_3_pontos.json")
SAIDA = os.path.join(T.BASE, "scenes/stages/inferno_3/inferno_3.tscn")
MAT_DIR = os.path.join(T.BASE, "assets/3d_model/stages/inferno_3/materiais")
MAT_RES = "res://assets/3d_model/stages/inferno_3/materiais/"


def materiais():
    m = lambda n: os.path.join(MAT_DIR, n)  # noqa: E731
    os.makedirs(MAT_DIR, exist_ok=True)
    # chao: pedra molhada (a lanterna corre no brilho dela)
    T.material_textura(m("mat_paralelepipedo.tres"), *T.tex_city("cobble"), albedo=(0.48, 0.46, 0.46, 1),
                       rough=0.72, uv=0.32, normal_scale=1.3)
    T.material_textura(m("mat_paralelepipedo_gasto.tres"), *T.tex_city("cobble_worn"), albedo=(0.44, 0.42, 0.4, 1),
                       rough=0.78, uv=0.32, normal_scale=1.3)
    T.material_textura(m("mat_cascalho.tres"), *T.tex_city("dirt"), albedo=(0.4, 0.36, 0.32, 1), uv=0.3)
    T.material_textura(m("mat_calcada.tres"), *T.tex_city("slate"), albedo=(0.4, 0.4, 0.42, 1), uv=0.3,
                       rough=0.7)
    T.material_textura(m("mat_terra.tres"), *T.tex_ph("brown_mud_02"), albedo=(0.3, 0.26, 0.22, 1), uv=0.2)
    T.material_textura(m("mat_rocha.tres"), *T.tex_ph("rock_wall_08"), albedo=(0.28, 0.26, 0.26, 1), uv=0.08,
                       normal_scale=1.3)
    # pedra das casas, da ponte e da catedral
    T.material_textura(m("mat_fachada_pedra.tres"), *T.tex_city("stone_church"), albedo=(0.48, 0.46, 0.48, 1),
                       uv=0.35, normal_scale=1.1)
    T.material_textura(m("mat_fachada_tijolo.tres"), *T.tex_ph("brick_wall_02"), albedo=(0.44, 0.32, 0.28, 1),
                       uv=0.3, normal_scale=1.1)
    T.material_textura(m("mat_fachada_reboco.tres"), *T.tex_city("plaster_raw"), albedo=(0.5, 0.48, 0.46, 1),
                       uv=0.3)
    T.material_textura(m("mat_pedra_clara.tres"), *T.tex_city("stone_cemetery"), albedo=(0.8, 0.78, 0.76, 1),
                       uv=0.45)
    T.material_textura(m("mat_pedra_ponte.tres"), *T.tex_city("stone_church"), albedo=(0.54, 0.52, 0.52, 1),
                       uv=0.25, normal_scale=1.2)
    T.material_textura(m("mat_pedra_catedral.tres"), *T.tex_city("stone_church"), albedo=(0.4, 0.39, 0.41, 1),
                       uv=0.22, normal_scale=1.2)
    T.material_textura(m("mat_degrau.tres"), *T.tex_city("stone_cemetery"), albedo=(0.64, 0.62, 0.6, 1), uv=0.4)
    T.material_textura(m("mat_telhado.tres"), *T.tex_ph("roof_slates_02"), albedo=(0.26, 0.26, 0.3, 1),
                       rough=0.6, uv=0.4)
    T.material_textura(m("mat_porta.tres"), *T.tex_city("wood"), albedo=(0.18, 0.13, 0.1, 1), uv=0.6)
    T.material_textura(m("mat_madeira.tres"), *T.tex_ph("dark_wooden_planks"), albedo=(0.34, 0.24, 0.18, 1), uv=0.6)
    T.material_textura(m("mat_madeira_queimada.tres"), *T.tex_ph("dark_wooden_planks"), albedo=(0.1, 0.08, 0.07, 1),
                       uv=0.6)
    T.material_textura(m("mat_tronco.tres"), *T.tex_city("wood"), albedo=(0.22, 0.19, 0.17, 1), uv=0.7)
    T.material_textura(m("mat_ferro.tres"), *T.tex_ph("rusty_metal_02"), albedo=(0.24, 0.2, 0.2, 1),
                       rough=0.55, uv=0.6, extras=["metallic = 0.6"])
    T.material_textura(m("mat_chapa.tres"), *T.tex_city("metal_corr"), albedo=(0.48, 0.28, 0.18, 1),
                       rough=0.7, uv=0.5, extras=["metallic = 0.4"])
    T.material_textura(m("mat_lapide.tres"), *T.tex_city("stone_cemetery"), albedo=(0.58, 0.58, 0.6, 1), uv=0.5)
    T.material_textura(m("mat_lapide_clara.tres"), *T.tex_city("stone_cemetery"), albedo=(0.85, 0.85, 0.85, 1),
                       uv=0.5)
    T.material_textura(m("mat_terra_solta.tres"), *T.tex_ph("brown_mud_02"), albedo=(0.26, 0.22, 0.18, 1), uv=0.5)
    T.material_textura(m("mat_carne_seca.tres"), *T.tex_city("plaster_raw"), albedo=(0.3, 0.15, 0.12, 1),
                       rough=0.9, uv=1.4, normal_scale=1.2)
    T.material_textura(m("mat_corda.tres"), *T.tex_city("plaster_raw"), albedo=(0.52, 0.4, 0.28, 1), uv=1.2)
    T.material_textura(m("mat_obsidiana.tres"), *T.tex_city("stone_cemetery"), albedo=(0.16, 0.15, 0.18, 1),
                       rough=0.35, uv=0.4, extras=["metallic_specular = 0.8"])
    T.material_textura(m("mat_osso.tres"), *T.tex_city("stone_cemetery"), albedo=(0.85, 0.85, 0.82, 1), uv=0.5)
    T.material_chapado(m("mat_janela.tres"), (0.02, 0.025, 0.035, 1), rough=0.15,
                       extras=["metallic_specular = 0.9"])
    T.material_chapado(m("mat_vidro_apagado.tres"), (0.04, 0.045, 0.05, 1), rough=0.2)
    T.material_chapado(m("mat_sangue.tres"), (0.13, 0.0, 0.005, 1), rough=0.18,
                       extras=["metallic_specular = 0.7"])
    T.material_chapado(m("mat_carvao.tres"), (0.035, 0.028, 0.024, 1))
    T.material_chapado(m("mat_silhueta.tres"), (0.035, 0.037, 0.045, 1))
    T.material_chapado(m("mat_escuro.tres"), (0.0, 0.0, 0.0, 1), extras=["shading_mode = 0"])
    T.material_chapado(m("mat_sombra.tres"), (0.0, 0.0, 0.0, 1), extras=["shading_mode = 0"])
    T.material_chapado(m("mat_buraco.tres"), (0.0, 0.0, 0.0, 1), extras=["shading_mode = 0"])
    T.material_emissivo(m("mat_janela_acesa.tres"), (0.3, 0.2, 0.08, 1), (1, 0.6, 0.27, 1), 1.5)
    T.material_emissivo(m("mat_vidro_lampiao.tres"), (0.6, 0.5, 0.3, 1), (1, 0.72, 0.38, 1), 3.0)
    T.material_emissivo(m("mat_vela.tres"), (0.9, 0.85, 0.7, 1), (1, 0.8, 0.5, 1), 1.2)
    T.material_emissivo(m("mat_vitral.tres"), (0.3, 0.02, 0.02, 1), (0.85, 0.08, 0.05, 1), 2.4)
    T.material_emissivo(m("mat_brasa.tres"), (0.3, 0.05, 0.04, 1), (0.9, 0.22, 0.14, 1), 1.6)
    T.material_emissivo(m("mat_sigilo.tres"), (0.4, 0.03, 0.03, 1), (1, 0.1, 0.05, 1), 2.0)


TABELA = {k: "mat_%s.tres" % k for k in (
    "paralelepipedo", "paralelepipedo_gasto", "cascalho", "calcada", "terra", "rocha", "fachada_pedra",
    "fachada_tijolo", "fachada_reboco", "pedra_clara", "pedra_ponte", "pedra_catedral", "degrau", "telhado",
    "porta", "madeira", "madeira_queimada", "tronco", "ferro", "chapa", "lapide", "lapide_clara", "terra_solta",
    "carne_seca", "corda", "obsidiana", "osso", "janela", "vidro_apagado", "sangue", "carvao", "silhueta",
    "escuro", "sombra", "buraco", "janela_acesa", "vidro_lampiao", "vela", "vitral", "brasa", "sigilo")}
# as gaiolas do inferno 2 vem com "metal"
TABELA["metal"] = "mat_ferro.tres"

# A lente desta cena: a da escola, um pouco mais fechada e mais fria.
LENTE = [
    ("barril", "0.0"),
    ("aberracao", "1.2"),
    ("exposicao", "1.0"),
    ("gama", "0.78"),
    ("piso_preto", "Color(0.012, 0.014, 0.02, 1)"),
    ("contraste", "1.06"),
    ("saturacao", "0.72"),
    ("tom_sombra", "Color(0.08, 0.1, 0.16, 1)"),
    ("tom_luz", "Color(1, 0.88, 0.72, 1)"),
    ("forca_tom", "0.38"),
    ("grao", "0.06"),
    ("vinheta", "0.9"),
    ("respiracao", "0.03"),
    ("interferencia", "0.15"),
]


def dicionario(d):
    return "{\n%s\n}" % ",\n".join('"%s": "%s"' % (k, v) for k, v in d.items())


def main():
    with open(PONTOS) as fp:
        P = json.load(fp)
    materiais()
    t = T.Tscn("inferno_3")

    script = t.ext("Script", "res://scripts/stages/inferno_3/inferno_3.gd")
    modelo = t.ext("PackedScene", "res://assets/3d_model/stages/inferno_3/inferno_3.glb")
    pintor = t.ext("Script", "res://scripts/stages/materiais_por_sufixo.gd")
    player = t.ext("PackedScene", "res://scenes/player/player.tscn")
    pause = t.ext("PackedScene", "res://scenes/configs/pause.tscn")
    minimapa = t.ext("PackedScene", "res://scenes/ui/minimap_inferno_3.tscn")
    fade = t.ext("PackedScene", "res://scenes/configs/fade.tscn")
    lanterna = t.ext("PackedScene", "res://assets/3d_model/player/lanterna/lanterna.glb")
    ceu_sh = t.ext("Shader", "res://shaders/environment/ceu_maldito.gdshader")
    portal_sh = t.ext("Shader", "res://shaders/environment/portal_vortice.gdshader")
    lente_sh = t.ext("Shader", "res://shaders/post_process/escola_lente.gdshader")
    s_vento = t.ext("AudioStream", "res://assets/sounds/cenarios/vento_frio.ogg")
    s_sino = t.ext("AudioStream", "res://assets/sounds/cenarios/sino.ogg")
    s_fogo = t.ext("AudioStream", "res://assets/sounds/common/fire_cracling.mp3")
    s_portal = t.ext("AudioStream", "res://assets/sounds/episodios/portal_red_valve.mp3")
    s_sussurro = t.ext("AudioStream", "res://assets/sounds/igreja/sussurro_culto.ogg")
    s_grito = t.ext("AudioStream", "res://assets/sounds/igreja/grito_monstro.ogg")
    s_amb = t.ext("AudioStream", "res://assets/sounds/igreja/ambiente_ritual.ogg")

    # ------------------------------------------------------------ ceu
    ruido = T.ruido_ceu(t, semente=1313, freq=0.011)
    t.sub("ceu_mat", "ShaderMaterial", [
        'shader = ExtResource("%s")' % ceu_sh,
        "shader_parameter/cor_zenite = Color(0.008, 0.009, 0.014, 1)",
        "shader_parameter/cor_horizonte = Color(0.05, 0.055, 0.07, 1)",
        "shader_parameter/cor_chao = Color(0.02, 0.022, 0.028, 1)",
        "shader_parameter/cor_nuvem = Color(0.022, 0.024, 0.032, 1)",
        "shader_parameter/cor_borda_nuvem = Color(0.16, 0.17, 0.21, 1)",
        'shader_parameter/ruido = SubResource("%s")' % ruido,
        "shader_parameter/escala_nuvem = 1.1", "shader_parameter/cobertura = 0.56",
        "shader_parameter/maciez = 0.34", "shader_parameter/vento = Vector2(0.006, 0.002)",
        "shader_parameter/lua_dir = Vector3(0.05, 0.26, -0.96)",
        "shader_parameter/lua_cor = Color(0.95, 0.93, 0.84, 1)",
        "shader_parameter/lua_tamanho = 0.07", "shader_parameter/lua_brilho = 1.5",
        "shader_parameter/lua_halo = 0.8", "shader_parameter/lua_eclipse = 0.0",
        "shader_parameter/vortice_forca = 0.0",
        "shader_parameter/estrelas = 0.12", "shader_parameter/brilho_baixo = 0.0",
        "shader_parameter/relampago = 0.0",
        "shader_parameter/relampago_cor = Color(0.75, 0.8, 1, 1)",
    ])
    t.sub("ceu", "Sky", ['sky_material = SubResource("ceu_mat")', "radiance_size = 1"])
    t.sub("ambiente", "Environment", [
        "background_mode = 2", 'sky = SubResource("ceu")',
        # COR (2), e nao ceu: com o ceu noturno quase preto o ambiente sumiria
        "ambient_light_source = 2", "ambient_light_color = " + cor((0.13, 0.15, 0.21, 1)),
        "ambient_light_energy = 0.32",
        # sem reflexo do ceu: a lua refletida na pedra molhada virava uma faixa
        # branca no meio da rua, e a rua ficava clara sem lanterna
        "reflected_light_source = 1",
        "tonemap_mode = 3", "tonemap_exposure = 1.65", "tonemap_white = 6.0",
        "glow_enabled = true", "glow_intensity = 0.6", "glow_strength = 1.0",
        "glow_bloom = 0.1", "glow_blend_mode = 1", "glow_hdr_threshold = 1.0",
        "fog_enabled = true", "fog_mode = 0",
        "fog_light_color = " + cor((0.045, 0.05, 0.064, 1)), "fog_light_energy = 1.0",
        "fog_sun_scatter = 0.0", "fog_density = 0.03", "fog_aerial_perspective = 0.1",
        "fog_sky_affect = 0.62",
        "fog_height = -4.0", "fog_height_density = 0.12",
        "adjustment_enabled = true", "adjustment_contrast = 1.12", "adjustment_saturation = 0.72",
    ])

    # ------------------------------------------------------------ particulas
    T.texturas_base(t)
    proc_fogo = T.fogo_preset(t)
    t.sub("mat_nevoa", "StandardMaterial3D", [
        "transparency = 1", "shading_mode = 0", "vertex_color_use_as_albedo = true",
        'albedo_texture = SubResource("tex_fumo")', "billboard_mode = 1",
        "billboard_keep_scale = true", "disable_receive_shadows = true",
        "distance_fade_mode = 1", "distance_fade_min_distance = 1.5",
        "distance_fade_max_distance = 9.0"])
    rampa(t, "nevoa", (0, 0.3, 0.7, 1), ((0.2, 0.22, 0.27, 0), (0.19, 0.21, 0.26, 0.2),
                                        (0.18, 0.2, 0.25, 0.15), (0.16, 0.18, 0.22, 0)))
    rampa(t, "cinza", (0, 0.2, 0.85, 1), ((0.55, 0.55, 0.57, 0), (0.5, 0.5, 0.52, 0.75),
                                          (0.48, 0.48, 0.5, 0.65), (0.45, 0.45, 0.47, 0)))
    rampa(t, "fagulha", (0, 0.3, 1), ((1, 0.72, 0.3, 0.9), (1, 0.35, 0.08, 0.7), (0.5, 0.08, 0.02, 0)))
    rampa(t, "fumo", (0, 0.3, 1), ((0.12, 0.1, 0.1, 0), (0.1, 0.09, 0.09, 0.45), (0.06, 0.06, 0.06, 0)))
    quad(t, "quad_nevoa", "mat_nevoa", 9.0, 9.0)
    quad(t, "quad_cinza", "mat_fosco", 0.05, 0.05)
    quad(t, "quad_fagulha", "mat_aditivo", 0.11, 0.11)
    quad(t, "quad_fumo", "mat_fumo", 3.0, 3.0)
    quad(t, "quad_fogo_grande", "mat_aditivo", 1.2, 1.7)
    processo(t, "proc_nevoa", emission_shape=3, emission_box_extents=(30, 0.8, 30),
             direction=(1, 0, 0.3), spread=40.0, initial_velocity_min=0.2, initial_velocity_max=0.6,
             gravity=(0, 0, 0), scale_min=0.7, scale_max=1.5, color_ramp='SubResource("r_nevoa")',
             turbulence_enabled=True, turbulence_noise_strength=0.3, turbulence_noise_scale=0.6)
    processo(t, "proc_cinza", emission_shape=3, emission_box_extents=(22, 1, 22),
             direction=(0.2, -1, 0.1), spread=20.0, initial_velocity_min=0.4, initial_velocity_max=0.9,
             gravity=(0.15, -0.35, 0.05), scale_min=0.6, scale_max=1.6, color_ramp='SubResource("r_cinza")',
             turbulence_enabled=True, turbulence_noise_strength=0.8, turbulence_noise_scale=1.2)
    processo(t, "proc_fagulha", emission_shape=1, emission_sphere_radius=1.8,
             direction=(0, 1, 0), spread=25.0, initial_velocity_min=1.5, initial_velocity_max=4.0,
             gravity=(0.3, 1.2, 0.1), scale_min=0.5, scale_max=1.4, color_ramp='SubResource("r_fagulha")',
             turbulence_enabled=True, turbulence_noise_strength=1.0, turbulence_noise_scale=1.3)
    processo(t, "proc_fumo", emission_shape=1, emission_sphere_radius=1.2,
             direction=(0, 1, 0), spread=12.0, initial_velocity_min=1.5, initial_velocity_max=2.6,
             gravity=(0.2, 0.5, 0.1), scale_min=0.8, scale_max=2.2, color_ramp='SubResource("r_fumo")')
    t.sub("ruido_portal_fn", "FastNoiseLite", ["noise_type = 3", "frequency = 0.03"])
    t.sub("ruido_portal", "NoiseTexture2D", ["width = 256", "height = 256", "seamless = true",
                                             'noise = SubResource("ruido_portal_fn")'])
    # o anel de chegada (o mesmo vermelho do inferno 2) e a porta da catedral,
    # palida: o que vem depois nao e' mais fogo
    t.sub("mat_portal", "ShaderMaterial", ['shader = ExtResource("%s")' % portal_sh,
                                           'shader_parameter/ruido = SubResource("ruido_portal")'])
    t.sub("mat_portal_porta", "ShaderMaterial", [
        'shader = ExtResource("%s")' % portal_sh, 'shader_parameter/ruido = SubResource("ruido_portal")',
        "shader_parameter/cor_borda = Color(0.72, 0.7, 0.86, 1)", "shader_parameter/cor_meio = Color(0.08, 0.05, 0.14, 1)",
        "shader_parameter/velocidade = 0.45", "shader_parameter/brilho = 1.0"])
    t.sub("malha_portal", "QuadMesh", ['material = SubResource("mat_portal")', "size = Vector2(23, 23)"])
    t.sub("malha_porta", "QuadMesh", ['material = SubResource("mat_portal_porta")', "size = Vector2(6.6, 11.6)"])
    t.sub("forma_saida", "BoxShape3D", ["size = Vector3(16, 8, 5)"])
    t.sub("forma_entrada", "BoxShape3D", ["size = Vector3(22, 26, 3)"])
    t.sub("forma_lanterna", "BoxShape3D", ["size = Vector3(3.2, 2.6, 3.2)"])
    t.sub("lente_mat", "ShaderMaterial", ['shader = ExtResource("%s")' % lente_sh]
          + ["shader_parameter/%s = %s" % kv for kv in LENTE])

    T.navmesh(t, P["navmesh"])

    # ------------------------------------------------------------ nos
    t.no("WorldEnvironment", "WorldEnvironment", props=[("environment", 'SubResource("ambiente")')])
    t.no("lua", "DirectionalLight3D", props=[
        ("transform", transform_olhando((0, 80, 0), (-0.05, -0.26, 0.96))),
        ("light_color", cor((0.62, 0.68, 0.86, 1))), ("light_energy", "0.3"),
        # sem brilho especular: a lua refletida na pedra molhada era uma faixa
        # branca no meio de toda rua que olha pro norte
        ("light_specular", "0.0"), ("shadow_enabled", "true"), ("shadow_opacity", "0.85"),
        ("shadow_bias", "0.06"), ("shadow_normal_bias", "1.4"), ("directional_shadow_mode", "2"),
        ("directional_shadow_max_distance", "70.0")])

    t.no("modelo", None, instancia=modelo, props=[
        ("script", 'ExtResource("%s")' % pintor), ("pasta", '"%s"' % MAT_RES),
        ("materiais", dicionario(TABELA)),
        ("sem_sombra", 'PackedStringArray("silhueta", "sombra", "escuro", "buraco", "janela_acesa", '
                       '"vidro_lampiao", "vela", "vitral", "brasa", "sigilo", "sangue")'),
        # a nevoa engole tudo a ~40 m: setor que esta' a mais de 150 m nem desenha
        ("alcance_visivel", "150.0"),
        ("sempre_visivel", 'PackedStringArray("silhueta", "pedra_catedral", "telhado")')])

    # --- luzes
    t.no("luzes", "Node3D")
    for i, (x, y, z, aceso) in enumerate(P["lampioes"]):
        if not aceso:
            continue
        t.no("lampiao_%d" % i, "OmniLight3D", "luzes", props=[
            ("transform", transform((x, y - 0.1, z))),
            ("light_color", cor((1.0, 0.68, 0.36, 1))), ("light_energy", "2.0"),
            ("light_indirect_energy", "0.8"), ("shadow_enabled", "false"),
            ("omni_range", "11.0"), ("omni_attenuation", "1.4")], metas=[("piscar", "vela")])
    fx, fy, fz = P["fogueira"]
    t.no("luz_fogueira", "OmniLight3D", "luzes", props=[
        ("transform", transform((fx, fy + 2.5, fz))),
        ("light_color", cor((1.0, 0.5, 0.2, 1))), ("light_energy", "6.0"),
        ("shadow_enabled", "true"), ("omni_range", "24.0"), ("omni_attenuation", "1.3")],
        metas=[("piscar", "fogueira")])
    rx, ry, rz = P["rosacea"]
    t.no("luz_rosacea", "OmniLight3D", "luzes", props=[
        ("transform", transform((rx, ry, rz))), ("light_color", cor((0.9, 0.12, 0.08, 1))),
        ("light_energy", "5.0"), ("shadow_enabled", "false"), ("omni_range", "30.0"),
        ("omni_attenuation", "1.6")], metas=[("piscar", "pulso")])
    cx_, cy_, cz_ = P["portal_chegada"]
    t.no("luz_chegada", "OmniLight3D", "luzes", props=[
        ("transform", transform((cx_, cy_ - 6.0, cz_ - 4.0))), ("light_color", cor((0.85, 0.28, 0.2, 1))),
        ("light_energy", "3.0"), ("shadow_enabled", "false"), ("omni_range", "16.0")],
        metas=[("piscar", "pulso")])
    px_, py_, pz_, ptx, ptz = P["porta"]
    t.no("luz_porta", "OmniLight3D", "luzes", props=[
        ("transform", transform((px_ - ptx * 3.0, py_ - 2.0, pz_ - ptz * 3.0))),
        ("light_color", cor((0.62, 0.52, 0.9, 1))), ("light_energy", "4.0"), ("shadow_enabled", "false"),
        ("omni_range", "18.0")], metas=[("piscar", "pulso")])
    for i, (x, y, z) in enumerate(P["velas"]):
        t.no("vela_%d" % i, "OmniLight3D", "luzes", props=[
            ("transform", transform((x, y + 0.1, z))), ("light_color", cor((1.0, 0.7, 0.4, 1))),
            ("light_energy", "0.9"), ("shadow_enabled", "false"), ("omni_range", "3.5")],
            metas=[("piscar", "vela")])

    # --- a lanterna no altar (o script some com ela se o jogador ja' a tem)
    lx, ly, lz, ldx, ldz = P["lanterna"]
    giro_l = math.atan2(ldz, -ldx)
    t.no("lanterna_no_chao", "Node3D")
    t.no("modelo", None, "lanterna_no_chao", instancia=lanterna,
         props=[("transform", transform((lx, ly + 0.052, lz), giro_l, 0.16))])
    t.no("facho", "SpotLight3D", "lanterna_no_chao", props=[
        ("transform", transform_olhando((lx + ldx * 0.18, ly + 0.07, lz + ldz * 0.18), (ldx, -0.22, ldz))),
        ("light_color", cor((1.0, 0.94, 0.82, 1))), ("light_energy", "16.0"), ("shadow_enabled", "false"),
        ("spot_range", "14.0"), ("spot_angle", "26.0"), ("spot_angle_attenuation", "0.45")])
    t.no("brilho", "OmniLight3D", "lanterna_no_chao", props=[
        ("transform", transform((lx + ldx * 0.3, ly + 0.1, lz + ldz * 0.3))),
        ("light_color", cor((1.0, 0.9, 0.75, 1))), ("light_energy", "0.7"), ("omni_range", "1.8")])
    t.no("area", "Area3D", "lanterna_no_chao", props=[
        ("transform", transform((lx + ldx * 1.6, ly - 0.4, lz + ldz * 1.6))),
        ("collision_layer", "0"), ("monitorable", "false")])
    t.no("CollisionShape3D", "CollisionShape3D", "lanterna_no_chao/area",
         props=[("shape", 'SubResource("forma_lanterna")')])

    # --- as piras da porta da catedral
    for i, (x, y, z) in enumerate(P["piras_catedral"]):
        t.no("luz_pira_%d" % i, "OmniLight3D", "luzes", props=[
            ("transform", transform((x, y + 1.6, z))), ("light_color", cor((1.0, 0.55, 0.25, 1))),
            ("light_energy", "6.5"), ("shadow_enabled", "false"), ("omni_range", "22.0"),
            ("omni_attenuation", "1.2")], metas=[("piscar", "fogueira")])

    # --- a fogueira
    t.no("fogo", "Node3D")
    T.particulas(t, "chamas", "fogo", (fx, fy, fz), proc_fogo, "quad_fogo_grande", 70, 1.6,
                 (-4, -1, -4, 8, 12, 8), extras=[("preprocess", "1.0"), ("randomness", "0.4"), ("scale", "Vector3(2.4, 2.4, 2.4)")])
    T.particulas(t, "fagulhas", "fogo", (fx, fy + 1.0, fz), "proc_fagulha", "quad_fagulha", 60, 3.5,
                 (-8, -2, -8, 16, 26, 16), extras=[("preprocess", "2.0")])
    T.particulas(t, "fumaca", "fogo", (fx, fy + 4.0, fz), "proc_fumo", "quad_fumo", 30, 7.0,
                 (-10, -2, -10, 20, 36, 20), extras=[("preprocess", "4.0")])
    T.som(t, "estalo", "fogo", s_fogo, pos=(fx, fy, fz), volume=-2.0, unit=10.0, maxd=50.0)
    for i, (x, y, z) in enumerate(P["piras_catedral"]):
        T.particulas(t, "chama_pira_%d" % i, "fogo", (x, y - 0.1, z), proc_fogo, "quad_fogo", 28, 1.3,
                     (-1.6, -0.6, -1.6, 3.2, 5.5, 3.2), extras=[("preprocess", "1.0"), ("randomness", "0.4")])

    # --- ar: nevoa rasteira e cinza caindo, presas a' camera (altura tambem)
    t.no("ar", "Node3D")
    t.no("segue", "Node3D", "ar", props=[("transform", transform(tuple(P["player"])))])
    t.nos.append(['[node name="nevoa_rasteira" type="GPUParticles3D" parent="ar/segue" groups=["segue_camera"]]',
                  "transform = " + transform((0, -1.6, 0)), "amount = 130", "lifetime = 22.0",
                  "preprocess = 20.0", "randomness = 0.5",
                  "visibility_aabb = AABB(-60, -6, -60, 120, 14, 120)",
                  'process_material = SubResource("proc_nevoa")', 'draw_pass_1 = SubResource("quad_nevoa")'])
    t.nos.append(['[node name="cinza" type="GPUParticles3D" parent="ar/segue" groups=["segue_camera"]]',
                  "transform = " + transform((0, 10, 0)), "amount = 700", "lifetime = 16.0",
                  "preprocess = 14.0", "randomness = 0.5",
                  "visibility_aabb = AABB(-40, -24, -40, 80, 34, 80)",
                  'process_material = SubResource("proc_cinza")', 'draw_pass_1 = SubResource("quad_cinza")'])

    # --- os portais: o anel de chegada (volta pro inferno 2) e a porta (saida)
    t.no("redemoinho", "MeshInstance3D", props=[
        ("transform", transform((cx_, cy_, cz_ - 0.2), 3.14159)), ("mesh", 'SubResource("malha_portal")'),
        ("cast_shadow", "0")])
    T.som(t, "som_portal", ".", s_portal, pos=(cx_, cy_, cz_), volume=-6.0, unit=12.0, maxd=70.0)
    t.no("porta_redemoinho", "MeshInstance3D", props=[
        ("transform", transform((px_ - ptx * 0.12, py_, pz_ - ptz * 0.12), math.atan2(-ptx, -ptz))),
        ("mesh", 'SubResource("malha_porta")'), ("cast_shadow", "0")])
    T.som(t, "som_porta", ".", s_portal, pos=(px_, py_, pz_), volume=-8.0, unit=10.0, maxd=60.0)
    sx, sy, sz, stx, stz = P["saida"]
    t.no("saida", "Area3D", props=[("transform", transform((sx, sy + 3.0, sz), math.atan2(stx, stz))),
                                   ("collision_layer", "0"), ("collision_mask", "1"), ("monitorable", "false")])
    t.no("forma", "CollisionShape3D", "saida", props=[("shape", 'SubResource("forma_saida")')])
    ex, ey, ez = P["entrada"]
    t.no("entrada", "Area3D", props=[("transform", transform((ex, ey + 4.0, ez))), ("collision_layer", "0"),
                                     ("collision_mask", "1"), ("monitorable", "false")])
    t.no("forma", "CollisionShape3D", "entrada", props=[("shape", 'SubResource("forma_entrada")')])

    # --- marcadores
    t.no("areas", "Node3D")
    for nome, (x, y, z) in sorted(P["areas"].items()):
        t.no(nome, "Marker3D", "areas", props=[("transform", transform((x, y + 0.2, z)))])
    t.no("spawn_entrada", "Marker3D", props=[("transform", transform(tuple(P["player"])))])
    # quem volta da cena seguinte aparece de costas pra porta, no adro
    t.no("spawn_saida", "Marker3D", props=[("transform", transform((sx - stx * 6.0, sy + 0.3, sz - stz * 6.0),
                                                                   math.atan2(stx, stz)))])
    t.no("enemies", "Node3D")
    for i, (x, y, z) in enumerate(P["inimigos"]):
        t.no("enemy_%d" % (i + 1), "Marker3D", "enemies", props=[("transform", transform((x, y, z)))])

    # --- sons
    sx_, sy_, sz_ = P["sino"]
    T.som(t, "sino", ".", s_sino, pos=(sx_, sy_, sz_), volume=6.0, unit=60.0, maxd=900.0, autoplay=False,
          loop=False)
    T.som(t, "vento_som", ".", s_vento, volume=-10.0)
    T.som(t, "ambiente_som", ".", s_amb, volume=-16.0)
    T.som(t, "sussurro", ".", s_sussurro, volume=-14.0, autoplay=False, loop=False)
    T.som(t, "grito", ".", s_grito, volume=-18.0, autoplay=False, loop=False)

    # --- a lente: so' o 3D (CanvasLayer -1, por baixo do HUD e do filtro)
    t.no("lente", "CanvasLayer", props=[("layer", "-1")])
    t.no("tela", "ColorRect", "lente", props=[("material", 'SubResource("lente_mat")'),
                                               ("anchors_preset", "15"), ("anchor_right", "1.0"),
                                               ("anchor_bottom", "1.0"), ("grow_horizontal", "2"),
                                               ("grow_vertical", "2"), ("mouse_filter", "2")])
    t.no("fade", None, instancia=fade)
    t.no("Pause", None, instancia=pause)
    # o mapa do local no canto (e a aba MAPA do menu): prancha de
    # tools/godot/inferno/make_mapa_inferno.py
    t.no("minimapa", None, instancia=minimapa)
    px, py, pz = P["player"]
    t.no("Player", None, instancia=player, props=[("transform", transform((px, py + 1.0, pz), 0.0))])

    t.salvar(SAIDA, script_raiz=[
        ("script", 'ExtResource("%s")' % script),
        # o anel de chegada leva ao FIM do inferno 4 (que chega aqui pelo anel
        # do largo dele); a porta da catedral leva de volta a' porta red valve
        # do porao da escola
        ("cena_entrada", '"res://scenes/stages/inferno_4/inferno_4.tscn"'),
        ("cena_saida", '"res://scenes/stages/escola/porao.tscn"'),
        ("ponto_saida", '"red_valve"'),
        ("maycow_normal", "true"), ("salvar_ao_entrar", "true"), ("nevoa_do_player", '"alta"'),
        ("segue_camera_altura", "true"),
    ])


if __name__ == "__main__":
    main()
