"""Mapa da cidade visto de cima, para o minimapa do HUD.

Desenhado a partir dos DADOS (layout.json + houses.json), não renderizado da
cena. Motivos: fica legível a 200 px, não depende de iluminação nem da hora
do dia, e regerar custa dois segundos.

Sai junto um `citymap.json` com o recorte do mundo que a imagem cobre, para o
script do Godot não precisar repetir esses números — se o mapa crescer, os
dois andam juntos sozinhos.

Coordenadas: o layout guarda (px, py) locais da cidade; o mundo do Godot é
X = origin_x + px  e  Z = origin_z - py  (ver layout.json/world).
"""
import json
import math
import os

from PIL import Image, ImageDraw

_HERE = os.path.dirname(os.path.abspath(__file__))
_CITYGEN = os.path.dirname(_HERE)
_REPO = os.path.abspath(os.path.join(_CITYGEN, "..", "..", ".."))
ASSETS = os.path.join(_REPO, "red-valve", "assets", "3d_model", "city")
OUT_PNG = os.path.join(ASSETS, "textures", "T_citymap.png")
OUT_JSON = os.path.join(ASSETS, "citymap.json")

RES = 2048          # pixels do lado
SS = 2              # supersampling: desenha em 2x e reduz, para suavizar
MARGEM = 40.0       # metros de folga além dos limites da cidade

# Paleta: noite chuvosa, na mesma família do LUT sépia do jogo. O contraste
# entre via e fundo é o que carrega a leitura em tamanho pequeno.
C_MATA     = (16, 20, 17)
C_SOLO     = (38, 34, 29)
C_QUADRA   = (47, 42, 35)
C_PRACA    = (44, 56, 40)
C_CASA     = (88, 76, 63)
C_CASA_BRD = (24, 21, 17)
C_VIA      = (156, 145, 126)
C_TERRA    = (112, 91, 68)
C_VIA_BRD  = (22, 19, 16)
C_MARCO    = (198, 152, 86)

# largura da linha por classe, em metros (a via real, sem o casing)
LARGURA = {"avenida": 10.0, "principal": 8.0, "radial": 7.0,
           "secundaria": 6.0, "travessa": 5.0, "beco": 3.5}
TERROSAS = ("travessa", "beco")
# desenhar da mais estreita para a mais larga: cruzamento fica com a via
# principal por cima, que é como um mapa de papel se lê
ORDEM = ["beco", "travessa", "secundaria", "radial", "principal", "avenida"]


def _carrega():
    lay = json.load(open(os.path.join(_CITYGEN, "city_data", "layout.json"),
                         encoding="utf-8"))
    casas = json.load(open(os.path.join(ASSETS, "houses.json"),
                           encoding="utf-8"))
    return lay, casas


def _recorte(lay):
    """Quadrado do mundo que a imagem cobre. Quadrado para a escala ser a
    mesma nos dois eixos — senão o minimapa gira deformado."""
    ox, oz = lay["world"]["origin_x"], lay["world"]["origin_z"]
    (x0, y0), (x1, y1) = lay["bounds"]["min"], lay["bounds"]["max"]
    X = [ox + x0, ox + x1]
    Z = [oz - y1, oz - y0]
    cx, cz = sum(X) / 2.0, sum(Z) / 2.0
    meio = max(X[1] - X[0], Z[1] - Z[0]) / 2.0 + MARGEM
    return cx - meio, cz - meio, meio * 2.0


