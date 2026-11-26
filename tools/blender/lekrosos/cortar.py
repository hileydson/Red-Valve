# -*- coding: utf-8 -*-
"""Desmembramento do Lekroso: pecas, crateras, cotos e as pecas soltas que
caem no chao.

    blender -b Red-Valve-Blender/lekrosos/lekroso_1.blend \
        -P tools/blender/lekrosos/cortar.py -- lekroso_1

Le' o .blend do `montar_lekroso.py` (malha + rig + pesos) e salva
`Red-Valve-Blender/lekrosos/lekroso_1_cortado.blend`, que o `animar.py` abre.
Escreve tambem `red-valve/scripts/enemies/lekrosos/lekroso_1_dados.gd` (a
tabela das pecas que o jogo le').

COMO UMA PECA SOME SEM CORTAR MALHA EM TEMPO DE JOGO
----------------------------------------------------
A malha continua UMA so' (um draw call por material), e cada peca removivel
e' uma ilha de faces separada do resto (as arestas da borda sao abertas, os
vertices duplicados). Os vertices da ilha nao pesam mais nos ossos do corpo,
e sim em OSSOS-SOMBRA: `pk_<peca>_<osso>`, filho do osso original e com o
mesmo repouso dele. Enquanto a peca esta' no corpo o osso-sombra nao faz
nada (repouso = o do pai), entao ela deforma EXATAMENTE como antes. Pra
arrancar, o jogo zera a escala dos ossos-sombra daquela peca (um
SkeletonModifier3D, depois da animacao): a ilha encolhe pra dentro do corpo
e some.

Por que nao esconder por shader: o amuleto troca o material de toda malha do
inimigo (`Realidade.disfarcar`), e o pedaco arrancado voltaria. Por que nao
um osso rigido por peca: os pesos da ilha deixariam de ser os do vizinho e a
emenda abriria fresta na animacao.

O QUE APARECE QUANDO A PECA SAI
-------------------------------
- Pedaco (cabeca, tronco, cintura, pernas): uma CRATERA de carne (paredes +
  fundo) ja' existe embaixo de cada pedaco, pesada nos ossos do corpo. Com o
  pedaco no lugar ela fica encoberta; sem ele, e' o buraco.
- Membro (braco, antebraco, mao): um DISCO DE CORTE (osso, tutano, gordura,
  musculo) na junta, dentro do membro enquanto ele esta' inteiro, pesado como
  o anel da junta. Fica no coto.

AS PECAS QUE CAEM
-----------------
Malhas estaticas, no espaco de repouso do esqueleto, dentro de um vazio
"pecas": `peca_<nome>` (a casca + a carne embaixo, fechada; nos membros, com
o disco de corte da ponta de cima) e `corte_<nome>` (o disco que fica no
coto — vai junto quando o membro de cima tambem cai depois). O jogo copia a
malha e poe na pose de agora pelo osso principal da peca.
"""

import json
import math
import os
import random
import sys
from collections import defaultdict

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
BLENDS = os.path.join(os.path.dirname(RAIZ), "Red-Valve-Blender", "lekrosos")
DADOS_GD = os.path.join(RAIZ, "red-valve/scripts/enemies/lekrosos")


def D(esq, frente, cima):
    """Direcao no espaco do personagem -> mundo do Blender (+X esq, -Y frente)."""
    return Vector((esq, -frente, cima)).normalized()


# ------------------------------------------------------------------ membros
# nome: (ossos que pertencem a ele, membro pai, osso principal)
MEMBROS = {}
for _l, _s in (("L", "l"), ("R", "r")):
    MEMBROS["braco_" + _s] = ({"upper_arm." + _l}, None, "upper_arm." + _l)
    MEMBROS["antebraco_" + _s] = ({"forearm." + _l}, "braco_" + _s, "forearm." + _l)
    MEMBROS["mao_" + _s] = ({"hand." + _l, "fingers." + _l, "thumb." + _l},
                            "antebraco_" + _s, "hand." + _l)

