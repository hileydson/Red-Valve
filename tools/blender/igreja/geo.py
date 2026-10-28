"""Biblioteca de geometria do gerador da igreja.

Tudo aqui devolve (verts, faces) em coordenadas do JOGO:

    X = largura (esquerda/direita)     Y = ALTURA      Z = eixo da nave

Ou seja, Y-up, e nao Z-up como o Blender mostra no viewport. Isso e' de
proposito e casa com `export_yup=False` no export: as pecas chegam no Godot
exatamente como foram escritas aqui. Ver o cabecalho de `gerar_igreja.py`.

REGRA DA CASA: toda peca e' um SOLIDO FECHADO (caixa, prisma, cilindro). Nada
de casca aberta, nada de furo booleano. Parede com janela nao e' um retangulo
furado — e' um monte de caixas em volta do vao. Isso parece bobo mas e' o que
faz o `recalc_face_normals` do Blender acertar a orientacao de tudo sem
supervisao, e o que evita aquele buraco preto que so' aparece depois de a cena
ja' estar montada no Godot.
"""

import math
import random

# --------------------------------------------------------------------------
# acumulador


class Malhas:
    """Junta triangulos/quads em grupos (setor, material) e vira objetos depois.

    Agrupar por SETOR (fatia de Z) e nao so' por material tem um motivo
    pratico: o renderer do Godot so' aceita 8 luzes omni + 8 spot POR MALHA, e
    a igreja tem velas, tochas e feixes de janela espalhados. Uma malha unica
    de "toda a pedra" perderia luz sem avisar; quatro fatias de nave nao.
    """

    def __init__(self):
        self.grupos = {}

    def add(self, setor, material, verts, faces, uvs=None, suave=False):
        g = self.grupos.setdefault((setor, material),
                                   {"v": [], "f": [], "uv": [], "s": []})
        base = len(g["v"])
        g["v"].extend(verts)
        for i, face in enumerate(faces):
            g["f"].append([k + base for k in face])
            g["uv"].append(uvs[i] if uvs else None)
            g["s"].append(suave)

    def add_pecas(self, setor, material, pecas, **kw):
        for verts, faces in pecas:
            self.add(setor, material, verts, faces, **kw)

    def total_tris(self):
        n = 0
        for g in self.grupos.values():
            for f in g["f"]:
                n += max(len(f) - 2, 1)
        return n


# --------------------------------------------------------------------------
# primitivas

FACES_CAIXA = [
    [0, 1, 2, 3],  # baixo  (y0)
    [7, 6, 5, 4],  # cima   (y1)
    [0, 4, 5, 1],
    [1, 5, 6, 2],
    [2, 6, 7, 3],
    [3, 7, 4, 0],
]


def caixa(p0, p1):
    """Caixa alinhada aos eixos entre dois cantos."""
    x0, y0, z0 = p0
    x1, y1, z1 = p1
    if x1 < x0:
        x0, x1 = x1, x0
    if y1 < y0:
        y0, y1 = y1, y0
    if z1 < z0:
        z0, z1 = z1, z0
    v = [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1),
         (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]
    return v, [list(f) for f in FACES_CAIXA]


def hexaedro(v8):
    """Caixa de 8 vertices soltos (base 0-3 em baixo, 4-7 em cima)."""
    return list(v8), [list(f) for f in FACES_CAIXA]


def prisma_quad(a0, a1, b1, b0):
    """Prisma entre dois quads: a* e' a face de baixo, b* a de cima."""
    return hexaedro([a0, a1, b1, b0][:0] + [a0, a1, b1, b0])


def cilindro(cx, cz, raio, y0, y1, n=12, fase=0.0, raio_topo=None):
    """Cilindro/tronco de cone em pe' (eixo Y)."""
    rt = raio if raio_topo is None else raio_topo
    v = []
    for k in range(n):
        a = fase + 2 * math.pi * k / n
        v.append((cx + raio * math.cos(a), y0, cz + raio * math.sin(a)))
    for k in range(n):
        a = fase + 2 * math.pi * k / n
        v.append((cx + rt * math.cos(a), y1, cz + rt * math.sin(a)))
    faces = []
    for k in range(n):
        j = (k + 1) % n
        faces.append([k, j, n + j, n + k])
    faces.append(list(range(n - 1, -1, -1)))
    faces.append(list(range(n, 2 * n)))
    return v, faces


