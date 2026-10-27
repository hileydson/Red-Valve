# -*- coding: utf-8 -*-
"""Monta a cena do INFERNO 4 (inferno_4.tscn) e os materiais dele.

    python3 tools/godot/inferno_4/gerar_cena_inferno_4.py

Le':   red-valve/assets/3d_model/stages/inferno_4/inferno_4_pontos.json
Grava: red-valve/scenes/stages/inferno_4/inferno_4.tscn
       red-valve/assets/3d_model/stages/inferno_4/materiais/*.tres

==============================================================================
A LUZ — A DO INFERNO 3, ATE' O TOPO

A cena nasce IGUAL ao inferno 3 (o mesmo ceu, a mesma lua, a mesma nevoa
azul-chumbo, a mesma lente, os mesmos materiais — a funcao `materiais` e' a
do gerador dele). O que muda vem do script (`inferno_4.gd`), pela posicao do
jogador: no fim da subida a nevoa ABRE e fica cor de brasa, o vortice do ceu
acende em cima da catedral colossal e o drone sobe. E' o que deixa ver o
GRANDE INFERNO, que e' feito so' de vista (materiais `vista_*`, sem sombra e
sem corte de distancia: o resto do mapa some a 220 m, a vista nunca).

A lua aqui fica a NORDESTE (o vortice e a catedral sao a noroeste): os dois
juntos no mesmo pedaco de ceu brigavam.
"""

import importlib.util
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

PONTOS = os.path.join(T.BASE, "assets/3d_model/stages/inferno_4/inferno_4_pontos.json")
SAIDA = os.path.join(T.BASE, "scenes/stages/inferno_4/inferno_4.tscn")
MAT_DIR = os.path.join(T.BASE, "assets/3d_model/stages/inferno_4/materiais")
MAT_RES = "res://assets/3d_model/stages/inferno_4/materiais/"
INFERNO_3 = "res://scenes/stages/inferno_3/inferno_3.tscn"


def _cena_do_inferno_3():
    caminho = os.path.join(AQUI, os.pardir, "inferno_3", "gerar_cena_inferno_3.py")
    spec = importlib.util.spec_from_file_location("cena_inferno_3_do_4", caminho)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


C3 = _cena_do_inferno_3()


def materiais():
    """Os do inferno 3, gravados na pasta daqui, e os da vista."""
    C3.MAT_DIR = MAT_DIR
    C3.materiais()
    m = lambda n: os.path.join(MAT_DIR, n)  # noqa: E731
    # o selo do largo do fim: o sigilo do 3 bem mais apagado (e' chao)
    T.material_emissivo(m("mat_sigilo.tres"), (0.25, 0.02, 0.02, 1), (0.9, 0.08, 0.04, 1), 0.9)
    # o grande inferno: chapado (a 300 m textura so' vira moire'), escuro, e
    # as luzes dele fortes — e' por elas que a escala se le' atraves da nevoa
    T.material_chapado(m("mat_vista_pedra.tres"), (0.2, 0.19, 0.22, 1))
    T.material_chapado(m("mat_vista_telhado.tres"), (0.12, 0.12, 0.15, 1))
    T.material_chapado(m("mat_vista_rocha.tres"), (0.17, 0.15, 0.15, 1))
    T.material_emissivo(m("mat_vista_janela.tres"), (0.4, 0.25, 0.1, 1), (1, 0.62, 0.28, 1), 5.0)
    T.material_emissivo(m("mat_vista_vitral.tres"), (0.3, 0.02, 0.02, 1), (0.95, 0.12, 0.06, 1), 5.0)
    T.material_emissivo(m("mat_vista_brasa.tres"), (0.4, 0.1, 0.03, 1), (1, 0.42, 0.12, 1), 7.0)


VISTA = ("vista_pedra", "vista_telhado", "vista_rocha", "vista_janela", "vista_vitral", "vista_brasa")
TABELA = dict(C3.TABELA)
TABELA.update({k: "mat_%s.tres" % k for k in VISTA})


