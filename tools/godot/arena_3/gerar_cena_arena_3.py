# -*- coding: utf-8 -*-
"""Monta a cena da ARENA 3 (battlefield_3.tscn) e os materiais dela.

    python3 tools/godot/arena_3/gerar_cena_arena_3.py

Le':   red-valve/assets/3d_model/stages/battlefield_3/arena_3_pontos.json
Grava: red-valve/scenes/stages/battlefield/battlefield_3.tscn
       red-valve/assets/3d_model/stages/battlefield_3/materiais/*.tres

Rodar de novo SOBRESCREVE a cena (e os .tres). O modelo vem antes, do
`tools/blender/arena_3/gerar_arena_3.py`.

==============================================================================
A LUZ

Noite com LUA DE SANGUE ao norte, em cima do trono: e' ela a direcional
principal (vermelha, com sombra), e e' por isso que o trono se recorta contra
o ceu quando se chega pela ponte. Uma contraluz fria e fraca, sem sombra,
desenha a borda das coisas do outro lado. O relampago e' uma terceira
direcional, apagada, que o script acende.

Omni (cota de 8 POR MALHA do renderer mobile): seis braseiros, o halo do trono
e a lanterna do colosso. O chao e' quebrado em setores de 26 m no Blender,
entao nenhuma malha da praca enxerga mais que quatro ou cinco delas.

==============================================================================
O AR

Muito vento: rastros finos que cruzam a praca de leste pra oeste, cinza
andando junto, poeira subindo da beira do abismo, brasas subindo de baixo e
tres redemoinhos de poeira que o `battlefield_3.gd` passeia pela praca.
"""

import json
import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "cenarios"))

import tscn as T  # noqa: E402
from tscn import cor, processo, quad, rampa, transform, transform_olhando  # noqa: E402

PONTOS = os.path.join(T.BASE, "assets/3d_model/stages/battlefield_3/arena_3_pontos.json")
SAIDA = os.path.join(T.BASE, "scenes/stages/battlefield/battlefield_3.tscn")
MAT_DIR = os.path.join(T.BASE, "assets/3d_model/stages/battlefield_3/materiais")
MAT_RES = "res://assets/3d_model/stages/battlefield_3/materiais/"

LUA_DIR = (0.0, 0.40, -0.92)


def materiais():
    T.material_textura(os.path.join(MAT_DIR, "mat_pedra.tres"), *T.tex_city("stone_church"),
                       albedo=(0.40, 0.40, 0.44, 1), uv=0.42, normal_scale=1.0)
    T.material_textura(os.path.join(MAT_DIR, "mat_pedra_esc.tres"), *T.tex_city("stone_cemetery"),
                       albedo=(0.24, 0.22, 0.24, 1), uv=0.5, normal_scale=1.1)
    T.material_textura(os.path.join(MAT_DIR, "mat_osso.tres"), *T.tex_city("plaster_raw"),
                       albedo=(0.66, 0.6, 0.5, 1), rough=0.85, uv=0.7, normal_scale=0.6)
    T.material_textura(os.path.join(MAT_DIR, "mat_carne.tres"), *T.tex_city("plaster_raw"),
                       albedo=(0.24, 0.03, 0.05, 1), rough=0.5, uv=1.1, normal_scale=1.4,
                       extras=["rim_enabled = true", "rim = 0.4", "rim_tint = 0.15"])
    T.material_textura(os.path.join(MAT_DIR, "mat_metal.tres"), *T.tex_ph("rusty_metal_02"),
                       albedo=(0.34, 0.27, 0.24, 1), rough=0.7, uv=0.6,
                       extras=["metallic = 0.75"])
    T.material_textura(os.path.join(MAT_DIR, "mat_rocha.tres"), *T.tex_ph("rock_wall_08"),
                       albedo=(0.30, 0.26, 0.27, 1), uv=0.12, normal_scale=1.3)
    T.material_emissivo(os.path.join(MAT_DIR, "mat_brasa.tres"), (0.35, 0.06, 0.02, 1),
                        (1, 0.33, 0.07, 1), 2.8)
    T.material_emissivo(os.path.join(MAT_DIR, "mat_sigilo.tres"), (0.3, 0.02, 0.02, 1),
                        (1, 0.08, 0.04, 1), 4.2)
    T.material_chapado(os.path.join(MAT_DIR, "mat_silhueta.tres"), (0.07, 0.045, 0.055, 1))
    # o mar de brasa la' embaixo: so' emissao, e fraca — e' visto atraves de
    # 100 m de nevoa
    T.material_emissivo(os.path.join(MAT_DIR, "mat_abismo.tres"), (0.05, 0.01, 0.01, 1),
                        (0.75, 0.13, 0.03, 1), 1.4, extras=["shading_mode = 0"])


