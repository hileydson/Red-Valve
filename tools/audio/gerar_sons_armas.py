"""Sons da MK3 (the_negotiator_V2) e da Granola (the_negotiator_V4).

    python3 tools/audio/gerar_sons_armas.py

Compostos a partir dos sons que a pistola e a cacadeira ja' usam
(red-valve/assets/sounds/player/) e do pacote CC0 "75 CC0 breaking / falling /
hit sfx" (OpenGameArt), o mesmo que o gerador da igreja baixa. As funcoes de
DSP sao as do `gerar_sons_igreja.py`.
"""
import os
import subprocess
import sys

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gerar_sons_igreja as g  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SONS = os.path.join(RAIZ, "red-valve/assets/sounds/player")
SR = g.SR
rng = np.random.default_rng(3141)


def proj(rel):
    """Le um som do proprio projeto (mp3/ogg) como float32 mono."""
    bruto = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", os.path.join(SONS, rel), "-f", "f32le", "-ac", "1",
         "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(bruto, dtype=np.float32).copy()


def gravar(pasta, nome, x):
    g.SAIDA = os.path.join(SONS, "guns", pasta)
    g.gravar(nome, x)


def passa_alta(x, corte):
    return (x - g.passa_baixa(x, corte)).astype(np.float32)


def ruido(seg):
    return rng.standard_normal(int(seg * SR)).astype(np.float32)


def mk3():
    tiro = g.normal(proj("gun_shot.mp3"))
    # Rajada de 3: cada tiro e' curto e seco (a pistola tem uma cauda longa
    # que, tocada 3 vezes em 0,2 s, embolava tudo). Tom um pouco acima.
    x = g.tom(tiro[: int(0.42 * SR)], 1.16)
    x = g.fade(x, 0.0, 0.18)
    clique = g.normal(g.ler("sfx_breaking_and_falling/bfh1_metal_hit_02.ogg"))
    g.por(x, g.tom(clique[: int(0.08 * SR)], 2.2), 0.0, 0.18)
    gravar("mk3", "mk3_tiro.ogg", g.normal(x))

    sai = g.normal(proj("load_gun.mp3"))
    gravar("mk3", "mk3_pente_sai.ogg", g.fade(g.tom(sai[: int(0.55 * SR)], 1.1), 0.0, 0.08))

    # O pente vazio quicando no chao: duas batidas de metal e um rolar curto
    cai = g.silencio(0.9)
    h1 = g.normal(g.ler("sfx_breaking_and_falling/bfh1_metal_hit_03.ogg"))
    h2 = g.normal(g.ler("sfx_breaking_and_falling/bfh1_metal_hit_05.ogg"))
    g.por(cai, g.tom(h1, 1.5), 0.0, 0.9)
    g.por(cai, g.tom(h2, 1.8), 0.17, 0.55)
    g.por(cai, g.tom(h1, 2.1), 0.31, 0.3)
    gravar("mk3", "mk3_pente_cai.ogg", g.fade(g.normal(cai), 0.0, 0.25))

    entra = g.normal(proj("gun_load.mp3"))
    tapa = g.normal(g.ler("sfx_breaking_and_falling/bfh1_metal_hit_01.ogg"))
    x = g.silencio(0.8)
    g.por(x, entra, 0.0, 1.0)
    g.por(x, g.tom(tapa, 1.3), 0.05, 0.35)
    gravar("mk3", "mk3_pente_entra.ogg", g.fade(g.normal(x), 0.0, 0.15))

    ferrolho = g.normal(proj("guns/shotgun/shotgun_reload.mp3"))
    gravar("mk3", "mk3_ferrolho.ogg", g.fade(g.tom(ferrolho, 1.35), 0.0, 0.1))


def granola():
    # O disparo: o baque grave do cano largo, o assobio do foguete saindo e um
    # chiado de propelente.
    base = g.normal(proj("guns/shotgun/shotgun_sound.mp3"))
    x = g.silencio(1.8)
    g.por(x, g.tom(base, 0.7), 0.0, 1.0)
    chiado = passa_alta(ruido(1.2), 2500.0)
    env = np.exp(-np.linspace(0, 5.0, len(chiado))).astype(np.float32)
    g.por(x, chiado * env, 0.02, 0.35)
    assobio = g.passa_baixa(ruido(0.9), 1800.0)
    t = np.linspace(0, 1, len(assobio))
    assobio = assobio * (np.sin(t * np.pi) ** 2).astype(np.float32)
    g.por(x, g.normal(assobio), 0.05, 0.4)
    x = g.reverb(x, 1.0, 0.15)
    gravar("granola", "granola_disparo.ogg", g.fade(np.tanh(g.normal(x) * 1.6).astype(np.float32), 0.0, 0.4))

    entra = g.normal(proj("guns/shotgun/shotgun_load_bullet.mp3"))
    raspa = g.normal(g.ler("sfx_breaking_and_falling/bfh1_metal_falling_01.ogg"))
    x = g.silencio(1.0)
    g.por(x, g.fade(g.tom(raspa[: int(0.6 * SR)], 1.4), 0.02, 0.2), 0.0, 0.35)
    g.por(x, g.tom(entra, 0.72), 0.35, 1.0)
    gravar("granola", "granola_foguete_entra.ogg", g.fade(g.normal(x), 0.0, 0.2))

    trava = g.normal(proj("guns/shotgun/shotgun_final_reload_sound.mp3"))
    gravar("granola", "granola_trava.ogg", g.fade(g.tom(trava, 0.85), 0.0, 0.12))


def mira():
    # A mira da Granola: um bipe curto e seco a cada piscada enquanto o alvo
    # esta' marcado, e dois tons subindo no instante em que ela trava nele.
    def bipe(freq, seg):
        t = np.arange(int(seg * SR)) / SR
        onda = np.sin(2 * np.pi * freq * t) + 0.25 * np.sign(np.sin(2 * np.pi * freq * t))
        return g.fade(g.normal(onda).astype(np.float32) * 0.8, 0.003, 0.02)
    gravar("granola", "granola_mira_bip.ogg", bipe(1900.0, 0.06))
    x = g.silencio(0.22)
    g.por(x, bipe(1500.0, 0.07), 0.0, 1.0)
    g.por(x, bipe(2250.0, 0.09), 0.1, 1.0)
    gravar("granola", "granola_mira_trava.ogg", x)


def creditos():
    texto = ("Sons da MK3 e da Granola, compostos por tools/audio/gerar_sons_armas.py a\n"
             "partir dos sons da pistola e da cacadeira do projeto e de:\n\n"
             "  \"75 CC0 breaking / falling / hit sfx\" (CC0)  "
             "https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx\n")
    for pasta in ("mk3", "granola"):
        with open(os.path.join(SONS, "guns", pasta, "CREDITOS.txt"), "w") as f:
            f.write(texto)


if __name__ == "__main__":
    # sem argumento gera tudo; com nomes (ex.: `mira`) so' esses
    if len(sys.argv) > 1:
        for nome in sys.argv[1:]:
            globals()[nome]()
    else:
        g.baixar()
        mk3()
        granola()
        mira()
        creditos()
