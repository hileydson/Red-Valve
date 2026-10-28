"""Desenha as texturas de vitral da igreja destruida.

Rodar (python do sistema, precisa de Pillow):

    python3 tools/texturas/gerar_vitrais.py

Saida: red-valve/assets/images/textures/igreja/
    vitral_lanceta.png      janela ogival alta e estreita (nave e clerestorio)
    vitral_lanceta_roto.png a mesma, com painel faltando (alfa 0 nos buracos)
    vitral_rosacea.png      rosacea da fachada oeste
    vitral_abside.png       janela larga do fundo, mais dourada
    vidro_caco.png          cacos soltos, pro chao

==============================================================================
POR QUE ESTAS TEXTURAS EXISTEM

O interior e' escuro de proposito: a leitura do espaco vem quase toda da luz
que entra pelas janelas. Vitral feito de geometria (um quad colorido por peca)
custaria milhares de triangulos por janela e ficaria chapado; vitral feito de
UMA cor emissiva vira lanterna sem desenho. Uma textura resolve os dois: o
desenho fica na imagem, a janela continua sendo dois triangulos, e a MESMA
imagem entra em `emission_texture` no Godot — entao o vitral brilha exatamente
onde e' claro e fica preto no chumbo.

O alfa nao e' enfeite: na versao `_roto` os paineis que faltam tem alfa 0, e o
material usa alpha scissor. E' por esses buracos que o feixe de luz entra sem
cor nenhuma, que e' o que da' o contraste entre "janela inteira" e "janela
arrombada" sem precisar de duas malhas diferentes.

PALETA: azul cobalto, rubi, ambar e verde-garrafa sujos — nada saturado demais,
porque no jogo a emissao multiplica a cor e vitral limpo fica parecendo
neon. O chumbo e' preto quase puro e GROSSO (3-5 px): e' ele que segura o
desenho quando a textura for vista a 15 m de distancia, no escuro.
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "red-valve", "assets", "images", "textures", "igreja")

# Cores de vidro. Guardadas escuras: a emissao no Godot levanta tudo.
COBALTO = [(24, 46, 120), (30, 58, 140), (18, 38, 100), (40, 72, 158)]
RUBI = [(120, 22, 28), (142, 30, 34), (96, 16, 22), (158, 44, 40)]
AMBAR = [(158, 112, 30), (178, 134, 44), (134, 92, 24), (196, 156, 62)]
VERDE = [(28, 86, 62), (36, 104, 74), (22, 70, 52)]
VIOLETA = [(74, 34, 96), (92, 46, 116), (60, 26, 80)]
CREME = [(178, 168, 138), (196, 186, 158), (160, 150, 122)]
CHUMBO = (10, 9, 12)


def _sujar(cor, rnd, forca=18):
    """Uma peca de vidro nunca e' lisa: varia de tom e tem sujeira."""
    return tuple(max(0, min(255, c + rnd.randint(-forca, forca))) for c in cor)


def _escolher(paleta, rnd):
    return _sujar(rnd.choice(paleta), rnd)


def _poligono(dr, pts, cor, chumbo=3):
    dr.polygon(pts, fill=cor, outline=CHUMBO)
    if chumbo > 1:
        dr.line(list(pts) + [pts[0]], fill=CHUMBO, width=chumbo)


def _arco_ogival(largura, altura_reta, altura_total, passos=48):
    """Contorno da lanceta: lados retos ate' `altura_reta`, dai' ponta ogival.

    Devolve a lista de pontos em sentido horario, com y=0 no TOPO da imagem
    (convencao do PIL).
    """
    meia = largura / 2.0
    flecha = altura_reta - 0  # altura da ponta, em pixels
    # Arco ogival: centro deslocado, R = c + meia (ver gerar_igreja.py).
    h = flecha
    c = (h * h - meia * meia) / (2.0 * meia) if meia > 0 else 0.0
    c = max(c, 0.0)
    r = c + meia
    pts = [(0, altura_total), (0, altura_reta)]
    for i in range(passos + 1):
        x = -meia + (largura * i / passos)
        dx = abs(x) + c
        y = math.sqrt(max(r * r - dx * dx, 0.0))
        pts.append((meia + x, altura_reta - y))
    pts.append((largura, altura_total))
    return pts


def _mascara_ogival(w, h, topo):
    """Mascara branca dentro do contorno da lanceta, preta fora."""
    m = Image.new("L", (w, h), 0)
    dr = ImageDraw.Draw(m)
    dr.polygon(_arco_ogival(w, topo, h), fill=255)
    return m


