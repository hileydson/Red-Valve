# -*- coding: utf-8 -*-
"""Base comum dos cenarios a ceu aberto gerados por script (arena 3, cemiterio
e inferno).

Nao reinventa nada: a geometria gotica vem do `geo.py` da igreja e as pecas
que a igreja nao tinha (tubo redondo, espinho, chapa fechada, export, ilha do
navmesh) vem do gerador da arena 2. O que mora aqui e' so' o que os tres
cenarios novos repetiriam igual:

  - `Cena`: o acumulador (malhas por setor x material, colisao, pontos pro
    Godot, bloqueios do navmesh) e o export do .glb + .json.
  - `navmesh_grade`: navmesh em grade a partir de uma funcao de altura e de
    um predicado "da' pra andar aqui", ja' cortado na maior ilha.
  - `muro_invisivel`: cerca de colisao ao longo de uma polilinha.
  - `chao_grade`: chao visivel em lajes FECHADAS por setor (ver
    [[project-chapa-aberta-normais]] na memoria do projeto: chapa aberta sai
    com normal sorteada).
  - `chao_visivel` / `estender_ate_o_chao` / `assentar` / `corrente_vertical`:
    nada fica no ar — pe' de pilar desce ate' o chao que se VE (a grade
    grossa passa metros abaixo da `altura` na beira do penhasco), pedra
    solta assenta, e o que pende pende de uma corrente que existe.

Convencao de eixos (a mesma do resto de tools/blender): X = largura, Y =
ALTURA, Z = profundidade; -Z e' o "norte". Export com `export_yup=False`.
"""

import json
import math
import os
import random
import sys

# nao suja o __pycache__ versionado da arena 2 ao importar o gerador dela
sys.dont_write_bytecode = True

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "igreja"))
sys.path.insert(0, os.path.join(AQUI, os.pardir, "arena_2"))

import gerar_arena_2 as a2                                   # noqa: E402
from geo import (Malhas, caixa, caixa_girada, cilindro, domo,  # noqa: E402,F401
                 entulho, hexaedro, mapa_girado, painel, pilar_composto,
                 tubo, arco_perfil, arquivolta, faixa_sobre_arco, cruz,
                 coluneta, corrente)

tubo_redondo = a2.tubo_redondo
espinho = a2.espinho
arco_pontos = a2.arco_pontos
chapa_grossa = a2.chapa_grossa
parede_reta = a2.parede_reta
dist_polilinha = a2.dist_polilinha
maior_ilha = a2.Arena._maior_ilha

DESTINO_BASE = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "stages")


def lerp(a, b, t):
    return a + (b - a) * t


