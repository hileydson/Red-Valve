"""Gera a biblioteca de pecas do Shadow Seraph e exporta pra `.glb`.

Rodar em background (NAO precisa do addon MCP nem mexe na cena que voce tem
aberta):

    /snap/blender/7740/blender --background --python tools/blender/seraph/gerar_seraph.py

Saida: red-valve/assets/3d_model/enemies/shadow_seraph/seraph.glb

==============================================================================
POR QUE ESTE ARQUIVO EXISTE

O corpo do Seraph era montado no Godot com `CapsuleMesh` e `SphereMesh`. Isso
funciona pras sombras da cidade — elas sao vulto, o shader come a silhueta e
ninguem chega perto. Nele nao funcionou: ele e um CHEFE, tem barra de vida no
topo da tela, o jogador fica minutos olhando pra ele de perto, e o que estava
la era um boneco de balao — pilha de capsulas sem quina, sem placa, sem
desenho. Nenhum ajuste de shader conserta a falta de forma.

Aqui ele e MODELADO: casco de peito com quilha, caixa de costelas vazada com a
brasa aparecendo entre os ossos, ombreiras em placa, elmo sem rosto com fenda,
coroa de chifres, garras, pes de ave de rapina e asas de LAMINA (nao de pena —
ver abaixo). Tudo procedural, num script versionado, e nao um `.blend` binario
que ninguem consegue revisar em diff.

==============================================================================
A IDEIA DO DESENHO

"Serafim caido, forjado em carvao aceso e ferro preto."

  - SEM ROSTO. Elmo liso e bicudo com uma fenda horizontal por onde as duas
    brasas dos olhos queimam. Um rosto exigiria detalhe que nao se ve a 10 m e
    que fica esquisito de perto; uma fenda acesa le a qualquer distancia e da
    mais medo.
  - CINTURA FINA, OMBRO LARGO. E o que separa "criatura" de "pessoa alta". A
    silhueta tem de ser reconhecivel em contraluz, no meio da nevoa.
  - COSTELAS VAZADAS. O peito e uma gaiola: da pra ver a brasa QUEIMANDO
    DENTRO dele pelos vaos. E o unico lugar do corpo onde o fogo nao esta na
    superficie, e e o detalhe que faz a diferenca entre "pintado de laranja" e
    "tem fogo la dentro".
  - ASAS DE LAMINA, NAO DE PENA. Pena e macia, e macio briga com tudo que este
    bicho e; alem disso pena convincente pede cartao com alfa, e o corpo dele
    usa alpha scissor. Lascas compridas e afiadas, abrindo em leque, casam com
    a linguagem de pedra e brasa do resto do jogo (Shadow Rock) e desenham uma
    silhueta muito melhor.
  - AURELA QUEBRADA atras da cabeca. Tres arcos de um anel que nao fecha. E o
    que diz "serafim" numa leitura so, e e barato.
  - MANTO ESFARRAPADO nos ombros. Da massa, esconde a junta do quadril e
    mexe quando ele anda.

==============================================================================
COMO AS PECAS CHEGAM NO GODOT

O `shadow_seraph.gd` continua montando o rig por codigo (pivos Node3D) — isso
NAO muda, e de proposito: todas as poses dos seis poderes dele estao escritas
em cima desses pivos, e o corpo tem de poder ser remontado peca a peca. O que
muda e so a MALHA pendurada em cada pivo.

Pra isso funcionar, toda peca e autorada num espaco normalizado:

  MEMBRO (braco, antebraco, coxa, canela, mao, garra, pena, chifre...):
      pende do pivo, ocupando y de 0 (junta de cima) a -1 (ponta). Largura
      dentro de x,z em [-0.5, 0.5]. O Godot escala por (raio*2, comp, raio*2)
      e a peca cai no lugar da capsula que havia antes.

  TRONCO (torax, costelado, pescoco, espada...):
      aponta pra cima, y de 0 a 1, mesma largura normalizada.

  CENTRADA (pelve, elmo, halo, pe, ombreira):
      cabe em [-0.5, 0.5] nos tres eixos, origem na junta.

  FRENTE E -Z em todas elas, igual ao corpo.

==============================================================================
O QUE VAI NA COR DE VERTICE

O shader `shadow_seraph_body.gdshader` passa a ler dois canais. Use
FLOAT_COLOR (cor em byte e gravada em sRGB e chegaria no Godot com gama
aplicada — aqui os canais sao DADO, nao cor).

  COLOR.r  BRASA: o quanto este ponto queima. 1 no fundo da caixa de costelas,
           na fenda do elmo, nas juntas e no fio das laminas; 0 no meio de uma
           placa de armadura. E o que deixa o fogo ser DESENHADO em vez de
           sorteado por ruido — era isso que faltava pro bicho ter cara de
           coisa projetada e nao de textura procedural jogada por cima.
  COLOR.g  QUINA: 1 numa aresta viva, 0 no meio de uma face chata. O shader
           clareia por ali, que e como carvao lascado pega luz.
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix

TAU = math.pi * 2.0

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
SAIDA = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "enemies",
                     "shadow_seraph", "seraph.glb")
COLECAO = "seraph"


# ============================================================ ferramentaria
#
# Tudo neste arquivo e feito de UMA operacao: costurar aneis. Um anel e uma
# volta de pontos; empilhando aneis e costurando os vizinhos sai um tubo que
# afina, curva, achata e vira quina. Braco, chifre, costela, lamina, elmo e
# tubo de bazuca sao todos o mesmo verbo com numeros diferentes — e por isso o
# arquivo inteiro cabe numa cabeca so.


def _limpa_cena():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _anel(n, rx, rz, y, forma="circulo", giro=0.0, dz=0.0, dx=0.0):
    """Uma volta de `n` pontos no plano XZ, na altura `y`.

    `forma` deforma a volta SEM mudar a contagem de pontos — e isso que deixa
    costurar um anel redondo num anel de placa dentro do mesmo tubo:

      circulo  redondo puro
      quilha   crista na frente (-Z): esterno, fio de lamina
      placa    achatado em Z: placa de armadura
      gota     largo atras, afilado na frente: cranio, pe
      chanfro  puxado pro octogono: leitura de ferro dobrado, nao de balao
      cunha    triangular, ponta pra frente: bico do elmo
    """
    pts = []
    for i in range(n):
        a = TAU * i / n + giro
        cx, cz = math.cos(a), math.sin(a)
        fx = fz = 1.0
        frente = max(0.0, -cz)
        atras = max(0.0, cz)
        if forma == "quilha":
            fz = 1.0 + 0.34 * frente ** 1.6
            fx = 1.0 - 0.30 * frente ** 1.6
        elif forma == "placa":
            fz = 0.46
            fx = 1.0 + 0.10 * abs(cx)
        elif forma == "gota":
            fz = 1.0 + 0.28 * atras - 0.14 * frente
        elif forma == "chanfro":
            k = 1.0 - 0.17 * abs(math.cos(2.0 * a))
            fx = fz = k
        elif forma == "cunha":
            fx = 1.0 - 0.62 * frente
            fz = 1.0 + 0.55 * frente
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
    """Atalho: lista de (y, rx, rz, forma) -> lista de aneis."""
    out = []
    for s in secoes:
        y, rx, rz = s[0], s[1], s[2]
        forma = s[3] if len(s) > 3 else "circulo"
        giro = s[4] if len(s) > 4 else 0.0
        dz = s[5] if len(s) > 5 else 0.0
        out.append(_anel(n, rx, rz, y, forma, giro, dz))
    return out


def _varre(caminho, raios, n=8, achata=1.0, giro=0.0, torcao=0.0):
    """Varre um perfil ao longo de uma polilinha 3D.

    Ferramenta dos chifres, costelas, garras e laminas: tudo que e um tubo que
    afina e curva. O referencial de cada no sai da tangente, com o "pra cima"
    preso num eixo do mundo — sem isso o perfil roda sozinho ao longo da curva
    e a peca sai retorcida.
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


