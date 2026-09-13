"""Gera a biblioteca de pedras do Shadow Rock e exporta pra `.glb`.

Rodar em background (NAO precisa do addon MCP nem mexe na cena que voce tem
aberta):

    /snap/blender/7740/blender --background --python tools/blender/rochas/gerar_pedras.py

Saida: red-valve/assets/3d_model/enemies/shadow_rock/pedras.glb

------------------------------------------------------------------------------
POR QUE ESTE ARQUIVO EXISTE (e por que a pedra nao e mais gerada no Godot)

O `rock_fx.gd` sabia fazer pedra sozinho: pegava uma esfera de baixa resolucao
e empurrava cada vertice por um numero sorteado. Aquilo da uma BATATA AMASSADA.
Pedra quebrada de verdade nao e uma bola irregular — ela tem PLANOS DE CLIVAGEM:
faces chatas e retas onde o bloco se partiu, encontrando-se em quinas vivas.

Reproduzir isso e cortar a malha com planos, e cortar malha com plano e uma
operacao de bmesh. Em GDScript daria um gerador de geometria inteiro dentro do
jogo, pago no carregamento, pra chegar onde tres linhas de `bmesh.ops` chegam
aqui — de graca, uma vez so, versionado no repo e abrivel no Blender pra quem
quiser mexer a mao.

O `rock_fx.gd` MANTEM o gerador antigo como reserva: se este `.glb` nao estiver
importado, o inimigo continua de pe com as pedras feias em vez de sumir.

------------------------------------------------------------------------------
O QUE VAI JUNTO DA MALHA

O shader `shadow_rock_body.gdshader` le duas coisas da cor do vertice, e elas
sao assadas aqui:

  COLOR.r  semente da pedra (constante na malha inteira). Desloca o desenho das
           gretas, pra que as 24 pedras nao repitam o mesmo padrao.
  COLOR.g  o quanto o vertice esta EXPOSTO: 1 numa quina saliente, 0 no fundo
           de uma reentrancia. O shader escurece por ali.

`COLOR.g` sai de CURVATURA, nao de oclusao de ambiente. Motivo: estas pedras
sao quase convexas, e num convexo a oclusao real e praticamente uniforme — nao
daria variacao nenhuma. Curvatura da o que se quer de fato, que e a quina
clareando e a junta entre duas faces escurecendo.

Use FLOAT_COLOR (nao BYTE_COLOR): cor em byte e gravada em sRGB e chega no
Godot com gama aplicada. Aqui os canais sao DADO, nao cor — uma conversao de
espaco no meio bagunçaria a semente e a curva de sombra.
"""
import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Vector, noise

# ---------------------------------------------------------------- parametros

## Quantas pedras a biblioteca tem. Com giro e escala sorteados por instancia no
## Godot, 24 formas cobrem as ~70 pedras do corpo sem repeticao visivel.
TOTAL = 24
## As primeiras sao as DETALHADAS (corpo, pedregulho, espada, parede); as
## ultimas sao as SIMPLES, de poucos triangulos, pros cacos no chao — que podem
## ser 150 ao mesmo tempo e nao aguentam o mesmo orcamento.
SIMPLES_A_PARTIR_DE = 16

## Raio MEDIO dos vertices de toda pedra, em metros de espaco de modelo.
##
## Medio, e nao maximo, e isso importa. Normalizar pelo vertice mais distante
## faz cada pedra caber numa esfera de raio 0,5 — mas uma pedra muito cortada
## tem quase todo o volume bem dentro dessa esfera, entao ela sai VISUALMENTE
## menor que uma pouco cortada de mesmo "raio". No corpo do inimigo, montado de
## ~70 pedras encostadas, isso apareceu na hora: as pedras pararam de se tocar e
## o boneco esfarelou em cacos soltos.
##
## O raio medio mede o VOLUME de fato, entao pedras diferentes com o mesmo
## numero ocupam o mesmo espaco. 0,45 e o volume que as pedras antigas (esferas
## amassadas) tinham — e o que mantem o `RockFX.bloco()` e o `escala_tex` do
## shader calibrados sem mexer em nada do lado do Godot.
RAIO = 0.52

COLECAO = "SHADOW_ROCK_PEDRAS"

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.abspath(os.path.join(_HERE, "..", "..", ".."))
SAIDA = os.path.join(_REPO, "red-valve", "assets", "3d_model",
                     "enemies", "shadow_rock", "pedras.glb")


# ------------------------------------------------------------------- helpers