def caixa_girada(cx, cy, cz, sx, sy, sz, giro_y=0.0, inclina=0.0, rnd=None,
                 irregular=0.0):
    """Caixa com giro no eixo Y (e uma inclinada opcional), opcionalmente
    amassada — e' assim que nascem as pedras dos escombros."""
    hx, hy, hz = sx / 2.0, sy / 2.0, sz / 2.0
    locais = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz),
              (-hx, hy, -hz), (hx, hy, -hz), (hx, hy, hz), (-hx, hy, hz)]
    ca, sa = math.cos(giro_y), math.sin(giro_y)
    ci, si = math.cos(inclina), math.sin(inclina)
    v = []
    for (x, y, z) in locais:
        if irregular and rnd:
            x += rnd.uniform(-irregular, irregular) * hx
            y += rnd.uniform(-irregular, irregular) * hy
            z += rnd.uniform(-irregular, irregular) * hz
        # inclina no plano YZ, depois gira em Y
        y2 = y * ci - z * si
        z2 = y * si + z * ci
        x3 = x * ca + z2 * sa
        z3 = -x * sa + z2 * ca
        v.append((cx + x3, cy + y2, cz + z3))
    return hexaedro(v)


# --------------------------------------------------------------------------
# arcos


def arco_perfil(vao, flecha, n=14):
    """Perfil de arco, do arranque ao arranque.

    Tres regimes, escolhidos pela flecha pedida:
      flecha > vao/2   ogiva (dois arcos de circulo que se cruzam numa ponta)
      flecha = vao/2   volta perfeita
      flecha < vao/2   abatido/segmentar — um unico arco de circulo raso

    O terceiro caso nao e' luxo: a abobada da nave e' mais LARGA que funda, e
    o arco transversal dela tem de ser abatido pra chave bater na mesma altura
    da diagonal. Sem este ramo, `c` ficava negativo e o arco de 13 m de vao
    subia 6,5 m em vez dos 4,6 pedidos — a nave inteira saia com o pe' direito
    errado.

    Devolve [(u, altura_acima_do_arranque)], u de -vao/2 a +vao/2.
    """
    meia = vao / 2.0
    pts = []
    if flecha >= meia:
        c = (flecha * flecha - meia * meia) / (2.0 * meia)
        r = c + meia
        for i in range(n + 1):
            u = -meia + vao * i / n
            d = abs(u) + c
            pts.append((u, math.sqrt(max(r * r - d * d, 0.0))))
    else:
        r = (flecha * flecha + meia * meia) / (2.0 * flecha)
        base = r - flecha
        for i in range(n + 1):
            u = -meia + vao * i / n
            pts.append((u, math.sqrt(max(r * r - u * u, 0.0)) - base))
    return pts


def faixa_sobre_arco(uc, vao, y_arranque, flecha, y_topo, w0, w1, mapa, n=14):
    """Enche o macico de parede ACIMA de um arco, prisma vertical por prisma.

    `mapa(u, y, w)` converte (posicao ao longo do painel, altura, espessura)
    nas coordenadas do jogo — e' o que deixa a mesma funcao servir pra um
    painel no plano X e pra outro no plano Z.
    """
    perfil = arco_perfil(vao, flecha, n)
    pecas = []
    for i in range(n):
        u0, h0 = perfil[i]
        u1, h1 = perfil[i + 1]
        y0 = y_arranque + h0
        y1 = y_arranque + h1
        if min(y0, y1) >= y_topo:
            continue
        v = [mapa(uc + u0, y0, w0), mapa(uc + u1, y1, w0),
             mapa(uc + u1, y1, w1), mapa(uc + u0, y0, w1),
             mapa(uc + u0, y_topo, w0), mapa(uc + u1, y_topo, w0),
             mapa(uc + u1, y_topo, w1), mapa(uc + u0, y_topo, w1)]
        pecas.append(hexaedro(v))
    return pecas