def _finaliza(nome, bm, brasa=None, suave=False, solda=1e-4):
    """Fecha a malha: solda, triangula, sombreamento e as duas cores de dado.

    `brasa` e uma funcao (Vector) -> float com o valor de COLOR.r naquele
    ponto. COLOR.g sai de CURVATURA (quina = 1), medida pelo angulo entre as
    faces que chegam no vertice.
    """
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=solda)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.normal_update()

    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()

    if not suave:
        for p in me.polygons:
            p.use_smooth = False

    # ---- COLOR.g: quina. Compara a normal do vertice com a de cada face que
    # chega nele; quanto mais elas discordam, mais viva e a aresta.
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
        b = 0.0 if brasa is None else max(0.0, min(1.0, brasa(v.co)))
        cam.data[i].color = (b, quina[i], 0.0, 1.0)
    me.color_attributes.active_color = cam
    me.attributes.active_color_name = cam.name
    me.attributes.default_color_name = cam.name

    return bpy.data.objects.new(nome, me)


def _novo():
    return bmesh.new()


# ================================================================ o TRONCO

def peca_torax():
    """Torax: cintura fina, peito largo, esterno em quilha, trave de ombro.

    A cintura e o numero que mais decide a leitura. Com ela grossa ele vira um
    barril com bracos; fina, a mesma massa de peito vira PEITORAL. Aponta pra
    cima (y 0 -> 1) porque o `_spine` do rig aponta pra cima.
    """
    bm = _novo()
    _costura(bm, _perfil([
        (0.00, 0.17, 0.15, "chanfro"),      # encaixe na pelve
        (0.10, 0.21, 0.17, "chanfro"),
        (0.26, 0.24, 0.18, "chanfro"),      # CINTURA — o ponto mais estreito
        (0.44, 0.34, 0.25, "quilha"),
        (0.62, 0.43, 0.30, "quilha"),       # peito
        (0.78, 0.46, 0.30, "quilha"),
        (0.88, 0.44, 0.26, "placa"),        # trave de ombro, ja achatando
        (0.96, 0.34, 0.20, "placa"),
        (1.00, 0.20, 0.13, "chanfro"),      # gola
    ], n=12))
    # Fogo na cintura e na gola: as duas juntas do tronco. No meio da placa do
    # peito nao ha brasa nenhuma — e placa.
    def brasa(v):
        junta = max(0.0, 1.0 - abs(v.y - 0.30) / 0.14)
        gola = max(0.0, 1.0 - abs(v.y - 0.99) / 0.08)
        return max(junta * 0.85, gola * 0.6)
    return _finaliza("torax", bm, brasa)


