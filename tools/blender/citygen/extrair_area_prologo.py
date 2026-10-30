#!/usr/bin/env python3
"""Tira da stage_1 o que NAO pode virar mata no meio da faixa sul.

    python3 tools/blender/citygen/extrair_area_prologo.py

Grava `city_data/area_prologo.json`, que `lib/vegetation.py` (`_mata_meio`) le:

  triangulos  o navmesh da stage_1 (so' existe na faixa sul: e' o chao do
              prologo), em XZ de MUNDO do Godot
  circulos    [x, z, raio] do que esta' em pe' ali: a casa do Maycow, os postes,
              os pinheiros grandes de `Greens` (a mata nova fica EM VOLTA deles)
  retangulos  [x0, z0, x1, z1]: a faixa de grama do caminho

Rodar de novo se o navmesh ou essas pecas mudarem na stage_1; depois
`refazer_scatter.py` e `assar_mata_sul.py`.
"""
import json
import os
import re

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
CENA = os.path.join(RAIZ, "red-valve", "scenes", "stages", "stage_1", "stage_1.tscn")
SAIDA = os.path.join(AQUI, "city_data", "area_prologo.json")

# folga em volta de cada coisa, em metros
RAIO_CASA = 24.0
RAIO_POSTE = 7.0
RAIO_PINHEIRO = 5.0


def _origem(corpo):
	m = re.search(r"transform = Transform3D\(([^)]*)\)", corpo)
	if not m:
		return None
	n = [float(v) for v in m.group(1).split(",")]
	return n[9], n[10], n[11]


def _nos(txt, pai):
	"""(nome, corpo) dos filhos diretos de `pai`."""
	return re.findall(r'^\[node name="([^"]+)"[^\]]*parent="%s"[^\]]*\]\n(.*?)(?=^\[)' % re.escape(pai),
	                  txt, re.M | re.S)


def main():
	txt = open(CENA, encoding="utf-8").read()

	i = txt.index('[sub_resource type="NavigationMesh"')
	bloco = txt[i:txt.index("\n[", i + 5)]
	nums = [float(v) for v in re.search(r"vertices = PackedVector3Array\(([^)]*)\)", bloco).group(1).split(",")]
	vs = [(nums[k], nums[k + 2]) for k in range(0, len(nums), 3)]
	tris = []
	for p in re.findall(r"PackedInt32Array\(([^)]*)\)", bloco):
		idx = [int(v) for v in p.split(",")]
		for k in range(1, len(idx) - 1):   # leque
			a, b, c = vs[idx[0]], vs[idx[k]], vs[idx[k + 1]]
			tris.append([round(a[0], 2), round(a[1], 2), round(b[0], 2), round(b[1], 2),
			             round(c[0], 2), round(c[1], 2)])

	circulos = []
	for nome, corpo in _nos(txt, "objects"):
		o = _origem(corpo)
		if o and o[2] > 0 and nome.startswith("street_lamp"):
			circulos.append([round(o[0], 2), round(o[2], 2), RAIO_POSTE])
	casa = [o for o in (_origem(c) for _n, c in _nos(txt, "casa")) if o and o[2] > 0]
	if casa:
		cx = sum(o[0] for o in casa) / len(casa)
		cz = sum(o[2] for o in casa) / len(casa)
		circulos.append([round(cx, 2), round(cz, 2), RAIO_CASA])
	retangulos = []
	grama = []
	for nome, corpo in _nos(txt, "Greens"):
		o = _origem(corpo)
		if not o or o[2] <= 0:
			continue
		if nome.startswith("Grass"):
			grama.append(o)
		else:
			circulos.append([round(o[0], 2), round(o[2], 2), RAIO_PINHEIRO])
	if grama:
		# cada Grass e' um ladrilho de ~20 m de grama em volta da origem
		retangulos.append([min(o[0] for o in grama) - 14.0, min(o[2] for o in grama) - 14.0,
		                   max(o[0] for o in grama) + 14.0, max(o[2] for o in grama) + 14.0])

	json.dump({"nota": "XZ de mundo da stage_1; gerado por extrair_area_prologo.py",
	           "triangulos": tris, "circulos": circulos, "retangulos": retangulos},
	          open(SAIDA, "w", encoding="utf-8"))
	print("  triangulos %d  circulos %d  retangulos %d -> %s"
	      % (len(tris), len(circulos), len(retangulos), SAIDA))


if __name__ == "__main__":
	main()