def arquivolta(uc, vao, y_arranque, flecha, esp, w0, w1, mapa, n=14):
    """A moldura saliente que acompanha o arco (aro de pedra do intradorso)."""
    perfil = arco_perfil(vao, flecha, n)
    pecas = []
    for i in range(n):
        u0, h0 = perfil[i]
        u1, h1 = perfil[i + 1]
        y0, y1 = y_arranque + h0, y_arranque + h1
        v = [mapa(uc + u0, y0 - esp, w0), mapa(uc + u1, y1 - esp, w0),
             mapa(uc + u1, y1 - esp, w1), mapa(uc + u0, y0 - esp, w1),
             mapa(uc + u0, y0, w0), mapa(uc + u1, y1, w0),
             mapa(uc + u1, y1, w1), mapa(uc + u0, y0, w1)]
        pecas.append(hexaedro(v))
    return pecas


def painel(mapa, u0, u1, y0, y1, w0, w1, vaos, n_arco=14):
    """Painel de parede com vaos ogivais.

    `vaos` = lista de dicts:
        {"u": centro, "larg": vao, "peitoril": altura da base do vao,
         "flecha": altura da ponta acima do arranque,
         "arranque": altura onde o arco comeca (default: peitoril + reta)}

    O painel vira: macicos entre vaos, peitoril embaixo de cada vao, e o
    macico acima de cada arco. Nenhum furo — so' caixas.
    """
    pecas = []
    vaos = sorted(vaos, key=lambda d: d["u"])
    borda = u0
    for vao in vaos:
        a = vao["u"] - vao["larg"] / 2.0
        b = vao["u"] + vao["larg"] / 2.0
        if a > borda:
            pecas.append(_caixa_mapa(mapa, borda, a, y0, y1, w0, w1))
        peit = vao.get("peitoril", y0)
        if peit > y0:
            pecas.append(_caixa_mapa(mapa, a, b, y0, peit, w0, w1))
        arr = vao.get("arranque", peit + vao.get("reta", vao["larg"] * 0.9))
        if arr > peit:
            # ombreiras: nada (o vao e' aberto ate' o arranque)
            pass
        pecas.extend(faixa_sobre_arco(vao["u"], vao["larg"], arr,
                                      vao.get("flecha", vao["larg"] * 0.75),
                                      y1, w0, w1, mapa, n_arco))
        borda = b
    if borda < u1:
        pecas.append(_caixa_mapa(mapa, borda, u1, y0, y1, w0, w1))
    return pecas


def _caixa_mapa(mapa, u0, u1, y0, y1, w0, w1):
    v = [mapa(u0, y0, w0), mapa(u1, y0, w0), mapa(u1, y0, w1), mapa(u0, y0, w1),
         mapa(u0, y1, w0), mapa(u1, y1, w0), mapa(u1, y1, w1), mapa(u0, y1, w1)]
    return hexaedro(v)


def mapa_x(cx):
    """Painel no plano X = cx, correndo ao longo de Z."""
    return lambda u, y, w: (cx + w, y, u)


def mapa_z(cz):
    """Painel no plano Z = cz, correndo ao longo de X."""
    return lambda u, y, w: (u, y, cz + w)


def mapa_girado(ox, oz, ang):
    """Painel girado no plano do chao (pros panos da abside).

    u corre na direcao do painel, w e' a espessura (pra dentro/pra fora).
    """
    ca, sa = math.cos(ang), math.sin(ang)
    return lambda u, y, w: (ox + u * ca - w * sa, y, oz + u * sa + w * ca)


# --------------------------------------------------------------------------
# abobadas


