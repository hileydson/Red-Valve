# -*- coding: utf-8 -*-
"""Acha pecas FLUTUANDO num cenario gerado por script (sem exportar nada).

    blender --background --factory-startup \
        --python tools/blender/cenarios/achar_flutuantes.py -- inferno_2

Um 2o argumento opcional soma prefixos de setor que tambem sao chao, pra
cenario que nao chama o piso de `chao` (a arena 3: `-- arena_3 praca`).

O argumento e' a pasta do gerador em tools/blender (`gerar_<pasta>.py`).
Roda o gerador inteiro, anota cada peca que entra nas malhas (com a linha do
gerador que a criou) e separa em componentes conexos. Imprime:

  - SEM ESPESSURA: peca achatada em dois eixos (nao aparece). O `tubo` da
    igreja na vertical sai assim: corrente feita com ele some e a gaiola fica
    no ar — use `corrente_vertical`.
  - SOLTAS: o que nao encosta no chao/lava nem, por uma cadeia de contatos,
    em nada que encoste. Tem de dar ZERO.
  - BASE NO AR: peca apoiada cujo pe' passa acima do chao que se ve' (pilar
    na quina do penhasco). Aqui sobra o que e' de proposito: corrente com
    barriga presa nas duas pontas, galho de espinho, ventosa de tentaculo.

"Chao" sao os setores `chao*` e `lava*` e os objetos soltos (sombras, maos,
que nascem dentro da lava). Ver [[project-cenarios-gerados-novos]].
"""
import collections
import importlib
import math
import os
import sys

from mathutils import Vector
from mathutils.bvhtree import BVHTree

ALVO = sys.argv[sys.argv.index("--") + 1]
_ARGS = sys.argv[sys.argv.index("--") + 1:]
CHAO_EXTRA = tuple(_ARGS[1].split(",")) if len(_ARGS) > 1 else ()
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RAIZ, ALVO))
sys.path.insert(0, os.path.join(RAIZ, "cenarios"))
sys.dont_write_bytecode = True
NOME = "gerar_" + ALVO
ARQ = os.path.join(RAIZ, ALVO, NOME + ".py")

import base  # noqa: E402
from geo import Malhas  # noqa: E402

REG = []          # (setor, mat, v0, nv, f0, nf, pilha)
_add = Malhas.add


def add(self, setor, material, verts, faces, uvs=None, suave=False):
    pilha = []
    f = sys._getframe(1)
    while f is not None:
        if f.f_code.co_filename == ARQ:
            pilha.append("%s:%d" % (f.f_code.co_name, f.f_lineno))
        f = f.f_back
    g = self.grupos.get((setor, material))
    v0 = len(g["v"]) if g else 0
    f0 = len(g["f"]) if g else 0
    REG.append((setor, material, v0, len(verts), f0, len(faces), pilha))
    return _add(self, setor, material, verts, faces, uvs, suave)


Malhas.add = add
CAPT = {}
base.Cena.exportar = lambda self, *a, **k: CAPT.setdefault("cena", self)
g = importlib.import_module(NOME)
g.main()
cena = CAPT["cena"]
EPS = 0.06


def componentes(verts, faces):
    pai = list(range(len(verts)))

    def ach(a):
        while pai[a] != a:
            pai[a] = pai[pai[a]]
            a = pai[a]
        return a
    for fa in faces:
        r0 = ach(fa[0])
        for k in fa[1:]:
            r = ach(k)
            if r != r0:
                pai[r] = r0
    grupos = collections.defaultdict(list)
    for fa in faces:
        grupos[ach(fa[0])].append(fa)
    out = []
    for fs in grupos.values():
        usados = sorted({k for fa in fs for k in fa})
        m = {k: i for i, k in enumerate(usados)}
        out.append(([verts[k] for k in usados], [[m[k] for k in fa] for fa in fs]))
    return out


def centros(v, f):
    out = []
    for fa in f:
        n = float(len(fa))
        out.append((sum(v[k][0] for k in fa) / n, sum(v[k][1] for k in fa) / n, sum(v[k][2] for k in fa) / n))
    return out


