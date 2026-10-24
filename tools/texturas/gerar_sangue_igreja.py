# -*- coding: utf-8 -*-
"""Texturas de decalque da cena da igreja: sangue, o simbolo do culto e a gosma.

    python3 tools/texturas/gerar_sangue_igreja.py

Salva em red-valve/assets/images/textures/igreja/:

  sangue_poca.png        poca grande, borda irregular, centro mais escuro
  sangue_respingo.png    respingos e gotas espalhados (impacto, faca)
  sangue_rastro.png      rastro escorrido (onde o corpo foi arrastado)
  simbolo_culto.png      circulo com runas, pintado a dedo em sangue seco
  gosma_verde.png        poca de baba verde da fase 2 (com bolhas)
  *_orm.png              rugosidade dos mesmos: sangue fresco e gosma brilham

Tudo com alfa (Decal do Godot usa o alfa do albedo). Sem palavra nenhuma na
textura (as runas sao inventadas). Deterministico: semente fixa.
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "red-valve/assets/images/textures/igreja")
N = 1024
rnd = random.Random(666)
np_rng = np.random.default_rng(666)


def ruido(n, escala, oitavas=5):
    """Ruido de valor em camadas, 0..1, n x n."""
    out = np.zeros((n, n), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(oitavas):
        k = max(2, int(escala * 2 ** o))
        g = np_rng.random((k + 1, k + 1)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
        out += np.asarray(im, np.float32) / 255 * amp
        tot += amp
        amp *= 0.5
    return out / tot


def mancha(n, raio, escala=3.0, aspereza=0.35, cx=0.5, cy=0.5):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) / n
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / raio
    return (d + (ruido(n, escala) - 0.5) * aspereza * 2) < 1.0


def salvar(nome, rgba, rug):
    os.makedirs(SAIDA, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(os.path.join(SAIDA, nome + ".png"))
    orm = np.zeros((rgba.shape[0], rgba.shape[1], 3), np.uint8)
    orm[..., 0] = 255                       # oclusao
    orm[..., 1] = (rug * 255).astype(np.uint8)
    orm[..., 2] = 0                         # metal
    Image.fromarray(orm, "RGB").save(os.path.join(SAIDA, nome + "_orm.png"))
    print("  " + nome)


def cor_sangue(n, molhado):
    base = np.zeros((n, n, 3), np.float32)
    v = ruido(n, 6)
    base[..., 0] = 0.20 + 0.16 * v * molhado
    base[..., 1] = 0.005
    base[..., 2] = 0.01 + 0.015 * v
    return base


def poca():
    m = mancha(N, 0.36, 2.5, 0.45).astype(np.float32)
    # bracos que escorreram pelas juntas do piso
    for _ in range(7):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.25, 0.33)
        m = np.maximum(m, mancha(N, rnd.uniform(0.05, 0.11), 4, 0.5,
                                 0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r))
    alfa = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(2.5)), np.float32) / 255
    # borda mais escura e seca, centro molhado
    dist = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(28)), np.float32) / 255
    rgb = cor_sangue(N, 1.0) * (0.55 + 0.6 * dist[..., None])
    rgba = np.zeros((N, N, 4), np.uint8)
    rgba[..., :3] = np.clip(rgb * 255, 0, 255)
    rgba[..., 3] = np.clip(alfa * 245, 0, 255)
    salvar("sangue_poca", rgba, 0.08 + 0.5 * (1 - dist))


def respingo():
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    for _ in range(90):
        a = rnd.uniform(0, math.tau)
        r = abs(rnd.gauss(0, 0.2)) * N
        x, y = N / 2 + math.cos(a) * r, N / 2 + math.sin(a) * r
        s = max(2, rnd.expovariate(1 / 14) * (1.0 - r / N))
        d.ellipse((x - s, y - s, x + s, y + s), fill=255)
        if rnd.random() < 0.5:   # cauda do respingo, pra fora
            c = s * rnd.uniform(2, 5)
            d.line((x, y, x + math.cos(a) * c, y + math.sin(a) * c), fill=255,
                   width=max(1, int(s * 0.6)))
    d.ellipse((N * 0.42, N * 0.42, N * 0.58, N * 0.58), fill=255)
    alfa = np.asarray(img.filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
    rgba = np.zeros((N, N, 4), np.uint8)
    rgba[..., :3] = np.clip(cor_sangue(N, 1.0) * 255, 0, 255)
    rgba[..., 3] = (alfa * 240).astype(np.uint8)
    salvar("sangue_respingo", rgba, np.full((N, N), 0.12, np.float32))


def rastro():
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    for k in range(5):
        x0 = N * (0.38 + k * 0.06) + rnd.uniform(-10, 10)
        pts = []
        for i in range(30):
            t = i / 29
            pts.append((x0 + math.sin(t * 7 + k) * 18, N * (0.05 + 0.9 * t)))
        d.line(pts, fill=int(140 + rnd.random() * 115), width=rnd.randint(12, 38))
    alfa = np.asarray(img.filter(ImageFilter.GaussianBlur(4)), np.float32) / 255
    alfa *= 0.35 + 0.65 * ruido(N, 8)
    rgba = np.zeros((N, N, 4), np.uint8)
    rgba[..., :3] = np.clip(cor_sangue(N, 0.6) * 0.8 * 255, 0, 255)
    rgba[..., 3] = np.clip(alfa * 255, 0, 255).astype(np.uint8)
    salvar("sangue_rastro", rgba, np.full((N, N), 0.35, np.float32))


def simbolo():
    """Circulo duplo, estrela de sete pontas e runas inventadas, a dedo."""
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    c = N / 2

    def traco(pts, w):
        tremido = [(x + rnd.uniform(-3, 3), y + rnd.uniform(-3, 3)) for (x, y) in pts]
        d.line(tremido, fill=255, width=w, joint="curve")

    for r, w in ((0.46, 16), (0.40, 9)):
        pts = [(c + math.cos(t) * r * N, c + math.sin(t) * r * N)
               for t in np.linspace(0, math.tau, 140)]
        traco(pts, w)
    pontas = [(c + math.cos(-math.pi / 2 + i * math.tau / 7) * 0.40 * N,
               c + math.sin(-math.pi / 2 + i * math.tau / 7) * 0.40 * N) for i in range(7)]
    ordem = [pontas[(i * 3) % 7] for i in range(8)]
    traco(ordem, 12)
    # runas entre os dois circulos
    for i in range(14):
        a = i * math.tau / 14 + 0.2
        x, y = c + math.cos(a) * 0.43 * N, c + math.sin(a) * 0.43 * N
        s = 0.018 * N
        for _ in range(rnd.randint(2, 4)):
            p0 = (x + rnd.uniform(-s, s), y + rnd.uniform(-s, s))
            p1 = (x + rnd.uniform(-s, s), y + rnd.uniform(-s, s))
            d.line((p0, p1), fill=255, width=6)
    alfa = np.asarray(img.filter(ImageFilter.GaussianBlur(2.0)), np.float32) / 255
    alfa *= 0.55 + 0.45 * ruido(N, 10)            # tinta falhando
    rgba = np.zeros((N, N, 4), np.uint8)
    rgba[..., :3] = np.clip(cor_sangue(N, 0.3) * 0.75 * 255, 0, 255)
    rgba[..., 3] = np.clip(alfa * 255, 0, 255).astype(np.uint8)
    salvar("simbolo_culto", rgba, np.full((N, N), 0.6, np.float32))


def gosma():
    m = mancha(N, 0.40, 2.0, 0.5).astype(np.float32)
    alfa = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(6)), np.float32) / 255
    v = ruido(N, 5)
    rgb = np.zeros((N, N, 3), np.float32)
    rgb[..., 0] = 0.18 + 0.15 * v
    rgb[..., 1] = 0.45 + 0.35 * v
    rgb[..., 2] = 0.05 + 0.08 * v
    # bolhas
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    for _ in range(60):
        x, y = rnd.uniform(0.2, 0.8) * N, rnd.uniform(0.2, 0.8) * N
        s = rnd.uniform(4, 22)
        d.ellipse((x - s, y - s, x + s, y + s), outline=255, width=3)
    b = np.asarray(img.filter(ImageFilter.GaussianBlur(1)), np.float32) / 255
    rgb = rgb * (1 + 0.6 * b[..., None])
    rgba = np.zeros((N, N, 4), np.uint8)
    rgba[..., :3] = np.clip(rgb * 255, 0, 255)
    rgba[..., 3] = np.clip(alfa * 235, 0, 255).astype(np.uint8)
    salvar("gosma_verde", rgba, np.full((N, N), 0.05, np.float32))


if __name__ == "__main__":
    poca()
    respingo()
    rastro()
    simbolo()
    gosma()