def abobada_cruzaria(x0, x1, z0, z1, y_arranque, flecha, esp=0.3, n=8,
                     ogival=True, recorte_z=None, recorte_x=None):
    """Abobada de cruzaria (dois berços que se cruzam), com espessura.

    A altura em cada ponto e' o MENOR dos dois arcos — e' isso que produz as
    quatro velas e as arestas na diagonal. Com espessura porque o teto desta
    igreja tem buraco, e pelo buraco se ve' a espessura da pedra.

    `recorte_z` / `recorte_x` geram so' uma FATIA da abobada, mantendo a forma
    da abobada inteira. E' assim que se faz o rombo do teto: a pedra que sobrou
    continua exatamente na curva onde estava, e nao vira uma abobada menor.
    """
    lx, lz = x1 - x0, z1 - z0
    fx = flecha if ogival else lx / 2.0
    fz = flecha if ogival else lz / 2.0
    px = arco_perfil(lx, fx, n)
    pz = arco_perfil(lz, fz, n)

    def altura(i, j):
        return y_arranque + min(px[i][1], pz[j][1])

    def faixa(recorte, a, b):
        if not recorte:
            return 0, n
        t0 = max(0, min(n, int(round((recorte[0] - a) / (b - a) * n))))
        t1 = max(0, min(n, int(round((recorte[1] - a) / (b - a) * n))))
        return (t0, t1) if t1 > t0 else (0, n)

    i0, i1 = faixa(recorte_x, x0, x1)
    j0, j1 = faixa(recorte_z, z0, z1)

    v_baixo, v_cima = [], []
    for i in range(i0, i1 + 1):
        for j in range(j0, j1 + 1):
            x = x0 + lx * i / n
            z = z0 + lz * j / n
            y = altura(i, j)
            v_baixo.append((x, y, z))
            v_cima.append((x, y + esp, z))
    n_i = i1 - i0
    n_j = j1 - j0
    off = len(v_baixo)
    verts = v_baixo + v_cima
    faces = []
    idx = lambda i, j: i * (n_j + 1) + j
    for i in range(n_i):
        for j in range(n_j):
            a, b, c, d = idx(i, j), idx(i + 1, j), idx(i + 1, j + 1), idx(i, j + 1)
            faces.append([a, b, c, d])                       # intradorso
            faces.append([off + d, off + c, off + b, off + a])  # extradorso
    for i in range(n_i):  # bordas em Z
        a, b = idx(i, 0), idx(i + 1, 0)
        faces.append([b, a, off + a, off + b])
        a, b = idx(i, n_j), idx(i + 1, n_j)
        faces.append([a, b, off + b, off + a])
    for j in range(n_j):  # bordas em X
        a, b = idx(0, j), idx(0, j + 1)
        faces.append([a, b, off + b, off + a])
        a, b = idx(n_i, j), idx(n_i, j + 1)
        faces.append([b, a, off + a, off + b])
    return verts, faces


def nervura_diagonal(x0, x1, z0, z1, y_arranque, flecha, larg=0.34, alt=0.34,
                     n=10):
    """Nervura que acompanha uma diagonal da abobada (tubo de secao quadrada)."""
    pontos = []
    diag = math.hypot(x1 - x0, z1 - z0)
    perfil = arco_perfil(diag, flecha + 0.25, n)
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        z = z0 + (z1 - z0) * t
        pontos.append((x, y_arranque + perfil[i][1], z))
    return tubo(pontos, larg, alt)


def tubo(pontos, larg, alt):
    """Prisma de secao retangular ao longo de uma polilinha (nervura, viga,
    corrente, corrimao...). A secao fica sempre com o 'alto' em Y."""
    verts, faces = [], []
    n = len(pontos)
    for i, p in enumerate(pontos):
        if i == 0:
            dx, dz = pontos[1][0] - p[0], pontos[1][2] - p[2]
        elif i == n - 1:
            dx, dz = p[0] - pontos[-2][0], p[2] - pontos[-2][2]
        else:
            dx = pontos[i + 1][0] - pontos[i - 1][0]
            dz = pontos[i + 1][2] - pontos[i - 1][2]
        d = math.hypot(dx, dz) or 1.0
        nx, nz = -dz / d * larg / 2.0, dx / d * larg / 2.0
        x, y, z = p
        verts.extend([(x + nx, y - alt / 2, z + nz), (x - nx, y - alt / 2, z - nz),
                      (x - nx, y + alt / 2, z - nz), (x + nx, y + alt / 2, z + nz)])
    for i in range(n - 1):
        a = i * 4
        b = (i + 1) * 4
        faces.extend([[a, b, b + 1, a + 1], [a + 1, b + 1, b + 2, a + 2],
                      [a + 2, b + 2, b + 3, a + 3], [a + 3, b + 3, b, a]])
    faces.append([3, 2, 1, 0])
    m = (n - 1) * 4
    faces.append([m, m + 1, m + 2, m + 3])
    return verts, faces


