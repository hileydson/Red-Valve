"""Etapa 02 — texturas tileáveis geradas proceduralmente.

Tudo com coordenadas em wrap (modulo o lado do tile), então a tileabilidade é
exata por construção — não aproximada como num bake de Voronoi do Blender.

Saída por material: _alb.png (albedo), _nrm.png (normal OpenGL) e _orm.png
(R=oclusao, G=rugosidade, B=metalico), 1024², empacotado como o Godot espera.
"""
import os
import sys

import numpy as np
from PIL import Image

RES = 1024
_REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                     "..", "..", "..", ".."))
OUT = os.path.join(_REPO, "red-valve", "assets", "3d_model", "city", "textures")


# ------------------------------------------------------------------ util
def srgb(a):
    a = np.clip(a, 0.0, 1.0)
    return np.where(a <= 0.0031308, a * 12.92, 1.055 * a ** (1 / 2.4) - 0.055)


def to_linear(a):
    a = np.clip(a, 0.0, 1.0)
    return np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)


def hex_rgb(h):
    """Hex sRGB -> LINEAR. Toda a mistura acontece em linear; o save
    reaplica a curva sRGB uma unica vez."""
    h = h.lstrip("#")
    return to_linear(np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]))


def grid():
    """Coordenadas UV em [0,1)."""
    t = (np.arange(RES) + 0.5) / RES
    return np.meshgrid(t, t, indexing="xy")


def wrap_delta(d):
    """Distancia toroidal: o que sai por um lado entra pelo outro."""
    return d - np.round(d)


def value_noise(U, V, cells, seed):
    """Ruido de valor com wrap exato em `cells` celulas por lado."""
    rng = np.random.default_rng(seed)
    g = rng.random((cells, cells))
    gu, gv = U * cells, V * cells
    i0, j0 = np.floor(gu).astype(int) % cells, np.floor(gv).astype(int) % cells
    i1, j1 = (i0 + 1) % cells, (j0 + 1) % cells
    fu, fv = gu - np.floor(gu), gv - np.floor(gv)
    su, sv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
    a = g[j0, i0] * (1 - su) + g[j0, i1] * su
    b = g[j1, i0] * (1 - su) + g[j1, i1] * su
    return a * (1 - sv) + b * sv


def fbm(U, V, cells, octaves, seed):
    tot = np.zeros_like(U)
    amp, norm, c = 1.0, 0.0, cells
    for o in range(octaves):
        tot += amp * value_noise(U, V, max(2, int(round(c))), seed + o * 131)
        norm += amp
        amp *= 0.5
        c *= 2
    return tot / norm


def voronoi(U, V, cells, seed, jitter=0.42):
    """Voronoi toroidal: devolve (dist ao 2o menos 1o) e id da celula."""
    rng = np.random.default_rng(seed)
    off = (rng.random((cells, cells, 2)) - 0.5) * 2.0 * jitter
    gu, gv = U * cells, V * cells
    bi, bj = np.floor(gu).astype(int), np.floor(gv).astype(int)
    d1 = np.full(U.shape, 1e9)
    d2 = np.full(U.shape, 1e9)
    cid = np.zeros(U.shape, dtype=np.int64)
    for dj in (-1, 0, 1):
        for di in (-1, 0, 1):
            ci, cj = (bi + di) % cells, (bj + dj) % cells
            px = bi + di + 0.5 + off[cj, ci, 0]
            py = bj + dj + 0.5 + off[cj, ci, 1]
            d = np.hypot(wrap_delta((gu - px) / cells) * cells,
                         wrap_delta((gv - py) / cells) * cells)
            newer = d < d1
            d2 = np.where(newer, d1, np.minimum(d2, d))
            cid = np.where(newer, cj * cells + ci, cid)
            d1 = np.where(newer, d, d1)
    return d1, d2 - d1, cid