def suave(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def ruido2(x, z, semente=0.0):
    """Ruido de valor barato e deterministico (soma de senos desalinhados).
    Nao precisa ser bonito: so' tirar a cara de grade das alturas."""
    return (math.sin(x * 0.137 + semente) * math.cos(z * 0.113 - semente * 0.7)
            + 0.5 * math.sin(x * 0.291 - z * 0.233 + semente * 1.3)
            + 0.25 * math.sin(x * 0.61 + z * 0.57 + semente * 2.1)) / 1.75


class Cena:
    """Acumulador de um cenario. Igual ao `Arena` da arena 2, sem a planta."""

    def __init__(self, prefixo, semente):
        self.prefixo = prefixo
        self.m = Malhas()
        self.rnd = random.Random(semente)
        self.col = []
        self.bloqueios = []
        self.pontos = {}
        # objetos com PIVO proprio (o script mexe neles): (nome, mat, (v, f), pos)
        # com os vertices em coordenada LOCAL. Saem no .glb como no' separado.
        self.soltos = []

    # -- utilidades -----------------------------------------------------

    def setor_grade(self, nome, x, z, passo):
        """Setor por celula de grade grossa. Mesmo motivo do `quadrante` da
        arena 2: o renderer mobile ve' so' 8 omni POR MALHA, e uma malha do
        tamanho do mapa enxergaria todas as luzes dele."""
        return "%s_%d_%d" % (nome, int(math.floor(x / passo)),
                             int(math.floor(z / passo)))

    def bloquear(self, x, z, raio):
        self.bloqueios.append((x, z, raio))

    def bloquear_linha(self, x0, z0, x1, z1, raio):
        d = math.hypot(x1 - x0, z1 - z0)
        n = max(2, int(d / max(raio, 0.5)) + 1)
        for i in range(n + 1):
            t = i / n
            self.bloqueios.append((lerp(x0, x1, t), lerp(z0, z1, t), raio))

    def bloqueado(self, x, z, folga=0.0):
        for bx, bz, br in self.bloqueios:
            if (x - bx) ** 2 + (z - bz) ** 2 < (br + folga) ** 2:
                return True
        return False

    # -- export ---------------------------------------------------------

    def exportar(self, pasta, nome, abertos=()):
        """Cria um objeto por (setor, material), a colisao `CL_<nome>-colonly`
        e grava `<nome>.glb` + `<nome>_pontos.json` em `pasta`."""
        import bpy
        a2.limpar_cena()
        criados = []
        for (setor, mat_nome), dados in sorted(self.m.grupos.items()):
            if not dados["f"]:
                continue
            obj = "SM_%s_%s_%s" % (self.prefixo, setor, mat_nome)
            ob = a2.criar_objeto(obj, dados, mat_nome)
            if not any(setor.startswith(a) for a in abertos):
                a2.recalcular_normais(ob)
            criados.append((obj, len(dados["f"])))
        for nome_solto, mat, (sv, sf), pos in self.soltos:
            sd = {"v": sv, "f": sf, "uv": [None] * len(sf), "s": [False] * len(sf)}
            ob = a2.criar_objeto("%s_%s" % (nome_solto, mat), sd, mat)
            a2.recalcular_normais(ob)
            ob.location = pos
            criados.append((ob.name, len(sf)))
        v, f = a2.juntar(self.col)
        dados = {"v": v, "f": f, "uv": [None] * len(f), "s": [False] * len(f)}
        a2.recalcular_normais(a2.criar_objeto("CL_%s-colonly" % nome, dados, "pedra"))
        destino = os.path.join(DESTINO_BASE, pasta)
        os.makedirs(destino, exist_ok=True)
        glb = os.path.join(destino, nome + ".glb")
        tam = a2.exportar(glb)
        with open(os.path.join(destino, nome + "_pontos.json"), "w") as fp:
            json.dump(self.pontos, fp, indent=1)
        print("\n--- %s gerado ---" % nome)
        for o, n in criados:
            print("  %-44s %6d faces" % (o, n))
        print("  colisao: %d faces" % len(f))
        print("  triangulos visiveis ~%d em %d malhas" % (self.m.total_tris(), len(criados)))
        print("  %s  %.1f MB" % (glb, tam / 1048576.0))
        _ = bpy
        return glb


# --------------------------------------------------------------------------
# chao


def chapa_aberta(celulas, passo, altura, vertice=None):
    """So' o tampo da grade, com vertices compartilhados e a face ja' virada
    pra cima (a, b, c, d = (i,j), (i,j+1), (i+1,j+1), (i+1,j) da' normal +Y).
    Serve pro chao que so' se VE: o setor tem de ir em `abertos` no export,
    senao o `normals_make_consistent` sorteia o lado.
    `vertice(i, j) -> (x, y, z)`, se vier, decide onde fica cada canto (a
    beira do abismo puxa os de fora pra linha da beira)."""
    idx, verts, faces = {}, [], []

    def vid(i, j):
        if (i, j) not in idx:
            idx[(i, j)] = len(verts)
            if vertice is not None:
                verts.append(vertice(i, j))
            else:
                x, z = i * passo, j * passo
                verts.append((x, altura(x, z), z))
        return idx[(i, j)]

    for (i, j) in celulas:
        faces.append([vid(i, j), vid(i, j + 1), vid(i + 1, j + 1), vid(i + 1, j)])
    return verts, faces


def chao_grade(cena, x0, x1, z0, z1, passo, altura, classe, setor_passo,
               nome_setor="chao", esp=0.6, aberta=False):
    """Chao visivel em lajes FECHADAS, uma por (setor, material).

    `classe(xc, zc)` devolve o material da celula (ou None = sem chao ali).
    `altura(x, z)` e' a mesma funcao que a colisao e o navmesh usam — chao,
    colisao e navmesh saem da mesma conta, entao ninguem anda acima nem
    abaixo do que ve' (licao das crateras da arena 2).
    """
    grupos = {}
    nx = int(math.ceil((x1 - x0) / passo))
    nz = int(math.ceil((z1 - z0) / passo))
    i0 = int(math.floor(x0 / passo))
    j0 = int(math.floor(z0 / passo))
    for i in range(i0, i0 + nx):
        for j in range(j0, j0 + nz):
            xc, zc = (i + 0.5) * passo, (j + 0.5) * passo
            mat = classe(xc, zc)
            if mat is None:
                continue
            setor = cena.setor_grade(nome_setor, xc, zc, setor_passo)
            grupos.setdefault((setor, mat), []).append((i, j))
    for (setor, mat), celulas in grupos.items():
        if aberta:
            v, f = chapa_aberta(celulas, passo, altura)
        else:
            v, f = chapa_grossa(celulas, passo, altura, esp)
        cena.m.add(setor, mat, v, f)
    return grupos


def colisao_grade(cena, celulas, passo, altura, esp=1.5):
    """Colisao do chao: a mesma conta de altura numa laje fechada."""
    v, f = chapa_grossa(list(celulas), passo, altura, esp)
    cena.col.append((v, f))


# --------------------------------------------------------------------------
# assentar no chao (nada flutuando)


def chao_visivel(altura, passo, x, z):
    """Altura do chao que se VE em (x, z). O chao e' uma grade de `passo` m
    com a altura so' nos cantos (`chapa_aberta`): entre eles o tampo e' reto,
    entao na beira do penhasco ele passa metros abaixo da `altura` do ponto,
    e o que nasce na `altura` fica no ar. A diagonal de cada quadrado depende
    da triangulacao do export, entao vale a mais baixa das duas."""
    i, j = math.floor(x / passo), math.floor(z / passo)
    u, w = x / passo - i, z / passo - j
    h00 = altura(i * passo, j * passo)
    h10 = altura((i + 1) * passo, j * passo)
    h01 = altura(i * passo, (j + 1) * passo)
    h11 = altura((i + 1) * passo, (j + 1) * passo)
    if u >= w:
        a = h00 + (h10 - h00) * u + (h11 - h10) * w
    else:
        a = h00 + (h11 - h01) * u + (h01 - h00) * w
    if u + w <= 1.0:
        b = h00 + (h10 - h00) * u + (h01 - h00) * w
    else:
        b = h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - w)
    return min(a, b, altura(x, z))


