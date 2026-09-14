"""Planta baixa do interior da igreja, para o minimapa e para a aba MAPA.

    python3 tools/godot/igreja/make_mapa_igreja.py     (precisa de Pillow)

Saidas:
    red-valve/assets/3d_model/stages/igreja/textures/T_igrejamap.png
    red-valve/assets/3d_model/stages/igreja/igrejamap.json

==============================================================================
POR QUE NAO E' UM RENDER DE CIMA

Pelo mesmo motivo do mapa da cidade (`tools/blender/citygen/textures/
make_minimap.py`): desenhado a partir dos DADOS ele fica legivel a 190 px, nao
depende da iluminacao da cena — e a igreja e' escura DE PROPOSITO, um render
de cima dela seria um retangulo preto — e regerar custa dois segundos.

E aqui tem um motivo a mais: a igreja e' um interior com TETO. Uma camera
ortografica de cima so' veria a abobada.

==============================================================================
DE ONDE VEM CADA NUMERO

  - a planta (paredes, pilares, escadas, abside) sai de `igreja_pontos.json`,
    bloco "planta", que o gerador do Blender escreve junto com o modelo;
  - a posicao da lanterna e a do item secreto saem de `gerar_cena_igreja.py`,
    que e' quem as escreve na cena.

Nada e' digitado duas vezes: mover o pilar no Blender move o pilar aqui.

==============================================================================
O QUE E' O 2o ANDAR NUM MAPA DE UM ANDAR SO'

A igreja tem duas galerias em cima das naves laterais, e o item secreto esta'
numa delas. Planta baixa de verdade resolveria isso com duas pranchas, o que
num minimapa de 190 px seria pior que inutil. Aqui o piso de cima aparece
como HACHURA diagonal por cima do piso de baixo: quem olha entende que ali
tem dois niveis, e o rotulo do ponto diz em qual deles ele esta'.
"""

import json
import math
import os
import sys

from PIL import Image, ImageDraw

_AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _AQUI)

from gerar_cena_igreja import ITEM_SECRETO_POS, LANTERNA_POS  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(_AQUI)))
ASSETS = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "stages", "igreja")
PONTOS = os.path.join(ASSETS, "igreja_pontos.json")
OUT_PNG = os.path.join(ASSETS, "textures", "T_igrejamap.png")
OUT_JSON = os.path.join(ASSETS, "igrejamap.json")

# 2048 e nao 1024: o painel do menu deixa aproximar ate' 12 m de altura, e a
# 1024 px isso daria 3,4x de ampliacao — borrao. A 2048 sao 36 px/m e a
# ampliacao maxima fica em 1,7x.
RES = 2048
SS = 2                # supersampling
MARGEM = 2.5          # metros de folga em volta do predio

# Paleta: mesma familia sepia do mapa da cidade, um degrau mais escura. O
# contraste que carrega a leitura e' piso claro x pedra escura — ao contrario
# da cidade, onde e' via clara x quadra escura.
C_FORA      = (13, 14, 15)
C_PEDRA     = (43, 40, 35)     # massa das paredes
C_PEDRA_BRD = (18, 17, 15)
C_PISO      = (122, 114, 99)   # nave central
C_LATERAL   = (99, 92, 80)     # naves laterais
C_CORO      = (137, 126, 107)  # coro e abside, elevados 0,9 m
C_PILAR     = (40, 37, 32)
C_ESCADA    = (150, 136, 110)
C_DEGRAU    = (60, 55, 46)
C_MADEIRA   = (132, 96, 58)    # passarela e remendo do jube
C_ENTULHO   = (74, 67, 57)
C_ROMBO     = (176, 158, 116)  # a coluna de luz que desce pelo buraco
C_HACHURA   = (188, 176, 150)  # galerias (2o andar)
C_PORTAL    = (150, 112, 62)


def _planta():
    d = json.load(open(PONTOS, encoding="utf-8"))
    p = d["planta"]
    if "pilar_z" not in p:
        raise SystemExit(
            "igreja_pontos.json antigo: rode tools/blender/igreja/"
            "gerar_igreja.py de novo para gravar o bloco planta completo.")
    return d, p


