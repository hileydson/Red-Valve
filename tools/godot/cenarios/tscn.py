# -*- coding: utf-8 -*-
"""Escrita de .tscn e .tres para os cenarios gerados por script (arena 3,
cemiterio, inferno).

Reaproveita as convencoes do gerador da arena 2 (`tools/godot/arena_2/
gerar_cena_arena_2.py`): Transform3D por LINHAS, `conferir_ordem` antes de
gravar (SubResource citado antes de declarado derruba a cena inteira) e
`billboard_keep_scale` em toda particula (sem ele scale_min/max nao valem).

O que mora aqui:
  - `Tscn`: externos, sub-recursos e nos, na ordem certa;
  - `material_textura` / `material_emissivo`: os .tres de cada cenario;
  - presets de particula que os tres cenarios repetem.
"""

import math
import os
import sys

# nao suja o __pycache__ versionado da arena 2 ao importar o gerador dela
sys.dont_write_bytecode = True

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "arena_2"))

import gerar_cena_arena_2 as g2  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
BASE = os.path.join(RAIZ, "red-valve")

cor = g2.cor
transform = g2.transform
transform_olhando = g2.transform_olhando
conferir_ordem = g2.conferir_ordem

PH_TEX = "res://assets/images/textures/polyhaven/"
CITY_TEX = "res://assets/3d_model/city/textures/"


def vec3(v):
    return "Vector3(%s)" % ", ".join("%g" % c for c in v)


class Tscn:

    def __init__(self, raiz, tipo="Node3D"):
        self.raiz = raiz
        self.tipo = tipo
        self.externos = []          # (tipo, caminho, id)
        self._por_caminho = {}
        self.subs = []              # (id, tipo, linhas)
        self._ids = set()
        self.nos = []

    def ext(self, tipo, caminho):
        if caminho in self._por_caminho:
            return self._por_caminho[caminho]
        ident = "%d_%s" % (len(self.externos) + 1,
                           os.path.splitext(os.path.basename(caminho))[0][:24].replace(" ", "_"))
        self.externos.append((tipo, caminho, ident))
        self._por_caminho[caminho] = ident
        return ident

    def sub(self, ident, tipo, linhas):
        if ident in self._ids:
            return ident
        self._ids.add(ident)
        self.subs.append((ident, tipo, list(linhas)))
        return ident

    def no(self, nome, tipo=None, pai=".", instancia=None, props=(), metas=()):
        cab = '[node name="%s"' % nome
        if tipo:
            cab += ' type="%s"' % tipo
        if pai is not None:
            cab += ' parent="%s"' % pai
        if instancia:
            cab += ' instance=ExtResource("%s")' % instancia
        linhas = [cab + "]"]
        for chave, valor in props:
            linhas.append("%s = %s" % (chave, valor))
        for chave, valor in metas:
            linhas.append('metadata/%s = "%s"' % (chave, valor))
        self.nos.append(linhas)

    def salvar(self, caminho, script_raiz=None, conexoes=()):
        linhas = ["[gd_scene load_steps=%d format=3]" % (len(self.externos) + len(self.subs) + 1), ""]
        for tipo, cam, ident in self.externos:
            linhas.append('[ext_resource type="%s" path="%s" id="%s"]' % (tipo, cam, ident))
        linhas.append("")
        for ident, tipo, corpo in self.subs:
            linhas.append('[sub_resource type="%s" id="%s"]' % (tipo, ident))
            linhas.extend(corpo)
            linhas.append("")
        cab = '[node name="%s" type="%s"]' % (self.raiz, self.tipo)
        linhas.append(cab)
        if script_raiz:
            for chave, valor in script_raiz:
                linhas.append("%s = %s" % (chave, valor))
        linhas.append("")
        for no in self.nos:
            linhas.extend(no)
            linhas.append("")
        for c in conexoes:
            linhas.append(c)
        conferir_ordem(linhas)
        os.makedirs(os.path.dirname(caminho), exist_ok=True)
        with open(caminho, "w") as fp:
            fp.write("\n".join(linhas).rstrip() + "\n")
        print("  %s  (externos=%d sub=%d nos=%d)" % (caminho, len(self.externos), len(self.subs),
                                                     len(self.nos)))


# --------------------------------------------------------------------------
# materiais (.tres)


def _grava_tres(caminho, externos, linhas):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    out = ['[gd_resource type="StandardMaterial3D" format=3]', ""]
    for i, (tipo, cam) in enumerate(externos):
        out.append('[ext_resource type="%s" path="%s" id="%d"]' % (tipo, cam, i + 1))
    if externos:
        out.append("")
    out.append("[resource]")
    out.extend(linhas)
    with open(caminho, "w") as fp:
        fp.write("\n".join(out) + "\n")


