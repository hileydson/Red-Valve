# -*- coding: utf-8 -*-
"""Os sons das cutscenes do fim do Capitulo 4 e do comeco do Capitulo 5.

    python3 tools/audio/gerar_sons_capitulo_4.py

A queima do Maycow parasita no meio da arena 2 e o despertar do Maycow
normal no pentagrama da igreja. Grava .ogg em
red-valve/assets/sounds/capitulo_4/, com o CREDITOS.txt.

Duas origens:
- VOZ (respiracao, gemido, grito, o esforco de levantar): composta a partir
  dos mesmos pacotes CC0 do OpenGameArt da cena da igreja, no mesmo cache
  (`gerar_sons_igreja.py` baixa o que faltar). O "breathing tired" e' um
  adulto ofegante: aqui ele fica no tom dele, um pouco mais grave.
- FOGO (o rugido, a erupcao da grelha, o estalo do flash de memoria):
  SINTETIZADO com ruido filtrado e senoide, como os sons dos cenarios — nao
  ha' licenca nem credito a cumprir nessa parte.

Os lacos (respiracao, gemido, fogo) emendam sem estalo: ou o rabo volta pro
comeco (voz, como a respiracao do Jonny), ou o fim cruza com o comeco (fogo,
como a lava). Tudo deterministico: cada som tem a propria semente, e rodar de
novo da' o mesmo arquivo.

Precisa de ffmpeg (decodifica e codifica) e numpy.
"""

import os
import sys

import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
# importar o gerador da igreja nao deixa __pycache__ na pasta das ferramentas
sys.dont_write_bytecode = True
import gerar_sons_igreja as ig  # noqa: E402  (so' as ferramentas; o __main__ dele nao roda)

RAIZ = os.path.dirname(os.path.dirname(AQUI))
SAIDA = os.path.join(RAIZ, "red-valve/assets/sounds/capitulo_4")
SR = ig.SR

ler = ig.ler
tom = ig.tom
por = ig.por
fade = ig.fade
normal = ig.normal
silencio = ig.silencio
passa_baixa = ig.passa_baixa

## Os pacotes do cache da igreja que entram aqui (pro CREDITOS.txt).
USADOS = ["breathing%20tired.wav", "80-CC0-creature-SFX_0.zip", "scream_horror1_0.mp3",
          "monster_roar.wav", "heartbeat_slow_reverb.wav", "sfx_breaking_and_falling.zip"]


# ---------------------------------------------------------------- arquivos
def gravar(nome, x):
    # o gravar da igreja normaliza o pico em 0,92 — o mesmo nivel dos sons de la'
    ig.SAIDA = SAIDA
    ig.gravar(nome, x.astype(np.float32))


# ---------------------------------------------------------------- dsp
def ruido(seg, sorte):
    return sorte.standard_normal(int(seg * SR)).astype(np.float32)


def filtro(x, lo=None, hi=None, inclina=0.0):
    """Passa-faixa por FFT (fase zero). `inclina` > 0 escurece o espectro
    (1 = ruido rosa, 2 = marrom). O mesmo dos sons dos cenarios."""
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


def envoltoria(seg, taxa, minimo, sorte):
    """Curva suave entre `minimo` e 1, mudando ~`taxa` vezes por segundo."""
    n = int(seg * SR)
    k = max(int(seg * taxa) + 3, 4)
    pontos = sorte.uniform(minimo, 1.0, k)
    x = np.linspace(0, k - 1, n)
    i = np.floor(x).astype(int)
    t = x - i
    t = t * t * (3 - 2 * t)
    i1 = np.minimum(i + 1, k - 1)
    return (pontos[i] * (1 - t) + pontos[i1] * t).astype(np.float32)


