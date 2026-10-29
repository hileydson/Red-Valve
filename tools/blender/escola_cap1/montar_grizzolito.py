# -*- coding: utf-8 -*-
"""Rig do Grizzolito Marolis (o integrante dos Anti-Lopes do Capitulo 1) e
das duas formas de monstro dele: malha + esqueleto + pesos.

    blender -b --factory-startup -P tools/blender/escola_cap1/montar_grizzolito.py -- <nome>

<nome>: grizzolito | grizzolito_monstro_1 | grizzolito_monstro_2

Le':   red-valve/assets/3d_model/enemies/anti_lopes_members/<arquivo>.glb  (scan, sem rig)
Salva: Red-Valve-Blender/grizzolito/<nome>.blend                           (fonte)

Mesmo caminho das malhas de scan da igreja (`tools/blender/igreja_dona_nice/`):
o esqueleto sai de PONTOS MEDIDOS e os pesos de um proxy de voxel — ver
`rig_lib.py` la'. Os pontos foram medidos em render ortografico com grade
(frente e lado, coordenadas do .glb importado: Z pra cima, frente no -Y, +X e'
a ESQUERDA do personagem).

O humano esta' em pose T. As duas formas de monstro estao curvadas, com o
braco esquerdo (o do parasita) enorme e pendurado ate' o joelho, e as pernas
abertas — por isso os dois lados sao escritos a mao, sem espelhar.

As animacoes vem do `animar.py` desta pasta, que abre o .blend salvo aqui.
RODAR DE NOVO SOBRESCREVE o .blend (e as acoes que estiverem nele).
"""

import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(AQUI), "igreja_dona_nice"))
import rig_lib as R  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
MEMBROS = os.path.join(RAIZ, "red-valve/assets/3d_model/enemies/anti_lopes_members")
BLENDS = os.path.join(os.path.dirname(RAIZ), "Red-Valve-Blender")

