"""Desenha os atlas de pichacao, cartaz e mancha da cidade da stage_1.

Rodar (python do sistema, precisa de Pillow e numpy):

    python3 tools/texturas/gerar_pichacao.py

Saida: red-valve/assets/images/textures/pichacao/
    pichacao_parede.png   RGBA — tudo que vai em parede e muro
    pichacao_chao.png     RGBA — tudo que vai no chao e no asfalto
    pichacao.json         manifesto: onde cada arte esta no atlas e como usa-la
"""

import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "red-valve", "assets", "images", "textures", "pichacao")
RES_ATLAS = "res://assets/images/textures/pichacao/%s"

SEMENTE = 20260915

# Tinta de spray de rua: preto de fumaca, prata sujo, giz palido, azul de caneta,
# vermelho oxido/sangue seco, ocre industrial, verde musgo escuro.
TINTAS = [
	(18, 16, 18),     # preto fumaca
	(28, 26, 30),     # preto lavado
	(168, 164, 156),  # prata / giz sujo
	(38, 50, 94),     # azul caneta noturno
	(138, 32, 28),    # vermelho oxido / valvula
	(108, 22, 20),    # sangue seco
	(148, 114, 42),   # amarelo ocre industrial
	(44, 60, 44),     # verde escuro
]


# ---------------------------------------------------------------------------
# alfabeto de pixacao: polilinhas num quadrado 0..1, y=0 em cima
# ---------------------------------------------------------------------------
ALFABETO = {
	"A": [[(0, 1), (0, 0.08), (1, 0), (1, 1)], [(0, 0.58), (1, 0.55)]],
	"B": [[(0, 1), (0, 0), (1, 0.14), (1, 0.42), (0, 0.55)], [(0, 0.55), (1, 0.66), (1, 0.88), (0, 1)]],
	"C": [[(1, 0.02), (0, 0.12), (0, 0.9), (1, 1)]],
	"D": [[(0, 1), (0, 0), (1, 0.22), (1, 0.8), (0, 1)]],
	"E": [[(1, 0), (0, 0.04), (0, 0.96), (1, 1)], [(0, 0.52), (0.72, 0.5)]],
	"F": [[(1, 0), (0, 0.05), (0, 1)], [(0, 0.5), (0.7, 0.48)]],
	"G": [[(1, 0.02), (0, 0.12), (0, 0.9), (1, 1), (1, 0.56), (0.42, 0.54)]],
	"H": [[(0, 0), (0, 1)], [(1, 0), (1, 1)], [(0, 0.56), (1, 0.52)]],
	"I": [[(0.5, 0.02), (0.5, 0.98)], [(0.06, 0), (0.94, 0.04)], [(0.06, 1), (0.94, 0.96)]],
	"J": [[(1, 0), (1, 0.84), (0.42, 1), (0, 0.78)]],
	"K": [[(0, 0), (0, 1)], [(1, 0), (0.05, 0.56), (1, 1)]],
	"L": [[(0, 0), (0, 0.96), (1, 1)]],
	"M": [[(0, 1), (0, 0.04), (0.5, 0.48), (1, 0), (1, 1)]],
	"N": [[(0, 1), (0, 0), (1, 1), (1, 0)]],
	"O": [[(0, 0.12), (0.5, 0), (1, 0.12), (1, 0.88), (0.5, 1), (0, 0.88), (0, 0.12)]],
	"P": [[(0, 1), (0, 0), (1, 0.14), (1, 0.44), (0, 0.6)]],
	"Q": [[(0, 0.12), (0.5, 0), (1, 0.12), (1, 0.88), (0.5, 1), (0, 0.88), (0, 0.12)], [(0.55, 0.72), (1.1, 1.12)]],
	"R": [[(0, 1), (0, 0), (1, 0.14), (1, 0.44), (0, 0.6)], [(0.3, 0.6), (1, 1)]],
	"S": [[(1, 0.04), (0, 0.16), (0, 0.44), (1, 0.6), (1, 0.88), (0, 1)]],
	"T": [[(0, 0.02), (1, 0)], [(0.5, 0), (0.5, 1)]],
	"U": [[(0, 0), (0, 0.88), (0.5, 1), (1, 0.88), (1, 0)]],
	"V": [[(0, 0), (0.5, 1), (1, 0)]],
	"W": [[(0, 0), (0.24, 1), (0.5, 0.38), (0.76, 1), (1, 0)]],
	"X": [[(0, 0), (1, 1)], [(1, 0), (0, 1)]],
	"Y": [[(0, 0), (0.5, 0.52), (1, 0)], [(0.5, 0.52), (0.5, 1)]],
	"Z": [[(0, 0.04), (1, 0), (0, 1), (1, 0.96)]],
	"0": [[(0, 0.12), (0.5, 0), (1, 0.12), (1, 0.88), (0.5, 1), (0, 0.88), (0, 0.12)], [(0, 0.88), (1, 0.12)]],
	"1": [[(0.16, 0.18), (0.5, 0), (0.5, 1)], [(0.08, 1), (0.92, 0.97)]],
	"2": [[(0, 0.16), (0.5, 0), (1, 0.16), (1, 0.4), (0, 1), (1, 0.96)]],
	"3": [[(0, 0.04), (1, 0.1), (0.38, 0.5), (1, 0.6), (1, 0.9), (0, 1)]],
	"4": [[(0.8, 0), (0, 0.7), (1, 0.68)], [(0.8, 0.34), (0.8, 1)]],
	"5": [[(1, 0.02), (0, 0), (0, 0.44), (1, 0.56), (1, 0.9), (0, 1)]],
	"6": [[(1, 0), (0.18, 0.38), (0, 0.9), (0.5, 1), (1, 0.88), (1, 0.6), (0.28, 0.5)]],
	"7": [[(0, 0.04), (1, 0), (0.3, 1)]],
	"8": [[(0.5, 0), (0, 0.22), (0.5, 0.5), (1, 0.22), (0.5, 0)], [(0.5, 0.5), (0, 0.8), (0.5, 1), (1, 0.8), (0.5, 0.5)]],
	"9": [[(1, 0.12), (0.5, 0), (0, 0.12), (0, 0.42), (1, 0.5), (1, 0.12)], [(1, 0.5), (0.18, 1)]],
	"-": [[(0, 0.55), (1, 0.52)]],
	".": [[(0.4, 0.95), (0.6, 0.98)]],
	"?": [[(0.05, 0.18), (0.5, 0), (0.95, 0.18), (0.9, 0.44), (0.5, 0.62), (0.5, 0.76)], [(0.45, 0.92), (0.55, 0.98)]],
	"!": [[(0.5, 0.0), (0.5, 0.74)], [(0.45, 0.92), (0.55, 0.98)]],
	":": [[(0.45, 0.28), (0.55, 0.34)], [(0.45, 0.72), (0.55, 0.78)]],
	"/": [[(0.85, 0.04), (0.15, 0.96)]],
}