def _malha_losangos(dr, caixa, paleta, rnd, passo=26):
    """Fundo de grisalha: losangos pequenos, o preenchimento classico."""
    x0, y0, x1, y1 = caixa
    i = 0
    y = y0 - passo
    while y < y1 + passo:
        x = x0 - passo
        j = 0
        while x < x1 + passo:
            desl = passo / 2.0 if (i % 2) else 0.0
            cx, cy = x + desl, y
            pts = [(cx, cy - passo * 0.55), (cx + passo * 0.5, cy),
                   (cx, cy + passo * 0.55), (cx - passo * 0.5, cy)]
            cor = _escolher(paleta, rnd)
            _poligono(dr, pts, cor, chumbo=2)
            x += passo
            j += 1
        y += passo * 0.9
        i += 1


def _medalhao(dr, cx, cy, raio, rnd, cor_fundo, cor_figura, raios=8):
    """Medalhao circular: aro, fatias e uma figura abstrata no meio.

    Figura abstrata de proposito — santo desenhado em 64 px vira borrao, e
    forma geometrica le' bem de longe (que e' como o jogador vai ver isto).
    """
    dr.ellipse([cx - raio, cy - raio, cx + raio, cy + raio],
               fill=_escolher(cor_fundo, rnd), outline=CHUMBO, width=4)
    for k in range(raios):
        a0 = 2 * math.pi * k / raios
        a1 = 2 * math.pi * (k + 0.5) / raios
        pts = [(cx, cy),
               (cx + raio * math.cos(a0), cy + raio * math.sin(a0)),
               (cx + raio * math.cos(a1), cy + raio * math.sin(a1))]
        _poligono(dr, pts, _escolher(cor_fundo, rnd), chumbo=2)
    r2 = raio * 0.58
    dr.ellipse([cx - r2, cy - r2, cx + r2, cy + r2],
               fill=_escolher(cor_figura, rnd), outline=CHUMBO, width=4)
    # cruz / estrela interna
    braco = r2 * 0.75
    grossura = max(3, int(r2 * 0.22))
    dr.line([(cx - braco, cy), (cx + braco, cy)], fill=CHUMBO, width=grossura)
    dr.line([(cx, cy - braco), (cx, cy + braco)], fill=CHUMBO, width=grossura)
    d = braco * 0.62
    dr.line([(cx - d, cy - d), (cx + d, cy + d)], fill=CHUMBO, width=max(2, grossura // 2))
    dr.line([(cx - d, cy + d), (cx + d, cy - d)], fill=CHUMBO, width=max(2, grossura // 2))


def _textura_pedra(img, rnd, forca=16):
    """Ruido fino por cima: vitral velho tem poeira e chumbo oxidado."""
    ruido = Image.new("L", img.size)
    px = ruido.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            px[x, y] = rnd.randint(128 - forca, 128 + forca)
    ruido = ruido.filter(ImageFilter.GaussianBlur(0.6))
    base = img.convert("RGBA")
    cinza = Image.merge("RGBA", (ruido, ruido, ruido, Image.new("L", img.size, 255)))
    return Image.blend(base, cinza, 0.10)


def _buracos(img, rnd, quantos=6, raio=(30, 90)):
    """Arranca pedacos do vitral: alfa 0, borda irregular."""
    w, h = img.size
    alfa = img.getchannel("A")
    dr = ImageDraw.Draw(alfa)
    for _ in range(quantos):
        cx = rnd.randint(int(w * 0.1), int(w * 0.9))
        cy = rnd.randint(int(h * 0.05), int(h * 0.95))
        r = rnd.randint(*raio)
        pts = []
        for k in range(10):
            a = 2 * math.pi * k / 10
            rr = r * rnd.uniform(0.55, 1.25)
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        dr.polygon(pts, fill=0)
    img.putalpha(alfa)
    return img


# --------------------------------------------------------------------------
# as janelas


def vitral_lanceta(semente=7, w=384, h=1024, quebrado=False):
    rnd = random.Random(semente)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)

    topo = int(h * 0.34)  # onde comeca a ponta ogival
    paleta_fundo = COBALTO + CREME
    _malha_losangos(dr, (0, 0, w, h), paleta_fundo, rnd, passo=int(w / 7.5))

    # tres medalhoes na vertical, o do meio maior
    for k, (fy, fr, fundo, fig) in enumerate((
            (0.52, 0.40, RUBI, AMBAR),
            (0.72, 0.34, VERDE, RUBI),
            (0.90, 0.30, VIOLETA, AMBAR))):
        _medalhao(dr, w / 2, h * fy, w * fr, rnd, fundo, fig, raios=8 + 2 * k)

    # bordadura: faixa de cor nas laterais
    faixa = int(w * 0.09)
    for lado in (0, w - faixa):
        y = 0
        while y < h:
            _poligono(dr, [(lado, y), (lado + faixa, y),
                           (lado + faixa, y + faixa * 1.4), (lado, y + faixa * 1.4)],
                      _escolher(AMBAR if (y // 40) % 2 else RUBI, rnd), chumbo=2)
            y += int(faixa * 1.4)

    # barras horizontais de ferro (ferramenta) — sempre existem e ajudam a
    # quebrar a verticalidade
    for k in range(1, 9):
        y = h * k / 9.0
        dr.line([(0, y), (w, y)], fill=(8, 8, 10), width=4)

    img = _textura_pedra(img, rnd)
    img.putalpha(_mascara_ogival(w, h, topo))

    if quebrado:
        img = _buracos(img, rnd, quantos=7, raio=(26, 78))
    return img


def vitral_rosacea(semente=11, lado=1024, quebrado=True):
    rnd = random.Random(semente)
    img = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    c = lado / 2.0
    r_ext = lado * 0.49

    # aneis concentricos, do maior pro menor
    aneis = ((0.49, 0.38, 16, COBALTO), (0.38, 0.27, 12, RUBI),
             (0.27, 0.17, 8, AMBAR), (0.17, 0.09, 6, VERDE))
    for r1, r0, fatias, paleta in aneis:
        for k in range(fatias):
            a0 = 2 * math.pi * k / fatias
            a1 = 2 * math.pi * (k + 1) / fatias
            pts = []
            for a in (a0, a1):
                pts.append((c + lado * r1 * math.cos(a), c + lado * r1 * math.sin(a)))
            pts.append((c + lado * r0 * math.cos(a1), c + lado * r0 * math.sin(a1)))
            pts.append((c + lado * r0 * math.cos(a0), c + lado * r0 * math.sin(a0)))
            _poligono(dr, pts, _escolher(paleta, rnd), chumbo=4)

    # petalas: circulos pequenos no anel de fora, como olho-de-boi
    for k in range(16):
        a = 2 * math.pi * (k + 0.5) / 16
        px, py = c + lado * 0.435 * math.cos(a), c + lado * 0.435 * math.sin(a)
        rr = lado * 0.045
        dr.ellipse([px - rr, py - rr, px + rr, py + rr],
                   fill=_escolher(CREME, rnd), outline=CHUMBO, width=4)

    _medalhao(dr, c, c, lado * 0.09, rnd, AMBAR, RUBI, raios=8)

    # mascara circular
    m = Image.new("L", (lado, lado), 0)
    ImageDraw.Draw(m).ellipse([c - r_ext, c - r_ext, c + r_ext, c + r_ext], fill=255)
    img = _textura_pedra(img, rnd)
    img.putalpha(m)
    if quebrado:
        img = _buracos(img, rnd, quantos=5, raio=(40, 110))
    return img


def vitral_abside(semente=23, w=640, h=1024):
    """Janela do fundo: mais dourada, porque e' ela que fica atras do altar."""
    rnd = random.Random(semente)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    _malha_losangos(dr, (0, 0, w, h), AMBAR + CREME, rnd, passo=int(w / 11.0))
    for k, fy in enumerate((0.40, 0.62, 0.84)):
        _medalhao(dr, w / 2, h * fy, w * 0.22, rnd,
                  (RUBI, COBALTO, VERDE)[k], AMBAR, raios=10)
    for k in range(1, 8):
        y = h * k / 8.0
        dr.line([(0, y), (w, y)], fill=(8, 8, 10), width=4)
    img = _textura_pedra(img, rnd)
    img.putalpha(_mascara_ogival(w, h, int(h * 0.30)))
    return _buracos(img, rnd, quantos=4, raio=(30, 70))


def vidro_caco(semente=31, lado=512):
    """Cacos no chao: fundo transparente, estilhacos coloridos espalhados."""
    rnd = random.Random(semente)
    img = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    paleta = COBALTO + RUBI + AMBAR + VERDE + VIOLETA
    for _ in range(150):
        cx, cy = rnd.randint(0, lado), rnd.randint(0, lado)
        r = rnd.uniform(4, 16)
        pts = []
        for k in range(rnd.randint(3, 5)):
            a = 2 * math.pi * k / 4 + rnd.uniform(-0.5, 0.5)
            rr = r * rnd.uniform(0.4, 1.0)
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        dr.polygon(pts, fill=_escolher(paleta, rnd) + (255,))
    return img


def main():
    os.makedirs(SAIDA, exist_ok=True)
    saidas = {
        "vitral_lanceta.png": vitral_lanceta(quebrado=False),
        "vitral_lanceta_roto.png": vitral_lanceta(semente=19, quebrado=True),
        "vitral_rosacea.png": vitral_rosacea(),
        "vitral_abside.png": vitral_abside(),
        "vidro_caco.png": vidro_caco(),
    }
    for nome, img in saidas.items():
        caminho = os.path.join(SAIDA, nome)
        img.save(caminho)
        print("%-26s %s  %s" % (nome, img.size, "%.0f KB" % (os.path.getsize(caminho) / 1024)))


if __name__ == "__main__":
    main()
