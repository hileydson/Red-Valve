"""Pinta a pele das maos de primeira pessoa.

Rodar (python do sistema, precisa de Pillow e numpy):

    python3 tools/texturas/gerar_pele_maos.py

Entrada e saida ficam em red-valve/assets/3d_model/player/hands/maos_fp/:
    maos_fp_Baked_BaseColor.png   (entrada) o bake que veio do scan
    maos_fp_normal.png            (entrada) de onde sai a cavidade
    maos_fp_pele.png              (saida)   2048x2048 RGB, albedo de pele

==============================================================================
POR QUE REPINTAR

O bake que acompanha o modelo e' gesso: na area util a luminancia vai de 0,49 a
0,89, media 0,72, com as tres componentes quase iguais (0,735 / 0,732 / 0,650).
Ou seja, quase sem contraste e quase sem cor — na tela a mao fica branca, sem
pele nenhuma. As outras maos do jogo (`hand_magic`, `hand_rigged`) tem o mesmo
problema; a unica com cor e' a da pistola, que e' outro modelo.

Repintar aqui, e nao trocar a textura por uma de outro modelo, porque UV de
modelo diferente nao serve: as ilhas caem em lugares diferentes e a mao sai
com costura no meio da palma.

O QUE ENTRA NA COR

1. A luminancia do bake, com o contraste esticado (0,47..0,90 -> 0..1). E' o
   sombreamento suave que o scan ja' tinha, e sozinho ele quase nao aparece.
2. A CAVIDADE, tirada do mapa de normais: onde o campo de normais converge tem
   vinco (linha do nó do dedo, canto da unha, prega da palma). E' isto que da'
   a leitura de mao e nao de luva — o bake nao tem essa informacao.
3. Manchas de baixa frequencia (duas oitavas) puxando para o vermelho ou para
   o oliva. Pele lisa demais parece plastico.
4. Poro de alta frequencia, fraquinho.

A rampa vai de vinco escuro avermelhado a pele clara. Nada de branco puro no
topo: no jogo escuro, o especular ja' estoura sozinho.
"""

import os

import numpy as np
from PIL import Image

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PASTA = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "player", "hands", "maos_fp")
ENTRADA_COR = os.path.join(PASTA, "maos_fp_Baked_BaseColor.png")
ENTRADA_NORMAL = os.path.join(PASTA, "maos_fp_normal.png")
SAIDA = os.path.join(PASTA, "maos_fp_pele.png")

LADO = 2048
SEMENTE = 20260916

# Faixa util do bake. Fora dela e' fundo preto do atlas, que nao interessa.
BAKE_MIN, BAKE_MAX = 0.47, 0.90

# Rampa de pele: (posicao, r, g, b) em sRGB 0..1
# A primeira versao subia ate' 0,80 no topo e a mao saia CLARA demais na tela —
# num jogo escuro, com a luz propria das maos por perto, o topo da rampa e' o
# que o olho ve' quase o tempo todo. Esta rampa e' a mesma curva rebaixada ~25%
# e com um pouco mais de cor: o vinco continua sendo vinco, mas a pele para de
# brilhar como gesso.
RAMPA = [
    (0.00, 0.150, 0.080, 0.068),
    (0.28, 0.288, 0.180, 0.152),
    (0.55, 0.420, 0.300, 0.256),
    (0.80, 0.516, 0.396, 0.346),
    (1.00, 0.596, 0.476, 0.422),
]

## Quanto o vinco escurece.
FORCA_CAVIDADE = 0.42
## Expoente da cavidade. Sem ele, meio mapa fica "meio vincado" e a palma sai
## manchada de escuro; com 2,0 so' o vinco de verdade escurece.
GAMA_CAVIDADE = 2.0
## Quanto as manchas mexem em cada componente (vermelho sobe, verde/azul caem).
MANCHA = np.array([0.075, -0.035, -0.050])


def _ruido(lado, celulas, semente):
    """Ruido suave: sorteia uma grade pequena e amplia com bicubica."""
    rng = np.random.default_rng(semente)
    pequeno = rng.random((celulas, celulas)).astype(np.float32)
    img = Image.fromarray((pequeno * 255.0).astype(np.uint8), mode="L")
    img = img.resize((lado, lado), Image.BICUBIC)
    return np.asarray(img).astype(np.float32) / 255.0


