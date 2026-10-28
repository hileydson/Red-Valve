"""`bpy` de mentira, pra importar os modulos de `lib/` fora do Blender.

Metade de `lib/` e' conta pura — o espalhamento da vegetacao, o campo de
altura, o traçado das vias — mas todo modulo de la' passa por `util`, que
importa `bpy` na primeira linha. Sem isto, qualquer ferramenta de linha de
comando que queira reaproveitar essa conta precisa abrir o Blender inteiro.

So' vale pra LER a conta. Qualquer coisa que de fato mexa na cena (`bpy.ops`,
`bpy.data`) estoura aqui, e e' pra estourar mesmo.
"""
import sys
import types


def instalar():
	for nome in ("bpy", "bpy.types", "bpy.utils", "bpy.props", "mathutils",
	             "bmesh"):
		if nome not in sys.modules:
			sys.modules[nome] = types.ModuleType(nome)
	bpy = sys.modules["bpy"]
	bpy.types = sys.modules["bpy.types"]
	bpy.utils = sys.modules["bpy.utils"]
	bpy.props = sys.modules["bpy.props"]
	bpy.data = None
	bpy.ops = None
	bpy.context = None
