# -*- coding: utf-8 -*-
"""Os sons da cena da igreja (Dona Nice), compostos a partir de pacotes CC0.

    python3 tools/audio/gerar_sons_igreja.py

Baixa os pacotes do OpenGameArt (so' CC0 — ver CREDITOS.txt gerado), compoe
cada som com numpy e grava .ogg em red-valve/assets/sounds/igreja/.

O que nao existia pronto foi COMPOSTO aqui:
- o canto do culto (sussurro_culto): nao ha' sussurro de frase CC0, mas ha'
  silabas sussurradas soltas. Elas viram palavras e frases de uma lingua que
  nao existe, em tres vozes (uma invertida, uma mais grave), com reverb de
  nave de igreja. Ininteligivel de proposito: "palavras esquisitas de um
  culto bizarro".
- a transformacao (ossos + carne): estalos de osso e gosma em camadas, com
  densidade crescendo.
- o grito da transformacao (grito_monstro): o guincho e o grito agudo
  puxados pra baixo, por cima do rugido grave, saturados e com reverb — o
  momento em que ela deixa de ser gente, nas duas fases.
Tudo deterministico (semente fixa): rodar de novo da' o mesmo arquivo.

Precisa de ffmpeg (decodifica e codifica) e numpy.
"""

import io
import os
import subprocess
import urllib.request
import zipfile

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "red-valve/assets/sounds/igreja")
CACHE = os.path.join(os.environ.get("TMPDIR", "/tmp"), "sons_igreja_cache")
SR = 44100
OGA = "https://opengameart.org/sites/default/files/"

PACOTES = {
    # arquivo: (pagina, titulo)
    "vocal_samples.zip": ("dialog-vocal-samples", "Dialog vocal samples"),
    "80-CC0-creature-SFX_0.zip": ("80-cc0-creature-sfx", "80 CC0 creature SFX"),
    "water-splash-slime-sfx.zip": ("40-cc0-water-splash-slime-sfx", "40 CC0 water / splash / slime SFX"),
    "deep_breaks.zip": ("deep-bone-crackbreak-sfx", "Deep Bone Crack/Break SFX"),
    "crunch_-_tito.zip": ("7-eating-crunches", "7 Eating Crunches"),
    "monster_roar.wav": ("cc0-deep-monster-roar", "CC0 Deep Monster Roar"),
    "scream_horror1_0.mp3": ("horror-scream1", "Horror Scream1"),
    "heartbeat_slow_reverb.wav": ("heartbeat-sounds", "Heartbeat sounds"),
    "heartbeat_fast_reverb.wav": ("heartbeat-sounds", "Heartbeat sounds"),
    "ambient_horror_0.ogg": ("ambient-horror", "Ambient Horror"),
    "squish_01_0.mp3": ("squish-sounds-effects", "Squish sounds effects"),
    "squish_03.mp3": ("squish-sounds-effects", "Squish sounds effects"),
    "squish_05.mp3": ("squish-sounds-effects", "Squish sounds effects"),
    "evil_screech_1.ogg": ("evil-screech-1", "Evil Screech 1"),
    "high_pitch_scream_gverb.mp3": ("high-pitch-scream-sounds2", "High pitch scream sounds(2)"),
    "breathing%20tired.wav": ("breathing-tired", "breathing tired"),
    "skeleton1sfx_0.wav": ("skeletonsfxshortpack", "SkeletonSFXShortPack"),
    "skeleton2sfx_0.wav": ("skeletonsfxshortpack", "SkeletonSFXShortPack"),
    "sfx_breaking_and_falling.zip": ("75-cc0-breaking-falling-hit-sfx", "75 CC0 breaking / falling / hit sfx"),
}

rng = np.random.default_rng(1983)