def reverb(x, segundos, mistura, sorte, brilho=4000.0):
    """O reverb de nave da igreja, mas com a semente de quem chama (o da
    igreja usa uma semente global e mudaria com a ordem dos sons)."""
    n = int(segundos * SR)
    t = np.arange(n) / SR
    ir = sorte.standard_normal(n).astype(np.float32) * np.exp(-t * 6.9 / segundos)
    ir = filtro(ir, hi=brilho)
    ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
    ir /= np.sqrt(np.sum(ir ** 2)) or 1.0
    tam = len(x) + n
    tam2 = 1 << (tam - 1).bit_length()
    molhado = np.fft.irfft(np.fft.rfft(x, tam2) * np.fft.rfft(ir, tam2), tam2)[:tam]
    seco = np.concatenate([x, np.zeros(n, dtype=np.float32)])
    return (seco * (1 - mistura) + molhado * mistura * 3.0).astype(np.float32)


def dobrar_rabo(y, laco):
    """Laco de voz: o que passa de `laco` segundos (o rabo do reverb, um
    folego que atravessou) volta pro comeco. O comeco de `y` e' silencio, entao
    o ultimo quadro emenda com o primeiro sem estalo."""
    n = int(laco * SR)
    corpo = y[:n].copy()
    rabo = y[n:]
    while len(rabo):
        k = min(len(rabo), n)
        corpo[:k] += rabo[:k]
        rabo = rabo[k:]
    return corpo


def emendar(x, cruz):
    """Laco de ruido: o fim cruza com o comeco (como a lava dos cenarios)."""
    c = int(cruz * SR)
    a = np.linspace(0, 1, c, dtype=np.float32)
    y = x[:-c].copy()
    y[:c] = y[:c] * a + x[-c:] * (1 - a)
    return y


def portao(x, piso, faixa):
    """Tira o chiado de fundo da gravacao entre um som e outro."""
    janela = int(0.03 * SR)
    env = np.convolve(np.abs(x), np.ones(janela) / janela, "same")
    return x * np.clip((env - piso) / faixa, 0.0, 1.0)


def estalos(seg, taxa, sorte, lo=1200.0, hi=9000.0, rajadas=3.0):
    """Lenha estalando: impulsos curtos com decaimento de poucos ms, em
    rajadas (a taxa sobe e desce), de tamanho bem desigual."""
    n = int(seg * SR)
    x = np.zeros(n, dtype=np.float32)
    dens = envoltoria(seg, rajadas, 0.05, sorte) ** 2
    t = 0.0
    while t < seg:
        i = int(t * SR)
        if i >= n:
            break
        if sorte.random() < dens[i]:
            d = sorte.uniform(0.001, 0.006)
            m = int(d * SR) + 8
            k = np.arange(m)
            clique = sorte.standard_normal(m) * np.exp(-k / (d * SR / 3.0))
            g = np.exp(sorte.normal(0.0, 0.8))
            fim = min(n, i + m)
            x[i:fim] += (clique[: fim - i] * g).astype(np.float32)
        t += sorte.exponential(1.0 / taxa)
    return filtro(x, lo, hi)


def estouros(seg, quantos, sorte):
    """Os estalos grandes (nó de madeira, gordura): um baque curto com corpo."""
    n = int(seg * SR)
    x = np.zeros(n, dtype=np.float32)
    for _ in range(quantos):
        i = int(sorte.uniform(0.05, seg - 0.1) * SR)
        m = int(0.09 * SR)
        k = np.arange(m) / SR
        corpo = sorte.standard_normal(m) * np.exp(-k * 55.0)
        corpo = filtro(corpo.astype(np.float32), 300.0, 4000.0)
        x[i:i + m] += corpo[: n - i] * sorte.uniform(0.5, 1.2)
    return x


# ---------------------------------------------------------------- voz
def _folegos(fator):
    """Os tres folegos do "breathing tired", sem o chiado entre eles."""
    x = portao(normal(ler("breathing%20tired.wav")), 0.06, 0.08)
    out = []
    for a, b in ((0.05, 0.75), (1.15, 1.85), (2.3, 3.05)):
        out.append(fade(tom(x[int(a * SR):int(b * SR)], fator), 0.01, 0.08))
    return out


