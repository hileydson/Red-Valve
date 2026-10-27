# -*- coding: utf-8 -*-
"""Monta a cena do INFERNO (inferno.tscn) e os materiais dele.

    python3 tools/godot/inferno/gerar_cena_inferno.py

Le':   red-valve/assets/3d_model/stages/inferno/inferno_pontos.json
Grava: red-valve/scenes/stages/inferno/inferno.tscn
       red-valve/assets/3d_model/stages/inferno/materiais/*.tres

==============================================================================
A LUZ

Ceu vermelho com um SOL NEGRO (eclipse, coroa acesa) e nuvem acesa POR BAIXO
pelo mar de lava (`brilho_baixo`). Tres direcionais:
  - o sol negro: vermelho, fraco, com sombra;
  - a LAVA: uma direcional virada pra CIMA, laranja e sem sombra — e' o que
    acende a barriga do penhasco, a parte de baixo da costela e o queixo das
    estatuas, como se o chao inteiro fosse a fonte de luz;
  - o relampago (apagado; o script acende, vermelho).
Omni so' nas piras do caminho (uma a cada ~70 m), nos geiseres (acesa so'
durante a erupcao) e no portal. O chao e' quebrado em setores de 64 m.
Nevoa leve e vermelha: o mapa e' enorme e a profundidade tem de aparecer.
"""

import json
import os
import sys

# o .pyc da base nao pode nascer antes de ela desligar o bytecode: desliga
# aqui, antes de importar
sys.dont_write_bytecode = True
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "cenarios"))

import tscn as T  # noqa: E402
from tscn import cor, processo, quad, rampa, transform, transform_olhando  # noqa: E402

PONTOS = os.path.join(T.BASE, "assets/3d_model/stages/inferno/inferno_pontos.json")
SAIDA = os.path.join(T.BASE, "scenes/stages/inferno/inferno.tscn")
MAT_DIR = os.path.join(T.BASE, "assets/3d_model/stages/inferno/materiais")
MAT_RES = "res://assets/3d_model/stages/inferno/materiais/"
LAVA = -14.0


def _lava_tres(nome, usar_mundo, escala_mundo, escala_uv, fluxo, energia, crosta):
    caminho = os.path.join(MAT_DIR, nome)
    linhas = [
        '[gd_resource type="ShaderMaterial" load_steps=4 format=3]', "",
        '[ext_resource type="Shader" path="res://shaders/environment/lava.gdshader" id="1"]', "",
        '[sub_resource type="FastNoiseLite" id="ruido_fn"]', "noise_type = 3", "frequency = 0.02",
        "fractal_octaves = 4", "",
        '[sub_resource type="NoiseTexture2D" id="ruido"]', "width = 256", "height = 256",
        "seamless = true", 'noise = SubResource("ruido_fn")', "",
        "[resource]", 'shader = ExtResource("1")',
        'shader_parameter/ruido = SubResource("ruido")',
        "shader_parameter/usar_mundo = %s" % ("true" if usar_mundo else "false"),
        "shader_parameter/escala_mundo = %g" % escala_mundo,
        "shader_parameter/escala_uv = Vector2(%g, %g)" % escala_uv,
        "shader_parameter/fluxo = Vector2(%g, %g)" % fluxo,
        "shader_parameter/energia = %g" % energia,
        "shader_parameter/crosta = %g" % crosta,
    ]
    os.makedirs(MAT_DIR, exist_ok=True)
    with open(caminho, "w") as fp:
        fp.write("\n".join(linhas) + "\n")


