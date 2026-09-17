#!/usr/bin/env python3
"""Reescreve `scatter.json` sem abrir o Blender.

    python3 tools/blender/citygen/refazer_scatter.py

Serve pra uma coisa so': mexer nas CLAREIRAS de `lib/vegetation.py` e ver o
resultado sem rodar a cidade inteira. O espalhamento e' Python puro — nao toca
em `bpy` —, entao basta um `bpy` de mentira pra o `import` do modulo passar.

Ele reproduz o arquivo EXATO que o Blender escreveria: mesma semente (90210) e
mesma ordem de sorteio. Se as clareiras estiverem vazias, o arquivo sai
identico byte a byte ao que estava la'.

Depois disto, as arvores no jogo ainda sao as VELHAS: os MultiMesh estao assados
em `assets/3d_model/city/multimesh/`. Pra elas mudarem, e' preciso apertar
`construir` no no `City/07_VEGETATION` dentro do editor.
"""
import json
import os
import random
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
sys.path.insert(0, AQUI)

import sem_bpy   # noqa: E402
sem_bpy.instalar()

from lib import layout, schematic, terrain, vegetation   # noqa: E402

DESTINOS = [
	os.path.join(AQUI, "out", "scatter.json"),
	os.path.join(RAIZ, "red-valve", "assets", "3d_model", "city",
	             "scatter.json"),
]
NOTA = ("posicoes LOCAIS da cidade (x, y, z, rot_y, escala); "
        "o no City aplica o deslocamento para o mundo")


def main():
	h, _ = terrain.build_heightfield()
	hs = schematic.Height(h, layout.load()["world"])
	pts = vegetation.scatter(hs, random.Random(90210))
	for tag, x0, z0, x1, z1 in vegetation.CLAREIRAS:
		print("  clareira %-10s x %.1f..%.1f  z %.1f..%.1f"
		      % (tag, x0, x1, z0, z1))
	for k in sorted(pts):
		print("  %-20s %5d" % (k, len(pts[k])))
	print("  total %d" % sum(len(v) for v in pts.values()))
	for caminho in DESTINOS:
		with open(caminho, "w", encoding="utf-8") as fh:
			json.dump({"nota": NOTA, "especies": pts}, fh)
		print("  gravado:", caminho)


if __name__ == "__main__":
	main()