def normal_from_height(H, strength=1.0):
    """Normal map OpenGL (+Y para cima) a partir de um heightmap com wrap."""
    dx = (np.roll(H, -1, axis=1) - np.roll(H, 1, axis=1)) * 0.5
    dy = (np.roll(H, -1, axis=0) - np.roll(H, 1, axis=0)) * 0.5
    nx, ny, nz = -dx * strength * RES / 16.0, -dy * strength * RES / 16.0, 1.0
    L = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.dstack([(nx / L) * 0.5 + 0.5, (ny / L) * 0.5 + 0.5, (nz / L) * 0.5 + 0.5])


def save(name, alb, nrm, occ, rough, metal=0.0):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((srgb(alb) * 255).astype(np.uint8)).save(
        os.path.join(OUT, name + "_alb.png"))
    Image.fromarray((np.clip(nrm, 0, 1) * 255).astype(np.uint8)).save(
        os.path.join(OUT, name + "_nrm.png"))
    m = np.full_like(occ, metal) if np.isscalar(metal) else metal
    orm = np.dstack([np.clip(occ, 0, 1), np.clip(rough, 0, 1), np.clip(m, 0, 1)])
    Image.fromarray((orm * 255).astype(np.uint8)).save(
        os.path.join(OUT, name + "_orm.png"))
    return name


# ------------------------------------------------------------ materiais
def make_cobble(name="T_cobble", cells=28, seed=7, base="#948B7C",
                joint="#6C6458", polish=0.0):
    """Paralelepipedo: domos de pedra com junta de terra escura."""
    U, V = grid()
    d1, edge, cid = voronoi(U, V, cells, seed)
    cell_w = 1.0 / cells
    j = np.clip(edge / (cell_w * 0.42), 0, 1)          # 0 na junta, 1 no miolo
    joint_m = 1.0 - j ** 0.7
    dome = np.clip(j, 0, 1) ** 0.42 * 1.05
    grain = fbm(U, V, 64, 4, seed + 91) - 0.5
    H = dome - joint_m * 0.85 + grain * 0.05
    H += (value_noise(U, V, cells, seed + 5)[..., ] - 0.5) * 0.0

    rng = np.random.default_rng(seed + 3)
    tint = rng.random(cells * cells + cells + 1)
    per = tint[cid % len(tint)]                         # variacao por pedra
    b = hex_rgb(base)[None, None, :]
    jc = hex_rgb(joint)[None, None, :]
    alb = b * (0.80 + 0.40 * per[..., None])
    alb = alb * (1 - joint_m[..., None]) + jc * joint_m[..., None]
    alb = alb * (0.92 + 0.16 * (grain[..., None] + 0.5))
    if polish:
        alb = alb * (1.0 + polish * 0.10 * j[..., None])

    occ = np.clip(0.35 + 0.65 * j, 0, 1)
    rough = np.clip(0.86 - 0.22 * j * (1 + polish) + 0.06 * grain, 0.25, 1.0)
    return save(name, alb, normal_from_height(H, 2.6), occ, rough)


def make_sidewalk(name="T_sidewalk", tiles=3, seed=21):
    """Placa de concreto trincada, com junta e mato."""
    U, V = grid()
    gu, gv = U * tiles, V * tiles
    fu, fv = gu - np.floor(gu), gv - np.floor(gv)
    du = np.minimum(fu, 1 - fu)
    dv = np.minimum(fv, 1 - fv)
    joint = np.clip(np.minimum(du, dv) / 0.035, 0, 1)
    joint_m = 1.0 - joint

    crack_n = fbm(U, V, 10, 4, seed + 17)
    crack = np.clip(1.0 - np.abs(crack_n - 0.5) / 0.022, 0, 1) ** 2
    grain = fbm(U, V, 96, 4, seed + 5) - 0.5
    stain = fbm(U, V, 6, 3, seed + 61)

    H = -joint_m * 0.5 - crack * 0.35 + grain * 0.10
    base = hex_rgb("#B2A894")[None, None, :]
    dark = hex_rgb("#7E7867")[None, None, :]
    moss = hex_rgb("#6F7350")[None, None, :]
    alb = base * (0.88 + 0.24 * (stain[..., None]))
    alb = alb * (1 - joint_m[..., None] * 0.85) + dark * joint_m[..., None] * 0.85
    alb = alb * (1 - crack[..., None] * 0.7) + dark * crack[..., None] * 0.7
    alb = alb * (1 - (joint_m * (stain > 0.62))[..., None] * 0.6) + \
        moss * (joint_m * (stain > 0.62))[..., None] * 0.6
    alb = alb * (0.94 + 0.12 * (grain[..., None] + 0.5))

    occ = np.clip(0.45 + 0.55 * joint * (1 - crack), 0, 1)
    rough = np.clip(0.90 - 0.05 * stain + 0.05 * grain, 0.5, 1.0)
    return save(name, alb, normal_from_height(H, 0.9), occ, rough)


