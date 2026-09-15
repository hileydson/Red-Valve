"""Gera a biblioteca de pecas do parasita do "Unknown Neighbor" e exporta
pra `.glb`.

Rodar em background (NAO precisa do addon MCP nem mexe na cena que voce tem
aberta):

    /snap/bin/blender --background --python tools/blender/vizinho/gerar_vizinho.py

Saida: red-valve/assets/3d_model/enemies/folded_neighbor/vizinho.glb

==============================================================================
POR QUE ESTE ARQUIVO EXISTE

O corpo deste inimigo NAO e modelado aqui: ele e uma PESSOA COMUM, e o corpo
vem pronto do pacote de moradores da cidade
(`assets/3d_model/stages/npc_cidade/ranbom_npc_cidade`), o mesmo que o
`city_npc.gd` usa. Isso e a piada inteira do bicho: ele anda na rua e e
indistinguivel de um vizinho ate se abrir.

O que este arquivo modela e o PARASITA — a coisa que estava dobrada dentro da
pessoa e que vai se desdobrando em cinco formas, conforme leva dano. Essas
pecas sao penduradas nos ossos do modelo humano pelo `folded_neighbor.gd`.

Fazer isso com capsula e esfera nao daria: a flor que abre na cabeca, a foice
que sai do antebraco e as placas de pele da defesa dependem de silhueta. Um
parasita de capsulas viraria um punhado de balao grudado num boneco.

==============================================================================
A IDEIA DO DESENHO

"Alguem dobrou uma pessoa por dentro e agora ela esta se abrindo."

  - NADA DE MONSTRO INTEIRO. Cada peca e um pedaco que sai de UM ponto do
    corpo humano. A leitura tem de ser sempre "aquilo cresceu de dentro da
    pessoa", nunca "um monstro vestindo uma pessoa".
  - PETALA, NAO TENTACULO. A cabeca que abre e uma FLOR: quatro a seis
    petalas rigidas, de dentro pra fora, com o nucleo no meio. E o que faz o
    bicho ser reconhecivel a 20 m na nevoa, e e a diferenca das quatro
    linhagens (cada uma tem a sua petala).
  - SIMETRIA QUEBRADA. Toda peca tem um lado ligeiramente maior que o outro.
    Simetria perfeita le como objeto fabricado; a assimetria e o que faz
    parecer que CRESCEU.
  - A FOICE E OSSO, NAO METAL. Fio afiado, mas com a grossura e o veio de um
    osso longo. Metal seria outra criatura.
  - AS PLACAS DE PELE tem uma ondulacao que quase desenha uma cara. Quase. Sao
    a defesa dele: a propria pele desdobrada pra fora, e o jogador tem de
    sentir que esta atirando em alguem.

==============================================================================
COMO AS PECAS CHEGAM NO GODOT

Mesma convencao da biblioteca do Shadow Seraph — e de proposito: o
`folded_neighbor.gd` pendura as pecas em pivos Node3D exatamente como o
`shadow_seraph.gd` faz, entao quem ja leu um le o outro.

  MEMBRO (foice, garra, haste, perna_extra, raiz):
      pende do pivo, ocupando y de 0 (junta de cima) a -1 (ponta). Largura
      dentro de x,z em [-0.5, 0.5]. O Godot escala por (raio*2, comp, raio*2).

  TRONCO (petala_*, broto, costela_aberta):
      aponta pra cima, y de 0 a 1, mesma largura normalizada.

  CENTRADA (nucleo, mandibula, placa_casca, coto):
      cabe em [-0.5, 0.5] nos tres eixos, origem na junta.

E duas cores de dado por vertice, lidas pelo
`shaders/enemies/folded_neighbor_parasite.gdshader`:

  COLOR.r  VEIA   — onde a rede de veias tem direito de acender
  COLOR.g  QUINA  — 1 numa aresta viva (sai da curvatura, calculada aqui)
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

TAU = math.pi * 2.0

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
SAIDA = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "enemies",
                     "folded_neighbor", "vizinho.glb")
COLECAO = "vizinho"


# ============================================================ ferramentaria
#
# Igual a do Seraph: tudo aqui e costurar aneis. Um anel e uma volta de pontos;
# empilhando aneis e costurando os vizinhos sai um tubo que afina, curva,
# achata e vira quina. Petala, foice, nucleo e placa de pele sao o mesmo verbo
# com numeros diferentes.


def _limpa_cena():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _anel(n, rx, rz, y, forma="circulo", giro=0.0, dz=0.0, dx=0.0):
    """Uma volta de `n` pontos no plano XZ, na altura `y`.

    `forma` deforma a volta SEM mudar a contagem de pontos, que e o que permite
    costurar um anel redondo num anel de lamina dentro do mesmo tubo:

      circulo  redondo puro
      lamina   achatado em X com fio na frente (-Z): foice, petala, espinho
      gota     largo atras, afilado na frente: nucleo, cranio da mandibula
      prega    ondulado: carne franzida, placa de pele
      talo     levemente triangular: haste, raiz
    """
    pts = []
    for i in range(n):
        a = TAU * i / n + giro
        cx, cz = math.cos(a), math.sin(a)
        fx = fz = 1.0
        frente = max(0.0, -cz)
        atras = max(0.0, cz)
        if forma == "lamina":
            fx = 0.30
            fz = 1.0 + 0.45 * frente ** 1.4
        elif forma == "gota":
            fz = 1.0 + 0.30 * atras - 0.18 * frente
        elif forma == "prega":
            fx = fz = 1.0 + 0.13 * math.cos(3.0 * a)
        elif forma == "talo":
            k = 1.0 + 0.16 * math.cos(3.0 * a + 1.1)
            fx = fz = k
        pts.append(Vector((cx * rx * fx + dx, y, cz * rz * fz + dz)))
    return pts


def _costura(bm, aneis, tampa=True, fechado=True):
    """Costura uma pilha de aneis (todos com a mesma contagem) dentro de `bm`."""
    vs = [[bm.verts.new(p) for p in anel] for anel in aneis]
    n = len(aneis[0])
    lim = n if fechado else n - 1
    for k in range(len(vs) - 1):
        a, b = vs[k], vs[k + 1]
        for i in range(lim):
            j = (i + 1) % n
            try:
                bm.faces.new((a[i], a[j], b[j], b[i]))
            except ValueError:
                pass
    if tampa:
        for cap, inverte in ((vs[0], True), (vs[-1], False)):
            if len(set(tuple(round(c, 6) for c in v.co) for v in cap)) < 3:
                continue   # anel degenerado (ponta fechada): nao tem tampa
            try:
                bm.faces.new(list(reversed(cap)) if inverte else list(cap))
            except ValueError:
                pass
    return vs


def _perfil(secoes, n=10):
    """Atalho: lista de (y, rx, rz, forma, giro, dz) -> lista de aneis."""
    out = []
    for s in secoes:
        y, rx, rz = s[0], s[1], s[2]
        forma = s[3] if len(s) > 3 else "circulo"
        giro = s[4] if len(s) > 4 else 0.0
        dz = s[5] if len(s) > 5 else 0.0
        dx = s[6] if len(s) > 6 else 0.0
        out.append(_anel(n, rx, rz, y, forma, giro, dz, dx))
    return out


def _varre(caminho, raios, n=8, achata=1.0, giro=0.0, torcao=0.0, eixo=None):
    """Varre um perfil ao longo de uma polilinha 3D.

    Ferramenta da foice, da garra, da haste e das petalas curvas: tudo que e um
    tubo que afina e curva. O referencial de cada no sai da tangente, com o
    "pra cima" preso num eixo do mundo.

    `eixo` TRAVA a largura num eixo fixo do mundo, e existe por causa da foice.
    Sem ele o referencial e' escolhido por no, comparando a tangente com o Y do
    mundo: numa lamina que comeca descendo (tangente ~ -Y) e termina apontando
    pra frente (tangente ~ -Z), essa escolha VIRA no meio do caminho e a peca
    sai torcida 90 graus na ponta — foi exatamente o que aconteceu na primeira
    versao da foice. Peca plana (lamina, petala, costela) passa o eixo da
    largura e o problema some.
    """
    caminho = [Vector(p) for p in caminho]
    aneis = []
    for k, p in enumerate(caminho):
        if k == 0:
            tang = caminho[1] - caminho[0]
        elif k == len(caminho) - 1:
            tang = caminho[-1] - caminho[-2]
        else:
            tang = caminho[k + 1] - caminho[k - 1]
        if tang.length < 1e-9:
            tang = Vector((0.0, -1.0, 0.0))
        tang.normalize()
        if eixo is not None:
            lado = Vector(eixo).normalized()
        else:
            ref = Vector((0.0, 1.0, 0.0))
            if abs(tang.dot(ref)) > 0.95:
                ref = Vector((0.0, 0.0, 1.0))
            lado = tang.cross(ref).normalized()
        cima = lado.cross(tang).normalized()
        r = raios[k]
        f = float(k) / max(1, len(caminho) - 1)
        anel = []
        for i in range(n):
            a = TAU * i / n + giro + torcao * f
            anel.append(p + lado * (math.cos(a) * r) + cima * (math.sin(a) * r * achata))
        aneis.append(anel)
    return aneis


def _finaliza(nome, bm, veia=None, suave=True, solda=1e-4):
    """Fecha a malha: solda, triangula, sombreamento e as duas cores de dado.

    `veia` e uma funcao (Vector) -> float com o valor de COLOR.r naquele ponto.
    COLOR.g sai da CURVATURA (quina = 1), medida pelo angulo entre as faces que
    chegam no vertice.
    """
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=solda)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.normal_update()

    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()

    # Carne e SUAVE por padrao aqui, ao contrario da pedra do Shadow Rock e do
    # carvao do Seraph: carne facetada le como origami. `suave=False` existe
    # pras poucas pecas que sao osso seco e ganham com a faceta.
    for p in me.polygons:
        p.use_smooth = suave

    quina = [0.0] * len(me.vertices)
    conta = [0] * len(me.vertices)
    for p in me.polygons:
        for vi in p.vertices:
            d = p.normal.dot(me.vertices[vi].normal)
            quina[vi] += 1.0 - max(-1.0, min(1.0, d))
            conta[vi] += 1
    for i in range(len(quina)):
        quina[i] = min(1.0, quina[i] / max(1, conta[i]) * 2.4)

    cam = me.color_attributes.new(name="dados", type="FLOAT_COLOR", domain="POINT")
    for i, v in enumerate(me.vertices):
        b = 0.0 if veia is None else max(0.0, min(1.0, veia(v.co)))
        cam.data[i].color = (b, quina[i], 0.0, 1.0)
    me.color_attributes.active_color = cam
    me.attributes.active_color_name = cam.name
    me.attributes.default_color_name = cam.name

    return bpy.data.objects.new(nome, me)


def _novo():
    return bmesh.new()


# ==================================================================== o NUCLEO

def peca_nucleo():
    """O parasita em si: o no de carne que estava dobrado dentro da pessoa.

    CENTRADA. E a peca mais importante do bicho — na quinta forma o corpo
    humano fica pendurado como casca e e ISTO que o jogador tem pela frente,
    entao ela precisa aguentar close.

    Desenho: um caroco em forma de gota deitada, com uma FENDA horizontal no
    meio (a boca que nao e boca) e quatro sulcos radiais correndo pro fundo,
    como se tivesse sido enrolado. Nada de olho: olho humaniza, e o horror
    daqui e nao ter com que negociar.
    """
    bm = _novo()
    # massa principal, de tras (z+) pra frente (z-)
    _costura(bm, _perfil([
        (-0.34, 0.10, 0.10, "gota"),
        (-0.22, 0.24, 0.22, "gota"),
        (-0.06, 0.34, 0.31, "prega"),
        (0.08, 0.36, 0.33, "prega"),
        (0.20, 0.30, 0.28, "gota"),
        (0.31, 0.16, 0.15, "gota"),
        (0.38, 0.05, 0.05),
    ], n=14))
    # a fenda: dois labios de carne que quase se encostam
    for lado in (1.0, -1.0):
        _costura(bm, _varre(
            [(0.0, 0.055 * lado, -0.36), (0.0, 0.085 * lado, -0.16),
             (0.0, 0.095 * lado, 0.08), (0.0, 0.070 * lado, 0.26)],
            [0.055, 0.085, 0.078, 0.045], n=7))
    # sulcos radiais: o caroco parece ENROLADO, nao moldado
    for i in range(5):
        a = TAU * i / 5.0 + 0.3
        _costura(bm, _varre(
            [(math.cos(a) * 0.16, -0.30, math.sin(a) * 0.16),
             (math.cos(a) * 0.33, -0.10, math.sin(a) * 0.31),
             (math.cos(a) * 0.30, 0.16, math.sin(a) * 0.28)],
            [0.030, 0.045, 0.030], n=5))

    def veia(v):
        # a rede sai da fenda e desce pro fundo do caroco
        fenda = max(0.0, 1.0 - abs(v.y) / 0.11)
        fundo = max(0.0, 1.0 - abs(v.y + 0.30) / 0.14)
        return max(fenda, fundo * 0.8)
    return _finaliza("nucleo", bm, veia)


# =================================================================== as PETALAS
#
# A coroa que abre na cabeca. Uma por linhagem — e a peca que distingue as
# quatro variacoes em contraluz, quando a cor ja morreu na nevoa.
#
# Todas na convencao TRONCO (y 0 -> 1): elas CRESCEM pra cima a partir do
# pescoco, e o Godot as gira em leque em volta da cabeca.


def peca_petala_lisa():
    """PALIDO: petala lisa, longa, de osso fino. Le como lirio morto."""
    bm = _novo()
    _costura(bm, _varre(
        [(0.0, 0.0, 0.02), (0.0, 0.26, -0.04), (0.0, 0.54, -0.16),
         (0.0, 0.80, -0.36), (0.0, 0.96, -0.60), (0.0, 1.0, -0.78)],
        [0.09, 0.21, 0.25, 0.20, 0.10, 0.010], n=9, achata=0.22, eixo=(1.0, 0.0, 0.0)), tampa=True)
    # nervura central: a linha que faz a petala ter um DENTRO e um fora
    _costura(bm, _varre(
        [(0.0, 0.05, 0.02), (0.0, 0.40, -0.09), (0.0, 0.72, -0.28),
         (0.0, 0.92, -0.54)],
        [0.055, 0.048, 0.034, 0.014], n=5))

    def veia(v):
        # so a base acende: a ponta e osso seco
        return max(0.0, 1.0 - v.y / 0.42)
    return _finaliza("petala_lisa", bm, veia)


def peca_petala_bulbo():
    """BILIAR: petala carnuda, com tres bulbos pendurados que gotejam."""
    bm = _novo()
    _costura(bm, _varre(
        [(0.0, 0.0, 0.02), (0.0, 0.24, -0.04), (0.0, 0.50, -0.14),
         (0.0, 0.74, -0.30), (0.0, 0.90, -0.50)],
        [0.09, 0.19, 0.22, 0.17, 0.05], n=9, achata=0.34, eixo=(1.0, 0.0, 0.0)))
    # Quatro bulbos pendurados ALTERNADOS nas duas bordas, cada um preso por um
    # talo curto. Pendurar no eixo da petala escondia todos dentro dela.
    for k, (y, z, r) in enumerate(((0.22, -0.05, 0.10), (0.44, -0.12, 0.115),
                                   (0.64, -0.24, 0.095), (0.80, -0.40, 0.070))):
        lado = 1.0 if k % 2 == 0 else -1.0
        bx = lado * (0.17 + r * 0.7)
        _costura(bm, _varre(
            [(lado * 0.10, y, z), (bx * 0.75, y - 0.02, z - 0.02)],
            [0.030, 0.026], n=5))
        _costura(bm, _perfil([
            (y + r * 0.8, r * 0.30, r * 0.30, "circulo", 0.0, z, bx),
            (y, r, r, "prega", 0.0, z - r * 0.15, bx),
            (y - r * 1.2, r * 0.60, r * 0.60, "circulo", 0.0, z - r * 0.05, bx),
            (y - r * 1.7, 0.012, 0.012, "circulo", 0.0, z, bx),
        ], n=8))

    def veia(v):
        base = max(0.0, 1.0 - v.y / 0.50)
        # os bulbos inteiros sao veia: e deles que a coisa escorre
        bulbo = 1.0 if abs(v.x) > 0.15 else 0.0
        return max(base, bulbo)
    return _finaliza("petala_bulbo", bm, veia)


def peca_petala_espinho():
    """ESCARLATE: petala curta e larga, com cinco espinhos na borda externa."""
    bm = _novo()
    _costura(bm, _varre(
        [(0.0, 0.0, 0.02), (0.0, 0.22, -0.06), (0.0, 0.48, -0.18),
         (0.0, 0.70, -0.36), (0.0, 0.84, -0.58)],
        [0.10, 0.23, 0.26, 0.17, 0.02], n=9, achata=0.30, eixo=(1.0, 0.0, 0.0)))
    for i in range(5):
        f = 0.14 + 0.17 * i
        y = f * 0.86
        z = -(0.02 + 0.52 * f * f)
        comp = 0.13 + 0.09 * (1.0 - abs(f - 0.5) * 2.0)
        for lado in (1.0, -1.0):
            x = lado * (0.10 + 0.14 * math.sin(f * math.pi))
            _costura(bm, _varre(
                [(x, y, z), (x * 1.5, y + comp * 0.5, z - comp * 0.35),
                 (x * 1.9, y + comp, z - comp * 0.7)],
                [0.032, 0.020, 0.004], n=5))

    def veia(v):
        base = max(0.0, 1.0 - v.y / 0.40)
        return max(base, 0.55 if abs(v.x) > 0.22 else 0.0)
    return _finaliza("petala_espinho", bm, veia)


def peca_petala_chifre():
    """CINZENTO: petala curta, grossa e gretada — quase um chifre.

    So tres delas abrem na cabeca desta linhagem, e e por isso que ela e a mais
    facil de reconhecer de longe: a coroa fica RALA, com vao entre as pecas.
    """
    bm = _novo()
    _costura(bm, _varre(
        [(0.0, 0.0, 0.02), (0.0, 0.20, -0.01), (0.0, 0.42, -0.08),
         (0.0, 0.60, -0.22), (0.0, 0.70, -0.40)],
        [0.16, 0.24, 0.21, 0.13, 0.018], n=8, achata=0.85, eixo=(1.0, 0.0, 0.0)))
    # tres gretas ao longo do dorso
    for i in range(3):
        y0 = 0.10 + 0.20 * i
        _costura(bm, _varre(
            [(0.0, y0, 0.06), (0.0, y0 + 0.13, 0.02)],
            [0.030, 0.018], n=5))

    def veia(v):
        # nesta linhagem a veia esta nas GRETAS, nao na base
        return 1.0 if v.z > 0.02 else max(0.0, 1.0 - v.y / 0.26) * 0.7
    return _finaliza("petala_chifre", bm, veia)


# ================================================================== a CABECA

def peca_mandibula():
    """Metade da mandibula humana depois que a cabeca racha.

    CENTRADA, autorada pro lado -X; o Godot espelha pro outro lado. E o
    pedacinho de gente que sobra na flor — sem ele a cabeca aberta vira so uma
    planta, e a leitura de "isto era uma pessoa" se perde.
    """
    bm = _novo()
    _costura(bm, _perfil([
        (0.10, 0.09, 0.14, "gota"),
        (0.02, 0.13, 0.19, "gota"),
        (-0.08, 0.14, 0.20, "gota"),
        (-0.17, 0.11, 0.16, "gota"),
        (-0.24, 0.05, 0.07, "gota"),
    ], n=10))
    # fileira de dentes na borda de baixo
    for i in range(5):
        z = 0.14 - 0.075 * i
        _costura(bm, _varre(
            [(0.0, -0.20, z), (0.0, -0.27, z)],
            [0.022, 0.006], n=4))

    def veia(v):
        return max(0.0, 1.0 - abs(v.y - 0.10) / 0.10)
    return _finaliza("mandibula", bm, veia)


# =================================================================== as ARMAS

def peca_foice():
    """A foice: o antebraco direito desdobrado numa lamina de osso.

    MEMBRO (pende de y=0 a y=-1). Curva pra FRENTE (-Z) na ponta, com fio na
    borda de dentro e um dorso grosso e veiado do lado de fora — e o dorso que
    da peso; uma lamina fina dos dois lados le como faca de cozinha.
    """
    bm = _novo()
    _costura(bm, _varre(
        [(0.0, 0.0, 0.04), (0.0, -0.20, 0.00), (0.0, -0.42, -0.09),
         (0.0, -0.62, -0.23), (0.0, -0.78, -0.42), (0.0, -0.90, -0.64),
         (0.0, -0.97, -0.86)],
        [0.14, 0.22, 0.25, 0.23, 0.18, 0.10, 0.012], n=10, achata=0.26, eixo=(1.0, 0.0, 0.0)))
    # o punho de carne que prende a lamina no cotovelo
    _costura(bm, _perfil([
        (0.06, 0.17, 0.17, "prega"),
        (-0.02, 0.21, 0.21, "prega"),
        (-0.13, 0.17, 0.17, "prega"),
    ], n=9))

    def veia(v):
        # a rede corre no DORSO (z positivo) e no punho; o fio fica seco
        punho = max(0.0, 1.0 - abs(v.y + 0.02) / 0.14)
        dorso = max(0.0, min(1.0, (v.z + 0.02) * 6.0)) * 0.8
        return max(punho, dorso)
    return _finaliza("foice", bm, veia)


def peca_garra():
    """Dedo/garra: usado na mao que ainda e mao e nas patas do rastejante."""
    bm = _novo()
    _costura(bm, _varre(
        [(0.0, 0.0, 0.0), (0.0, -0.34, -0.06), (0.0, -0.66, -0.20),
         (0.0, -0.88, -0.42), (0.0, -1.0, -0.66)],
        [0.16, 0.13, 0.09, 0.05, 0.008], n=7))

    def veia(v):
        return max(0.0, 1.0 + v.y / 0.30)
    return _finaliza("garra", bm, veia)


def peca_haste():
    """Haste: o segmento de tentaculo da semeadura e das raizes.

    MEMBRO, afina forte e tem aneis de carne — a leitura tem de ser "cordao
    umbilical", nao "cabo".
    """
    bm = _novo()
    aneis = []
    n = 12
    for k in range(n + 1):
        f = k / float(n)
        y = -f
        r = 0.18 * (1.0 - f) ** 0.7 + 0.02
        # aneis de carne: engrossa e afina ao longo do caminho
        r *= 1.0 + 0.22 * math.sin(f * math.pi * 5.0)
        dz = math.sin(f * math.pi * 1.7) * 0.10
        aneis.append(_anel(7, r, r, y, "talo", f * 2.2, dz))
    _costura(bm, aneis)

    def veia(v):
        return 0.75
    return _finaliza("haste", bm, veia)


def peca_broto():
    """O broto que nasce onde a mao arremessada cai e que agarra o jogador.

    TRONCO. Um bulbo fechado em cima de um talo curto, com quatro labios que o
    Godot abre por rotacao quando ele floresce.
    """
    bm = _novo()
    _costura(bm, _perfil([
        (0.0, 0.17, 0.17, "talo"),
        (0.14, 0.11, 0.11, "talo"),
        (0.28, 0.19, 0.19, "prega"),
        (0.42, 0.28, 0.28, "prega"),
        (0.58, 0.30, 0.30, "prega"),
        (0.72, 0.26, 0.26, "prega"),
        (0.86, 0.16, 0.16, "prega"),
        (0.96, 0.07, 0.07),
        (1.0, 0.015, 0.015),
    ], n=11))
    # quatro costuras verticais: e por elas que o bulbo ABRE quando floresce
    for i in range(4):
        a = TAU * i / 4.0 + 0.6
        _costura(bm, _varre(
            [(math.cos(a) * 0.20, 0.30, math.sin(a) * 0.20),
             (math.cos(a) * 0.30, 0.58, math.sin(a) * 0.30),
             (math.cos(a) * 0.17, 0.86, math.sin(a) * 0.17)],
            [0.022, 0.030, 0.018], n=5))

    def veia(v):
        return max(0.0, 1.0 - abs(v.y - 0.56) / 0.40)
    return _finaliza("broto", bm, veia)


def peca_perna_extra():
    """Pata do rastejante: sai das costas, dobra pra cima e desce ate o chao.

    MEMBRO. Tem DUAS dobras (nao uma) porque e isso que separa pata de inseto
    de perna de bicho — e a quarta forma dele tem de mudar a silhueta inteira
    numa leitura so.
    """
    bm = _novo()
    _costura(bm, _varre(
        [(0.0, 0.0, 0.0), (0.0, 0.16, -0.22), (0.0, 0.06, -0.48),
         (0.0, -0.34, -0.60), (0.0, -0.74, -0.52), (0.0, -1.0, -0.40)],
        [0.11, 0.10, 0.085, 0.065, 0.040, 0.008], n=7))

    def veia(v):
        # as duas dobras acendem
        d1 = max(0.0, 1.0 - abs(v.y - 0.13) / 0.12)
        d2 = max(0.0, 1.0 - abs(v.y + 0.35) / 0.14)
        return max(d1, d2)
    return _finaliza("perna_extra", bm, veia)


# ================================================================== a DEFESA

def peca_placa_casca():
    """Uma placa da casca de defesa: pele humana desdobrada pra fora.

    CENTRADA e quase plana (olha pro -Z). A ondulacao da superficie quase
    desenha uma cara — testa, orbitas, a linha de uma boca — e para de propria
    no "quase": um rosto de verdade viraria careta de halloween, e o que
    incomoda e a duvida.
    """
    bm = _novo()
    n = 9
    linhas = []
    for j in range(7):
        fy = j / 6.0
        y = -0.5 + fy
        pts = []
        for i in range(n):
            fx = i / float(n - 1)
            x = -0.46 + 0.92 * fx
            # curvatura da placa: casca de ovo
            z = -0.10 - 0.16 * (1.0 - (2.0 * fx - 1.0) ** 2) * (1.0 - (2.0 * fy - 1.0) ** 2)
            # as "orbitas": duas covas na faixa de cima
            cova = 0.0
            for ox in (-0.19, 0.19):
                d = math.hypot(x - ox, (y - 0.14) * 1.5)
                cova += max(0.0, 1.0 - d / 0.15) ** 2
            # a "boca": um sulco horizontal na faixa de baixo
            boca = max(0.0, 1.0 - abs(y + 0.20) / 0.05) * max(0.0, 1.0 - abs(x) / 0.26)
            z += cova * 0.085 + boca * 0.05
            pts.append(Vector((x, y, z)))
        linhas.append(pts)
    # costura aberta (nao e um tubo): grade de quads
    vs = [[bm.verts.new(p) for p in linha] for linha in linhas]
    for j in range(len(vs) - 1):
        for i in range(n - 1):
            try:
                bm.faces.new((vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]))
            except ValueError:
                pass

    def veia(v):
        # as bordas rasgadas acendem; o meio da placa e pele e fica apagado
        borda = max(abs(v.x) / 0.46, abs(v.y) / 0.5)
        return max(0.0, (borda - 0.72) / 0.28)
    return _finaliza("placa_casca", bm, veia)


# =================================================================== o CORTE

def peca_coto():
    """O que sobra no corpo quando um membro e arrancado.

    CENTRADA, pequena. Nao e um toco liso: e um buque de hastes curtas
    espremidas, como se o membro tivesse sido feito de um FEIXE delas e o corte
    tivesse revelado isso. E o detalhe que faz a mutilacao valer — um toco
    chapado le como malha faltando.
    """
    bm = _novo()
    _costura(bm, _perfil([
        (0.22, 0.05, 0.05),
        (0.10, 0.26, 0.26, "prega"),
        (-0.06, 0.30, 0.30, "prega"),
        (-0.20, 0.22, 0.22, "prega"),
        (-0.30, 0.08, 0.08),
    ], n=10))
    for i in range(7):
        a = TAU * i / 7.0 + 0.4
        r = 0.12 + 0.07 * ((i * 5) % 3)
        x, z = math.cos(a) * r, math.sin(a) * r
        comp = 0.16 + 0.10 * ((i * 3) % 4) / 3.0
        _costura(bm, _varre(
            [(x, 0.06, z), (x * 1.2, 0.06 + comp * 0.7, z * 1.2),
             (x * 1.35, 0.06 + comp, z * 1.35)],
            [0.030, 0.018, 0.004], n=5))

    def veia(v):
        return 1.0 if v.y > -0.02 else 0.4
    return _finaliza("coto", bm, veia)


def peca_raiz():
    """Raiz fina que corre por baixo da pele (pescoco, punho) na PRIMEIRA forma.

    MEMBRO, bem fina. E o unico sinal de que aquele morador na calcada nao e um
    morador — tem de ser discreta o bastante pra passar batida numa olhada e
    obvia o bastante pra recompensar quem olha duas vezes.
    """
    bm = _novo()
    caminho = []
    raios = []
    n = 10
    for k in range(n + 1):
        f = k / float(n)
        caminho.append((math.sin(f * 5.4) * 0.12, -f, math.cos(f * 3.1) * 0.06))
        raios.append(0.055 * (1.0 - f * 0.75))
    _costura(bm, _varre(caminho, raios, n=5))
    # duas ramificacoes
    for (inicio, lado) in ((0.35, 1.0), (0.62, -1.0)):
        base = Vector((math.sin(inicio * 5.4) * 0.12, -inicio, math.cos(inicio * 3.1) * 0.06))
        _costura(bm, _varre(
            [tuple(base),
             tuple(base + Vector((0.11 * lado, -0.12, 0.03))),
             tuple(base + Vector((0.20 * lado, -0.28, 0.01)))],
            [0.030, 0.020, 0.004], n=5))

    def veia(v):
        return 1.0
    return _finaliza("raiz", bm, veia)


def peca_costela_aberta():
    """Uma costela do torax que se abre na quarta forma.

    TRONCO: nasce na coluna e varre pra frente e pra fora, como uma gaiola
    abrindo. O Godot poe seis delas de cada lado e vai girando conforme a forma
    avanca — o peito ABRE em cena, nao aparece aberto.
    """
    bm = _novo()
    _costura(bm, _varre(
        [(0.0, 0.0, 0.10), (0.0, 0.22, -0.06), (0.0, 0.42, -0.26),
         (0.0, 0.58, -0.50), (0.0, 0.66, -0.74), (0.0, 0.68, -0.94)],
        [0.070, 0.062, 0.052, 0.040, 0.026, 0.008], n=6, achata=0.55, eixo=(1.0, 0.0, 0.0)))

    def veia(v):
        return max(0.0, 1.0 - v.y / 0.30)
    return _finaliza("costela_aberta", bm, veia)


# ================================================================== export

PECAS = [
    peca_nucleo, peca_mandibula,
    peca_petala_lisa, peca_petala_bulbo, peca_petala_espinho, peca_petala_chifre,
    peca_foice, peca_garra, peca_haste, peca_broto, peca_perna_extra,
    peca_placa_casca, peca_coto, peca_raiz, peca_costela_aberta,
]


def _exporta(colecao, caminho):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.collections[colecao].objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = list(
        bpy.data.collections[colecao].objects)[0]

    # export_yup=False DE PROPOSITO — mesma razao do gerador do Seraph: as
    # pecas sao autoradas aqui na convencao do JOGO (Y pra cima, -Z pra
    # frente), nao na do Blender (Z pra cima). Com `export_yup=True` o
    # exportador faria a conversao Z-up -> Y-up por cima de dados que ja estao
    # em Y-up e tudo chegaria no Godot deitado. (Em contrapartida, quem abrir
    # o .blend vai ver as pecas deitadas — e o preco, e esta escrito aqui.)
    kw = dict(filepath=caminho, export_format="GLB", use_selection=True,
              export_apply=True, export_yup=False, export_materials="NONE",
              export_normals=True)
    # O nome da opcao de cor de vertice mudou entre versoes do exportador; sem
    # ela o COLOR_0 nao sai e o shader perde a veia e a quina.
    for chave, valor in (("export_vertex_color", "ACTIVE"), ("export_colors", True)):
        try:
            bpy.ops.export_scene.gltf(**dict(kw, **{chave: valor}))
            return chave
        except TypeError:
            continue
    bpy.ops.export_scene.gltf(**kw)
    return "padrao"


def main():
    _limpa_cena()
    col = bpy.data.collections.new(COLECAO)
    bpy.context.scene.collection.children.link(col)

    linhas = []
    total = 0
    for fn in PECAS:
        ob = fn()
        col.objects.link(ob)
        n = len(ob.data.polygons)
        total += n
        linhas.append((ob.name, n, len(ob.data.vertices)))

    flag = _exporta(COLECAO, SAIDA)

    print("\n[folded_neighbor] %d pecas -> %s" % (len(PECAS), SAIDA))
    for nome, tris, verts in sorted(linhas, key=lambda r: -r[1]):
        print("  %-18s %5d tris  %4d verts" % (nome, tris, verts))
    print("[folded_neighbor] total %d tris" % total)
    print("[folded_neighbor] cor de vertice via %r" % flag)
    print("[folded_neighbor] tamanho: %.1f KB" % (os.path.getsize(SAIDA) / 1024.0))


if __name__ == "__main__":
    main()