def peca_costelado():
    """Caixa de costelas VAZADA, por fora do torax.

    E a peca principal do bicho. Sao cinco arcos por lado, com vao entre eles,
    e nada atras: de perto da pra ver a brasa do peito queimando LA DENTRO
    pelos vaos. Tudo que o corpo tinha antes era superficie pintada de laranja;
    isto e a unica parte em que o fogo esta de fato dentro de alguma coisa.
    """
    bm = _novo()
    alturas = [0.40, 0.50, 0.60, 0.70, 0.795]
    larguras = [0.36, 0.42, 0.455, 0.455, 0.42]
    fundos = [0.27, 0.31, 0.335, 0.335, 0.30]
    grossura = [0.030, 0.032, 0.032, 0.030, 0.027]
    for lado in (1.0, -1.0):
        for k in range(len(alturas)):
            y = alturas[k]
            w = larguras[k]
            d = fundos[k]
            # a costela sai da coluna (atras), abraca o lado e para antes do
            # esterno: o VAO da frente e o que deixa ver o fogo de dentro
            caminho = []
            for i in range(9):
                a = math.pi * (0.06 + 0.80 * i / 8.0)   # de tras pra frente
                caminho.append((
                    lado * math.sin(a) * w,
                    y - 0.055 * (i / 8.0) ** 2,          # a costela cai um pouco
                    math.cos(a) * d,
                ))
            r = grossura[k]
            raios = [r * (0.75 + 0.45 * math.sin(math.pi * i / 8.0)) for i in range(9)]
            _costura(bm, _varre(caminho, raios, n=6, achata=1.5), tampa=True)
    # coluna: a barra vertical atras que segura as costelas
    _costura(bm, _perfil([
        (0.36, 0.055, 0.050, "chanfro", 0.0, 0.27),
        (0.50, 0.060, 0.055, "chanfro", 0.0, 0.30),
        (0.66, 0.060, 0.055, "chanfro", 0.0, 0.32),
        (0.82, 0.052, 0.046, "chanfro", 0.0, 0.29),
    ], n=6))
    # Osso e osso: a brasa deste pedaco fica baixa. Quem queima e o vao, e o
    # vao e o torax atras (que tem brasa alta na cintura) e o ar.
    return _finaliza("costelado", bm, lambda v: 0.12)


def peca_peitoral():
    """Placa do esterno: a lasca chata que cobre a frente do peito.

    Vai por cima do costelado, tapando o vao central. Sem ela a gaiola fica
    aberta demais e ele perde a leitura de peito.
    """
    bm = _novo()
    _costura(bm, _perfil([
        (0.34, 0.055, 0.030, "cunha", 0.0, -0.26),
        (0.48, 0.115, 0.045, "cunha", 0.0, -0.30),
        (0.64, 0.140, 0.050, "cunha", 0.0, -0.32),
        (0.78, 0.120, 0.044, "cunha", 0.0, -0.30),
        (0.87, 0.060, 0.028, "cunha", 0.0, -0.26),
    ], n=8))
    return _finaliza("peitoral", bm, lambda v: 0.05)