def semicupula(cx, cz, raio, y_arranque, flecha, esp=0.3, nseg=9, nanel=6,
               ang0=-math.pi / 2, ang1=math.pi / 2):
    """Meia-cupula da abside: um quarto de elipse girado no arco de fora."""
    verts, faces = [], []
    idx = lambda i, j: i * (nanel + 1) + j
    baixo, cima = [], []
    for i in range(nseg + 1):
        a = ang0 + (ang1 - ang0) * i / nseg
        for j in range(nanel + 1):
            t = j / nanel
            r = raio * math.cos(t * math.pi / 2)
            y = y_arranque + flecha * math.sin(t * math.pi / 2)
            baixo.append((cx + r * math.sin(a), y, cz + r * math.cos(a)))
            cima.append((cx + (r + esp * 0.2) * math.sin(a), y + esp,
                         cz + (r + esp * 0.2) * math.cos(a)))
    off = len(baixo)
    verts = baixo + cima
    for i in range(nseg):
        for j in range(nanel):
            a, b = idx(i, j), idx(i + 1, j)
            c, d = idx(i + 1, j + 1), idx(i, j + 1)
            faces.append([a, b, c, d])
            faces.append([off + d, off + c, off + b, off + a])
    for i in range(nseg):  # borda de baixo
        a, b = idx(i, 0), idx(i + 1, 0)
        faces.append([b, a, off + a, off + b])
    return verts, faces


# --------------------------------------------------------------------------
# pecas de arquitetura


def pilar_composto(cx, cz, y0, y1, r_nucleo=0.62, r_colunete=0.20,
                   n_colunetes=8, n_lados=10):
    """Pilar gotico: nucleo poligonal + feixe de colunetas + base e capitel."""
    pecas = []
    h = y1 - y0
    base_h = 0.85
    cap_h = 0.70
    # plinto quadrado + toro
    pecas.append(caixa((cx - r_nucleo - 0.52, y0, cz - r_nucleo - 0.52),
                       (cx + r_nucleo + 0.52, y0 + 0.34, cz + r_nucleo + 0.52)))
    pecas.append(cilindro(cx, cz, r_nucleo + 0.42, y0 + 0.34, y0 + base_h,
                          n=n_lados, raio_topo=r_nucleo + 0.10))
    # fuste
    pecas.append(cilindro(cx, cz, r_nucleo, y0 + base_h, y1 - cap_h, n=n_lados))
    # colunetas encostadas
    for k in range(n_colunetes):
        a = 2 * math.pi * k / n_colunetes + math.pi / n_colunetes
        px = cx + (r_nucleo + r_colunete * 0.75) * math.cos(a)
        pz = cz + (r_nucleo + r_colunete * 0.75) * math.sin(a)
        pecas.append(cilindro(px, pz, r_colunete, y0 + base_h - 0.18,
                              y1 - cap_h + 0.10, n=6))
        # capitelzinho da coluneta
        pecas.append(cilindro(px, pz, r_colunete * 1.5, y1 - cap_h + 0.10,
                              y1 - cap_h + 0.32, n=6, raio_topo=r_colunete * 1.1))
    # capitel: tronco de cone invertido + abaco quadrado
    pecas.append(cilindro(cx, cz, r_nucleo, y1 - cap_h, y1 - 0.22,
                          n=n_lados, raio_topo=r_nucleo + 0.46))
    pecas.append(caixa((cx - r_nucleo - 0.62, y1 - 0.22, cz - r_nucleo - 0.62),
                       (cx + r_nucleo + 0.62, y1, cz + r_nucleo + 0.62)))
    return pecas, h