# ------------------------------------------------------------------ pedacos
# (nome, zona, osso do eixo, t no osso, direcao pra fora, raio, profundidade,
#  ossos de onde as faces podem sair)
TRONCO_ALTO = {"chest", "upper_chest", "shoulder.L", "shoulder.R"}
PEDACOS = [
    # a cabeca afunda mais que a pele: o cabelo e' casca solta, e uma tigela
    # rasa aparecia entre as mechas com a cabeca inteira
    ("cabeca_rosto_l", "cabeca", "head", 0.32, D(0.65, 0.75, 0.05), 0.050, 0.028, {"head"}),
    ("cabeca_rosto_r", "cabeca", "head", 0.32, D(-0.65, 0.75, 0.05), 0.050, 0.028, {"head"}),
    ("cabeca_nuca", "cabeca", "head", 0.30, D(0.0, -1.0, 0.15), 0.060, 0.034, {"head"}),
    ("cabeca_topo", "cabeca", "head", 0.78, D(0.25, -0.25, 1.0), 0.058, 0.034, {"head"}),
    ("peito_l", "tronco", "upper_chest", 0.25, D(0.45, 1.0, 0.0), 0.085, 0.040, TRONCO_ALTO),
    ("peito_r", "tronco", "upper_chest", 0.25, D(-0.45, 1.0, 0.0), 0.085, 0.040, TRONCO_ALTO),
    ("costas_l", "tronco", "upper_chest", 0.35, D(0.45, -1.0, 0.0), 0.090, 0.040, TRONCO_ALTO),
    ("costas_r", "tronco", "upper_chest", 0.35, D(-0.45, -1.0, 0.0), 0.090, 0.040, TRONCO_ALTO),
    ("ombro_l", "tronco", "shoulder.L", 0.65, D(0.25, 0.1, 1.0), 0.065, 0.030,
     {"shoulder.L", "upper_chest"}),
    ("ombro_r", "tronco", "shoulder.R", 0.65, D(-0.25, 0.1, 1.0), 0.065, 0.030,
     {"shoulder.R", "upper_chest"}),
    ("barriga", "tronco", "spine", 0.55, D(0.0, 1.0, 0.0), 0.085, 0.040, {"spine", "chest"}),
    ("lombar", "tronco", "spine", 0.55, D(0.0, -1.0, 0.0), 0.085, 0.040, {"spine", "chest"}),
    # o lado do quadril pesa mais na coxa do que no osso do quadril
    ("quadril_l", "cintura", "hips", 0.15, D(0.85, 0.45, 0.0), 0.075, 0.035,
     {"hips", "spine", "thigh.L"}),
    ("quadril_r", "cintura", "hips", 0.15, D(-0.85, 0.45, 0.0), 0.075, 0.035,
     {"hips", "spine", "thigh.R"}),
    ("nadega_l", "cintura", "hips", 0.0, D(0.45, -1.0, -0.35), 0.078, 0.035,
     {"hips", "thigh.L"}),
    ("nadega_r", "cintura", "hips", 0.0, D(-0.45, -1.0, -0.35), 0.078, 0.035,
     {"hips", "thigh.R"}),
]
for _l, _s, _x in (("L", "l", 1.0), ("R", "r", -1.0)):
    PEDACOS += [
        # raios maiores que os do tronco: a perna decimada tem triangulos de
        # 3 cm, e um raio de 6 cm pegava meia duzia deles
        ("coxa_%s_frente" % _s, "coxa_" + _s, "thigh." + _l, 0.40, D(0.1 * _x, 1.0, 0.0),
         0.080, 0.030, {"thigh." + _l}),
        ("coxa_%s_tras" % _s, "coxa_" + _s, "thigh." + _l, 0.55, D(0.0, -1.0, 0.0),
         0.078, 0.030, {"thigh." + _l}),
        ("coxa_%s_fora" % _s, "coxa_" + _s, "thigh." + _l, 0.30, D(_x, 0.0, 0.0),
         0.078, 0.028, {"thigh." + _l}),
        ("canela_%s_frente" % _s, "canela_" + _s, "shin." + _l, 0.35, D(0.0, 1.0, 0.0),
         0.062, 0.020, {"shin." + _l}),
        ("panturrilha_" + _s, "canela_" + _s, "shin." + _l, 0.30, D(0.0, -1.0, 0.0),
         0.066, 0.024, {"shin." + _l}),
    ]

# Indices de material na malha do corpo
MAT_PELE, MAT_CARNE, MAT_CORTE = 0, 1, 2


# ================================================================ texturas

def _ruido(tam, celulas, semente):
    """Ruido de valor que fecha nas bordas (tileavel), entre 0 e 1."""
    rng = np.random.default_rng(semente)
    g = rng.random((celulas, celulas))
    xs = np.arange(tam) * celulas / tam
    i0 = np.floor(xs).astype(int) % celulas
    i1 = (i0 + 1) % celulas
    f = xs - np.floor(xs)
    f = f * f * (3 - 2 * f)
    a = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
    b = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
    return a * (1 - f)[:, None] + b * f[:, None]


def _fbm(tam, semente, oitavas=5, base=4):
    soma = np.zeros((tam, tam))
    amp, total = 1.0, 0.0
    for o in range(oitavas):
        soma += _ruido(tam, base * (2 ** o), semente + o * 17) * amp
        total += amp
        amp *= 0.5
    return soma / total


def _salvar_png(nome, rgb):
    tam = rgb.shape[0]
    img = bpy.data.images.get(nome)
    if img:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(nome, tam, tam, alpha=False)
    rgba = np.ones((tam, tam, 4), dtype=np.float32)
    # o Blender guarda de baixo pra cima
    rgba[:, :, :3] = np.clip(rgb[::-1], 0, 1)
    img.pixels.foreach_set(rgba.ravel())
    caminho = os.path.join(BLENDS, nome + ".png")
    img.filepath_raw = caminho
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img


def textura_carne():
    """Carne viva, molhada: vermelho escuro com coagulo e fibra clara."""
    t = 256
    n = _fbm(t, 11)
    fibra = _fbm(t, 29, oitavas=3, base=16)
    coag = np.clip((_fbm(t, 47, oitavas=4, base=3) - 0.52) * 4.0, 0, 1)
    base = np.array([0.36, 0.035, 0.04])
    claro = np.array([0.62, 0.16, 0.14])
    escuro = np.array([0.12, 0.008, 0.012])
    k = np.clip((n - 0.35) * 1.6, 0, 1)[..., None]
    rgb = base * (1 - k) + claro * k
    rgb = rgb * (0.8 + 0.4 * fibra[..., None])
    rgb = rgb * (1 - coag[..., None]) + escuro * coag[..., None]
    return _salvar_png("lekroso_carne", rgb)