def chao_sob(chao, x, z, raio):
    """O ponto mais baixo de `chao(x, z)` debaixo de um pe' de `raio`."""
    hs = [chao(x, z)]
    for k in range(8):
        a = math.pi * k / 4.0
        for r in (raio * 0.5, raio):
            hs.append(chao(x + r * math.cos(a), z + r * math.sin(a)))
    return min(hs)


def _pe(v):
    """Indices dos vertices do pe' de uma peca (a face de baixo)."""
    y0 = min(p[1] for p in v)
    y1 = max(p[1] for p in v)
    tol = max(0.05, 0.12 * (y1 - y0))
    return [k for k, p in enumerate(v) if p[1] <= y0 + tol]


def estender_ate_o_chao(pecas, chao, folga=0.5, passo=2.0):
    """Puxa o pe' de cada peca (pilar, espinho, plinto, torre) pra baixo ate'
    `folga` m DENTRO do chao mais baixo debaixo dela. A peca vira mais
    comprida pra baixo: na encosta o lado de cima fica enterrado e o de baixo
    desce ate' o chao, em vez de ficar no ar. So' desce, nunca sobe."""
    out = []
    for v, f in pecas:
        pe = _pe(v)
        xs = [v[k][0] for k in pe]
        zs = [v[k][2] for k in pe]
        nx = max(1, int(math.ceil((max(xs) - min(xs)) / passo)))
        nz = max(1, int(math.ceil((max(zs) - min(zs)) / passo)))
        fundo = min(chao(lerp(min(xs), max(xs), a / nx), lerp(min(zs), max(zs), b / nz))
                    for a in range(nx + 1) for b in range(nz + 1)) - folga
        v = list(v)
        for k in pe:
            if v[k][1] > fundo:
                v[k] = (v[k][0], fundo, v[k][2])
        out.append((v, f))
    return out