def coluneta(cx, cz, y0, y1, raio=0.17, n=6, capitel=True):
    pecas = [cilindro(cx, cz, raio, y0, y1 - (0.22 if capitel else 0.0), n=n)]
    if capitel:
        pecas.append(cilindro(cx, cz, raio * 1.6, y1 - 0.22, y1, n=n,
                              raio_topo=raio * 1.2))
        pecas.append(cilindro(cx, cz, raio * 1.5, y0, y0 + 0.16, n=n,
                              raio_topo=raio))
    return pecas


def escada_reta(x0, x1, z0, z1, y0, y1, n_degraus, ao_longo_z=True,
                invertido=False):
    """Lance reto. Devolve (pecas_visuais, rampa_de_colisao).

    A rampa existe porque `CharacterBody3D` no Godot sobe degrau por degrau
    aos trancos e engancha na quina quando o passo e' alto. Degrau bonito pra
    olhar, rampa lisa pra andar — e a rampa vai no objeto `-colonly`, invisivel.
    """
    pecas = []
    comp = (z1 - z0) if ao_longo_z else (x1 - x0)
    passo = comp / n_degraus
    alt = (y1 - y0) / n_degraus
    for k in range(n_degraus):
        y = y0 + alt * (k + 1)
        if ao_longo_z:
            a = z0 + passo * k if not invertido else z1 - passo * (k + 1)
            b = a + passo
            pecas.append(caixa((x0, y0 - 0.3, a), (x1, y, b)))
        else:
            a = x0 + passo * k if not invertido else x1 - passo * (k + 1)
            b = a + passo
            pecas.append(caixa((a, y0 - 0.3, z0), (b, y, z1)))
    # rampa: prisma com o topo inclinado
    if ao_longo_z:
        ya, yb = (y0, y1) if not invertido else (y1, y0)
        rampa = hexaedro([(x0, y0 - 0.4, z0), (x1, y0 - 0.4, z0),
                          (x1, y0 - 0.4, z1), (x0, y0 - 0.4, z1),
                          (x0, ya, z0), (x1, ya, z0),
                          (x1, yb, z1), (x0, yb, z1)])
    else:
        ya, yb = (y0, y1) if not invertido else (y1, y0)
        rampa = hexaedro([(x0, y0 - 0.4, z0), (x1, y0 - 0.4, z0),
                          (x1, y0 - 0.4, z1), (x0, y0 - 0.4, z1),
                          (x0, ya, z0), (x1, yb, z0),
                          (x1, yb, z1), (x0, ya, z1)])
    return pecas, rampa


def escada_caracol(cx, cz, r_int, r_ext, y0, y1, n_degraus, giro_total,
                   fase=0.0, esp=0.22):
    """Escada helicoidal aberta em volta de um poste. Visual + rampa."""
    pecas = []
    rampas = []
    alt = (y1 - y0) / n_degraus
    d_ang = giro_total / n_degraus
    for k in range(n_degraus):
        a0 = fase + d_ang * k
        a1 = a0 + d_ang * 1.02
        y = y0 + alt * (k + 1)
        p = []
        for (r, a) in ((r_int, a0), (r_ext, a0), (r_ext, a1), (r_int, a1)):
            p.append((cx + r * math.cos(a), y - esp, cz + r * math.sin(a)))
        for (r, a) in ((r_int, a0), (r_ext, a0), (r_ext, a1), (r_int, a1)):
            p.append((cx + r * math.cos(a), y, cz + r * math.sin(a)))
        pecas.append(hexaedro(p))
        # colisao: mesmo degrau, mas descendo ate' o degrau anterior (sem quina)
        q = []
        for (r, a) in ((r_int, a0), (r_ext, a0), (r_ext, a1), (r_int, a1)):
            q.append((cx + r * math.cos(a), y - alt - 0.05, cz + r * math.sin(a)))
        for (r, a, yy) in ((r_int, a0, y - alt * 0.5), (r_ext, a0, y - alt * 0.5),
                           (r_ext, a1, y), (r_int, a1, y)):
            q.append((cx + r * math.cos(a), yy, cz + r * math.sin(a)))
        rampas.append(hexaedro(q))
    return pecas, rampas