def make_dirt(name="T_dirt", seed=33):
    """Terra batida com pedra residual e poca seca."""
    U, V = grid()
    d1, edge, cid = voronoi(U, V, 26, seed, jitter=0.48)
    stone = np.clip(1.0 - d1 / 0.016, 0, 1)
    stone *= (value_noise(U, V, 26, seed + 9) > 0.62)
    coarse = fbm(U, V, 8, 4, seed + 3)
    fine = fbm(U, V, 110, 4, seed + 44) - 0.5
    H = coarse * 0.30 + fine * 0.16 + stone * 0.45

    base = hex_rgb("#7A6A55")[None, None, :]
    pale = hex_rgb("#948B7C")[None, None, :]
    wet = hex_rgb("#574C3D")[None, None, :]
    alb = base * (0.82 + 0.36 * coarse[..., None])
    alb = alb * (1 - stone[..., None]) + pale * stone[..., None]
    poca = np.clip((coarse - 0.62) / 0.16, 0, 1)
    alb = alb * (1 - poca[..., None] * 0.55) + wet * poca[..., None] * 0.55
    alb = alb * (0.93 + 0.14 * (fine[..., None] + 0.5))

    occ = np.clip(0.55 + 0.45 * (1 - poca), 0, 1)
    rough = np.clip(0.96 - 0.18 * poca + 0.04 * fine, 0.6, 1.0)
    return save(name, alb, normal_from_height(H, 0.8), occ, rough)


def make_curb(name="T_curb", seed=55):
    """Granito do meio-fio: bloco liso, gasto, com lascas."""
    U, V = grid()
    d1, edge, cid = voronoi(U, V, 6, seed, jitter=0.18)
    j = np.clip(edge / 0.05, 0, 1)
    grain = fbm(U, V, 140, 4, seed + 2) - 0.5
    chip = np.clip(1.0 - fbm(U, V, 30, 3, seed + 77) / 0.28, 0, 1) * 0.35
    H = j * 0.35 + grain * 0.12 - chip * 0.4
    rng = np.random.default_rng(seed + 1)
    per = rng.random(64)[cid % 64]
    base = hex_rgb("#8E877A")[None, None, :]
    alb = base * (0.86 + 0.28 * per[..., None]) * (0.94 + 0.12 * (grain[..., None] + 0.5))
    alb = alb * (1 - chip[..., None] * 0.35)
    occ = np.clip(0.5 + 0.5 * j, 0, 1)
    rough = np.clip(0.74 + 0.10 * grain + 0.15 * chip, 0.4, 1.0)
    return save(name, alb, normal_from_height(H, 1.0), occ, rough)


def make_brick(name="T_brick", rows=16, seed=71):
    """Tijolo aparente em amarracao corrida, com junta de argamassa."""
    U, V = grid()
    cols = rows // 2
    gv = V * rows
    r = np.floor(gv).astype(int)
    fv = gv - r
    gu = U * cols + (r % 2) * 0.5          # amarracao: fiada alternada
    c = np.floor(gu).astype(int)
    fu = gu - np.floor(gu)

    ju = np.minimum(fu, 1 - fu) / 0.055
    jv = np.minimum(fv, 1 - fv) / 0.13
    joint = np.clip(np.minimum(ju, jv), 0, 1)
    joint_m = 1.0 - joint

    rng = np.random.default_rng(seed)
    per = rng.random(rows * cols * 4)[(r * cols + c) % (rows * cols * 4)]
    grain = fbm(U, V, 120, 4, seed + 8) - 0.5
    H = joint * 0.6 + grain * 0.10 + (per[..., ] - 0.5) * 0.10

    tijolo = hex_rgb("#8A5B45")[None, None, :]
    argamassa = hex_rgb("#9B978C")[None, None, :]
    alb = tijolo * (0.72 + 0.56 * per[..., None])
    alb = alb * (1 - joint_m[..., None]) + argamassa * joint_m[..., None]
    alb = alb * (0.92 + 0.16 * (grain[..., None] + 0.5))
    occ = np.clip(0.40 + 0.60 * joint, 0, 1)
    rough = np.clip(0.90 - 0.04 * grain, 0.6, 1.0)
    return save(name, alb, normal_from_height(H, 1.6), occ, rough)