def materiais():
    m = lambda n: os.path.join(MAT_DIR, n)  # noqa: E731
    T.material_textura(m("mat_cinza.tres"), *T.tex_ph("mud_cracked_dry_03"), albedo=(0.30, 0.25, 0.24, 1),
                       uv=0.16, normal_scale=1.1)
    T.material_textura(m("mat_basalto.tres"), *T.tex_ph("rock_wall_08"), albedo=(0.17, 0.14, 0.14, 1),
                       uv=0.12, normal_scale=1.3)
    T.material_textura(m("mat_basalto_col.tres"), *T.tex_ph("rock_wall_08"), albedo=(0.13, 0.11, 0.115, 1),
                       uv=0.35, normal_scale=1.2)
    T.material_textura(m("mat_rocha.tres"), *T.tex_ph("rocky_trail_02"), albedo=(0.22, 0.16, 0.15, 1),
                       uv=0.05, normal_scale=1.4)
    T.material_chapado(m("mat_rocha_longe.tres"), (0.09, 0.05, 0.05, 1))
    T.material_textura(m("mat_obsidiana.tres"), *T.tex_city("stone_cemetery"), albedo=(0.07, 0.06, 0.08, 1),
                       rough=0.35, uv=0.4, normal_scale=1.0, extras=["metallic_specular = 0.8"])
    T.material_textura(m("mat_pedra.tres"), *T.tex_city("stone_church"), albedo=(0.30, 0.24, 0.23, 1),
                       uv=0.4, normal_scale=1.1)
    T.material_textura(m("mat_osso.tres"), *T.tex_city("plaster_raw"), albedo=(0.62, 0.55, 0.45, 1),
                       rough=0.8, uv=0.5, normal_scale=0.8)
    T.material_textura(m("mat_carne.tres"), *T.tex_city("plaster_raw"), albedo=(0.28, 0.04, 0.05, 1),
                       rough=0.45, uv=1.1, normal_scale=1.4,
                       extras=["rim_enabled = true", "rim = 0.4", "rim_tint = 0.2"])
    T.material_textura(m("mat_carne_seca.tres"), *T.tex_city("plaster_raw"), albedo=(0.18, 0.08, 0.06, 1),
                       rough=0.9, uv=1.4, normal_scale=1.2)
    T.material_textura(m("mat_metal.tres"), *T.tex_ph("rusty_metal_02"), albedo=(0.25, 0.18, 0.15, 1),
                       rough=0.7, uv=0.6, extras=["metallic = 0.7"])
    T.material_chapado(m("mat_escuro.tres"), (0.0, 0.0, 0.0, 1), extras=["shading_mode = 0"])
    T.material_chapado(m("mat_silhueta.tres"), (0.06, 0.025, 0.025, 1))
    T.material_chapado(m("mat_sombra.tres"), (0.0, 0.0, 0.0, 1), extras=["shading_mode = 0"])
    T.material_emissivo(m("mat_brasa.tres"), (0.35, 0.06, 0.02, 1), (1, 0.33, 0.07, 1), 3.0)
    T.material_emissivo(m("mat_vitral.tres"), (0.3, 0.03, 0.02, 1), (1, 0.22, 0.05, 1), 2.6)
    T.material_emissivo(m("mat_lava_brilho.tres"), (0.4, 0.06, 0.02, 1), (1, 0.4, 0.08, 1), 6.0,
                        extras=["shading_mode = 0"])
    _lava_tres("mat_lava.tres", True, 0.009, (1, 1), (0.002, 0.003), 2.4, 0.56)
    _lava_tres("mat_lava_corre.tres", False, 0.0, (0.6, 1.0), (0.0, -0.18), 3.4, 0.48)
    _lava_tres("mat_lava_cai.tres", False, 0.0, (0.5, 1.0), (0.0, 0.55), 3.8, 0.42)


TABELA = {k: "mat_%s.tres" % k for k in (
    "cinza", "basalto", "basalto_col", "rocha", "rocha_longe", "obsidiana", "pedra", "osso", "carne",
    "carne_seca", "metal", "escuro", "silhueta", "sombra", "brasa", "vitral", "lava_brilho",
    "lava", "lava_corre", "lava_cai")}


def dicionario(d):
    return "{\n%s\n}" % ",\n".join('"%s": "%s"' % (k, v) for k, v in d.items())