def peca_pelve():
    """Pelve: bacia estreita, centrada na origem."""
    bm = _novo()
    _costura(bm, _perfil([
        (-0.26, 0.14, 0.13, "chanfro"),
        (-0.12, 0.20, 0.16, "chanfro"),
        (0.02, 0.24, 0.18, "gota"),
        (0.16, 0.21, 0.16, "chanfro"),
        (0.26, 0.15, 0.12, "chanfro"),
    ], n=10))
    return _finaliza("pelve", bm, lambda v: 0.25 * max(0.0, 1.0 - abs(v.y) / 0.28))


def peca_pescoco():
    bm = _novo()
    _costura(bm, _perfil([
        (0.00, 0.20, 0.19, "chanfro"),
        (0.30, 0.15, 0.15, "chanfro"),
        (0.72, 0.13, 0.14, "chanfro"),
        (1.00, 0.16, 0.17, "chanfro"),
    ], n=8))
    # o pescoco e junta pura: queima inteiro
    return _finaliza("pescoco", bm, lambda v: 0.75)


# ============================================================= CABECA e ELMO

def peca_elmo():
    """Elmo SEM ROSTO: casco liso, bicudo pra frente, com uma fenda horizontal.

    A fenda nao e furo — e um sulco fundo, com brasa no fundo dele. Furo de
    verdade deixaria ver o interior vazio, e alpha scissor nao perdoa. O sulco
    com COLOR.r = 1 no fundo da a mesma leitura e nao abre a malha.

    Origem na base do pescoco, cresce pra cima e pra frente (-Z).
    """
    bm = _novo()
    # Poucos lados (n=8) e de proposito: com 12 ele volta a ser ovo. O que da
    # leitura de ELMO e a face chata pegando luz, nao a curva macia.
    _costura(bm, _perfil([
        (0.00, 0.15, 0.16, "chanfro"),
        (0.12, 0.24, 0.27, "gota"),
        (0.26, 0.29, 0.34, "gota", 0.0, 0.03),
        (0.40, 0.30, 0.36, "gota", 0.0, 0.01),     # linha dos olhos
        (0.54, 0.27, 0.33, "gota", 0.0, 0.04),
        (0.68, 0.23, 0.28, "chanfro", 0.0, 0.08),
        (0.82, 0.19, 0.23, "chanfro", 0.0, 0.12),
        (0.92, 0.13, 0.15, "chanfro", 0.0, 0.15),
    ], n=8))
    # Bico: a cunha que desce e AVANCA na frente, no lugar do focinho. Sem ela
    # o elmo e um ovo com um risco; com ela ele tem direcao — da pra dizer pra
    # onde o bicho esta olhando mesmo sem rosto nenhum.
    _costura(bm, _varre([(0.0, 0.56, -0.22), (0.0, 0.44, -0.40),
                         (0.0, 0.30, -0.50), (0.0, 0.16, -0.46)],
                        [0.13, 0.115, 0.075, 0.020], n=6, achata=0.62))

    def brasa(v):
        # Fenda: faixa estreita na altura dos olhos, so na metade da frente.
        # Nao e furo — e sulco com brasa no fundo. Furo deixaria ver o interior
        # vazio, e alpha scissor nao perdoa isso.
        if v.z > -0.05:
            return 0.0
        f = max(0.0, 1.0 - abs(v.y - 0.40) / 0.05)
        return f * min(1.0, (-v.z - 0.05) / 0.14)
    return _finaliza("elmo", bm, brasa)


def peca_chifre():
    """Um chifre da coroa. Sobe do craneo e varre pra TRAS (+Z).

    O Godot instancia varios com escala e giro diferentes — e a variacao entre
    eles que faz uma coroa em vez de duas antenas.
    """
    caminho = []
    for i in range(8):
        f = i / 7.0
        caminho.append((0.0, f * 0.86 - f * f * 0.26, f * f * 0.78))
    raios = [0.135 * (1.0 - f / 7.0) ** 0.8 + 0.004 for f in range(8)]
    bm = _novo()
    _costura(bm, _varre(caminho, raios, n=6, achata=0.72))
    # so a raiz queima: a ponta e osso frio
    return _finaliza("chifre", bm, lambda v: max(0.0, 1.0 - v.y / 0.22) * 0.7)


