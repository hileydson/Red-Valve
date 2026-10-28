"""Enxerta no Maycow normal um morph target de MAO FECHADA.

    python3 tools/modelos/gerar_punho_maycow.py

O rig do Maycow normal tem 24 ossos e a mao e' UM SO' (ver o cabecalho de
`player_gun_hold.gd`): os dedos existem na carne, mas nao no esqueleto, entao
nenhum osso novo no Godot fecha essa mao — peso de malha nao se cria por codigo
no motor.

O que se cria por codigo e' MORPH TARGET. Este script abre o .glb, dobra os
vertices dos dedos em torno das tres juntas e grava o resultado como um alvo de
deformacao (`punho_d` e `punho_e`, um por mao). No Godot isso vira um
`blend_shapes/punho_d` de 0 a 1 — quem liga e desliga e' o `player_gun_hold.gd`.

POR QUE ASSIM, E NAO NO BLENDER:
- nao existe .blend fonte deste rig (so' o .glb), entao qualquer ida ao Blender
  e' um round-trip que poe em risco as 6 animacoes e os indices de osso que o
  `player.tscn` referencia por numero (`bones/13/rotation`);
- morph target e' so' um par de accessors a mais no arquivo: osso, animacao,
  pele e UV saem daqui byte a byte como entraram.

E' IDEMPOTENTE: rodar de novo apaga os alvos antigos e escreve os novos. O
backup e' o proprio git (o .glb e' versionado).

A DOBRA. Em espaco do osso da mao (centimetros): +Y aponta pras pontas dos
dedos, X e' a normal da palma e Z e' a largura. O script descobre sozinho de que
lado esta' a palma (o polegar e' o grupo mais CURTO dos dois extremos de Z, e ele
pende pro lado da palma) — e' o que faz a mesma conta servir pras duas maos.

Dedo nao e' arame: ele nao curva parelho, ele quebra em tres juntas. Entao a
curvatura e' concentrada em tres sinos (MCP, PIP, DIP) e a linha do dedo sai da
INTEGRAL dessa curvatura. Curvar parelho, que foi a primeira tentativa, da' uma
garra: com 180 graus a ponta para seis centimetros ACIMA da palma, porque meia
volta de um dedo de 9,5 cm e' um semicirculo de 6 cm de diametro.
"""

import json
import math
import os
import struct
import sys

import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
MODELO = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "player",
	"Maycow Lopes", "maycow_normal", "maycow_normal_rigged.glb")

## Onde comecam os dedos, em fracao do comprimento da mao (0 = pulso). Medido:
## a ponta do polegar para em 9,7 de 17,4 cm, que e' justamente a linha dos nos.
NO_DOS_DEDOS = 0.56
## Juntas, em centimetros a partir do no' — e quanto cada uma dobra (graus).
## Com estes, a ponta do dedo para a 3,8 cm do lado da palma: fora dela, em cima
## do cabo. Somar mais graus enfia a ponta pra dentro da propria mao.
JUNTAS = [(0.0, 72.0), (3.4, 82.0), (5.9, 42.0)]
## Largura do sino de cada junta (cm). Menor = vinco mais duro.
LARGURA_JUNTA = 0.9
## O polegar nao dobra: ele GIRA inteiro, na base, por cima dos dedos. Dobrar
## um dedo de 5 cm com 40 vertices so' rasga. Graus em Z (pra palma) e em X
## (pra frente dos dedos).
POLEGAR_PALMA = 26.0
POLEGAR_FRENTE = 32.0
## Ate' onde vai o polegar (cm em Z a partir da ponta dele) e a faixa em que a
## carne volta a ser palma.
POLEGAR_RAIO = 3.0
POLEGAR_FAIXA = 2.0

TIPOS = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
COMPS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def abrir(caminho):
	dados = open(caminho, "rb").read()
	off, js, binoff, binlen = 12, None, None, 0
	while off < len(dados):
		ln, tp = struct.unpack_from("<II", dados, off)
		if tp == 0x4E4F534A:
			js = json.loads(dados[off + 8:off + 8 + ln])
		else:
			binoff, binlen = off + 8, ln
		off += 8 + ln
	return dados, js, binoff, binlen


def ler(dados, js, binoff, i):
	a = js["accessors"][i]
	bv = js["bufferViews"][a["bufferView"]]
	n = COMPS[a["type"]]
	crua = np.frombuffer(dados, dtype=np.dtype(TIPOS[a["componentType"]]),
		count=a["count"] * n,
		offset=binoff + bv.get("byteOffset", 0) + a.get("byteOffset", 0))
	return crua.reshape(a["count"], n).astype(np.float64)


