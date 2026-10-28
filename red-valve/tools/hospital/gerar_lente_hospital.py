"""Gera um vinhete leve para a lente do hospital, sem shader de pós-processo."""

from pathlib import Path
from PIL import Image
import math
import random


destino = Path(__file__).resolve().parents[2] / "assets/3d_model/stages/hospital/textures/lente_hospital.png"
random.seed(41)
lado = 512
imagem = Image.new("RGBA", (lado, lado))
pixels = imagem.load()
for y in range(lado):
    dy = (y + .5 - lado / 2) / (lado / 2)
    for x in range(lado):
        dx = (x + .5 - lado / 2) / (lado / 2)
        raio = math.sqrt(dx * dx * .82 + dy * dy)
        vinheta = max(0.0, min(1.0, (raio - .47) / .61)) ** 2
        grao = random.random() * 3.0 if raio > .3 else 0.0
        pixels[x, y] = (3, 10, 9, min(83, round(vinheta * 76 + grao)))

destino.parent.mkdir(parents=True, exist_ok=True)
imagem.save(destino, optimize=True)
print(destino)