def _media_caixa(a, raio):
    """Media de caixa separavel via soma acumulada (sem scipy)."""
    if raio < 1:
        return a
    n = 2 * raio + 1
    saida = a
    for eixo in (0, 1):
        p = np.pad(saida, [(raio + 1, raio) if e == eixo else (0, 0) for e in (0, 1)], mode="edge")
        c = np.cumsum(p, axis=eixo)
        if eixo == 0:
            saida = (c[n:, :] - c[:-n, :]) / n
        else:
            saida = (c[:, n:] - c[:, :-n]) / n
    return saida


def _cavidade(normal):
    """Onde o campo de normais converge tem vinco.

    O mapa de normais e' tangente: R e G sao X e Y da normal. A divergencia
    desse campo (quanto ele "aponta pra dentro") marca as concavidades — que e'
    exatamente onde a pele tem linha: nó do dedo, unha, prega da palma.
    """
    nx = normal[..., 0] * 2.0 - 1.0
    ny = normal[..., 1] * 2.0 - 1.0
    div = (np.roll(nx, 1, axis=1) - np.roll(nx, -1, axis=1)) \
        + (np.roll(ny, 1, axis=0) - np.roll(ny, -1, axis=0))
    div = _media_caixa(div, 2)
    escala = np.percentile(np.abs(div), 99.0)
    if escala <= 1e-6:
        return np.zeros_like(div)
    return np.clip(div / escala, 0.0, 1.0)


def _aplicar_rampa(t):
    """Interpola a rampa de pele para cada pixel."""
    pos = np.array([p for p, _r, _g, _b in RAMPA], dtype=np.float32)
    cores = np.array([[r, g, b] for _p, r, g, b in RAMPA], dtype=np.float32)
    saida = np.empty(t.shape + (3,), dtype=np.float32)
    for c in range(3):
        saida[..., c] = np.interp(t, pos, cores[:, c])
    return saida


def main():
    cor = np.asarray(Image.open(ENTRADA_COR).convert("RGB").resize((LADO, LADO),
            Image.LANCZOS)).astype(np.float32) / 255.0
    normal = np.asarray(Image.open(ENTRADA_NORMAL).convert("RGB").resize((LADO, LADO),
            Image.LANCZOS)).astype(np.float32) / 255.0

    lum = cor[..., 0] * 0.299 + cor[..., 1] * 0.587 + cor[..., 2] * 0.114
    # Fora das ilhas de UV o bake e' preto. Puxar esses pixels para o meio da
    # faixa evita que a interpolacao da GPU chupe preto na costura das ilhas.
    fora = lum < 0.05
    lum = np.where(fora, 0.72, lum)
    t = np.clip((lum - BAKE_MIN) / (BAKE_MAX - BAKE_MIN), 0.0, 1.0)

    pele = _aplicar_rampa(t)

    cav = _cavidade(normal) ** GAMA_CAVIDADE
    pele *= (1.0 - FORCA_CAVIDADE * cav)[..., None]
    # O vinco nao e' so mais escuro: e' mais vermelho, porque a carne aparece.
    pele[..., 0] += cav * 0.040
    pele[..., 2] -= cav * 0.015

    manchas = (_ruido(LADO, 22, SEMENTE) - 0.5) * 1.35 \
        + (_ruido(LADO, 64, SEMENTE + 17) - 0.5) * 0.75
    pele *= 1.0 + manchas[..., None] * MANCHA[None, None, :]

    poro = (_ruido(LADO, 512, SEMENTE + 101) - 0.5) * 0.05
    pele *= 1.0 + poro[..., None]

    pele = np.clip(pele, 0.0, 1.0)
    Image.fromarray((pele * 255.0 + 0.5).astype(np.uint8), mode="RGB").save(SAIDA)

    usada = ~fora
    print("pele: %s" % SAIDA)
    print("  media na area util: %s" % [round(float(pele[..., i][usada].mean()), 3) for i in range(3)])
    print("  cavidade: media %.3f, p99 %.3f" % (float(cav.mean()), float(np.percentile(cav, 99))))
    return SAIDA


if __name__ == "__main__":
    main()
