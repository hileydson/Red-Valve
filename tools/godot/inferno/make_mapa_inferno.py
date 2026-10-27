# -*- coding: utf-8 -*-
"""Mapa visto de cima dos infernos, para o minimapa e a aba MAPA.

    python3 tools/godot/inferno/make_mapa_inferno.py     (precisa de Pillow)

Saidas (uma prancha por inferno):
    red-valve/assets/3d_model/stages/inferno/textures/T_infernomap.png
    red-valve/assets/3d_model/stages/inferno/infernomap.json
    red-valve/assets/3d_model/stages/inferno_2/textures/T_inferno2map.png
    red-valve/assets/3d_model/stages/inferno_2/inferno2map.json
    red-valve/assets/3d_model/stages/inferno_3/textures/T_inferno3map.png
    red-valve/assets/3d_model/stages/inferno_3/inferno3map.json
    red-valve/assets/3d_model/stages/inferno_4/textures/T_inferno4map.png
    red-valve/assets/3d_model/stages/inferno_4/inferno4map.json

Rode DEPOIS do Blender sempre que o caminho de um inferno mudar.

==============================================================================
POR QUE NAO E' UM RENDER DE CIMA

Pelo mesmo motivo do mapa da cidade (`tools/blender/citygen/textures/
make_minimap.py`) e do da igreja: desenhado a partir dos DADOS ele fica
legivel a 190 px. Um render de cima do inferno seria um borrao vermelho — o
ceu, a nevoa e a lava pintam tudo da mesma cor — e o caminho, que e' o que o
jogador precisa ler, sumiria no meio.

==============================================================================
DE ONDE VEM CADA NUMERO

Do proprio gerador do Blender, importado aqui (sem o `bpy`: so' a geometria
do caminho e a funcao `altura`, que nao dependem dele). A linha de centro, a
largura, as pontes, o rio, o nivel da lava e os pontos das areas (o
`*_pontos.json` que o mesmo gerador escreveu) sao os MESMOS do modelo — mexer
no caminho no Blender mexe no mapa.

  - o chao: `altura` amostrada numa grade, com sombra de relevo (o funil do
    inferno 2 so' se le' pelos degraus dos terracos);
  - a lava: onde o chao fica embaixo do nivel dela; o rio do inferno 1 e a
    cascata do inferno 2 saem num tom mais aceso;
  - o caminho e as pontes: em vetor por cima, na resolucao cheia, pra borda
    sair nitida;
  - os pontos: uma marca por area (o nome e' chave de traducao).

Sem nevoa: igual a' cidade, a prancha nasce toda acesa.
"""
import importlib
import json
import math
import os
import sys
import types

# o .pyc da base nao pode nascer antes de ela desligar o bytecode
sys.dont_write_bytecode = True

from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(AQUI, os.pardir, os.pardir, os.pardir))
BLENDER = os.path.join(REPO, "tools", "blender")
STAGES = os.path.join(REPO, "red-valve", "assets", "3d_model", "stages")

RES = 2048
SS = 2              # supersampling do vetor: desenha em 2x e reduz

# Paleta: a mesma ideia da cidade (o contraste entre caminho e fundo carrega
# a leitura em tamanho pequeno), na familia de cor do inferno.
PALETA_FOGO = {
    "rocha": (74, 50, 42), "lava": (150, 38, 12), "lava_viva": (226, 104, 30),
    "caminho": (168, 146, 120), "caminho_brd": (26, 16, 12),
    "ponte": (112, 80, 56), "ponte_brd": (20, 12, 9),
}
# O inferno 3 e' cidade de noite: pedra fria, o abismo de nevoa no lugar da
# lava, e as QUADRAS (casas, catedral, mausoleus) desenhadas por cima — numa
# rua estreita entre fachadas, o que diz "rua" no papel sao as casas.
PALETA_CIDADE = {
    "rocha": (58, 58, 64), "lava": (20, 23, 30), "lava_viva": (20, 23, 30),
    "caminho": (150, 142, 128), "caminho_brd": (14, 14, 18),
    "ponte": (104, 98, 92), "ponte_brd": (12, 12, 15),
    "bloco": (34, 33, 38), "bloco_brd": (8, 8, 10),
}
PAL = PALETA_FOGO