def make_plaster(name="T_plaster", base="#C9BCA6", seed=88, descasque=0.30):
    """Caiacao suja: manchas, escorrimento, trincas e reboco descascando."""
    U, V = grid()
    mancha = fbm(U, V, 5, 4, seed)
    fino = fbm(U, V, 90, 4, seed + 12) - 0.5
    escorre = fbm(U * 8.0, V * 0.6, 12, 3, seed + 31)      # alongado na vertical
    trinca = np.clip(1.0 - np.abs(fbm(U, V, 14, 4, seed + 55) - 0.5) / 0.020, 0, 1) ** 2

    # areas onde o reboco caiu e o tijolo aparece
    solto = np.clip((fbm(U, V, 7, 3, seed + 77) - (1.0 - descasque)) / 0.10, 0, 1)

    H = -trinca * 0.5 - solto * 0.7 + fino * 0.12
    b = hex_rgb(base)[None, None, :]
    sujo = hex_rgb("#8A8378")[None, None, :]
    tijolo = hex_rgb("#8A5B45")[None, None, :]
    alb = b * (0.86 + 0.28 * mancha[..., None])
    alb = alb * (1 - escorre[..., None] * 0.35) + sujo * escorre[..., None] * 0.35
    alb = alb * (1 - trinca[..., None] * 0.55) + sujo * trinca[..., None] * 0.55
    alb = alb * (1 - solto[..., None]) + tijolo * solto[..., None]
    alb = alb * (0.94 + 0.12 * (fino[..., None] + 0.5))
    occ = np.clip(0.55 + 0.45 * (1 - trinca) * (1 - solto), 0, 1)
    rough = np.clip(0.92 - 0.05 * mancha + 0.04 * fino, 0.6, 1.0)
    return save(name, alb, normal_from_height(H, 1.1), occ, rough)


def make_wood(name="T_wood", tabuas=9, seed=104):
    """Tabua vertical envelhecida, com veio, no e folga entre pecas."""
    U, V = grid()
    gu = U * tabuas
    c = np.floor(gu).astype(int)
    fu = gu - c
    folga = np.clip(np.minimum(fu, 1 - fu) / 0.045, 0, 1)
    folga_m = 1.0 - folga

    rng = np.random.default_rng(seed)
    per = rng.random(tabuas * 3)[c % (tabuas * 3)]
    veio = fbm(U * 26.0, V * 1.2, 40, 4, seed + 6) - 0.5
    fino = fbm(U, V, 150, 3, seed + 19) - 0.5
    H = folga * 0.55 + veio * 0.22 + fino * 0.08

    b = hex_rgb("#6B5844")[None, None, :]
    esc = hex_rgb("#3A3128")[None, None, :]
    alb = b * (0.74 + 0.52 * per[..., None]) * (0.86 + 0.28 * (veio[..., None] + 0.5))
    alb = alb * (1 - folga_m[..., None] * 0.9) + esc * folga_m[..., None] * 0.9
    occ = np.clip(0.42 + 0.58 * folga, 0, 1)
    rough = np.clip(0.90 + 0.06 * veio, 0.65, 1.0)
    return save(name, alb, normal_from_height(H, 1.3), occ, rough)


