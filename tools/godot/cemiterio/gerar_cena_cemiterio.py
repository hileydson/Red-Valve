# -*- coding: utf-8 -*-
"""Monta a cena do CEMITERIO (cemiterio.tscn) e os materiais dele.

    python3 tools/godot/cemiterio/gerar_cena_cemiterio.py

Le':   red-valve/assets/3d_model/stages/cemiterio/cemiterio_pontos.json
Grava: red-valve/scenes/stages/cemiterio/cemiterio.tscn
       red-valve/assets/3d_model/stages/cemiterio/materiais/*.tres

==============================================================================
A NEVOA

Silent Hill: a nevoa de profundidade e' DENSA (0,045, quase nada passa de
40 m) e cinza, e o ceu inteiro e' nevoa (`fog_sky_affect` alto). O que segura
a leitura do espaco e' o AMBIENTE claro e frio — sem ele, com o filtro PS1 de
32 degraus do player, tudo abaixo de ~8/255 vira preto e a nevoa perde a cara
de nevoa (vira escuro). Em cima disso:
  - nevoa rasteira: folhas grandes e quase transparentes andando devagar a 1 m
    do chao, que somem perto da camera (`distance_fade`), senao viram cortina;
  - cinza caindo (a "neve" de Silent Hill) presa a' camera pelo script;
  - fumaca saindo das covas abertas e fogos-fatuos verdes vagando.

A luz: lua fria e fraca (a nevoa ja' espalha), lampioes quentes na avenida e na
praca, velas nos anjos. Cota de 8 omni por malha: o chao e' quebrado em setores
de 30 m no Blender.
"""

import json
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "cenarios"))

import tscn as T  # noqa: E402
from tscn import cor, processo, quad, rampa, transform, transform_olhando  # noqa: E402

PONTOS = os.path.join(T.BASE, "assets/3d_model/stages/cemiterio/cemiterio_pontos.json")
SAIDA = os.path.join(T.BASE, "scenes/stages/cemiterio/cemiterio.tscn")
MAT_DIR = os.path.join(T.BASE, "assets/3d_model/stages/cemiterio/materiais")
MAT_RES = "res://assets/3d_model/stages/cemiterio/materiais/"


