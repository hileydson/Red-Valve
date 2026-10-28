# -*- coding: utf-8 -*-
"""Rig das malhas de scan da cena da igreja: malha + esqueleto + pesos.

    blender -b --factory-startup -P tools/blender/igreja_dona_nice/montar_personagem.py -- <nome>

<nome>: jonny | dona_nice_monster | dona_nice_monster_fase_2

Le':   red-valve/assets/3d_model/npc/<nome>.glb   (scan, sem rig)
Salva: Red-Valve-Blender/<nome>/<nome>.blend     (fonte, editavel no Blender)

So' monta. As animacoes vem do `animar_cena_igreja.py`, que abre este .blend.
RODAR DE NOVO SOBRESCREVE o .blend (e as acoes que estiverem nele).

Os PONTOS foram medidos no .glb importado (Z cima, frente -Y, +X = esquerda
do personagem), com fatias da malha e render ortografico com grade — ver
rig_lib. A monstro fase 1 e' um pouco torta (o corpo pende pro +X), por isso
os dois lados dela sao escritos a mao e nao espelhados.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_lib as R  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
NPC = os.path.join(RAIZ, "red-valve/assets/3d_model/npc")
BLENDS = os.path.join(os.path.dirname(RAIZ), "Red-Valve-Blender")

PERSONAGENS = {
    # Um menino de uns oito anos: a meia cabeca do peito do Maycow, que e' o
    # que faz ele caber no colo na corrida pro hospital.
    "jonny": {
        "altura": 1.28, "voxel": 0.008, "tris": None,
        "pontos": R.espelhar({
            "hips": (0.0, 0.03, -0.14), "spine": (0.0, 0.03, -0.02),
            "chest": (0.0, 0.02, 0.14), "upper_chest": (0.0, 0.03, 0.30),
            "neck": (0.0, 0.04, 0.52), "head": (0.0, 0.03, 0.60),
            "head_top": (0.0, 0.02, 0.95),
            "shoulder.L": (0.03, 0.04, 0.48), "upper_arm.L": (0.22, 0.05, 0.42),
            "forearm.L": (0.40, 0.05, 0.22), "hand.L": (0.535, 0.02, 0.07),
            "fingers_tip.L": (0.63, -0.01, -0.03),
            "thumb.L": (0.52, -0.02, 0.05), "thumb_tip.L": (0.55, -0.07, -0.01),
            "thigh.L": (0.09, 0.03, -0.14), "shin.L": (0.11, 0.04, -0.53),
            "foot.L": (0.12, 0.06, -0.86), "toe.L": (0.12, -0.08, -0.925),
            "toe_tip.L": (0.12, -0.17, -0.93),
        }),
    },
    # A Dona Nice depois de possuida: mais alta que ela (1,58 m) porque o
    # corpo estica na transformacao — e' isso que a cena mostra.
    "dona_nice_monster": {
        "altura": 1.82, "voxel": 0.022, "tris": None,
        "pontos": {
            "hips": (0.04, 0.06, -0.08), "spine": (0.04, 0.07, 0.08),
            "chest": (0.04, 0.08, 0.25), "upper_chest": (0.04, 0.09, 0.43),
            "neck": (0.04, 0.08, 0.62), "head": (0.05, 0.05, 0.70),
            "head_top": (0.06, 0.02, 0.95),
            "shoulder.L": (0.08, 0.09, 0.58), "upper_arm.L": (0.24, 0.09, 0.55),
            "forearm.L": (0.40, 0.06, 0.33), "hand.L": (0.52, -0.05, 0.12),
            "fingers_tip.L": (0.58, -0.18, -0.15),
            "thumb.L": (0.50, -0.10, 0.08), "thumb_tip.L": (0.50, -0.17, 0.0),
            "shoulder.R": (0.0, 0.09, 0.58), "upper_arm.R": (-0.20, 0.09, 0.55),
            "forearm.R": (-0.35, 0.06, 0.33), "hand.R": (-0.47, -0.05, 0.14),
            "fingers_tip.R": (-0.55, -0.18, -0.15),
            "thumb.R": (-0.44, -0.10, 0.10), "thumb_tip.R": (-0.45, -0.17, 0.02),
            "thigh.L": (0.16, 0.06, -0.08), "shin.L": (0.20, 0.05, -0.50),
            "foot.L": (0.20, 0.08, -0.85), "toe.L": (0.20, -0.04, -0.92),
            "toe_tip.L": (0.20, -0.14, -0.94),
            "thigh.R": (-0.07, 0.06, -0.08), "shin.R": (-0.11, 0.05, -0.48),
            "foot.R": (-0.11, 0.08, -0.85), "toe.R": (-0.11, -0.04, -0.92),
            "toe_tip.R": (-0.11, -0.14, -0.94),
        },
    },
    # A segunda forma: tronco, bracos enormes e tentaculos, sem perna. "Fica
    # tao grande" — 5 m da ponta do tentaculo ao alto da cabeca. As pernas do
    # esqueleto existem (a hierarquia e' a mesma dos outros) mas ficam
    # encolhidas dentro do quadril e nao pegam peso nenhum.
    "dona_nice_monster_fase_2": {
        "altura": 5.0, "voxel": 0.010, "tris": 70000,
        "pontos": {
            "hips": (0.02, 0.12, -0.25), "spine": (0.02, 0.13, -0.05),
            "chest": (0.02, 0.15, 0.15), "upper_chest": (0.03, 0.15, 0.35),
            "neck": (0.04, 0.10, 0.55), "head": (0.05, 0.05, 0.62),
            "head_top": (0.06, 0.0, 0.92),
            "shoulder.L": (0.08, 0.15, 0.48), "upper_arm.L": (0.33, 0.17, 0.42),
            "forearm.L": (0.62, 0.02, 0.05), "hand.L": (0.78, -0.22, -0.30),
            "fingers_tip.L": (0.86, -0.48, -0.60),
            "thumb.L": (0.72, -0.30, -0.32), "thumb_tip.L": (0.70, -0.42, -0.45),
            "shoulder.R": (-0.02, 0.15, 0.48), "upper_arm.R": (-0.30, 0.17, 0.40),
            "forearm.R": (-0.58, 0.02, 0.05), "hand.R": (-0.75, -0.22, -0.28),
            "fingers_tip.R": (-0.85, -0.48, -0.62),
            "thumb.R": (-0.69, -0.30, -0.30), "thumb_tip.R": (-0.67, -0.42, -0.44),
            "thigh.L": (0.08, 0.12, -0.25), "shin.L": (0.08, 0.12, -0.27),
            "foot.L": (0.08, 0.12, -0.29), "toe.L": (0.08, 0.10, -0.30),
            "toe_tip.L": (0.08, 0.08, -0.30),
            "thigh.R": (-0.04, 0.12, -0.25), "shin.R": (-0.04, 0.12, -0.27),
            "foot.R": (-0.04, 0.12, -0.29), "toe.R": (-0.04, 0.10, -0.30),
            "toe_tip.R": (-0.04, 0.08, -0.30),
        },
        # seis tentaculos pendurados do fundo do tronco, tres ossos cada
        "tentaculos": [(-0.17, 0.05), (-0.05, 0.0), (0.08, 0.02), (0.20, 0.08),
                       (-0.08, 0.22), (0.10, 0.22)],
        "sem_peso": ["thigh", "shin", "foot", "toe"],
    },
}


def main():
    nome = sys.argv[sys.argv.index("--") + 1]
    cfg = PERSONAGENS[nome]
    R.limpar_cena()
    malha = R.importar_malha(os.path.join(NPC, nome + ".glb"))
    malha.name = nome + "_malha"
    if cfg["tris"]:
        print("  decimada para %d tris" % R.decimar(malha, cfg["tris"]))
    pontos = dict(cfg["pontos"])
    for i, (x, y) in enumerate(cfg.get("tentaculos", [])):
        pontos["tentaculo_%d" % (i + 1)] = [(x, y, z) for z in (-0.28, -0.48, -0.68, -0.90)]
    pontos, _ = R.normalizar_escala(malha, cfg["altura"], pontos)
    extras = [("tentaculo_%d" % (i + 1), "hips", pontos["tentaculo_%d" % (i + 1)])
              for i in range(len(cfg.get("tentaculos", [])))]
    arm = R.criar_esqueleto(nome + "_rig", pontos, extras)
    for b in arm.data.bones:
        if any(b.name.startswith(p + ".") for p in cfg.get("sem_peso", [])):
            b.use_deform = False
    R.pesar(malha, arm, voxel=cfg["voxel"] * cfg["altura"] / 1.9)
    saida = os.path.join(BLENDS, nome, nome + ".blend")
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    R.salvar(saida)
    print("== salvo", saida)


main()
