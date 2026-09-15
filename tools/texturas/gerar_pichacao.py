"""Desenha os atlas de pichacao, cartaz e mancha da cidade da stage_1.

Rodar (python do sistema, precisa de Pillow e numpy):

    python3 tools/texturas/gerar_pichacao.py

Saida: red-valve/assets/images/textures/pichacao/
    pichacao_parede.png   2048x2048 RGBA — tudo que vai em parede
    pichacao_chao.png     1024x1024 RGBA — tudo que vai no chao
    pichacao.json         manifesto: onde cada arte esta no atlas e como usa-la

==============================================================================
POR QUE ATLAS, E NAO UMA TEXTURA POR ARTE

Cada pichacao no jogo e' um quad de dois triangulos colado na fachada. Se cada
desenho fosse uma textura propria, cada desenho seria um material proprio e uma
chamada de desenho propria: 30 desenhos x 25 blocos da cidade = 750 chamadas so
de rabisco. Com atlas, os 30 desenhos dividem UM material, entao o bloco
inteiro cabe num MultiMesh de uma chamada so. Qual pedaco do atlas cada
instancia usa vai no custom data do MultiMesh (INSTANCE_CUSTOM), lido pelo
shader `pichacao.gdshader`.

E' por isso que este script cospe um JSON junto: o retangulo UV de cada arte
nao da' pra adivinhar do lado do Godot.

==============================================================================
POR QUE OS DESENHOS NAO TEM FRASE NENHUMA

A diretriz do projeto manda todo texto do jogo entrar nos CSV e sair traduzido.
Texto assado dentro de uma imagem nao tem como ser traduzido. Entao aqui so
entra o que e' igual nas duas linguas: nome proprio (ARORUA, CALIXTO,
ANTI-LOPES, MAYCOW, NICE, BICA), sigla, numero e rabisco ilegivel. Os cartazes
seguem a mesma regra — o texto deles e' BARRA CINZA, que e' exatamente o que o
olho le num cartaz rasgado a cinco metros de distancia.

==============================================================================
COMO A PIXACAO E' DESENHADA

Pixacao brasileira nao e' fonte: e' traco reto, alto e estreito, derivado de
runa e de letra gotica. Entao cada letra aqui e' uma lista de POLILINHAS num
quadrado 0..1 (y=0 em cima), desenhada com bico grosso. O alfabeto esta em
ALFABETO, e a altura util e' ~2,4x a largura da letra — e' essa proporcao que
faz o rabisco parecer pixacao e nao letra de forma.

O bico do spray e' feito em tres passadas:
    1. traco solido, que e' o que sobrevive ao alpha scissor de perto;
    2. respingo ao redor, que quebra a borda reta;
    3. escorrido, que sai de baixo de alguns vertices.
Sem o passo 1 o desenho some quando o shader corta o alfa; sem o 2 e o 3 fica
com cara de adesivo.
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

# Tinta de spray de rua: preto de fumaca, prata, azul de caneta, vermelho
# oxidado. Nada saturado — na cidade com neblina e LUT sepia, cor pura brilha
# mais que o poste.
TINTAS = [
	(18, 16, 18),     # preto fumaca
	(28, 26, 30),     # preto lavado
	(150, 148, 146),  # prata
	(34, 44, 86),     # azul caneta
	(120, 30, 28),    # vermelho oxido
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
	# ponta redonda: o joint="curve" so arredonda as juntas, nao as pontas
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
			# distancia com cara de gauss: perto do traco e' denso, longe e' raro
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
		comp = rng.uniform(largura * 1.5, largura * 7.0) * alcance
		grossura = max(1.0, largura * rng.uniform(0.12, 0.3))
		passos = max(2, int(comp / 3))
		for i in range(passos):
			t = i / float(passos - 1)
			gy = y + comp * t
			gr = grossura * (1.0 - t * 0.55)
			d.ellipse([x - gr, gy - gr, x + gr, gy + gr], fill=int(255 * (1.0 - t * 0.35)))
		# a bolinha que acumula na ponta
		d.ellipse([x - grossura, y + comp - grossura, x + grossura, y + comp + grossura], fill=210)


def _tinta(mascara, cor, variacao=0.16, rng=None):
	"""Mascara em L -> RGBA colorido. A variacao suja a cor pixel a pixel pra a
	pichacao nao virar um decalque chapado."""
	a = np.asarray(mascara, dtype=np.float32) / 255.0
	h, w = a.shape
	rgb = np.zeros((h, w, 3), dtype=np.float32)
	if rng is not None:
		semente = rng.randint(0, 1 << 30)
	else:
		semente = 0
	ruido = np.random.default_rng(semente).normal(0.0, variacao, (h, w, 1)).astype(np.float32)
	for c in range(3):
		rgb[:, :, c] = np.clip(cor[c] / 255.0 * (1.0 + ruido[:, :, 0]), 0.0, 1.0)
	out = np.zeros((h, w, 4), dtype=np.uint8)
	out[:, :, :3] = (rgb * 255).astype(np.uint8)
	out[:, :, 3] = (a * 255).astype(np.uint8)
	return Image.fromarray(out, "RGBA")


# ---------------------------------------------------------------------------
# artes
# ---------------------------------------------------------------------------
def pixacao(texto, tam=(512, 256), rng=None, cor=None, bico=None, inclina=True):
	"""Uma linha de pixacao. As letras encostam umas nas outras de proposito:
	pixacao real e' assim, sem espaco entre letra."""
	rng = rng or random
	cor = cor or rng.choice(TINTAS)
	w, h = tam
	m = Image.new("L", (w * 2, h * 2), 0)   # 2x e reduz depois: antialias barato
	W, H = w * 2, h * 2
	margem = H * 0.14
	alt = H - margem * 2
	larg_letra = alt / 2.45                  # a proporcao que faz virar pixacao
	n = len(texto)
	total = larg_letra * n
	escala = min(1.0, (W - margem * 2) / max(total, 1.0))
	larg_letra *= escala
	alt *= escala
	bico = bico or max(3.0, alt * 0.085)
	x0 = (W - larg_letra * n) * 0.5
	y0 = (H - alt) * 0.5
	traços = []
	for i, ch in enumerate(texto.upper()):
		glifo = ALFABETO.get(ch)
		if glifo is None:
			continue
		# cada letra torta pro seu lado: a "serifa" da pixacao e' o erro da mao
		incl = rng.uniform(-0.1, 0.1) if inclina else 0.0
		dy = rng.uniform(-alt * 0.03, alt * 0.03)
		for poli in glifo:
			pts = []
			for (gx, gy) in poli:
				px = x0 + (i + gx) * larg_letra + (0.5 - gy) * incl * larg_letra * 2.0
				py = y0 + dy + gy * alt
				pts.append((px, py))
			traços.append(_linha(m, pts, bico, jitter=bico * 0.22, rng=rng))
	for pts in traços:
		_respingo(m, pts, bico, rng)
	for pts in traços:
		_escorrido(m, pts, bico, rng, chance=0.22)
	m = m.resize((w, h), Image.LANCZOS)
	return _tinta(m, cor, rng=rng)