def main():
    with open(PONTOS) as fp:
        P = json.load(fp)
    materiais()
    t = T.Tscn("inferno_4")

    script = t.ext("Script", "res://scripts/stages/inferno_4/inferno_4.gd")
    modelo = t.ext("PackedScene", "res://assets/3d_model/stages/inferno_4/inferno_4.glb")
    pintor = t.ext("Script", "res://scripts/stages/materiais_por_sufixo.gd")
    player = t.ext("PackedScene", "res://scenes/player/player.tscn")
    pause = t.ext("PackedScene", "res://scenes/configs/pause.tscn")
    minimapa = t.ext("PackedScene", "res://scenes/ui/minimap_inferno_4.tscn")
    fade = t.ext("PackedScene", "res://scenes/configs/fade.tscn")
    lanterna = t.ext("PackedScene", "res://assets/3d_model/player/lanterna/lanterna.glb")
    ceu_sh = t.ext("Shader", "res://shaders/environment/ceu_maldito.gdshader")
    portal_sh = t.ext("Shader", "res://shaders/environment/portal_vortice.gdshader")
    lente_sh = t.ext("Shader", "res://shaders/post_process/escola_lente.gdshader")
    s_vento = t.ext("AudioStream", "res://assets/sounds/cenarios/vento_frio.ogg")
    s_sino = t.ext("AudioStream", "res://assets/sounds/cenarios/sino.ogg")
    s_drone = t.ext("AudioStream", "res://assets/sounds/cenarios/drone_inferno.ogg")
    s_fogo = t.ext("AudioStream", "res://assets/sounds/common/fire_cracling.mp3")
    s_portal = t.ext("AudioStream", "res://assets/sounds/episodios/portal_red_valve.mp3")
    s_sussurro = t.ext("AudioStream", "res://assets/sounds/igreja/sussurro_culto.ogg")
    s_grito = t.ext("AudioStream", "res://assets/sounds/igreja/grito_monstro.ogg")
    s_rugido = t.ext("AudioStream", "res://assets/sounds/igreja/rugido_monstro.ogg")
    s_amb = t.ext("AudioStream", "res://assets/sounds/igreja/ambiente_ritual.ogg")

    # ------------------------------------------------------------ ceu
    # o do inferno 3, com a lua a nordeste e o vortice (apagado: o script
    # acende) em cima da catedral colossal
    mx, my, mz = P["mirante"]
    ax, ay, az = P["vista_alvo"]
    dx, dy, dz = ax - mx, ay - my, az - mz
    dd = math.sqrt(dx * dx + dz * dz)
    vort = (dx / dd * 0.96, 0.27, dz / dd * 0.96)
    ruido = T.ruido_ceu(t, semente=1414, freq=0.011)
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
        "shader_parameter/lua_dir = Vector3(0.42, 0.3, -0.86)",
        "shader_parameter/lua_cor = Color(0.95, 0.93, 0.84, 1)",
        "shader_parameter/lua_tamanho = 0.07", "shader_parameter/lua_brilho = 1.5",
        "shader_parameter/lua_halo = 0.8", "shader_parameter/lua_eclipse = 0.0",
        "shader_parameter/vortice_dir = Vector3(%.3f, %.3f, %.3f)" % vort,
        "shader_parameter/vortice_forca = 0.0", "shader_parameter/vortice_raio = 0.5",
        "shader_parameter/vortice_cor = Color(0.8, 0.12, 0.05, 1)", "shader_parameter/vortice_brilho = 0.75",
        "shader_parameter/estrelas = 0.12", "shader_parameter/brilho_baixo = 0.0",
        "shader_parameter/relampago = 0.0",
        "shader_parameter/relampago_cor = Color(0.75, 0.8, 1, 1)",
    ])
    t.sub("ceu", "Sky", ['sky_material = SubResource("ceu_mat")', "radiance_size = 1"])
    t.sub("ambiente", "Environment", [
        "background_mode = 2", 'sky = SubResource("ceu")',
        "ambient_light_source = 2", "ambient_light_color = " + cor((0.13, 0.15, 0.21, 1)),
        "ambient_light_energy = 0.32",
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
    rampa(t, "fumo_longe", (0, 0.25, 1), ((0.2, 0.1, 0.07, 0), (0.16, 0.09, 0.07, 0.55), (0.08, 0.06, 0.06, 0)))
    quad(t, "quad_nevoa", "mat_nevoa", 9.0, 9.0)
    quad(t, "quad_cinza", "mat_fosco", 0.05, 0.05)
    quad(t, "quad_fagulha", "mat_aditivo", 0.11, 0.11)
    # o fogo e a fumaca das torres do grande inferno: vistos a 400-900 m
    quad(t, "quad_fogo_longe", "mat_aditivo", 9.0, 13.0)
    quad(t, "quad_fumo_longe", "mat_fumo", 60.0, 60.0)
    processo(t, "proc_nevoa", emission_shape=3, emission_box_extents=(30, 0.8, 30),
             direction=(1, 0, 0.3), spread=40.0, initial_velocity_min=0.2, initial_velocity_max=0.6,
             gravity=(0, 0, 0), scale_min=0.7, scale_max=1.5, color_ramp='SubResource("r_nevoa")',
             turbulence_enabled=True, turbulence_noise_strength=0.3, turbulence_noise_scale=0.6)
    processo(t, "proc_cinza", emission_shape=3, emission_box_extents=(22, 1, 22),
             direction=(0.2, -1, 0.1), spread=20.0, initial_velocity_min=0.4, initial_velocity_max=0.9,
             gravity=(0.15, -0.35, 0.05), scale_min=0.6, scale_max=1.6, color_ramp='SubResource("r_cinza")',
             turbulence_enabled=True, turbulence_noise_strength=0.8, turbulence_noise_scale=1.2)
    processo(t, "proc_fogo_longe", emission_shape=1, emission_sphere_radius=5.0,
             direction=(0, 1, 0), spread=12.0, initial_velocity_min=6.0, initial_velocity_max=12.0,
             gravity=(0, 4.0, 0), scale_min=0.5, scale_max=1.3, color_ramp='SubResource("r_fogo")')
    processo(t, "proc_fumo_longe", emission_shape=1, emission_sphere_radius=8.0,
             direction=(0, 1, 0), spread=10.0, initial_velocity_min=8.0, initial_velocity_max=14.0,
             gravity=(1.5, 1.5, 0.5), scale_min=0.6, scale_max=1.8, color_ramp='SubResource("r_fumo_longe")')
    t.sub("ruido_portal_fn", "FastNoiseLite", ["noise_type = 3", "frequency = 0.03"])
    t.sub("ruido_portal", "NoiseTexture2D", ["width = 256", "height = 256", "seamless = true",
                                             'noise = SubResource("ruido_portal_fn")'])
    t.sub("mat_portal", "ShaderMaterial", ['shader = ExtResource("%s")' % portal_sh,
                                           'shader_parameter/ruido = SubResource("ruido_portal")'])
    t.sub("malha_portal", "QuadMesh", ['material = SubResource("mat_portal")', "size = Vector2(23, 23)"])
    t.sub("forma_anel", "BoxShape3D", ["size = Vector3(22, 26, 3)"])
    t.sub("forma_lanterna", "BoxShape3D", ["size = Vector3(3.2, 2.6, 3.2)"])
    gx, gy, gz, ggiro, glarg = P["gatilho"]
    t.sub("forma_gatilho", "BoxShape3D", ["size = Vector3(%.2f, 8, 6)" % glarg])
    t.sub("lente_mat", "ShaderMaterial", ['shader = ExtResource("%s")' % lente_sh]
          + ["shader_parameter/%s = %s" % kv for kv in C3.LENTE])

    T.navmesh(t, P["navmesh"])

    # ------------------------------------------------------------ nos
    t.no("WorldEnvironment", "WorldEnvironment", props=[("environment", 'SubResource("ambiente")')])
    t.no("lua", "DirectionalLight3D", props=[
        ("transform", transform_olhando((0, 80, 0), (-0.42, -0.3, 0.86))),
        ("light_color", cor((0.62, 0.68, 0.86, 1))), ("light_energy", "0.3"),
        ("light_specular", "0.0"), ("shadow_enabled", "true"), ("shadow_opacity", "0.85"),
        ("shadow_bias", "0.06"), ("shadow_normal_bias", "1.4"), ("directional_shadow_mode", "2"),
        ("directional_shadow_max_distance", "70.0")])

    t.no("modelo", None, instancia=modelo, props=[
        ("script", 'ExtResource("%s")' % pintor), ("pasta", '"%s"' % MAT_RES),
        ("materiais", C3.dicionario(TABELA)),
        ("sem_sombra", 'PackedStringArray("silhueta", "sombra", "escuro", "buraco", "janela_acesa", '
                       '"vidro_lampiao", "vela", "vitral", "brasa", "sigilo", "sangue", %s)'
                       % ", ".join('"%s"' % k for k in VISTA)),
        # o topo ve' longe: o mapa corta a 220 m, a vista nunca
        ("alcance_visivel", "220.0"),
        ("sempre_visivel", 'PackedStringArray("silhueta", "telhado", %s)' % ", ".join('"%s"' % k for k in VISTA))])

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
    cx_, cy_, cz_ = P["portal_chegada"]
    t.no("luz_chegada", "OmniLight3D", "luzes", props=[
        ("transform", transform((cx_, cy_ - 6.0, cz_ - 4.0))), ("light_color", cor((0.85, 0.28, 0.2, 1))),
        ("light_energy", "3.0"), ("shadow_enabled", "false"), ("omni_range", "16.0")],
        metas=[("piscar", "pulso")])
    ox_, oy_, oz_, otx, otz = P["portal_saida"]
    t.no("luz_portal_saida", "OmniLight3D", "luzes", props=[
        ("transform", transform((ox_ - otx * 4.0, oy_ - 6.0, oz_ - otz * 4.0))),
        ("light_color", cor((0.85, 0.28, 0.2, 1))), ("light_energy", "3.5"), ("shadow_enabled", "false"),
        ("omni_range", "20.0")], metas=[("piscar", "pulso")])
    for i, (x, y, z) in enumerate(P["velas"]):
        t.no("vela_%d" % i, "OmniLight3D", "luzes", props=[
            ("transform", transform((x, y + 0.1, z))), ("light_color", cor((1.0, 0.7, 0.4, 1))),
            ("light_energy", "0.9"), ("shadow_enabled", "false"), ("omni_range", "3.5")],
            metas=[("piscar", "vela")])
    # as piras: duas no mirante (sao elas que acendem o Maycow no plano da
    # gargula) e quatro no largo do fim (a luta precisa de luz)
    for i, (x, y, z) in enumerate(P["piras"]):
        t.no("luz_pira_%d" % i, "OmniLight3D", "luzes", props=[
            ("transform", transform((x, y + 1.6, z))), ("light_color", cor((1.0, 0.55, 0.25, 1))),
            ("light_energy", "6.5"), ("shadow_enabled", "false"), ("omni_range", "22.0"),
            ("omni_attenuation", "1.2")], metas=[("piscar", "fogueira")])

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

    # --- fogo: as piras e as torres acesas do grande inferno
    t.no("fogo", "Node3D")
    for i, (x, y, z) in enumerate(P["piras"]):
        T.particulas(t, "chama_pira_%d" % i, "fogo", (x, y - 0.1, z), proc_fogo, "quad_fogo", 28, 1.3,
                     (-1.6, -0.6, -1.6, 3.2, 5.5, 3.2), extras=[("preprocess", "1.0"), ("randomness", "0.4")])
        T.som(t, "estalo_%d" % i, "fogo", s_fogo, pos=(x, y, z), volume=-6.0, unit=6.0, maxd=30.0)
    for i, (x, y, z, esc) in enumerate(P["vista_fogos"]):
        T.particulas(t, "fogo_longe_%d" % i, "fogo", (x, y, z), "proc_fogo_longe", "quad_fogo_longe", 40, 2.4,
                     (-40, -10, -40, 80, 90, 80),
                     extras=[("preprocess", "2.0"), ("randomness", "0.4"),
                             ("scale", "Vector3(%.2f, %.2f, %.2f)" % (esc, esc, esc))])
        T.particulas(t, "fumo_longe_%d" % i, "fogo", (x, y + 12.0, z), "proc_fumo_longe", "quad_fumo_longe", 40, 16.0,
                     (-160, -20, -160, 320, 320, 320), extras=[("preprocess", "12.0"), ("randomness", "0.5")])

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

    # --- os dois aneis: o da chegada (volta pro inferno 3) e o do largo do
    # fim (a saida, ainda sem destino)
    t.no("redemoinho", "MeshInstance3D", props=[
        ("transform", transform((cx_, cy_, cz_ - 0.2), 3.14159)), ("mesh", 'SubResource("malha_portal")'),
        ("cast_shadow", "0")])
    T.som(t, "som_portal", ".", s_portal, pos=(cx_, cy_, cz_), volume=-6.0, unit=12.0, maxd=70.0)
    t.no("redemoinho_saida", "MeshInstance3D", props=[
        ("transform", transform((ox_ - otx * 0.2, oy_, oz_ - otz * 0.2), math.atan2(-otx, -otz))),
        ("mesh", 'SubResource("malha_portal")'), ("cast_shadow", "0")])
    T.som(t, "som_portal_saida", ".", s_portal, pos=(ox_, oy_, oz_), volume=-6.0, unit=12.0, maxd=70.0)
    sx, sy, sz, stx, stz = P["saida"]
    t.no("saida", "Area3D", props=[("transform", transform((sx, sy + 4.0, sz), math.atan2(stx, stz))),
                                   ("collision_layer", "0"), ("collision_mask", "1"), ("monitorable", "false")])
    t.no("forma", "CollisionShape3D", "saida", props=[("shape", 'SubResource("forma_anel")')])
    ex, ey, ez = P["entrada"]
    t.no("entrada", "Area3D", props=[("transform", transform((ex, ey + 4.0, ez))), ("collision_layer", "0"),
                                     ("collision_mask", "1"), ("monitorable", "false")])
    t.no("forma", "CollisionShape3D", "entrada", props=[("shape", 'SubResource("forma_anel")')])

    # --- o mirante: a faixa que dispara a cutscene e os pontos dela
    t.no("gatilho_mirante", "Area3D", props=[("transform", transform((gx, gy + 4.0, gz), ggiro)),
                                             ("collision_layer", "0"), ("collision_mask", "1"),
                                             ("monitorable", "false")])
    t.no("forma", "CollisionShape3D", "gatilho_mirante", props=[("shape", 'SubResource("forma_gatilho")')])
    t.no("mirante", "Marker3D", props=[("transform", transform((mx, my, mz)))])
    t.no("vista_alvo", "Marker3D", "mirante", props=[("transform", transform((ax - mx, ay - my, az - mz)))])
    for i, (bx, bz) in enumerate(P["beira_mirante"]):
        t.no("beira_%d" % i, "Marker3D", "mirante", props=[("transform", transform((bx - mx, 0.0, bz - mz)))])

    # --- marcadores
    t.no("areas", "Node3D")
    for nome, (x, y, z) in sorted(P["areas"].items()):
        t.no(nome, "Marker3D", "areas", props=[("transform", transform((x, y + 0.2, z)))])
    t.no("spawn_entrada", "Marker3D", props=[("transform", transform(tuple(P["player"])))])
    # quem volta da cena seguinte aparece na frente do anel, de costas pra ele
    t.no("spawn_saida", "Marker3D", props=[("transform", transform((sx - stx * 16.0, sy - 0.9, sz - stz * 16.0),
                                                                   math.atan2(stx, stz)))])
    bx, by, bz, braio = P["mini_boss"]
    t.no("boss", "Node3D")
    t.no("mini_boss", "Marker3D", "boss", props=[("transform", transform((bx, by + 0.1, bz)))],
         metas=[("raio_arena", "%.1f" % braio)])
    t.no("enemies", "Node3D")
    for i, (x, y, z) in enumerate(P["inimigos"]):
        t.no("enemy_%d" % (i + 1), "Marker3D", "enemies", props=[("transform", transform((x, y, z)))])

    # --- sons
    sx_, sy_, sz_ = P["sino"]
    T.som(t, "sino", ".", s_sino, pos=(sx_, sy_, sz_), volume=6.0, unit=60.0, maxd=900.0, autoplay=False,
          loop=False)
    T.som(t, "vento_som", ".", s_vento, volume=-10.0)
    T.som(t, "ambiente_som", ".", s_amb, volume=-16.0)
    # o grande inferno: sobe com a nevoa abrindo (o script mexe no volume)
    T.som(t, "drone_vista", ".", s_drone, volume=-40.0)
    T.som(t, "sussurro", ".", s_sussurro, volume=-14.0, autoplay=False, loop=False)
    T.som(t, "grito", ".", s_grito, volume=-18.0, autoplay=False, loop=False)
    T.som(t, "grito_gargula", ".", s_rugido, volume=-4.0, autoplay=False, loop=False, pitch=1.4)

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

    vx, vy, vz, vr = P["vista_bando"]
    z1, z2, z3, z4 = P["nevoa_z"]
    t.salvar(SAIDA, script_raiz=[
        ("script", 'ExtResource("%s")' % script),
        # o anel de chegada volta pro inferno 3; o do largo do fim ainda nao leva
        ("cena_entrada", '"%s"' % INFERNO_3),
        ("maycow_normal", "true"), ("salvar_ao_entrar", "true"), ("nevoa_do_player", '"alta"'),
        ("segue_camera_altura", "true"),
        # o ceu cheio de gargulas: as da base seguem a camera...
        ("gargulas_ceu", "9"), ("ceu_raio", "200.0"), ("ceu_altura_min", "70.0"), ("ceu_altura_max", "140.0"),
        # ...e o bando da cratera voa sobre a vista (inferno_4.gd)
        ("bando_centro", "Vector3(%.1f, %.1f, %.1f)" % (vx, vy, vz)), ("bando_raio", "%.1f" % vr),
        ("nevoa_z", "Vector4(%.1f, %.1f, %.1f, %.1f)" % (z1, z2, z3, z4)),
    ])


if __name__ == "__main__":
    main()
