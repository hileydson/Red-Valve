#!/usr/bin/env python3
"""Assa a mata do sul e pendura os nos dela no `city.tscn`.

    python3 tools/blender/citygen/refazer_scatter.py     # 1. os pontos
    python3 tools/blender/citygen/assar_mata_sul.py      # 2. as MultiMesh

A faixa sul do terreno da stage_1 (Z do Godot 0 a 512, o comeco do prologo)
ficava sem mata nas laterais: o anel de `lib/vegetation.py` so' cobria a area
importada da cidade. `_mata_sul` planta essa faixa; este script assa SO' ela,
pelo mesmo motivo do `podar_multimesh.py`: o botao `construir` do
`City/Vegetation` reassaria as 14 mil plantas e mais de 300 .tres, e o
`ResourceSaver` dentro de um @tool ja' derrubou o editor neste projeto.

O assar em si e' do Godot (`red-valve/tools/godot/citybuild/assar_mata_sul.gd`,
headless, fora do editor). Aqui: roda ele, tira do `city.tscn` os nos `*_sul_*`
de uma rodada anterior e escreve os novos, filhos de `Vegetation`, com as
mesmas propriedades de LOD e sombra dos blocos que o botao gera.

Se um dia alguem apertar `construir`, a mata do sul entra junto (ela esta' no
`scatter.json`) — e os nos `*_sul_*` daqui tem de ser apagados, senao dobram.
"""
import os
import re
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
PROJETO = os.path.join(RAIZ, "red-valve")
CENA = os.path.join(PROJETO, "scenes", "stages", "city", "city.tscn")
GODOT = os.environ.get("GODOT", "/home/dev/Applications/Godot_v4.6.1-stable_linux.x86_64")
SCRIPT = "res://tools/godot/citybuild/assar_mata_sul.gd"
DIST_LOD = 340.0
MARGEM_LOD = 30.0


def assar():
	# SEM --headless: o renderer de mentira do headless nao guarda o buffer
	# do MultiMesh, e o .tres sai so' com instance_count (arvore nenhuma).
	r = subprocess.run([GODOT, "--path", PROJETO, "--resolution", "320x180", "--script", SCRIPT],
	                   capture_output=True, text=True)
	nos = []
	for linha in r.stdout.splitlines():
		if linha.startswith("NO|"):
			_, nome, caminho, cx, cy, cz, lod = linha.split("|")
			nos.append((nome, caminho, float(cx), float(cy), float(cz), lod == "1"))
		elif linha.startswith("TOTAL|"):
			print("  plantas:", linha.split("|")[1])
	if not nos:
		print(r.stdout[-2000:], r.stderr[-2000:])
		sys.exit("o Godot nao assou nada")
	# .tres de rodada anterior que nao saiu de novo (bloco que esvaziou)
	vivos = {os.path.basename(n[1]) for n in nos}
	pasta = os.path.join(PROJETO, "assets", "3d_model", "city", "multimesh")
	for f in os.listdir(pasta):
		if "_sul_" in f and f.endswith(".tres") and f not in vivos:
			os.remove(os.path.join(pasta, f))
	return nos


def escrever(nos):
	txt = open(CENA, encoding="utf-8").read()
	# rodada anterior: fora os nos e os ext_resources da mata sul
	txt = re.sub(r'\[node name="[^"]*_sul_[^"]*" type="MultiMeshInstance3D" parent="Vegetation"[^\]]*\]\n'
	             r'(?:(?!\[)[^\n]*\n)*\n?', "", txt)
	txt = re.sub(r'\[ext_resource type="MultiMesh" path="[^"]*_sul_[^"]*" id="[^"]+"\]\n', "", txt)

	exts, corpo = [], []
	for k, (nome, caminho, cx, cy, cz, lod) in enumerate(nos):
		ident = "sul_%d" % k
		exts.append('[ext_resource type="MultiMesh" path="%s" id="%s"]\n' % (caminho, ident))
		props = ['transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)'
		         % (_f(cx), _f(cy), _f(cz)), "cast_shadow = 0"]
		if lod:
			props += ["visibility_range_begin = %s" % _f(DIST_LOD),
			          "visibility_range_begin_margin = %s" % _f(MARGEM_LOD),
			          "visibility_range_fade_mode = 1"]
		elif not nome.startswith(("TREE_urban", "TREE_cypress")):
			props += ["visibility_range_end = %s" % _f(DIST_LOD),
			          "visibility_range_end_margin = %s" % _f(MARGEM_LOD),
			          "visibility_range_fade_mode = 1"]
		props.append('multimesh = ExtResource("%s")' % ident)
		corpo.append('[node name="%s" type="MultiMeshInstance3D" parent="Vegetation"]\n%s\n'
		             % (nome, "\n".join(props)))

	# ext_resources logo depois do ultimo existente; nos no fim do arquivo
	ultimo = list(re.finditer(r'^\[ext_resource [^\n]*\n', txt, re.M))[-1]
	txt = txt[:ultimo.end()] + "".join(exts) + txt[ultimo.end():]
	txt = txt.rstrip("\n") + "\n\n" + "\n".join(corpo)
	open(CENA, "w", encoding="utf-8").write(txt)
	print("  nos na cena:", len(nos))


def _f(v):
	s = ("%.6f" % v).rstrip("0").rstrip(".")
	return s if s not in ("-0", "") else "0"


if __name__ == "__main__":
	escrever(assar())
