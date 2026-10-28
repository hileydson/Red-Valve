# -*- coding: utf-8 -*-
"""Sons dos cenarios novos (arena 3, cemiterio, inferno), SINTETIZADOS.

    python3 tools/audio/gerar_sons_cenarios.py

Grava .ogg em red-valve/assets/sounds/cenarios/. Nada aqui e' baixado: vento,
trovao, lava e sino saem de ruido filtrado e senoide com numpy, entao nao ha'
licenca nem credito a cumprir. Deterministico (semente fixa).

Os loops (vento, lava, drone) terminam cruzando com o proprio comeco, entao o
`parameters/looping` do Godot emenda sem estalo.

Precisa de ffmpeg (codifica o vorbis) e numpy.
"""

import os
import subprocess

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "red-valve/assets/sounds/cenarios")
SR = 44100
rng = np.random.default_rng(20261026)


def gravar(nome, x, direita=None):
    os.makedirs(SAIDA, exist_ok=True)
    if direita is not None:
        dados = np.stack([x, direita], axis=1)
        canais = 2
    else:
        dados = x
        canais = 1
    pico = np.max(np.abs(dados)) or 1.0
    dados = (dados / pico * 0.9).astype(np.float32)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", str(canais), "-ar", str(SR),
         "-i", "-", "-c:a", "libvorbis", "-q:a", "5", os.path.join(SAIDA, nome)],
        input=dados.tobytes(), check=True)
    print("  %-24s %5.2f s" % (nome, len(x) / SR))


# ------------------------------------------------------------------ dsp
def ruido(seg):
    return rng.standard_normal(int(seg * SR)).astype(np.float32)