def amostra(vs, k=40):
    if len(vs) <= k:
        return list(vs)
    passo = len(vs) / float(k)
    return [vs[int(i * passo)] for i in range(k)]


def eh_chao(setor):
    return setor.startswith(("chao", "lava") + CHAO_EXTRA)


chao_v, chao_f = [], []
pecas = []        # dicts
for setor, mat, v0, nv, f0, nf, pilha in REG:
    gr = cena.m.grupos[(setor, mat)]
    v = gr["v"][v0:v0 + nv]
    f = [[k - v0 for k in fa] for fa in gr["f"][f0:f0 + nf]]
    if eh_chao(setor):
        b = len(chao_v)
        chao_v.extend(v)
        chao_f.extend([[k + b for k in fa] for fa in f])
        continue
    for cv, cf in componentes(v, f):
        xs = [p[0] for p in cv]
        ys = [p[1] for p in cv]
        zs = [p[2] for p in cv]
        pecas.append({"v": cv, "f": cf, "c": centros(cv, cf),
                      "bb": (min(xs), min(ys), min(zs), max(xs), max(ys), max(zs)),
                      "setor": setor, "mat": mat, "pilha": pilha})
for setor_solto, mat, (sv, sf), pos in cena.soltos:
    cv = [(p[0] + pos[0], p[1] + pos[1], p[2] + pos[2]) for p in sv]
    # soltos (sombras, maos) nascem dentro da lava de proposito
    b = len(chao_v)
    chao_v.extend(cv)
    chao_f.extend([[k + b for k in fa] for fa in sf])

arv_chao = BVHTree.FromPolygons(chao_v, chao_f, epsilon=EPS)
for p in pecas:
    p["t"] = BVHTree.FromPolygons(p["v"], p["f"], epsilon=EPS)
    # raio com epsilon acerta a mesma face duas vezes (entra e sai da casca)
    p["t0"] = BVHTree.FromPolygons(p["v"], p["f"])
arv_chao0 = BVHTree.FromPolygons(chao_v, chao_f)


def dentro(t, q):
    # paridade de cruzamentos subindo: vale pra malha fechada de qualquer giro
    o = Vector(q)
    n = 0
    d = Vector((0.0013, 1.0, 0.0007)).normalized()
    for _ in range(60):
        loc, _nor, _idx, _dist = t.ray_cast(o, d)
        if loc is None:
            break
        n += 1
        o = loc + d * 1e-3
    return n % 2 == 1


def perto(t, pts):
    return any(t.find_nearest(q, EPS)[0] is not None for q in pts)


def toca(a, b):
    if a["t"].overlap(b["t"]):
        return True
    if perto(b["t"], amostra(a["v"]) + amostra(a["c"], 60)):
        return True
    if perto(a["t"], amostra(b["v"]) + amostra(b["c"], 60)):
        return True
    return any(dentro(b["t0"], q) for q in amostra(a["v"], 8)) or any(dentro(a["t0"], q) for q in amostra(b["v"], 8))


def chao_em(x, y, z):
    """Altura do chao/lava visivel abaixo de (x, y, z); None se nada."""
    loc = arv_chao0.ray_cast(Vector((x, y + 0.02, z)), Vector((0, -1, 0)))[0]
    return None if loc is None else loc.y


def embaixo_do_chao(x, y, z):
    loc = arv_chao0.ray_cast(Vector((x, y, z)), Vector((0, 1, 0)), 500.0)[0]
    return loc is not None


apoio = [False] * len(pecas)
no_chao = [False] * len(pecas)
fila = []
for i, p in enumerate(pecas):
    if (p["t"].overlap(arv_chao) or perto(arv_chao, amostra(p["v"]) + amostra(p["c"], 60))
            or all(embaixo_do_chao(*q) for q in amostra(p["v"], 12))):
        apoio[i] = True
        no_chao[i] = True
        fila.append(i)

