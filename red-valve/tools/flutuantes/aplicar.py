"""Aplica as correcoes do achar.gd numa .tscn: soma `delta` na origem do no'
`raiz` (o pai dele tem de estar sem transform, que e' o caso dos conteineres).

    python3 tools/flutuantes/aplicar.py <cena.tscn> <achados.json> [--so a,b]
"""
import json
import re
import sys


def main():
    cena, achados = sys.argv[1], sys.argv[2]
    so = None
    if "--so" in sys.argv:
        so = set(sys.argv[sys.argv.index("--so") + 1].split(","))
    texto = open(cena).read()
    vistos = set()
    for a in json.load(open(achados)):
        raiz = a["raiz"]
        if raiz in vistos or (so and raiz not in so):
            continue
        vistos.add(raiz)
        dx, dy, dz = a["delta"]
        if dx == dy == dz == 0:
            continue
        nome = raiz.split("/")[-1]
        pai = "/".join(raiz.split("/")[:-1]) or "."
        cab = re.escape('[node name="%s"' % nome) + r'[^\]]*parent="' + re.escape(pai) + r'"[^\]]*\]'
        m = re.search(cab, texto)
        if not m:
            print("NAO ACHEI", raiz)
            continue
        fim = texto.find("\n[", m.end())
        bloco = texto[m.end():fim if fim >= 0 else len(texto)]
        t = re.search(r"transform = Transform3D\(([^)]*)\)", bloco)
        if t:
            v = [float(x) for x in t.group(1).split(",")]
            v[9] += dx; v[10] += dy; v[11] += dz
            novo = "transform = Transform3D(%s)" % ", ".join(("%.6f" % n).rstrip("0").rstrip(".") if n != 0 else "0" for n in v)
            bloco2 = bloco[:t.start()] + novo + bloco[t.end():]
        else:
            linha = "\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.4f, %.4f, %.4f)" % (dx, dy, dz)
            bloco2 = linha + bloco
        texto = texto[:m.end()] + bloco2 + texto[m.end() + len(bloco):]
        print("ok", raiz, (dx, dy, dz))
    open(cena, "w").write(texto)


main()
