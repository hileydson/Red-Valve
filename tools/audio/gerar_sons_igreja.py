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
    creditos()
