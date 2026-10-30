"""Transforma um movel FIXO em corpo com fisica (RigidBody3D), como as cadeiras.

Formato de entrada (o da casa do Jimmy): o movel `mobilia/<nome>` (instancia)
e a colisao em `colisoes_mobilia/col_<nome>` (StaticBody3D + CollisionShape3D).
Sai:

    mobilia/<nome>            RigidBody3D, no transform do movel
      <nome>_malha            a instancia, identidade
      <nome>_colisao          a forma
      <enfeite>...            o que estava EM CIMA dele, agora filho (anda junto)

    python3 tools/flutuantes/rigidificar.py <cena.tscn> nome:massa [nome:massa ...]
"""
import re
import sys

import numpy as np


def blocos(texto):
    return re.split(r"\n(?=\[)", texto)


def cab(b):
    return b.split("\n", 1)[0]


def attr(c, k):
    m = re.search(k + r'="([^"]*)"', c)
    return m.group(1) if m else None


def tf_de(b):
    m = re.search(r"transform = Transform3D\(([^)]*)\)", b)
    if not m:
        return np.eye(4)
    v = [float(x) for x in m.group(1).split(",")]
    t = np.eye(4)
    # colunas da base: (v0,v1,v2) = x, (v3,v4,v5) = y, (v6,v7,v8) = z
    t[:3, 0] = v[0:3]
    t[:3, 1] = v[3:6]
    t[:3, 2] = v[6:9]
    t[:3, 3] = v[9:12]
    return t


def tf_txt(t):
    v = list(t[:3, 0]) + list(t[:3, 1]) + list(t[:3, 2]) + list(t[:3, 3])
    return "transform = Transform3D(%s)" % ", ".join(("%.6f" % n).rstrip("0").rstrip(".") if abs(n) > 1e-9 else "0" for n in v)


def com_tf(b, t):
    linha = tf_txt(t)
    if re.search(r"transform = Transform3D\([^)]*\)", b):
        return re.sub(r"transform = Transform3D\([^)]*\)", linha, b, count=1)
    c, _, resto = b.partition("\n")
    return c + "\n" + linha + ("\n" + resto if resto else "")


def tamanho_forma(texto, ident):
    m = re.search(r'\[sub_resource type="BoxShape3D" id="%s"\]\nsize = Vector3\(([^)]*)\)' % re.escape(ident), texto)
    return [float(x) for x in m.group(1).split(",")] if m else None


def main():
    caminho = sys.argv[1]
    pedidos = [a.split(":") for a in sys.argv[2:]]
    texto = open(caminho).read()
    for nome, massa in pedidos:
        bs = blocos(texto)
        i_mov = next(i for i, b in enumerate(bs) if cab(b).startswith('[node name="%s"' % nome) and attr(cab(b), "parent") == "mobilia")
        i_col = next(i for i, b in enumerate(bs) if cab(b).startswith('[node name="col_%s"' % nome))
        i_cs = next(i for i, b in enumerate(bs) if attr(cab(b), "parent") == "colisoes_mobilia/col_%s" % nome)
        t_mov = tf_de(bs[i_mov])
        t_col = tf_de(bs[i_col])
        t_cs = tf_de(bs[i_cs])
        forma = re.search(r'shape = SubResource\("([^"]+)"\)', bs[i_cs]).group(1)
        tam = tamanho_forma(texto, forma)
        inv = np.linalg.inv(t_mov)
        # o que esta' em cima: origem dentro da pegada da forma e acima do chao
        cs_mundo = t_col @ t_cs
        centro = cs_mundo[:3, 3]
        topo = centro[1] + tam[1] / 2
        enfeites = []
        for i, b in enumerate(bs):
            c = cab(b)
            if i == i_mov or attr(c, "parent") != "mobilia" or "RigidBody3D" in c:
                continue
            o = tf_de(b)[:3, 3]
            local = np.linalg.inv(cs_mundo) @ np.array([o[0], o[1], o[2], 1.0])
            if abs(local[0]) <= tam[0] / 2 + 0.02 and abs(local[2]) <= tam[2] / 2 + 0.02 \
                    and topo - 0.15 <= o[1] <= topo + 0.6:
                enfeites.append(i)
        # o RigidBody no lugar do movel
        inst = re.search(r'instance=ExtResource\("([^"]+)"\)', cab(bs[i_mov])).group(1)
        corpo = ('[node name="%s" type="RigidBody3D" parent="mobilia"]\n%s\ncollision_layer = 2\ncollision_mask = 2\n'
                 'mass = %s\nlinear_damp = 2.0\nangular_damp = 3.0\n') % (nome, tf_txt(t_mov), massa)
        malha = '[node name="%s_malha" parent="mobilia/%s" instance=ExtResource("%s")]\n' % (nome, nome, inst)
        colisao = '[node name="%s_colisao" type="CollisionShape3D" parent="mobilia/%s"]\n%s\nshape = SubResource("%s")\n' % (
            nome, nome, tf_txt(inv @ t_col @ t_cs), forma)
        novos_enfeites = []
        for i in enfeites:
            b = bs[i]
            b = b.replace('parent="mobilia"', 'parent="mobilia/%s"' % nome, 1)
            novos_enfeites.append(com_tf(b, inv @ tf_de(bs[i])))
        print(nome, "enfeites:", [attr(cab(bs[i]), "name") for i in enfeites])
        tirar = {i_mov, i_col, i_cs} | set(enfeites)
        saida = []
        for i, b in enumerate(bs):
            if i == i_mov:
                saida.extend([corpo, malha, colisao] + novos_enfeites)
            elif i not in tirar:
                saida.append(b)
        texto = "\n".join(s.rstrip("\n") + "\n" for s in saida)
    open(caminho, "w").write(texto)


main()
