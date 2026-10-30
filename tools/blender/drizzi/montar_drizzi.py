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

Ela nao e' simetrica: o braco ESQUERDO e' do parasita (garra ate' o joelho,
espinhos), e ela nao tem pernas — o corpo termina num cacho de tentaculos que
pinga. As "pernas" do esqueleto ficam dentro desse cacho, so' pra o rig
seguir a lingua dos outros; nenhum clipe mexe nelas.

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

## Flutuando, do alto da cabeca a' ponta do tentaculo mais comprido.
ALTURA = 1.75
VOXEL = 0.014

PONTOS = {
    "hips": (0.0, 0.10, -0.22), "spine": (0.0, 0.12, -0.02),
    "chest": (0.02, 0.12, 0.18), "upper_chest": (0.03, 0.10, 0.36),
    "neck": (0.05, 0.05, 0.56), "head": (0.06, 0.02, 0.62),
    "head_top": (0.05, 0.02, 0.93),
    # o braco direito, humano, aberto em A
    "shoulder.R": (-0.12, 0.08, 0.47), "upper_arm.R": (-0.30, 0.08, 0.42),
    "forearm.R": (-0.54, 0.05, 0.15), "hand.R": (-0.74, 0.0, -0.10),
    "fingers_tip.R": (-0.84, -0.02, -0.22),
    "thumb.R": (-0.76, -0.05, -0.12), "thumb_tip.R": (-0.80, -0.09, -0.18),
    # o braco esquerdo, do parasita: pendurado, garra ate' embaixo
    "shoulder.L": (0.15, 0.08, 0.48), "upper_arm.L": (0.35, 0.10, 0.45),
    "forearm.L": (0.62, 0.08, 0.15), "hand.L": (0.70, 0.0, -0.38),
    "fingers_tip.L": (0.72, -0.05, -0.72),
    "thumb.L": (0.64, -0.05, -0.42), "thumb_tip.L": (0.58, -0.10, -0.60),
    # o cacho de tentaculos no lugar das pernas
    "thigh.L": (0.15, 0.05, -0.30), "shin.L": (0.15, 0.0, -0.55),
    "foot.L": (0.15, -0.02, -0.80), "toe.L": (0.15, -0.08, -0.85),
    "toe_tip.L": (0.15, -0.14, -0.88),
    "thigh.R": (-0.15, 0.05, -0.30), "shin.R": (-0.15, 0.0, -0.55),
    "foot.R": (-0.15, -0.02, -0.80), "toe.R": (-0.15, -0.08, -0.85),
    "toe_tip.R": (-0.15, -0.14, -0.88),
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