def _limpa_cena():
    """Comeca de um arquivo vazio. Em background isso nao toca em nada seu."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _icosfera(bm, subdiv):
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)


def _amassa(bm, rng, forca, escala_ruido):
    """Empurra cada vertice pela normal com ruido. E o volume BRUTO da pedra —
    o que vem depois (os cortes) e que da a cara de rocha partida."""
    origem = Vector((rng.uniform(-50, 50), rng.uniform(-50, 50), rng.uniform(-50, 50)))
    for v in bm.verts:
        n = noise.noise(v.co * escala_ruido + origem)
        v.co += v.normal * (n * forca)


def _estica(bm, rng):
    """Escala nao uniforme + cisalhamento: e o que diferencia laje, seixo e
    lasca. Sem isto as 24 pedras tem todas a mesma proporcao."""
    sx = rng.uniform(0.62, 1.35)
    sy = rng.uniform(0.55, 1.30)
    sz = rng.uniform(0.62, 1.35)
    cis = rng.uniform(-0.22, 0.22)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
        v.co.x += v.co.z * cis


def _corta_plano(bm, co, no):
    """Um plano de clivagem. Fatia a malha, joga fora o lado de fora e TAMPA o
    buraco — o tampao e a face chata que o olho le como pedra partida.

    Sem o `edgeloop_fill` a pedra fica com um rombo aberto e o Godot renderiza
    o avesso dela por dentro.
    """
    res = bmesh.ops.bisect_plane(
        bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
        plane_co=co, plane_no=no, clear_outer=True)
    arestas = [g for g in res["geom_cut"] if isinstance(g, bmesh.types.BMEdge)]
    if arestas:
        bmesh.ops.edgeloop_fill(bm, edges=arestas)


def _clivagem(bm, rng, cortes):
    """`cortes` planos em direcoes sorteadas, cada um a uma distancia sorteada
    do centro. Distancia perto de 1 raspa so uma quina; perto de 0,5 corta um
    naco grande. A mistura das duas e o que da pedra irregular em vez de
    poliedro regular."""
    for _ in range(cortes):
        d = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1)))
        if d.length < 1e-6:
            continue
        d.normalize()
        # alcance da malha nesta direcao, pra medir o corte contra ela
        alcance = max((v.co.dot(d) for v in bm.verts), default=1.0)
        if alcance <= 1e-6:
            continue
        _corta_plano(bm, d * (alcance * rng.uniform(0.48, 0.88)), d)


def _normaliza(bm):
    """Centro na origem e raio MEDIO dos vertices = RAIO (ver a constante)."""
    if not bm.verts:
        return
    mn = Vector((min(v.co.x for v in bm.verts),
                 min(v.co.y for v in bm.verts),
                 min(v.co.z for v in bm.verts)))
    mx = Vector((max(v.co.x for v in bm.verts),
                 max(v.co.y for v in bm.verts),
                 max(v.co.z for v in bm.verts)))
    centro = (mn + mx) * 0.5
    for v in bm.verts:
        v.co -= centro

    medio = sum(v.co.length for v in bm.verts) / float(len(bm.verts))
    if medio <= 1e-9:
        return
    k = RAIO / medio
    # Teto de seguranca: uma lasca muito fina tem raio medio baixinho e o
    # fator acima a inflaria ate virar um menir. 0,85 no vertice mais distante
    # e o limite do que ainda le como pedaco de pedra.
    maior = max(v.co.length for v in bm.verts) * k
    if maior > 0.95:
        k *= 0.95 / maior
    for v in bm.verts:
        v.co *= k


def _curvatura(bm):
    """Por vertice: quanto a superficie DOBRA ali, e pra que lado.

    Media, sobre os vizinhos, de dot(normalize(vizinho - v), normal_v):
      > 0  os vizinhos estao acima do plano tangente  -> reentrancia (concavo)
      < 0  os vizinhos estao abaixo                   -> quina viva (convexo)

    Devolve {indice: exposto}, com 1 na quina e 0 no fundo da junta.
    """
    fora = {}
    for v in bm.verts:
        viz = [e.other_vert(v) for e in v.link_edges]
        if not viz:
            fora[v.index] = 1.0
            continue
        soma = 0.0
        for w in viz:
            d = w.co - v.co
            if d.length < 1e-9:
                continue
            soma += d.normalized().dot(v.normal)
        conc = soma / float(len(viz))
        # -0,35..+0,35 cobre bem a faixa real destas malhas; fora disso satura
        fora[v.index] = min(1.0, max(0.0, 0.5 - conc * 1.45))
    return fora


def _radial(bm):
    """Quanto o vertice se projeta pra fora, de 0 (o mais afundado) a 1 (a
    ponta mais saliente). Entra junto da curvatura pra dar a sombra de volume
    grande — a curvatura sozinha so enxerga a junta entre duas faces."""
    if not bm.verts:
        return {}
    rs = {v.index: v.co.length for v in bm.verts}
    mn, mx = min(rs.values()), max(rs.values())
    faixa = max(mx - mn, 1e-9)
    return {i: (r - mn) / faixa for i, r in rs.items()}


def _pedra(indice, semente):
    rng = random.Random(semente)
    simples = indice >= SIMPLES_A_PARTIR_DE

    bm = bmesh.new()
    _icosfera(bm, 1 if simples else 2)
    bm.verts.ensure_lookup_table()
    _estica(bm, rng)
    _amassa(bm, rng,
            forca=rng.uniform(0.10, 0.26),
            escala_ruido=rng.uniform(1.1, 2.4))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _clivagem(bm, rng, rng.randint(4, 7) if simples else rng.randint(8, 14))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    # solda vertices que os cortes deixaram praticamente em cima uns dos outros
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.004)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _normaliza(bm)

    bm.verts.ensure_lookup_table()
    bm.normal_update()
    curv = _curvatura(bm)
    radi = _radial(bm)

    me = bpy.data.meshes.new("PEDRA_%02d" % indice)
    bm.to_mesh(me)
    bm.free()

    # faceta: pedra partida nao tem sombreamento suave
    me.polygons.foreach_set("use_smooth", [False] * len(me.polygons))

    cor_semente = (semente % 997) / 997.0
    cam = me.color_attributes.new(name="rock", type="FLOAT_COLOR", domain="POINT")
    for i, _v in enumerate(me.vertices):
        exposto = curv.get(i, 1.0) * 0.65 + radi.get(i, 1.0) * 0.35
        cam.data[i].color = (cor_semente, min(1.0, max(0.0, exposto)), 1.0, 1.0)
    # Marca "rock" como a camada ATIVA e a PADRAO de cor. O exportador de glTF
    # so escreve COLOR_0 a partir da ativa; a padrao e a que o Blender usa ao
    # renderizar. Sao propriedades de `mesh.attributes` e recebem o NOME, nao a
    # camada (`color_attributes.default_color` nao existe no 5.2).
    me.color_attributes.active_color = cam
    me.attributes.active_color_name = cam.name
    me.attributes.default_color_name = cam.name

    ob = bpy.data.objects.new(me.name, me)
    return ob, len(me.polygons)


# -------------------------------------------------------------------- export

def _exporta(col_nome, caminho):
    col = bpy.data.collections.get(col_nome)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in col.all_objects:
        if ob.type == "MESH":
            ob.select_set(True)
            bpy.context.view_layer.objects.active = ob
    os.makedirs(os.path.dirname(caminho), exist_ok=True)

    # `.glb` de arquivo unico: sao 24 malhas minusculas sem textura nenhuma (a
    # rocha vem do shader, por triplanar), entao nao ha PNG pra referenciar como
    # no citygen — embutir e mais simples e nao duplica nada.
    kw = dict(filepath=caminho, export_format="GLB", use_selection=True,
              export_apply=True, export_yup=True, export_materials="NONE",
              export_normals=True)
    # O nome da opcao de cor de vertice mudou entre versoes do exportador; sem
    # ela o COLOR_0 nao sai e o shader perde semente e curvatura.
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

    tris = []
    for i in range(TOTAL):
        ob, n = _pedra(i, 7919 * (i + 1) + 13)
        col.objects.link(ob)
        tris.append(n)

    flag = _exporta(COLECAO, SAIDA)

    detalhadas = tris[:SIMPLES_A_PARTIR_DE]
    simples = tris[SIMPLES_A_PARTIR_DE:]
    print("\n[shadow_rock] %d pedras -> %s" % (TOTAL, SAIDA))
    print("[shadow_rock] detalhadas: %d..%d tris (media %.0f)"
          % (min(detalhadas), max(detalhadas), sum(detalhadas) / len(detalhadas)))
    print("[shadow_rock] simples:    %d..%d tris (media %.0f)"
          % (min(simples), max(simples), sum(simples) / len(simples)))
    print("[shadow_rock] cor de vertice via %r" % flag)
    print("[shadow_rock] tamanho: %.1f KB" % (os.path.getsize(SAIDA) / 1024.0))


if __name__ == "__main__":
    main()