def make_corrugated(name="T_metal_corr", ondas=13, seed=121):
    """Telha/chapa ondulada enferrujada."""
    U, V = grid()
    onda = np.sin(U * ondas * 2 * np.pi)
    fino = fbm(U, V, 120, 4, seed + 3) - 0.5
    rust = fbm(U, V, 9, 4, seed + 44)
    furo = np.clip((fbm(U, V, 22, 3, seed + 66) - 0.72) / 0.08, 0, 1)
    H = onda * 0.55 + fino * 0.10 - furo * 0.5

    zinco = hex_rgb("#8A8378")[None, None, :]
    ferrugem = hex_rgb("#7A5442")[None, None, :]
    escuro = hex_rgb("#5C3E30")[None, None, :]
    m = np.clip((rust - 0.34) / 0.34, 0, 1)
    alb = zinco * (1 - m[..., None]) + ferrugem * m[..., None]
    alb = alb * (1 - furo[..., None] * 0.7) + escuro * furo[..., None] * 0.7
    alb = alb * (0.90 + 0.20 * (onda[..., None] * 0.5 + 0.5))
    occ = np.clip(0.6 + 0.4 * (onda * 0.5 + 0.5), 0, 1)
    rough = np.clip(0.55 + 0.40 * m + 0.05 * fino, 0.35, 1.0)
    metal = np.clip(0.55 - 0.35 * m, 0, 1)
    return save(name, alb, normal_from_height(H, 1.9), occ, rough, metal)


def make_roof_tile(name="T_roof_tile", base="#8C5138", ondas=11, fiadas=6, seed=140):
    """Telha colonial: canais meia-cana com fiadas sobrepostas."""
    U, V = grid()
    canal = np.cos(U * ondas * 2 * np.pi)          # meia-cana ao longo do caimento
    gv = V * fiadas
    r = np.floor(gv).astype(int)
    fv = gv - r
    degrau = np.clip((fv - 0.80) / 0.20, 0, 1)     # sobreposicao entre fiadas

    rng = np.random.default_rng(seed)
    per = rng.random(ondas * fiadas * 4)[
        ((r * ondas) + np.floor(U * ondas).astype(int)) % (ondas * fiadas * 4)]
    fino = fbm(U, V, 130, 4, seed + 7) - 0.5
    limo = np.clip((fbm(U, V, 9, 4, seed + 23) - 0.58) / 0.20, 0, 1)

    H = canal * 0.42 + degrau * 0.55 + fino * 0.08

    b = hex_rgb(base)[None, None, :]
    esc = hex_rgb("#4A2E22")[None, None, :]
    musgo = hex_rgb("#6F7350")[None, None, :]
    alb = b * (0.76 + 0.48 * per[..., None])
    alb = alb * (0.82 + 0.36 * (canal[..., None] * 0.5 + 0.5))
    alb = alb * (1 - degrau[..., None] * 0.55) + esc * degrau[..., None] * 0.55
    alb = alb * (1 - limo[..., None] * 0.65) + musgo * limo[..., None] * 0.65
    alb = alb * (0.94 + 0.12 * (fino[..., None] + 0.5))

    occ = np.clip(0.45 + 0.55 * (canal * 0.5 + 0.5) * (1 - degrau), 0, 1)
    rough = np.clip(0.86 + 0.10 * limo + 0.04 * fino, 0.6, 1.0)
    return save(name, alb, normal_from_height(H, 2.2), occ, rough)