def textura_corte():
    """O corte de um membro, de dentro pra fora: tutano, osso, musculo,
    gordura e a pele na borda. Mapeado num disco (centro = 0,5)."""
    t = 256
    y, x = np.mgrid[0:t, 0:t]
    dx = (x - t / 2 + 0.5) / (t / 2)
    dy = (y - t / 2 + 0.5) / (t / 2)
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    n = _fbm(t, 5)
    torto = 0.04 * np.sin(ang * 5 + 1.3) + 0.03 * np.sin(ang * 9 + 0.4) + (n - 0.5) * 0.06
    rr = r + torto
    musculo = np.array([0.48, 0.05, 0.05])
    musculo_escuro = np.array([0.22, 0.01, 0.015])
    fibra = 0.5 + 0.5 * np.sin(ang * 60 + n * 8)
    k = np.clip(_fbm(t, 61, base=6) * 1.4 - 0.2, 0, 1)
    rgb = musculo[None, None] * (0.75 + 0.35 * fibra[..., None])
    rgb = rgb * (1 - k[..., None] * 0.6) + musculo_escuro * (k[..., None] * 0.6)
    osso = np.array([0.86, 0.80, 0.66])
    tutano = np.array([0.30, 0.03, 0.03])
    gordura = np.array([0.86, 0.68, 0.34])
    pele = np.array([0.42, 0.26, 0.22])
    # o osso sai um pouco do centro (o umero nao e' o eixo do braco)
    ox, oy = dx - 0.08, dy + 0.05
    ro = np.sqrt(ox * ox + oy * oy) + (n - 0.5) * 0.03
    m_osso = ro < 0.19
    m_tut = ro < 0.09
    m_gord = (rr > 0.80) & (rr < 0.91)
    m_pele = rr >= 0.91
    rgb[m_gord] = gordura * (0.85 + 0.3 * n[m_gord, None])
    rgb[m_pele] = pele * (0.8 + 0.4 * n[m_pele, None])
    rgb[m_osso] = osso * (0.85 + 0.25 * n[m_osso, None])
    rgb[m_tut] = tutano * (0.8 + 0.4 * n[m_tut, None])
    return _salvar_png("lekroso_corte", rgb)


