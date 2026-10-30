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

Desde 2026-10-30 o `Drizzi_Wisny.glb` e' ela HUMANA (de avental, em pose A,
1,0 de altura no arquivo) — e' a que aparece na cutscene do hospital. A versao
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
    "hips": (0.0, -0.01, 0.53), "spine": (0.0, -0.01, 0.60),
    "chest": (0.0, -0.01, 0.68), "upper_chest": (0.0, -0.005, 0.75),
    "neck": (0.0, 0.0, 0.83), "head": (0.0, -0.005, 0.86),
    "head_top": (0.0, 0.0, 1.0),
    # bracos em A, os dois iguais
    "shoulder.R": (-0.03, 0.0, 0.80), "upper_arm.R": (-0.11, 0.0, 0.78),
    "forearm.R": (-0.197, -0.01, 0.653), "hand.R": (-0.288, -0.03, 0.542),
    "fingers_tip.R": (-0.312, -0.05, 0.494),
    "thumb.R": (-0.285, -0.06, 0.535), "thumb_tip.R": (-0.29, -0.08, 0.505),
    "shoulder.L": (0.03, 0.0, 0.80), "upper_arm.L": (0.11, 0.0, 0.78),
    "forearm.L": (0.197, -0.01, 0.653), "hand.L": (0.288, -0.03, 0.542),
    "fingers_tip.L": (0.312, -0.05, 0.494),
    "thumb.L": (0.285, -0.06, 0.535), "thumb_tip.L": (0.29, -0.08, 0.505),
    "thigh.L": (0.055, 0.0, 0.50), "shin.L": (0.06, 0.0, 0.24),
    "foot.L": (0.065, 0.025, 0.045), "toe.L": (0.065, -0.04, 0.015),
    "toe_tip.L": (0.065, -0.085, 0.01),
    "thigh.R": (-0.055, 0.0, 0.50), "shin.R": (-0.06, 0.0, 0.24),
    "foot.R": (-0.065, 0.025, 0.045), "toe.R": (-0.065, -0.04, 0.015),
    "toe_tip.R": (-0.065, -0.085, 0.01),
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