def peca_halo():
    """Aurela QUEBRADA: tres arcos de um anel que nao fecha, atras da cabeca.

    Diz "serafim" numa leitura so. Fica no plano XY (de frente pro jogador
    quando ele encara) e e a peca com mais brasa do corpo inteiro.
    """
    bm = _novo()
    for a0, a1 in ((0.10, 0.92), (1.12, 1.72), (1.90, 2.28)):
        caminho, raios = [], []
        passos = 10
        for i in range(passos):
            a = math.pi * (a0 + (a1 - a0) * i / (passos - 1.0))
            caminho.append((math.cos(a) * 0.46, math.sin(a) * 0.46, 0.0))
            borda = math.sin(math.pi * i / (passos - 1.0))
            # grosso: fino demais o arco some contra a cidade e vira um fio
            raios.append(0.034 + 0.030 * borda)
        _costura(bm, _varre(caminho, raios, n=5, achata=0.55))
    return _finaliza("halo", bm, lambda v: 1.0)


# ================================================================== MEMBROS
#
# Todos pendem do pivo: y de 0 (junta) a -1 (ponta).

def peca_braco():
    """Braco: grosso no ombro, afinando pro cotovelo, com quina por fora."""
    bm = _novo()
    _costura(bm, _perfil([
        (0.00, 0.42, 0.40, "chanfro"),
        (-0.10, 0.48, 0.44, "chanfro"),
        (-0.35, 0.42, 0.38, "chanfro"),
        (-0.68, 0.34, 0.31, "chanfro"),
        (-0.90, 0.32, 0.30, "chanfro"),
        (-1.00, 0.27, 0.26, "chanfro"),
    ], n=8))
    def brasa(v):
        return max(max(0.0, 1.0 - abs(v.y) / 0.10),
                   max(0.0, 1.0 - abs(v.y + 1.0) / 0.10)) * 0.8
    return _finaliza("braco", bm, brasa)


def peca_antebraco():
    """Antebraco com ESPORAO no cotovelo: a lasca que aponta pra tras.

    E o detalhe que transforma um cilindro em arma. Ele aparece toda vez que o
    bicho dobra o braco, que e em quase toda pose de poder.
    """
    bm = _novo()
    _costura(bm, _perfil([
        (0.00, 0.40, 0.38, "chanfro"),
        (-0.16, 0.44, 0.40, "chanfro"),
        (-0.50, 0.34, 0.31, "chanfro"),
        (-0.82, 0.26, 0.24, "chanfro"),
        (-1.00, 0.22, 0.21, "chanfro"),
    ], n=8))
    # esporao: sai do cotovelo pra tras (+Z) e pra cima
    esp = [(0.0, -0.06 + 0.10 * f, 0.30 + 0.58 * f) for f in
           [i / 5.0 for i in range(6)]]
    _costura(bm, _varre(esp, [0.10, 0.085, 0.065, 0.045, 0.026, 0.006],
                        n=5, achata=0.7))
    def brasa(v):
        junta = max(max(0.0, 1.0 - abs(v.y) / 0.10),
                    max(0.0, 1.0 - abs(v.y + 1.0) / 0.09)) * 0.8
        return max(junta, 0.45 if v.z > 0.55 else 0.0)
    return _finaliza("antebraco", bm, brasa)


def peca_mao():
    """Palma: cunha chata de onde saem as garras."""
    bm = _novo()
    _costura(bm, _perfil([
        (0.00, 0.36, 0.34, "chanfro"),
        (-0.30, 0.44, 0.30, "placa"),
        (-0.70, 0.42, 0.26, "placa"),
        (-1.00, 0.30, 0.20, "placa"),
    ], n=8))
    return _finaliza("mao", bm, lambda v: max(0.0, 1.0 - abs(v.y) / 0.14) * 0.7)


def peca_garra():
    """Uma garra: comprida, curvando pra frente e afinando ate a ponta."""
    caminho = []
    for i in range(7):
        f = i / 6.0
        caminho.append((0.0, -f, -0.30 * f * f))
    raios = [0.17 * (1.0 - f / 6.0) ** 0.8 + 0.005 for f in range(7)]
    bm = _novo()
    _costura(bm, _varre(caminho, raios, n=5, achata=0.8))
    # a ponta da garra e brasa viva
    return _finaliza("garra", bm, lambda v: max(0.0, (-v.y - 0.55) / 0.45) * 0.9)