def bomba(texto, tam=(512, 384), rng=None):
	"""Throw-up: letra gorda de duas cores, contorno grosso e brilho. E' o que
	se ve de longe — a pixacao fina some a 15 m, a bomba nao."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	preenche = rng.choice([(158, 150, 132), (132, 52, 44), (58, 68, 112), (146, 124, 52)])
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
	# o contorno e' a casca: fora menos dentro
	fora = np.asarray(m_fora, dtype=np.int16)
	dentro = np.asarray(m_dentro, dtype=np.int16)
	casca = np.clip(fora - dentro, 0, 255).astype(np.uint8)

	rgba = np.zeros((H, W, 4), dtype=np.uint8)
	for c in range(3):
		rgba[:, :, c] = np.where(dentro > 120, preenche[c], contorno[c])
	rgba[:, :, 3] = np.maximum(casca, dentro).astype(np.uint8)

	img = Image.fromarray(rgba, "RGBA")
	# escorrido por cima de tudo, na cor do contorno
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
	"""Volante de valvula: o simbolo do titulo, virado marca de rua."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	m = Image.new("L", (W, H), 0)
	cx, cy = W * 0.5, H * 0.5
	r = W * 0.33
	bico = W * 0.04
	aro = [(cx + math.cos(i / 28 * math.tau) * r * rng.uniform(0.95, 1.05),
			cy + math.sin(i / 28 * math.tau) * r * rng.uniform(0.95, 1.05)) for i in range(29)]
	tracos = [_linha(m, aro, bico, jitter=bico * 0.25, rng=rng)]
	for k in range(3):
		a = k / 3.0 * math.pi
		tracos.append(_linha(m, [(cx - math.cos(a) * r, cy - math.sin(a) * r),
								 (cx + math.cos(a) * r, cy + math.sin(a) * r)],
							 bico * 0.75, jitter=bico * 0.25, rng=rng))
	for t in tracos:
		_respingo(m, t, bico, rng)
	_escorrido(m, aro[::4], bico, rng, chance=0.2)
	return _tinta(m.resize((w, h), Image.LANCZOS), (150, 40, 34), rng=rng)