CONFIG = {
    "inferno": {
        "gerador": "gerar_inferno",
        "pasta": "inferno",
        "png": "T_infernomap.png",
        "json": "infernomap.json",
        "passo": 3.0,
        "margem": 70.0,
        "paleta": PALETA_FOGO,
        "pontos": [
            ("area_1_portao", "MAP_POI_INF_PORTAO", "local"),
            ("area_2_planicie", "MAP_POI_INF_PLANICIE", "marco"),
            ("area_3_ponte", "MAP_POI_INF_PONTE", "marco"),
            ("area_4_colossos", "MAP_POI_INF_COLOSSOS", "marco"),
            ("area_5_espinhos", "MAP_POI_INF_ESPINHOS", "marco"),
            ("area_6_catedral", "MAP_POI_INF_CATEDRAL", "marco"),
            ("area_7_crista", "MAP_POI_INF_CRISTA", "marco"),
            ("area_8_portal", "MAP_POI_INF_PORTAL", "local"),
        ],
    },
    "inferno_2": {
        "gerador": "gerar_inferno_2",
        "pasta": "inferno_2",
        "png": "T_inferno2map.png",
        "json": "inferno2map.json",
        "passo": 2.0,
        "margem": 50.0,
        "paleta": PALETA_FOGO,
        "pontos": [
            ("area_1_chegada", "MAP_POI_INF2_CHEGADA", "local"),
            ("area_2_fenda", "MAP_POI_INF2_FENDA", "marco"),
            ("area_3_mirante", "MAP_POI_INF2_MIRANTE", "marco"),
            ("area_4_cascata", "MAP_POI_INF2_CASCATA", "marco"),
            ("area_5_forja", "MAP_POI_INF2_FORJA", "marco"),
            ("area_6_enforcados", "MAP_POI_INF2_ENFORCADOS", "marco"),
            ("area_7_garganta", "MAP_POI_INF2_GARGANTA", "marco"),
            ("area_8_ponte", "MAP_POI_INF2_PONTE", "marco"),
            ("area_9_agulha", "MAP_POI_INF2_AGULHA", "local"),
        ],
    },
    "inferno_3": {
        "gerador": "gerar_inferno_3",
        "pasta": "inferno_3",
        "png": "T_inferno3map.png",
        "json": "inferno3map.json",
        "passo": 3.0,
        "margem": 60.0,
        "paleta": PALETA_CIDADE,
        "pontos": [
            ("area_1_chegada", "MAP_POI_INF3_CHEGADA", "local"),
            ("area_2_rua", "MAP_POI_INF3_RUA", "marco"),
            ("area_3_praca", "MAP_POI_INF3_PRACA", "marco"),
            ("area_4_ponte", "MAP_POI_INF3_PONTE", "marco"),
            ("area_5_cemiterio", "MAP_POI_INF3_CEMITERIO", "marco"),
            ("area_6_beco", "MAP_POI_INF3_BECO", "marco"),
            ("area_7_escadaria", "MAP_POI_INF3_ESCADARIA", "marco"),
            ("area_8_catedral", "MAP_POI_INF3_CATEDRAL", "local"),
        ],
    },
    "inferno_4": {
        "gerador": "gerar_inferno_4",
        "pasta": "inferno_4",
        "png": "T_inferno4map.png",
        "json": "inferno4map.json",
        "passo": 3.0,
        "margem": 60.0,
        "paleta": PALETA_CIDADE,
        "pontos": [
            ("area_1_chegada", "MAP_POI_INF4_CHEGADA", "local"),
            ("area_2_ladeira", "MAP_POI_INF4_LADEIRA", "marco"),
            ("area_3_subida", "MAP_POI_INF4_SUBIDA", "marco"),
            ("area_4_cemiterio", "MAP_POI_INF4_CEMITERIO", "marco"),
            ("area_5_mirante", "MAP_POI_INF4_MIRANTE", "marco"),
            ("area_6_descida", "MAP_POI_INF4_DESCIDA", "marco"),
            ("area_7_fosso", "MAP_POI_INF4_FOSSO", "local"),
        ],
    },
}