def material_textura(caminho, alb, nrm, orm, albedo, rough=1.0, normal_scale=1.0,
                     uv=0.5, extras=()):
    """Material triplanar em espaco de mundo, como os da arena 2 (o modelo e'
    regerado, entao UV de verdade nao existe — triplanar resolve tudo)."""
    linhas = [
        'albedo_texture = ExtResource("1")',
        'roughness_texture = ExtResource("3")',
        "roughness_texture_channel = 1",
        "normal_enabled = true",
        'normal_texture = ExtResource("2")',
        "ao_enabled = true",
        'ao_texture = ExtResource("3")',
        "ao_texture_channel = 0",
        "ao_light_affect = 0.45",
        "uv1_triplanar = true",
        "uv1_world_triplanar = true",
        "albedo_color = " + cor(albedo),
        "roughness = %g" % rough,
        "normal_scale = %g" % normal_scale,
        "uv1_scale = Vector3(%g, %g, %g)" % (uv, uv, uv),
    ]
    linhas.extend(extras)
    _grava_tres(caminho, [("Texture2D", alb), ("Texture2D", nrm), ("Texture2D", orm)], linhas)


def tex_ph(nome):
    """(alb, nrm, arm) de uma textura do Poly Haven ja' no projeto."""
    return (PH_TEX + nome + "_diff.jpg", PH_TEX + nome + "_nor_gl.jpg", PH_TEX + nome + "_arm.jpg")


def tex_city(nome):
    return (CITY_TEX + "T_%s_alb.png" % nome, CITY_TEX + "T_%s_nrm.png" % nome,
            CITY_TEX + "T_%s_orm.png" % nome)


def material_emissivo(caminho, albedo, emissao, energia, rough=0.85, extras=()):
    linhas = ["albedo_color = " + cor(albedo), "roughness = %g" % rough,
              "emission_enabled = true", "emission = " + cor(emissao),
              "emission_energy_multiplier = %g" % energia]
    linhas.extend(extras)
    _grava_tres(caminho, [], linhas)


def material_chapado(caminho, albedo, rough=1.0, extras=()):
    linhas = ["albedo_color = " + cor(albedo), "roughness = %g" % rough, "specular_mode = 1"]
    linhas.extend(extras)
    _grava_tres(caminho, [], linhas)


# --------------------------------------------------------------------------
# particulas


def texturas_base(t):
    """Ponto macio + materiais aditivo/fosco de particula."""
    t.sub("grad_ponto", "Gradient", [
        "offsets = PackedFloat32Array(0, 0.45, 1)",
        "colors = PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0.55, 1, 1, 1, 0)"])
    t.sub("tex_ponto", "GradientTexture2D", [
        'gradient = SubResource("grad_ponto")', "width = 64", "height = 64",
        "fill = 1", "fill_from = Vector2(0.5, 0.5)", "fill_to = Vector2(1, 0.5)"])
    t.sub("grad_fumo", "Gradient", [
        "offsets = PackedFloat32Array(0, 0.35, 1)",
        "colors = PackedColorArray(1, 1, 1, 0.75, 1, 1, 1, 0.32, 1, 1, 1, 0)"])
    t.sub("tex_fumo", "GradientTexture2D", [
        'gradient = SubResource("grad_fumo")', "width = 128", "height = 128",
        "fill = 1", "fill_from = Vector2(0.5, 0.5)", "fill_to = Vector2(1, 0.5)"])
    for ident, blend, bb, tex in (("mat_aditivo", 1, 1, "tex_ponto"), ("mat_fosco", 0, 1, "tex_ponto"),
                                  ("mat_risco", 1, 3, "tex_ponto"), ("mat_risco_fosco", 0, 3, "tex_ponto"),
                                  ("mat_fumo", 0, 1, "tex_fumo"), ("mat_fumo_aditivo", 1, 1, "tex_fumo")):
        t.sub(ident, "StandardMaterial3D", [
            "transparency = 1", "blend_mode = %d" % blend, "shading_mode = 0",
            "vertex_color_use_as_albedo = true",
            'albedo_texture = SubResource("%s")' % tex,
            "billboard_mode = %d" % bb, "billboard_keep_scale = true",
            "disable_receive_shadows = true"])