def material(nome, imagem, rugosidade):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    m.use_backface_culling = False
    nt = m.node_tree
    nt.nodes.clear()
    saida = nt.nodes.new("ShaderNodeOutputMaterial")
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = imagem
    nt.links.new(tex.outputs["Color"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = rugosidade
    nt.links.new(p.outputs["BSDF"], saida.inputs["Surface"])
    return m


# ================================================================ geometria

def _base_ortogonal(n):
    ref = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    b1 = n.cross(ref).normalized()
    return b1, n.cross(b1).normalized()


def _ruido_borda(semente):
    rnd = random.Random(semente)
    fases = [rnd.uniform(0, math.tau) for _ in range(4)]

    # Rasgado, mas de carne: com amplitudes maiores a borda virava estrela
    # (folha de bordo recortada em papel vermelho, no jogo).
    def f(theta):
        return (0.11 * math.sin(3 * theta + fases[0]) + 0.07 * math.sin(5 * theta + fases[1])
                + 0.05 * math.sin(7 * theta + fases[2]) + 0.03 * math.sin(11 * theta + fases[3]))
    return f


class Corte:
    def __init__(self, malha, arm):
        self.malha = malha
        self.arm = arm
        self.bm = bmesh.new()
        self.bm.from_mesh(malha.data)
        # A camada da parte nasce AQUI: criar camada depois invalida as faces
        # que ja' viraram chave de dicionario.
        self.camada = self.bm.faces.layers.int.new("parte")
        self.bm.verts.ensure_lookup_table()
        self.bm.faces.ensure_lookup_table()
        self.dl = self.bm.verts.layers.deform.verify()
        self.uv = self.bm.loops.layers.uv.active
        self.gi = {g.index: g.name for g in malha.vertex_groups}
        self.ig = {g.name: g.index for g in malha.vertex_groups}
        self.parte = {}          # face -> nome da parte ("" = corpo)
        self.osso_dom = {}       # face -> osso dominante
        self.info = {}           # parte -> dados exportados
        self.pecas_bm = {}       # nome do objeto -> bmesh solto
        self.osso_membro = {}
        for nome, (ossos, _, _) in MEMBROS.items():
            for o in ossos:
                self.osso_membro[o] = nome

    # ---------------------------------------------------------- leitura
    def pesos(self, v):
        return {self.gi[k]: w for k, w in v[self.dl].items() if w > 1e-5}

    def classificar(self):
        for f in self.bm.faces:
            acc = defaultdict(float)
            for v in f.verts:
                for g, w in v[self.dl].items():
                    acc[g] += w
            dom = self.gi[max(acc, key=acc.get)] if acc else "hips"
            self.osso_dom[f] = dom
            self.parte[f] = self.osso_membro.get(dom, "")

    def _osso(self, nome):
        return self.arm.data.bones[nome]

    # ---------------------------------------------------------- pedacos
    def escolher_pedacos(self):
        corpo = [f for f in self.bm.faces if self.parte[f] == ""]
        cos = [v.co.copy() for v in self.bm.verts]
        polys = [[v.index for v in f.verts] for f in corpo]
        bvh = BVHTree.FromPolygons(cos, polys)
        centros = {f: f.calc_center_median() for f in corpo}
        for i, (nome, zona, osso, t, n, raio, prof, ossos) in enumerate(PEDACOS):
            b = self._osso(osso)
            eixo = b.head_local + (b.tail_local - b.head_local) * t
            hit = bvh.ray_cast(eixo + n * 0.8, -n, 0.8)
            if hit[0] is None:
                print("  !! %s: o raio nao achou a pele" % nome)
                continue
            h = hit[0]
            b1, b2 = _base_ortogonal(n)
            borda = _ruido_borda(1000 + i * 7)

            def dentro(p):
                rel = p - h
                fundo = rel.dot(n)
                if fundo < -prof * 1.8 or fundo > 0.07:
                    return False
                tang = rel - n * fundo
                theta = math.atan2(tang.dot(b2), tang.dot(b1))
                return tang.length < raio * (1.0 + borda(theta))

            # Por VERTICE (2 de 3 dentro), e nao pelo centro da face: o
            # centro faz a borda em dente de serra nos triangulos grandes da
            # malha decimada.
            cand = set()
            for f in corpo:
                if self.parte[f] != "" or self.osso_dom[f] not in ossos:
                    continue
                if sum(1 for v in f.verts if dentro(v.co)) >= 2:
                    cand.add(f)
            faces = self._suavizar_selecao(cand, ossos)
            if len(faces) < 12:
                print("  !! %s: so' %d faces, ficou de fora" % (nome, len(faces)))
                continue
            for f in faces:
                self.parte[f] = nome
            self.info[nome] = {"tipo": "pedaco", "zona": zona, "osso": osso,
                               "normal": n, "pele": h, "raio": raio, "prof": prof,
                               "faces": len(faces)}

    def _vizinhos(self):
        """Vizinhanca de faces pela posicao dos vertices, e nao pelo indice:
        o scan vem retalhado nas costuras de UV (o vertice e' duplicado ali),
        e a vizinhanca do bmesh acharia ilha onde a pele e' continua."""
        if getattr(self, "_viz", None) is not None:
            return self._viz
        chave = {v: (round(v.co.x * 5000), round(v.co.y * 5000), round(v.co.z * 5000))
                 for v in self.bm.verts}
        arestas = defaultdict(list)
        for f in self.bm.faces:
            ks = [chave[v] for v in f.verts]
            for i in range(len(ks)):
                a, b = ks[i], ks[(i + 1) % len(ks)]
                arestas[(min(a, b), max(a, b))].append(f)
        viz = defaultdict(set)
        for fs in arestas.values():
            for a in fs:
                for b in fs:
                    if a is not b:
                        viz[a].add(b)
        self._viz = viz
        return viz

    def _suavizar_selecao(self, cand, ossos):
        """Tira as pontas soltas e fecha os dentes da borda (duas passadas)."""
        viz = self._vizinhos()
        sel = set(cand)
        for _ in range(2):
            sel = {f for f in sel if sum(1 for g in viz[f] if g in sel) >= 2}
            novas = set()
            for f in sel:
                for g in viz[f]:
                    if g in sel or self.parte[g] != "" or self.osso_dom[g] not in ossos:
                        continue
                    if sum(1 for k in viz[g] if k in sel) >= 2:
                        novas.add(g)
            sel |= novas
        return list(sel)

    # ---------------------------------------------------------- aneis
    def aneis_dos_membros(self):
        """Antes de separar: o anel de cada junta (vertices na fronteira entre
        o membro e quem esta' acima dele)."""
        for nome, (_, pai, osso) in MEMBROS.items():
            anel = {}
            for e in self.bm.edges:
                if len(e.link_faces) != 2:
                    continue
                a, b = e.link_faces
                pa, pb = self.parte[a], self.parte[b]
                if nome not in (pa, pb) or pa == pb:
                    continue
                outro = pb if pa == nome else pa
                acima = (outro == pai) if pai else (outro not in MEMBROS)
                if not acima:
                    continue
                for v in e.verts:
                    anel[v.index] = (v.co.copy(), self.pesos(v))
            self.info[nome] = {"tipo": "membro", "zona": nome, "osso": osso, "pai": pai,
                               "anel": list(anel.values()),
                               "faces": sum(1 for f in self.bm.faces if self.parte[f] == nome)}

    # ---------------------------------------------------------- separar
    def separar(self):
        corte = [e for e in self.bm.edges if len(e.link_faces) == 2
                 and self.parte[e.link_faces[0]] != self.parte[e.link_faces[1]]]
        camada = self.camada
        nomes = [""] + list(self.info.keys())
        idx = {n: i for i, n in enumerate(nomes)}
        for f in self.bm.faces:
            f[camada] = idx.get(self.parte[f], 0)
        bmesh.ops.split_edges(self.bm, edges=corte)
        self.bm.verts.ensure_lookup_table()
        self.bm.faces.ensure_lookup_table()
        self.parte = {f: nomes[f[camada]] for f in self.bm.faces}
        # confere: nenhum vertice pode ficar entre duas partes
        misto = 0
        for v in self.bm.verts:
            ps = {self.parte[f] for f in v.link_faces}
            if len(ps) > 1:
                misto += 1
        print("  separado: %d arestas cortadas, %d vertices mistos" % (len(corte), misto))

    # ---------------------------------------------------------- crateras
    def crateras(self):
        # A pele por onde os raios da tigela descem: corpo e pedacos (os
        # membros ficam de fora — a mao pendurada ao lado do quadril seria
        # confundida com a pele dele).
        base = [f for f in self.bm.faces if self.parte[f] not in MEMBROS]
        cos = [v.co.copy() for v in self.bm.verts]
        bvh = BVHTree.FromPolygons(cos, [[v.index for v in f.verts] for f in base])
        # a mesma pele, pro teste de "esta' escondido" (sem os membros: o
        # braco do lado tamparia um ponto que esta' fora do tronco)
        pele = bvh
        kd = KDTree(len(self.bm.verts))
        for v in self.bm.verts:
            kd.insert(v.co, v.index)
        kd.balance()
        pesos_de = [self.pesos(v) for v in self.bm.verts]

        for i, (nome, inf) in enumerate(list(self.info.items())):
            if inf["tipo"] != "pedaco":
                continue
            faces = [f for f in self.bm.faces if self.parte[f] == nome]
            n = inf["normal"]
            b1, b2 = _base_ortogonal(n)
            h = inf["pele"]
            prof = inf["prof"]
            raio = inf["raio"]
            borda = _ruido_borda(1000 + [p[0] for p in PEDACOS].index(nome) * 7)
            verts = {v for f in faces for v in f.verts}

            # 1) no corpo: a TIGELA. Uma grade polar no plano da ferida; cada
            # ponto desce por raio ate' a camada mais FUNDA da pele (a de baixo
            # do colete, o couro debaixo do cabelo) e afunda dali. Assim a
            # borda fica sempre por baixo da pele: com o pedaco no lugar
            # nada aparece, e sem ele o buraco inteiro tem fundo.
            # Afundar e' andar na direcao do EIXO do osso (que esta' sempre
            # dentro do corpo), nao no -n do plano: numa cabeca ou canela o
            # -n de um ponto da borda sai pela lateral.
            ob = self._osso(inf["osso"])
            e0, e1 = ob.head_local, ob.tail_local

            def no_eixo(p):
                d = e1 - e0
                t = max(0.0, min(1.0, (p - e0).dot(d) / max(d.length_squared, 1e-9)))
                return e0 + d * t

            janela = prof * (2.2 if inf["zona"] == "cabeca" else 1.5)
            aneis, gomos = 5, 22
            grade = [[None] * gomos for _ in range(aneis + 1)]
            ultimo = [None] * gomos
            vazou = 0
            for a in range(aneis + 1):
                k = a / aneis
                for g in range(gomos):
                    th = math.tau * g / gomos
                    r = raio * (1.0 + borda(th)) * 1.18 * k
                    p = h + (b1 * math.cos(th) + b2 * math.sin(th)) * r
                    funda = self._mais_funda(bvh, p, n, janela)
                    if funda is None:
                        funda = ultimo[g] if ultimo[g] is not None else no_eixo(p).lerp(p, 0.5)
                    ultimo[g] = funda
                    ax = no_eixo(funda)
                    rumo = ax - funda
                    fundo = prof * (0.28 + 0.72 * (1.0 - k * k))
                    q = funda + rumo.normalized() * min(fundo, rumo.length * 0.7)
                    # E tem de estar ESCONDIDO com o pedaco no lugar: seis
                    # raios, todos batendo na pele. Escapou um, puxa pro eixo.
                    for _ in range(6):
                        if self._escondido(pele, q, n):
                            break
                        q = q.lerp(ax, 0.3)
                        vazou += 1
                    grade[a][g] = q
            # O vertice escondido nao basta: o triangulo entre dois deles
            # atravessa o buraco do olho e a linha da mandibula. Confere o
            # meio de cada face e de cada aresta; o que aparece puxa os cantos.
            eixo_de = {}
            for _ in range(5):
                puxar = set()
                for a in range(aneis):
                    for g in range(gomos):
                        g2 = (g + 1) % gomos
                        cantos = [(a, g), (a + 1, g), (a + 1, g2), (a, g2)]
                        pts = [grade[x][y] for x, y in cantos]
                        testes = [sum(pts, Vector()) / 4] + \
                            [(pts[i] + pts[(i + 1) % 4]) * 0.5 for i in range(4)]
                        if not all(self._escondido(pele, t, n) for t in testes):
                            puxar.update(cantos)
                if not puxar:
                    break
                for x, y in puxar:
                    q = grade[x][y]
                    ax = eixo_de.setdefault((x, y), no_eixo(q))
                    grade[x][y] = q.lerp(ax, 0.25)
                    vazou += 1
            if vazou:
                print("  %s: %d pontos da tigela puxados pra dentro" % (nome, vazou))
            novos = [[None] * gomos for _ in range(aneis + 1)]
            for a in range(aneis + 1):
                for g in range(gomos if a else 1):
                    co = grade[a][g]
                    if a == 0:
                        co = sum((grade[0][x] for x in range(gomos)), Vector()) / gomos
                    nv = self.bm.verts.new(co)
                    _, idx, _ = kd.find(co)
                    for gn, w in pesos_de[idx].items():
                        nv[self.dl][self.ig[gn]] = w
                    novos[a][g] = nv
            for g in range(gomos):
                novos[0][g] = novos[0][0]

            def uv_plano(p):
                rel = p - h
                return (0.5 + rel.dot(b1) * 4.0, 0.5 + rel.dot(b2) * 4.0)

            criadas = []
            for a in range(aneis):
                for g in range(gomos):
                    g2 = (g + 1) % gomos
                    if a == 0:
                        quad = [novos[0][0], novos[1][g], novos[1][g2]]
                    else:
                        quad = [novos[a][g], novos[a + 1][g], novos[a + 1][g2], novos[a][g2]]
                    criadas.append(self.bm.faces.new(quad))
            # As PAREDES: da beira do buraco (a pele que fica) ate' dentro. Sem
            # elas, onde a tigela teve de ser puxada pro eixo sobrava um vao
            # entre a beira e o fundo, e pelo buraco do peito se via o
            # interior do tronco (com o disco do ombro la' dentro).
            bordas = [e for e in {e for f in faces for e in f.edges}
                      if sum(1 for lf in e.link_faces if self.parte[lf] == nome) == 1]
            topo, baixo = {}, {}

            def parede(v):
                if v in topo:
                    return
                ax = no_eixo(v.co)
                rumo = ax - v.co
                # o topo 2 mm pra dentro: rente a' pele, a parede aparecia
                # de raspao nas curvas com o pedaco ainda no lugar
                t = self.bm.verts.new(v.co + rumo.normalized() * min(0.002, rumo.length * 0.1))
                for gn, w in v[self.dl].items():
                    t[self.dl][gn] = w
                q = v.co + rumo.normalized() * min(prof * 0.9, rumo.length * 0.6)
                for _ in range(6):
                    if self._escondido(pele, q, n):
                        break
                    q = q.lerp(ax, 0.3)
                b = self.bm.verts.new(q)
                for gn, w in v[self.dl].items():
                    b[self.dl][gn] = w
                topo[v], baixo[v] = t, b

            for e in bordas:
                f = next(lf for lf in e.link_faces if self.parte[lf] == nome)
                for lp in f.loops:
                    if lp.edge == e:
                        a, b = lp.vert, lp.link_loop_next.vert
                        break
                parede(a)
                parede(b)
                try:
                    criadas.append(self.bm.faces.new([topo[a], topo[b], baixo[b], baixo[a]]))
                except ValueError:
                    pass

            # a frente da tigela olha pra fora (pra quem ve' o buraco)
            for nf in criadas:
                nf.normal_update()
                if nf.normal.dot(n) < 0:
                    nf.normal_flip()
                nf.material_index = MAT_CARNE
                nf.smooth = True
                self.parte[nf] = ""
                for lp in nf.loops:
                    lp[self.uv].uv = uv_plano(lp.vert.co)

            # 2) a peca solta: a casca + uma lasca de carne embaixo, fechada.
            # Aqui a carne sai da PROPRIA posicao de cada vertice (afundada e
            # puxada pro meio): a peca e' vista de todos os lados, rolando no
            # chao, e tem de ter grossura de carne de verdade.
            fundo = {}
            for v in verts:
                rel = v.co - h
                tang = rel - n * rel.dot(n)
                k = min(tang.length / (raio * 1.25), 1.0)
                fundo[v] = v.co - tang * 0.15 - n * prof * (0.40 + 0.60 * (1.0 - k * k))
            bordas = [e for e in {e for f in faces for e in f.edges}
                      if sum(1 for lf in e.link_faces if self.parte[lf] == nome) == 1]
            pb = bmesh.new()
            uv = pb.loops.layers.uv.new("UVMap")
            mapa, mapa_f = {}, {}
            for v in verts:
                mapa[v] = pb.verts.new(v.co.copy())
                mapa_f[v] = pb.verts.new(fundo[v])
            for f in faces:
                try:
                    nf = pb.faces.new([mapa[v] for v in f.verts])
                    nf.material_index = MAT_PELE
                    nf.smooth = True
                    for lo, ld in zip(f.loops, nf.loops):
                        ld[uv].uv = lo[self.uv].uv
                except ValueError:
                    pass
                try:
                    nf = pb.faces.new([mapa_f[v] for v in reversed(f.verts)])
                    nf.material_index = MAT_CARNE
                    nf.smooth = True
                    for ld in nf.loops:
                        ld[uv].uv = uv_plano(ld.vert.co)
                except ValueError:
                    pass
            for e in bordas:
                f = next(lf for lf in e.link_faces if self.parte[lf] == nome)
                for lp in f.loops:
                    if lp.edge == e:
                        a, b = lp.vert, lp.link_loop_next.vert
                        break
                try:
                    nf = pb.faces.new([mapa[b], mapa[a], mapa_f[a], mapa_f[b]])
                    nf.material_index = MAT_CARNE
                    for ld in nf.loops:
                        ld[uv].uv = uv_plano(ld.vert.co)
                except ValueError:
                    pass
            self.pecas_bm["peca_" + nome] = pb
            centro = sum((v.co for v in verts), Vector()) / max(len(verts), 1)
            inf["centro"] = centro
            inf["massa"] = len(faces)

    @staticmethod
    def _escondido(bvh, p, n):
        """Alguem de fora ve' este ponto? Um leque de raios em volta da normal
        da ferida (de onde se olha pra ela) — todos tem de bater na pele.
        Raio pra tras nao conta: ele anda por dentro do tubo da perna e sai
        pelo buraco do ombro, que nao tem nada a ver com ser visto."""
        b1, b2 = _base_ortogonal(n)
        dirs = [n]
        # tres aneis de 6: o cabelo e' cheio de fresta, e 9 raios passavam
        # por ela sem achar o buraco
        for anel, (inc, gomos) in enumerate(((0.35, 6), (0.8, 6), (1.25, 6))):
            for a in range(gomos):
                ang = math.tau * a / gomos + anel * 0.5
                lado = b1 * math.cos(ang) + b2 * math.sin(ang)
                dirs.append((n * math.cos(inc) + lado * math.sin(inc)).normalized())
        for d in dirs:
            if bvh.ray_cast(p + d * 0.0005, d, 0.5)[0] is None:
                return False
        return True

    @staticmethod
    def _mais_funda(bvh, p, n, janela):
        """Desce de fora pra dentro ao longo de -n e devolve o toque mais
        fundo que ainda esteja a `janela` metros do primeiro (camadas de
        roupa e cabelo em cima da pele; mais fundo que isso ja' e' o outro
        lado do membro)."""
        o = p + n * 0.25
        primeiro = None
        funda = None
        resto = 0.25 + janela + 0.3
        for _ in range(12):
            hit = bvh.ray_cast(o, -n, resto)
            if hit[0] is None:
                break
            q = hit[0]
            if primeiro is None:
                primeiro = q
            elif (primeiro - q).dot(n) > janela:
                break
            funda = q
            andou = (o - q).length + 0.0008
            resto -= andou
            o = q - n * 0.0008
            if resto <= 0:
                break
        return funda

    # ---------------------------------------------------------- discos
    def _disco(self, bm, uv, centro, n, raio_em, domo, segmentos=18):
        """Disco de corte (leque) virado pro `n`, com o meio estufado.
        `raio_em(direcao)` diz o raio de cada gomo: o aro acompanha o corte
        da junta em vez de ser um circulo (no ombro um circulo furava o
        deltoide do braco ainda inteiro)."""
        b1, b2 = _base_ortogonal(n)
        meio = bm.verts.new(centro + n * domo)
        aro = []
        for i in range(segmentos):
            a = math.tau * i / segmentos
            d = b1 * math.cos(a) + b2 * math.sin(a)
            aro.append(bm.verts.new(centro + d * raio_em(d)))
        faces = []
        for i in range(segmentos):
            a, b = aro[i], aro[(i + 1) % segmentos]
            f = bm.faces.new([meio, a, b])
            f.material_index = MAT_CORTE
            f.smooth = True
            faces.append(f)
            for lp in f.loops:
                if lp.vert is meio:
                    lp[uv].uv = (0.5, 0.5)
                else:
                    k = aro.index(lp.vert)
                    ang = math.tau * k / segmentos
                    lp[uv].uv = (0.5 + 0.5 * math.cos(ang), 0.5 + 0.5 * math.sin(ang))
        return meio, aro, faces

    def discos(self):
        # a pele intacta (sem as tigelas), pra medir ate' onde cabe cada disco
        lisas = [f for f in self.bm.faces if f.material_index == MAT_PELE]
        pele = BVHTree.FromPolygons([v.co.copy() for v in self.bm.verts],
                                    [[v.index for v in f.verts] for f in lisas])
        for nome, inf in list(self.info.items()):
            if inf["tipo"] != "membro" or not inf["anel"]:
                if inf["tipo"] == "membro":
                    print("  !! %s: sem anel de junta" % nome)
                continue
            pts = np.array([list(p) for p, _ in inf["anel"]])
            centro = Vector(pts.mean(axis=0))
            # o plano do anel (o menor eixo da nuvem), virado pro membro
            _, _, vt = np.linalg.svd(pts - pts.mean(axis=0))
            n = Vector(vt[2]).normalized()
            b = self._osso(inf["osso"])
            if n.dot(b.tail_local - b.head_local) < 0:
                n = -n
            dist = []
            for p, _ in inf["anel"]:
                rel = p - centro
                dist.append((rel - n * rel.dot(n)).length)
            raio = float(np.median(dist))
            inf["centro"] = centro
            inf["normal"] = n
            inf["raio"] = raio

            def raio_em(d, folga=0.86, teto=0.92):
                hit = pele.ray_cast(centro, d, raio * 1.6)
                if hit[0] is None:
                    return raio * teto
                return max(raio * 0.35, min(raio * teto, hit[3] * folga))

            # 1) o coto, no corpo (ou no membro de cima): pesado como o anel
            meio, aro, faces = self._disco(self.bm, self.uv, centro, n, raio_em, raio * 0.18)
            for v in aro:
                perto = min(inf["anel"], key=lambda pw: (pw[0] - v.co).length)
                for g, w in perto[1].items():
                    v[self.dl][self.ig[g]] = w
            soma = defaultdict(float)
            for _, pw in inf["anel"]:
                for g, w in pw.items():
                    soma[g] += w
            tot = sum(soma.values())
            for g, w in soma.items():
                meio[self.dl][self.ig[g]] = w / tot
            pai = inf["pai"] or ""
            for f in faces:
                self.parte[f] = pai

            # 2) a ponta de cima da peca que cai, e o disco do coto solto
            pb = self._peca_do_membro(nome)
            uvp = pb.loops.layers.uv.active
            def raio_solto(d):
                return raio_em(d, 0.95, 0.98)
            self._disco(pb, uvp, centro, -n, raio_solto, raio * 0.18)
            cb = bmesh.new()
            uvc = cb.loops.layers.uv.new("UVMap")
            self._disco(cb, uvc, centro, n, raio_solto, raio * 0.18)
            self.pecas_bm["corte_" + nome] = cb

    def _peca_do_membro(self, nome):
        chave = "peca_" + nome
        if chave in self.pecas_bm:
            return self.pecas_bm[chave]
        pb = bmesh.new()
        uv = pb.loops.layers.uv.new("UVMap")
        mapa = {}
        faces = [f for f in self.bm.faces if self.parte[f] == nome]
        for f in faces:
            for v in f.verts:
                if v not in mapa:
                    mapa[v] = pb.verts.new(v.co.copy())
            try:
                nf = pb.faces.new([mapa[v] for v in f.verts])
                nf.material_index = f.material_index
                nf.smooth = True
                for lo, ld in zip(f.loops, nf.loops):
                    ld[uv].uv = lo[self.uv].uv
            except ValueError:
                pass
        self.pecas_bm[chave] = pb
        if mapa:
            self.info[nome]["massa"] = len(faces)
            pts = [v.co for v in mapa]
            self.info[nome]["centro_peca"] = sum(pts, Vector()) / len(pts)
        return pb

    # ---------------------------------------------------------- ossos-sombra
    def ossos_sombra(self):
        """Repesa cada vertice de peca em `pk_<peca>_<osso>` e cria os ossos."""
        precisa = set()
        verts_parte = defaultdict(set)
        for f in self.bm.faces:
            p = self.parte.get(f, "")
            if p:
                for v in f.verts:
                    verts_parte[p].add(v)
        for p, vs in verts_parte.items():
            for v in vs:
                novo = {}
                for g, w in v[self.dl].items():
                    sombra = "pk_%s_%s" % (p, self.gi[g])
                    precisa.add((sombra, self.gi[g]))
                    novo[sombra] = w
                v[self.dl].clear()
                for s, w in novo.items():
                    if s not in self.ig:
                        self.ig[s] = self.malha.vertex_groups.new(name=s).index
                        self.gi[self.ig[s]] = s
                    v[self.dl][self.ig[s]] = w
        bpy.context.view_layer.objects.active = self.arm
        bpy.ops.object.mode_set(mode='EDIT')
        eb = self.arm.data.edit_bones
        for sombra, orig in sorted(precisa):
            o = eb[orig]
            b = eb.new(sombra)
            b.head, b.tail, b.roll = o.head.copy(), o.tail.copy(), o.roll
            b.parent = o
            b.use_connect = False
            b.use_deform = True
        bpy.ops.object.mode_set(mode='OBJECT')
        print("  %d ossos-sombra" % len(precisa))

    # ---------------------------------------------------------- gravar
    def gravar(self, mats):
        self.bm.to_mesh(self.malha.data)
        self.malha.data.update()
        self.bm.free()
        vazio = bpy.data.objects.get("pecas") or bpy.data.objects.new("pecas", None)
        if vazio.name not in bpy.context.scene.collection.objects:
            bpy.context.scene.collection.objects.link(vazio)
        for nome, pb in self.pecas_bm.items():
            me = bpy.data.meshes.new(nome)
            pb.to_mesh(me)
            pb.free()
            for m in mats:
                me.materials.append(m)
            obj = bpy.data.objects.new(nome, me)
            bpy.context.scene.collection.objects.link(obj)
            obj.parent = vazio


def _godot(v):
    """Blender (Z cima, frente -Y) -> Godot (Y cima, frente +Z)."""
    return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


def escrever_dados(nome, info):
    linhas = [
        "## GERADO por tools/blender/lekrosos/cortar.py — nao editar a mao.",
        "##",
        "## As pecas removiveis do %s. Espaco do Skeleton3D (metros, frente +Z)." % nome,
        "## pedaco: some da carne e cai uma lasca (o corpo continua andando).",
        "## membro: o membro inteiro cai (`pai` = quem esta' acima dele).",
        "",
        "const PECAS := {",
    ]
    for p, inf in sorted(info.items()):
        c = inf.get("centro_peca", inf.get("centro"))
        if c is None:
            continue
        n = inf.get("normal", Vector((0, 0, 1)))
        campos = ['"tipo": "%s"' % inf["tipo"], '"zona": "%s"' % inf["zona"],
                  '"osso": "%s"' % inf["osso"],
                  '"centro": Vector3(%s, %s, %s)' % tuple(_godot(c)),
                  '"normal": Vector3(%s, %s, %s)' % tuple(_godot(n)),
                  '"raio": %.4f' % inf.get("raio", 0.05),
                  '"massa": %d' % inf.get("massa", inf.get("faces", 0))]
        if inf["tipo"] == "membro":
            campos.append('"pai": "%s"' % (inf["pai"] or ""))
            cj = inf.get("centro")
            if cj is not None:
                campos.append('"junta": Vector3(%s, %s, %s)' % tuple(_godot(cj)))
        linhas.append('\t"%s": {%s},' % (p, ", ".join(campos)))
    linhas.append("}")
    os.makedirs(DADOS_GD, exist_ok=True)
    caminho = os.path.join(DADOS_GD, nome + "_dados.gd")
    with open(caminho, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas) + "\n")
    print("== dados", caminho)


def main():
    nome = sys.argv[sys.argv.index("--") + 1]
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    malha = next(o for o in bpy.data.objects if o.type == 'MESH' and o.parent == arm)
    bpy.context.view_layer.objects.active = malha
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')

    mats = [malha.data.materials[0], material("lekroso_carne", textura_carne(), 0.22),
            material("lekroso_corte", textura_corte(), 0.3)]
    while len(malha.data.materials) > 1:
        malha.data.materials.pop()
    malha.data.materials.append(mats[1])
    malha.data.materials.append(mats[2])

    c = Corte(malha, arm)
    c.classificar()
    c.escolher_pedacos()
    c.aneis_dos_membros()
    c.separar()
    c.crateras()
    for membro in MEMBROS:
        c._peca_do_membro(membro)
    c.discos()
    c.ossos_sombra()
    c.gravar(mats)

    for p, inf in sorted(c.info.items()):
        print("  %-18s %-7s %-12s %5d faces" % (p, inf["tipo"], inf["osso"],
                                              inf.get("massa", inf.get("faces", 0))))
    escrever_dados(nome, c.info)
    saida = os.path.join(BLENDS, nome + "_cortado.blend")
    bpy.ops.wm.save_as_mainfile(filepath=saida)
    print("== salvo", saida)


main()