def respiracao_maycow():
    """O Maycow parasita de joelhos depois da luta: ofegante, puxado, falhando.

    Arfadas curtas (ar entrando e saindo rapido, cada folego encurtado), um
    engasgo de vez em quando — duas puxadas secas antes de soltar — e, raro,
    um gemido grave saindo com o ar. Laco de 10 s.
    """
    sorte = np.random.default_rng(4401)
    laco = 10.0
    folegos = _folegos(0.93)
    # o folego encurtado vira arfada; o inteiro, o ar que sai pesado
    curtos = [fade(f[: int(len(f) * 0.55)], 0.005, 0.05) for f in folegos]
    puxada = fade(tom(folegos[1][: int(len(folegos[1]) * 0.35)], 1.15), 0.004, 0.03)
    ar = normal(ler("80-CC0-creature-SFX_0/breath.ogg"))
    gemido = normal(ler("80-CC0-creature-SFX_0/grunt_03.ogg"))
    y = silencio(laco + 3.0)
    t = 0.12
    n = 0
    while t < laco - 0.75:
        if n % 7 == 5:
            # engasgo: duas puxadas secas, e o ar sai inteiro
            por(y, puxada, t, 0.85)
            t += len(puxada) / SR + 0.06
            por(y, puxada, t, 0.95)
            t += len(puxada) / SR + 0.05
            f = folegos[sorte.integers(0, 3)]
            por(y, f, t, 1.0)
            t += len(f) / SR + sorte.uniform(0.12, 0.22)
        else:
            f = curtos[sorte.integers(0, 3)]
            por(y, f, t, sorte.uniform(0.6, 0.95))
            if n % 9 == 3:
                # o ar tremido do pacote de criaturas, bem grave, por baixo
                por(y, fade(tom(ar, 0.62), 0.01, 0.1), t + 0.03, 0.22)
            if n == 11:
                por(y, fade(tom(gemido, 0.86), 0.01, 0.12), t + 0.08, 0.3)
            t += len(f) / SR + sorte.uniform(0.07, 0.2)
        n += 1
    y = reverb(passa_baixa(y, 6000), 0.7, 0.12, sorte)
    gravar("respiracao_maycow.ogg", dobrar_rabo(y, laco))


def gemido_maycow():
    """O Maycow normal deitado no pentagrama: gemidos graves de dor, o ar
    falhando no meio, na nave da igreja. Laco de 7 s (o reverb volta pro
    comeco)."""
    sorte = np.random.default_rng(4402)
    laco = 7.0
    oh = normal(ler("80-CC0-creature-SFX_0/ooh.ogg"))
    dor = normal(ler("80-CC0-creature-SFX_0/hurt_05.ogg"))
    grunhe = normal(ler("80-CC0-creature-SFX_0/grunt_03.ogg"))
    longo = normal(ler("80-CC0-creature-SFX_0/grunt_01.ogg"))
    folegos = _folegos(0.95)
    y = silencio(laco + 4.0)
    # o "ohh" do pacote e' agudo (~270 Hz): a 0,6 vira um homem (~160 Hz) e
    # se arrasta, que e' como geme quem nao tem forca
    por(y, folegos[0], 0.15, 0.55)
    por(y, fade(tom(oh, 0.6), 0.04, 0.35), 0.55, 0.85)
    por(y, fade(tom(longo, 0.82), 0.03, 0.3), 2.0, 0.5)
    por(y, folegos[2], 3.0, 0.5)
    por(y, fade(tom(dor, 0.9), 0.01, 0.1), 3.65, 0.45)
    por(y, fade(tom(oh, 0.55), 0.06, 0.45), 4.05, 0.75)
    por(y, fade(tom(grunhe, 0.88), 0.02, 0.2), 5.6, 0.35)
    por(y, folegos[1], 6.05, 0.4)
    y = passa_baixa(y, 3600)
    y = reverb(y, 2.6, 0.38, sorte)
    gravar("gemido_maycow.ogg", dobrar_rabo(y, laco))