def _recorte(p):
    """Quadrado do mundo que a imagem cobre.

    Quadrado, e nao o retangulo justo do predio, porque o minimapa GIRA: com
    escalas diferentes nos dois eixos a igreja apareceria esticada em algumas
    direcoes e achatada em outras.
    """
    x1 = p["parede_ext"]
    z0 = p["z_portal_ext"]
    z1 = p["z_coro"] + p["abside_r"] + (p["parede_ext"] - p["parede_x"])
    cx, cz = 0.0, (z0 + z1) / 2.0
    meio = max(x1, (z1 - z0) / 2.0) + MARGEM
    return cx - meio, cz - meio, meio * 2.0


def build():
    dados, p = _planta()
    X0, Z0, TAM = _recorte(p)
    N = RES * SS
    ppm = N / TAM

    def P(x, z):
        return ((x - X0) * ppm, (z - Z0) * ppm)

    def cx(x0, z0, x1, z1):
        """Caixa alinhada aos eixos, em metros -> par de pixels."""
        return [P(min(x0, x1), min(z0, z1)), P(max(x0, x1), max(z0, z1))]

    img = Image.new("RGB", (N, N), C_FORA)
    dr = ImageDraw.Draw(img)

    par_i, par_e = p["parede_x"], p["parede_ext"]
    nave_x, lat_x = p["nave_x"], p["lat_x"]
    z_por, z_cruz, z_coro = p["z_portal"], p["z_cruz"], p["z_coro"]
    abs_r = p["abside_r"]
    esp = par_e - par_i          # espessura da parede lateral

    # ---- massa de pedra: o predio inteiro, cheio
    dr.rectangle(cx(-par_e, p["z_portal_ext"], par_e, z_coro), fill=C_PEDRA)
    dr.pieslice(cx(-(abs_r + esp), z_coro - (abs_r + esp),
                   abs_r + esp, z_coro + (abs_r + esp)),
                start=0, end=180, fill=C_PEDRA)

    # ---- o vazio por dentro, escavado na pedra
    dr.rectangle(cx(-par_i, z_por, par_i, z_coro), fill=C_PISO)
    dr.pieslice(cx(-abs_r, z_coro - abs_r, abs_r, z_coro + abs_r),
                start=0, end=180, fill=C_CORO)

    # naves laterais: um tom abaixo da central, que e' o que da' a leitura de
    # "tres naves" sem precisar desenhar linha nenhuma
    dr.rectangle(cx(-par_i, z_por, -lat_x, z_cruz), fill=C_LATERAL)
    dr.rectangle(cx(lat_x, z_por, par_i, z_cruz), fill=C_LATERAL)
    # coro elevado 0,9 m: mesma cor da abside
    dr.rectangle(cx(-par_i, z_cruz, par_i, z_coro), fill=C_CORO)

    # ---- o portal oeste, unica saida
    dr.rectangle(cx(-2.2, p["z_portal_ext"], 2.2, z_por + 0.3), fill=C_PORTAL)

    # ---- arcadas: pilar por pilar, dos dois lados
    quebrado = _pilar_quebrado(p)
    for lado in (-1, 1):
        for z in p["pilar_z"]:
            meio_x = lado * p["eixo_x"]
            caixa = cx(meio_x - 0.75, z - 0.75, meio_x + 0.75, z + 0.75)
            if (lado, z) == quebrado:
                # o fuste partiu na altura do peito: em planta ele ainda ocupa
                # o lugar, mas vazado, para nao parecer pilar inteiro
                dr.rectangle(caixa, fill=C_ENTULHO, outline=C_PEDRA_BRD,
                             width=max(1, int(0.18 * ppm)))
            else:
                dr.rectangle(caixa, fill=C_PILAR)

    # ---- arco triunfal: os dois esporoes que estreitam a passagem pro coro
    for lado in (-1, 1):
        dr.rectangle(cx(lado * par_i, z_cruz - 0.6,
                        lado * nave_x, z_cruz + 0.6), fill=C_PILAR)

    # ---- a ruina: rombo da abobada e a pilha embaixo dele
    b0, b1 = p["baias"][p["baia_rompida"]]
    _clarao(img, P, ppm, (0.0, (b0 + b1) / 2.0), nave_x - 0.4, (b1 - b0) / 2.0)
    for e in dados.get("escombros", []):
        _entulho(dr, P, ppm, e[0], e[2])

    # ---- circulacao vertical
    _escada_reta(dr, cx, ppm, p)
    _caracol(dr, P, cx, ppm, p)

    # ---- 2o andar: galerias, passarela e jube
    _galerias(img, P, ppm, p)
    _passarela(dr, cx, ppm, p)

    # ---- contorno por ultimo, por cima de tudo
    dr.rectangle(cx(-par_e, p["z_portal_ext"], par_e, z_coro),
                 outline=C_PEDRA_BRD, width=max(1, int(0.35 * ppm)))

    img = img.resize((RES, RES), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT_PNG), exist_ok=True)
    img.save(OUT_PNG)

    meta = {
        "nota": "recorte do interior da igreja coberto por T_igrejamap.png; "
                "gerado por tools/godot/igreja/make_mapa_igreja.py",
        "mundo_x0": round(X0, 2), "mundo_z0": round(Z0, 2),
        "tamanho_m": round(TAM, 2), "resolucao": RES,
        "pontos": _pontos(p),
    }
    json.dump(meta, open(OUT_JSON, "w", encoding="utf-8"), indent=1)
    return meta


