"""Textura da poça de luz projetada no chão (opção D).

Não é luz: é um quad aceso, desenhado com blend aditivo. Por não ser luz,
escapa do teto de ~8 fontes por objeto do renderer Forward Mobile, que é o
que impedia a pista de acender.

Saída em escala de cinza — a cor vem do material, para dar para trocar o tom
sem regerar a imagem.
"""
import os
import numpy as np
from PIL import Image

RES = 512
_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.abspath(os.path.join(_HERE, "..", "..", "..", ".."))
OUT = os.path.join(_REPO, "red-valve", "assets", "3d_model", "city", "textures")


def fbm(U, V, cells, oct_, seed):
    tot = np.zeros_like(U)
    amp, norm, c = 1.0, 0.0, cells
    rng = np.random.default_rng(seed)
    for o in range(oct_):
        n = max(2, int(round(c)))
        g = rng.random((n, n))
        gu, gv = U * n, V * n
        i0, j0 = np.floor(gu).astype(int) % n, np.floor(gv).astype(int) % n
        i1, j1 = (i0 + 1) % n, (j0 + 1) % n
        fu, fv = gu - np.floor(gu), gv - np.floor(gv)
        su, sv = fu*fu*(3-2*fu), fv*fv*(3-2*fv)
        a = g[j0, i0]*(1-su) + g[j0, i1]*su
        b = g[j1, i0]*(1-su) + g[j1, i1]*su
        tot += amp * (a*(1-sv) + b*sv)
        norm += amp; amp *= 0.5; c *= 2
    return tot / norm


def build(nome="T_lightpool", seed=17):
    t = (np.arange(RES) + 0.5) / RES
    U, V = np.meshgrid(t, t, indexing="xy")
    dx, dy = (U - 0.5) * 2.0, (V - 0.5) * 2.0

    # elipse: a luminária é inclinada, então a poça é alongada no eixo do braço
    r = np.sqrt((dx / 0.98) ** 2 + (dy / 0.80) ** 2)

    # queda suave, com joelho: núcleo forte e franja longa
    nucleo = np.clip(1.0 - r / 0.42, 0, 1) ** 1.6
    franja = np.clip(1.0 - r, 0, 1) ** 2.6
    f = np.clip(nucleo * 0.75 + franja * 0.55, 0, 1)

    # irregularidade: borda de poça real não é círculo perfeito
    f *= 0.86 + 0.28 * fbm(U, V, 5, 3, seed)
    f *= np.clip(1.0 - r, 0, 1) ** 0.5      # garante zero na borda do quad
    f = np.clip(f, 0, 1)

    img = (np.dstack([f, f, f]) * 255).astype(np.uint8)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(img).save(os.path.join(OUT, nome + ".png"))
    return f


if __name__ == "__main__":
    f = build()
    print("T_lightpool.png gerado em", OUT)
    print("  pico %.2f | media %.3f | borda %.4f (tem que ser ~0)" % (
        f.max(), f.mean(), max(f[0].max(), f[-1].max(), f[:, 0].max(), f[:, -1].max())))