# ---------------------------------------------------------------- arquivos
def baixar():
    os.makedirs(CACHE, exist_ok=True)
    for arq in PACOTES:
        destino = os.path.join(CACHE, arq)
        if not os.path.exists(destino):
            req = urllib.request.Request(OGA + arq, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req) as r, open(destino, "wb") as f:
                f.write(r.read())
        if arq.endswith(".zip"):
            pasta = os.path.join(CACHE, arq[:-4])
            if not os.path.isdir(pasta):
                with zipfile.ZipFile(destino) as z:
                    z.extractall(pasta)


def ler(rel):
    """Decodifica qualquer coisa pra float32 mono 44,1 kHz."""
    caminho = os.path.join(CACHE, rel)
    bruto = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", caminho, "-f", "f32le", "-ac", "1",
         "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(bruto, dtype=np.float32).copy()


def gravar(nome, x, estereo=None):
    os.makedirs(SAIDA, exist_ok=True)
    if estereo is not None:
        dados = np.stack([x, estereo], axis=1)
        canais = 2
    else:
        dados = x
        canais = 1
    pico = np.max(np.abs(dados)) or 1.0
    dados = (dados / pico * 0.92).astype(np.float32)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", str(canais), "-ar", str(SR),
         "-i", "-", "-c:a", "libvorbis", "-q:a", "5", os.path.join(SAIDA, nome)],
        input=dados.tobytes(), check=True)
    print("  %-28s %5.2f s" % (nome, len(x) / SR))


# ---------------------------------------------------------------- dsp
def tom(x, fator):
    """Muda tom e duracao juntos (fator < 1 = mais grave e mais longo)."""
    n = int(len(x) / fator)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)


def silencio(seg):
    return np.zeros(int(seg * SR), dtype=np.float32)


def por(base, x, t, ganho=1.0):
    i = int(t * SR)
    fim = min(len(base), i + len(x))
    if fim > i:
        base[i:fim] += x[:fim - i] * ganho
    return base


def fade(x, ini=0.01, fim=0.05):
    x = x.copy()
    a, b = int(ini * SR), int(fim * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def passa_baixa(x, corte):
    # um polo, suficiente pra tirar o "chiado digital" dos estalos
    a = np.exp(-2 * np.pi * corte / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def reverb(x, segundos=2.6, mistura=0.45, brilho=4000.0):
    """Reverb de nave: convolucao com ruido que decai (e escurece)."""
    n = int(segundos * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n).astype(np.float32) * np.exp(-t * 6.9 / segundos)
    ir = passa_baixa(ir, brilho)
    ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))  # pre-delay curto
    ir /= np.sqrt(np.sum(ir ** 2))
    tam = len(x) + n
    tam2 = 1 << (tam - 1).bit_length()
    molhado = np.fft.irfft(np.fft.rfft(x, tam2) * np.fft.rfft(ir, tam2), tam2)[:tam]
    seco = np.concatenate([x, np.zeros(n, dtype=np.float32)])
    return (seco * (1 - mistura) + molhado * mistura * 3.0).astype(np.float32)


def normal(x):
    return x / (np.max(np.abs(x)) or 1.0)


# ---------------------------------------------------------------- sons
def sussurro_culto():
    silabas = [normal(ler("vocal_samples/whisper_%d.ogg" % i)) for i in (1, 2, 3, 4)]
    demonio = [normal(ler("vocal_samples/demon_%d.ogg" % i)) for i in (1, 2, 3, 4)]
    dur = 18.0

    def voz(fonte, tom_base, invertida=False, densidade=1.0):
        out = silencio(dur)
        t = 0.3 + rng.uniform(0, 0.5)
        while t < dur - 1.0:
            # uma palavra: 2 a 4 silabas coladas
            for _ in range(rng.integers(2, 5)):
                s = fonte[rng.integers(len(fonte))]
                s = s[::-1].copy() if invertida else s
                s = fade(tom(s, tom_base * rng.uniform(0.9, 1.08)), 0.005, 0.03)
                por(out, s, t, rng.uniform(0.6, 1.0))
                t += len(s) / SR * rng.uniform(0.65, 0.85)
            t += rng.uniform(0.18, 0.45) / densidade
            if rng.random() < 0.22:
                t += rng.uniform(0.9, 1.6)          # respiro entre frases
        return out

    a = voz(silabas, 0.92)
    b = voz(silabas, 0.80, invertida=True, densidade=0.8)
    c = voz(demonio, 0.62, densidade=0.6)
    esq = reverb(a * 0.9 + b * 0.5 + c * 0.25, 3.2, 0.5)
    dir_ = reverb(a * 0.6 + b * 0.8 + c * 0.25, 3.0, 0.5)
    n = int(dur * SR)
    # costura de laco: o rabo do reverb entra por baixo do comeco
    for canal in (esq, dir_):
        canal[: len(canal) - n] += canal[n:]
    gravar("sussurro_culto.ogg", esq[:n], dir_[:n])