def grito_fogo():
    """O Maycow parasita queimando vivo no meio da arena.

    O grito de horror e' agudo (~830 Hz): a 0,52 cai pra uma voz de homem
    no limite (~430 Hz) e fica mais longo, que e' o grito que nao acaba. Um
    tremor de 6-8 Hz no volume (o corpo convulsionando), o rosnado do pacote
    de criaturas bem grave por baixo, saturado, e uma sala curta de pedra.
    """
    sorte = np.random.default_rng(4403)
    grito = normal(ler("scream_horror1_0.mp3"))[int(0.95 * SR): int(3.55 * SR)]
    ronco = normal(ler("monster_roar.wav"))[int(0.15 * SR): int(2.6 * SR)]
    golpe = normal(ler("80-CC0-creature-SFX_0/hurt_05.ogg"))
    rasga = normal(ler("80-CC0-creature-SFX_0/scream_01.ogg"))
    x = silencio(5.6)
    # o ar entra de uma vez antes do grito
    por(x, fade(tom(golpe, 0.82), 0.004, 0.08), 0.0, 0.7)
    g = fade(tom(grito, 0.52), 0.12, 1.2)
    t = np.arange(len(g)) / SR
    vib = 1.0 + 0.22 * np.sin(2 * np.pi * (6.0 + 2.0 * t / t[-1]) * t)
    por(x, (g * vib).astype(np.float32), 0.22, 1.0)
    por(x, fade(tom(rasga, 0.6), 0.02, 0.4), 0.3, 0.35)
    por(x, fade(tom(ronco, 0.72), 0.2, 1.0), 0.25, 0.3)
    x = np.tanh(normal(x) * 2.0).astype(np.float32)
    x = passa_baixa(x, 7000)
    x = reverb(x, 1.2, 0.22, sorte, brilho=3000.0)[: int(5.2 * SR)]
    gravar("grito_fogo.ogg", fade(x, 0.003, 0.9))


def levantar_ferido():
    """Levantando do chao devagar, no limite: o ar preso, o gemido do
    esforco, e o folego que sai quando ele ja' esta' quase de pe'."""
    sorte = np.random.default_rng(4404)
    longo = normal(ler("80-CC0-creature-SFX_0/grunt_01.ogg"))
    grunhe = normal(ler("80-CC0-creature-SFX_0/grunt_03.ogg"))
    dor = normal(ler("80-CC0-creature-SFX_0/hurt_05.ogg"))
    folegos = _folegos(0.95)
    x = silencio(4.4)
    por(x, folegos[1], 0.05, 0.6)
    por(x, fade(tom(grunhe, 0.86), 0.02, 0.15), 0.75, 0.65)
    por(x, fade(tom(longo, 0.74), 0.05, 0.35), 1.45, 0.8)
    por(x, fade(tom(dor, 0.88), 0.005, 0.1), 2.65, 0.55)
    por(x, folegos[0], 3.05, 0.75)
    x = passa_baixa(x, 4200)
    x = reverb(x, 1.6, 0.22, sorte)[: int(4.4 * SR)]
    gravar("levantar_ferido.ogg", fade(x, 0.01, 0.5))


# ---------------------------------------------------------------- fogo
def fogo_rugindo():
    """O corpo virando fogueira: o ronco grave das chamas, o bater delas
    (lambidas de 5-12 por segundo), estalo de lenha e de gordura, e o chiado
    em cima. Laco de 8 s, o fim cruzando com o comeco."""
    sorte = np.random.default_rng(4405)
    seg = 8.0 + 1.5
    ronco = filtro(ruido(seg, sorte), 25.0, 260.0, inclina=1.4)
    ronco = normal(ronco) * (0.65 + 0.35 * envoltoria(seg, 0.9, 0.0, sorte))
    # as lambidas: a faixa media pulsa rapido, sem ritmo certo
    lambe = normal(filtro(ruido(seg, sorte), 180.0, 1600.0, inclina=0.6))
    pulso = envoltoria(seg, 9.0, 0.15, sorte) ** 1.5
    lambe = lambe * pulso * (0.6 + 0.4 * envoltoria(seg, 0.7, 0.2, sorte))
    sopro = normal(filtro(ruido(seg, sorte), 900.0, 5000.0)) * envoltoria(seg, 2.0, 0.2, sorte)
    chiado = normal(filtro(ruido(seg, sorte), 3500.0, 11000.0))
    est = normal(estalos(seg, 160.0, sorte))
    big = normal(estouros(seg, 7, sorte))
    x = ronco * 1.0 + lambe * 0.55 + sopro * 0.18 + chiado * 0.05 + est * 0.42 + big * 0.35
    gravar("fogo_rugindo.ogg", emendar(x.astype(np.float32), 1.5))