# ---------------------------------------------------------------------------
# bico de spray
# ---------------------------------------------------------------------------
def _linha(mascara, pts, largura, jitter=0.0, rng=None):
	"""Traco solido. O jitter torce cada vertice — mao tremida, nao regua."""
	d = ImageDraw.Draw(mascara)
	saida = []
	for (x, y) in pts:
		if jitter > 0.0 and rng is not None:
			x += rng.uniform(-jitter, jitter)
			y += rng.uniform(-jitter, jitter)
		saida.append((x, y))
	d.line(saida, fill=255, width=int(largura), joint="curve")
	r = largura * 0.5
	for (x, y) in (saida[0], saida[-1]):
		d.ellipse([x - r, y - r, x + r, y + r], fill=255)
	return saida


def _respingo(mascara, pts, largura, rng, quanto=1.0):
	"""Gotinhas ao redor do traco. E' o que tira a borda de adesivo."""
	d = ImageDraw.Draw(mascara)
	for i in range(len(pts) - 1):
		ax, ay = pts[i]
		bx, by = pts[i + 1]
		comp = math.hypot(bx - ax, by - ay)
		n = int(comp * 0.5 * quanto)
		for _ in range(n):
			t = rng.random()
			cx = ax + (bx - ax) * t
			cy = ay + (by - ay) * t
			ang = rng.uniform(0, math.tau)
			dist = abs(rng.gauss(0.0, largura * 0.55)) + largura * 0.4
			px = cx + math.cos(ang) * dist
			py = cy + math.sin(ang) * dist
			r = rng.uniform(0.6, largura * 0.16)
			tom = int(rng.uniform(70, 230))
			d.ellipse([px - r, py - r, px + r, py + r], fill=tom)


def _escorrido(mascara, pts, largura, rng, chance=0.3, alcance=1.0):
	"""Tinta escorrendo pra baixo. So dos vertices, que e' onde a mao para."""
	d = ImageDraw.Draw(mascara)
	for (x, y) in pts:
		if rng.random() > chance:
			continue
		comp = rng.uniform(largura * 1.5, largura * 7.5) * alcance
		grossura = max(1.0, largura * rng.uniform(0.12, 0.32))
		passos = max(2, int(comp / 3))
		for i in range(passos):
			t = i / float(passos - 1)
			gy = y + comp * t
			gr = grossura * (1.0 - t * 0.55)
			d.ellipse([x - gr, gy - gr, x + gr, gy + gr], fill=int(255 * (1.0 - t * 0.35)))
		d.ellipse([x - grossura, y + comp - grossura, x + grossura, y + comp + grossura], fill=210)


def _tinta(mascara, cor, variacao=0.16, rng=None):
	"""Mascara em L -> RGBA colorido."""
	a = np.asarray(mascara, dtype=np.float32) / 255.0
	h, w = a.shape
	rgb = np.zeros((h, w, 3), dtype=np.float32)
	semente = rng.randint(0, 1 << 30) if rng is not None else 0
	ruido = np.random.default_rng(semente).normal(0.0, variacao, (h, w, 1)).astype(np.float32)
	for c in range(3):
		rgb[:, :, c] = np.clip(cor[c] / 255.0 * (1.0 + ruido[:, :, 0]), 0.0, 1.0)
	out = np.zeros((h, w, 4), dtype=np.uint8)
	out[:, :, :3] = (rgb * 255).astype(np.uint8)
	out[:, :, 3] = (a * 255).astype(np.uint8)
	return Image.fromarray(out, "RGBA")


# ---------------------------------------------------------------------------
# artes de parede
# ---------------------------------------------------------------------------
def pixacao(texto, tam=(512, 256), rng=None, cor=None, bico=None, inclina=True):
	"""Uma linha de pixacao."""
	rng = rng or random
	cor = cor or rng.choice(TINTAS)
	w, h = tam
	m = Image.new("L", (w * 2, h * 2), 0)
	W, H = w * 2, h * 2
	margem = H * 0.14
	alt = H - margem * 2
	larg_letra = alt / 2.45
	n = max(1, len(texto))
	total = larg_letra * n
	escala = min(1.0, (W - margem * 2) / max(total, 1.0))
	larg_letra *= escala
	alt *= escala
	bico = bico or max(3.0, alt * 0.088)
	x0 = (W - larg_letra * n) * 0.5
	y0 = (H - alt) * 0.5
	tracos = []
	for i, ch in enumerate(texto.upper()):
		glifo = ALFABETO.get(ch)
		if glifo is None:
			continue
		incl = rng.uniform(-0.1, 0.1) if inclina else 0.0
		dy = rng.uniform(-alt * 0.03, alt * 0.03)
		for poli in glifo:
			pts = []
			for (gx, gy) in poli:
				px = x0 + (i + gx) * larg_letra + (0.5 - gy) * incl * larg_letra * 2.0
				py = y0 + dy + gy * alt
				pts.append((px, py))
			tracos.append(_linha(m, pts, bico, jitter=bico * 0.22, rng=rng))
	for pts in tracos:
		_respingo(m, pts, bico, rng)
	for pts in tracos:
		_escorrido(m, pts, bico, rng, chance=0.26)
	m = m.resize((w, h), Image.LANCZOS)
	return _tinta(m, cor, rng=rng)