def suave(x):
	"""smoothstep de 0 a 1."""
	x = np.clip(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


def perfil(y, juntas, largura):
	"""Angulo acumulado ao longo do dedo: soma dos sinos de cada junta."""
	ang = np.zeros_like(y)
	for pos, graus in juntas:
		ang += math.radians(graus) * suave((y - pos) / largura + 0.5)
	return ang


def dobrar(loc, y0, juntas, lado):
	"""Dobra a carne acima de y0 seguindo a curvatura das juntas.

	A linha do dedo e' a integral do angulo: cada fatia de dy anda na direcao
	que o angulo acumulado aponta. O vertice acompanha essa linha e gira junto,
	o que serve tambem pra girar a NORMAL dele.
	"""
	passo = 0.05
	topo = max(loc[:, 1].max() - y0, 0.1) + passo
	s = np.arange(0.0, topo, passo)
	ang = perfil(s, juntas, LARGURA_JUNTA)
	# integral: x anda com sen(angulo) pro lado da palma, y com cos
	cx = np.concatenate([[0.0], np.cumsum(np.sin(ang[:-1]) * passo)])
	cy = np.concatenate([[0.0], np.cumsum(np.cos(ang[:-1]) * passo)])

	fora = loc[:, 1] - y0
	dentro = np.clip(fora, 0.0, s[-1])
	th = np.interp(dentro, s, ang)
	linha_x = np.interp(dentro, s, cx)
	linha_y = np.interp(dentro, s, cy)

	novo = loc.copy()
	u = loc[:, 0]
	# o vertice fica a` mesma distancia da linha, no eixo ja' girado
	novo[:, 0] = lado * linha_x + u * np.cos(th)
	novo[:, 1] = y0 + linha_y - lado * u * np.sin(th)
	# quem esta' abaixo do no' nao se mexe
	parado = fora <= 0.0
	novo[parado] = loc[parado]
	return novo, np.where(parado, 0.0, th)


def girar_polegar(loc, nor, z_polegar, sinal_z, lado):
	"""Gira o polegar inteiro na base, por cima dos dedos.

	O peso cai com a distancia em Z a` ponta do polegar, entao a carne da palma
	fica parada e a membrana entre polegar e indicador acompanha de leve — sem
	corte duro, que era o que rasgava.
	"""
	dist = np.abs(loc[:, 2] - z_polegar)
	peso = 1.0 - suave((dist - POLEGAR_RAIO) / POLEGAR_FAIXA)
	if peso.max() <= 0.0:
		return loc, nor
	dedo = peso > 0.01
	base = loc[dedo & (loc[:, 1] < loc[dedo, 1].min() + 1.5)].mean(0)

	saida, nsaida = loc.copy(), nor.copy()
	for i in np.where(dedo)[0]:
		a = math.radians(POLEGAR_PALMA) * peso[i] * lado
		b = math.radians(POLEGAR_FRENTE) * peso[i] * sinal_z
		ca, sa, cb, sb = math.cos(a), math.sin(a), math.cos(b), math.sin(b)
		rz = np.array([[ca, -sa, 0.0], [sa, ca, 0.0], [0.0, 0.0, 1.0]])
		rx = np.array([[1.0, 0.0, 0.0], [0.0, cb, -sb], [0.0, sb, cb]])
		r = rz @ rx
		saida[i] = base + r @ (loc[i] - base)
		nsaida[i] = r @ nor[i]
	return saida, nsaida


def girar_normais(nor, th, lado):
	"""A normal gira o mesmo tanto que a carne (rotacao em torno de Z)."""
	c, s = np.cos(th), np.sin(th)
	saida = nor.copy()
	saida[:, 0] = c * nor[:, 0] + lado * s * nor[:, 1]
	saida[:, 1] = -lado * s * nor[:, 0] + c * nor[:, 1]
	return saida


def fechar_mao(P, N, dom, k, M, nome):
	"""Devolve (delta de posicao, delta de normal) desta mao."""
	Minv = np.linalg.inv(M)
	sel = np.where(dom == k)[0]
	loc = (np.c_[P[sel], np.ones(len(sel))] @ M.T)[:, :3]
	nloc = N[sel] @ M[:3, :3].T

	comp = loc[:, 1].max()
	y0 = NO_DOS_DEDOS * comp

	# Qual extremo de Z e' o polegar: o mais CURTO dos dois (ele para na linha
	# dos nos, os dedos vao ate' a ponta da mao). E' isto que faz a mesma conta
	# servir nas duas maos, sem tabela de lado nenhuma.
	corte = 4.0
	baixo = loc[:, 2] < loc[:, 2].min() + corte
	alto = loc[:, 2] > loc[:, 2].max() - corte
	if loc[baixo, 1].max() < loc[alto, 1].max():
		z_polegar, sinal_z = loc[:, 2].min(), 1.0
	else:
		z_polegar, sinal_z = loc[:, 2].max(), -1.0

	# Pra que lado a palma cai: o polegar pende pra ela.
	perto = np.abs(loc[:, 2] - z_polegar) < corte
	lado = 1.0 if loc[perto, 0].mean() > loc[~perto, 0].mean() else -1.0

	# Os dedos so' existem acima do no', e o polegar so' abaixo dele: as duas
	# contas nao se cruzam, entao uma roda depois da outra sem mistura nenhuma.
	novo, th = dobrar(loc, y0, JUNTAS, lado)
	nnovo = girar_normais(nloc, th, lado)
	novo, nnovo = girar_polegar(novo, nnovo, z_polegar, sinal_z, lado)

	dP = np.zeros_like(P)
	dN = np.zeros_like(N)
	dP[sel] = (np.c_[novo, np.ones(len(novo))] @ Minv.T)[:, :3] - P[sel]
	fim = nnovo @ np.linalg.inv(M[:3, :3]).T
	fim /= np.linalg.norm(fim, axis=1, keepdims=True)
	dN[sel] = fim - N[sel]
	print("  %s: %d vertices, palma em %sX, no' em %.1f cm, "
		"ponta anda %.1f cm" % (nome, len(sel), "+" if lado > 0 else "-", y0,
		np.abs(novo - loc).max()))
	return dP, dN


def main():
	saida = sys.argv[1] if len(sys.argv) > 1 else MODELO
	dados, js, binoff, binlen = abrir(MODELO)
	prim = js["meshes"][0]["primitives"][0]
	P = ler(dados, js, binoff, prim["attributes"]["POSITION"])
	N = ler(dados, js, binoff, prim["attributes"]["NORMAL"])
	J = ler(dados, js, binoff, prim["attributes"]["JOINTS_0"]).astype(int)
	W = ler(dados, js, binoff, prim["attributes"]["WEIGHTS_0"])
	dom = J[np.arange(len(J)), W.argmax(1)]

	pele = js["skins"][0]
	IBM = ler(dados, js, binoff, pele["inverseBindMatrices"]).reshape(-1, 4, 4)
	ossos = [js["nodes"][j].get("name") for j in pele["joints"]]

	# Rodar de novo nao empilha: o que ja' existe sai antes.
	prim.pop("targets", None)
	js["meshes"][0].pop("weights", None)
	js["meshes"][0].get("extras", {}).pop("targetNames", None)

	alvos = []
	print("fechando a mao:")
	for osso, nome in [("RightHand", "punho_d"), ("LeftHand", "punho_e")]:
		k = ossos.index(osso)
		dP, dN = fechar_mao(P, N, dom, k, IBM[k].T, osso)
		alvos.append((nome, dP.astype(np.float32), dN.astype(np.float32)))

	bins = bytearray(dados[binoff:binoff + binlen])

	def anexar(arr):
		while len(bins) % 4:
			bins.append(0)
		ini = len(bins)
		bins.extend(arr.tobytes())
		js["bufferViews"].append({"buffer": 0, "byteOffset": ini,
			"byteLength": arr.nbytes})
		js["accessors"].append({"bufferView": len(js["bufferViews"]) - 1,
			"componentType": 5126, "count": len(arr), "type": "VEC3",
			"min": [float(v) for v in arr.min(0)],
			"max": [float(v) for v in arr.max(0)]})
		return len(js["accessors"]) - 1

	prim["targets"] = []
	for _, dP, dN in alvos:
		prim["targets"].append({"POSITION": anexar(dP), "NORMAL": anexar(dN)})
	js["meshes"][0]["weights"] = [0.0] * len(alvos)
	js["meshes"][0].setdefault("extras", {})["targetNames"] = [n for n, _, _ in alvos]
	js["buffers"][0]["byteLength"] = len(bins)

	texto = json.dumps(js, separators=(",", ":")).encode("utf-8")
	while len(texto) % 4:
		texto += b" "
	while len(bins) % 4:
		bins.append(0)
	total = 12 + 8 + len(texto) + 8 + len(bins)
	with open(saida, "wb") as f:
		f.write(b"glTF" + struct.pack("<II", 2, total))
		f.write(struct.pack("<II", len(texto), 0x4E4F534A))
		f.write(texto)
		f.write(struct.pack("<II", len(bins), 0x004E4942))
		f.write(bins)
	print("gravado %s (%.1f MB)" % (saida, total / 1048576.0))


if __name__ == "__main__":
	main()
