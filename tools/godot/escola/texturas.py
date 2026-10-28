"""As texturas proprias da escola: papel, cartaz, desenho de crianca, marca e
sujeira de chao. Desenhadas aqui, em Python, e gravadas em atlas.

    python3 tools/godot/escola/texturas.py

Sai em `red-valve/assets/images/textures/escola/`:

    papeis.png    3 x 4  folhas soltas (caderno, prova, desenho, aviso, jornal)
    cartazes.png  3 x 2  cartaz didatico de parede
    marcas.png    4 x 2  mao, arranhao, contagem, seta de giz, teia, infiltracao
    chao.png      4 x 2  poca, folha seca, caco, pegada, barro

==============================================================================
NENHUMA PALAVRA ESCRITA NA TEXTURA

Tudo o que se le' na escola (titulo de cartaz, aviso, lousa, placa) e' um
`Label3D` com chave do CSV de traducao — e' assim que o ingles sai de graca.
Por isso o papel aqui so' tem RABISCO que parece letra (garrancho, linha de
texto cinza) e a faixa do titulo do cartaz nasce VAZIA: quem escreve nela e' o
gerador da cena, por cima. Letra solta e numero (o alfabeto, a tabuada) podem
ficar, porque nao tem idioma.

==============================================================================
SEMENTE FIXA

Cada atlas tem a sua semente. Sem isso o desenho muda a cada build e duas
capturas de tela da mesma sala deixam de ser comparaveis.
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
DIR = os.path.join(RAIZ, "red-valve", "assets", "images", "textures", "escola")
RES = "res://assets/images/textures/escola"

# ==========================================================================
# GRADES DOS ATLAS — quem posiciona o quad le' o recorte daqui
# ==========================================================================

ATLAS = {
    # nome: (largura, altura, colunas, linhas)
    "papeis": (1024, 1024, 4, 3),
    "cartazes": (1024, 1024, 3, 2),
    "marcas": (1024, 512, 4, 2),
    "chao": (1024, 512, 4, 2),
    "bandeiras": (512, 128, 4, 1),
}

PAPEIS = ["caderno", "caderno_amassado", "quadriculado", "prova",
          "desenho_casa", "desenho_familia", "desenho_escada", "aviso",
          "desaparecido", "jornal", "pardo", "contagem"]
CARTAZES = ["alfabeto", "tabuada", "corpo", "planetas", "tabela", "mapa"]
MARCAS = ["mao", "arrasto", "riscos", "seta", "unhas", "teia", "infiltracao",
          "buraco_forro"]
CHAO = ["poca", "folhas", "cacos", "pegadas", "papel_picado", "mancha",
        "barro", "pezinhos"]
BANDEIRAS = ["vermelha", "amarela", "azul", "verde"]


def recorte(atlas, nome):
    """(u0, v0, du, dv) da celula `nome` no atlas — o que o material quer em
    `uv1_offset` / `uv1_scale`."""
    lista = {"papeis": PAPEIS, "cartazes": CARTAZES, "marcas": MARCAS,
             "chao": CHAO, "bandeiras": BANDEIRAS}[atlas]
    _w, _h, cols, linhas = ATLAS[atlas]
    i = lista.index(nome)
    return ((i % cols) / float(cols), (i // cols) / float(linhas),
            1.0 / cols, 1.0 / linhas)


def proporcao(atlas):
    """altura / largura de uma celula."""
    w, h, cols, linhas = ATLAS[atlas]
    return (h / float(linhas)) / (w / float(cols))


def caminho_res(atlas):
    return "%s/%s.png" % (RES, atlas)


# ==========================================================================
# FERRAMENTAS DE DESENHO
# ==========================================================================

def _ruido(w, h, rng, escala=1.0, forca=18):
    """Ruido de valor suavizado: o que tira o chapado do papel."""
    pequeno = Image.new("L", (max(w // 8, 2), max(h // 8, 2)))
    px = pequeno.load()
    for y in range(pequeno.size[1]):
        for x in range(pequeno.size[0]):
            px[x, y] = 128 + int(rng.uniform(-forca, forca))
    return pequeno.resize((w, h), Image.BICUBIC).filter(
        ImageFilter.GaussianBlur(1.5 * escala))


def _papel(w, h, cor, rng, amassado=0.0, mancha=0.0, rasgo=0.0):
    """Folha com fibra, amarelado de borda e — se pedir — vinco de amassado.

    Devolve RGBA: o alfa recorta a borda (rasgo e canto dobrado), entao a
    folha nao e' um retangulo perfeito colado na parede.
    """
    img = Image.new("RGB", (w, h), cor)
    base = _ruido(w, h, rng, 1.0, 10)
    r, g, b = cor
    px = img.load()
    bp = base.load()
    for y in range(h):
        for x in range(w):
            n = (bp[x, y] - 128) / 128.0
            borda = min(x, y, w - 1 - x, h - 1 - y) / float(min(w, h))
            amarelo = max(0.0, 0.12 - borda) * 2.2
            px[x, y] = (int(max(0, min(255, r + n * 14 - amarelo * 40))),
                        int(max(0, min(255, g + n * 14 - amarelo * 46))),
                        int(max(0, min(255, b + n * 14 - amarelo * 80))))
    d = ImageDraw.Draw(img, "RGBA")
    if amassado > 0:
        # vincos: faceta clara de um lado, escura do outro — e' como a luz
        # rasante desenha papel amassado. Desenhado numa camada a parte e
        # borrado, senao vira risco de regua em cima da folha.
        camada = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        dc = ImageDraw.Draw(camada, "RGBA")
        for _ in range(int(10 * amassado)):
            x0, y0 = rng.uniform(0, w), rng.uniform(0, h)
            ang = rng.uniform(0, math.pi)
            comp = rng.uniform(0.2, 0.55) * max(w, h)
            x1, y1 = x0 + math.cos(ang) * comp, y0 + math.sin(ang) * comp
            nx, ny = -math.sin(ang) * 10, math.cos(ang) * 10
            dc.polygon([(x0, y0), (x1, y1), (x1 + nx, y1 + ny), (x0 + nx, y0 + ny)],
                       fill=(0, 0, 0, int(26 * amassado)))
            dc.polygon([(x0, y0), (x1, y1), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)],
                       fill=(255, 255, 255, int(20 * amassado)))
        camada = camada.filter(ImageFilter.GaussianBlur(3))
        img.paste(camada, (0, 0), camada)
        d = ImageDraw.Draw(img, "RGBA")
    if mancha > 0:
        for _ in range(int(3 * mancha) + 1):
            cx, cy = rng.uniform(0, w), rng.uniform(0, h)
            raio = rng.uniform(0.08, 0.3) * w
            for k in range(6):
                rr = raio * (1.0 - k * 0.12)
                d.ellipse((cx - rr, cy - rr * 0.8, cx + rr, cy + rr * 0.8),
                          outline=(110, 80, 40, int(30 * mancha)), width=3)
            d.ellipse((cx - raio, cy - raio * 0.8, cx + raio, cy + raio * 0.8),
                      fill=(120, 90, 50, int(22 * mancha)))
    alfa = Image.new("L", (w, h), 255)
    da = ImageDraw.Draw(alfa)
    if rasgo > 0:
        # a beira de cima arrancada do bloco: dente irregular
        pts = [(0, 0)]
        x = 0.0
        while x < w:
            pts.append((x, rng.uniform(0, 10 * rasgo)))
            x += rng.uniform(3, 9)
        pts += [(w, 0)]
        da.polygon(pts, fill=0)
    # um canto dobrado, sempre
    c = int(rng.uniform(0.08, 0.16) * w)
    canto = rng.randrange(4)
    if canto == 0:
        da.polygon([(w - c, h), (w, h), (w, h - c)], fill=0)
        d.polygon([(w - c, h), (w, h - c), (w - c, h - c)], fill=(0, 0, 0, 40))
    elif canto == 1:
        da.polygon([(0, h - c), (0, h), (c, h)], fill=0)
        d.polygon([(0, h - c), (c, h), (c, h - c)], fill=(0, 0, 0, 40))
    # o recorte so' entra no FIM, quando a celula ja' foi desenhada: desenhar
    # com ImageDraw numa imagem RGBA SUBSTITUI o alfa em vez de misturar, e a
    # mancha de 20 % de opacidade virava uma bola marrom solida.
    img.alfa = alfa
    return img


def _fechar(img):
    """Aplica o recorte guardado por `_papel` depois de tudo desenhado."""
    alfa = img.alfa
    img = img.convert("RGBA")
    img.putalpha(alfa)
    return img


def _garrancho(d, x0, y, largura, rng, cor, altura=7, espessura=2):
    """Uma linha de 'letra cursiva' que nao diz nada em lingua nenhuma."""
    x = x0
    while x < x0 + largura:
        palavra = rng.uniform(14, 46)
        pts = []
        t = 0.0
        while t < palavra:
            pts.append((x + t, y + math.sin(t * rng.uniform(0.6, 1.1)) * altura * 0.5
                        + rng.uniform(-1.5, 1.5)))
            t += rng.uniform(2.0, 3.6)
        if len(pts) > 1:
            d.line(pts, fill=cor, width=espessura, joint="curve")
        x += palavra + rng.uniform(6, 12)


def _linhas_de_texto(d, x0, y0, x1, y1, passo, rng, cor, falhas=0.25):
    """Texto impresso visto de longe: barrinhas cinzas de comprimento solto."""
    y = y0
    while y < y1:
        x = x0
        fim = x1 - (rng.uniform(0, (x1 - x0) * 0.5) if rng.random() < falhas else 0)
        while x < fim:
            w = rng.uniform(10, 34)
            d.rectangle((x, y, min(x + w, fim), y + passo * 0.38), fill=cor)
            x += w + rng.uniform(4, 7)
        y += passo


def _giz_de_cera(d, pts, cor, largura, rng, falhas=0.25):
    """Traco de giz de cera: grosso, falhado, com o papel aparecendo."""
    for k in range(len(pts) - 1):
        (ax, ay), (bx, by) = pts[k], pts[k + 1]
        passos = max(int(math.hypot(bx - ax, by - ay) / 1.5), 1)
        for s in range(passos):
            t = s / float(passos)
            x, y = ax + (bx - ax) * t, ay + (by - ay) * t
            for _ in range(3):
                if rng.random() < falhas:
                    continue
                ox, oy = rng.uniform(-largura, largura) * 0.5, rng.uniform(-largura, largura) * 0.5
                rr = rng.uniform(0.6, 1.6)
                a = int(cor[3] * rng.uniform(0.5, 1.0)) if len(cor) > 3 else 220
                d.ellipse((x + ox - rr, y + oy - rr, x + ox + rr, y + oy + rr),
                          fill=(cor[0], cor[1], cor[2], a))


def _circulo_pts(cx, cy, r, rng, n=28, torto=0.08):
    return [(cx + math.cos(t * 2 * math.pi / n) * r * (1 + rng.uniform(-torto, torto)),
             cy + math.sin(t * 2 * math.pi / n) * r * (1 + rng.uniform(-torto, torto)))
            for t in range(n + 1)]


def _boneco(d, cx, base, altura, cor, rng, largura=4):
    cabeca = altura * 0.18
    _giz_de_cera(d, _circulo_pts(cx, base - altura + cabeca, cabeca, rng, 16, 0.12),
                 cor, largura, rng)
    pescoco = base - altura + cabeca * 2
    quadril = base - altura * 0.38
    _giz_de_cera(d, [(cx, pescoco), (cx + rng.uniform(-2, 2), quadril)], cor, largura, rng)
    _giz_de_cera(d, [(cx - altura * 0.22, pescoco + altura * 0.12), (cx, pescoco + altura * 0.08),
                     (cx + altura * 0.22, pescoco + altura * 0.14)], cor, largura, rng)
    _giz_de_cera(d, [(cx - altura * 0.15, base), (cx, quadril), (cx + altura * 0.15, base)],
                 cor, largura, rng)


# ==========================================================================
# PAPEIS
# ==========================================================================

def _celula_papel(nome, w, h, rng):
    branco = (226, 222, 205)
    if nome in ("caderno", "caderno_amassado"):
        img = _papel(w, h, branco, rng, amassado=1.6 if nome.endswith("amassado") else 0.3,
                     mancha=0.6, rasgo=1.0)
        d = ImageDraw.Draw(img, "RGBA")
        for y in range(40, h - 8, 13):
            d.line((0, y, w, y), fill=(90, 130, 190, 120), width=1)
        d.line((30, 0, 30, h), fill=(200, 70, 70, 140), width=1)
        tinta = (40, 50, 120, 210) if rng.random() < 0.6 else (40, 40, 40, 200)
        for y in range(52, int(h * rng.uniform(0.55, 0.9)), 13):
            _garrancho(d, 36, y - 4, w - 50, rng, tinta)
        return img
    if nome == "quadriculado":
        img = _papel(w, h, (230, 228, 214), rng, amassado=0.5, mancha=0.4)
        d = ImageDraw.Draw(img, "RGBA")
        for k in range(0, max(w, h), 9):
            d.line((k, 0, k, h), fill=(120, 150, 170, 70))
            d.line((0, k, w, k), fill=(120, 150, 170, 70))
        for y in range(30, h - 40, 26):
            _garrancho(d, 18, y, w - 40, rng, (30, 30, 30, 200), 9)
        return img
    if nome == "prova":
        img = _papel(w, h, (232, 230, 220), rng, amassado=0.8, mancha=0.5)
        d = ImageDraw.Draw(img, "RGBA")
        d.rectangle((14, 14, w - 14, 46), outline=(60, 60, 60, 180), width=2)
        _linhas_de_texto(d, 20, 22, w - 20, 40, 9, rng, (70, 70, 70, 160), 0.0)
        y = 60
        for q in range(5):
            _linhas_de_texto(d, 18, y, w - 18, y + 26, 9, rng, (60, 60, 60, 170))
            for k in range(3):
                d.ellipse((24, y + 32 + k * 12, 32, y + 40 + k * 12), outline=(60, 60, 60, 170))
                d.rectangle((38, y + 34 + k * 12, 38 + rng.uniform(40, 120), y + 37 + k * 12),
                            fill=(90, 90, 90, 140))
            # a correcao em caneta vermelha
            if rng.random() < 0.6:
                xx, yy = w - 40, y + 30
                d.line((xx, yy, xx + 18, yy + 18), fill=(190, 30, 30, 220), width=3)
                d.line((xx + 18, yy, xx, yy + 18), fill=(190, 30, 30, 220), width=3)
            y += 56
        d.ellipse((w - 70, 12, w - 18, 56), outline=(190, 30, 30, 230), width=3)
        return img
    if nome.startswith("desenho"):
        img = _papel(w, h, (236, 234, 226), rng, amassado=0.4, mancha=0.3)
        d = ImageDraw.Draw(img, "RGBA")
        if nome == "desenho_casa":
            _giz_de_cera(d, [(30, h - 60), (w - 30, h - 60)], (60, 140, 60, 230), 8, rng)
            casa = [(70, h - 62), (70, h - 160), (w - 70, h - 160), (w - 70, h - 62)]
            _giz_de_cera(d, casa, (180, 60, 40, 230), 5, rng)
            _giz_de_cera(d, [(55, h - 158), (w / 2, h - 230), (w - 55, h - 158)],
                         (120, 50, 30, 230), 5, rng)
            _giz_de_cera(d, [(w / 2 - 14, h - 62), (w / 2 - 14, h - 112), (w / 2 + 14, h - 112),
                             (w / 2 + 14, h - 62)], (90, 60, 30, 230), 4, rng)
            _giz_de_cera(d, _circulo_pts(w - 50, 50, 24, rng), (240, 190, 30, 240), 6, rng)
            for k in range(8):
                a = k * math.pi / 4
                _giz_de_cera(d, [(w - 50 + math.cos(a) * 32, 50 + math.sin(a) * 32),
                                 (w - 50 + math.cos(a) * 46, 50 + math.sin(a) * 46)],
                             (240, 190, 30, 240), 4, rng)
            # e a janela de cima pintada de preto, que ninguem sabe por que
            _giz_de_cera(d, [(96, h - 140), (124, h - 140), (124, h - 118), (96, h - 118),
                             (96, h - 140), (124, h - 118)], (20, 20, 20, 250), 6, rng)
        elif nome == "desenho_familia":
            _giz_de_cera(d, [(20, h - 50), (w - 20, h - 50)], (60, 140, 60, 230), 8, rng)
            for (cx, alt, cor) in ((60, 110, (40, 80, 180, 230)), (110, 120, (190, 50, 120, 230)),
                                   (150, 70, (230, 140, 30, 230))):
                _boneco(d, cx, h - 52, alt, cor, rng)
            # a figura alta, preta, sem rosto, do lado da familia
            _boneco(d, w - 50, h - 52, 230, (15, 15, 15, 255), rng, 7)
            for _ in range(160):
                x = w - 50 + rng.uniform(-22, 22)
                y = rng.uniform(h - 270, h - 60)
                d.line((x, y, x + rng.uniform(-6, 6), y + rng.uniform(4, 12)),
                       fill=(10, 10, 10, 160), width=2)
        else:
            # a escada descendo e o boneco no fim dela
            for k in range(7):
                y = 60 + k * 30
                x = 30 + k * 22
                _giz_de_cera(d, [(x, y), (x + 40, y), (x + 40, y + 30)], (90, 70, 50, 230), 5, rng)
            _boneco(d, w - 50, h - 60, 70, (20, 20, 20, 250), rng)
            for _ in range(5):
                pts = [(rng.uniform(10, w - 10), rng.uniform(10, h - 10)) for _ in range(6)]
                _giz_de_cera(d, pts, (160, 20, 20, 200), 4, rng, 0.4)
        return img
    if nome == "aviso":
        img = _papel(w, h, (228, 226, 214), rng, amassado=0.3, mancha=0.8)
        d = ImageDraw.Draw(img, "RGBA")
        # faixa de titulo VAZIA (o Label3D escreve nela) e o corpo datilografado
        _linhas_de_texto(d, 22, 96, w - 22, h - 60, 12, rng, (50, 50, 50, 170), 0.35)
        d.line((w - 110, h - 34, w - 24, h - 34), fill=(40, 40, 40, 160), width=1)
        _garrancho(d, w - 108, h - 46, 80, rng, (30, 40, 110, 200), 8)
        # o furo do percevejo
        d.ellipse((w / 2 - 5, 6, w / 2 + 5, 16), fill=(180, 30, 30, 255))
        return img
    if nome == "desaparecido":
        img = _papel(w, h, (230, 229, 222), rng, amassado=0.7, mancha=1.2)
        d = ImageDraw.Draw(img, "RGBA")
        fx0, fy0, fx1, fy1 = 46, 70, w - 46, 70 + (w - 92) * 1.1
        d.rectangle((fx0, fy0, fx1, fy1), fill=(80, 80, 78, 255))
        # retrato em xerox: cabeca e ombros, granulado e sem rosto legivel
        cx = (fx0 + fx1) / 2
        d.ellipse((cx - 38, fy0 + 34, cx + 38, fy0 + 120), fill=(150, 148, 142, 255))
        d.ellipse((cx - 80, fy0 + 118, cx + 80, fy1 + 60), fill=(120, 118, 112, 255))
        d.rectangle((fx0, fy1, fx1, fy1 + 60), fill=img.getpixel((10, int(fy1) + 20)))
        for _ in range(900):
            x, y = rng.uniform(fx0, fx1), rng.uniform(fy0, fy1)
            v = int(rng.uniform(40, 200))
            d.point((x, y), fill=(v, v, v, 120))
        d.rectangle((fx0, fy0, fx1, fy1), outline=(20, 20, 20, 255), width=2)
        _linhas_de_texto(d, 30, fy1 + 52, w - 30, h - 16, 11, rng, (40, 40, 40, 190), 0.2)
        return img
    if nome == "jornal":
        img = _papel(w, h, (200, 196, 180), rng, amassado=1.0, mancha=1.0)
        d = ImageDraw.Draw(img, "RGBA")
        d.rectangle((12, 12, w - 12, 40), fill=(30, 30, 30, 200))
        d.rectangle((14, 52, w * 0.62, 140), fill=(90, 90, 88, 220))
        col = (w - 30) / 3.0
        for k in range(3):
            x0 = 15 + k * col
            _linhas_de_texto(d, x0, 150 if k < 2 else 52, x0 + col - 8, h - 14, 7, rng,
                             (50, 50, 50, 170), 0.05)
        return img
    if nome == "pardo":
        img = _papel(w, h, (176, 142, 100), rng, amassado=1.2, mancha=1.4, rasgo=1.6)
        d = ImageDraw.Draw(img, "RGBA")
        _garrancho(d, 30, h * 0.45, w - 60, rng, (30, 25, 20, 200), 10, 3)
        return img
    # contagem: os riscos de quem estava contando os dias
    img = _papel(w, h, (224, 222, 210), rng, amassado=0.6, mancha=0.9, rasgo=1.2)
    d = ImageDraw.Draw(img, "RGBA")
    y = 34
    while y < h - 30:
        x = 20
        while x < w - 40:
            for k in range(4):
                d.line((x + k * 7, y, x + k * 7 + rng.uniform(-2, 2), y + 22),
                       fill=(40, 40, 40, 220), width=2)
            d.line((x - 3, y + 16, x + 26, y + 4), fill=(40, 40, 40, 220), width=2)
            x += 40
        y += 34
    return img


def gerar_papeis():
    w, h, cols, linhas = ATLAS["papeis"]
    cw, ch = w // cols, h // linhas
    atlas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for i, nome in enumerate(PAPEIS):
        rng = random.Random("papel/" + nome)
        cel = _fechar(_celula_papel(nome, cw - 4, ch - 4, rng))
        atlas.paste(cel, ((i % cols) * cw + 2, (i // cols) * ch + 2))
    return atlas


# ==========================================================================
# CARTAZES
# ==========================================================================

CORES_VIVAS = [(200, 50, 40), (40, 110, 190), (230, 170, 30), (50, 150, 70),
               (150, 60, 160), (230, 110, 30)]


def _letra_bloco(d, x, y, s, ch, cor):
    """Letra/numero em traco grosso, desenhada sem fonte nenhuma — o cartaz
    nao pode depender de fonte instalada na maquina de quem gera."""
    from PIL import ImageFont
    try:
        fonte = ImageFont.truetype(os.path.join(RAIZ, "red-valve", "assets", "fonts",
                                                "Montserrat-ExtraBold.ttf"), int(s))
    except OSError:
        fonte = ImageFont.load_default()
    d.text((x, y), ch, fill=cor, font=fonte)


def _cartaz(nome, w, h, rng):
    fundo = {"alfabeto": (232, 226, 200), "tabuada": (220, 232, 214),
             "corpo": (226, 230, 232), "planetas": (24, 28, 52),
             "tabela": (232, 230, 222), "mapa": (210, 222, 226)}[nome]
    img = _papel(w, h, fundo, rng, amassado=0.5, mancha=1.0)
    d = ImageDraw.Draw(img, "RGBA")
    # faixa do titulo: cor chapada e VAZIA, o Label3D escreve em cima dela
    faixa = CORES_VIVAS[CARTAZES.index(nome) % len(CORES_VIVAS)]
    d.rectangle((10, 10, w - 10, 70), fill=faixa + (235,))
    topo = 84
    if nome == "alfabeto":
        letras = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        cols = 4
        cw = (w - 30) / cols
        chh = (h - topo - 14) / 7
        for i, ch in enumerate(letras):
            cx = 15 + (i % cols) * cw
            cy = topo + (i // cols) * chh
            cor = CORES_VIVAS[i % len(CORES_VIVAS)]
            d.rectangle((cx + 3, cy + 3, cx + cw - 3, cy + chh - 3), outline=cor + (200,), width=2)
            _letra_bloco(d, cx + 10, cy + 2, chh * 0.62, ch + ch.lower(), cor + (255,))
    elif nome == "tabuada":
        for i in range(10):
            for j in range(10):
                x = 18 + j * (w - 36) / 10.0
                y = topo + 6 + i * (h - topo - 30) / 10.0
                cor = (40, 40, 40, 230) if (i == 0 or j == 0) else (70, 90, 70, 200)
                _letra_bloco(d, x + 2, y, 15, str((i + 1) * (j + 1)), cor)
                d.rectangle((x, y - 2, x + (w - 36) / 10.0, y + (h - topo - 30) / 10.0 - 2),
                            outline=(120, 150, 120, 120))
    elif nome == "corpo":
        cx = w / 2
        d.ellipse((cx - 34, topo + 10, cx + 34, topo + 86), fill=(220, 180, 160, 255),
                  outline=(80, 60, 50, 255), width=2)
        d.polygon([(cx - 70, topo + 96), (cx + 70, topo + 96), (cx + 54, topo + 280),
                   (cx - 54, topo + 280)], fill=(220, 180, 160, 255), outline=(80, 60, 50, 255))
        for lado in (-1, 1):
            d.line((cx + lado * 70, topo + 100, cx + lado * 110, topo + 260),
                   fill=(220, 180, 160, 255), width=22)
            d.line((cx + lado * 30, topo + 280, cx + lado * 40, h - 30),
                   fill=(220, 180, 160, 255), width=28)
        d.ellipse((cx - 16, topo + 130, cx + 16, topo + 166), fill=(190, 30, 40, 255))
        for lado in (-1, 1):
            d.ellipse((cx + lado * 40 - 22, topo + 110, cx + lado * 40 + 22, topo + 190),
                      fill=(220, 120, 130, 255))
        d.ellipse((cx - 40, topo + 196, cx + 40, topo + 250), fill=(180, 120, 70, 255))
        for k in range(6):
            y = topo + 120 + k * 30
            d.line((cx + 70, y, w - 30, y), fill=(40, 40, 40, 200), width=1)
            d.rectangle((w - 30, y - 3, w - 14, y + 3), fill=(40, 40, 40, 200))
    elif nome == "planetas":
        d.ellipse((-160, topo + 40, 60, h - 40), fill=(250, 200, 60, 255))
        x = 80
        for k, (r, cor) in enumerate(((6, (160, 150, 140)), (10, (230, 200, 140)),
                                      (11, (60, 120, 200)), (8, (200, 90, 50)),
                                      (26, (210, 170, 120)), (22, (220, 200, 150)),
                                      (15, (140, 200, 220)), (14, (60, 90, 200)))):
            cy = topo + 40 + (h - topo - 80) * (k / 7.0)
            d.ellipse((x + k * 26 - r, cy - r, x + k * 26 + r, cy + r), fill=cor + (255,))
            if k == 5:
                d.ellipse((x + k * 26 - r * 1.8, cy - r * 0.5, x + k * 26 + r * 1.8, cy + r * 0.5),
                          outline=(230, 210, 170, 255), width=2)
        for _ in range(140):
            x0, y0 = rng.uniform(0, w), rng.uniform(topo, h)
            d.point((x0, y0), fill=(255, 255, 255, int(rng.uniform(80, 255))))
    elif nome == "tabela":
        cw = (w - 20) / 9.0
        chh = (h - topo - 20) / 11.0
        for i in range(11):
            for j in range(9):
                if i < 3 and 1 <= j <= 6:
                    continue
                cor = CORES_VIVAS[(i + j * 2) % len(CORES_VIVAS)]
                x, y = 10 + j * cw, topo + 4 + i * chh
                d.rectangle((x + 1, y + 1, x + cw - 1, y + chh - 1), fill=cor + (150,),
                            outline=(40, 40, 40, 200))
                _letra_bloco(d, x + 4, y + 2, chh * 0.5, str(i * 9 + j + 1), (20, 20, 20, 220))
    else:
        # mapa: manchas de terra com rio e uma cruz vermelha marcando um ponto
        for _ in range(5):
            cx, cy = rng.uniform(40, w - 40), rng.uniform(topo + 40, h - 40)
            pts = _circulo_pts(cx, cy, rng.uniform(30, 90), rng, 20, 0.35)
            d.polygon(pts, fill=(120, 160, 100, 255), outline=(60, 90, 60, 255))
        rio = [(0, rng.uniform(topo, h))]
        for k in range(1, 8):
            rio.append((w * k / 7.0, rio[-1][1] + rng.uniform(-40, 40)))
        d.line(rio, fill=(60, 110, 190, 255), width=5)
        for k in range(0, int(w), 12):
            d.line((k, topo + (h - topo) * 0.5, k + 6, topo + (h - topo) * 0.5),
                   fill=(80, 80, 80, 200), width=2)
        x, y = w * 0.62, h * 0.66
        d.line((x - 12, y - 12, x + 12, y + 12), fill=(200, 20, 20, 255), width=5)
        d.line((x + 12, y - 12, x - 12, y + 12), fill=(200, 20, 20, 255), width=5)
    # durex amarelado nos quatro cantos
    for (x, y) in ((14, 4), (w - 44, 4), (14, h - 18), (w - 44, h - 18)):
        d.rectangle((x, y, x + 30, y + 12), fill=(230, 210, 150, 140))
    return img


def gerar_cartazes():
    w, h, cols, linhas = ATLAS["cartazes"]
    cw, ch = w // cols, h // linhas
    atlas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for i, nome in enumerate(CARTAZES):
        rng = random.Random("cartaz/" + nome)
        atlas.paste(_fechar(_cartaz(nome, cw - 4, ch - 4, rng)),
                    ((i % cols) * cw + 2, (i // cols) * ch + 2))
    return atlas


# ==========================================================================
# MARCAS DE PAREDE / TETO
# ==========================================================================

def _mao(d, cx, cy, s, ang, cor, rng):
    """Mao espalmada: palma + cinco dedos, com borrao."""
    def gira(x, y):
        c, sn = math.cos(ang), math.sin(ang)
        return (cx + x * c - y * sn, cy + x * sn + y * c)
    palma = [gira(x * s, y * s) for (x, y) in
             ((-0.45, -0.1), (0.45, -0.1), (0.5, 0.55), (0.0, 0.75), (-0.5, 0.55))]
    d.polygon(palma, fill=cor)
    for (dx, comp, larg) in ((-0.42, 0.55, 0.13), (-0.2, 0.75, 0.14), (0.04, 0.82, 0.14),
                             (0.27, 0.72, 0.13), (0.58, 0.45, 0.14)):
        x0, y0 = gira(dx * s, -0.05 * s)
        incl = 0.25 if dx > 0.5 else 0.0
        x1, y1 = gira((dx + incl) * s, (-0.05 - comp) * s)
        d.line((x0, y0, x1, y1), fill=cor, width=int(larg * s * 2))
        d.ellipse((x1 - larg * s, y1 - larg * s, x1 + larg * s, y1 + larg * s), fill=cor)


def _celula_marca(nome, w, h, rng):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    if nome == "mao":
        for k in range(3):
            _mao(d, rng.uniform(60, w - 60), rng.uniform(80, h - 50), rng.uniform(34, 44),
                 rng.uniform(-0.5, 0.5), (60, 22, 16, int(rng.uniform(150, 220))), rng)
        img = img.filter(ImageFilter.GaussianBlur(1.2))
    elif nome == "arrasto":
        for k in range(4):
            x = 50 + k * 42 + rng.uniform(-6, 6)
            pts = [(x, 30)]
            y = 30
            while y < h - 10:
                y += rng.uniform(6, 14)
                pts.append((pts[-1][0] + rng.uniform(-3, 3), y))
            for j, (a, b) in enumerate(zip(pts, pts[1:])):
                alfa = int(220 * (1 - j / float(len(pts))))
                d.line((a, b), fill=(55, 20, 15, alfa), width=int(14 - j * 0.25) if j < 40 else 4)
        img = img.filter(ImageFilter.GaussianBlur(1.6))
    elif nome == "riscos":
        # a contagem de dias riscada na parede, em giz
        y = 30
        while y < h - 40:
            x = 20
            while x < w - 50:
                if rng.random() < 0.85:
                    for k in range(4):
                        d.line((x + k * 9, y, x + k * 9 + rng.uniform(-3, 3), y + 34),
                               fill=(220, 220, 210, 210), width=3)
                    d.line((x - 4, y + 26, x + 34, y + 6), fill=(220, 220, 210, 210), width=3)
                x += 52
            y += 52
    elif nome == "seta":
        cor = (225, 225, 215, 230)
        # seta de giz apontando PRA BAIXO: e' a pista do buraco
        cx = w / 2
        _giz_de_cera(d, [(cx, 20), (cx + rng.uniform(-4, 4), h - 60)], cor, 9, rng, 0.35)
        _giz_de_cera(d, [(cx - 60, h - 110), (cx, h - 40), (cx + 60, h - 110)], cor, 9, rng, 0.35)
    elif nome == "unhas":
        for k in range(5):
            x = 60 + k * 30
            d.line((x, 30, x + rng.uniform(-30, 30), h - 30), fill=(20, 15, 12, 200), width=3)
            d.line((x + 2, 30, x + rng.uniform(-30, 30), h - 30), fill=(140, 120, 100, 90), width=1)
    elif nome == "teia":
        # teia de canto: raios saindo do canto de cima-esquerda, fios em arco
        raios = 9
        for k in range(raios):
            a = (k / (raios - 1.0)) * math.pi * 0.5
            d.line((0, 0, math.cos(a) * w * 1.1, math.sin(a) * h * 1.1),
                   fill=(220, 220, 220, 120), width=1)
        r = 22
        while r < w * 1.05:
            pts = []
            for k in range(raios):
                a = (k / (raios - 1.0)) * math.pi * 0.5
                rr = r * rng.uniform(0.9, 1.06)
                pts.append((math.cos(a) * rr, math.sin(a) * rr))
            for a, b in zip(pts, pts[1:]):
                meio = ((a[0] + b[0]) * 0.47, (a[1] + b[1]) * 0.47)
                d.line((a, meio, b), fill=(220, 220, 220, 110), width=1)
            r += rng.uniform(14, 26)
        # poeira presa nos fios
        for _ in range(60):
            a = rng.uniform(0, math.pi * 0.5)
            rr = rng.uniform(10, w)
            d.point((math.cos(a) * rr, math.sin(a) * rr), fill=(200, 200, 190, 160))
    elif nome == "infiltracao":
        # escorrido de agua do forro: aneis marrons e o veu descendo
        for k in range(9):
            cx = w / 2 + rng.uniform(-30, 30)
            rx = w * (0.48 - k * 0.045)
            d.ellipse((cx - rx, -rx * 0.6, cx + rx, rx * 0.7),
                      outline=(90, 62, 30, 150), width=4)
            d.ellipse((cx - rx, -rx * 0.6, cx + rx, rx * 0.7), fill=(100, 72, 36, 50))
        for _ in range(9):
            x = rng.uniform(w * 0.2, w * 0.8)
            comp = rng.uniform(h * 0.3, h * 0.95)
            d.line((x, h * 0.2, x + rng.uniform(-6, 6), comp), fill=(80, 56, 28, 130),
                   width=int(rng.uniform(4, 12)))
        img = img.filter(ImageFilter.GaussianBlur(2.2))
    else:
        # o buraco no forro: placa caida, o escuro de cima e a borda esfiapada
        pts = _circulo_pts(w / 2, h / 2, w * 0.36, rng, 22, 0.25)
        d.polygon(pts, fill=(6, 6, 7, 255))
        for (a, b) in zip(pts, pts[1:]):
            d.line((a, b), fill=(120, 116, 104, 230), width=5)
            if rng.random() < 0.5:
                d.line((a, (a[0] + rng.uniform(-14, 14), a[1] + rng.uniform(-14, 14))),
                       fill=(130, 124, 110, 220), width=3)
        img = img.filter(ImageFilter.GaussianBlur(0.8))
    return img


def gerar_marcas():
    w, h, cols, linhas = ATLAS["marcas"]
    cw, ch = w // cols, h // linhas
    atlas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for i, nome in enumerate(MARCAS):
        rng = random.Random("marca/" + nome)
        atlas.paste(_celula_marca(nome, cw - 4, ch - 4, rng), ((i % cols) * cw + 2, (i // cols) * ch + 2))
    return atlas


# ==========================================================================
# CHAO
# ==========================================================================

def _celula_chao(nome, w, h, rng):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    if nome == "poca":
        # mascara de poca: a cor real vem do material (escura e lisa), aqui so'
        # sai a forma — varias bolhas fundidas, borda macia
        for _ in range(7):
            cx, cy = rng.uniform(w * 0.25, w * 0.75), rng.uniform(h * 0.25, h * 0.75)
            rx, ry = rng.uniform(30, 80), rng.uniform(24, 60)
            d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(255, 255, 255, 255))
        img = img.filter(ImageFilter.GaussianBlur(6))
    elif nome == "folhas":
        for _ in range(26):
            cx, cy = rng.uniform(20, w - 20), rng.uniform(20, h - 20)
            s = rng.uniform(8, 18)
            a = rng.uniform(0, math.pi)
            cor = rng.choice(((110, 70, 30), (140, 100, 40), (90, 60, 30), (120, 110, 50)))
            pts = [(cx + math.cos(a) * s * 1.6, cy + math.sin(a) * s * 1.6),
                   (cx + math.cos(a + 1.57) * s * 0.7, cy + math.sin(a + 1.57) * s * 0.7),
                   (cx - math.cos(a) * s * 1.6, cy - math.sin(a) * s * 1.6),
                   (cx - math.cos(a + 1.57) * s * 0.7, cy - math.sin(a + 1.57) * s * 0.7)]
            d.polygon(pts, fill=cor + (240,))
            d.line((pts[0], pts[2]), fill=(60, 40, 20, 200), width=1)
    elif nome == "cacos":
        for _ in range(40):
            cx, cy = rng.uniform(10, w - 10), rng.uniform(10, h - 10)
            s = rng.uniform(3, 16)
            pts = [(cx + rng.uniform(-s, s), cy + rng.uniform(-s, s)) for _ in range(3)]
            d.polygon(pts, fill=(190, 210, 215, 150), outline=(240, 250, 255, 220))
    elif nome == "pegadas":
        for k in range(6):
            x = w * 0.3 + (k % 2) * 46
            y = h - 30 - k * 40
            d.ellipse((x - 12, y - 22, x + 12, y + 6), fill=(40, 30, 22, 120))
            d.ellipse((x - 10, y + 8, x + 10, y + 22), fill=(40, 30, 22, 110))
        img = img.filter(ImageFilter.GaussianBlur(1.5))
    elif nome == "papel_picado":
        for _ in range(120):
            cx, cy = rng.uniform(10, w - 10), rng.uniform(10, h - 10)
            s = rng.uniform(2, 6)
            cor = rng.choice(((220, 218, 200), (200, 210, 230), (230, 220, 160)))
            d.rectangle((cx - s, cy - s * 0.6, cx + s, cy + s * 0.6), fill=cor + (230,))
    elif nome == "mancha":
        for _ in range(5):
            cx, cy = rng.uniform(w * 0.3, w * 0.7), rng.uniform(h * 0.3, h * 0.7)
            r = rng.uniform(20, 60)
            d.ellipse((cx - r, cy - r * 0.7, cx + r, cy + r * 0.7), fill=(35, 14, 10, 150))
        for _ in range(30):
            cx, cy = rng.uniform(0, w), rng.uniform(0, h)
            r = rng.uniform(2, 6)
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(35, 14, 10, 160))
        img = img.filter(ImageFilter.GaussianBlur(2.5))
    elif nome == "barro":
        for _ in range(40):
            cx, cy = rng.uniform(20, w - 20), rng.uniform(20, h - 20)
            r = rng.uniform(4, 26)
            d.ellipse((cx - r, cy - r * 0.7, cx + r, cy + r * 0.7),
                      fill=(70, 50, 32, int(rng.uniform(80, 200))))
        img = img.filter(ImageFilter.GaussianBlur(2.0))
    else:
        # pezinhos descalcos de crianca, em barro, numa fileira so'
        for k in range(7):
            x = w * 0.42 + (k % 2) * 30
            y = h - 24 - k * 34
            d.ellipse((x - 7, y - 14, x + 7, y + 4), fill=(55, 38, 24, 190))
            d.ellipse((x - 6, y + 6, x + 6, y + 15), fill=(55, 38, 24, 180))
            for t in range(5):
                d.ellipse((x - 8 + t * 4, y - 22, x - 5 + t * 4, y - 18), fill=(55, 38, 24, 180))
        img = img.filter(ImageFilter.GaussianBlur(0.9))
    return img


def gerar_chao():
    w, h, cols, linhas = ATLAS["chao"]
    cw, ch = w // cols, h // linhas
    atlas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for i, nome in enumerate(CHAO):
        rng = random.Random("chao/" + nome)
        atlas.paste(_celula_chao(nome, cw - 4, ch - 4, rng), ((i % cols) * cw + 2, (i // cols) * ch + 2))
    return atlas


# ==========================================================================
# BANDEIRINHAS
# ==========================================================================

def gerar_bandeiras():
    """As bandeirinhas de festa junina: papel de seda colorido com o corte em V
    embaixo, ja' desbotado de sol e de chuva."""
    w, h, cols, linhas = ATLAS["bandeiras"]
    cw = w // cols
    atlas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cores = {"vermelha": (170, 40, 36), "amarela": (196, 160, 50),
             "azul": (44, 84, 150), "verde": (50, 120, 60)}
    for i, nome in enumerate(BANDEIRAS):
        rng = random.Random("bandeira/" + nome)
        cel = _papel(cw - 8, h - 8, cores[nome], rng, amassado=0.8, mancha=0.6)
        alfa = Image.new("L", cel.size, 255)
        da = ImageDraw.Draw(alfa)
        cx = cel.size[0] / 2.0
        da.polygon([(0, cel.size[1]), (cx, cel.size[1] * 0.70), (cel.size[0], cel.size[1])], fill=0)
        # o dente do barbante, no alto
        da.rectangle((0, 0, cel.size[0], 4), fill=0)
        cel.alfa = alfa
        atlas.paste(_fechar(cel), (i * cw + 4, 4))
    return atlas


def gerar():
    os.makedirs(DIR, exist_ok=True)
    for nome, fn in (("papeis", gerar_papeis), ("cartazes", gerar_cartazes),
                     ("marcas", gerar_marcas), ("chao", gerar_chao),
                     ("bandeiras", gerar_bandeiras)):
        img = fn()
        destino = os.path.join(DIR, nome + ".png")
        img.save(destino, optimize=True)
        print("  %s (%d x %d)" % (destino, img.size[0], img.size[1]))


if __name__ == "__main__":
    gerar()
