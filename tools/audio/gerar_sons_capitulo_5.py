# -*- coding: utf-8 -*-
"""Os sons do fim do Capitulo 5 (o resgate do Jimmy e o reencontro).

    python3 tools/audio/gerar_sons_capitulo_5.py

Grava em red-valve/assets/sounds/capitulo_5/, com o CREDITOS.txt:

- grade_pancada.ogg   o Jimmy socando a barra da jaula: duas pancadas de ferro
                      do "75 CC0 breaking / falling / hit sfx", uma mais grave
                      por baixo, com cauda de metal vibrando
- porta_arrancada.ogg o Maycow arrancando a porta da jaula: o rangido do ferro
                      cedendo (ruido filtrado subindo) e o estalo da dobradica
- reencontro.ogg      a musica do reencontro do Jimmy com o Jonny e dos
                      creditos: "I Want to go Home" (Eldritch Grim, CC0), so'
                      convertida pra .ogg (o Godot nao toca .wav comprido bem
                      e o arquivo cai de 34 MB pra ~4 MB)

As pancadas vem do mesmo cache dos sons da igreja (`gerar_sons_igreja.py`
baixa o que faltar). Deterministico: rodar de novo da' o mesmo arquivo.

Precisa de ffmpeg e numpy.
"""

import os
import subprocess
import sys
import urllib.request

import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.dont_write_bytecode = True
import gerar_sons_igreja as ig  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(AQUI))
SAIDA = os.path.join(RAIZ, "red-valve/assets/sounds/capitulo_5")
SR = ig.SR
MUSICA_URL = "https://opengameart.org/sites/default/files/i_want_to_go_home.wav"
MUSICA_CACHE = os.path.join(ig.CACHE, "i_want_to_go_home.wav")


def gravar(nome, x):
    ig.SAIDA = SAIDA
    ig.gravar(nome, x.astype(np.float32))


def ruido(seg, sorte):
    return np.random.default_rng(sorte).standard_normal(int(seg * SR)).astype(np.float32)


def passa_banda(x, lo, hi):
    f = np.fft.rfft(x)
    hz = np.fft.rfftfreq(len(x), 1.0 / SR)
    f[(hz < lo) | (hz > hi)] = 0.0
    return np.fft.irfft(f, len(x)).astype(np.float32)


def misturar(base, x, em):
    i = int(em * SR)
    fim = min(len(base), i + len(x))
    base[i:fim] += x[:fim - i]
    return base


def grade_pancada():
    a = ig.normal(ig.ler("sfx_breaking_and_falling/bfh1_metal_hit_02.ogg"))
    b = ig.normal(ig.ler("sfx_breaking_and_falling/bfh1_metal_hit_05.ogg"))
    grave = ig.tom(b, 0.72)
    y = np.zeros(int(1.6 * SR), dtype=np.float32)
    misturar(y, a, 0.0)
    misturar(y, grave * 0.6, 0.004)
    # a barra vibrando: duas senoides de metal que morrem devagar
    t = np.arange(len(y)) / SR
    vibra = (np.sin(2 * np.pi * 410 * t) * 0.5 + np.sin(2 * np.pi * 1130 * t) * 0.3) * np.exp(-t * 4.5)
    y += vibra.astype(np.float32) * 0.18
    gravar("grade_pancada.ogg", ig.fade(y, 0.001, 0.4))


def porta_arrancada():
    seg = 2.2
    t = np.arange(int(seg * SR)) / SR
    # o ferro cedendo: ruido estreito que sobe de tom, cada vez mais forte
    rangido = np.zeros_like(t, dtype=np.float32)
    for k, (lo, hi) in enumerate(((300, 700), (600, 1300), (900, 2200))):
        n = passa_banda(ruido(seg, 50 + k), lo, hi)
        rangido += n * (0.35 / (k + 1))
    rangido *= (np.clip(t / 1.6, 0.0, 1.0) ** 2 * (t < 1.75)).astype(np.float32)
    y = rangido
    estalo = ig.normal(ig.ler("sfx_breaking_and_falling/bfh1_metal_hit_04.ogg"))
    queda = ig.normal(ig.ler("sfx_breaking_and_falling/bfh1_metal_falling_02.ogg"))
    misturar(y, estalo * 1.1, 1.74)
    misturar(y, ig.tom(estalo, 0.6) * 0.7, 1.75)
    misturar(y, queda * 0.5, 1.9)
    gravar("porta_arrancada.ogg", ig.fade(y, 0.01, 0.3))


def reencontro():
    if not os.path.exists(MUSICA_CACHE):
        os.makedirs(ig.CACHE, exist_ok=True)
        req = urllib.request.Request(MUSICA_URL, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as r, open(MUSICA_CACHE, "wb") as f:
            f.write(r.read())
    os.makedirs(SAIDA, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", MUSICA_CACHE, "-c:a", "libvorbis",
                    "-q:a", "5", os.path.join(SAIDA, "reencontro.ogg")], check=True)


CREDITOS = """Sons do fim do Capitulo 5 (o resgate do Jimmy e o reencontro com o Jonny).
Compostos por tools/audio/gerar_sons_capitulo_5.py.

A MUSICA do reencontro e dos creditos (reencontro.ogg) e'

  "I Want to go Home", de Eldritch Grim — CC0 (dominio publico)
  https://opengameart.org/content/i-want-to-go-home
  (versao sentimental de "Nostalgic Piano", de Rafael Krux, tambem CC0)

As PANCADAS de ferro (grade_pancada, porta_arrancada) saem do pacote CC0 do
OpenGameArt:

  "75 CC0 breaking / falling / hit sfx"  https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx

O rangido da porta e a vibracao da barra sao sintetizados (ruido filtrado e
senoide) — sem licenca nem credito a cumprir nessa parte.
"""


def main():
    ig.baixar()
    grade_pancada()
    porta_arrancada()
    reencontro()
    with open(os.path.join(SAIDA, "CREDITOS.txt"), "w", encoding="utf-8") as f:
        f.write(CREDITOS)
    print("== sons em", SAIDA)


if __name__ == "__main__":
    main()