def assentar(pecas, chao, afundar=0.15):
    """Desce cada peca inteira (pedra solta, entulho) ate' nenhum vertice do
    pe' ficar acima do chao debaixo dele. So' desce, nunca sobe."""
    out = []
    for v, f in pecas:
        folga = max(v[k][1] - chao(v[k][0], v[k][2]) for k in _pe(v))
        dy = -(folga + afundar) if folga > -afundar else 0.0
        out.append(([(p[0], p[1] + dy, p[2]) for p in v], f))
    return out


def corrente_vertical(x, z, y_cima, y_baixo, larg=0.16):
    """Corrente pendurada, de elos chatos alternados a 90 graus e encavalados
    (uma peca continua do apoio ate' o que ela segura). O `tubo` da igreja
    nao serve aqui: a secao dele se orienta pelo passo em X/Z e, na vertical,
    sai com espessura ZERO — a corrente some e a gaiola fica no ar."""
    n = max(1, int(math.ceil((y_cima - y_baixo) / (larg * 2.2))))
    passo = (y_cima - y_baixo) / n
    pecas = []
    for k in range(n):
        yc = y_cima - passo * (k + 0.5)
        pecas.append(caixa_girada(x, yc, z, larg, passo + larg * 0.6, larg * 0.4, (k % 2) * math.pi / 2))
    return pecas


# --------------------------------------------------------------------------
# cerca e navmesh


def muro_invisivel(cena, pontos, y0=-4.0, y1=26.0, esp=1.2, fechar=True):
    """Cerca de colisao ao longo de uma polilinha (x, z). E' ela, e nao o
    cenario, que segura o jogador: caixa lisa, sem quina pra escalar."""
    n = len(pontos)
    lim = n if fechar else n - 1
    for k in range(lim):
        p0 = pontos[k]
        p1 = pontos[(k + 1) % n]
        # um palmo a mais de cada lado: dois paineis encostados na quina
        # deixam fresta por onde a capsula escorrega
        dx, dz = p1[0] - p0[0], p1[1] - p0[1]
        d = math.hypot(dx, dz) or 1.0
        ex, ez = dx / d * 0.6, dz / d * 0.6
        cena.col.append(parede_reta((p0[0] - ex, p0[1] - ez),
                                    (p1[0] + ex, p1[1] + ez), y0, y1, esp))