# --------------------------------------------------------------------------
# pecas


def _pilar_quebrado(p):
    """(lado, z) do pilar que partiu: arcada SUL (X>0), em Z=19."""
    return (1, 19.0) if 19.0 in p["pilar_z"] else (0, None)


def _clarao(img, P, ppm, centro, raio_x, raio_z):
    """Mancha de luz do rombo da abobada.

    Desenhada numa camada a parte e misturada com alfa: por cima do piso, um
    retangulo chapado viraria um adesivo. O que se quer e' a leitura de
    "aqui entra luz", que e' o unico ponto claro da igreja inteira.
    """
    cxm, czm = centro
    camada = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)
    for k in range(6, 0, -1):
        f = k / 6.0
        d.ellipse([P(cxm - raio_x * f, czm - raio_z * f),
                   P(cxm + raio_x * f, czm + raio_z * f)],
                  fill=C_ROMBO + (26,))
    img.paste(Image.alpha_composite(img.convert("RGBA"), camada).convert("RGB"),
              (0, 0))


def _entulho(dr, P, ppm, x, z):
    """Pilha de pedra caida: poligono irregular, mas SEMPRE o mesmo — o
    formato vem do angulo, nao de sorteio, para o mapa nao mudar a cada
    regeracao."""
    pts = []
    for k in range(11):
        a = 2 * math.pi * k / 11.0
        r = 2.6 + 1.1 * math.sin(3.0 * a + 0.7)
        pts.append(P(x + r * math.cos(a), z + r * 0.78 * math.sin(a)))
    dr.polygon(pts, fill=C_ENTULHO, outline=C_PEDRA_BRD,
               width=max(1, int(0.16 * ppm)))


def _escada_reta(dr, cx, ppm, p):
    """Escada de pedra da nave lateral norte: dois lances e um patamar."""
    x0, x1, z0, z1, zpat, z2 = p["escada"]
    dr.rectangle(cx(x0, z0, x1, z2), fill=C_ESCADA)
    largura = max(1, int(0.1 * ppm))
    for a, b in ((z0, z1), (zpat, z2)):
        z = a + 0.32
        while z < b:
            dr.line([cx(x0, z, x1, z)[0], cx(x0, z, x1, z)[1]],
                    fill=C_DEGRAU, width=largura)
            z += 0.32
    # o patamar fica liso: e' o que diz de relance onde o lance vira
    dr.rectangle(cx(x0, z1, x1, zpat), fill=C_ESCADA,
                 outline=C_DEGRAU, width=max(1, int(0.12 * ppm)))


def _caracol(dr, P, cx, ppm, p):
    """Escada em caracol da nave lateral sul, com o poco que ela abre na
    laje da galeria."""
    cxm, _, czm = p["caracol"]
    r = p["caracol_r"]
    px0, pz0, pz1, boca = p["poco"]
    # o poco na laje, primeiro: e' o buraco por onde a escada sobe
    dr.rectangle(cx(px0, pz0, p["parede_x"], pz1), fill=C_LATERAL,
                 outline=C_PEDRA_BRD, width=max(1, int(0.18 * ppm)))
    dr.ellipse(cx(cxm - r, czm - r, cxm + r, czm + r), fill=C_ESCADA)
    # os degraus, como raios: e' o que faz ler "caracol" e nao "coluna"
    for k in range(14):
        a = 2 * math.pi * k / 14.0
        dr.line([P(cxm + 0.35 * math.cos(a), czm + 0.35 * math.sin(a)),
                 P(cxm + r * math.cos(a), czm + r * math.sin(a))],
                fill=C_DEGRAU, width=max(1, int(0.1 * ppm)))
    dr.ellipse(cx(cxm - 0.38, czm - 0.38, cxm + 0.38, czm + 0.38), fill=C_PILAR)
    # a boca de saida, virada pra dentro da nave (-X)
    dr.rectangle(cx(px0 - 0.5, czm - boca, px0 + 0.2, czm + boca), fill=C_ESCADA)


