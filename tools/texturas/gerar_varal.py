"""Desenha o atlas do que fica pendurado em linha na cidade da stage_1.

Rodar (python do sistema, precisa de Pillow e numpy):

    python3 tools/texturas/gerar_varal.py

Saida: red-valve/assets/images/textures/varal/
    varal_atlas.png   1024x1024 RGBA — roupa de varal e bandeirinha de festa
    varal.json        manifesto: recorte de cada peca e como pendura-la

==============================================================================
POR QUE ISTO EXISTE

Cidade viva nao e' cidade cheia de objeto: e' cidade com sinal de que alguem
mora ali. Roupa no varal e' o sinal mais barato e mais forte que existe —
diz que a casa esta' habitada, que e' dia, que choveu ontem ou nao. Bandeirinha
atravessando a rua diz a mesma coisa do bairro inteiro.

Cada peca e' UM quad. Todas dividem este atlas, entao o varal inteiro de um
bloco cabe num MultiMesh de uma chamada — mesmo esquema da pichacao, e a
mesma razao: uma textura por peca viraria uma chamada de desenho por peca.

O balanco NAO esta na imagem: e' o `varal.gdshader` que torce o quad no
vertex(), preso pela borda de cima. Animar por textura exigiria quadros; animar
por vertice sai de graca e cada peca balanca com a fase da propria posicao, que
e' o que evita o varal inteiro oscilar junto feito cortina de teatro.

==============================================================================
COMO AS PECAS SAO DESENHADAS

Roupa de varal vista a 8 metros e' silhueta e cor — costura, botao e estampa
nao chegam. Entao cada peca e' um POLIGONO chapado, com:
    * uma sombra propria de cima pra baixo (a luz vem de cima);
    * um vinco vertical de ruido, que e' o que diferencia pano de adesivo;
    * o topo mordido pelo prendedor, que e' onde o pano franze.
Tudo com o topo do quad ENCOSTANDO na borda da imagem: e' por essa borda que o
shader prende a peca na corda.
"""

import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "red-valve", "assets", "images", "textures", "varal")
RES_ATLAS = "res://assets/images/textures/varal/varal_atlas.png"

SEMENTE = 20260915

# Roupa de cidade pequena: algodao lavado muitas vezes. Nada saturado — a
# cidade roda com LUT sepia e cor pura vira neon no varal.
PANOS = [
	(198, 192, 178), (176, 178, 170), (150, 138, 120), (120, 126, 132),
	(146, 108, 96), (104, 116, 104), (168, 156, 128), (88, 96, 112),
	(182, 160, 140), (132, 132, 138),
]

# Bandeirinha de festa: essas SAO saturadas de proposito. Papel de seda novo e'
# a unica coisa berrante que aparece numa rua dessas, e o contraste e' o ponto.
BANDEIRAS = [
	(198, 64, 52), (222, 168, 48), (64, 128, 92), (58, 96, 170),
	(206, 108, 150), (232, 132, 44), (120, 76, 150),
]


