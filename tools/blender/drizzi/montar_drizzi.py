# -*- coding: utf-8 -*-
"""Rig da Drizzi Wisny (a mãe do Jonny, do outro lado): malha + esqueleto +
pesos.

    blender -b --factory-startup -P tools/blender/drizzi/montar_drizzi.py

Le':   red-valve/assets/3d_model/enemies/cemiterio/Drizzi_Wisny.glb   (scan, sem rig)
Salva: Red-Valve-Blender/drizzi/drizzi.blend                          (fonte)

Mesmo caminho do Grizzolito e das malhas de scan da igreja
(`tools/blender/igreja_dona_nice/rig_lib.py`): o esqueleto sai de PONTOS
MEDIDOS e os pesos de um proxy de voxel. Os pontos foram medidos em render
ortografico com grade (frente e lado, coordenadas do .glb importado: Z pra
cima, frente no -Y, +X e' a ESQUERDA dela).

O scan trocado em 2026-11-03 e' a mesma Drizzi na mesma pose, mas noutra
escala: 1,90 de altura CENTRADA na origem (z de -0,952 a 0,949; o anterior ia
de 0 a 1,0). Os pontos foram levados pra ela (x1,901, z-0,952) e as pernas
remedidas por fatias da malha (ficaram mais abertas e ~5 cm pra tras).

Desde 2026-10-30 o `Drizzi_Wisny.glb` e' ela HUMANA (de avental, em pose A) — e' a que aparece na cutscene do hospital. A versao
tomada pelo parasita virou `Drizzi_Wisny_monster.glb`; o rig antigo dela
ficou em `Red-Valve-Blender/drizzi/drizzi_monstro.blend`.

As animacoes vem do `animar_drizzi.py` desta pasta, que abre o .blend salvo
aqui. RODAR DE NOVO SOBRESCREVE o .blend (e as acoes que estiverem nele).
"""

import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(AQUI), "igreja_dona_nice"))
import rig_lib as R  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
ORIGEM = os.path.join(RAIZ, "red-valve/assets/3d_model/enemies/cemiterio/Drizzi_Wisny.glb")
BLENDS = os.path.join(os.path.dirname(RAIZ), "Red-Valve-Blender")

## Do alto da cabeca a' sola do sapato.
ALTURA = 1.68
VOXEL = 0.014

PONTOS = {
    "hips": (0.0, -0.019, 0.056), "spine": (0.0, -0.019, 0.189),
    "chest": (0.0, -0.019, 0.341), "upper_chest": (0.0, -0.01, 0.474),
    "neck": (0.0, 0.0, 0.626), "head": (0.0, -0.01, 0.683),
    "head_top": (0.0, 0.0, 0.949),
    # bracos em A, os dois iguais
    "shoulder.R": (-0.057, 0.0, 0.569), "upper_arm.R": (-0.209, 0.0, 0.531),
    "forearm.R": (-0.374, -0.019, 0.289), "hand.R": (-0.547, -0.057, 0.078),
    "fingers_tip.R": (-0.593, -0.095, -0.013),
    "thumb.R": (-0.542, -0.114, 0.065), "thumb_tip.R": (-0.551, -0.152, 0.008),
    "shoulder.L": (0.057, 0.0, 0.569), "upper_arm.L": (0.209, 0.0, 0.531),
    "forearm.L": (0.374, -0.019, 0.289), "hand.L": (0.547, -0.057, 0.078),
    "fingers_tip.L": (0.593, -0.095, -0.013),
    "thumb.L": (0.542, -0.114, 0.065), "thumb_tip.L": (0.551, -0.152, 0.008),
    "thigh.L": (0.11, 0.03, -0.001), "shin.L": (0.133, 0.047, -0.496),
    "foot.L": (0.155, 0.05, -0.866), "toe.L": (0.16, -0.076, -0.923),
    "toe_tip.L": (0.16, -0.16, -0.933),
    "thigh.R": (-0.11, 0.03, -0.001), "shin.R": (-0.133, 0.047, -0.496),
    "foot.R": (-0.155, 0.05, -0.866), "toe.R": (-0.16, -0.076, -0.923),
    "toe_tip.R": (-0.16, -0.16, -0.933),
}


def main():
    R.limpar_cena()
    malha = R.importar_malha(ORIGEM)
    malha.name = "drizzi_malha"
    pontos, _ = R.normalizar_escala(malha, ALTURA, dict(PONTOS))
    arm = R.criar_esqueleto("drizzi_rig", pontos)
    R.pesar(malha, arm, voxel=VOXEL * ALTURA / 1.9)
    saida = os.path.join(BLENDS, "drizzi", "drizzi.blend")
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    R.salvar(saida)
    print("== salvo", saida)


main()