def _galerias(img, P, ppm, p):
    """Hachura diagonal sobre tudo que tem piso em cima: as duas galerias."""
    camada = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)
    faixas = [(p["lat_x"], p["z_portal"], p["parede_x"], p["z_cruz"]),
              (-p["parede_x"], p["z_portal"], -p["lat_x"], p["z_cruz"])]
    passo = 1.15
    largura = max(1, int(0.13 * ppm))
    for x0, z0, x1, z1 in faixas:
        t = 0.0
        while t < (x1 - x0) + (z1 - z0):
            # reta a 45 graus recortada na caixa da faixa
            ax, az = x0 + min(t, x1 - x0), z0 + max(0.0, t - (x1 - x0))
            bx, bz = x0 + max(0.0, t - (z1 - z0)), z0 + min(t, z1 - z0)
            d.line([P(ax, az), P(bx, bz)], fill=C_HACHURA + (44,),
                   width=largura)
            t += passo
    img.paste(Image.alpha_composite(img.convert("RGBA"), camada).convert("RGB"),
              (0, 0))


def _passarela(dr, cx, ppm, p):
    """Passarela de tabuas no meio da nave e o jube sobre o arco triunfal:
    as duas travessias do 2o andar."""
    _, _, pz = p["passarela"]
    dr.rectangle(cx(-p["nave_x"], pz - 0.85, p["nave_x"], pz + 0.85),
                 fill=C_MADEIRA, outline=C_PEDRA_BRD,
                 width=max(1, int(0.12 * ppm)))
    x = -p["nave_x"] + 0.6
    while x < p["nave_x"]:
        dr.line([cx(x, pz - 0.85, x, pz + 0.85)[0],
                 cx(x, pz - 0.85, x, pz + 0.85)[1]],
                fill=C_PEDRA_BRD, width=max(1, int(0.07 * ppm)))
        x += 0.6

    jz0, jz1 = p["jube_z"]
    dr.rectangle(cx(-p["nave_x"], jz0, p["nave_x"], jz1), fill=C_PILAR)
    # o meio do jube desabou e foi remendado com tabua
    dr.rectangle(cx(-2.4, jz0 + 0.25, 2.4, jz1 - 0.25), fill=C_MADEIRA)


# --------------------------------------------------------------------------
# pontos


def _pontos(p):
    """As duas interrogacoes do mapa.

    `chave` vazia de proposito: uma interrogacao com o nome do item escrito ao
    lado nao seria uma interrogacao. O que o rotulo diz, quando diz, e' o ANDAR
    — e isso nao entrega nada, so' evita que o jogador procure no chao um
    item que esta' dez metros acima da cabeca dele.

    `oculto_com_item` e' lido pelo Godot contra o inventario salvo: a
    interrogacao da lanterna some no instante em que a lanterna e' pega, e um
    save antigo que ja' a tenha tambem chega com o mapa limpo.
    """
    return [
        {"id": "lanterna", "chave": "", "tipo": "interrogacao",
         "x": round(LANTERNA_POS[0], 2), "z": round(LANTERNA_POS[2], 2),
         "oculto_com_item": "lanterna"},
        {"id": "item_secreto", "chave": "", "tipo": "interrogacao",
         "x": round(ITEM_SECRETO_POS[0], 2), "z": round(ITEM_SECRETO_POS[2], 2),
         "andar": "MAP_FLOOR_GALLERY"},
    ]


if __name__ == "__main__":
    m = build()
    print("T_igrejamap.png:", OUT_PNG)
    print("  recorte X0=%.1f Z0=%.1f tamanho=%.1f m  (%.2f px/m)" % (
        m["mundo_x0"], m["mundo_z0"], m["tamanho_m"],
        m["resolucao"] / m["tamanho_m"]))
    for pt in m["pontos"]:
        print("  ? %-12s (%.2f, %.2f)" % (pt["id"], pt["x"], pt["z"]))