def simbolo_olho(tam=(256, 256), rng=None):
	"""Olho: o que os moradores desenham quando a cidade comeca a olhar de volta."""
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
	d.ellipse([cx - W * 0.05, cy - W * 0.05, cx + W * 0.05, cy + W * 0.05], fill=255)
	for t in tracos:
		_respingo(m, t, bico, rng)
	_escorrido(m, baixo[::5], bico, rng, chance=0.3)
	return _tinta(m.resize((w, h), Image.LANCZOS), rng.choice(TINTAS), rng=rng)


def rabisco(tam=(512, 256), rng=None):
	"""Risco sem palavra nenhuma: o que sobra quando alguem passa o spray so
	pra apagar o que estava escrito."""
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


def cartaz(tam=(256, 384), rng=None):
	"""Cartaz colado no poste, ja rasgado. O texto e' BARRA CINZA de proposito
	(ver o cabecalho): a cinco metros e' isso que o olho enxerga mesmo."""
	rng = rng or random
	w, h = tam
	W, H = w * 2, h * 2
	papel = rng.choice([(206, 198, 178), (188, 182, 170), (198, 186, 152), (176, 174, 176)])
	img = Image.new("RGBA", (W, H), papel + (255,))
	d = ImageDraw.Draw(img)
	tinta = (52, 48, 46)
	destaque = rng.choice([(150, 40, 34), (40, 52, 110), (52, 48, 46)])

	m = H * 0.07
	y = m
	# faixa de titulo
	d.rectangle([m, y, W - m, y + H * 0.1], fill=destaque)
	y += H * 0.14
	# bloco de imagem (silhueta chapada, tipo foto 3x4 xerocada)
	if rng.random() < 0.7:
		bh = H * rng.uniform(0.2, 0.3)
		d.rectangle([m * 1.6, y, W - m * 1.6, y + bh], fill=(120, 116, 112))
		cx = W * 0.5
		d.ellipse([cx - bh * 0.17, y + bh * 0.12, cx + bh * 0.17, y + bh * 0.46], fill=(70, 66, 64))
		d.pieslice([cx - bh * 0.3, y + bh * 0.42, cx + bh * 0.3, y + bh * 1.1], 180, 360, fill=(70, 66, 64))
		y += bh + H * 0.05
	# linhas de texto
	while y < H - m * 2.2:
		lw = (W - m * 2) * rng.uniform(0.45, 1.0)
		d.rectangle([m, y, m + lw, y + H * 0.018], fill=tinta)
		y += H * 0.038
	# franjinha de destaque embaixo, tipo telefone recortado
	fy = H - m * 1.8
	for i in range(8):
		fx = m + (W - m * 2) / 8 * i
		d.rectangle([fx + 2, fy, fx + (W - m * 2) / 8 - 4, H - m * 0.4], fill=(160, 154, 142))

	# envelhecer: mancha, amassado e rasgo
	suj = np.asarray(img, dtype=np.float32)
	ruido = np.random.default_rng(rng.randint(0, 1 << 30)).normal(1.0, 0.07, (H, W, 1))
	suj[:, :, :3] = np.clip(suj[:, :, :3] * ruido, 0, 255)
	img = Image.fromarray(suj.astype(np.uint8), "RGBA")

	# rasgo: alfa 0 num canto, com borda irregular
	alfa = Image.new("L", (W, H), 255)
	da = ImageDraw.Draw(alfa)
	canto = rng.randint(0, 3)
	cx = 0 if canto in (0, 2) else W
	cy = 0 if canto in (0, 1) else H
	pts = [(cx, cy)]
	n = 7
	for i in range(n + 1):
		t = i / n
		px = cx + (W * rng.uniform(0.2, 0.5) - 0) * (1 if cx == 0 else -1) * (1 - t)
		py = cy + (H * rng.uniform(0.15, 0.4)) * (1 if cy == 0 else -1) * t
		pts.append((px, py))
	da.polygon(pts, fill=0)
	# a borda do papel nunca e' reta
	borda = ImageDraw.Draw(alfa)
	for _ in range(60):
		bx = rng.uniform(0, W)
		by = rng.choice([rng.uniform(0, H * 0.02), rng.uniform(H * 0.98, H)])
		r = rng.uniform(2, 9)
		borda.ellipse([bx - r, by - r, bx + r, by + r], fill=0)
	img.putalpha(Image.composite(alfa, Image.new("L", (W, H), 0), alfa))
	return img.resize((w, h), Image.LANCZOS)