def materiais():
    m = lambda n: os.path.join(MAT_DIR, n)  # noqa: E731
    T.material_textura(m("mat_terra.tres"), *T.tex_ph("brown_mud_02"), albedo=(0.34, 0.31, 0.28, 1),
                       uv=0.22, normal_scale=1.0)
    T.material_textura(m("mat_terra_solta.tres"), *T.tex_ph("brown_mud_02"), albedo=(0.26, 0.22, 0.19, 1),
                       uv=0.6, normal_scale=1.3)
    T.material_textura(m("mat_grama.tres"), *T.tex_ph("aerial_grass_rock"), albedo=(0.40, 0.39, 0.33, 1),
                       uv=0.18, normal_scale=0.9)
    T.material_textura(m("mat_caminho.tres"), *T.tex_city("cobble_worn"), albedo=(0.46, 0.45, 0.44, 1),
                       uv=0.38, normal_scale=1.0)
    T.material_textura(m("mat_lajota.tres"), *T.tex_city("stone_cemetery"), albedo=(0.40, 0.40, 0.40, 1),
                       uv=0.28, normal_scale=1.0)
    T.material_textura(m("mat_lapide.tres"), *T.tex_city("stone_cemetery"), albedo=(0.50, 0.50, 0.49, 1),
                       uv=0.75, normal_scale=1.15)
    T.material_textura(m("mat_lapide_clara.tres"), *T.tex_city("plaster_raw"), albedo=(0.72, 0.70, 0.66, 1),
                       rough=0.8, uv=0.8, normal_scale=0.7)
    T.material_textura(m("mat_pedra_esc.tres"), *T.tex_city("stone_cemetery"), albedo=(0.26, 0.26, 0.27, 1),
                       uv=0.6, normal_scale=1.0)
    T.material_textura(m("mat_muro.tres"), *T.tex_city("stone_church"), albedo=(0.44, 0.43, 0.42, 1),
                       uv=0.45, normal_scale=1.1)
    T.material_textura(m("mat_metal.tres"), *T.tex_ph("rusty_metal_02"), albedo=(0.24, 0.21, 0.2, 1),
                       rough=0.75, uv=0.8, extras=["metallic = 0.7"])
    T.material_textura(m("mat_telhado.tres"), *T.tex_ph("roof_slates_02"), albedo=(0.30, 0.31, 0.33, 1),
                       uv=0.4, normal_scale=1.1)
    T.material_textura(m("mat_tronco.tres"), *T.tex_ph("rock_wall_08"), albedo=(0.17, 0.14, 0.12, 1),
                       uv=0.9, normal_scale=1.4)
    T.material_textura(m("mat_carne.tres"), *T.tex_city("plaster_raw"), albedo=(0.26, 0.04, 0.06, 1),
                       rough=0.45, uv=1.1, normal_scale=1.4,
                       extras=["rim_enabled = true", "rim = 0.45", "rim_tint = 0.2"])
    T.material_textura(m("mat_osso.tres"), *T.tex_city("plaster_raw"), albedo=(0.68, 0.63, 0.53, 1),
                       rough=0.85, uv=0.7, normal_scale=0.6)
    T.material_chapado(m("mat_porta.tres"), (0.025, 0.022, 0.022, 1))
    T.material_chapado(m("mat_buraco.tres"), (0.0, 0.0, 0.0, 1), extras=["shading_mode = 0"])
    T.material_chapado(m("mat_silhueta.tres"), (0.12, 0.12, 0.13, 1))
    T.material_emissivo(m("mat_sigilo.tres"), (0.05, 0.2, 0.12, 1), (0.35, 1.0, 0.65, 1), 2.6)
    # o sigilo da praca nasce quase apagado: `cemiterio.gd` acende na chegada do chefe
    T.material_emissivo(m("mat_sigilo_praca.tres"), (0.06, 0.08, 0.07, 1), (0.35, 1.0, 0.65, 1), 0.15)
    T.material_textura(m("mat_vela.tres"), *T.tex_city("plaster_raw"), albedo=(0.86, 0.82, 0.72, 1),
                       rough=0.6, uv=2.0, normal_scale=0.3)
    T.material_emissivo(m("mat_chama.tres"), (1, 0.7, 0.3, 1), (1, 0.62, 0.22, 1), 5.0,
                        extras=["shading_mode = 0"])
    T.material_emissivo(m("mat_luz.tres"), (0.9, 0.7, 0.4, 1), (1, 0.72, 0.38, 1), 2.4)
    T.material_emissivo(m("mat_vitral.tres"), (0.25, 0.02, 0.02, 1), (0.9, 0.1, 0.06, 1), 1.8)


TABELA = {k: "mat_%s.tres" % k for k in (
    "terra", "terra_solta", "grama", "caminho", "lajota", "lapide", "lapide_clara", "pedra_esc",
    "muro", "metal", "telhado", "tronco", "carne", "osso", "porta", "buraco", "silhueta",
    "sigilo", "sigilo_praca", "vela", "chama", "luz", "vitral")}


def dicionario(d):
    return "{\n%s\n}" % ",\n".join('"%s": "%s"' % (k, v) for k, v in d.items())