def batimentos():
    for nome, arq in (("batimento_lento.ogg", "heartbeat_slow_reverb.wav"),
                      ("batimento_rapido.ogg", "heartbeat_fast_reverb.wav")):
        x = normal(ler(arq))
        gravar(nome, np.concatenate([x] * 4))


def gota():
    b = normal(ler("water-splash-slime-sfx/bubble_02.ogg"))
    s = normal(ler("water-splash-slime-sfx/slime_06.ogg"))
    x = silencio(1.6)
    por(x, tom(b, 0.55), 0.0, 0.7)
    por(x, tom(s, 0.5), 0.05, 0.5)
    gravar("gota_sangue.ogg", fade(reverb(x, 1.8, 0.4), 0.002, 0.3))
    sp = normal(ler("water-splash-slime-sfx/splash_02.ogg"))
    gravar("gota_impacto.ogg", fade(reverb(tom(sp, 0.6) * 0.8, 1.5, 0.35), 0.001, 0.4))


def transformacao():
    quebras = [normal(ler("deep_breaks/Deep Break %d.wav" % i)) for i in range(1, 11)]
    gosmas = [normal(ler("water-splash-slime-sfx/slime_%02d.ogg" % i)) for i in (2, 3, 6, 7, 9)]
    squish = [normal(ler(f)) for f in ("squish_01_0.mp3", "squish_03.mp3", "squish_05.mp3")]
    dur = 6.0
    x = silencio(dur)
    t = 0.0
    while t < dur - 0.8:
        dens = 0.25 + 0.75 * (t / dur)          # cada vez mais rapido
        por(x, tom(quebras[rng.integers(10)], rng.uniform(0.7, 1.1)), t, rng.uniform(0.5, 1.0))
        if rng.random() < 0.7:
            por(x, tom(gosmas[rng.integers(5)], rng.uniform(0.5, 0.8)), t + 0.05, 0.6)
        if rng.random() < 0.4:
            por(x, tom(squish[rng.integers(3)], rng.uniform(0.6, 0.9)), t + 0.1, 0.5)
        t += rng.uniform(0.18, 0.5) / dens
    gravar("transformacao_ossos.ogg", fade(reverb(x, 2.2, 0.3), 0.01, 0.6))

    grito = normal(ler("scream_horror1_0.mp3"))[: int(6.0 * SR)]
    gravar("grito_transformacao.ogg", fade(reverb(tom(grito, 0.82), 2.8, 0.4), 0.05, 1.2))


def rugido():
    r = normal(ler("monster_roar.wav"))
    r2 = normal(ler("80-CC0-creature-SFX_0/roar_02.ogg"))
    sc = normal(ler("80-CC0-creature-SFX_0/scream_01.ogg"))
    x = silencio(len(r) / SR + 1.0)
    por(x, r, 0.0, 1.0)
    por(x, tom(r2, 0.6), 0.1, 0.6)
    por(x, tom(sc, 0.55), 0.35, 0.5)
    gravar("rugido_monstro.ogg", fade(reverb(x, 3.0, 0.35), 0.01, 0.8))


