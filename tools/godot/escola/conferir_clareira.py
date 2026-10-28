#!/usr/bin/env python3
"""A clareira da mata ainda cobre o lote da escola?

    python3 tools/godot/escola/conferir_clareira.py

A escola esta' na faixa de mata a leste da cidade. Pra nao nascer arvore dentro
dela, `tools/blender/citygen/lib/vegetation.py` tem um retangulo em CLAREIRAS
onde o espalhamento nao planta. Esse retangulo e' um numero escrito a mao: se
alguem arrastar a escola no editor, ele fica pra tras e as arvores voltam a
atravessar o telhado — sem erro nenhum, so' aparece andando por la'.

Isto compara os dois e, quando discordam, escreve a linha certa pra colar.
"""
import json
import math
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
CENA = os.path.join(RAIZ, "red-valve", "scenes", "stages", "stage_1",
                    "stage_1.tscn")
FORMA = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "stages",
                     "escola", "escola_mapa.json")
CITYGEN = os.path.join(RAIZ, "tools", "blender", "citygen")
sys.path.insert(0, CITYGEN)

import sem_bpy   # noqa: E402
sem_bpy.instalar()

from lib import layout   # noqa: E402
from lib.vegetation import CLAREIRAS   # noqa: E402

FOLGA = 2.0     # o tronco encostado na divisa ainda deita por cima do muro


def _transform(nome):
	txt = open(CENA, encoding="utf-8").read()
	bloco = re.search(r'^\[node name="%s"[^\]]*\](.*?)(?=^\[node |\Z)'
	                  % re.escape(nome), txt, re.M | re.S)
	if bloco is None:
		return None
	t = re.search(r"^transform = Transform3D\(([^)]*)\)", bloco.group(1), re.M)
	if t is None:
		return None
	v = [float(n) for n in t.group(1).split(",")]
	return v if len(v) == 12 else None


def lote_da_escola():
	"""(x0, z0, x1, z1) do lote em MUNDO LOCAL da cidade, ou None."""
	m = _transform("escola_exterior")
	forma = json.load(open(FORMA, encoding="utf-8"))
	if m is None or not forma.get("lote"):
		return None
	# Os 12 numeros sao as LINHAS da base e depois a origem.
	bxx, bxz, bzx, bzz = m[0], m[2], m[6], m[8]
	ox, oz = m[9], m[11]
	w = layout.load()["world"]
	xs, zs = [], []
	for (lx0, lz0, lx1, lz1) in forma["lote"]:
		for lx, lz in ((lx0, lz0), (lx1, lz0), (lx1, lz1), (lx0, lz1)):
			xs.append(ox + bxx * lx + bxz * lz - w["origin_x"])
			zs.append(oz + bzx * lx + bzz * lz - w["origin_z"])
	return (math.floor((min(xs) - FOLGA) * 10) / 10.0,
	        math.floor((min(zs) - FOLGA) * 10) / 10.0,
	        math.ceil((max(xs) + FOLGA) * 10) / 10.0,
	        math.ceil((max(zs) + FOLGA) * 10) / 10.0)


def main():
	lote = lote_da_escola()
	if lote is None:
		print("  a escola nao esta' na stage_1 — nada a conferir")
		return 0
	atual = [c for c in CLAREIRAS if c[0] == "escola"]
	x0, z0, x1, z1 = lote
	linha = '    ("escola", %.1f, %.1f, %.1f, %.1f),' % (x0, z0, x1, z1)
	if atual and all(abs(a - b) < 0.15 for a, b in
	                 zip(atual[0][1:], (x0, z0, x1, z1))):
		print("  clareira ok")
		return 0
	print("  ATENCAO: a clareira da mata NAO cobre mais o lote da escola.")
	print("  em lib/vegetation.py, CLAREIRAS deve ser:")
	print(linha)
	print("  depois: python3 tools/blender/citygen/refazer_scatter.py")
	print("     e    python3 tools/blender/citygen/podar_multimesh.py")
	return 1


if __name__ == "__main__":
	sys.exit(main())