def erupcao_fogo():
    """A Boca cuspindo fogo pela grelha de ferro: o chao ronca subindo,
    estoura (o baque grave, a grelha batendo) e a coluna de fogo sobe num
    sopro que vai do grave pro agudo; o fogo fica estalando e se apaga."""
    sorte = np.random.default_rng(4406)
    seg = 3.2
    n = int(seg * SR)
    t = np.arange(n) / SR
    ESTOURO = 0.85
    # 1. o ronco que sobe: ruido grave, cada vez mais forte e mais claro
    sobe = np.clip(t / ESTOURO, 0.0, 1.0)
    ronco = np.zeros(n, dtype=np.float32)
    for k, corte in enumerate((120.0, 220.0, 420.0)):
        faixa = normal(filtro(ruido(seg, sorte), 20.0, corte, inclina=1.2))
        janela = np.clip((sobe - k / 3.0) * 3.0, 0.0, 1.0)
        ronco += faixa * janela
    ronco *= (sobe ** 2.2) * np.exp(-np.maximum(t - ESTOURO, 0.0) * 2.4)
    # 2. o baque: senoide caindo de 90 pra 32 Hz + um estalo largo
    d = t - ESTOURO
    em = d >= 0
    f = 32.0 + 58.0 * np.exp(-np.maximum(d, 0.0) * 9.0)
    fase = 2 * np.pi * np.cumsum(f * em) / SR
    baque = np.sin(fase) * np.exp(-np.maximum(d, 0.0) * 4.5) * em
    estalo = normal(filtro(ruido(seg, sorte), 80.0, 6000.0)) * np.exp(-np.maximum(d, 0.0) * 22.0) * em
    # 3. o sopro da coluna: faixa que sobe de 300 Hz pra 3 kHz em 0,4 s
    sopro = np.zeros(n, dtype=np.float32)
    base = ruido(seg, sorte)
    for lo, hi, atraso in ((150.0, 700.0, 0.0), (500.0, 1800.0, 0.08), (1400.0, 4500.0, 0.18)):
        faixa = normal(filtro(base, lo, hi))
        dd = d - atraso
        sopro += faixa * np.clip(dd / 0.06, 0.0, 1.0) * np.exp(-np.maximum(dd, 0.0) * 2.0) * (dd >= 0)
    # 4. o fogo que fica: estalos e chiado se apagando
    resto = normal(estalos(seg, 220.0, sorte)) * 0.5 + normal(filtro(ruido(seg, sorte), 2500.0, 9000.0)) * 0.12
    resto *= np.clip(d / 0.1, 0.0, 1.0) * np.exp(-np.maximum(d, 0.0) * 0.75) * em
    # 5. a grelha de ferro batendo, grave
    x = ronco * 0.7 + baque * 1.0 + estalo * 0.5 + sopro * 0.75 + resto * 0.9
    grade = normal(ler("sfx_breaking_and_falling/bfh1_metal_hit_03.ogg"))
    por(x, fade(tom(grade, 0.62), 0.002, 0.2), ESTOURO + 0.01, 0.35)
    x = np.tanh(normal(x) * 1.6).astype(np.float32)
    gravar("erupcao_fogo.ogg", fade(x, 0.005, 0.35))