def navmesh_grade(cena, x0, x1, z0, z1, passo, altura, caminhavel,
                  max_desnivel=0.6, folga=0.45, blocos=(8, 4, 2), desnivel_bloco=1.0):
    """Grade de navmesh, furada nos bloqueios, so' com a maior ilha.

    As celulas livres sao FUNDIDAS em blocos alinhados de 8x8, 4x4 e 2x2
    (quadtree). Sem isso o mapa grande passa de 4 mil poligonos e o A* do
    Godot desiste no meio (ele procura no maximo ~4096 poligonos por consulta
    e devolve um caminho PARCIAL, sem erro). O bloco leva todos os vertices da
    grade na borda, entao a aresta dele casa com a de qualquer vizinho menor —
    sem T-junction, sem ilha falsa. Ver [[project-navmesh-por-grade]].
    """
    indice = {}
    verts = []

    def vid(i, j):
        if (i, j) not in indice:
            x, z = i * passo, j * passo
            indice[(i, j)] = len(verts)
            verts.append([round(x, 3), round(altura(x, z), 3), round(z, 3)])
        return indice[(i, j)]

    livres = set()
    for i in range(int(math.floor(x0 / passo)), int(math.ceil(x1 / passo))):
        for j in range(int(math.floor(z0 / passo)), int(math.ceil(z1 / passo))):
            xc, zc = (i + 0.5) * passo, (j + 0.5) * passo
            if not caminhavel(xc, zc):
                continue
            if cena.bloqueado(xc, zc, folga):
                continue
            hs = [altura(a * passo, b * passo)
                  for a, b in ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))]
            if max(hs) - min(hs) > max_desnivel:
                continue
            livres.add((i, j))

    polys = []
    usadas = set()
    for s in blocos:
        for (i, j) in sorted(livres):
            if i % s or j % s:
                continue
            bloco = [(i + a, j + b) for a in range(s) for b in range(s)]
            if any(c not in livres or c in usadas for c in bloco):
                continue
            hs = [altura((i + a) * passo, (j + b) * passo) for a in (0, s) for b in (0, s)]
            hs.append(altura((i + s / 2.0) * passo, (j + s / 2.0) * passo))
            if max(hs) - min(hs) > desnivel_bloco:
                continue
            usadas.update(bloco)
            borda = [vid(i + a, j) for a in range(s)]
            borda += [vid(i + s, j + b) for b in range(s)]
            borda += [vid(i + s - a, j + s) for a in range(s)]
            borda += [vid(i, j + s - b) for b in range(s)]
            polys.append(borda)
    for (i, j) in sorted(livres - usadas):
        polys.append([vid(i, j), vid(i + 1, j), vid(i + 1, j + 1), vid(i, j + 1)])

    polys = maior_ilha(polys)
    usados, novos, limpos = {}, [], []
    for poly in polys:
        saida = []
        for k in poly:
            if k not in usados:
                usados[k] = len(novos)
                novos.append(verts[k])
            saida.append(usados[k])
        limpos.append(saida)
    return {"v": novos, "p": limpos}


def centros_navmesh(nav):
    out = []
    for poly in nav["p"]:
        n = float(len(poly))
        out.append((sum(nav["v"][k][0] for k in poly) / n,
                    sum(nav["v"][k][1] for k in poly) / n,
                    sum(nav["v"][k][2] for k in poly) / n))
    return out


def marcadores_em_volta(nav, centro, raio, quantos, fase=0.26):
    """Pontos de nascimento escolhidos ENTRE as celulas do navmesh (nunca no
    chao cru: marcador atras de escombro nasce fora do navmesh)."""
    centros = centros_navmesh(nav)
    usados, out = set(), []
    for k in range(quantos):
        a = 2 * math.pi * k / quantos + fase
        ax, az = centro[0] + raio * math.sin(a), centro[1] + raio * math.cos(a)
        melhor, md = None, 1e18
        for i, c in enumerate(centros):
            if i in usados:
                continue
            d = (c[0] - ax) ** 2 + (c[2] - az) ** 2
            if d < md:
                melhor, md = i, d
        if melhor is None:
            continue
        usados.add(melhor)
        c = centros[melhor]
        out.append([round(c[0], 2), round(c[1] + 0.1, 2), round(c[2], 2)])
    return out


