# -*- coding: utf-8 -*-
"""As manchas de sangue que o tiro deixa no chao e na parede (Decal).

    python3 tools/vfx/gerar_respingos_sangue.py

Grava red-valve/assets/images/vfx/sangue_respingo_<n>.png (256 x 256, RGBA).
Cada uma e' uma poca central de borda irregular, com rajadas de gotas
alongadas saindo dela (as "exclamacoes" que o sangue faz quando bate em
alguma coisa) e pingos soltos em volta. Mais escura onde e' mais grossa.
Usadas por `scripts/effects/sangue_tiro.gd`.

Deterministico (semente por variante): rodar de novo da' os mesmos arquivos.
Precisa de numpy e Pillow.
"""

import math
import os

import numpy as np
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "red-valve/assets/images/vfx")
TAM = 256
VARIANTES = 3


def mancha(semente):
    rnd = np.random.default_rng(semente)
    ys, xs = np.mgrid[0:TAM, 0:TAM].astype(np.float32)
    u = (xs + 0.5) / TAM * 2.0 - 1.0     # -1..1
    v = (ys + 0.5) / TAM * 2.0 - 1.0
    aa = 2.0 / TAM                        # meia largura da borda suave

    # espessura (0..1): o que define cobertura e cor
    grosso = np.zeros((TAM, TAM), np.float32)

    # poca central: raio torto por soma de senos
    r0 = rnd.uniform(0.26, 0.34)
    # o sangue chega torto: a poca escorrega pra tras e o respingo vai pra frente
    rumo = rnd.uniform(0, 2 * math.pi)
    cu, cv = -math.cos(rumo) * 0.08, -math.sin(rumo) * 0.08
    rp = np.sqrt((u - cu) ** 2 + (v - cv) ** 2)
    ap = np.arctan2(v - cv, u - cu)
    borda = np.zeros_like(ap)
    for k in range(2, 11):
        borda += rnd.uniform(0.02, 0.10) / k ** 0.5 * np.sin(k * ap + rnd.uniform(0, 6.28))
    cobre = np.clip((r0 * (1.0 + borda) - rp) / aa + 0.5, 0.0, 1.0)
    manchado = np.zeros_like(u)
    for k in range(3, 9):
        manchado += np.sin(u * k * rnd.uniform(5, 9) + rnd.uniform(0, 6.28)) * \
            np.sin(v * k * rnd.uniform(5, 9) + rnd.uniform(0, 6.28)) / k
    grosso = np.maximum(grosso, cobre * np.clip(0.85 + 0.12 * manchado, 0.6, 1.0))

    def gota(cx, cy, raio, alonga, giro, peso):
        nonlocal grosso
        c, s = math.cos(giro), math.sin(giro)
        du, dv = u - cx, v - cy
        a = du * c + dv * s               # ao longo da rajada
        b = -du * s + dv * c
        d = np.sqrt((a / alonga) ** 2 + b * b)
        g = np.clip((raio - d) / aa + 0.5, 0.0, 1.0) * peso
        grosso = np.maximum(grosso, g)

    # rajadas: cada uma e' uma fila de gotas que afinam e se alongam pra fora
    for i in range(rnd.integers(10, 16)):
        if i % 3 != 2:
            # a maioria vai no rumo do respingo, e vai longe
            giro = rumo + rnd.normal(0.0, 0.55)
            alcance = rnd.uniform(0.6, 0.97)
        else:
            giro = rnd.uniform(0, 2 * math.pi)
            alcance = rnd.uniform(0.4, 0.6)
        dist = r0 * rnd.uniform(0.7, 0.95)
        raio = rnd.uniform(0.03, 0.065)
        while dist < alcance and raio > 0.006:
            gota(math.cos(giro) * dist, math.sin(giro) * dist, raio,
                 1.0 + dist * rnd.uniform(1.5, 3.5), giro, rnd.uniform(0.55, 0.9))
            passo = raio * rnd.uniform(1.6, 3.2)
            dist += passo
            raio *= rnd.uniform(0.62, 0.85)
            giro += rnd.uniform(-0.05, 0.05)

    # pingos soltos
    for _ in range(rnd.integers(30, 55)):
        dist = r0 + abs(rnd.normal(0.0, 0.3))
        if dist > 0.95:
            continue
        giro = rumo + rnd.normal(0.0, 1.1)
        gota(math.cos(giro) * dist, math.sin(giro) * dist, rnd.uniform(0.006, 0.022),
             rnd.uniform(1.0, 1.8), giro, rnd.uniform(0.45, 0.8))

    # mais escuro (seco por cima, grosso) no meio; vermelho vivo nas bordas finas
    escuro = np.array([0.20, 0.0, 0.01], np.float32)
    vivo = np.array([0.52, 0.02, 0.04], np.float32)
    k = np.clip(grosso, 0.0, 1.0)[..., None]
    rgb = vivo * (1.0 - k) + escuro * k
    alfa = np.clip(np.where(grosso > 0.0, 0.55 + 0.45 * grosso, 0.0), 0.0, 1.0)
    alfa *= np.clip(grosso * 8.0, 0.0, 1.0)  # a borda suave das gotas
    img = np.dstack([rgb, alfa[..., None]])
    return Image.fromarray((img * 255.0 + 0.5).astype(np.uint8), "RGBA")


def main():
    os.makedirs(SAIDA, exist_ok=True)
    for n in range(1, VARIANTES + 1):
        caminho = os.path.join(SAIDA, "sangue_respingo_%d.png" % n)
        mancha(1983 + n).save(caminho)
        print("  ", caminho)


if __name__ == "__main__":
    main()