def bomba(texto, tam=(512, 384), rng=None, preenche=None):
	"""Throw-up: letra gorda de duas cores, contorno grosso e brilho."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	preenche = preenche or rng.choice([(164, 156, 138), (144, 42, 36), (54, 68, 114), (152, 124, 48)])
	contorno = rng.choice([(16, 14, 16), (20, 18, 22)])

	m_fora = Image.new("L", (W, H), 0)
	m_dentro = Image.new("L", (W, H), 0)
	n = max(1, len(texto))
	larg = (W * 0.82) / n
	alt = H * 0.62
	x0 = (W - larg * n) * 0.5
	y0 = (H - alt) * 0.5
	bico = alt * 0.3
	for i, ch in enumerate(texto.upper()):
		glifo = ALFABETO.get(ch)
		if glifo is None:
			continue
		for poli in glifo:
			pts = [(x0 + (i + gx * 0.86 + 0.07) * larg, y0 + gy * alt) for (gx, gy) in poli]
			_linha(m_fora, pts, bico * 1.42, jitter=bico * 0.05, rng=rng)
			_linha(m_dentro, pts, bico, jitter=bico * 0.05, rng=rng)
	fora = np.asarray(m_fora, dtype=np.int16)
	dentro = np.asarray(m_dentro, dtype=np.int16)
	casca = np.clip(fora - dentro, 0, 255).astype(np.uint8)

	rgba = np.zeros((H, W, 4), dtype=np.uint8)
	for c in range(3):
		rgba[:, :, c] = np.where(dentro > 120, preenche[c], contorno[c])
	rgba[:, :, 3] = np.maximum(casca, dentro).astype(np.uint8)

	img = Image.fromarray(rgba, "RGBA")
	m_pingo = Image.new("L", (W, H), 0)
	d = ImageDraw.Draw(m_pingo)
	for _ in range(rng.randint(4, 9)):
		px = rng.uniform(x0, x0 + larg * n)
		py = y0 + alt * rng.uniform(0.75, 1.0)
		comp = rng.uniform(H * 0.04, H * 0.2)
		gr = rng.uniform(bico * 0.06, bico * 0.14)
		d.line([(px, py), (px, py + comp)], fill=255, width=int(max(2, gr * 2)))
		d.ellipse([px - gr, py + comp - gr, px + gr, py + comp + gr], fill=255)
	img.alpha_composite(_tinta(m_pingo, preenche, rng=rng))
	return img.resize((w, h), Image.LANCZOS)


def marcas_contagem(tam=(384, 256), rng=None):
	"""Marcas de contagem (||||/) riscadas em giz/sangue seco na parede."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	bico = H * 0.045
	tracos = []
	grupos = rng.randint(3, 4)
	larg_grupo = (W * 0.78) / grupos
	x_ini = W * 0.11
	for g in range(grupos):
		gx = x_ini + g * larg_grupo
		y_top = H * rng.uniform(0.22, 0.30)
		y_bot = H * rng.uniform(0.68, 0.78)
		for k in range(4):
			lx = gx + k * (larg_grupo * 0.17)
			pts = [(lx + rng.uniform(-4, 4), y_top + rng.uniform(-6, 6)),
				   (lx + rng.uniform(-6, 6), y_bot + rng.uniform(-6, 6))]
			tracos.append(_linha(m, pts, bico, jitter=bico * 0.2, rng=rng))
		if g < grupos - 1 or rng.random() < 0.7:
			pts_diag = [(gx - larg_grupo * 0.04, y_bot - (y_bot - y_top) * 0.18),
						(gx + larg_grupo * 0.60, y_top + (y_bot - y_top) * 0.18)]
			tracos.append(_linha(m, pts_diag, bico * 0.95, jitter=bico * 0.25, rng=rng))
	for t in tracos:
		_respingo(m, t, bico * 0.8, rng, quanto=0.7)
	_escorrido(m, tracos[-1], bico, rng, chance=0.35)
	cor = rng.choice([(168, 162, 152), (132, 28, 24)])
	return _tinta(m.resize((w, h), Image.LANCZOS), cor, rng=rng)


def simbolo_engrenagem(tam=(256, 256), rng=None):
	"""A engrenagem do amuleto, rabiscada na parede por quem acredita nela."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	cx, cy = W * 0.5, H * 0.5
	re, ri = W * 0.34, W * 0.22
	dentes = rng.randint(7, 9)
	pts = []
	passos = dentes * 4
	for i in range(passos + 1):
		a = i / passos * math.tau
		r = re if (i // 2) % 2 == 0 else ri
		r *= rng.uniform(0.94, 1.06)
		pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
	bico = W * 0.035
	t1 = _linha(m, pts, bico, jitter=bico * 0.3, rng=rng)
	miolo = [(cx + math.cos(i / 16 * math.tau) * W * 0.1,
			  cy + math.sin(i / 16 * math.tau) * W * 0.1) for i in range(17)]
	t2 = _linha(m, miolo, bico * 0.8, jitter=bico * 0.3, rng=rng)
	for t in (t1, t2):
		_respingo(m, t, bico, rng)
	_escorrido(m, t1, bico, rng, chance=0.15)
	return _tinta(m.resize((w, h), Image.LANCZOS), rng.choice(TINTAS), rng=rng)


def simbolo_valvula(tam=(256, 256), rng=None):
	"""Volante de valvula vermelha: o simbolo do titulo virado marca de rua."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	cx, cy = W * 0.5, H * 0.5
	r = W * 0.34
	bico = W * 0.045
	aro = [(cx + math.cos(i / 28 * math.tau) * r * rng.uniform(0.95, 1.05),
			cy + math.sin(i / 28 * math.tau) * r * rng.uniform(0.95, 1.05)) for i in range(29)]
	aro_int = [(cx + math.cos(i / 18 * math.tau) * (r * 0.32),
				cy + math.sin(i / 18 * math.tau) * (r * 0.32)) for i in range(19)]
	tracos = [
		_linha(m, aro, bico, jitter=bico * 0.25, rng=rng),
		_linha(m, aro_int, bico * 0.8, jitter=bico * 0.2, rng=rng),
	]
	for k in range(3):
		a = k / 3.0 * math.pi
		tracos.append(_linha(m, [(cx - math.cos(a) * r, cy - math.sin(a) * r),
								 (cx + math.cos(a) * r, cy + math.sin(a) * r)],
							 bico * 0.78, jitter=bico * 0.25, rng=rng))
	for t in tracos:
		_respingo(m, t, bico, rng)
	_escorrido(m, aro[::3], bico, rng, chance=0.35, alcance=1.3)
	return _tinta(m.resize((w, h), Image.LANCZOS), (154, 34, 28), rng=rng)


