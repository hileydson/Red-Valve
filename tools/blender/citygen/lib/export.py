"""Exporta uma coleção para .glb (seleção), para o lado Godot."""
import os
import bpy


def export_collection(col_name, filepath):
    col = bpy.data.collections.get(col_name)
    if col is None:
        return {"ok": False, "error": "coleção %r não existe" % col_name}

    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    n = 0
    for ob in col.all_objects:
        if ob.type == "MESH":
            ob.select_set(True)
            bpy.context.view_layer.objects.active = ob
            n += 1
    if n == 0:
        return {"ok": False, "error": "nenhuma malha em %r" % col_name}

    # .gltf separado + keep_originals: o arquivo REFERENCIA as PNGs que ja
    # estao no projeto, em vez de embutir uma copia em cada .glb. Sem isso
    # cada export duplicava ~15 MB de textura.
    kw = dict(filepath=filepath, export_format="GLTF_SEPARATE",
              use_selection=True, export_keep_originals=True)
    try:
        bpy.ops.export_scene.gltf(**kw)
    except TypeError:
        bpy.ops.export_scene.gltf(filepath=filepath, export_format="GLTF_SEPARATE",
                                  use_selection=True)
    size = 0
    base = os.path.splitext(filepath)[0]
    for ext in (".gltf", ".bin"):
        if os.path.exists(base + ext):
            size += os.path.getsize(base + ext)
    return {"ok": size > 0, "path": base + ".gltf", "meshes": n, "bytes": size}


def merge_by_material(col_name, colisao=None):
    """Une os objetos de uma coleção por material — corta draw calls.

    `colisao` é o conjunto de materiais (sem o prefixo MI_) que devem ganhar
    o sufixo `-col`: o importador glTF do Godot cria StaticBody3D +
    ConcavePolygonShape3D para esses, mantendo a malha visual.

    Destrutivo, mas as fases são idempotentes: re-rodar reconstrói tudo.
    """
    colisao = colisao or set()
    col = bpy.data.collections.get(col_name)
    if col is None:
        return {"ok": False, "error": "coleção %r não existe" % col_name}
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")

    grupos = {}
    for ob in list(col.objects):
        if ob.type != "MESH" or not ob.data.materials:
            continue
        grupos.setdefault(ob.data.materials[0].name, []).append(ob)

    antes = len([o for o in col.objects if o.type == "MESH"])
    # prefixo por coleção: sem ele o Blender vira "-col.002" ao repetir um
    # nome, e o importador do Godot só reconhece o sufixo "-col" exato.
    tag = col_name.split("_", 1)[-1].lower()[:6]
    for mat_name, obs in grupos.items():
        if len(obs) > 1:
            bpy.ops.object.select_all(action="DESELECT")
            for ob in obs:
                ob.select_set(True)
            bpy.context.view_layer.objects.active = obs[0]
            bpy.ops.object.join()
        curto = mat_name.replace("MI_", "")
        sufixo = "-col" if (colisao is True or curto in colisao) else ""
        # grupos de um objeto só também precisam do sufixo
        obs[0].name = "SM_%s_%s%s" % (tag, curto, sufixo)
    depois = len([o for o in col.objects if o.type == "MESH"])
    com_col = [o.name for o in col.objects if o.name.endswith("-col")]
    return {"ok": True, "antes": antes, "depois": depois,
            "materiais": sorted(grupos), "com_colisao": len(com_col)}