# --------------------------------------------------------------------------
# pecas que os tres usam


def tentaculo(cena, setor, mat, base, direcao, comp, raio, curva=0.6, n=14,
              lados=9, fase=0.0, ventosas=None):
    """Tentaculo que sai de `base` na direcao dada e se enrola no fim."""
    dx, dy, dz = direcao
    d = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
    dx, dy, dz = dx / d, dy / d, dz / d
    # lateral pra torcer
    lx, lz = -dz, dx
    pts, raios = [], []
    for i in range(n + 1):
        t = i / n
        enrola = curva * t * t
        ang = enrola * math.pi * 1.6 + fase
        lat = math.sin(ang) * comp * 0.18 * t
        sobe = math.cos(ang) * comp * 0.05 * t
        pts.append((base[0] + dx * comp * t + lx * lat,
                    base[1] + dy * comp * t + sobe,
                    base[2] + dz * comp * t + lz * lat))
        raios.append(raio * (1.0 - 0.88 * t) + 0.04)
    cena.m.add_pecas(setor, mat, [tubo_redondo(pts, raios, n=lados)], suave=True)
    if ventosas:
        for i in range(2, n - 1, 2):
            p = pts[i]
            r = raios[i]
            cena.m.add_pecas(setor, ventosas, [cilindro(p[0], p[2], r * 0.28,
                                                         p[1] - r * 0.15,
                                                         p[1] + r * 1.02, n=6)])
    return pts, raios


def raiz_no_chao(base, direcao, comp, chao, fundo=1.5, raio=0.0):
    """Recua a raiz de um tentaculo pelo proprio eixo ate' ela ficar `fundo`
    m abaixo de `chao(x, z)` em toda a volta de `raio` (na parede ingreme o
    centro enterrado ainda deixa meia boca da raiz de fora), e devolve
    (raiz, comprimento + o recuo): o tentaculo que nascia no ar passa a sair
    do chao, quase do mesmo tamanho a' vista."""
    dx, dy, dz = direcao
    d = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
    dx, dy, dz = dx / d, dy / d, dz / d
    extra = 0.0
    while extra < 80.0:
        b = (base[0] - dx * extra, base[1] - dy * extra, base[2] - dz * extra)
        if b[1] < chao_sob(chao, b[0], b[2], raio) - fundo:
            return b, comp + extra
        extra += 0.5
    return b, comp + extra


def silhueta_gotica(cena, setor, mat, x, z, larg, alt, rnd, giro=0.0):
    """Igreja/torre so' de silhueta, pra horizonte: corpo, telhado de duas
    aguas e uma ou duas agulhas. Nada de detalhe: e' vista a 150 m na nevoa."""
    prof = larg * rnd.uniform(1.2, 2.4)
    pecas = [caixa_girada(x, alt * 0.5, z, larg, alt, prof, giro)]
    # telhado
    ca, sa = math.cos(giro), math.sin(giro)
    for s in (-1, 1):
        pecas.append(caixa_girada(x + ca * s * larg * 0.22, alt + larg * 0.18,
                                  z - sa * s * larg * 0.22, larg * 0.62, larg * 0.08,
                                  prof, giro, 0.0))
    torres = 1 if rnd.random() < 0.6 else 2
    for t in range(torres):
        off = (t - (torres - 1) / 2.0) * larg * 0.7
        tx, tz = x + ca * off - sa * prof * 0.45, z - sa * off - ca * prof * 0.45
        ta = alt * rnd.uniform(1.5, 2.3)
        tl = larg * rnd.uniform(0.28, 0.4)
        pecas.append(caixa_girada(tx, ta * 0.5, tz, tl, ta, tl, giro))
        pecas.append(espinho((tx, ta - 0.1, tz), (tx, ta + ta * 0.55, tz), tl * 0.62, n=4))
    cena.m.add_pecas(setor, mat, pecas)