def parapeito_rendilhado(mapa, u0, u1, y0, y1, w0, w1, passo=1.15,
                         vazado=0.55, rnd=None, falhas=0.0):
    """Guarda-corpo gotico: base, montantes, arquinhos e corrimao.

    `falhas` (0..1) = chance de um trecho estar quebrado e faltando. Um
    parapeito inteirinho numa igreja arruinada denuncia o cenario montado.
    """
    pecas = []
    base_h = 0.22
    topo_h = 0.16
    pecas.append(_caixa_mapa(mapa, u0, u1, y0, y0 + base_h, w0, w1))
    n = max(int((u1 - u0) / passo), 1)
    passo_real = (u1 - u0) / n
    for k in range(n + 1):
        u = u0 + passo_real * k
        pecas.append(_caixa_mapa(mapa, u - 0.09, u + 0.09, y0 + base_h,
                                 y1 - topo_h, w0, w1))
    for k in range(n):
        uc = u0 + passo_real * (k + 0.5)
        if rnd and falhas and rnd.random() < falhas:
            continue
        # arquinho vazado: enche o quadro menos o miolo
        larg = passo_real - 0.18
        pecas.extend(faixa_sobre_arco(uc, larg, y0 + base_h + vazado * 0.62,
                                      larg * 0.62, y1 - topo_h, w0, w1, mapa, 6))
    for k in range(n):
        uc = u0 + passo_real * (k + 0.5)
        if rnd and falhas and rnd.random() < falhas * 0.8:
            continue
        pecas.append(_caixa_mapa(mapa, uc - passo_real / 2 + 0.09,
                                 uc + passo_real / 2 - 0.09,
                                 y1 - topo_h, y1, w0 - 0.06, w1 + 0.06))
    return pecas


# --------------------------------------------------------------------------
# mobilia e ruina


def banco(cx, cz, larg, prof=0.62, giro=0.0, tombado=False, quebrado=0.0,
          rnd=None):
    """Banco de igreja. Tombado = deitado de lado no chao."""
    pecas = []
    if tombado:
        # deitado: assento na vertical, encosto no chao
        pecas.append(caixa_girada(cx, 0.30, cz, larg, 0.08, 0.52, giro,
                                  math.pi / 2 * 0.92, rnd, 0.02))
        pecas.append(caixa_girada(cx, 0.14, cz + 0.34, larg, 0.07, 0.46,
                                  giro, 0.25, rnd, 0.02))
        return pecas
    l = larg
    if quebrado and rnd and rnd.random() < quebrado:
        l = larg * rnd.uniform(0.35, 0.7)
        cx += (larg - l) / 2.0 * rnd.choice((-1, 1))
    pecas.append(caixa_girada(cx, 0.45, cz, l, 0.09, prof, giro))
    pecas.append(caixa_girada(cx, 0.72, cz - prof / 2 + 0.06, l, 0.55, 0.08, giro))
    for s in (-1, 1):
        px = cx + s * (l / 2 - 0.10) * math.cos(giro)
        pz = cz - s * (l / 2 - 0.10) * math.sin(giro)
        pecas.append(caixa_girada(px, 0.22, pz, 0.10, 0.45, prof * 0.92, giro))
    return pecas


def entulho(cx, cz, raio, quantidade, rnd, y=0.0, tamanho=(0.35, 1.1),
            altura_pilha=0.0):
    """Monte de pedra caida. Pedras amassadas, giradas, empilhadas ao acaso."""
    pecas = []
    for _ in range(quantidade):
        a = rnd.uniform(0, 2 * math.pi)
        r = raio * math.sqrt(rnd.random())
        s = rnd.uniform(*tamanho)
        alto = altura_pilha * (1.0 - r / raio) if altura_pilha else 0.0
        pecas.append(caixa_girada(cx + r * math.cos(a),
                                  y + s * 0.35 + rnd.uniform(0, max(alto, 0.02)),
                                  cz + r * math.sin(a),
                                  s, s * rnd.uniform(0.45, 0.8), s * rnd.uniform(0.7, 1.3),
                                  rnd.uniform(0, math.pi), rnd.uniform(-0.4, 0.4),
                                  rnd, 0.30))
    return pecas