def peca_coxa():
    """Coxa: musculosa em cima, fina no joelho. Perna digitigrada."""
    bm = _novo()
    _costura(bm, _perfil([
        (0.00, 0.38, 0.36, "chanfro"),
        (-0.14, 0.48, 0.46, "chanfro"),
        (-0.44, 0.44, 0.42, "chanfro"),
        (-0.78, 0.32, 0.32, "chanfro"),
        (-1.00, 0.25, 0.26, "chanfro"),
    ], n=8))
    def brasa(v):
        return max(max(0.0, 1.0 - abs(v.y) / 0.10),
                   max(0.0, 1.0 - abs(v.y + 1.0) / 0.09)) * 0.75
    return _finaliza("coxa", bm, brasa)


def peca_canela():
    """Canela: fina e reta, com a quina da tibia na frente."""
    bm = _novo()
    _costura(bm, _perfil([
        (0.00, 0.40, 0.38, "chanfro"),
        (-0.22, 0.34, 0.34, "quilha"),
        (-0.60, 0.26, 0.28, "quilha"),
        (-0.88, 0.24, 0.26, "chanfro"),
        (-1.00, 0.26, 0.28, "chanfro"),
    ], n=8))
    def brasa(v):
        return max(max(0.0, 1.0 - abs(v.y) / 0.09),
                   max(0.0, 1.0 - abs(v.y + 1.0) / 0.09)) * 0.75
    return _finaliza("canela", bm, brasa)


def peca_pe():
    """Pe de ave de rapina: calcanhar alto atras, tres dedos pra frente.

    Centrado na origem do tornozelo; frente e -Z. Faz parte da leitura
    digitigrada que as pernas ja tentavam ter e a caixa de antes matava.
    """
    bm = _novo()
    # metatarso, inclinado: do tornozelo pra frente e pra baixo
    _costura(bm, _varre([(0.0, 0.0, 0.08), (0.0, -0.16, -0.10), (0.0, -0.26, -0.30)],
                        [0.16, 0.14, 0.11], n=7, achata=0.85))
    # esporao do calcanhar
    _costura(bm, _varre([(0.0, -0.05, 0.06), (0.0, -0.16, 0.26), (0.0, -0.23, 0.38)],
                        [0.09, 0.06, 0.015], n=5, achata=0.8))
    # tres dedos, com a garra virando pra baixo na ponta
    for lado in (-1.0, 0.0, 1.0):
        base = (lado * 0.11, -0.26, -0.30)
        caminho = [base,
                   (lado * 0.15, -0.31, -0.46),
                   (lado * 0.17, -0.34, -0.60),
                   (lado * 0.18, -0.42, -0.68)]
        _costura(bm, _varre(caminho, [0.085, 0.065, 0.045, 0.010], n=5, achata=0.85))
    return _finaliza("pe", bm, lambda v: max(0.0, 1.0 - abs(v.y) / 0.12) * 0.6)


def peca_ombreira():
    """Ombreira: placa grande e angular por cima do ombro.

    Autorada pro lado ESQUERDO (+X); o Godot espelha com scale.x = -1 pro
    direito. E a peca que da largura de ombro sem engordar o braco — e largura
    de ombro com cintura fina e o que faz a silhueta dele.
    """
    bm = _novo()
    _costura(bm, _perfil([
        (0.16, 0.10, 0.16, "placa", 0.0, 0.0),
        (0.06, 0.30, 0.30, "chanfro"),
        (-0.10, 0.44, 0.34, "chanfro"),
        (-0.30, 0.46, 0.31, "chanfro"),
        (-0.48, 0.38, 0.24, "chanfro"),
        (-0.58, 0.24, 0.15, "chanfro"),
    ], n=10))
    # espinho pra fora, na quina de cima da placa
    _costura(bm, _varre([(0.30, -0.04, 0.0), (0.52, 0.06, 0.02), (0.68, 0.12, 0.03)],
                        [0.10, 0.06, 0.008], n=5, achata=0.8))
    return _finaliza("ombreira", bm, lambda v: 0.06)


