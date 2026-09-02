"""Constrói um material Principled por entrada da paleta.

Etapa 00 deliberadamente NÃO gera textura procedural: o objetivo é validar
albedo + rugosidade sob a luz real do Godot. A textura entra na Etapa 02,
assada a partir destes mesmos materiais.
"""
import bpy
from . import palette

PREFIX = "MI_"

# nomes de socket mudaram entre versões do Blender; tenta em ordem
_ALIASES = {
    "base_color": ("Base Color",),
    "roughness": ("Roughness",),
    "metallic": ("Metallic",),
    "specular": ("Specular IOR Level", "Specular"),
}


def _set(node, key, value):
    for name in _ALIASES[key]:
        if name in node.inputs:
            node.inputs[name].default_value = value
            return True
    return False


def build_one(name, entry):
    mat = bpy.data.materials.get(PREFIX + name)
    if mat is None:
        mat = bpy.data.materials.new(PREFIX + name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if out is None:
            out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs[0], out.inputs["Surface"])

    col = palette.hex_to_linear(entry["hex"])
    _set(bsdf, "base_color", col)
    _set(bsdf, "roughness", float(entry.get("rough", 0.85)))
    _set(bsdf, "metallic", float(entry.get("metal", 0.0)))
    _set(bsdf, "specular", 0.35)

    # cor de viewport: usa o sRGB direto para o solid shading bater com a paleta
    mat.diffuse_color = col
    mat.roughness = float(entry.get("rough", 0.85))
    mat.metallic = float(entry.get("metal", 0.0))
    mat["citygen_hex"] = entry["hex"]
    mat["citygen_family"] = entry.get("family", "")
    mat["citygen_uso"] = entry.get("uso", "")
    return mat


def build_all():
    entries = palette.flat()
    made = {}
    for name, e in entries.items():
        made[name] = build_one(name, e)
    return made


def get(name):
    return bpy.data.materials.get(PREFIX + name)


# --------------------------------------------------------------- texturas
import os

# lib -> citygen -> blender -> tools -> raiz do repo (5 niveis)
_REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                     "..", "..", "..", ".."))
TEXDIR = os.path.join(_REPO, "red-valve", "assets", "3d_model", "city", "textures")

# material da paleta -> basename da textura (Etapa 02)
TEXTURED = {
    "cobble_base": "T_cobble",
    "cobble_polish": "T_cobble_worn",
    "sidewalk_concrete": "T_sidewalk",
    "dirt_road": "T_dirt",
    "curb_granite": "T_curb",
    "sign_plate": "T_signs",
    "wall_whitewash": "T_plaster",
    "wall_render_raw": "T_plaster_raw",
    "wall_brick": "T_brick",
    "wood_aged": "T_wood",
    "roof_metal_rust": "T_metal_corr",
    "roof_metal_zinc": "T_metal_corr",
    "roof_tile_faded": "T_roof_tile",
    "roof_tile_warm": "T_roof_tile_warm",
    "roof_tile_bleached": "T_roof_tile_pale",
    "paint_shop_red": "T_plaster_red",
    "paint_shop_ochre": "T_plaster_ochre",
    "wall_stone_church": "T_stone_church",
    "wall_stone_cemetery": "T_stone_cemetery",
    "roof_slate_blue": "T_slate",
}


def _img(path, non_color):
    img = bpy.data.images.get(os.path.basename(path))
    if img is None or img.filepath_from_user() != path:
        img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    return img


def attach_textures(mat, base):
    """Liga albedo / normal / ORM (R=occ, G=rough, B=metal) ao Principled.

    A embalagem ORM é exatamente a convenção glTF, então o exportador escreve
    metallicRoughnessTexture direto, sem reempacotar.
    """
    paths = {k: os.path.join(TEXDIR, "%s_%s.png" % (base, k))
             for k in ("alb", "nrm", "orm")}
    # normal e opcional (a placa esmaltada, por exemplo, e lisa)
    if not all(os.path.exists(paths[k]) for k in ("alb", "orm")):
        return False

    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return False
    for n in [n for n in nt.nodes if n.type in
              ("TEX_IMAGE", "NORMAL_MAP", "SEPARATE_COLOR", "MAPPING",
               "TEX_COORD", "VERTEX_COLOR", "MIX")]:
        nt.nodes.remove(n)

    ta = nt.nodes.new("ShaderNodeTexImage"); ta.location = (-620, 300)
    ta.image = _img(paths["alb"], False)

    # Color Attribute multiplicando o albedo: sem este no, o exportador glTF
    # descarta a vertex color (sarjeta e trilha de roda) por "nao usada".
    vc = nt.nodes.new("ShaderNodeVertexColor"); vc.location = (-620, 520)
    vc.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix"); mix.location = (-320, 400)
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(ta.outputs["Color"], mix.inputs[6])
    nt.links.new(vc.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])

    if os.path.exists(paths["nrm"]):
        tn = nt.nodes.new("ShaderNodeTexImage"); tn.location = (-620, 20)
        tn.image = _img(paths["nrm"], True)
        nm = nt.nodes.new("ShaderNodeNormalMap"); nm.location = (-320, 20)
        nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])

    to = nt.nodes.new("ShaderNodeTexImage"); to.location = (-620, -260)
    to.image = _img(paths["orm"], True)
    sp = nt.nodes.new("ShaderNodeSeparateColor"); sp.location = (-320, -260)
    nt.links.new(to.outputs["Color"], sp.inputs["Color"])
    nt.links.new(sp.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sp.outputs["Blue"], bsdf.inputs["Metallic"])
    mat["citygen_tex"] = base
    return True


def build_all_textured():
    made = build_all()
    n = 0
    for name, base in TEXTURED.items():
        mat = made.get(name)
        if mat is not None and attach_textures(mat, base):
            n += 1
    return made, n
