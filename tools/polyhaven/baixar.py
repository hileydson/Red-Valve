"""Baixa modelos e texturas do Poly Haven (CC0) para dentro do projeto.

    python3 tools/polyhaven/baixar.py modelos wheelchair_01 medical_box ...
    python3 tools/polyhaven/baixar.py texturas dirty_tiles white_rough_plaster ...

Segue o layout que o projeto ja' usa (o mesmo da casa do Jimmy):

    red-valve/assets/3d_model/polyhaven/<nome>/<nome>_1k.gltf + .bin + textures/
    red-valve/assets/images/textures/polyhaven/<nome>_diff.jpg  (e _arm, _nor_gl)

Pula o que ja' existe, entao rodar de novo e' barato.
"""

import json
import os
import sys
import urllib.request

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASE = os.path.join(RAIZ, "red-valve")
DIR_MODELOS = os.path.join(BASE, "assets", "3d_model", "polyhaven")
DIR_TEXTURAS = os.path.join(BASE, "assets", "images", "textures", "polyhaven")
API = "https://api.polyhaven.com/files/%s"


def _pegar(url, destino):
    if os.path.exists(destino) and os.path.getsize(destino) > 0:
        return False
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "red-valve/1.0"})
    with urllib.request.urlopen(req, timeout=120) as resp, open(destino, "wb") as fp:
        fp.write(resp.read())
    return True


def _ficha(nome):
    req = urllib.request.Request(API % nome, headers={"User-Agent": "red-valve/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def modelo(nome, res="1k"):
    d = _ficha(nome)
    if "gltf" not in d:
        print("  %-34s SEM GLTF" % nome)
        return
    g = d["gltf"][res]["gltf"]
    pasta = os.path.join(DIR_MODELOS, nome)
    novos = 0
    novos += _pegar(g["url"], os.path.join(pasta, os.path.basename(g["url"])))
    for rel, info in g.get("include", {}).items():
        novos += _pegar(info["url"], os.path.join(pasta, rel))
    print("  %-34s %s" % (nome, "baixado" if novos else "ja' existia"))


# Mapa dos canais do Poly Haven para o sufixo que o projeto usa.
CANAIS = {"Diffuse": "diff", "arm": "arm", "nor_gl": "nor_gl"}


def textura(nome, res="1k"):
    d = _ficha(nome)
    novos = 0
    for canal, sufixo in CANAIS.items():
        if canal not in d or res not in d[canal]:
            continue
        info = d[canal][res].get("jpg") or d[canal][res].get("png")
        if not info:
            continue
        ext = os.path.splitext(info["url"])[1]
        novos += _pegar(info["url"],
                        os.path.join(DIR_TEXTURAS, "%s_%s%s" % (nome, sufixo, ext)))
    print("  %-34s %s" % (nome, "baixado" if novos else "ja' existia"))


if __name__ == "__main__":
    modo = sys.argv[1]
    nomes = sys.argv[2:]
    print("%s (%d):" % (modo, len(nomes)))
    for n in nomes:
        try:
            (modelo if modo == "modelos" else textura)(n)
        except Exception as erro:
            print("  %-34s FALHOU: %s" % (n, erro))