def filtro(x, lo=None, hi=None, inclina=0.0):
    """Passa-faixa por FFT (fase zero). `inclina` > 0 escurece o espectro
    (1 = ruido rosa, 2 = marrom)."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    X = np.fft.rfft(x)
    g = np.ones_like(f)
    if lo:
        g *= 1.0 / (1.0 + (lo / np.maximum(f, 1e-3)) ** 4)
    if hi:
        g *= 1.0 / (1.0 + (f / hi) ** 4)
    if inclina:
        g *= 1.0 / np.maximum(f, 20.0) ** (inclina / 2.0)
    return np.fft.irfft(X * g, n).astype(np.float32)


def envoltoria_lenta(seg, taxa, minimo=0.2):
    """Curva suave entre `minimo` e 1, mudando ~`taxa` vezes por segundo."""
    n = int(seg * SR)
    k = max(int(seg * taxa) + 3, 4)
    pontos = rng.uniform(minimo, 1.0, k)
    x = np.linspace(0, k - 1, n)
    i = np.floor(x).astype(int)
    t = x - i
    t = t * t * (3 - 2 * t)
    i1 = np.minimum(i + 1, k - 1)
    return (pontos[i] * (1 - t) + pontos[i1] * t).astype(np.float32)


def emendar(x, cruz=1.5):
    """Loop sem estalo: o fim cruza com o comeco."""
    c = int(cruz * SR)
    a = np.linspace(0, 1, c, dtype=np.float32)
    y = x[:-c].copy()
    y[:c] = y[:c] * a + x[-c:] * (1 - a)
    return y


def reverb(x, segundos=2.5, mistura=0.4):
    n = int(segundos * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n).astype(np.float32) * np.exp(-t * 6.9 / segundos)
    ir = filtro(ir, hi=3500.0)
    ir /= np.sqrt(np.sum(ir ** 2)) or 1.0
    tam = len(x) + n
    tam2 = 1 << (tam - 1).bit_length()
    molhado = np.fft.irfft(np.fft.rfft(x, tam2) * np.fft.rfft(ir, tam2), tam2)[:tam]
    seco = np.concatenate([x, np.zeros(n, dtype=np.float32)])
    return (seco * (1 - mistura) + molhado * mistura * 2.5).astype(np.float32)


def fade(x, ini=0.01, fim=0.1):
    x = x.copy()
    a, b = int(ini * SR), int(fim * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


# ------------------------------------------------------------------ sons
def vento(nome, seg, camadas, uivo=0.0):
    """Varias faixas de ruido, cada uma com a propria rajada: a mistura muda
    de cor sozinha e soa como vento de verdade, nao como chiado."""
    canais = []
    for _lado in range(2):
        soma = np.zeros(int((seg + 1.5) * SR), dtype=np.float32)
        for lo, hi, ganho, taxa in camadas:
            r = filtro(ruido(seg + 1.5), lo, hi, inclina=1.0)
            r /= np.max(np.abs(r)) or 1.0
            soma += r * envoltoria_lenta(seg + 1.5, taxa, 0.15) ** 2 * ganho
        if uivo:
            # uivo: ruido estreito em faixa que desliza devagar
            t = np.arange(len(soma)) / SR
            f0 = 380 + 160 * np.sin(2 * np.pi * t / 7.3) + 90 * np.sin(2 * np.pi * t / 3.1)
            fase = 2 * np.pi * np.cumsum(f0) / SR
            u = np.sin(fase) * filtro(ruido(seg + 1.5), 200, 900)
            u /= np.max(np.abs(u)) or 1.0
            soma += u * envoltoria_lenta(seg + 1.5, 0.25, 0.0) ** 3 * uivo
        canais.append(emendar(soma))
    gravar(nome, canais[0], canais[1])


def trovao():
    seg = 7.5
    n = int(seg * SR)
    t = np.arange(n) / SR
    estalo = filtro(ruido(seg), 800, 6000) * np.exp(-t * 18.0) * 0.8
    ronco = filtro(ruido(seg), 25, 260, inclina=1.5)
    ronco /= np.max(np.abs(ronco)) or 1.0
    env = np.minimum(t / 0.25, 1.0) * np.exp(-t * 0.55)
    ronco *= env * (0.55 + 0.45 * envoltoria_lenta(seg, 4.0, 0.1))
    x = estalo * 0.35 + ronco
    gravar("trovao.ogg", fade(reverb(x, 3.0, 0.35), 0.002, 1.5))


def meteoro():
    seg = 2.4
    n = int(seg * SR)
    t = np.arange(n) / SR
    # assobio que desce + rugido que cresce ate' o impacto
    f0 = 1600 * np.exp(-t * 0.9) + 220
    fase = 2 * np.pi * np.cumsum(f0) / SR
    assobio = np.sin(fase) * filtro(ruido(seg), 300, 3000) * 0.6
    rugido = filtro(ruido(seg), 40, 900, inclina=1.0)
    rugido /= np.max(np.abs(rugido)) or 1.0
    env = (t / seg) ** 2.2
    x = (assobio * 0.3 + rugido) * env
    gravar("meteoro.ogg", fade(x, 0.05, 0.05))


def lava():
    seg = 16.0
    n = int((seg + 1.5) * SR)
    t = np.arange(n) / SR
    ronco = filtro(ruido(seg + 1.5), 20, 180, inclina=1.6)
    ronco /= np.max(np.abs(ronco)) or 1.0
    x = ronco * (0.6 + 0.4 * envoltoria_lenta(seg + 1.5, 0.5))
    # bolhas: senoide curta que sobe de tom e estoura
    for _ in range(70):
        t0 = rng.uniform(0, seg + 1.0)
        d = rng.uniform(0.06, 0.22)
        m = int(d * SR)
        tt = np.arange(m) / SR
        f = rng.uniform(70, 190) * (1 + tt / d * rng.uniform(0.6, 1.8))
        b = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / d) ** 2
        i = int(t0 * SR)
        x[i:i + m] += b[: max(0, min(m, n - i))] * rng.uniform(0.3, 0.8)
    # chiado de crosta estalando
    chiado = filtro(ruido(seg + 1.5), 2000, 8000) * (envoltoria_lenta(seg + 1.5, 6.0, 0.0) ** 6)
    x += chiado * 0.3
    _ = t
    gravar("lava.ogg", emendar(x))


def geiser():
    seg = 3.2
    n = int(seg * SR)
    t = np.arange(n) / SR
    jato = filtro(ruido(seg), 60, 2400, inclina=0.8)
    jato /= np.max(np.abs(jato)) or 1.0
    env = np.minimum(t / 0.12, 1.0) * np.exp(-np.maximum(t - 0.6, 0) * 1.6)
    estalos = filtro(ruido(seg), 1500, 7000) * (envoltoria_lenta(seg, 25.0, 0.0) ** 8)
    gravar("geiser.ogg", fade(jato * env + estalos * env * 0.4, 0.002, 0.3))


def drone_inferno():
    seg = 30.0
    n = int((seg + 2.0) * SR)
    t = np.arange(n) / SR
    x = np.zeros(n, dtype=np.float32)
    for f, g in ((41.2, 0.5), (41.9, 0.45), (61.7, 0.3), (82.4, 0.18), (123.0, 0.06)):
        x += (np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * g).astype(np.float32)
    x *= 0.6 + 0.4 * envoltoria_lenta(seg + 2.0, 0.15)
    # gemido distante: banda estreita deslizando, bem baixo
    f0 = 210 + 70 * np.sin(2 * np.pi * t / 11.0) + 40 * np.sin(2 * np.pi * t / 4.3)
    gem = np.sin(2 * np.pi * np.cumsum(f0) / SR) * filtro(ruido(seg + 2.0), 150, 700)
    gem /= np.max(np.abs(gem)) or 1.0
    x += gem * envoltoria_lenta(seg + 2.0, 0.2, 0.0) ** 4 * 0.35
    vento_baixo = filtro(ruido(seg + 2.0), 60, 500, inclina=1.0)
    vento_baixo /= np.max(np.abs(vento_baixo)) or 1.0
    x += vento_baixo * envoltoria_lenta(seg + 2.0, 0.3, 0.2) * 0.35
    x = reverb(x, 3.5, 0.3)[:n]
    gravar("drone_inferno.ogg", emendar(x, 2.0))


def sino():
    """Sino de igreja longe, na nevoa: parciais inarmonicas que somem."""
    seg = 7.0
    n = int(seg * SR)
    t = np.arange(n) / SR
    f0 = 196.0
    x = np.zeros(n, dtype=np.float32)
    for k, g, d in ((0.5, 0.5, 2.8), (1.0, 1.0, 2.2), (1.19, 0.6, 1.7), (1.5, 0.45, 1.5),
                    (2.0, 0.4, 1.2), (2.51, 0.25, 0.9), (3.0, 0.15, 0.7), (4.07, 0.1, 0.5)):
        x += (np.sin(2 * np.pi * f0 * k * t) * g * np.exp(-t / d)).astype(np.float32)
    x *= np.minimum(t / 0.004, 1.0)
    x = filtro(x, 60, 2600)          # longe: perde o brilho
    gravar("sino.ogg", fade(reverb(x, 4.0, 0.6)[: int(9 * SR)], 0.0, 1.5))


if __name__ == "__main__":
    print("--- sons dos cenarios ---")
    vento("vento_tempestade.ogg", 24.0,
          [(30, 250, 1.0, 0.35), (150, 900, 0.7, 0.6), (600, 3000, 0.35, 0.9),
           (2000, 7000, 0.12, 1.4)], uivo=0.28)
    vento("vento_frio.ogg", 24.0,
          [(40, 300, 0.6, 0.2), (200, 1200, 0.45, 0.3), (900, 4000, 0.18, 0.5)], uivo=0.42)
    vento("vento_quente.ogg", 24.0,
          [(25, 200, 1.0, 0.25), (120, 700, 0.6, 0.4), (500, 2500, 0.2, 0.7)], uivo=0.1)
    trovao()
    meteoro()
    lava()
    geiser()
    drone_inferno()
    sino()