def build():
    lay, casas = _carrega()
    ox, oz = lay["world"]["origin_x"], lay["world"]["origin_z"]
    X0, Z0, TAM = _recorte(lay)
    N = RES * SS
    ppm = N / TAM                      # pixels por metro

    def P(wx, wz):
        return ((wx - X0) * ppm, (wz - Z0) * ppm)

    def L(px, py):
        """local da cidade -> pixel"""
        return P(ox + px, oz - py)

    img = Image.new("RGB", (N, N), C_MATA)
    dr = ImageDraw.Draw(img)

    # ---- chão da cidade, com canto arredondado para não virar um quadrado
    (bx0, by0), (bx1, by1) = lay["bounds"]["min"], lay["bounds"]["max"]
    a, b = L(bx0, by1), L(bx1, by0)
    dr.rounded_rectangle([a, b], radius=int(28 * ppm), fill=C_SOLO)

    # ---- quadras
    for q in lay["blocks"]:
        dr.polygon([L(*p) for p in q["poly"]], fill=C_QUADRA)

    # ---- marcos com área própria
    for nome, m in lay["landmarks"].items():
        if m["type"] == "circle":
            cx, cy = m["center"]
            r = m["radius"]
            dr.ellipse([L(cx - r, cy + r), L(cx + r, cy - r)], fill=C_PRACA)
        elif m["type"] == "rect":
            cx, cy = m["center"]
            w, h = m["size"]
            dr.polygon(_rect(L, cx, cy, w, h, m.get("rotation", 0.0)),
                       fill=C_QUADRA)
        elif m["type"] == "compound":
            cx, cy = m["center"]
            w, h = m["size"]
            dr.polygon(_rect(L, cx, cy, w, h, 0.0), fill=C_QUADRA)

    # ---- vias: casing escuro primeiro, depois a pista
    for passada in (0, 1):
        for cls in ORDEM:
            for r in lay["roads"]:
                if r["class"] != cls:
                    continue
                lg = LARGURA.get(cls, r["width"])
                if passada == 0:
                    cor, larg = C_VIA_BRD, lg + 2.2
                else:
                    cor = C_TERRA if cls in TERROSAS else C_VIA
                    larg = lg
                pts = [L(*p) for p in r["points"]]
                dr.line(pts, fill=cor, width=max(1, int(larg * ppm)),
                        joint="curve")

    # ---- casas (já vêm em coordenadas locais do Godot: x, z)
    for c in casas["casas"]:
        cantos = _casa(P, ox, oz, c)
        dr.polygon(cantos, fill=C_CASA, outline=C_CASA_BRD)

    # ---- acentos dos marcos, por cima de tudo
    pr = lay["landmarks"]["praca_obelisco"]
    r = pr["island_radius"]
    dr.ellipse([L(-r, r), L(r, -r)], fill=C_MARCO)
    ig = lay["landmarks"]["igreja_matriz"]
    dr.polygon(_rect(L, ig["center"][0], ig["center"][1],
                     ig["size"][0], ig["size"][1], ig["rotation"]),
               fill=C_MARCO)

    img = img.resize((RES, RES), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT_PNG), exist_ok=True)
    img.save(OUT_PNG)

    meta = {"nota": "recorte do mundo coberto por T_citymap.png; "
                    "gerado por tools/blender/citygen/textures/make_minimap.py",
            "mundo_x0": round(X0, 2), "mundo_z0": round(Z0, 2),
            "tamanho_m": round(TAM, 2), "resolucao": RES}
    json.dump(meta, open(OUT_JSON, "w", encoding="utf-8"), indent=1)
    return meta


def _rect(L, cx, cy, w, h, graus):
    t = math.radians(graus)
    ct, st = math.cos(t), math.sin(t)
    saida = []
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        dx, dy = sx * w / 2.0, sy * h / 2.0
        saida.append(L(cx + dx * ct - dy * st, cy + dx * st + dy * ct))
    return saida


def _casa(P, ox, oz, c):
    """Retângulo da casa no plano (X, Z) do mundo.

    `rot` é o mesmo ângulo que o oclusor usa em `Basis(Vector3.UP, rot)`, que
    leva (a, 0, b) para (a·cos + b·sen, 0, −a·sen + b·cos).

    houses.json está em coordenadas LOCAIS da cidade (o nó City fica em
    (origin_x, 0, origin_z)), então soma-se a origem para chegar ao mundo.
    Isto é diferente das ruas do layout, que vêm em (px, py) e trocam o sinal
    de py — foi exatamente aí que eu errei na primeira tentativa.
    """
    ct, st = math.cos(c["rot"]), math.sin(c["rot"])
    hw, hd = c["w"] / 2.0, c["d"] / 2.0
    cx, cz = ox + c["x"], oz + c["z"]
    saida = []
    for sa, sb in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        a, b = sa * hw, sb * hd
        saida.append(P(cx + a * ct + b * st, cz - a * st + b * ct))
    return saida


if __name__ == "__main__":
    m = build()
    print("T_citymap.png:", OUT_PNG)
    print("  recorte X0=%.1f Z0=%.1f tamanho=%.1f m  (%.2f px/m)" % (
        m["mundo_x0"], m["mundo_z0"], m["tamanho_m"],
        m["resolucao"] / m["tamanho_m"]))