def simbolo_olho(tam=(256, 256), rng=None):
	"""Olho do Abismo: o que os moradores desenham quando a cidade olha de volta."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	cx, cy = W * 0.5, H * 0.5
	rw, rh = W * 0.36, H * 0.2
	bico = W * 0.04
	cima = [(cx + math.cos(math.pi + i / 20 * math.pi) * rw,
			 cy + math.sin(math.pi + i / 20 * math.pi) * rh) for i in range(21)]
	baixo = [(cx + math.cos(i / 20 * math.pi) * rw,
			  cy + math.sin(i / 20 * math.pi) * rh) for i in range(21)]
	iris = [(cx + math.cos(i / 18 * math.tau) * W * 0.11,
			 cy + math.sin(i / 18 * math.tau) * W * 0.11) for i in range(19)]
	tracos = [_linha(m, p, bico, jitter=bico * 0.3, rng=rng) for p in (cima, baixo, iris)]
	d = ImageDraw.Draw(m)
	d.ellipse([cx - W * 0.04, cy - W * 0.07, cx + W * 0.04, cy + W * 0.07], fill=255)
	for t in tracos:
		_respingo(m, t, bico, rng)
	_escorrido(m, baixo[::4], bico, rng, chance=0.4, alcance=1.4)
	return _tinta(m.resize((w, h), Image.LANCZOS), rng.choice([(142, 30, 26), (22, 20, 24), (162, 156, 146)]), rng=rng)


def simbolo_vizinho(tam=(256, 384), rng=None):
	"""Silhueta sombria do Vizinho Dobrado / Sombra pintada no beco com olhos claros."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	d = ImageDraw.Draw(m)
	cx = W * 0.5
	# cabeca inclinada / torta
	hx = cx + W * rng.uniform(-0.06, 0.06)
	hy = H * 0.22
	hr = W * 0.13
	d.ellipse([hx - hr, hy - hr * 1.15, hx + hr, hy + hr * 1.15], fill=245)
	# ombros e tronco esguio
	pts_corpo = [
		(hx - hr * 0.5, hy + hr * 0.9),
		(cx - W * 0.26, H * 0.38),
		(cx - W * 0.22, H * 0.88),
		(cx + W * 0.22, H * 0.88),
		(cx + W * 0.28, H * 0.36),
		(hx + hr * 0.5, hy + hr * 0.9),
	]
	d.polygon(pts_corpo, fill=240)
	bico = W * 0.045
	contorno = _linha(m, pts_corpo + [pts_corpo[0]], bico, jitter=bico * 0.35, rng=rng)
	_respingo(m, contorno, bico * 1.2, rng, quanto=1.3)
	_escorrido(m, [(cx - W * 0.15, H * 0.85), (cx, H * 0.87), (cx + W * 0.14, H * 0.85)], bico, rng, chance=0.85, alcance=1.4)
	img = _tinta(m, (16, 14, 18), rng=rng)
	# olhos brancos/amarelados furando a sombra
	d_rgba = ImageDraw.Draw(img)
	er = W * 0.022
	d_rgba.ellipse([hx - hr * 0.45 - er, hy - er, hx - hr * 0.45 + er, hy + er], fill=(215, 205, 180, 245))
	d_rgba.ellipse([hx + hr * 0.35 - er, hy - er * 0.8, hx + hr * 0.35 + er, hy + er * 1.2], fill=(215, 205, 180, 245))
	return img.resize((w, h), Image.LANCZOS)


def simbolo_cruz_abismo(tam=(256, 256), rng=None):
	"""Espiral / cruz oculta do Abismo de Ferro."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	cx, cy = W * 0.5, H * 0.5
	bico = W * 0.038
	pts = []
	volta = 2.6
	passos = 55
	for i in range(passos):
		t = i / float(passos - 1)
		a = t * volta * math.tau
		r = W * (0.04 + 0.33 * t)
		pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
	t1 = _linha(m, pts, bico, jitter=bico * 0.22, rng=rng)
	t2 = _linha(m, [(cx, H * 0.1), (cx, H * 0.9)], bico * 0.85, jitter=bico * 0.25, rng=rng)
	t3 = _linha(m, [(W * 0.18, cy - H * 0.12), (W * 0.82, cy - H * 0.12)], bico * 0.85, jitter=bico * 0.25, rng=rng)
	for t in (t1, t2, t3):
		_respingo(m, t, bico, rng)
	_escorrido(m, [pts[-1], (cx, H * 0.9)], bico, rng, chance=0.7)
	return _tinta(m.resize((w, h), Image.LANCZOS), rng.choice([(136, 26, 24), (20, 18, 22)]), rng=rng)


def simbolo_perigo(tam=(256, 256), rng=None):
	"""Triangulo industrial de risco / quarentena estencilado."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	bico = W * 0.048
	tri = [(W * 0.5, H * 0.12), (W * 0.88, H * 0.84), (W * 0.12, H * 0.84), (W * 0.5, H * 0.12)]
	t1 = _linha(m, tri, bico, jitter=bico * 0.18, rng=rng)
	t2 = _linha(m, [(W * 0.5, H * 0.36), (W * 0.5, H * 0.64)], bico * 1.1, jitter=bico * 0.15, rng=rng)
	d = ImageDraw.Draw(m)
	r = bico * 0.65
	d.ellipse([W * 0.5 - r, H * 0.74 - r, W * 0.5 + r, H * 0.74 + r], fill=255)
	_respingo(m, t1, bico, rng)
	_escorrido(m, tri[1:3], bico, rng, chance=0.45)
	return _tinta(m.resize((w, h), Image.LANCZOS), (156, 122, 36), rng=rng)