def _pano(mascara, cor, rng, vinco=0.17, sombra=0.32):
	"""Mascara em L -> RGBA de pano. O vinco vertical e' o que tira a cara de
	adesivo; a sombra de cima pra baixo poe o volume sem geometria nenhuma."""
	a = np.asarray(mascara, dtype=np.float32) / 255.0
	h, w = a.shape
	rg = np.random.default_rng(rng.randint(0, 1 << 30))

	# vinco: ruido esticado na vertical, pra virar dobra e nao granulado. A
	# grade e' GROSSA de proposito — poucos blocos, bem largos. Com ruido fino
	# o pano vira veio de madeira, que foi o que a primeira versao produziu.
	base = rg.random((max(2, h // 90), max(2, w // 7))).astype(np.float32)
	dobra = np.asarray(
		Image.fromarray((base * 255).astype(np.uint8), "L").resize((w, h), Image.BICUBIC),
		dtype=np.float32) / 255.0
	dobra = 1.0 + (dobra - 0.5) * vinco

	# a luz vem de cima: o pano escurece pro barrado
	yy = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]
	luz = 1.0 - yy * sombra

	rgb = np.zeros((h, w, 3), dtype=np.float32)
	for c in range(3):
		rgb[:, :, c] = np.clip(cor[c] / 255.0 * dobra * luz, 0.0, 1.0)
	out = np.zeros((h, w, 4), dtype=np.uint8)
	out[:, :, :3] = (rgb * 255).astype(np.uint8)
	out[:, :, 3] = (a * 255).astype(np.uint8)
	return Image.fromarray(out, "RGBA")


def _franze_topo(d, w, rng, n=5, fundura=0.03, altura=1.0):
	"""Mordidas no topo: o pano franze entre um prendedor e o seguinte."""
	for i in range(n):
		x = w * (i + 0.5) / n
		r = w * fundura * rng.uniform(0.6, 1.4)
		d.ellipse([x - r, -r * 0.4, x + r, r * 1.6 * altura], fill=0)


def camisa(tam=(256, 288), rng=None, manga_longa=False):
	"""Camisa pendurada pelos ombros: tronco reto e manga caida."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	d = ImageDraw.Draw(m)
	ombro = W * 0.16
	tronco_x0 = ombro
	tronco_x1 = W - ombro
	manga = H * (0.62 if manga_longa else 0.34)
	# tronco, ligeiramente mais largo embaixo
	d.polygon([(tronco_x0, H * 0.04), (tronco_x1, H * 0.04),
			   (tronco_x1 + W * 0.03, H * 0.96), (tronco_x0 - W * 0.03, H * 0.96)], fill=255)
	# mangas
	for lado in (-1, 1):
		bx = (tronco_x0 if lado < 0 else tronco_x1)
		d.polygon([(bx, H * 0.05), (bx + lado * ombro, H * 0.16),
				   (bx + lado * ombro * 0.9, H * 0.16 + manga),
				   (bx + lado * ombro * 0.2, H * 0.14 + manga)], fill=255)
	# gola
	d.ellipse([W * 0.40, -H * 0.03, W * 0.60, H * 0.07], fill=0)
	_franze_topo(d, W, rng, n=4, fundura=0.035)
	m = m.filter(ImageFilter.GaussianBlur(1.6))
	return _pano(m.resize((w, h), Image.LANCZOS), rng.choice(PANOS), rng)


def calca(tam=(224, 320), rng=None):
	"""Calca pendurada pela cintura, com o vao entre as pernas."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	d = ImageDraw.Draw(m)
	d.polygon([(W * 0.10, H * 0.03), (W * 0.90, H * 0.03),
			   (W * 0.86, H * 0.97), (W * 0.56, H * 0.97),
			   (W * 0.50, H * 0.40),
			   (W * 0.44, H * 0.97), (W * 0.14, H * 0.97)], fill=255)
	_franze_topo(d, W, rng, n=3, fundura=0.04)
	m = m.filter(ImageFilter.GaussianBlur(1.6))
	return _pano(m.resize((w, h), Image.LANCZOS), rng.choice(PANOS), rng)


def toalha(tam=(224, 288), rng=None, listras=True):
	"""Toalha/pano retangular, com a barra em outra cor."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	d = ImageDraw.Draw(m)
	d.polygon([(W * 0.05, H * 0.02), (W * 0.95, H * 0.02),
			   (W * 0.97, H * 0.98), (W * 0.03, H * 0.98)], fill=255)
	_franze_topo(d, W, rng, n=5, fundura=0.03)
	m = m.filter(ImageFilter.GaussianBlur(1.4))
	cor = rng.choice(PANOS)
	img = _pano(m.resize((w, h), Image.LANCZOS), cor, rng).copy()
	if listras:
		# barra: duas faixas escuras perto do pe' da toalha
		px = img.load()
		escura = tuple(int(c * 0.72) for c in cor)
		for faixa in (0.80, 0.88):
			y0 = int(h * faixa)
			for y in range(y0, min(h, y0 + max(2, h // 40))):
				for x in range(w):
					if px[x, y][3] > 16:
						px[x, y] = escura + (px[x, y][3],)
	return img


def lencol(tam=(352, 288), rng=None):
	"""Lencol: largo, dobrado na corda, com a barriga pesando no meio."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	d = ImageDraw.Draw(m)
	pts = [(W * 0.03, H * 0.02), (W * 0.97, H * 0.02)]
	# o pe' do lencol nao e' reto: o pano pesa e faz barriga
	for i in range(13, -1, -1):
		t = i / 13.0
		x = W * (0.02 + 0.96 * t)
		y = H * (0.86 + 0.10 * math.sin(t * math.pi) + rng.uniform(-0.02, 0.02))
		pts.append((x, y))
	d.polygon(pts, fill=255)
	_franze_topo(d, W, rng, n=7, fundura=0.025)
	m = m.filter(ImageFilter.GaussianBlur(2.0))
	return _pano(m.resize((w, h), Image.LANCZOS), rng.choice(PANOS), rng, vinco=0.24)


def fronha(tam=(192, 192), rng=None):
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	d = ImageDraw.Draw(m)
	d.polygon([(W * 0.08, H * 0.03), (W * 0.92, H * 0.03),
			   (W * 0.94, H * 0.9), (W * 0.06, H * 0.9)], fill=255)
	_franze_topo(d, W, rng, n=4, fundura=0.03)
	m = m.filter(ImageFilter.GaussianBlur(1.4))
	return _pano(m.resize((w, h), Image.LANCZOS), rng.choice(PANOS), rng)


def bandeirinha(tam=(128, 160), rng=None, cor=None):
	"""Bandeirinha de papel de seda: triangulo preso pela borda de cima.

	Sao as unicas pecas berrantes do atlas, e de proposito — ver o cabecalho."""
	rng = rng or random
	cor = cor or rng.choice(BANDEIRAS)
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	d = ImageDraw.Draw(m)
	d.polygon([(W * 0.03, 0), (W * 0.97, 0), (W * 0.5, H * 0.94)], fill=255)
	m = m.filter(ImageFilter.GaussianBlur(1.0))
	img = _pano(m.resize((w, h), Image.LANCZOS), cor, rng, vinco=0.1, sombra=0.2).copy()
	# vinco central do papel dobrado
	px = img.load()
	clara = tuple(min(255, int(c * 1.25)) for c in cor)
	for y in range(h):
		x = w // 2
		if px[x, y][3] > 16:
			px[x, y] = clara + (px[x, y][3],)
	return img


# ---------------------------------------------------------------------------
# catalogo
# ---------------------------------------------------------------------------
# papel — em que tipo de linha a peca entra:
#   roupa    varal de quintal
#   bandeira corda de festa atravessando a rua
# largura   — faixa de largura em METROS no mundo.
def catalogo(rng):
	itens = []

	def add(nome, img, papel, largura, peso):
		itens.append({"n": nome, "img": img, "papel": papel,
					  "largura": largura, "peso": peso})

	for i in range(3):
		add("camisa_%02d" % (i + 1), camisa((256, 288), rng, manga_longa=(i == 2)),
			"roupa", [0.48, 0.60], 9)
	for i in range(2):
		add("calca_%02d" % (i + 1), calca((224, 320), rng), "roupa", [0.42, 0.54], 8)
	for i in range(2):
		add("toalha_%02d" % (i + 1), toalha((224, 288), rng, listras=(i == 0)),
			"roupa", [0.46, 0.62], 7)
	add("lencol_01", lencol((352, 288), rng), "roupa", [0.95, 1.30], 4)
	for i in range(2):
		add("fronha_%02d" % (i + 1), fronha((192, 192), rng), "roupa", [0.36, 0.46], 6)

	for i, cor in enumerate(BANDEIRAS):
		add("bandeira_%02d" % (i + 1), bandeirinha((128, 160), rng, cor),
			"bandeira", [0.24, 0.30], 10)
	return itens


# ---------------------------------------------------------------------------
# empacotamento: prateleira, do mais alto pro mais baixo
# ---------------------------------------------------------------------------
def empacotar(itens, largura, margem=4):
	ordem = sorted(itens, key=lambda it: -it["img"].height)
	pos = {}
	x = margem
	y = margem
	alt_linha = 0
	for it in ordem:
		w, h = it["img"].size
		if x + w + margem > largura:
			x = margem
			y += alt_linha + margem
			alt_linha = 0
		pos[it["n"]] = (x, y)
		x += w + margem
		alt_linha = max(alt_linha, h)
	return pos, y + alt_linha + margem


def main():
	rng = random.Random(SEMENTE)
	os.makedirs(SAIDA, exist_ok=True)
	itens = catalogo(rng)

	largura = 1024
	pos, usado = empacotar(itens, largura)
	altura = ((usado + 63) // 64) * 64
	atlas = Image.new("RGBA", (largura, altura), (0, 0, 0, 0))
	manifesto = []
	for it in itens:
		x, y = pos[it["n"]]
		w, h = it["img"].size
		atlas.alpha_composite(it["img"], (x, y))
		manifesto.append({
			"n": it["n"],
			"papel": it["papel"],
			"uv": [round(x / largura, 6), round(y / altura, 6),
				   round(w / largura, 6), round(h / altura, 6)],
			"px": [w, h],
			"largura": it["largura"],
			"peso": it["peso"],
		})
	caminho = os.path.join(SAIDA, "varal_atlas.png")
	atlas.save(caminho)
	print("  %-24s %dx%d  %d pecas  %.1f KB" % (
		os.path.basename(caminho), largura, altura, len(manifesto),
		os.path.getsize(caminho) / 1024.0))

	manifesto.sort(key=lambda m: (m["papel"], m["n"]))
	with open(os.path.join(SAIDA, "varal.json"), "w", encoding="utf-8") as f:
		json.dump({
			"nota": "gerado por tools/texturas/gerar_varal.py — nao editar a mao",
			"atlas": RES_ATLAS,
			"pecas": manifesto,
		}, f, ensure_ascii=False, indent=1)
	print("  varal.json               %d pecas" % len(manifesto))


if __name__ == "__main__":
	main()
