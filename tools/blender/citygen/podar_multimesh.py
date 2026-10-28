#!/usr/bin/env python3
"""Tira das MultiMesh JA' ASSADAS tudo que caiu dentro de uma clareira.

    python3 tools/blender/citygen/podar_multimesh.py [--conferir]

`refazer_scatter.py` corrige o `scatter.json`, mas o jogo nao le esse arquivo:
le as MultiMesh de `assets/3d_model/city/multimesh/`, assadas uma vez pelo no
`City/Vegetation`. O caminho oficial pra elas mudarem e' apertar `construir`
naquele no — so' que isso reassa a floresta inteira (14 mil plantas, mais de
300 .tres) por causa de 30 arvores, e o `ResourceSaver` dentro de um @tool ja'
derrubou o editor neste projeto.

Este atalho faz a mesma poda direto no arquivo. As instancias que sobram ficam
na MESMA ordem e no MESMO ladrilho, entao o resultado e' o mesmo que o botao
produziria. `--conferir` so' conta, sem gravar.

ATENCAO a uma pegadinha: o buffer de cada .tres esta' em coordenada LOCAL do
no que o instancia, nao da cidade. Por isso e' preciso ler o `city.tscn` —
comparar o buffer cru com o retangulo da clareira da' resposta errada.
"""
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
CENA = os.path.join(RAIZ, "red-valve", "scenes", "stages", "city", "city.tscn")
sys.path.insert(0, AQUI)

import sem_bpy   # noqa: E402
sem_bpy.instalar()

# A lista mora em `lib/vegetation.py` pra os dois caminhos — reassar no Blender
# e podar aqui — nao poderem discordar.
from lib.vegetation import CLAREIRAS   # noqa: E402


def _dentro(x, z):
	for _tag, x0, z0, x1, z1 in CLAREIRAS:
		if x0 <= x <= x1 and z0 <= z <= z1:
			return True
	return False


def ladrilhos():
	"""(caminho do .tres, origem do no) de cada MultiMesh da vegetacao."""
	txt = open(CENA, encoding="utf-8").read()
	ids = {}
	for caminho, ident in re.findall(
			r'\[ext_resource type="MultiMesh"[^\]]*path="([^"]+)" id="([^"]+)"\]',
			txt):
		ids[ident] = caminho
	saida = []
	for no in re.finditer(
			r'^\[node name="[^"]+" type="MultiMeshInstance3D" parent="([^"]*)"'
			r'[^\]]*\](.*?)(?=^\[node |\Z)', txt, re.M | re.S):
		pai, corpo = no.groups()
		if "Vegetation" not in pai:
			continue
		mm = re.search(r'multimesh = ExtResource\("([^"]+)"\)', corpo)
		tr = re.search(r'^transform = Transform3D\(([^)]*)\)', corpo, re.M)
		if mm is None or mm.group(1) not in ids:
			continue
		v = [float(n) for n in tr.group(1).split(",")] if tr else [0.0] * 12
		saida.append((ids[mm.group(1)].replace("res://", ""), v[9], v[11]))
	return saida


def podar(rel, ox, oz, gravar):
	caminho = os.path.join(RAIZ, "red-valve", rel)
	txt = open(caminho, encoding="utf-8").read()
	b = re.search(r"buffer = PackedFloat32Array\(([^)]*)\)", txt, re.S)
	if b is None:
		return 0
	v = [x.strip() for x in b.group(1).split(",") if x.strip()]
	# transform_format = 1 (3D): 12 floats por instancia, a origem em 3, 7 e 11.
	fica, tirou = [], 0
	for k in range(0, len(v), 12):
		o = v[k:k + 12]
		if len(o) < 12:
			break
		if _dentro(float(o[3]) + ox, float(o[11]) + oz):
			tirou += 1
			continue
		fica.extend(o)
	if not tirou or not gravar:
		return tirou
	txt = re.sub(r"instance_count = \d+",
	             "instance_count = %d" % (len(fica) // 12), txt, count=1)
	txt = (txt[:b.start()] + "buffer = PackedFloat32Array(%s)" % ", ".join(fica)
	       + txt[b.end():])
	open(caminho, "w", encoding="utf-8").write(txt)
	return tirou


def main():
	gravar = "--conferir" not in sys.argv
	for tag, x0, z0, x1, z1 in CLAREIRAS:
		print("  clareira %-10s x %.1f..%.1f  z %.1f..%.1f"
		      % (tag, x0, x1, z0, z1))
	total = 0
	for rel, ox, oz in ladrilhos():
		n = podar(rel, ox, oz, gravar)
		if n:
			print("  %-40s -%d" % (os.path.basename(rel), n))
			total += n
	print("  %d instancias %s" % (total, "podadas" if gravar else "a podar"))


if __name__ == "__main__":
	main()