def rabisco(tam=(512, 256), rng=None):
	"""Risco sem palavra nenhuma."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	bico = H * 0.07
	tracos = []
	for _ in range(rng.randint(3, 6)):
		n = rng.randint(3, 7)
		pts = [(rng.uniform(W * 0.06, W * 0.94), rng.uniform(H * 0.12, H * 0.88)) for _ in range(n)]
		tracos.append(_linha(m, pts, bico * rng.uniform(0.6, 1.3), jitter=bico * 0.3, rng=rng))
	for t in tracos:
		_respingo(m, t, bico, rng)
		_escorrido(m, t, bico, rng, chance=0.18)
	return _tinta(m.resize((w, h), Image.LANCZOS), rng.choice(TINTAS), rng=rng)


def cartaz(tam=(256, 384), rng=None, variante=0):
	"""Cartaz lambe-lambe rasgado e envelhecido (desaparecido, interditado, aviso)."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	papel = rng.choice([(206, 196, 174), (188, 180, 164), (196, 182, 148), (176, 170, 162)])
	img = Image.new("RGBA", (W, H), papel + (255,))
	d = ImageDraw.Draw(img)
	tinta = (46, 42, 40)
	destaque = [(148, 36, 30), (38, 50, 104), (146, 108, 28), (44, 40, 38)][variante % 4]

	m = H * 0.065
	y = m
	# faixa de titulo ou listras de perigo
	if variante == 2:
		# listras diagonais amarelas/pretas de quarentena/interdicao
		d.rectangle([m, y, W - m, y + H * 0.12], fill=(168, 132, 38))
		for k in range(-2, 10):
			x_s = m + k * (W * 0.11)
			d.polygon([(x_s, y), (x_s + W * 0.055, y), (x_s + W * 0.01, y + H * 0.12), (x_s - W * 0.045, y + H * 0.12)], fill=(28, 26, 24))
		y += H * 0.15
	else:
		d.rectangle([m, y, W - m, y + H * 0.105], fill=destaque)
		# barras claras simulando letras garrafais no cabecalho
		bx = m + W * 0.08
		while bx < W - m - W * 0.12:
			bw = W * rng.uniform(0.08, 0.18)
			d.rectangle([bx, y + H * 0.028, min(W - m * 1.4, bx + bw), y + H * 0.078], fill=papel)
			bx += bw + W * 0.04
		y += H * 0.14

	# bloco de retrato (foto 3x4 xerocada em alto contraste — ex: desaparecido)
	if variante in (0, 1, 3):
		bh = H * rng.uniform(0.26, 0.34)
		d.rectangle([m * 1.4, y, W - m * 1.4, y + bh], fill=(116, 110, 104))
		d.rectangle([m * 1.4 + 4, y + 4, W - m * 1.4 - 4, y + bh - 4], outline=(48, 44, 42), width=3)
		cx = W * 0.5
		# cabeca e ombros sombrios
		d.ellipse([cx - bh * 0.20, y + bh * 0.10, cx + bh * 0.20, y + bh * 0.52], fill=(42, 38, 36))
		d.pieslice([cx - bh * 0.36, y + bh * 0.48, cx + bh * 0.36, y + bh * 1.18], 180, 360, fill=(42, 38, 36))
		if variante == 1:
			# carimbo vermelho diagonal ou X sobre o retrato
			d.line([(m * 1.6, y + bh * 0.15), (W - m * 1.6, y + bh * 0.85)], fill=(142, 32, 28), width=10)
			d.line([(W - m * 1.6, y + bh * 0.15), (m * 1.6, y + bh * 0.85)], fill=(142, 32, 28), width=10)
		y += bh + H * 0.045
	else:
		# simbolo de valvula/engrenagem central no cartaz industrial
		bh = H * 0.26
		cx, cy_s = W * 0.5, y + bh * 0.5
		r = bh * 0.38
		d.ellipse([cx - r, cy_s - r, cx + r, cy_s + r], outline=(42, 38, 36), width=12)
		d.ellipse([cx - r * 0.35, cy_s - r * 0.35, cx + r * 0.35, cy_s + r * 0.35], fill=(142, 32, 28))
		y += bh + H * 0.04

	# linhas de texto (barras de xerox gasto)
	while y < H - m * 2.1:
		lw = (W - m * 2) * rng.uniform(0.45, 0.98)
		d.rectangle([m, y, m + lw, y + H * 0.019], fill=tinta)
		y += H * 0.036

	# franjinha de destaque embaixo (picote de telefone)
	fy = H - m * 1.75
	for i in range(8):
		if rng.random() < 0.25:
			continue  # papelzinho ja arrancado
		fx = m + (W - m * 2) / 8 * i
		d.rectangle([fx + 2, fy, fx + (W - m * 2) / 8 - 4, H - m * 0.35], fill=(156, 148, 134))

	# envelhecer: mancha de umidade, amassado e rasgo
	suj = np.asarray(img, dtype=np.float32)
	ruido = np.random.default_rng(rng.randint(0, 1 << 30)).normal(1.0, 0.08, (H, W, 1))
	fbm = _ruido_fbm(W, H, 4, rng.randint(0, 1 << 30), base=3)[:, :, None]
	suj[:, :, :3] = np.clip(suj[:, :, :3] * ruido * (0.72 + 0.42 * fbm), 0, 255)
	img = Image.fromarray(suj.astype(np.uint8), "RGBA")

	alfa = Image.new("L", (W, H), 255)
	da = ImageDraw.Draw(alfa)
	canto = rng.randint(0, 3)
	cx = 0 if canto in (0, 2) else W
	cy = 0 if canto in (0, 1) else H
	pts = [(cx, cy)]
	n = 7
	for i in range(n + 1):
		t = i / n
		px = cx + (W * rng.uniform(0.18, 0.48)) * (1 if cx == 0 else -1) * (1 - t)
		py = cy + (H * rng.uniform(0.14, 0.38)) * (1 if cy == 0 else -1) * t
		pts.append((px, py))
	da.polygon(pts, fill=0)
	borda = ImageDraw.Draw(alfa)
	for _ in range(70):
		bx = rng.uniform(0, W)
		by = rng.choice([rng.uniform(0, H * 0.025), rng.uniform(H * 0.975, H)])
		r = rng.uniform(2, 10)
		borda.ellipse([bx - r, by - r, bx + r, by + r], fill=0)
	img.putalpha(Image.composite(alfa, Image.new("L", (W, H), 0), alfa))
	return img.resize((w, h), Image.LANCZOS)


def _ruido_fbm(w, h, oitavas, semente, base=4):
	"""Ruido de valor somado em oitavas, normalizado para usar toda a faixa 0..1."""
	rg = np.random.default_rng(semente)
	acc = np.zeros((h, w), dtype=np.float32)
	amp = 1.0
	soma = 0.0
	for o in range(oitavas):
		n = base * (2 ** o)
		g = rg.random((n + 1, n + 1)).astype(np.float32)
		peq = Image.fromarray((g * 255).astype(np.uint8), "L").resize((w, h), Image.BICUBIC)
		acc += np.asarray(peq, dtype=np.float32) / 255.0 * amp
		soma += amp
		amp *= 0.5
	acc /= soma
	lo, hi = float(acc.min()), float(acc.max())
	if hi - lo > 1e-5:
		acc = (acc - lo) / (hi - lo)
	return acc


def mancha(tam=(512, 512), cor=(30, 26, 22), dureza=0.5, corte=0.28, rng=None, alongar=1.0):
	"""Mancha organica."""
	rng = rng or random
	w, h = tam
	n = _ruido_fbm(w, h, 5, rng.randint(0, 1 << 30), base=3)
	yy, xx = np.mgrid[0:h, 0:w]
	fx = (xx / (w - 1.0) - 0.5) * 2.0
	fy = (yy / (h - 1.0) - 0.5) * 2.0 / max(alongar, 0.01)
	rad = np.sqrt(fx * fx + fy * fy)
	vinheta = np.clip(1.0 - rad ** 1.6, 0.0, 1.0)
	campo = (0.35 + 0.65 * n) * vinheta
	corte_ef = min(corte, 0.34)
	a = np.clip((campo - corte_ef) / max(1e-4, (1.0 - corte_ef)) * (1.2 + dureza * 2.5), 0.0, 1.0)
	rgb = np.zeros((h, w, 3), dtype=np.float32)
	sujeira = (n * 0.55 + 0.45)
	for c in range(3):
		rgb[:, :, c] = np.clip(cor[c] / 255.0 * sujeira * 1.35, 0.0, 1.0)
	out = np.zeros((h, w, 4), dtype=np.uint8)
	out[:, :, :3] = (rgb * 255).astype(np.uint8)
	out[:, :, 3] = (a * 255).astype(np.uint8)
	return Image.fromarray(out, "RGBA")