def _carregar_gerador(nome, pasta):
    """Importa o gerador do Blender sem o Blender: os modulos que so' o
    export usa viram casca vazia, e o `exportar` nao roda."""
    for falso in ("bpy", "bmesh", "mathutils"):
        sys.modules.setdefault(falso, types.ModuleType(falso))
    sys.path.insert(0, os.path.join(BLENDER, "cenarios"))
    sys.path.insert(0, os.path.join(BLENDER, pasta))
    import base
    base.Cena.exportar = lambda self, *a, **k: None
    g = importlib.import_module(nome)
    g.main()
    return g


def _trecho(g):
    """Os pontos da linha que sao caminho de verdade (entre os dois muros)."""
    L = g.LINHA
    if hasattr(g, "S_FIM"):
        return [i for i in range(len(L.p)) if g.S_INICIO - 2.0 <= L.s[i] <= g.S_FIM + 2.0]
    return [i for i in range(len(L.p)) if g.Z_FIM - 2.0 <= L.p[i][1] <= g.Z_INICIO + 2.0]


def _recorte(g, idx, margem):
    """Quadrado do mundo que a imagem cobre (quadrado: mesma escala nos dois
    eixos, senao o minimapa gira deformado)."""
    L = g.LINHA
    xs = [L.p[i][0] + s * L.p[i][2] for i in idx for s in (-1, 1)]
    zs = [L.p[i][1] + s * L.p[i][2] for i in idx for s in (-1, 1)]
    x0, x1 = min(xs) - margem, max(xs) + margem
    z0, z1 = min(zs) - margem, max(zs) + margem
    tam = max(x1 - x0, z1 - z0)
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    return cx - tam / 2.0, cz - tam / 2.0, tam


def _lava(g, x, z):
    if hasattr(g, "lava_em"):
        return g.lava_em(x, z)
    if hasattr(g, "FUNDO"):
        # a cidade: o "mar" e' o abismo de nevoa, abaixo de onde a nevoa baixa engole
        return g.FUNDO + 30.0
    return g.LAVA


def _sem_chao(g, x, z, h):
    """O jogo nao desenha chao aqui: o que se ve' e' a lava. Mesma regra do
    `chao` do gerador (longe da linha, o inferno 1 e' mar ate' o horizonte)."""
    if hasattr(g, "_sem_chao"):
        return g._sem_chao(x, z)
    return h < _lava(g, x, z) - 3.0


def _fundo(g, x0, z0, tam, passo):
    """Chao e lava numa grade de `passo` m, com sombra de relevo. Devolve a
    imagem pequena (um pixel por celula)."""
    n = int(math.ceil(tam / passo))
    alt = [[0.0] * n for _ in range(n)]
    for j in range(n):
        z = z0 + (j + 0.5) * passo
        for i in range(n):
            alt[j][i] = g.altura(x0 + (i + 0.5) * passo, z)
    # a sombra sai de uma copia SUAVIZADA: o ruido fino da encosta, amostrado
    # a cada 2-3 m, virava listras diagonais no papel
    suave = [[sum(alt[min(max(j + b, 0), n - 1)][min(max(i + a, 0), n - 1)]
                  for a in (-2, -1, 0, 1, 2) for b in (-2, -1, 0, 1, 2)) / 25.0 for i in range(n)] for j in range(n)]
    hs = [h for linha in alt for h in linha]
    h_min, h_max = min(hs), max(hs)
    img = Image.new("RGB", (n, n))
    px = img.load()
    # luz de noroeste e de cima, como num mapa de relevo de papel
    lx, ly, lz = -0.55, 0.62, -0.55
    for j in range(n):
        z = z0 + (j + 0.5) * passo
        for i in range(n):
            x = x0 + (i + 0.5) * passo
            h = alt[j][i]
            lava = _lava(g, x, z)
            viva = g.dist_rio(x, z) < g.RIO_W + 0.5 if getattr(g, "RIO", None) else False
            if h < lava + 0.3 or _sem_chao(g, x, z, h):
                k = 0.85 + 0.15 * g.ruido2(x * 0.06, z * 0.06, 3.0)
                cor = PAL["lava_viva"] if viva else PAL["lava"]
                px[i, j] = tuple(int(c * k) for c in cor)
                continue
            if viva and hasattr(g, "lava_em"):
                # a cascata do inferno 2 escorre POR CIMA da parede
                px[i, j] = PAL["lava_viva"]
                continue
            dx = suave[j][min(i + 1, n - 1)] - suave[j][max(i - 1, 0)]
            dz = suave[min(j + 1, n - 1)][i] - suave[max(j - 1, 0)][i]
            nx, ny, nz = -dx / (2 * passo), 1.0, -dz / (2 * passo)
            d = math.sqrt(nx * nx + ny * ny + nz * nz)
            luz = max(0.0, (nx * lx + ny * ly + nz * lz) / d)
            # o que e' mais alto um tom mais claro: o funil se le' em degraus
            t = (h - h_min) / max(1.0, h_max - h_min)
            k = (0.35 + 0.85 * luz) * (0.8 + 0.35 * t)
            px[i, j] = tuple(min(255, int(c * k)) for c in PAL["rocha"])
    return img