def main():
    with open(PONTOS) as fp:
        P = json.load(fp)
    materiais()
    t = T.Tscn("inferno")

    script = t.ext("Script", "res://scripts/stages/inferno/inferno.gd")
    modelo = t.ext("PackedScene", "res://assets/3d_model/stages/inferno/inferno.glb")
    pintor = t.ext("Script", "res://scripts/stages/materiais_por_sufixo.gd")
    player = t.ext("PackedScene", "res://scenes/player/player.tscn")
    pause = t.ext("PackedScene", "res://scenes/configs/pause.tscn")
    fade = t.ext("PackedScene", "res://scenes/configs/fade.tscn")
    calor = t.ext("PackedScene", "res://scenes/effects/heat_distortion_filter.tscn")
    ceu_sh = t.ext("Shader", "res://shaders/environment/ceu_maldito.gdshader")
    portal_sh = t.ext("Shader", "res://shaders/environment/portal_vortice.gdshader")
    s_drone = t.ext("AudioStream", "res://assets/sounds/cenarios/drone_inferno.ogg")
    s_vento = t.ext("AudioStream", "res://assets/sounds/cenarios/vento_quente.ogg")
    s_lava = t.ext("AudioStream", "res://assets/sounds/cenarios/lava.ogg")
    s_geiser = t.ext("AudioStream", "res://assets/sounds/cenarios/geiser.ogg")
    s_trovao = t.ext("AudioStream", "res://assets/sounds/cenarios/trovao.ogg")
    s_fogo = t.ext("AudioStream", "res://assets/sounds/common/fire_cracling.mp3")
    s_portal = t.ext("AudioStream", "res://assets/sounds/episodios/portal_red_valve.mp3")

    # ------------------------------------------------------------ ceu
    ruido = T.ruido_ceu(t, semente=66, freq=0.013)
    t.sub("ceu_mat", "ShaderMaterial", [
        'shader = ExtResource("%s")' % ceu_sh,
        "shader_parameter/cor_zenite = Color(0.05, 0.012, 0.012, 1)",
        "shader_parameter/cor_horizonte = Color(0.36, 0.075, 0.035, 1)",
        "shader_parameter/cor_chao = Color(0.3, 0.06, 0.02, 1)",
        "shader_parameter/cor_nuvem = Color(0.09, 0.025, 0.02, 1)",
        "shader_parameter/cor_borda_nuvem = Color(0.75, 0.2, 0.05, 1)",
        'shader_parameter/ruido = SubResource("%s")' % ruido,
        "shader_parameter/escala_nuvem = 1.2", "shader_parameter/cobertura = 0.62",
        "shader_parameter/maciez = 0.3", "shader_parameter/vento = Vector2(0.01, 0.004)",
        "shader_parameter/lua_dir = Vector3(-0.3, 0.28, -0.91)",
        "shader_parameter/lua_cor = Color(1, 0.35, 0.08, 1)",
        "shader_parameter/lua_tamanho = 0.11", "shader_parameter/lua_brilho = 4.0",
        "shader_parameter/lua_halo = 1.6", "shader_parameter/lua_eclipse = 1.0",
        "shader_parameter/vortice_dir = Vector3(-0.3, 0.28, -0.91)",
        "shader_parameter/vortice_forca = 0.7", "shader_parameter/vortice_raio = 0.5",
        "shader_parameter/vortice_cor = Color(0.8, 0.12, 0.03, 1)",
        "shader_parameter/vortice_brilho = 0.6",
        "shader_parameter/estrelas = 0.0", "shader_parameter/brilho_baixo = 1.0",
        "shader_parameter/relampago = 0.0",
        "shader_parameter/relampago_cor = Color(1, 0.35, 0.15, 1)",
    ])
    t.sub("ceu", "Sky", ['sky_material = SubResource("ceu_mat")', "radiance_size = 1"])
    t.sub("ambiente", "Environment", [
        "background_mode = 2", 'sky = SubResource("ceu")',
        "ambient_light_source = 2", "ambient_light_color = " + cor((0.5, 0.33, 0.29, 1)),
        "ambient_light_energy = 1.6", "reflected_light_source = 2",
        "tonemap_mode = 3", "tonemap_exposure = 1.2", "tonemap_white = 6.0",
        "glow_enabled = true", "glow_intensity = 0.9", "glow_strength = 1.05",
        "glow_bloom = 0.12", "glow_blend_mode = 0", "glow_hdr_threshold = 0.95",
        "fog_enabled = true", "fog_mode = 0",
        "fog_light_color = " + cor((0.30, 0.085, 0.05, 1)), "fog_light_energy = 0.62",
        "fog_sun_scatter = 0.0", "fog_density = 0.0042", "fog_sky_affect = 0.35",
        "fog_height = -8.0", "fog_height_density = 0.03",
        "adjustment_enabled = true", "adjustment_contrast = 1.14", "adjustment_saturation = 0.84",
    ])

    # ------------------------------------------------------------ particulas
    T.texturas_base(t)
    proc_fogo = T.fogo_preset(t)
    rampa(t, "fagulha", (0, 0.3, 1), ((1, 0.72, 0.3, 0.9), (1, 0.35, 0.08, 0.7), (0.5, 0.08, 0.02, 0)))
    rampa(t, "cinza", (0, 0.3, 1), ((0.18, 0.13, 0.12, 0), (0.15, 0.11, 0.1, 0.6), (0.1, 0.08, 0.08, 0)))
    rampa(t, "jato", (0, 0.22, 0.62, 1), ((1, 0.86, 0.46, 0.42), (1, 0.47, 0.12, 0.42),
                                         (0.68, 0.14, 0.03, 0.26), (0.18, 0.03, 0.01, 0)))
    rampa(t, "fumo", (0, 0.3, 1), ((0.2, 0.12, 0.1, 0), (0.15, 0.09, 0.08, 0.35), (0.08, 0.05, 0.05, 0)))
    rampa(t, "erupcao", (0, 0.15, 0.5, 1), ((1, 0.9, 0.5, 0.6), (1, 0.45, 0.1, 0.55),
                                            (0.5, 0.1, 0.03, 0.35), (0.12, 0.04, 0.03, 0)))
    quad(t, "quad_fagulha", "mat_aditivo", 0.13, 0.13)
    quad(t, "quad_cinza", "mat_fosco", 0.06, 0.06)
    quad(t, "quad_fumo", "mat_fumo", 2.2, 2.2)
    t.sub("mat_jato", "StandardMaterial3D", [
        "transparency = 1", "blend_mode = 1", "shading_mode = 0", "vertex_color_use_as_albedo = true",
        'albedo_texture = SubResource("tex_ponto")', "billboard_mode = 3", "billboard_keep_scale = true",
        "disable_receive_shadows = true"])
    quad(t, "quad_jato", "mat_jato", 0.9, 2.4)
    quad(t, "quad_erupcao", "mat_fumo_aditivo", 6.0, 9.0)
    processo(t, "proc_cinza", emission_shape=3, emission_box_extents=(40, 12, 40),
             direction=(0.3, -1, 0.1), spread=25.0, initial_velocity_min=0.6, initial_velocity_max=1.4,
             gravity=(0.4, -0.5, 0.1), scale_min=0.6, scale_max=1.8, color_ramp='SubResource("r_cinza")',
             turbulence_enabled=True, turbulence_noise_strength=0.9, turbulence_noise_scale=1.2)
    processo(t, "proc_brasa", emission_shape=3, emission_box_extents=(45, 3, 45),
             direction=(0, 1, 0), spread=30.0, initial_velocity_min=0.8, initial_velocity_max=2.5,
             gravity=(0.3, 0.9, -0.2), scale_min=0.5, scale_max=1.5, color_ramp='SubResource("r_fagulha")',
             turbulence_enabled=True, turbulence_noise_strength=1.0, turbulence_noise_scale=1.3)
    processo(t, "proc_aviso", emission_shape=1, emission_sphere_radius=0.9,
             direction=(0, 1, 0), spread=18.0, initial_velocity_min=1.2, initial_velocity_max=3.2,
             gravity=(0, 0.4, 0), scale_min=0.6, scale_max=1.4, color_ramp='SubResource("r_fumo")')
    processo(t, "proc_jato", emission_shape=1, emission_sphere_radius=0.8,
             direction=(0, 1, 0), spread=7.0, initial_velocity_min=10.0, initial_velocity_max=16.0,
             gravity=(0, -6.0, 0), damping_min=0.1, damping_max=0.5, scale_min=0.6, scale_max=1.6,
             color_ramp='SubResource("r_jato")', particle_flag_align_y=True,
             turbulence_enabled=True, turbulence_noise_strength=0.7, turbulence_noise_scale=1.6)
    processo(t, "proc_erupcao", emission_shape=1, emission_sphere_radius=3.0,
             direction=(0, 1, 0), spread=9.0, initial_velocity_min=18.0, initial_velocity_max=34.0,
             gravity=(0, -9.0, 0), damping_min=0.2, damping_max=0.8, scale_min=0.6, scale_max=1.8,
             color_ramp='SubResource("r_erupcao")', turbulence_enabled=True,
             turbulence_noise_strength=1.1, turbulence_noise_scale=0.8)
    t.sub("ruido_portal_fn", "FastNoiseLite", ["noise_type = 3", "frequency = 0.03"])
    t.sub("ruido_portal", "NoiseTexture2D", ["width = 256", "height = 256", "seamless = true",
                                             'noise = SubResource("ruido_portal_fn")'])
    t.sub("mat_portal", "ShaderMaterial", ['shader = ExtResource("%s")' % portal_sh,
                                           'shader_parameter/ruido = SubResource("ruido_portal")'])
    t.sub("malha_portal", "QuadMesh", ['material = SubResource("mat_portal")', "size = Vector2(23, 23)"])
    t.sub("forma_portal", "BoxShape3D", ["size = Vector3(22, 26, 3)"])
    t.sub("forma_portao", "BoxShape3D", ["size = Vector3(18, 14, 4)"])

    T.navmesh(t, P["navmesh"])

    # ------------------------------------------------------------ nos
    t.no("WorldEnvironment", "WorldEnvironment", props=[("environment", 'SubResource("ambiente")')])
    t.no("sol_negro", "DirectionalLight3D", props=[
        ("transform", transform_olhando((0, 60, 0), (0.3, -0.28, 0.91))),
        ("light_color", cor((1.0, 0.42, 0.25, 1))), ("light_energy", "0.95"),
        ("light_specular", "0.3"), ("shadow_enabled", "true"), ("shadow_opacity", "0.75"),
        ("shadow_bias", "0.08"), ("shadow_normal_bias", "1.6"), ("directional_shadow_mode", "2"),
        ("directional_shadow_max_distance", "150.0")])
    t.no("brilho_da_lava", "DirectionalLight3D", props=[
        ("transform", transform_olhando((0, -10, 0), (0.1, 1.0, 0.15))),
        ("light_color", cor((1.0, 0.36, 0.1, 1))), ("light_energy", "0.55"),
        ("light_specular", "0.0"), ("shadow_enabled", "false")])
    t.no("relampago", "DirectionalLight3D", props=[
        ("transform", transform_olhando((0, 60, 0), (-0.2, -0.9, -0.3))),
        ("light_color", cor((1.0, 0.45, 0.3, 1))), ("light_energy", "0.0"), ("shadow_enabled", "false")])

    t.no("modelo", None, instancia=modelo, props=[
        ("script", 'ExtResource("%s")' % pintor), ("pasta", '"%s"' % MAT_RES),
        ("materiais", dicionario(TABELA)),
        ("sem_sombra", 'PackedStringArray("silhueta", "sombra", "brasa", "vitral", "lava", "lava_corre", '
                       '"lava_cai", "lava_brilho", "rocha_longe", "escuro")')])

    # --- luzes: piras e portal
    t.no("luzes", "Node3D")
    for i, (x, y, z) in enumerate(P["braseiros"]):
        t.no("pira_%d" % i, "OmniLight3D", "luzes", props=[
            ("transform", transform((x, y + 0.6, z))),
            ("light_color", cor((1.0, 0.45, 0.16, 1))), ("light_energy", "4.4"),
            ("light_indirect_energy", "1.2"), ("shadow_enabled", "false"),
            ("omni_range", "15.0"), ("omni_attenuation", "1.3")], metas=[("piscar", "fogueira")])
    px_, py_, pz_ = P["portal"]
    t.no("luz_portal", "OmniLight3D", "luzes", props=[
        ("transform", transform((px_, py_, pz_ + 4.0))),
        ("light_color", cor((1.0, 0.3, 0.12, 1))), ("light_energy", "6.0"),
        ("shadow_enabled", "false"), ("omni_range", "26.0"), ("omni_attenuation", "1.4")],
        metas=[("piscar", "pulso")])

    # --- fogo das piras
    t.no("fogo", "Node3D")
    for i, (x, y, z) in enumerate(P["braseiros"]):
        T.particulas(t, "chama_%d" % i, "fogo", (x, y - 0.1, z), proc_fogo, "quad_fogo", 28, 1.3,
                     (-1.6, -0.6, -1.6, 3.2, 5.5, 3.2), extras=[("preprocess", "1.0"), ("randomness", "0.4")])
        if i % 2 == 0:
            T.som(t, "estalo_%d" % i, "fogo", s_fogo, pos=(x, y, z), volume=-8.0, unit=6.0, maxd=30.0)

    # --- geiseres (o script acende)
    t.no("geiseres", "Node3D")
    for i, (x, y, z) in enumerate(P["geiseres"]):
        pai = "geiseres/geiser_%d" % i
        t.no("geiser_%d" % i, "Node3D", "geiseres", props=[("transform", transform((x, y, z)))])
        T.particulas(t, "aviso", pai, (0, 0, 0), "proc_aviso", "quad_fumo", 26, 1.6,
                     (-4, -1, -4, 8, 10, 8), extras=[("emitting", "false")])
        T.particulas(t, "jato", pai, (0, 0.2, 0), "proc_jato", "quad_jato", 110, 1.6,
                     (-5, -1, -5, 10, 20, 10), extras=[("emitting", "false"), ("randomness", "0.35")])
        t.no("luz", "OmniLight3D", pai, props=[
            ("transform", transform((0, 2.5, 0))), ("light_color", cor((1.0, 0.42, 0.12, 1))),
            ("light_energy", "0.0"), ("shadow_enabled", "false"), ("omni_range", "12.0")])
        T.som(t, "som", pai, s_geiser, pos=(0, 1, 0), volume=-2.0, unit=10.0, maxd=60.0,
              autoplay=False, loop=False)

    # --- erupcoes ao longe (molde)
    t.no("erupcoes", "Node3D")
    T.particulas(t, "modelo", "erupcoes", (0, -100, 0), "proc_erupcao", "quad_erupcao", 70, 3.4,
                 (-25, -5, -25, 50, 80, 50), extras=[("emitting", "false"), ("one_shot", "true"),
                                                     ("explosiveness", "0.55"), ("visible", "false")])

    # --- ar: cinza e brasa presas a' camera (o mapa tem 1 km)
    t.no("ar", "Node3D")
    t.no("segue", "Node3D", "ar", props=[("transform", transform((0, 0, 420)))])
    t.nos.append(['[node name="cinza" type="GPUParticles3D" parent="ar/segue" groups=["segue_camera"]]',
                  "transform = " + transform((0, 14, 0)), "amount = 700", "lifetime = 14.0",
                  "preprocess = 12.0", "randomness = 0.5",
                  "visibility_aabb = AABB(-60, -30, -60, 120, 50, 120)",
                  'process_material = SubResource("proc_cinza")', 'draw_pass_1 = SubResource("quad_cinza")'])
    t.nos.append(['[node name="brasas" type="GPUParticles3D" parent="ar/segue" groups=["segue_camera"]]',
                  "transform = " + transform((0, -1, 0)), "amount = 260", "lifetime = 9.0",
                  "preprocess = 6.0", "randomness = 0.6",
                  "visibility_aabb = AABB(-60, -10, -60, 120, 40, 120)",
                  'process_material = SubResource("proc_brasa")', 'draw_pass_1 = SubResource("quad_fagulha")'])

    # --- sons de lava espalhados
    t.no("sons_lava", "Node3D")
    for i, (x, y, z) in enumerate(P["lavas_som"]):
        T.som(t, "lava_%d" % i, "sons_lava", s_lava, pos=(x, y, z), volume=2.0, unit=18.0, maxd=110.0)

    # --- o portal (saida) e o portao (entrada)
    t.no("redemoinho", "MeshInstance3D", props=[
        ("transform", transform((px_, py_, pz_ + 0.2))), ("mesh", 'SubResource("malha_portal")'),
        ("cast_shadow", "0")])
    T.som(t, "som_portal", ".", s_portal, pos=(px_, py_, pz_), volume=-4.0, unit=14.0, maxd=90.0)
    sx, sy, sz = P["saida"]
    # a caixa desce ate' o piso da plataforma: o jogador ANDA pra dentro do anel
    t.no("saida", "Area3D", props=[("transform", transform((px_, py_ - 3.0, pz_))), ("collision_layer", "0"),
                                   ("collision_mask", "1"), ("monitorable", "false")])
    t.no("forma", "CollisionShape3D", "saida", props=[("shape", 'SubResource("forma_portal")')])
    ex, ey, ez = P["entrada"]
    t.no("entrada", "Area3D", props=[("transform", transform((ex, ey + 6.0, ez + 6.0))),
                                     ("collision_layer", "0"), ("collision_mask", "1"),
                                     ("monitorable", "false")])
    t.no("forma", "CollisionShape3D", "entrada", props=[("shape", 'SubResource("forma_portao")')])

    # --- marcadores: areas (pra montar o conteudo depois), spawn e inimigos
    t.no("areas", "Node3D")
    for nome, (x, y, z) in sorted(P["areas"].items()):
        t.no(nome, "Marker3D", "areas", props=[("transform", transform((x, y + 0.2, z)))])
    t.no("spawn_entrada", "Marker3D", props=[("transform", transform(tuple(P["player"])))])
    t.no("spawn_saida", "Marker3D", props=[("transform", transform((sx, sy + 0.3, sz + 20.0), 3.14159))])
    t.no("enemies", "Node3D")
    for i, (x, y, z) in enumerate(P["inimigos"]):
        t.no("enemy_%d" % (i + 1), "Marker3D", "enemies", props=[("transform", transform((x, y, z)))])

    T.som(t, "drone", ".", s_drone, volume=-8.0)
    T.som(t, "vento_som", ".", s_vento, volume=-12.0)
    T.som(t, "trovao", ".", s_trovao, volume=-6.0, autoplay=False, loop=False)
    t.no("calor", None, instancia=calor)
    t.no("fade", None, instancia=fade)
    t.no("Pause", None, instancia=pause)
    px, py, pz = P["player"]
    t.no("Player", None, instancia=player, props=[("transform", transform((px, py + 1.0, pz)))])

    t.salvar(SAIDA, script_raiz=[
        ("script", 'ExtResource("%s")' % script),
        # o portal do fim leva ao inferno 2 (que volta pra ca' pelo anel dele)
        ("cena_saida", '"res://scenes/stages/inferno_2/inferno_2.tscn"'),
        ("salvar_ao_entrar", "true"), ("nevoa_do_player", '"baixa"'),
        ("gargulas_ceu", "7"), ("ceu_raio", "230.0"), ("ceu_altura_min", "60.0"),
        ("ceu_altura_max", "150.0"),
        ("relampagos", "true"), ("relampago_espera_min", "14.0"), ("relampago_espera_max", "40.0"),
        ("relampago_energia", "1.8"),
    ])


if __name__ == "__main__":
    main()