def escorrido_parede(tam=(256, 512), cor=(74, 52, 34), rng=None):
	"""Ferrugem/umidade descendo da parede."""
	rng = rng or random
	w, h = tam
	m = Image.new("L", (w, h), 0)
	d = ImageDraw.Draw(m)
	for _ in range(rng.randint(6, 14)):
		x = rng.uniform(w * 0.08, w * 0.92)
		topo = rng.uniform(0, h * 0.25)
		comp = rng.uniform(h * 0.3, h * 0.95)
		gr = rng.uniform(w * 0.01, w * 0.07)
		passos = int(comp / 3)
		for i in range(passos):
			t = i / max(1, passos - 1)
			y = topo + comp * t
			r = gr * (1.0 - t * 0.7) * rng.uniform(0.85, 1.15)
			d.ellipse([x - r, y - r, x + r, y + r], fill=int(230 * (1.0 - t * 0.55)))
			x += rng.uniform(-0.4, 0.4)
	m = m.filter(ImageFilter.GaussianBlur(w * 0.012))
	base = np.asarray(m, dtype=np.float32) / 255.0
	n = _ruido_fbm(w, h, 4, rng.randint(0, 1 << 30), base=3)
	a = np.clip(base * (0.55 + n * 0.9), 0.0, 1.0)
	rgb = np.zeros((h, w, 3), dtype=np.float32)
	for c in range(3):
		rgb[:, :, c] = np.clip(cor[c] / 255.0 * (0.6 + n * 0.8), 0.0, 1.0)
	out = np.zeros((h, w, 4), dtype=np.uint8)
	out[:, :, :3] = (rgb * 255).astype(np.uint8)
	out[:, :, 3] = (a * 255).astype(np.uint8)
	return Image.fromarray(out, "RGBA")


def tijolo_exposto(tam=(384, 384), rng=None):
	"""Reboco quebrado revelando tijolos velhos e argamassa escura."""
	rng = rng or random
	w, h = tam
	n = _ruido_fbm(w, h, 5, rng.randint(0, 1 << 30), base=3)
	yy, xx = np.mgrid[0:h, 0:w]
	fx = (xx / (w - 1.0) - 0.5) * 2.0
	fy = (yy / (h - 1.0) - 0.5) * 2.0
	rad = np.sqrt(fx * fx + fy * fy)
	vinheta = np.clip(1.0 - rad ** 1.7, 0.0, 1.0)
	campo = (0.38 + 0.62 * n) * vinheta
	mask_buraco = np.clip((campo - 0.28) * 5.0, 0.0, 1.0)
	borda_reboco = np.clip((campo - 0.21) * 6.5, 0.0, 1.0) - mask_buraco

	# padrao de tijolos dentro do buraco
	brick_h = h / 9.0
	brick_w = w / 4.5
	fila = np.floor(yy / brick_h)
	offset_x = (fila % 2) * (brick_w * 0.5)
	bx = (xx + offset_x) % brick_w
	by = yy % brick_h
	argamassa = (bx < 5.0) | (by < 4.5)

	rgb = np.zeros((h, w, 3), dtype=np.float32)
	cor_tijolo = np.array([108.0, 48.0, 34.0]) / 255.0
	cor_junta = np.array([34.0, 30.0, 28.0]) / 255.0
	cor_borda = np.array([52.0, 48.0, 44.0]) / 255.0
	var_tijolo = 0.75 + 0.5 * n
	for c in range(3):
		tij = np.where(argamassa, cor_junta[c], cor_tijolo[c] * var_tijolo)
		rgb[:, :, c] = np.clip(tij * mask_buraco + cor_borda[c] * borda_reboco, 0.0, 1.0)

	alfa = np.clip(mask_buraco + borda_reboco * 0.85, 0.0, 1.0)
	out = np.zeros((h, w, 4), dtype=np.uint8)
	out[:, :, :3] = (rgb * 255).astype(np.uint8)
	out[:, :, 3] = (alfa * 255).astype(np.uint8)
	return Image.fromarray(out, "RGBA")


def rachadura_superficie(tam=(384, 384), rng=None):
	"""Rachaduras ramificadas para parede ou asfalto."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	d = ImageDraw.Draw(m)

	def ramo(x, y, ang, comp, esp, prof):
		if prof <= 0 or comp < 10:
			return
		passos = max(4, int(comp / 14))
		pts = [(x, y)]
		cx, cy = x, y
		for _ in range(passos):
			ang += rng.uniform(-0.38, 0.38)
			passo = comp / passos
			cx += math.cos(ang) * passo
			cy += math.sin(ang) * passo
			pts.append((cx, cy))
			if rng.random() < 0.28 and prof > 1:
				ramo(cx, cy, ang + rng.choice([-1, 1]) * rng.uniform(0.4, 0.9), comp * 0.55, max(1.5, esp * 0.6), prof - 1)
		d.line(pts, fill=int(min(255, 160 + esp * 12)), width=int(max(1, esp)))

	cx, cy = W * 0.5, H * 0.5
	for k in range(rng.randint(3, 5)):
		ang = k * (math.tau / 4.0) + rng.uniform(-0.4, 0.4)
		ramo(cx, cy, ang, W * rng.uniform(0.32, 0.44), rng.uniform(5.0, 8.5), 3)

	m = m.resize((w, h), Image.LANCZOS)
	return _tinta(m, (20, 18, 18), variacao=0.12, rng=rng)


def poca_asfalto(tam=(496, 496), rng=None):
	"""Poca d'agua escura no asfalto com borda umida (brilha no shader com molhado=1)."""
	rng = rng or random
	w, h = tam
	n = _ruido_fbm(w, h, 5, rng.randint(0, 1 << 30), base=3)
	yy, xx = np.mgrid[0:h, 0:w]
	fx = (xx / (w - 1.0) - 0.5) * 2.0
	fy = (yy / (h - 1.0) - 0.5) * 2.0 / 1.25
	rad = np.sqrt(fx * fx + fy * fy)
	vinheta = np.clip(1.0 - rad ** 1.65, 0.0, 1.0)
	campo = (0.36 + 0.64 * n) * vinheta
	a = np.clip((campo - 0.25) * 5.0, 0.0, 1.0)
	borda = np.clip((campo - 0.25) * 10.0, 0.0, 1.0) * (1.0 - np.clip((campo - 0.33) * 8.0, 0.0, 1.0))
	rgb = np.zeros((h, w, 3), dtype=np.float32)
	# interior bem escuro (0.04..0.07) para ativar reflexo especular de agua no shader
	cor_agua = (0.04, 0.045, 0.055)
	cor_borda = (0.12, 0.11, 0.10)
	for c in range(3):
		rgb[:, :, c] = cor_agua[c] * (1.0 - borda) + cor_borda[c] * borda
	out = np.zeros((h, w, 4), dtype=np.uint8)
	out[:, :, :3] = (np.clip(rgb, 0.0, 1.0) * 255).astype(np.uint8)
	out[:, :, 3] = (a * 235).astype(np.uint8)
	return Image.fromarray(out, "RGBA")


