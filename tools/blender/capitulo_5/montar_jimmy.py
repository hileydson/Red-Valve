# -*- coding: utf-8 -*-
"""Rig do Jimmy (o patrao do Maycow, preso do outro lado): malha + esqueleto +
pesos.

    blender -b --factory-startup -P tools/blender/capitulo_5/montar_jimmy.py

Le':   red-valve/assets/3d_model/npc/jimmy.glb      (scan, sem rig)
Salva: Red-Valve-Blender/jimmy/jimmy.blend          (fonte)

Mesmo caminho da Drizzi e das malhas de scan da igreja
(`tools/blender/igreja_dona_nice/rig_lib.py`): o esqueleto sai de PONTOS
MEDIDOS e os pesos de um proxy de voxel. Os pontos foram medidos em render
ortografico com grade e em fatias da malha (coordenadas do .glb importado: Z
pra cima, frente no -Y, +X e' a ESQUERDA dele). O scan tem 1,90 de altura
CENTRADO na origem (z de -0,952 a 0,951), de macacao, em pose A.

A malha vai decimada (o scan tem 265 mil vertices): ele anda atras do Maycow
pela cidade e pelo hospital, nao so' em cutscene.

As animacoes vem do `animar_capitulo_5.py` desta pasta, que abre o .blend
salvo aqui. RODAR DE NOVO SOBRESCREVE o .blend (e as acoes que estiverem nele).
"""

import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(AQUI), "igreja_dona_nice"))
import rig_lib as R  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
ORIGEM = os.path.join(RAIZ, "red-valve/assets/3d_model/npc/jimmy.glb")
BLENDS = os.path.join(os.path.dirname(RAIZ), "Red-Valve-Blender")

## Do alto da cabeca a' sola da bota.
ALTURA = 1.80
VOXEL = 0.013
TRIS = 50000

PONTOS = R.espelhar({
    "hips": (0.0, 0.02, 0.04), "spine": (0.0, 0.03, 0.17),
    "chest": (0.0, 0.03, 0.32), "upper_chest": (0.0, 0.03, 0.46),
    "neck": (0.0, 0.03, 0.63), "head": (0.0, 0.02, 0.70),
    "head_top": (0.0, 0.02, 0.951),
    # bracos em A, os dois iguais
    "shoulder.L": (0.05, 0.03, 0.57), "upper_arm.L": (0.205, 0.04, 0.535),
    "forearm.L": (0.40, 0.045, 0.30), "hand.L": (0.53, -0.03, 0.15),
    "fingers_tip.L": (0.61, -0.08, 0.0),
    "thumb.L": (0.535, -0.07, 0.12), "thumb_tip.L": (0.54, -0.14, 0.07),
    "thigh.L": (0.10, 0.0, -0.02), "shin.L": (0.15, 0.025, -0.46),
    "foot.L": (0.205, 0.06, -0.87), "toe.L": (0.21, -0.08, -0.93),
    "toe_tip.L": (0.21, -0.17, -0.945),
})


def main():
    R.limpar_cena()
    malha = R.importar_malha(ORIGEM)
    malha.name = "jimmy_malha"
    print("  decimada para %d tris" % R.decimar(malha, TRIS))
    pontos, _ = R.normalizar_escala(malha, ALTURA, dict(PONTOS))
    arm = R.criar_esqueleto("jimmy_rig", pontos)
    R.pesar(malha, arm, voxel=VOXEL * ALTURA / 1.9)
    saida = os.path.join(BLENDS, "jimmy", "jimmy.blend")
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    R.salvar(saida)
    print("== salvo", saida)


main()
