# -*- coding: utf-8 -*-
"""Rig do Lekroso 1 (o primeiro dos lekrosos): malha + esqueleto + pesos.

    blender -b --factory-startup -P tools/blender/lekrosos/montar_lekroso.py -- lekroso_1

Le':   red-valve/assets/3d_model/enemies/lekrosos/lekroso_1.glb   (scan, sem rig)
Salva: Red-Valve-Blender/lekrosos/lekroso_1.blend                  (fonte)

Mesmo caminho do Grizzolito e das malhas de scan da igreja: o esqueleto sai
de PONTOS MEDIDOS e os pesos de um proxy de voxel (ver `rig_lib.py` em
`tools/blender/igreja_dona_nice/`). Os pontos foram medidos em render
ortografico com grade de 5 cm (frente e lado, coordenadas do .glb importado:
Z pra cima, frente no -Y, +X e' a ESQUERDA do personagem).

O lekroso esta' em pose relaxada de zumbi: bracos pendurados um pouco a'
frente do corpo, cabeca projetada pra frente do pescoco e pes abertos. O
scan tem 116 mil triangulos — decimado pra 36 mil (o renderer e' o mobile, e
o desmembramento ainda soma as pecas por cima).

Depois deste: `cortar.py` (pecas, feridas e cotos) e `animar.py` (clipes),
na ordem do `construir.sh`. RODAR DE NOVO SOBRESCREVE o .blend.
"""

import os
import sys

import bmesh

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(AQUI), "igreja_dona_nice"))
import rig_lib as R  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
LEKROSOS = os.path.join(RAIZ, "red-valve/assets/3d_model/enemies/lekrosos")
BLENDS = os.path.join(os.path.dirname(RAIZ), "Red-Valve-Blender")

PERSONAGENS = {
    # 1,88 m, bracos pendurados a' frente, cabeca pra frente do pescoco.
    "lekroso_1": {
        "arquivo": "lekroso_1.glb",
        "altura": 1.88, "voxel": 0.012, "tris": 36000,
        "pontos": R.espelhar({
            "hips": (0.0, 0.06, -0.04), "spine": (0.0, 0.06, 0.10),
            "chest": (0.0, 0.05, 0.26), "upper_chest": (0.0, 0.03, 0.42),
            "neck": (0.0, -0.01, 0.62), "head": (0.0, -0.10, 0.72),
            "head_top": (0.0, -0.14, 0.94),
            "shoulder.L": (0.05, 0.02, 0.57), "upper_arm.L": (0.21, 0.03, 0.54),
            "forearm.L": (0.31, 0.01, 0.23), "hand.L": (0.375, -0.07, 0.0),
            "fingers_tip.L": (0.37, -0.11, -0.20),
            "thumb.L": (0.35, -0.10, -0.04), "thumb_tip.L": (0.33, -0.15, -0.12),
            # joelho e tornozelo no MEIO da perna (medido por fatia da malha:
            # na frente da rotula o eixo da canela ficava rente a' pele)
            "thigh.L": (0.10, 0.085, -0.08), "shin.L": (0.14, 0.035, -0.46),
            "foot.L": (0.18, 0.125, -0.86), "toe.L": (0.19, -0.04, -0.92),
            "toe_tip.L": (0.20, -0.14, -0.94),
        }),
    },
}


def main():
    nome = sys.argv[sys.argv.index("--") + 1]
    cfg = PERSONAGENS[nome]
    R.limpar_cena()
    malha = R.importar_malha(os.path.join(LEKROSOS, cfg["arquivo"]))
    malha.name = nome + "_malha"
    # O glTF chega com o vertice DUPLICADO em toda costura de UV, e a
    # decimacao mexe nas duas bordas de cada costura sem saber que eram a
    # mesma: sobravam frestas pela roupa inteira (e o desmembramento poe
    # carne la dentro, que aparecia por elas). Soldar antes: no Blender o UV
    # e' do canto da face, nao do vertice, entao nada se perde.
    bm = bmesh.new()
    bm.from_mesh(malha.data)
    antes = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0002)
    print("  soldados %d vertices de costura" % (antes - len(bm.verts)))
    bm.to_mesh(malha.data)
    bm.free()
    if cfg["tris"]:
        print("  decimada para %d tris" % R.decimar(malha, cfg["tris"]))
    pontos, _ = R.normalizar_escala(malha, cfg["altura"], dict(cfg["pontos"]))
    arm = R.criar_esqueleto(nome + "_rig", pontos)
    R.pesar(malha, arm, voxel=cfg["voxel"] * cfg["altura"] / 1.9)
    saida = os.path.join(BLENDS, "lekrosos", nome + ".blend")
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    R.salvar(saida)
    print("== salvo", saida)


main()