PERSONAGENS = {
    # O homem de terno: 1,82 m, pose T.
    "grizzolito": {
        "arquivo": "Integrante_Grizzolito_Marolis.glb",
        "altura": 1.82, "voxel": 0.012, "tris": None,
        "pontos": R.espelhar({
            "hips": (0.0, 0.05, 0.02), "spine": (0.0, 0.05, 0.15),
            "chest": (0.0, 0.05, 0.30), "upper_chest": (0.0, 0.06, 0.44),
            "neck": (0.0, 0.07, 0.60), "head": (0.0, 0.06, 0.67),
            "head_top": (0.0, 0.04, 0.94),
            "shoulder.L": (0.04, 0.07, 0.55), "upper_arm.L": (0.19, 0.08, 0.53),
            "forearm.L": (0.40, 0.08, 0.525), "hand.L": (0.60, 0.07, 0.52),
            "fingers_tip.L": (0.77, 0.06, 0.515),
            "thumb.L": (0.62, 0.02, 0.51), "thumb_tip.L": (0.67, -0.02, 0.50),
            "thigh.L": (0.10, 0.05, 0.0), "shin.L": (0.13, 0.06, -0.46),
            "foot.L": (0.17, 0.10, -0.87), "toe.L": (0.18, -0.07, -0.925),
            "toe_tip.L": (0.19, -0.18, -0.94),
        }),
    },
    # Primeira forma: o parasita tomou o lado esquerdo (garra ate' o joelho,
    # espinhos nas costas). 2,30 m.
    "grizzolito_monstro_1": {
        "arquivo": "Integrante_Grizzolito_Marolis_Monster_1.glb",
        "altura": 2.30, "voxel": 0.016, "tris": 60000,
        "pontos": {
            "hips": (-0.02, 0.15, 0.05), "spine": (-0.02, 0.12, 0.20),
            "chest": (-0.03, 0.08, 0.34), "upper_chest": (-0.04, 0.04, 0.48),
            "neck": (-0.05, -0.02, 0.62), "head": (-0.06, -0.06, 0.68),
            "head_top": (-0.07, -0.12, 0.90),
            "shoulder.R": (-0.08, 0.06, 0.55), "upper_arm.R": (-0.32, 0.10, 0.54),
            "forearm.R": (-0.48, 0.14, 0.25), "hand.R": (-0.54, 0.16, 0.03),
            "fingers_tip.R": (-0.58, 0.12, -0.20),
            "thumb.R": (-0.50, 0.10, 0.0), "thumb_tip.R": (-0.47, 0.06, -0.08),
            "shoulder.L": (0.04, 0.06, 0.55), "upper_arm.L": (0.28, 0.06, 0.53),
            "forearm.L": (0.44, -0.02, 0.20), "hand.L": (0.40, -0.12, -0.12),
            "fingers_tip.L": (0.36, -0.28, -0.50),
            "thumb.L": (0.32, -0.15, -0.15), "thumb_tip.L": (0.27, -0.22, -0.28),
            "thigh.R": (-0.12, 0.18, 0.02), "shin.R": (-0.33, 0.18, -0.40),
            "foot.R": (-0.40, 0.18, -0.84), "toe.R": (-0.42, -0.02, -0.92),
            "toe_tip.R": (-0.43, -0.12, -0.94),
            "thigh.L": (0.08, 0.18, 0.02), "shin.L": (0.12, 0.18, -0.40),
            "foot.L": (0.20, 0.18, -0.84), "toe.L": (0.22, -0.02, -0.92),
            "toe_tip.L": (0.23, -0.12, -0.94),
        },
    },
    # Segunda forma: o rosto ja' e' do parasita, a perna direita virou osso e
    # o braco direito e' um toco. 2,50 m.
    "grizzolito_monstro_2": {
        "arquivo": "Integrante_Grizzolito_Marolis_Monster_2.glb",
        "altura": 2.50, "voxel": 0.016, "tris": 60000,
        "pontos": {
            "hips": (-0.03, 0.17, 0.05), "spine": (-0.03, 0.13, 0.20),
            "chest": (-0.04, 0.08, 0.34), "upper_chest": (-0.05, 0.02, 0.46),
            "neck": (-0.07, -0.08, 0.58), "head": (-0.08, -0.14, 0.64),
            "head_top": (-0.09, -0.24, 0.84),
            "shoulder.R": (-0.09, 0.05, 0.52), "upper_arm.R": (-0.33, 0.06, 0.52),
            "forearm.R": (-0.40, 0.10, 0.26), "hand.R": (-0.30, 0.08, -0.20),
            "fingers_tip.R": (-0.26, 0.04, -0.38),
            "thumb.R": (-0.28, 0.02, -0.22), "thumb_tip.R": (-0.25, -0.02, -0.30),
            "shoulder.L": (0.03, 0.05, 0.50), "upper_arm.L": (0.26, 0.04, 0.47),
            "forearm.L": (0.40, -0.04, 0.16), "hand.L": (0.38, -0.12, -0.20),
            "fingers_tip.L": (0.34, -0.28, -0.52),
            "thumb.L": (0.31, -0.16, -0.22), "thumb_tip.L": (0.27, -0.22, -0.34),
            "thigh.R": (-0.13, 0.18, 0.02), "shin.R": (-0.35, 0.20, -0.38),
            "foot.R": (-0.42, 0.20, -0.84), "toe.R": (-0.43, -0.02, -0.92),
            "toe_tip.R": (-0.44, -0.14, -0.94),
            "thigh.L": (0.08, 0.18, 0.02), "shin.L": (0.12, 0.20, -0.38),
            "foot.L": (0.20, 0.20, -0.84), "toe.L": (0.21, -0.02, -0.92),
            "toe_tip.L": (0.22, -0.14, -0.94),
        },
    },
}


def main():
    nome = sys.argv[sys.argv.index("--") + 1]
    cfg = PERSONAGENS[nome]
    R.limpar_cena()
    malha = R.importar_malha(os.path.join(MEMBROS, cfg["arquivo"]))
    malha.name = nome + "_malha"
    if cfg["tris"]:
        print("  decimada para %d tris" % R.decimar(malha, cfg["tris"]))
    pontos, _ = R.normalizar_escala(malha, cfg["altura"], dict(cfg["pontos"]))
    arm = R.criar_esqueleto(nome + "_rig", pontos)
    R.pesar(malha, arm, voxel=cfg["voxel"] * cfg["altura"] / 1.9)
    saida = os.path.join(BLENDS, "grizzolito", nome + ".blend")
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    R.salvar(saida)
    print("== salvo", saida)


main()