def grito_monstro():
    gu = normal(ler("evil_screech_1.ogg"))[int(1.6 * SR): int(3.3 * SR)]
    ag = normal(ler("high_pitch_scream_gverb.mp3"))
    ro = normal(ler("monster_roar.wav"))
    de = normal(ler("vocal_samples/demon_2.ogg"))
    x = silencio(4.6)
    por(x, tom(ro, 0.55), 0.0, 0.75)
    por(x, tom(gu, 0.78), 0.18, 1.0)
    por(x, tom(ag, 0.62), 0.32, 0.55)
    por(x, tom(de, 0.6), 0.05, 0.45)
    x = np.tanh(normal(x) * 2.2).astype(np.float32)
    gravar("grito_monstro.ogg", fade(reverb(x, 3.2, 0.42), 0.005, 1.4))


def boca():
    crunch = [normal(ler("crunch_-_tito/crunch.%d.ogg" % i)) for i in (1, 2, 3)]
    eat = [normal(ler("80-CC0-creature-SFX_0/eat_%02d.ogg" % i)) for i in (1, 2, 4)]
    slime = [normal(ler("water-splash-slime-sfx/slime_%02d.ogg" % i)) for i in (3, 7, 9)]
    for i in range(3):
        x = silencio(1.4)
        por(x, tom(crunch[i], 0.75), 0.0, 0.9)
        por(x, tom(eat[i], 0.6), 0.03, 0.8)
        por(x, tom(slime[i], 0.7), 0.08, 0.6)
        gravar("mordida_%d.ogg" % (i + 1), fade(reverb(x, 1.2, 0.2), 0.001, 0.3))
    bur = [normal(ler("80-CC0-creature-SFX_0/burble_%02d.ogg" % i)) for i in (1, 2)]
    x = silencio(3.0)
    por(x, tom(bur[0], 0.7), 0.0, 0.8)
    por(x, tom(bur[1], 0.6), 1.2, 0.8)
    por(x, tom(slime[0], 0.5), 0.5, 0.5)
    gravar("baba.ogg", fade(x, 0.05, 0.3))
    sp = normal(ler("80-CC0-creature-SFX_0/spit_02.ogg"))
    sl = normal(ler("water-splash-slime-sfx/slime_09.ogg"))
    x = silencio(1.6)
    por(x, tom(sp, 0.7), 0.0, 1.0)
    por(x, tom(sl, 0.55), 0.12, 0.7)
    gravar("cuspe.ogg", fade(reverb(x, 1.6, 0.3), 0.001, 0.3))
    x = silencio(1.4)
    por(x, tom(sl, 0.45), 0.0, 1.0)
    por(x, tom(normal(ler("water-splash-slime-sfx/splash_03.ogg")), 0.6), 0.02, 0.6)
    gravar("gosma_cai.ogg", fade(x, 0.001, 0.3))


def pancadas():
    q = normal(ler("deep_breaks/Deep Break 3.wav"))
    m = normal(ler("80-CC0-creature-SFX_0/monster_05.ogg"))
    sp = normal(ler("water-splash-slime-sfx/splash_02.ogg"))
    x = silencio(2.5)
    por(x, tom(q, 0.45), 0.0, 1.0)
    por(x, tom(m, 0.5), 0.0, 0.7)
    por(x, tom(sp, 0.5), 0.02, 0.5)
    gravar("tapa_chao.ogg", fade(reverb(x, 2.8, 0.4), 0.001, 0.6))
    for i, h in enumerate((1, 3, 5)):
        x = normal(ler("80-CC0-creature-SFX_0/hurt_%02d.ogg" % h))
        gravar("dano_monstro_%d.ogg" % (i + 1), fade(reverb(tom(x, 0.6), 1.4, 0.3), 0.001, 0.2))
    m4 = normal(ler("80-CC0-creature-SFX_0/monster_04.ogg"))
    m7 = normal(ler("80-CC0-creature-SFX_0/monster_07.ogg"))
    sc = normal(ler("80-CC0-creature-SFX_0/scream_02.ogg"))
    x = silencio(5.0)
    por(x, tom(m4, 0.6), 0.0, 1.0)
    por(x, tom(sc, 0.5), 0.6, 0.8)
    por(x, tom(m7, 0.45), 1.6, 0.8)
    gravar("morte_monstro.ogg", fade(reverb(x, 3.2, 0.4), 0.01, 1.0))