def peca_manto():
    """Manto esfarrapado: casca aberta atras, com a barra rasgada em pontas.

    Pendura no ombro (y 0 -> -1). Nao e tubo fechado: e meia casca, com a
    frente aberta, senao ele fica dentro de um saco.
    """
    bm = _novo()
    aneis = []
    for k, (y, r, dz) in enumerate([
            (0.00, 0.30, 0.04), (-0.22, 0.38, 0.06), (-0.50, 0.45, 0.08),
            (-0.78, 0.50, 0.09), (-1.00, 0.53, 0.10)]):
        anel = []
        n = 11
        for i in range(n):
            # Metade de TRAS: o arco tem de ser simetrico em torno de +Z, que e
            # onde as costas ficam. De 0 a PI ele varria de tras ate a FRENTE
            # por um lado so — o manto nascia torto e tapava o peito inteiro,
            # que e justamente o que ninguem pode tapar neste bicho.
            a = math.pi * (-0.58 + 1.16 * i / (n - 1.0))
            # a barra do manto e rasgada: a ultima fiada oscila de comprimento
            corte = 1.0 + (0.14 * math.sin(i * 2.7) if k == 4 else 0.0)
            anel.append(Vector((math.sin(a) * r, y * corte, math.cos(a) * r * 0.85 + dz)))
        aneis.append(anel)
    _costura(bm, aneis, tampa=False, fechado=False)
    return _finaliza("manto", bm, lambda v: max(0.0, (-v.y - 0.7) / 0.3) * 0.5,
                     suave=True)


# ==================================================================== ASAS
#
# Asa de LAMINA, nao de pena (ver a nota do desenho no topo). Cada "pena" e
# uma lasca comprida, chata e afiada, com o fio aceso. Pendem do pivo, y 0 ->
# -1, achatadas em Z, e o Godot as abre em leque com escalas diferentes.

def _lamina_pena(nome, largura, espessura, gume=0.9):
    bm = _novo()
    aneis = []
    for f in [0.0, 0.08, 0.24, 0.46, 0.68, 0.86, 0.95, 0.99, 1.0]:
        # Larga logo depois da raiz e afilando ate a ponta, como lamina de
        # faca. Antes ela afinava nas DUAS pontas e saia uma agulha.
        w = largura * (0.42 + 0.58 * math.sin(math.pi * min(1.0, f * 1.45)) ** 0.45) \
            * (1.0 - 0.97 * f ** 4.5)
        e = espessura * (1.0 - 0.70 * f)
        aneis.append(_anel(6, w, e, -f, "quilha"))
    _costura(bm, aneis)
    # gume aceso na borda de ataque (-Z) e na ponta
    def brasa(v):
        fio = max(0.0, min(1.0, (-v.z) / max(1e-5, espessura * 0.9)))
        ponta = max(0.0, (-v.y - 0.72) / 0.28)
        return max(fio * gume * 0.55, ponta * 0.85)
    return _finaliza(nome, bm, brasa)


def peca_pena_g():
    return _lamina_pena("pena_g", 0.40, 0.090)


def peca_pena_m():
    return _lamina_pena("pena_m", 0.46, 0.105)


def peca_pena_p():
    return _lamina_pena("pena_p", 0.52, 0.125, gume=0.6)


def peca_asa_osso():
    """Osso da asa: pende do pivo (y 0 -> -1) como todo membro.

    O `shadow_seraph.gd` gira em Z pra deixa-lo apontando pra fora, que e a
    mesma conta que ele ja fazia com a capsula.
    """
    bm = _novo()
    _costura(bm, _perfil([
        (0.00, 0.46, 0.40, "chanfro"),
        (-0.18, 0.40, 0.34, "chanfro"),
        (-0.55, 0.30, 0.25, "chanfro"),
        (-0.85, 0.24, 0.20, "chanfro"),
        (-1.00, 0.28, 0.23, "chanfro"),
    ], n=7))
    return _finaliza("asa_osso", bm,
                     lambda v: max(0.0, 1.0 - abs(v.y + 1.0) / 0.14) * 0.8)


# =================================================================== ARMAS

def peca_espada_lamina():
    """Lamina: reta, afinando, com quilha no fio. Aponta pra CIMA (y 0 -> 1)."""
    bm = _novo()
    aneis = []
    for f in [0.0, 0.06, 0.35, 0.68, 0.88, 0.97, 1.0]:
        w = 0.42 * (1.0 - 0.42 * f) * math.sin(math.pi * (0.30 + 0.70 * (1.0 - f))) ** 0.35
        e = 0.115 * (1.0 - 0.55 * f)
        aneis.append(_anel(6, w, e, f, "quilha", giro=math.pi * 0.5))
    _costura(bm, aneis)
    def brasa(v):
        fio = max(0.0, min(1.0, (abs(v.x) - 0.18) / 0.16))
        return max(fio * 0.9, max(0.0, (v.y - 0.9) / 0.1))
    return _finaliza("espada_lamina", bm, brasa)


