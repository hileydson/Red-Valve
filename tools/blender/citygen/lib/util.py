"""Helpers de coleção, malha e limpeza idempotente.

Regra do projeto: toda função de construção apaga a própria coleção antes de
reconstruir. Rodar duas vezes nunca duplica geometria.
"""
import bpy


# ---------------------------------------------------------------- coleções
def _unlink_everywhere(col):
    for c in list(bpy.data.collections):
        if col.name in c.children:
            c.children.unlink(col)
    sc = bpy.context.scene.collection
    if col.name in sc.children:
        sc.children.unlink(col)


def get_collection(name, parent=None):
    """Devolve a coleção `name`, criando e religando ao pai se preciso."""
    parent = parent or bpy.context.scene.collection
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
    if col.name not in parent.children:
        _unlink_everywhere(col)
        parent.children.link(col)
    return col


def clear_collection(col):
    """Remove recursivamente objetos e sub-coleções, preservando a coleção."""
    for child in list(col.children):
        clear_collection(child)
        col.children.unlink(child)
        if child.users == 0:
            bpy.data.collections.remove(child)
    for ob in list(col.objects):
        bpy.data.objects.remove(ob, do_unlink=True)


def reset_collection(name, parent=None):
    """get_collection + clear_collection — o par idempotente padrão."""
    col = get_collection(name, parent)
    clear_collection(col)
    return col


def purge_orphans():
    for _ in range(4):
        n = 0
        for block in (bpy.data.meshes, bpy.data.curves, bpy.data.lights,
                      bpy.data.cameras, bpy.data.images):
            for d in list(block):
                if d.users == 0:
                    block.remove(d)
                    n += 1
        if n == 0:
            break


# ---------------------------------------------------------------- malhas
def _mk(name, verts, faces, col, mat=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.rotation_euler = rot
    if mat is not None:
        ob.data.materials.append(mat)
    col.objects.link(ob)
    return ob


def box(name, sx, sy, sz, col, mat=None, loc=(0, 0, 0), rot=(0, 0, 0), base=True):
    """Caixa sx*sy*sz. base=True assenta a face inferior em z=0 do objeto."""
    hx, hy = sx / 2.0, sy / 2.0
    z0, z1 = (0.0, sz) if base else (-sz / 2.0, sz / 2.0)
    v = [(-hx, -hy, z0), (hx, -hy, z0), (hx, hy, z0), (-hx, hy, z0),
         (-hx, -hy, z1), (hx, -hy, z1), (hx, hy, z1), (-hx, hy, z1)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
         (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return _mk(name, v, f, col, mat, loc, rot)


def plane(name, sx, sy, col, mat=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    hx, hy = sx / 2.0, sy / 2.0
    v = [(-hx, -hy, 0), (hx, -hy, 0), (hx, hy, 0), (-hx, hy, 0)]
    return _mk(name, v, [(0, 1, 2, 3)], col, mat, loc, rot)


def cyl(name, r, h, col, mat=None, loc=(0, 0, 0), rot=(0, 0, 0), seg=10):
    import math
    v, f = [], []
    for i in range(seg):
        a = 2.0 * math.pi * i / seg
        v.append((r * math.cos(a), r * math.sin(a), 0.0))
    for i in range(seg):
        a = 2.0 * math.pi * i / seg
        v.append((r * math.cos(a), r * math.sin(a), h))
    for i in range(seg):
        j = (i + 1) % seg
        f.append((i, j, seg + j, seg + i))
    f.append(tuple(range(seg - 1, -1, -1)))
    f.append(tuple(range(seg, 2 * seg)))
    return _mk(name, v, f, col, mat, loc, rot)


# ---------------------------------------------------------------- cena
def setup_scene_units():
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'
    sc.unit_settings.length_unit = 'METERS'
    sc.unit_settings.scale_length = 1.0


def faces_up(ob, limiar=-0.05):
    """Vira as faces cuja normal aponta para baixo.

    Só para superfícies ABERTAS que representam chão (pista, calçada, lote,
    terreno). Nunca usar em sólido fechado: a face de baixo de uma caixa
    aponta para baixo por definição, e virá-la a joga para dentro.

    A fita gerada por `_strip` sai com winding invertido — as faces ficam
    visíveis (o glTF marca doubleSided) mas com N·L < 0, então nenhuma luz
    as atinge. Este é o conserto.
    """
    me = ob.data
    n = 0
    for poly in me.polygons:
        if poly.normal.z < limiar:
            poly.flip()
            n += 1
    if n:
        me.update()
    return n