def vozes():
    br = normal(ler("80-CC0-creature-SFX_0/breath.ogg"))
    oh = normal(ler("80-CC0-creature-SFX_0/ooh.ogg"))
    x = silencio(3.2)
    por(x, tom(br, 1.18), 0.0, 0.6)
    por(x, tom(oh, 1.22), 1.3, 0.35)
    gravar("gemido_jonny.ogg", fade(reverb(passa_baixa(x, 3500), 2.0, 0.3), 0.05, 0.4))
    x = np.concatenate([tom(br, 0.55), silencio(0.4), tom(br, 0.5), silencio(0.6)])
    gravar("respiracao_monstro.ogg", fade(reverb(x, 1.6, 0.3), 0.05, 0.2))


def respiracao_jonny():
    """O Jonny respirando, ferido: curto, rapido, falhando, com gemido baixo.

    A fonte e' um adulto ofegante; afinado pra cima vira a voz de um menino.
    Laco de 12 s (o rabo do reverb volta pro comeco, sem emenda). Semente
    propria: nao mexe nos outros sons.
    """
    sorte = np.random.default_rng(2011)
    x = normal(ler("breathing%20tired.wav"))
    # tira o chiado de fundo entre um folego e outro
    env = np.convolve(np.abs(x), np.ones(int(0.03 * SR)) / int(0.03 * SR), "same")
    x = x * np.clip((env - 0.06) / 0.08, 0.0, 1.0)
    # os tres folegos da gravacao, separados pelo envelope
    folegos = []
    for a, b in ((0.05, 0.75), (1.15, 1.85), (2.3, 3.05)):
        folegos.append(fade(tom(x[int(a * SR):int(b * SR)], 1.32), 0.01, 0.08))
    oh = normal(ler("80-CC0-creature-SFX_0/ooh.ogg"))
    dor = normal(ler("80-CC0-creature-SFX_0/hurt_04.ogg"))
    laco = 12.0
    y = silencio(laco + 3.0)
    t = 0.15
    n = 0
    while t < laco - 1.0:
        f = folegos[sorte.integers(0, 3)]
        g = sorte.uniform(0.55, 0.9)
        if n % 3 == 2:
            # o folego falha: duas puxadas curtas antes de soltar
            meio = f[: len(f) // 2]
            por(y, fade(meio, 0.005, 0.03), t, g * 0.8)
            t += len(meio) / SR + 0.07
        por(y, f, t, g)
        if n % 4 == 3:
            # o gemido sai junto com o ar
            por(y, fade(tom(oh, 1.55), 0.02, 0.15), t + 0.12, 0.22)
        if n == 6:
            por(y, fade(tom(dor, 1.45), 0.005, 0.1), t + 0.05, 0.18)
        t += len(f) / SR + sorte.uniform(0.35, 0.7)
        n += 1
    y = reverb(passa_baixa(y, 5200), 0.9, 0.15)
    corpo = y[: int(laco * SR)].copy()
    rabo = y[int(laco * SR):]
    corpo[: len(rabo)] += rabo[: len(corpo)]
    gravar("respiracao_jonny.ogg", corpo)


def pescoco():
    """O pescoco dela torcendo pra tras (o `girar_cabeca`, 6,4 s na chegada).

    Os estalos caem nos dois trechos em que o pescoco torce de verdade
    (TORCE_PESCOCO do gerador da cena: 1,45-2,45 s e 3,27-4,9 s, ja' na
    velocidade da chegada): um rangido de osso esfregando, estalos miudos em
    rajada e, no fim do giro (~4,4 s, quando a cabeca passa dos 180 graus), o
    estalo grande de quebrar. Semente propria: nao mexe nos outros sons.
    """
    sorte = np.random.default_rng(2207)
    fundos = [normal(ler("deep_breaks/Deep Break %d.wav" % i)) for i in range(1, 11)]
    rajada = normal(ler("skeleton2sfx_0.wav"))
    ossos = normal(ler("skeleton1sfx_0.wav"))
    quebra = normal(ler("sfx_breaking_and_falling/bfh1_breaking_01.ogg"))
    madeira = [normal(ler("sfx_breaking_and_falling/bfh1_wood_breaking_%02d.ogg" % i)) for i in (1, 3, 4)]
    mastiga = [normal(ler("crunch_-_tito/crunch.%d.ogg" % i)) for i in (1, 2, 3)]
    x = silencio(6.8)
    for ini, fim in ((1.45, 2.45), (3.27, 4.9)):
        # o rangido: a rajada de estalos do esqueleto, grave e esticada
        por(x, fade(tom(rajada, sorte.uniform(0.62, 0.7)), 0.03, 0.2), ini, 0.55)
        t = ini
        while t < fim:
            por(x, tom(fundos[sorte.integers(10)], sorte.uniform(0.85, 1.25)), t, sorte.uniform(0.6, 1.0))
            if sorte.random() < 0.6:
                por(x, tom(madeira[sorte.integers(3)], sorte.uniform(0.5, 0.65)), t + 0.02, 0.6)
            if sorte.random() < 0.5:
                # a cartilagem: o estalo molhado de quem mastiga osso
                por(x, tom(mastiga[sorte.integers(3)], sorte.uniform(0.6, 0.8)), t + 0.04, 0.55)
            t += sorte.uniform(0.09, 0.22)
    # o estalo grande, quando a cabeca passa do ponto
    por(x, tom(fundos[2], 0.7), 4.38, 1.0)
    por(x, tom(quebra, 0.72), 4.4, 0.9)
    por(x, tom(ossos[int(0.3 * SR):int(0.9 * SR)], 0.8), 4.42, 0.7)
    por(x, tom(fundos[7], 0.6), 4.62, 0.6)
    # seco e comprimido: tem de passar por cima do ambiente e do coracao
    x = reverb(x, 1.3, 0.14)
    x = np.tanh(normal(x) * 3.0).astype(np.float32)
    gravar("pescoco_torcendo.ogg", fade(x, 0.01, 0.6))


def teleporte():
    """O teleporte da monstro: SOME num sopro puxado ao contrario (o ar sendo
    sugado pra dentro dela) que fecha num estalo molhado, e SURGE num estouro
    de carne com o rosnado por baixo. Semente propria.
    """
    sorte = np.random.default_rng(3301)
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    # sopro: ruido que sobe de brilho
    ruido = sorte.standard_normal(n).astype(np.float32)
    sopro = passa_baixa(ruido, 900.0) * 0.6 + passa_baixa(ruido, 3500.0) * (t / 1.4) * 0.4
    sopro *= (t / 1.4) ** 2.2
    respiro = normal(ler("80-CC0-creature-SFX_0/breath.ogg"))[::-1].copy()
    squish = normal(ler("squish_03.mp3"))
    monstro = normal(ler("80-CC0-creature-SFX_0/monster_05.ogg"))
    x = silencio(2.4)
    por(x, sopro.astype(np.float32), 0.0, 0.8)
    por(x, tom(respiro, 0.5)[-int(1.4 * SR):], 0.0, 0.6)
    por(x, tom(squish, 0.6), 1.36, 0.9)
    por(x, tom(normal(ler("deep_breaks/Deep Break 5.wav")), 0.55), 1.38, 0.7)
    gravar("teleporte_some.ogg", fade(reverb(x, 2.2, 0.4), 0.05, 0.5))
    x = silencio(3.0)
    estouro = normal(ler("water-splash-slime-sfx/splash_03.ogg"))
    por(x, tom(estouro, 0.5), 0.0, 1.0)
    por(x, tom(normal(ler("squish_05.mp3")), 0.55), 0.03, 0.8)
    por(x, tom(monstro, 0.5), 0.12, 0.8)
    por(x, tom(normal(ler("deep_breaks/Deep Break 9.wav")), 0.5), 0.0, 0.7)
    gravar("teleporte_surge.ogg", fade(reverb(x, 2.8, 0.42), 0.001, 0.8))


def rajada():
    """Os bancos voando: a rajada que ela solta (ar varrendo a nave, de baixo
    pra cima e de volta), madeira rangendo e quebrando por cima e um ronco
    grave no chao. Semente propria.
    """
    sorte = np.random.default_rng(4409)
    dur = 4.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    ruido = sorte.standard_normal(n).astype(np.float32)
    # o vento: o brilho sobe ate' o meio e desce, e o volume vem em onda
    grave = passa_baixa(ruido, 500.0)
    agudo = passa_baixa(ruido, 2600.0) - passa_baixa(ruido, 700.0)
    forma = np.sin(np.pi * np.clip(t / 3.2, 0, 1)) ** 1.5
    vento = (grave * 0.9 + agudo * forma * 0.8) * (0.2 + 0.8 * forma)
    madeira = [normal(ler("sfx_breaking_and_falling/bfh1_wood_breaking_%02d.ogg" % i)) for i in (1, 2, 3, 4)]
    batida = [normal(ler("sfx_breaking_and_falling/bfh1_wood_hit_%02d.ogg" % i)) for i in (1, 2, 3)]
    ronco = passa_baixa(normal(ler("monster_roar.wav")), 400.0)
    x = silencio(dur + 1.0)
    por(x, vento.astype(np.float32), 0.0, 0.9)
    por(x, tom(ronco, 0.45), 0.0, 0.8)
    tt = 0.15
    while tt < 2.6:
        por(x, tom(madeira[sorte.integers(4)], sorte.uniform(0.45, 0.7)), tt, sorte.uniform(0.5, 0.9))
        if sorte.random() < 0.4:
            por(x, tom(batida[sorte.integers(3)], sorte.uniform(0.5, 0.7)), tt + 0.05, 0.6)
        tt += sorte.uniform(0.12, 0.35)
    x = np.tanh(normal(reverb(x, 2.6, 0.35)) * 1.8).astype(np.float32)
    gravar("rajada_bancos.ogg", fade(x, 0.05, 1.0))


def ambiente():
    x = normal(ler("ambient_horror_0.ogg"))
    gravar("ambiente_ritual.ogg", fade(x, 0.5, 0.5))


def creditos():
    linhas = ["Sons da cena da igreja (Dona Nice). Todos CC0 (dominio publico), do",
              "OpenGameArt. Compostos por tools/audio/gerar_sons_igreja.py a partir de:", ""]
    vistos = set()
    for arq, (pag, titulo) in PACOTES.items():
        if pag in vistos:
            continue
        vistos.add(pag)
        linhas.append("  \"%s\"  https://opengameart.org/content/%s" % (titulo, pag))
    linhas += ["", "O canto do culto (sussurro_culto.ogg) foi montado silaba a silaba a",
               "partir das amostras sussurradas do \"Dialog vocal samples\": nao e' uma",
               "lingua, e sim silabas em sequencia, invertidas e graves, com reverb."]
    with open(os.path.join(SAIDA, "CREDITOS.txt"), "w") as f:
        f.write("\n".join(linhas) + "\n")


if __name__ == "__main__":
    baixar()
    sussurro_culto()
    batimentos()
    gota()
    transformacao()
    rugido()
    boca()
    pancadas()
    vozes()
    ambiente()
    # por ultimo: a semente e' uma so', e os sons de antes nao mudam
    grito_monstro()
    respiracao_jonny()
    pescoco()
    teleporte()
    rajada()
    creditos()