def peca_espada_punho():
    """Guarda + cabo + pomo numa peca so, centrada na origem."""
    bm = _novo()
    # guarda: barra atravessada, com as pontas viradas pra cima
    _costura(bm, _varre([(-0.50, 0.06, 0.0), (-0.25, -0.01, 0.0), (0.0, -0.03, 0.0),
                         (0.25, -0.01, 0.0), (0.50, 0.06, 0.0)],
                        [0.02, 0.055, 0.075, 0.055, 0.02], n=6, achata=0.55))
    _costura(bm, _perfil([
        (-0.06, 0.055, 0.055, "chanfro"),
        (-0.34, 0.048, 0.048, "chanfro"),
        (-0.46, 0.075, 0.075, "chanfro"),
        (-0.56, 0.045, 0.045, "chanfro"),
    ], n=6))
    def brasa(v):
        return 0.8 if v.y > -0.02 and abs(v.x) > 0.36 else 0.1
    return _finaliza("espada_punho", bm, brasa)


def peca_bazuca():
    """Bazuca inteira numa peca: tubo, bocal e empunhadura.

    Autorada apontando pra FRENTE (-Z), origem no ombro de quem segura.
    """
    bm = _novo()
    _costura(bm, _varre([(0.0, 0.0, 0.50), (0.0, 0.0, 0.20), (0.0, 0.0, -0.15),
                         (0.0, 0.0, -0.40), (0.0, 0.0, -0.50)],
                        [0.10, 0.15, 0.14, 0.17, 0.19], n=10))
    # mira por cima
    _costura(bm, _varre([(0.0, 0.13, 0.06), (0.0, 0.22, 0.02), (0.0, 0.23, -0.10)],
                        [0.035, 0.030, 0.022], n=5))
    # empunhadura por baixo
    _costura(bm, _varre([(0.0, -0.10, 0.06), (0.0, -0.26, 0.12)],
                        [0.045, 0.038], n=5))
    def brasa(v):
        return 1.0 if v.z < -0.42 else (0.5 if v.z > 0.46 else 0.05)
    return _finaliza("bazuca", bm, brasa)


# ================================================================== export

PECAS = [
    peca_torax, peca_costelado, peca_peitoral, peca_pelve, peca_pescoco,
    peca_elmo, peca_chifre, peca_halo,
    peca_braco, peca_antebraco, peca_mao, peca_garra,
    peca_coxa, peca_canela, peca_pe, peca_ombreira, peca_manto,
    peca_asa_osso, peca_pena_g, peca_pena_m, peca_pena_p,
    peca_espada_lamina, peca_espada_punho, peca_bazuca,
]


def _exporta(colecao, caminho):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.collections[colecao].objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = list(
        bpy.data.collections[colecao].objects)[0]

    # export_yup=False DE PROPOSITO. As pecas sao autoradas neste arquivo na
    # convencao do JOGO (Y pra cima, -Z pra frente), nao na do Blender (Z pra
    # cima). Com `export_yup=True` o exportador faria a conversao Z-up -> Y-up
    # por cima de dados que ja estao em Y-up e tudo chegaria no Godot deitado.
    # Desligado, os eixos vao crus pro `.glb`, que e Y-up por especificacao, e
    # e exatamente o que o Godot espera. (Em contrapartida, quem abrir o
    # `.blend` vai ver as pecas deitadas — e o preco, e esta escrito aqui.)
    kw = dict(filepath=caminho, export_format="GLB", use_selection=True,
              export_apply=True, export_yup=False, export_materials="NONE",
              export_normals=True)
    # O nome da opcao de cor de vertice mudou entre versoes do exportador; sem
    # ela o COLOR_0 nao sai e o shader perde a mascara de brasa e a quina.
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

    print("\n[shadow_seraph] %d pecas -> %s" % (len(PECAS), SAIDA))
    for nome, tris, verts in sorted(linhas, key=lambda r: -r[1]):
        print("  %-16s %5d tris  %4d verts" % (nome, tris, verts))
    print("[shadow_seraph] total %d tris" % total)
    print("[shadow_seraph] cor de vertice via %r" % flag)
    print("[shadow_seraph] tamanho: %.1f KB" % (os.path.getsize(SAIDA) / 1024.0))


if __name__ == "__main__":
    main()