def bueiro_asfalto(tam=(384, 384), rng=None):
	"""Tampao de ferro fundido de bueiro / esgoto na rua."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	cx, cy = W * 0.5, H * 0.5
	r_ext = W * 0.43
	r_int = W * 0.37
	# halo de sujeira/asfalto ao redor
	d.ellipse([cx - r_ext * 1.06, cy - r_ext * 1.06, cx + r_ext * 1.06, cy + r_ext * 1.06], fill=(20, 18, 18, 190))
	# anel externo de ferro
	d.ellipse([cx - r_ext, cy - r_ext, cx + r_ext, cy + r_ext], fill=(46, 42, 38, 250), outline=(24, 20, 18, 255), width=8)
	d.ellipse([cx - r_int, cy - r_int, cx + r_int, cy + r_int], fill=(34, 30, 28, 255), outline=(62, 54, 48, 255), width=6)
	# grade losangular / nervuras do ferro fundido
	passo = int(W * 0.075)
	for ofs in range(-int(r_int), int(r_int), passo):
		L = math.sqrt(max(0.0, r_int * r_int - ofs * ofs))
		d.line([(cx - L, cy + ofs), (cx + L, cy + ofs)], fill=(58, 50, 44, 255), width=6)
		d.line([(cx + ofs, cy - L), (cx + ofs, cy + L)], fill=(58, 50, 44, 255), width=6)
	# anel central e furos de alavanca
	d.ellipse([cx - r_int * 0.35, cy - r_int * 0.35, cx + r_int * 0.35, cy + r_int * 0.35], fill=(42, 36, 32, 255), outline=(66, 56, 48, 255), width=6)
	for s in (-1, 1):
		fx = cx + s * r_int * 0.72
		d.rectangle([fx - 12, cy - 22, fx + 12, cy + 22], fill=(12, 10, 10, 255))
	# ruido de ferrugem
	arr = np.asarray(img, dtype=np.float32)
	fbm = _ruido_fbm(W, H, 4, rng.randint(0, 1 << 30), base=4)
	arr[:, :, 0] = np.clip(arr[:, :, 0] * (0.8 + 0.55 * fbm), 0, 255)
	arr[:, :, 1] = np.clip(arr[:, :, 1] * (0.8 + 0.38 * fbm), 0, 255)
	arr[:, :, 2] = np.clip(arr[:, :, 2] * (0.8 + 0.25 * fbm), 0, 255)
	return Image.fromarray(arr.astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)


def jornais_chao(tam=(496, 496), rng=None):
	"""Folhas de jornal velho e panfletos pisoteados e sujos no chao."""
	rng = rng or random
	w, h = tam
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	for _ in range(rng.randint(3, 5)):
		pw, ph = int(w * rng.uniform(0.34, 0.50)), int(h * rng.uniform(0.26, 0.40))
		folha = Image.new("RGBA", (pw, ph), (168, 160, 142, 235))
		df = ImageDraw.Draw(folha)
		df.rectangle([8, 8, pw - 8, int(ph * 0.22)], fill=(54, 50, 46, 235))
		df.rectangle([8, int(ph * 0.28), int(pw * 0.46), int(ph * 0.76)], fill=(86, 80, 74, 235))
		for ly in range(int(ph * 0.28), ph - 10, 10):
			df.line([(int(pw * 0.52), ly), (pw - 10, ly)], fill=(62, 58, 54, 220), width=4)
		# manchar a folha
		arr = np.asarray(folha, dtype=np.float32)
		fbm = _ruido_fbm(pw, ph, 3, rng.randint(0, 1 << 30), base=3)
		for c in range(3):
			arr[:, :, c] = np.clip(arr[:, :, c] * (0.55 + 0.55 * fbm), 0, 255)
		folha = Image.fromarray(arr.astype(np.uint8), "RGBA")
		folha = folha.rotate(rng.uniform(-180, 180), expand=True, resample=Image.BICUBIC)
		ox = int(rng.uniform(w * 0.08, max(w * 0.09, w - folha.width - w * 0.08)))
		oy = int(rng.uniform(h * 0.08, max(h * 0.09, h - folha.height - h * 0.08)))
		img.alpha_composite(folha, (ox, oy))
	return img


# ---------------------------------------------------------------------------
# catalogo: o que desenhar, e como cada coisa entra na cidade
# ---------------------------------------------------------------------------
def catalogo(rng):
	itens = []

	def add(nome, img, papel, largura, peso, atlas="parede"):
		itens.append({"n": nome, "img": img, "papel": papel,
					  "largura": largura, "peso": peso, "atlas": atlas})

	# --- pixacao: nomes proprios da lore, datas, codigos e siglas --------
	for nome, txt, peso, cor in [
		("tag_arorua", "ARORUA", 8, (142, 32, 28)),
		("tag_antilopes", "ANTI-LOPES", 8, (22, 20, 24)),
		("tag_calixto", "CALIXTO", 6, (132, 28, 24)),
		("tag_kraycik", "KRAYCIK", 6, (152, 118, 42)),
		("tag_jimmy", "JIMMY?", 7, (172, 166, 156)),
		("tag_1994", "1994", 6, (142, 32, 28)),
		("tag_husker", "HUSKER", 5, (38, 50, 94)),
		("tag_cobalt", "COBALT", 4, (164, 160, 152)),
		("tag_lopes", "LOPES", 4, None),
		("tag_maycow", "MAYCOW", 3, None),
		("tag_nice", "NICE", 3, None),
		("tag_bica", "BICA", 4, None),
		("tag_rv", "RV-94", 6, (148, 34, 28)),
		("tag_al", "AL", 5, None),
		("tag_13", "13", 4, None),
		("tag_0000", "00:00", 5, (168, 162, 152)),
		("tag_666", "666", 4, (124, 24, 22)),
		("tag_xix", "XIX", 3, None),
	]:
		largo = 0.5 + len(txt) * 0.34
		add(nome, pixacao(txt, (512, 256), rng, cor=cor), "pichacao", [largo * 0.75, largo * 1.25], peso)

	# pichacoes no alto das fachadas (quem subiu no telhado/marquise)
	add("alto_antilopes", pixacao("ANTI-LOPES", (512, 256), rng, cor=(20, 18, 22)), "alto", [3.4, 5.2], 5)
	add("alto_arorua", pixacao("ARORUA", (512, 256), rng, cor=(144, 30, 26)), "alto", [2.6, 4.2], 4)
	add("alto_kraycik", pixacao("KRAYCIK", (512, 256), rng, cor=(164, 158, 148)), "alto", [2.8, 4.4], 4)
	add("alto_1994", pixacao("1994", (512, 256), rng, cor=(144, 30, 26)), "alto", [2.0, 3.2], 3)

	# --- bombas (throw-ups visiveis de longe) ----------------------------
	add("bomba_rv", bomba("RV", (512, 384), rng, preenche=(148, 42, 36)), "pichacao", [2.2, 3.4], 5)
	add("bomba_al", bomba("AL", (512, 384), rng, preenche=(162, 154, 136)), "pichacao", [2.2, 3.4], 4)
	add("bomba_94", bomba("94", (512, 384), rng, preenche=(148, 120, 44)), "pichacao", [2.0, 3.2], 4)
	add("bomba_xis", bomba("X", (384, 384), rng), "pichacao", [1.4, 2.2], 3)

	# --- simbolos e marcas da lore ---------------------------------------
	add("simb_engrenagem", simbolo_engrenagem((256, 256), rng), "pichacao", [0.8, 1.6], 6)
	add("simb_valvula", simbolo_valvula((256, 256), rng), "pichacao", [0.85, 1.6], 7)
	add("simb_olho", simbolo_olho((256, 256), rng), "pichacao", [0.75, 1.4], 6)
	add("simb_vizinho", simbolo_vizinho((256, 384), rng), "pichacao", [0.9, 1.5], 5)
	add("simb_abismo", simbolo_cruz_abismo((256, 256), rng), "pichacao", [0.8, 1.5], 5)
	add("simb_perigo", simbolo_perigo((256, 256), rng), "pichacao", [0.7, 1.2], 5)
	add("simb_contagem", marcas_contagem((384, 256), rng), "pichacao", [0.9, 1.7], 6)
	add("simb_engrenagem_alto", simbolo_engrenagem((256, 256), rng), "alto", [1.3, 2.3], 3)
	add("simb_olho_alto", simbolo_olho((256, 256), rng), "alto", [1.3, 2.2], 3)

	# --- rabiscos --------------------------------------------------------
	add("risco_01", rabisco((512, 256), rng), "pichacao", [1.4, 2.8], 5)
	add("risco_02", rabisco((512, 256), rng), "pichacao", [1.4, 2.8], 5)

	# --- cartazes rasgados (desaparecido, interditado, lambe-lambe) ------
	for i in range(5):
		add("cartaz_%02d" % (i + 1), cartaz((256, 384), rng, variante=i), "cartaz", [0.36, 0.56], 6)

	# --- manchas, tijolo exposto e rachaduras de parede ------------------
	add("escorrido_ferrugem", escorrido_parede((256, 512), (82, 44, 24), rng), "mancha_parede", [1.0, 2.5], 8)
	add("escorrido_umidade", escorrido_parede((256, 512), (38, 44, 36), rng), "mancha_parede", [1.2, 2.8], 8)
	add("escorrido_fuligem", escorrido_parede((256, 512), (20, 18, 18), rng), "mancha_parede", [1.0, 2.4], 6)
	add("mancha_reboco", mancha((512, 512), (46, 42, 36), 0.35, 0.42, rng), "mancha_parede", [1.4, 3.0], 6)
	add("parede_tijolo", tijolo_exposto((384, 384), rng), "mancha_parede", [1.1, 2.2], 7)
	add("parede_rachadura", rachadura_superficie((384, 384), rng), "mancha_parede", [1.2, 2.5], 7)

	# --- manchas, pocas, bueiros, rachaduras e jornais no chao -----------
	add("chao_terra", mancha((496, 496), (52, 42, 30), 0.3, 0.44, rng, alongar=1.3),
		"mancha_chao", [1.6, 3.6], 9, atlas="chao")
	add("chao_limo", mancha((496, 496), (34, 46, 28), 0.35, 0.48, rng, alongar=1.1),
		"mancha_chao", [1.2, 2.8], 7, atlas="chao")
	add("chao_ferrugem", mancha((496, 496), (72, 30, 22), 0.45, 0.48, rng, alongar=1.2),
		"mancha_chao", [1.0, 2.2], 6, atlas="chao")
	add("chao_jornais", jornais_chao((496, 496), rng),
		"mancha_chao", [0.9, 1.6], 7, atlas="chao")
	add("rua_oleo", mancha((496, 496), (14, 14, 16), 0.65, 0.48, rng, alongar=1.6),
		"mancha_rua", [1.2, 2.6], 8, atlas="chao")
	add("rua_poca_01", poca_asfalto((496, 496), rng),
		"mancha_rua", [1.8, 3.8], 10, atlas="chao")
	add("rua_poca_02", poca_asfalto((496, 496), rng),
		"mancha_rua", [1.4, 3.2], 9, atlas="chao")
	add("rua_queimado", mancha((496, 496), (24, 20, 18), 0.5, 0.52, rng, alongar=1.0),
		"mancha_rua", [0.9, 2.0], 5, atlas="chao")
	add("rua_rachadura", rachadura_superficie((496, 496), rng),
		"mancha_rua", [1.4, 3.0], 8, atlas="chao")
	add("rua_bueiro", bueiro_asfalto((384, 384), rng),
		"mancha_rua", [0.85, 1.05], 6, atlas="chao")
	add("rua_jornais", jornais_chao((496, 496), rng),
		"mancha_rua", [0.85, 1.5], 5, atlas="chao")
	return itens


# ---------------------------------------------------------------------------
# empacotamento: prateleira simples, do mais alto pro mais baixo
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


def _arredonda(v, passo=64):
	return ((v + passo - 1) // passo) * passo


def montar(itens, nome_atlas, largura):
	sub = [it for it in itens if it["atlas"] == nome_atlas]
	pos, usado = empacotar(sub, largura)
	altura = _arredonda(usado)
	atlas = Image.new("RGBA", (largura, altura), (0, 0, 0, 0))
	manifesto = []
	for it in sub:
		x, y = pos[it["n"]]
		w, h = it["img"].size
		atlas.alpha_composite(it["img"], (x, y))
		manifesto.append({
			"n": it["n"],
			"atlas": nome_atlas,
			"papel": it["papel"],
			"uv": [round(x / largura, 6), round(y / altura, 6),
				   round(w / largura, 6), round(h / altura, 6)],
			"px": [w, h],
			"largura": it["largura"],
			"peso": it["peso"],
		})
	return atlas, manifesto


def main():
	rng = random.Random(SEMENTE)
	os.makedirs(SAIDA, exist_ok=True)
	itens = catalogo(rng)

	manifesto = []
	for nome, largura in (("parede", 2048), ("chao", 2048)):
		atlas, man = montar(itens, nome, largura)
		caminho = os.path.join(SAIDA, "pichacao_%s.png" % nome)
		atlas.save(caminho)
		manifesto += man
		print("  %-28s %dx%d  %d artes  %.1f KB" % (
			os.path.basename(caminho), atlas.width, atlas.height, len(man),
			os.path.getsize(caminho) / 1024.0))

	manifesto.sort(key=lambda m: (m["papel"], m["n"]))
	saida = {
		"nota": "gerado por tools/texturas/gerar_pichacao.py — nao editar a mao",
		"atlas": {
			"parede": RES_ATLAS % "pichacao_parede.png",
			"chao": RES_ATLAS % "pichacao_chao.png",
		},
		"artes": manifesto,
	}
	with open(os.path.join(SAIDA, "pichacao.json"), "w", encoding="utf-8") as f:
		json.dump(saida, f, ensure_ascii=False, indent=1)
	print("  pichacao.json                %d artes" % len(manifesto))


if __name__ == "__main__":
	main()