def flash_memoria():
    """O corte pro flash de lembranca: um sopro AO CONTRARIO puxa a tela, um
    baque seco (o coracao, a faca) e o zumbido agudo que fica no ouvido e
    some."""
    sorte = np.random.default_rng(4407)
    seg = 1.6
    n = int(seg * SR)
    t = np.arange(n) / SR
    BATE = 0.42
    # sopro: ruido que decai, filtrado, ao contrario (cresce ate' o baque)
    m = int(BATE * SR)
    k = np.arange(m) / SR
    sopro = normal(filtro(ruido(BATE, sorte), 400.0, 6000.0, inclina=0.3)) * np.exp(-k * 9.0)
    sopro = reverb(sopro.astype(np.float32), 0.5, 0.35, sorte)[:m][::-1].copy()
    x = np.zeros(n, dtype=np.float32)
    x[:m] += sopro * 0.8
    d = t - BATE
    em = d >= 0
    # o baque: o batimento grave da igreja, mais um bumbo de senoide
    bate = normal(ler("heartbeat_slow_reverb.wav"))[: int(0.5 * SR)]
    por(x, fade(tom(bate, 0.8), 0.002, 0.15), BATE - 0.01, 0.9)
    f = 45.0 + 70.0 * np.exp(-np.maximum(d, 0.0) * 30.0)
    bumbo = np.sin(2 * np.pi * np.cumsum(f * em) / SR) * np.exp(-np.maximum(d, 0.0) * 9.0) * em
    seco = normal(filtro(ruido(seg, sorte), 1500.0, 9000.0)) * np.exp(-np.maximum(d, 0.0) * 60.0) * em
    # o zumbido: tres parciais desafinadas entre si, com um tremido lento
    zumbe = np.zeros(n, dtype=np.float32)
    for fz, g, dec in ((2093.0, 1.0, 2.6), (3371.0, 0.55, 3.4), (5207.0, 0.3, 4.6)):
        vib = 1.0 + 0.003 * np.sin(2 * np.pi * 5.0 * t)
        zumbe += g * np.sin(2 * np.pi * np.cumsum(fz * vib) / SR) * np.exp(-np.maximum(d, 0.0) * dec)
    zumbe *= np.clip(d / 0.03, 0.0, 1.0) * em
    x += bumbo * 0.9 + seco * 0.35 + zumbe * 0.16
    x = reverb(x.astype(np.float32), 0.9, 0.18, sorte)[:n]
    gravar("flash_memoria.ogg", fade(x, 0.002, 0.25))


# ---------------------------------------------------------------- creditos
def creditos():
    linhas = ["Sons das cutscenes do fim do Capitulo 4 e do comeco do Capitulo 5",
              "(a queima na arena 2 e o despertar na igreja). Compostos por",
              "tools/audio/gerar_sons_capitulo_4.py.", "",
              "A VOZ (respiracao_maycow, gemido_maycow, grito_fogo, levantar_ferido)",
              "sai de pacotes CC0 (dominio publico) do OpenGameArt:", ""]
    vistos = set()
    for arq in USADOS:
        pag, titulo = ig.PACOTES[arq]
        if pag in vistos:
            continue
        vistos.add(pag)
        linhas.append("  \"%s\"  https://opengameart.org/content/%s" % (titulo, pag))
    linhas += ["", "O FOGO (fogo_rugindo, erupcao_fogo) e o flash de memoria (flash_memoria)",
               "sao sintetizados com ruido filtrado e senoide; o flash usa ainda o",
               "batimento do \"Heartbeat sounds\" e a erupcao, a pancada de metal do",
               "\"75 CC0 breaking / falling / hit sfx\" (os dois CC0, listados acima)."]
    os.makedirs(SAIDA, exist_ok=True)
    with open(os.path.join(SAIDA, "CREDITOS.txt"), "w") as f:
        f.write("\n".join(linhas) + "\n")


if __name__ == "__main__":
    ig.baixar()
    respiracao_maycow()
    gemido_maycow()
    grito_fogo()
    levantar_ferido()
    fogo_rugindo()
    erupcao_fogo()
    flash_memoria()
    creditos()