def _ruido_fbm(w, h, oitavas, semente, base=4):
	"""Ruido de valor somado em oitavas. Serve de base pra toda mancha."""
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
	return acc / soma


def mancha(tam=(512, 512), cor=(30, 26, 22), dureza=0.5, corte=0.5, rng=None, alongar=1.0):
	"""Mancha organica: fbm cortado numa altura, com as bordas suavizadas e
	uma vinheta radial pra a mancha nao encostar na borda do quad."""
	rng = rng or random
	w, h = tam
	n = _ruido_fbm(w, h, 5, rng.randint(0, 1 << 30), base=3)
	yy, xx = np.mgrid[0:h, 0:w]
	fx = (xx / (w - 1.0) - 0.5) * 2.0
	fy = (yy / (h - 1.0) - 0.5) * 2.0 / max(alongar, 0.01)
	rad = np.sqrt(fx * fx + fy * fy)
	vinheta = np.clip(1.0 - rad, 0.0, 1.0) ** 1.4
	campo = n * vinheta
	a = np.clip((campo - corte) / max(1e-4, (1.0 - corte)) * (1.0 + dureza * 3.0), 0.0, 1.0)
	rgb = np.zeros((h, w, 3), dtype=np.float32)
	sujeira = (n * 0.5 + 0.5)
	for c in range(3):
		rgb[:, :, c] = np.clip(cor[c] / 255.0 * sujeira * 1.4, 0.0, 1.0)
	out = np.zeros((h, w, 4), dtype=np.uint8)
	out[:, :, :3] = (rgb * 255).astype(np.uint8)
	out[:, :, 3] = (a * 255).astype(np.uint8)
	return Image.fromarray(out, "RGBA")


def escorrido_parede(tam=(256, 512), cor=(74, 52, 34), rng=None):
	"""Ferrugem/umidade descendo da parede. Vertical de proposito: e' a marca
	que mais aparece em fachada de reboco velho."""
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


