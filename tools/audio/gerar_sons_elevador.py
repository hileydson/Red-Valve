# -*- coding: utf-8 -*-
"""Sons do elevador do hospital, SINTETIZADOS.

    python3 tools/audio/gerar_sons_elevador.py

Grava .ogg em red-valve/assets/sounds/hospital/. Nada aqui e' baixado: motor,
porta, tranco, campainha e botao saem de ruido filtrado e senoide com numpy
(mesmo esquema do `gerar_sons_cenarios.py`), sem licenca nem credito.
Deterministico (semente fixa).

  elevador_motor.ogg   loop do motor/cabo enquanto a cabine anda
  elevador_porta.ogg   as folhas correndo (1,9 s, o TEMPO_PORTA do script)
  elevador_tranco.ogg  o solavanco de partida e de chegada
  elevador_ding.ogg    a campainha ao chegar no andar
  elevador_botao.ogg   o clique do botao do painel

Precisa de ffmpeg (codifica o vorbis) e numpy.
"""

import os
import subprocess

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "red-valve/assets/sounds/hospital")
SR = 44100
rng = np.random.default_rng(20261030)


def gravar(nome, x):
    os.makedirs(SAIDA, exist_ok=True)
    pico = np.max(np.abs(x)) or 1.0
    dados = (x / pico * 0.9).astype(np.float32)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", "1", "-ar", str(SR),
         "-i", "-", "-c:a", "libvorbis", "-q:a", "5", os.path.join(SAIDA, nome)],
        input=dados.tobytes(), check=True)


def t_de(seg):
    return np.arange(int(seg * SR)) / SR


def ruido(seg):
    return rng.standard_normal(int(seg * SR))


def banda(x, baixo, alto):
    """Filtro de banda pela FFT (corte suave nas pontas)."""
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    X = np.fft.rfft(x)
    ganho = np.clip((f - baixo * 0.7) / (baixo * 0.3 + 1e-9), 0, 1) if baixo > 0 else np.ones_like(f)
    ganho *= np.clip((alto * 1.3 - f) / (alto * 0.3), 0, 1)
    return np.fft.irfft(X * ganho, len(x))


def loop_cruzado(x, cruza):
    """O fim cruza com o comeco: o looping do Godot emenda sem estalo."""
    n = int(cruza * SR)
    corpo = x[:-n].copy()
    rampa = np.linspace(0.0, 1.0, n)
    corpo[:n] = corpo[:n] * rampa + x[-n:] * (1.0 - rampa)
    return corpo


def motor():
    seg = 7.0
    t = t_de(seg)
    oscila = 1.0 + 0.004 * np.sin(2 * np.pi * 0.35 * t)
    zumbido = (np.sin(2 * np.pi * 50 * oscila * t) * 0.55
               + np.sin(2 * np.pi * 100 * oscila * t) * 0.35
               + np.sin(2 * np.pi * 150 * oscila * t) * 0.12)
    # o cabo correndo nas polias: ronco grave com batida lenta
    ronco = banda(ruido(seg), 40, 260) * (0.7 + 0.3 * np.sin(2 * np.pi * 1.6 * t))
    # chiado fino do motor velho
    chiado = np.sin(2 * np.pi * 760 * oscila * t) * 0.025
    ar = banda(ruido(seg), 900, 3200) * 0.05
    x = zumbido * 0.6 + ronco / (np.max(np.abs(ronco)) or 1) * 0.55 + chiado + ar
    gravar("elevador_motor.ogg", loop_cruzado(x, 1.0))


def porta():
    seg = 2.1
    t = t_de(seg)
    corre = 1.9
    k = np.clip(t / corre, 0, 1)
    env = np.sin(np.pi * k) ** 0.7 * (t < corre)
    rolo = banda(ruido(seg), 180, 1400)
    rolo /= np.max(np.abs(rolo)) or 1
    # trepidar das rodinhas no trilho
    trepida = 0.75 + 0.25 * np.sign(np.sin(2 * np.pi * 23 * t))
    x = rolo * env * trepida * 0.7
    x += banda(ruido(seg), 60, 200) * env * 0.6
    # batente no fim do curso
    bate = t - corre
    m = bate >= 0
    x[m] += (np.sin(2 * np.pi * 85 * bate[m]) * np.exp(-bate[m] * 28) * 1.2
             + banda(ruido(seg), 200, 2500)[m] * np.exp(-bate[m] * 60) * 0.8)
    gravar("elevador_porta.ogg", x)


def tranco():
    seg = 1.4
    t = t_de(seg)
    grave = np.sin(2 * np.pi * 62 * t) * np.exp(-t * 7) * 1.2
    batida = banda(ruido(seg), 80, 900) * np.exp(-t * 30)
    batida /= np.max(np.abs(batida)) or 1
    metal = sum(np.sin(2 * np.pi * f * t) * a * np.exp(-t * d)
                for f, a, d in ((431, 0.20, 6), (1117, 0.12, 9), (1733, 0.07, 12)))
    gravar("elevador_tranco.ogg", grave + batida * 0.7 + metal)


def ding():
    seg = 2.6
    t = t_de(seg)
    x = np.zeros_like(t)
    for ini, f in ((0.0, 1318.5), (0.42, 1046.5)):
        m = t >= ini
        tt = t[m] - ini
        x[m] += (np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * f * 2.76 * tt)
                 + 0.15 * np.sin(2 * np.pi * f * 5.4 * tt)) * np.exp(-tt * 2.4)
    gravar("elevador_ding.ogg", x)


def botao():
    seg = 0.18
    t = t_de(seg)
    x = banda(ruido(seg), 1500, 7000) * np.exp(-t * 180)
    x += np.sin(2 * np.pi * 2200 * t) * np.exp(-t * 90) * 0.4
    gravar("elevador_botao.ogg", x)


if __name__ == "__main__":
    motor()
    porta()
    tranco()
    ding()
    botao()
    print("sons do elevador em", SAIDA)