def rampa(t, ident, offsets, cores):
    """Gradiente + GradientTexture1D. `cores` = lista de (r,g,b,a)."""
    t.sub("g_" + ident, "Gradient", [
        "offsets = PackedFloat32Array(%s)" % ", ".join("%g" % o for o in offsets),
        "colors = PackedColorArray(%s)" % ", ".join("%g" % c for cc in cores for c in cc)])
    return t.sub("r_" + ident, "GradientTexture1D", ['gradient = SubResource("g_%s")' % ident, "width = 64"])


def quad(t, ident, mat, w, h):
    return t.sub(ident, "QuadMesh", ['material = SubResource("%s")' % mat, "size = Vector2(%g, %g)" % (w, h)])


def processo(t, ident, **kw):
    """ParticleProcessMaterial a partir de kwargs com o nome da propriedade."""
    linhas = []
    for chave, valor in kw.items():
        if isinstance(valor, bool):
            valor = "true" if valor else "false"
        elif isinstance(valor, (tuple, list)):
            valor = vec3(valor)
        linhas.append("%s = %s" % (chave, valor))
    return t.sub(ident, "ParticleProcessMaterial", linhas)


def particulas(t, nome, pai, pos, proc, malha, amount, lifetime, aabb, extras=()):
    props = [("transform", transform(pos)), ("amount", str(amount)), ("lifetime", "%g" % lifetime)]
    props.extend(extras)
    props.extend([("visibility_aabb", "AABB(%s)" % ", ".join("%g" % c for c in aabb)),
                  ("process_material", 'SubResource("%s")' % proc),
                  ("draw_pass_1", 'SubResource("%s")' % malha)])
    t.no(nome, "GPUParticles3D", pai, props=props)


def fogo_preset(t):
    """O braseiro da arena 2: chama que sobe e treme."""
    rampa(t, "fogo", (0, 0.25, 0.65, 1), ((1, 0.95, 0.6, 1), (1, 0.5, 0.12, 1),
                                         (0.6, 0.11, 0.03, 0.75), (0.15, 0.03, 0.02, 0)))
    quad(t, "quad_fogo", "mat_aditivo", 0.55, 0.8)
    return processo(t, "proc_fogo", emission_shape=1, emission_sphere_radius=0.3,
                    direction=(0, 1, 0), spread=14.0, initial_velocity_min=0.7,
                    initial_velocity_max=1.8, gravity=(0, 1.1, 0), damping_min=0.6,
                    damping_max=1.4, scale_min=0.4, scale_max=1.1,
                    color_ramp='SubResource("r_fogo")', turbulence_enabled=True,
                    turbulence_noise_strength=0.55, turbulence_noise_scale=2.2)


def som(t, nome, pai, stream, pos=None, volume=-8.0, unit=8.0, maxd=40.0, autoplay=True,
        loop=True, pitch=1.0):
    props = []
    tipo = "AudioStreamPlayer"
    if pos is not None:
        tipo = "AudioStreamPlayer3D"
        props.append(("transform", transform(pos)))
    props.append(("stream", 'ExtResource("%s")' % stream))
    props.append(("volume_db", "%g" % volume))
    if pitch != 1.0:
        props.append(("pitch_scale", "%g" % pitch))
    if pos is not None:
        props.append(("unit_size", "%g" % unit))
        props.append(("max_distance", "%g" % maxd))
    if autoplay:
        props.append(("autoplay", "true"))
    if loop:
        props.append(("parameters/looping", "true"))
    t.no(nome, tipo, pai, props=props)


def navmesh(t, nav):
    verts = []
    for v in nav["v"]:
        verts.extend("%g" % c for c in v)
    polis = ", ".join("PackedInt32Array(%s)" % ", ".join(str(i) for i in p) for p in nav["p"])
    t.sub("navmesh", "NavigationMesh", [
        "vertices = PackedVector3Array(%s)" % ", ".join(verts),
        "polygons = [%s]" % polis,
        "agent_radius = 0.6"])
    t.no("navegacao", "NavigationRegion3D", ".", props=[
        ("navigation_mesh", 'SubResource("navmesh")'), ("navigation_layers", "4")])


def ruido_ceu(t, semente=7, freq=0.012):
    t.sub("ruido_ceu_fn", "FastNoiseLite", [
        "noise_type = 3", "seed = %d" % semente, "frequency = %g" % freq,
        "fractal_octaves = 3"])
    return t.sub("ruido_ceu", "NoiseTexture2D", [
        "width = 256", "height = 256", "seamless = true",
        'noise = SubResource("ruido_ceu_fn")'])


def angulo_para(x, z, alvo=(0.0, 0.0)):
    return math.atan2(alvo[0] - x, alvo[1] - z)