def domo(cx, cz, raio, altura, n=14, aneis=3):
    """Monte liso, pra COLISAO de pilha de entulho.

    A pilha bonita e' feita de pedras avulsas e amassadas; dar colisao a elas
    uma por uma produz um campo de quinas onde o jogador enrosca, escorrega e
    fica presa entre dois blocos. O corpo dele anda por cima deste monte liso
    (a inclinacao media fica por volta de 20 graus, bem abaixo do limite de
    piso do `CharacterBody3D`) e os olhos veem a pedra.
    """
    verts = [(cx, altura, cz)]
    for a in range(aneis):
        t = (a + 1) / aneis
        r = raio * t
        y = altura * (1.0 - t * t)
        for k in range(n):
            ang = 2 * math.pi * k / n
            verts.append((cx + r * math.cos(ang), y, cz + r * math.sin(ang)))
    verts.append((cx, -0.6, cz))
    base = len(verts) - 1
    faces = []
    for k in range(n):
        j = (k + 1) % n
        faces.append([0, 1 + j, 1 + k])
    for a in range(aneis - 1):
        o0 = 1 + a * n
        o1 = 1 + (a + 1) * n
        for k in range(n):
            j = (k + 1) % n
            faces.append([o0 + k, o0 + j, o1 + j, o1 + k])
    o = 1 + (aneis - 1) * n
    for k in range(n):
        j = (k + 1) % n
        faces.append([o + k, o + j, base])
    return verts, faces


def viga_caida(x0, y0, z0, x1, y1, z1, larg=0.24, alt=0.3):
    return tubo([(x0, y0, z0), (x1, y1, z1)], larg, alt)


def corrente(x, z, y0, y1, elos=None, larg=0.06):
    n = max(int((y1 - y0) / 0.5), 2)
    pontos = [(x, y0 + (y1 - y0) * i / n, z) for i in range(n + 1)]
    return tubo(pontos, larg, larg)


def candelabro(cx, cy, cz, raio=1.15, bracos=8, caido=False, giro=0.0):
    """Roda de ferro com velas. Caido = de lado no chao, amassado."""
    pecas = []
    if caido:
        # aro de pe' inclinado, meio amassado
        for k in range(bracos):
            a = 2 * math.pi * k / bracos
            a1 = 2 * math.pi * (k + 1) / bracos
            p0 = (cx + raio * math.cos(a) * math.cos(giro), cy + raio * math.sin(a) * 0.35,
                  cz + raio * math.cos(a) * math.sin(giro) + raio * math.sin(a) * 0.8)
            p1 = (cx + raio * math.cos(a1) * math.cos(giro), cy + raio * math.sin(a1) * 0.35,
                  cz + raio * math.cos(a1) * math.sin(giro) + raio * math.sin(a1) * 0.8)
            pecas.append(tubo([p0, p1], 0.09, 0.14))
        return pecas
    for k in range(bracos):
        a = 2 * math.pi * k / bracos
        a1 = 2 * math.pi * (k + 1) / bracos
        p0 = (cx + raio * math.cos(a), cy, cz + raio * math.sin(a))
        p1 = (cx + raio * math.cos(a1), cy, cz + raio * math.sin(a1))
        pecas.append(tubo([p0, p1], 0.10, 0.16))
        pecas.append(caixa((p0[0] - 0.06, cy + 0.08, p0[2] - 0.06),
                           (p0[0] + 0.06, cy + 0.34, p0[2] + 0.06)))
    return pecas


def cruz(cx, cy, cz, alt=2.4, larg=0.22, giro=0.0, inclina=0.0):
    pecas = [caixa_girada(cx, cy + alt / 2, cz, larg, alt, larg * 0.8, giro, inclina),
             caixa_girada(cx, cy + alt * 0.72, cz, alt * 0.55, larg, larg * 0.8,
                          giro, inclina)]
    return pecas