def _desenhar_caminho(g, idx, para_px, escala):
    """O caminho e as pontes em vetor, numa camada RGBA do tamanho final x SS."""
    L = g.LINHA
    camada = Image.new("RGBA", (RES * SS, RES * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)

    def faixa(pontos, larg_m, cor):
        # poligono por segmento + disco nas juntas: curva fechada sem dente
        r = larg_m * escala
        for (ax, az), (bx, bz) in zip(pontos, pontos[1:]):
            pa, pb = para_px(ax, az), para_px(bx, bz)
            vx, vz = pb[0] - pa[0], pb[1] - pa[1]
            dd = math.hypot(vx, vz) or 1.0
            ox, oz = -vz / dd * r, vx / dd * r
            d.polygon([(pa[0] + ox, pa[1] + oz), (pb[0] + ox, pb[1] + oz),
                       (pb[0] - ox, pb[1] - oz), (pa[0] - ox, pa[1] - oz)], fill=cor)
        for x, z in pontos:
            p = para_px(x, z)
            d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=cor)

    def pelo_caminho(folga, cor):
        # a largura muda ao longo da linha: um segmento por par de pontos
        for a, b in zip(idx, idx[1:]):
            w = max(L.p[a][2], L.p[b][2]) + folga
            faixa([(L.p[a][0], L.p[a][1]), (L.p[b][0], L.p[b][1])], w, cor)

    pelo_caminho(1.6, PAL["caminho_brd"])
    pelo_caminho(0.0, PAL["caminho"])

    for ponte in _pontes(g):
        faixa(ponte["pts"], ponte["w"] + 1.4, PAL["ponte_brd"])
        faixa(ponte["pts"], ponte["w"], PAL["ponte"])
        # as tabuas: riscos atravessados, que e' o que diz "ponte" a 190 px
        pts = ponte["pts"]
        for (ax, az), (bx, bz) in zip(pts, pts[1:]):
            vx, vz = bx - ax, bz - az
            dd = math.hypot(vx, vz) or 1.0
            ox, oz = -vz / dd * ponte["w"], vx / dd * ponte["w"]
            k = 0.0
            while k < dd:
                t = k / dd
                cx, cz = ax + vx * t, az + vz * t
                d.line([para_px(cx + ox, cz + oz), para_px(cx - ox, cz - oz)], fill=PAL["ponte_brd"],
                       width=max(1, int(0.35 * escala)))
                k += 2.5
    return camada