def make_ashlar(name="T_stone", base="#C4B79C", fiadas=7, seed=170, liquen=0.0):
    """Silhar aparelhado: blocos de pedra com junta funda e desgaste."""
    U, V = grid()
    cols = max(2, fiadas - 2)
    gv = V * fiadas
    r = np.floor(gv).astype(int)
    fv = gv - r
    gu = U * cols + (r % 2) * 0.5
    c = np.floor(gu).astype(int)
    fu = gu - np.floor(gu)
    ju = np.minimum(fu, 1 - fu) / 0.05
    jv = np.minimum(fv, 1 - fv) / 0.09
    joint = np.clip(np.minimum(ju, jv), 0, 1)
    joint_m = 1.0 - joint

    rng = np.random.default_rng(seed)
    per = rng.random(fiadas * cols * 4)[(r * cols + c) % (fiadas * cols * 4)]
    grao = fbm(U, V, 110, 4, seed + 9) - 0.5
    lasca = np.clip(1.0 - fbm(U, V, 26, 3, seed + 61) / 0.30, 0, 1) * 0.30
    H = joint * 0.55 + grao * 0.14 - lasca * 0.35

    b = hex_rgb(base)[None, None, :]
    esc = hex_rgb("#5E574C")[None, None, :]
    musgo = hex_rgb("#5A6146")[None, None, :]
    alb = b * (0.82 + 0.34 * per[..., None]) * (0.93 + 0.14 * (grao[..., None] + 0.5))
    alb = alb * (1 - joint_m[..., None] * 0.75) + esc * joint_m[..., None] * 0.75
    if liquen:
        m = np.clip((fbm(U, V, 11, 4, seed + 88) - (1.0 - liquen)) / 0.16, 0, 1)
        alb = alb * (1 - m[..., None] * 0.6) + musgo * m[..., None] * 0.6
    occ = np.clip(0.42 + 0.58 * joint, 0, 1)
    rough = np.clip(0.86 + 0.08 * lasca - 0.04 * grao, 0.55, 1.0)
    return save(name, alb, normal_from_height(H, 1.7), occ, rough)


def make_slate(name="T_slate", base="#5A6472", fiadas=14, seed=190):
    """Ardosia: placas retangulares sobrepostas, superficie mais lisa."""
    U, V = grid()
    cols = 9
    gv = V * fiadas
    r = np.floor(gv).astype(int)
    fv = gv - r
    gu = U * cols + (r % 2) * 0.5
    c = np.floor(gu).astype(int)
    fu = gu - np.floor(gu)
    degrau = np.clip((fv - 0.72) / 0.28, 0, 1)
    lado = np.clip(np.minimum(fu, 1 - fu) / 0.03, 0, 1)

    rng = np.random.default_rng(seed)
    per = rng.random(fiadas * cols * 3)[(r * cols + c) % (fiadas * cols * 3)]
    grao = fbm(U, V, 150, 3, seed + 4) - 0.5
    H = degrau * 0.6 + lado * 0.18 + grao * 0.07

    b = hex_rgb(base)[None, None, :]
    esc = hex_rgb("#2E353D")[None, None, :]
    alb = b * (0.80 + 0.40 * per[..., None]) * (0.94 + 0.12 * (grao[..., None] + 0.5))
    alb = alb * (1 - degrau[..., None] * 0.6) + esc * degrau[..., None] * 0.6
    occ = np.clip(0.5 + 0.5 * (1 - degrau), 0, 1)
    rough = np.clip(0.62 + 0.10 * per + 0.04 * grao, 0.4, 0.9)
    return save(name, alb, normal_from_height(H, 1.5), occ, rough)


if __name__ == "__main__":
    feitos = [
        make_cobble("T_cobble"),
        make_cobble("T_cobble_worn", cells=28, seed=7, base="#A69C8B",
                    joint="#77705F", polish=1.0),
        make_sidewalk(),
        make_dirt(),
        make_curb(),
        make_brick(),
        make_plaster("T_plaster", base="#C9BCA6", descasque=0.30),
        make_plaster("T_plaster_raw", base="#A89880", seed=203, descasque=0.16),
        make_wood(),
        make_corrugated(),
        make_roof_tile("T_roof_tile", base="#8C5138"),
        make_roof_tile("T_roof_tile_warm", base="#A8613F", seed=311),
        make_roof_tile("T_roof_tile_pale", base="#9A7A66", seed=402),
        make_plaster("T_plaster_red", base="#7E3A32", seed=511, descasque=0.34),
        make_plaster("T_plaster_ochre", base="#9C7A45", seed=622, descasque=0.26),
        make_ashlar("T_stone_church", base="#C4B79C", fiadas=7, liquen=0.14),
        make_ashlar("T_stone_cemetery", base="#9B978C", fiadas=6, seed=250, liquen=0.34),
        make_slate(),
    ]
    print("gerados em", OUT)
    for n in feitos:
        print("  ", n, "-> _alb / _nrm / _orm")