# ---------------------------------------------------------------------------
# catalogo: o que desenhar, e como cada coisa entra na cidade
# ---------------------------------------------------------------------------
# papel  — onde a arte pode nascer (o .gd le isto):
#   pichacao      parede de casa, na altura do braco
#   alto          parede de casa, alto (quem subiu de escada)
#   mancha_parede rodape da parede: umidade, ferrugem
#   cartaz        colado em poste
#   mancha_chao   calcada e terreno
#   mancha_rua    asfalto (oleo, queimado)
# largura — faixa de largura em METROS no mundo.
def catalogo(rng):
	itens = []

	def add(nome, img, papel, largura, peso, atlas="parede"):
		itens.append({"n": nome, "img": img, "papel": papel,
					  "largura": largura, "peso": peso, "atlas": atlas})

	# --- pixacao: so nome proprio, sigla e numero ------------------------
	for nome, txt, peso in [
		("tag_arorua", "ARORUA", 7),
		("tag_antilopes", "ANTI-LOPES", 8),
		("tag_calixto", "CALIXTO", 5),
		("tag_lopes", "LOPES", 4),
		("tag_maycow", "MAYCOW", 3),
		("tag_nice", "NICE", 3),
		("tag_bica", "BICA", 4),
		("tag_rv", "RV", 6),
		("tag_al", "AL", 5),
		("tag_13", "13", 4),
		("tag_171", "171", 3),
		("tag_xv", "XV", 3),
	]:
		largo = 0.5 + len(txt) * 0.34
		add(nome, pixacao(txt, (512, 256), rng), "pichacao", [largo * 0.75, largo * 1.25], peso)

	# duas repetidas la' em cima, onde so chega quem subiu
	add("alto_antilopes", pixacao("ANTI-LOPES", (512, 256), rng), "alto", [3.4, 5.2], 4)
	add("alto_arorua", pixacao("ARORUA", (512, 256), rng), "alto", [2.6, 4.0], 3)

	# --- bombas ----------------------------------------------------------
	add("bomba_rv", bomba("RV", (512, 384), rng), "pichacao", [2.2, 3.4], 4)
	add("bomba_al", bomba("AL", (512, 384), rng), "pichacao", [2.2, 3.4], 4)
	add("bomba_xis", bomba("X", (384, 384), rng), "pichacao", [1.4, 2.2], 3)

	# --- simbolos --------------------------------------------------------
	add("simb_engrenagem", simbolo_engrenagem((256, 256), rng), "pichacao", [0.8, 1.6], 6)
	add("simb_valvula", simbolo_valvula((256, 256), rng), "pichacao", [0.8, 1.5], 5)
	add("simb_olho", simbolo_olho((256, 256), rng), "pichacao", [0.7, 1.3], 4)
	add("simb_engrenagem_alto", simbolo_engrenagem((256, 256), rng), "alto", [1.2, 2.2], 3)

	# --- rabiscos --------------------------------------------------------
	add("risco_01", rabisco((512, 256), rng), "pichacao", [1.4, 2.8], 6)
	add("risco_02", rabisco((512, 256), rng), "pichacao", [1.4, 2.8], 6)

	# --- cartaz no poste -------------------------------------------------
	for i in range(3):
		add("cartaz_%02d" % (i + 1), cartaz((256, 384), rng), "cartaz", [0.32, 0.46], 6)

	# --- mancha de parede ------------------------------------------------
	add("escorrido_ferrugem", escorrido_parede((256, 512), (78, 44, 24), rng), "mancha_parede", [1.0, 2.4], 8)
	add("escorrido_umidade", escorrido_parede((256, 512), (48, 52, 44), rng), "mancha_parede", [1.2, 2.8], 8)
	add("mancha_reboco", mancha((512, 512), (46, 42, 36), 0.35, 0.42, rng), "mancha_parede", [1.4, 3.0], 6)

	# --- mancha de chao (atlas proprio) ----------------------------------
	add("chao_terra", mancha((496, 496), (52, 42, 30), 0.3, 0.44, rng, alongar=1.3),
		"mancha_chao", [1.6, 3.6], 10, atlas="chao")
	add("chao_limo", mancha((496, 496), (38, 48, 32), 0.35, 0.48, rng, alongar=1.1),
		"mancha_chao", [1.2, 2.8], 7, atlas="chao")
	add("rua_oleo", mancha((496, 496), (16, 15, 17), 0.6, 0.5, rng, alongar=1.6),
		"mancha_rua", [1.0, 2.4], 9, atlas="chao")
	add("rua_queimado", mancha((496, 496), (24, 20, 18), 0.5, 0.52, rng, alongar=1.0),
		"mancha_rua", [0.8, 1.8], 5, atlas="chao")
	return itens


# ---------------------------------------------------------------------------
# empacotamento: prateleira simples, do mais alto pro mais baixo
# ---------------------------------------------------------------------------
def empacotar(itens, largura, margem=4):
	"""Prateleira simples, do mais alto pro mais baixo. Devolve
	({nome: (x, y)}, altura_usada). A margem evita que o mipmap do atlas
	sangre a arte vizinha pra dentro do quad."""
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
	"""A altura do atlas sai do empacotamento, arredondada pra cima num
	multiplo de 64. Potencia de dois desperdicaria metade do arquivo: com 29
	artes a prateleira para em ~2,3 mil px e o proximo degrau seria 4096."""
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