def _pontes(g):
    """As pontes como polilinhas (x, z) com meia-largura."""
    L = g.LINHA
    saida = []
    if hasattr(g, "PONTES"):
        for p in g.PONTES:
            a = L.em_s(p["s"] - p["comp"])
            b = L.em_s(p["s"] + p["comp"])
            if p.get("reta"):
                pts = [(L.p[a][0], L.p[a][1]), (L.p[b][0], L.p[b][1])]
            else:
                pts = [(L.p[i][0], L.p[i][1]) for i in range(a, b + 1)]
            saida.append({"pts": pts, "w": p["w"]})
    elif not hasattr(g, "PONTE_COMP"):
        # o inferno 3 guarda a ponte como (s0, s1) ao longo da linha; o 4 nao
        # tem ponte (a dele fica fora da linha)
        if g.PONTE[1] < 0.0:
            return saida
        a, b = L.em_s(g.PONTE[0] - 7.0), L.em_s(g.PONTE[1] + 7.0)
        saida.append({"pts": [(L.p[i][0], L.p[i][1]) for i in range(a, b + 1)], "w": 7.5})
    else:
        a = L.em_z(g.PONTE[1] + g.PONTE_COMP)
        b = L.em_z(g.PONTE[1] - g.PONTE_COMP)
        a, b = min(a, b), max(a, b)
        saida.append({"pts": [(L.p[i][0], L.p[i][1]) for i in range(a, b + 1)], "w": g.PONTE_W})
    return saida


def _desenhar_blocos(blocos, para_px, escala):
    """As quadras (casas, catedral, mausoleus) que o gerador anotou."""
    camada = Image.new("RGBA", (RES * SS, RES * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)
    for b in blocos:
        pts = [para_px(x, z) for x, z in b]
        d.polygon(pts, fill=PAL["bloco"], outline=PAL["bloco_brd"], width=max(1, int(0.5 * escala)))
    return camada


def gerar(chave):
    global PAL
    cfg = CONFIG[chave]
    PAL = cfg["paleta"]
    g = _carregar_gerador(cfg["gerador"], cfg["pasta"])
    idx = _trecho(g)
    x0, z0, tam = _recorte(g, idx, cfg["margem"])
    escala = RES * SS / tam          # pixels (da camada 2x) por metro

    def para_px(x, z):
        return ((x - x0) * escala, (z - z0) * escala)

    fundo = _fundo(g, x0, z0, tam, cfg["passo"])
    # um pouco de desfoque antes de esticar: sem ele a grade de amostragem
    # aparece em escadinha na beira da lava
    fundo = fundo.filter(ImageFilter.GaussianBlur(0.6)).resize((RES * SS, RES * SS), Image.BICUBIC)
    fundo = fundo.convert("RGBA")
    pontos_cena = json.load(open(os.path.join(STAGES, cfg["pasta"], cfg["pasta"] + "_pontos.json"), encoding="utf-8"))
    if pontos_cena.get("mapa_blocos"):
        fundo.alpha_composite(_desenhar_blocos(pontos_cena["mapa_blocos"], para_px, escala))
    fundo.alpha_composite(_desenhar_caminho(g, idx, para_px, escala))
    final = fundo.convert("RGB").resize((RES, RES), Image.LANCZOS)

    pasta = os.path.join(STAGES, cfg["pasta"])
    os.makedirs(os.path.join(pasta, "textures"), exist_ok=True)
    final.save(os.path.join(pasta, "textures", cfg["png"]))

    pontos = []
    for area, chave_tr, tipo in cfg["pontos"]:
        p = pontos_cena["areas"].get(area)
        if p is None:
            continue
        pontos.append({"id": area, "chave": chave_tr, "tipo": tipo,
                       "x": round(p[0], 2), "z": round(p[2], 2)})
    dados = {
        "nota": "recorte do %s coberto por %s; gerado por tools/godot/inferno/make_mapa_inferno.py"
                % (cfg["pasta"], cfg["png"]),
        "mundo_x0": round(x0, 2),
        "mundo_z0": round(z0, 2),
        "tamanho_m": round(tam, 2),
        "resolucao": RES,
        "pontos": pontos,
    }
    with open(os.path.join(pasta, cfg["json"]), "w", encoding="utf-8") as fp:
        json.dump(dados, fp, indent=1, ensure_ascii=False)
    print("  %s: %.0f m de lado, %d pontos -> %s" % (chave, tam, len(pontos), cfg["png"]))
    # o proximo gerador importa outros modulos com os mesmos nomes de global
    for m in (cfg["gerador"],):
        sys.modules.pop(m, None)
    sys.path.remove(os.path.join(BLENDER, cfg["pasta"]))


if __name__ == "__main__":
    for k in sys.argv[1:] or ("inferno", "inferno_2", "inferno_3", "inferno_4"):
        gerar(k)