TABELA = {
    "pedra_esc": "mat_pedra_esc.tres", "pedra": "mat_pedra.tres", "osso": "mat_osso.tres",
    "carne": "mat_carne.tres", "metal": "mat_metal.tres", "rocha": "mat_rocha.tres",
    "brasa": "mat_brasa.tres", "sigilo": "mat_sigilo.tres", "silhueta": "mat_silhueta.tres",
    "abismo": "mat_abismo.tres",
}


def dicionario(d):
    return "{\n%s\n}" % ",\n".join('"%s": "%s"' % (k, v) for k, v in d.items())


def main():
    with open(PONTOS) as fp:
        P = json.load(fp)
    materiais()
    t = T.Tscn("battlefield_3")

    script = t.ext("Script", "res://scripts/stages/battlefield/battlefield_3.gd")
    modelo = t.ext("PackedScene", "res://assets/3d_model/stages/battlefield_3/arena_3.glb")
    pintor = t.ext("Script", "res://scripts/stages/materiais_por_sufixo.gd")
    player = t.ext("PackedScene", "res://scenes/player/player.tscn")
    pause = t.ext("PackedScene", "res://scenes/configs/pause.tscn")
    fade = t.ext("PackedScene", "res://scenes/configs/fade.tscn")
    ceu_sh = t.ext("Shader", "res://shaders/environment/ceu_maldito.gdshader")
    s_amb = t.ext("AudioStream", "res://assets/sounds/igreja/ambiente_ritual.ogg")
    s_vento = t.ext("AudioStream", "res://assets/sounds/cenarios/vento_tempestade.ogg")
    s_trovao = t.ext("AudioStream", "res://assets/sounds/cenarios/trovao.ogg")
    s_fogo = t.ext("AudioStream", "res://assets/sounds/common/fire_cracling.mp3")
    s_meteoro = t.ext("AudioStream", "res://assets/sounds/cenarios/meteoro.ogg")
    s_estouro = t.ext("AudioStream", "res://assets/sounds/common/explosao.mp3")

    # ------------------------------------------------------------ ceu
    ruido = T.ruido_ceu(t, semente=31, freq=0.011)
    t.sub("ceu_mat", "ShaderMaterial", [
        'shader = ExtResource("%s")' % ceu_sh,
        "shader_parameter/cor_zenite = Color(0.035, 0.016, 0.026, 1)",
        "shader_parameter/cor_horizonte = Color(0.19, 0.05, 0.05, 1)",
        "shader_parameter/cor_chao = Color(0.05, 0.012, 0.01, 1)",
        "shader_parameter/cor_nuvem = Color(0.07, 0.035, 0.045, 1)",
        "shader_parameter/cor_borda_nuvem = Color(0.62, 0.13, 0.06, 1)",
        'shader_parameter/ruido = SubResource("%s")' % ruido,
        "shader_parameter/escala_nuvem = 1.1",
        "shader_parameter/cobertura = 0.6",
        "shader_parameter/maciez = 0.34",
        "shader_parameter/vento = Vector2(0.018, 0.006)",
        "shader_parameter/lua_dir = Vector3(%g, %g, %g)" % LUA_DIR,
        "shader_parameter/lua_cor = Color(1, 0.2, 0.08, 1)",
        "shader_parameter/lua_tamanho = 0.085",
        "shader_parameter/lua_brilho = 4.6",
        "shader_parameter/lua_halo = 1.3",
        "shader_parameter/vortice_dir = Vector3(0, 0.86, -0.51)",
        "shader_parameter/vortice_forca = 1.6",
        "shader_parameter/vortice_raio = 0.62",
        "shader_parameter/vortice_cor = Color(0.95, 0.16, 0.05, 1)",
        "shader_parameter/vortice_brilho = 1.0",
        "shader_parameter/estrelas = 0.35",
        "shader_parameter/relampago = 0.0",
    ])
    t.sub("ceu", "Sky", ['sky_material = SubResource("ceu_mat")', "radiance_size = 1"])
    t.sub("ambiente", "Environment", [
        "background_mode = 2", 'sky = SubResource("ceu")',
        "ambient_light_source = 2",
        "ambient_light_color = " + cor((0.32, 0.30, 0.36, 1)),
        "ambient_light_energy = 1.55",
        "reflected_light_source = 2",
        "tonemap_mode = 3", "tonemap_exposure = 1.18", "tonemap_white = 6.0",
        "glow_enabled = true", "glow_intensity = 0.62", "glow_strength = 1.0",
        "glow_bloom = 0.08", "glow_blend_mode = 0", "glow_hdr_threshold = 1.05",
        "fog_enabled = true", "fog_mode = 0",
        "fog_light_color = " + cor((0.10, 0.045, 0.05, 1)),
        "fog_light_energy = 0.4", "fog_sun_scatter = 0.0",
        "fog_density = 0.0056", "fog_sky_affect = 0.16",
        "fog_height = -6.0", "fog_height_density = 0.035",
        "adjustment_enabled = true", "adjustment_contrast = 1.16",
        "adjustment_saturation = 0.82",
    ])

    # ------------------------------------------------------------ particulas
    T.texturas_base(t)
    proc_fogo = T.fogo_preset(t)
    rampa(t, "fagulha", (0, 0.3, 1), ((1, 0.72, 0.3, 0.9), (1, 0.35, 0.08, 0.7), (0.5, 0.08, 0.02, 0)))
    rampa(t, "cinza", (0, 0.3, 1), ((0.16, 0.13, 0.13, 0), (0.13, 0.11, 0.11, 0.55), (0.09, 0.08, 0.08, 0)))
    rampa(t, "risco", (0, 0.4, 1), ((0.7, 0.62, 0.6, 0), (0.62, 0.55, 0.53, 0.16), (0.5, 0.45, 0.44, 0)))
    rampa(t, "poeira", (0, 0.25, 1), ((0.42, 0.33, 0.3, 0), (0.36, 0.29, 0.27, 0.2), (0.25, 0.2, 0.2, 0)))
    rampa(t, "fumo_abismo", (0, 0.3, 1), ((0.25, 0.08, 0.06, 0), (0.2, 0.07, 0.06, 0.28), (0.1, 0.04, 0.04, 0)))
    rampa(t, "explosao", (0, 0.15, 0.5, 1), ((1, 0.95, 0.7, 1), (1, 0.5, 0.12, 0.9),
                                             (0.45, 0.1, 0.03, 0.5), (0.1, 0.05, 0.04, 0)))
    rampa(t, "rastro", (0, 0.3, 1), ((1, 0.8, 0.4, 0.8), (1, 0.35, 0.08, 0.5), (0.2, 0.06, 0.03, 0)))
    quad(t, "quad_fagulha", "mat_aditivo", 0.12, 0.12)
    quad(t, "quad_cinza", "mat_fosco", 0.07, 0.07)
    quad(t, "quad_risco", "mat_risco_fosco", 0.05, 2.2)
    quad(t, "quad_poeira", "mat_fumo", 2.4, 2.4)
    quad(t, "quad_fumo_abismo", "mat_fumo", 9.0, 9.0)
    quad(t, "quad_explosao", "mat_fumo_aditivo", 2.2, 2.2)
    quad(t, "quad_rastro", "mat_fumo_aditivo", 1.7, 1.7)

    vento = (-1.0, 0.0, -0.32)
    processo(t, "proc_risco", emission_shape=3, emission_box_extents=(10, 9, 56),
             direction=vento, spread=6.0, initial_velocity_min=16.0, initial_velocity_max=24.0,
             gravity=(0, -0.4, 0), scale_min=0.6, scale_max=1.3,
             color_ramp='SubResource("r_risco")', particle_flag_align_y=True)
    processo(t, "proc_cinza", emission_shape=3, emission_box_extents=(12, 10, 58),
             direction=vento, spread=18.0, initial_velocity_min=6.0, initial_velocity_max=11.0,
             gravity=(0, -0.35, 0), scale_min=0.5, scale_max=1.7,
             color_ramp='SubResource("r_cinza")', turbulence_enabled=True,
             turbulence_noise_strength=1.2, turbulence_noise_scale=1.4)
    processo(t, "proc_poeira_borda", emission_shape=6, emission_ring_axis=(0, 1, 0),
             emission_ring_height=1.0, emission_ring_radius=55.0, emission_ring_inner_radius=52.0,
             direction=(0, 1, 0), spread=25.0, initial_velocity_min=2.5, initial_velocity_max=6.0,
             gravity=(-1.2, 1.4, -0.4), damping_min=0.2, damping_max=0.6, scale_min=0.8, scale_max=2.4,
             color_ramp='SubResource("r_poeira")', turbulence_enabled=True,
             turbulence_noise_strength=0.8, turbulence_noise_scale=1.2)
    processo(t, "proc_brasa_abismo", emission_shape=6, emission_ring_axis=(0, 1, 0),
             emission_ring_height=4.0, emission_ring_radius=80.0, emission_ring_inner_radius=56.0,
             direction=(0, 1, 0), spread=20.0, initial_velocity_min=3.0, initial_velocity_max=7.0,
             gravity=(-1.6, 0.9, -0.5), scale_min=0.6, scale_max=1.6,
             color_ramp='SubResource("r_fagulha")', turbulence_enabled=True,
             turbulence_noise_strength=1.0, turbulence_noise_scale=1.5)
    processo(t, "proc_fumo_abismo", emission_shape=6, emission_ring_axis=(0, 1, 0),
             emission_ring_height=6.0, emission_ring_radius=110.0, emission_ring_inner_radius=62.0,
             direction=(0, 1, 0), spread=10.0, initial_velocity_min=2.0, initial_velocity_max=4.0,
             gravity=(-0.8, 0.4, -0.2), scale_min=1.0, scale_max=2.6,
             color_ramp='SubResource("r_fumo_abismo")')
    processo(t, "proc_brasa_praca", emission_shape=3, emission_box_extents=(46, 2, 46),
             direction=(0, 1, 0), spread=35.0, initial_velocity_min=0.5, initial_velocity_max=1.8,
             gravity=(-1.4, 0.6, -0.45), scale_min=0.5, scale_max=1.4,
             color_ramp='SubResource("r_fagulha")', turbulence_enabled=True,
             turbulence_noise_strength=0.9, turbulence_noise_scale=1.4)
    # redemoinho: anel pequeno com aceleracao tangencial e puxada pro centro
    processo(t, "proc_redemoinho", emission_shape=6, emission_ring_axis=(0, 1, 0),
             emission_ring_height=0.4, emission_ring_radius=1.6, emission_ring_inner_radius=0.4,
             direction=(0, 1, 0), spread=15.0, initial_velocity_min=2.5, initial_velocity_max=5.0,
             gravity=(0, 1.2, 0), tangential_accel_min=9.0, tangential_accel_max=14.0,
             radial_accel_min=-3.5, radial_accel_max=-1.5, scale_min=0.4, scale_max=1.3,
             color_ramp='SubResource("r_poeira")')
    processo(t, "proc_redemoinho_cisco", emission_shape=6, emission_ring_axis=(0, 1, 0),
             emission_ring_height=0.4, emission_ring_radius=1.3, emission_ring_inner_radius=0.2,
             direction=(0, 1, 0), spread=10.0, initial_velocity_min=3.0, initial_velocity_max=7.0,
             gravity=(0, 0.8, 0), tangential_accel_min=14.0, tangential_accel_max=20.0,
             radial_accel_min=-4.0, radial_accel_max=-2.0, scale_min=0.6, scale_max=1.4,
             color_ramp='SubResource("r_cinza")')
    # chuva de fogo
    processo(t, "proc_rastro", emission_shape=1, emission_sphere_radius=0.5,
             direction=(0, 1, 0), spread=180.0, initial_velocity_min=0.2, initial_velocity_max=1.0,
             gravity=(0, 1.5, 0), scale_min=0.6, scale_max=1.6,
             color_ramp='SubResource("r_rastro")')
    processo(t, "proc_explosao", emission_shape=1, emission_sphere_radius=0.6,
             direction=(0, 1, 0), spread=70.0, initial_velocity_min=4.0, initial_velocity_max=11.0,
             gravity=(0, -3.0, 0), damping_min=2.5, damping_max=4.0, scale_min=0.7, scale_max=2.2,
             color_ramp='SubResource("r_explosao")')
    processo(t, "proc_fogo_chao", emission_shape=1, emission_sphere_radius=1.4,
             direction=(0, 1, 0), spread=12.0, initial_velocity_min=0.5, initial_velocity_max=1.6,
             gravity=(0, 1.0, 0), scale_min=0.4, scale_max=1.0,
             color_ramp='SubResource("r_fogo")', turbulence_enabled=True,
             turbulence_noise_strength=0.5, turbulence_noise_scale=2.0)
    t.sub("mat_bola", "StandardMaterial3D", [
        "shading_mode = 0", "albedo_color = Color(1, 0.62, 0.25, 1)",
        "emission_enabled = true", "emission = Color(1, 0.42, 0.1, 1)",
        "emission_energy_multiplier = 6.0"])
    t.sub("malha_bola", "SphereMesh", ['material = SubResource("mat_bola")', "radius = 0.7",
                                       "height = 1.4", "radial_segments = 12", "rings = 6"])
    # anel de aviso no chao: textura radial que so' acende a borda
    t.sub("grad_anel", "Gradient", [
        "offsets = PackedFloat32Array(0, 0.62, 0.8, 0.9, 1)",
        "colors = PackedColorArray(1, 0.2, 0.05, 0.12, 1, 0.2, 0.05, 0.05, 1, 0.35, 0.08, 0.9, "
        "1, 0.2, 0.05, 0.5, 1, 0.1, 0.05, 0)"])
    t.sub("tex_anel", "GradientTexture2D", ['gradient = SubResource("grad_anel")', "width = 128",
                                            "height = 128", "fill = 1",
                                            "fill_from = Vector2(0.5, 0.5)", "fill_to = Vector2(1, 0.5)"])
    t.sub("mat_anel", "StandardMaterial3D", [
        "transparency = 1", "blend_mode = 1", "shading_mode = 0", "cull_mode = 2",
        'albedo_texture = SubResource("tex_anel")', "albedo_color = Color(1, 0.6, 0.4, 1)",
        "disable_receive_shadows = true"])
    t.sub("malha_anel", "PlaneMesh", ['material = SubResource("mat_anel")', "size = Vector2(7.2, 7.2)"])

    T.navmesh(t, P["navmesh"])

    # ------------------------------------------------------------ nos
    t.no("WorldEnvironment", "WorldEnvironment", props=[("environment", 'SubResource("ambiente")')])
    lua = [-c for c in LUA_DIR]
    t.no("lua", "DirectionalLight3D", props=[
        ("transform", transform_olhando((0, 40, 0), lua)),
        ("light_color", cor((0.95, 0.55, 0.5, 1))), ("light_energy", "1.25"),
        ("light_indirect_energy", "1.0"), ("light_angular_distance", "1.2"),
        ("light_specular", "0.35"), ("shadow_enabled", "true"), ("shadow_opacity", "0.72"),
        ("shadow_bias", "0.06"), ("shadow_normal_bias", "1.4"),
        ("directional_shadow_mode", "2"), ("directional_shadow_split_1", "0.06"),
        ("directional_shadow_split_2", "0.2"), ("directional_shadow_split_3", "0.5"),
        ("directional_shadow_max_distance", "130.0")])
    t.no("contraluz", "DirectionalLight3D", props=[
        ("transform", transform_olhando((0, 40, 0), (0.35, -0.55, 0.76))),
        ("light_color", cor((0.42, 0.5, 0.8, 1))), ("light_energy", "0.75"),
        ("light_specular", "0.05"), ("shadow_enabled", "false")])
    t.no("relampago", "DirectionalLight3D", props=[
        ("transform", transform_olhando((0, 40, 0), (-0.3, -0.85, -0.42))),
        ("light_color", cor((0.78, 0.8, 1.0, 1))), ("light_energy", "0.0"),
        ("light_specular", "0.6"), ("shadow_enabled", "false")])

    t.no("modelo", None, instancia=modelo, props=[
        ("script", 'ExtResource("%s")' % pintor),
        ("pasta", '"%s"' % MAT_RES),
        ("materiais", dicionario(TABELA)),
        ("sem_sombra", 'PackedStringArray("silhueta", "brasa", "sigilo", "abismo")')])

    # --- luzes
    t.no("luzes", "Node3D")
    for i, (x, y, z) in enumerate(P["braseiros"]):
        t.no("braseiro_%d" % i, "OmniLight3D", "luzes", props=[
            ("transform", transform((x, y + 0.5, z))),
            ("light_color", cor((1.0, 0.48, 0.18, 1))), ("light_energy", "4.6"),
            ("light_indirect_energy", "1.2"), ("light_specular", "0.3"),
            ("shadow_enabled", "true" if i < 2 else "false"),
            ("omni_range", "13.0"), ("omni_attenuation", "1.3")], metas=[("piscar", "fogueira")])
    hx, hy, hz = P["halo"]
    t.no("halo_trono", "OmniLight3D", "luzes", props=[
        ("transform", transform((hx, hy - 6.0, hz + 4.0))),
        ("light_color", cor((1.0, 0.16, 0.08, 1))), ("light_energy", "6.0"),
        ("light_indirect_energy", "1.5"), ("shadow_enabled", "false"),
        ("omni_range", "22.0"), ("omni_attenuation", "1.5")], metas=[("piscar", "pulso")])
    for i, (x, y, z) in enumerate(P.get("lanternas", [])):
        t.no("lanterna_%d" % i, "OmniLight3D", "luzes", props=[
            ("transform", transform((x, y, z))),
            ("light_color", cor((1.0, 0.3, 0.12, 1))), ("light_energy", "5.0"),
            ("shadow_enabled", "false"), ("omni_range", "16.0"), ("omni_attenuation", "1.4")],
            metas=[("piscar", "vela")])

    # --- fogo dos braseiros
    t.no("fogo", "Node3D")
    for i, (x, y, z) in enumerate(P["braseiros"]):
        T.particulas(t, "chama_%d" % i, "fogo", (x, y - 0.15, z), proc_fogo, "quad_fogo", 26, 1.25,
                     (-1.5, -0.6, -1.5, 3, 5, 3), extras=[("preprocess", "1.0"), ("randomness", "0.4")])
        if i % 2 == 0:
            T.som(t, "estalo_%d" % i, "fogo", s_fogo, pos=(x, y, z), volume=-8.0, unit=6.0, maxd=28.0)

    # --- o ar
    t.no("ar", "Node3D")
    T.particulas(t, "rastros_vento", "ar", (34, 4, 6), "proc_risco", "quad_risco", 220, 3.2,
                 (-90, -12, -60, 130, 30, 120), extras=[("preprocess", "3.0"), ("randomness", "0.5")])
    T.particulas(t, "cinza_vento", "ar", (36, 6, 6), "proc_cinza", "quad_cinza", 420, 8.0,
                 (-90, -14, -64, 130, 34, 128), extras=[("preprocess", "8.0"), ("randomness", "0.5")])
    T.particulas(t, "poeira_borda", "ar", (0, -1.5, 0), "proc_poeira_borda", "quad_poeira", 160, 7.0,
                 (-70, -6, -70, 140, 40, 140), extras=[("preprocess", "6.0"), ("randomness", "0.5")])
    T.particulas(t, "brasas_abismo", "ar", (0, -10, 0), "proc_brasa_abismo", "quad_fagulha", 360, 10.0,
                 (-100, -12, -100, 200, 90, 200), extras=[("preprocess", "8.0"), ("randomness", "0.6")])
    T.particulas(t, "fumaca_abismo", "ar", (0, -30, 0), "proc_fumo_abismo", "quad_fumo_abismo", 70, 16.0,
                 (-130, -10, -130, 260, 80, 260), extras=[("preprocess", "12.0"), ("randomness", "0.5")])
    T.particulas(t, "brasas_praca", "ar", (0, 1.5, 0), "proc_brasa_praca", "quad_fagulha", 180, 9.0,
                 (-60, -4, -60, 120, 40, 120), extras=[("preprocess", "6.0"), ("randomness", "0.6")])

    t.no("redemoinhos", "Node3D")
    for i, (x, y, z) in enumerate(P["redemoinhos"]):
        t.no("redemoinho_%d" % i, "Node3D", "redemoinhos", props=[("transform", transform((x, y, z)))])
        T.particulas(t, "poeira", "redemoinhos/redemoinho_%d" % i, (0, 0.2, 0), "proc_redemoinho",
                     "quad_poeira", 70, 3.4, (-6, -1, -6, 12, 18, 12),
                     extras=[("preprocess", "2.0"), ("randomness", "0.4"), ("local_coords", "true")])
        T.particulas(t, "cisco", "redemoinhos/redemoinho_%d" % i, (0, 0.2, 0), "proc_redemoinho_cisco",
                     "quad_cinza", 90, 2.6, (-5, -1, -5, 10, 16, 10),
                     extras=[("preprocess", "2.0"), ("randomness", "0.4"), ("local_coords", "true")])

    # --- chuva de fogo: moldes que o script duplica
    cc = P["chuva_fogo"]
    t.no("chuva_fogo", "Node3D", props=[
        ("metadata/centro", "Vector3(%g, %g, %g)" % tuple(cc["centro"])),
        ("metadata/raio", "%g" % cc["raio"])])
    t.no("meteoro", "Node3D", "chuva_fogo", props=[("visible", "false")])
    t.no("bola", "MeshInstance3D", "chuva_fogo/meteoro", props=[
        ("mesh", 'SubResource("malha_bola")'), ("cast_shadow", "0")])
    T.particulas(t, "rastro", "chuva_fogo/meteoro", (0, 0, 0), "proc_rastro", "quad_rastro", 220, 0.8,
                 (-8, -8, -8, 16, 16, 16), extras=[("emitting", "false"), ("randomness", "0.3")])
    T.particulas(t, "explosao", "chuva_fogo", (0, -50, 0), "proc_explosao", "quad_explosao", 60, 1.1,
                 (-8, -2, -8, 16, 12, 16), extras=[("emitting", "false"), ("one_shot", "true"),
                                                   ("explosiveness", "0.92"), ("visible", "false")])
    T.particulas(t, "fogo_chao", "chuva_fogo", (0, -50, 0), proc_fogo, "quad_fogo", 30, 1.1,
                 (-3, -1, -3, 6, 5, 6), extras=[("emitting", "false"), ("visible", "false")])
    t.no("aviso", "MeshInstance3D", "chuva_fogo", props=[
        ("transform", transform((0, -50, 0))), ("visible", "false"),
        ("mesh", 'SubResource("malha_anel")'), ("cast_shadow", "0")])
    T.som(t, "zunido", "chuva_fogo", s_meteoro, pos=(0, -50, 0), volume=-3.0, unit=14.0,
          maxd=90.0, autoplay=False, loop=False)
    T.som(t, "estouro", "chuva_fogo", s_estouro, pos=(0, -50, 0), volume=-6.0, unit=14.0,
          maxd=90.0, autoplay=False, loop=False)

    t.no("pousos", "Node3D")
    for i, (x, y, z) in enumerate(P["pousos"]):
        t.no("pouso_%d" % i, "Marker3D", "pousos",
             props=[("transform", transform((x, y, z), T.angulo_para(x, z)))])

    t.no("enemies", "Node3D")
    for i, (x, y, z) in enumerate(P["inimigos"]):
        t.no("enemy_%d" % (i + 1), "Marker3D", "enemies",
             props=[("transform", transform((x, y, z), T.angulo_para(x, z)))])
    cx, cy, cz = P["chefe"]
    # onde o chefe fica: na frente do trono, olhando pra ponte
    t.no("chefe", "Marker3D", props=[("transform", transform((cx, cy, cz), 0.0))])

    T.som(t, "ambiente_som", ".", s_amb, volume=-12.0)
    T.som(t, "vento_som", ".", s_vento, volume=-7.0)
    T.som(t, "trovao", ".", s_trovao, volume=-4.0, autoplay=False, loop=False)
    t.no("fade", None, instancia=fade)
    t.no("Pause", None, instancia=pause)
    px, _, pz = P["player"]
    t.no("Player", None, instancia=player, props=[("transform", transform((px, 1.2, pz)))])

    t.salvar(SAIDA, script_raiz=[
        ("script", 'ExtResource("%s")' % script),
        ("e_arena", "true"), ("nevoa_do_player", '"baixa"'),
        ("gargulas_poleiro", "3"), ("gargulas_ceu", "4"),
        ("ceu_raio", "110.0"), ("ceu_altura_min", "38.0"), ("ceu_altura_max", "85.0"),
        ("relampagos", "true"), ("relampago_espera_min", "8.0"), ("relampago_espera_max", "20.0"),
    ])
    _ = math


if __name__ == "__main__":
    main()