CEL = 6.0
grade = collections.defaultdict(list)
for i, p in enumerate(pecas):
    x0, y0, z0, x1, y1, z1 = p["bb"]
    for a in range(int(math.floor(x0 / CEL)), int(math.floor(x1 / CEL)) + 1):
        for b in range(int(math.floor(z0 / CEL)), int(math.floor(z1 / CEL)) + 1):
            grade[(a, b)].append(i)


def candidatos(i):
    x0, y0, z0, x1, y1, z1 = pecas[i]["bb"]
    vistos = set()
    for a in range(int(math.floor(x0 / CEL)), int(math.floor(x1 / CEL)) + 1):
        for b in range(int(math.floor(z0 / CEL)), int(math.floor(z1 / CEL)) + 1):
            for j in grade[(a, b)]:
                if j == i or j in vistos:
                    continue
                vistos.add(j)
                q = pecas[j]["bb"]
                if (q[0] > x1 + EPS or q[3] < x0 - EPS or q[1] > y1 + EPS or q[4] < y0 - EPS
                        or q[2] > z1 + EPS or q[5] < z0 - EPS):
                    continue
                yield j


while fila:
    i = fila.pop()
    for j in candidatos(i):
        if not apoio[j] and toca(pecas[i], pecas[j]):
            apoio[j] = True
            fila.append(j)


def chave(p):
    return "%s %s" % (p["pilha"][0] if p["pilha"] else "?", p["mat"])


def desc(p, extra=""):
    x0, y0, z0, x1, y1, z1 = p["bb"]
    return "      c=(%.1f, %.2f, %.1f) tam=(%.1f, %.1f, %.1f) %s %s  [%s]" % (
        (x0 + x1) / 2, y0, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, p["setor"], extra, " < ".join(p["pilha"][1:3]))


finas = collections.Counter()
for p in pecas:
    x0, y0, z0, x1, y1, z1 = p["bb"]
    if sum(1 for d in (x1 - x0, y1 - y0, z1 - z0) if d < 0.005) >= 2:
        finas[chave(p)] += 1
print("\n==== %s: pecas sem espessura (invisiveis): %s" % (ALVO, dict(finas)))

soltas = collections.defaultdict(list)
for i, p in enumerate(pecas):
    if not apoio[i]:
        soltas[chave(p)].append(p)
print("\n==== %s: %d pecas, %d SOLTAS ====" % (ALVO, len(pecas), sum(len(v) for v in soltas.values())))
for k in sorted(soltas, key=lambda k: -len(soltas[k])):
    print("%-40s n=%3d" % (k, len(soltas[k])))
    for p in soltas[k][:5]:
        print(desc(p))

# pe' no ar: so' pra peca apoiada (as soltas ja' sairam acima)
base_ar = collections.defaultdict(list)
for i, p in enumerate(pecas):
    if not no_chao[i]:
        continue
    x0, y0, z0, x1, y1, z1 = p["bb"]
    if y1 - y0 < 0.3:
        continue
    lim = y0 + 0.15
    pe = [q for q in p["v"] if q[1] <= lim]
    pior = 0.0
    for q in pe:
        if embaixo_do_chao(*q):
            continue
        h = chao_em(*q)
        if h is None:
            continue
        pior = max(pior, q[1] - h)
    if pior > 0.6:
        # o pe' pode estar apoiado em outra peca (estatua no pedestal)
        sobre = False
        for j in candidatos(i):
            if j != i and perto(pecas[j]["t"], [Vector(q) - Vector((0, 0.05, 0)) for q in pe[:12]]):
                sobre = True
                break
        if not sobre:
            base_ar[chave(p)].append((pior, p))
print("\n==== %s: BASE NO AR (pe' acima do chao, sem outra peca embaixo) ====" % ALVO)
for k in sorted(base_ar, key=lambda k: -max(e[0] for e in base_ar[k])):
    lst = sorted(base_ar[k], key=lambda e: -e[0])
    print("%-40s n=%3d  pior=%.2f" % (k, len(lst), lst[0][0]))
    for pior, p in lst[:4]:
        print(desc(p, "vao=%.2f" % pior))
