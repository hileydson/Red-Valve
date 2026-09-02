"""Etapa 06 — atlas das placas de nome de rua.

Chapa esmaltada 0,42 x 0,14 m (proporcao 3:1). Grade de 2 x 6 celulas num
atlas 1024x1020; cada via nomeada do layout.json ocupa uma celula, e o
indice da celula volta em signs.json para o gerador de geometria posicionar
a UV certa.
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
OUT = os.path.join(REPO, "red-valve", "assets", "3d_model", "city", "textures")
LAYOUT = os.path.join(HERE, "..", "city_data", "layout.json")

FONT = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
CW, CH = 512, 170          # celula
COLS, ROWS = 2, 6

ESMALTE = (206, 197, 178)  # creme sujo
BORDA = (58, 52, 45)
TEXTO = (44, 40, 35)


def _fit(draw, text, maxw, maxh):
    """Maior corpo que couber, quebrando em duas linhas se preciso."""
    for size in range(48, 15, -1):
        f = ImageFont.truetype(FONT, size)
        if draw.textlength(text, font=f) <= maxw:
            return f, [text]
        palavras = text.split()
        for k in range(1, len(palavras)):
            l1, l2 = " ".join(palavras[:k]), " ".join(palavras[k:])
            if (draw.textlength(l1, font=f) <= maxw
                    and draw.textlength(l2, font=f) <= maxw
                    and size * 2.3 <= maxh):
                return f, [l1, l2]
    return ImageFont.truetype(FONT, 16), [text]


def build():
    with open(os.path.abspath(LAYOUT), "r", encoding="utf-8") as fh:
        data = json.load(fh)
    nomes = [(r["id"], r["name"]) for r in data["roads"] if r["named"] and r["name"]]

    atlas = Image.new("RGB", (CW * COLS, CH * ROWS), (24, 22, 20))
    d = ImageDraw.Draw(atlas)
    mapa = {}
    for i, (rid, nome) in enumerate(nomes[:COLS * ROWS]):
        cx, cy = (i % COLS) * CW, (i // COLS) * CH
        d.rectangle([cx + 4, cy + 4, cx + CW - 5, cy + CH - 5], fill=ESMALTE)
        d.rectangle([cx + 4, cy + 4, cx + CW - 5, cy + CH - 5], outline=BORDA, width=7)
        f, linhas = _fit(d, nome.upper(), CW - 56, CH - 46)
        lh = f.size * 1.16
        y = cy + CH / 2 - lh * len(linhas) / 2
        for ln in linhas:
            w = d.textlength(ln, font=f)
            d.text((cx + CW / 2 - w / 2, y), ln, font=f, fill=TEXTO)
            y += lh
        mapa[rid] = {"cell": i, "uv": [(i % COLS) / COLS, (i // COLS) / ROWS,
                                       1.0 / COLS, 1.0 / ROWS], "nome": nome}

    # envelhecimento: manchas de ferrugem, sujeira e lascas
    a = np.asarray(atlas).astype(np.float64) / 255.0
    rng = np.random.default_rng(9)
    H, W = a.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W]
    grime = np.zeros((H, W))
    for _ in range(90):
        px, py = rng.integers(0, W), rng.integers(0, H)
        r = rng.integers(14, 70)
        grime += np.clip(1.0 - np.hypot(xx - px, yy - py) / r, 0, 1) ** 2
    grime = np.clip(grime * 0.55, 0, 0.8)
    ferrugem = np.array([0.42, 0.24, 0.15])
    a = a * (1 - grime[..., None] * 0.75) + ferrugem * grime[..., None] * 0.75
    a *= (0.90 + 0.18 * rng.random((H, W, 1)))

    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(
        os.path.join(OUT, "T_signs_alb.png"))
    occ = np.clip(0.75 + 0.25 * (1 - grime), 0, 1)
    rough = np.clip(0.55 + 0.40 * grime, 0, 1)
    orm = np.dstack([occ, rough, np.full_like(occ, 0.15)])
    Image.fromarray((orm * 255).astype(np.uint8)).save(os.path.join(OUT, "T_signs_orm.png"))

    with open(os.path.join(os.path.dirname(os.path.abspath(LAYOUT)), "signs.json"),
              "w", encoding="utf-8") as fh:
        json.dump({"atlas": "T_signs", "cols": COLS, "rows": ROWS, "plates": mapa},
                  fh, indent=1, ensure_ascii=False)
    return mapa


if __name__ == "__main__":
    m = build()
    print("placas no atlas:", len(m))
    for rid, e in m.items():
        print("  %-20s celula %2d  %s" % (rid, e["cell"], e["nome"]))