def main():
    with open(PONTOS) as fp:
        P = json.load(fp)
    materiais()
    t = T.Tscn("cemiterio")

    script = t.ext("Script", "res://scripts/stages/cemiterio/cemiterio.gd")
    modelo = t.ext("PackedScene", "res://assets/3d_model/stages/cemiterio/cemiterio.glb")
    pintor = t.ext("Script", "res://scripts/stages/materiais_por_sufixo.gd")
    player = t.ext("PackedScene", "res://scenes/player/player.tscn")
    pause = t.ext("PackedScene", "res://scenes/configs/pause.tscn")
    fade = t.ext("PackedScene", "res://scenes/configs/fade.tscn")
    ceu_sh = t.ext("Shader", "res://shaders/environment/ceu_maldito.gdshader")
    s_amb = t.ext("AudioStream", "res://assets/sounds/escola/atmosfera_fantasma.ogg")
    s_vento = t.ext("AudioStream", "res://assets/sounds/cenarios/vento_frio.ogg")
    s_trovao = t.ext("AudioStream", "res://assets/sounds/cenarios/trovao.ogg")
    s_sino = t.ext("AudioStream", "res://assets/sounds/cenarios/sino.ogg")
    s_sussurro = t.ext("AudioStream", "res://assets/sounds/igreja/sussurro_culto.ogg")

    # ------------------------------------------------------------ ceu e nevoa
    ruido = T.ruido_ceu(t, semente=5, freq=0.009)
    t.sub("ceu_mat", "ShaderMaterial", [
        'shader = ExtResource("%s")' % ceu_sh,
        "shader_parameter/cor_zenite = Color(0.16, 0.17, 0.19, 1)",
        "shader_parameter/cor_horizonte = Color(0.34, 0.35, 0.36, 1)",
        "shader_parameter/cor_chao = Color(0.2, 0.2, 0.21, 1)",
        "shader_parameter/cor_nuvem = Color(0.22, 0.23, 0.25, 1)",
        "shader_parameter/cor_borda_nuvem = Color(0.55, 0.58, 0.62, 1)",
        'shader_parameter/ruido = SubResource("%s")' % ruido,
        "shader_parameter/escala_nuvem = 0.8", "shader_parameter/cobertura = 0.75",
        "shader_parameter/maciez = 0.6", "shader_parameter/vento = Vector2(0.006, 0.002)",
        "shader_parameter/lua_dir = Vector3(0.35, 0.55, -0.76)",
        "shader_parameter/lua_cor = Color(0.85, 0.9, 1, 1)",
        "shader_parameter/lua_tamanho = 0.06", "shader_parameter/lua_brilho = 1.4",
        "shader_parameter/lua_halo = 1.6",
        "shader_parameter/vortice_forca = 0.0", "shader_parameter/estrelas = 0.0",
        "shader_parameter/relampago = 0.0",
    ])
    t.sub("ceu", "Sky", ['sky_material = SubResource("ceu_mat")', "radiance_size = 1"])
    t.sub("ambiente", "Environment", [
        "background_mode = 2", 'sky = SubResource("ceu")',
        "ambient_light_source = 2",
        "ambient_light_color = " + cor((0.46, 0.48, 0.5, 1)),
        "ambient_light_energy = 1.5",
        "reflected_light_source = 2",
        "tonemap_mode = 3", "tonemap_exposure = 1.2", "tonemap_white = 6.0",
        "glow_enabled = true", "glow_intensity = 0.55", "glow_strength = 1.0",
        "glow_bloom = 0.1", "glow_blend_mode = 0", "glow_hdr_threshold = 1.0",
        "fog_enabled = true", "fog_mode = 0",
        "fog_light_color = " + cor((0.40, 0.41, 0.43, 1)),
        "fog_light_energy = 1.0", "fog_sun_scatter = 0.0",
        "fog_density = 0.043", "fog_sky_affect = 0.9",
        "fog_height = 1.2", "fog_height_density = 0.06",
        "adjustment_enabled = true", "adjustment_contrast = 1.06",
        "adjustment_saturation = 0.55",
    ])

    # ------------------------------------------------------------ particulas
    T.texturas_base(t)
    # a nevoa rasteira some PERTO da camera: folha de 9 m colada no rosto vira
    # cortina cinza chapada
    t.sub("mat_nevoa", "StandardMaterial3D", [
        "transparency = 1", "shading_mode = 0", "vertex_color_use_as_albedo = true",
        'albedo_texture = SubResource("tex_fumo")', "billboard_mode = 1",
        "billboard_keep_scale = true", "disable_receive_shadows = true",
        "distance_fade_mode = 1", "distance_fade_min_distance = 1.5",
        "distance_fade_max_distance = 9.0"])
    rampa(t, "nevoa", (0, 0.3, 0.7, 1), ((0.62, 0.63, 0.65, 0), (0.6, 0.61, 0.63, 0.16),
                                        (0.58, 0.59, 0.61, 0.12), (0.55, 0.56, 0.58, 0)))
    rampa(t, "cinza", (0, 0.2, 0.85, 1), ((0.85, 0.85, 0.86, 0), (0.82, 0.82, 0.84, 0.8),
                                          (0.8, 0.8, 0.82, 0.7), (0.78, 0.78, 0.8, 0)))
    rampa(t, "fumaca_cova", (0, 0.3, 1), ((0.6, 0.62, 0.64, 0), (0.55, 0.57, 0.6, 0.22), (0.5, 0.52, 0.55, 0)))
    rampa(t, "fatuo", (0, 0.3, 0.7, 1), ((0.3, 1, 0.65, 0), (0.35, 1, 0.7, 0.85), (0.3, 0.9, 0.6, 0.7),
                                        (0.2, 0.7, 0.5, 0)))
    rampa(t, "vela", (0, 0.4, 1), ((1, 0.8, 0.4, 0.8), (1, 0.5, 0.15, 0.5), (0.4, 0.1, 0.05, 0)))
    quad(t, "quad_nevoa", "mat_nevoa", 9.0, 9.0)
    quad(t, "quad_cinza", "mat_fosco", 0.05, 0.05)
    quad(t, "quad_fumaca", "mat_fumo", 1.6, 1.6)
    quad(t, "quad_fatuo", "mat_aditivo", 0.32, 0.32)
    processo(t, "proc_nevoa", emission_shape=3, emission_box_extents=(34, 0.8, 34),
             direction=(1, 0, 0.3), spread=40.0, initial_velocity_min=0.2, initial_velocity_max=0.7,
             gravity=(0, 0, 0), scale_min=0.7, scale_max=1.5, color_ramp='SubResource("r_nevoa")',
             turbulence_enabled=True, turbulence_noise_strength=0.3, turbulence_noise_scale=0.6)
    processo(t, "proc_cinza", emission_shape=3, emission_box_extents=(22, 1, 22),
             direction=(0.2, -1, 0.1), spread=20.0, initial_velocity_min=0.4, initial_velocity_max=0.9,
             gravity=(0.15, -0.35, 0.05), scale_min=0.6, scale_max=1.6, color_ramp='SubResource("r_cinza")',
             turbulence_enabled=True, turbulence_noise_strength=0.8, turbulence_noise_scale=1.2)
    processo(t, "proc_fumaca", emission_shape=3, emission_box_extents=(0.45, 0.05, 0.9),
             direction=(0, 1, 0), spread=15.0, initial_velocity_min=0.15, initial_velocity_max=0.45,
             gravity=(0.1, 0.12, 0), scale_min=0.6, scale_max=1.8, color_ramp='SubResource("r_fumaca_cova")',
             turbulence_enabled=True, turbulence_noise_strength=0.4, turbulence_noise_scale=1.0)
    processo(t, "proc_fatuo", emission_shape=3, emission_box_extents=(50, 1.2, 54),
             direction=(0, 1, 0), spread=180.0, initial_velocity_min=0.1, initial_velocity_max=0.5,
             gravity=(0, 0.02, 0), scale_min=0.5, scale_max=1.2, color_ramp='SubResource("r_fatuo")',
             turbulence_enabled=True, turbulence_noise_strength=1.4, turbulence_noise_scale=0.4)
    processo(t, "proc_vela", emission_shape=1, emission_sphere_radius=0.35,
             direction=(0, 1, 0), spread=8.0, initial_velocity_min=0.1, initial_velocity_max=0.3,
             gravity=(0, 0.2, 0), scale_min=0.3, scale_max=0.6, color_ramp='SubResource("r_vela")')
    quad(t, "quad_vela", "mat_aditivo", 0.12, 0.18)

    # olhos na nevoa: atravessam a nevoa (disable_fog) de proposito
    t.sub("mat_olho", "StandardMaterial3D", [
        "transparency = 1", "albedo_color = Color(0.4, 0.02, 0.01, 0)",
        "emission_enabled = true", "emission = Color(1, 0.12, 0.04, 1)",
        "emission_energy_multiplier = 0.0", "disable_fog = true",
        "disable_receive_shadows = true"])
    t.sub("malha_olho", "SphereMesh", ['material = SubResource("mat_olho")', "radius = 0.055",
                                       "height = 0.07", "radial_segments = 8", "rings = 4"])

    T.navmesh(t, P["navmesh"])

    # ------------------------------------------------------------ nos
    t.no("WorldEnvironment", "WorldEnvironment", props=[("environment", 'SubResource("ambiente")')])
    t.no("lua", "DirectionalLight3D", props=[
        ("transform", transform_olhando((0, 40, 0), (-0.35, -0.55, 0.76))),
        ("light_color", cor((0.66, 0.72, 0.86, 1))), ("light_energy", "0.65"),
        ("light_specular", "0.2"), ("shadow_enabled", "true"), ("shadow_opacity", "0.6"),
        ("shadow_bias", "0.05"), ("shadow_normal_bias", "1.2"),
        ("directional_shadow_mode", "2"), ("directional_shadow_max_distance", "60.0")])
    t.no("relampago", "DirectionalLight3D", props=[
        ("transform", transform_olhando((0, 40, 0), (0.2, -0.9, -0.3))),
        ("light_color", cor((0.82, 0.86, 1.0, 1))), ("light_energy", "0.0"),
        ("shadow_enabled", "false")])

    t.no("modelo", None, instancia=modelo, props=[
        ("script", 'ExtResource("%s")' % pintor), ("pasta", '"%s"' % MAT_RES),
        ("materiais", dicionario(TABELA)),
        ("sem_sombra", 'PackedStringArray("silhueta", "sigilo", "chama", "luz", "vitral", "buraco")')])

    t.no("luzes", "Node3D")
    for i, (x, y, z) in enumerate(P["lanternas"]):
        t.no("lampiao_%d" % i, "OmniLight3D", "luzes", props=[
            ("transform", transform((x, y - 0.15, z))),
            ("light_color", cor((1.0, 0.72, 0.42, 1))), ("light_energy", "2.4"),
            ("light_indirect_energy", "0.8"), ("shadow_enabled", "true" if i < 2 else "false"),
            ("omni_range", "9.5"), ("omni_attenuation", "1.4")], metas=[("piscar", "vela")])
    for i, (x, y, z) in enumerate(P["velas"]):
        t.no("velas_%d" % i, "OmniLight3D", "luzes", props=[
            ("transform", transform((x, y, z))),
            ("light_color", cor((1.0, 0.6, 0.3, 1))), ("light_energy", "1.3"),
            ("shadow_enabled", "false"), ("omni_range", "4.5"), ("omni_attenuation", "1.6")],
            metas=[("piscar", "vela")])
    vx, vy, vz = P["vitral"]
    t.no("brasa_capela", "OmniLight3D", "luzes", props=[
        ("transform", transform((vx, vy, vz + 1.5))),
        ("light_color", cor((1.0, 0.18, 0.08, 1))), ("light_energy", "2.2"),
        ("shadow_enabled", "false"), ("omni_range", "8.0")], metas=[("piscar", "pulso")])

    # --- efeitos
    t.no("ar", "Node3D")
    t.no("segue", "Node3D", "ar", props=[("transform", transform((0, 0, 50)))])
    # os dois que andam com a camera ficam no grupo `segue_camera`
    t.nos.append(['[node name="nevoa_rasteira" type="GPUParticles3D" parent="ar/segue" groups=["segue_camera"]]',
                  "transform = " + transform((0, 1.3, 0)), "amount = 140", "lifetime = 22.0",
                  "preprocess = 20.0", "randomness = 0.5",
                  "visibility_aabb = AABB(-60, -4, -60, 120, 12, 120)",
                  'process_material = SubResource("proc_nevoa")', 'draw_pass_1 = SubResource("quad_nevoa")'])
    t.nos.append(['[node name="cinza" type="GPUParticles3D" parent="ar/segue" groups=["segue_camera"]]',
                  "transform = " + transform((0, 12, 0)), "amount = 900", "lifetime = 16.0",
                  "preprocess = 14.0", "randomness = 0.5",
                  "visibility_aabb = AABB(-40, -20, -40, 80, 30, 80)",
                  'process_material = SubResource("proc_cinza")', 'draw_pass_1 = SubResource("quad_cinza")'])
    T.particulas(t, "fogos_fatuos", "ar", (0, 1.4, 0), "proc_fatuo", "quad_fatuo", 22, 12.0,
                 (-60, -4, -64, 120, 14, 128), extras=[("preprocess", "10.0"), ("randomness", "0.6")])
    for i, (x, y, z) in enumerate(P["covas"]):
        T.particulas(t, "fumaca_cova_%d" % i, "ar", (x, y + 0.1, z), "proc_fumaca", "quad_fumaca", 14, 6.0,
                     (-4, -1, -4, 8, 8, 8), extras=[("preprocess", "4.0"), ("randomness", "0.5")])
    for i, (x, y, z) in enumerate(P["velas"]):
        T.particulas(t, "brilho_velas_%d" % i, "ar", (x / 0.93 * 0.95, y - 0.3, z / 0.93 * 0.95),
                     "proc_vela", "quad_vela", 10, 0.7, (-2, -1, -2, 4, 3, 4))

    # o molde dos olhos (o script duplica)
    t.no("olhos", "Node3D", props=[("transform", transform((0, -40, 0))), ("visible", "false")])
    for nome, dx in (("olho_e", -0.085), ("olho_d", 0.085)):
        t.no(nome, "MeshInstance3D", "olhos", props=[("transform", transform((dx, 0, 0))),
                                                    ("mesh", 'SubResource("malha_olho")'),
                                                    ("cast_shadow", "0")])

    t.no("enemies", "Node3D")
    for i, (x, y, z) in enumerate(P["inimigos"]):
        t.no("enemy_%d" % (i + 1), "Marker3D", "enemies",
             props=[("transform", transform((x, y, z), T.angulo_para(x, z)))])
    cx, cy, cz = P["chefe"]
    t.no("chefe", "Marker3D", props=[("transform", transform((cx, cy, cz), 0.0))])

    T.som(t, "ambiente_som", ".", s_amb, volume=-9.0)
    T.som(t, "vento_som", ".", s_vento, volume=-12.0)
    T.som(t, "trovao", ".", s_trovao, volume=-9.0, autoplay=False, loop=False)
    T.som(t, "sino", ".", s_sino, pos=(70.0, 20.0, -150.0), volume=4.0, unit=60.0, maxd=400.0,
          autoplay=False, loop=False)
    T.som(t, "sussurro", ".", s_sussurro, pos=(0.0, 1.6, 0.0), volume=-14.0, unit=5.0, maxd=22.0,
          autoplay=False, loop=False)
    t.no("fade", None, instancia=fade)
    t.no("Pause", None, instancia=pause)
    px, _, pz = P["player"]
    t.no("Player", None, instancia=player, props=[("transform", transform((px, 1.2, pz)))])

    t.salvar(SAIDA, script_raiz=[
        ("script", 'ExtResource("%s")' % script),
        ("maycow_normal", "true"), ("salvar_ao_entrar", "true"), ("nevoa_do_player", '"alta"'),
        ("relampagos", "true"), ("relampago_espera_min", "28.0"), ("relampago_espera_max", "70.0"),
        ("relampago_energia", "1.4"),
    ])


if __name__ == "__main__":
    main()
